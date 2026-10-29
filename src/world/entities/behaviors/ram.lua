-- LANZARSE Y EMPUJAR (la Bola de Nieve; vale para cualquier enemigo que embista, p. ej. una cabra): con un jugador a la
-- vista se prepara (aviso) y se LANZA hacia él — rodando muy rápido; en un borde salta el hueco si al otro lado hay
-- suelo a su altura (`Entity:landingAhead`; si no, frena); si el jugador está más alto, salta lo que haga falta para
-- llegar a esa repisa —. Lo que pilla delante sale EMPUJADO con fuerza de lado
-- (y un poco hacia arriba): su gracia es tirar a los jugadores de las repisas a los huecos o al agua. El empujón es una
-- caja de peligro `effect = 'launch'` (Interactions: el jugador sale lanzado como por un trampolín, sin perder vida; el
-- cliente online lo PREDICE igual que un trampolín) y no se repite mientras el jugador sigue lanzado. A los enemigos que
-- pilla los derriba (`Entity:sweepAhead`, el mismo arrollar del Escarabajo).
-- Estados: 'windup' (aviso) → 'charge' (lanzado) → 'recoil' (empujó a alguien: rebota un poco hacia atrás) o 'dazed'
-- (se dio contra una pared) → anda. Si el lanzamiento acaba sin chocar (largo máximo, o un borde), vuelve a andar.
local Entity = require 'src/world/entities/base/Entity'
local T = TILE_PX
local MAX_T = 3.0                     -- s como mucho lanzado (por si algo lo deja atascado)
local GAP_H = 1.0                     -- casillas: el salto con que cruza un hueco (Entity:landingAhead dice si llega)
local SWEEP_VX, SWEEP_VY = 420, -260  -- px/s: lo ligero que arrolla sale despedido así
local RECOIL_VX, RECOIL_VY = 150, -260

local function finish(e, cfg)
    e.cd_ram = cfg.cooldown
    e:backToWalk()
end

