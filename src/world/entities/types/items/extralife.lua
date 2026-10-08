-- Vida extra: el icono de vidas del HUD con animación gelatinosa. +1 vida.
local Entity = require 'src/world/entities/base/Entity'

local Life = Entity.extend(Entity, { deadDuration = 0.4, debugColor = { 0.4, 1, 0.5 } })
local SCALE = 4
local img
function Life.loadAssets()
    if img then return end
    img = require('src/fx/Anim').image('assets/images/player/icon.png')
    img:setFilter('nearest', 'nearest')
end
function Life.sizePx() return img:getWidth() * SCALE, img:getHeight() * SCALE end

function Life:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    self.phase = (self.col * 0.53 + self.row * 0.29) % (math.pi * 2)
end

function Life:updateCustom(dt) return true end
function Life:canBeStomped() return false end

function Life:render(camX, camY)
    local t = love.timer.getTime() + (self.phase or 0)
    -- Gelatina: estira y aplasta con rebote, anclada por la base
    local w  = math.sin(t * 5)
    local sx = 1 + 0.14 * w
    local sy = 1 - 0.14 * w
    local hop = math.max(0, math.sin(t * 2.5)) * 8
    local a = 1
    if self.state == 'dead' then
        local k = math.min(1, self.deadTimer / 0.4)
        sx, sy, a = 1 - k * 0.6, 1 + k * 1.2, 1 - k
    end
    local x    = math.floor(self.x - camX)
    local base = math.floor(self.y - camY + self.outerH / 2 - hop)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, x, base, 0, SCALE * sx, SCALE * sy, img:getWidth() / 2, img:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'extralife', label = 'Vida extra', category = 'Objetos',
    description = 'Coleccionable: +1 vida.',
    class = Life,
    pickup = { lives = 1 },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
             'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    editor = { sprite = 'assets/images/player/icon.png' },
}
