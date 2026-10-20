-- src/story/films/lair.lua
-- LA GUARIDA: la película de antes de "Ruta del Espejo" (el jefe final; la primera vez que se entra). Sin texto.
-- Tiempos y momentos (cues): assets/story/films.json. Guion: docs/story/story.md.
--   escape   el final de la huida: el monstruo cruza el lago de lava con el doble salto; el Reflejo se para en la
--            orilla, se ríe... y se rompe en pedazos: se ha ido
--   night    cae la noche. El monstruo, solo y sin aliento. A lo lejos brilla el fragmento del centro; la risa,
--            con eco; y uno tras otro se encienden espejos flotantes: un camino hacia la guarida del Reflejo
--   follow   respira hondo; sus seis fragmentos brillan hacia allí; y echa a andar, en la oscuridad
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Particles = require 'src/fx/Particles'

local lerp, smooth, easeIn, easeOut = K.lerp, K.smooth, K.easeIn, K.easeOut
local F = {}

local FL = K.LFLOOR
local RUN_V = 330
local REST_X = 3300                      -- donde se queda el monstruo, pasado el lago
local EDGE_X = K.LAKE[1] - 70            -- donde se para el Reflejo, en la orilla
local GLINT_X, GLINT_Y = 3660, 300       -- el brillo del fragmento del centro, a lo lejos
-- el camino de espejos flotantes (x, y del mundo)
local TRAIL = { { 3460, 380 }, { 3560, 330 }, { 3650, 290 }, { 3740, 260 } }

local function carried(c) c.shared.ids = c.shared.ids or K.carryIds(c.xtra); return c.shared.ids end

-- ── 1. El final de la huida ─────────────────────────────────────────────────
-- x del monstruo y su altura: corre, cruza el lago con dos saltos (el segundo, el doble salto) y se para
local function runner(c, t)
    local leap = c.at('leap')
    local x0 = 2180
    local xl = x0 + leap * RUN_V                         -- donde salta
    local air = c.b(2.2)
    if t < leap then return x0 + t * RUN_V, 0, 'run' end
    if t < leap + air then
        local u = (t - leap) / air
        local x = lerp(xl, K.LAKE[2] + 80, u)
        -- dos arcos: el salto y, a media subida, el doble salto (más alto)
        local h = (u < 0.35) and math.sin(u / 0.35 * math.pi * 0.5) * 130
                  or 130 + math.sin((u - 0.35) / 0.65 * math.pi * 0.5 + 0.0) * 60 - easeIn((u - 0.35) / 0.65) * 190
        return x, math.max(0, h), (u < 0.6) and 'rise' or 'fall'
    end
    local x = K.LAKE[2] + 80 + (t - leap - air) * RUN_V * 0.7
    return math.min(REST_X, x), 0, (x < REST_X) and 'run' or 'stop'
end

F.escape = {
    enter = function(c) c.v.set = Stage.set('ladera'); c.v.laughs = 0 end,
    events = {
        { cue = 'leap', fn = function(c) c.sfx('jump') end },
        { beat = 3.8, fn = function(c) c.sfx('jump', 1.15) end },
        { cue = 'stop', fn = function(c) c.sfx('step', 0.8); c.sfx('step', 0.9, 0.7) end },
        { cue = 'shatter', fn = function(c)
            c.sfx('mirrorWarp')
            Particles.emit('mirror_shards', EDGE_X, FL - 20)
            Stage.spark(EDGE_X, FL - 20, 18, 30, 260, { life = 0.7, s = 3, g = 300 })
        end },
        { beat = 10.5, fn = function(c) c.sfx('storyPant', 1, 0.9) end },
    },
    update = function(c, t, dt)
        local _, h, kind = runner(c, t)
        if kind == 'run' and h == 0 then K.steps(c, t * 1.6, dt * 1.6, 0, c.dur * 1.6) end
        local lt = t - (c.at('stop') + c.b(1))                   -- la risa, en la orilla
        while lt >= 0 and c.v.laughs < 5 and lt >= (1 / 6) + c.v.laughs * (2 / 6) do
            c.sfx('mirrorLaugh', 0.9 + math.random() * 0.16)
            c.v.laughs = c.v.laughs + 1
        end
    end,
    draw = function(c, t)
        local leap, stop, shatter = c.at('leap'), c.at('stop'), c.at('shatter')
        local mx, h, kind = runner(c, t)
        local mo
        if kind == 'run' then mo = K.pose('walk', t * 1.6)
        elseif kind == 'rise' then mo = K.pose('rise'); mo.puff = math.max(K.puff(t, leap), K.puff(t, c.b(3.8)))
        elseif kind == 'fall' then mo = K.pose('fall', t)
        else
            -- se para, se da la vuelta y mira atrás; sin aliento
            mo = (t > c.b(10.3)) and K.pose('crouch') or K.pose('idle')
            mo.facing = -1
            mo.puff = 1 + 0.06 * math.max(0, math.sin(t * 9))
        end
        mo.facing = mo.facing or 1
        -- el Reflejo: corre detrás hasta la orilla; se para, se ríe y se rompe
        local rx = math.min(EDGE_X, 1960 + t * RUN_V)
        local ro, trail = K.pose('walk', t * 1.8), 3
        if rx >= EDGE_X then ro, trail = K.pose('idle'), 0 end
        ro.facing = 1
        local camX = math.max(1900, math.min(2420, mx - 760))
        local sx, sy = Particles.shakeOffset()
        Stage.drawSet(c.v.set, camX + sx, K.LCAMY + sy, function()
            if t < shatter then
                local laughT = t - (stop + c.b(1))
                if laughT >= 0 then Stage.laugh(rx, FL, laughT, { facing = 1 })
                else K.reflex(rx, FL, ro, trail) end
                local a = t * 2.4
                Stage.shard('7', rx + math.cos(a) * 60, FL - 20 + math.sin(a) * 22, { s = 2, rot = t * 2 })
            end
            Stage.monster(mx, FL - h, mo)
            K.carry(mx, FL - h, t, carried(c), 0.3, 0)
        end)
        if t >= shatter then Stage.flash(0.35 * (1 - (t - shatter) / 0.3), 0.8, 0.95, 1) end
    end,
}

