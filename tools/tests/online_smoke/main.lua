-- tools/tests/online_smoke — prueba online de humo, sin humano.
-- Un cliente REAL (OnlineAdventureState) + un bot juegan una partida contra un
-- servidor LOCAL (nunca el real) y se comprueba que no salta ningún error.
--
--   love server --headless &                 (desde la raíz del repo)
--   LEVEL=assets/levels/carrera01.json MODE=race love tools/tests/online_smoke
--   pkill -f "^love server"
--
-- (MODE: race | hunt | koth; SECS = duración, 16 por defecto)
-- WATCH=bomb: además apunta los estados que ve el cliente de las entidades de
-- ese tipo, los tiles que cambian y la vida del jugador local; con WANT=lit,exploding
-- falla si alguno de esos estados no llegó (p. ej. la arena de bombas:
-- LEVEL=tools/levelgen/arenas/bombas.json)
-- WANTTILES=thin_ice_1,thin_ice_2,...: falla si el cliente no llegó a ver esos
-- tiles (eventos 'tile' del servidor), p. ej. el hielo fino que se agrieta bajo
-- el jugador local (LEVEL=tools/levelgen/arenas/hielo.json)
-- WANTICE=1: falla si el jugador local nunca quedó congelado (congelador:
-- LEVEL=tools/levelgen/arenas/congelador.json WATCH=gummy WANT=frozen WANTICE=1)
io.stdout:setvbuf("no")
love.filesystem.setSymlinksEnabled(true)
lovesize = require 'libs/lovesize'
Timer    = require 'libs/timer'
require 'settings'
Input = require 'input'
Sound = require 'src/Sound'
StateMachine = require 'src/StateMachine'
NC = require 'src/network/NetworkClient'
Notify = require 'src/ui/Notify'
local sock = require 'libs/sock'
local bitser = require 'libs/bitser'
local P = require 'src/network/Protocol'
local PixelIcons = require 'src/ui/PixelIcons'
local OnlineAdventureState = require 'src/states/OnlineAdventureState'
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
    bot.c = sock.newClient('localhost', 22122, P.CHANNELS)
    bot.c:setSerialization(bitser.dumps, bitser.loads)
    bot.c:on('game_init', function() bot.inGame = true end)
    bot.c:on('login_success', function(d) bot.logged = true; bot.id = d.id end)
    bot.c:connect()
    -- un segundo cliente con un nombre NO permitido (disfrazado con números y guiones): el servidor lo rechaza
    bad = sock.newClient('localhost', 22122, P.CHANNELS)
    bad:setSerialization(bitser.dumps, bitser.loads)
    bad:on('login_error', function(d) BADNAME = d and d.key end)
    bad:on('login_success', function() BADNAME = 'ACEPTADO' end)
    bad:connect()
end
function love.update(dt)
    t = t + dt
    Timer.update(dt); Sound.update(dt); NC:update(dt); bot.c:update(); bad:update()
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
    if bot.inGame then
        bot.acc = bot.acc + dt
        while bot.acc >= P.TICK_DT do bot.acc = bot.acc - P.TICK_DT; bot.seq = bot.seq + 1
            table.insert(bot.bits, P.encodeInput(false, bot.seq % 120 < 60, false, false, bot.seq % 40 == 0, false)) end
        if #bot.bits > 0 then bot.c:send('in', { s = bot.seq - #bot.bits + 1, b = bot.bits }); bot.bits = {} end
    end
    Input = setmetatable({ pressed = stub.pressed, down = stub.down }, { __index = package.loaded['input'] })
    if gStateMachine:_top() then gStateMachine:update(dt) end
    Input = package.loaded['input']
    if st and st.localPaInit then frames = frames + 1 end
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
        end
    end
    -- Reloj del HUD en los modos con tiempo: tiene que ir hacia atrás
    if st and st.roundEndAt then
        local left = st.roundEndAt - st.levelTime
        clk = clk or { first = left, t = t }
        clk.last, clk.lastT = left, t
    end
    if t > (tonumber(os.getenv('SECS')) or 16) then
        if os.getenv('DIFF') and st and st.level then      -- la dificultad de la sala llega al cliente y a su jugador
            local want = ({ easy = 4 })[os.getenv('DIFF')] or 3
            print(('dificultad: sala %s → cliente %s, vida del jugador %s'):format(os.getenv('DIFF'), tostring(st.level.difficulty), tostring(st.localPa and st.localPa.hpMax)))
            if st.level.difficulty ~= os.getenv('DIFF') or (st.localPa and st.localPa.hpMax) ~= want then print('Error: la dificultad no llegó al cliente') end
            -- (Xtra extremo cambia QUÉ hay: el cliente construye el nivel con la dificultad y le salen los dos jefes)
            local nb = 0
            for _, e in pairs(st.enemyRenderers or {}) do if e.def and e.def.boss then nb = nb + 1 end end
            print(('jefes en el cliente: %d'):format(nb))
            if os.getenv('DIFF') == 'xtra' and #(st.level.bossZones or {}) > 0 and nb < 2 then print('Error: el cliente no tiene los dos jefes de Xtra extremo') end
        end
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
            for w in (os.getenv('WANT') or ''):gmatch('[^,]+') do
                if not watch.states[w] then print('Error: el cliente no vio el estado ' .. w) end
            end
        end
        if not GIVE2 then print('Error: ceder el admin (cliente → bot → cliente): ida=' .. tostring(GIVE1) .. ' vuelta=' .. tostring(GIVE2)) end
        if BADNAME ~= 'srv.name_blocked' then print('Error: el servidor no rechazó el nombre vetado (' .. tostring(BADNAME) .. ')') end
        print(('admin cedido y devuelto=%s · nombre vetado rechazado por el servidor=%s'):format(tostring(GIVE2), tostring(BADNAME)))
        print(('OK: %d fotogramas de partida sin errores; iconos: skull %dx%d, flag %dx%d, hill %dx%d, corona %dx%d'):format(frames,
            PixelIcons.size('skull'), select(2, PixelIcons.size('skull')), PixelIcons.size('flag'), select(2, PixelIcons.size('flag')),
            PixelIcons.size('hill'), select(2, PixelIcons.size('hill')), PixelIcons.CROWN_W, PixelIcons.CROWN_H))
        love.event.quit()
    end
end
function love.draw()
    lovesize.begin()
    if gStateMachine:_top() then gStateMachine:render() end
    for i, n in ipairs({ 'skull', 'flag', 'hill', 'crown' }) do PixelIcons.draw(n, 20 + i * 40, 600, 3) end
    lovesize.finish()
end
