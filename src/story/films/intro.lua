-- src/story/films/intro.lua
-- LA INTRO de la historia (al crear una partida). Sin texto: se cuenta con imagen, sonido y música.
-- Tiempos y momentos (cues): assets/story/films.json. Guion: docs/historia/HISTORIA.md.
--   flappy   un día cualquiera: el monstruo ALETEA entre las tuberías (el modo Flappy de verdad)
--   glint    algo brilla a lo lejos; las tuberías se acaban y aparece el volcán
--   mirror   baja por la chimenea del cráter: un espejo antiguo; su reflejo lo imita
--   crash    aletea demasiado cerca: ¡CRAC! el cristal se rompe en siete
--   reflex   del marco vacío sale su REFLEJO
--   steal    el Reflejo le arranca el aleteo (su magia), se ríe, y lo echa del cráter con los fragmentos
--   scatter  seis fragmentos (y el monstruo) cruzan el cielo y caen por las islas; el séptimo se lo queda
--   fury     la FURIA DEL ESPEJO: quien encuentra un fragmento crece y se enfurece
--   onfoot   el monstruo cae en la Pradera; ya no puede aletear: echa a andar
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Particles = require 'src/fx/Particles'

local lerp, smooth, easeIn, easeOut = K.lerp, K.smooth, K.easeIn, K.easeOut
local F = {}

-- ── 1. Un día cualquiera ────────────────────────────────────────────────────
F.flappy = {
    enter = function(c)
        c.shared.rig = K.flappyRig(760, 5)
        c.shared.rig.quiet = c.film.mute
    end,
    update = function(c, t, dt) K.flappyStep(c.shared.rig, dt) end,
    draw = function(c, t)
        local rig = c.shared.rig
        Stage.flappyBg(rig.scroll, K.SKY_BLUE)
        K.flappyDraw(rig)
    end,
}

-- ── 2. El destello ──────────────────────────────────────────────────────────
local GLINT_X, GLINT_Y = 440, 282                 -- (el cráter del volcán del fondo, con la cámara del cielo en 0)
F.glint = {
    enter = function(c)
        c.shared.rig = c.shared.rig or K.flappyRig(-999, 0)
        c.v.camX = 0
    end,
    events = {
        { cue = 'glint', fn = function(c) c.sfx('storyGlint'); Stage.spark(GLINT_X, GLINT_Y, 10, 6, 90, { life = 0.7, s = 4 }) end },
        { cue = 'turn', fn = function(c) c.sfx('storyGlint', 1.25, 0.7); Stage.spark(GLINT_X, GLINT_Y, 8, 6, 70, { life = 0.6, s = 4 }) end },
    },
    update = function(c, t, dt)
        local rig = c.shared.rig
        -- desde que lo ve, va hacia allí: avanza por la pantalla y busca su altura
        local k = c.k(c.at('turn'), c.dur)
        rig.player.x = lerp(PLAYER_START_X, 330, smooth(k))
        rig.targetY = lerp(360, GLINT_Y + 60, smooth(k))
        K.flappyStep(rig, dt)
    end,
    draw = function(c, t)
        local rig = c.shared.rig
        local k = c.k(c.at('cross'), c.dur - c.b(1))          -- el cielo del Flappy se deshace en el del volcán
        local col = K.mix(K.SKY_BLUE, K.SKY_DUSK, smooth(c.k(0, c.at('cross'))))
        if k > 0 then Stage.sky({ background = 'volcano', time = 'dusk', clouds = false }, c.v.camX, 0) end
        if k < 1 then Stage.flappyBg(rig.scroll, col, 1 - smooth(k)) end
        K.flappyDraw(rig)
        -- el destello: parpadea desde que aparece
        if t >= c.at('glint') then
            local tw = 0.5 + 0.5 * math.sin((t - c.at('glint')) * 9)
            Stage.rays(GLINT_X, GLINT_Y, t * 3, 4, 26 + 22 * tw, 0.55, { 0.8, 0.95, 1 })
            if math.random() < 0.25 then Stage.spark(GLINT_X, GLINT_Y, 1, 14, 30, { life = 0.4, s = 3 }) end
        end
        Stage.drawSparks()
    end,
}

-- ── 3. El espejo antiguo ────────────────────────────────────────────────────
-- (el reflejo dentro del cristal: el propio monstruo, vuelto, algo azulado)
local function reflection(dx, hop, frame)
    return function(gx, gy)
        Stage.monster(gx + dx, gy + 34 - hop, { facing = -1, scale = 4, alpha = 0.8, color = { 0.75, 0.88, 1 }, frame = frame })
    end
