-- ACCIÓN ESPECIAL: SALTO. Cada cierto tiempo, con un jugador a la vista, se agacha (aviso) y salta en arco hacia
-- él. Estado 'special' (aviso + vuelo); al caer vuelve a andar.
local T = TILE_PX
return {
    name = 'leap', label = 'Salto (acción especial)',
    description = 'Cada cierto tiempo se agacha y salta en arco hacia el jugador.',
    states = { 'special' },
    params = {
        { key = 'range',  kind = 'number', label = 'Lo ve a (casillas)', default = 6, min = 1, max = 20, step = 0.5 },
        { key = 'every',  kind = 'number', label = 'Cada (s)', default = 3, min = 0.5, max = 20, step = 0.1 },
        { key = 'windup', kind = 'number', label = 'Aviso (s)', default = 0.4, min = 0.1, max = 3, step = 0.05 },
        { key = 'height', kind = 'number', label = 'Altura del salto (casillas)', default = 2.5, min = 0.5, max = 8, step = 0.5 },
        { key = 'dist',   kind = 'number', label = 'Largo máximo (casillas)', default = 5, min = 0.5, max = 14, step = 0.5 },
    },
    think = function(e, cfg, dt, level)
        if (e.cd_leap or 0) > 0 or e.flying or not e.onGround then return false end
        local pa = e:seesPlayer(level, cfg.range, 4)
        if not pa then return false end
        e.facing = pa.x > e.x and 1 or -1
        e.leapTx, e.leaped, e.vx = pa.x, false, 0
        e:enter('special')
        return true
    end,
    update = function(e, cfg, dt, level)
        local dir = e.facing
        if not e.leaped then
            e.vy = e.vy + ADV_GRAVITY * dt
            e:moveAndCollide(level, 0, e.vy * dt)
            if e.deadTimer >= cfg.windup then
                -- salto balístico: sube `height` casillas y cae a la distancia del jugador (como mucho `dist`)
                local vy = -math.sqrt(2 * ADV_GRAVITY * cfg.height * T)
                local air = 2 * -vy / ADV_GRAVITY
                local dx = math.max(-cfg.dist * T, math.min(cfg.dist * T, (e.leapTx or e.x) - e.x))
                e.vx, e.vy, e.onGround, e.leaped = dx / air, vy, false, true
            end
        else
            e.vy = e.vy + ADV_GRAVITY * dt
            local vx = e.vx
            e:moveAndCollide(level, vx * dt, e.vy * dt)
            if e.onGround then
                e.cd_leap = cfg.every
                e:backToWalk()
            end
        end
        e.facing = dir
    end,
}
