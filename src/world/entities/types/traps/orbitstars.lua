-- ESTRELLAS EN ÓRBITA (Vía Estelar, docs/design/starway-rhythm-objects.md #9; 0.5.230): de 1 a 4 estrellas de
-- pinchos que giran alrededor de un eje de cristal a `radius` casillas, AL COMPÁS: por defecto una vuelta por FRASE
-- (8 pulsos; 0.5.232 — antes una por compás: «increíblemente difíciles, un martirio», el usuario —) y a golpes — en
-- cada pulso avanzan un octavo de vuelta en un momento (SNAP) y se quedan quietas el resto —: se aprende y se pasa
-- cuando el hueco está de tu lado. `motion = 'smooth'` = giran sin parar (la misma vuelta). Tocarlas daña como un pincho.
-- El eje no es sólido (solo dibujo); su lámpara se enciende en el pulso; unos puntos marcan el camino de la órbita.
-- Todo es FUNCIÓN del reloj de compás (src/world/systems/BeatClock.lua): igual en un jugador, servidor y cliente, sin red.
-- Arte: tools/art/world/make_starway_orbit.py (assets/anim/traps/orbitstars.json).
local Entity    = require 'src/world/entities/base/Entity'
local BeatClock = require 'src/world/systems/BeatClock'

local T = TILE_PX
local O = Entity.extend(Entity, { debugColor = { 0.8, 0.8, 1 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

O.animId = 'traps/orbitstars'
O.wantsLevel = true
O.SNAP = 0.22                     -- parte del pulso que tardan en dar su paso (a golpes)
O.LIT = 0.3                       -- parte del pulso con la lámpara encendida
O.BOX = 36                        -- px: lado de la caja que daña de cada estrella (el núcleo y el arranque de las puntas)
O.DOTS = 6                        -- puntos del camino por casilla de radio

function O.loadAssets() O.anims(O) end
function O.sizePx() return T, T end

function O:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
end

-- Ángulo (radianes; 0 = arriba, a favor del reloj) de la estrella 1 a `beats` pulsos
function O.angleAt(beats, p)
    p = p or {}
    local per = math.max(1, p.beatsPerTurn or 8)
    local step
    if p.motion == 'smooth' then
        step = beats
    else
        local n = math.floor(beats)
        local e = math.min(1, (beats - n) / O.SNAP)
        step = n + e * e * (3 - 2 * e)
    end
    local a = 2 * math.pi * (step + (p.phase or 0)) / per
    if p.dir == 'ccw' then a = -a end
    return a
end

function O:center() return (self.col - 0.5) * T, (self.row - 0.5) * T end
function O:count() return math.max(1, math.min(4, self.props.count or 2)) end

-- Centro de la estrella i (1..count) ahora
function O:starPos(i, beats)
    local a = O.angleAt(beats or BeatClock.beats(self.levelRef), self.props) + (i - 1) * 2 * math.pi / self:count()
    local cx, cy = self:center()
    local r = (self.props.radius or 2) * T
    return cx + r * math.sin(a), cy - r * math.cos(a)
end

function O:getOuterBounds(into) return Entity.box(into, (self.col - 1) * T, (self.row - 1) * T, T, T) end
O.getInnerBounds = O.getOuterBounds
-- (dañan SOLO sus estrellas — getHazardBoxes, que mira Interactions.defaultCheck —; el eje no tiene cuerpo. Antes era
-- un `isGhost` con `interact` vacío y Interactions.check se lo saltaba entero: no dañaban — el usuario, 2026-11-15 —)
function O:isBodyDisabled() return true end
function O:canBeStomped() return false end
function O:canBeKnocked() return false end
function O:canFreeze() return false end
function O:canBeLaunched() return false end
function O:isObstacle() return true end

function O:getHazardBoxes()
    local hb = self._hb
    local n = self:count()
    if not hb or #hb ~= n then
        hb = {}
        for i = 1, n do hb[i] = { part = 'hazard' } end
        self._hb = hb
    end
    local beats = BeatClock.beats(self.levelRef)
    for i = 1, n do
        local x, y = self:starPos(i, beats)
        local b = hb[i]
        b.x, b.y, b.w, b.h = x - O.BOX / 2, y - O.BOX / 2, O.BOX, O.BOX
    end
    return hb
end

function O:updateCustom(dt, level)
    self.levelRef = level or self.levelRef
    return true
end

-- Red: nada que mandar (todo sale del reloj de compás, que ya viaja en `bt`)
function O:netAtRest() return true end
function O:netRest() end
function O:netBounds()
    local cx, cy = self:center()
    local r = (self.props.radius or 2) * T + T
    return cx - r, cy - r, cx + r, cy + r
end

function O:debugBoxes()
    local out = { { x = (self.col - 1) * T, y = (self.row - 1) * T, w = T, h = T, kind = 'area' } }
    for _, b in ipairs(self:getHazardBoxes() or {}) do out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h } end
    return out
end

function O:render(camX, camY)
    local A = O.anims(O)
    local cx, cy = self:center()
    local r = (self.props.radius or 2) * T
    local beats = BeatClock.beats(self.levelRef)
    local lit = self.levelRef and self.levelRef.beat and (beats - math.floor(beats)) < O.LIT
    love.graphics.setColor(1, 1, 1, 1)
    -- el camino (puntos fijos)
    local nd = math.max(8, math.floor((self.props.radius or 2) * O.DOTS + 0.5))
    for k = 0, nd - 1 do
        local a = 2 * math.pi * k / nd
        A:draw('dot', 0, math.floor(cx + r * math.sin(a) - camX), math.floor(cy - r * math.cos(a) - camY), 0, 4, 4, 0.5, 0.5)
    end
    A:draw(lit and 'lit' or 'idle', 0, math.floor(cx - camX), math.floor(cy - camY), 0, 4, 4, 0.5, 0.5)
    for i = 1, self:count() do
        local x, y = self:starPos(i, beats)
        A:draw(lit and 'star_lit' or 'star', 0, math.floor(x - camX), math.floor(y - camY), 0, 4, 4, 0.5, 0.5)
    end
end

local function editorIcon(x, y, s)
    O.loadAssets()
    love.graphics.setColor(1, 1, 1, 1)
    local A = O.anims(O)
    A:draw('idle', 0, x + s / 2, y + s / 2, 0, s / 32, s / 32, 0.5, 0.5)
    A:draw('star', 0, x + s / 2, y + s * 0.22, 0, s / 40, s / 40, 0.5, 0.5)
    A:draw('star', 0, x + s / 2, y + s * 0.78, 0, s / 40, s / 40, 0.5, 0.5)
end

return {
    name = 'orbitstars', label = 'Estrellas en órbita', category = 'Trampas', class = O, beat = true,
    description = 'Estrellas de pinchos que giran alrededor de un eje al compás: una vuelta por frase, a golpes en cada pulso (Vía Estelar).',
    defaults = { movement = 'static' },
    props = {
        { key = 'count', kind = 'int', label = 'Estrellas', group = 'Estrellas en órbita', default = 2, min = 1, max = 4,
          help = 'Repartidas por igual en la órbita' },
        { key = 'radius', kind = 'number', label = 'Radio (casillas)', group = 'Estrellas en órbita', default = 2,
          min = 1, max = 6, step = 0.5 },
        { key = 'beatsPerTurn', kind = 'int', label = 'Pulsos por vuelta', group = 'Estrellas en órbita', default = 8,
          min = 2, max = 16, help = '8 = una vuelta por frase (cuando cambian los Bloques Beep: un octavo por pulso); 4 = una por compás (el doble de rápido)' },
        { key = 'dir', kind = 'enum', label = 'Sentido', group = 'Estrellas en órbita', default = 'cw',
          options = { { value = 'cw', label = 'Como el reloj' }, { value = 'ccw', label = 'Al revés' } } },
        { key = 'motion', kind = 'enum', label = 'Movimiento', group = 'Estrellas en órbita', default = 'snap',
          options = { { value = 'snap', label = 'A golpes (un paso por pulso)' }, { value = 'smooth', label = 'Seguido' } } },
        { key = 'phase', kind = 'number', label = 'Desfase (pulsos)', group = 'Estrellas en órbita', default = 0,
          min = 0, max = 15, step = 0.5, help = 'Adelanta el giro: para que dos órbitas vecinas no coincidan' },
    },
    editor = { sprite = 'assets/images/traps/orbitstars/star.png', draw = editorIcon },
}