-- ── 2. Cae la noche ─────────────────────────────────────────────────────────
local NIGHT_CAM = 2600

local function portalK(c, t, i)
    local t0 = c.at('trail') + (i - 1) * c.b(0.5)
    return (t >= t0) and math.min(1, (t - t0) / 0.2) * 0.55 or 0
end

F.night = {
    enter = function(c) c.v.set = Stage.set('ladera_noche'); c.v.lit = 0 end,
    events = {
        { beat = 0.3, fn = function(c) c.sfx('storyPant', 0.95, 0.8) end },
        { beat = 1.5, fn = function(c) c.sfx('storyRumble', 0.8, 0.6) end },
        { cue = 'glint', fn = function(c) c.sfx('storyGlint'); Stage.spark(GLINT_X, GLINT_Y, 10, 6, 90, { life = 0.7, s = 4 }) end },
        { cue = 'laugh', fn = function(c) c.sfx('storyLaughFar') end },
    },
    update = function(c, t, dt)
        for i = c.v.lit + 1, #TRAIL do
            if portalK(c, t, i) > 0 then c.v.lit = i; c.sfx('mirrorPortal', 0.9 + i * 0.1, 0.7) end
        end
    end,
    draw = function(c, t)
        local glint, laugh = c.at('glint'), c.at('laugh')
        local mo = (t < c.b(2)) and K.pose('crouch') or K.pose('idle')
        mo.facing = (t < glint + c.b(0.3)) and -1 or 1
        mo.puff = 1 + 0.06 * math.max(0, math.sin(t * 7)) * (1 - c.k(0, c.b(3)))
        local my = FL
        if t >= laugh and t < laugh + c.b(1.2) then my = FL + math.floor(math.sin(t * 60) * 2) end   -- (un escalofrío)
        Stage.drawSet(c.v.set, NIGHT_CAM, K.LCAMY, function()
            for i, p in ipairs(TRAIL) do K.portal(p[1], p[2], portalK(c, t, i), t + i) end
            Stage.monster(REST_X, my, mo)
            K.carry(REST_X, my, t, carried(c), (t >= glint) and (0.5 + 0.5 * math.sin(t * 6)) or 0, 0)
        end, nil, function()
            if t >= glint then
                local tw = 0.5 + 0.5 * math.sin((t - glint) * 9)
                Stage.rays(GLINT_X, GLINT_Y, t * 3, 4, 26 + 22 * tw, 0.6, { 0.8, 0.95, 1 })
                Stage.shard('7', GLINT_X, GLINT_Y, { s = 1, rot = t })
            end
        end)
    end,
}

-- ── 3. Hacia la guarida ─────────────────────────────────────────────────────
F.follow = {
    enter = function(c) c.v.set = Stage.set('ladera_noche') end,
    events = {
        { cue = 'breath', fn = function(c) c.sfx('storyPant', 0.75, 1) end },
        { cue = 'walk', fn = function(c) c.sfx('storyGlint', 1.1, 0.6) end },
    },
    update = function(c, t, dt) K.steps(c, t, dt, c.at('walk'), c.dur) end,
    draw = function(c, t)
        local breath, walk = c.at('breath'), c.at('walk')
        local x = REST_X + math.max(0, t - walk) * 170
        local o
        if t < breath then o = K.pose('idle')
        elseif t < walk then
            -- respira hondo: se agacha un poco, se hincha... y asiente con un saltito
            local u = c.k(breath, walk)
            o = (u < 0.3) and K.pose('crouch') or K.pose('idle')
            o.puff = 1 + 0.2 * math.sin(c.k(breath + c.b(0.5), breath + c.b(2)) * math.pi)
        else o = K.pose('walk', t - walk) end
        o.facing = 1
        local glow = 0.4 + 0.6 * c.k(breath, walk)
        local camX = NIGHT_CAM + 300 + math.max(0, t - walk) * 90
        Stage.drawSet(c.v.set, camX, K.LCAMY, function()
            for i, p in ipairs(TRAIL) do K.portal(p[1], p[2], 0.55, t + i) end
            Stage.monster(x, FL, o)
            -- los fragmentos brillan y se inclinan hacia allí (por delante de él)
            K.carry(x + 12 * glow, FL, t, carried(c), glow * (0.6 + 0.4 * math.sin(t * 6)), 0)
        end, nil, function()
            local tw = 0.5 + 0.5 * math.sin(t * 9)
            Stage.rays(GLINT_X, GLINT_Y, t * 3, 4, 26 + 22 * tw, 0.6, { 0.8, 0.95, 1 })
            Stage.shard('7', GLINT_X, GLINT_Y, { s = 1, rot = t })
        end)
    end,
}

return F
