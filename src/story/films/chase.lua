-- src/story/films/chase.lua
-- LA PERSECUCIÓN: la película de antes de "La Huida del Espejo" (la primera vez que se entra). Sin texto.
-- Tiempos y momentos (cues): assets/story/films.json. Guion: docs/story/story.md.
-- El monstruo y el Reflejo son ACTORES (src/story/Actor.lua): cuerpos de verdad del juego, con su física, sus saltos
-- y su doble salto, movidos por un guion de entradas. Lo único "mágico" es lo que en el juego también lo es: el
-- espejo flotante del Reflejo y su salto en plancha.
--   arrive   tras la erupción, sube por la ladera; se para, se agacha y SACA sus seis fragmentos: brillan y tiemblan
--            (notan el séptimo cerca)
--   ambush   una risa; un espejo flotante; el REFLEJO cae en picado detrás de él, con el fragmento del centro. Se
--            ríe... y mira los seis: se agacha para saltar
--   run      ¡a correr! (al ritmo de "¡Corre!", la música del nivel): salta del susto, huye, salta la zanja de lava;
--            el Reflejo se lanza en plancha y el doble salto lo salva por poco. Sale corriendo de cuadro; la música
--            se queda en la dominante y enlaza con la del nivel
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Actor = require 'src/story/Actor'
local Particles = require 'src/fx/Particles'

local lerp, easeIn = K.lerp, K.easeIn
local F = {}

local FL = K.LFLOOR
local CAM0 = 400                         -- la cámara de las dos primeras escenas
local START_X = 210                      -- de donde viene andando (fuera de cuadro; dentro del decorado): llega en 'stop'
local STOP_X = 960                       -- donde se para el monstruo
local PORTAL_X, PORTAL_Y = 700, 190      -- el espejo flotante (detrás de él)
local REF_X = 700                        -- donde cae el Reflejo

local function ids(c) c.shared.ids = c.shared.ids or K.carryIds(c.xtra); return c.shared.ids end
local function set() return Stage.set('ladera') end
local function monster(c)
    if not c.shared.m then
        c.shared.m = Actor.new(set().level, START_X, FL, { mute = c.film.mute })
    end
    return c.shared.m
end
local function reflection(c)
    if not c.shared.r then
        c.shared.r = Actor.new(set().level, REF_X, FL, { invert = true, pitch = 0.8, mute = c.film.mute })
        c.shared.r.face = 1
    end
    return c.shared.r
end

-- El fragmento del centro, en manos del Reflejo: flota sobre su cabeza, con su brillo
local function centre(x, y, t, glow)
    local sx, sy = math.floor(x), math.floor(y - 108 + math.sin(t * 3) * 4)
    K.shardGlow('7', sx, sy, 2, 0, glow or 0.8, t)
    Stage.shard('7', sx, sy, { s = 2 })
end

-- ── 1. La ladera ────────────────────────────────────────────────────────────
F.arrive = {
    enter = function(c) monster(c) end,
    events = {
        { beat = 0.2, fn = function(c) c.sfx('storyRumble', 1, 0.8) end },
        { cue = 'take', fn = function(c) c.sfx('shardDrop', 0.8, 0.7) end },
        { cue = 'glow', fn = function(c) c.sfx('storyGlint', 0.8, 0.8) end },
        { beat = 9.5, fn = function(c) c.sfx('storyGlint', 0.7, 0.6) end },
    },
    update = function(c, t, dt)
        local m = monster(c)
        m.mx = (m.body.x < STOP_X) and 1 or 0
        m.crouch = t >= c.at('take') and t < c.at('take') + c.b(0.6)
        -- al notar el séptimo: mira a un lado y a otro
        if t >= c.at('glow') then m.face = (math.floor((t - c.at('glow')) / c.b(1.5)) % 2 == 0) and 1 or -1 end
        m:update(dt, set().level)
    end,
    draw = function(c, t)
        local m = monster(c)
        local take, glow = c.at('take'), c.at('glow')
        local out = K.clamp(c.k(take + c.b(0.4), take + c.b(1.8)))
        local g = c.k(glow, glow + c.b(0.6))
        Stage.drawSet(set(), CAM0, K.LCAMY, function()
            m:draw()
        end, nil, function()
            K.carry(m.body.x, m.body.y, t, ids(c), { out = out, glow = g, shake = (t >= glow) and 1 or 0 })
        end)
    end,
}

