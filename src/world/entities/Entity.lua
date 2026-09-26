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
        iw, ih = img:getWidth() * GUMMY_SCALE, img:getHeight() * GUMMY_SCALE
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
local KNOCK_VX   = 520    -- empujón de un ground pound cercano
local KNOCK_HOP  = 360
local KNOCK_STUN = 1.2    -- s aturdida
local DROP_SHAKE = 0.5    -- s temblando antes de caer del techo
Entity.SPAWN_ANIM = SPAWN_ANIM

-- ¿Hay un jugador justo debajo (dentro de `rangeTiles` casillas) y a la vista
-- (sin paredes en medio)? Lo usan los pinchos que caen y las entidades de techo.
function Entity:seesPlayerBelow(level, rangeTiles, halfW)
    local T = TILE_PX
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
    elseif st == 'stunned' then
        -- Empujada por un ground pound: sale despedida, frena y se queda
        -- aturdida un momento; luego sigue con lo que hacía
        self.deadTimer = self.deadTimer + dt
        local vx = self.vx * math.max(0, 1 - (self.onGround and 7 or 2.5) * dt)
        self.vx = vx
        local facing = self.facing
        if self.flying then
            self:moveAndCollide(level, vx * dt, 0)
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
            if self.flying then self.baseY = self.y end
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
    if p.dropOnSight and self.flipped and not self.dropped and (st == 'walk' or st == 'idle')
       and self:seesPlayerBelow(level, p.detectRange or 6) then
        self.state, self.deadTimer, self.vx = 'drop_shake', 0, 0
        Sound.play('spikeShake')
        return true
    end
    return false
end

-- ¿Le afecta el empujón de un ground pound cercano?
function Entity:canBeKnocked()
    if not self:isObstacle() then return false end
    local st = self.state
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

-- Intocable (esperando / apareciendo)
function Entity:isGhost()
    return self.state == 'gone' or self.state == 'spawning'
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
        if o ~= self and (o.x - self.x) * dir > 0 and o:isObstacle() then
            local ob = o:getOuterBounds()
            if bx < ob.x + ob.w and bx + probe > ob.x and by < ob.y + ob.h and by + bh > ob.y then
                return true
            end
        end
    end
    return false
end

-- Da la vuelta si tiene un obstáculo delante
function Entity:turnAtObstacles(level)
    if not self.moving or self.vx == 0 then return end
    local dir = self.vx > 0 and 1 or -1
    if self:blockedAhead(level, dir) then
        self.vx, self.facing = -self.vx, -dir
    end
end

-- Colisión con el nivel. Si está pegado al techo (flipped) la "gravedad" va
-- hacia arriba: se apoya al chocar por arriba.
function Entity:moveAndCollide(level, dx, dy)
    local T  = TILE_PX
    local hw = self.outerW / 2
    local hh = self.outerH / 2
    local x, y = self.x, self.y

    x = x + dx
    if dx > 0 then
        if solidAt(level, x + hw, y - hh + 4) or solidAt(level, x + hw, y + hh - 4) then
            x = math.floor((x + hw) / T) * T - hw
            self.vx = -self.speed;  self.facing = -1
        elseif x + hw >= self.rightBoundPx then
            x = self.rightBoundPx - hw
            self.vx = -self.speed;  self.facing = -1
        end
    elseif dx < 0 then
        if solidAt(level, x - hw, y - hh + 4) or solidAt(level, x - hw, y + hh - 4) then
            x = math.ceil((x - hw) / T) * T + hw
            self.vx =  self.speed;  self.facing = 1
        elseif x - hw <= self.leftBoundPx then
            x = self.leftBoundPx + hw
            self.vx =  self.speed;  self.facing = 1
        end
    end

    y = y + dy
    self.onGround = false
    local chx = { x - hw + 4, x, x + hw - 4 }
    local landDown = not self.flipped
    if dy > 0 then
        for _, px in ipairs(chx) do
            if solidAt(level, px, y + hh) then
                y = math.floor((y + hh) / T) * T - hh
                self.vy = 0;  if landDown then self.onGround = true end;  break
            end
        end
    elseif dy < 0 then
        for _, px in ipairs(chx) do
            if solidAt(level, px, y - hh) then
                y = math.ceil((y - hh) / T) * T + hh
                self.vy = 0;  if not landDown then self.onGround = true end;  break
            end
        end
    end

    self.x, self.y = x, y
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
function Entity:update(dt, level)
    local tn = self.tuning

    if self.state == 'dead' then
        self:onDead(dt)
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= tn.deadDuration then
            if (self.props.respawn or 0) > 0 then
                self.state, self.deadTimer = 'gone', 0     -- reaparecerá
            else
                self.alive = false
            end
        end
        return
    end

    if self:updateCommonStates(dt, level) then return end
    if self:updateCustom(dt, level) then return end

    if self.state == 'idle' then
        self:onIdle(dt)
        self.idleTimer = self.idleTimer + dt
        self.breatheT  = self.breatheT  + dt
        self:fall(level, dt)
        if self.idleTimer >= self.idleDuration then
            if not self:onIdleEnd() then self:startWalk() end
        end
        return
    end

    -- ── Walk / vuelo ─────────────────────────────────────────────────────────
    self:onWalk(dt)

    if self.props.pauses then
        self.idleCountdown = self.idleCountdown - dt
        if self.idleCountdown <= 0 and (self.onGround or self.flying or not self.moving) then
            self:startIdle()
            return
        end
    end

    if self.flying then
        -- Vuela: patrulla horizontal sin gravedad con oscilación vertical
        self.flyT = self.flyT + dt
        self:turnAtObstacles(level)
        self:moveAndCollide(level, self.vx * dt, 0)
        self.y = self.baseY + math.sin(self.flyT * tn.flyBobSpeed) * (self.props.bobAmp or 0)
    else
        -- Detección de borde: si no hay suelo (o techo) al frente → dar la vuelta
        if self.moving and self.onGround and self.props.turnAtEdges then
            local hw    = self.outerW / 2
            local lookX = self.x + (self.vx > 0 and (hw + 2) or -(hw + 2))
            local lookY = self.flipped and (self.y - self.outerH / 2 - TILE_PX / 2)
                                        or (self.y + self.outerH / 2 + TILE_PX / 2)
            if not solidAt(level, lookX, lookY) then
                self.vx = -self.vx;  self.facing = -self.facing
            end
        end
        self:turnAtObstacles(level)
        local gravDir = self.flipped and -1 or 1
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
    end

    if self.moving then
        self.animT = self.animT + dt
        if self.animT >= 1 / tn.walkFps then
            self.animT = self.animT - 1 / tn.walkFps
            self.frame = (self.frame % tn.walkFrames) + 1
        end
    end
end

-- ── Pisotón ───────────────────────────────────────────────────────────────────
function Entity:stomp()
    if self.state == 'dead' then return end
    if not self:canBeStomped() then return end
    self.state     = 'dead'
    self.deadTimer = 0
    self.vx        = 0
    self.vy        = 0
    self:onStomp()
    Sound.play('enemyExplode')
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
    if self.leftBoundPx > -math.huge then
        love.graphics.setColor(0.2, 1, 1, 0.22)
        love.graphics.line(self.leftBoundPx  - camX, 0, self.leftBoundPx  - camX, WINDOW_H)
        love.graphics.line(self.rightBoundPx - camX, 0, self.rightBoundPx - camX, WINDOW_H)
    end
end

return Entity