end
local MIRROR_X0 = 620                                -- donde aterriza, frente al espejo

F.mirror = {
    enter = function(c) c.v.set = Stage.set('crater') end,
    events = {
        { beat = 0.1, fn = function(c) c.sfx('jump') end },
        { beat = 1.1, fn = function(c) c.sfx('jump') end },
        { beat = 2.0, fn = function(c) c.sfx('jump') end },
        { cue = 'land', fn = function(c) c.sfx('step') end },
        { cue = 'wave', fn = function(c) c.sfx('jump', 1.15, 0.6) end },
    },
    draw = function(c, t)
        local land = c.at('land')
        local u = c.k(0, land)
        -- baja por la chimenea aleteando: tres aleteos (cada uno, un saltito hacia arriba)
        local x = lerp(K.HOLE_X, MIRROR_X0, smooth(u))
        local y = lerp(60, K.FLOOR, easeIn(u)) - math.abs(math.sin(u * math.pi * 3)) * 46 * (1 - u)
        local puff = math.max(K.puff(t, c.b(0.1)), K.puff(t, c.b(1.1)), K.puff(t, c.b(2.0)))
        local hop = 0
        if t >= c.at('wave') then                    -- saluda con un saltito; su reflejo, igual
            local h = c.k(c.at('wave'), c.at('wave') + c.b(1))
            hop = math.sin(h * math.pi) * 44
        end
        local frame = (u < 1) and 2 or 1
        Stage.drawSet(c.v.set, K.CAMX, K.CAMY, function()
            Stage.mirror(K.MX, K.MF, { whole = true, reflection = (u >= 0.75) and reflection((1 - c.k(land * 0.75, land)) * 52, hop, frame) or nil })
            Stage.monster(x, y - hop, { frame = (hop > 0) and 2 or frame, puff = puff })
        end, { Stage.mirrorLight(K.MX, K.MF, 0.55) })
    end,
}

-- ── 4. ¡CRAC! ───────────────────────────────────────────────────────────────
local HIT_X, HIT_Y = K.MX - 78, K.MF - 150            -- donde choca con el cristal
local ALL = Stage.shardIds(false)

F.crash = {
    enter = function(c) c.v.set = Stage.set('crater') end,
    events = {
        { cue = 'flap', fn = function(c) c.sfx('jump') end },
        { cue = 'crash', fn = function(c)
            c.sfx('storyCrash')
            local gx, gy = Stage.glassCenter(K.MX, K.MF)
            Particles.emit('mirror_shards', gx + K.CAMX * 0, gy)
            Particles.emit('mirror_shards', gx - 30, gy - 40)
            Particles.emit('shake_big', gx, gy)
            Stage.spark(gx, gy, 16, 30, 260, { life = 0.8, s = 4, g = 300 })
        end },
    },
    draw = function(c, t)
        local flap, crash = c.at('flap'), c.at('crash')
        local x, y, o = MIRROR_X0, K.FLOOR, { frame = 1 }
        local shake = 0
        if t >= crash then
            -- rebota hacia atrás, dando vueltas, y cae al suelo
            local u = c.k(crash, crash + c.b(1.4))
            x = lerp(HIT_X, 500, u)
            y = lerp(HIT_Y, K.FLOOR + 18, u) - math.sin(u * math.pi) * 120
            o = (u < 1) and { frame = 4, angle = -u * math.pi * 2 } or { frame = 5 }
            if u >= 1 then y = K.FLOOR + 18 end
            shake = math.max(0, 10 * (1 - (t - crash) / 0.5))
        elseif t >= flap then
            -- aletea hacia su reflejo, demasiado cerca
            local u = c.k(flap, crash)
            x = lerp(MIRROR_X0, HIT_X, easeIn(u))
            y = lerp(K.FLOOR, HIT_Y, easeOut(u))
            o = { frame = 2, puff = K.puff(t, flap) }
        end
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, K.CAMX + sx, K.CAMY + sy, function()
            if t < crash then
                local u = c.k(flap, crash)
                Stage.mirror(K.MX, K.MF, { whole = true, reflection = function(gx, gy)
                    Stage.monster(gx + lerp(0, -12, u), gy + lerp(34, -40, easeOut(u)), { facing = -1, scale = 4, alpha = 0.8, color = { 0.75, 0.88, 1 }, frame = (t >= flap) and 2 or 1 })
                end })
            else
                Stage.mirror(K.MX, K.MF, { shards = ALL, shake = shake })      -- (agrietado: los siete trozos, aún en su sitio)
            end
            Stage.monster(x, y, o)
        end, { Stage.mirrorLight(K.MX, K.MF, (t < crash) and 0.6 or 0.3) })
        if t >= crash then Stage.flash(1 - (t - crash) / 0.45) end
    end,
}

