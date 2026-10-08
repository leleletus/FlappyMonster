-- PERSEGUIR: al ver a un jugador cerca corre hacia él (estado 'run'); lo deja si se aleja un rato.
local T = TILE_PX
return {
    name = 'chase', label = 'Perseguir',
    description = 'Corre hacia el jugador cuando lo tiene cerca y lo deja si se le escapa.',
    states = { 'run' },
    params = {
        { key = 'range',   kind = 'number', label = 'Lo ve a (casillas)', default = 5, min = 1, max = 20, step = 0.5 },
        { key = 'height',  kind = 'number', label = 'Alto que ve (casillas)', default = 1.5, min = 0.5, max = 10, step = 0.5 },
        { key = 'speedK',  kind = 'number', label = 'Velocidad (× la de andar)', default = 1.8, min = 1, max = 5, step = 0.1 },
        { key = 'giveUp',  kind = 'number', label = 'Lo deja a los (s) sin verlo', default = 1.2, min = 0, max = 10, step = 0.1 },
        { key = 'careful', kind = 'bool',   label = 'No se tira por los bordes', default = true },
    },
    think = function(e, cfg, dt, level)
        if e.flying or not e.onGround then return false end
        local pa = e:seesPlayer(level, cfg.range, cfg.height)
        if not pa then return false end
        e.lostT = 0
        e:enter('run')
        return true
    end,
    update = function(e, cfg, dt, level)
        local pa = e:seesPlayer(level, cfg.range * 1.3, cfg.height * 1.5)
        if pa then
            e.lostT = 0
            if math.abs(pa.x - e.x) > 6 then e.facing = pa.x > e.x and 1 or -1 end
        else
            e.lostT = (e.lostT or 0) + dt
            if e.lostT >= cfg.giveUp then return e:backToWalk() end
        end
        local dir = e.facing
        local vx = (e.speed > 0 and e.speed or 60) * cfg.speedK * dir
        if e.onGround and (not e:canGo(level, dir) or (cfg.careful and not e:groundAhead(level, dir))) then vx = 0 end
        e.vy = e.vy + ADV_GRAVITY * dt
        e:moveAndCollide(level, vx * dt, e.vy * dt)
        e.facing = dir                                   -- (chocar no le da la vuelta mientras persigue)
    end,
}
