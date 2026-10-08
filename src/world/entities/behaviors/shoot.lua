-- DISPARO: con un jugador a la vista se prepara y lanza un proyectil recto hacia delante. Los proyectiles son
-- suyos (no hay un sistema global): viajan en línea recta, se paran en un bloque sólido y quitan vida al tocar.
-- Estado 'attack' mientras dispara (aviso + retroceso). Se dibujan con la secuencia `shot` de su conjunto de
-- animación (si no la tiene, un cuadradito).
local T = TILE_PX
return {
    name = 'shoot', label = 'Disparo',
    description = 'Con el jugador a la vista dispara un proyectil recto que quita vida.',
    states = { 'attack' },
    anims = { 'shot' },                -- (secuencias extra que usa, además de las de sus estados)
    params = {
        { key = 'range',    kind = 'number', label = 'Lo ve a (casillas)', default = 8, min = 1, max = 24, step = 0.5 },
        { key = 'windup',   kind = 'number', label = 'Aviso (s)', default = 0.5, min = 0.1, max = 3, step = 0.05 },
        { key = 'rest',     kind = 'number', label = 'Retroceso (s)', default = 0.3, min = 0, max = 3, step = 0.05 },
        { key = 'speed',    kind = 'number', label = 'Velocidad del proyectil (px/s)', default = 360, min = 60, max = 1200, step = 20 },
        { key = 'life',     kind = 'number', label = 'Dura (s)', default = 2.5, min = 0.3, max = 8, step = 0.1 },
        { key = 'size',     kind = 'number', label = 'Tamaño (px)', default = 20, min = 6, max = 64, step = 2 },
        { key = 'damage',   kind = 'int',    label = 'Vida que quita', default = 1, min = 1, max = 3, step = 1 },
        { key = 'cooldown', kind = 'number', label = 'Espera entre disparos (s)', default = 2, min = 0.2, max = 15, step = 0.1 },
    },
    think = function(e, cfg, dt, level)
        if (e.cd_shoot or 0) > 0 then return false end
        local pa = e:seesPlayer(level, cfg.range, 1.5)
        if not pa then return false end
        e.facing = pa.x > e.x and 1 or -1
        e.vx, e.fired = 0, false
        e:enter('attack')
        return true
    end,
    update = function(e, cfg, dt, level)
        local dir = e.facing
        if not e.flying then
            e.vy = e.vy + ADV_GRAVITY * dt
            e:moveAndCollide(level, 0, e.vy * dt)
        end
        e.facing = dir
        if not e.fired and e.deadTimer >= cfg.windup then
            e.fired = true
            e:addShot(e.x + dir * e.outerW / 2, e.y, cfg.speed * dir, 0, cfg.life, cfg.size, cfg.damage)
        end
        if e.deadTimer >= cfg.windup + cfg.rest then
            e.cd_shoot = cfg.cooldown
            e:backToWalk()
        end
    end,
}
