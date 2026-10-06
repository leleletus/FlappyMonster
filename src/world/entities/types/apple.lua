-- Manzana: devuelve 1 de VIDA (PS) al cogerla. Con la vida llena no hay nada que curar: da puntos.
-- (La regla está en Interactions.pickupEffect: `pickup = { heal = n, score = puntos si no cura }`.)
local Entity = require 'src/world/entities/Entity'

local Apple = Entity.extend(Entity, { deadDuration = 0.35, debugColor = { 1, 0.3, 0.3 } })
local SCALE = 4
local img
function Apple.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/items/apple.png')
    img:setFilter('nearest', 'nearest')
end
function Apple.sizePx() return img:getWidth() * SCALE, img:getHeight() * SCALE end

function Apple:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    self.phase = (self.col * 0.41 + self.row * 0.63) % (math.pi * 2)
end

function Apple:updateCustom(dt) return true end
function Apple:canBeStomped() return false end

function Apple:render(camX, camY)
    local t = love.timer.getTime() + (self.phase or 0)
    -- se mece colgada de su rabito y sube y baja un poco
    local x = math.floor(self.x - camX)
    local y = math.floor(self.y - camY + math.sin(t * 2.2) * 4)
    local rot = math.sin(t * 2.2 + 1) * 0.16
    local a, s = 1, 1
    if self.state == 'dead' then
        local k = math.min(1, self.deadTimer / 0.35)
        a, s = 1 - k, 1 + k * 0.7
    end
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, x, y, rot, SCALE * s, SCALE * s, img:getWidth() / 2, img:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'apple', label = 'Manzana', category = 'Objetos',
    description = 'Coleccionable: devuelve 1 de vida (PS). Con la vida llena, +20 puntos.',
    class = Apple,
    pickup = { heal = 1, score = 20 },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
             'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    editor = { sprite = 'assets/images/items/apple.png' },
}
