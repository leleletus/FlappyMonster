-- Rey de la Colina: partida con tiempo. Quien esté dentro de una Zona de
-- puntos (entidad 'pointarea') suma puntos cada cierto tiempo. Al acabar el
-- tiempo gana quien tenga más puntos; empates: más vidas y luego quien llegó
-- antes a esa puntuación. Si solo queda uno en pie, gana él (regla genérica
-- 'last_standing' del servidor) y, si caen todos, gana el que más puntos tenía.
local L = require 'src/Lang'

local DEFAULT_TIME = 100        -- s: poco más de 1:30 (el usuario); el nivel puede cambiarlo: "matchTime"

local function timeLeft(m) return math.max(0, (m.data.duration or DEFAULT_TIME) - m.time) end

return {
    -- Textos (nombre, tagline, objetivo, emptyHint): assets/lang, claves mode.koth.*
    id = 'koth', icon = 'hill',
    color = { 1.0, 0.78, 0.22 },
    hudLine = function(md)
        if not md.tl then return nil end
        local secs = md.tl / 100
        local txt = L('mode.koth.time', { m = math.floor(secs / 60), s = string.format('%02d', math.floor(secs) % 60) })
        if secs <= 10 then return txt, true, tostring(math.ceil(secs)) end
        return txt, false
    end,
    DEFAULT_TIME = DEFAULT_TIME,

    requires = function(info)
        if (info.pointAreas or 0) > 0 then return true end
        return false, L('mode.why.no_point_areas')
    end,

    start = function(m)
        m.data.duration = (m.level and m.level.matchTime) or DEFAULT_TIME
    end,

    tick = function(m)
        if timeLeft(m) <= 0 then return 'time_up' end
    end,

    hud = function(m) return { tl = math.floor(timeLeft(m) * 100 + 0.5) } end,

    rank = function(m, entries, reason)
        table.sort(entries, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            if a.lives ~= b.lives then return a.lives > b.lives end
            if a.scoreT ~= b.scoreT then return a.scoreT < b.scoreT end
            return (a.order or 0) < (b.order or 0)
        end)
        local top = entries[1]
        if not top or top.score <= 0 then return nil end       -- nadie puntuó: no hay ganador
        local tied, note = 0, nil
        for _, e in ipairs(entries) do
            e.winner = (e.score == top.score and e.lives == top.lives and e.scoreT == top.scoreT)
            if e.winner then tied = tied + 1 end
        end
        local second = entries[2]
        if tied > 1 then
            note = 'mode.koth.tie_all'
        elseif second and second.score == top.score then
            note = (second.lives ~= top.lives) and 'mode.tie_lives' or 'mode.tie_time'
        end
        return note, tied > 1
    end,

    reasonText = function(reason)
        if reason == 'time_up' then return 'mode.koth.time_up' end
        if reason == 'all_out' then return 'mode.koth.all_out' end
    end,
}
