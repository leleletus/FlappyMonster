-- Estrella coleccionable: gira y flota. Al tocarla da 25 puntos.
local Entity = require 'src/world/entities/base/Entity'

local Star = Entity.extend(Entity, { deadDuration = 0.35, debugColor = { 1, 1, 0.3 } })
local SCALE = 4
local img
function Star.loadAssets()
    if img then return end
    img = require('src/fx/Anim').image('assets/images/items/star.png')
    img:setFilter('nearest', 'nearest')
end
function Star.sizePx() return img:getWidth() * SCALE, img:getHeight() * SCALE end

function Star:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    self.phase = (self.col * 0.37 + self.row * 0.71) % (math.pi * 2)
end

function Star:updateCustom(dt) self.animT = self.animT + dt; return true end
function Star:canBeStomped() return false end

function Star:render(camX, camY)
    local t  = love.timer.getTime() + (self.phase or 0)
    local x  = math.floor(self.x - camX)
    local y  = math.floor(self.y - camY + math.sin(t * 2.5) * 5)
    local sx = math.cos(t * 3)                  -- giro (se estrecha de canto)
    if math.abs(sx) < 0.15 then sx = sx < 0 and -0.15 or 0.15 end
    local a, s = 1, 1
    if self.state == 'dead' then
        local k = math.min(1, self.deadTimer / 0.35)
        a, s = 1 - k, 1 + k * 0.8
    end
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, x, y, 0, SCALE * sx * s, SCALE * s, img:getWidth() / 2, img:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'star', label = 'Estrella', category = 'Objetos',
    description = 'Coleccionable: +25 puntos.',
    class = Star,
    pickup = { score = 25 },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
             'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    editor = { sprite = 'assets/images/items/star.png' },
}
