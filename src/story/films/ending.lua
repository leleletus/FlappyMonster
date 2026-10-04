-- src/story/films/ending.lua
-- EL FINAL de la historia: empieza cuando el jugador recoge el último fragmento (el del jefe Espejo), sin
-- tocar la meta. Tiempos: assets/story/films.json. Guion: docs/historia/HISTORIA.md.
--   seven    en el cráter, ante el marco vacío, los fragmentos salen y giran alrededor del monstruo
--   pieces   vuelan al marco y encajan uno a uno, en el orden en que se ganaron (Xtra extremo: las 14 mitades)
--   whole    el espejo, entero: las grietas se borran
--   return   el espejo tira del Reflejo, que vuelve dentro y suelta lo que robó: el aleteo
--   light    una onda de luz sale del volcán y recorre las islas: la furia del espejo se apaga
--   shrink   los jefes vuelven a ser pequeños
--   flap     el monstruo recupera su magia: aletea... y sale volando por la chimenea
--   home     vuela a casa; el cielo vuelve a ser el del modo Flappy, vuelven las tuberías; el logo
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Particles = require 'src/fx/Particles'

local lerp, smooth, easeIn, easeOut = K.lerp, K.smooth, K.easeIn, K.easeOut
local F = {}

local MONSTER_X = 520
local ORBIT_Y = K.FLOOR - 70
local SCALE = { 0, 2, 4, 5, 7, 9, 12 }              -- la nota de cada fragmento al encajar (semitonos: una escala que sube)

-- Dónde gira el fragmento i de n alrededor del monstruo (gt = tiempo de la película: no salta entre escenas)
local function orbit(i, n, gt)
    local a = gt * 0.9 + (i - 1) / n * math.pi * 2
    return MONSTER_X + math.cos(a) * 200, ORBIT_Y + math.sin(a) * 104
end

