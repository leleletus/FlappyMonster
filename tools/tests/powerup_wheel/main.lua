-- tools/tests/powerup_wheel — la RUEDA RÁPIDA de los power-ups (src/states/adventure/WheelState.lua; Plan 4b,
-- docs/design/flappy-plan-4b-powerups.md) con el juego de verdad, en una etapa de la campaña Flappy:
--   abre        mantener la rueda (Q / Tab / L) la abre encima del nivel y el nivel se CONGELA
--   usar        elegir el escudo y soltar: se aplica y se gasta YA (en el archivo de la partida)
--   apagado     uno que no se puede usar ahora (un imán con el súper imán puesto) no se gasta
--   cancelar    soltar sin elegir no gasta nada
--   atajo       la tecla 2 usa directamente el 2º tipo que se tiene
--   muriendo    con el jugador muriendo (o la etapa acabada) no se abre
--   gastado     gastar y luego morir: sigue gastado
--   tactil      tocar la bolsa del HUD la abre; tocar una casilla la usa
--   Capturas <save>/wheel_{960,1280,1600}.png          tools/tests/run.sh powerup_wheel
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local DT = 1 / 60
local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local realInput, pressed, held, co, wantShot = nil, {}, {}, nil, nil
local function top() return gStateMachine:_top() end
local function tick()
    local cur = pressed; pressed = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function(x) return held[x] == true end },
                         { __index = realInput })
    gameUpdate(DT)
    Input = realInput
end
local function wait(s) for _ = 1, math.floor(s / DT + 0.5) do tick(); if _ % 8 == 0 then coroutine.yield() end end end
local function press(a, s) pressed[a] = true; wait(s or 0.05) end
local function shot(name) wantShot = name; coroutine.yield('shot') end
local function resize(w, h) love.window.setMode(w, h, { resizable = true }); love.resize(w, h) end
local function name(st)
    for k, v in pairs(package.loaded) do if v == getmetatable(st) then return (k:match('[^/]+$')) end end
    return tostring(st)
end

local FlappyRun, FlappySave
local function inv(id) local d = FlappySave.load(1); return (d and d.inventory and d.inventory[id]) or 0 end
-- abre la rueda manteniendo la acción `wheel`
local function openWheel() pressed.wheel = true; held.wheel = true; wait(0.1) end
local function choose(id)
    local w = top()
    if name(w) ~= 'WheelState' then return end
    for i, s in ipairs(w.items) do if s.id == id then w.sel = i end end
end
local function release() held.wheel = false; wait(0.03) end

local function run()
    FlappyRun = require 'src/flappy/FlappyRun'
    FlappySave = require 'src/flappy/FlappySave'
    for i = 1, 3 do FlappySave.delete(i) end
    FlappyRun.open(1, 'normal')
    for _, id in ipairs({ 'shield', 'heart', 'magnet_all', 'magnet_points', 'strength' }) do FlappyRun.addPowerup(id) end
    FlappyRun.save()
    gStateMachine:change('flappy_map', { world = 1, node = 1 }); wait(0.6)
    press('confirm', 4.5)                           -- (entra y pasa la cuenta atrás)
    local adv = top()
    local inStage = name(adv) == 'AdventureState' and adv.powerups ~= nil
    local pa = adv.player
    -- abre: la rueda encima; el nivel congelado
    openWheel()
    local w = top()
    local opened = name(w) == 'WheelState'
    local x0, y0, t0 = pa.x, pa.y, adv.levelTime
    wait(1.0)
    local frozen = pa.x == x0 and pa.y == y0 and adv.levelTime == t0
    for _, wd in ipairs({ 960, 1600, 1280 }) do resize(wd, 720); wait(0.2); shot(wd) end
    check('abre', inStage and opened and frozen, ('etapa con power-ups=%s; rueda=%s; nivel congelado=%s'):format(
        tostring(inStage), tostring(opened), tostring(frozen)))
    -- usar el escudo (se mira justo al cerrar: luego un golpe contra el suelo lo gastaría)
    choose('shield'); release()
    check('usar', name(top()) == 'AdventureState' and pa.shield == true and inv('shield') == 0,
          ('vuelve al nivel=%s; escudo puesto=%s; en el archivo quedan %d'):format(name(top()), tostring(pa.shield), inv('shield')))
    -- apagado: con el súper imán puesto, el imán de puntos no se gasta
    openWheel(); choose('magnet_all'); release()
    openWheel(); choose('magnet_points'); release()
    check('apagado', pa:hasEffect('magnet_all') and inv('magnet_all') == 0 and inv('magnet_points') == 1,
          ('súper imán puesto=%s; imán de puntos sin gastar (%d)'):format(tostring(pa:hasEffect('magnet_all')), inv('magnet_points')))
    -- cancelar
    openWheel(); top().sel = nil; release()
    check('cancelar', name(top()) == 'AdventureState' and inv('heart') == 1 and inv('strength') == 1, 'soltar sin elegir no gasta nada')
    -- atajo: la tecla 2 = el 2º tipo que tiene (ahora: corazón, imán de puntos, fuerza → el imán de puntos está apagado: no;
    -- la 1 = el corazón)
    local hpMax0 = pa.hpMax
    press('wheel_1', 0.1)
    check('atajo', pa.hpMax == hpMax0 + 1 and inv('heart') == 0, ('tecla 1 → corazón: vida máxima %d → %d'):format(hpMax0, pa.hpMax))
    -- tactil: la bolsa del HUD abre; tocar la casilla de la fuerza la usa
    local FlappyHud = require 'src/ui/FlappyHud'
    local b = FlappyHud.bagRect()
    adv:touchpressed('d', b.x + b.w / 2, b.y + b.h / 2); wait(0.1)
    local tw = top()
    local touchOpen = name(tw) == 'WheelState'
    local usedTouch = false
    if touchOpen then
        local r
        for i, s in ipairs(tw.items) do if s.id == 'strength' then r = tw:_layout().cells[i] end end
        if r then
            tw:touchpressed('d', r.x + r.w / 2, r.y + r.h / 2); tw:touchreleased('d', r.x + r.w / 2, r.y + r.h / 2); wait(0.15)
            usedTouch = pa:hasEffect('strength') and inv('strength') == 0 and name(top()) == 'AdventureState'
        end
    end
    check('tactil', touchOpen and usedTouch, ('la bolsa abre=%s; tocar la fuerza la usa=%s'):format(tostring(touchOpen), tostring(usedTouch)))
    -- muriendo: no se abre; y lo gastado sigue gastado
    pa:die(nil, true); wait(0.1)
    openWheel(); release()
    local noOpen = name(top()) ~= 'WheelState'
    check('muriendo', noOpen, 'con el jugador muriendo la rueda no se abre')
    check('gastado', inv('shield') == 0 and inv('heart') == 0 and inv('strength') == 0, 'lo gastado sigue gastado tras morir')
    FlappyRun.close()
    for i = 1, 3 do FlappySave.delete(i) end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
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
        love.graphics.captureScreenshot(function(img) img:encode('png', 'wheel_' .. n .. '.png'); wantShot = nil end)
        wantShot = false
    end
end
