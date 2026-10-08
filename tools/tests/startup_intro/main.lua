-- tools/tests/startup_intro — la PANTALLA DE INICIO (src/states/menu/StartupState.lua) con el juego real:
--  1. el juego arranca en `update` y de ahí va a `startup` (no al título directamente);
--  2. a pasos fijos de 1/60 s: empieza en NEGRO, llega a BLANCO sin letras antes de la primera nota, la melodía
--     suena UNA vez y justo con la primera letra, con el acorde están las seis letras, acaba en NEGRO y pasa al
--     título en lo que dice StartupState:total() + T_OUT;
--  3. las seis piezas de assets/startup/logo.json existen y la melodía dura al menos hasta el final del logo;
--  4. SALTAR: un botón a media animación funde a negro y llega al título en T_SKIP; la melodía se corta.
-- Capturas: <save>/startup_<n>.png          tools/tests/run.sh startup_intro
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameDraw = love.load, love.draw

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local S, state, realInput
local plays, stops, steps, phase, want = 0, 0, 0, 'run', nil
local POINTS, got = {}, {}

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    S = require 'src/states/menu/StartupState'
    local first = gStateMachine:_top()
    check('arranque', first.after == 'startup', 'el estado de actualización pasa después a: ' .. tostring(first.after))
    local json = require 'libs/json'
    local data = json.decode(love.filesystem.read('assets/startup/logo.json'))
    local n = 0
    for _, p in ipairs(data.parts) do if love.filesystem.getInfo('assets/startup/parts/' .. p.file) then n = n + 1 end end
    local src = love.audio.newSource('assets/sounds/jingles/startup.wav', 'static')
    check('archivos', n == 6 and #data.parts == 6 and src:getDuration() >= 0.90 + 1.0, ('%d/6 letras; melodía de %.2f s'):format(n, src:getDuration()))
    local pt, st = Sound.playTracked, Sound.stopTracked
    Sound.playTracked = function(name, ...) if name == 'startup' then plays = plays + 1; got.playAt = state and state.t end; return pt(name, ...) end
    Sound.stopTracked = function(name, ...) if name == 'startup' then stops = stops + 1 end; return st(name, ...) end
    gStateMachine:change('startup')
    state = gStateMachine:_top()
    local total = state:total()
    -- (momento, nombre): se mira la pantalla en cada uno
    POINTS = { { 0.02, 'negro' }, { S.T_FIRST - 0.03, 'blanco' }, { S.T_FIRST + 0.4, 'medio' }, { total - 0.2, 'entero' },
               { total + S.T_OUT - 0.02, 'fin' } }
end

-- cuánto negro hay en la franja central y de qué color es la esquina
local function look(img)
    local w, h = img:getDimensions()
    local dark, n = 0, 0
    for y = math.floor(h * 0.3), math.floor(h * 0.7), 3 do
        for x = math.floor(w * 0.15), math.floor(w * 0.85), 3 do
            local r, g, b = img:getPixel(x, y)
            n = n + 1
            if r + g + b < 0.6 then dark = dark + 1 end
        end
    end
    local r, g, b = img:getPixel(math.floor(w / 2), math.floor(h * 0.08))
    return dark / n, (r + g + b) / 3
end

function love.update(dt)
    if want then return end
    if phase == 'run' then
        for _ = 1, 600 do
            if gStateMachine:_top() ~= state then break end
            state:update(1 / 60); steps = steps + 1
            if POINTS[1] and state.t >= POINTS[1][1] then want = table.remove(POINTS, 1)[2]; return end
        end
        local total = state:total() + S.T_OUT
        check('negro', got.negro and got.negro.bg < 0.08, ('fondo al empezar: %.2f'):format(got.negro and got.negro.bg or -1))
        check('blanco', got.blanco and got.blanco.bg > 0.97 and got.blanco.ink < 0.001, ('antes de la primera nota: fondo %.2f, tinta %.4f'):format(got.blanco.bg, got.blanco.ink))
        check('letras', got.medio.ink > 0.01 and got.entero.ink > got.medio.ink * 1.3, ('tinta a media melodía %.3f, con el logo entero %.3f'):format(got.medio.ink, got.entero.ink))
        check('melodia', plays == 1 and math.abs((got.playAt or -1) - S.T_FIRST) < 0.03, ('suena %d vez, a los %.2f s (primera letra a %.2f)'):format(plays, got.playAt or -1, S.T_FIRST))
        check('final', got.fin.bg < 0.08 and gStateMachine:_top() ~= state and math.abs(steps / 60 - total) < 0.05,
              ('último fotograma: fondo %.2f; pasa al título a los %.2f s (previsto %.2f)'):format(got.fin.bg, steps / 60, total))
        phase = 'skip'
    elseif phase == 'skip' then
        gStateMachine:change('startup')
        state = gStateMachine:_top()
        plays, stops = 0, 0
        local press = false
        Input = setmetatable({ pressed = function(a) return press and a == 'confirm' end }, { __index = realInput })
        for _ = 1, 70 do state:update(1 / 60) end           -- (ya suena)
        press = true; state:update(1 / 60); press = false
        local n = 0
        while gStateMachine:_top() == state and n < 300 do state:update(1 / 60); n = n + 1 end
        Input = realInput
        check('saltar', math.abs(n / 60 - S.T_SKIP) < 0.05 and stops == 1 and plays == 1, ('al título %.2f s después de pulsar (T_SKIP %.2f); melodía cortada %d vez'):format(n / 60, S.T_SKIP, stops))
        print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
        love.event.quit(fails == 0 and 0 or 1)
    end
end

function love.draw()
    if phase == 'run' and state and gStateMachine:_top() ~= state and not want then return gameDraw() end
    gameDraw()
    if want then
        local name = want
        love.graphics.captureScreenshot(function(img)
            local ink, bg = look(img)
            got[name] = { ink = ink, bg = bg }
            img:encode('png', 'startup_' .. name .. '.png')
            want = nil
        end)
    end
end
