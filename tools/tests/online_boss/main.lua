-- tools/tests/online_boss — pelea de jefe ONLINE sin humano: un cliente real
-- (OnlineAdventureState) y un bot entran andando a la arena (la pelea empieza
-- cuando todos están dentro) y se quedan quietos. Desde el cliente se registra
-- lo que llega del jefe por red (estados, vida) y cualquier error, y se hacen
-- capturas (<save>/boss_*.png) en los estados que interesan.
-- Si el nivel tiene inundaciones conectadas a la pelea (control 'boss', p. ej.
-- fortaleza_malvada) comprueba lo que ve el cliente: en el mínimo antes de la
-- pelea, activas durante ella (llega por red) y sin saltos del agua.
--
--   love server --headless &
--   LEVEL=assets/levels/guarida_cangrejo_rey.json love tools/tests/online_boss
--   pkill -f "^love server"
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
local Crawler = require 'src/world/entities/Crawler'
local OnlineAdventureState = require 'src/states/OnlineAdventureState'
local LEVEL = os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json'
local SECS = tonumber(os.getenv('SECS')) or 60
local t, st = 0, nil
local stub = P.newInputStub()
local bot = { seq = 0, acc = 0, bits = {} }
local log = { states = {}, maxJump = 0, shots = {}, lastState = nil }
local STOP_X                    -- x a la que andan (dentro de la arena)
local function snap(name) love.graphics.captureScreenshot(function(img) img:encode('png', 'boss_' .. name .. '.png') end) end

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    lovesize.set(1280, 720)
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    FONT_MED   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    FONT_BIG   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 28)
    Input.load(); Sound.load(); love.audio.setVolume(0)
    local Done = { new = function() return setmetatable({}, { __index = { enter = function() log.roundOver = t end,
        update = function() end, render = function() end, exit = function() end } }) end }
    gStateMachine = StateMachine:new({ online_adventure = function() return OnlineAdventureState:new() end,
                                       online_results = function() return Done.new() end,
                                       online_room = function() return Done.new() end })
    NC:on('login_success', function() NC:send('create_room', { name = 'Jefe', maxPlayers = 4 }) end)
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
    bot.c:on('s', function(s) if s.o then bot.x = s.o[1] end end)
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
    local boss
    if st and st.enemyRenderers then
        for _, er in pairs(st.enemyRenderers) do if er.def and er.def.boss then boss = er end end
    end
    if boss and boss.zone and not STOP_X then STOP_X = boss.zone.x0 + 3 * TILE_PX end
    -- bot: anda a la derecha hasta entrar en la arena
    if bot.inGame then
        bot.acc = bot.acc + dt
        while bot.acc >= P.TICK_DT do bot.acc = bot.acc - P.TICK_DT; bot.seq = bot.seq + 1
            local right, left, jump = STOP_X and bot.x and bot.x < STOP_X + 40, false, false
            if boss and bot.x and bot.inArena and boss.state ~= 'dormant' then
                local d = bot.x - boss.x
                if math.abs(d) < 4 * TILE_PX then
                    right, left = d > 0, d <= 0
                    jump = math.abs(d) < 2.5 * TILE_PX and bot.seq % 20 == 0
                end
            end
            if STOP_X and bot.x and bot.x >= STOP_X then bot.inArena = true end
            table.insert(bot.bits, P.encodeInput(left, right, false, false, jump, false)) end
        if #bot.bits > 0 then bot.c:send('in', { s = bot.seq - #bot.bits + 1, b = bot.bits }); bot.bits = {} end
    end
    -- cliente: igual
    local s = stub.state
    s.left, s.jump, s.crouch, s.jump_pressed, s.crouch_pressed = false, false, false, false, false
    s.right = st and st.localPa and STOP_X and st.localPa.x < STOP_X or false
    local pa = st and st.localPa
    if pa and boss and STOP_X and pa.x >= STOP_X - 10 and boss.state ~= 'dormant' then
        local d = pa.x - boss.x
        if math.abs(d) < 4 * TILE_PX then
            s.right, s.left = d > 0, d <= 0
            s.jump_pressed = math.abs(d) < 2.5 * TILE_PX and math.floor(t * 3) ~= math.floor((t - dt) * 3)
            s.jump = s.jump_pressed
        end
    end
    Input = setmetatable({ pressed = stub.pressed, down = stub.down }, { __index = package.loaded['input'] })
    if gStateMachine:_top() then gStateMachine:update(dt) end
    Input = package.loaded['input']
    if boss then
        if boss.state ~= log.lastState then
            log.lastState = boss.state
            log.states[#log.states + 1] = ('%.1f %s(%s/%s)'):format(t, boss.state, boss.hp, boss.hpMax)
            log.stateT = t
        end
        -- (DEBUG_CLIMB: posición fotograma a fotograma al empezar a trepar)
        if os.getenv('DEBUG_CLIMB') and (boss.state == 'climb' or log.lastState == 'climb') then
            log.cn = (log.cn or 0) + 1
            if log.cn <= 14 then
                local fx, fy = Crawler.pose(boss)
                print(('    f%02d %s crawl=%s att=%s x=%.1f y=%.1f pose=%.1f,%.1f'):format(log.cn, boss.state,
                    tostring(boss.crawl), tostring(boss.cattached), boss.x, boss.y, fx, fy))
            end
        end
        -- saltos del dibujo al trepar (pose)
        if boss.crawl and boss.cattached then
            local fx, fy = Crawler.pose(boss)
            if log.pfx then
                local j = math.sqrt((fx - log.pfx) ^ 2 + (fy - log.pfy) ^ 2)
                log.maxJump = math.max(log.maxJump, j)
                if j > 3 and os.getenv('DEBUG_JUMPS') then
                    print(('  salto %.1f px en %s  giro=%s n=(%d,%d) xy=%.0f,%.0f'):format(j, boss.state, tostring(Crawler.turning(boss)), boss.cnx, boss.cny, boss.x, boss.y))
                end
            end
            log.pfx, log.pfy = fx, fy
        else log.pfx = nil end
        -- Bloques de jefe y súbditos tal y como los ve el cliente
        local wl, nm = {}, 0
        for _, er in pairs(st.enemyRenderers) do
            if er.def.name == 'bosswall' then wl[#wl + 1] = er.state end
            if er.summonOf and er.alive then nm = nm + 1 end
        end
        local key = table.concat(wl, ',') .. ' súbditos=' .. nm
        if key ~= log.lastOther then log.lastOther = key; log.states[#log.states + 1] = ('\n    %.1f [cliente] bloques=%s'):format(t, key) end
        for _, want in ipairs({ 'climb', 'aim', 'stuck', 'chase', 'dying_shrink', 'summon', 'wallaim' }) do
            if not os.getenv('NOSHOTS') and boss.state == want and not log.shots[want] and t - (log.stateT or t) > 0.4 then
                log.shots[want] = true; snap(want)
            end
        end
    end
    -- Inundaciones conectadas a la pelea, tal y como las ve el cliente
    if st and st.level and st.level.floods then
        for i, f in ipairs(st.level.floods) do
            if f.control == 'boss' then
                local fl = log.floods or {}; log.floods = fl
                local r = fl[i] or { maxStep = 0, preBad = 0, sawActive = false, maxLv = 0 }; fl[i] = r
                if r.last then r.maxStep = math.max(r.maxStep, math.abs(f.level - r.last)) end
                r.last = f.level
                r.maxLv = math.max(r.maxLv, f.level)
                if boss and boss.zone and boss.zone.state ~= 'fight' and not r.sawActive and math.abs(f.level - f.lo) > 1e-3 then
                    r.preBad = r.preBad + 1
                end
                if f.active then r.sawActive = true end
                r.f = f
            end
        end
    end
    if t > SECS or (log.roundOver and t > log.roundOver + 0.5) then
        for i, r in pairs(log.floods or {}) do
            local f = r.f
            -- (el salto máximo por fotograma: lo que sube a su velocidad + margen por el reloj estimado)
            local lim = math.max(f.riseSpeed, f.fallSpeed) * 0.1 + 0.05
            local ok = r.sawActive and r.preBad == 0 and r.maxStep <= lim and r.maxLv > f.lo + 0.5
            print(('%s inundación #%d (pelea de jefe): activa en la pelea=%s, fuera del mínimo antes=%d, máximo visto %.2f (mín %.2f máx %.2f), salto máximo %.3f casillas/fotograma (límite %.3f)'):format(
                ok and 'OK   ' or 'FALLA', f.id, tostring(r.sawActive), r.preBad, r.maxLv, f.lo, f.hi, r.maxStep, lim))
            if not ok then log.fail = true end
        end
        if log.roundOver then print(('Ronda terminada a los %.1f s'):format(log.roundOver)) end
        print('Estados del jefe vistos en el cliente:')
        print('  ' .. table.concat(log.states, '  '))
        print(('Salto máximo del dibujo trepando: %.1f px por fotograma'):format(log.maxJump))
        love.event.quit(log.fail and 1 or 0)
    end
end
function love.draw() lovesize.begin(); if gStateMachine:_top() then gStateMachine:render() end; lovesize.finish() end
