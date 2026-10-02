-- tools/tests/story_flow — el MODO HISTORIA con el juego real (etapa 1: cimientos):
--  1. partidas: tres huecos vacíos; ENTER en el 1 pregunta la DIFICULTAD (Extremo y Xtra cerradas),
--     se elige Fácil, crea la partida y abre el mapa; el nivel se juega en esa dificultad (4 de vida);
--  2. mapa: el mundo 1 con su camino; el nodo 2 está CERRADO (ENTER no entra) y el mundo 2 también;
--  3. jugar el nivel 1 y llegar a la META (se teletransporta al jugador): cartel, y vuelve al
--     mapa con el nivel superado, el siguiente abierto y el monstruo ya en él;
--  4. el nivel 2 igual; salir a las partidas: el hueco 1 dice 2 niveles;
--  5. se RELEE del disco (como al reabrir el juego): el progreso sigue ahí;
--  6. con todos los niveles y el jefe del mundo 1 superados se abre el mundo 2;
--  6b. las VIDAS son de la aventura: perder una en un nivel se nota en el siguiente; salir por la pausa las
--     guarda; sin vidas = GAME OVER: de vuelta al principio del mundo (sus niveles, sin superar), vidas de
--     nuevo; en Xtra extremo, todo el juego; vidas de partida 3 / 3 / 3 / 4 / 6;
--  6c. RESULTADOS tras cada nivel (estadísticas, nota S-D, puntos) y de ahí al mapa; notas con casos fijos;
--     premios (vida por la primera S, premio del mundo una sola vez);
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
        pressNext('confirm'); go('pick')
    elseif step == 'pick' and t - T > 0.3 then
        -- partida nueva: pregunta la dificultad (Normal elegida; Extremo y Xtra, cerradas)
        local p = st.pick
        local Difficulty = require 'src/Difficulty'
        check('dificultad', p ~= nil and Difficulty.ORDER[p.sel] == 'normal' and st:_diffOpen(1) and st:_diffOpen(3)
            and not st:_diffOpen(4) and not st:_diffOpen(5),
            ('pide dificultad=%s (elegida %s); fácil/difícil abiertas=%s/%s; extremo/xtra cerradas=%s/%s'):format(tostring(p ~= nil),
             tostring(p and Difficulty.ORDER[p.sel]), tostring(st:_diffOpen(1)), tostring(st:_diffOpen(3)),
             tostring(not st:_diffOpen(4)), tostring(not st:_diffOpen(5))))
        shot('difficulty')
        pressNext('nav_up'); go('pick2')
    elseif step == 'pick2' and t - T > 0.3 then
        pressNext('confirm'); go('map')
    elseif step == 'map' and t - T > 0.4 then
        check('mapa', st.world == 1 and st.node == 1 and Run.active() and love.filesystem.getInfo('story1.sav') ~= nil
            and Run.data.difficulty == 'easy',
            ('mundo %s nodo %s; partida creada en disco=%s'):format(tostring(st.world), tostring(st.node),
             tostring(love.filesystem.getInfo('story1.sav') ~= nil)))
        shot('map_1280')
        pressNext('nav_right'); go('locked')
    elseif step == 'locked' and t - T > 0.3 then
        -- el camino al nodo 2 está cerrado: el monstruo no anda (choca) y ABAJO no pasa al mundo 2
        LOCK1 = top().node == 1 and top().world == 1 and #top().queue == 0 and top().levelPath == nil
        pressNext('nav_down'); go('locked3')
    elseif step == 'locked3' and t - T > 0.3 then
        check('cerrado', LOCK1 and st.world == 1 and Run.state(1, 2) == 'locked' and not Run.worldOpen(2),
            ('DERECHA hacia el nodo 2 cerrado no anda=%s; ABAJO no pasa al mundo 2 (sigue en el %s)'):format(tostring(LOCK1), tostring(st.world)))
        go('play1')
    elseif step == 'play1' and t - T > 0.3 then
        pressNext('confirm'); go('in1')
    elseif step == 'in1' and t - T > 0.6 then
        IN1 = st.levelPath == Worlds.path(W1[1].id) and st.returnTo == 'story_map' and st.level.difficulty == 'easy'
              and st.player.hpMax == 4
        LIVES0 = st.player.lives
        st.player.lives = st.player.lives - 1               -- (pierde una vida en el nivel)
        toFinish(st); go('won1')
    elseif step == 'won1' and t - T > 0.5 then
        WON1 = st.won == true
        go('back1')
    elseif step == 'back1' and t - T > 3.2 then
        -- antes del mapa, los RESULTADOS del nivel: estadísticas, nota y premio
        local sm = st.sum
        local d = Run.data.best[W1[1].id]
        check('resultados', sm ~= nil and st.rows ~= nil and #st.rows == 5 and sm.grade ~= nil and d and d.grade == sm.grade
            and sm.rating <= 100 and sm.rating >= 0 and Run.data.points == sm.points,
            ('pantalla de resultados=%s: nota %s (%s/100), puntos %s; guardada en la partida=%s'):format(tostring(st.rows ~= nil),
             tostring(sm and sm.grade), tostring(sm and sm.rating), tostring(sm and sm.points), tostring(d and d.grade)))
        go('res1a')
    elseif step == 'res1a' and t - T > 7.0 then          -- (la animación ya ha acabado: un ENTER vuelve al mapa)
        shot('results')
        pressNext('confirm'); go('back1b')
    elseif step == 'back1b' and t - T > 0.5 then
        check('superar', IN1 and WON1 and st.world == 1 and st.node == 2 and Run.isDone(W1[1].id) and Run.state(1, 2) == 'open',
            ('entra en %s=%s; meta=%s; vuelve al mapa en el nodo %s; nivel 1 superado=%s, nodo 2 %s'):format(W1[1].id, tostring(IN1),
             tostring(WON1), tostring(st.node), tostring(Run.isDone(W1[1].id)), Run.state(1, 2)))
        shot('map_done')
        pressNext('confirm'); go('in2')
    elseif step == 'in2' and t - T > 0.6 then
        check('vidas', LIVES0 == 3 and Run.data.lives == 2 and st.player.lives == 2,
            ('empieza con %s; pierde una en el nivel 1 → la aventura lleva %s y el nivel 2 empieza con %s'):format(tostring(LIVES0),
             tostring(Run.data.lives), tostring(st.player.lives)))
        toFinish(st); go('back2')
    elseif step == 'back2' and t - T > 3.6 then
        pressNext('confirm'); go('back2a')
    elseif step == 'back2a' and t - T > 0.2 then
        pressNext('confirm'); go('back2b')
    elseif step == 'back2b' and t - T > 0.5 then
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
        shot('map_w2')
        -- GAME OVER en el mundo 2: con su nivel 1 superado, entra en el 2, sale por la pausa con una vida
        -- menos (se guarda), vuelve a entrar y se queda sin vidas
        local W2 = Worlds.nodes(2)
        Run.data.done[W2[1].id] = true; Run.save()
        pressNext('nav_right'); go('go1')
    elseif step == 'go1' and t - T > 0.3 then
        pressNext('confirm'); go('go2')
    elseif step == 'go2' and t - T > 0.6 then
        st.player.lives = st.player.lives - 1
        gStateMachine:push('pause'); top().selected = 2
        pressNext('confirm'); go('go3')
    elseif step == 'go3' and t - T > 0.5 then
        QUIT_LIVES = Run.data.lives
        pressNext('confirm'); go('go4')
    elseif step == 'go4' and t - T > 0.6 then
        IN_LIVES = st.player.lives
        st.player.lives = 1
        st.player:die(nil, true); go('go5')
    elseif step == 'go5' and (st.dead and st.deadTimer > 1.0 or t - T > 12) then
        DEAD, NOTE = st.dead == true, st.gameOverNote
        pressNext('confirm'); go('go6')
    elseif step == 'go6' and t - T > 0.5 then
        local W2 = Worlds.nodes(2)
        check('game_over', QUIT_LIVES == 1 and IN_LIVES == 1 and DEAD and st.world == 2 and st.node == 1 and st.notice ~= nil
            and Run.data.lives == 3 and not Run.isDone(W2[1].id) and Run.isDone(W1[1].id) and Run.data.gameOvers == 1,
            ('salir por la pausa guarda las vidas (%s) y se vuelve a entrar con %s; sin vidas: GAME OVER=%s → mapa mundo %s nodo %s, '
             .. 'vidas %s, mundo 2 reiniciado=%s, mundo 1 intacto=%s'):format(tostring(QUIT_LIVES), tostring(IN_LIVES), tostring(DEAD),
             tostring(st.world), tostring(st.node), tostring(Run.data.lives), tostring(not Run.isDone(W2[1].id)), tostring(Run.isDone(W1[1].id))))
        shot('game_over_map')
        -- vidas de partida y Game Over por dificultad (sin jugar: la lógica de la partida)
        local s4, s6 = Save.new('extreme').lives, Save.new('xtra').lives
        local keepSlot, keepData = Run.slot, Run.data
        Run.slot, Run.data = 3, Save.new('xtra')
        Run.data.done[W1[1].id], Run.data.done[W2[1].id], Run.data.lives = true, true, 1
        local back = Run.gameOver(2)
        local wiped = back == 1 and next(Run.data.done) == nil and Run.data.lives == 6
        Save.delete(3)
        Run.slot, Run.data = keepSlot, keepData
        check('extremos', Save.new('easy').lives == 3 and Save.new('hard').lives == 3 and s4 == 4 and s6 == 6 and wiped,
            ('vidas al empezar: fácil %d, difícil %d, extremo %d, xtra %d; Game Over en Xtra: todo el juego de nuevo=%s'):format(
             Save.new('easy').lives, Save.new('hard').lives, s4, s6, tostring(wiped)))
        -- NOTAS (src/story/Score.lua): casos fijos
        local Score = require 'src/story/Score'
        local perfect = Score.level({ time = 60, par = 90, deaths = 0, hits = 0, kills = 8, killable = 8, stars = 5, starsTotal = 5 })
        local mid = Score.level({ time = 180, par = 90, deaths = 1, hits = 3, kills = 4, killable = 8, stars = 2, starsTotal = 5 })
        local bad = Score.level({ time = 400, par = 90, deaths = 3, hits = 6, kills = 0, killable = 8, stars = 0, starsTotal = 5 })
        local empty = Score.level({ time = 60, par = 90, deaths = 0, hits = 0, kills = 0, killable = 0, stars = 0, starsTotal = 0 })
        local avg, ag = Score.average({ 100, 80 }, 4)
        check('notas', perfect.rating == 100 and perfect.grade == 'S' and mid.rating == 52 and mid.grade == 'C' and bad.rating == 0
            and bad.grade == 'D' and empty.rating == 100 and Score.par(160) == 120 and Score.par(10) == 40 and avg == 45 and ag == 'D',
            ('perfecto %d %s; regular %d %s; desastre %d %s; nivel sin enemigos ni estrellas %d; referencia de 160 casillas %d s; media de mundo %d %s'):format(
             perfect.rating, perfect.grade, mid.rating, mid.grade, bad.rating, bad.grade, empty.rating, Score.par(160), avg, ag))
        -- premios: la primera S de un nivel da una vida; repetirla, no; el mundo completo da el suyo una vez
        local keepSlot, keepData = Run.slot, Run.data
        Run.slot, Run.data = 3, Save.new('hard')
        local full = { score = 100, time = 30, width = 100, lives = 3, deaths = 0, hits = 0, kills = 1, killable = 1, stars = 1, starsTotal = 1 }
        local r1 = Run.complete(W1[1].id, full)
        local l1 = Run.data.lives
        local r2 = Run.complete(W1[1].id, full)
        local l2 = Run.data.lives
        for k = 2, #W1 - 1 do full.lives = Run.data.lives; Run.complete(W1[k].id, full) end
        full.lives = Run.data.lives
        local rb = Run.complete(W1[#W1].id, full)
        Save.delete(3)
        local lw = Run.data.lives
        Run.slot, Run.data = keepSlot, keepData
        check('premios', r1.grade == 'S' and r1.reward and r1.reward.lives == 1 and l1 == 4 and r2.reward == nil and l2 == 3 and r1.points == 120
            and rb.world and rb.world.grade == 'S' and rb.world.reward and rb.world.reward.lives == 2,
            ('primera S: +%s vida (vidas %d), puntos ×1,2 en Difícil = %d; repetirla: premio=%s; mundo completo: nota %s, +%s vidas'):format(
             tostring(r1.reward and r1.reward.lives), l1, r1.points, tostring(r2.reward), tostring(rb.world and rb.world.grade),
             tostring(rb.world and rb.world.reward and rb.world.reward.lives)))
        MOODS = { { 'S', 98, 'happy' }, { 'C', 60, 'meh' }, { 'D', 40, 'sad' }, { 'D', 10, 'dead' } }
        MI = 0
        go('mood')
    -- La REACCIÓN del monstruo en los resultados: nervioso al contar; luego contento / sin más / triste /
    -- se muere del disgusto (capturas story_mood_<nota>_{wait,react}.png)
    elseif step == 'mood' and t - T > 0.3 then
        MI = MI + 1
        local m = MOODS[MI]
        if not m then gStateMachine:change('story_map', { world = 2, node = 1 }); go('r960') else
            gStateMachine:change('story_results', { level = W1[1].id, result = { time = 90, deaths = 1, hits = 2, kills = 3, killable = 6, stars = 1, starsTotal = 4 },
                summary = { rating = m[2], grade = m[1], parts = {}, points = 100 }, map = { world = 1, node = 1 }, color = { 0.36, 0.62, 0.36 } })
            go('mood2')
        end
    elseif step == 'mood2' and t - T > 0.2 then
        local m = MOODS[MI]
        MOODOK = (MOODOK ~= false) and st.mood == m[3]
        st.t = 2.6; go('mood3')
    elseif step == 'mood3' and t - T > 0.1 then
        shot('mood_' .. MOODS[MI][3] .. '_wait'); go('mood4')
    elseif step == 'mood4' and t - T > 0.2 then
        st.t = st.tStamp + (MOODS[MI][3] == 'dead' and 0.3 or 1.2); go('mood5')
    elseif step == 'mood5' and t - T > 0.1 then
        shot('mood_' .. MOODS[MI][3] .. '_react')
        if MI == #MOODS then
            check('reaccion', MOODOK, 'S → contento, C → sin más, D → triste, D con menos de 25 → se muere del disgusto: ' .. tostring(MOODOK))
        end
        go('mood')
    elseif step == 'r960' and t - T > 0.3 then resize(960, 720); go('r960b')
    elseif step == 'r960b' and t - T > 0.5 then shot('map_960'); go('r1600')
    elseif step == 'r1600' and t - T > 0.3 then resize(1600, 720); go('r1600b')
    elseif step == 'r1600b' and t - T > 0.5 then shot('map_1600'); resize(1280, 720); TOUR = 0; go('tour')
    -- VUELTA por el mapa: todos los mundos abiertos (copia de la partida, se restaura) y una captura
    -- de cada uno, con el monstruo ya llegado a su primer nivel (story_world_<n>.png)
    elseif step == 'tour' and t - T > 0.3 then
        if TOUR == 0 then
            KEEP = {}
            for k, v in pairs(Run.data.done) do KEEP[k] = v end
            for w = 1, Worlds.count() - 1 do for _, n in ipairs(Worlds.nodes(w)) do Run.data.done[n.id] = true end end
        end
        TOUR = TOUR + 1
        if TOUR > Worlds.count() then
            Run.data.done = KEEP; Run.save(); go('del')
        else
            gStateMachine:change('story_map', { world = TOUR, node = 1 }); go('tour2')
        end
    elseif step == 'tour2' and t - T > 0.6 then shot('world_' .. TOUR); go('tour')
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