-- Los fragmentos flotando alrededor del marco; `k` 0..1 = cuánto han salido de su sitio; `skip[id]` no se dibuja
local function floating(k, t, skip)
    for _, id in ipairs(ALL) do
        if not (skip and skip[id]) then
            local sx, sy = Stage.shardSlot(id, K.MX, K.MF)
            local hx, hy = K.hover(id, t)
            Stage.shard(id, lerp(sx, hx, k), lerp(sy, hy, k), { rot = math.sin(t * 1.3 + tonumber(id)) * 0.25 * k })
        end
    end
end

-- ── 5. El Reflejo sale ──────────────────────────────────────────────────────
local REF_X = 778                                    -- donde se planta el Reflejo, delante del espejo
F.reflex = {
    enter = function(c) c.v.set = Stage.set('crater') end,
    events = {
        { beat = 0, fn = function(c) c.sfx('glassRise', 1.1, 0.8) end },
        { cue = 'peek', fn = function(c) c.sfx('mirrorAppear') end },
        { cue = 'step', fn = function(c) c.sfx('jump', 0.8) end },
        { cue = 'land', fn = function(c) c.sfx('gpImpact', 0.9, 0.6); Particles.emit('shake_small', REF_X, K.FLOOR) end },
    },
    draw = function(c, t)
        local peek, step, land = c.at('peek'), c.at('step'), c.at('land')
        local out = easeOut(c.k(0, c.b(1.2)))
        -- el monstruo: caído; se levanta y retrocede
        local mu = c.k(c.b(2), c.b(6))
        local mx = lerp(500, 440, smooth(mu))
        local mo = (t < c.b(2)) and { frame = 5 } or { frame = (mu > 0 and mu < 1) and (math.floor(t * 8) % 3 + 1) or 1 }
        local my = (t < c.b(2)) and K.FLOOR + 18 or K.FLOOR
        local gx, gy = Stage.glassCenter(K.MX, K.MF)
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, K.CAMX + sx, K.CAMY + sy, function()
            Stage.mirror(K.MX, K.MF, { reflection = (t >= peek and t < step) and function(x, y)
                Stage.monster(x, y + 34, { facing = -1, scale = 5, invert = true, alpha = smooth(c.k(peek, peek + c.b(1))) })
            end or nil })
            floating(out, t)
            if t >= step then
                local u = c.k(step, land)
                local x = lerp(gx, REF_X, u)
                local y = lerp(gy + 34, K.FLOOR, u) - math.sin(u * math.pi) * 90
                Stage.monster(x, y, { facing = -1, invert = true, frame = (u < 1) and 2 or 1, scale = lerp(5, PLAYER_SCALE, u) })
            end
            Stage.monster(mx, my, mo)
        end, { Stage.mirrorLight(K.MX, K.MF, 0.22) })
    end,
}