-- ── 2. La emboscada ─────────────────────────────────────────────────────────
F.ambush = {
    enter = function(c) c.v.laughs = 0 end,
    events = {
        { cue = 'laugh', fn = function(c) c.sfx('storyLaughFar') end },
        { cue = 'portal', fn = function(c) c.sfx('mirrorAppear') end },
        { beat = 5.3, fn = function(c) c.sfx('mirrorPortal') end },
        { cue = 'drop', fn = function(c) c.sfx('jump', 0.75) end },
        { cue = 'land', fn = function(c)
            c.sfx('gpImpact', 0.85, 0.9)
            Particles.emit('shake_big', REF_X, FL)
            Stage.spark(REF_X, FL + 40, 10, 20, 200, { life = 0.5, s = 3, vy = -60 })
            reflection(c):place(REF_X, FL)
        end },
        { beat = 10.5, fn = function(c) c.sfx('glassWarn', 1.2, 0.6) end },
    },
    update = function(c, t, dt)
        local m = monster(c)
        local laugh, portal, land = c.at('laugh'), c.at('portal'), c.at('land')
        m.mx = 0
        if t >= laugh and t < portal then m.face = (math.floor((t - laugh) / c.b(0.75)) % 2 == 0) and -1 or 1
        else m.face = -1 end
        m.crouch = t >= land and t < land + c.b(1)                -- (se encoge del susto)
        m:update(dt, set().level)
        if t >= land then
            local r = reflection(c)
            r.crouch = t >= c.b(10.5)                              -- (se agacha para saltar)
            r:update(dt, set().level)
        end
        local lt = t - c.at('grin')                               -- la risa: cinco carcajadas, como el jefe
        while lt >= 0 and c.v.laughs < 5 and lt >= (1 / 6) + c.v.laughs * (2 / 6) do
            c.sfx('mirrorLaugh', 0.92 + math.random() * 0.16)
            c.v.laughs = c.v.laughs + 1
        end
    end,
    draw = function(c, t)
        local m = monster(c)
        local portal, drop, land, grin = c.at('portal'), c.at('drop'), c.at('land'), c.at('grin')
        local pk = 0
        if t >= portal then pk = math.min(1, (t - portal) / 0.25) * (1 - c.k(land, land + 0.3)) end
        local sx, sy = Particles.shakeOffset()
        local r = c.shared.r
        Stage.drawSet(set(), CAM0 + sx, K.LCAMY + sy, function()
            K.portal(PORTAL_X, PORTAL_Y, pk, t)
            if t >= portal + 0.3 and t < drop then
                K.reflex(PORTAL_X, PORTAL_Y + 10, { frame = 5, facing = 1, sx = 0.9, sy = 0.9, alpha = c.k(portal + 0.3, portal + 0.6) })
            elseif t >= drop and t < land then
                local u = c.k(drop, land)                          -- (cae en picado, como su ataque: magia)
                K.reflex(PORTAL_X, lerp(PORTAL_Y + 10, FL, easeIn(u)), { frame = 2, facing = 1, sx = 0.85, sy = 1.3 }, 3, 0, -40)
            elseif t >= land and r then
                if t >= grin and t < grin + c.b(2.5) then Stage.laugh(r.body.x, r.body.y, t - grin, { facing = 1 })
                else r:draw() end
            end
            m:draw()
        end, nil, function()
            if t >= drop and t < land then K.mark(REF_X, FL + 48, t) end
            K.carry(m.body.x, m.body.y, t, ids(c), { glow = 0.5 + 0.3 * math.sin(t * 5), shake = (t >= c.b(10.5)) and 2 or 0 })
            if t >= land and r then centre(r.body.x, r.body.y, t, 0.9) end
        end)
    end,
}

