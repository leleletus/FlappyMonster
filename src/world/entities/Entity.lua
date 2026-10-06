-- src/world/entities/Entity.lua
-- Clase base de TODAS las entidades del nivel (enemigos, NPCs...).
--
-- Resuelve lo común a partir de las propiedades de la colocación (ver
-- EntityTypes.COMMON): movimiento (camina por suelo o techo, vuela, quieto),
-- ruta con límites, giro en bordes, pausas con "respiración", muerte y
-- pisotón. Un tipo nuevo hereda con Entity.extend() y solo define:
--
--   Cls.tuning            constantes de animación/tiempos (ver DEFAULT_TUNING)
--   Cls.loadAssets()      carga sus sprites (una vez)
--   Cls.sizeImage()       imagen cuyo tamaño define la hitbox
--   e:render(camX, camY)  dibujo
--
-- y, si quiere comportamiento propio, cualquiera de estos hooks:
--   e:init()              al crearse (timers propios)
--   e:updateCustom(dt, level) -> true   estados propios (se salta lo común)
--   e:onWalk(dt) / e:onIdle(dt) / e:onDead(dt) / e:onStomp()
--   e:onIdleEnd() -> true  decidir otro estado al terminar una pausa
--   e:canBeStomped(), e:isBodyDisabled(), e:getHazardBoxes()
--   e:netPack() / e:netApply(a, b, f)   datos extra sincronizados online
--   e:netAtRest() / e:netRest()          no enviarla mientras está en reposo
--   Cls.sizePx() -> w, h  tamaño en px (en vez de sizeImage) para dibujos por código
--   Cls.customDrop = true  los estados 'drop_*' los lleva su updateCustom
--
-- Comunes a todas (propiedades): reaparecer tras morir (respawn), y para las
-- de techo, dejarse caer al ver a un jugador debajo (dropOnSight/detectRange).
-- Estados comunes extra: 'gone' (esperando reaparecer), 'spawning' (animación
-- de aparición), 'drop_shake' / 'drop_fall' (caída desde el techo). Para ver a
-- los jugadores, el juego pone la lista en level.players.

local Entity = {}
Entity.__index = Entity

local DEFAULT_TUNING = {
    walkFps      = 7,      -- cuadros/s de la animación de caminar
    walkFrames   = 2,      -- cuántos cuadros tiene el ciclo
    deadDuration = 1.4,    -- s mostrando el sprite de muerto
    idleEvery    = { 3.0, 7.0 },  -- s entre pausas (mín, máx)
    idleFor      = { 1.0, 2.2 },  -- duración de cada pausa (mín, máx)
    breatheSpeed = 3.2,
    breatheAmp   = 0.06,
    hitbox       = { outerW = 0.72, outerH = 0.80, innerW = 0.44, innerH = 0.50 },
    flyBobSpeed  = 2.0,    -- rad/s de la oscilación de los voladores
    debugColor   = { 1, 0.55, 0 },
}
Entity.tuning = DEFAULT_TUNING

function Entity.extend(base, tuning)
    base = base or Entity
    local cls = setmetatable({}, { __index = base })
    cls.__index = cls
    cls.super = base
    local t = {}
    for k, v in pairs(base.tuning) do t[k] = v end
    for k, v in pairs(tuning or {}) do t[k] = v end
    cls.tuning = t
    return cls
end

local FreeFlight
local function randRange(a, b)
    return a + math.random() * (b - a)
end
Entity.randRange = randRange

-- ── Construcción ──────────────────────────────────────────────────────────────
-- data = colocación normalizada { type, col, row, props }
function Entity.create(cls, data)
    cls.loadAssets()
    local e = setmetatable({}, cls)
    local p, tn, T = data.props, cls.tuning, TILE_PX
    e.def, e.typeName, e.props = cls.def, cls.def.name, p
    -- RASGOS del tipo (`traits = { needsPound = true, ... }` en su definición): interruptores de
    -- las reglas base, sin escribir código (lista en docs/entidades/COMO_CREAR_UN_ENEMIGO.md).
    -- Van en la instancia: varios tipos pueden compartir clase con rasgos distintos.
    if cls.def.traits then for k, v in pairs(cls.def.traits) do e[k] = v end end
    e.col, e.row = data.col, data.row

    e.x = (data.col - 1) * T + T / 2
    e.y = (data.row - 1) * T + T / 2
    e.sub = data.sub
    if data.sub then   -- colocada en una subcelda (1 TL, 2 TR, 3 BL, 4 BR): su centro
        e.x = (data.col - 1) * T + ((data.sub - 1) % 2) * T / 2 + T / 4
        e.y = (data.row - 1) * T + math.floor((data.sub - 1) / 2) * T / 2 + T / 4
    end
    e.baseY = e.y

    local dir = (p.startDir == 'left') and -1 or 1
    e.speed   = p.speed or 0
    e.moving  = p.movement ~= 'static'
    e.flying  = p.movement == 'fly'
    e.freeFly = e.flying and p.flyMode == 'free'      -- (vuelo libre: entities/FreeFlight.lua)
    e.flipped = (p.movement == 'walk') and p.attach == 'ceiling'
    e.vx = e.moving and e.speed * dir or 0
    e.vy = 0

    if p.patrol then
        e.leftBoundPx  = (p.patrol.left  - 1) * T
        e.rightBoundPx =  p.patrol.right      * T
    else
        e.leftBoundPx, e.rightBoundPx = -math.huge, math.huge
    end

    local iw, ih
    if cls.sizePx then
        iw, ih = cls.sizePx()
    else
        local img = cls.sizeImage()
        local k = cls.artScale or GUMMY_SCALE                  -- (artScale: tipos dibujados a otra escala, p. ej. el Crabby helado)
        iw, ih = img:getWidth() * k, img:getHeight() * k
    end
    local hb = tn.hitbox
    e.sprW, e.sprH = iw, ih
    e.outerW, e.outerH = iw * hb.outerW, ih * hb.outerH
    e.innerW, e.innerH = iw * hb.innerW, ih * hb.innerH

    e.onGround  = false
    e.facing    = dir
    e.state     = 'walk'     -- 'walk' | 'idle' | 'dead' | estados propios
    e.deadTimer = 0
    e.alive     = true
    e.animT, e.frame = 0, 1

    e.idleCountdown = randRange(tn.idleEvery[1], tn.idleEvery[2])
    e.idleTimer, e.idleDuration, e.breatheT = 0, 0, 0
    e.flyT = 0

    e:init()
    -- Estado inicial para poder reaparecer igual que al colocarla
    e.home = { x = e.x, y = e.y, vx = e.vx, facing = e.facing, flipped = e.flipped, state = e.state }
    return e
