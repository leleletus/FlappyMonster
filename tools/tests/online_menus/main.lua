-- tools/tests/online_menus — LAS PANTALLAS DEL MODO ONLINE (docs/architecture/menus.md, "Online screens") con el juego real, contra un
-- servidor LOCAL (run.sh lo arranca; FM_SERVER=localhost) y dos bots (sockets) que crean salas y entran en la nuestra:
--  1. login: el nombre se escribe, ENTER conecta y llega a la lista de salas;
--  2. lista de salas: se ven las salas de los bots (pública y con contraseña);
--  3. crear sala: los 4 pasos del asistente (nombre, privada, contraseña, máximo) y llega a la sala; con mando,
--     el número de jugadores (◀ ▶) y los botones de abajo (ABAJO, ◀ a CANCELAR, confirmar cancela);
--  4. sala: el bot entra; el host CAMBIA LA DIFICULTAD con el selector (a la derecha y a la izquierda, todas las de
--     src/core/Difficulty.lua y "sin dificultad") y la sala del servidor la recibe; el menú de modo de juego;
--     el menú de un jugador (admin);
--  5. la partida empieza (los dos listos) con la dificultad elegida; el menú de pausa;
--  6. resultados (datos de prueba) y la pantalla de error;
--  7. contraseña de una sala privada del bot.
-- Capturas a 1280 y 960 de ancho: <save>/online_*.png         tools/tests/run.sh online_menus
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw
local sock   = require 'libs/sock'
local bitser = require 'libs/bitser'
local P      = require 'src/network/Protocol'

