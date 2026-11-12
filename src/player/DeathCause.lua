-- src/player/DeathCause.lua
-- DE QUÉ HA MUERTO el jugador (0.5.200, docs/design/ux-round-2026-11.md): no hay pantalla de muerte, así que al
-- reaparecer una línea con una calavera lo dice unos segundos (src/ui/DeathBanner.lua). Se mira EN EL MOMENTO de morir,
-- con lo que hay alrededor; solo datos (sin dibujo): lo usan un jugador y el cliente online (cada uno el suyo).
--   DeathCause.of(pa, level, entities, flags) → { kind = 'drown' | 'time' | 'fall' | 'lava' | 'spikes' | 'enemy' | 'hit',
--                                                 name = nombre del enemigo (ya traducido) }
--   flags = { drown = true (ahogado), force = true (muerte forzada: el tiempo, quedarse atrás) }
local L = require 'src/core/Lang'
local DC = {}

-- Nombre del enemigo en el idioma del jugador: `enemy.<familia>` (gummy_ice → gummy, crabby_river → crabby); los jefes,
-- con su nombre propio (Lang.bossName)
function DC.enemyName(e)
    local d = e and e.def
    if not d then return nil end
    if d.boss or d.category == 'Jefes' then return L.bossName(d.name, e.props) end
    for _, k in ipairs({ d.name, (d.name or ''):match('^(%a+)') }) do
        if k and L.has('enemy.' .. k) then return L('enemy.' .. k) end
    end
    return nil
end

local function boxOf(e)
    if e.getOuterBounds then return e:getOuterBounds() end
    local w, h = e.outerW or TILE_PX, e.outerH or TILE_PX
    return { x = (e.x or 0) - w / 2, y = (e.y or 0) - h / 2, w = w, h = h }
end

-- (las causas sin entidad: su frase `death.<kind>`)
local CAUSE_KIND = { drown = 'drown', time = 'time', fall = 'fall', crush = 'crush', explosion = 'explosion',
                     spikes = 'spikes', danger = 'lava' }

function DC.of(pa, level, entities, flags)
    flags = flags or {}
    -- LA FUENTE del último golpe (0.5.205, src/player/DamageSource.lua): lo que de verdad lo mató, sin adivinar
    local src = pa.lastHit
    if src and src.what then
        if CAUSE_KIND[src.what] then return { kind = CAUSE_KIND[src.what] } end
        local text = require('src/player/DamageSource').text(src)
        if text then return { kind = 'enemy', name = text } end
    end
    -- (sin fuente — algo que aún no la pasa —: se mira alrededor, como antes)
    if flags.drown or pa.drownDead then return { kind = 'drown' } end
    if flags.force then return { kind = 'time' } end
    local T = TILE_PX
    local ob = pa:getOuterBounds()
    if level then
        if pa.y > (level.heightPx or level.tileH * T) - T * 0.5 then return { kind = 'fall' } end
        local pad = 6
        local c0, c1 = math.floor((ob.x - pad) / T) + 1, math.floor((ob.x + ob.w + pad) / T) + 1
        local r0, r1 = math.floor((ob.y - pad) / T) + 1, math.floor((ob.y + ob.h + pad) / T) + 1
        for r = r0, r1 do for c = c0, c1 do
            local d = level:getDef(c, r)
            if d and d.name == 'danger' then return { kind = 'lava' } end
        end end
        if level:hasSpikeCellInBox(ob.x - pad, ob.y - pad, ob.w + 2 * pad, ob.h + 2 * pad) then return { kind = 'spikes' } end
    end
    -- el enemigo más cerca que lo tocaba (o casi)
    local best, bd
    local cx, cy = ob.x + ob.w / 2, ob.y + ob.h / 2
    for _, e in pairs(entities or {}) do
        local d = e.def
        if d and (d.category == 'Enemigos' or d.category == 'Jefes' or d.boss) and e.alive ~= false then
            local b = boxOf(e)
            local dx = math.max(0, math.max(b.x - (ob.x + ob.w), ob.x - (b.x + b.w)))
            local dy = math.max(0, math.max(b.y - (ob.y + ob.h), ob.y - (b.y + b.h)))
            local dist = dx + dy
            if dist < T * 1.2 and (not bd or dist < bd) then best, bd = e, dist end
        end
    end
    if best then return { kind = 'enemy', name = DC.enemyName(best) } end
    return { kind = 'hit' }
end

return DC
