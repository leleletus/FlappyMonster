-- src/entities/Gummy.lua
local Class = require 'libs/class'
local Gummy = Class:new()

local imgIdle, imgWalk1, imgWalk2, imgDead = nil, nil, nil, nil

local function loadSprites()
    if imgIdle then return end
    imgIdle  = love.graphics.newImage('assets/images/gummy/gummy.png')
    imgWalk1 = love.graphics.newImage('assets/images/gummy/gummy1.png')
    imgWalk2 = love.graphics.newImage('assets/images/gummy/gummy2.png')
    imgDead  = love.graphics.newImage('assets/images/gummy/dead.png')
end

local WALK_FPS      = 7
local GUMMY_SPEED   = 55      -- px/s
local DEAD_DURATION = 1.4     -- segundos antes de desaparecer

-- Pausa/respiración
local IDLE_INTERVAL_MIN = 3.0  -- segundos mínimos entre pausas
local IDLE_INTERVAL_MAX = 7.0  -- segundos máximos entre pausas
local IDLE_DURATION_MIN = 1.0  -- duración mínima de la pausa
local IDLE_DURATION_MAX = 2.2  -- duración máxima de la pausa
local BREATHE_SPEED     = 3.2  -- frecuencia de la animación de respiración
local BREATHE_AMP       = 0.06 -- amplitud máxima de escala (±6 %)

-- Fracciones de hitbox sobre el sprite escalado
local OUTER_W_FRAC = 0.72
local OUTER_H_FRAC = 0.80
local INNER_W_FRAC = 0.44
local INNER_H_FRAC = 0.50

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function solidAt(level, wx, wy)
    local id = level:getTileAt(wx, wy)
    return id == TILE_SOLID or id == TILE_BORDER or id == TILE_PLATFORM
end

local function randRange(a, b)
    return a + math.random() * (b - a)
end