local DT = 1 / 60
local fails = 0
local function check(name, ok, msg)
    print(('%-12s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local realInput, pressed, co, wantShot = nil, {}, nil, nil
local NC, Difficulty
local bots = {}

local function top() return gStateMachine:_top() end
local function name(st)
    for k, v in pairs(package.loaded) do if v == getmetatable(st) then return (k:match('[^/]+$')) end end
    return tostring(st)
end
local function botsUpdate() for _, b in ipairs(bots) do b.c:update() end end
local function tick()
    local cur = pressed; pressed = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
                         { __index = realInput })
    gameUpdate(DT)
    Input = realInput
    botsUpdate()
end
local function wait(s) for i = 1, math.floor(s / DT + 0.5) do tick(); if i % 8 == 0 then coroutine.yield() end end end
local function waitFor(fn, s) local n = 0; while not fn() and n < s / DT do tick(); n = n + 1; if n % 8 == 0 then coroutine.yield() end end; return fn() end
local function press(a, s) pressed[a] = true; wait(s or 0.08) end
local function key(k, s) top():keypressed(k); wait(s or 0.05) end
local function type_(text) for ch in text:gmatch('.') do top():textinput(ch) end; wait(0.05) end
local function shot(n) wantShot = n; coroutine.yield('shot') end
local function resize(w, h) love.window.setMode(w, h, { resizable = true }); love.resize(w, h) end
local function shots(n) shot(n); resize(960, 720); wait(0.1); shot(n .. '_960'); resize(1280, 720); wait(0.1) end

-- Un bot: un cliente de sockets con su nombre
local function newBot(nm)
    local b = { name = nm }
    b.c = sock.newClient('localhost', SERVER_PORT, P.CHANNELS)
    b.c:setSerialization(bitser.dumps, bitser.loads)
    b.c:on('connect', function() b.c:send('hello', { v = P.VERSION, name = nm }) end)
    b.c:on('login_success', function(d) b.logged, b.id = true, d.id end)
    b.c:on('room_update', function(d) b.room = d end)
    b.c:on('game_init', function() b.inGame = true end)
    b.c:connect()
    bots[#bots + 1] = b
    return b
end

local function run()
    -- dos bots con sus salas (una pública esperando, otra con contraseña)
    local b1, b2 = newBot('Gummy'), newBot('Crabby')
    waitFor(function() return b1.logged and b2.logged end, 5)
    b1.c:send('create_room', { name = 'Sala de Gummy', isPublic = true, password = '', maxPlayers = 4 })
    b2.c:send('create_room', { name = 'Secreta', isPublic = false, password = 'abc', maxPlayers = 6 })
    waitFor(function() return b1.room and b2.room end, 5)
    check('bots', b1.room ~= nil and b2.room ~= nil, 'los bots crearon sus salas')

    -- ── 1. login ─────────────────────────────────────────────────────────
    gStateMachine:change('online_login')
    wait(0.6)
    local st = top()
    while #(st.fields[1] or '') > 0 do key('backspace', 0) end
    type_('Prueba')
    shots('login')
    key('return', 0)
    waitFor(function() return name(top()) == 'OnlineHubState' end, 6)
    check('login', name(top()) == 'OnlineHubState', 'el nombre conecta y abre la lista de salas → ' .. name(top()))

    -- ── 2. lista ─────────────────────────────────────────────────────────
    st = top()
    waitFor(function() return #st.roomList >= 2 end, 4)
    wait(0.6)
    check('lista', #st.roomList >= 2, ('salas en la lista: %d'):format(#st.roomList))
    shots('hub')

    -- ── 7. contraseña (la sala del bot 2) ────────────────────────────────
    for i, r in ipairs(st.roomList) do if r.hasPassword then st.selectedIdx = i end end
    st.listFocus = 'rooms'
    press('confirm', 0.3)
    check('clave', st.sub == 'PASSWORD', 'una sala con contraseña la pide: ' .. tostring(st.sub))
    type_('abc')
    shots('password')
    press('back', 0.3)

    -- ── 3b. crear sala con MANDO: en el número de jugadores ▶ suma y ◀ resta, ABAJO baja a los botones, ◀ va a
    --        CANCELAR y confirmar cancela (antes el mando no llegaba a CANCELAR y arriba restaba)
    st:_resetCreate(); st.sub = 'CREATE'
    wait(0.2)
    type_('Mando')
    press('confirm', 0.2); press('confirm', 0.2)                 -- (nombre → pública → número)
    local m0 = st.maxValue
    press('nav_right', 0.1); press('nav_right', 0.1)
    local m1 = st.maxValue
    press('nav_left', 0.1)
    local m2 = st.maxValue
    press('nav_down', 0.1)
    local navNext = st.hoveredCreateNav
    press('nav_left', 0.1)
    local navCancel = st.hoveredCreateNav
    press('confirm', 0.3)
    check('crear_mando', st.createStep == 1 and st.sub == 'LIST' and m1 == m0 + 2 and m2 == m0 + 1 and navNext == 2 and navCancel == 1,
        ('jugadores %d → ▶▶ %d → ◀ %d; abajo → botón %s, ◀ → botón %s; confirmar → %s'):format(m0, m1, m2,
         tostring(navNext), tostring(navCancel), tostring(st.sub)))

    -- ── 3. crear sala ────────────────────────────────────────────────────
    st:_resetCreate(); st.sub = 'CREATE'
    wait(0.3)
    type_('Mi sala')
    shots('create_1')
    press('confirm', 0.3)
    press('nav_right', 0.2)
    shots('create_2')
    press('confirm', 0.3)
    type_('1234')
    shots('create_3')
    press('confirm', 0.3)
    press('nav_right', 0.2)
    shots('create_4')
    press('confirm', 0.1)
    waitFor(function() return name(top()) == 'OnlineRoomState' end, 6)
    check('crear', name(top()) == 'OnlineRoomState', 'el asistente crea la sala y entra → ' .. name(top()))

    -- ── 4. sala ──────────────────────────────────────────────────────────
    st = top()
    local myRoom = st.currentRoom.id
    b1.c:send('leave_room', {})
    wait(0.3)
    b1.c:send('join_room', { id = myRoom, password = '1234' })
    waitFor(function() return #(st.currentRoom.players or {}) >= 2 end, 4)
    wait(0.8)
    check('entra', #(st.currentRoom.players or {}) >= 2, 'el bot entra en la sala')
    shots('room')
    -- la DIFICULTAD: todas, con el selector, y el servidor la guarda
    local function diffId() return st.currentRoom.difficulty or 'none' end
    local seen, order = {}, { 'none' }
    for _, d in ipairs(Difficulty.ORDER) do order[#order + 1] = d end
    local ok = st.focusDifficulty and st:focusDifficulty()
    check('selector', ok == true, 'la sala tiene el selector de dificultad del host')
    for _ = 1, #order do
        press('nav_right', 0.25)
        waitFor(function() return b1.room and (b1.room.difficulty or 'none') == diffId() end, 1)
        seen[diffId()] = true
    end
    local all = true
    for _, d in ipairs(order) do if not seen[d] then all = false end end
    check('dificultad', all, 'el host pasa por todas: ' .. table.concat(order, ', ') .. ' (el bot ve la misma)')
    local before = diffId()
    press('nav_left', 0.3)
    check('izquierda', diffId() ~= before, ('a la izquierda vuelve atrás: %s → %s'):format(before, diffId()))
    for _ = 1, 8 do if diffId() == 'hard' then break end; press('nav_right', 0.25) end
    shots('room_difficulty')
    -- menú de modo de juego
    st:_executeAction('gamemode'); wait(0.5)
    shots('room_modes')
    st:_closeModeMenu(); wait(0.2)
    -- menú de un jugador
    st.focus, st.playerSel = 'players', 2
    press('confirm', 0.3)
    check('jugador', st.sub == 'pmenu', 'el admin abre el menú de un jugador')
    shots('room_player')
    press('back', 0.2)

    -- ── 5. la partida ────────────────────────────────────────────────────
    b1.c:send('set_ready', { ready = true })
    st:_executeAction('ready')
    wait(0.5)
    st:_executeAction('start')
    waitFor(function() return name(top()) == 'OnlineAdventureState' and top().localPaInit end, 8)
    check('partida', name(top()) == 'OnlineAdventureState', 'empieza la partida → ' .. name(top()))
    wait(1.5)
    local lv = top().level
    check('dific_part', lv and lv.difficulty == 'hard', 'la partida usa la dificultad elegida: ' .. tostring(lv and lv.difficulty))
    shots('game')
    press('pause', 0.4)
    shots('pause')

    -- ── 6. resultados y error ────────────────────────────────────────────
    NC:disconnect()
    for _, b in ipairs(bots) do b.c:disconnect() end
    wait(0.3)
    gStateMachine:change('online_results', { room = { name = 'Mi sala' }, results = { mode = 'race', reason = 'all_finished',
        entries = {
            { id = 1, name = 'Prueba', color = { 1, 0.85, 0.2 }, score = 1200, finished = true, place = 1, time = 61.2, winner = true },
            { id = 2, name = 'Gummy', color = { 0.3, 0.8, 1 }, score = 800, finished = true, place = 2, time = 70.5 },
            { id = 3, name = 'Crabby', color = { 1, 0.4, 0.4 }, score = 300, place = 3 },
            { id = 4, name = 'Bolita', color = { 0.5, 1, 0.5 }, score = 0, place = 4, out = true } } } })
    wait(4)
    shots('results')
    gStateMachine:change('online_error', { code = 'ERR_SERVER_UNREACHABLE', msg = require('src/core/Lang')('err.unreachable') })
    wait(0.6)
    shots('error')

    print(fails == 0 and 'TODO OK' or ('FALLAN %d'):format(fails))
    print('capturas: ' .. love.filesystem.getSaveDirectory() .. '/online_*.png')
    love.event.quit(fails == 0 and 0 or 1)
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    NC = require 'src/network/NetworkClient'
    Difficulty = require 'src/core/Difficulty'
    co = coroutine.create(run)
end

function love.update()
    if wantShot or not co or coroutine.status(co) == 'dead' then return end
    local ok, err = coroutine.resume(co)
    if not ok then print('Error: ' .. tostring(err)); print(debug.traceback(co)); love.event.quit(1) end
end

function love.draw()
    gameDraw()
    if wantShot then
        local n = wantShot
        love.graphics.captureScreenshot(function(img) img:encode('png', 'online_' .. n .. '.png'); wantShot = nil end)
        wantShot = false
    end
end
