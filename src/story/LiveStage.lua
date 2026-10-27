-- src/story/LiveStage.lua
-- Un ESCENARIO VIVO de los créditos (docs/story/credits.md): un nivel pequeño (assets/story/sets/credits_*.json,
-- tools/levelgen/make_credits_sets.py) que se JUEGA de verdad con el motor del juego — un AdventureState en modo
-- demo, como el fondo de los menús (src/ui/menu/MenuScene.lua) —: sus enemigos, bombas, trampolines, hielo fino,
-- lava y sonidos son los del juego; nada está animado a mano. Al monstruo lo lleva el bot del fondo de los menús
-- (abajo) paseando de objetivo en objetivo; si muere, reaparece (vidas sin fin).
-- A pasos fijos de 1/60 s con su propio generador de azar: lo mismo cada vez que se ven los créditos. Las
-- partículas y las decoraciones usan el azar normal (se crean al dibujar: ver MenuScene).
--   local s = LiveStage.new('credits_pradera', seed[, opts])   opts.pilot(st) → quien lleva al monstruo en vez del bot
--                             (algo con :step(dt, level), p. ej. src/story/CreditsFight.lua), opts.immortal
--   s:update(dt)              s:draw(y)   (la franja, con lo de arriba del nivel en la y de pantalla `y`)
--   s.h                       alto de la franja en píxeles;   s.stats = { kills, deaths, booms, goals, jumps, inPlace } (para
--                             las pruebas; inPlace = lo más que SONÓ un salto en el mismo sitio —32 px— en 3 s; flips = lo
--                             más que cambió de sentido EN EL SUELO en 1 s: temblaba de un lado a otro)
local LiveStage = {}
LiveStage.__index = LiveStage

local STEP = 1 / 60
local Particles = require 'src/fx/Particles'
local DecoFx    = require 'src/world/decorations/DecoFx'

-- Partículas y decoraciones con el azar normal aunque el resto use el del escenario (ver MenuScene.realRandom)
local pEmit, pUpdate = Particles.emit, Particles.update
local dEmit, dEvery = DecoFx.emit, DecoFx.every
local outerRandom
local function realRandom(fn)
    return function(...)
        local r = math.random
        math.random = outerRandom or r
        local a, b, c = fn(...)
        math.random = r
        return a, b, c
    end
end
local wEmit, wUpdate, wdEmit, wdEvery = realRandom(pEmit), realRandom(pUpdate), realRandom(dEmit), realRandom(dEvery)
-- (y la animación de las decoraciones ENTERA: las del volcán echan chispas con math.random a pelo, y solo si se vieron
-- en el último dibujo; con el azar del escenario, lo que pasaba dependía de cuándo se dibujaba —la pelea del final de
-- los créditos salía distinta según los cuadros por segundo—)
local Level = require 'src/world/level/Level'
local lFoliage = Level.updateFoliage
local wlFoliage = realRandom(lFoliage)

local IDLE = setmetatable({ pressed = function() return false end, down = function() return false end },
                          { __index = function() return function() return false end end })

-- ── El bot de los créditos ────────────────────────────────────────────────
-- El MISMO bot que el fondo de los menús (src/ai/Bot.lua, con PRECAUCIÓN: salta, pisa o espera a los enemigos que
-- tiene cerca) por el grafo de navegación de la franja (assets/nav/credits_*.json: `run.sh bot_nav BUILD=1 --
-- assets/story/sets/credits_x.json`). En vez de ir a una meta, hace un PASEO de objetivos variados (`_pick`): ir a
-- por un enemigo (a pisarlo), a por una estrella, a una casilla cualquiera (arriba de una repisa, al otro lado de
-- un charco) o al otro extremo; llegado, se para un momento y elige otro. (Antes, uno a mano que solo andaba de lado
-- a lado y saltaba: el usuario, "muy repetitivo y rancio")
local Bot    = require 'src/ai/Bot'
local BotNav = require 'src/ai/BotNav'

-- Las casillas del grafo en las columnas col-1..col+1 (o nil)
local function nodesNear(nav, col)
    local set, any = {}, false
    for id, n in pairs(nav.nodes) do
        if math.abs(n.c - col) <= 1 then set[id], any = true, true end
    end
    return any and set or nil
