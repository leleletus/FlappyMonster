-- ATAQUE cuerpo a cuerpo: con el jugador a tiro se prepara (aviso), golpea delante (una caja que quita vida,
-- opcionalmente embistiendo) y descansa. Todo en el estado 'attack': su animación dura aviso + golpe + descanso.
local T = TILE_PX
return {
    name = 'melee', label = 'Ataque',
    description = 'Con el jugador delante y cerca: se prepara, golpea (o embiste) y descansa.',
    states = { 'attack' },
    params = {
        { key = 'range',    kind = 'number', label = 'Ataca a (casillas)', default = 2, min = 0.5, max = 12, step = 0.5 },
        { key = 'windup',   kind = 'number', label = 'Aviso (s)', default = 0.45, min = 0.1, max = 3, step = 0.05 },
        { key = 'active',   kind = 'number', label = 'Golpe (s)', default = 0.25, min = 0.05, max = 3, step = 0.05 },
        { key = 'rest',     kind = 'number', label = 'Descanso (s)', default = 0.5, min = 0, max = 5, step = 0.05 },
        { key = 'reach',    kind = 'number', label = 'Largo del golpe (casillas)', default = 0.8, min = 0.2, max = 6, step = 0.1 },
        { key = 'lunge',    kind = 'number', label = 'Embestida (px/s)', default = 0, min = 0, max = 900, step = 20 },
        { key = 'damage',   kind = 'int',    label = 'Vida que quita', default = 1, min = 1, max = 3, step = 1 },
        { key = 'cooldown', kind = 'number', label = 'Espera entre ataques (s)', default = 1.2, min = 0, max = 10, step = 0.1 },
    },
    think = function(e, cfg, dt, level)
        if (e.cd_melee or 0) > 0 or not e.onGround then return false end
        local pa = e:seesPlayer(level, cfg.range, 1.2)
        if not pa then return false end
        e.facing = pa.x > e.x and 1 or -1
        e.vx = 0
        e:enter('attack')
        return true
    end,
    update = function(e, cfg, dt, level)
        local t = e.deadTimer
        local vx = 0
        if t >= cfg.windup and t < cfg.windup + cfg.active then vx = cfg.lunge * e.facing end
        local dir = e.facing
        if vx ~= 0 and e.onGround and not e:groundAhead(level, dir) then vx = 0 end
        e.vy = e.vy + ADV_GRAVITY * dt
        e:moveAndCollide(level, vx * dt, e.vy * dt)
        e.facing = dir
        if t >= cfg.windup + cfg.active + cfg.rest then
            e.cd_melee = cfg.cooldown
            e:backToWalk()
        end
    end,
    hazards = function(e, cfg)
        local t = e.deadTimer
        if e.state ~= 'attack' or t < cfg.windup or t >= cfg.windup + cfg.active then return nil end
        local w, h = cfg.reach * T, e.outerH * 0.8
        local x = e.facing > 0 and (e.x + e.outerW / 2) or (e.x - e.outerW / 2 - w)
        return { { x = x, y = e.y - h / 2, w = w, h = h, effect = 'hurt', dmg = cfg.damage } }
    end,
}
