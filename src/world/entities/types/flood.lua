-- Inundación: el nivel del agua de un rectángulo sube y baja en ciclo.
-- La entidad solo sirve para colocarla y configurarla en el editor: la
-- casilla donde se coloca es la esquina superior izquierda y la cajita
-- "Esquina" (arrastrable) la inferior derecha. En la partida no hace nada:
-- el nivel construye las inundaciones con estas propiedades (world/Floods.lua)
-- y el agua funciona igual en un jugador, en el servidor y en el cliente.

local Entity = require 'src/world/entities/Entity'
local Floods = require 'src/world/Floods'

local Flood = Entity.extend(Entity, { debugColor = { 0.3, 0.6, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

function Flood.loadAssets() end
function Flood.sizePx() return TILE_PX, TILE_PX end

function Flood:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
end

function Flood:canBeStomped() return false end
function Flood:canBeKnocked() return false end
function Flood:isBodyDisabled() return true end
function Flood:isObstacle() return false end
function Flood:isGhost() return true end            -- nada interactúa con ella
function Flood:interact() return nil end
function Flood:updateCustom() return true end
function Flood:netAtRest() return true end          -- nunca se envía (el agua va por tiempo)
function Flood:netRest() end

-- Icono: ola sobre agua
local function drawIcon(x, y, s)
    local k = s / 16
    love.graphics.setColor(0.1, 0.35, 0.85, 0.9)
    love.graphics.rectangle('fill', x + k, y + 7 * k, 14 * k, 8 * k)
    love.graphics.setColor(0.85, 0.95, 1, 1)
    for i = 0, 3 do
        love.graphics.rectangle('fill', x + (1 + i * 4) * k, y + (6 + (i % 2)) * k, 3 * k, k)
    end
    -- Flechas arriba / abajo
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon('fill', x + 5 * k, y + k, x + 2 * k, y + 4 * k, x + 8 * k, y + 4 * k)
    love.graphics.polygon('fill', x + 11 * k, y + 5 * k, x + 8 * k, y + 2 * k, x + 14 * k, y + 2 * k)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Rectángulo y niveles de una colocación (editor)
local function preview(props, col, row)
    return Floods.fromPlacement({ type = 'flood', col = col, row = row, props = props })
end

-- En el editor se ve el área (con el agua a su nivel inicial)
function Flood:render(camX, camY)
    if not EDITOR_VIEW then return end
    local f = preview(self.props, self.col, self.row)
    love.graphics.setColor(0.2, 0.5, 1, 0.12)
    love.graphics.rectangle('fill', f.x0 - camX, f.surf - camY, f.x1 - f.x0, f.y1 - f.surf)
    love.graphics.setColor(0.4, 0.7, 1, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', f.x0 - camX, f.y0 - camY, f.x1 - f.x0, f.y1 - f.y0)
    love.graphics.setLineWidth(1)
    drawIcon(math.floor(self.x - camX - TILE_PX / 2), math.floor(self.y - camY - TILE_PX / 2), TILE_PX)
end

-- Editor (seleccionada): niveles inicial / máximo y una vista previa animada
-- del ciclo (con el tiempo real)
function Flood.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    local T = ctx.t
    local col = math.floor((cx + ctx.camX) / T) + 1
    local row = math.floor((cy + ctx.camY) / T) + 1
    local f = preview(props, col, row)
    local s = T / TILE_PX                                   -- px de mundo → px del editor
    local x0, x1 = f.x0 * s - ctx.camX, f.x1 * s - ctx.camX
    local y0, y1 = f.y0 * s - ctx.camY, f.y1 * s - ctx.camY
    local function yAt(lv) return y1 - lv * T end
    -- Agua animada según el ciclo
    local lv, phase = Floods.levelAt(f, love.timer.getTime() % math.max(0.01, f.startDelay + f.cycle))
    love.graphics.setColor(0.15, 0.45, 1, 0.35)
    love.graphics.rectangle('fill', x0, yAt(lv), x1 - x0, lv * T)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.setColor(0.4, 0.75, 1, 1)
    love.graphics.rectangle('line', x0, y0, x1 - x0, y1 - y0)
    -- Nivel máximo (rojo) e inicial (verde)
    love.graphics.setColor(1, 0.35, 0.3, 0.9)
    love.graphics.line(x0, yAt(f.hi), x1, yAt(f.hi))
    love.graphics.setColor(0.4, 1, 0.5, 0.9)
    love.graphics.line(x0, yAt(f.lo), x1, yAt(f.lo))
    local names = { low = 'abajo', rise = 'subiendo', hold = 'arriba', fall = 'bajando' }
    -- (texto a tamaño fijo en pantalla aunque el editor esté alejado)
    love.graphics.push()
    love.graphics.translate(x0, y1 + 4 / zoom); love.graphics.scale(1 / zoom)
    local txt
    if f.control == 'switch' then
        txt = string.format('#%d · bloques ON/OFF: ON = sube al máximo en %.1f s · OFF = baja al mínimo en %.1f s',
            f.id, f.riseT, f.fallT)
    else
        txt = string.format('#%d · %sciclo %.1f s (sube %.1f, arriba %.1f, baja %.1f, abajo %.1f) - %s', f.id,
            f.control == 'boss' and 'durante la pelea de jefe: ' or '', f.cycle, f.riseT, f.holdTime, f.fallT,
            f.lowTime, names[phase] or phase)
    end
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(txt, 1, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

local G0, G1, G2, G3 = 'Control', 'Área y niveles', 'Subida', 'Bajada'
local function cyclic(p) return p.control ~= 'switch' end
return {
    name = 'flood', label = 'Inundación', category = 'Mecanismos',
    description = 'Área cuyo nivel de agua sube y baja: siempre en ciclo, durante la pelea de una zona de jefe, '
               .. 'o al encender/apagar bloques ON/OFF conectados a ella (capa Bloques → herramienta Conectar).',
    class = Flood,
    hide = 'all',
    activatable = true,
    -- (al conectarle un bloque ON/OFF en el editor, pasa a moverse con ellos)
    onLink = function(p) p.control = 'switch' end,
    defaults = { movement = 'static' },
    props = {
        { key='id', kind='int', label='Número (id)', group=G0, default=1, min=1, max=99, step=1,
          help='Los bloques ON/OFF se conectan a este número (capa Bloques → Conectar)' },
        { key='control', kind='enum', label='Se mueve', group=G0, default='cycle',
          options={ { value='cycle', label='Siempre' }, { value='boss', label='Pelea de jefe' },
                    { value='switch', label='Bloques ON/OFF' } },
          help='Siempre: ciclo sin fin. Pelea de jefe: su ciclo solo mientras dura la pelea; al morir el jefe baja al mínimo y se queda. '
            .. 'Bloques ON/OFF: con uno conectado en ON sube al máximo y se queda; con todos en OFF baja al mínimo' },
        { key='zone', kind='int', label='Zona de jefe (id)', group=G0, default=0, min=0, max=99, step=1,
          showIf=function(p) return p.control == 'boss' end, help='0 = la zona con la que se solapa (o la más cercana)' },
        { key='corner', kind='point', label='Esquina inferior derecha', group=G1,
          default=function(d) return { col = (d.col or 1) + 7, row = (d.row or 1) + 4 } end,
          help='Arrastra la cajita en el mapa. La casilla de la entidad es la esquina superior izquierda' },
        { key='startLevel', kind='number', label='Nivel inicial / mínimo', group=G1, default=1,
          min=0, max=200, step=0.25, help='Casillas de agua desde el fondo del area (también a donde vuelve al bajar)' },
        { key='maxLevel', kind='number', label='Nivel máximo', group=G1, default=4,
          min=0, max=200, step=0.25, help='Casillas de agua desde el fondo cuando está arriba del todo' },
        { key='startDelay', kind='number', label='Espera inicial (s)', group=G1, default=3, showIf=cyclic,
          min=0, max=600, step=0.5, help='Tiempo hasta la primera subida (desde que empieza el nivel, o la pelea)' },
        { key='holdTime', kind='number', label='Tiempo arriba (s)', group=G1, default=4, showIf=cyclic,
          min=0, max=600, step=0.5, help='Lo que se queda en el nivel máximo antes de bajar' },
        { key='lowTime', kind='number', label='Tiempo abajo (s)', group=G1, default=4, showIf=cyclic,
          min=0, max=600, step=0.5, help='Lo que se queda en el nivel mínimo antes de volver a subir' },
        { key='riseSpeed', kind='number', label='Velocidad (casillas/s)', group=G2, default=0.5,
          min=0.05, max=20, step=0.05 },
        { key='riseStep', kind='number', label='Escalón (casillas)', group=G2, default=0,
          min=0, max=200, step=0.25, help='0 = sube seguido. Si no, sube de esto en esto con pausas' },
        { key='risePause', kind='number', label='Pausa entre escalones (s)', group=G2, default=1,
          min=0, max=120, step=0.25, showIf=function(p) return (p.riseStep or 0) > 0 end },
        { key='fallSpeed', kind='number', label='Velocidad (casillas/s)', group=G3, default=0.5,
          min=0.05, max=20, step=0.05 },
        { key='fallStep', kind='number', label='Escalón (casillas)', group=G3, default=0,
          min=0, max=200, step=0.25, help='0 = baja seguido. Si no, baja de esto en esto con pausas' },
        { key='fallPause', kind='number', label='Pausa entre escalones (s)', group=G3, default=1,
          min=0, max=120, step=0.25, showIf=function(p) return (p.fallStep or 0) > 0 end },
    },
    editor = { draw = drawIcon },
}
