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
--  1b. el SOUND TEST secreto (↑↑↓↓←→←→ en el título, o 7 toques en la versión): suena música y un efecto, el tono
--     cambia lo que suena, ATRÁS vuelve al título (captura menu_soundtest.png).
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

local function top() return gStateMachine:_top() end
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
        back = name(top()) == 'TitleState'
        local t = top()
        for _ = 1, 7 do t:touchpressed('dedo', WINDOW_W - 40, WINDOW_H - 20); wait(0.05) end
        wait(0.2)
        taps = name(top()) == 'SoundTestState'
        press('back', 0.6)
    end
    check('soundtest', inST and musicOk and pitchOk and sfxOk and back and taps and TOUCH_ST,
        ('código → %s; música suena=%s; tono 1,05 en lo que suena=%s; efectos suena=%s; atrás → título=%s; 7 toques en la versión → entra=%s; con el dedo: %s'):format(
         name(stt), tostring(musicOk), tostring(pitchOk), tostring(sfxOk), tostring(back), tostring(taps), tostring(TOUCH_MSG)))
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
    go('classic', 'DifficultySelectionState', 'difficulty')
    press('back', 0.6)
    check('vuelve cla', selId(top()) == 'classic', 'atrás → menú con CLÁSICO elegido: ' .. tostring(selId(top())))
    go('settings', 'SettingsState', 'settings')
    local lang0 = L.current()
    press('nav_right', 0.3)
    local lang1 = L.current()
    shot('settings_lang')
    press('nav_left', 0.3)
    check('idioma', lang1 ~= lang0 and L.current() == lang0, ('%s → %s → %s'):format(lang0, lang1, L.current()))
    press('back', 0.6)
    check('vuelve cfg', selId(top()) == 'settings', 'atrás → menú con CONFIGURACIÓN elegido: ' .. tostring(selId(top())))

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

    -- ── 4. CONTINUAR ─────────────────────────────────────────────────────
    local Save = require 'src/story/Save'
    for i = 1, Save.SLOTS do Save.delete(i) end
    gStateMachine:change('main_menu')
    check('sin partida', top().slot == nil and selId(top()) == 'adventure', 'sin partidas no hay CONTINUAR')
    Save.write(2, Save.new('normal'))
    gStateMachine:change('main_menu')
    check('con partida', top().slot == 2 and selId(top()) == 'continue', 'con la partida 2: CONTINUAR, el primero')
    wait(0.6)
    shot('continue')
    press('confirm', 0.9)
    local Run = require 'src/story/Run'
    check('continuar', name(top()) == 'StoryMapState' and Run.slot == 2, ('CONTINUAR → %s (partida %s)'):format(name(top()), tostring(Run.slot)))
    Run.close()
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
