-- Checkpoint: al tocarlo, el jugador reaparecerá aquí al morir. La bandera
-- se levanta solo para quien la activó (cada jugador tiene su checkpoint).
local Entity = require 'src/world/entities/base/Entity'

-- Zona de activación alta (una columna de ~3 casillas desde el suelo): difícil de saltarse
local Checkpoint = Entity.extend(Entity, { debugColor = { 0.4, 0.9, 1 },
    hitbox = { outerW = 1.3, outerH = 2.0, innerW = 1.3, innerH = 2.0 } })
local SCALE = 6
local imgOff, imgOn
function Checkpoint.loadAssets()
    if imgOff then return end
    imgOff = love.graphics.newImage('assets/images/items/checkpoint_off.png')
    imgOn  = love.graphics.newImage('assets/images/items/checkpoint_on.png')
    imgOff:setFilter('nearest', 'nearest'); imgOn:setFilter('nearest', 'nearest')
end
function Checkpoint.sizePx() return imgOff:getWidth() * SCALE, imgOff:getHeight() * SCALE end

function Checkpoint:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    -- Apoyado en el suelo de su celda
    self.y = self.row * TILE_PX - self.outerH / 2
    self.activeLocal = false
    self.raiseT = 0
end

function Checkpoint:updateCustom(dt) return true end
function Checkpoint:canBeStomped() return false end

-- Punto donde reaparece el jugador
function Checkpoint:respawnPoint()
    return self.x, self.y + self.outerH / 2 - TILE_PX
end

function Checkpoint:activate()
    self.activeLocal = true
    self.raiseT = love.timer and love.timer.getTime() or 0
end

function Checkpoint:render(camX, camY)
    local on  = self.activeLocal
    local im  = on and imgOn or imgOff
    local x   = math.floor(self.x - camX)
    local bot = math.floor(self.y - camY + self.outerH / 2)
    local sy  = SCALE
    if on then
        local k = math.min(1, (love.timer.getTime() - (self.raiseT or 0)) / 0.3)
        sy = SCALE * (0.8 + 0.2 * k)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(im, x, bot, 0, SCALE, sy, im:getWidth() / 2, im:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'checkpoint', label = 'Checkpoint', category = 'Objetos',
    description = 'Al tocarlo pasa a ser el punto de reaparición del jugador.',
    class = Checkpoint,
    checkpoint = true,
    hide = 'all',
    editor = { sprite = 'assets/images/items/checkpoint_on.png' },
}
