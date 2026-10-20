-- tools/tests/story_film — las CINEMÁTICAS de la historia con el juego real (src/story/Film.lua):
--  1. las películas (intro, final, persecución y guarida) se reproducen ENTERAS por el estado de verdad (story_film), a pasos fijos de 1/60 s,
--     sin errores, pasando por todas las escenas en orden y llamando a onDone al acabar;
--  2. cada escena dura lo que dice assets/story/films.json;
--  3. tres capturas por escena (al 20 %, 55 % y 88 %): <save>/film_<película>_<nn>_<escena>_<k>.png
--  4. RELOJ: con su música sonando, la película sigue el reloj de la música (desfase < 0,08 s);
--  5. SALTAR: manteniendo pulsado 1 s se sale; un toque corto no.
--  5b. LAVA: en las películas con actores (persecución, guarida) ninguno se hunde en la lava al saltarla.
--  6. ENLACE: una película con `next` (la de antes de un nivel) deja sonando al acabar la música de ese nivel, y el
--     nivel, al pedir la suya, la SIGUE (no vuelve a empezar).
--  7. LOS CRÉDITOS (credits): la música dura lo que la película; cada bloque de texto entra por abajo al empezar su
--     canción y cabe en ella; el último ha salido por arriba antes de la subida del Espejo.
--   tools/tests/run.sh story_film [FILM=intro|ending|chase|lair|credits] [XTRA=1] [NOSHOTS=1]
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameDraw = love.load, love.draw

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local FILMS = os.getenv('FILM') and { os.getenv('FILM') } or { 'intro', 'ending', 'chase', 'lair', 'credits' }
local XTRA, NOSHOTS = os.getenv('XTRA') == '1', os.getenv('NOSHOTS') == '1'
local fi, state, done, shots, seen, pending, phase = 0, nil, false, {}, {}, nil, 'film'
local realInput, holdT, clockT, worst
local NEXT1, P0, sink

local function start()
    fi = fi + 1
    local name = FILMS[fi]
    if not name then phase = 'clock'; return end
    done, seen, sink = false, {}, 0
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
            for _, a in ipairs({ film.shared.m or false, film.shared.r or false }) do
                if a and not a.hidden then sink = math.max(sink, a.body.y - require('src/story/films/common').LFLOOR) end
            end
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
            if film.name == 'credits' then
                -- LOS CRÉDITOS: la música dura lo que la película; cada bloque de texto entra por abajo al empezar su
                -- canción y cabe en ella; el último ha salido por arriba cuando empieza la subida del Espejo
                local C = require 'src/story/films/credits'
                local lay = C._layout(film.ctx)
                local src = love.audio.newSource('assets/music/story/story_credits.ogg', 'stream')
                local dur = src:getDuration()
                check('creditos', math.abs(dur - tl.total) < 0.05, ('música %.2f s, película %.2f s'):format(dur, tl.total))
                local bad, rise = {}, nil
                for _, sc in ipairs(tl.scenes) do if sc.id == 'rise' then rise = sc end end
                for _, b in ipairs(lay.blocks) do
                    local yIn = b.y - C._scrollAt(film.ctx, b.sc.t0)
                    local fits = b.h <= lay.v * b.sc.dur
                    if math.abs(yIn - WINDOW_H * 0.92) > 2 or not fits then bad[#bad + 1] = b.sc.id end
                end
                local last = lay.blocks[#lay.blocks]
                local out = last.y + last.h - C._scrollAt(film.ctx, rise.t0) < 0
                check('bloques', #bad == 0 and out, ('%d bloques a %.0f px/s; entran al empezar su canción y caben: %s; el último fuera antes del Espejo=%s'):format(
                    #lay.blocks, lay.v, #bad == 0 and 'sí' or table.concat(bad, ' '), tostring(out)))
            end
            if film.shared.m then check('lava', sink < 2, ('%s: lo más que se hunde un actor bajo el suelo: %.1f px'):format(film.name, sink)) end
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
        phase, clockT = 'handoff', nil
    elseif phase == 'handoff' then
        -- (con sonido de verdad, a volumen 0) la película acaba → suena ya la pista del nivel; el nivel la sigue
        if not clockT then
            gStateMachine:change('story_film', { film = 'chase', onDone = function() end })
            state = gStateMachine:_top(); clockT = 0
            state:_finish()
            NEXT1 = select(1, Sound.musicPosition())
            Sound.setLevelMusic(nil); Sound.setBaseLevelMusic('mirror_chase')
        else
            clockT = clockT + dt
            if clockT > 0.6 and not P0 then P0 = select(2, Sound.musicPosition()); Sound.playMusic('level') end
            if clockT > 1.0 then
                local name, pos = Sound.musicPosition()
                check('enlace', NEXT1 == 'mirror_chase' and name == 'mirror_chase' and P0 ~= nil and pos ~= nil and pos > P0,
                      ('al acabar la película suena %s; el nivel pide la suya y sigue sonando %s en %.2f s (antes %.2f: no vuelve a empezar)'):format(
                       tostring(NEXT1), tostring(name), pos or -1, P0 or -1))
                Sound.stopMusic()
                print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
                love.event.quit(fails == 0 and 0 or 1)
            end
        end
    end
end

function love.draw()
    gameDraw()
    if pending then
        love.graphics.captureScreenshot(pending .. '.png')
        pending = nil
    end
end
