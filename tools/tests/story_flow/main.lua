-- tools/tests/story_flow — el MODO HISTORIA con el juego real (etapa 1: cimientos):
--  1. partidas: tres huecos vacíos; ENTER en el 1 crea la partida y abre el mapa;
--  2. mapa: el mundo 1 con su camino; el nodo 2 está CERRADO (ENTER no entra) y el mundo 2 también;
--  3. jugar el nivel 1 y llegar a la META (se teletransporta al jugador): cartel, y vuelve al
--     mapa con el nivel superado, el siguiente abierto y el monstruo ya en él;
--  4. el nivel 2 igual; salir a las partidas: el hueco 1 dice 2 niveles;
--  5. se RELEE del disco (como al reabrir el juego): el progreso sigue ahí;
--  6. con todos los niveles y el jefe del mundo 1 superados se abre el mundo 2;
--  7. borrar la partida (dos pulsaciones) la deja vacía;
--  8. capturas del mapa y de las partidas a 1280, 960 y 1600 de ancho: <save>/story_*.png
--   tools/tests/run.sh story_flow
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local press, realInput = {}, nil
local function pressNext(a) press[a] = true end
local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local step, t, T, shotQ = 'start', 0, 0, {}
local Save, Run, Worlds

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    Save, Run, Worlds = require 'src/story/Save', require 'src/story/Run', require 'src/story/Worlds'
    for i = 1, Save.SLOTS do Save.delete(i) end
    gStateMachine:change('story_slots')
end

