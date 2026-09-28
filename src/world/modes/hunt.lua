-- Cazamonstruos: elimina a todos los enemigos pisoteables. Cuando no queda ninguno,
-- gana quien más puntos tenga (empates: ganan todos los empatados). Si todos
-- los jugadores caen antes, nadie gana.
local L = require 'src/Lang'

local function killableAlive(m)
    local n = 0
    for _, e in ipairs(m.enemies) do
        if e.props.stompable and e.alive and e.state ~= 'dead' then n = n + 1 end
    end
    return n
end

return {
    -- Textos (nombre, tagline, objetivo): assets/lang, claves mode.hunt.*
    id = 'hunt', icon = 'skull',
    color = { 1.0, 0.45, 0.30 },
    -- Línea de estado del panel de objetivo (cliente; md = hud del servidor)
    hudLine = function(md)
        if not md.left then return nil end
        if md.left == 1 then return L('mode.hunt.left_one'), true end
        return L('mode.hunt.left', { n = md.left }), false
    end,

    requires = function(info)
        -- Los niveles con jefe son solo para Carrera
        if (info.bosses or 0) > 0 then return false, L('mode.why.boss') end
        if info.autoScroll then return false, L('mode.why.autoscroll') end
        if (info.pointAreas or 0) > 0 then return false, L('mode.why.point_areas') end
        if info.killable > 0 then return true end
        return false, L('mode.why.no_killable')
    end,

    tick = function(m)
        if killableAlive(m) == 0 then return 'cleared' end
    end,

    hud = function(m) return { left = killableAlive(m) } end,

    -- Desempate: 1) más puntos, 2) más vidas restantes, 3) quien llegó
    -- antes a esa puntuación. Si todo coincide, comparten la victoria.
    rank = function(m, entries, reason)
        table.sort(entries, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            if a.lives ~= b.lives then return a.lives > b.lives end
            if a.scoreT ~= b.scoreT then return a.scoreT < b.scoreT end
            return (a.order or 0) < (b.order or 0)
        end)
        if reason ~= 'cleared' or not entries[1] then return end
        local top, note = entries[1], nil
        local tied = 0
        for _, e in ipairs(entries) do
            e.winner = (e.score == top.score and e.lives == top.lives and e.scoreT == top.scoreT)
            if e.winner then tied = tied + 1 end
        end
        local second = entries[2]
        if tied > 1 then
            note = 'mode.tie_all'
        elseif second and second.score == top.score then
            if second.lives ~= top.lives then
                note = 'mode.tie_lives'
            else
                note = 'mode.tie_time'
            end
        end
        return note, tied > 1
    end,

    reasonText = function(reason)
        if reason == 'cleared' then return 'mode.hunt.cleared' end
    end,
}
