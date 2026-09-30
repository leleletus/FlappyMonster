-- tools/tests/free_play — el Juego libre (Aventura → SOLO) con el juego real:
--  1. carga las fichas de TODOS los niveles (tiempo total, ninguno roto) y
--     las lista (nombre, monstruos, modos);
--  2. navega con las flechas: la selección baja de fila en fila y el scroll
--     la sigue (siempre visible);
--  3. ENTER abre ese nivel en AdventureState (returnTo = free_play);
--  4. pausa → salir vuelve al Juego libre, con la misma selección;
--  5. capturas a 1280x720, 960x720 (4:3) y 1600x720 (móvil alargado):
--     <save>/free_play_{1280,960,1600}.png
--  6. vista fija en los niveles (src/ui/View.lua): con la ventana a 1600x720,
--     el menú usa 1600 de ancho lógico; al entrar en un nivel pasa a 1280
--     (bandas negras) y al salir vuelve a 1600. Captura free_play_level1600.png
--
--   tools/tests/run.sh free_play
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local press = {}                   -- acciones "pulsadas" este fotograma
local realInput
local function pressNext(a) press[a] = true end

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local step, t, frame, shotQ = 'load', 0, 0, {}
local fp, t0

function love.load(a)
    gameLoad(a)
    -- Aislada del escritorio: el ratón real (cursor, clics), el táctil y el
    -- foco de la ventana no deben tocar la prueba (mientras corre la batería
    -- las ventanas aparecen bajo el cursor)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    gStateMachine:change('free_play')
    fp = gStateMachine:_top()
    t0 = love.timer.getTime()
end

local function top() return gStateMachine:_top() end
local function shot(name) shotQ[#shotQ + 1] = name end

local function resize(w, h)
    love.window.setMode(w, h, { resizable = true })
    love.resize(w, h)
end

function love.update(dt)
    t = t + dt; frame = frame + 1
    -- Input de prueba: las acciones de `press` cuentan como pulsadas una vez
    local cur = press; press = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
                         { __index = realInput })
    gameUpdate(dt)
    Input = realInput

    local st = top()
    if step == 'load' then
        local n, loaded, broken = #fp.files, 0, {}
        for i = 1, n do
            local info = fp:info(i)
            if info then loaded = loaded + 1; if info.broken then broken[#broken + 1] = info.file end end
        end
        if loaded == n or t > 20 then
            for i = 1, n do
                local info = fp:info(i)
                if info and not info.broken then
                    print(('   %-24s %-24s %3d monstruos  %s'):format(info.file, info.name, info.monsters,
                        table.concat(info.modeList, ',')))
                end
            end
            check('fichas', loaded == n and #broken == 0 and n >= 20,
                ('%d/%d niveles en %.2f s, rotos: %s'):format(loaded, n, love.timer.getTime() - t0,
                    #broken > 0 and table.concat(broken, ' ') or 'ninguno'))
            shot('1280'); step = 'nav'; T = t
        end
    elseif step == 'nav' and t - T > 0.3 then
        local cols = math.max(1, math.floor((WINDOW_W - 48 + 24) / (372 + 24)))
        step, T, NAV = 'nav2', t, { sel0 = fp.sel, n = 0, cols = cols }
    elseif step == 'nav2' then
        if NAV.n < 4 and frame % 6 == 0 then pressNext('nav_down'); NAV.n = NAV.n + 1 end
        if NAV.n >= 4 and t - T > 1.5 then
            local want = math.min(#fp.files, NAV.sel0 + 4 * NAV.cols)
            -- (la fila de la seleccionada tiene que estar dentro de la vista)
            local row = math.floor((fp.sel - 1) / NAV.cols)
            local y = 104 + row * (318 + 24) - fp.scroll
            if fp.sel ~= want then
                print(('   (diagnóstico: arriba=%s, aviso bloqueando=%s, sel=%d)'):format(
                    top() == fp and 'Juego libre' or tostring(top()), tostring(require('src/ui/Notify').blocking()), fp.sel))
            end
            check('navegar', fp.sel == want and y >= 96 and y + 318 <= WINDOW_H - 40 + 8,
                ('4 veces abajo: %d → %d (%d columnas), tarjeta en y=%d, scroll %d'):format(NAV.sel0, fp.sel, NAV.cols, y, fp.scroll))
            SEL = fp.sel
            pressNext('confirm'); step, T = 'play', t
        end
    elseif step == 'play' and t - T > 0.5 then
        local path = fp.files[SEL] and ('assets/levels/' .. fp.files[SEL])
        check('jugar', st.levelPath == path and st.returnTo == 'free_play',
            ('ENTER abre %s (returnTo=%s)'):format(tostring(st.levelPath), tostring(st.returnTo)))
        gStateMachine:push('pause')
        top().selected = 2
        pressNext('confirm'); step, T = 'back', t
    elseif step == 'back' and t - T > 0.4 then
        local ok = st == top() and st.files ~= nil
        check('volver', ok and st.sel == SEL, ('pausa → salir: %s, selección %s (antes %d)'):format(
            st.files and 'Juego libre' or tostring(st), tostring(st.sel), SEL))
        fp = st
        resize(960, 720); step, T = 'r960', t
    elseif step == 'r960' and t - T > 0.6 then
        shot('960'); step, T = 'r960b', t
    elseif step == 'r960b' and t - T > 0.3 then          -- (que la captura se haga antes de cambiar)
        resize(1600, 720); step, T = 'r1600', t
    elseif step == 'r1600' and t - T > 0.6 then
        shot('1600'); step, T = 'vl', t
    elseif step == 'vl' and t - T > 0.3 then
        MENU_W = WINDOW_W
        pressNext('confirm'); step, T = 'vl2', t
    elseif step == 'vl2' and t - T > 0.8 then
        LEVEL_W = WINDOW_W
        shot('level1600')
        step, T = 'vl3', t
    elseif step == 'vl3' and t - T > 0.3 then
        gStateMachine:push('pause')
        top().selected = 2
        pressNext('confirm'); step, T = 'vl4', t
    elseif step == 'vl4' and t - T > 0.5 then
        check('vista', MENU_W == 1600 and LEVEL_W == 1280 and WINDOW_W == 1600,
            ('ventana 1600x720: menú %d, nivel %d (fijo 16:9), tras salir %d'):format(MENU_W, LEVEL_W, WINDOW_W))
        step, T = 'end', t
    elseif step == 'end' and t - T > 0.5 then
        print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
        print('capturas: ' .. love.filesystem.getSaveDirectory() .. '/free_play_*.png')
        love.event.quit(fails == 0 and 0 or 1)
    end
end

function love.draw()
    gameDraw()
    local name = table.remove(shotQ, 1)
    if name then love.graphics.captureScreenshot(function(img) img:encode('png', 'free_play_' .. name .. '.png') end) end
end
