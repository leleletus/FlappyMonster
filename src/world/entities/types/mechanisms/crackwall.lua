-- MURO AGRIETADO (solo niveles Flappy: docs/design/flappy-plan-4-attack-and-cages.md): un obstáculo ESPECIAL. Sólido
-- (como la Puerta: solidFull + isSolidBody) de `rows` casillas de alto hacia arriba desde su casilla; el ATAQUE ESPECIAL
-- con al menos `minCharge` de potencia lo rompe (si no llega, aguanta y para la ráfaga). Tapa atajos y premios: la ruta
-- principal de una etapa nunca depende de romperlo (el piloto de flappy_flight pasa las etapas sin carga).
-- Arte: assets/images/world/flappy/crackwall.png (tools/art/items/make_flappy_items.py), una casilla que se repite.
local Entity = require 'src/world/entities/base/Entity'

local Wall = Entity.extend(Entity, { debugColor = { 0.7, 0.6, 0.5 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })
Wall.solidFull = true

local T = TILE_PX
local img
function Wall.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/world/flappy/crackwall.png')
    img:setFilter('nearest', 'nearest')
end
function Wall.sizePx() return T, T end

function Wall:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    local rows = math.max(1, math.floor(tonumber(self.props.rows) or 3))
    self.x0, self.x1 = (self.col - 1) * T, self.col * T
    self.y0, self.y1 = (self.row - rows) * T, self.row * T
    self.x, self.y = (self.x0 + self.x1) / 2, (self.y0 + self.y1) / 2
    self.outerW, self.outerH = T, self.y1 - self.y0
    self.innerW, self.innerH = self.outerW, self.outerH
    self.state = 'intact'
end

function Wall:getOuterBounds(into) return Entity.box(into, self.x0, self.y0, T, self.y1 - self.y0) end
function Wall:getInnerBounds(into) return self:getOuterBounds(into) end
function Wall:isSolidBody() return self.alive and self.state == 'intact' end
function Wall:isObstacle() return self:isSolidBody() end
function Wall:canBeStomped() return false end
function Wall:isGhost() return true end            -- (no se toca como un enemigo: solo choca)
function Wall:updateCustom(dt) return true end

function Wall:onSpecialHit(power)
    if self.state ~= 'intact' then return false end
    if power >= (self.props.minCharge or 2) then
        self.state = 'broken'
        Sound.play('blockBreak', 0.8)
        for y = self.y0 + T / 2, self.y1, T do Entity.emitFx('block_break', self.x, y) end
    else
        Sound.play('headBump')
    end
    return true
end

function Wall:render(camX, camY)
    if self.state ~= 'intact' then return end
    love.graphics.setColor(1, 1, 1, 1)
    for y = self.y0, self.y1 - 1, T do
        love.graphics.draw(img, math.floor(self.x0 - camX), math.floor(y - camY), 0, T / 16, T / 16)
    end
    -- la carga que pide (puntitos)
    local n = self.props.minCharge or 2
    for i = 1, n do
        love.graphics.setColor(0.43, 0.82, 1, 1)
        love.graphics.rectangle('fill', math.floor(self.x - camX) - n * 6 + (i - 1) * 12 + 2, math.floor(self.y0 - camY) - 14, 8, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'crackwall', label = 'Muro agrietado', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: muro sólido que se rompe con el ataque especial (carga mínima). Para atajos y premios.',
    class = Wall,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'minCharge', kind = 'int', label = 'Carga mínima', group = 'Muro', default = 2, min = 1, max = 5, step = 1,
          help = 'Potencia del ataque especial que hace falta para romperlo (1..5)' },
        { key = 'rows', kind = 'int', label = 'Alto (casillas)', group = 'Muro', default = 3, min = 1, max = 9, step = 1,
          help = 'Desde la casilla de la entidad hacia arriba' },
    },
    editor = { draw = function(x, y, s)
        Wall.loadAssets()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, s / 16, s / 16)
    end },
}
