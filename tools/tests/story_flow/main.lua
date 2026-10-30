-- tools/tests/story_flow — el MODO HISTORIA con el juego real (etapa 1: cimientos):
--  0. guardado roto: el principal cortado se lee de la copia .bak; los dos rotos → hueco vacío y .damaged;
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
--     premios (vida por la primera S, premio del mundo una sola vez); REPETIR: solo suman los puntos que superan el
--     récord del nivel y una vida extra ya cogida solo da puntos;
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
local introSeen
local SHIDS, DROPPED, ENDING, FILMS, WALK1, RUN, SEC, JB
local XS, AST
local CAN
local Save, Run, Worlds

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    Save, Run, Worlds = require 'src/story/Save', require 'src/story/Run', require 'src/story/Worlds'
    for i = 1, Save.SLOTS do Save.delete(i) end
    pcall(love.filesystem.remove, 'story.sav'); pcall(love.filesystem.remove, 'story.sav.bak')          -- (desbloqueos globales de una pasada anterior)
    -- 0. guardado ROTO (el juego se cerró a mitad de escribir): vale la copia .bak; con los dos rotos, el hueco sale
    --    vacío pero el archivo se aparta a .damaged
    do
        local d = Save.new('hard'); d.lives = 7
        local wrote = Save.write(2, d)
        love.filesystem.write('story2.sav', 'return { done = {')                   -- (cortado a medias)
        local fromBak = Save.load(2)
        love.filesystem.write('story2.sav.bak', 'basura')
        pcall(love.filesystem.remove, 'story2.sav.damaged')
        local none = Save.load(2)
        local kept = love.filesystem.getInfo('story2.sav.damaged') ~= nil
        check('roto', wrote and fromBak and fromBak.lives == 7 and fromBak.difficulty == 'hard' and none == nil and kept,
            ('escribe=%s; principal cortado → copia: vidas %s; los dos rotos → %s, apartado a .damaged=%s'):format(
             tostring(wrote), tostring(fromBak and fromBak.lives), tostring(none), tostring(kept)))
        Save.delete(2); pcall(love.filesystem.remove, 'story2.sav.damaged')
    end
    gStateMachine:change('story_slots')
end