-- ── 6. Le roba el aleteo ────────────────────────────────────────────────────
local HOVER_Y = K.FLOOR - 170
F.steal = {
    enter = function(c) c.v.set = Stage.set('crater'); c.v.laughs = 0 end,
    events = {
        { cue = 'pull', fn = function(c) c.sfx('storyOrb') end },
        { cue = 'got', fn = function(c) c.sfx('mirrorWarp', 1.2, 0.8); Stage.spark(REF_X, K.FLOOR - 20, 14, 10, 220, { life = 0.6, s = 4 }) end },
        { beat = 4.5, fn = function(c) c.sfx('jump', 0.75) end },
        { cue = 'try', fn = function(c) c.sfx('jump') end },
        { beat = 8.6, fn = function(c) c.sfx('jump', 1.2, 0.8); Stage.spark(480, K.FLOOR - 60, 5, 10, 60, { life = 0.35, s = 3 }) end },
        { beat = 9.6, fn = function(c) c.sfx('gpImpact', 1.1, 0.5) end },
        { cue = 'blast', fn = function(c) c.sfx('storyBlast') end },
    },
    update = function(c, t, dt)
        -- la risa: cinco carcajadas, como el jefe
        local lt = t - c.at('laugh')
        while lt >= 0 and c.v.laughs < 5 and lt >= (1 / 6) + c.v.laughs * (2 / 6) do
            c.sfx('mirrorLaugh', 0.92 + math.random() * 0.16)
            c.v.laughs = c.v.laughs + 1
        end
        -- las chispas del aleteo, arrancadas hacia el Reflejo
        if t >= c.at('pull') and t < c.at('got') and math.random() < 0.6 then
            Stage.spark(lerp(440, 500, c.k(c.at('pull'), c.at('got'))), K.FLOOR - 10, 1, 24, 40, { life = 0.7, s = 3, tx = REF_X, ty = K.FLOOR - 10 })
        end
    end,
    draw = function(c, t)
        local pull, got, laugh, try, blast = c.at('pull'), c.at('got'), c.at('laugh'), c.at('try'), c.at('blast')
        local bk = c.k(blast, c.dur)                              -- la explosión final: todo sale despedido
        -- el monstruo
        local mx, my, mo = 440, K.FLOOR, { frame = 1 }
        if t >= pull and t < got then                             -- tira de él: lo arrastra
            mx = lerp(440, 500, c.k(pull, got)) + math.sin(t * 40) * 2
            mo = { frame = 2 }
        elseif t >= got and t < try then                          -- se queda sin fuerzas, de rodillas
            mx, my, mo = 500, K.FLOOR + 18, { frame = 5 }
        elseif t >= try then
            mx = 500
            -- intenta aletear: salta... un segundo salto en el aire (lo poco que le queda) y cae
            local a, b2, e = try, c.b(8.6), c.b(9.6)
            if t < b2 then
                local u = (t - a) / (b2 - a)
                my = K.FLOOR - math.sin(u * math.pi * 0.5) * 100
                mo = { frame = 2 }
            elseif t < e then
                local u = (t - b2) / (e - b2)
                my = K.FLOOR - 100 - math.sin(u * math.pi) * 70 + easeIn(u) * 118
                mo = { frame = (u < 0.5) and 2 or 3 }
            else
                my, mo = K.FLOOR + 18, { frame = 5 }
            end
        end
        if bk > 0 then                                             -- sale volando por la chimenea
            mx = lerp(500, K.HOLE_X, easeIn(bk))
            my = lerp(K.FLOOR, -80, easeIn(bk))
            mo = { frame = 4, angle = bk * math.pi * 5 }
        end
        -- el Reflejo: recibe el aleteo, sube aleteando y se ríe
        local ry, rpuff = K.FLOOR, 1
        if t >= got then
            ry = lerp(K.FLOOR, HOVER_Y, easeOut(c.k(got, laugh))) + math.sin(t * 5) * 6
            rpuff = math.max(K.puff(t, got), K.puff(t, c.b(4.5)))
        end
        local ox, oy = lerp(mx, REF_X, easeIn(c.k(pull, got))), K.FLOOR - 10 + math.sin(t * 14) * 5
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, K.CAMX + sx, K.CAMY + sy, function()
            Stage.mirror(K.MX, K.MF, {})
            -- los seis de alrededor flotan; al final salen disparados por la chimenea
            for _, id in ipairs(ALL) do
                local hx, hy = K.hover(id, t)
                if id == '7' then
                    -- el del centro va a la mano del Reflejo y gira a su alrededor
                    local u = smooth(c.k(got, laugh))
                    local a = t * 2.4
                    hx, hy = lerp(hx, REF_X + math.cos(a) * 70, u), lerp(hy, ry - 10 + math.sin(a) * 28, u)
                elseif bk > 0 then
                    hx, hy = lerp(hx, K.HOLE_X + (tonumber(id) - 3.5) * 16, easeIn(bk)), lerp(hy, -120, easeIn(bk))
                end
                Stage.shard(id, hx, hy, { rot = math.sin(t * 1.3 + tonumber(id)) * 0.25 + bk * 9 })
            end
            if t >= laugh and t < try then
                Stage.laugh(REF_X, ry, t - laugh, { facing = -1, puff = rpuff })
            else
                Stage.monster(REF_X, ry, { facing = -1, invert = true, frame = (t >= got) and 2 or 1, puff = rpuff })
            end
            Stage.monster(mx, my, mo)
        end, { Stage.mirrorLight(K.MX, K.MF, 0.2), Stage.light(ox, oy, 150, (t >= pull and t < got) and 0.5 or 0) },
        function()
            if t >= pull and t < got then Stage.orb(ox, oy, t, 4) end
        end)
        Stage.flash(easeIn(bk))
    end,
}

