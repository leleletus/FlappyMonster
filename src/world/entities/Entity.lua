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

    local img = cls.sizeImage()
    local sc  = GUMMY_SCALE
    local iw, ih = img:getWidth() * sc, img:getHeight() * sc
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
    return e
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
        if self.deadTimer >= tn.deadDuration then self.alive = false end
        return
    end

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