local function top() return gStateMachine:_top() end
local function shot(name) shotQ[#shotQ + 1] = name end
local function resize(w, h) love.window.setMode(w, h, { resizable = true }); love.resize(w, h) end

-- Lleva al jugador a la meta del nivel en curso (o a la casilla con otro trigger: 'secret_exit')
local function toFinish(st, trigger)
    local lv = st.level
    for r = 1, lv.tileH do
        for c = 1, lv.tileW do
            if lv:getDef(c, r).trigger == (trigger or 'finish') then
                st.player.x, st.player.y = (c - 0.5) * TILE_PX, (r - 0.5) * TILE_PX
                st.player.vx, st.player.vy = 0, 0
                return true
            end
        end
    end
end

local go = function(s) step, T = s, t end
-- (los nodos del MAPA de un mundo: sus niveles, el bonus y sus secretos, como los pone StoryMapState)
local function mapNodesOf(w)
    local list = {}
    for _, n in ipairs(Worlds.nodes(w)) do list[#list + 1] = n end
    if Worlds.bonus(w) then list[#list + 1] = Worlds.bonus(w) end
    for _, n in ipairs(Worlds.secrets(w)) do list[#list + 1] = n end
    return list
end
local function mapNode(w, k) return mapNodesOf(w)[k] end
local function stopOfMap(w, k)                -- (= StoryMapState:_stopOf, sin estar en el mapa)
    local i = k
    for ww = 1, w - 1 do i = i + #mapNodesOf(ww) end
    return i
end
function love.update(dt)
    t = t + dt
    local cur = press; press = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
                         { __index = realInput })
    gameUpdate(dt)
    Input = realInput
    local st = top()
    local W1 = Worlds.nodes(1)
    -- (mientras el cartucho elegido se mete o la transición de pantalla tapa: el guion espera; docs/architecture/menus.md)
    if require('src/ui/menu/Transition').active() and step == 'in1' then
        IRIS1, IRISF = true, (IRISF or 0) + 1
        if IRISF == 22 then shot('level_iris') end                 -- (a media transición: el iris sobre el monstruo)
    end
    if st.inserting or require('src/ui/menu/Transition').active() then return end
    -- (la cuenta atrás del principio de cada nivel, StartCountdown: se prueba en el primero — pasos in1 / in1b —; en
    -- los demás se pasa de largo, como las películas)
    if st.startCd and CD_DONE then st.startCd = nil end
    -- (una partida nueva empieza con la INTRO de la historia, y algunos niveles con la suya: aquí se pasan de largo; la
    -- prueba de las películas es tools/tests/story_film)
    if st.film and st._finish then
        introSeen = (introSeen or 0) + 1
        if FILMS then FILMS[#FILMS + 1] = st.film.name end
        st:_finish()
        return
    end

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
        local Difficulty = require 'src/core/Difficulty'
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
        top():_move(1); go('locked')                     -- (al nodo siguiente: está cerrado)
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
        -- ENTRAR desde el mapa: iris + fundido (Transition, estilo 'level') y la cuenta atrás con todo congelado
        CD1 = { x = st.player.x, y = st.player.y, cd = st.startCd }
        shot('level_countdown')
        go('in1b')
    elseif step == 'in1b' and t - T > 1.0 then
        local p = st.player
        check('entrar', IRIS1 == true and CD1.cd ~= nil and CD1.cd > 0 and st.startCd ~= nil and st.startCd < CD1.cd
            and p.x == CD1.x and p.y == CD1.y and st.levelTime == 0,
            ('transición al entrar=%s; cuenta atrás %.2f → %s s; el jugador quieto=%s; reloj del nivel %.2f'):format(tostring(IRIS1),
             CD1.cd or -1, tostring(st.startCd and ('%.2f'):format(st.startCd)), tostring(p.x == CD1.x and p.y == CD1.y), st.levelTime))
        -- (y de pie SOBRE el suelo: el primer paso de física no lo mueve — antes salía metido y lo sacaba al empezar)
        local y0 = p.y
        p:update(1 / 60, st.level)
        check('apoyado', p.onGround and math.abs(p.y - y0) < 1,
            ('al acabar la cuenta atrás el primer paso lo mueve %.1f px (en el suelo=%s)'):format(p.y - y0, tostring(p.onGround)))
        CD_DONE = true
        st.startCd = nil
        IN1 = st.levelPath == Worlds.path(W1[1].id) and st.returnTo == 'story_map' and st.level.difficulty == 'easy'
              and st.player.hpMax == 4
        LIVES0 = st.player.lives
        st.player.lives = st.player.lives - 1               -- (pierde una vida en el nivel)
        -- (premio de vida con CUALQUIER nota, solo en este nivel: al salir del nivel terminado no se puede perder)
        local Score = require 'src/story/Score'
        REW_KEEP = Score.LEVEL_REWARD
        Score.LEVEL_REWARD = setmetatable({}, { __index = function() return { lives = 1 } end })
        toFinish(st); go('won1')
    elseif step == 'won1' and t - T > 0.5 then
        WON1 = st.won == true
        go('back1')
    elseif step == 'back1' and t - T > 3.2 then
        -- antes del mapa, los RESULTADOS del nivel: estadísticas, nota y premio
        local sm = st.sum
        local d = Run.data.best[W1[1].id]
        require('src/story/Score').LEVEL_REWARD = REW_KEEP
        check('premio_vida', sm and sm.reward and sm.reward.lives == 1 and Run.data.lives == LIVES0,
            ('nivel terminado con premio +1: vidas %s → %s (esperado %s, el premio no se pisa al salir)'):format(
             tostring(LIVES0 - 1), tostring(Run.data.lives), tostring(LIVES0)))
        Run.data.lives = LIVES0 - 1; Run.save()              -- (lo de después cuenta sin el premio)
        check('resultados', sm ~= nil and st.rows ~= nil and #st.rows == 5 and sm.grade ~= nil and d and d.grade == sm.grade
            and sm.rating <= 100 and sm.rating >= 0 and Run.data.points == sm.points,
            ('pantalla de resultados=%s: nota %s (%s/100), puntos %s; guardada en la partida=%s'):format(tostring(st.rows ~= nil),
             tostring(sm and sm.grade), tostring(sm and sm.rating), tostring(sm and sm.points), tostring(d and d.grade)))
        go('res1a')
    elseif step == 'res1a' and t - T > 7.0 then          -- (la animación ya ha acabado: un ENTER vuelve al mapa)
        shot('results')
        pressNext('confirm'); go('back1b')
    elseif step == 'back1b' and t - T > 0.5 then
        -- vuelve al mapa en el nodo que ACABA de superar (no en el nuevo) y el siguiente se abre a la vista
        local opens = st.opening and st.opening[2] == true
        check('superar', IN1 and WON1 and st.world == 1 and st.node == 1 and opens and Run.isDone(W1[1].id) and Run.state(1, 2) == 'open',
            ('entra en %s=%s; meta=%s; vuelve al mapa en el nodo %s (el superado); el nodo 2 se abre a la vista=%s; nivel 1 superado=%s, nodo 2 %s'):format(W1[1].id, tostring(IN1),
             tostring(WON1), tostring(st.node), tostring(opens), tostring(Run.isDone(W1[1].id)), Run.state(1, 2)))
        shot('map_done')
        -- FLECHAS POR DIRECCIÓN: desde cada parada, pulsar hacia donde sale el camino a la siguiente lleva a ella
        -- (aunque quede a la izquierda), y hacia donde sale el de la anterior, a la anterior
        local bad, tested = {}, 0
        local keep = { st.world, st.node, Run.data.done }
        local all = {}
        for w = 1, Worlds.count() do for _, n in ipairs(Worlds.nodes(w)) do all[n.id] = true end end
        Run.data.done = all
        local total = 0
        for w = 1, Worlds.count() do total = total + #Worlds.nodes(w) end
        -- FLECHAS DEL MAPA, parada a parada (con todo abierto): desde cada una, a la anterior y a la siguiente por el
        -- camino se llega SIEMPRE con alguna flecha; esa flecha apunta de verdad hacia el nodo vecino; y una flecha
        -- que no apunta a ninguna vecina no hace NADA (ni anterior / siguiente, ni saltar de mundo)
        local DIRV = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
        local away, nothing, stops, worstDot = {}, {}, 0, 1
        for w = 1, Worlds.count() do
            for k = 1, #Worlds.nodes(w) do
                stops = stops + 1
                local x0, y0 = st:_nodeXY(w, k)
                local map = st:_dirs(w, k)
                for _, d in ipairs({ 1, -1 }) do
                    local to = k + d
                    if to >= 1 and to <= #Worlds.nodes(w) then
                        tested = tested + 1
                        local tx, ty = st:_nodeXY(w, to)
                        local len = math.max(1, math.sqrt((tx - x0) ^ 2 + (ty - y0) ^ 2))
                        local reached, best = false, -2
                        for name, v in pairs(DIRV) do
                            st.world, st.node, st.queue = w, k, {}
                            st.heroX, st.heroY = x0, y0
                            if map[name] then
                                st:_dirMove(v[1], v[2])
                                if st.world == w and st.node == to then
                                    reached = true
                                    best = math.max(best, ((tx - x0) * v[1] + (ty - y0) * v[2]) / len)
                                end
                            end
                        end
                        if not reached then bad[#bad + 1] = ('%d:%d→%d'):format(w, k, to)
                        else
                            worstDot = math.min(worstDot, best)
                            if best < 0.3 then away[#away + 1] = ('%d:%d→%d (%.2f)'):format(w, k, to, best) end
                        end
                    end
                end
                for name, v in pairs(DIRV) do
                    if not map[name] then
                        st.world, st.node, st.queue = w, k, {}
                        st.heroX, st.heroY = x0, y0
                        local moved = st:_dirMove(v[1], v[2])
                        if moved or st.world ~= w or st.node ~= k or #st.queue > 0 then nothing[#nothing + 1] = ('%d:%d %s'):format(w, k, name) end
                    end
                end
            end
        end
        if os.getenv('MAPDBG') then
            for w = 1, Worlds.count() do
                for k2 = 1, #Worlds.nodes(w) do
                    local x0, y0 = st:_nodeXY(w, k2)
                    local m = st:_dirs(w, k2)
                    print(('MAP %d:%d (%.0f,%.0f)  izq=%s der=%s arriba=%s abajo=%s'):format(w, k2, x0, y0, tostring(m.left), tostring(m.right), tostring(m.up), tostring(m.down)))
                end
            end
        end
        -- encadenar: pulsar otra vez mientras anda sigue desde donde va a llegar
        st.world, st.node, st.queue = 1, 1, {}
        st.heroX, st.heroY = st:_nodeXY(1, 1)
        local m1 = st:_dirs(1, 1)
        local first
        for name, v in pairs(DIRV) do if m1[name] and not first then first = v end end
        st:_dirMove(first[1], first[2])
        local w1, k1, q1 = st.world, st.node, #st.queue
        local chained = false
        for name, v in pairs(DIRV) do
            local m2 = st:_dirs(w1, k1)
            if not chained and m2[name] and not (v[1] == -first[1] and v[2] == -first[2]) then
                st:_dirMove(v[1], v[2])
                chained = #st.queue > q1 and not (st.world == w1 and st.node == k1)
            end
        end
        st.world, st.node, Run.data.done = keep[1], keep[2], keep[3]
        st.queue = {}
        st.heroX, st.heroY = st:_nodeXY(st.world, st.node)
        check('direccion', #bad == 0 and #away == 0 and #nothing == 0 and chained,
            ('%d paradas, %d vecinas: sin flecha %d %s; con una flecha que no apunta a ella %d %s (la peor apunta %.2f); flechas sin vecina que hacen algo %d %s; se encadena andando=%s'):format(
            stops, tested, #bad, table.concat(bad, ' '), #away, table.concat(away, ' '), worstDot, #nothing, table.concat(nothing, ' '), tostring(chained)))
        top():_move(1); go('in2a')
    elseif step == 'in2a' and t - T > 0.3 and #(st.queue or {}) == 0 then          -- (que llegue al nodo)
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
        OK2 = Run.isDone(W1[2].id) and st.node == 2
        pressNext('back'); go('slots2')
    elseif step == 'slots2' and t - T > 0.4 then
        local s = st.slots and st.slots[1]
        check('partida', OK2 and s and s.done == 2 and not Run.active(),
            ('nivel 2 superado=%s; el hueco 1 dice %s niveles'):format(tostring(OK2), tostring(s and s.done)))
        -- releer del disco, como al reabrir el juego
        package.loaded['src/story/Run'] = nil
        local d = Save.load(1)
        check('guardado', d ~= nil and d.done[W1[1].id] == true and d.done[W1[2].id] == true and d.world == 1 and d.node == 2,
            ('en disco: %s y %s superados, mundo %s nodo %s'):format(tostring(d and d.done[W1[1].id]), tostring(d and d.done[W1[2].id]),
             tostring(d and d.world), tostring(d and d.node)))
        -- todo el mundo 1 superado → se abre el 2
        for _, n in ipairs(W1) do d.done[n.id] = true end
        Save.write(1, d)
        pressNext('confirm'); go('world2')
    elseif step == 'world2' and t - T > 0.4 then
        local open = Run.worldOpen(2)
        local w0 = st.world
        top():_world(1); go('world2b'); OPEN2, W0 = open, w0
    elseif step == 'world2b' and t - T > 0.3 then
        check('mundo2', OPEN2 and st.world == 2 and Run.state(2, 1) == 'open' and Run.state(2, 2) == 'locked',
            ('mundo 1 completo → mundo 2 abierto=%s; ABAJO pasa al mundo %s; su nodo 1 %s, el 2 %s'):format(tostring(OPEN2), tostring(st.world),
             Run.state(2, 1), Run.state(2, 2)))
        shot('map_w2')
        -- GAME OVER en el mundo 2: con su nivel 1 superado, entra en el 2, sale por la pausa con una vida
        -- menos (se guarda), vuelve a entrar y se queda sin vidas
        local W2 = Worlds.nodes(2)
        Run.data.done[W2[1].id] = true; Run.save()
        top():_move(1); go('go1')
    elseif step == 'go1' and t - T > 0.3 and #(st.queue or {}) == 0 then           -- (que llegue al nodo)
        pressNext('confirm'); go('go2')
    elseif step == 'go2' and t - T > 0.6 then
        -- pierde una vida y coge DOS vidas extra: saliendo a medias cuenta la perdida y no las ganadas
        st.player.lives = st.player.lives - 1 + 2
        st.stats.deaths = st.stats.deaths + 1
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
        -- (Xtra extremo: desde 0.5.26 vuelve al principio del MUNDO, como las demás — antes, todo el juego —)
        local wiped = back == 2 and Run.data.done[W1[1].id] == true and not Run.data.done[W2[1].id] and Run.data.lives == 6
        Save.delete(3)
        Run.slot, Run.data = keepSlot, keepData
        check('extremos', Save.new('easy').lives == 3 and Save.new('hard').lives == 3 and s4 == 4 and s6 == 6 and wiped,
            ('vidas al empezar: fácil %d, difícil %d, extremo %d, xtra %d; Game Over en Xtra: al principio del mundo (el 1 sigue hecho)=%s'):format(
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
        -- REPETIR un nivel (granjas): a la partida solo suman los puntos que superan el récord del nivel; las vidas
        -- extra que ya se cogieron se apuntan y la próxima vez solo dan puntos
        do
            Run.slot, Run.data = 3, Save.new('normal')
            local id = W1[1].id
            local base = { time = 30, width = 100, lives = 3, deaths = 0, hits = 0, kills = 0, killable = 0, stars = 0, starsTotal = 0 }
            local function play(score, taken)
                local r = {}
                for k, v in pairs(base) do r[k] = v end
                r.score, r.taken = score, taken
                local p0 = Run.data.points
                local sm = Run.complete(id, r)
                return Run.data.points - p0, sm
            end
            local g1, s1 = play(100, { 4 })
            local g2 = play(60, {})
            local g3, s3 = play(150, {})
            local tk = Run.data.taken[id] and Run.data.taken[id][4]
            local Interactions = require 'src/world/entities/base/Interactions'
            local pkNew = Interactions.pickupEffect({}, { lives = 1 }, { taken = false })
            local pkOld = Interactions.pickupEffect({}, { lives = 1 }, { taken = true })
            Save.delete(3)
            Run.slot, Run.data = keepSlot, keepData
            -- la PRIMERA vez no hay récord que batir: ni "nueva mejor nota" ni "lo que supera tu récord" (antes salía
            -- "nueva mejor nota" en el primer nivel de una partida nueva, como si viniera de otra)
            local firstClean = s1.record == false and s1.gain == s1.points
            check('repetir', g1 == 100 and g2 == 0 and g3 == 50 and s3.gain == 50 and tk == true and pkNew.lives == 1
                and pkOld.lives == nil and (pkOld.score or 0) > 0 and firstClean,
                ('puntos sumados: 1ª vez 100 → +%d (sin récord previo=%s); peor (60) → +%d; mejor (150) → +%d; vida extra cogida apuntada=%s; ya cogida da vida=%s, puntos=%s'):format(
                 g1, tostring(firstClean), g2, g3, tostring(tk), tostring(pkOld.lives), tostring(pkOld.score)))
        end
        -- DESBLOQUEOS: acabar el juego (jefe del último mundo) en Difícil abre Extremo; en Extremo, Xtra; una vez
        local keepSlot, keepData = Run.slot, Run.data
        local lastW = Worlds.nodes(Worlds.count())
        local lastBoss = lastW[#lastW].id
        local function finish(diff)
            Run.slot, Run.data = 3, Save.new(diff)
            for w = 1, Worlds.count() do for _, n in ipairs(Worlds.nodes(w)) do Run.data.done[n.id] = true end end
            Run.data.done[lastBoss] = nil
            return Run.complete(lastBoss, { score = 10, time = 60, width = 100, lives = 3 })
        end
        local before = Save.global().unlocked.extreme
        local u1 = finish('normal').unlocked
        local u2 = finish('hard').unlocked
        local u3 = finish('hard').unlocked
        local u4 = finish('extreme').unlocked
        local g = Save.global()
        Save.delete(3)
        pcall(love.filesystem.remove, 'story.sav'); pcall(love.filesystem.remove, 'story.sav.bak')
        Run.slot, Run.data = keepSlot, keepData
        check('desbloqueo', not before and u1 == nil and u2 == 'extreme' and u3 == nil and u4 == 'xtra' and g.unlocked.extreme and g.unlocked.xtra,
            ('acabar el juego en Normal desbloquea=%s; en Difícil=%s (otra vez=%s); en Extremo=%s; guardado global: extremo=%s xtra=%s'):format(
             tostring(u1), tostring(u2), tostring(u3), tostring(u4), tostring(g.unlocked.extreme), tostring(g.unlocked.xtra)))
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
            -- BONUS (arena contra el bot): cerrado sin vencer al jefe; abierto con él; se juega, se gana y da premio una vez
            local lockedB = Run.bonusState(Worlds.count())
            local openB = Run.bonusState(1)
            LIVES_B = Run.data.lives
            BON1 = lockedB == 'locked' and openB == 'open'
            gStateMachine:change('story_map', { world = 1, node = #Worlds.nodes(1) + 1 }); go('bonus1')
        else
            gStateMachine:change('story_map', { world = TOUR, node = 1 }); go('tour2')
        end
    elseif step == 'tour2' and t - T > 0.6 then
        shot('world_' .. TOUR)
        -- la música del mapa: el arreglo de ESA isla (tools/music/worldmap_nes.py)
        local name = Sound.musicPosition()
        local want = 'map_' .. Worlds.get(TOUR).id
        MUSIC_OK = (MUSIC_OK ~= false) and (name == want)
        if name ~= want then print(('  (isla %d: suena %s, tocaba %s)'):format(TOUR, tostring(name), want)) end
        if TOUR == Worlds.count() then
            check('musica', MUSIC_OK, 'cada isla del mapa suena con su arreglo de "Rumbo a las islas": ' .. tostring(MUSIC_OK))
        end
        -- el MAPA ENTERO en una imagen (2688x2016, con la jungla PRÓXIMAMENTE), para revisarlo: story_map_full.png
        if TOUR == Worlds.count() then
            top():renderFull():encode('png', 'story_map_full.png')
            top().showBosses = true                       -- (otra vez con los jefes junto a sus castillos: sus pinzas, la corona)
            top():renderFull():encode('png', 'story_map_bosses.png')
            top().showBosses = nil
        end
        go('tour')
    elseif step == 'bonus1' and t - T > 0.5 then
        shot('bonus_node')
        pressNext('confirm'); go('bonus2')
    elseif step == 'bonus2' and t - T > 2.5 then
        local b = st.bonus
        BON2 = b ~= nil and b.bot ~= nil and st.levelPath == Worlds.path(Worlds.bonus(1).id) and st.player.lives == 99 and #b.bots == 1 and b.time == 60
        BOTX0 = b and b.bot.pa.x
        go('bonus3')
    elseif step == 'bonus3' and (t - T > 30 or (st.bonus and st.bonus.botScore > 0 and t - T > 6)) then
        local b = st.bonus
        -- (en el JUEGO DE VERDAD, con su dt variable: el bot llega a la zona y puntúa)
        BON3 = b and math.abs(b.bot.pa.x - BOTX0) > 64 and b.botScore > 0
        print(('  (bot: %d puntos a los %.0f s)'):format(b.botScore, t - T))
        shot('bonus_match')
        st.score = b.botScore + 40
        b.t = b.time - 0.2                                      -- (se acaba el tiempo, ganando)
        go('bonus4')
    elseif step == 'bonus4' and t - T > 1.0 then
        -- (terminado el bonus el jugador queda CONGELADO: sin control e invulnerable)
        BON4 = st.bonus and st.bonus.over and st.player.frozen == true and st.player:isInvulnerable()
        shot('bonus_end')
        go('bonus5')
    elseif step == 'bonus5' and t - T > 3.5 then
        local id = Worlds.bonus(1).id
        local d = Run.data.bonus[id]
        -- ahora sale la pantalla de RESULTADOS (la de los niveles, con las líneas del bonus) y de ahí se vuelve al mapa
        local sum = st.args and st.args.summary
        local RES = sum ~= nil and st.rows ~= nil and #st.rows == 4 and sum.won == true and #sum.rewards >= 1 and sum.points > 0
        local gain = 0
        for _, rw in ipairs(sum and sum.rewards or {}) do gain = gain + (rw.lives or 0) end
        local again = Run.bonusResult(id, { won = true, score = 1, botScore = 50 })
        local lost = Run.bonusResult(id, { won = false, score = 1000, botScore = 1 })
        BONUS_OK = BON1 and BON2 and BON3 and BON4 and RES and d and d.won and gain >= 1
            and Run.data.lives == LIVES_B + gain and Run.bonusState(1) == 'done' and #again.rewards == 0 and lost.grade == 'D' and lost.points == 0
        BONUS_MSG = ('cerrado sin jefe / abierto con jefe=%s; partida con bot y vidas aparte=%s; el bot llega a la zona y puntúa=%s; al acabar el jugador queda congelado=%s; RESULTADOS con 4 líneas=%s, nota %s (%s/100), %s puntos, premios %d; ganar: bonus %s, vidas %s → %s; repetir con peor nota: premios=%d; perder: nota %s'):format(
             tostring(BON1), tostring(BON2), tostring(BON3), tostring(BON4), tostring(RES), tostring(sum and sum.grade), tostring(sum and sum.rating), tostring(sum and sum.points),
             sum and #sum.rewards or -1, Run.bonusState(1), tostring(LIVES_B), tostring(Run.data.lives), #again.rewards, lost.grade)
        st.t = st.tEnd or 99
        shot('bonus_results')
        pressNext('confirm'); go('bonus5b')
    elseif step == 'bonus5b' and t - T > 0.3 then
        go('bonus5c')                                    -- (la animación ya estaba al final: un toque vuelve al mapa)
    elseif step == 'bonus5c' and t - T > 0.5 then
        local id = Worlds.bonus(1).id
        check('bonus', BONUS_OK and st.world == 1 and st.node == #Worlds.nodes(1) + 1, BONUS_MSG .. ('; de vuelta al mapa en el nodo %s'):format(tostring(st.node)))
        shot('bonus_won')
        Run.data.done = KEEP; Run.data.bonus = {}; Run.data.lives = LIVES_B; Run.save()
        -- Xtra extremo: DOS bots, y más hostiles que en Fácil
        gStateMachine:change('adventure', { level = Worlds.path(id), returnTo = 'story_map', difficulty = 'xtra', bonus = {} }); go('bonusx')
    elseif step == 'bonusx' and t - T > 3 then
        local b = st.bonus
        local cdX = b.bots[1].attackCd
        gStateMachine:change('adventure', { level = st.levelPath, returnTo = 'story_map', difficulty = 'easy', bonus = {} })
        local e = top().bonus
        check('bonus_dif', #b.bots == 2 and #e.bots == 1 and cdX < e.bots[1].attackCd and b.bots[1].chaseR > e.bots[1].chaseR,
            ('Xtra extremo: %d bots, descanso %.2f s, persigue a %d casillas; Fácil: %d bot, descanso %.2f s, a %d casillas'):format(
             #b.bots, cdX, b.bots[1].chaseR, #e.bots, e.bots[1].attackCd, e.bots[1].chaseR))
        shot('bonus_xtra')
        go('sh0')
    -- ── FRAGMENTOS DEL ESPEJO: el jefe suelta el suyo, se recoge y queda guardado; con el último, el final ──
    elseif step == 'sh0' and t - T > 0.2 then
        local d = Run.data
        d.difficulty, d.done, d.shards, d.lives = 'normal', {}, {}, 5
        for k = 1, #W1 - 1 do d.done[W1[k].id] = true end
        Run.save()
        gStateMachine:change('story_map', { world = 1, node = #W1 }); go('sh1')
    elseif step == 'sh1' and t - T > 0.5 then
        pressNext('confirm'); go('sh2')
    elseif (step == 'sh2' or step == 'fin2') and t - T > 0.8 then
        -- al centro de la arena: empieza la pelea
        local z = st.level.bossZones[1]
        st.player.x, st.player.y = require('src/world/systems/BossZones').safeSpawn(st.level, z)
        st.player.spawnX, st.player.spawnY = st.player.x, st.player.y
        SHIDS = st.shards and table.concat(st.shards.ids, ',') or 'ninguno'
        go(step == 'sh2' and 'sh3' or 'fin3')
    elseif (step == 'sh3' or step == 'fin3') and (st.level.bossZones[1].state == 'fight' or t - T > 25) then
        for _, e in ipairs(st.enemies) do if e.def.category == 'Jefes' then e:defeat() end end
        st.player:grantInvulnerability(60)
        go(step == 'sh3' and 'sh4' or 'fin4')
    elseif (step == 'sh4' or step == 'fin4') and ((st.shards and #st.shards.list > 0 and st.shards.list[1].t > 0.9) or t - T > 25) then
        local s1 = st.shards and st.shards.list[1]
        DROPPED = s1 ~= nil
        if s1 then shot(step == 'sh4' and 'shard_drop' or 'shard_final'); st.player.x, st.player.y, st.player.vx, st.player.vy = s1.x, s1.y, 0, 0 end
        go(step == 'sh4' and 'sh5' or 'fin5')
    elseif step == 'sh5' and t - T > 0.4 then
        local disk = Save.load(1)
        local have, total = Run.shards()
        -- (recogido, pero el nivel SIN terminar: aún no está en la partida ni en disco; se apunta al acabarlo)
        local held = st.shards and st.shards.got == 1
        check('fragmento', SHIDS == '1' and DROPPED and held and Run.data.shards['1'] == nil and disk.shards['1'] == nil and have == 0 and total == require('src/story/Shards').TOTAL and not st.endingT,
            ('el jefe del mundo 1 guarda el %s; lo suelta=%s; sin terminar el nivel: en la partida=%s, en disco=%s; cuenta %d/%d'):format(
             SHIDS, tostring(DROPPED), tostring(Run.data.shards['1']), tostring(disk.shards['1']), have, total))
        go('sh6')
    elseif step == 'sh6' and ((st.args and st.args.summary ~= nil) or t - T > 10) then
        -- (en la historia el nivel de jefe TERMINA SOLO al vencer al jefe y recoger su fragmento: sin tocar la meta)
        check('jefe_solo', st.args ~= nil and st.args.summary ~= nil and Run.isDone(W1[#W1].id) and Run.data.shards['1'] == true,
            ('vencido el jefe y recogido el fragmento, sin ir a la meta: resultados=%s, nivel superado=%s, fragmento guardado=%s'):format(
             tostring(st.args ~= nil and st.args.summary ~= nil), tostring(Run.isDone(W1[#W1].id)), tostring(Run.data.shards['1'])))
        -- el Escarabajo Gigante (la jungla, mundo 3) suelta el SUYO (el 8: assets/story/shards.json) y queda guardado
        local d = Run.data
        local WJ = Worlds.nodes(3)
        for w = 1, 2 do for _, n in ipairs(Worlds.nodes(w)) do d.done[n.id] = true end end
        for k = 1, #WJ - 1 do d.done[WJ[k].id] = true end
        Run.save()
        gStateMachine:change('story_map', { world = 3, node = #WJ }); go('jb1')
    elseif step == 'jb1' and t - T > 0.5 then
        pressNext('confirm'); go('jb2')
    elseif step == 'jb2' and st.level and t - T > 0.8 then
        local z = st.level.bossZones[1]
        st.player.x, st.player.y = require('src/world/systems/BossZones').safeSpawn(st.level, z)
        st.player.spawnX, st.player.spawnY = st.player.x, st.player.y
        JB = { ids = st.shards and table.concat(st.shards.ids, ',') or 'ninguno', level = st.levelPath }
        go('jb3')
    elseif step == 'jb3' and (st.level.bossZones[1].state == 'fight' or t - T > 25) then
        for _, e in ipairs(st.enemies) do if e.def.category == 'Jefes' then e:defeat() end end
        st.player:grantInvulnerability(60)
        go('jb4')
    elseif step == 'jb4' and ((st.shards and #st.shards.list > 0 and st.shards.list[1].t > 0.9) or t - T > 25) then
        local s1 = st.shards and st.shards.list[1]
        JB.dropped = s1 ~= nil
        if s1 then shot('shard_beetle'); st.player.x, st.player.y, st.player.vx, st.player.vy = s1.x, s1.y, 0, 0 end
        go('jb5')
    elseif step == 'jb5' and ((st.args and st.args.summary ~= nil) or t - T > 12) then
        local have = Run.shards()
        check('fragmento_jungla', JB.ids == '8' and JB.level == Worlds.path('templo_escarabajo') and JB.dropped and Run.isDone('templo_escarabajo')
            and Run.data.shards['8'] == true and Save.load(1).shards['8'] == true and have == 2,
            ('jefe de la jungla (%s): guarda %s; lo suelta=%s; nivel superado=%s; fragmento 8 en la partida=%s, en disco=%s; cuenta %d'):format(
             tostring(JB.level), JB.ids, tostring(JB.dropped), tostring(Run.isDone('templo_escarabajo')), tostring(Run.data.shards['8']),
             tostring(Save.load(1).shards['8']), have))
        go('fin0')
    elseif step == 'fin0' and t - T > 0.3 then
        -- ahora, el último: todo superado menos el jefe Espejo, con todos los demás fragmentos
        local d = Run.data
        for w = 1, Worlds.count() do for _, n in ipairs(Worlds.nodes(w)) do d.done[n.id] = true end end
        local last = Worlds.nodes(Worlds.count())
        d.done[last[#last].id] = nil
        local SH = require 'src/story/Shards'
        for _, n in ipairs(SH.ORDER) do if n ~= SH.FINAL then d.shards[tostring(n)] = true end end
        Run.save()
        FILMS = {}
        gStateMachine:change('story_map', { world = Worlds.count(), node = #last }); go('fin1')
    elseif step == 'fin1' and t - T > 0.6 then
        shot('map_shards'); pressNext('confirm'); go('fin2')
    elseif step == 'fin5' and t - T > 0.4 then
        ENDING = st.endingT ~= nil and st.player.forceFrozen == true
        -- (nivel de jefe en la historia: sin meta)
        NOFINISH = true
        for r = 1, st.level.tileH do
            for c = 1, st.level.tileW do if st.level:getDef(c, r).trigger == 'finish' then NOFINISH = false end end
        end
        go('fin6')
    elseif step == 'fin6' and ((st.args and st.args.summary ~= nil) or t - T > 12) then
        local have, total = Run.shards()
        local last = Worlds.nodes(Worlds.count())
        -- (antes del nivel, la primera vez, su película — Worlds films: 'lair' —, apuntada como vista; y con el último
        -- fragmento, el final)
        check('final', SHIDS == tostring(require('src/story/Shards').FINAL) and DROPPED and ENDING and NOFINISH and FILMS[1] == 'lair' and FILMS[2] == 'ending' and Run.data.films.lair == true
            and st.args and st.args.summary ~= nil and Run.isDone(last[#last].id) and have == total,
            ('el Espejo guarda el %s; lo suelta=%s; al recogerlo se queda quieto y a blanco=%s; sin meta=%s; películas=%s (vista=%s); luego resultados=%s; nivel superado=%s sin tocar la meta; %d/%d'):format(
             SHIDS, tostring(DROPPED), tostring(ENDING), tostring(NOFINISH), table.concat(FILMS, ','), tostring(Run.data.films.lair), tostring(st.args ~= nil and st.args.summary ~= nil), tostring(Run.isDone(last[#last].id)), have, total))
        -- partida antigua (sin fragmentos): los de los jefes ya vencidos se dan por recogidos
        local old = { difficulty = 'xtra', done = { reino_gummy = true, lago_helado = true } }
        require('src/story/Shards').migrate(old)
        local n = 0
        for _ in pairs(old.shards) do n = n + 1 end
        -- (y una de Xtra con las MITADES de cuando había dos jefes por arena — hasta 0.5.23 —: cada mitad, el entero)
        local halves = { difficulty = 'xtra', shards = { ['1a'] = true, ['1b'] = true, ['3a'] = true } }
        require('src/story/Shards').migrate(halves)
        local h = 0
        for _ in pairs(halves.shards) do h = h + 1 end
        check('migrar', n == 2 and old.shards['1'] and old.shards['4'] and h == 2 and halves.shards['1'] and halves.shards['3'],
            ('partida antigua en Xtra con 2 jefes vencidos: %d fragmentos; con mitades 1a, 1b, 3a: %d fragmentos (1=%s, 3=%s)'):format(
             n, h, tostring(halves.shards['1']), tostring(halves.shards['3'])))
        -- partida de ANTES de la jungla (versión 1: 6 mundos) que ya estaba en la Fortaleza (su mundo 3) con la nota del
        -- mundo 2: el mundo pasa al 4, la nota sigue en la Costa, la jungla (3) se abre y la Fortaleza (4) sigue abierta;
        -- otra que solo había pasado la Pradera: nada abierto de más
        local v1 = { version = 1, difficulty = 'normal', world = 3, node = 2, worldReward = { [2] = 'A' }, open = {},
                     done = { reino_gummy = true, cala_resaca = true, fabrica_morteros = true } }
        require('src/story/Save').migrate(v1)
        local v1b = { version = 1, world = 1, worldReward = {}, open = {}, done = { reino_gummy = true } }
        require('src/story/Save').migrate(v1b)
        -- (versión 2: la isla helada partida en dos en la 3 — Montañas Heladas con la Bola de Nieve, Costa Helada con el
        --  Mega Crabby helado —): una que había vencido a la Bola de Nieve pero no al Crabby helado tiene abierta la
        --  Costa Helada y NO las Cuevas; otra que ya había vencido al Crabby helado, las Cuevas abiertas)
        local S = require 'src/story/Save'
        local all = function(list) local t = {} for _, id in ipairs(list) do t[id] = true end return t end
        local v2a = { version = 2, world = 5, worldReward = {}, open = {},
                      done = all({ 'reino_gummy', 'cala_resaca', 'templo_escarabajo', 'fortaleza_malvada', 'cumbres_escarcha', 'fabrica_criogenica', 'lago_helado' }) }
        local v2b = { version = 2, world = 6, worldReward = { [5] = 'B' }, open = {},
                      done = all({ 'reino_gummy', 'cala_resaca', 'templo_escarabajo', 'fortaleza_malvada', 'cumbres_escarcha', 'fabrica_criogenica', 'lago_helado', 'torre_viento', 'glaciar_cangrejo' }) }
        S.migrate(v2a); S.migrate(v2b)
        local function opens(d) local keep = Run.data; Run.data = d; local o = {} for w = 1, Worlds.count() do o[w] = Run.worldOpen(w) end Run.data = keep; return o end
        local o1, oa, ob = opens(v1), opens(v2a), opens(v2b)
        local CH, CU = 6, 7
        check('migrar_mundos', v1.version == S.VERSION and v1.world == 4 and v1.worldReward[2] == 'A' and v1.worldReward[3] == nil
            and Worlds.get(3).id == 'jungla' and o1[3] and o1[4] and not o1[5] and next(v1b.open) == nil
            and Worlds.get(CH).id == 'costa_helada' and oa[CH] and not oa[CU] and ob[CH] and ob[CU] and ob[CU + 1] == false and v2b.world == 7 and v2b.worldReward[5] == 'B',
            ('versión 1 en la Fortaleza: mundo %s, jungla=%s, Fortaleza=%s, Montañas=%s; en la Pradera: abiertos de más=%s · versión 2 con la Bola vencida: Costa Helada=%s, Cuevas=%s · con el Crabby helado vencido: Costa Helada=%s, Cuevas=%s, Final=%s, mundo %s'):format(
             tostring(v1.world), tostring(o1[3]), tostring(o1[4]), tostring(o1[5]), tostring(next(v1b.open)), tostring(oa[CH]), tostring(oa[CU]),
             tostring(ob[CH]), tostring(ob[CU]), tostring(ob[CU + 1]), tostring(v2b.world)))
        gStateMachine:change('story_map', { world = 1, node = 1 }); go('walk0')
    -- ── MAPA: pulsar ENTRAR mientras el monstruo aún anda hacia el nodo: entra al LLEGAR, no antes ──
    elseif step == 'walk0' and t - T > 0.4 then
        st:_move(1); pressNext('confirm'); go('walk1')
    elseif step == 'walk1' and t - T > 0.12 then
        WALK1 = { map = st.queue ~= nil, walking = st.queue and #st.queue > 0, pending = st.playOnArrive == true }
        go('walk2')
    elseif step == 'walk2' and (st.level or t - T > 6) then
        check('andando', WALK1.map and WALK1.walking and WALK1.pending and st.level ~= nil and st.levelPath == Worlds.path(Worlds.nodes(1)[2].id),
            ('ENTRAR a medio camino: sigue en el mapa=%s (andando=%s, entrará al llegar=%s); luego entra en %s'):format(
             tostring(WALK1.map), tostring(WALK1.walking), tostring(WALK1.pending), tostring(st.levelPath)))
        -- ── LA HUIDA DEL ESPEJO enlaza con el jefe: escena dentro del nivel, la película de la guarida y el nivel ──
        local d = Run.data
        d.done.huida_del_espejo, d.done.ruta_del_espejo, d.films = nil, nil, {}
        Run.save()
        FILMS = {}
        gStateMachine:change('story_map', { world = Worlds.count(), node = 4 }); go('run0')
    elseif step == 'run0' and t - T > 0.4 then
        pressNext('confirm'); go('run1')
    elseif step == 'run1' and st.level and t - T > 0.6 then
        -- (adelanta la carrera: la cámara justo antes de la escena final, el jugador dentro de ella)
        local a = st.level.autoScroll
        local finish = 0
        for r = 1, st.level.tileH do for c = 1, st.level.tileW do if st.level:getDef(c, r).trigger == 'finish' then finish = finish + 1 end end end
        RUN = { finish = finish, film1 = FILMS[1] }
        a.state, a.x = 'run', (Worlds.outro('huida_del_espejo').col - 1) * TILE_PX - 40
        st.player.x, st.player.y, st.player.vx, st.player.vy = a.x + 500, st.player.y, 0, 0
        -- (el peor caso: el Espejo DELANTE del jugador cuando empieza la escena — tiene que acabar detrás)
        for _, e in ipairs(st.enemies or {}) do if e.def.name == 'mirrorchase' then e.x = a.x + 900 end end
        go('run2')
    elseif step == 'run2' and t - T > 1.2 then
        local chase
        for _, e in ipairs(st.enemies or {}) do if e.def.name == 'mirrorchase' then chase = e end end
        RUN.active = st.runOut and st.runOut.active
        RUN.cinema = st.level.cinema == true
        RUN.chase = chase and chase.state
        RUN.seen = chase and chase.x > st.camX - 40 and chase.x < st.camX + WINDOW_W
        RUN.behind = chase and chase.x < st.player.x
        RUN.moved = st.player.x - (st.level.autoScroll.x + 500)
        RUN.cam0 = st.camX
        shot('outro')
        go('run3')
    elseif step == 'run3' and st.runOut and st.runOut.fadeT and not RUN.camEnd then
        -- (al empezar el fundido: la cámara no se ha movido y el monstruo sigue corriendo, lejos de la pared del final)
        RUN.camEnd, RUN.vx, RUN.px = st.camX, st.player.vx, st.player.x
        RUN.vol0 = Sound.musicVolume()
        RUN.wall = (st.level.tileW - 1) * TILE_PX
    elseif step == 'run3' and RUN.camEnd and not RUN.vol1 and st.runOut and st.runOut.fadeT and st.runOut.fadeT > 0.5 then
        RUN.vol1 = Sound.musicVolume()                        -- (la música se apaga con el fundido)
    elseif step == 'run3' and (FILMS[2] or t - T > 15) then
        go('run4')
    elseif step == 'run4' and (st.level or t - T > 3) then
        check('enlace', RUN.film1 == 'chase' and RUN.finish == 0 and RUN.active and RUN.cinema and RUN.chase == 'outro' and RUN.seen and RUN.behind and RUN.moved > 150
            and RUN.camEnd == RUN.cam0 and (RUN.vol1 or 1) < (RUN.vol0 or 0) * 0.4 and (RUN.vx or 0) > 100 and (RUN.px or 1e9) < RUN.wall - 2 * TILE_PX
            and FILMS[2] == 'lair' and st.levelPath == Worlds.path('ruta_del_espejo') and Run.isDone('huida_del_espejo')
            and Run.data.node == 5,
            ('película antes=%s; sin meta=%s; escena final=%s, franjas=%s, el Espejo=%s (en cuadro=%s, detrás del monstruo aunque empezó delante=%s), corre solo %.0f px; la cámara quieta=%s; la música con el fundido %.2f → %.2f; al fundirse a negro sigue corriendo (%.0f px/s) a %.0f px de la pared del final; después la película %s y el nivel %s; huida superada=%s; la partida en el nodo %s'):format(
             tostring(RUN.film1), tostring(RUN.finish == 0), tostring(RUN.active), tostring(RUN.cinema), tostring(RUN.chase), tostring(RUN.seen), tostring(RUN.behind), RUN.moved or 0, tostring(RUN.camEnd == RUN.cam0), RUN.vol0 or -1, RUN.vol1 or -1, RUN.vx or 0, (RUN.wall or 0) - (RUN.px or 0),
             tostring(FILMS[2]), tostring(st.levelPath), tostring(Run.isDone('huida_del_espejo')), tostring(Run.data.node)))
        gStateMachine:change('story_map', { world = 1, node = 1 }); go('sec1')
    -- LOS SECRETOS (Worlds `secrets`). El GROOVE: sin vencer al Espejo, o sin TODAS las astillas (las de tipo 'splinter'
    -- de assets/story/collectibles.json, en cualquier estado: también 'stolen'), ni se ve ni es una parada ni le lleva
    -- una flecha; con las dos cosas aparece (un ramal desde el bonus del Final) y se juega su nivel. El MEGA MASHUP
    -- cuelga del Groove: escondido hasta vencerlo
    elseif step == 'sec1' and t - T > 0.3 then
        local w = Worlds.count()
        local keep = {}
        for k, v in pairs(Run.data.done) do keep[k] = v end
        SEC = { keepDone = keep }
        Run.data.done[Worlds.get(w).boss] = nil
        Run.data.collect, Run.data.found = { astilla_crabby = true, astilla_gloomy = true }, {}
        gStateMachine:change('story_map', { world = w, node = #Worlds.nodes(w) + 1 }); go('sec2')
    elseif step == 'sec2' and t - T > 0.3 then
        local w = Worlds.count()
        SEC.gk, SEC.mk = #Worlds.nodes(w) + 2, #Worlds.nodes(w) + 3          -- (el bonus, el Groove, el Mashup)
        local function hidden(k)                     -- (ni parada que se vea, ni flecha desde el nodo del que sale)
            local total, all = st:_stops()
            local stop = st:_stopOf(w, k)
            for _, i in pairs(st:_dirs(w, k - 1)) do if i == stop then return false end end
            return Run.secretState(mapNode(w, k).id) == 'locked' and total < all
        end
        SEC.noMirror = hidden(SEC.gk)
        Run.data.done[Worlds.get(w).boss] = true
        Run.data.collect = { astilla_crabby = true }
        SEC.noSplinter = hidden(SEC.gk)
        SEC.mashHidden = hidden(SEC.mk)
        -- con las dos: EL ROBO (escena del mapa, StoryMapScenes 'groove') se pone sola; hasta que acaba (o se salta), el
        -- Groove sigue cerrado; después las astillas quedan robadas ('stolen') y su isla, abierta
        Run.data.collect = { astilla_crabby = true, astilla_gloomy = true }
        Run.data.films.groove, Run.data.films.regrow, Run.data.films.disco = nil, nil, nil
        gStateMachine:change('story_map', { world = w, node = #Worlds.nodes(w) + 1 }); go('sec2b')
    elseif step == 'sec2b' and ((st._sceneNow and st:_sceneNow() == 'groove' and select(2, st:_sceneNow()) > 3.2) or t - T > 10) then
        SEC.scene = st._sceneNow and st:_sceneNow() == 'groove'
        SEC.lockedDuring = Run.secretState('isla_del_groove') == 'locked'
        shot('scene_groove')
        pressNext('confirm'); go('sec3')                                    -- (se salta: su efecto se aplica igual)
    elseif step == 'sec3' and t - T > 2.2 then
        local w = Worlds.count()
        SEC.open = Run.secretState('isla_del_groove') == 'open' and mapNode(w, SEC.gk).id == 'isla_del_groove'
        SEC.stolen = Run.data.collect.astilla_crabby == 'stolen' and Run.data.collect.astilla_gloomy == 'stolen' and Run.data.films.groove == true
                     and Save.load(1).collect.astilla_crabby == 'stolen'
        shot('map_secret')
        st:_walkTo(st:_stopOf(w, SEC.gk)); go('sec4')
    elseif step == 'sec4' and #st.queue == 0 and t - T > 0.3 then
        SEC.there = st.node == SEC.gk
        st:_play(); go('sec5')
    elseif step == 'sec5' and (st.level or t - T > 6) then
        if st.startCd then CD_DONE = true end
        check('secreto', SEC.noMirror and SEC.noSplinter and SEC.scene and SEC.lockedDuring and SEC.open and SEC.stolen and SEC.there and st.levelPath == Worlds.path('isla_del_groove'),
            ('sin vencer al Espejo, escondido=%s; vencido pero sin todas las astillas, escondido=%s; con las dos, la escena del robo=%s (cerrado mientras=%s); después abierto=%s, astillas robadas y guardado=%s; anda hasta él=%s; entra en %s'):format(
             tostring(SEC.noMirror), tostring(SEC.noSplinter), tostring(SEC.scene), tostring(SEC.lockedDuring), tostring(SEC.open), tostring(SEC.stolen), tostring(SEC.there), tostring(st.levelPath)))
        -- el Groove vencido: se abre el MEGA MASHUP, se entra y, terminado (en su salida: es un EVENTO y conserva su meta),
        -- da la BOLA DE DISCOTECA, guardada al acabar
        -- (al volver, la escena de los tres que CRECEN otra vez: StoryMapScenes 'regrow'; luego se abre el Mashup)
        Run.data.done.isla_del_groove = true
        Run.save()
        gStateMachine:change('story_map', { world = Worlds.count(), node = SEC.gk }); go('mash0')
    elseif step == 'mash0' and not SEC.shotSmall and st._sceneNow and st:_sceneNow() == 'regrow' and select(2, st:_sceneNow()) > 0.6 then
        SEC.shotSmall = true; shot('scene_regrow_pequenos')              -- (los tres aún pequeños: su tamaño y sus pinzas)
    elseif step == 'mash0' and ((st._sceneNow and st:_sceneNow() == 'regrow' and select(2, st:_sceneNow()) > 4.7) or t - T > 10) then
        SEC.regrow = st._sceneNow and st:_sceneNow() == 'regrow' and Run.secretState('mashup_cangrejos') == 'locked'
        shot('scene_regrow')
        pressNext('confirm'); go('mash1')
    elseif step == 'mash1' and t - T > 2.2 then
        SEC.mashOpen = Run.secretState('mashup_cangrejos') == 'open'
        st:_walkTo(st:_stopOf(Worlds.count(), SEC.mk)); go('mash2')
    elseif step == 'mash2' and #st.queue == 0 and t - T > 0.3 then
        SEC.mashThere = st.node == SEC.mk
        shot('map_mashup')
        st:_play(); go('mash3')
    elseif step == 'mash3' and st.level and t - T > 1.0 then
        local fin = 0
        for r = 1, st.level.tileH do for c = 1, st.level.tileW do if st.level:getDef(c, r).trigger == 'finish' then fin = fin + 1 end end end
        SEC.mash = { level = st.levelPath, event = st.level.event, finish = fin }
        toFinish(st); go('mash4')
    elseif step == 'mash4' and t - T > 0.5 and not SEC.mash.notYet then
        SEC.mash.notYet = Run.data.collect.bola_disco == nil and Save.load(1).collect.bola_disco == nil and st.won == true
    elseif step == 'mash4' and ((st.args and st.args.summary ~= nil) or t - T > 12) then
        -- (de los resultados al mapa: EL FINAL DE VERDAD, StoryMapScenes 'disco': las astillas vuelven a sus monturas)
        SEC.mash.results = st.args ~= nil and st.args.summary ~= nil
        gStateMachine:change('story_map', st.args and st.args.map or { world = Worlds.count(), node = SEC.mk }); go('mash5')
    elseif step == 'mash5' and not SEC.shotBig and st._sceneNow and st:_sceneNow() == 'disco' and select(2, st:_sceneNow()) > 0.6 then
        SEC.shotBig = true; shot('scene_disco_grandes')                  -- (antes de romperse la bola: grandes)
    elseif step == 'mash5' and ((st._sceneNow and st:_sceneNow() == 'disco' and select(2, st:_sceneNow()) > 5.8) or t - T > 12) then
        SEC.mash.disco = st._sceneNow and st:_sceneNow() == 'disco'
        shot('scene_disco')
        pressNext('confirm'); go('mash6')
    elseif step == 'mash6' and t - T > 0.5 then
        local M = SEC.mash
        M.back = Run.data.collect.astilla_crabby == true and Run.data.collect.astilla_gloomy == true and Run.data.films.disco == true
        check('mashup', SEC.mashHidden and SEC.mashOpen and SEC.mashThere and M.level == Worlds.path('mashup_cangrejos') and M.event and M.finish > 0
            and M.notYet and Run.data.collect.bola_disco == true and Save.load(1).collect.bola_disco == true and Run.isDone('mashup_cangrejos')
            and SEC.regrow and M.results and M.disco and M.back,
            ('sin vencer al Groove, escondido=%s; vencido, la escena de los tres que crecen (cerrado mientras)=%s; luego abierto=%s; anda hasta él=%s; entra en %s (evento=%s, con meta=%d); en la meta sin terminar, sin bola=%s; terminado: resultados=%s, bola de discoteca en la partida=%s, en disco=%s; en el mapa, el final de verdad=%s y las astillas de vuelta=%s'):format(
             tostring(SEC.mashHidden), tostring(SEC.regrow), tostring(SEC.mashOpen), tostring(SEC.mashThere), tostring(M.level), tostring(M.event), M.finish,
             tostring(M.notYet), tostring(M.results), tostring(Run.data.collect.bola_disco), tostring(Save.load(1).collect.bola_disco), tostring(M.disco), tostring(M.back)))
        -- LA SALIDA SECRETA del Arrecife Globo (Costa): con el nodo secreto ESCONDIDO, se juega el arrecife y se acaba
        -- por su salida secreta (tile `secret_exit`): resultados como siempre y, de vuelta en el mapa, su camino se
        -- dibuja solo y sale el nodo rojo; guardado al TERMINAR el nivel
        local d = Run.data
        d.done, d.collect, d.found = {}, {}, {}
        for _, n in ipairs(Worlds.nodes(1)) do d.done[n.id] = true end
        local W2 = Worlds.nodes(2)
        for k = 1, #W2 - 2 do d.done[W2[k].id] = true end                          -- (hasta el arrecife, abierto)
        Run.save()
        XS = { k = #W2 - 1, gk = #mapNodesOf(2) }
        gStateMachine:change('story_map', { world = 2, node = XS.k }); go('xs1')
    elseif step == 'xs1' and t - T > 0.4 then
        local stop = st:_stopOf(2, XS.gk)
        XS.arrow0 = false
        for _, i in pairs(st:_dirs(2, XS.k)) do if i == stop then XS.arrow0 = true end end
        XS.hidden = Run.secretState('guarida_cangrejo_rey') == 'locked' and mapNode(2, XS.gk).id == 'guarida_cangrejo_rey' and not XS.arrow0
        pressNext('confirm'); go('xs2')
    elseif step == 'xs2' and st.level and t - T > 0.8 then
        XS.level = st.levelPath
        XS.tile = toFinish(st, 'secret_exit')
        go('xs3')
    elseif step == 'xs3' and t - T > 0.5 then
        XS.won = st.won == true and st.secretExit == true
        XS.notYet = Run.data.found.guarida_cangrejo_rey == nil and (Save.load(1).found or {}).guarida_cangrejo_rey == nil
        go('xs4')
    elseif step == 'xs4' and ((st.args and st.args.summary ~= nil) or t - T > 8) then
        XS.results = st.args ~= nil and st.args.summary ~= nil
        XS.saved = Run.data.found.guarida_cangrejo_rey == true and Save.load(1).found.guarida_cangrejo_rey == true and Run.isDone('arrecife_globo')
        local m = st.args and st.args.map or { world = 2, node = XS.k }
        XS.opened = false
        for _, i in ipairs(m.opened or {}) do if i == stopOfMap(2, XS.gk) then XS.opened = true end end
        gStateMachine:change('story_map', m); go('xs5')
    elseif step == 'xs5' and t - T > 0.85 then
        shot('map_secret_path')                       -- (el camino a medio dibujar)
        XS.midNode = st.opening and st.opening[st:_stopOf(2, XS.gk)] and st.t < 1.5
        go('xs6')
    elseif step == 'xs6' and t - T > 1.3 then
        shot('map_secret_open')
        local stop = st:_stopOf(2, XS.gk)
        XS.arrow = false
        for _, i in pairs(st:_dirs(2, XS.k)) do if i == stop then XS.arrow = true end end
        check('salida_secreta', XS.hidden and XS.level == Worlds.path('arrecife_globo') and XS.tile and XS.won and XS.notYet and XS.results
            and XS.saved and XS.opened and XS.midNode and XS.arrow and Run.secretState('guarida_cangrejo_rey') == 'open' and st.node == XS.k,
            ('antes, el nodo secreto escondido (sin flecha)=%s; entra en %s, toca la salida secreta=%s → nivel superado=%s, sin guardar aún=%s; resultados=%s; guardado al terminar=%s; en el mapa se abre a la vista=%s (camino dibujándose=%s), con flecha desde el arrecife=%s; sigue en el nodo %s'):format(
             tostring(XS.hidden), tostring(XS.level), tostring(XS.tile), tostring(XS.won), tostring(XS.notYet), tostring(XS.results),
             tostring(XS.saved), tostring(XS.opened), tostring(XS.midNode), tostring(XS.arrow), tostring(st.node)))
        st:_walkTo(stop); go('ast1')
    -- LA ASTILLA del Mega Crabby: su jefe secreto la SUELTA al caer (la corona: su icono), se recoge, no se guarda
    -- hasta terminar el nivel (que acaba solo al vencerlo); con ella ya en la partida, no la vuelve a soltar
    elseif step == 'ast1' and #st.queue == 0 and t - T > 0.3 then
        AST = { walked = st.node == XS.gk }
        st:_play(); go('ast2')
    elseif step == 'ast2' and st.level and t - T > 0.8 then
        local z = st.level.bossZones[1]
        st.player.x, st.player.y = require('src/world/systems/BossZones').safeSpawn(st.level, z)
        st.player.spawnX, st.player.spawnY = st.player.x, st.player.y
        AST.level = st.levelPath
        AST.items = st.shards and #st.shards.items or 0
        go('ast3')
    elseif step == 'ast3' and (st.level.bossZones[1].state == 'fight' or t - T > 25) then
        for _, e in ipairs(st.enemies) do if e.def.category == 'Jefes' then e:defeat() end end
        st.player:grantInvulnerability(60)
        go('ast4')
    elseif step == 'ast4' and ((st.shards and #st.shards.list > 0 and st.shards.list[1].t > 0.9) or t - T > 25) then
        local s1 = st.shards and st.shards.list[1]
        AST.drop = s1 and s1.collect and s1.id
        if s1 then shot('splinter_drop'); st.player.x, st.player.y, st.player.vx, st.player.vy = s1.x, s1.y, 0, 0 end
        go('ast5')
    elseif step == 'ast5' and t - T > 0.4 then
        AST.held = st.shards and st.shards.cgot == 1
        AST.notYet = Run.data.collect.astilla_crabby == nil and (Save.load(1).collect or {}).astilla_crabby == nil
        go('ast6')
    elseif step == 'ast6' and ((st.args and st.args.summary ~= nil) or t - T > 12) then
        local Collect = require 'src/story/Collect'
        local again = #Collect.drops('guarida_cangrejo_rey', Run.data)
        check('astilla', AST.walked and AST.level == Worlds.path('guarida_cangrejo_rey') and AST.items == 1 and AST.drop == 'astilla_crabby'
            and AST.held and AST.notYet and st.args ~= nil and st.args.summary ~= nil and Run.data.collect.astilla_crabby == true
            and Save.load(1).collect.astilla_crabby == true and again == 0,
            ('anda al nodo secreto=%s; entra en %s (%d coleccionable por soltar); el jefe suelta %s, recogida=%s, sin guardar aún=%s; el nivel acaba solo (resultados=%s); guardada=%s (disco %s); con ella, la vuelve a soltar %d'):format(
             tostring(AST.walked), tostring(AST.level), AST.items, tostring(AST.drop), tostring(AST.held), tostring(AST.notYet),
             tostring(st.args ~= nil and st.args.summary ~= nil), tostring(Run.data.collect.astilla_crabby), tostring(Save.load(1).collect.astilla_crabby), again))
        -- partidas de ANTES de los secretos (versión 3): llegan a la 4 sin coleccionables ni salidas encontradas, y quien
        -- ya había jugado la guarida del Mega Crabby fuera de la historia (o cuando era el jefe de la Costa) no se lleva nada
        local S = require 'src/story/Save'
        local v3 = { version = 3, world = 2, worldReward = {}, open = {}, done = { reino_gummy = true, guarida_cangrejo_rey = true, gruta_lugubre = true, arrecife_globo = true } }
        S.migrate(v3)
        local function empty(tb) return type(tb) == 'table' and next(tb) == nil end
        check('migrar_secretos', v3.version == S.VERSION and S.VERSION >= 4 and empty(v3.collect) and empty(v3.found) and v3.done.guarida_cangrejo_rey == nil
            and v3.done.gruta_lugubre == nil and v3.done.arrecife_globo == true and v3.world == 2,
            ('versión 3 → %s: coleccionables vacíos=%s, salidas encontradas vacías=%s; la guarida y la gruta ya no superadas=%s/%s; el arrecife sigue=%s'):format(
             tostring(v3.version), tostring(empty(v3.collect)), tostring(empty(v3.found)), tostring(v3.done.guarida_cangrejo_rey == nil),
             tostring(v3.done.gruta_lugubre == nil), tostring(v3.done.arrecife_globo)))
        Run.data.done, Run.data.collect, Run.data.found = SEC.keepDone, {}, {}
        Run.save()
        CAN = { keep = Run.data.done, keepOpen = Run.data.open }
        go('can1')
    -- LOS CAÑONES entre islas (StoryMapCannons): con el mundo 1 superado (el 2 abierto, el 3 no), del castillo del
    -- mundo 1 al primer nivel del 2 por la FLECHA que lleva allí: anda al cañón, se mete, apunta, mecha, ¡bum!, vuela,
    -- cae y llega al nodo; suena la música de la isla nueva; y de vuelta con el otro cañón. Un cruce CERRADO no
    -- dispara. Capturas del vuelo: story_cannon_<momento>.png
    elseif step == 'can1' and t - T > 0.3 then
        Run.data.done, Run.data.open = {}, {}
        for _, n in ipairs(Worlds.nodes(1)) do Run.data.done[n.id] = true end
        local n1 = #Worlds.nodes(1)
        gStateMachine:change('story_map', { world = 1, node = n1 }); go('can2')
    elseif step == 'can2' and t - T > 0.4 then
        local function arrowTo(w, k)
            local want = st:_stopOf(w, k)
            for name, i in pairs(st:_dirs()) do if i == want then return name end end
        end
        CAN.dirF = arrowTo(2, 1)
        CAN.shots0, CAN.phases, CAN.snap = st.cannonShots or 0, {}, {}
        if CAN.dirF then pressNext('nav_' .. CAN.dirF) end
        go('can3')
    elseif step == 'can3' then
        local F = st.flight
        if F then
            if not CAN.phases[F.ph] then CAN.phases[F.ph] = true; CAN.phases[#CAN.phases + 1] = F.ph end
            CAN.music = CAN.music or {}
            if F.ph == 'fly' then CAN.maxH = math.max(CAN.maxH or 0, st.flyH or 0); CAN.musicMid = CAN.musicMid or (F.t / F.T > 0.9 and Sound.musicPosition()) end
            for _, m in ipairs({ { 'hop', 0.6 }, { 'aim', 0.9 }, { 'fuse', 0.5 }, { 'fly', 0.05 }, { 'fly', 0.4 }, { 'fly', 0.8 }, { 'land', 0.15 } }) do
                local key = m[1] .. m[2]
                local u = (m[1] == 'fly') and F.t / F.T or F.t / ({ hop = 0.32, aim = 0.45, fuse = 0.6, land = 0.4 })[m[1]]
                if F.ph == m[1] and u >= m[2] and not CAN.snap[key] then
                    CAN.snap[key] = true
                    CAN.nshot = (CAN.nshot or 0) + 1
                    shot(('cannon_%d_%s%d'):format(CAN.nshot, m[1], math.floor(m[2] * 100)))
                end
            end
        end
        if not F and #st.queue == 0 and t - T > 1 then
            local x, y = st:_nodeXY(2, 1)
            CAN.fwd = st.world == 2 and st.node == 1 and math.abs(st.heroX - x) < 1 and math.abs(st.heroY - y) < 1
                and (st.cannonShots or 0) == CAN.shots0 + 1 and #CAN.phases >= 7 and (CAN.maxH or 0) > 60
            CAN.musicF = Sound.musicPosition()
            CAN.fwdMsg = ('flecha %s; fases %s; altura máx. %.0f px; llega a %d:%d'):format(tostring(CAN.dirF), table.concat(CAN.phases, '>'),
                CAN.maxH or 0, st.world, st.node)
            local want = st:_stopOf(1, #Worlds.nodes(1))
            for name, i in pairs(st:_dirs()) do if i == want then CAN.dirB = name end end
            CAN.phases = {}
            if CAN.dirB then pressNext('nav_' .. CAN.dirB) end
            go('can4')
        elseif t - T > 15 then CAN.fwdMsg = 'no llegó (15 s)'; go('can5') end
    elseif step == 'can4' then
        local F = st.flight
        if F and not CAN.phases[F.ph] then CAN.phases[F.ph] = true; CAN.phases[#CAN.phases + 1] = F.ph; CAN.sideB = F.side end
        if not F and #st.queue == 0 and t - T > 1 then
            local n1 = #Worlds.nodes(1)
            local x, y = st:_nodeXY(1, n1)
            CAN.back = st.world == 1 and st.node == n1 and math.abs(st.heroX - x) < 1 and math.abs(st.heroY - y) < 1
                and (st.cannonShots or 0) == CAN.shots0 + 2 and CAN.sideB == 'b'
            CAN.musicB = Sound.musicPosition()
            CAN.backMsg = ('flecha %s; cañón %s; fases %s; llega a %d:%d'):format(tostring(CAN.dirB), tostring(CAN.sideB), table.concat(CAN.phases, '>'), st.world, st.node)
            -- CERRADO: el castillo del mundo 2 (sin superar: la isla 3 sigue cerrada) no cruza a la 3
            local n2 = #Worlds.nodes(2)
            gStateMachine:change('story_map', { world = 2, node = n2 })
            go('can5')
        elseif t - T > 15 then CAN.backMsg = 'no volvió (15 s)'; go('can5') end
    elseif step == 'can5' and t - T > 0.4 then
        CAN.shotsL = st.cannonShots or 0
        st:_walkTo(st:_stopOf(3, 1))
        CAN.lockMoved = #st.queue > 0 or st.world ~= 2
        shot('cannon_locked')
        go('can6')
    elseif step == 'can6' and t - T > 1.2 then
        local locked = Run.state(3, 1) == 'locked' and not CAN.lockMoved and st.flight == nil and (st.cannonShots or 0) == CAN.shotsL
        local want1, want2 = 'map_' .. Worlds.get(2).id, 'map_' .. Worlds.get(1).id
        local mus = CAN.musicF == want1 and CAN.musicB == want2 and CAN.musicMid == want1
        check('canon', CAN.fwd and CAN.back and locked and mus,
            ('ida=%s (%s); vuelta=%s (%s); cruce cerrado no dispara=%s; música: al caer %s, en el 2 %s, de vuelta %s'):format(
            tostring(CAN.fwd), tostring(CAN.fwdMsg), tostring(CAN.back), tostring(CAN.backMsg), tostring(locked),
            tostring(CAN.musicMid), tostring(CAN.musicF), tostring(CAN.musicB)))
        Run.data.done, Run.data.open = CAN.keep, CAN.keepOpen
        gStateMachine:change('story_map', { world = 1, node = 1 }); go('del')
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
