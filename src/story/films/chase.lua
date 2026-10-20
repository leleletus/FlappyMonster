-- src/story/films/chase.lua
-- LA PERSECUCIÓN: la película de antes de "La Huida del Espejo" (la primera vez que se entra). Sin texto.
-- Tiempos y momentos (cues): assets/story/films.json. Guion: docs/story/story.md.
--   arrive   tras la erupción, el monstruo sube por la ladera del volcán con sus seis fragmentos; se paran:
--            notan el séptimo cerca
--   ambush   una risa; un espejo flotante; el REFLEJO cae en picado detrás de él, con el fragmento del centro.
--            Se ríe... y mira los seis fragmentos: se agacha para saltar
--   run      ¡a correr! El monstruo huye ladera arriba, salta la zanja de lava; el Reflejo se le echa encima y
--            falla por poco. La carrera sigue en el nivel
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Particles = require 'src/fx/Particles'

local lerp, smooth, easeIn, easeOut = K.lerp, K.smooth, K.easeIn, K.easeOut
local F = {}

local FL = K.LFLOOR
local STOP_X = 560                       -- donde se para el monstruo
local PORTAL_X, PORTAL_Y = 300, 190      -- el espejo flotante (detrás de él)
local REF_X = 300                        -- donde cae el Reflejo

local function carried(c) c.shared.ids = c.shared.ids or K.carryIds(c.xtra); return c.shared.ids end

-- ── 1. La ladera ────────────────────────────────────────────────────────────
F.arrive = {
    enter = function(c) c.v.set = Stage.set('ladera') end,
    events = {
        { beat = 0.2, fn = function(c) c.sfx('storyRumble', 1, 0.8) end },
        { cue = 'look', fn = function(c) c.sfx('storyGlint', 0.8, 0.8) end },
        { beat = 9.5, fn = function(c) c.sfx('storyGlint', 0.7, 0.6) end },
    },
    update = function(c, t, dt) K.steps(c, t, dt, 0, c.at('stop')) end,
    draw = function(c, t)
        local stop, look = c.at('stop'), c.at('look')
        local x = lerp(-60, STOP_X, c.k(0, stop))
        local o = (t < stop) and K.pose('walk', t) or K.pose('idle')
        -- al notar el séptimo: mira hacia el cráter (adelante y atrás)
        if t >= look then o.facing = (math.floor((t - look) / c.b(1.5)) % 2 == 0) and 1 or -1 end
        local glow = c.k(look, look + c.b(1)) * (0.6 + 0.4 * math.sin(t * 10))
        Stage.drawSet(c.v.set, 0, K.LCAMY, function()
            Stage.monster(x, FL, o)
            K.carry(x, FL, t, carried(c), glow, (t >= look) and 2 or 0)
        end)
    end,
}

