-- PLATAFORMA METRÓNOMO (Vía Estelar, docs/design/starway-rhythm-objects.md): una losa de cristal de 2 casillas de
-- ancho y media de alto que avanza UNA casilla en cada pulso de la música, de golpe (SNAP del pulso), `steps` casillas
-- hacia `dir` y otras tantas de vuelta (4 + 4 = una frase de 8 pulsos). Su lámpara se enciende en el pulso.
-- Su posición es FUNCIÓN del reloj de compás (src/world/systems/BeatClock.lua), así que un jugador, el servidor y el
-- cliente la calculan igual sin mandar nada (netAtRest siempre). Es un cuerpo que se mueve (`bodyParts`, `moves`):
-- los jugadores van encima con `standBody` (docs/gameplay/carry-and-push.md); por defecto solo se pisa por arriba.
-- Arte: tools/art/world/make_starway_objects.py (assets/anim/mechanisms/metronome.json).
local Entity    = require 'src/world/entities/base/Entity'
local BeatClock = require 'src/world/systems/BeatClock'

local T = TILE_PX
local M = Entity.extend(Entity, { debugColor = { 0.7, 0.6, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

M.animId = 'mechanisms/metronome'
M.wantsLevel = true
M.SNAP = 0.16                     -- parte del pulso que tarda en dar el paso (0,08 s a 120 BPM): el resto, quieta
M.LIT = 0.3                       -- parte del pulso con la lámpara encendida
local DIRS = { right = { 1, 0 }, left = { -1, 0 }, up = { 0, -1 }, down = { 0, 1 } }

function M.loadAssets() M.anims(M) end
function M.sizePx() return 2 * T, T / 2 end

-- Casillas desde su sitio (con decimales mientras da el paso) a `beats` pulsos
function M.offsetAt(steps, beats)
    steps = math.max(1, steps)
    local n = math.floor(beats)
    local e = math.min(1, (beats - n) / M.SNAP)
    e = e * e * (3 - 2 * e)
    local k = n % (2 * steps)
    if k < steps then return k + e end
    return 2 * steps - k - e
end

function M:offset()
    return M.offsetAt(self.props.steps or 4, BeatClock.beats(self.levelRef))
end

-- La losa (la esquina de arriba a la izquierda de su casilla es su sitio)
function M:slab(into)
    local d = DIRS[self.props.dir or 'right'] or DIRS.right
    local o = self:offset()
    local b = into or {}
    b.x = (self.col - 1) * T + d[1] * o * T
    b.y = (self.row - 1) * T + d[2] * o * T
    b.w, b.h = 2 * T, T / 2
    return b
end

function M:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    local owner = self
    local part = { owner = self, solidFull = true, moves = true, alive = true, oneway = self.props.oneway ~= false }
    function part:getOuterBounds(into) return owner:slab(into) end
    self.parts = { part }
end
function M:bodyParts() return self.parts end
function M:getOuterBounds(into) return self:slab(into) end
M.getInnerBounds = M.getOuterBounds
function M:canBeStomped() return false end
function M:canBeKnocked() return false end
function M:canFreeze() return false end
function M:canBeLaunched() return false end
function M:isObstacle() return false end
function M:isGhost() return true end
function M:interact() return nil end

function M:updateCustom(dt, level)
    self.levelRef = level or self.levelRef
    return true
end

-- Red: nada que mandar (la posición sale del reloj de compás, que ya viaja en `bt`)
function M:netAtRest() return true end
function M:netRest() end
-- (el cliente: que el recorrido entero cuente para saber si está cerca)
function M:netBounds()
    local s, d = self.props.steps or 4, DIRS[self.props.dir or 'right'] or DIRS.right
    local x0, y0 = (self.col - 1) * T, (self.row - 1) * T
    local x1, y1 = x0 + d[1] * s * T, y0 + d[2] * s * T
    return math.min(x0, x1), math.min(y0, y1), math.max(x0, x1) + 2 * T, math.max(y0, y1) + T / 2
end

function M:debugBoxes()
    local b = self:slab({})
    return { { x = b.x, y = b.y, w = b.w, h = b.h, kind = 'area' } }
end

function M:render(camX, camY)
    local b = self:slab()
    local beats = BeatClock.beats(self.levelRef)
    local lit = self.levelRef and self.levelRef.beat and (beats - math.floor(beats)) < M.LIT
    love.graphics.setColor(1, 1, 1, 1)
    M.anims(M):draw(lit and 'lit' or 'idle', 0, math.floor(b.x + b.w / 2 - camX), math.floor(b.y + b.h / 2 - camY), 0, 4, 4, 0.5, 0.5)
end

return {
    name = 'metronome', label = 'Plataforma metrónomo', category = 'Mecanismos', class = M, beat = true,
    description = 'Losa de cristal de 2 casillas que avanza una casilla en cada pulso de la música y vuelve (Vía Estelar).',
    defaults = { movement = 'static' },
    props = {
        { key = 'steps', kind = 'int', label = 'Casillas', group = 'Metrónomo', default = 4, min = 1, max = 8,
          help = 'Casillas que avanza (una por pulso) antes de volver: 4 = una frase de ida y vuelta' },
        { key = 'dir', kind = 'enum', label = 'Dirección', group = 'Metrónomo', default = 'right',
          options = { { value = 'right', label = 'Derecha' }, { value = 'left', label = 'Izquierda' },
                      { value = 'up', label = 'Arriba' }, { value = 'down', label = 'Abajo' } } },
        { key = 'oneway', kind = 'bool', label = 'Solo por arriba', group = 'Metrónomo', default = true,
          help = 'Se atraviesa desde abajo y de lado (como una plataforma); sin marcar, es sólida por todos lados' },
    },
    editor = { sprite = 'assets/images/mechanisms/metronome/platform.png' },
}
