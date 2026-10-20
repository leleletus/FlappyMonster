-- src/story/films/lair.lua
-- LA GUARIDA: la película de antes de "Ruta del Espejo" (el jefe final; la primera vez que se entra). Sin texto.
-- Tiempos y momentos (cues): assets/story/films.json. Guion: docs/story/story.md.
-- El monstruo y el Reflejo son ACTORES (src/story/Actor.lua): física de verdad del juego.
--   escape   el final de la huida (los fragmentos, guardados): el monstruo cruza el lago de lava con un salto y el DOBLE salto; el Reflejo se para
--            en la orilla, se ríe, salta a un espejo flotante... y el espejo se va volando, lejos, hasta perderse en
--            el horizonte (allí está su guarida). El monstruo lo ve irse
--   night    cae la noche. Sin aliento, saca sus seis fragmentos: tiemblan y se ponen en fila SEÑALANDO hacia allí;
--            a lo lejos el séptimo contesta con un destello, y la risa llega con eco
--   follow   asiente y echa a andar detrás de sus fragmentos, hacia allí (al ritmo de la música del nivel, que
--            entra al acabar)
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local Actor = require 'src/story/Actor'
local Particles = require 'src/fx/Particles'

local lerp, smooth, easeIn = K.lerp, K.smooth, K.easeIn
local F = {}

local FL = K.LFLOOR
local REST_X = 3160                      -- donde se para el monstruo, pasado el lago
local EDGE_X = K.LAKE[1] - 90            -- donde se para el Reflejo, en la orilla
local CAM = 2300                         -- la cámara de la orilla (se ven el lago, el Reflejo y el monstruo)
local PEAK_SX, PEAK_SY = 1196, 430       -- la guarida, a lo lejos, en el horizonte por delante (en PANTALLA)

local function ids(c) c.shared.ids = c.shared.ids or K.carryIds(c.xtra); return c.shared.ids end
local function dusk() return Stage.set('ladera') end
local function night() return Stage.set('ladera_noche') end

-- El destello de la guarida, a lo lejos (en pantalla)
local function peak(t, k)
    if k <= 0 then return end
    local tw = 0.5 + 0.5 * math.sin(t * 9)
    Stage.rays(PEAK_SX, PEAK_SY, t * 3, 4, (18 + 16 * tw) * k, 0.6 * k, { 0.8, 0.95, 1 })
    K.shardGlow('7', PEAK_SX, PEAK_SY, 1, 0, k, t)
    Stage.shard('7', PEAK_SX, PEAK_SY, { s = 1, alpha = k })
end

