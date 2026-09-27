-- Zona de puntos: quien está dentro gana `points` puntos cada `interval`
-- segundos. Es el objetivo del modo "Rey de la Colina" (un nivel con zonas de
-- puntos se ofrece en ese modo), pero funciona en cualquiera.
-- Como la inundación, la entidad solo sirve para colocarla y configurarla: la
-- casilla donde se coloca es la esquina superior izquierda y la cajita
-- "Esquina" la inferior derecha. El nivel construye las zonas
-- (world/PointAreas.lua) y el juego / servidor reparte los puntos.

local Entity     = require 'src/world/entities/Entity'
local PointAreas = require 'src/world/PointAreas'

local PA = Entity.extend(Entity, { debugColor = { 1, 0.82, 0.22 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

function PA.loadAssets() end
function PA.sizePx() return TILE_PX, TILE_PX end

function PA:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
end

function PA:canBeStomped() return false end
function PA:canBeKnocked() return false end
function PA:isBodyDisabled() return true end
function PA:isObstacle() return false end
function PA:isGhost() return true end
function PA:interact() return nil end
function PA:updateCustom() return true end
function PA:netAtRest() return true end      -- nunca se envía
function PA:netRest() end

-- Icono: moneda con una bandera (la colina)
local function drawIcon(x, y, s)
    local k = s / 16
    love.graphics.setColor(0.35, 0.25, 0.05, 1)
    love.graphics.rectangle('fill', x + 2 * k, y + 11 * k, 12 * k, 4 * k)
    love.graphics.setColor(1, 0.82, 0.22, 1)
    love.graphics.rectangle('fill', x + 1 * k, y + 10 * k, 14 * k, 3 * k)
    love.graphics.rectangle('fill', x + 4 * k, y + 8 * k, 8 * k, 2 * k)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    love.graphics.rectangle('fill', x + 7 * k, y + 1 * k, 1 * k, 7 * k)
    love.graphics.setColor(1, 0.35, 0.3, 1)
    love.graphics.rectangle('fill', x + 8 * k, y + 1 * k, 5 * k, 3 * k)
    love.graphics.setColor(1, 1, 1, 1)
end

-- En el editor: el área se ve como en la partida (lo dibuja el nivel); aquí
-- solo el icono en su esquina
function PA:render(camX, camY)
    if not EDITOR_VIEW then return end
    drawIcon(math.floor(self.x - camX - TILE_PX / 2) + 8, math.floor(self.y - camY - TILE_PX / 2) + 8, TILE_PX - 16)
end

function PA.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    local T = ctx.t
    local col = math.floor((cx + ctx.camX) / T) + 1
    local row = math.floor((cy + ctx.camY) / T) + 1
    local a = PointAreas.fromPlacement({ type = 'pointarea', col = col, row = row, props = props })
    local x0, y1 = a.x0 - ctx.camX, a.y1 - ctx.camY
    love.graphics.push()
    love.graphics.translate(x0, y1 + 4 / zoom); love.graphics.scale(1 / zoom)
    local txt = string.format('+%d puntos cada %s s%s', a.points, (a.interval % 1 == 0) and tostring(a.interval) or string.format('%.2f', a.interval),
                              a.contested and '  ·  disputada: con varios dentro nadie suma' or '')
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.print(txt, 1, 1)
    love.graphics.setColor(1, 0.85, 0.3, 1); love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

local G = 'Puntos'
return {
    name = 'pointarea', label = 'Zona de puntos', category = 'Mecanismos',
    description = 'Quien esté dentro gana puntos cada cierto tiempo. Es el objetivo del modo Rey de la Colina.',
    class = PA,
    hide = 'all',
    defaults = { movement = 'static' },
    props = {
        { key='corner', kind='point', label='Esquina inferior derecha', group='Área',
          default=function(d) return { col = (d.col or 1) + 2, row = (d.row or 1) + 1 } end,
          help='Arrastra la cajita en el mapa. La casilla de la entidad es la esquina superior izquierda' },
        { key='points', kind='int', label='Puntos', group=G, default=1, min=1, max=100, step=1,
          help='Puntos que recibe cada jugador dentro en cada intervalo' },
        { key='interval', kind='number', label='Cada (s)', group=G, default=1, min=0.1, max=30, step=0.1,
          help='Segundos que hay que estar dentro para recibirlos (al salir se empieza de cero)' },
        { key='contested', kind='bool', label='Disputada', group=G, default=false,
          help='Si hay varios jugadores dentro, nadie suma: hay que echar a los demás' },
    },
    editor = { draw = drawIcon },
}