-- ── 7. Seis fragmentos, seis sitios ─────────────────────────────────────────
local ZOOM_FAR = 0.5
local function farCam()
    local _, SM = Stage.map()
    local pw, ph = SM.mapSize()
    return (pw - WINDOW_W / ZOOM_FAR) / 2, (ph - WINDOW_H / ZOOM_FAR) / 2
end

F.scatter = {
    enter = function(c)
        local map = Stage.map()
        K.setBosses(map, { K.SMALL, K.SMALL, K.SMALL, K.SMALL, K.SMALL, K.SMALL }, 1)
        c.v.landed = 0
    end,
    update = function(c, t, dt)
        -- cada fragmento sale en su pulso y tarda 1,2 pulsos en llegar
        for i = c.v.landed + 1, 6 do
            if t >= c.at('first') + c.b(i - 1) + c.b(1.2) then
                c.v.landed = i
                local tg = K.targets()[i]
                c.sfx('storyShard', 1.25 - i * 0.07)
                Stage.spark(tg.x, tg.y - 20, 8, 8, 120, { life = 0.6, s = 6 })
            end
        end
    end,
    draw = function(c, t)
        local map, SM = Stage.map()
        local cx, cy = farCam()
        local vx, vy = SM.bossXY(6)
        local hx, hy = SM.nodeXY(1, 1)
        map:filmDraw(cx, cy, ZOOM_FAR, { extra = function(ox, oy)
            love.graphics.push()
            love.graphics.translate(-ox, -oy)
            K.drawSnow(map, K.SMALL)
            for i, tg in ipairs(K.targets()) do
                local t0 = c.at('first') + c.b(i - 1)
                local u = (t - t0) / c.b(1.2)
                if u > 0 and u < 1 then
                    local x, y = lerp(vx, tg.x, u), lerp(vy - 40, tg.y - 20, u) - math.sin(u * math.pi) * 260
                    Stage.shard(tostring(i), x, y, { s = 5, rot = t * 9 })
                    if math.random() < 0.5 then Stage.spark(x, y, 1, 6, 20, { life = 0.4, s = 5 }) end
                elseif u >= 1 then
                    Stage.shard(tostring(i), tg.x, tg.y - 34 + math.sin(t * 4 + i) * 4, { s = 4 })
                end
            end
            -- el monstruo, lanzado desde el volcán hasta la Pradera
            local u = c.k(c.b(0.3), c.dur - c.b(0.4))
            if u < 1 then
                Stage.monster(lerp(vx, hx, u), lerp(vy - 40, hy - 20, u) - math.sin(u * math.pi) * 420, { frame = 4, angle = t * 7, scale = 5 })
            end
            Stage.drawSparks()
            love.graphics.pop()
        end })
    end,
}

