-- src/entities/Player.lua
local Class = require 'libs/class'
local Player = Class:new()

local sprites = nil

local function loadSprites()
    if sprites then return end
    sprites = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
end

local IDLE_FPS   = 4
local JUMP_HOLD  = 0.2
local PUFF_SCALE = 1.18
local PUFF_SPEED = 14

function Player:new()
    loadSprites()
    local o = setmetatable({}, self)
    self.__index = self
    o.x     = PLAYER_START_X
    o.y     = PLAYER_START_Y
    o.vy    = 0
    o.angle = 0
    o.alive = true
    o.dead  = false   -- true = caída libre sin input
    o.scale = PLAYER_SCALE
    o.w     = 9  * o.scale
    o.h     = 16 * o.scale
    o.idleTimer = 0
    o.idleFrame = 1
    o.jumpTimer = 0
    o.puff      = 1
    return o
end

function Player:flap()
    if self.dead then return end
    self.vy        = FLAP_VELOCITY
    self.jumpTimer = JUMP_HOLD
    self.puff      = PUFF_SCALE
    Sound.play('jump')
end

function Player:die()
    self.dead  = true
    self.alive = false   -- señal para PlayState
end

function Player:update(dt)
    -- Física siempre activa
    self.vy = self.vy + GRAVITY * dt
    self.y  = self.y  + self.vy * dt

    if self.dead then
        -- Caída libre: rotación suave capeada, gira según velocidad
        local maxRotSpeed = 4.0   -- radianes/segundo máximo
        local rotSpeed = math.max(-maxRotSpeed, math.min(maxRotSpeed, self.vy * 0.004))
        self.angle = self.angle + rotSpeed * dt
    else
        -- Vivo: inclinación leve controlada
        local targetAngle = math.max(-0.08, math.min(0.18, self.vy / 2200))
        self.angle = self.angle + (targetAngle - self.angle) * 10 * dt

        -- Límites de pantalla → muerte
        if self.y < -self.h / 2 or self.y > WINDOW_H + self.h / 2 then
            self:die()
        end
    end

    if self.jumpTimer > 0 then self.jumpTimer = self.jumpTimer - dt end

    self.idleTimer = self.idleTimer + dt
    if self.idleTimer >= 1 / IDLE_FPS then
        self.idleTimer = self.idleTimer - 1 / IDLE_FPS
        self.idleFrame = (self.idleFrame == 1) and 2 or 1
    end

    self.puff = self.puff + (1 - self.puff) * PUFF_SPEED * dt
end

function Player:getBounds()
    local mx = self.w * 0.25
    local my = self.h * 0.25
    return {
        x = self.x - self.w / 2 + mx,
        y = self.y - self.h / 2 + my,
        w = self.w - mx * 2,
        h = self.h - my * 2,
    }
end

function Player:render()
    local img
    if self.jumpTimer > 0 then
        img = sprites[2]
    elseif self.idleFrame == 1 then
        img = sprites[1]
    else
        img = sprites[3]
    end
    local s = self.scale * self.puff
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.draw(img, 0, 0, 0, s, s,
        img:getWidth() / 2, img:getHeight() / 2)
    love.graphics.pop()
end

return Player
