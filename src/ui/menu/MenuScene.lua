-- src/ui/menu/MenuScene.lua
-- EL FONDO VIVO de los menús (docs/architecture/menus.md): una CARRERA DE VERDAD jugada por un bot. Cada escena es
-- un nivel de carrera (sin jefes ni Rey de la Colina) cargado en un AdventureState en modo DEMO (los enemigos, los
-- pinchos, el agua, los puntos de control y la meta, con sus reglas de siempre; sin HUD, sin música, sin pausa) y
-- el monstruo lo maneja el bot de los bonus (src/ai/Bot.lua) con un objetivo claro: LLEGAR A LA META por su grafo
-- de navegación (assets/nav/<nivel>.json). Le hacen daño, muere y reaparece en el último punto de control, con
-- vidas sin fin. Al llegar a la meta (o si se le acaba el tiempo a la escena) un IRIS de píxeles se cierra sobre el
-- monstruo, se carga el nivel siguiente a oscuras y se abre sobre él. Todo en silencio. Es un módulo con estado
-- propio: sigue igual al cambiar de pantalla de menú, así que las pantallas entran y salen sobre el mismo fondo.
--   MenuScene.update(dt)   (cada pantalla de menú, en su update)
--   MenuScene.draw()       (cada pantalla de menú, lo primero de su render)
--   MenuScene.backdrop()   el fondo + un PANEL oscuro grande encima: para las pantallas de contenido (partidas,
--                          juego libre, online) que se diseñaron sobre negro
--   MenuScene.dim(a)       velo oscuro encima
--   MenuScene.reset(i)     empezar en la escena i (las pruebas)
-- Solo un jugador local: no toca la red ni las partidas.
local Bot = require 'src/ai/Bot'
local BotNav = require 'src/ai/BotNav'
local P = require 'src/network/Protocol'
local Transition = require 'src/ui/menu/Transition'

local MenuScene = {}

-- Las escenas, en orden: niveles de CARRERA (modo `race`; sin zonas de jefe ni de puntos) de las islas, cada uno
-- con su grafo de navegación (tools/tests/run.sh bot_nav BUILD=1 -- assets/levels/<nivel>.json) y su SEMILLA: con
-- ella (y a pasos fijos) la carrera es siempre la misma — una en la que el bot llega a la meta, con sus golpes y
-- sus muertes por el camino —. Para elegirla: tools/tests/run.sh menu_flow FINDSEED=40 LEVELS=<nivel> (dice con qué
-- semillas llega, en cuánto y con cuántas muertes). menu_flow comprueba que cada una llega. Añadir una = una línea
-- + su grafo + su semilla; si cambia el nivel, el bot o la física, hay que volver a buscarlas.
MenuScene.SCENES = {
    { level = 'valle_soleado',    seed = 15 },     -- la Pradera (41 s, 1 muerte)
    { level = 'arrecife_globo',   seed = 9 },      -- la Costa, buceando (66 s)
    { level = 'fabrica_morteros', seed = 4 },      -- la Fortaleza, al atardecer (46 s, 2 muertes)
    { level = 'cumbres_escarcha', seed = 7 },      -- las Cumbres (59 s, 2 muertes)
}
MenuScene.SCENE_MAX = 100       -- s como mucho por escena (si el bot no llega a la meta)
MenuScene.STALL = 8             -- s sin avanzar hacia la meta → se rinde (muere y reaparece en el punto de control)
MenuScene.STALLS = 3            -- … tantas veces → se pasa a la escena siguiente
MenuScene.CAM_X = 0.15          -- el monstruo va a este tanto del ancho de la pantalla (a la izquierda de los botones)
MenuScene.CAM_Y = 0.62          -- … y a este tanto del alto
MenuScene.IRIS_OUT = 0.6        -- s en cerrarse el iris sobre el monstruo
MenuScene.HOLD = 0.2            -- s a oscuras (ahí se carga el nivel siguiente)
MenuScene.IRIS_IN = 0.7         -- s en abrirse

local cur, index, phase, phaseT
local stats = {}                -- (para las pruebas)
MenuScene.stats = stats

-- ── Silencio: la demo no suena (ni pasos, ni enemigos, ni fanfarria) ni oye el mando ──────────────────────────
local function noop() end
local SILENT = setmetatable({}, { __index = function() return noop end })
local IDLE = P.newInputStub()
-- (y con el AZAR PROPIO de la escena, sc.rng: así la carrera es siempre la misma con su semilla, pase lo que pase en
-- el menú — ver MenuScene.SCENES —)
-- Las PARTÍCULAS y los efectos de las DECORACIONES son solo dibujo y dependen de lo que se dibuja (el polvo del Crabby
-- que escarba sale al dibujarlo; una decoración solo echa chispas si se ha visto): con el azar de la escena le
-- gastaban números y la carrera cambiaba según cuántos fotogramas se dibujaran. Ellos usan siempre el azar normal.
local Particles = require 'src/fx/Particles'
local DecoFx = require 'src/world/decorations/DecoFx'
local pEmit, pUpdate = Particles.emit, Particles.update
local dEmit, dEvery = DecoFx.emit, DecoFx.every
local function realRandom(fn)
    return function(...)
        local r = math.random
        math.random = MenuScene._random
        local a, b, c = fn(...)
        math.random = r
        return a, b, c
    end