-- ── 1. Los siete ────────────────────────────────────────────────────────────
F.seven = {
    enter = function(c)
        c.v.set = Stage.set('crater')
        c.shared.ids = Stage.shardIds(c.xtra)
        c.v.out = 0
    end,
    events = {
        { beat = 0.2, fn = function(c) c.sfx('step') end },
        { beat = 0.9, fn = function(c) c.sfx('step') end },
        { beat = 1.6, fn = function(c) c.sfx('step') end },
    },
    update = function(c, t, dt)
        local ids = c.shared.ids
        local gap = c.b(3.2) / #ids
        for i = c.v.out + 1, #ids do
            if t >= c.at('out') + (i - 1) * gap then
                c.v.out = i
                if not c.xtra or i % 2 == 1 then c.sfx('storyShard', 0.9 + i / #ids * 0.5, 0.7) end
                Stage.spark(MONSTER_X, K.FLOOR - 10, 3, 10, 90, { life = 0.4, s = 3 })
            end
        end
    end,
    draw = function(c, t)
        local ids, gt = c.shared.ids, c.film.t
        local wu = c.k(0, c.at('out'))
        local mx = lerp(300, MONSTER_X, wu)
        local gap = c.b(3.2) / #ids
        Stage.drawSet(c.v.set, K.CAMX, K.CAMY, function()
            Stage.mirror(K.MX, K.MF, {})
            Stage.monster(mx, K.FLOOR, { frame = (wu < 1) and (math.floor(t * 9) % 3 + 1) or 1 })
            for i, id in ipairs(ids) do
                local u = (t - (c.at('out') + (i - 1) * gap)) / c.b(0.9)
                if u > 0 then
                    local ox, oy = orbit(i, #ids, gt)
                    local k = easeOut(u)
                    Stage.shard(id, lerp(MONSTER_X, ox, k), lerp(K.FLOOR - 10, oy, k), { rot = math.sin(gt * 2 + i) * 0.3, s = lerp(1.5, 4, k) })
                end
            end
        end, { Stage.mirrorLight(K.MX, K.MF, 0.15), Stage.light(MONSTER_X, ORBIT_Y, 300, 0.35 * c.k(c.at('out'), c.dur)) })
    end,
}

-- ── 2. Pieza a pieza ────────────────────────────────────────────────────────
local function arrival(c, i)
    local n = #c.shared.ids
    local step = c.at('each') * 7 / n                  -- (7 fragmentos: uno cada 2 pulsos; 14 mitades: una por pulso)
    return c.at('first') + (i - 1) * step
end

F.pieces = {
    enter = function(c)
        c.v.set = Stage.set('crater')
        c.shared.ids = c.shared.ids or Stage.shardIds(c.xtra)
        c.v.placed = 0
    end,
    update = function(c, t, dt)
        local ids = c.shared.ids
        for i = c.v.placed + 1, #ids do
            if t >= arrival(c, i) then
                c.v.placed = i
                local n = tonumber(ids[i]:sub(1, 1))
                c.sfx('storyClink', 2 ^ (SCALE[n] / 12))
                local sx, sy = Stage.shardSlot(ids[i], K.MX, K.MF)
                Stage.spark(sx, sy, 8, 12, 150, { life = 0.5, s = 3 })
            end
        end
    end,
    draw = function(c, t)
        local ids, gt = c.shared.ids, c.film.t
        local placed, flying = {}, {}
        for i, id in ipairs(ids) do
            local ta = arrival(c, i)
            if t >= ta then placed[#placed + 1] = id
            else flying[#flying + 1] = { i = i, id = id, u = 1 - (ta - t) / c.b(1) } end
        end
        local pulse = 0
        if c.v.placed > 0 then pulse = math.max(0, 1 - (t - arrival(c, c.v.placed)) / 0.3) end
        Stage.drawSet(c.v.set, K.CAMX, K.CAMY, function()
            Stage.mirror(K.MX, K.MF, { shards = placed })
            Stage.monster(MONSTER_X, K.FLOOR, { frame = 1 })
            for _, f in ipairs(flying) do
                local ox, oy = orbit(f.i, #ids, gt)
                if f.u > 0 then
                    local sx, sy = Stage.shardSlot(f.id, K.MX, K.MF)
                    local k = smooth(f.u)
                    Stage.shard(f.id, lerp(ox, sx, k), lerp(oy, sy, k) - math.sin(k * math.pi) * 60, { rot = (1 - k) * 1.5 })
                else
                    Stage.shard(f.id, ox, oy, { rot = math.sin(gt * 2 + f.i) * 0.3 })
                end
            end
        end, { Stage.mirrorLight(K.MX, K.MF, 0.15 + 0.5 * #placed / #ids + 0.25 * pulse),
               Stage.light(MONSTER_X, ORBIT_Y, 300, 0.35 * #flying / #ids) })
    end,
}

-- ── 3. El espejo, entero ────────────────────────────────────────────────────
F.whole = {
    enter = function(c) c.v.set = Stage.set('crater') end,
    events = {
        { beat = 0, fn = function(c)
            c.sfx('storyRestore')
            local gx, gy = Stage.glassCenter(K.MX, K.MF)
            Stage.spark(gx, gy, 24, 40, 300, { life = 1.0, s = 4 })
        end },
    },
    draw = function(c, t)
        local gx, gy = Stage.glassCenter(K.MX, K.MF)
        Stage.drawSet(c.v.set, K.CAMX, K.CAMY, function()
            Stage.mirror(K.MX, K.MF, { whole = true })
            Stage.monster(MONSTER_X, K.FLOOR, { frame = 1 })
        end, { Stage.mirrorLight(K.MX, K.MF, 1.0, 520) }, function()
            Stage.rays(gx, gy, t * 2, 10, 360, 0.16 + 0.1 * (1 - c.k(0, c.dur)))
            Stage.mirror(K.MX, K.MF, { whole = true })                   -- (el espejo, encima de sus rayos: brilla)
        end)
    end,
}

-- ── 4. El Reflejo vuelve ────────────────────────────────────────────────────
local ORB_X, ORB_Y = 760, 430                       -- donde se queda flotando el aleteo, fuera ya del espejo
F['return'] = {
    enter = function(c) c.v.set = Stage.set('crater') end,
    events = {
        { cue = 'pull', fn = function(c) c.sfx('mirrorPortal') end },
        { cue = 'inside', fn = function(c)
            c.sfx('mirrorWarp')
            local gx, gy = Stage.glassCenter(K.MX, K.MF)
            Particles.emit('mirror_glint', gx, gy)
            Particles.emit('shake_small', gx, gy)
        end },
        { cue = 'orb', fn = function(c) c.sfx('storyOrb', 1.2) end },
    },
    update = function(c, t, dt)
        local gx, gy = Stage.glassCenter(K.MX, K.MF)
        if t >= c.at('pull') and t < c.at('inside') and math.random() < 0.5 then      -- todo lo suyo, hacia el cristal
            Stage.spark(gx - 200 - math.random() * 300, gy - 150 + math.random() * 300, 1, 10, 20, { life = 0.7, s = 3, tx = gx, ty = gy })
        end
    end,
    draw = function(c, t)
        local pull, inside, orb = c.at('pull'), c.at('inside'), c.at('orb')
        local gx, gy = Stage.glassCenter(K.MX, K.MF)
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, K.CAMX + sx, K.CAMY + sy, function()
            Stage.mirror(K.MX, K.MF, { whole = true })
            Stage.monster(MONSTER_X, K.FLOOR, { frame = 1 })
            if t >= pull and t < inside then
                -- arrastrado desde la chimenea: patalea, se agarra al aire, encoge al entrar
                local u = c.k(pull, inside)
                local x = lerp(K.HOLE_X, gx, easeIn(u)) + math.sin(u * 22) * 26 * (1 - u)
                local y = lerp(40, gy, smooth(u)) + math.cos(u * 17) * 30 * (1 - u)
                Stage.monster(x, y, { invert = true, frame = (math.floor(t * 12) % 2 == 0) and 1 or 3,
                                      angle = math.sin(t * 16) * 0.5, scale = lerp(PLAYER_SCALE, 2.5, easeIn(c.k(lerp(pull, inside, 0.75), inside))) })
            end
        end, { Stage.mirrorLight(K.MX, K.MF, 0.75, 460) }, function()
            Stage.rays(gx, gy, t * 2, 10, 300, 0.1)
            Stage.mirror(K.MX, K.MF, { whole = true })
            if t >= orb then
                local u = easeOut(c.k(orb, orb + c.b(1)))
                Stage.orb(lerp(gx, ORB_X, u), lerp(gy, ORB_Y, u) + math.sin(t * 3) * 6, t, 4)
            end
        end)
        if t >= inside then Stage.flash(0.6 * (1 - (t - inside) / 0.3)) end
    end,
}

-- ── 5. La luz recorre las islas ─────────────────────────────────────────────
local ZOOM_FAR, ZOOM_NEAR = 0.5, 2
local function farCam()
    local _, SM = Stage.map()
    local pw, ph = SM.mapSize()
    return (pw - WINDOW_W / ZOOM_FAR) / 2, (ph - WINDOW_H / ZOOM_FAR) / 2
end
local RING_MAX = 2100

F.light = {
    enter = function(c)
        local map = Stage.map()
        K.setBosses(map, { 1, 1, 1, 1, 1, 1 }, 0)
        c.v.hit = {}
    end,
    events = { { cue = 'wave', fn = function(c) c.sfx('storyWave') end } },
    update = function(c, t, dt)
        local _, SM = Stage.map()
        local vx, vy = SM.bossXY(6)
        local R = RING_MAX * easeOut(c.k(c.at('wave'), c.b(10)))
        for i, tg in ipairs(K.targets()) do
            local d = math.sqrt((tg.x - vx) ^ 2 + (tg.y - vy) ^ 2)
            if not c.v.hit[i] and R >= d and t >= c.at('wave') then
                c.v.hit[i] = true
                c.sfx('storyBell', 2 ^ (SCALE[i] / 12), 0.8)
                Stage.spark(tg.x, tg.y - 24, 10, 14, 150, { life = 0.7, s = 6 })
            end
        end
    end,
    draw = function(c, t)
        local map, SM = Stage.map()
        local cx, cy = farCam()
        local vx, vy = SM.bossXY(6)
        local k = c.k(c.at('wave'), c.b(10))
        local R = RING_MAX * easeOut(k)
        map:filmDraw(cx, cy, ZOOM_FAR, { extra = function(ox, oy)
            love.graphics.push()
            love.graphics.translate(-ox, -oy)
            K.drawSnow(map, 1)
            Stage.rays(vx, vy - 30, t * 2, 8, 150, 0.35)
            if t >= c.at('wave') then                             -- la onda: tres anillos duros
                love.graphics.setBlendMode('add')
                for n = 0, 2 do
                    local r = R - n * 46
                    if r > 0 then
                        love.graphics.setColor(1, 1, 0.85, (0.55 - n * 0.16) * (1 - k * 0.6))
                        love.graphics.setLineWidth(22 - n * 6)
                        love.graphics.circle('line', vx, vy - 30, r, 64)
                    end
                end
                love.graphics.setLineWidth(1)
                love.graphics.setBlendMode('alpha')
                love.graphics.setColor(1, 1, 1, 1)
            end
            Stage.drawSparks()
            love.graphics.pop()
        end })
        Stage.flash(0.25 * (1 - k) * c.k(c.at('wave'), c.at('wave') + 0.2), 1, 1, 0.85)
    end,
}

-- ── 6. Todos, pequeños otra vez ─────────────────────────────────────────────
F.shrink = {
    enter = function(c) c.v.done = 0; c.v.sizes = { 1, 1, 1, 1, 1, 1 } end,
    update = function(c, t, dt)
        local each = c.at('each')
        for i = c.v.done + 1, 6 do
            if t >= c.at('first') + (i - 1) * each + c.b(0.5) then
                c.v.done = i
                c.sfx('storyShrink', 0.9 + i * 0.06)
                local tg = K.targets()[i]
                Stage.spark(tg.x, tg.y - 24, 7, 30, 200, { life = 0.45, s = 2 })
            end
        end
    end,
    draw = function(c, t)
        local map = Stage.map()
        local each, tgs = c.at('each'), K.targets()
        local i = math.min(6, math.floor((t - c.at('first')) / each) + 1)
        local wide = t >= c.at('first') + 6 * each
        for n = 1, 6 do
            local t0 = c.at('first') + (n - 1) * each + c.b(0.5)
            c.v.sizes[n] = (t < t0) and 1 or lerp(1, K.SMALL, K.elastic((t - t0) / c.b(0.9)))
        end
        K.setBosses(map, c.v.sizes, 0)
        local function extra(ox, oy)
            love.graphics.push()
            love.graphics.translate(-ox, -oy)
            K.drawSnow(map, c.v.sizes[4])
            Stage.drawSparks()
            love.graphics.pop()
        end
        if wide then
            local cx, cy = farCam()
            map:filmDraw(cx, cy, ZOOM_FAR, { extra = extra })
        else
            local tg = tgs[i]
            map:filmDraw(tg.x - WINDOW_W / ZOOM_NEAR / 2, tg.y - 26 - WINDOW_H / ZOOM_NEAR / 2, ZOOM_NEAR, { extra = extra })
            local t0 = c.at('first') + (i - 1) * each + c.b(0.5)
            if t >= t0 then Stage.flash(0.35 * (1 - (t - t0) / 0.18), 1, 1, 0.85) end
        end
    end,
}

-- ── 7. El aleteo ────────────────────────────────────────────────────────────
-- Altura sobre el suelo (negativa = arriba) con los aleteos dados hasta t: la física del modo Flappy
local function flapY(t, times)
    local y, vy, last = 0, 0, nil
    local function advance(dt)
        y = y + vy * dt + 0.5 * GRAVITY * dt * dt
        vy = vy + GRAVITY * dt
        if y > 0 then y, vy = 0, 0 end
    end
    for _, ft in ipairs(times) do
        if ft > t then break end
        if last then advance(ft - last) end
        vy, last = FLAP_VELOCITY, ft
    end
    if last then advance(t - last) end
    return y, last
end

F.flap = {
    enter = function(c)
        c.v.set = Stage.set('crater')
        -- los aleteos: uno, luego dos seguidos, y ya sin parar hasta salir por la chimenea
        local times = { c.at('try1'), c.at('try2'), c.at('try2') + c.b(0.45) }
        local ft = c.at('rise')
        while ft < c.dur do times[#times + 1] = ft; ft = ft + c.b(0.4) end
        c.v.times, c.v.n = times, 0
    end,
    events = {
        { cue = 'orb', fn = function(c) c.sfx('storyOrb', 1.4) end },
        { beat = 2, fn = function(c)
            c.sfx('storyRestore', 1.5, 0.6)
            Stage.spark(MONSTER_X, K.FLOOR - 10, 16, 10, 220, { life = 0.7, s = 4 })
        end },
    },
    update = function(c, t, dt)
        for i = c.v.n + 1, #c.v.times do
            if t >= c.v.times[i] then
                c.v.n = i
                c.sfx('jump')
                Stage.spark(c.v.x or MONSTER_X, (c.v.y or K.FLOOR) + 30, 3, 12, 50, { life = 0.35, s = 3, vy = 60 })
            end
        end
    end,
    draw = function(c, t)
        local got = c.b(2)
        local dy, last = flapY(t, c.v.times)
        local x = lerp(MONSTER_X, K.HOLE_X + 30, smooth(c.k(c.at('rise'), c.dur)))
        local y = K.FLOOR + dy
        c.v.x, c.v.y = x, y
        local puff = math.max(K.puff(t, got), last and K.puff(t, last) or 1)
        local frame = (dy < -2) and 2 or 1
        local ou = easeIn(c.k(c.at('orb'), got))
        Stage.drawSet(c.v.set, K.CAMX, K.CAMY, function()
            Stage.mirror(K.MX, K.MF, { whole = true, reflection = function(gx, gy)
                Stage.monster(gx + (MONSTER_X - x) * 0.2, gy + 34 + dy * 0.66, { facing = -1, scale = 4, alpha = 0.8, color = { 0.75, 0.88, 1 }, frame = frame, puff = puff })
            end })
            Stage.monster(x, y, { frame = frame, puff = puff })
        end, { Stage.mirrorLight(K.MX, K.MF, 0.6), Stage.light(x, y, 200, (t >= got) and 0.3 or 0) }, function()
            if t < got then Stage.orb(lerp(ORB_X, MONSTER_X, ou), lerp(ORB_Y, K.FLOOR - 10, ou) + math.sin(t * 3) * 6 * (1 - ou), t, 4) end
        end)
        if t >= got then Stage.flash(0.5 * (1 - (t - got) / 0.3)) end
    end,
}

-- ── 8. Volando a casa ───────────────────────────────────────────────────────
F.home = {
    enter = function(c)
        local rig = K.flappyRig(-999, 0)
        rig.quiet = c.film.mute
        rig.player.y = 420
        c.v.rig, c.v.camX, c.v.piped = rig, 0, false
    end,
    update = function(c, t, dt)
        local rig = c.v.rig
        if not c.v.piped and t >= c.at('pipes') then
            c.v.piped = true
            for i = 1, 6 do K.addPipe(rig, WINDOW_W + 60 + (i - 1) * 380, i) end
        end
        K.flappyStep(rig, dt)
        c.v.camX = c.v.camX + 140 * dt
    end,
    draw = function(c, t)
        local rig = c.v.rig
        local k = smooth(c.k(c.at('cross'), c.at('pipes')))
        if k < 1 then Stage.sky({ background = 'volcano', time = 'day' }, c.v.camX, 0) end
        if k > 0 then Stage.flappyBg(rig.scroll, K.SKY_BLUE, k) end
        K.flappyDraw(rig)
        if t >= c.at('logo') then
            local logo = Stage.img('assets/images/menus/logo.png')
            if logo then
                local u = c.k(c.at('logo'), c.at('logo') + c.b(1.5))
                local s = 12
                local y = lerp(-200, 96, K.elastic(u))
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.draw(logo, math.floor(WINDOW_W / 2 - logo:getWidth() * s / 2) + 6, math.floor(y) + 6, 0, s, s)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(logo, math.floor(WINDOW_W / 2 - logo:getWidth() * s / 2), math.floor(y), 0, s, s)
            end
        end
    end,
}

return F