end

-- Efectos visuales de las entidades (impactos...). El juego pone aquí quién
-- los dibuja: partículas en un jugador; el servidor los reenvía como eventos.
Entity.fx = nil
function Entity.emitFx(kind, x, y)
    if Entity.fx then Entity.fx(kind, x, y) end
end

local SPAWN_ANIM = 0.7    -- s de la animación de reaparición
local FLING_T    = 1.6    -- s volando tras romperle el bloque de debajo
local BURST_T    = 1.0    -- s "muerta" tras reventar (las partículas vuelan)
local FLING_VX, FLING_VY = 230, -760
local LAUNCH_MIN_VX = 170   -- px/s de avance mínimo al salir de un trampolín hacia arriba
-- Muertes especiales (ya muertas: sin choques, lo atraviesan todo; el dibujo
-- solo depende de state + deadTimer + x, y: igual online)
Entity.SPECIAL_DEATH = { dead_fling = true, dead_burst = true }
local KNOCK_VX   = 520    -- empujón de un ground pound cercano
local KNOCK_HOP  = 360
local KNOCK_STUN = 1.2    -- s aturdida
local DROP_SHAKE = 0.5    -- s temblando antes de caer del techo
Entity.SPAWN_ANIM = SPAWN_ANIM

-- ¿Hay un jugador justo debajo (dentro de `rangeTiles` casillas) y a la vista
-- (sin paredes en medio)? Lo usan los pinchos que caen y las entidades de techo.
function Entity:seesPlayerBelow(level, rangeTiles, halfW)
    local T = TILE_PX
    rangeTiles = rangeTiles * require('src/Difficulty').k('sense')     -- (la dificultad: más o menos vista)
    halfW = halfW or (self.outerW / 2 + 20)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and math.abs(pa.x - self.x) <= halfW then
            local dy = pa.y - self.y
            if dy > 0 and dy <= rangeTiles * T then
                local blocked = false
                local yy = self.y + self.outerH / 2 + 2
                local top = pa.y - T / 2
                while yy < top do
                    local t = level:collisionAt(self.x, yy)
                    if t and t.collision == 'solid' then blocked = true; break end
                    yy = yy + T / 2
                end
                if not blocked then return pa end
            end
        end
    end
    return nil
end

-- Vuelve a su colocación original (reaparecer)
function Entity:resetToHome()
    local h = self.home
    self.x, self.y, self.vx, self.vy = h.x, h.y, h.vx, 0
    self.facing, self.flipped = h.facing, h.flipped
    self.baseY = h.y
    self.onGround, self.alive = false, true
    self.ffx, self.ffy, self.ffArea, self.fvx, self.fvy, self.ffBlock, self.ffSeen = nil, nil, nil, nil, nil, nil, nil   -- (vuelo libre)
    self.animT, self.frame = 0, 1
    self.dropped = false
    self:init()
    self.state = h.state
end

