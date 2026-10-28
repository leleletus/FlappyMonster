-- src/world/systems/Weight.lua
-- EL PESO de lo que está encima de algo, APILADO incluido (el usuario: una caja con algo encima pesa las dos cosas).
-- Una sola regla para todo lo que pesa cosas: el platillo de la Balanza, lo que levanta el chorro del Géiser…
--   * un jugador pesa 1 (+ lo que lleva en las manos); una entidad, su `weight` (1 si no dice nada: la Caja grande 2,
--     la pequeña 1, la Semilla 0,5); lo que VUELA, lo que va en las manos de alguien, los jefes y los fantasmas, nada
--     — salvo el jefe que va en la Balanza (`ridesScale`): pesa su `weight` (0.5.84, el usuario: de pie en un platillo
--     no lo bajaba) —.
--   * encima de X = jugadores de pie en X (`standBody`) y entidades con los pies en su cara de arriba; y lo que esté
--     encima de esas, y así hacia arriba.
-- Simulación (un jugador / servidor): mira level.players y level.liveEntities.
local Weight = {}

local ON_TOP = 4                 -- px: "apoyado" en una cara
local B = {}

function Weight.ofPlayer(pa)
    local c = pa.carrying
    return 1 + ((c and (c.weight or 1)) or 0)
end
function Weight.ofEntity(e) return e.weight or 1 end

-- ¿Cuenta como peso? (`except` = quien pesa: no se pesa a sí mismo)
function Weight.counts(e, except)
    return e ~= except and e.alive and not e.flying and e.state ~= 'carried' and not (e.isGhost and e:isGhost())
           and not (e.def and e.def.boss and not e.ridesScale)
end

local function restsOn(e, b)
    local eb = e:getOuterBounds()
    local foot = eb.y + eb.h
    return foot >= b.y - ON_TOP and foot <= b.y + ON_TOP and eb.x + eb.w > b.x and eb.x < b.x + b.w
end

-- Lo que hay ENCIMA de `base` (un cuerpo, una entidad o un jugador: algo con getOuterBounds), apilado incluido →
-- jugadores, entidades, peso total de todo eso (sin contar `base`)
function Weight.stack(base, level, except)
    local players, ents, w = {}, {}, 0
    local seen = { [base] = true }
    local frontier = { base }
    while #frontier > 0 do
        local cur = table.remove(frontier)
        local b = cur:getOuterBounds(B)
        b = { x = b.x, y = b.y, w = b.w, h = b.h }
        for _, pa in ipairs(level.players or {}) do
            if not seen[pa] and not pa.dying and pa.standBody == cur then
                seen[pa] = true
                players[#players + 1] = pa
                w = w + Weight.ofPlayer(pa)
                frontier[#frontier + 1] = pa                 -- (una caja apoyada en su cabeza también pesa)
            end
        end
        for _, e in ipairs(level.liveEntities or {}) do
            if not seen[e] and Weight.counts(e, except) and restsOn(e, b) then
                seen[e] = true
                ents[#ents + 1] = e
                w = w + Weight.ofEntity(e)
                frontier[#frontier + 1] = e
            end
        end
    end
    return players, ents, w
end

-- Peso de `o` (jugador si `isPlayer`, si no entidad) con todo lo que lleva encima
function Weight.total(o, level, isPlayer, except)
    local own = isPlayer and Weight.ofPlayer(o) or Weight.ofEntity(o)
    local _, _, w = Weight.stack(o, level, except)
    return own + w
end

return Weight
