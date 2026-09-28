-- tools/tests/online_smoke — prueba online de humo, sin humano.
-- Un cliente REAL (OnlineAdventureState) + un bot juegan una partida contra un
-- servidor LOCAL (nunca el real) y se comprueba que no salta ningún error.
--
--   love server --headless &                 (desde la raíz del repo)
--   LEVEL=assets/levels/carrera01.json MODE=race love tools/tests/online_smoke
--   pkill -f "^love server"
--
-- (MODE: race | hunt | koth; SECS = duración, 16 por defecto)
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
        if phase == 0 then phase = 1
            NC:send('set_mode', { mode = os.getenv('MODE') or 'race', level = LEVEL })
            bot.roomId = d.id end        -- (el bot entra cuando haya iniciado sesión)
    end)
    NC:connect('localhost', 22122, 'Prueba')     -- (nunca el servidor real)
    bot.c = sock.newClient('localhost', 22122, P.CHANNELS)
    bot.c:setSerialization(bitser.dumps, bitser.loads)
    bot.c:on('game_init', function() bot.inGame = true end)
    bot.c:on('login_success', function() bot.logged = true end)
    bot.c:connect()
end
function love.update(dt)
    t = t + dt
    Timer.update(dt); Sound.update(dt); NC:update(dt); bot.c:update()
    if not bot.hello and bot.c:isConnected() then bot.hello = true; bot.c:send('hello', { v = P.VERSION, name = 'Bot' }) end
    if bot.logged and bot.roomId and not bot.joined then
        bot.joined = true; bot.c:send('join_room', { id = bot.roomId }); bot.readyAt = t + 1.2 end
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
    if t > (tonumber(os.getenv('SECS')) or 16) then
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
