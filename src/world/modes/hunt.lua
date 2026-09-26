-- Cazamonstruos: elimina a todos los enemigos pisoteables. Cuando no queda ninguno,
-- gana quien más puntos tenga (empates: ganan todos los empatados). Si todos
-- los jugadores caen antes, nadie gana.
local function killableAlive(m)
    local n = 0
    for _, e in ipairs(m.enemies) do
        if e.props.stompable and e.alive and e.state ~= 'dead' then n = n + 1 end
    end
    return n
end

return {
    id = 'hunt', label = 'Cazamonstruos', icon = 'skull',
    tagline = 'Aplasta a todos los monstruos. Cuando no quede ninguno, gana quien tenga más puntos.',
    color = { 1.0, 0.45, 0.30 },

    requires = function(info)
        if info.killable > 0 then return true end
        return false, 'el nivel no tiene enemigos que se puedan pisotear'
    end,

    tick = function(m)
        if killableAlive(m) == 0 then return 'cleared' end
    end,

    hud = function(m) return { left = killableAlive(m) } end,

    rank = function(m, entries, reason)
        table.sort(entries, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return (a.order or 0) < (b.order or 0)
        end)
        if reason == 'cleared' and entries[1] then
            local top = entries[1].score
            for _, e in ipairs(entries) do e.winner = (e.score == top) end
        end
    end,

    reasonText = function(reason)
        if reason == 'cleared' then return '¡No queda ni un monstruo en pie!' end
    end,
}