end

function LiveStage:_pick(level)
    local st, nav = self.st, self.bot.nav
    local p = st.player
    local cands = {}
    local function add(w, x) for _ = 1, w do cands[#cands + 1] = x end end
    for _, e in ipairs(st.enemies) do
        if e.alive and e.state ~= 'dead' and e.state ~= 'reserve' and not e.def.boss and e.def.category ~= 'Directores' then
            local far = math.abs(e.x - p.x) > TILE_PX
            if e.def.pickup then add(2, e.x)
            elseif e.def.name == 'bomb' or e.def.name == 'bombobject' then if far then add(6, e.x) end    -- (¡a encenderla!)
            elseif e.def.category == 'Enemigos' and far then add(3, e.x) end
        end
    end
    if not nav.ids then
        nav.ids = {}
        for id in pairs(nav.nodes) do nav.ids[#nav.ids + 1] = id end
        table.sort(nav.ids)
    end
    for _ = 1, 2 do
        local n = nav.nodes[nav.ids[math.random(#nav.ids)]]
        add(1, (n.c - 0.5) * TILE_PX)
    end
    add(1, (p.x < level.widthPx / 2) and (level.widthPx - 2.5 * TILE_PX) or 2.5 * TILE_PX)    -- (al otro extremo)
    for _ = 1, 6 do
        local x = cands[math.random(#cands)]
        local set = nodesNear(nav, math.floor(x / TILE_PX) + 1)
        if set and math.abs(x - p.x) > TILE_PX * 1.5 then
            return { set = set, x = x, giveUp = self.clock + 3.5 + math.random() * 2 }
        end
    end
    local id = nav.ids[math.random(#nav.ids)]
    local n = nav.nodes[id]
    return { set = { [id] = true }, x = (n.c - 0.5) * TILE_PX, giveUp = self.clock + 5 }
end

function LiveStage:_tour(level)
    local p = self.st.player
    local g = self.goal
    if g and p.onGround and (math.abs(p.x - g.x) < 28 or self.clock > g.giveUp) then
        -- llegado (o no hay manera): un respiro y otro objetivo
        g.rest = g.rest or (self.clock + 0.15 + math.random() * 0.9)
        if self.clock >= g.rest then g = nil end
    end
    if not g then g = self:_pick(level); self.goal = g; self.stats.goals = self.stats.goals + 1 end
    return g.set, 'finish', g.x
end

function LiveStage.new(name, seed, opts)
    opts = opts or {}
    local AdventureState = require 'src/states/adventure/AdventureState'
    local self = setmetatable({ name = name, rng = love.math.newRandomGenerator(seed or 7), acc = 0, clock = 0,
                                gain = LiveStage.GAIN, stats = { kills = 0, deaths = 0, booms = 0, goals = 0, jumps = 0, inPlace = 0, flips = 0 },
                                jumpLog = {}, flipLog = {} }, LiveStage)
    local st = AdventureState:new()
    local me = self
    self:_wrap(function()
        st:enter({ level = 'assets/story/sets/' .. name .. '.json', returnTo = 'main_menu',
                   demo = { noSky = true, noBossCtl = true,
                            camera = function() return me.cx or 0, me.cy or 0 end,
                            step = function(dt, level)
                                me.clock = me.clock + dt
                                local ground = st.player.onGround
                                me.bot:step(dt, level, nil)
                                if ground and not st.player.onGround and st.player.vy < 0 then me.stats.jumps = me.stats.jumps + 1 end
                            end } })
        if opts.immortal then st.player.immortal = true end
        if opts.pilot then return end                          -- (lo pone abajo, con los jefes ya despiertos)
        local nav = BotNav.load(name, st.level)
        assert(nav and not nav.stale, 'escenario ' .. name .. ' sin grafo al día: run.sh bot_nav BUILD=1 -- assets/story/sets/' .. name .. '.json')
        me.bot = Bot.new(st.player, nav, { mortal = true, dodge = true, firstDelay = 0,
                                           goal = function(_, level) return me:_tour(level) end })
    end)
    self.st = st
    -- (los jefes, sin zona ni pelea de verdad — sin intro, sin música, sin barra —: despiertos desde el principio, con
    -- su cuerpo y sus ataques)
    self:_wrap(function()
        local z = st.level.bossZones and st.level.bossZones[1]
        if z then z.state = 'fight' end
        for _, e in ipairs(st.enemies) do
            if e.def.boss and e.startFight then
                if z then e.zone = z; z.bosses[#z.bosses + 1] = e end
                e.introPlayed = true                 -- (como tras su entrada: ataca directamente)
                e:startFight(1)
            end
        end
        if opts.pilot then me.bot = opts.pilot(st) end
    end)
    self.h = st.level.heightPx
    self.w = st.level.widthPx
    return self
end

-- EL SONIDO de un escenario: sus efectos, a GAIN del volumen normal y apagándose con la franja (self.gain, que pone
-- draw); la música no la toca nadie de dentro (al reaparecer, el monstruo pedía la del nivel: cortaba los créditos)
LiveStage.GAIN = 0.5
local function noop() end
local MUSIC = { playMusic = true, stopMusic = true, setLevelMusic = true, setBaseLevelMusic = true, leaveMatch = true,
                pauseAll = true, resumeAll = true, setEcho = true, stopAllTracked = true }
local function soundProxy(stage, real)
    local p = {
        play = function(name, pitch, vol)
            if name == 'jump' then stage:_jumpHeard() end
            return real.play(name, pitch, (vol or 1) * stage.gain)
        end,
        playAt = function(name, x, y, pitch, vol) return real.playAt(name, x, y, pitch, (vol or 1) * stage.gain) end,
        playTracked = function(name, pitch, vol) return real.playTracked(name, pitch, (vol or 1) * stage.gain) end,
        loop = function(name, on, x, y, g) return real.loop(name, on, x, y, (g or 1) * stage.gain) end,
        resumeAll = function() return true end,
    }
    return setmetatable(p, { __index = function(_, k) if MUSIC[k] then return noop end return real[k] end })
end

-- (el usuario: el monstruo "salta muchísimas veces sin moverse, solo suena": cuántos saltos suenan en el mismo sitio)
function LiveStage:_jumpHeard()
    local p = self.st and self.st.player
    if not p then return end
    local log, n = self.jumpLog, 1
    log[#log + 1] = { t = self.clock, x = p.x }
    while log[1] and log[1].t < self.clock - 3 do table.remove(log, 1) end
    for i = 1, #log - 1 do if math.abs(log[i].x - p.x) < 32 then n = n + 1 end end
    if n > self.stats.inPlace then self.stats.inPlace = n end
end

function LiveStage:_flipCount()
    local p = self.st.player
    local d = (p.x > (self.lx or p.x) + 0.5) and 1 or ((p.x < (self.lx or p.x) - 0.5) and -1 or 0)
    self.lx = p.x
    if d == 0 then return end
    if self.ld and d ~= self.ld and p.onGround then                -- (en el suelo: en el aire es dirigir el salto)
        local log = self.flipLog
        log[#log + 1] = self.clock
        while log[1] and log[1] < self.clock - 1 do table.remove(log, 1) end
        if #log > self.stats.flips then self.stats.flips = #log end
    end
    self.ld = d
end

-- Ejecuta fn con el azar del escenario (las decoraciones y partículas, con el normal), sin el mando de verdad y con
-- su sonido (soundProxy)
function LiveStage:_wrap(fn, drawing)
    local rI, rR, rS = Input, math.random, Sound
    self.sound = self.sound or soundProxy(self, rS)
    Sound = self.sound
    local rng = self.rng
    outerRandom = rR
    Input = IDLE
    -- (al DIBUJAR, el azar normal: lo que se dibuja no puede cambiar lo que pasa)
    if not drawing then
        math.random = function(a, b) if b then return rng:random(a, b) elseif a then return rng:random(a) end return rng:random() end
    end
    Particles.emit, Particles.update = wEmit, wUpdate
    DecoFx.emit, DecoFx.every = wdEmit, wdEvery
    Level.updateFoliage = wlFoliage
    local ok, err = pcall(fn)
    Input, math.random, Sound = rI, rR, rS
    Particles.emit, Particles.update = pEmit, pUpdate
    DecoFx.emit, DecoFx.every = dEmit, dEvery
    Level.updateFoliage = lFoliage
    if not ok then error(err, 0) end
end

-- (las explosiones de verdad, contadas para las pruebas: Explosions.blast con este escenario simulándose)
local Explosions = require 'src/world/systems/Explosions'
local current
local realBlast = Explosions.blast
Explosions.blast = function(level, ...)
    if current and level == current.st.level then current.stats.booms = current.stats.booms + 1 end
    return realBlast(level, ...)
end

function LiveStage:update(dt)
    current = self
    local st = self.st
    self.acc = math.min(self.acc + dt, STEP * 4)
    while self.acc >= STEP - 1e-9 do
        self.acc = self.acc - STEP
        local alive = {}
        for i, e in ipairs(st.enemies) do alive[i] = e.alive and e.state ~= 'dead' end
        local wasDying = st.player.dying
        self:_wrap(function()
            st:rebindGlobals()
            st:update(STEP)
            -- (un jefe que acabó su entrada espera a que la zona empiece la pelea: aquí no hay quien la empiece)
            for _, e in ipairs(st.enemies) do
                if e.def.boss and e.state == 'ready' and e.startFight then e:startFight(1) end
            end
        end)
        -- (lo que pasa: para las pruebas)
        for i, e in ipairs(st.enemies) do
            if alive[i] and not (e.alive and e.state ~= 'dead') then
                self.stats.kills = self.stats.kills + 1
            end
        end
        if st.player.dying and not wasDying then self.stats.deaths = self.stats.deaths + 1 end
        self:_flipCount()
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────
-- La franja se dibuja en un lienzo propio (uno para todos: se dibujan de uno en uno) y luego se le DIFUMINAN los bordes
-- de los lados y de abajo multiplicando su alfa por la máscara en escalones (assets/images/fx/fade_edge.png,
-- tools/art/fx/make_fades.py): así el suelo no acaba en seco. `alpha` = la de toda la franja (al irse).
local FADE = 96                           -- px de difuminado en cada borde
local canvas, mask
local function ensure()
    if not canvas or canvas:getWidth() ~= WINDOW_W or canvas:getHeight() ~= WINDOW_H then
        canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end
    if not mask then
        mask = love.graphics.newImage('assets/images/fx/fade_edge.png')
        mask:setFilter('nearest', 'nearest')
    end
end

-- La franja con el borde de arriba del nivel en la y de pantalla `y` (centrada a lo ancho)
function LiveStage:draw(y, alpha)
    alpha = alpha or 1
    self.gain = LiveStage.GAIN * alpha
    -- (la cámara, aunque aún no se vea: lo que pasa depende de ella —lo que está a la vista— y tiene que ser lo mismo
    -- desde el primer paso: la pelea del final de los créditos sale siempre igual)
    y = math.floor(y)
    self.cx = math.floor((self.w - WINDOW_W) / 2)
    self.cy = -y
    if alpha <= 0 then return end
    local st = self.st
    ensure()
    st.camX, st.camY = self.cx, self.cy
    -- (en el lienzo, a tamaño lógico: sin la escala ni el recorte de lovesize)
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor(0, math.max(0, y), WINDOW_W, math.max(0, math.min(WINDOW_H, y + self.h) - math.max(0, y)))
    self.gain = LiveStage.GAIN * alpha                   -- (lo que suena se apaga con la franja)
    self:_wrap(function()
        st:rebindGlobals()
        st:render()
    end, true)
    love.graphics.setScissor()
    -- los bordes: izquierda, derecha y abajo (alfa × la máscara)
    love.graphics.setBlendMode('multiply', 'premultiplied')
    love.graphics.setColor(1, 1, 1, 1)
    local mw = mask:getWidth()
    love.graphics.draw(mask, 0, y, 0, FADE / mw, self.h)
    love.graphics.draw(mask, WINDOW_W, y, 0, -FADE / mw, self.h)
    love.graphics.draw(mask, 0, y + self.h, -math.pi / 2, FADE / mw, WINDOW_W)
    love.graphics.pop()
    -- a la pantalla (con la transformación de quien dibuja)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.setColor(alpha, alpha, alpha, alpha)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

return LiveStage