-- Estados comunes que no son "vivo normal". Devuelve true si se ocupó del paso.
function Entity:updateCommonStates(dt, level)
    local st = self.state
    if st == 'gone' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= (self.props.respawn or 0) then
            self:resetToHome()
            self.state, self.deadTimer = 'spawning', 0
            Sound.play('respawnFx')
        end
        return true
    elseif st == 'spawning' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= SPAWN_ANIM then
            self.deadTimer = 0
            self.state = self.home.state
            if self.state == 'walk' then self:startWalk() end
        end
        return true
    elseif st == 'launched' then
        -- Lanzada por un trampolín: vuela hasta aterrizar
        self.deadTimer = self.deadTimer + dt
        local vx = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, vx * dt, self.vy * dt)
        if self.state ~= 'launched' then return true end     -- (otro trampolín la relanzó)
        if self.vx ~= vx then self.vx = -vx * 0.3 end         -- chocó con una pared: rebota un poco
        if self.deadTimer > 0.05 and self:onDeadlyGround(level) then
            self:dieBurst()                                    -- (¡en pinchos! revienta)
            return true
        end
        if self.onGround and self.deadTimer > 0.05 then
            self.launchedPrev = nil
            self.vy = 0
            self.vx = self.moving and self.speed * self.facing or 0
            self:startWalk()
        elseif self.y > level.heightPx + TILE_PX * 4 then
            self.alive = false
        end
        return true
    elseif st == 'frozen' then
        -- Congelada (congelador): dentro de un bloque de hielo, cae (salvo las que
        -- flotan: freezeFloats) y no hace nada; deadTimer = lo que le queda
        self.deadTimer = self.deadTimer - dt
        if not self.freezeFloats then
            self.vy = self.vy + ADV_GRAVITY * dt
            self:moveAndCollide(level, 0, self.vy * dt)
            if self.y > level.heightPx + TILE_PX * 4 then self.alive = false; return true end
        end
        if self.deadTimer <= 0 then self:thaw() end
        return true
    elseif st == 'stunned' then
        -- Empujada por un ground pound: sale despedida, frena y se queda
        -- aturdida un momento; luego sigue con lo que hacía
        self.deadTimer = self.deadTimer + dt
        local vx = self.vx * math.max(0, 1 - (self.onGround and 7 or 2.5) * dt)
        self.vx = vx
        local facing = self.facing
        if self.flying then
            self:moveAndCollide(level, vx * dt, 0)
            if self.moving then self:animateWalk(dt) end       -- (en el aire sigue pataleando)
        else
            local gravDir = self.flipped and -1 or 1
            self.vy = self.vy + ADV_GRAVITY * dt * gravDir
            self:moveAndCollide(level, vx * dt, self.vy * dt)
        end
        if self.vx ~= vx then self.vx = 0 end          -- chocó con una pared
        self.facing = facing
        if self.deadTimer >= KNOCK_STUN and (self.onGround or self.flying) then
            local prev = self.stunPrev
            self.deadTimer, self.vy = 0, 0
            self.vx = self.moving and self.speed * self.facing or 0
            if self.flying then          -- (sigue su oscilación desde donde quedó, sin salto)
                self.baseY = self.y - math.sin(self.flyT * self.tuning.flyBobSpeed) * (self.props.bobAmp or 0)
            end
            if prev == 'walk' or prev == 'idle' or not prev then self:startWalk() else self.state = prev end
        end
        return true
    elseif self.customDrop and st:sub(1, 5) == 'drop_' then
        return false        -- el tipo tiene su propia caída (ver Crabby)
    elseif st == 'drop_shake' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= DROP_SHAKE then
            -- Se gira y cae: a partir de aquí es una entidad de suelo
            self.state, self.deadTimer = 'drop_fall', 0
            self.flipped, self.vy, self.vx = false, 0, 0
        end
        return true
    elseif st == 'drop_fall' then
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.onGround then
            self.dropped = true
            self.vx = self.moving and self.speed * self.facing or 0
            self:startWalk()
        end
        return true
    end
    -- Entidad de techo que se deja caer al ver a un jugador debajo
    local p = self.props
    if p.dropOnSight and self.flipped and not self.dropped and self:canDropNow()
       and self:seesPlayerBelow(level, p.detectRange or 6) then
        self.dropHidden = self:isHiding()          -- (escondido: cae tal cual, sin asomarse)
        self.state, self.deadTimer, self.vx = 'drop_shake', 0, 0
        Sound.play('spikeShake')
        return true
    end
    return false
end

-- ¿Puede empezar ya la caída desde el techo? (el Crabby también escondido)
function Entity:canDropNow() return self.state == 'walk' or self.state == 'idle' end
function Entity:isHiding() return false end

-- ¿Le afecta el empujón de un ground pound cercano?
function Entity:canBeKnocked()
    if not self:isObstacle() then return false end
    local st = self.state
    if st == 'frozen' then return false end
    return st ~= 'drop_shake' and st ~= 'drop_fall' and not st:match('^drop_')
end

function Entity:knockback(dirX)
    if self.state ~= 'stunned' then self.stunPrev = self.state end
    self.state, self.deadTimer = 'stunned', 0
    self.vx = dirX * KNOCK_VX
    self.vy = self.flying and 0 or -KNOCK_HOP * (self.flipped and -1 or 1)
    self.onGround = false
    Sound.play('stunned')
end

-- Coleccionables: desaparece (con su animación de 'dead'). true si se recogió.
function Entity:collect()
    if self.state == 'dead' or self:isGhost() then return false end
    self.state, self.deadTimer, self.vx, self.vy = 'dead', 0, 0, 0
    return true
end

-- Intocable (esperando / apareciendo / en una muerte especial)
function Entity:isGhost()
    return self.state == 'gone' or self.state == 'spawning' or Entity.SPECIAL_DEATH[self.state] == true
end

-- Muere porque le rompen el bloque sobre el que está: sale despedida hacia
-- arriba y hacia fuera, girando (no la muerte de "aplastada")
function Entity:dieFling(dirX)
    if Entity.SPECIAL_DEATH[self.state] or self.state == 'dead' then return end
    if self.releaseCrawl then self:releaseCrawl() end
    dirX = (dirX and dirX ~= 0) and dirX or self.facing or 1
    self.state, self.deadTimer = 'dead_fling', 0
    self.vx, self.vy = dirX * FLING_VX, FLING_VY
    self.facing = dirX
    self.flipped, self.onGround = false, false
    Sound.play('crabPop', 1.2)
    Entity.emitFx('gp_start', self.x, self.y + self.outerH / 2)
end

-- Revienta en pedazos (cae en pinchos o algo mortal tras un trampolín)
function Entity:dieBurst()
    if Entity.SPECIAL_DEATH[self.state] or self.state == 'dead' then return end
    if self.releaseCrawl then self:releaseCrawl() end
    self.state, self.deadTimer, self.vx, self.vy = 'dead_burst', 0, 0, 0
    Sound.play('enemyExplode', 1.1)
    Sound.play('blockBreak', 0.8)
    Entity.emitFx('enemy_burst', self.x, self.y)
    Entity.emitFx('shake_small', self.x, self.y)
end

-- ¿Algo mortal donde está? (pinchos de verdad o material 'deadly')
function Entity:onDeadlyGround(level)
    local b = self:getOuterBounds()
    if #level:getSpikesInBox(b.x, b.y, b.w, b.h) > 0 then return true end
    for _, py in ipairs({ self.y, b.y + b.h - 4 }) do
        local t = level:getDefAt(self.x, py)
        if t and t.mat and t.mat.contact == 'kill' then return true end
    end
    return false
end

