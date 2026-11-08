-- CARGA DE ALETEO (solo niveles Flappy: docs/design/flappy-plan-4-attack-and-cages.md): al cogerla suma 1 al medidor de
-- carga del jugador (hasta PlayerAdventure.CHARGE_MAX), que el ATAQUE ESPECIAL gasta entero (src/player/PlayerFlight.lua).
-- La regla del efecto está en el jugador (PlayerAdventure:addCharge); el pickup solo la declara (`charge = 1`).
-- Arte: assets/images/items/flapcharge.png (tools/art/items/make_flappy_items.py).
local Entity = require 'src/world/entities/base/Entity'

local Charge = Entity.extend(Entity, { deadDuration = 0.35, debugColor = { 0.4, 0.8, 1 } })
local SCALE = 4
local img
function Charge.loadAssets()
    if img then return end
    img = require('src/fx/Anim').part('assets/images/items/flapcharge.png')
    if img.setFilter then img:setFilter('nearest', 'nearest') end
end
function Charge.sizePx() return 16 * SCALE, 16 * SCALE end

function Charge:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'idle'
    self.phase = (self.col * 0.53 + self.row * 0.29) % (math.pi * 2)
end

function Charge:updateCustom(dt) self.animT = self.animT + dt; return true end
function Charge:canBeStomped() return false end

function Charge:render(camX, camY)
    local t = love.timer.getTime() + (self.phase or 0)
    local x = math.floor(self.x - camX)
    local y = math.floor(self.y - camY + math.sin(t * 3) * 4)
    local a, s = 1, 1 + math.sin(t * 6) * 0.05
    if self.state == 'dead' then
        local k = math.min(1, self.deadTimer / 0.35)
        a, s = 1 - k, 1 + k
    end
    love.graphics.setColor(1, 1, 1, a)
    img:show(x, y, t * 2, SCALE * s, SCALE * s, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'flapcharge', label = 'Carga de aleteo', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: +1 de carga para el ataque especial (hasta 5).',
    class = Charge,
    pickup = { charge = 1, score = 10 },
    hide = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
             'onTouch', 'stompable', 'points', 'dropOnSight', 'detectRange' },
    editor = { sprite = 'assets/images/items/flapcharge.png' },
}
