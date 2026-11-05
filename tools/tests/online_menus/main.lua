-- tools/tests/online_menus — LAS PANTALLAS DEL MODO ONLINE (docs/architecture/menus.md, "Online screens") con el juego real, contra un
-- servidor LOCAL (run.sh lo arranca; FM_SERVER=localhost) y dos bots (sockets) que crean salas y entran en la nuestra:
--  1. login: el nombre se escribe, ENTER conecta y llega a la lista de salas;
--  2. lista de salas: se ven las salas de los bots (pública y con contraseña);
--  3. crear sala: los 4 pasos del asistente (nombre, privada, contraseña, máximo) y llega a la sala; con mando,
--     el número de jugadores (◀ ▶) y los botones de abajo (ABAJO, ◀ a CANCELAR, confirmar cancela);
--  4. sala: el bot entra; el host CAMBIA LA DIFICULTAD con el selector (a la derecha y a la izquierda, todas las de
--     src/core/Difficulty.lua y "sin dificultad") y la sala del servidor la recibe; el menú de modo de juego;
--     récords tras una carrera de dos bots (`records`, con META), el desafío del día en solitario (`diario`) y el club
--     del día (`club`); las pantallas del desafío: su menú, la sala en solitario, la lista y la sala del club (`d_solo`, `d_club`);
--     entrar a mirar una partida en marcha y volver a ella tras un corte (`mirar`, `volver`);
--     el menú de un jugador (admin); bloquear (el nombre deja de verse) y denunciar (llega y no se repite);
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
local function botsUpdate()
    for _, b in ipairs(bots) do
        -- (un bot que CORRE: a la derecha, un input por paso — para llegar a la meta de los récords —)
        -- (al ritmo del reloj de verdad, 60 por segundo: el arnés va más rápido y el servidor lo echaba por flood)
        local now = love.timer.getTime()
        if b.run and b.inGame and now - (b.lastIn or 0) >= 1 / 60 then
            b.lastIn, b.seq = now, (b.seq or 0) + 1
            b.c:send('in', { s = b.seq, b = { P.encodeInput(false, true, false, false, false, false) } })
        end
        b.c:update()
    end