-- Está de pie sobre la casilla (c, r)? (pies en su cara de arriba)
function Entity:standingOnCell(c, r)
    if not self.alive or self.flying then return false end
    if Entity.SPECIAL_DEATH[self.state] or self.state == 'dead' or self.state == 'gone' then return false end
    local T = TILE_PX
    -- Trepadores (Crawler): la casilla a la que están AGARRADOS, sea suelo, pared o techo
    -- (no tienen `onGround`: por eso a los Crabbies lúgubres no les pasaba nada)
    if self.crawl and self.cattached then
        local Crawler = require 'src/world/entities/Crawler'
        local fx, fy = Crawler.feet(self)
        local px, py = fx - self.cnx * 6, fy - self.cny * 6            -- (un poco dentro del bloque)
        if math.floor(px / T) + 1 == c and math.floor(py / T) + 1 == r then return true end
        -- (en el suelo: también los bloques bajo los extremos de su caja, como los que caminan)
        if self.cny == -1 then
            local b = self:getOuterBounds()
            return r == math.floor(py / T) + 1 and b.x < c * T and b.x + b.w > (c - 1) * T
        end
        return false
    end
    if not self.onGround then return false end
    local b = self:getOuterBounds()
    local x0, x1 = (c - 1) * T, c * T
    local top = (r - 1) * T
    return b.x < x1 and b.x + b.w > x0 and math.abs(b.y + b.h - top) <= 6
end

-- ── Hooks por defecto ─────────────────────────────────────────────────────────
function Entity.loadAssets() end
function Entity:init() end
function Entity:updateCustom(dt, level) return false end
function Entity:onWalk(dt) end
function Entity:onIdle(dt) end
function Entity:onIdleEnd() return false end
function Entity:onDead(dt) end
function Entity:onStomp() end
function Entity:canBeStomped() return true end
function Entity:isBodyDisabled() return false end
function Entity:getHazardBoxes() return nil end
function Entity:netPack() return nil end
function Entity:netApply(a, b, f) end
-- Red: una entidad "en reposo" (quieta en su estado de siempre, p. ej. un
-- pincho colgando) no se envía en los snapshots; el cliente la devuelve a ese
-- estado con netRest(). Ahorra muchísimo con cientos de pinchos.
-- Por defecto solo las de RESERVA (ver makeReserve) mientras no están en juego.
function Entity:netAtRest() return self.summonOf ~= nil and (self.state == 'reserve' or not self.alive) end
function Entity:netRest()
    if self.summonOf then self.alive, self.state = false, 'reserve' end
end

-- ── Súbdito de RESERVA (cualquier entidad puede serlo) ──────────────────────
-- El tipo de un jefe declara `summons(placement)` → Level.fromData añade esas colocaciones de
-- reserva detrás de las del JSON (mismos índices en servidor y clientes) y Entities.create llama
-- aquí: fuera de juego (no viva, estado 'reserve', no se envía por red) hasta que su jefe la
-- active (resetToHome + estado). Sin ruta: se mueve libre por la zona del jefe. Gancho opcional
-- `onMakeReserve(key)` para lo propio de cada tipo.
function Entity:makeReserve(key)
    self.summonOf = key
    self.alive, self.state = false, 'reserve'
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge
    if self.onMakeReserve then self:onMakeReserve(key) end
end

-- ── Hitboxes ──────────────────────────────────────────────────────────────────
function Entity:getOuterBounds()
    return { x = self.x - self.outerW / 2, y = self.y - self.outerH / 2,
             w = self.outerW, h = self.outerH }
end

function Entity:getInnerBounds()
    return { x = self.x - self.innerW / 2, y = self.y - self.innerH / 2,
             w = self.innerW, h = self.innerH }
end

-- ── Movimiento ────────────────────────────────────────────────────────────────
local function solidAt(level, wx, wy)
    return level:isEnemySolidAt(wx, wy)   -- según el catálogo de tiles (enemySolid)
end

-- Tile sólido en el punto (con su forma real: las losas no son bloques enteros)
local function solidDefAt(level, wx, wy)
    return level:enemySolidDefAt(wx, wy)
end

-- Caras de la hitbox real del tile que hay en el punto (px de mundo)
local function faceLeft(t, px)   return math.floor(px / TILE_PX) * TILE_PX + t.hitbox.x * TILE_PX end
local function faceRight(t, px)
    if t.fullHitbox then return math.ceil(px / TILE_PX) * TILE_PX end
    return math.floor(px / TILE_PX) * TILE_PX + (t.hitbox.x + t.hitbox.w) * TILE_PX
end
local function faceTop(t, py)    return math.floor(py / TILE_PX) * TILE_PX + t.hitbox.y * TILE_PX end
local function faceBottom(t, py)
    if t.fullHitbox then return math.ceil(py / TILE_PX) * TILE_PX end
    return math.floor(py / TILE_PX) * TILE_PX + (t.hitbox.y + t.hitbox.h) * TILE_PX
end

-- ¿Cuenta como obstáculo para las que caminan? (no los coleccionables ni lo
-- que está esperando/apareciendo o muriendo)
function Entity:isObstacle()
    local d = self.def or {}
    if d.pickup or d.checkpoint then return false end
    return self.alive and self.state ~= 'dead' and not self:isGhost()
end

-- ¿Hay algo "sólido" justo delante (pinchos u otra entidad)? Las paredes ya
-- las resuelve moveAndCollide.
function Entity:blockedAhead(level, dir)
    local hw, hh, probe = self.outerW / 2, self.outerH / 2, 4
    local bx = dir > 0 and (self.x + hw) or (self.x - hw - probe)
    local by, bh = self.y - hh + 2, self.outerH - 4
    if level.hasSpikeCellInBox and level:hasSpikeCellInBox(bx, by, probe, bh) then return true end
    for _, o in ipairs(level.liveEntities or {}) do
        if o ~= self and not o.solidFull and (o.x - self.x) * dir > 0 and o:isObstacle() then   -- (los sólidos los choca moveAndCollide)
            local ob = o:getOuterBounds()
            if bx < ob.x + ob.w and bx + probe > ob.x and by < ob.y + ob.h and by + bh > ob.y then
                return true
            end
        end
    end
    return false
