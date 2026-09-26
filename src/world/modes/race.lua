-- Carrera Relámpago: el primero en tocar la meta activa una cuenta atrás de
-- GRACE segundos para el resto. Al acabar (o cuando nadie más puede llegar),
-- ganan solo los que llegaron, ordenados por orden de llegada.
local GRACE = 15

return {
    id = 'race', label = 'Carrera Relámpago', icon = 'flag',
    tagline = 'Corre hasta la meta. Cuando llegue el primero, el resto tendrá 15 segundos.',
    color = { 0.35, 0.85, 1.0 },
    triggers = { 'finish' },

    requires = function(info)
        if info.finish > 0 then return true end
        return false, 'el nivel no tiene meta (tile Meta)'
    end,

    start = function(m) m.data.arrived = 0 end,

    onTrigger = function(m, ps, name)
        if name ~= 'finish' or ps.finished then return end
        m.data.arrived = m.data.arrived + 1
        ps.finished   = true
        ps.place      = m.data.arrived
        ps.finishTime = m.time
        ps.isSpectator = true              -- sale de la partida: ya llegó
        if ps.place == 1 then m.data.deadline = m.time + GRACE end
        m.event({ type = 'finish', playerId = ps.id, place = ps.place, time = m.time })
    end,

    tick = function(m)
        if m.data.arrived > 0 then
            local all = true
            for _, ps in pairs(m.players) do if not ps.finished then all = false; break end end
            if all then return 'all_finished' end
        end
        if m.data.deadline and m.time >= m.data.deadline then return 'time_up' end
    end,

    hud = function(m)
        if m.data.deadline then
            return { cd = math.max(0, math.floor((m.data.deadline - m.time) * 100 + 0.5)) }
        end
    end,

    rank = function(m, entries)
        table.sort(entries, function(a, b)
            if a.finished ~= b.finished then return a.finished end
            if a.finished then return a.place < b.place end
            if a.score ~= b.score then return a.score > b.score end
            return (a.order or 0) < (b.order or 0)
        end)
        for _, e in ipairs(entries) do e.winner = e.finished end
    end,

    reasonText = function(reason)
        if reason == 'all_finished' then return '¡Todos cruzaron la meta!' end
        if reason == 'time_up' then return '¡Se acabó la cuenta atrás!' end
        if reason == 'all_out' then return 'Ya no queda nadie en carrera' end
    end,
}
