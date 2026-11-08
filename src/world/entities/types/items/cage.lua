-- FLAPPY ENJAULADO (solo niveles Flappy: docs/design/flappy-plan-4-attack-and-cages.md): uno de la raza al que el Evil
-- Monster probó sus máquinas y dejó encerrado. Se libera con el ATAQUE ESPECIAL con al menos `minCharge` de potencia (si
-- no llega, la jaula aguanta y para la ráfaga). Libre, sale volando a casa (por magia: sin alas).
-- Estados: 'closed' · 'open' (liberado AHORA: `rescuedNow`, que AdventureState junta al TERMINAR la etapa en
-- `result.rescued`; FlappyRun lo guarda — golden rule 7 —) · 'empty' (`freed`: liberado en una partida ya terminada).
-- Cada uno REGALA un power-up (`gift`, docs/design/powerups.md) al terminar la etapa: src/flappy/FlappyRun.lua.
-- Arte: assets/images/items/cage-Sheet.png (tools/art/items/make_flappy_items.py): cerrada · abierta · el flappy suelto.
local Entity = require 'src/world/entities/base/Entity'

local Cage = Entity.extend(Entity, { debugColor = { 1, 0.5, 0.75 } })
local SCALE = 4
local FLY_T = 1.6                       -- s que tarda el liberado en irse volando
local img, quads
function Cage.loadAssets()
    if img then return end
    img = love.graphics.newImage('assets/images/items/cage-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, 3 do quads[i] = love.graphics.newQuad((i - 1) * 16, 0, 16, 16, img:getDimensions()) end
end
function Cage.sizePx() return 16 * SCALE, 16 * SCALE end

function Cage:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    self.state = 'closed'
    self.flyT = 0
end

function Cage:updateCustom(dt)
    if self.freed and self.state == 'closed' then self.state = 'empty' end
    if self.state == 'open' then self.flyT = self.flyT + dt end
    return true
end
function Cage:canBeStomped() return false end
function Cage:isGhost() return true end            -- (no se toca: ni daña ni se recoge)

function Cage:onSpecialHit(power)
    if self.state ~= 'closed' then return false end
    if power >= (self.props.minCharge or 1) then
        self.state, self.rescuedNow, self.flyT = 'open', true, 0
        Sound.play('oneUp')
        Entity.emitFx('collect', self.x, self.y)
    else
        Sound.play('headBump')
    end
    return true
end

function Cage:render(camX, camY)
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, quads[self.state == 'closed' and 1 or 2], x, y, 0, SCALE, SCALE, 8, 8)
    if self.state == 'open' and self.flyT < FLY_T then
        local k = self.flyT / FLY_T
        local fy = y - k * 260 + math.sin(self.flyT * 14) * 6
        love.graphics.setColor(1, 1, 1, 1 - k * k)
        love.graphics.draw(img, quads[3], x + math.floor(k * 60), math.floor(fy), 0, SCALE, SCALE, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- la carga que pide (puntitos encima)
    if self.state == 'closed' then
        local n = self.props.minCharge or 1
        for i = 1, n do
            love.graphics.setColor(0.43, 0.82, 1, 1)
            love.graphics.rectangle('fill', x - n * 6 + (i - 1) * 12 + 2, y - 46, 8, 8)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return {
    name = 'cage', label = 'Flappy enjaulado', category = 'Flappy', flappyOnly = true,
    description = 'Solo niveles Flappy: se libera con el ataque especial (carga mínima). Se guarda al terminar la etapa.',
    class = Cage,
    defaults = { movement = 'static' }, hide = 'all',
    props = {
        { key = 'minCharge', kind = 'int', label = 'Carga mínima', group = 'Jaula', default = 1, min = 1, max = 5, step = 1,
          help = 'Potencia del ataque especial que hace falta para abrirla (1..5)' },
        { key = 'gift', kind = 'enum', label = 'Regala', group = 'Jaula', default = 'shield', options = (function()
              local o = {}
              for _, p in ipairs(require('src/world/powerups/Powerups').forMode('flappy')) do
                  o[#o + 1] = { value = p.id, label = p.id }
              end
              return o
          end)(), help = 'El power-up que da al liberarlo (al terminar la etapa, una vez por partida)' },
    },
    editor = { draw = function(x, y, s)                    -- (la jaula cerrada, el primer cuadro)
        Cage.loadAssets()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, quads[1], x, y, 0, s / 16, s / 16)
    end },
}