end

-- ¿Puede avanzar hacia `dir`? (no está pegado al límite de su ruta ni a
-- una pared en ese lado)
function Entity:canGo(level, dir)
    local hw = self.outerW / 2
    if dir > 0 and self.x + hw >= self.rightBoundPx - 1 then return false end
    if dir < 0 and self.x - hw <= self.leftBoundPx + 1 then return false end
    local ex = self.x + dir * (hw + 2)
    for _, py in ipairs({ self.y - self.outerH / 2 + 4, self.y, self.y + self.outerH / 2 - 4 }) do
        if level:entitySolidAt(ex, py, self) then return false end
    end
    return true
end

-- Da la vuelta si tiene un obstáculo delante. Un volador:
--  · encajonado (algo delante y, detrás, otra entidad, el límite de su ruta
--    o una pared) no se gira: sigue y atraviesa la entidad;
--  · tras girarse por una entidad, no vuelve a hacerlo en FLY_TURN_CD s (si
--    no, en el límite de su ruta con otra delante iba y venía 1-2 px).
-- Así nunca convulsiona ni se queda clavado girándose cada fotograma.
local FLY_TURN_CD = 0.8
function Entity:turnAtObstacles(level)
    if not self.moving or self.vx == 0 then return end
    local dir = self.vx > 0 and 1 or -1
    if self.flying and self.flyTurnAt and self.flyT - self.flyTurnAt < FLY_TURN_CD then return end
    if self:blockedAhead(level, dir) then
        if self.flying then
            if self:blockedAhead(level, -dir) or not self:canGo(level, -dir) then return end
            self.flyTurnAt = self.flyT
        end
        self.vx, self.facing = -self.vx, -dir
    end
end

-- Colisión con el nivel. Si está pegado al techo (flipped) la "gravedad" va
-- hacia arriba: se apoya al chocar por arriba. Se ajusta a las caras de la
-- hitbox REAL de cada tile (una losa no es un bloque entero: colgada debajo
-- de una plataforma queda pegada a ella, no flotando).
local MAX_STEP = 16      -- px por sub-paso vertical (no atravesar losas finas)
local EMBED = 6         -- px: un volador más metido que esto en una cara la atraviesa (sale)

-- Cara que se toca en el punto: tile (forma real) u objeto sólido (trampolín,
-- mortero...). `side` = cara del obstáculo que se toca ('left' al ir hacia la
-- derecha, 'top' al caer...). Devuelve la coordenada de la cara y el objeto.
local function probe(level, self, px, py, side)
    local t = solidDefAt(level, px, py)
    if t then
        if side == 'left'  then return faceLeft(t, px) end
        if side == 'right' then return faceRight(t, px) end
        if side == 'top'   then return faceTop(t, py) end
        return faceBottom(t, py)
    end
    local o, b = level:bodyAt(px, py, self)
    if o then
        if side == 'left'  then return b.x, o end
        if side == 'right' then return b.x + b.w, o end
        if side == 'top'   then return b.y, o end
        return b.y + b.h, o
    end
    return nil
end

function Entity:moveAndCollide(level, dx, dy)
    local hw = self.outerW / 2
    local hh = self.outerH / 2
    local x, y = self.x, self.y
    local free = self.state == 'launched'      -- lanzada: sin límites de ruta
    local touched, touchedFace                 -- objeto sólido que tocó (trampolín)

    x = x + dx
    local rows = level.samples and level:samples(y - hh + 4, y + hh - 4) or { y - hh + 4, y, y + hh - 4 }
    if dx ~= 0 then
        local side = (dx > 0) and 'left' or 'right'
        local edge = (dx > 0) and (x + hw) or (x - hw)
        local hit, body
        for _, py in ipairs(rows) do
            local f, o = probe(level, self, edge, py, side)
            -- Volador: una cara que ya quedaba bien por detrás de su borde
            -- (estaba metido en ella, p. ej. un bloque de jefe que apareció
            -- encima) no lo frena: así sale en vez de quedarse atascado dando
            -- vueltas. (Más de EMBED px: el roce de las esquinas sí choca.)
            if f and self.flying and ((dx > 0 and f < self.x + hw - EMBED) or (dx < 0 and f > self.x - hw + EMBED)) then f = nil end
            if f and (not hit or (dx > 0 and f < hit) or (dx < 0 and f > hit)) then hit, body = f, o end
        end
        if hit then
            x = (dx > 0) and (hit - hw) or (hit + hw)
            if body then touched, touchedFace = body, side end
            local d = (dx > 0) and -1 or 1
            self.vx = d * self.speed;  self.facing = d
        -- Límite de la ruta: no pasa de él, pero si ya estaba fuera (un
        -- trepador que salió de ella, un empujón...) no lo devuelve de golpe:
        -- solo no se aleja más (antes saltaba al borde en un paso = "teletransporte")
        elseif not free and dx > 0 and x + hw >= self.rightBoundPx then
            x = math.max(math.min(self.x, x), self.rightBoundPx - hw)
            self.vx = -self.speed;  self.facing = -1
        elseif not free and dx < 0 and x - hw <= self.leftBoundPx then
            x = math.min(math.max(self.x, x), self.leftBoundPx + hw)
            self.vx =  self.speed;  self.facing = 1
        end
    end

    self.onGround = false
    local chx = level.samples and level:samples(x - hw + 4, x + hw - 4) or { x - hw + 4, x, x + hw - 4 }
    local landDown = not self.flipped
    -- En sub-pasos: una caída rápida no se salta una losa fina
    local left = dy
    while left ~= 0 do
        local step = (left > 0) and math.min(left, MAX_STEP) or math.max(left, -MAX_STEP)
        left = left - step
        y = y + step
        local side = (step > 0) and 'top' or 'bottom'
        local edge = (step > 0) and (y + hh) or (y - hh)
        local hit, body
        for _, px in ipairs(chx) do
            local f, o = probe(level, self, px, edge, side)
            if f and self.flying and ((step > 0 and f < y - step + hh - EMBED) or (step < 0 and f > y - step - hh + EMBED)) then f = nil end
            if f and (not hit or (step > 0 and f < hit) or (step < 0 and f > hit)) then hit, body = f, o end
        end
        if hit then
            y = (step > 0) and (hit - hh) or (hit + hh)
            self.vy = 0
            if (step > 0) == landDown then self.onGround = true end
            if body then touched, touchedFace = body, side end
            break
        end
    end

    self.x, self.y = x, y
    -- Trampolín: si tocó su cara buena, sale lanzada
    if touched then self:touchBody(touched, touchedFace) end
