-- tools/tests/story_film — las CINEMÁTICAS de la historia con el juego real (src/story/Film.lua):
--  1. la intro y el final se reproducen ENTEROS por el estado de verdad (story_film), a pasos fijos de 1/60 s,
--     sin errores, pasando por todas las escenas en orden y llamando a onDone al acabar;
--  2. cada escena dura lo que dice assets/story/films.json;
--  3. tres capturas por escena (al 20 %, 55 % y 88 %): <save>/film_<película>_<nn>_<escena>_<k>.png
--  4. RELOJ: con su música sonando, la película sigue el reloj de la música (desfase < 0,08 s);
--  5. SALTAR: manteniendo pulsado 1 s se sale; un toque corto no.
--   tools/tests/run.sh story_film [FILM=intro|ending] [XTRA=1] [NOSHOTS=1]
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameDraw = love.load, love.draw

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local FILMS = os.getenv('FILM') and { os.getenv('FILM') } or { 'intro', 'ending' }
local XTRA, NOSHOTS = os.getenv('XTRA') == '1', os.getenv('NOSHOTS') == '1'
local fi, state, done, shots, seen, pending, phase = 0, nil, false, {}, {}, nil, 'film'
local realInput, holdT, clockT, worst

local function start()
    fi = fi + 1
    local name = FILMS[fi]
    if not name then phase = 'clock'; return end
    done, seen = false, {}
    gStateMachine:change('story_film', { film = name, xtra = XTRA, onDone = function() done = true end })
    state = gStateMachine:_top()
    state.film.mute = true
    shots = {}
    for _, sc in ipairs(state.film.tl.scenes) do
        for k, f in ipairs({ 0.2, 0.55, 0.88 }) do
            shots[#shots + 1] = { t = sc.t0 + sc.dur * f, name = ('film_%s_%02d_%s_%d'):format(name, sc.index, sc.id, k) }
        end
    end
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    local Save, Run = require 'src/story/Save', require 'src/story/Run'
    Save.delete(1)
    Run.open(1, XTRA and 'xtra' or 'normal')
    start()
end

function love.update(dt)
    if pending then return end
    if phase == 'film' then
        local film = state.film
        local nextShot = (not NOSHOTS) and shots[1] or nil
        for _ = 1, 240 do
            if done then break end
            state:update(1 / 60)
            local sc = film:scene()
            if sc and not seen[sc.index] then seen[sc.index] = true end
            if nextShot and film.t >= nextShot.t then
                table.remove(shots, 1); pending = nextShot.name; return
            end
        end
        if done then
            local n = 0
            for _ in pairs(seen) do n = n + 1 end
            local tl = film.tl
            check(film.name, n == #tl.scenes and math.abs(film.t - tl.total) < 0.1,
                  ('%d/%d escenas, %.2f s de %.2f'):format(n, #tl.scenes, film.t, tl.total))
            start()
        end
    elseif phase == 'clock' then
        -- con SONIDO de verdad (volumen 0): suena su música y el reloj de la película es el de la música
        if not clockT then
            gStateMachine:change('story_film', { film = 'intro', onDone = function() end })
            state = gStateMachine:_top(); clockT, worst = 0, 0
        else
            clockT = clockT + dt
            state:update(dt)
            local name, pos = Sound.musicPosition()
            if clockT > 0.5 and pos then worst = math.max(worst, math.abs(pos - state.film.t)) end
            if clockT > 4 then
                check('reloj', name == 'story_intro' and pos ~= nil and worst < 0.08,
                      ('suena %s; la película va a %.2f s y la música a %.2f s; desfase máximo %.3f s'):format(tostring(name), state.film.t, pos or -1, worst))
                phase = 'skip'
            end
        end
    elseif phase == 'skip' then
        -- un toque corto no la salta; mantenerlo 1 s, sí
        done = false
        gStateMachine:change('story_film', { film = 'intro', onDone = function() done = true end })
        state = gStateMachine:_top(); state.film.mute = true
        local down = false
        Input = setmetatable({ down = function(a) return down and a == 'confirm' end, pressed = function() return false end }, { __index = realInput })
        down = true; for _ = 1, 20 do state:update(1 / 60) end
        down = false; for _ = 1, 30 do state:update(1 / 60) end
        local short = done
        down = true; for _ = 1, 70 do if not done then state:update(1 / 60) end end
        Input = realInput
        check('saltar', not short and done, ('toque corto la salta=%s, mantener 1 s la salta=%s'):format(tostring(short), tostring(done)))
        print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
        love.event.quit(fails == 0 and 0 or 1)
    end
end

function love.draw()
    gameDraw()
    if pending then
        love.graphics.captureScreenshot(pending .. '.png')
        pending = nil
    end
end
