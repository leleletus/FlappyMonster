-- Rey de la Colina: partida con tiempo. Quien esté dentro de una Zona de
-- puntos (entidad 'pointarea') suma puntos cada cierto tiempo. Al acabar el
-- tiempo gana quien tenga más puntos; empates: más vidas y luego quien llegó
-- antes a esa puntuación. Si solo queda uno en pie, gana él (regla genérica
-- 'last_standing' del servidor) y, si caen todos, gana el que más puntos tenía.
local DEFAULT_TIME = 150        -- s (el nivel puede cambiarlo: "matchTime")

local function timeLeft(m) return math.max(0, (m.data.duration or DEFAULT_TIME) - m.time) end

return {
    id = 'koth', label = 'Rey de la Colina', icon = 'hill',
    tagline = 'Quédate en las zonas de puntos. Cuando se acabe el tiempo, gana quien tenga más puntos.',
    color = { 1.0, 0.78, 0.22 },
    emptyHint = 'Crea uno en el editor con la "Zona de puntos" (Entidades › Mecanismos)',
    DEFAULT_TIME = DEFAULT_TIME,

    requires = function(info)
        if (info.pointAreas or 0) > 0 then return true end
        return false, 'el nivel no tiene zonas de puntos'
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
            note = 'Empate total: comparten la corona'
        elseif second and second.score == top.score then
            note = (second.lives ~= top.lives) and 'Empate a puntos: gana quien conservó más vidas'
                   or 'Empate a puntos y vidas: gana quien llegó antes a esa puntuación'
        end
        return note, tied > 1
    end,

    reasonText = function(reason)
        if reason == 'time_up' then return '¡Se acabó el tiempo!' end
        if reason == 'all_out' then return 'Todos cayeron: gana quien más puntos tenía' end
    end,
}