end
local wEmit, wUpdate = realRandom(pEmit), realRandom(pUpdate)
local wdEmit, wdEvery = realRandom(dEmit), realRandom(dEvery)
local function muted(fn, rng)
    local rS, rI, rR = Sound, Input, math.random
    Sound, Input = SILENT, IDLE
    if rng then
        MenuScene._random = rR
        math.random = function(a, b) if b then return rng:random(a, b) elseif a then return rng:random(a) end return rng:random() end
        Particles.emit, Particles.update = wEmit, wUpdate
        DecoFx.emit, DecoFx.every = wdEmit, wdEvery
    end
    local ok, err = pcall(fn)
    Sound, Input, math.random = rS, rI, rR
    Particles.emit, Particles.update = pEmit, pUpdate
    DecoFx.emit, DecoFx.every = dEmit, dEvery
    if not ok then error(err, 0) end
end

-- Las casillas del grafo DENTRO de la META (de pie en ellas se la toca); si no hay, las de al lado; sin meta, la
-- más a la derecha. (Con las de al lado como objetivo se quedaba quieto junto a la meta sin tocarla.)
local function finishGoals(nav, level)
    -- (y la x del centro de la meta: llegado a su casilla, anda hasta tocarla)
    local fx, n = 0, 0
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            if level:getDef(c, r).trigger == 'finish' then fx, n = fx + (c - 0.5) * TILE_PX, n + 1 end
        end
    end
    fx = n > 0 and fx / n or nil
    for _, side in ipairs({ 0, 1 }) do
        local set, any = {}, false
        for r = 1, level.tileH do
            for c = 1, level.tileW do
                if level:getDef(c, r).trigger == 'finish' then
                    for dc = -side, side do
                        for dr = -side, 1 do
                            local id = (r + dr) * 4096 + (c + dc)
                            if nav.nodes[id] then set[id], any = true, true end
                        end
                    end
                end
            end
        end
        if any then return set, fx end
    end
    local best
    for id, n in pairs(nav.nodes) do if not best or n.c > nav.nodes[best].c then best = id end end
    return best and { [best] = true } or nil, fx
end

local function newScene(i)
    local def = MenuScene.SCENES[i]
    local AdventureState = require 'src/states/adventure/AdventureState'
    local st = AdventureState:new()
    local sc = { i = i, def = def, t = 0, best = math.huge, bestT = 0, acc = 0,
                 rng = love.math.newRandomGenerator(def.seed or love.math.random(1, 2 ^ 30)) }
    muted(function()
        st:enter({ level = 'assets/levels/' .. def.level .. '.json', returnTo = 'main_menu',
                   onFinish = function() sc.reason = sc.reason or 'meta' end,
                   demo = { camX = MenuScene.CAM_X, camY = MenuScene.CAM_Y,
                            step = function(dt, level) if sc.bot then sc.bot:step(dt, level, nil) end end } })
    end, sc.rng)
    sc.st = st
    -- (las decoraciones, con el azar normal: ver realRandom)
    st.level.updateFoliage = realRandom(st.level.updateFoliage)
    local nav = BotNav.load(def.level, st.level)
    sc.nav = nav
    if nav then
        local goals, fx = finishGoals(nav, st.level)
        sc.bot = Bot.new(st.player, nav, { mortal = true, dodge = true, firstDelay = 0, goal = function() return goals, 'finish', fx end })
    end
    -- la cámara, ya en su sitio
    local p = st.player
    st.camX = math.max(0, math.min(st.level.widthPx - WINDOW_W, p.x - WINDOW_W * MenuScene.CAM_X))
    st.camY = math.max(0, math.min(st.level.heightPx - WINDOW_H, p.y - WINDOW_H * MenuScene.CAM_Y))
    return sc
end

-- Dónde está el monstruo en la pantalla (el iris se cierra y se abre sobre él)
local function playerOnScreen(sc)
    local p = sc.st.player
    return math.floor(p.x - sc.st.camX), math.floor(p.y - sc.st.camY)
end