return {
    name = 'ram', label = 'Lanzarse y empujar',
    description = 'Si ve a un jugador, se prepara y se lanza hacia él (rueda o salta, también a otra repisa); lo que pilla delante sale empujado con fuerza de lado. Derriba a otros enemigos.',
    states = { 'windup', 'charge', 'recoil', 'dazed' },
    launchState = 'recoil',
    freeOfRoute = true,                  -- (lanzado, los límites de su ruta no lo paran: DataEnemy:freeOfRoute)              -- (el estado en que entra al empujar a un jugador: su sonido es el que predice el cliente)
    params = {
        { key = 'range',    kind = 'number', label = 'Lo ve a (casillas)', default = 6, min = 1, max = 20, step = 0.5 },
        { key = 'height',   kind = 'number', label = 'Lo ve hasta (casillas de alto)', default = 2.5, min = 0.5, max = 8, step = 0.5 },
        { key = 'windup',   kind = 'number', label = 'Aviso (s)', default = 0.55, min = 0.1, max = 3, step = 0.05 },
        { key = 'speed',    kind = 'number', label = 'Velocidad lanzado (px/s)', default = 430, min = 100, max = 1000, step = 10 },
        { key = 'dist',     kind = 'number', label = 'Largo máximo (casillas)', default = 6, min = 1, max = 16, step = 0.5 },
        { key = 'hop',      kind = 'number', label = 'Salto al lanzarse (casillas)', default = 0, min = 0, max = 4, step = 0.1 },
        { key = 'push',     kind = 'number', label = 'Empujón de lado (px/s)', default = 640, min = 100, max = 1400, step = 20 },
        { key = 'lift',     kind = 'number', label = 'Empujón hacia arriba (px/s)', default = 330, min = 0, max = 1000, step = 10 },
        { key = 'damage',   kind = 'int',    label = 'Vida que quita al empujar', default = 0, min = 0, max = 3, step = 1 },
        { key = 'rest',     kind = 'number', label = 'Descanso tras chocar (s)', default = 0.7, min = 0, max = 5, step = 0.05 },
        { key = 'cooldown', kind = 'number', label = 'Espera entre lanzamientos (s)', default = 1.6, min = 0, max = 10, step = 0.1 },
    },
    think = function(e, cfg, dt, level)
        if (e.cd_ram or 0) > 0 or e.flying or not e.onGround then return false end
        local pa = e:seesPlayer(level, cfg.range, cfg.height)
        if not pa or math.abs(pa.x - e.x) < T * 0.6 then return false end
        e.facing = pa.x > e.x and 1 or -1
        local feet = e.y + e.outerH / 2
        local pb = pa:getOuterBounds()
        e.ramRise = math.max(0, feet - (pb.y + pb.h))    -- (cuánto más alto tiene los pies el jugador)
        e.vx = 0
        e:enter('windup')
        return true
    end,
    update = function(e, cfg, dt, level)
        local dir = e.facing ~= 0 and e.facing or 1
        local st, t = e.state, e.deadTimer
        if st == 'windup' then
            e:fall(level, dt)
            if t >= cfg.windup then
                -- salta lo justo: bajito si está a su altura (cruza un hueco corto), más si está en una repisa más alta
                local h = math.max(cfg.hop * T, (e.ramRise or 0) > T * 0.4 and (e.ramRise + T * 0.6) or 0)
                e.vx, e.vy = dir * cfg.speed, (h > 0) and -math.sqrt(2 * ADV_GRAVITY * h) or 0
                e.onGround = false
                e.ramX0, e.ramSwept = e.x, {}
                e:enter('charge')
                Entity.emitFx('gp_land', e.x - dir * e.outerW / 2, e.y + e.outerH / 2)
            end
        elseif st == 'charge' then
            if e.onGround and not e:groundAhead(level, dir) then
                -- en un BORDE: si al otro lado hay suelo a su altura al alcance de un salto, lo cruza; si no, frena
                local vy = math.sqrt(2 * ADV_GRAVITY * GAP_H * T)
                local reach = cfg.speed * 2 * vy / ADV_GRAVITY - e.outerW * 0.5 - 8
                local d = e:landingAhead(level, dir, reach)
                if not d then return finish(e, cfg) end
                e.vy, e.onGround = -vy, false
            end
            local x0 = e.x
            e.vx = dir * cfg.speed
            e:fall(level, dt, e.vx)
            e.facing = dir
            -- arrolla a los enemigos y lo ligero que pilla delante (una vez a cada uno por lanzamiento)
            local ob = e:getOuterBounds()
            local front = { x = (dir > 0) and ob.x + ob.w * 0.5 or ob.x - 8, y = ob.y, w = ob.w * 0.5 + 8, h = ob.h }
            e:sweepAhead(level, front, dir, e.ramSwept or {}, SWEEP_VX, SWEEP_VY)
            if e:fellOut(level) or e:inVoid(level) or e:onDeadlyGround(level) then e:dieBurst(); return end
            if math.abs(e.x - x0) < cfg.speed * dt * 0.4 then       -- (contra una pared: rebota y se marea)
                e.vx, e.vy, e.onGround = -dir * RECOIL_VX * 0.6, -180, false
                e.cd_ram = cfg.cooldown
                e:enter('dazed')
                Entity.emitFx('shake_small', e.x, e.y)
                e.facing = dir
                return
            end
            if (e.onGround and math.abs(e.x - (e.ramX0 or e.x)) >= cfg.dist * T) or t >= MAX_T then return finish(e, cfg) end
        else                                                          -- 'recoil' / 'dazed': rebote y descanso
            e.vx = (e.vx or 0) * math.max(0, 1 - 5 * dt)
            e:fall(level, dt, e.vx)
            e.facing = dir
            if e:fellOut(level) or e:inVoid(level) or e:onDeadlyGround(level) then e:dieBurst(); return end
            if t >= cfg.rest * ((st == 'dazed') and 1.5 or 1) and e.onGround then return finish(e, cfg) end
        end
    end,
    -- La caja que empuja: lo de delante del cuerpo, lanzado. Caerle ENCIMA no empuja (se le pisa: `stompable`)
    hazards = function(e, cfg)
        if e.state ~= 'charge' then return nil end
        local dir = e.facing ~= 0 and e.facing or 1
        local w, h = e.outerW * 0.7 + 6, e.outerH
        local x = (dir > 0) and (e.x + e.outerW / 2 + 6 - w) or (e.x - e.outerW / 2 - 6)
        return { { x = x, y = e.y - h / 2, w = w, h = h, effect = 'launch', vx = dir * cfg.push, vy = -cfg.lift,
                   jumps = 1, stompable = true } }
    end,
    -- Interactions.run, tras lanzar a un jugador (en un jugador y en el servidor): rebota hacia atrás y se ríe
    onLaunch = function(e, cfg, pa)
        if e.state ~= 'charge' then return end
        local dir = e.facing ~= 0 and e.facing or 1
        if (cfg.damage or 0) > 0 and pa.hurt and not pa.peaceful then pa:hurt(cfg.damage) end
        e.vx, e.vy, e.onGround = -dir * RECOIL_VX, RECOIL_VY, false
        e.cd_ram = cfg.cooldown
        e:enter('recoil')
        e.facing = dir
    end,
}