-- ── Constructor ───────────────────────────────────────────────────────────────
function Gummy:new(data)
    loadSprites()
    local o = setmetatable({}, self)
    self.__index = self

    o.x  = (data.col - 1) * TILE_PX + TILE_PX / 2
    o.y  = (data.row - 1) * TILE_PX + TILE_PX / 2
    o.vx = GUMMY_SPEED
    o.vy = 0

    o.leftBoundPx  = (data.leftBound  - 1) * TILE_PX
    o.rightBoundPx =  data.rightBound      * TILE_PX

    local iw = imgIdle:getWidth()  * GUMMY_SCALE
    local ih = imgIdle:getHeight() * GUMMY_SCALE
    o.sprW   = iw
    o.sprH   = ih
    o.outerW = iw * OUTER_W_FRAC
    o.outerH = ih * OUTER_H_FRAC
    o.innerW = iw * INNER_W_FRAC
    o.innerH = ih * INNER_H_FRAC

    o.onGround  = false
    o.facing    = 1
    o.state     = 'walk'   -- 'walk' | 'idle' | 'dead'
    o.deadTimer = 0
    o.alive     = true

    o.animT = 0
    o.frame = 1

    -- Temporizador de pausa: cuántos segundos hasta la próxima pausa
    o.idleCountdown  = randRange(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
    o.idleTimer      = 0   -- tiempo transcurrido en estado idle
    o.idleDuration   = 0   -- duración total de la pausa actual
    o.breatheT       = 0   -- tiempo acumulado para la animación de respiración

    return o
end

-- ── Hitboxes ──────────────────────────────────────────────────────────────────
function Gummy:getOuterBounds()
    return { x = self.x - self.outerW / 2,
             y = self.y - self.outerH / 2,
             w = self.outerW, h = self.outerH }
end

function Gummy:getInnerBounds()
    return { x = self.x - self.innerW / 2,
             y = self.y - self.innerH / 2,
             w = self.innerW, h = self.innerH }
end

-- ── Colisión con nivel ────────────────────────────────────────────────────────
function Gummy:moveAndCollide(level, dx, dy)
    local hw = self.outerW / 2
    local hh = self.outerH / 2
    local x, y = self.x, self.y

    -- ── X ─────────────────────────────────────────────────────────────────────
    x = x + dx
    if dx > 0 then
        if solidAt(level, x + hw, y - hh + 4) or solidAt(level, x + hw, y + hh - 4) then
            x = math.floor((x + hw) / TILE_PX) * TILE_PX - hw
            self.vx = -GUMMY_SPEED;  self.facing = -1
        elseif x + hw >= self.rightBoundPx then
            x = self.rightBoundPx - hw
            self.vx = -GUMMY_SPEED;  self.facing = -1
        end
    elseif dx < 0 then
        if solidAt(level, x - hw, y - hh + 4) or solidAt(level, x - hw, y + hh - 4) then
            x = math.ceil((x - hw) / TILE_PX) * TILE_PX + hw
            self.vx =  GUMMY_SPEED;  self.facing = 1
        elseif x - hw <= self.leftBoundPx then
            x = self.leftBoundPx + hw
            self.vx =  GUMMY_SPEED;  self.facing = 1
        end
    end

    -- ── Y ─────────────────────────────────────────────────────────────────────
    y = y + dy
    self.onGround = false
    local chx = { x - hw + 4, x, x + hw - 4 }
    if dy > 0 then
        for _, px in ipairs(chx) do
            if solidAt(level, px, y + hh) then
                y = math.floor((y + hh) / TILE_PX) * TILE_PX - hh
                self.vy = 0;  self.onGround = true;  break
            end
        end
    elseif dy < 0 then
        for _, px in ipairs(chx) do
            if solidAt(level, px, y - hh) then
                y = math.ceil((y - hh) / TILE_PX) * TILE_PX + hh
                self.vy = 0;  break
            end
        end
    end

    self.x, self.y = x, y
end

-- ── Muerte por pisotón ────────────────────────────────────────────────────────
function Gummy:stomp()
    if self.state == 'dead' then return end
    self.state     = 'dead'
    self.deadTimer = 0
    self.vx        = 0
    self.vy        = 0
    Sound.play('enemyExplode')
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Gummy:update(dt, level)
    -- ── Muerto ────────────────────────────────────────────────────────────────
    if self.state == 'dead' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= DEAD_DURATION then
            self.alive = false
        end
        return
    end

    -- ── Idle (pausa/respiración) ──────────────────────────────────────────────
    if self.state == 'idle' then
        self.idleTimer  = self.idleTimer + dt
        self.breatheT   = self.breatheT  + dt

        -- Gravedad (puede caer mientras está parado)
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)

        if self.idleTimer >= self.idleDuration then
            -- Volver a caminar
            self.state         = 'walk'
            self.idleCountdown = randRange(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
            self.idleTimer     = 0
            self.breatheT      = 0
        end
        return
    end

    -- ── Walk ──────────────────────────────────────────────────────────────────

    -- Cuenta regresiva hacia la próxima pausa
    self.idleCountdown = self.idleCountdown - dt
    if self.idleCountdown <= 0 and self.onGround then
        self.state        = 'idle'
        self.idleTimer    = 0
        self.idleDuration = randRange(IDLE_DURATION_MIN, IDLE_DURATION_MAX)
        self.breatheT     = 0
        return
    end

    -- Detección de borde: si no hay suelo al frente → dar la vuelta
    if self.onGround then
        local hw     = self.outerW / 2
        local lookX  = self.x + (self.vx > 0 and (hw + 2) or -(hw + 2))
        local floorY = self.y + self.outerH / 2 + TILE_PX / 2
        if not solidAt(level, lookX, floorY) then
            self.vx     = -self.vx
            self.facing = -self.facing
        end
    end

    -- Gravedad
    self.vy = self.vy + ADV_GRAVITY * dt

    self:moveAndCollide(level, self.vx * dt, self.vy * dt)

    -- Animación walk
    self.animT = self.animT + dt
    if self.animT >= 1 / WALK_FPS then
        self.animT = self.animT - 1 / WALK_FPS
        self.frame = (self.frame == 1) and 2 or 1
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────
function Gummy:render(camX, camY)
    local img
    local scaleX = GUMMY_SCALE * self.facing
    local scaleY = GUMMY_SCALE

    if self.state == 'dead' then
        img = imgDead

    elseif self.state == 'idle' then
        img = imgIdle
        -- Animación elástica de respiración: escala vertical oscilante con sine
        -- Se compensa el origen Y para que no "flote" (la base queda fija).
        local breathe = math.sin(self.breatheT * BREATHE_SPEED * math.pi)
        -- scaleY crece/encoge suavemente; scaleX compensa levemente al contrario
        scaleY = GUMMY_SCALE * (1.0 + breathe * BREATHE_AMP)
        scaleX = GUMMY_SCALE * self.facing * (1.0 - breathe * BREATHE_AMP * 0.4)

    else
        img = (self.frame == 1) and imgWalk1 or imgWalk2
    end

    local iw = img:getWidth()
    local ih = img:getHeight()

    -- Ancla en la BASE del sprite (parte inferior).
    -- self.y es el centro; los pies están en self.y + sprH/2.
    local drawX = math.floor(self.x - camX)
    local feetY = math.floor(self.y - camY + self.sprH / 2)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img,
        drawX, feetY,
        0, scaleX, scaleY,
        iw / 2, ih)
end

function Gummy:renderDebug(camX, camY)
    local ob = self:getOuterBounds()
    love.graphics.setColor(1, 0.55, 0, 0.55)
    love.graphics.rectangle('line', ob.x - camX, ob.y - camY, ob.w, ob.h)
    local ib = self:getInnerBounds()
    love.graphics.setColor(1, 0.15, 0, 0.55)
    love.graphics.rectangle('line', ib.x - camX, ib.y - camY, ib.w, ib.h)
    love.graphics.setColor(0.2, 1, 1, 0.22)
    love.graphics.line(self.leftBoundPx  - camX, 0, self.leftBoundPx  - camX, WINDOW_H)
    love.graphics.line(self.rightBoundPx - camX, 0, self.rightBoundPx - camX, WINDOW_H)
end

return Gummy