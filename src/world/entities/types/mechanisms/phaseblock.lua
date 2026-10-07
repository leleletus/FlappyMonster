-- Bloques de fase: las casillas de su rectángulo NO están en la partida hasta que
-- el jefe de su zona llega a la fase `phase` (en su sitio hay `hiddenAs`: vacío,
-- hielo, nieve...). Entonces aparecen con un saltito y chispas (y, si es un
-- Activador, el reguero de chispas hasta lo que controla). Sirve para que una
-- pieza de la arena (un Activador, una plataforma, un muro) solo esté cuando hace
-- falta. Como la zona de puntos, la entidad solo sirve para colocarla: su casilla
-- es la esquina superior izquierda y la cajita "Esquina" la inferior derecha. Lo
-- hace todo src/world/systems/PhaseBlocks.lua (un jugador, servidor y cliente igual).

local Entity      = require 'src/world/entities/base/Entity'
local PhaseBlocks = require 'src/world/systems/PhaseBlocks'

local PB = Entity.extend(Entity, { debugColor = { 0.55, 0.85, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

function PB.loadAssets() end
function PB.sizePx() return TILE_PX, TILE_PX end

function PB:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
end

function PB:canBeStomped() return false end
function PB:canBeKnocked() return false end
function PB:isBodyDisabled() return true end
function PB:isObstacle() return false end
function PB:isGhost() return true end
function PB:interact() return nil end
function PB:updateCustom() return true end
function PB:netAtRest() return true end      -- nunca se envía
function PB:netRest() end

-- Icono: bloque punteado con un número romano de fase
local function drawIcon(x, y, s)
    local k = s / 16
    love.graphics.setColor(0.1, 0.15, 0.25, 0.85)
    love.graphics.rectangle('fill', x + 1 * k, y + 1 * k, 14 * k, 14 * k)
    love.graphics.setColor(0.55, 0.85, 1, 1)
    for i = 0, 6 do
        love.graphics.rectangle('fill', x + (1 + i * 2) * k, y + 1 * k, k, k)
        love.graphics.rectangle('fill', x + (2 + i * 2) * k, y + 14 * k, k, k)
        love.graphics.rectangle('fill', x + 1 * k, y + (2 + i * 2) * k, k, k)
        love.graphics.rectangle('fill', x + 14 * k, y + (1 + i * 2) * k, k, k)
    end
    love.graphics.rectangle('fill', x + 5 * k, y + 5 * k, 1 * k, 6 * k)
    love.graphics.rectangle('fill', x + 7 * k, y + 5 * k, 1 * k, 6 * k)
    love.graphics.rectangle('fill', x + 9 * k, y + 5 * k, 1 * k, 6 * k)
    love.graphics.setColor(1, 1, 1, 1)
end

function PB:render(camX, camY)
    if not EDITOR_VIEW then return end
    drawIcon(math.floor(self.x - camX - TILE_PX / 2) + 8, math.floor(self.y - camY - TILE_PX / 2) + 8, TILE_PX - 16)
end

-- En el editor: el rectángulo (los bloques se ven tal cual) y el texto
function PB.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    local T = ctx.t
    local col = math.floor((cx + ctx.camX) / T) + 1
    local row = math.floor((cy + ctx.camY) / T) + 1
    local cr = props.corner or {}
    local c1, r1 = tonumber(cr.col) or col, tonumber(cr.row) or row
    local x0 = (math.min(col, c1) - 1) * T - ctx.camX
    local y0 = (math.min(row, r1) - 1) * T - ctx.camY
    local w = (math.abs(c1 - col) + 1) * T
    local h = (math.abs(r1 - row) + 1) * T
    love.graphics.setColor(0.55, 0.85, 1, 0.18)
    love.graphics.rectangle('fill', x0, y0, w, h)
    love.graphics.setColor(0.55, 0.85, 1, 0.9)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.rectangle('line', x0, y0, w, h)
    love.graphics.setLineWidth(1)
    love.graphics.push()
    love.graphics.translate(x0, y0 + h + 4 / zoom); love.graphics.scale(1 / zoom)
    local txt = string.format('Aparece en la fase %d del jefe  ·  antes: %s', tonumber(props.phase) or 2, props.hiddenAs or 'empty')
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.print(txt, 1, 1)
    love.graphics.setColor(0.55, 0.85, 1, 1); love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

local HIDDEN_LABELS = { empty = 'Vacío', ice = 'Hielo', snow = 'Nieve', solid = 'Piedra',
                        dirt = 'Tierra', grass = 'Césped', sand = 'Arena' }
local hiddenOpts = {}
for _, n in ipairs(PhaseBlocks.HIDDEN_AS) do hiddenOpts[#hiddenOpts + 1] = { value = n, label = HIDDEN_LABELS[n] or n } end

local G = 'Fase'
return {
    name = 'phaseblock', label = 'Bloques de fase', category = 'Mecanismos',
    description = 'Los bloques de su rectángulo solo aparecen cuando el jefe de la zona llega a una fase '
               .. '(p. ej. un Activador que sale en la fase 3). Mientras tanto, en su sitio hay lo que elijas.',
    class = PB,
    inBlockOk = true,          -- (cubre bloques: es lo suyo)
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='corner', kind='point', label='Esquina inferior derecha', group='Área',
          default=function(d) return { col = d.col or 1, row = d.row or 1 } end,
          help='Arrastra la cajita en el mapa. La casilla de la entidad es la esquina superior izquierda' },
        { key='phase', kind='int', label='Aparece en la fase', group=G, default=3, min=2, max=5, step=1,
          help='Fase del jefe de la zona con la que aparecen los bloques' },
        { key='zone', kind='int', label='Zona de jefe', group=G, default=0, min=0, max=20, step=1,
          help='Id de la zona de jefe (0 = la que lo contiene o la más cercana)' },
        { key='hiddenAs', kind='enum', label='Antes hay', group=G, default='empty', options=hiddenOpts,
          help='Lo que ocupa esas casillas hasta que aparecen' },
    },
    editor = { draw = drawIcon },
}
