-- src/world/systems/BeatClock.lua
-- RELOJ DE COMPÁS de los niveles con Bloques Beep (docs/design/beep-blocks.md; tiles en
-- src/world/tiles/types/beepblock.lua). Su tiempo `t` ES la posición de la música del nivel: empieza con ella (al
-- entrar al nivel; online, el tick 0 de la ronda), avanza con ella — también ×Hurry.RATE cuando el ¡date prisa! la
-- acelera — y vuelve a 0 si la música vuelve a empezar (un jugador: tras ahogarse). Cada `period` s de música (4 s =
-- una frase de la canción, 8 pulsos a 120 BPM) cambian los bloques: rosa sólido ↔ cian sólido.
--
-- Quién hace qué (las 3 partes de la regla de oro 1):
--   un jugador  BeatClock.update cada fotograma (también durante la tarjeta y la cuenta atrás: la música ya suena)
--               + BeatClock.audio (los 3 beeps, el golpe del cambio y la música atada al reloj)
--   servidor    BeatClock.update cada tick (desde el tick 0, como la música de los clientes); decide los tiles
--               (cambio 'set' → evento `tile`) y manda `t` en la instantánea (`bt`, centésimas)
--   cliente     BeatClock.update con su dt (no cambia tiles: canBreak = false) + BeatClock.netApply(bt) lo corrige
--               + BeatClock.audio
-- El PARPADEO de cada beep (BeatClock.blink) es solo dibujo: en los pulsos 6, 7 y 8 de la frase cada bloque se ve un
-- momento en el OTRO estado, sin cambiar su colisión (el usuario, 2026-11-14).
local BeatClock = {}

BeatClock.PERIOD = 4          -- s de música entre cambios (una frase de 2 compases a 120 BPM)
BeatClock.BEEPS  = 3          -- beeps de aviso: los últimos pulsos de la frase (6, 7 y 8 de 8)
BeatClock.BEATS  = 8          -- pulsos por frase
BeatClock.BLINK  = 0.18       -- s de música que dura cada parpadeo (desde el beep)
BeatClock.SYNC_TOL = 0.05     -- s: la música se recoloca si se separa del reloj más que esto
BeatClock.SYNC_EVERY = 0.5    -- s entre comprobaciones de la música

local function hasBeepTiles(level)
    local TileTypes = require 'src/world/tiles/TileTypes'
    for r = 1, level.tileH do
        local row = level.tiles[r]
        for c = 1, level.tileW do
            local raw = row[c]
            if raw and raw ~= 0 then
                local sb = level:getDef(c, r).switchBlock
                if sb and sb.beat then return true end
            end
        end
    end
    return false
end

-- Desde Level.fromData (antes de initSwitchBlocks). JSON opcional: "beat": { "period": 4, "start": "pink" }.
function BeatClock.build(level, lvl)
    if not hasBeepTiles(level) then return nil end
    local b = type(lvl.beat) == 'table' and lvl.beat or {}
    local period = tonumber(b.period) or BeatClock.PERIOD
    if period <= 0 then period = BeatClock.PERIOD end
    return { t = 0, period = period, start = (b.start == 'cyan') and 'cyan' or 'pink' }
end

-- Frase en la que va el reloj (0, 1, 2...) y el color sólido en ella
local function phraseOf(bc, t) return math.floor((t or bc.t) / bc.period) end
function BeatClock.solid(level)
    local bc = level.beat
    if not bc then return nil end
    local even = phraseOf(bc) % 2 == 0
    if bc.start == 'pink' then return even and 'pink' or 'cyan' end
    return even and 'cyan' or 'pink'
end

-- ¿Quiere estar sólido un bloque de este `kind` ('beep_pink' | 'beep_cyan')? (Level:updateSwitchBlocks)
function BeatClock.wants(level, kind)
    return ('beep_' .. (BeatClock.solid(level) or 'pink')) == kind
end

-- La velocidad de la música: ×Hurry.RATE desde que acaba el jingle del ¡date prisa! (`timeLeft` = lo que queda del
-- límite del nivel; nil = sin ¡date prisa!)
function BeatClock.rate(timeLeft)
    return require('src/audio/Hurry').rateAt(timeLeft)
end

-- Avanza el reloj; si cambia de frase, los bloques cambian (solo donde se deciden los tiles).
function BeatClock.update(level, dt, timeLeft)
    local bc = level.beat
    if not bc or not dt or dt <= 0 then return end
    local before = phraseOf(bc)
    bc.rate = BeatClock.rate(timeLeft)
    bc.t = bc.t + dt * bc.rate
    if phraseOf(bc) ~= before and level.canBreak ~= false then level:updateSwitchBlocks() end
end

-- La música volvió a empezar desde el principio: el reloj con ella
function BeatClock.reset(level)
    local bc = level.beat
    if not bc then return end
    local before = phraseOf(bc)
    bc.t = 0
    if phraseOf(bc) ~= before and level.canBreak ~= false then level:updateSwitchBlocks() end
end

-- ── Red ───────────────────────────────────────────────────────────────────────────────────────────────────────
function BeatClock.netPack(level)
    local bc = level.beat
    return bc and math.floor(bc.t * 100 + 0.5) or nil
end
-- `lead` = s que la instantánea llega tarde (medio ping): el reloj del servidor ya va por delante
function BeatClock.netApply(level, bt, lead)
    local bc = level.beat
    if not (bc and type(bt) == 'number') then return end
    local t = bt / 100 + (lead or 0) * (bc.rate or 1)
    if math.abs(t - bc.t) > 0.06 then bc.t = t end      -- (lo pequeño, no: el avance local ya va bien y no tiembla)
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────────────────────────────────────
-- ¿Parpadean ahora los bloques? (un momento tras cada beep: se dibujan en el otro estado)
function BeatClock.blink(level)
    local bc = level.beat
    if not bc then return false end
    local beat = bc.period / BeatClock.BEATS
    local pos = bc.t % bc.period
    local first = (BeatClock.BEATS - BeatClock.BEEPS) * beat
    if pos < first then return false end
    return (pos - first) % beat < BeatClock.BLINK
end

-- ── Sonido (un jugador y el cliente; el servidor no suena) ───────────────────────────────────────────────────
-- Los beeps y el golpe del cambio, por los instantes que el reloj cruzó desde la última llamada; y la música del
-- nivel, atada al reloj. `st` = una tabla del estado (guarda lo suyo).
function BeatClock.audio(level, st, dt)
    local bc = level.beat
    if not bc then return end
    local prev = st.beatPrev
    st.beatPrev = bc.t
    if prev and bc.t > prev and bc.t - prev < 1 then
        local beat = bc.period / BeatClock.BEATS
        local k0, k1 = math.floor(prev / beat), math.floor(bc.t / beat)
        for k = k0 + 1, k1 do
            local i = k % BeatClock.BEATS                     -- (0 = el pulso 1 de la frase: el cambio)
            local pitch = bc.rate or 1                        -- (con la música acelerada, también más agudo)
            if i == 0 then Sound.play('beepSwitch', pitch)
            elseif i >= BeatClock.BEATS - BeatClock.BEEPS then Sound.play('beepWarn', pitch) end
        end
    end
    st.beatSyncT = (st.beatSyncT or 0) - (dt or 0)
    if st.beatSyncT <= 0 then
        st.beatSyncT = BeatClock.SYNC_EVERY
        Sound.syncMusic('level', bc.t, BeatClock.SYNC_TOL)
    end
end

return BeatClock