-- ── 1. El final de la huida ─────────────────────────────────────────────────
F.escape = {
    enter = function(c)
        local lv = dusk().level
        -- el monstruo llega corriendo (ya a su velocidad); el Reflejo, detrás
        c.shared.m = Actor.new(lv, K.LAKE[1] - 40 - 240 * c.at('leap'), FL, { mute = c.film.mute })
        c.shared.m.body.vx = ADV_MOVE_SPD
        c.shared.r = Actor.new(lv, c.shared.m.body.x - 330, FL, { invert = true, pitch = 0.8, mute = c.film.mute })
        c.shared.r.body.vx, c.shared.r.trail = ADV_MOVE_SPD, 3
        c.v.j1, c.v.j2, c.v.laughs = false, false, 0
    end,
    events = {
        { cue = 'portal', fn = function(c) c.sfx('mirrorAppear') end },
        { beat = 12.6, fn = function(c) c.shared.r:jump() end },               -- (salta al espejo)
        { cue = 'fly', fn = function(c) c.sfx('mirrorWarp', 1.1, 0.8) end },
        { cue = 'gone', fn = function(c) c.sfx('storyGlint', 0.9, 0.7) end },
        { beat = 18.5, fn = function(c) c.sfx('storyPant', 1, 0.9) end },
    },
    update = function(c, t, dt)
        local m, r = c.shared.m, c.shared.r
        local lv = dusk().level
        -- el lago: salta en la orilla y, en lo alto, el doble salto
        if not c.v.j1 and m.body.onGround and m.body.x > K.LAKE[1] - 40 then c.v.j1 = true; m:jump() end
        if c.v.j1 and not c.v.j2 and not m.body.onGround and m.body.vy > -40 then c.v.j2 = true; m:jump() end
        m.mx = (m.body.x < REST_X) and 1 or 0
        if m.mx == 0 then m.face = -1 end                          -- (se para y mira atrás)
        -- el espejo pasa por encima: lo sigue con la mirada
        if t >= c.at('fly') + c.b(0.8) then m.face = 1 end
        m.crouch = t >= c.b(18)                                    -- (sin aliento)
        m:update(dt, lv)
        -- el Reflejo: hasta la orilla; allí se para; se ríe; salta al espejo
        r.mx = (r.body.x < EDGE_X and t < c.at('stop') + c.b(1)) and 1 or 0
        r.face, r.trail = (r.mx == 0) and 1 or nil, (r.mx ~= 0) and 3 or 0
        if not r.hidden then r:update(dt, lv) end
        -- (en lo alto del salto, el espejo se lo traga)
        if not r.hidden and t >= c.b(12.6) + 0.1 and not r.body.onGround and r.body.vy > -80 then
            r.hidden = true; c.sfx('mirrorPortal', 1, 0.8)
            Stage.spark(c.v.px, c.v.py, 10, 20, 120, { life = 0.5, s = 2 })
        end
        local lt = t - (c.at('stop') + c.b(1))                     -- la risa, en la orilla
        while lt >= 0 and t < c.at('portal') and c.v.laughs < 5 and lt >= (1 / 6) + c.v.laughs * (2 / 6) do
            c.sfx('mirrorLaugh', 0.9 + math.random() * 0.16)
            c.v.laughs = c.v.laughs + 1
        end
        -- el espejo flotante, sobre el Reflejo... y luego, volando lejos, hacia la guarida (deja chispas)
        local fly = c.at('fly')
        local px0, py0 = EDGE_X + 10, FL - 110
        if t < fly then c.v.px, c.v.py = px0, py0
        else
            local u = easeIn(c.k(fly, c.at('gone')))
            local tx, ty = CAM + PEAK_SX, K.LCAMY + PEAK_SY
            c.v.px = lerp(px0, tx, u)
            c.v.py = lerp(py0, ty, u) - math.sin(u * math.pi) * 120
            if u < 1 and math.random() < 0.7 then Stage.spark(c.v.px, c.v.py, 1, 8, 30, { life = 0.5, s = 2 }) end
        end
    end,
    draw = function(c, t)
        local m, r = c.shared.m, c.shared.r
        local stop, portal, fly, gone = c.at('stop'), c.at('portal'), c.at('fly'), c.at('gone')
        local camX = math.min(CAM, math.max(m.body.x - 760, CAM - 400))
        local pk = 0
        if t >= portal then pk = math.min(1, (t - portal) / 0.25) * (1 - 0.8 * c.k(fly, gone)) * (1 - c.k(gone - 0.15, gone)) end      -- (se aleja: cada vez más pequeño)
        Stage.drawSet(dusk(), camX, K.LCAMY, function()
            K.portal(c.v.px, c.v.py, pk, t)
            if not r.hidden then
                local laughT = t - (stop + c.b(1))
                if laughT >= 0 and t < portal then Stage.laugh(r.body.x, r.body.y, laughT, { facing = 1 })
                else r:draw() end
            end
            m:draw()
        end)
        -- (aquí los fragmentos van GUARDADOS, los de los dos: el monstruo solo saca los suyos de noche, cuando el
        -- Espejo ya se ha ido, para que lo guíen)
        peak(t, (t >= gone) and (1 - c.k(gone + c.b(0.5), c.dur)) or 0)
    end,
}

-- ── 2. Cae la noche ─────────────────────────────────────────────────────────
-- Sin corte: la MISMA toma (la cámara donde la dejó la escena anterior, el monstruo donde se paró) y el atardecer se
-- funde poco a poco con la noche (el decorado de noche dibujado encima, cada vez más opaco). (Antes entraba de
-- negro con otra cámara y el monstruo recolocado: el usuario lo vio "brutal, como a tropiezos".)
local NIGHT_CAM = CAM
local DUSK_OUT = 2.0                     -- pulsos que tarda en hacerse de noche
local dissolve

