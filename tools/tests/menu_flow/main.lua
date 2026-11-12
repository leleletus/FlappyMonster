-- tools/tests/menu_flow — LOS MENÚS (docs/architecture/menus.md) con el juego real, a pasos fijos de 1/60 s:
--  1. título: las letras del logo caen y aparece "Presiona..."; al pulsar se abre el menú (el logo sube, entran
--     los botones); atrás vuelve al título;
--  2. cada botón lleva a su pantalla tras la animación de salida (Aventura, Clásico, Configuración) y desde ella
--     ATRÁS vuelve al menú principal con ese botón elegido; Configuración cambia el idioma y lo devuelve;
--  3. Aventura → Historia pasa por la TRANSICIÓN (el iris de píxeles): mientras se cierra, el estado de abajo no se
--     actualiza y al abrirse ya están los CARTUCHOS de las partidas (con dos partidas de prueba: capturas a 1280 y
--     960, la elección de dificultad de una nueva);
--  4. CONTINUAR: solo con una partida guardada; abre la más reciente y va al mapa de la historia;
--  5. el FONDO VIVO: cada escena de MenuScene.SCENES es un nivel de CARRERA (modo race, sin jefes ni zonas de
--     puntos), con su grafo al día, y con su semilla el bot LLEGA A LA META (AdventureState en modo demo: enemigos y
--     daño de verdad); la misma carrera con el dt real variable (pasos fijos por dentro); morir: reaparece y las
--     vidas no se acaban; el iris entre escenas se cierra, pasa a la siguiente y se abre;
--  6. capturas a 1280, 960 y 1600 de ancho;
--  1b. el MENÚ DE DEPURACIÓN secreto (↑↑↓↓←→←→ en el título, o 7 toques en la versión) y desde él el SOUND TEST:
--     suena música y un efecto, el tono cambia lo que suena, ATRÁS vuelve al menú de depuración (menu_soundtest.png);
--  1c. el FILM TEST desde el menú de depuración; 1d. CLÁSICO INFINITO y AVENTURA SIN CANDADO desde él;
--  2b. el CANDADO DE AVENTURA (src/flappy/Campaign.lua) con la campaña "lista": botón gris sin CONTINUAR, no entra;
--     se abre al terminar la campaña (global) o desde el menú de depuración (solo la sesión).
-- Capturas: <save>/menu_*.png                tools/tests/run.sh menu_flow
--   SCENES=0             sin el paso 5
--   LEVELS=a,b,c         el paso 5 con esos niveles (sin semilla: una al azar; SEED=n: esa) en vez de SCENES
--   FINDSEED=n           para cada escena (o cada nivel de LEVELS) prueba las semillas 1..n: con cuáles llega a la
--                        meta, en cuánto y con cuántas muertes (para elegir la de MenuScene.SCENES)
--   MENUDBG=1            dónde muere y de qué, el grafo desde la salida y el mapa alrededor al acabar
--   DETCHECK2=i [PART=]  la escena i sin dibujar y dibujando tras cada paso: el primer paso en que la carrera
--                        cambia (lo que se dibuja no puede cambiar la simulación) y qué entidad; PART=enemies|level|player
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local DT = 1 / 60
local fails = 0
local function check(name, ok, msg)
    print(('%-12s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local realInput, pressed, co, wantShot = nil, {}, nil, nil
local MenuScene, Transition, L

local MenuList = require 'src/ui/menu/MenuList'
local function top() return gStateMachine:_top() end
-- ICONOS EN TODO EL JUEGO (0.5.198): mientras dura el recorrido, cualquier texto dibujado con love.graphics.print /
-- printf que lleve un nombre de botón con icono ([Space], [A], [Esc]...) se apunta: ese sitio no pasa por
-- src/ui/RichText.lua. RichText dibuja sus trozos ya sin corchetes, así que no cuenta
local plainKeys = {}
do
    local RichText = require 'src/ui/RichText'
    local function watch(name)
        local real = love.graphics[name]
        love.graphics[name] = function(text, ...)
            if type(text) == 'string' and text:find('[', 1, true) and RichText.has(text) then
                local where = debug.getinfo(2, 'Sl')
                plainKeys[where.short_src .. ':' .. where.currentline] = text
            end
            return real(text, ...)
        end
    end
    watch('print'); watch('printf')
end
local function tick()
    local cur = pressed; pressed = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
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
local function selId(st) local it = st.list and st.list.items[st.list.selected]; return it and (it.id or it.text) end

local function run()
    -- (PAD=1: todo el recorrido como con un MANDO — los iconos de mando —; si no, con el teclado)
    if os.getenv('PAD') then Input.lastDevice = 'gamepad' end
    -- ── 1. título ─────────────────────────────────────────────────────────
    gStateMachine:change('title')
    local st = top()
    wait(0.15)
    check('caen', not st.dropped, 'las letras están cayendo al empezar')
    wait(1.6)
    check('logo', st.dropped and not st.menu, 'letras abajo, sigue en el título (sin menú)')
    shot('title')
    press('confirm', 1.0)
    check('abre', st.menu and st.logoUp == 1, ('pulsar abre el menú (logo arriba: %.2f)'):format(st.logoUp))
    shot('main')
    press('back', 0.8)
    check('cierra', not st.menu and st.logoUp == 0, 'atrás vuelve al título (logo en el centro)')

    -- ── 1b. SOUND TEST secreto: ↑ ↑ ↓ ↓ ← → ← → en el título; suena una pista y un efecto, las opciones cambian
    --        lo que suena; ATRÁS vuelve; 7 toques en la versión también entran ──
    for _, a in ipairs({ 'nav_up', 'nav_up', 'nav_down', 'nav_down', 'nav_left', 'nav_right', 'nav_left', 'nav_right' }) do press(a, 0.05) end
    wait(0.2)
    local dbg = top()
    local inDbg = name(dbg) == 'DebugMenuState'
    if inDbg then wait(0.8) end
    shot('debug')
    -- elegir un botón del menú de depuración por su id (los que van con el iris tardan más)
    local function pickDbg(id)
        local m = top()
        for _ = 1, 8 do if selId(m) == id then break end; press('nav_down', 0.1) end
        press('confirm', 1.2)
    end
    if inDbg then pickDbg('sound') end
    local stt = top()
    local inST = name(stt) == 'SoundTestState'
    local musicOk, pitchOk, sfxOk, back, taps = false, false, false, false, false
    if inST then
        press('confirm', 0.3)
        local s0 = stt:_current()
        musicOk = s0 ~= nil and stt.playing ~= nil and stt.playing.music ~= nil
        press('nav_right', 0.05); press('nav_down', 0.05); press('nav_down', 0.05)      -- (opciones → Tono)
        press('nav_right', 0.1)
        pitchOk = stt.pitch == 1.05 and s0 ~= nil and math.abs(s0:getPitch() - 1.05) < 0.001
        press('back', 0.05); press('light', 0.05)                                        -- (a la lista; efectos)
        press('nav_down', 0.05); press('confirm', 0.2)
        sfxOk = stt.tab == 2 and stt.playing ~= nil and stt.playing.music == nil
        -- con el DEDO / el ratón: la opción LISTA (→ música), el botón ▶ (suena), la barra (va a la mitad), ■ (para)
        local Ly = stt:_layout()
        local o1 = Ly.opts[1]                                                   -- (la opción LISTA, tocada: música)
        stt:touchpressed('d', o1.x + 10, o1.y + 10); stt:touchreleased('d', o1.x + 10, o1.y + 10)
        local tabOk = stt.tab == 1
        stt:_stop()
        stt:touchpressed('d', Ly.play.x + 10, Ly.play.y + 10); stt:touchreleased('d', Ly.play.x + 10, Ly.play.y + 10)
        wait(0.2)
        local sPlay = stt:_current()
        local playOk = sPlay ~= nil and stt.playing and stt.playing.music ~= nil
        stt:touchpressed('d', Ly.bar.x + Ly.bar.w / 2, Ly.bar.y + 4); stt:touchreleased('d', Ly.bar.x + Ly.bar.w / 2, Ly.bar.y + 4)
        wait(0.1)
        local s2 = stt:_current()
        local seekOk = s2 ~= nil and s2:getDuration() > 0 and math.abs(s2:tell() / s2:getDuration() - 0.5) < 0.1
        stt:touchpressed('d', Ly.play.x + 10, Ly.play.y + 10); stt:touchreleased('d', Ly.play.x + 10, Ly.play.y + 10)
        wait(0.1)
        local stopOk = stt:_current() == nil
        TOUCH_ST = tabOk and playOk and seekOk and stopOk
        TOUCH_MSG = ('LISTA=%s ▶=%s barra a la mitad=%s ■=%s'):format(tostring(tabOk), tostring(playOk), tostring(seekOk), tostring(stopOk))
        shot('soundtest')
        if stt.focus == 'opts' then press('back', 0.1) end                    -- (tocar una opción deja el foco en ellas)
        press('back', 0.6)
        back = name(top()) == 'DebugMenuState' and selId(top()) == 'sound'
        gStateMachine:change('title'); wait(1.8)
        local t = top()
        do local vx, vy, vw, vh = t:_versionRect(); for _ = 1, 7 do t:touchpressed('dedo', vx + vw / 2, vy + vh / 2); wait(0.05) end end
        wait(0.2)
        taps = name(top()) == 'DebugMenuState'
    end
    check('soundtest', inDbg and inST and musicOk and pitchOk and sfxOk and back and taps and TOUCH_ST,
        ('código → %s → %s; música suena=%s; tono 1,05 en lo que suena=%s; efectos suena=%s; atrás → depuración=%s; 7 toques en la versión → depuración=%s; con el dedo: %s'):format(
         name(dbg), name(stt), tostring(musicOk), tostring(pitchOk), tostring(sfxOk), tostring(back), tostring(taps), tostring(TOUCH_MSG)))
    -- ── 1c. FILM TEST secreto (desde el menú de depuración): la lista sale de los catálogos (películas, escenas del mapa,
    --        escenas dentro del juego); ver una película, una escena del mapa, la escena final de la huida y la
    --        entrada de un jefe, y cada una vuelve al film test; la partida de mentira no toca la de verdad ──
    do
        gStateMachine:change('debug_menu'); wait(0.6)
        pickDbg('film')
        local ft = top()
        local inFT = name(ft) == 'FilmTestState'
        local groups, ids = {}, {}
        for i, it in ipairs(inFT and ft.list or {}) do groups[it.group] = (groups[it.group] or 0) + 1; ids[it.id] = i end
        local Run = require 'src/story/Run'
        local before = Run.data
        local function pick(id) local t = top(); t.sel = ids[id]; press('confirm', 0.4) end
        local filmOk, mapOk, outroOk, bossOk = false, false, false, false
        if inFT then
            pick('intro')
            filmOk = name(top()) == 'StoryFilmState'
            if filmOk then top():_finish(); wait(0.3) end
            filmOk = filmOk and name(top()) == 'FilmTestState'
            pick('groove'); wait(0.6)
            local m = top()
            mapOk = name(m) == 'StoryMapState' and m.scene ~= nil and m.scene.id == 'groove'
            if mapOk then shot('filmtest_escena'); press('confirm', 0.4) end
            mapOk = mapOk and name(top()) == 'FilmTestState'
            pick('outro_huida_del_espejo'); wait(1.2)
            local a = top()
            outroOk = name(a) == 'AdventureState' and a.runOut ~= nil and (a.runOut.active == true or a.level.cinema == true)
            if outroOk then shot('filmtest_huida') end
            gStateMachine:change('film_test'); wait(0.3)
            pick('boss_ruta_del_espejo'); wait(2.0)
            local b = top()
            local z = name(b) == 'AdventureState' and b.level.bossZones and b.level.bossZones[1]
            bossOk = z ~= nil and z ~= false and z.state ~= 'wait'
            if bossOk then shot('filmtest_espejo') end
            gStateMachine:change('film_test'); wait(0.3)
        end
        local restored = (Run.data == before) and not Run.filmTest
        check('filmtest', inFT and (groups.film or 0) >= 6 and (groups.map or 0) >= 3 and (groups.game or 0) >= 10 and filmOk and mapOk and outroOk and bossOk and restored,
            ('depuración → %s; %d películas, %d escenas del mapa, %d en el juego; película → y vuelta=%s; escena del mapa=%s; escena final de la huida=%s; entrada del Espejo=%s; partida de verdad intacta=%s'):format(
             name(ft), groups.film or 0, groups.map or 0, groups.game or 0, tostring(filmOk), tostring(mapOk), tostring(outroOk), tostring(bossOk), tostring(restored)))
    end
    -- ── 1d. depuración: CLÁSICO INFINITO (atrás vuelve a la depuración) y AVENTURA SIN CANDADO (abre la sesión) ──
    do
        local Campaign = require 'src/flappy/Campaign'
        gStateMachine:change('debug_menu'); wait(0.6)
        pickDbg('classic')
        local toDiff = name(top()) == 'DifficultySelectionState'
        press('back', 0.6)
        local backDbg = name(top()) == 'DebugMenuState' and selId(top()) == 'classic'
        Campaign.debugOpen = false
        pickDbg('adventure')
        local advName = name(top())
        local toAdv = advName == 'AdventureModeSelectState' and Campaign.debugOpen == true
        Campaign.debugOpen = false
        -- VUELO FLAPPY (prueba): entra a la etapa de prueba con el jugador volando y la cámara automática; aletear sube
        gStateMachine:change('debug_menu'); wait(0.6)
        pickDbg('flight')                            -- (tras el inicio del nivel — StartCountdown: lo que dure —)
        for _ = 1, 80 do if name(top()) == 'AdventureState' and not top().startCd then break end; wait(0.1) end
        wait(0.3)
        local adv = top()
        local flies = name(adv) == 'AdventureState' and adv.level.flappy == true and adv.player.flight == true
        local y0 = flies and adv.player.y or 0
        for _ = 1, 4 do press('jump', 0.12) end
        local up = flies and adv.player.y < y0
        if flies then adv.player.charge = 3; wait(1.0); adv.player.shield = true; adv.player.invT = 0; shot('flight') end      -- (con carga y escudo: el HUD de Flappy y la burbuja)
        toAdv = toAdv and flies and up
        check('vuelo', flies and up, ('depuración → %s; nivel Flappy y jugador volando=%s; aletear sube=%s'):format(name(adv), tostring(flies), tostring(up)))
        check('depuracion', toDiff and backDbg and toAdv,
            ('clásico infinito → dificultad=%s, atrás → depuración=%s; aventura sin candado → %s (sesión abierta=%s)'):format(
             tostring(toDiff), tostring(backDbg), advName, tostring(toAdv)))
    end
    gStateMachine:change('title'); st = top(); wait(1.8)
    press('confirm', 0.8)

    -- ── 2. cada botón y vuelta ───────────────────────────────────────────
    local hasCont = st.slot ~= nil
    local function go(id, want, shotName)
        local m = top()
        for _ = 1, 6 do if selId(m) == id then break end; press('nav_down', 0.1) end
        press('confirm', 0.75)
        local s = top()
        check('a ' .. id, name(s) == want, ('%s → %s'):format(id, name(s)))
        if shotName then shot(shotName) end
        return s
    end
    go('adventure', 'AdventureModeSelectState', 'adventure')
    press('back', 0.6)
    check('vuelve adv', top().startInMenu and selId(top()) == 'adventure', 'atrás → menú con AVENTURA elegido: ' .. tostring(selId(top())))
    go('classic', 'FlappyCampaignState', 'classic')
    do      -- (la campaña aún no existe: CAMPAÑA gris y el INFINITO, que lleva a la dificultad y vuelve)
        local fc = top()
        local ids = {}
        for _, it in ipairs(fc.list.items) do ids[#ids + 1] = it.id end
        press('nav_down', 0.1); press('confirm', 0.75)
        local toDiff = name(top()) == 'DifficultySelectionState'
        shot('difficulty')
        press('back', 0.6)
        local backFc = name(top()) == 'FlappyCampaignState' and selId(top()) == 'endless'
        check('campana', table.concat(ids, ',') == 'campaign,endless' and toDiff and backFc,
            ('botones %s; infinito → dificultad=%s; atrás → campaña con INFINITO elegido=%s'):format(table.concat(ids, ','), tostring(toDiff), tostring(backFc)))
    end
    press('back', 0.6)
    check('vuelve cla', selId(top()) == 'classic', 'atrás → menú con CLÁSICO elegido: ' .. tostring(selId(top())))
    -- ── 2b. el candado de Aventura con la campaña "lista" ──
    do
        local Campaign = require 'src/flappy/Campaign'
        local Save = require 'src/story/Save'
        local g0 = love.filesystem.read('story.sav')
        for i = 1, require('src/flappy/FlappySave').SLOTS do require('src/flappy/FlappySave').delete(i) end -- que una ejecución caída no deje partidas
        local g = Save.global(); g.adventure = nil; Save.writeGlobal(g)
        Save.write(1, Save.new('normal'))
        Campaign.READY = true
        gStateMachine:change('main_menu'); wait(0.6)
        local m = top()
        local function advItem(st) for i, x in ipairs(st.list.items) do if x.id == 'adventure' then return x, i end end end
        local it, ai = advItem(m)
        local lockedOk = m.slot == nil and it and it.locked == true and it.color == 'grey'
        m.list.selected = ai
        shot('locked')
        press('confirm', 0.75)
        local stays = name(top()) == 'TitleState'
        gStateMachine:change('flappy_campaign'); wait(0.3)
        local noEndless = #top().list.items == 1
        Campaign.debugOpen = true
        gStateMachine:change('main_menu'); wait(0.1)
        local dbgOpen = not advItem(top()).locked and top().slot == 1
        Campaign.debugOpen = false
        Campaign.unlockAdventure()
        gStateMachine:change('main_menu'); wait(0.1)
        local unlocked = not Campaign.adventureLocked() and top().slot == 1 and Save.global().adventure == true
        Campaign.READY = false
        Save.delete(1)
        if g0 then love.filesystem.write('story.sav', g0) else love.filesystem.remove('story.sav') end
        check('candado', lockedOk and stays and noEndless and dbgOpen and unlocked,
            ('bloqueada: gris sin CONTINUAR=%s, no entra=%s; campaña lista sin infinito=%s; depuración la abre=%s; terminar la campaña la abre (global)=%s'):format(
             tostring(lockedOk), tostring(stays), tostring(noEndless), tostring(dbgOpen), tostring(unlocked)))
        gStateMachine:change('main_menu', { select = 'classic' }); wait(0.6)
    end
    -- ── 2b2. las PARTIDAS de la campaña Flappy: FLAPPY → CAMPAÑA → 3 cartuchos vacíos; uno vacío ofrece SOLO Fácil,
    --         Normal y Difícil; Normal crea flappy<n>.sav (no story<n>.sav) y lleva al mapa de zonas; ATRÁS vuelve a la
    --         pantalla de FLAPPY con CAMPAÑA elegida ──
    do
        local FlappySave = require 'src/flappy/FlappySave'
        local Save = require 'src/story/Save'
        for i = 1, 3 do FlappySave.delete(i); Save.delete(i) end
        gStateMachine:change('flappy_campaign'); wait(0.6)
        press('confirm', 1.4)                                   -- (CAMPAÑA, el primero)
        local sl = top()
        local inSlots = name(sl) == 'StorySlotState' and sl.c and sl.c.id == 'flappy'
        local empty = inSlots and not sl.slots[1] and not sl.slots[2] and not sl.slots[3]
        if inSlots then for _, w in ipairs({ 960, 1600, 1280 }) do resize(w, 720); wait(0.3); shot('flappy_slots_' .. w) end end
        press('confirm', 0.4)                                   -- (el 1, vacío: pide la dificultad)
        local diffs = inSlots and sl.pick and #sl.c.difficulties or 0
        if inSlots and sl.pick then shot('flappy_pick') end
        press('confirm', 1.4)                                   -- (Normal, la elegida al abrir)
        local toMap = name(top()) == 'FlappyMapState'
        local files = love.filesystem.getInfo('flappy1.sav') ~= nil and love.filesystem.getInfo('story1.sav') == nil
        local nd = FlappySave.load(1)
        gStateMachine:change('story_slots', { campaign = 'flappy' }); wait(0.6)
        press('back', 0.8)
        local backOk = name(top()) == 'FlappyCampaignState' and selId(top()) == 'campaign'
        check('flappy_slots', inSlots and empty and diffs == 3 and toMap and files and nd and nd.difficulty == 'normal' and backOk,
            ('CAMPAÑA → partidas Flappy=%s, vacías=%s; dificultades %d; Normal → mapa=%s; flappy1.sav y no story1.sav=%s (%s); atrás → FLAPPY con CAMPAÑA=%s'):format(
             tostring(inSlots), tostring(empty), diffs, tostring(toMap), tostring(files), nd and nd.difficulty or '-', tostring(backOk)))
        require('src/flappy/FlappyRun').close()
        for i = 1, 3 do FlappySave.delete(i) end
    end
    -- ── 2c. el MAPA DE ZONAS de la campaña Flappy: nodos, jugar una etapa (nivel Flappy, vuelve al mapa), terminarla
    --        (resultados → el mapa con la siguiente abierta) y salir a medias (vidas perdidas sí, nada ganado) ──
    do
        local FlappyRun = require 'src/flappy/FlappyRun'
        local FlappySave = require 'src/flappy/FlappySave'
        for i = 1, FlappySave.SLOTS do FlappySave.delete(i) end
        FlappyRun.open(1, 'normal')
        local lives0 = FlappyRun.data.lives
        gStateMachine:change('flappy_map', { world = 1, node = 1 }); wait(0.6)
        local m = top()
        local inMap = name(m) == 'FlappyMapState'
        local nodesOk = inMap and #m.nodes == #require('src/flappy/Zones').nodes(1) and FlappyRun.state(1, 1) == 'open' and FlappyRun.state(1, 2) == 'locked'
        for _, w in ipairs({ 960, 1600, 1280 }) do resize(w, 720); wait(0.3); shot('flappy_map_' .. w) end
        -- la TIENDA en el mapa (el nido del mercader): un sitio más, no un nodo; ← desde la etapa 1 la elige y → vuelve;
        -- con el dedo, tocarla la elige y tocar la etapa 1 vuelve a ella
        local shopOk = false
        if inMap then
            local nSpots = #m.spots
            press('nav_left', 0.1)
            local toShop = m.onShop == true
            if toShop then shot('flappy_map_shop') end
            press('nav_right', 0.1)
            local back1 = not m.onShop and m.sel == 1
            local Ly = m:_layout()
            m:touchpressed('d', Ly.shop.x, Ly.shop.y - 20); wait(0.05)
            local tShop = m.onShop == true and name(top()) == 'FlappyMapState'
            m:touchpressed('d', Ly.nodes[1].x, Ly.nodes[1].y - 20); wait(0.05)
            local t1 = not m.onShop and m.sel == 1 and name(top()) == 'FlappyMapState'
            shopOk = nSpots == #m.nodes + 1 and toShop and back1 and tShop and t1
            if not shopOk then print(('   tienda en el mapa: sitios %d (nodos %d), ← %s, → %s, tocar %s / %s'):format(
                nSpots, #m.nodes, tostring(toShop), tostring(back1), tostring(tShop), tostring(t1))) end
        end
        press('confirm', 1.6)
        local adv = top()
        local plays = name(adv) == 'AdventureState' and adv.level.flappy == true and adv.returnTo == 'flappy_map'
        -- salir a medias tras perder una vida: se guarda la vida perdida, la etapa no
        if plays then adv.stats.deaths = 1; adv.player.lives = lives0 - 1 end
        gStateMachine:change('flappy_map'); wait(0.3)
        local left = FlappyRun.data.lives == lives0 - 1 and FlappySave.load(1).lives == lives0 - 1 and not FlappyRun.isDone('valle_pilares_1')
        -- terminarla: resultados y, al seguir, el mapa con la etapa 2 abierta
        press('confirm', 1.6)
        local adv2 = top()
        local fin = false
        if name(adv2) == 'AdventureState' and adv2.onFinish then
            adv2.onFinish({ time = 30, width = 114, score = 200, lives = FlappyRun.data.lives, deaths = 0, hits = 0 })
            wait(0.3)
            local res = top()
            fin = name(res) == 'StoryResultsState'
            if fin then
                press('confirm', 0.1); press('confirm', 0.6)
                fin = name(top()) == 'FlappyMapState' and FlappyRun.state(1, 2) == 'open' and FlappyRun.isDone('valle_pilares_1')
            end
        end
        -- REINTENTAR en los resultados: la misma etapa otra vez, con las vidas extra ya cogidas apuntadas (`taken`)
        local retry = false
        local m2 = top()
        if name(m2) == 'FlappyMapState' then
            m2.sel = 1
            press('confirm', 1.6)
            local a3 = top()
            if name(a3) == 'AdventureState' and a3.onFinish then
                a3.onFinish({ time = 30, width = 114, score = 200, lives = FlappyRun.data.lives, deaths = 0, hits = 0, taken = { 1 } })
                wait(0.3)
                if name(top()) == 'StoryResultsState' then
                    top().t = 999; top():_continue(true); wait(1.8)
                    local a4 = top()
                    retry = name(a4) == 'AdventureState' and a4.levelPath == 'assets/levels/valle_pilares_1.json'
                            and a4.takenArg ~= nil and a4.takenArg[1] == true
                end
            end
        end
        fin = fin and retry
        -- (captura del mapa avanzado: la 1 a la 3 superadas —nidos dorados con su nota— y el jefe abierto)
        local zn = require('src/flappy/Zones').nodes(1)
        for k = 2, #zn - 1 do
            FlappyRun.complete(zn[k].id, { time = 40, width = 114, score = 300, lives = FlappyRun.data.lives, deaths = 0, hits = 0 })
        end
        gStateMachine:change('flappy_map', { world = 1, node = #zn }); wait(0.6)
        shot('flappy_map_done')
        check('mapa', inMap and nodesOk and shopOk and plays and left and fin,
            ('mapa=%s; nodos abierto/cerrado=%s; la tienda, un sitio más (← →, con el dedo)=%s; jugar → nivel Flappy que vuelve al mapa=%s; salir a medias guarda la vida perdida y nada más=%s; terminar → resultados → mapa con la 2 abierta y REINTENTAR → la misma, con sus vidas cogidas=%s'):format(
             tostring(inMap), tostring(nodesOk), tostring(shopOk), tostring(plays), tostring(left), tostring(fin)))
        FlappyRun.close()
        for i = 1, FlappySave.SLOTS do FlappySave.delete(i) end
        gStateMachine:change('main_menu', { select = 'classic' }); wait(0.6)
    end
    -- ── 2d. la TIENDA de una zona Flappy (src/states/flappy/FlappyShopState.lua), desde el nido del mercader del mapa (←,
    --        ENTER): sus fichas, comprar con confirmación
    --        (gasta el monedero y se guarda), cancelar, sin puntos / inventario lleno → aviso sin ventana ni gasto, con
    --        el dedo (ficha, otra vez: confirmar, COMPRAR) y ATRÁS vuelve al mapa de la zona con la tienda elegida ──
    do
        local FlappyRun = require 'src/flappy/FlappyRun'
        local FlappySave = require 'src/flappy/FlappySave'
        for i = 1, FlappySave.SLOTS do FlappySave.delete(i) end
        FlappyRun.open(1, 'normal')
        local d = FlappyRun.data
        d.wallet = 1000
        -- se entra desde el MAPA: ← (de la etapa 1 al nido del mercader) y ENTER
        gStateMachine:change('flappy_map', { world = 1, node = 1 }); wait(0.6)
        press('nav_left', 0.1); press('confirm', 0.9)
        local sh = top()
        local inShop = name(sh) == 'FlappyShopState' and #sh.items == 3 and sh.zone == 1
        local buyOk, cancelOk, poorOk, fullOk, touchOk, backOk = false, false, false, false, false, false
        if inShop then
            for _, w in ipairs({ 960, 1600, 1280 }) do resize(w, 720); wait(0.3); shot('flappy_shop_' .. w) end
            -- comprar el 1º (escudo, 300): confirmar y COMPRAR
            press('confirm', 0.1)
            local asked = sh.confirm ~= nil
            if asked then shot('flappy_shop_confirm') end
            press('confirm', 0.1)
            buyOk = asked and sh.confirm == nil and d.wallet == 700 and d.inventory.shield == 1 and FlappySave.load(1).wallet == 700
                    and sh.noticeOk == true
            -- cancelar: ATRÁS cierra la ventana sin gastar y sigue en la tienda
            press('confirm', 0.1); press('back', 0.3)
            cancelOk = sh.confirm == nil and top() == sh and d.wallet == 700 and d.inventory.shield == 1
            -- sin puntos (corazón, 400): apagada, ni ventana ni gasto
            d.wallet = 100
            press('nav_down', 0.1); press('confirm', 0.1)
            poorOk = sh.sel == 2 and sh.confirm == nil and sh.noticeOk == false and d.wallet == 100 and d.inventory.heart == nil
            shot('flappy_shop_poor')
            -- inventario lleno (6): el imán no entra, ni ventana ni gasto
            d.wallet, d.inventory = 5000, { heart = 3, strength = 3 }
            press('nav_down', 0.1); press('confirm', 0.1)
            fullOk = sh.sel == 3 and sh.confirm == nil and sh.noticeOk == false and d.wallet == 5000 and d.inventory.magnet_points == nil
            -- con el dedo: tocar la 1ª la elige, otra vez abre la confirmación, fuera la cancela; luego COMPRAR
            d.inventory = {}
            local c1 = sh:_layout().cards[1]
            local cx, cy = c1.x + 40, c1.y + 20
            sh:touchpressed('d', cx, cy); wait(0.05)
            local picked = sh.sel == 1 and sh.confirm == nil
            sh:touchpressed('d', cx, cy); wait(0.05)
            local opened = sh.confirm ~= nil
            sh:touchpressed('d', 4, 4); wait(0.05)
            local outCancel = sh.confirm == nil and d.wallet == 5000
            sh:touchpressed('d', cx, cy); wait(0.05)
            local _, rects = require('src/ui/menu/MenuKit').optionsLayout(2, { note = true })
            sh:touchpressed('d', rects[1].x + 20, rects[1].y + 20); wait(0.05)
            touchOk = picked and opened and outCancel and d.wallet == 4700 and d.inventory.shield == 1
            press('back', 0.9)
            backOk = name(top()) == 'FlappyMapState' and top().world == 1 and top().onShop == true
        end
        check('tienda', inShop and buyOk and cancelOk and poorOk and fullOk and touchOk and backOk,
            ('mapa → ← → ENTER → tienda=%s; comprar con confirmación (monedero 1000 → 700, guardado)=%s; cancelar=%s; sin puntos: aviso sin gastar=%s; inventario lleno: aviso sin gastar=%s; con el dedo=%s; atrás → mapa con la tienda elegida=%s'):format(
             tostring(inShop), tostring(buyOk), tostring(cancelOk), tostring(poorOk), tostring(fullOk), tostring(touchOk), tostring(backOk)))
        FlappyRun.close()
        for i = 1, FlappySave.SLOTS do FlappySave.delete(i) end
        gStateMachine:change('main_menu', { select = 'classic' }); wait(0.6)
    end
    -- LAS OPCIONES como datos (src/ui/menu/SettingsRows.lua): cada una una vez, con sus textos en todos los idiomas
    do
        local okR, Rows = pcall(require, 'src/ui/menu/SettingsRows')
        local want = { 'musicVol', 'sfxVol', 'muted', 'rhythmOffset', 'swapAB', 'rumble', 'wheelToggle', 'language', 'hitStop', 'deathCause', 'showPerf', 'credits' }
        local seen, missing, bad = {}, {}, {}
        if okR then
            for _, tab in ipairs(Rows.TABS) do
                for _, lg in ipairs(L.LANGUAGES) do if not L.keys(lg.id)[tab.label] then bad[#bad + 1] = tab.label end end
                for _, r in ipairs(tab.rows) do
                    seen[r.id] = (seen[r.id] or 0) + 1
                    for _, k in ipairs({ r.label, r.desc }) do
                        for _, lg in ipairs(L.LANGUAGES) do if not L.keys(lg.id)[k] then bad[#bad + 1] = k .. '/' .. lg.id end end
                    end
                end
            end
        end
        for _, id in ipairs(want) do if seen[id] ~= 1 then missing[#missing + 1] = id .. '×' .. tostring(seen[id] or 0) end end
        check('cfg_datos', okR and #missing == 0 and #bad == 0 and #Rows.TABS == 4,
            ('pestañas %s · opciones que faltan o se repiten: %s · textos que faltan: %s'):format(okR and #Rows.TABS or 'sin módulo',
             #missing > 0 and table.concat(missing, ',') or 'ninguna', #bad > 0 and table.concat(bad, ',', 1, math.min(#bad, 6)) or 'ninguno'))
    end
    -- EL ENGRANAJE (abajo a la derecha, en lugar del botón de configuración): abajo desde el último botón lo elige,
    -- arriba vuelve a la lista; confirmar abre la configuración
    do
        local m = top()
        for _ = 1, 6 do if m.gearSel then break end; press('nav_down', 0.1) end
        local focused = m.gearSel == true
        press('nav_up', 0.1)
        local lastId = m.list.items[#m.list.items].id
        local backList = not m.gearSel and selId(m) == lastId
        press('nav_down', 0.1)
        press('confirm', 0.75)
        check('a settings', focused and backList and name(top()) == 'SettingsState',
            ('abajo → engranaje=%s · arriba → %s=%s · confirmar → %s'):format(tostring(focused), tostring(lastId), tostring(backList), name(top())))
    end
    -- LA CONFIGURACIÓN rehecha (docs/design/settings-menu-rework.md): pestañas, filas, interruptores, barras
    do
        local S = require 'src/core/Settings'
        local Rows = require 'src/ui/menu/SettingsRows'
        local st = top()
        local function tabId() return Rows.TABS[st.tab] and Rows.TABS[st.tab].id end
        local function rowId() local t = Rows.TABS[st.tab]; local r = t and t.rows[st.row]; return r and r.id end
        shot('settings_audio')
        -- pestañas: siguiente ×4 da la vuelta; anterior vuelve
        local seq = {}
        for _ = 1, 4 do seq[#seq + 1] = tabId(); press('tab_next', 0.05) end
        local wrapped = tabId()
        press('tab_prev', 0.05)
        local back1 = tabId()
        press('tab_next', 0.05)
        check('cfg_pestanas', table.concat(seq, ',') == 'audio,controls,game,other' and wrapped == 'audio' and back1 == 'other',
            ('siguiente: %s → %s · anterior: %s'):format(table.concat(seq, ','), tostring(wrapped), tostring(back1)))
        -- volumen de la música (se aplica y se guarda), silencio, A / B
        S.set('musicVol', 10)                                     -- (lo guardado por una pasada anterior no cuenta)
        Sound.playMusic('menus'); wait(0.05)
        local v0 = Sound.musicVolume()
        local onMusic = rowId() == 'musicVol'
        press('nav_left', 0.05); press('nav_left', 0.05)
        local volOk = onMusic and S.musicVol == 8 and math.abs(Sound.musicVolume() - v0) < 0.01
        S.set('muted', true); local muteOk = love.audio.getVolume() == 0
        S.set('muted', false); muteOk = muteOk and love.audio.getVolume() == 1
        S.set('swapAB', true); Input.load(); S.set('swapAB', false); Input.load()
        local saved = (love.filesystem.read('options.cfg') or ''):find('musicVol = 8', 1, true) ~= nil
        -- abajo y arriba por las filas; arriba desde la primera = la barra de pestañas
        local n = #Rows.TABS[st.tab].rows
        for _ = 1, n - 1 do press('nav_down', 0.03) end
        local last = st.row == n
        for _ = 1, n do press('nav_up', 0.03) end
        local onBar = st.row == 0
        press('nav_down', 0.03)
        S.set('musicVol', 10)
        check('opciones_son', volOk and muteOk and saved and last and onBar and st.row == 1,
            ('música 8=%s · silencio=%s · guardado=%s · última fila=%s · arriba = pestañas=%s'):format(tostring(volOk), tostring(muteOk),
             tostring(saved), tostring(last), tostring(onBar)))
        -- idioma: en JUEGO, izquierda / derecha; los textos cambian al momento
        press('tab_next', 0.05); press('tab_next', 0.05)
        local lang0, tab0 = L.current(), L('settings.tab_game')
        local onLang = rowId() == 'language'
        press('nav_right', 0.3)
        local lang1, tab1 = L.current(), L('settings.tab_game')
        shot('settings_game')
        press('nav_left', 0.3)
        check('idioma', onLang and lang1 ~= lang0 and tab1 ~= tab0 and L.current() == lang0,
            ('%s → %s → %s (pestaña «%s» → «%s»)'):format(lang0, lang1, L.current(), tab0, tab1))
        -- táctil: tocar una pestaña la elige; tocar una fila sin elegir solo la elige; otra vez, cambia
        local Lt = st:layout()
        local tb = Lt.tabs[2]
        st:touchpressed('t', tb.x + tb.w / 2, tb.y + tb.h / 2); wait(0.05)
        local tabOk = tabId() == 'controls'
        local rum0 = S.rumble
        local rr = st:layout().rows[2]
        st:touchpressed('t', rr.x + rr.w - 30, rr.y + rr.h / 2); wait(0.05)
        local selOnly = rowId() == 'rumble' and S.rumble == rum0
        st:touchpressed('t', rr.x + rr.w - 30, rr.y + rr.h / 2); wait(0.05)
        local toggled = S.rumble ~= rum0
        S.set('rumble', rum0)
        check('cfg_tactil', tabOk and selOnly and toggled,
            ('tocar la pestaña=%s · 1er toque solo elige=%s · 2º cambia=%s'):format(tostring(tabOk), tostring(selOnly), tostring(toggled)))
        -- revisión final: tocar el NOMBRE de una fila de volumen ya elegida no cambia nada (solo su control); izquierda
        -- en un interruptor apagado lo deja apagado y derecha lo enciende; izquierda / derecha en CRÉDITOS no la abren
        do
            st.tab, st.row, st.first = 1, 1, 1
            local rv = st:layout().rows[1]
            local v0 = S.musicVol
            st:touchpressed('t', rv.x + 20, rv.y + rv.h / 2); wait(0.05)
            local labelSafe = S.musicVol == v0
            st.tab, st.row = 2, 2                                   -- (CONTROLES · vibración)
            local keepR = S.rumble
            S.set('rumble', false)
            press('nav_left', 0.05); local leftOff = S.rumble == false
            press('nav_right', 0.05); local rightOn = S.rumble == true
            press('nav_right', 0.05); local stillOn = S.rumble == true
            S.set('rumble', keepR)
            st.tab, st.row = 4, 1                                   -- (OTROS · créditos)
            press('nav_right', 0.1); press('nav_left', 0.1)
            local noFilm = name(top()) == 'SettingsState' and not st.anim:busy()
            st.tab, st.row = 1, 1
            check('cfg_revision', labelSafe and leftOff and rightOn and stillOn and noFilm,
                ('tocar el nombre no cambia el volumen=%s · interruptor: izquierda apagado=%s, derecha encendido=%s (y sigue=%s) · ←/→ en créditos no los abre=%s'):format(
                 tostring(labelSafe), tostring(leftOff), tostring(rightOn), tostring(stillOn), tostring(noFilm)))
        end
        -- una pestaña que no cabe: barra de desplazamiento y la elegida siempre dentro del panel (960 de ancho)
        resize(960, 720); wait(0.2)
        shot('settings_960')
        local tab = Rows.TABS[1]
        local keep = tab.rows
        local many = {}
        for k = 1, 14 do many[k] = keep[(k - 1) % #keep + 1] end
        tab.rows = many
        st.tab, st.row, st.first = 1, 1, 1
        for _ = 1, 13 do press('nav_down', 0.02) end
        local L2 = st:layout()
        local sr, pn = L2.rows[st.row], L2.panel
        local inside = sr and sr.y >= pn.y and sr.y + sr.h <= pn.y + pn.h
        tab.rows = keep
        st.tab, st.row, st.first = 1, 1, 1
        resize(1280, 720); wait(0.2)
        local L3 = st:layout()
        check('cfg_scroll', L2.scroll ~= nil and inside and L3.scroll == nil,
            ('14 filas: barra=%s, la elegida dentro=%s · 4 filas: barra=%s'):format(tostring(L2.scroll ~= nil), tostring(inside), tostring(L3.scroll ~= nil)))
    end
    press('back', 0.6)
    check('vuelve cfg', top().gearSel == true, 'atrás → menú con el ENGRANAJE elegido: ' .. tostring(top().gearSel))
    -- con el dedo: tocar el engranaje abre la configuración; con el menú cerrado (el título) no está
    do
        local m = top()
        local gx, gy, gw, gh = m:_gearRect()
        m:touchpressed('dedo', gx + gw / 2, gy + gh / 2); wait(0.75)
        local tapOk = name(top()) == 'SettingsState'
        press('back', 0.6)
        local m2 = top()
        m2:_close(); wait(0.8)
        m2:touchpressed('dedo', gx + gw / 2, gy + gh / 2); wait(0.75)
        local closedOk = name(top()) == 'TitleState'
        local vx = m2:_versionRect()
        check('engranaje', tapOk and closedOk and gx > WINDOW_W / 2 and vx < WINDOW_W / 2,
            ('tocarlo abre=%s · en el título no=%s · engranaje a la derecha=%s · versión a la izquierda=%s'):format(tostring(tapOk),
             tostring(closedOk), tostring(gx > WINDOW_W / 2), tostring(vx < WINDOW_W / 2)))
        -- a 960 de ancho la descripción más larga no tapa el engranaje
        resize(960, 720); wait(0.2)
        local m3 = top()
        local gx3, gy3, gw3, gh3 = m3:_gearRect()
        local worst = 0
        for _, it in ipairs(m3.list.items) do
            for _, lg in ipairs(L.LANGUAGES) do
                local txt = L.keys(lg.id)[it.desc] or ''
                local fx, fy, fw, fh = MenuList.footerRect(txt, m3:_footerMaxW())
                if fx + fw > gx3 and fy + fh > gy3 then worst = math.max(worst, fx + fw - gx3) end
            end
        end
        shot('main_960_gear')
        resize(1280, 720); wait(0.2)
        check('engranaje_pie', worst == 0, 'la descripción tapa el engranaje en 960: ' .. worst .. ' px')
        gStateMachine:change('main_menu', { select = 'settings' }); wait(0.6)
    end

    -- ── 3. transición (el iris): Aventura → Historia ─────────────────────
    -- (con dos partidas para ver los cartuchos llenos: la 1 en el mundo 3, la 3 recién empezada)
    do
        local Save = require 'src/story/Save'
        local Worlds = require 'src/story/Worlds'
        for i = 1, Save.SLOTS do Save.delete(i) end
        local d = Save.new('hard')
        for w = 1, 2 do for _, n in ipairs(Worlds.nodes(w)) do d.done[n.id] = true end end
        d.world, d.node, d.lives, d.playTime, d.shards = 3, 1, 5, 4321, { ['1'] = true, ['2'] = true }
        Save.write(1, d)
        Save.write(3, Save.new('easy'))
    end
    go('adventure', 'AdventureModeSelectState')
    local adv = top()
    pressed['confirm'] = true
    local frames, frozen, covered = 0, true, false
    while name(top()) ~= 'StorySlotState' and frames < 120 do
        local t0, was = adv.anim.t, Transition.blocking()
        tick(); frames = frames + 1
        if was then
            covered = true
            if top() == adv and adv.anim.t ~= t0 then frozen = false end
        end
    end
    check('iris pant', covered and frozen and name(top()) == 'StorySlotState',
          ('tapa en %.2f s sin actualizar la pantalla de abajo; luego %s'):format(frames * DT, name(top())))
    wait(0.25)
    shot('transition')
    wait(0.4)
    check('destapa', not Transition.active(), 'la transición termina')
    shot('story_slots')
    press('nav_right', 0.5)
    shot('story_slots_2')
    resize(960, 720); wait(0.4); shot('story_slots_960'); resize(1280, 720)
    press('confirm', 0.6)                                  -- (la 2, vacía: pregunta la dificultad)
    shot('story_pick')
    press('back', 0.3)

    -- ── 3b. La OFERTA del tutorial: solo la primera vez que se crea una partida; EMPEZAR YA / atrás → la intro; JUGAR →
    --        el nivel, y de cualquier salida del nivel → la intro (docs/design/tutorial-level.md)
    do
        local S = require 'src/core/Settings'
        local keep = S.tutorialOffered
        local function newGame(flag)
            S.tutorialOffered = flag
            local slot = top()
            slot.inserting = { slot = 2, t = 0, new = true }
            slot:_go()
            wait(1.2)
            return name(top())
        end
        local first = newGame(false)
        shot('tutorial_offer')
        local marked = S.tutorialOffered == true
        press('back', 1.2)
        local skip = name(top())
        gStateMachine:change('story_slots'); wait(0.5)
        local again = newGame(true)
        gStateMachine:change('story_slots'); wait(0.5)
        newGame(false)
        press('confirm', 1.2)
        local played, lvl, ret = name(top()), top().levelPath, top().returnTo
        -- (la cueva del tutorial: la oscuridad sigue al jugador en el estado de verdad)
        local st = top()
        local function at(col)
            st.startCd, st.player.x, st.player.y, st.player.vx, st.player.vy = nil, (col - 0.5) * TILE_PX, 5 * TILE_PX, 0, 0
            wait(0.6)
            return st.level.dark == true, st.level.darkness
        end
        -- (TUTLOOK=1: capturas a lo largo del nivel, para ver cómo queda decorado)
        if os.getenv('TUTLOOK') then
            for _, col in ipairs({ 12, 50, 100, 150, 200, 250, 295, 345 }) do at(col); at(col); at(col); shot('tut_' .. col) end
        end
        -- (los carteles con ICONOS de botones: teclado y mando; con el dedo, el botón de la pantalla brilla)
        do
            local realDev, realMob = Input.lastDevice, Input.isMobile
            local TC = require 'src/ui/TouchControls'
            local seen = {}
            for _, dev in ipairs({ 'keyboard', 'gamepad', 'touch' }) do
                Input.lastDevice, Input.isMobile = dev, dev == 'touch' or realMob
                at(17); at(17)
                -- (el bocadillo aparece con el tiempo REAL — love.timer.getDelta —, que aquí apenas corre: ya del todo)
                for _, e in ipairs(st.enemies or {}) do if e.def and e.def.name == 'hint' and e.props.text == 'tut.run' then e.show = 1 end end
                shot('tut_sign_' .. dev)
                for _, e in ipairs(st.enemies or {}) do
                    if e.def and e.def.name == 'hint' and e.props.text == 'tut.run' and e._lines then
                        local imgs = 0
                        for _, l in ipairs(e._lines) do for _, p in ipairs(l.parts) do if p.img then imgs = imgs + 1 end end end
                        seen[dev] = imgs
                    end
                end
            end
            Input.lastDevice, Input.isMobile = realDev, realMob
            check('tut_iconos', seen.keyboard == 1 and seen.gamepad == 1 and seen.touch == 0,
                ('iconos en el cartel de correr: teclado %s · mando %s · dedo %s'):format(tostring(seen.keyboard), tostring(seen.gamepad), tostring(seen.touch)))
        end
        local dark, dkMid = at(315)                                  -- (a medio fundido: aún no del todo)
        local _, dk = at(315); at(315)
        local fullIdx = st.level.sceneIdx
        shot('tutorial_dark')
        local stillDark, dkOut = at(300)                             -- (al salir, la luz vuelve poco a poco)
        local _, _ = at(300); local lit = at(300)
        check('tutorial_cueva', dark and dkMid > 0 and dkMid < 1 and dk > dkMid and fullIdx == 1 and stillDark and dkOut > 0 and dkOut < 1 and not lit and st.level.sceneIdx == nil,
            ('entrando: %.2f → %.2f, escena %s · saliendo: %.2f, sigue a oscuras=%s · fuera: oscuro=%s'):format(dkMid, dk, tostring(fullIdx), dkOut, tostring(stillDark), tostring(lit)))
        gStateMachine:change(ret); wait(0.3)
        local after = name(top())
        check('oferta', first == 'TutorialOfferState' and marked and skip == 'StoryFilmState' and again == 'StoryFilmState'
              and played == 'AdventureState' and lvl == 'assets/levels/tutorial.json' and after == 'StoryFilmState',
            ('1ª vez: %s (marcada=%s) · atrás: %s · 2ª vez: %s · JUGAR: %s %s · al salir del nivel: %s'):format(first, tostring(marked),
             skip, again, played, tostring(lvl), after))
        S.tutorialOffered = keep
        gStateMachine:change('story_slots'); wait(0.5)
    end

    -- ── 4. CONTINUAR ─────────────────────────────────────────────────────
    local Save = require 'src/story/Save'
    for i = 1, Save.SLOTS do Save.delete(i) end
    gStateMachine:change('main_menu')
    local order = {}
    for _, x in ipairs(top().list.items) do order[#order + 1] = x.id end
    check('sin partida', top().slot == nil and table.concat(order, ',') == 'classic,adventure',
          'sin partidas no hay CONTINUAR; orden: ' .. table.concat(order, ','))
    Save.write(2, Save.new('normal'))
    gStateMachine:change('main_menu')
    check('con partida', top().slot == 2 and selId(top()) == 'continue', 'con la partida 2: CONTINUAR, el primero')
    wait(0.6)
    shot('continue')
    press('confirm', 0.9)
    local Run = require 'src/story/Run'
    check('continuar', name(top()) == 'StoryMapState' and Run.slot == 2, ('CONTINUAR → %s (partida %s)'):format(name(top()), tostring(Run.slot)))
    Run.close()
    -- CONTINUAR sigue el ÚLTIMO MODO jugado: la partida escrita más tarde, Flappy o Aventura (las fechas de los archivos
    -- van por segundos: se espera de verdad entre una escritura y otra); con Aventura bloqueada no cuenta la suya
    do
        local FlappySave, FlappyRun = require 'src/flappy/FlappySave', require 'src/flappy/FlappyRun'
        local Campaign = require 'src/flappy/Campaign'
        for i = 1, 3 do FlappySave.delete(i) end
        love.timer.sleep(1.1)
        FlappySave.write(1, FlappySave.new('hard'))
        gStateMachine:change('main_menu'); wait(0.6)
        local m = top()
        local pickF = m.contCampaign == 'flappy' and m.slot == 1 and selId(m) == 'continue'
        press('confirm', 1.2)
        local toF = name(top()) == 'FlappyMapState' and FlappyRun.slot == 1
        FlappyRun.close()
        love.timer.sleep(1.1)
        Save.write(2, Save.new('normal'))
        gStateMachine:change('main_menu'); wait(0.1)
        local pickS = top().contCampaign == 'story' and top().slot == 2
        -- (Aventura bloqueada: aunque la suya sea la más reciente, CONTINUAR va a Flappy)
        local g0 = love.filesystem.read('story.sav')
        local g = Save.global(); g.adventure = nil; Save.writeGlobal(g)
        Campaign.READY = true
        gStateMachine:change('main_menu'); wait(0.1)
        local lockedF = top().contCampaign == 'flappy' and top().slot == 1
        Campaign.READY = false
        if g0 then love.filesystem.write('story.sav', g0) else love.filesystem.remove('story.sav') end
        check('continuar_flappy', pickF and toF and pickS and lockedF,
            ('Flappy la más reciente → CONTINUAR=%s y lleva a su mapa=%s; luego Aventura más reciente → la suya=%s; con Aventura bloqueada → Flappy=%s'):format(
             tostring(pickF), tostring(toF), tostring(pickS), tostring(lockedF)))
        for i = 1, 3 do FlappySave.delete(i) end
    end
    for i = 1, Save.SLOTS do Save.delete(i) end

    -- ── 5. el fondo vivo ─────────────────────────────────────────────────
    gStateMachine:change('main_menu')
    -- DETCHECK2=i: la escena i sin dibujar y dibujando tras cada paso: el primer paso en que difieren y qué entidad
    if os.getenv('DETCHECK2') then
        local i = tonumber(os.getenv('DETCHECK2'))
        local function snap(sc)
            local o = { ('p %.3f %.3f'):format(sc.st.player.x, sc.st.player.y) }
            for k, e in ipairs(sc.st.enemies) do o[#o + 1] = ('%d %s %.3f %.3f %s %s'):format(k, e.def.name, e.x, e.y, tostring(e.state), tostring(e.alive)) end
            return o
        end
        local runs = {}
        for k = 1, 2 do
            MenuScene.reset(i)
            local sc = MenuScene.current()
            runs[k] = {}
            for n = 1, 60 * 60 do
                MenuScene.update(DT)
                if k == 2 then
                    local part = os.getenv('PART')
                    love.graphics.setCanvas(love.graphics.newCanvas(8, 8))
                    if part == 'enemies' then for _, e in ipairs(sc.st.enemies) do if e.alive then e:render(sc.st.camX, sc.st.camY) end end
                    elseif part == 'level' then sc.st.level:render(sc.st.camX, sc.st.camY); sc.st.level:renderFoliage(sc.st.camX, sc.st.camY); sc.st.level:renderFoliageBack(sc.st.camX, sc.st.camY)
                    elseif part == 'player' then sc.st.player:render(sc.st.camX, sc.st.camY)
                    else MenuScene.draw() end
                    love.graphics.setCanvas()
                end
                runs[k][n] = snap(sc)
                if n % 300 == 0 then coroutine.yield() end
            end
        end
        for n = 1, #runs[1] do
            local a, b = runs[1][n], runs[2][n]
            for j = 1, math.max(#a, #b) do
                if a[j] ~= b[j] then print(('   difiere en el paso %d: %s  /  %s'):format(n, tostring(a[j]), tostring(b[j]))); love.event.quit(0); return end
            end
        end
        print('   iguales')
        love.event.quit(0)
        return
    end
    -- FINDSEED=n: para cada nivel de LEVELS (o de SCENES) prueba las semillas 1..n y dice con cuáles llega a la meta
    if os.getenv('FINDSEED') then
        for i, def in ipairs(MenuScene.SCENES) do
            local found = {}
            for seed = 1, tonumber(os.getenv('FINDSEED')) do
                def.seed = seed
                MenuScene.reset(i)
                local sc = MenuScene.current()
                local n = 0
                while not sc.reason and n < (MenuScene.SCENE_MAX + 5) * 60 do
                    MenuScene.update(DT); n = n + 1
                    if n % 900 == 0 then coroutine.yield() end
                end
                if sc.reason == 'meta' then found[#found + 1] = ('%d (%.0f s, %d muertes)'):format(seed, sc.t, sc.st.stats.deaths) end
            end
            print(('   %-22s llega con: %s'):format(def.level, #found > 0 and table.concat(found, ', ') or 'ninguna'))
        end
        love.event.quit(0)
        return
    end
    if os.getenv('SCENES') ~= '0' then
        local json = require 'libs/json'
        for i, def in ipairs(MenuScene.SCENES) do
            -- (solo niveles de CARRERA: modo race, sin zonas de jefe ni de puntos)
            local data = json.decode(love.filesystem.read('assets/levels/' .. def.level .. '.json'))
            local race = false
            for _, m in ipairs(data.modes or {}) do if m == 'race' then race = true end end
            local okData = race and not (data.bossZones and #data.bossZones > 0) and not (data.pointAreas and #data.pointAreas > 0)
            if os.getenv('SEED') then def.seed = tonumber(os.getenv('SEED')) end
            MenuScene.reset(i)
            local sc = MenuScene.current()
            local ok, err = pcall(wait, 1.5)
            if not ok then check('escena ' .. i, false, def.level .. ': ' .. tostring(err)) break end
            shot('scene_' .. i)
            if os.getenv('MENUDBG') and sc.nav then
                local BotNav = require 'src/ai/BotNav'
                local p = sc.st.player
                local from = BotNav.nodeAt(sc.nav, p.x, p.y, p:getOuterBounds().h)
                local goals = sc.bot.goalFn()
                local path = from and BotNav.path(sc.nav, from, goals)
                local ng = 0; for _ in pairs(goals or {}) do ng = ng + 1 end
                -- (lo que se alcanza por el grafo desde la salida: ¿llega a la meta?, ¿hasta qué columna?)
                local sx = sc.st.level.playerStart[1]
                local seen, q, maxc, reach = {}, {}, 0, false
                for id, nd in pairs(sc.nav.nodes) do if math.abs(nd.c - sx) <= 2 then seen[id] = true; q[#q + 1] = id end end
                while #q > 0 do
                    local u = table.remove(q)
                    local nd = sc.nav.nodes[u]
                    if nd and nd.c > maxc then maxc = nd.c end
                    if goals and goals[u] then reach = true end
                    for _, e in ipairs(sc.nav.edges[u] or {}) do if not seen[e.to] then seen[e.to] = true; q[#q + 1] = e.to end end
                end
                print(('   %s: desde %s, %d metas, camino %s; por el grafo desde la salida: meta %s, hasta la columna %d'):format(def.level, tostring(from), ng, path and #path or 'NO', tostring(reach), maxc))
                local die = p.die
                p.die = function(self, ...) if not self.dying then print(('     muere en %d,%d t=%.1f'):format(math.floor(self.x / TILE_PX) + 1, math.floor(self.y / TILE_PX) + 1, sc.t)); 
                    local lv, c0, r0 = sc.st.level, math.floor(self.x / TILE_PX) + 1, math.floor(self.y / TILE_PX) + 1
                    for r = r0 - 4, r0 + 2 do local row = {} for c = c0 - 8, c0 + 8 do local d = lv:getDef(c, r); row[#row + 1] = (c == c0 and r == r0) and '@' or (d.collision == 'solid' and '#' or ((lv:hasSpikeCellInBox((c-1)*TILE_PX+1,(r-1)*TILE_PX+1,TILE_PX-2,TILE_PX-2)) and '^' or (d.trigger and 'T' or '.'))) end print('       ' .. table.concat(row)) end
                    local near, nd = nil, 1e9
                    for _, e in ipairs(lv.liveEntities or {}) do local d = math.abs(e.x - self.x) + math.abs(e.y - self.y); if e.alive and d < nd then near, nd = e, d end end
                    if near then print(('       cerca: %s a %d,%d px (%s), jugador vy %d suelo %s'):format(near.def.name, near.x - self.x, near.y - self.y, tostring(near.state), self.vy, tostring(self.onGround))) end
                    print('       modo ' .. tostring(sc.bot.mode) .. ' edge ' .. tostring(sc.bot.edge and (sc.bot.edge.walk and 'walk' or 'seq')))
                end; return die(self, ...) end
            end
            -- (sin dibujar, a pasos de 1/60 s, hasta que la escena acaba)
            local n = 0
            while MenuScene.current() == sc and not sc.reason and n < (MenuScene.SCENE_MAX + 5) * 60 do
                MenuScene.update(DT); n = n + 1
                if n % 600 == 0 then coroutine.yield() end
            end
            local secs = sc.t
            if os.getenv('MENUDBG') then shot('scene_' .. i .. '_fin') end
            if os.getenv('MENUDBG') and sc.bot then
                local self, lv = sc.st.player, sc.st.level
                local c0, r0 = math.floor(self.x / TILE_PX) + 1, math.floor(self.y / TILE_PX) + 1
                for r = r0 - 5, r0 + 3 do local row = {} for c = c0 - 10, c0 + 10 do local d = lv:getDef(c, r); local id = r * 4096 + c
                    row[#row + 1] = (c == c0 and r == r0) and '@' or (d.collision == 'solid' and '#' or (d.trigger == 'finish' and 'F' or (sc.nav.nodes[id] and 'n' or '.'))) end print('       ' .. table.concat(row)) end
                local b = sc.bot
                print(('       modo %s kind %s camino %s noPath %.1f wander %s onGround %s'):format(tostring(b.mode), tostring(b.kind), b.path and #b.path or 'nil', b.noPathT or 0, tostring(b.wander), tostring(self.onGround)))
            end
            local want = os.getenv('LEVELS') and true or sc.reason == 'meta'
            local fin = 0
            for r = 1, sc.st.level.tileH do for c = 1, sc.st.level.tileW do if sc.st.level:getDef(c, r).trigger == 'finish' then fin = c end end end
            okData = okData and sc.nav ~= nil and not sc.nav.stale          -- (su grafo, al día con el nivel)
            check('escena ' .. i, okData and want and sc.bot ~= nil,
                  ('%-22s %s en %5.1f s, %d muertes, llega a la casilla %d de %d (meta en %d)%s'):format(def.level, tostring(sc.reason), secs, sc.st.stats.deaths,
                  math.floor((sc.maxX or 0) / TILE_PX) + 1, sc.st.level.tileW, fin,
                  okData and '' or ' (NO es un nivel de carrera, o su grafo falta o está desactualizado)'))
        end
        -- la MISMA carrera con el dt real del juego (variable: 144 Hz, 30 Hz, tirones): pasos fijos por dentro
        do
            local def = MenuScene.SCENES[1]
            MenuScene.reset(1)
            local sc = MenuScene.current()
            local dts, n = { 1 / 144, 1 / 30, 1 / 60, 0.05, 1 / 90 }, 0
            while not sc.reason and sc.t < MenuScene.SCENE_MAX + 5 do
                n = n + 1
                MenuScene.update(dts[n % #dts + 1])
                if n % 900 == 0 then coroutine.yield() end
            end
            check('pasos fijos', sc.reason == 'meta', ('%s con dt variable: %s en %.1f s'):format(def.level, tostring(sc.reason), sc.t))
        end
        -- morir: reaparece y las vidas no se acaban
        MenuScene.reset(1)
        wait(1.0)
        local sc = MenuScene.current()
        local p = sc.st.player
        p:die(nil, true)
        local died = false
        for _ = 1, 600 do MenuScene.update(DT); if p.dying then died = true end; if died and p.alive and not p.dying then break end end
        check('muere', died and p.alive and not p.dying and p.lives == 99 and sc.st.stats.deaths == 1,
              ('muere y reaparece (vidas %d, muertes %d)'):format(p.lives, sc.st.stats.deaths))
        -- el iris entre escenas: se cierra sobre el monstruo, a oscuras se carga la siguiente y se abre
        sc.reason = 'prueba'
        wait(MenuScene.IRIS_OUT * 0.6)
        shot('iris')
        wait(MenuScene.IRIS_OUT * 0.4 + MenuScene.HOLD + MenuScene.IRIS_IN + 0.2)
        check('iris', MenuScene.current() ~= sc and MenuScene.current().i == 1 % #MenuScene.SCENES + 1 and not MenuScene.fading(),
              'el iris se cierra, pasa a la escena siguiente y se abre')
    end

    -- ── 6. anchos ────────────────────────────────────────────────────────
    gStateMachine:change('main_menu')
    resize(960, 720); wait(0.8); shot('main_960')
    resize(1600, 720); wait(0.2); shot('main_1600')
    resize(1280, 720)

    -- LA PANTALLA DE CARGA (src/ui/LoadingScreen.lua): en un aparato rápido no sale; marcado como lento, sí, antes de cargar
    do
        local LS = require 'src/ui/LoadingScreen'
        local real, n = LS.present, 0
        LS.present = function() n = n + 1 end
        LS.slow = false
        gStateMachine:change('adventure', { level = 'assets/levels/valle_soleado.json' }); wait(0.1)
        local fastNo = n == 0
        LS.slow = true
        gStateMachine:change('adventure', { level = 'assets/levels/valle_soleado.json' }); wait(0.1)
        local slowYes = n == 1
        LS.present, LS.slow = real, false
        local cv = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
        love.graphics.setCanvas(cv); LS.draw(1.3); love.graphics.setCanvas()
        cv:newImageData():encode('png', 'menu_loading.png')
        gStateMachine:change('main_menu'); wait(0.5)
        check('carga', fastNo and slowYes, ('rápido: no sale=%s · lento: sale antes de cargar=%s'):format(tostring(fastNo), tostring(slowYes)))
    end
    do
        -- (el detector funciona: un texto con [Esc] dibujado a mano se apunta)
        local dev = Input.lastDevice
        Input.lastDevice = 'keyboard'
        love.graphics.printf('[Esc] prueba', 0, 0, 100)             -- (con el teclado: [Esc] es un botón)
        local caught = false
        for where, txt in pairs(plainKeys) do if txt == '[Esc] prueba' then caught = true; plainKeys[where] = nil end end
        Input.lastDevice = dev
        check('iconos_detector', caught, 'un [Esc] dibujado como texto se detecta: ' .. tostring(caught))
        local list = {}
        for where, txt in pairs(plainKeys) do list[#list + 1] = where .. ' «' .. txt:sub(1, 50) .. '»' end
        table.sort(list)
        check('iconos_todo', #list == 0, #list == 0 and 'ningún nombre de botón dibujado como texto' or
            (#list .. ' sitios con el nombre del botón como texto: ' .. table.concat(list, ' · ', 1, math.min(#list, 10))))
    end

    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    print('capturas: ' .. love.filesystem.getSaveDirectory() .. '/menu_*.png')
    love.event.quit(fails == 0 and 0 or 1)
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    MenuScene = require 'src/ui/menu/MenuScene'
    Transition = require 'src/ui/menu/Transition'
    L = require 'src/core/Lang'
    -- options.cfg: guardar y volver a leer da lo mismo (con comillas y acentos en el nombre); un archivo roto no rompe
    -- el arranque (se queda lo que había)
    do
        local Settings = require 'src/core/Settings'
        local keepL, keepN = Settings.language, Settings.onlineName
        local had = love.filesystem.getInfo('options.cfg') and love.filesystem.read('options.cfg')
        Settings.language, Settings.onlineName = 'en', 'Ñandú "x"'
        Settings.save()
        Settings.language, Settings.onlineName = 'es', ''
        Settings.load()
        local rt = Settings.language == 'en' and Settings.onlineName == 'Ñandú "x"'
        love.filesystem.write('options.cfg', 'return { language = ')
        local okLoad = pcall(Settings.load)
        local kept = Settings.language == 'en'
        if had then love.filesystem.write('options.cfg', had) else love.filesystem.remove('options.cfg') end
        Settings.language, Settings.onlineName = keepL, keepN
        L.set(keepL)
        check('opciones', rt and okLoad and kept, ('guardar → leer: idioma y nombre iguales=%s; archivo roto: arranca=%s, conserva=%s'):format(
            tostring(rt), tostring(okLoad), tostring(kept)))
    end
    -- LEVELS=a,b,c: probar otros niveles como escenas (para elegirlas)
    if os.getenv('LEVELS') then
        MenuScene.SCENES = {}
        for lv in os.getenv('LEVELS'):gmatch('[^,]+') do MenuScene.SCENES[#MenuScene.SCENES + 1] = { level = lv } end
    end
    MenuScene.reset(1)
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
        love.graphics.captureScreenshot(function(img) img:encode('png', 'menu_' .. n .. '.png'); wantShot = nil end)
        wantShot = false
    end
end