-- A PASOS FIJOS de 1/60 s (como se buscó su semilla): con el dt real del juego la carrera sería otra cada vez
MenuScene.STEP = 1 / 60
local function updateScene(sc, dt)
    local st = sc.st
    st.sceneCanvas = require('src/fx/SceneCanvas').get()     -- (el lienzo compartido; otro si la pantalla cambió)
    sc.acc = math.min(sc.acc + dt, MenuScene.STEP * 4)
    while sc.acc >= MenuScene.STEP - 1e-9 do
        sc.acc = sc.acc - MenuScene.STEP
        sc.t = sc.t + MenuScene.STEP
        muted(function()
            st:rebindGlobals()
            st:update(MenuScene.STEP)
        end, sc.rng)
    end
    local p = st.player
    -- PROGRESO = lo que le queda de camino hasta la meta (en fotogramas, por el grafo): en un nivel que sube (la torre)
    -- avanzar no es ir a la derecha
    local b = sc.bot
    if b and b.path and b.kind == 'finish' and p.onGround then
        local left = 0
        for _, e in ipairs(b.path) do left = left + (e.cost or 0) end
        if left < sc.best - 20 then sc.best, sc.bestT = left, sc.t end
    end
    if p.x > (sc.maxX or -math.huge) then sc.maxX = p.x end
    if not sc.reason then
        if not sc.bot then sc.reason = 'sin grafo'
        elseif sc.t > MenuScene.SCENE_MAX then sc.reason = 'tiempo'
        elseif sc.t - sc.bestT > MenuScene.STALL and not st.won and not p.dying then
            -- (encajado en algún sitio o dando vueltas: muere — como se rendiría un jugador — y vuelve a probar)
            sc.stalls, sc.bestT = (sc.stalls or 0) + 1, sc.t
            if sc.stalls >= MenuScene.STALLS then sc.reason = 'atascado'
            else muted(function() p:die(nil, true) end, sc.rng) end
        end
    end
    return sc.reason ~= nil
end

-- ── API ─────────────────────────────────────────────────────────────────────
function MenuScene.reset(i)
    index = i or love.math.random(#MenuScene.SCENES)
    cur, phase, phaseT = newScene(index), 'in', 0
    stats.scenes = 1
end

function MenuScene.current() return cur end
function MenuScene.fading() return phase ~= nil end

function MenuScene.update(dt)
    if not cur then MenuScene.reset() end
    if phase == 'hold' then
        phaseT = phaseT + dt
        if phaseT >= MenuScene.HOLD then
            index = index % #MenuScene.SCENES + 1
            cur, phase, phaseT = newScene(index), 'in', 0
            stats.scenes = (stats.scenes or 0) + 1
        end
        return
    end
    local over = updateScene(cur, dt)
    if phase then
        phaseT = phaseT + dt
        if phase == 'in' and phaseT >= MenuScene.IRIS_IN then phase = nil
        elseif phase == 'out' and phaseT >= MenuScene.IRIS_OUT then phase, phaseT = 'hold', 0 end
    elseif over then
        phase, phaseT = 'out', 0
        stats.last = { level = cur.def.level, reason = cur.reason, t = cur.t, deaths = cur.st.stats.deaths }
    end
end

function MenuScene.draw()
    if not cur then MenuScene.reset() end
    if phase == 'hold' then Transition.drawIris(0); return end
    muted(function() cur.st:render() end)
    local x, y = playerOnScreen(cur)
    if phase == 'out' then Transition.drawIris(1 - phaseT / MenuScene.IRIS_OUT, x, y)
    elseif phase == 'in' then Transition.drawIris(phaseT / MenuScene.IRIS_IN, x, y) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Fondo de LADRILLOS (el del modo Flappy) para las pantallas que ocupan casi toda la pantalla ─────────────────
-- (0.5.20, el usuario: en las partidas, el juego libre, todo el online... el fondo vivo distraía). Se repite en las
-- dos direcciones y va de lado despacio; un color por pantalla (MenuScene.BRICKS), oscurecido para que lo de encima
-- se lea. El fondo vivo sigue en el título y en los menús de botones (modo, configuración, dificultad del Flappy).
MenuScene.BRICKS = {
    story    = { 1.00, 0.80, 0.30 },     -- partidas: dorado
    free     = { 0.40, 0.90, 0.80 },     -- juego libre: verde azulado
    online   = { 0.45, 0.65, 1.00 },     -- online (entrar, salas, sala): azul
    error    = { 1.00, 0.45, 0.45 },     -- error de red: rojo
    sound    = { 0.75, 0.55, 1.00 },     -- sound test: morado
}
local BRICK_DARK = 0.38
local bricksT = 0
function MenuScene.bricks(which)
    local c = MenuScene.BRICKS[which] or MenuScene.BRICKS.online
    bricksT = love.timer.getTime()
    require('src/story/Stage').flappyBg(bricksT * 14, { c[1] * BRICK_DARK, c[2] * BRICK_DARK, c[3] * BRICK_DARK }, 1, bricksT * 5)
end

MenuScene.MARGIN = 24        -- px de fondo que deja ver el panel de MenuScene.backdrop
-- (which = color de los ladrillos; sin él, el fondo vivo)
function MenuScene.backdrop(which)
    if which then MenuScene.bricks(which) else MenuScene.draw() end
    local m = MenuScene.MARGIN
    require('src/ui/menu/MenuButton').panel(m, m, WINDOW_W - 2 * m, WINDOW_H - 2 * m)
end

function MenuScene.dim(a)
    love.graphics.setColor(0.04, 0.05, 0.12, a or 0.35)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuScene
