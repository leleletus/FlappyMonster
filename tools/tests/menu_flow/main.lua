-- tools/tests/menu_flow — LOS MENÚS (docs/architecture/menus.md) con el juego real, a pasos fijos de 1/60 s:
--  1. título: las letras del logo caen y aparece "Presiona..."; al pulsar se abre el menú (el logo sube, entran
--     los botones); atrás vuelve al título;
--  2. cada botón lleva a su pantalla tras la animación de salida (Aventura, Clásico, Configuración) y desde ella
--     ATRÁS vuelve al menú principal con ese botón elegido; Configuración cambia el idioma y lo devuelve;
--  3. Aventura → Historia pasa por la TRANSICIÓN de bloques: mientras tapa, el estado de abajo no se actualiza y
--     al destapar ya está la pantalla de partidas (con el fondo vivo y el panel);
--  4. CONTINUAR: solo con una partida guardada; abre la más reciente y va al mapa de la historia;
--  5. el FONDO VIVO: cada escena de MenuScene.SCENES carga su nivel, el monstruo avanza (al menos MIN_TILES
--     casillas) y la escena acaba sola; el fundido de píxeles entre dos escenas;
--  6. capturas a 1280, 960 y 1600 de ancho.
-- Capturas: <save>/menu_*.png                tools/tests/run.sh menu_flow   (SCENES=0: sin el paso 5;
--   LEVELS=a,b,c: el paso 5 con esos niveles en vez de MenuScene.SCENES, para elegir escenas nuevas)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local DT = 1 / 60
local MIN_TILES = 8
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

    -- ── 3. transición de bloques: Aventura → Historia ────────────────────
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
    check('bloques', covered and frozen and name(top()) == 'StorySlotState',
          ('tapa en %.2f s sin actualizar la pantalla de abajo; luego %s'):format(frames * DT, name(top())))
    wait(0.25)
    shot('transition')
    wait(0.4)
    check('destapa', not Transition.active(), 'la transición termina')
    shot('story_slots')

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
    if os.getenv('SCENES') ~= '0' then
        for i, def in ipairs(MenuScene.SCENES) do
            MenuScene.reset(i)
            local sc = MenuScene.current()
            local x0 = sc.actor.body.x
            local ok, err = pcall(wait, 1.2)
            if not ok then check('escena ' .. i, false, def.level .. ': ' .. tostring(err)) break end
            shot('scene_' .. i)
            local secs = 1.2
            while MenuScene.current() == sc and not MenuScene.fading() and secs < MenuScene.SCENE_TIME + 1 do wait(0.5); secs = secs + 0.5 end
            if MenuScene.current() == sc then shot('scene_' .. i .. '_fin') end
            local tiles = (sc.actor.body.x - x0) / TILE_PX
            -- (las escenas de verdad no pueden acabar porque el monstruo se atasque; con LEVELS= solo se informa)
            local stuckOk = os.getenv('LEVELS') or sc.endReason ~= 'atascado'
            check('escena ' .. i, tiles >= MIN_TILES and stuckOk and secs <= MenuScene.SCENE_TIME + 0.5,
                  ('%-22s avanza %5.1f casillas en %4.1f s (%s)'):format(def.level, tiles, secs, sc.endReason or '?'))
        end
        wait(MenuScene.FADE * 0.5)
        shot('fade')
        wait(MenuScene.FADE)
        check('fundido', not MenuScene.fading(), 'el fundido de píxeles acaba')
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
