-- tools/tests/online_smoke — prueba online de humo, sin humano.
-- Un cliente REAL (OnlineAdventureState) + un bot juegan una partida contra un
-- servidor LOCAL (nunca el real) y se comprueba que no salta ningún error.
--
--   love server --headless &                 (desde la raíz del repo)
--   LEVEL=assets/levels/carrera01.json MODE=race love tools/tests/online_smoke
--   pkill -f "^love server"
--
-- (MODE: race | hunt | koth; SECS = duración, 16 por defecto)
-- PERF=1: lo que cuesta el CLIENTE online de verdad (update y dibujo; falla si la media de update + dibujo pasa de 16,7 ms)
-- LAG=ms LOSS=%: red MALA simulada en el cliente real — lo que manda y lo que recibe llega LAG ms tarde, y se pierde
-- el LOSS % de las fotos ('s') y de los paquetes de inputs ('in'); falla si la predicción se queda atrás (el servidor
-- tiene que ir confirmando inputs) o si hay errores
-- WANTOXY=1: falla si el cliente no llegó a ver ninguna burbuja de OXÍGENO de los respiraderos (las crea el
-- servidor; el servidor sin ventana no cargaba sus imágenes y no salía ninguna)
-- STALL=4.5: el bot sufre un CORTE de red de esos segundos a los 3 s de partida (sigue contando sus inputs pero no
-- llega ninguno); al volver, el servidor tiene que procesarlos otra vez (antes, tras > 3 s, no se movía nunca más)
-- WATCH=bomb: además apunta los estados que ve el cliente de las entidades de
-- ese tipo, los tiles que cambian y la vida del jugador local; con WANT=lit,exploding
-- falla si alguno de esos estados no llegó (p. ej. la arena de bombas:
-- LEVEL=tools/levelgen/arenas/bombas.json)
-- WANTTILES=thin_ice_1,thin_ice_2,...: falla si el cliente no llegó a ver esos
-- tiles (eventos 'tile' del servidor), p. ej. el hielo fino que se agrieta bajo
-- el jugador local (LEVEL=tools/levelgen/arenas/hielo.json)
-- WANTICE=1: falla si el jugador local nunca quedó congelado (congelador:
-- LEVEL=tools/levelgen/arenas/congelador.json WATCH=gummy WANT=frozen WANTICE=1)
-- WANTGULP=1: TRAGADO por una Planta carnívora (0.5.97; LEVEL=tools/tests/online_smoke/planta.json WATCH=carnivoreplant
-- WANT=hold): el jugador local tiene que quedar tragado (estado propio `gulped`, predicho), no verse, machacar el salto
-- (lo manda por red) y salir escupido, vivo; falla si nunca lo tragó o si no salió
-- WANTSHOVE=1: EMPUJADO por una Bola de Nieve (LEVEL=tools/tests/online_smoke/bola_de_nieve.json WATCH=snowball
-- WANT=windup,charge): el jugador local tiene que salir lanzado de lado (predicho como un trampolín: ctrlLockT y vx) sin
-- perder vida; se mide la mayor corrección del servidor en el medio segundo siguiente (falla si pasa de SHOVE_ERR px)
-- LA ESPERA DEL PRINCIPIO (0.5.202, docs/design/level-intro-card.md): el servidor no empieza la tarjeta + cuenta atrás
-- hasta que todos han cargado (`level_loaded`), con un límite. El bot avisa al recibir game_init; con DELAYLOAD=s lo
-- hace esos segundos tarde (la tarjeta del cliente espera viva y sale «Esperando jugadores»), con NOLOAD=1 nunca (se
-- empieza 8 s después del primero) y con QUITLOAD=1 se desconecta antes de cargar (se empieza enseguida). Siempre:
-- tras empezar, la tarjeta dura CARD_TIME por el reloj del servidor y luego la cuenta atrás (checks espera_carga,
-- tarjeta_online). LEAVELOAD=1: el bot SALE de la sala antes de cargar, sin desconectarse (se empieza enseguida).
-- DROPSTART=1: el cliente pierde el aviso round_start (llega antes de que el estado escuche): tiene que empezar igual
-- (NC.pendingRoundStart). Mientras se espera, un espectador sí puede abrir su menú (`espectador_libre`)
io.stdout:setvbuf("no")
love.filesystem.setSymlinksEnabled(true)
lovesize = require 'libs/lovesize'
Timer    = require 'libs/timer'
require 'settings'
Input = require 'input'
Sound = require 'src/audio/Sound'
StateMachine = require 'src/core/StateMachine'
NC = require 'src/network/NetworkClient'
Notify = require 'src/ui/Notify'
local sock = require 'libs/sock'
local bitser = require 'libs/bitser'
local P = require 'src/network/Protocol'
local PixelIcons = require 'src/ui/PixelIcons'
local OnlineAdventureState = require 'src/states/online/OnlineAdventureState'
local LEVEL = os.getenv('LEVEL')
local t, st, frames = 0, nil, 0
local stub = P.newInputStub()
local bad, ADM, GIVE1, GIVE2, BADNAME
local bot = { seq = 0, acc = 0, bits = {} }
function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    lovesize.set(1280, 720)
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    FONT_MED   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    FONT_BIG   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 28)
    Input.load(); Sound.load(); love.audio.setVolume(0)
    -- (al terminar la ronda el juego pasa a resultados / sala: aquí basta con parar)
    local Done = { new = function() return setmetatable({}, { __index = { enter = function() end,
        update = function() end, render = function() end, exit = function() end } }) end }
    gStateMachine = StateMachine:new({ online_adventure = function() return OnlineAdventureState:new() end,
                                       online_results = function() return Done.new() end,
                                       online_room = function() return Done.new() end })
    NC:on('login_success', function() NC:send('create_room', { name = 'Prueba', maxPlayers = 4 }) end)
    NC:on('room_error', function(d) print('room_error', d.key, d.msg) end)
    local phase = 0
    NC:on('room_update', function(d)
        if not st and d.state == 'IN_GAME' then gStateMachine:change('online_adventure', { room = d }); st = gStateMachine:_top() end
        ADM = d.adminId                                    -- (quién es el admin, visto por el cliente)
        if phase == 0 then phase = 1
            NC:send('set_mode', { mode = os.getenv('MODE') or 'race', level = LEVEL, difficulty = os.getenv('DIFF') })
            bot.roomId = d.id end        -- (el bot entra cuando haya iniciado sesión)
    end)
    NC:connect('localhost', 22122, 'Prueba')     -- (nunca el servidor real)
    if os.getenv('DROPSTART') then                 -- (el aviso round_start no llega al estado: se pierde por el camino)
        local fire = NC._fire
        NC._fire = function(self, ev, data) if ev == 'round_start' then return end return fire(self, ev, data) end
    end
    if os.getenv('LAG') or os.getenv('LOSS') then
        local lag, loss = (tonumber(os.getenv('LAG')) or 0) / 1000, (tonumber(os.getenv('LOSS')) or 0) / 100
        local rng = love.math.newRandomGenerator(5)
        netQ = {}
        local fire, sendState = NC._fire, NC.sendState
        NC._fire = function(self, ev, data)                -- (recibir: tarde, y las fotos a veces no llegan)
            if ev == 's' and rng:random() < loss then return end
            netQ[#netQ + 1] = { at = love.timer.getTime() + lag, fn = function() fire(self, ev, data) end }
        end
        NC.sendState = function(self, ev, data)            -- (mandar: tarde, y los inputs a veces no llegan)
            if rng:random() < loss then return end
            local copy = {}
            for k, v in pairs(data) do
                if type(v) == 'table' then local t = {}; for i, x in pairs(v) do t[i] = x end; copy[k] = t else copy[k] = v end
            end
            netQ[#netQ + 1] = { at = love.timer.getTime() + lag, fn = function() sendState(self, ev, copy) end }
        end
    end
    bot.c = sock.newClient('localhost', 22122, P.CHANNELS)
    bot.c:setSerialization(bitser.dumps, bitser.loads)
    bot.c:on('game_init', function()
        bot.inGame = true
        if os.getenv('QUITLOAD') then bot.quitAt = t + 1
        elseif os.getenv('LEAVELOAD') then bot.leaveAt = t + 1
        elseif not os.getenv('NOLOAD') then bot.loadAt = t + (tonumber(os.getenv('DELAYLOAD')) or 0) end
    end)
    bot.c:on('s', function(d) if d.a then bot.ack = d.a end end)
    bot.c:on('login_success', function(d) bot.logged = true; bot.id = d.id end)
    bot.c:connect()
    -- un segundo cliente con un nombre NO permitido (disfrazado con números y guiones): el servidor lo rechaza
    bad = sock.newClient('localhost', 22122, P.CHANNELS)
    bad:setSerialization(bitser.dumps, bitser.loads)
    bad:on('login_error', function(d) BADNAME = d and d.key end)
    bad:on('login_success', function() BADNAME = 'ACEPTADO' end)
    bad:connect()
end
PERFLOG = os.getenv('PERF') and { upd = 0, draw = 0, n = 0 } or nil
function love.update(dt)
    t = t + dt
    Timer.update(dt); Sound.update(dt); NC:update(dt); bot.c:update(); bad:update()
    if netQ then
        local now, i = love.timer.getTime(), 1
        while i <= #netQ do
            if netQ[i].at <= now then local q = table.remove(netQ, i); q.fn() else i = i + 1 end
        end
    end
    if not bad.hello and bad:isConnected() then bad.hello = true; bad:send('hello', { v = P.VERSION, name = 'xX_PuT4_Xx' }) end
    if not bot.hello and bot.c:isConnected() then bot.hello = true; bot.c:send('hello', { v = P.VERSION, name = 'Bot' }) end
    if bot.logged and bot.roomId and not bot.joined then
        bot.joined = true; bot.c:send('join_room', { id = bot.roomId }); bot.giveAt = t + 0.6 end
    -- CEDER EL ADMIN: el cliente se lo da al bot (todos ven al bot de admin y el cliente deja de serlo) y el bot se lo devuelve
    if bot.giveAt and t > bot.giveAt then bot.giveAt = nil; bot.giveT = t; NC:send('give_admin', { playerId = bot.id }) end
    if bot.giveT and not GIVE1 and ADM == bot.id then GIVE1 = true; bot.c:send('give_admin', { playerId = NC.myId }) end
    if bot.giveT and GIVE1 and not GIVE2 and ADM == NC.myId then GIVE2 = true end
    if bot.giveT and (GIVE2 or t > bot.giveT + 4) then bot.giveT = nil; bot.readyAt = t + 0.4 end
    if bot.readyAt and t > bot.readyAt then bot.readyAt = nil
        bot.c:send('set_ready', { ready = true }); NC:send('set_ready', { ready = true }); bot.startAt = t + 0.6 end
    if bot.startAt and t > bot.startAt then bot.startAt = nil; NC:send('start_game', {}) end
    if bot.loadAt and t >= bot.loadAt then bot.loadAt = nil; bot.c:send('level_loaded', {}) end
    if bot.leaveAt and t >= bot.leaveAt then bot.leaveAt = nil; bot.gone = true; bot.c:send('leave_room', {}) end
    if bot.quitAt and t >= bot.quitAt then bot.quitAt = nil; bot.gone = true; bot.c:disconnectNow() end
    if bot.inGame and not bot.gone then
        bot.acc = bot.acc + dt
        while bot.acc >= P.TICK_DT do bot.acc = bot.acc - P.TICK_DT; bot.seq = bot.seq + 1
            table.insert(bot.bits, P.encodeInput(false, bot.seq % 120 < 60, false, false, bot.seq % 40 == 0, false)) end
        bot.t0 = bot.t0 or t
        local stall = tonumber(os.getenv('STALL'))
        local cut = stall and t > bot.t0 + 3 and t < bot.t0 + 3 + stall          -- (corte: los paquetes se pierden)
        if cut then bot.stalled = true end
        if #bot.bits > 0 and not cut then bot.c:send('in', { s = bot.seq - #bot.bits + 1, b = bot.bits }) end
        bot.bits = {}
    end
    Input = setmetatable({ pressed = stub.pressed, down = stub.down }, { __index = package.loaded['input'] })
    local perfT0 = love.timer.getTime()
    if gStateMachine:_top() then gStateMachine:update(dt) end
    if PERFLOG then PERFLOG.upd, PERFLOG.n = PERFLOG.upd + love.timer.getTime() - perfT0, PERFLOG.n + 1 end
    Input = package.loaded['input']
    if st and st.localPaInit then frames = frames + 1 end
    if os.getenv('WANTOXY') and st and st.level then
        for _, v in ipairs(st.level.vents or {}) do oxySeen = math.max(oxySeen or 0, #v.oxyBubbles) end
    end
    if (os.getenv('WATCH') or os.getenv('WANTTILES')) and st and st.enemyRenderers then
        watch = watch or { states = {}, tiles = 0, minHp = 99, deaths = 0, tileNames = {} }
        for _, er in pairs(st.enemyRenderers) do
            if er.def and er.def.name == os.getenv('WATCH') then watch.states[er.state] = true end
        end
        if st.level and not watch.t0 then
            watch.t0 = {}
            for r = 1, st.level.tileH do for c = 1, st.level.tileW do watch.t0[r * 65536 + c] = st.level:getRaw(c, r) end end
        end
        if watch.t0 then
            for r = 1, st.level.tileH do for c = 1, st.level.tileW do
                if watch.t0[r * 65536 + c] ~= st.level:getRaw(c, r) then watch.tileNames[st.level:getDef(c, r).name] = true end
            end end
        end
        local pa = st.localPa
        if pa then
            watch.minHp = math.min(watch.minHp, pa.hp or 99)
            if pa.dying and not watch.wasDying then watch.deaths = watch.deaths + 1 end
            watch.wasDying = pa.dying
            if (pa.iceT or 0) > 0 then watch.iced = (watch.iced or 0) + 1 end
            -- (empujado por una Bola de Nieve: lanzado de lado sin control un momento; la corrección que llega después)
            if (pa.ctrlLockT or 0) > 0.1 and math.abs(pa.vx or 0) > 450 then
                if not watch.shoveAt or t > watch.shoveAt + 1 then watch.shoves = (watch.shoves or 0) + 1 end
                watch.shoveAt = watch.shoveAt and t <= watch.shoveAt + 1 and watch.shoveAt or t
            end
            if watch.shoveAt and t < watch.shoveAt + 0.5 and st.predictor then
                watch.shoveErr = math.max(watch.shoveErr or 0, st.predictor.lastError or 0)
            end
            if pa.gulped then
                watch.gulped = (watch.gulped or 0) + 1
                if frames % 6 == 0 then stub.state.jump_pressed = true end    -- (machaca el salto: viaja por red)
            elseif (watch.gulped or 0) > 0 and not pa.dying then watch.spat = true end
        end
    end
    -- LA ESPERA y la TARJETA del principio (vistas en el cliente)
    if st and st.localPaInit then
        intro = intro or { gi = t }
        if st.startTicks and not intro.rs then intro.rs = t end
        if st.waitingStart and st.ownData and intro.specFree == nil then     -- (un espectador, mientras se espera)
            local was = st.ownData.isSpectator
            st.ownData.isSpectator = true
            intro.specFree = not st:_startLocked()
            st.ownData.isSpectator = was
        end
        if st._introWaiting then intro.wait = math.max(intro.wait or 0, st:_introWaiting() or 0) end
        local showing = st._cardShowing and st:_cardShowing()
        if showing and not intro.rs then intro.cardWait = true end
        if showing and intro.rs then intro.cardEnd = t end
        if showing and intro.cardEnd and intro.rs and not intro.cardFirst then intro.cardFirst = t end
    end
    -- Cuenta atrás del principio (StartCountdown): mientras dura, el jugador propio no se mueve (aunque se pulse)
    local cdRem = st and st._startRemaining and st:_startRemaining()
    if cdRem and cdRem > 0.2 and st.localPaInit then
        startCd = startCd or { x = st.renderX, y = st.renderY, max = cdRem, moved = 0 }
        startCd.moved = math.max(startCd.moved, math.abs(st.renderX - startCd.x) + math.abs(st.renderY - startCd.y))
    end
    -- Reloj del HUD en los modos con tiempo: tiene que ir hacia atrás (tras la cuenta atrás: durante ella está quieto)
    if st and st.roundEndAt and not (cdRem and cdRem > 0) then
        local left = st.roundEndAt - st.levelTime
        clk = clk or { first = left, t = t }
        clk.last, clk.lastT = left, t
    end
    if t > (tonumber(os.getenv('SECS')) or 16) then
        if PERFLOG and not PERFLOG.done then
            PERFLOG.done = true
            local n = math.max(1, PERFLOG.n)
            local u, d = PERFLOG.upd / n * 1000, PERFLOG.draw / n * 1000
            print(('%s cliente online: update %.2f ms + dibujo %.2f ms de media, %d fotogramas (límite 16,7)'):format(u + d <= 16.7 and 'OK   ' or 'FALLA', u, d, n))
            if u + d > 16.7 then print('FALLA rendimiento del cliente'); love.event.quit(1); return end
        end
        if os.getenv('DIFF') and st and st.level then      -- la dificultad de la sala llega al cliente y a su jugador
            local want = ({ easy = 4 })[os.getenv('DIFF')] or 3
            print(('dificultad: sala %s → cliente %s, vida del jugador %s'):format(os.getenv('DIFF'), tostring(st.level.difficulty), tostring(st.localPa and st.localPa.hpMax)))
            if st.level.difficulty ~= os.getenv('DIFF') or (st.localPa and st.localPa.hpMax) ~= want then print('Error: la dificultad no llegó al cliente') end
            -- (el cliente construye el nivel con la dificultad: `bossExtra` cambiaría QUÉ hay — hoy ninguna dificultad lo
            -- pone; Xtra extremo es UN jefe enfadado desde la 0.5.24 —; los jefes tienen que estar)
            local nb = 0
            for _, e in pairs(st.enemyRenderers or {}) do if e.def and e.def.boss then nb = nb + 1 end end
            print(('jefes en el cliente: %d'):format(nb))
            if #(st.level.bossZones or {}) > 0 and nb < 1 then print('Error: el cliente no tiene el jefe') end
        end
        do
            local SC = require 'src/world/systems/StartCountdown'
            local gap = intro and intro.rs and (intro.rs - intro.gi) or -1
            local want, okWait
            if os.getenv('DELAYLOAD') then want = tonumber(os.getenv('DELAYLOAD')); okWait = gap >= want - 0.3 and gap < want + 1.2
                and intro.cardWait and (intro.wait or 0) > (want > SC.CARD_TIME + 1 and 0.5 or -1)
            elseif os.getenv('NOLOAD') then want = 8; okWait = gap >= 7.5 and gap < 9.2
            elseif os.getenv('QUITLOAD') or os.getenv('LEAVELOAD') then want = 1; okWait = gap >= 0.7 and gap < 2.2
            else want = 0; okWait = gap >= 0 and gap < 1.0 end
            print(('%s espera_carga: game_init → empieza %.2f s (se esperaba ~%s); tarjeta esperando=%s; «esperando» %.1f s'):format(
                okWait and 'OK   ' or 'FALLA', gap, tostring(want), tostring(intro and intro.cardWait), intro and intro.wait or 0))
            if not okWait then print('Error: el servidor no esperó lo que debía a que cargaran todos') end
            local cardLen = intro and intro.rs and intro.cardEnd and (intro.cardEnd - intro.rs) or -1
            local okCard = math.abs(cardLen - SC.CARD_TIME) < 0.45
            print(('%s tarjeta_online: tras empezar, la tarjeta dura %.2f s (CARD_TIME %.1f)'):format(okCard and 'OK   ' or 'FALLA', cardLen, SC.CARD_TIME))
            if not okCard then print('Error: la tarjeta online no sigue el reloj del servidor') end
            if intro and intro.specFree ~= nil then
                print(('%s espectador_libre: mientras se espera, un espectador puede abrir su menú=%s'):format(intro.specFree and 'OK   ' or 'FALLA', tostring(intro.specFree)))
                if not intro.specFree then print('Error: un espectador no puede abrir su menú mientras se espera') end
            end
        end
        print(('cuenta atrás: %s (desde %.1f s), el jugador se movió %.1f px'):format(tostring(startCd ~= nil),
              startCd and startCd.max or -1, startCd and startCd.moved or -1))
        if not startCd or startCd.moved > 1 then print('Error: sin cuenta atrás al empezar o el jugador se mueve durante ella') end
        if clk then
            local fell = clk.first - clk.last
            print(('reloj: %.1f s → %.1f s (baja %.1f s en %.1f s)'):format(clk.first, clk.last, fell, clk.lastT - clk.t))
            if math.abs(fell - (clk.lastT - clk.t)) > 1.5 then print('Error: el reloj de la ronda no cuenta hacia atrás') end
        end
        if watch then
            local changed = 0
            for r = 1, st.level.tileH do for c = 1, st.level.tileW do
                if watch.t0[r * 65536 + c] ~= st.level:getRaw(c, r) then changed = changed + 1 end
            end end
            local seen = {}
            for k in pairs(watch.states) do seen[#seen + 1] = k end
            table.sort(seen)
            local tn = {}
            for k in pairs(watch.tileNames) do tn[#tn + 1] = k end
            table.sort(tn)
            print(('%s vistos en el cliente: %s · tiles cambiados: %d (%s) · vida mínima del jugador: %d · muertes: %d'):format(
                os.getenv('WATCH') or '-', table.concat(seen, ','), changed, table.concat(tn, ','), watch.minHp, watch.deaths))
            for w in (os.getenv('WANTTILES') or ''):gmatch('[^,]+') do
                if not watch.tileNames[w] then print('Error: el cliente no vio el tile ' .. w) end
            end
            print(('jugador local congelado: %d fotogramas'):format(watch.iced or 0))
            if os.getenv('WANTICE') and (watch.iced or 0) == 0 then print('Error: el jugador local nunca quedó congelado') end
            print(('jugador local tragado por una planta: %d fotogramas, escupido=%s'):format(watch.gulped or 0, tostring(watch.spat)))
            if os.getenv('WANTGULP') and ((watch.gulped or 0) == 0 or not watch.spat) then
                print('Error: el jugador local no quedó tragado por la planta o no salió machacando')
            end
            for w in (os.getenv('WANT') or ''):gmatch('[^,]+') do
                if not watch.states[w] then print('Error: el cliente no vio el estado ' .. w) end
            end
            print(('jugador local empujado: %d veces, mayor corrección tras el empujón %.1f px'):format(watch.shoves or 0, watch.shoveErr or 0))
            if os.getenv('WANTSHOVE') then
                local maxErr = tonumber(os.getenv('SHOVE_ERR')) or 48
                if (watch.shoves or 0) == 0 then print('Error: el jugador local nunca salió empujado') end
                if (watch.shoveErr or 0) > maxErr then print(('Error: corrección tras el empujón %.1f px > %d'):format(watch.shoveErr, maxErr)) end
                if watch.minHp < 3 then print('Error: el empujón le quitó vida') end
            end
        end
        if netQ and st and st.predictor then
            local pr = st.predictor
            local behind = pr.seq - pr.ackSeq
            local maxBehind = math.floor((tonumber(os.getenv('LAG')) or 0) / 1000 * 2 * 60) + 30
            print(('red mala (%s ms, %s %% perdido): inputs sin confirmar al final %d (máximo %d)'):format(
                os.getenv('LAG') or 0, os.getenv('LOSS') or 0, behind, maxBehind))
            if behind > maxBehind then print('Error: con la red mala la predicción se queda atrás') end
        end
        if os.getenv('WANTOXY') then
            print(('burbujas de oxígeno vistas en el cliente (máximo a la vez): %d'):format(oxySeen or 0))
            if (oxySeen or 0) == 0 then print('Error: el cliente no vio ninguna burbuja de oxígeno del servidor') end
        end
        if os.getenv('STALL') then
            local lag = bot.seq - (bot.ack or 0)
            print(('corte de red del bot de %s s: tras volver, el servidor va por su input %s de %d (atraso %d)'):format(
                os.getenv('STALL'), tostring(bot.ack), bot.seq, lag))
            if not bot.stalled or lag > 60 then print('Error: tras el corte de red el servidor no volvió a procesar los inputs del bot') end
        end
        if not GIVE2 then print('Error: ceder el admin (cliente → bot → cliente): ida=' .. tostring(GIVE1) .. ' vuelta=' .. tostring(GIVE2)) end
        if BADNAME ~= 'srv.name_blocked' then print('Error: el servidor no rechazó el nombre vetado (' .. tostring(BADNAME) .. ')') end
        print(('admin cedido y devuelto=%s · nombre vetado rechazado por el servidor=%s'):format(tostring(GIVE2), tostring(BADNAME)))
        print(('OK: %d fotogramas de partida sin errores; iconos: skull %dx%d, flag %dx%d, hill %dx%d, corona %dx%d'):format(frames,
            PixelIcons.size('skull'), select(2, PixelIcons.size('skull')), PixelIcons.size('flag'), select(2, PixelIcons.size('flag')),
            PixelIcons.size('hill'), select(2, PixelIcons.size('hill')), PixelIcons.CROWN_W, PixelIcons.CROWN_H))
        do
            local bad, seen = {}, {}
            for k, n in pairs(HUDBAD or {}) do bad[#bad + 1] = k .. ' (' .. n .. ')' end
            for k in pairs(HUDSEEN or {}) do seen[#seen + 1] = k end
            table.sort(bad); table.sort(seen)
            print(('%s hud_online: [%s] %s'):format(#bad == 0 and 'OK   ' or 'FALLA', table.concat(seen, ','), #bad == 0 and 'nada se pisa' or table.concat(bad, ' · ')))
            if #bad > 0 then print('Error: el HUD online se pisa') end
            -- (el cartel de presentación del modo se llega a VER: no se gasta tapado por la tarjeta)
            if not (HUDSEEN or {}).intro then print('Error: el cartel del modo no se vio (se gastó bajo la tarjeta)') end
        end
        love.event.quit()
    end
end
function love.draw()
    local perfT0 = love.timer.getTime()
    lovesize.begin()
    if gStateMachine:_top() then gStateMachine:render() end
    if PERFLOG then PERFLOG.draw = PERFLOG.draw + love.timer.getTime() - perfT0 end
    for i, n in ipairs({ 'skull', 'flag', 'hill', 'crown' }) do PixelIcons.draw(n, 20 + i * 40, 600, 3) end
    -- (el HUD sin pisarse: lo que se haya pisado en algún fotograma — src/ui/HudRects.lua —)
    if gStateMachine:_top() and gStateMachine:_top().localPaInit then
        HUDBAD = HUDBAD or {}
        for _, o in ipairs(require('src/ui/HudRects').overlaps()) do HUDBAD[o] = (HUDBAD[o] or 0) + 1 end
        HUDSEEN = HUDSEEN or {}
        for _, r in ipairs(require('src/ui/HudRects').list()) do HUDSEEN[r.name] = true end
    end
    lovesize.finish()
end