-- ── 2. La emboscada ─────────────────────────────────────────────────────────
F.ambush = {
    enter = function(c) c.v.set = Stage.set('ladera'); c.v.laughs = 0 end,
    events = {
        { cue = 'laugh', fn = function(c) c.sfx('storyLaughFar') end },
        { cue = 'portal', fn = function(c) c.sfx('mirrorAppear') end },
        { beat = 5.3, fn = function(c) c.sfx('mirrorPortal') end },
        { cue = 'drop', fn = function(c) c.sfx('jump', 0.75) end },
        { cue = 'land', fn = function(c)
            c.sfx('gpImpact', 0.85, 0.9)
            Particles.emit('shake_big', REF_X, FL)
            Stage.spark(REF_X, FL + 40, 10, 20, 200, { life = 0.5, s = 3, vy = -60 })
        end },
        { beat = 11, fn = function(c) c.sfx('glassWarn', 1.2, 0.6) end },
    },
    update = function(c, t, dt)
        local lt = t - c.at('grin')                           -- la risa: cinco carcajadas, como el jefe
        while lt >= 0 and c.v.laughs < 5 and lt >= (1 / 6) + c.v.laughs * (2 / 6) do
            c.sfx('mirrorLaugh', 0.92 + math.random() * 0.16)
            c.v.laughs = c.v.laughs + 1
        end
    end,
    draw = function(c, t)
        local laugh, portal, drop, land, grin = c.at('laugh'), c.at('portal'), c.at('drop'), c.at('land'), c.at('grin')
        -- el monstruo: un respingo con la risa, mira a un lado y a otro; al caer el Reflejo, se encoge; luego retrocede
        local mx, my, mo = STOP_X, FL, K.pose('idle')
        local h
        h, mo = K.hop(c.k(laugh, laugh + c.b(0.5)), 24, t)
        my = FL - h
        if t >= laugh and t < portal then mo.facing = (math.floor((t - laugh) / c.b(0.75)) % 2 == 0) and -1 or 1
        else mo.facing = -1 end
        if t >= land and t < land + c.b(1) then mo = K.pose('crouch'); mo.facing = -1 end
        if t >= c.b(9.5) then
            local u = c.k(c.b(9.5), c.b(11))
            mx = lerp(STOP_X, STOP_X + 50, smooth(u))
            mo = (u > 0 and u < 1) and K.pose('walk', t) or K.pose('idle')
            mo.facing = -1                                    -- (retrocede sin darle la espalda)
        end
        -- el espejo flotante: se abre, el Reflejo dentro; cae en picado
        local pk = 0
        if t >= portal then pk = math.min(1, (t - portal) / 0.25) * (1 - c.k(land, land + 0.3)) end
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, sx, K.LCAMY + sy, function()
            K.portal(PORTAL_X, PORTAL_Y, pk, t)
            if t >= portal + 0.3 and t < drop then
                K.reflex(PORTAL_X, PORTAL_Y + 10, { frame = 5, facing = 1, sx = 0.9, sy = 0.9, alpha = c.k(portal + 0.3, portal + 0.6) })
            elseif t >= drop and t < land then
                local u = c.k(drop, land)
                K.reflex(lerp(PORTAL_X, REF_X, u), lerp(PORTAL_Y + 10, FL, easeIn(u)), { frame = 2, facing = 1, sx = 0.85, sy = 1.3 }, 3, 0, -40)
            elseif t >= land then
                local rx = REF_X
                if t >= grin and t < grin + c.b(2.5) then
                    Stage.laugh(rx, FL, t - grin, { facing = 1 })
                elseif t >= c.b(10.5) then
                    -- mira los fragmentos... y se agacha para saltar (tiembla, como antes de embestir)
                    local j = math.floor(math.sin(t * 70) * 3)
                    K.reflex(rx + j, FL + 6, { frame = 5, facing = 1, sx = 1.1, sy = 0.9 })
                else
                    K.reflex(rx, FL, { frame = (t < land + c.b(0.4)) and 5 or 3, facing = 1 })
                end
                -- el fragmento del centro, girando a su alrededor
                local a = t * 2.4
                Stage.shard('7', rx + math.cos(a) * 64, FL - 20 + math.sin(a) * 22, { s = 2, rot = math.sin(t * 1.3) * 0.3 })
            end
            Stage.monster(mx, my, mo)
            K.carry(mx, my, t, carried(c), 0.5 + 0.5 * math.sin(t * 8), (t >= c.b(10.5)) and 3 or 0)
        end, nil, function()
            if t >= drop and t < land then K.mark(REF_X, FL + 48, t) end
        end)
    end,
}

-- ── 3. ¡A correr! ───────────────────────────────────────────────────────────
local RUN_V = 330                       -- px/s del monstruo corriendo (el Reflejo, igual: no lo alcanza)
local X0 = STOP_X + 50

-- x del monstruo y su altura sobre el suelo (salta la zanja de lava)
local function runner(c, t)
    local go = c.at('go')
    local x = X0 + math.max(0, t - go) * RUN_V
    local h = 0
    local a, b = K.DITCH[1] - 90, K.DITCH[2] + 70
    if x > a and x < b then h = math.sin((x - a) / (b - a) * math.pi) * 120 end
    -- el respingo al fallar el Reflejo: un saltito
    local miss = c.at('miss')
    if t >= miss and t < miss + 0.3 then h = math.max(h, math.sin((t - miss) / 0.3 * math.pi) * 50) end
    return x, h
