-- src/entities/Pipe.lua
local Class = require 'libs/class'
local Pipe  = Class:new()

local img = nil
local function loadSprite()
    if img then return end
    img = love.graphics.newImage('assets/images/pipes/pipe.png')
end

-- Duración de las animaciones en segundos
local INTRO_DUR = 0.35
local OUTRO_DUR = 0.30
-- A partir de qué distancia del borde izquierdo empieza el outro
local OUTRO_DIST = 120

function Pipe:new(x, gapY)
    loadSprite()
    local o = setmetatable({}, self)
    self.__index = self
    o.x       = x
    o.gapY    = gapY
    o.w       = PIPE_W
    o.gap     = PIPE_GAP
    o.passed  = false
    o.introT   = 0
    o.outroT   = 0
    o.leaving  = false
    o.entering = false   -- se activa cuando el pipe cruza el borde derecho
    return o
end

function Pipe:update(dt)
    -- Nota: el movimiento horizontal lo hace PlayState directamente (p.x = ...)
    -- Aquí solo manejamos los timers de animación.

    -- Activar intro cuando el pipe entra en pantalla por la derecha
    if not self.entering and self.x + self.w <= WINDOW_W then
        self.entering = true
    end

    if self.entering and self.introT < 1 then
        self.introT = math.min(1, self.introT + dt / INTRO_DUR)
    end

    if not self.leaving and self.x < OUTRO_DIST then
        self.leaving = true
    end
    if self.leaving and self.outroT < 1 then
        self.outroT = math.min(1, self.outroT + dt / OUTRO_DUR)
    end
end

function Pipe:isOffScreen()
    return self.x + self.w < 0
end

function Pipe:collides(bounds)
    local topPipeBottom = self.gapY - self.gap / 2
    local botPipeTop    = self.gapY + self.gap / 2
    local bRight        = bounds.x + bounds.w
    local bBottom       = bounds.y + bounds.h
    if bRight < self.x or bounds.x > self.x + self.w then return false end
    if bounds.y > topPipeBottom and bBottom < botPipeTop then return false end
    return true
end

-- Easing: ease out cubic para intro, ease in cubic para outro
local function easeOut(t) return 1 - (1-t)^3 end
local function easeIn(t)  return t^3 end

function Pipe:render()
    local iw = img:getWidth()   -- 6
    local ih = img:getHeight()  -- 84
    local sx = PIPE_SCALE
    local sy = PIPE_SCALE

    local topPipeBottom = self.gapY - self.gap / 2
    local botPipeTop    = self.gapY + self.gap / 2

    -- ── Calcular offset y stretch ─────────────────────────────────────────────
    -- intro: t va 0→1, pipes entran desde fuera
    -- outro: t va 0→1, pipes salen hacia fuera
    local slideT   -- 0 = fuera de pantalla, 1 = posición final
    local stretchY -- factor de stretch vertical (leve)

    if self.outroT > 0 then
        -- Salida: ease in (acelera hacia afuera)
        slideT   = 1 - easeIn(self.outroT)
        stretchY = 1 + (1 - slideT) * 0.12
    else
        -- Entrada: ease out (desacelera al llegar)
        slideT   = easeOut(self.introT)
        stretchY = 1 + (1 - slideT) * 0.18
    end

    -- Offset en píxeles: cuánto están "metidos" fuera de pantalla
    local slideAmt = (1 - slideT)

    -- Tubería superior: offset negativo (sale hacia arriba)
    local topOffset = -topPipeBottom * slideAmt

    -- Tubería inferior: offset positivo (sale hacia abajo)
    local botTotalH = WINDOW_H - botPipeTop
    local botOffset = botTotalH * slideAmt

    love.graphics.setColor(COLOR_WHITE)

    -- ── Tubería superior (flipped, cap hacia abajo) ───────────────────────────
    love.graphics.push()
    love.graphics.translate(self.x, topPipeBottom + topOffset)
    love.graphics.scale(sx, -sy * stretchY)
    love.graphics.draw(img, 0, 0)
    love.graphics.pop()

    -- ── Tubería inferior (normal, cap hacia arriba) ───────────────────────────
    love.graphics.push()
    love.graphics.translate(self.x, botPipeTop + botOffset)
    love.graphics.scale(sx, sy * stretchY)
    love.graphics.draw(img, 0, 0)
    love.graphics.pop()

    love.graphics.setColor(COLOR_WHITE)
end

return Pipe