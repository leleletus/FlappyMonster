-- src/story/LiveStage.lua
-- Un ESCENARIO VIVO de los créditos (docs/story/credits.md): un nivel pequeño (assets/story/sets/credits_*.json,
-- tools/levelgen/make_credits_sets.py) que se JUEGA de verdad con el motor del juego — un AdventureState en modo
-- demo, como el fondo de los menús (src/ui/menu/MenuScene.lua) —: sus enemigos, bombas, trampolines, hielo fino,
-- lava y sonidos son los del juego; nada está animado a mano. Al monstruo lo lleva un bot sencillo (abajo): anda de
-- lado a lado, salta lo que tiene delante, intenta pisar a los enemigos y hace ground pound cuando tiene algo
-- debajo; si muere, reaparece (vidas sin fin).
-- A pasos fijos de 1/60 s con su propio generador de azar: lo mismo cada vez que se ven los créditos. Las
-- partículas y las decoraciones usan el azar normal (se crean al dibujar: ver MenuScene).
--   local s = LiveStage.new('credits_pradera', seed)
--   s:update(dt)              s:draw(y)   (la franja, con lo de arriba del nivel en la y de pantalla `y`)
--   s.h                       alto de la franja en píxeles;   s.stats = { kills, deaths, booms } (para las pruebas)
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

local IDLE = setmetatable({ pressed = function() return false end, down = function() return false end },
                          { __index = function() return function() return false end end })

-- ── El bot de los créditos ────────────────────────────────────────────────
local function solidAt(level, x, y)
    local def = level:getDefAt(x, y)
    return def and def.collision == 'solid'
end
local function badFloor(level, x, y)
    if y >= level.heightPx then return true end
    local def = level:getDefAt(x, y)
    if not def then return true end
    if level:liquidAt(x, y) then return true end
    return def.collision == 'none' or (def.mat and def.mat.contact)
end

function LiveStage:_think()
    local st, level = self.st, self.st.level
    local p = st.player
    local inp = self.inp
    inp.left, inp.right, inp.crouch, inp.jumpPress, inp.jumpHold = false, false, false, false, false
    if p.dying or not p.alive then self.wasCrouch = false; return end
    self.cool = math.max(0, self.cool - STEP)
    -- de un lado a otro de la franja
    if p.x > level.widthPx - 90 then self.dir = -1 elseif p.x < 90 then self.dir = 1 end
    local d = self.dir
    -- (a veces se para un momento: así los enemigos llegan hasta él)
    self.wait = math.max(0, self.wait - STEP)
    if self.wait <= 0 and self.rng:random() < 0.004 then self.wait = 0.6 + self.rng:random() * 0.8 end
    if self.wait <= 0 then if d > 0 then inp.right = true else inp.left = true end end
    local feet = p.y + (p.h or 60) / 2 + 6
    local wantJump = false
    if p.onGround then
        if solidAt(level, p.x + d * 44, p.y) then wantJump = true end                 -- una pared o un bloque
        if badFloor(level, p.x + d * 52, feet) then wantJump = true end               -- un hueco, agua o lava
        for _, e in ipairs(st.enemies) do                                            -- alguien delante: a pisarle
            local dx = (e.x - p.x) * d
            if e.alive and e.state ~= 'dead' and dx > 20 and dx < 150 and math.abs(e.y - p.y) < 90 and not e.def.pickup then
                wantJump = true
            end
        end
    else
        -- en el aire, con algo justo debajo: ground pound (aplasta, rompe bloques)
        for _, e in ipairs(st.enemies) do
            if e.alive and e.state ~= 'dead' and math.abs(e.x - p.x) < 26 and e.y > p.y + 30 and e.y < p.y + 260 and not e.def.pickup then
                inp.crouch = true
            end
        end
        local below = level:getDefAt(p.x, feet + 40)
        if below and below.breakable then inp.crouch = true end
    end
    -- en el agua: brazadas (saltar nada hacia arriba); atascado medio segundo contra algo: saltar
    if level:liquidAt(p.x, p.y) and self.cool <= 0.3 then wantJump, self.cool = true, 0 end
    if self.wait <= 0 and math.abs(p.x - (self.lastX or p.x)) < 0.5 then self.stuck = (self.stuck or 0) + STEP else self.stuck = 0 end
    self.lastX = p.x
    if self.stuck > 0.5 then wantJump, self.cool, self.stuck = true, 0, 0 end
    if wantJump and self.cool <= 0 then
        inp.jumpPress, self.hold, self.cool = true, 0.28, 0.5
    end
    self.hold = math.max(0, self.hold - STEP)
    inp.jumpHold = self.hold > 0
    inp.crouchPress = inp.crouch and not self.wasCrouch
    self.wasCrouch = inp.crouch
end

function LiveStage.new(name, seed)
    local AdventureState = require 'src/states/adventure/AdventureState'
    local self = setmetatable({ name = name, rng = love.math.newRandomGenerator(seed or 7), dir = 1, cool = 0, wait = 0,
                                hold = 0, acc = 0, inp = {}, stats = { kills = 0, deaths = 0, booms = 0 } }, LiveStage)
    local st = AdventureState:new()
    local me = self
    local stub = {
        pressed = function(k)
            if k == 'jump' then return me.inp.jumpPress end
            if k == 'crouch' then return me.inp.crouchPress end      -- (agacharse en el aire = ground pound)
            return false
        end,
        down = function(k)
            if k == 'move_left' then return me.inp.left end
            if k == 'move_right' then return me.inp.right end
            if k == 'crouch' then return me.inp.crouch end
            if k == 'jump' then return me.inp.jumpHold or me.inp.jumpPress end
            return false
        end,
    }
    self.stub = setmetatable(stub, { __index = IDLE })
    self:_wrap(function()
        st:enter({ level = 'assets/story/sets/' .. name .. '.json', returnTo = 'main_menu',
                   demo = { noSky = true, noBossCtl = true,
                            camera = function() return me.cx or 0, me.cy or 0 end,
                            step = function(dt, level)
                                me:_think()
                                local real = Input
                                Input = me.stub
                                local ok, err = pcall(st.player.update, st.player, dt, level)
                                Input = real
                                if not ok then error(err, 0) end
                            end } })
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
    end)
    self.h = st.level.heightPx
    self.w = st.level.widthPx
    return self
end

-- Ejecuta fn con el azar del escenario (las decoraciones y partículas, con el normal) y sin el mando de verdad
function LiveStage:_wrap(fn)
    local rI, rR = Input, math.random
    local rng = self.rng
    outerRandom = rR
    Input = IDLE
    math.random = function(a, b) if b then return rng:random(a, b) elseif a then return rng:random(a) end return rng:random() end
    Particles.emit, Particles.update = wEmit, wUpdate
    DecoFx.emit, DecoFx.every = wdEmit, wdEvery
    local ok, err = pcall(fn)
    Input, math.random = rI, rR
    Particles.emit, Particles.update = pEmit, pUpdate
    DecoFx.emit, DecoFx.every = dEmit, dEvery
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
    if alpha <= 0 then return end
    local st = self.st
    ensure()
    y = math.floor(y)
    self.cx = math.floor((self.w - WINDOW_W) / 2)
    self.cy = -y
    st.camX, st.camY = self.cx, self.cy
    -- (en el lienzo, a tamaño lógico: sin la escala ni el recorte de lovesize)
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor(0, math.max(0, y), WINDOW_W, math.max(0, math.min(WINDOW_H, y + self.h) - math.max(0, y)))
    st:rebindGlobals()
    st:render()
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