F.night = {
    enter = function(c)
        local m = c.shared.m or Actor.new(night().level, REST_X, FL, { mute = c.film.mute })
        c.shared.m = m
        m.mx, m.crouch, m.face, m.level = 0, true, 1, night().level        -- (sigue donde estaba)
    end,
    events = {
        { beat = 0.3, fn = function(c) c.sfx('storyPant', 0.95, 0.8) end },
        { beat = 1.2, fn = function(c) c.sfx('storyRumble', 0.8, 0.5) end },
        { cue = 'out', fn = function(c) c.sfx('shardDrop', 0.8, 0.7) end },
        { cue = 'point', fn = function(c) c.sfx('storyGlint', 0.8, 0.8) end },
        { cue = 'glint', fn = function(c) c.sfx('storyGlint', 1.2); c.sfx('storyLaughFar', 1, 0.8) end },
    },
    update = function(c, t, dt)
        local m = c.shared.m
        m.crouch = t < c.b(1.5)
        m.face = 1
        m:update(dt, night().level)
    end,
    draw = function(c, t)
        local m = c.shared.m
        local out, point, glint = c.at('out'), c.at('point'), c.at('glint')
        -- hacia dónde señalan: la guarida (de pantalla a mundo)
        local dx, dy = PEAK_SX + NIGHT_CAM - m.body.x, PEAK_SY + K.LCAMY - (m.body.y - 60)
        local d = math.sqrt(dx * dx + dy * dy)
        local function scene(set)
            Stage.drawSet(set, NIGHT_CAM, K.LCAMY, function()
                m:draw()
            end, nil, function()
                K.carry(m.body.x, m.body.y, t, ids(c), { out = c.k(out, out + c.b(1.5)), glow = 0.3 + 0.7 * c.k(point, point + c.b(1)),
                                                         shake = (t >= point and t < glint) and 2 or 0,
                                                         lead = c.k(point, point + c.b(1.5)), dx = dx / d, dy = dy / d })
            end)
        end
        local k = K.smooth(c.k(0, c.b(DUSK_OUT)))
        if k < 1 then
            -- el atardecer debajo y la noche encima, fundiéndose
            scene(dusk())
            if not dissolve or dissolve:getWidth() ~= WINDOW_W or dissolve:getHeight() ~= WINDOW_H then
                dissolve = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
            end
            local prev = love.graphics.getCanvas()
            love.graphics.setCanvas(dissolve)
            love.graphics.clear(0, 0, 0, 1)
            scene(night())
            love.graphics.setCanvas(prev)
            love.graphics.setColor(1, 1, 1, k)
            love.graphics.draw(dissolve, 0, 0)
            love.graphics.setColor(1, 1, 1, 1)
        else
            scene(night())
        end
        peak(t, (t >= glint) and (1 - 0.5 * c.k(glint + c.b(1), c.dur)) or 0)
        if t >= glint then Stage.flash(0.25 * (1 - (t - glint) / 0.3), 0.8, 0.95, 1) end
    end,
}

-- ── 3. Hacia la guarida ─────────────────────────────────────────────────────
F.follow = {
    enter = function(c) c.v.cam = NIGHT_CAM end,          -- (la misma toma: la cámara empieza donde estaba)
    events = {
        { beat = 0.5, fn = function(c) c.shared.m.crouch = true end },          -- (asiente: se agacha y se levanta)
        { beat = 1.0, fn = function(c) c.shared.m.crouch = false end },
    },
    update = function(c, t, dt)
        local m = c.shared.m
        m.mx = (t >= c.at('walk')) and 1 or 0
        m.face = 1
        m:update(dt, night().level)
        -- la cámara lo sigue, suave (sin saltos), y al final se queda: él se va hacia la oscuridad
        if t < c.at('hush') then
            local want = math.max(c.v.cam, m.body.x - 640)
            c.v.cam = c.v.cam + (want - c.v.cam) * math.min(1, dt * 2.5)
        end
    end,
    draw = function(c, t)
        local m = c.shared.m
        local dx, dy = PEAK_SX + c.v.cam - m.body.x, PEAK_SY + K.LCAMY - (m.body.y - 60)
        local d = math.sqrt(dx * dx + dy * dy)
        Stage.drawSet(night(), c.v.cam, K.LCAMY, function()
            m:draw()
        end, nil, function()
            K.carry(m.body.x, m.body.y, t, ids(c), { glow = 0.8, lead = 1, dx = dx / d, dy = dy / d })
        end)
        peak(t, 0.5)
    end,
}

return F
