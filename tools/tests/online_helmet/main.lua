-- tools/tests/online_helmet — casco de Gummy y pez globo ONLINE: un cliente
-- real (OnlineAdventureState, con su predicción) + un bot contra un servidor
-- LOCAL, en un nivel pequeño (level.json de esta carpeta):
--   A. el jugador cae sobre un Gummy con casco y rebota encima unos segundos:
--      rebota (sonido helmetBounce predicho), el casco sigue, sin daño;
--   B. ground pound encima: el Gummy muere, el casco se rompe (helmetBreak
--      llega del servidor), sin daño;
--   C. anda hasta el estanque del pez globo: se hincha y pincha (pufferPrick
--      del servidor, -1 de vida), sin morir.
--
--   tools/tests/run.sh online_helmet LEVEL=tools/tests/online_helmet/level.json
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
local OnlineAdventureState = require 'src/states/OnlineAdventureState'
local LEVEL = os.getenv('LEVEL')
local t, st = 0, nil
local stub = P.newInputStub()
local bot = { seq = 0, acc = 0, bits = {} }
local heard = {}
local T = { phase = 'wait' }

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    lovesize.set(1280, 720)
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    FONT_MED   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    FONT_BIG   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 28)
    Input.load(); Sound.load(); love.audio.setVolume(0)
    -- Qué suena en el cliente (predicho o llegado del servidor)
    -- (Sound.playAt también pasa por Sound.play: se cuenta una vez)
    local play = Sound.play
    Sound.play = function(n, ...) heard[n] = (heard[n] or 0) + 1; return play(n, ...) end
    local Done = { new = function() return setmetatable({}, { __index = { enter = function() end,
        update = function() end, render = function() end, exit = function() end } }) end }
    gStateMachine = StateMachine:new({ online_adventure = function() return OnlineAdventureState:new() end,
                                       online_results = function() return Done.new() end,
                                       online_room = function() return Done.new() end })
    NC:on('login_success', function() NC:send('create_room', { name = 'Casco', maxPlayers = 4 }) end)
    NC:on('room_error', function(d) print('room_error', d.key, d.msg) end)
    local phase = 0
    NC:on('room_update', function(d)
        if not st and d.state == 'IN_GAME' then gStateMachine:change('online_adventure', { room = d }); st = gStateMachine:_top() end
        if phase == 0 then phase = 1
            NC:send('set_mode', { mode = 'race', level = LEVEL })
            bot.roomId = d.id end        -- (el bot entra cuando haya iniciado sesión)
    end)
    NC:connect('localhost', 22122, 'Cliente')        -- (nunca el servidor real)
    bot.c = sock.newClient('localhost', 22122, P.CHANNELS)
    bot.c:setSerialization(bitser.dumps, bitser.loads)
    bot.c:on('game_init', function() bot.inGame = true end)
    bot.c:on('login_success', function() bot.logged = true end)
    bot.c:connect()
end

local function gummy()
    for _, er in pairs(st.enemyRenderers or {}) do if er.def and er.def.name == 'gummy' then return er end end
end

local function finish()
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
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
    if bot.inGame then        -- el bot: quieto (manda "nada" de vez en cuando)
        bot.acc = bot.acc + dt
        while bot.acc >= P.TICK_DT do bot.acc = bot.acc - P.TICK_DT; bot.seq = bot.seq + 1
            if bot.seq % 30 == 0 then table.insert(bot.bits, P.encodeInput(false, false, false, false, false, false)) end end
        if #bot.bits > 0 then bot.c:send('in', { s = bot.seq - #bot.bits + 1, b = bot.bits }); bot.bits = {} end
    end

    -- ── Prueba (sobre el jugador propio) ──────────────────────────────────────
    local s = stub.state
    local pa = st and st.localPaInit and st.localPa
    if pa then
        local g = gummy()
        T.minHp = math.min(T.minHp or 99, pa.hp)
        T.died = T.died or pa.dying
        if T.phase == 'wait' then
            T.phase, T.t0, T.hp0 = 'A', t, pa.hp
        elseif T.phase == 'A' and t - T.t0 > 6 then
            check('rebote', (heard.helmetBounce or 0) >= 2 and g and g.helmet and g.alive and not T.died and T.minHp == T.hp0,
                ('rebotes oídos=%d, casco=%s, jugador %s, vida mínima %d/%d'):format(heard.helmetBounce or 0,
                    tostring(g and g.helmet), T.died and 'MUERTO' or 'vivo', T.minHp, T.hp0))
            T.phase = 'B'
        elseif T.phase == 'B' then
            -- Ground pound al caer de un rebote, con el Gummy debajo
            if not T.gpAt and not pa.onGround and pa.vy > 0 and g and pa.y < g.y - 90 then
                s.crouch_pressed = true; T.gpAt = t
            end
            if T.gpAt and t - T.gpAt > 1.5 then
                local dead = not g or not g.alive or g.state == 'dead'
                check('gp', dead and not (g and g.helmet) and (heard.helmetBreak or 0) >= 1 and not T.died and T.minHp == T.hp0,
                    ('gummy %s, casco=%s, helmetBreak oído=%d, jugador %s vida %d'):format(dead and 'muerto' or 'VIVO',
                        tostring(g and g.helmet), heard.helmetBreak or 0, T.died and 'MUERTO' or 'vivo', pa.hp))
                T.phase, T.t1, T.hpC = 'C', t, pa.hp
            end
        elseif T.phase == 'C' then
            s.right = true
            if pa.hp < T.hpC and not T.prickAt then T.prickAt = t end
            if (T.prickAt and t - T.prickAt > 1.0) or t - T.t1 > 12 then
                s.right = false
                check('pez', T.prickAt ~= nil and (heard.pufferPrick or 0) >= 1 and (heard.pufferInflate or 0) >= 1
                    and not pa.dying and pa.hp == T.hpC - 1,
                    ('se hinchó=%d, pufferPrick oído=%d, vida %d→%d, %s'):format(heard.pufferInflate or 0,
                        heard.pufferPrick or 0, T.hpC, pa.hp, pa.dying and 'MUERTO' or 'vivo'))
                finish()
            end
        end
    end
    if t > 60 then print('tiempo agotado en la fase ' .. T.phase); fails = fails + 1; finish() end

    Input = setmetatable({ pressed = stub.pressed, down = stub.down }, { __index = package.loaded['input'] })
    if gStateMachine:_top() then gStateMachine:update(dt) end
    Input = package.loaded['input']
end

function love.draw()
    lovesize.begin()
    if gStateMachine:_top() then gStateMachine:render() end
    lovesize.finish()
end