end

-- ── Trampolines ───────────────────────────────────────────────────────────────
-- Tocar la cara que lanza de un objeto (o.bouncyFace, o.face) la lanza con la
-- misma velocidad que a un jugador. Los voladores no (rebotan como en una pared).
function Entity:canBeLaunched()
    return not self.flying and self.alive and self.state ~= 'dead' and self.state ~= 'frozen' and not self:isGhost()
end

function Entity:touchBody(o, face)
    if not (o.bouncyFace and o.face == face and o.launchVelocity) then return false end
    if o.canLaunchEntity and not o:canLaunchEntity() then return false end
    if not self:canBeLaunched() then return false end
    local vx, vy = o:launchVelocity()
    -- Hacia arriba (sin impulso de lado): sigue avanzando hacia donde andaba,
    -- no rebota en el sitio para siempre (volvía a caer en el mismo trampolín)
    if vx == 0 and self.moving then vx = (self.facing or 1) * math.max(self.speed or 0, LAUNCH_MIN_VX) end
    if o.onLaunch then o:onLaunch(nil) end
    self:launch(vx, vy)
    -- Sale desde ENCIMA de la cara de arriba: un trepador llega a ella girando
    -- por la esquina, medio metido en la caja del trampolín, y su primer paso
    -- de lado chocaba con él y lo devolvía hacia atrás (rebotaba en el sitio)
    if face == 'top' and o.getOuterBounds then
        local bb = o:getOuterBounds()
        self.y = math.min(self.y, bb.y - self.outerH / 2 - 1)
    end
    return true
end

-- Sale despedida (trampolín): vuela con gravedad normal hasta aterrizar y
-- sigue andando (ya fuera de su ruta). Del techo o de una pared cae al suelo.
function Entity:launch(vx, vy)
    if self.releaseCrawl then self:releaseCrawl() end
    if self.launchedPrev == nil and self.state ~= 'launched' then self.launchedPrev = self.state end
    self.state, self.deadTimer = 'launched', 0
    self.flipped, self.onGround = false, false
    self.vx, self.vy = vx, vy
    if vx ~= 0 then self.facing = vx > 0 and 1 or -1 end
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge
end

-- Gravedad (hacia el techo si está boca abajo) sin desplazamiento horizontal.
-- Los voladores no caen.
function Entity:fall(level, dt)
    if self.flying then return end
    local gravDir = self.flipped and -1 or 1
    self.vy = self.vy + ADV_GRAVITY * dt * gravDir
    self:moveAndCollide(level, 0, self.vy * dt)
end

function Entity:startIdle()
    local tn = self.tuning
    self.state        = 'idle'
    self.idleTimer    = 0
    self.idleDuration = randRange(tn.idleFor[1], tn.idleFor[2])
    self.breatheT     = 0
end

function Entity:startWalk()
    local tn = self.tuning
    self.state         = 'walk'
    self.idleCountdown = randRange(tn.idleEvery[1], tn.idleEvery[2])
    self.idleTimer     = 0
    self.breatheT      = 0
end

-- ── Update ────────────────────────────────────────────────────────────────────
-- Fin de una muerte: reaparecerá (respawn) o desaparece
function Entity:finishDeath()
    if (self.props.respawn or 0) > 0 then
        self.state, self.deadTimer = 'gone', 0     -- reaparecerá
    else
        self.alive = false
    end
end

