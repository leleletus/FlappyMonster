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
--     canción y cabe en ella; el último ha salido por arriba antes de la subida del Espejo; los 8 ESCENARIOS VIVOS
--     se juegan y en ellos pasan cosas (≥ 8 enemigos muertos, ≥ 2 explosiones, el monstruo muere alguna vez).
--  8. STAGES=1: solo los ESCENARIOS VIVOS de los créditos (src/story/LiveStage.lua): cada uno 25 s a pasos fijos,
--     sin errores, con lo que pasa (enemigos que mueren, explosiones, muertes del monstruo) y 4 capturas
--     (<save>/stage_<nombre>_<k>.png) sobre el fondo de ladrillos; STAGE=credits_pradera para uno solo; CRAWLDBG=1
--     escribe dónde van los trepadores (normal 0,1 = boca abajo, en un techo)
--   tools/tests/run.sh story_film [FILM=intro|ending|chase|lair|credits] [XTRA=1] [NOSHOTS=1] [STAGES=1 [STAGE=x]]
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

-- (los escenarios vivos que crea la película de los créditos: para contar lo que pasa en ellos)
LIVE = {}
MUSICS = {}
do
    local LS = require 'src/story/LiveStage'
    local new = LS.new
    LS.new = function(...) local s = new(...); LIVE[#LIVE + 1] = s; return s end
end

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
        -- (el final de los créditos, más: el vuelo, el golpe, pegado al cristal, resbalando, cayendo, el gracias)
        local fr = (sc.id == 'finale') and { 0.06, 0.09, 0.13, 0.25, 0.4, 0.5, 0.75 } or { 0.2, 0.55, 0.88 }
        for k, f in ipairs(fr) do
            shots[#shots + 1] = { t = sc.t0 + sc.dur * f, name = ('film_%s_%02d_%s_%d'):format(name, sc.index, sc.id, k) }
        end
    end
end

function love.load(a)
    gameLoad(a)
    if os.getenv('STAGES') then
        for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
        love.audio.setVolume(0)
        return
    end
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed', 'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    local Save, Run = require 'src/story/Save', require 'src/story/Run'
    Save.delete(1)
    Run.open(1, XTRA and 'xtra' or 'normal')
    start()
end

-- ── STAGES=1: los escenarios vivos de los créditos ──────────────────────────
-- ── FIGHT=1: la pelea del final de los créditos (src/story/CreditsFight.lua) sola: cada golpe, cuándo cae ──
local FG
local function fightUpdate()
    if not FG then
        local F = require 'src/story/films/credits'
        FG = { st = F._newFight(), f = 0, t = 0 }
        FG.st:draw(F._fightY(FG.st), 0)                   -- (la cámara antes del primer paso, como en la película)
        for _, e in ipairs(FG.st.st.enemies) do if e.def.name == 'mirror' then FG.boss = e end end
        FG.hp, FG.state = FG.boss.hp, FG.boss.state
        print(('  pelea: Espejo con %d de vida'):format(FG.hp))
    end
    -- (FPS=n: otro ritmo de cuadros —con tirones si n no divide a 60—; la pelea tiene que salir igual)
    local fdt = 1 / (tonumber(os.getenv('FPS')) or 60)
    FG.st:update(fdt)
    FG.f, FG.t = FG.f + 1, FG.t + fdt
    local b, t = FG.boss, FG.t
    if b.hp ~= FG.hp then print(('  t=%5.2f golpe: %d → %d (%s)'):format(t, FG.hp, b.hp, b.state)); FG.hp = b.hp end
    if b.state ~= FG.state then
        if os.getenv('FIGHTDBG') or b:isDying() then print(('  t=%5.2f Espejo: %s'):format(t, b.state)) end
        FG.state = b.state
        if b:isDying() and not FG.defeat then FG.defeat = t end
    end
    if os.getenv('FIGHTDBG') and FG.f % (tonumber(os.getenv('FIGHTDBG')) or 15) == 0 then
        local p = FG.st.st.player
        print(('    t=%5.2f monstruo x=%d y=%d vy=%d gp=%s modo=%s · espejo x=%d y=%d %s inv=%.1f'):format(t, p.x, p.y, p.vy, tostring(p.gpPhase), FG.st.bot.mode, b.x, b.y, b.state, b.inv or 0))
    end
    if FG.f % 60 == 0 and os.getenv('NOSHOTS') == nil then FG.shot = ('fight_%02d'):format(FG.f / 60) end
    if FG.t >= (tonumber(os.getenv('SECS')) or 22) then
        local T = 48 * 60 / 158                              -- (la música de la pelea: 16 + 32 pulsos a 158)
        check('pelea', FG.defeat ~= nil and FG.defeat <= T + 0.05 and FG.defeat >= T - 3.2,
            ('vencido a los %s s (la música de la pelea dura %.2f s: tiene que caer en sus 3,2 s últimos: luego explota hasta que se lo lleva el final)'):format(
            FG.defeat and ('%.2f'):format(FG.defeat) or 'nunca', T))
        print(fails == 0 and 'TODO OK' or ('FALLAN %d'):format(fails))
        love.event.quit(fails == 0 and 0 or 1)
        FG.done = true
    end
end

local STG
local function stagesUpdate()
    if not STG then
        local list = os.getenv('STAGE') and { os.getenv('STAGE') } or
            { 'credits_pradera', 'credits_costa', 'credits_fortaleza', 'credits_nieve', 'credits_cuevas', 'credits_volcan', 'credits_crab', 'credits_bola' }
        STG = { list = list, i = 0, f = 0 }
    end
    if not STG.cur then
        STG.i = STG.i + 1
        local nm = STG.list[STG.i]
        if not nm then
            print(fails == 0 and 'TODO OK' or ('FALLAN %d'):format(fails))
            love.event.quit(fails == 0 and 0 or 1)
            STG.done = true
            return
        end
        STG.cur, STG.f, STG.name = require('src/story/LiveStage').new(nm, 11), 0, nm
        if os.getenv('JUMPDBG') then                     -- (cada sonido de salto: dónde, en el suelo o no, y el objetivo)
            local snd, cur = STG.cur.sound, STG.cur
            local play = snd.play
            snd.play = function(name, ...)
                if name == 'jump' then
                    local p = cur.st.player
                    print(('  J %4d x=%d y=%d suelo=%s vy=%d quedan=%s obj=%s'):format(STG.f, p.x, p.y, tostring(p.onGround),
                        p.vy, tostring(p.jumpsLeft), cur.goal and math.floor(cur.goal.x) or '-'))
                end
                return play(name, ...)
            end
        end
    end
    STG.cur:update(1 / 60)
    STG.f = STG.f + 1
    if os.getenv('CRAWLDBG') and STG.f % 30 == 0 then      -- (los que trepan: dónde van y hacia dónde miran sus patas)
        for _, e in ipairs(STG.cur.st.enemies) do
            if e.crawl then print(('  C %d %s x=%d y=%d normal=%s,%s st=%s'):format(STG.f, e.def.name, e.x, e.y, tostring(e.cnx), tostring(e.cny), tostring(e.state))) end
        end
    end
    if os.getenv('BOTDBG') and STG.f % (tonumber(os.getenv('BOTDBG')) or 10) == 0 then      -- (el bot: qué hace, cada 10 cuadros)
        local b, p = STG.cur.bot, STG.cur.st.player
        local BotNav = require 'src/ai/BotNav'
        local cur = p.onGround and BotNav.nodeAt(b.nav, p.x, p.y, b:_h())
        local e = b.path and b.path[1]
        print(('  B %4d x=%d y=%d suelo=%s agua=%s nodo=%s→%s %s arista=%s f=%s modo=%s tipo=%s atasco=%.1f sinCamino=%.1f'):format(STG.f, p.x, p.y,
            tostring(p.onGround), tostring(p.inWater), tostring(cur), e and tostring(e.to) or '-', e and (e.walk and 'andar' or 'grabado') or '',
            b.edge and tostring(b.edge.to) or '-', tostring(b.edgeF), tostring(b.mode), tostring(b.kind), b.stuckT or 0, b.noPathT or 0) .. ' macro=' .. tostring(b.macro and #b.macro) .. ' bits=' .. tostring(b.prevBits) .. ' atrás=' .. tostring(b.backN) .. ' meta=' .. tostring(STG.cur.goal and math.floor(STG.cur.goal.x)))
    end
    if os.getenv('STAGEDBG') and STG.f % 60 == 0 then
        for _, e in ipairs(STG.cur.st.enemies) do
            if e.def.boss then print(('  t=%d %s estado=%s x=%d en pelea=%s'):format(STG.f / 60, e.def.name, tostring(e.state), e.x, tostring(e.inFight and e:inFight()))) end
        end
    end
    if STG.f % 375 == 0 then STG.shot = ('stage_%s_%d'):format(STG.name, STG.f / 375) end
    if STG.f >= 1500 then
        local s = STG.cur.stats
        -- (el bot del menú, de paseo: varios objetivos en 25 s, no solo de lado a lado)
        -- (y no salta en el sitio: ≤ 3 saltos que suenan en el mismo sitio en 3 s —salía de una charca así, sin parar—;
        -- ni tiembla: ≤ 5 cambios de sentido en 1 s)
        check('escenario', s.goals >= 4 and s.inPlace <= 3 and s.flips <= 5, ('%s: %d enemigos muertos, %d explosiones, %d muertes del monstruo, %d objetivos, %d saltos, en el sitio como mucho %d, cambios de sentido en 1 s como mucho %d'):format(
            STG.name, s.kills, s.booms, s.deaths, s.goals, s.jumps, s.inPlace, s.flips))
        STG.cur = nil
    end
end

function love.update(dt)
    if os.getenv('FIGHT') then if not (FG and FG.done) then fightUpdate() end; return end
    if os.getenv('STAGES') then if not (STG and STG.done) then stagesUpdate() end; return end
    if pending then return end
    if phase == 'film' then
        local film = state.film
        local nextShot = (not NOSHOTS) and shots[1] or nil
        for _ = 1, 240 do
            if done then break end
            state:update(1 / 60)
            -- (en los créditos nadie más toca la música: la película va muda aquí, así que cualquier pista que suene la
            -- ha pedido otro — un escenario vivo al reaparecer el monstruo cortaba la de los créditos —)
            if film.name == 'credits' then
                local mn = Sound.musicPosition()
                if mn then MUSICS[mn] = true end
            end
            for _, a in ipairs({ film.shared.m or false, film.shared.r or false }) do
                if a and not a.hidden then sink = math.max(sink, a.body.y - require('src/story/films/common').LFLOOR) end
            end
            local sc = film:scene()
            if sc and not seen[sc.index] then seen[sc.index] = true end
            -- (la pelea del final: cuándo cae el Espejo, desde que empieza la escena 'fight')
            if film.name == 'credits' and film.shared.boss and not FIGHT_KO and film.shared.boss:isDying()
               and film:scene() and film:scene().id ~= 'finale' then
                FIGHT_KO = film.t - (film.shared.fightT0 or film.t)
            end
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
                -- canción y cabe en ella; el último ha salido por arriba cuando empieza la pelea final
                local C = require 'src/story/films/credits'
                local lay = C._layout(film.ctx)
                local src = love.audio.newSource('assets/music/story/story_credits.ogg', 'stream')
                local dur = src:getDuration()
                check('creditos', math.abs(dur - tl.total) < 0.05, ('música %.2f s, película %.2f s'):format(dur, tl.total))
                local bad, fight = {}, nil
                for _, sc in ipairs(tl.scenes) do if sc.id == 'fight' then fight = sc end end
                for _, b in ipairs(lay.blocks) do
                    local yIn = b.y - C._scrollAt(film.ctx, b.sc.t0)
                    local fits = b.h <= lay.v * b.sc.dur
                    if math.abs(yIn - WINDOW_H * 0.92) > 2 or not fits then bad[#bad + 1] = b.sc.id end
                end
                local last = lay.blocks[#lay.blocks]
                local out = last.y + last.h - C._scrollAt(film.ctx, fight.t0) < 0
                check('bloques', #bad == 0 and out, ('%d bloques a %.0f px/s; entran al empezar su canción y caben: %s; el último fuera antes de la pelea=%s'):format(
                    #lay.blocks, lay.v, #bad == 0 and 'sí' or table.concat(bad, ' '), tostring(out)))
                -- los ESCENARIOS VIVOS: se jugaron todos y pasaron cosas (enemigos muertos, explosiones, el monstruo muere)
                local n, k, bo, d = 0, 0, 0, 0
                for _, st in ipairs(LIVE) do
                    if st.name ~= 'credits_espejo' then n = n + 1; k = k + st.stats.kills; bo = bo + st.stats.booms; d = d + st.stats.deaths end
                end
                local other = {}
                for mn in pairs(MUSICS) do if mn ~= 'story_credits' then other[#other + 1] = mn end end
                check('musica', #other == 0, 'nadie pide otra música durante los créditos: ' .. (#other == 0 and 'sí' or table.concat(other, ', ')))
                check('escenarios', n == 8 and k >= 8 and bo >= 2 and d >= 1,
                      ('%d escenarios vivos jugados: %d enemigos muertos, %d explosiones, %d muertes del monstruo'):format(n, k, bo, d))
            end
            if film.name == 'credits' then
                -- EL FINAL: la pelea se jugó, el Espejo cayó en ella (no por el seguro del final: FIGHT=1 dice cuándo) y
                -- la película se lo llevó volando hasta estrellarlo contra la pantalla
                local sh = film.shared
                local m = sh.boss
                check('final', sh.fight ~= nil and m ~= nil and FIGHT_KO ~= nil and sh.flyFrom ~= nil and m.alive == false,
                      ('pelea jugada=%s · el Espejo vencido en la pelea a los %s s · se lo lleva volando=%s'):format(tostring(sh.fight ~= nil),
                      FIGHT_KO and ('%.2f'):format(FIGHT_KO) or 'nunca', tostring(sh.flyFrom ~= nil)))
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
    if os.getenv('FIGHT') then
        lovesize.begin()
        require('src/story/Stage').flappyBg(FG and FG.f or 0, { 0.35, 0.55, 0.85 })
        if FG and FG.st then FG.st:draw(require('src/story/films/credits')._fightY(FG.st)) end
        lovesize.finish()
        if FG and FG.shot then love.graphics.captureScreenshot(FG.shot .. '.png'); FG.shot = nil end
        return
    end
    if os.getenv('STAGES') then
        lovesize.begin()
        require('src/story/Stage').flappyBg(STG and STG.f or 0, { 0.35, 0.55, 0.85 })
        if STG and STG.cur then STG.cur:draw(300) end
        lovesize.finish()
        if STG and STG.shot then love.graphics.captureScreenshot(STG.shot .. '.png'); STG.shot = nil end
        return
    end
    gameDraw()
    if pending then
        love.graphics.captureScreenshot(pending .. '.png')
        pending = nil
    end
end