local function top() return gStateMachine:_top() end
local function shot(name) shotQ[#shotQ + 1] = name end
local function resize(w, h) love.window.setMode(w, h, { resizable = true }); love.resize(w, h) end

-- Lleva al jugador a la meta del nivel en curso
local function toFinish(st)
    local lv = st.level
    for r = 1, lv.tileH do
        for c = 1, lv.tileW do
            if lv:getDef(c, r).trigger == 'finish' then
                st.player.x, st.player.y = (c - 0.5) * TILE_PX, (r - 0.5) * TILE_PX
                st.player.vx, st.player.vy = 0, 0
                return true
            end
        end
    end
end

local go = function(s) step, T = s, t end
function love.update(dt)
    t = t + dt
    local cur = press; press = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
                         { __index = realInput })
    gameUpdate(dt)
    Input = realInput
    local st = top()
    local W1 = Worlds.nodes(1)

    if step == 'start' and t > 0.4 then
        local empty = true
        for i = 1, Save.SLOTS do if st.slots[i] then empty = false end end
        check('huecos', st.slots ~= nil and empty, ('%d huecos, todos vacíos=%s'):format(Save.SLOTS, tostring(empty)))
        shot('slots_1280'); go('open')
    elseif step == 'open' and t - T > 0.3 then
        pressNext('confirm'); go('map')
    elseif step == 'map' and t - T > 0.4 then
        check('mapa', st.world == 1 and st.node == 1 and Run.active() and love.filesystem.getInfo('story1.sav') ~= nil,
            ('mundo %s nodo %s; partida creada en disco=%s'):format(tostring(st.world), tostring(st.node),
             tostring(love.filesystem.getInfo('story1.sav') ~= nil)))
        shot('map_1280')
        pressNext('nav_right'); go('locked')
    elseif step == 'locked' and t - T > 0.3 then
        pressNext('confirm'); go('locked2')
    elseif step == 'locked2' and t - T > 0.4 then
        local stayed = top().node == 2 and top().world == 1 and top().levelPath == nil
        pressNext('nav_down'); go('locked3'); LOCK1 = stayed
    elseif step == 'locked3' and t - T > 0.3 then
        check('cerrado', LOCK1 and st.world == 1 and Run.state(1, 2) == 'locked' and not Run.worldOpen(2),
            ('ENTER en el nodo 2 cerrado no entra=%s; ABAJO no pasa al mundo 2 (sigue en el %s)'):format(tostring(LOCK1), tostring(st.world)))
        pressNext('nav_left'); go('play1')
    elseif step == 'play1' and t - T > 0.3 then
        pressNext('confirm'); go('in1')
    elseif step == 'in1' and t - T > 0.6 then
        IN1 = st.levelPath == Worlds.path(W1[1].id) and st.returnTo == 'story_map'
        toFinish(st); go('won1')
    elseif step == 'won1' and t - T > 0.5 then
        WON1 = st.won == true
        go('back1')
    elseif step == 'back1' and t - T > 3.2 then
        check('superar', IN1 and WON1 and st.world == 1 and st.node == 2 and Run.isDone(W1[1].id) and Run.state(1, 2) == 'open',
            ('entra en %s=%s; meta=%s; vuelve al mapa en el nodo %s; nivel 1 superado=%s, nodo 2 %s'):format(W1[1].id, tostring(IN1),
             tostring(WON1), tostring(st.node), tostring(Run.isDone(W1[1].id)), Run.state(1, 2)))
        shot('map_done')
        pressNext('confirm'); go('in2')
    elseif step == 'in2' and t - T > 0.6 then
        toFinish(st); go('back2')
    elseif step == 'back2' and t - T > 3.6 then
        OK2 = Run.isDone(W1[2].id) and st.node == 3
        pressNext('back'); go('slots2')
    elseif step == 'slots2' and t - T > 0.4 then
        local s = st.slots and st.slots[1]
        check('partida', OK2 and s and s.done == 2 and not Run.active(),
            ('nivel 2 superado=%s; el hueco 1 dice %s niveles'):format(tostring(OK2), tostring(s and s.done)))
        -- releer del disco, como al reabrir el juego
        package.loaded['src/story/Run'] = nil
        local d = Save.load(1)
        check('guardado', d ~= nil and d.done[W1[1].id] == true and d.done[W1[2].id] == true and d.world == 1 and d.node == 3,
            ('en disco: %s y %s superados, mundo %s nodo %s'):format(tostring(d and d.done[W1[1].id]), tostring(d and d.done[W1[2].id]),
             tostring(d and d.world), tostring(d and d.node)))
        -- todo el mundo 1 superado → se abre el 2
        for _, n in ipairs(W1) do d.done[n.id] = true end
        Save.write(1, d)
        pressNext('confirm'); go('world2')
    elseif step == 'world2' and t - T > 0.4 then
        local open = Run.worldOpen(2)
        local w0 = st.world
        pressNext('nav_down'); go('world2b'); OPEN2, W0 = open, w0
    elseif step == 'world2b' and t - T > 0.3 then
        check('mundo2', OPEN2 and st.world == 2 and Run.state(2, 1) == 'open' and Run.state(2, 2) == 'locked',
            ('mundo 1 completo → mundo 2 abierto=%s; ABAJO pasa al mundo %s; su nodo 1 %s, el 2 %s'):format(tostring(OPEN2), tostring(st.world),
             Run.state(2, 1), Run.state(2, 2)))
        shot('map_w2'); go('r960')
    elseif step == 'r960' and t - T > 0.3 then resize(960, 720); go('r960b')
    elseif step == 'r960b' and t - T > 0.5 then shot('map_960'); go('r1600')
    elseif step == 'r1600' and t - T > 0.3 then resize(1600, 720); go('r1600b')
    elseif step == 'r1600b' and t - T > 0.5 then shot('map_1600'); go('del')
    elseif step == 'del' and t - T > 0.3 then
        resize(1280, 720)
        pressNext('back'); go('del2')
    elseif step == 'del2' and t - T > 0.5 then
        shot('slots_used')
        st:_delete(1); st:_delete(1); go('del3')
    elseif step == 'del3' and t - T > 0.3 then
        check('borrar', st.slots[1] == false and love.filesystem.getInfo('story1.sav') == nil,
            ('hueco 1 vacío=%s, archivo borrado=%s'):format(tostring(st.slots[1] == false), tostring(love.filesystem.getInfo('story1.sav') == nil)))
        go('end')
    elseif step == 'end' and t - T > 0.4 then
        print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
        print('capturas: ' .. love.filesystem.getSaveDirectory() .. '/story_*.png')
        love.event.quit(fails == 0 and 0 or 1)
    end
end

function love.draw()
    gameDraw()
    if #shotQ > 0 then
        local name = table.remove(shotQ, 1)
        love.graphics.captureScreenshot('story_' .. name .. '.png')
    end
end