function Entity:update(dt, level)
    local tn = self.tuning

    if self.state == 'dead' then
        self:onDead(dt)
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= tn.deadDuration then self:finishDeath() end
        return
    elseif self.state == 'dead_fling' then
        -- Despedida girando (le rompieron el bloque de debajo): vuela sin chocar
        self.deadTimer = self.deadTimer + dt
        self.vy = self.vy + ADV_GRAVITY * dt
        self.x, self.y = self.x + self.vx * dt, self.y + self.vy * dt
        if self.deadTimer >= FLING_T then self:finishDeath() end
        return
    elseif self.state == 'dead_burst' then
        -- Reventada en pedazos (partículas): el cuerpo ya no está
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= BURST_T then self:finishDeath() end
        return
    end

    if self:updateCommonStates(dt, level) then return end
    if self:updateCustom(dt, level) then return end

    if self.state == 'idle' then
        self:onIdle(dt)
        self.idleTimer = self.idleTimer + dt
        self.breatheT  = self.breatheT  + dt
        self:fall(level, dt)
        if self.boxedIn then
            -- Encerrado: sigue en reposo (animación de idle) mientras no tenga sitio;
            -- en cuanto lo tiene, echa a andar
            if self.onGround and self:isBoxedIn(level) then
                self.idleTimer = 0
            else
                self.boxedIn = nil
                self:startWalk()
            end
            return
        end
        if self.idleTimer >= self.idleDuration then
            if not self:onIdleEnd() then self:startWalk() end
        end
        return
    end

    -- ── Walk / vuelo ─────────────────────────────────────────────────────────
    self:onWalk(dt)

    -- Pausas (idle): solo apoyado en el suelo o quieto. Un volador nunca: en el
    -- aire sigue moviendo las patitas (animación de andar) aunque esté parado
    if self.props.pauses and not self.flying then
        self.idleCountdown = self.idleCountdown - dt
        if self.idleCountdown <= 0 and (self.onGround or not self.moving) then
            self:startIdle()
            return
        end
    end

    if self.flying and self.freeFly then
        -- Vuelo libre: recorre toda su zona sin quedarse atrapado (FreeFlight.lua)
        self.flyT = self.flyT + dt
        FreeFlight = FreeFlight or require 'src/world/entities/FreeFlight'
        FreeFlight.update(self, dt, level)
    elseif self.flying then
        -- Vuela: patrulla horizontal sin gravedad con oscilación vertical. La
        -- oscilación también choca (no se mete en el suelo, techo, losas ni
        -- objetos sólidos): se queda en la cara y la sigue cuando se aparta.
        self.flyT = self.flyT + dt
        self:turnAtObstacles(level)
        self:moveAndCollide(level, self.vx * dt, 0)
        local ty = self.baseY + math.sin(self.flyT * tn.flyBobSpeed) * (self.props.bobAmp or 0)
        if ty ~= self.y then self:moveAndCollide(level, 0, ty - self.y) end
    else
        -- Encerrado (no puede andar hacia ningún lado: bloques, límites de su
        -- ruta, bordes, pinchos u otra entidad a los dos lados): se queda
        -- quieto EN REPOSO (idle) en vez de girarse cada fotograma o quedarse
        -- con un cuadro de andar; vuelve a andar en cuanto tenga sitio
        local gravDir = self.flipped and -1 or 1
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        if self.moving and self.onGround and self:isBoxedIn(level) then
            -- (no intenta andar: pasa al reposo y se queda en él hasta tener sitio;
            -- el estado 'idle' viaja en las instantáneas, así online se ve igual)
            self.boxedIn = true
            self:moveAndCollide(level, 0, self.vy * dt)
            self:startIdle()
            return
        end
        self.boxedIn = nil
        -- Detección de borde: si no hay suelo (o techo) al frente → dar la vuelta
        if self.moving and self.onGround and self.props.turnAtEdges and not self:groundAhead(level, self.vx > 0 and 1 or -1) then
            self.vx = -self.vx;  self.facing = -self.facing
        end
        self:turnAtObstacles(level)
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
    end

    if self.moving then self:animateWalk(dt) end
end

-- ¿Hay suelo (o techo, boca abajo) justo delante, hacia `dir`? Se mira 4 px
-- pasada la superficie: media casilla más abajo se saldría de una losa fina y
-- creería estar siempre en un borde
function Entity:groundAhead(level, dir)
    local lookX = self.x + dir * (self.outerW / 2 + 2)
    local lookY = self.flipped and (self.y - self.outerH / 2 - 4) or (self.y + self.outerH / 2 + 4)
    return solidAt(level, lookX, lookY)
end

-- Sitio libre hacia `dir` (px, hasta `max`): hasta una pared u objeto sólido,
-- el límite de su ruta o, si gira en los bordes, un borde
function Entity:freeRoom(level, dir, max)
    local hw, d = self.outerW / 2, 0
    local rows = { self.y - self.outerH / 2 + 4, self.y, self.y + self.outerH / 2 - 4 }
    local lookY = self.flipped and (self.y - self.outerH / 2 - 4) or (self.y + self.outerH / 2 + 4)
    while d < max do
        local ex = self.x + dir * (hw + d + 2)
        if dir > 0 and ex >= self.rightBoundPx or dir < 0 and ex <= self.leftBoundPx then break end
        local hit = false
        for _, py in ipairs(rows) do if level:entitySolidAt(ex, py, self) then hit = true; break end end
        if hit or (self.props.turnAtEdges and not solidAt(level, ex, lookY)) then break end
        d = d + 4
    end
    return d
end

local MIN_ROOM = TILE_PX / 2     -- px de juego (a los dos lados juntos) para echar a andar

-- ¿Encerrado? No puede andar hacia ningún lado, o el hueco que le queda es tan
-- pequeño que solo iría y vendría chocando (p. ej. un Gummy entre dos bloques
-- con una casilla de hueco)
function Entity:isBoxedIn(level)
    local dir = self.vx >= 0 and 1 or -1
    local ahead = self:freeRoom(level, dir, MIN_ROOM)
    if ahead >= MIN_ROOM and self:canWalk(level, dir) then return false end      -- (lo normal: rápido)
    if not self:canWalk(level, 1) and not self:canWalk(level, -1) then return true end
    return ahead + self:freeRoom(level, -dir, MIN_ROOM) < MIN_ROOM
end

-- ¿Puede echar a andar hacia `dir`? (sitio libre, dentro de su ruta, sin
-- pinchos ni entidades delante y, si gira en los bordes, con suelo delante)
function Entity:canWalk(level, dir)
    if not self:canGo(level, dir) or self:blockedAhead(level, dir) then return false end
    if self.props.turnAtEdges and not self:groundAhead(level, dir) then return false end
    return true
end

-- Avanza la animación de andar (patitas)
function Entity:animateWalk(dt)
    local tn = self.tuning
    self.animT = self.animT + dt
    if self.animT >= 1 / tn.walkFps then
        self.animT = self.animT - 1 / tn.walkFps
        self.frame = (self.frame % tn.walkFrames) + 1
    end
end

-- ── Congelada (congelador: types/cryo.lua) ────────────────────────────────────
-- Solo los enemigos normales (los jefes deciden en Boss; objetos, trampas... no)
function Entity:canFreeze()
    local st = self.state
    if not self.alive or st == 'dead' or st == 'gone' or st == 'spawning' or st == 'reserve'
       or st == 'frozen' or Entity.SPECIAL_DEATH[st] then return false end
    return (self.def and self.def.category) == 'Enemigos'
