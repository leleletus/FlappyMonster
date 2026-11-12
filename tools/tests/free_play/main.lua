-- tools/tests/free_play — el Juego libre (Aventura → SOLO) con el juego real:
--  1. carga las fichas de TODOS los niveles (tiempo total, ninguno roto) y
--     las lista (nombre, monstruos, modos);
--  1a. la ayuda de abajo con las teclas del aparato (teclado / mando);
--  1b. la dificultad con teclado / mando: arriba desde la primera fila da el foco
--     al selector, ▶ / ◀ la cambian, abajo vuelve a la lista (captura free_play_diff.png);
--  2. navega con las flechas: la selección baja de fila en fila y el scroll
--     la sigue (siempre visible);
--  3. ENTER abre ese nivel en AdventureState (returnTo = free_play);
--  4. pausa → salir vuelve al Juego libre, con la misma selección;
--  5. capturas a 1280x720, 960x720 (4:3) y 1600x720 (móvil alargado):
--     <save>/free_play_{1280,960,1600}.png
--  6. vista fija en los niveles (src/ui/View.lua): con la ventana a 1600x720,
--     el menú usa 1600 de ancho lógico; al entrar en un nivel pasa a 1280
--     (bandas negras) y al salir vuelve a 1600. Captura free_play_level1600.png; la pausa, free_play_pause.png
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
            -- las AYUDAS con las teclas del aparato que se usa: teclado → [ENTER] / [F]; mando → [A] / [Y]
            local L = require 'src/core/Lang'
            local dev = realInput.lastDevice
            realInput.lastDevice = 'keyboard'; local hk = L('free.hint')
            realInput.lastDevice = 'gamepad'; local hp = L('free.hint')
            -- el ACELERÓMETRO de Android es un "joystick" que no es un mando: moverlo no pasa a modo mando (los controles
            -- táctiles parpadeaban y las ayudas pedían botones); un mando de verdad, sí
            local acc = { isConnected = function() return true end, isGamepad = function() return false end }
            local pad = { isConnected = function() return true end, isGamepad = function() return true end }
            realInput.lastDevice = 'touch'; love.joystickaxis(acc, 1, 0.95); love.joystickpressed(acc, 1)
            local afterAcc = realInput.lastDevice
            love.joystickaxis(pad, 1, 0.95)
            local afterPad = realInput.lastDevice
            check('acelerometro', afterAcc == 'touch' and afterPad == 'gamepad',
                ('con el dedo, mover el acelerómetro → %s; mover un mando → %s'):format(afterAcc, afterPad))
            realInput.lastDevice = dev
            check('ayudas', hk:find('[ENTER]', 1, true) and hk:find('[F]', 1, true) and hp:find('[A]', 1, true)
                and hp:find('[Y]', 1, true) and not hk:find('{', 1, true) and not hp:find('{', 1, true),
                ('teclado: "%s" · mando: "%s"'):format(hk, hp))
            -- las fichas del HILO (src/world/level/CatalogWorker.lua) son iguales que las calculadas aquí
            local LevelCatalog = require 'src/world/level/LevelCatalog'
            local function same(a, b)
                if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
                for k, v in pairs(a) do if not same(v, b[k]) then return false end end
                for k in pairs(b) do if a[k] == nil then return false end end
                return true
            end
            local diff = {}
            for i = 1, n do
                local info = fp:info(i)
                if not same(info, LevelCatalog.load(info.path, info.file)) then diff[#diff + 1] = info.file end
            end
            check('hilo', #diff == 0 and love.filesystem.getInfo('freeplay_cards.dat') ~= nil,
                ('fichas del hilo distintas: %s; guardadas en disco: %s'):format(#diff > 0 and table.concat(diff, ' ') or 'ninguna',
                    tostring(love.filesystem.getInfo('freeplay_cards.dat') ~= nil)))
            -- con la SUPERPOSICIÓN (Switch: actualización sin montar) el hilo lee los niveles de la versión descargada
            local base = 'update/slots/prueba_hilo/'
            love.filesystem.createDirectory(base .. 'assets/levels')
            local ovName = '_solo_en_la_version.json'
            love.filesystem.write(base .. 'assets/levels/' .. ovName, love.filesystem.read(fp:info(1).path))
            love.filesystem.remove('freeplay_cards.dat')
            OV = { out = love.thread.newChannel(), req = love.thread.newChannel() }
            OV.thread = love.thread.newThread('src/world/level/CatalogWorkerThread.lua')
            OV.thread:start({ ovName }, OV.out, OV.req, base, 'prueba', false)
            shot('1280'); step = 'ov'; T = t
        end
    elseif step == 'ov' then
        local m = OV.out:peek()
        if (m and (m.info or m.broken)) or OV.thread:getError() or t - T > 20 then
            check('hilo_version', m and m.info and m.info.file == '_solo_en_la_version.json',
                ('nivel que solo está en la versión descargada: %s'):format(tostring(m and (m.info and 'leído' or m.broken) or OV.thread:getError())))
            UPDATE_RMRF('update/slots/prueba_hilo')
            step, T = 'dif', t
        end
    elseif step == 'dif' and t - T > 0.3 then
        fp.sel = 1; pressNext('nav_up'); step, T = 'dif1b', t
    elseif step == 'dif1b' and t - T > 0.1 then
        -- (arriba desde la primera fila: las PESTAÑAS — ▶ pasa a JEFES, con el Boss Rush primero; ◀ vuelve —; arriba otra vez,
        -- la dificultad)
        TAB = { focus = fp.tabFocus }
        pressNext('nav_right'); step, T = 'dif1c', t
    elseif step == 'dif1c' and t - T > 0.1 then
        TAB.boss = fp.files[1] == '*bossrush' and #fp.files > 1
        for k = 2, #fp.files do if not require('src/world/level/LevelCatalog').hasBossZone(fp.files[k]) then TAB.boss = false end end
        shot('tab_boss')
        pressNext('nav_left'); step, T = 'dif1d', t
    elseif step == 'dif1d' and t - T > 0.1 then
        TAB.race = fp.files[1] ~= '*bossrush'
        pressNext('nav_up'); step, T = 'dif2', t
    elseif step == 'dif2' and t - T > 0.1 then
        DIF = { focus = fp.diffFocus }
        pressNext('nav_right'); step, T = 'dif3', t
    elseif step == 'dif3' and t - T > 0.1 then
        DIF.right = fp.diffT < 0.2 and fp.sel == 1            -- (cambió la dificultad, no la tarjeta)
        shot('diff'); step, T = 'dif4', t
    elseif step == 'dif4' and t - T > 0.2 then
        pressNext('nav_left'); step, T = 'dif5', t
    elseif step == 'dif5' and t - T > 0.1 then
        DIF.left = fp.diffT < 0.2 and fp.sel == 1
        pressNext('nav_down'); step, T = 'dif5b', t
    elseif step == 'dif5b' and t - T > 0.1 then
        pressNext('nav_down'); step, T = 'dif6', t
    elseif step == 'dif6' and t - T > 0.1 then
        check('pestanas', TAB.focus and TAB.boss and TAB.race, ('arriba → pestañas %s · ▶ JEFES: Boss Rush y solo niveles de jefe %s · ◀ CARRERAS %s'):format(
            tostring(TAB.focus), tostring(TAB.boss), tostring(TAB.race)))
        check('dificultad', DIF.focus and DIF.right and DIF.left and not fp.diffFocus and not fp.tabFocus and fp.sel == 1,
            ('arriba → foco %s, ▶ cambia %s, ◀ cambia %s, abajo → lista %s'):format(tostring(DIF.focus),
                tostring(DIF.right), tostring(DIF.left), tostring(not fp.diffFocus)))
        step, T = 'buscar', t
    elseif step == 'buscar' and t - T > 0.2 then
        -- EL BUSCADOR: / lo abre (la / no se escribe), escribir filtra (sin tildes ni mayúsculas: por nombre, jefe…);
        -- Esc borra la búsqueda, otro Esc la cierra sin salir de la pantalla
        local all = #fp.files
        love.keypressed('/'); love.textinput('/')
        for ch in ('ESCARABAJO gigánte'):gmatch('.[\128-\191]*') do love.textinput(ch) end
        local found = {}
        for _, f in ipairs(fp.files) do found[#found + 1] = f end
        shot('search')
        love.keypressed('escape')
        local cleared = #fp.files
        love.keypressed('escape')
        SRCH = { all = all, found = found, cleared = cleared, closed = not fp.searching, q = fp.query }
        step, T = 'buscar2', t
    elseif step == 'buscar2' and t - T > 0.2 then
        local f = SRCH.found
        check('buscar', #f == 1 and f[1] == 'templo_escarabajo.json' and SRCH.cleared == SRCH.all and SRCH.closed
            and SRCH.q == '' and top() == fp,
            ('«ESCARABAJO gigánte» → %s · Esc: %d/%d niveles · otro Esc: cerrado=%s, sigue en Juego libre=%s'):format(
                table.concat(f, ', '), SRCH.cleared, SRCH.all, tostring(SRCH.closed), tostring(top() == fp)))
        step, T = 'nav', t
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
        step, T = 'pshot', t
    elseif step == 'pshot' and t - T > 0.5 then
        shot('pause')                                   -- (la pausa: la ventana de opciones de los menús)
        step, T = 'pback', t
    elseif step == 'pback' and t - T > 0.2 then
        -- (REINTENTAR: está, y vuelve a empezar el mismo nivel; luego, a la pausa otra vez para salir)
        local p = top()
        local stack = gStateMachine.stack
        local adv = stack[#stack - 1]                     -- (el nivel, debajo de la pausa)
        local hasRetry = p.options and p.options[2] == 'common.retry'
        local lv0 = adv.levelPath
        p:_choose(2)
        local st2 = top()
        RETRY = hasRetry and st2 ~= adv and st2.levelPath == lv0 and st2.levelTime == 0
        gStateMachine:push('pause')
        top().selected = #top().options
        pressNext('confirm'); step, T = 'back', t
    elseif step == 'back' and t - T > 0.4 then
        local ok = st == top() and st.files ~= nil
        check('reintentar', RETRY == true, 'pausa → REINTENTAR: el mismo nivel desde el principio = ' .. tostring(RETRY))
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
        top().selected = #top().options
        pressNext('confirm'); step, T = 'vl4', t
    elseif step == 'vl4' and t - T > 0.5 then
        check('vista', MENU_W == 1600 and LEVEL_W == 1280 and WINDOW_W == 1600,
            ('ventana 1600x720: menú %d, nivel %d (fijo 16:9), tras salir %d'):format(MENU_W, LEVEL_W, WINDOW_W))
        gStateMachine:change('settings'); resize(1280, 720)
        require('src/core/Settings').showPerf = true           -- (el medidor, sin guardarlo)
        step, T = 'cfg', t
    elseif step == 'cfg' and t - T > 1.2 then
        shot('settings'); step, T = 'rush', t
    elseif step == 'rush' and t - T > 0.3 then
        -- BOSS RUSH: cada nivel empieza en la arena de su primer jefe y la pelea arranca sola (sin tocar nada); vencidos
        -- los jefes, el nivel termina y sigue el siguiente; con el último, el resumen en el Juego Libre y el récord
        require('src/core/Settings').showPerf = false
        local BossRush = require 'src/story/BossRush'
        local list = BossRush.levels()
        local bad = {}
        local function steps(n) for _ = 1, n do top():update(1 / 60) end end
        for _, f in ipairs(list) do
            gStateMachine:change('adventure', { level = 'assets/levels/' .. f, returnTo = 'free_play', atBoss = true, endOnBoss = true })
            steps(300 + math.floor(require('src/world/systems/StartCountdown').CARD_TIME * 60))                                -- (+ la tarjeta de presentación)
            local z = top().level.bossZones[1]
            if not (z and (z.state == 'intro' or z.state == 'fight')) then bad[#bad + 1] = f .. '=' .. tostring(z and z.state) end
        end
        check('rush_arena', #list >= 8 and #bad == 0, ('%d peleas; sin empezar sola: %s'):format(#list, #bad == 0 and 'ninguna' or table.concat(bad, ', ')))
        -- la cadena: dos peleas, vencidas a mano (zonas superadas)
        love.filesystem.remove('bossrush.dat')
        local realLevels = BossRush.levels
        BossRush.levels = function() return { list[1], list[2] } end
        BossRush.start(nil)
        local first = top().levelPath
        steps(200 + math.floor(require('src/world/systems/StartCountdown').CARD_TIME * 60))   -- (la tarjeta y la cuenta atrás del principio)
        for _, zz in ipairs(top().level.bossZones) do zz.state = 'cleared' end
        steps(240)                                                 -- (la celebración, y al siguiente)
        local second = top().levelPath
        local chained = second ~= first and top().rush and top().rush.i == 2
        steps(200 + math.floor(require('src/world/systems/StartCountdown').CARD_TIME * 60))
        for _, zz in ipairs(top().level.bossZones) do zz.state = 'cleared' end
        steps(240)
        local fp2 = top()
        local R = fp2.rushResult
        BossRush.levels = realLevels
        check('rush_cadena', chained and R and R.all and R.cleared == 2 and R.record and BossRush.best(nil) ~= nil,
            ('1ª → 2ª pelea=%s · resumen: todas=%s, vencidos %s, récord=%s guardado=%s'):format(tostring(chained), tostring(R and R.all),
            tostring(R and R.cleared), tostring(R and R.record), tostring(BossRush.best(nil))))
        shot('rush_result')
        love.filesystem.remove('bossrush.dat')
        step, T = 'ghost', t
    elseif step == 'ghost' and t - T > 0.3 then
        -- CONTRARRELOJ: la primera llegada a la meta guarda el fantasma; la siguiente partida lo tiene; una más lenta no lo pisa
        local Ghost = require 'src/story/Ghost'
        local path = os.getenv('META') or 'assets/levels/valle_soleado.json'
        love.filesystem.remove('ghosts/' .. path:match('([^/]+)%.json$') .. '.dat')
        local function steps(n) for _ = 1, n do top():update(1 / 60) end end
        local function run(secs)
            gStateMachine:change('adventure', { level = path, returnTo = 'free_play', ghost = true })
            local st0 = top()
            steps(200 + math.floor(require('src/world/systems/StartCountdown').CARD_TIME * 60) + math.floor(secs * 60))   -- (la tarjeta, la cuenta atrás y la carrera)
            st0:win()
            return st0
        end
        GH = { path = path, run = run, steps = steps }
        GH.b1 = (function() run(1); return Ghost.best(path) end)()
        -- (la 2ª partida: se deja correr de verdad unos fotogramas — que se DIBUJE el fantasma — y se captura)
        gStateMachine:change('adventure', { level = path, returnTo = 'free_play', ghost = true })
        GH.st = top()
        steps(200)
        step, T = 'ghost2', t
    elseif step == 'ghost2' and t - T > 0.6 then
        local Ghost = require 'src/story/Ghost'
        shot('ghost'); step, T = 'ghost3', t
    elseif step == 'ghost3' and t - T > 0.3 then
        local Ghost = require 'src/story/Ghost'
        local path, run = GH.path, GH.run
        local hasGhost = GH.st.ghost and GH.st.ghost.draw ~= nil
        GH.st:win()
        local b2 = Ghost.best(path)                                  -- (más rápida: el récord nuevo)
        run(3)
        local b3 = Ghost.best(path)
        local b1 = GH.b1
        check('fantasma', b1 ~= nil and hasGhost and b2 < b1 and b3 == b2, ('1ª llegada guarda %.2f s · la 2ª lo ve=%s y mejora a %.2f · una más lenta no lo pisa (%.2f)'):format(
            b1 or -1, tostring(hasGhost), b2 or -1, b3 or -1))
        gStateMachine:change('free_play')
        step, T = 'end', t
    elseif step == 'end' and t - T > 0.5 then
        require('src/core/Settings').showPerf = false
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