-- ── 3. ¡A correr! ───────────────────────────────────────────────────────────
F.run = {
    enter = function(c) c.v.ditch, c.v.dodge, c.v.dodge2 = false, false, false end,
    events = {
        { cue = 'jump', fn = function(c) monster(c):jump() end },                     -- (el susto: un salto de verdad)
        { cue = 'go', fn = function(c) c.sfx('mirrorLaugh', 0.85, 0.7) end },
        { cue = 'pounce', fn = function(c)
            local r, m = reflection(c), monster(c)
            -- se lanza en plancha (su ataque: magia) adonde estará el monstruo... que da un doble salto a tiempo
            c.v.px0, c.v.py0 = r.body.x, r.body.y
            c.v.landX = m.body.x + 240 * (c.at('miss') - c.at('pounce')) - 40
            r.hidden = true
            c.sfx('jump', 0.7); c.sfx('mirrorPortal', 1.2, 0.6)
        end },
        { cue = 'miss', fn = function(c)
            local r = reflection(c)
            r:place(c.v.landX, FL); r.hidden = false
            c.sfx('gpImpact', 0.9, 0.9)
            Particles.emit('shake_small', c.v.landX, FL)
            Particles.emit('mirror_shards', c.v.landX, FL + 30)
        end },
    },
    update = function(c, t, dt)
        local m, r = monster(c), reflection(c)
        local go, pounce, miss = c.at('go'), c.at('pounce'), c.at('miss')
        m.face = (t < go) and -1 or nil
        m.mx = (t >= go) and 1 or 0
        m.crouch = false
        -- la zanja: salta en el borde
        if not c.v.ditch and m.body.onGround and m.body.x > K.DITCH[1] - 70 then c.v.ditch = true; m:jump() end
        -- la plancha: salta... y en lo alto, el doble salto
        if not c.v.dodge and t >= pounce + c.b(0.6) and m.body.onGround then c.v.dodge = true; m:jump() end
        if c.v.dodge and not c.v.dodge2 and not m.body.onGround and m.body.vy > -60 then c.v.dodge2 = true; m:jump() end
        m:update(dt, set().level)
        -- el Reflejo: corre detrás (a su paso: no lo alcanza); tras fallar, se levanta y sigue
        r.crouch = t < go + c.b(0.5) or (t >= miss and t < miss + c.b(1.5))
        r.mx = ((t >= go + c.b(0.5) and t < pounce) or t >= miss + c.b(1.5)) and 1 or 0
        r.face = (r.mx == 0) and 1 or nil
        r.trail = (r.mx ~= 0) and 3 or 0
        -- (la zanja también la salta: en el juego la lava no le hace nada, pero aquí se vería metido en ella)
        if r.body.onGround and r.mx ~= 0 and r.body.x > K.DITCH[1] - 70 and r.body.x < K.DITCH[1] then r:jump() end
        if not r.hidden then r:update(dt, set().level) end
    end,
    draw = function(c, t)
        local m, r = monster(c), reflection(c)
        local pounce, miss, hush = c.at('pounce'), c.at('miss'), c.at('hush')
        -- la cámara sigue al monstruo... hasta que sale corriendo de cuadro
        c.v.cam = c.v.cam or CAM0
        if t < hush then c.v.cam = math.max(c.v.cam, m.body.x - 700) end
        local sx, sy = Particles.shakeOffset()
        local diving = t >= pounce and t < miss
        Stage.drawSet(set(), c.v.cam + sx, K.LCAMY + sy, function()
            if diving then
                local u = c.k(pounce, miss)
                K.reflex(lerp(c.v.px0, c.v.landX, u), lerp(c.v.py0, FL, u) - math.sin(u * math.pi) * 200,
                         { frame = (u < 0.5) and 2 or 1, facing = 1, sx = 0.9, sy = 1.15 }, 3)
            else
                r:draw()
            end
            m:draw()
        end, nil, function()
            if diving then K.mark(c.v.landX, FL + 48, t) end
            K.carry(m.body.x, m.body.y, t, ids(c), { glow = 0.35 })
            if not diving then centre(r.body.x, r.body.y, t, 0.8) end
        end)
    end,
}

return F