end
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
    b.c:on('room_update', function(d) b.room = d; if d.state == 'WAITING' and b.inGame then b.ended = true end end)
    b.c:on('room_error', function(d) b.err = d end)
    b.c:on('room_list', function(d) b.list = d end)
    b.c:on('game_init', function(d) b.inGame, b.init = true, d end)
    b.c:connect()
    bots[#bots + 1] = b
    return b
end

local function run()
    -- dos bots con sus salas (una pública esperando, otra con contraseña)
    local b1, b2 = newBot('Gummy'), newBot('Crabby')
    -- (10 s: con la batería en paralelo el servidor local puede tardar más en arrancar)
    waitFor(function() return b1.logged and b2.logged end, 10)
    b1.c:send('create_room', { name = 'Sala de Gummy', isPublic = true, password = '', maxPlayers = 4 })
    b2.c:send('create_room', { name = 'Secreta', isPublic = false, password = 'abc', maxPlayers = 6 })
    waitFor(function() return b1.room and b2.room end, 10)
    check('bots', b1.room ~= nil and b2.room ~= nil, 'los bots crearon sus salas')

    -- ── 1. login ─────────────────────────────────────────────────────────
    gStateMachine:change('online_login')
    wait(0.6)
    local st = top()
    while #(st.fields[1] or '') > 0 do key('backspace', 0) end
    type_('Prueba')
    shots('login')
    press('confirm', 0)                       -- (Enter = la acción confirm, como en el juego)
    waitFor(function() return name(top()) == 'OnlineMenuState' end, 6)
    local atMenu = name(top()) == 'OnlineMenuState'
    wait(0.6)
    shots('menu')
    -- el menú online: SALAS (el hub), DESAFÍO DEL DÍA, RÉCORDS; SALAS abre la lista y su VOLVER vuelve al menú
    press('confirm', 0.1)
    waitFor(function() return name(top()) == 'OnlineHubState' end, 4)
    local hubOk = name(top()) == 'OnlineHubState'
    wait(0.4)
    top():_leave(); wait(0.6)
    local backOk = name(top()) == 'OnlineMenuState' and NC:isConnected()
    press('confirm', 0.1)
    waitFor(function() return name(top()) == 'OnlineHubState' end, 4)
    check('login', atMenu and hubOk and backOk, ('el nombre conecta y abre el menú online=%s · SALAS → lista=%s · VOLVER → menú, sigue conectado=%s'):format(
        tostring(atMenu), tostring(hubOk), tostring(backOk)))

    -- ── 2. lista ─────────────────────────────────────────────────────────
    st = top()
    waitFor(function() return #st.roomList >= 2 end, 4)
    wait(0.6)
    check('lista', #st.roomList >= 2, ('salas en la lista: %d'):format(#st.roomList))
    shots('hub')
    -- con el DEDO: tocar una sala que no es la elegida solo la elige (no entra); arrastrar desplaza la elección
    do
        local Ly = st:_layout()
        local r2 = Ly.rows[2]
        st.selectedIdx, st.listFocus = 1, 'rooms'
        st:touchpressed('f1', r2.x + 20, r2.y + 10); st:touchreleased('f1', r2.x + 20, r2.y + 10)
        local tapSel, tapSub = st.selectedIdx, st.sub
        st:touchpressed('f2', r2.x + 20, r2.y + 10); st:touchmoved('f2', r2.x + 20, r2.y + 90); st:touchreleased('f2', r2.x + 20, r2.y + 90)
        check('lista_dedo', tapSel == 2 and tapSub == 'LIST' and st.selectedIdx == 1 and st.sub == 'LIST',
            ('tocar la 2ª: elegida %d, sigue en %s; arrastrar hacia abajo (la lista baja): elegida %d, %s'):format(tapSel, tapSub, st.selectedIdx, st.sub))
    end

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

    -- ── 3c. una sala PRIVADA sin contraseña no se crea: se queda en el paso de la contraseña ──
    st:_resetCreate(); st.sub = 'CREATE'
    st.createData.name, st.privacySel, st.createStep, st.inputBuffer = 'Privada', 2, 3, ''
    st:_createNext()
    local stays = st.createStep == 3 and st.sub == 'CREATE'
    st.inputBuffer = 'abc'; st:_createNext()
    check('privada', stays and st.createStep == 4, ('privada sin contraseña: sigue en el paso %s; con contraseña pasa al %d'):format(
        stays and '3' or 'otro', st.createStep))

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
    -- VOLVER en la sala lleva el foco a SALIR (no sale todavía)
    do
        local f0, a0 = st.focus, st.actionSel
        press('back', 0.15)
        local acts = st:_buildActions()
        local onLeave = acts[st.actionSel] and acts[st.actionSel].id == 'leave'
        check('sala_volver', onLeave and name(top()) == 'OnlineRoomState', ('VOLVER → foco en %s, sigue en %s'):format(
            tostring(acts[st.actionSel] and acts[st.actionSel].id), name(top())))
        st.focus, st.actionSel = f0, a0
    end
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
    -- BLOQUEAR y DENUNCIAR (todos, no solo el admin): el nombre deja de verse; la denuncia llega y la segunda, "otra vez"
    do
        local Blocks = require 'src/network/Blocks'
        local target = st.currentRoom.players[2]
        local function pick(act)
            for i, it in ipairs(st.pmenu) do if it[3] == act then st.pmenuSel = i end end
            press('confirm', 0.4)
        end
        local hasItems = false
        for _, it in ipairs(st.pmenu) do if it[3] == 'block' then hasItems = true end end
        pick('block')
        local blocked = Blocks.has(target.name) and Blocks.show(target.name) ~= target.name
        local toasts = {}
        local realToast = Notify.toast
        Notify.toast = function(m, k) toasts[#toasts + 1] = m; return realToast(m, k) end
        press('confirm', 0.3); pick('report_player'); wait(0.5)
        press('confirm', 0.3); pick('report_player'); wait(0.5)
        Notify.toast = realToast
        local L = require 'src/core/Lang'
        local repOk = toasts[1] == L('room.reported') and toasts[2] == L('room.report_again')
        press('confirm', 0.3); pick('block')                        -- (desbloquear)
        local unblocked = not Blocks.has(target.name)
        check('bloquear', hasItems and blocked and repOk and unblocked, ('opciones=%s · bloqueado (se ve "%s")=%s · denuncia + "otra vez"=%s (%s) · desbloqueado=%s'):format(
            tostring(hasItems), tostring(Blocks.show(target.name)), tostring(blocked), tostring(repOk), table.concat(toasts, ' | '), tostring(unblocked)))
    end

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
    press('pause', 0.3)

    -- ── 5b. ENTRAR A MIRAR una partida en marcha y VOLVER A ENTRAR tras un corte ──
    do
        local roomId = b1.room and b1.room.id
        local b3 = newBot('Bolita')
        waitFor(function() return b3.logged end, 4)
        b3.c:send('join_room', { id = roomId, password = '1234' })
        waitFor(function() return b3.init ~= nil end, 4)
        check('mirar', b3.init and b3.init.late == true and type(b3.init.rejoin) == 'string',
            ('entra con la partida en marcha: game_init=%s, mirando=%s %s'):format(tostring(b3.init ~= nil), tostring(b3.init and b3.init.late),
            b3.err and ('(error: ' .. tostring(b3.err.key or b3.err.msg) .. ')') or ''))
        local myIdx, token = top().myIdx, NC.rejoin and NC.rejoin.token
        NC:disconnect()                                              -- (se corta)
        wait(0.6)
        gStateMachine:change('online_error', { code = 'ERR_CONNECTION_LOST', msg = 'corte' })
        wait(0.3)
        local offered = top().canRejoin == true
        shots('rejoin_offer')
        press('confirm', 0.2)
        for k = 1, 10 do
            wait(0.5)
            if os.getenv('DBG') then print('  volver:', name(top()), top().connecting, top().auto, NC.rejoin and NC.rejoin.name, NC.connected, top().errorMsg) end
            if name(top()) == 'OnlineAdventureState' and top().localPaInit then break end
        end
        local back = name(top()) == 'OnlineAdventureState' and top().myIdx == myIdx and NC.rejoin and NC.rejoin.token == token
        check('volver', offered and back, ('ofrece volver=%s · de vuelta en la partida con su jugador (%s → %s)=%s'):format(
            tostring(offered), tostring(myIdx), tostring(top().myIdx), tostring(back)))
        -- (sale de la partida: dentro, el arnés manda entradas más rápido que el reloj y el servidor lo echa por flood
        -- mientras corren los bots de los récords; vuelve a la lista de donde entró — NC:toLobby —)
        NC:send('leave_room', {})
        waitFor(function() return name(top()) == 'OnlineHubState' end, 4)
    end

    -- ── 5c. RÉCORDS y DESAFÍO DEL DÍA ────────────────────────────────────
    do
        local META = os.getenv('META')                                  -- (un nivel con la meta a 5 casillas)
        for _, b in ipairs(bots) do b.c:disconnect() end                -- (el servidor admite 4 conexiones por IP)
        wait(1)                                                         -- (siguen actualizándose: que la desconexión salga)
        bots = {}
        local b4, b5, b6 = newBot('Corre1'), newBot('Corre2'), newBot('Diario')
        waitFor(function() return b4.logged and b5.logged and b6.logged end, 4)
        b4.c:send('create_room', { name = 'Carrera', isPublic = true, password = '', maxPlayers = 4 })
        waitFor(function() return b4.room end, 3)
        b4.c:send('set_mode', { mode = 'race', level = META })
        b5.c:send('join_room', { id = b4.room.id })
        wait(0.5)
        b4.c:send('set_ready', { ready = true }); b5.c:send('set_ready', { ready = true })
        wait(0.3)
        b4.c:send('start_game', {})
        waitFor(function() return b4.inGame and b5.inGame end, 4)
        b4.run, b5.run = true, true
        -- (en segundos de VERDAD: el servidor simula a su ritmo — cuenta atrás y la carrera —, el arnés va más rápido)
        local t0 = love.timer.getTime()
        while not b4.ended and love.timer.getTime() - t0 < 20 do tick(); coroutine.yield() end
        b4.run, b5.run = false, false
        local got
        NC:on('records', function(d) got = d end)
        NC:send('get_records', {})
        waitFor(function() return got ~= nil end, 3)
        local entry
        for _, e in ipairs(got and got.index or {}) do if e.level == META then entry = e end end
        got = nil
        NC:send('get_records', { level = META })
        waitFor(function() return got ~= nil end, 3)
        local list = got and got.list or {}
        check('records', entry and entry.best and (entry.best.name == 'Corre1' or entry.best.name == 'Corre2') and #list >= 1 and list[1].name == entry.best.name,
            ('carrera terminada=%s · en el índice=%s (mejor %s %s) · top del nivel: %d marcas'):format(tostring(b4.ended), tostring(entry ~= nil),
            entry and entry.best and entry.best.name or '-', entry and entry.best and tostring(entry.best.time) or '-', #list))
        -- la pantalla de récords con lo que llegó (captura)
        do
            local index = { index = { { level = META, name = 'Prueba de récords', best = list[1] or { name = '?', time = 0 } },
                                      { level = 'x', name = 'Valle Soleado', best = { name = 'Gummy', time = 74.31 } } },
                            daily = { date = '2026-11-03', level = 'assets/levels/torre_viento.json', name = 'Torre del Viento',
                                      list = { { name = 'Diario', time = 95.2 }, { name = 'Prueba', time = 101.75 } } } }
            gStateMachine:change('online_records'); wait(0.6)          -- (desde el menú online)
            top():_onRecords(index); wait(0.3)
            shots('records')
        end
        -- el desafío EN SOLITARIO: una sala de uno, privada y fuera de las listas, con el nivel del día; no se cambia
        -- y se empieza solo
        b6.c:send('join_daily', {})
        waitFor(function() return b6.room ~= nil end, 3)
        local r = b6.room or {}
        b6.c:send('set_mode', { mode = 'koth' })
        wait(0.3)
        local fixed = b6.err and b6.err.key == 'srv.daily_fixed'
        b5.list = nil; b5.c:send('get_rooms', { daily = true })
        waitFor(function() return b5.list ~= nil end, 3)
        local hidden = true
        for _, x in ipairs(b5.list or {}) do if x.id == r.id then hidden = false end end
        b6.c:send('set_ready', { ready = true }); wait(0.2)
        b6.c:send('start_game', {})
        waitFor(function() return b6.inGame end, 4)
        check('diario', r.daily ~= nil and r.solo == true and r.maxPlayers == 1 and r.isPublic == false and r.level ~= nil
            and r.mode == 'race' and fixed and hidden and b6.inGame == true,
            ('solitario %s en %s (%s) · de %s, privada=%s · fuera de las listas=%s · no se cambia=%s · empieza solo=%s'):format(
            tostring(r.daily), tostring(r.level), tostring(r.mode), tostring(r.maxPlayers), tostring(r.isPublic == false),
            tostring(hidden), tostring(fixed), tostring(b6.inGame)))
        -- el CLUB DEL DÍA: create_room { daily } → Carrera en el nivel de hoy; sale en SU lista y no en la normal
        b6.c:send('leave_room', {}); wait(0.4)
        b6.room = nil
        b6.c:send('create_room', { name = 'Club de Diario', isPublic = true, password = '', maxPlayers = 4, daily = true })
        waitFor(function() return b6.room ~= nil end, 3)
        local c = b6.room or {}
        local inClub, inNormal = false, false
        b5.list = nil; b5.c:send('get_rooms', { daily = true }); waitFor(function() return b5.list ~= nil end, 3)
        for _, x in ipairs(b5.list or {}) do if x.id == c.id then inClub = true elseif not x.daily then inNormal = true end end
        local clubOnlyDaily = not inNormal
        b5.list = nil; b5.c:send('get_rooms', {}); waitFor(function() return b5.list ~= nil end, 3)
        local leaked = false
        for _, x in ipairs(b5.list or {}) do if x.daily then leaked = true end end
        check('club', c.daily ~= nil and c.mode == 'race' and c.level == r.level and not c.solo and inClub and clubOnlyDaily and not leaked,
            ('sala del club %s en %s (%s) · en la lista del club=%s (solo del club=%s) · se cuela en la normal=%s'):format(
            tostring(c.daily), tostring(c.level), tostring(c.mode), tostring(inClub), tostring(clubOnlyDaily), tostring(leaked)))
    end

    -- ── 5d. LAS PANTALLAS DEL DESAFÍO: su menú (solitario · club), la lista del club y sus salas (solo LISTO / EMPEZAR /
    --        SALIR); al salir se vuelve de donde se entró ──
    do
        if os.getenv('DBG') then print('  5d: conectado', NC:isConnected()) end
        gStateMachine:change('online_daily'); wait(0.8)
        local atDaily = name(top()) == 'OnlineDailyState'
        shots('daily')
        local function ids()
            local out = {}
            for _, a in ipairs(top():_buildActions()) do out[#out + 1] = a.id end
            return table.concat(out, ',')
        end
        -- en solitario
        top().list.selected = 1
        press('confirm', 0.1)
        waitFor(function() return name(top()) == 'OnlineRoomState' and top().currentRoom.solo end, 4)
        if os.getenv('DBG') then print('  5d: solitario', name(top())) end
        local st = top()
        if name(st) ~= 'OnlineRoomState' then error('d_solo: no llega a la sala en solitario (' .. name(st) .. ')') end
        wait(0.8)
        local soloIds = ids()
        st:_executeAction('ready'); wait(0.4)
        local blocker = st:_startBlocker()
        shots('daily_solo')
        st:_executeAction('leave')
        waitFor(function() return name(top()) == 'OnlineDailyState' end, 4)
        local backSolo = name(top()) == 'OnlineDailyState'
        check('d_solo', atDaily and soloIds == 'ready,start,leave' and blocker == nil and backSolo,
            ('menú del desafío=%s · botones: %s · se puede empezar solo=%s · SALIR → menú del desafío=%s'):format(
            tostring(atDaily), soloIds, tostring(blocker == nil), tostring(backSolo)))
        -- el club: su lista (con la sala del bot), crear una y su sala
        wait(0.6)
        top().list.selected = 2
        press('confirm', 0.1)
        waitFor(function() return name(top()) == 'OnlineHubState' end, 4)
        local hub = top()
        waitFor(function() return #hub.roomList >= 1 end, 4)
        wait(0.6)
        local onlyClub = hub.daily == true and #hub.roomList >= 1
        for _, x in ipairs(hub.roomList) do if not x.daily then onlyClub = false end end
        shots('daily_hub')
        NC:send('create_room', { name = 'Mi club', isPublic = true, password = '', maxPlayers = 4, daily = true })
        waitFor(function() return name(top()) == 'OnlineRoomState' end, 4)
        st = top(); wait(0.8)
        local clubIds = ids()
        shots('daily_room')
        st:_executeAction('leave')
        waitFor(function() return name(top()) == 'OnlineHubState' end, 4)
        local backClub = name(top()) == 'OnlineHubState' and top().daily == true
        wait(0.6)
        top():_leave(); wait(0.8)
        local backMenu = name(top()) == 'OnlineDailyState'
        check('d_club', onlyClub and clubIds == 'ready,start,leave' and backClub and backMenu,
            ('lista del club (solo sus salas: %d)=%s · botones: %s · SALIR → lista del club=%s · VOLVER → menú del desafío=%s'):format(
            #hub.roomList, tostring(onlyClub), clubIds, tostring(backClub), tostring(backMenu)))
    end

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