-- ── 8. La furia del espejo ──────────────────────────────────────────────────
local ZOOM_NEAR = 2
F.fury = {
    enter = function(c) c.v.done = 0; c.v.sizes = { K.SMALL, K.SMALL, K.SMALL, K.SMALL, K.SMALL, K.SMALL } end,
    update = function(c, t, dt)
        local each = c.at('each')
        for i = c.v.done + 1, 6 do
            if t >= c.at('first') + (i - 1) * each + c.b(0.5) then
                c.v.done = i
                c.sfx('storyGrow', 0.85 + i * 0.05)
                local tg = K.targets()[i]
                Stage.spark(tg.x, tg.y - 24, 7, 30, 220, { life = 0.45, s = 2 })
            end
        end
    end,
    draw = function(c, t)
        local map = Stage.map()
        local each, tgs = c.at('each'), K.targets()
        local i = math.min(6, math.floor((t - c.at('first')) / each) + 1)
        local wide = t >= c.at('first') + 6 * each
        -- tamaños: los que ya crecieron, grandes; el de ahora, creciendo
        for n = 1, 6 do
            local t0 = c.at('first') + (n - 1) * each + c.b(0.5)
            c.v.sizes[n] = (t < t0) and K.SMALL or lerp(K.SMALL, 1, K.elastic((t - t0) / c.b(0.9)))
        end
        K.setBosses(map, c.v.sizes, 1)
        local function extra(ox, oy)
            love.graphics.push()
            love.graphics.translate(-ox, -oy)
            K.drawSnow(map, c.v.sizes[4])
            if not wide then
                local tg = tgs[i]
                local u = c.k(c.at('first') + (i - 1) * each, c.at('first') + (i - 1) * each + c.b(0.5))
                if u < 1 then Stage.shard(tostring(i), tg.x, lerp(tg.y - 200, tg.y - 26, easeIn(u)), { s = 2, rot = t * 6 }) end
            end
            Stage.drawSparks()
            love.graphics.pop()
        end
        if wide then
            local cx, cy = farCam()
            map:filmDraw(cx, cy, ZOOM_FAR, { extra = extra })
            Stage.flash(0.12 + 0.08 * math.sin(t * 6), 0.9, 0.1, 0.1)       -- la furia, sobre todas las islas
        else
            local tg = tgs[i]
            local t0 = c.at('first') + (i - 1) * each + c.b(0.5)
            local sh = (t >= t0) and math.max(0, 5 * (1 - (t - t0) / 0.35)) or 0
            local jx, jy = (math.random() * 2 - 1) * sh, (math.random() * 2 - 1) * sh
            map:filmDraw(tg.x - WINDOW_W / ZOOM_NEAR / 2 + jx, tg.y - 26 - WINDOW_H / ZOOM_NEAR / 2 + jy, ZOOM_NEAR, { extra = extra })
            if t >= t0 then
                Stage.flash(0.45 * (1 - (t - t0) / 0.18))
                Stage.flash(0.16 * c.k(t0, t0 + c.b(1)), 0.9, 0.1, 0.1)
            end
        end
    end,
}

-- ── 9. A pie ────────────────────────────────────────────────────────────────
F.onfoot = {
    enter = function(c)
        local map = Stage.map()
        K.setBosses(map, { 1, 1, 1, 1, 1, 1 }, 1)
    end,
    events = {
        { cue = 'land', fn = function(c)
            local _, SM = Stage.map()
            local hx, hy = SM.nodeXY(1, 1)
            c.sfx('gpImpact', 1, 0.7)
            Stage.spark(hx, hy, 8, 10, 110, { life = 0.4, s = 3, vy = -40 })
        end },
        { beat = 6.5, fn = function(c) c.sfx('jump') end },
        { cue = 'walk', fn = function(c) c.sfx('step') end },
        { beat = 8.5, fn = function(c) c.sfx('step') end },
        { beat = 9, fn = function(c) c.sfx('step') end },
    },
    draw = function(c, t)
        local map, SM = Stage.map()
        local hx, hy = SM.nodeXY(1, 1)
        local pw, ph = SM.mapSize()
        local cx = math.max(0, math.min(pw - WINDOW_W, hx - WINDOW_W / 2))
        local cy = math.max(0, math.min(ph - WINDOW_H, hy - WINDOW_H / 2))
        local land, up, walk = c.at('land'), c.at('up'), c.at('walk')
        map:filmDraw(cx, cy, 1, { extra = function(ox, oy)
            love.graphics.push()
            love.graphics.translate(-ox, -oy)
            K.drawSnow(map, 1)
            local y0 = hy - 16                                       -- (el centro del monstruo de pie en su nodo)
            local x, y, o = hx, y0, { scale = 3, frame = 1 }
            if t < land then
                local u = t / land
                y = lerp(y0 - 620, y0, easeIn(u)); o = { scale = 3, frame = 4, angle = t * 9 }
            elseif t < up then
                y, o = y0 + 9, { scale = 3, frame = 5 }
            elseif t < walk then
                -- se levanta, mira el volcán (a lo lejos) e intenta aletear: solo un saltito
                local h = c.k(c.b(6.5), c.b(7.5))
                y = y0 - math.sin(h * math.pi) * 26
                o = { scale = 3, frame = (h > 0 and h < 1) and 2 or 1, facing = (t > c.b(5.8)) and 1 or -1 }
            else
                local u = c.k(walk, c.dur)                            -- ... y echa a andar
                o = { scale = 3, frame = math.floor(t * 9) % 3 + 1 }
                y = y0 - math.abs(math.sin(u * math.pi * 6)) * 4
            end
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle('fill', math.floor(hx) - 12, math.floor(hy) + 6, 24, 6)
            Stage.monster(x, y, o)
            Stage.drawSparks()
            love.graphics.pop()
        end })
    end,
}

return F