end

-- Encerrada en hielo `t` s: deja lo que hacía (lo retoma al descongelarse, con
-- su temporizador), no hace daño, cae; un pisotón rompe el hielo (shatter)
function Entity:freeze(t)
    if not self:canFreeze() then return false end
    if self.releaseCrawl then self:releaseCrawl() end
    self.frozenPrev, self.frozenPrevT = self.state, self.deadTimer
    self.frozenFlying = self.flying
    self.state, self.deadTimer = 'frozen', t
    self.vx, self.vy = 0, 0
    self.onGround = false
    if not self.freezeFloats then
        self.flying = false                       -- (el bloque de hielo cae)
        if self.flipped then self.flipped, self.dropped = false, true end    -- (del techo: cae al suelo)
    end
    Sound.play('cryoFreeze')
    Entity.emitFx('ice_freeze', self.x, self.y)
    return true
end

-- Se rompe el hielo y sigue con lo que hacía
function Entity:thaw()
    if self.state ~= 'frozen' then return end
    local prev = self.frozenPrev
    self.flying = self.frozenFlying
    self.vy = 0
    self.vx = self.moving and self.speed * self.facing or 0
    if self.flying then           -- (sigue su oscilación desde donde quedó)
        self.baseY = self.y - math.sin(self.flyT * self.tuning.flyBobSpeed) * (self.props.bobAmp or 0)
    end
    if not prev or prev == 'walk' or prev == 'idle' or prev == 'stunned' or prev == 'launched' or prev:match('^drop_') then
        self.deadTimer = 0
        self:startWalk()
    else
        self.state, self.deadTimer = prev, self.frozenPrevT or 0
    end
    Sound.play('cryoFree')
    Entity.emitFx('ice_shatter', self.x, self.y)
end

-- Le rompen el bloque de hielo (pisotón, ground pound): muere si se le puede
-- pisotear; si no (pez globo...), solo se descongela
function Entity:shatter()
    if self.state ~= 'frozen' then return end
    if self.props.stompable then
        self.flying = self.frozenFlying
        self.state, self.deadTimer = 'dead', 0
        self.vx, self.vy = 0, 0
        Sound.play('cryoFree')
        Sound.play('enemyExplode')
        Entity.emitFx('ice_shatter', self.x, self.y)
    else
        self:thaw()
    end
end

-- ── Pisotón ───────────────────────────────────────────────────────────────────
function Entity:stomp()
    if self.state == 'dead' then return end
    if self.state == 'frozen' then return self:shatter() end
    if not self:canBeStomped() then return end
    self.state     = 'dead'
    self.deadTimer = 0
    self.vx        = 0
    self.vy        = 0
    self:onStomp()
    Sound.play('enemyExplode')
    require('src/world/Noise').emit(self.x, self.y, require('src/world/Noise').R.kill)   -- (un enemigo que muere se oye)
end

-- Escala de "respiración" durante las pausas: sx, sy multiplicadores.
function Entity:breatheScale()
    if self.state ~= 'idle' then return 1, 1 end
    local tn = self.tuning
    local b  = math.sin(self.breatheT * tn.breatheSpeed * math.pi)
    return 1.0 - b * tn.breatheAmp * 0.4, 1.0 + b * tn.breatheAmp
end

-- ── Debug (F1) ────────────────────────────────────────────────────────────────
function Entity:renderDebug(camX, camY)
    local c = self.tuning.debugColor
    local ob = self:getOuterBounds()
    if self:isBodyDisabled() then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.25)
        love.graphics.rectangle('line', ob.x - camX, ob.y - camY, ob.w, ob.h)
    else
        love.graphics.setColor(c[1], c[2], c[3], 0.55)
        love.graphics.rectangle('line', ob.x - camX, ob.y - camY, ob.w, ob.h)
        local ib = self:getInnerBounds()
        love.graphics.setColor(c[1] * 0.8, c[2] * 0.3, c[3], 0.55)
        love.graphics.rectangle('line', ib.x - camX, ib.y - camY, ib.w, ib.h)
    end
    for _, hb in ipairs(self:getHazardBoxes() or {}) do
        love.graphics.setColor(1, 0.3, 0.3, 0.6)
        love.graphics.rectangle('line', hb.x - camX, hb.y - camY, hb.w, hb.h)
    end
    -- ZONAS PROPIAS del tipo (`debugBoxes()`): todo lo que golpea o se puede golpear y NO es su caja ni una zona de
    -- peligro corriente (pinzas, ondas, trozos, el cuerpo que copia el Espejo, el radio de una bomba…).
    --   { x, y, w, h, kind }  o  { cx, cy, r, kind }   kind: 'hurt' rojo · 'weak' amarillo (ahí se le pega) · 'area' blanco
    if self.debugBoxes then
        for _, b in ipairs(self:debugBoxes() or {}) do
            if b.kind == 'weak' then love.graphics.setColor(1, 0.9, 0.2, 0.8)
            elseif b.kind == 'area' then love.graphics.setColor(1, 1, 1, 0.5)
            else love.graphics.setColor(1, 0.3, 0.3, 0.7) end
            if b.r then love.graphics.circle('line', b.cx - camX, b.cy - camY, b.r)
            else love.graphics.rectangle('line', b.x - camX, b.y - camY, b.w, b.h) end
        end
    end
    if self.leftBoundPx > -math.huge then
        love.graphics.setColor(0.2, 1, 1, 0.22)
        love.graphics.line(self.leftBoundPx  - camX, 0, self.leftBoundPx  - camX, WINDOW_H)
        love.graphics.line(self.rightBoundPx - camX, 0, self.rightBoundPx - camX, WINDOW_H)
    end
end

return Entity
