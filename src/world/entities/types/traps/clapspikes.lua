-- PINCHOS DE PALMAS (Vía Estelar, docs/design/starway-rhythm-objects.md): una PLACA de una casilla (sólida como un
-- bloque) de la que salen dos pinchos del juego (los de siempre, con el aspecto del nivel: SpikeSkins) hacia arriba,
-- en los pulsos 2 y 4 de cada compás — con la caja de la música — y se esconden en el 1 y el 3. Medio pulso antes de
-- salir, la franja de la placa se enciende y echa chispas (el aviso). Fuera, dañan como los pinchos de casilla (la
-- misma caja: Level._spikeHitbox). `offset` = 1 los adelanta un pulso (salen en el 1 y el 3), para alternar placas.
-- Todo es FUNCIÓN del reloj de compás (src/world/systems/BeatClock.lua): igual en los tres sitios, sin red.
-- Arte: la placa de tools/art/world/make_starway_objects.py (assets/anim/traps/clapspikes.json).
local Entity     = require 'src/world/entities/base/Entity'
local BeatClock  = require 'src/world/systems/BeatClock'
local SpikeSkins = require 'src/world/level/SpikeSkins'

local T, H = TILE_PX, TILE_PX / 2
local C = Entity.extend(Entity, { debugColor = { 1, 0.4, 0.6 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

C.animId = 'traps/clapspikes'
C.wantsLevel = true
C.RISE = 0.12                     -- parte del pulso que tardan en salir (solo dibujo; dañan desde el principio)
C.HIDDEN = 8                      -- px de punta que asoman escondidos
C.WARN = 0.5                      -- desde esta parte del pulso de antes, el aviso

function C.loadAssets() C.anims(C) end
function C.sizePx() return T, T end

function C:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
end

-- Estado ahora: 'up' (fuera), 'warn' (escondidos, avisando) o 'down'; y la parte del pulso que va
function C.stateAt(beats, offset)
    local n = math.floor(beats)
    local f = beats - n
    local out = (n + (offset or 0)) % 2 == 1
    if out then return 'up', f end
    return (f >= C.WARN) and 'warn' or 'down', f
end
function C:clap()
    return C.stateAt(BeatClock.beats(self.levelRef), self.props.offset or 0)
end

-- Sólida como un bloque (la placa)
C.solidFull = true
function C:isSolidBody() return self.alive end
function C:getOuterBounds(into) return Entity.box(into, (self.col - 1) * T, (self.row - 1) * T, T, T) end
C.getInnerBounds = C.getOuterBounds
function C:canBeStomped() return false end
function C:canBeKnocked() return false end
function C:canFreeze() return false end
function C:canBeLaunched() return false end
function C:isObstacle() return true end

-- Fuera: dos pinchos de media casilla encima de la placa (la caja de los pinchos de casilla)
local LevelMod
function C:getHazardBoxes()
    if self:clap() ~= 'up' then return nil end
    LevelMod = LevelMod or package.loaded['src/world/level/Level'] or require('src/world/level/Level')
    local hb = self._hb
    if not hb then hb = { { part = 'spike' }, { part = 'spike' } }; self._hb = hb end
    local x0, y0 = (self.col - 1) * T, (self.row - 1) * T - H
    for i = 1, 2 do
        local b = hb[i]
        b.x, b.y, b.w, b.h = LevelMod._spikeHitbox(x0 + (i - 1) * H, y0, H, 0)      -- 0 = DIR_UP
    end
    return hb
end

function C:updateCustom(dt, level)
    self.levelRef = level or self.levelRef
    return true
end

function C:netAtRest() return true end
function C:netRest() end

function C:debugBoxes()
    local out = { { x = (self.col - 1) * T, y = (self.row - 1) * T, w = T, h = T, kind = 'area' } }
    for _, b in ipairs(self:getHazardBoxes() or {}) do out[#out + 1] = { x = b.x, y = b.y, w = b.w, h = b.h } end
    return out
end

function C:render(camX, camY)
    local st, f = self:clap()
    local x, y = math.floor((self.col - 1) * T - camX), math.floor((self.row - 1) * T - camY)
    local rise = C.HIDDEN
    if st == 'up' then rise = C.HIDDEN + (H - C.HIDDEN) * math.min(1, f / C.RISE) end
    if st == 'warn' then rise = C.HIDDEN + 2 end
    love.graphics.setColor(1, 1, 1, 1)
    local skin = self.levelRef and self.levelRef.spikeSkin
    local k = H / SpikeSkins.width(skin)
    for i = 0, 1 do SpikeSkins.draw(skin, x + i * H, y - math.floor(rise), 0, k, k) end
    C.anims(C):draw(st == 'warn' and 'glint' or 'idle', 0, x + T / 2, y + T / 2, 0, 4, 4, 0.5, 0.5)
end

return {
    name = 'clapspikes', label = 'Pinchos de palmas', category = 'Trampas', class = C, beat = true,
    description = 'Placa de la que salen pinchos en los pulsos 2 y 4 de cada compás, con la caja de la música (Vía Estelar).',
    defaults = { movement = 'static' },
    props = {
        { key = 'offset', kind = 'int', label = 'Adelanto (pulsos)', group = 'Pinchos de palmas', default = 0, min = 0, max = 1,
          help = '0 = salen en los pulsos 2 y 4; 1 = en el 1 y el 3 (para alternar placas)' },
    },
    editor = { sprite = 'assets/images/traps/clapspikes/plate.png' },
}