end

F.run = {
    enter = function(c) c.v.set = Stage.set('ladera'); c.v.jumped = false end,
    events = {
        { cue = 'jump', fn = function(c) c.sfx('jump') end },
        { cue = 'go', fn = function(c) c.sfx('mirrorLaugh', 0.85, 0.7) end },
        { cue = 'pounce', fn = function(c) c.sfx('jump', 0.7); c.sfx('mirrorPortal', 1.2, 0.6) end },
        { cue = 'miss', fn = function(c)
            c.sfx('gpImpact', 0.9, 0.9); c.sfx('jump', 1.2, 0.7)
            Particles.emit('shake_small', 0, 0)
            Particles.emit('mirror_shards', c.v.missX or 0, FL + 30)
        end },
    },
    update = function(c, t, dt)
        local go = c.at('go')
        if t >= go then K.steps(c, t * 1.6, dt * 1.6, go * 1.6, c.dur * 1.6) end
        local x = runner(c, t)
        if not c.v.jumped and x > K.DITCH[1] - 90 then c.v.jumped = true; c.sfx('jump') end
    end,
    draw = function(c, t)
        local jump, go, pounce, miss = c.at('jump'), c.at('go'), c.at('pounce'), c.at('miss')
        -- el monstruo: respingo (se da la vuelta) y a correr
        local mx, h = runner(c, t)
        local mo
        if t < jump then mo = K.pose('idle'); mo.facing = -1
        elseif t < go then
            local hh
            hh, mo = K.hop(c.k(jump, go), 60, t)
            h = hh
            mo.facing = (t > (jump + go) / 2) and 1 or -1
        elseif h > 0 then mo = K.pose(h > 60 and 'rise' or 'fall', t); mo.facing = 1
        else mo = K.pose('walk', t * 1.6); mo.facing = 1 end
        -- el Reflejo: arranca detrás, se lanza en plancha (salto) y cae donde estaba el monstruo... por poco
        local rgo = go + 0.2
        local rx, ry, ro, trail = REF_X, FL, { frame = 5, facing = 1, sx = 1.1, sy = 0.9 }, 0
        local px0 = REF_X + (pounce - rgo) * RUN_V * 1.05
        local landX = runner(c, miss) - 70
        c.v.missX = landX
        if t >= rgo and t < pounce then
            rx = REF_X + (t - rgo) * RUN_V * 1.05
            ro, trail = K.pose('walk', t * 1.8), 3
        elseif t >= pounce and t < miss then
            local u = c.k(pounce, miss)
            rx, ry = lerp(px0, landX, u), FL - math.sin(u * math.pi) * 170
            ro, trail = { frame = (u < 0.5) and 2 or 1, sx = 0.9, sy = 1.15 }, 3
        elseif t >= miss then
            local u = c.k(miss, miss + c.b(1))
            rx = landX + math.max(0, t - miss - c.b(1)) * RUN_V
            ro = (u < 1) and { frame = 5, sx = 1.15, sy = 0.85 } or K.pose('walk', t * 1.8)
            trail = (u < 1) and 0 or 3
        end
        if t < rgo then ro.sx = 1.1 + 0.05 * math.sin(t * 70) end
        ro.facing = 1
        -- la cámara sigue al monstruo
        local camX = math.max(0, mx - 760)
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, camX + sx, K.LCAMY + sy, function()
            K.reflex(rx, ry, ro, trail)
            local a = t * 2.4
            Stage.shard('7', rx - 40 + math.cos(a) * 30, ry - 60 + math.sin(a) * 14, { s = 2, rot = t * 3 })
            Stage.monster(mx, FL - h, mo)
            K.carry(mx, FL - h, t, carried(c), 0.4, 0)
        end, nil, function()
            if t >= pounce and t < miss then K.mark(landX, FL + 48, t) end
        end)
    end,
}

return F
