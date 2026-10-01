-- tools/tests/boss_intro — la ENTRADA del jefe (cualquiera; con el Mega Crabby
-- además sus emotes y súbditos). Con
-- las clases reales y dos jugadores dentro de la zona (uno justo en el sitio
-- donde está colocado el jefe, para que tenga que caer en otro lado):
--   congelados  durante 'intro' los jugadores no se mueven aunque pulsen
--               derecha y salto (la gravedad sí actúa)
--   silencio    BossZones.music = SILENCE durante la entrada, luego la del jefe
--   orden       dormant → fall_in → land_in → roar_in → ready → chase
--   intocable   escondido y cayendo no es sólido ni activo
--   lejos       aterriza a más de INTRO_SAFE casillas de todos; nadie sufre daño
--   sonidos     megaFall y megaRoar
--   libres      al empezar la pelea vuelven a moverse
--   emotes      los descansos siguen el orden 1 (rugido), 2 (pinzas), 1, 3 (pincho)
--   invocar     con 3 súbditos por invocación (6 a la vez): ninguno sale encima de
--               otro (≥ 1 casilla) ni dentro del Mega
--   reaparece   muriendo en plena pelea (uno cada 6 s) se reaparece con
--               BossZones.respawnPoint (como el servidor y un jugador): siempre
--               dentro de la zona, de pie en suelo seguro, sin la cabeza en el
--               agua y lejos del jefe (≥ 2 casillas de su cuerpo)
--
--   gp_subditos el segundo jugador hace ground pounds justo al lado de súbditos
--               vivos (empujón + aturdido): ningún súbdito se mueve más de lo
--               físicamente posible en un paso (antes "se teletransportaban")
--   camara      durante la entrada la cámara no sigue a nadie: la misma para
--               los dos jugadores y quieta, centrada en el jefe
--   (Nave Malvada / Espejo / Gran Bola de Nieve: orden dormant → intro → ready → su estado de pelea,
--    sonidos de su entrada; lejos/emotes/invocar son solo del Mega)
--
--   tools/tests/run.sh boss_intro        (LEVEL=..., SECS=90)
--   LEVEL=assets/levels/fortaleza_malvada.json / ruta_del_espejo.json
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local sounds = {}
Sound = setmetatable({ play = function(n) sounds[n] = (sounds[n] or 0) + 1 end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

function love.load()
    math.randomseed(5)
    local data = json.decode(love.filesystem.read(os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json'))
    -- (muchos súbditos: 3 por invocación, 6 a la vez, a menudo)
    for _, e in ipairs(data.entities or {}) do
        if e.type == 'megacrabby' or e.type == 'megacrabby_ice' then
            e.props = e.props or {}
            e.props.summonCount, e.props.summonMax, e.props.summonPool, e.props.summonEvery = 3, 6, 6, 4
        end
    end
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local z = boss.zone
    local T = TILE_PX
    local mega = boss.def.name == 'megacrabby' or boss.def.name == 'megacrabby_ice'
    local camBad, camRef = 0, nil
    local landGap
    -- Uno justo donde está el jefe (debe caer en otro sitio) y otro a la izquierda
    -- (de pie en el suelo que haya: el de la arena puede tener agua)
    local function ground(x)
        local gx, gy = level:findGround(math.floor(x / T) + 1, z.col, z.col + z.w - 1, z.row, z.row + z.h - 1)
        return gx or x, gy or (z.y1 - 60)
    end
    local players = { PlayerAdventure:new(ground(boss.x)), PlayerAdventure:new(ground(z.x0 + 3 * T)) }
    for _, pa in ipairs(players) do pa.spawnX, pa.spawnY = pa.x, pa.y end
    level.players = players
    local dt, t = 1 / 60, 0
    local seq, lastState = { boss.state }, boss.state
    print(('%6.2fs jefe: %-10s x=%d y=%d  zona=%s'):format(0, boss.state, boss.x, boss.y, z.state))
    local frozenMoved, silenceBad, solidBad, hurtIntro = 0, 0, 0, 0
    local introSeen, fightT, landClear = false, nil, nil
    local x0 = {}
    local rests, lastRest = {}, nil
    local freeMoved = 0
    local spawnBad, spawnN, spawnMinGap, spawnMinBoss = 0, 0, math.huge, math.huge
    local wasSpawning = {}
    local spawns, nextKill = {}, nil
    local lastPos, jumps, gps, worstJump = {}, {}, 0, 0
    -- (DEBUG_JUMP=1: dice qué función movió de golpe a un súbdito)
    if os.getenv('DEBUG_JUMP') then
        local Crawler = require 'src/world/entities/Crawler'
        local function wrap(tbl, name, getE)
            local f = tbl[name]
            tbl[name] = function(...)
                local e = getE(...)
                local x0, y0 = e.x, e.y
                local r = { f(...) }
                if e.summonOf and math.sqrt((e.x - x0) ^ 2 + (e.y - y0) ^ 2) > 30 then
                    print(('  SALTO en %s: (%d,%d)→(%d,%d) estado=%s'):format(name, x0, y0, e.x, e.y, e.state))
                    print(debug.traceback('', 2))
                end
                return unpack(r)
            end
        end
        local Entity = require 'src/world/entities/Entity'
        wrap(Entity, 'moveAndCollide', function(e) return e end)
        wrap(Crawler, 'attach', function(e) return e end)
        wrap(Crawler, 'move', function(e) return e end)
    end
    local nextGP = nil
    while t < (tonumber(os.getenv('SECS')) or 90) do
        t = t + dt
        local intro = z.state == 'intro'
        -- Pulsan derecha y saltan sin parar hasta 0.5 s después de empezar la pelea
        local pushing = not fightT or t - fightT < 0.5
        stub.state.right = pushing
        stub.state.jump_pressed = pushing
        for i, pa in ipairs(players) do x0[i] = pa.x end
        for _, pa in ipairs(players) do pa:update(dt, level) end
        level.solidBodies = Entities.solidBodies(ents)
        for _, ev in ipairs(ctrl:update(dt)) do
            if ev.type == 'boss_intro' then introSeen = true end
            if ev.type == 'boss_start' then fightT = t end
        end
        for _, e in ipairs(ents) do if e.alive then e:update(dt, level) end end
        if z.state == 'intro' and BossZones.music(level) ~= BossZones.SILENCE then silenceBad = silenceBad + 1 end
        for _, pa in ipairs(players) do Entities.interactions.run(pa, ents, {}) end
        if intro then
            local c1x, c1y = BossZones.cameraTarget(level, players[1].x, players[1].y)
            local c2x, c2y = BossZones.cameraTarget(level, players[2].x, players[2].y)
            camRef = camRef or { c1x, c1y }
            if not c1x or c1x ~= c2x or c1y ~= c2y or c1x ~= camRef[1] or c1y ~= camRef[2] then camBad = camBad + 1 end
            for i, pa in ipairs(players) do
                if math.abs(pa.x - x0[i]) > 0.01 then frozenMoved = frozenMoved + 1 end
                if pa.hp < pa.hpMax or pa.dying then hurtIntro = hurtIntro + 1 end
            end
        end
        local hidden = boss.state == 'dormant' or boss.state == 'fall_in' or boss.state == 'intro' or (not mega and boss.state == 'ready')
        if hidden and (boss:isSolidBody() or boss:isActive()) then
            solidBad = solidBad + 1
        end
        if fightT and t - fightT < 0.5 then
            for i, pa in ipairs(players) do freeMoved = freeMoved + math.abs(pa.x - x0[i]) end
        end
        -- (Espejo: al acabar la entrada, de pie EN el suelo: ni enterrado ni flotando)
        if boss.def.name == 'mirror' and boss.state == 'ready' and not landGap then
            local ob = boss:getOuterBounds()
            local bot = ob.y + ob.h
            local hit, top = level:landingCross(boss.x, bot - 40, bot + 40)
            landGap = hit and (bot - top) or 999
        end
        if boss.state ~= lastState then
            print(('%6.2fs jefe: %-10s x=%d y=%d  zona=%s'):format(t, boss.state, boss.x, boss.y, z.state))
            if #seq == 0 or seq[#seq] ~= boss.state then seq[#seq + 1] = boss.state end
            if boss.state == 'land_in' then
                local d = math.huge
                for _, pa in ipairs(players) do d = math.min(d, math.abs(pa.x - boss.x)) end
                landClear = d
            end
            if boss.state == 'rest' then rests[#rests + 1] = boss.restKind; print('         emote ' .. tostring(boss.restKind)) end
            lastState = boss.state
        end
        -- Muertes forzadas en plena pelea (el primero, cada 6 s)
        if fightT and z.state == 'fight' then
            nextKill = nextKill or fightT + 6
            if t >= nextKill and not players[1].dying then players[1]:die(nil, true); nextKill = t + 6 end
        end
        for _, pa in ipairs(players) do
            if not pa.alive or (pa.dying and pa.deathPhase == 'fall') then
                local rx, ry = BossZones.respawnPoint(level, pa)
                if rx then pa.spawnX, pa.spawnY = rx, ry end
                pa:respawn(); pa.hp = pa.hpMax
                if z.state == 'fight' then
                    local c = math.floor(pa.spawnX / T) + 1
                    local r = math.floor((pa.spawnY + 16 * PLAYER_SCALE / 2 - 2) / T) + 1   -- (celda donde está de pie)
                    local d = math.max(0, math.abs(pa.spawnX - boss.x) - boss.outerW / 2)
                    spawns[#spawns + 1] = { inZone = BossZones.contains(z, pa.spawnX, pa.spawnY),
                        stand = level:isStandable(c, r), wet = level:liquidAt(pa.spawnX, pa.spawnY - 30) ~= nil, d = d }
                    local sp = spawns[#spawns]
                    print(('%6.2fs reaparece en (%d,%d), a %.1f casillas del jefe (%s)%s%s%s'):format(t, c, r, d / T, boss.state,
                        sp.inZone and '' or ' FUERA DE LA ZONA', sp.stand and '' or ' SIN SUELO', sp.wet and ' EN EL AGUA' or ''))
                end
            end
        end
        -- Ground pound del jugador 2 junto a un súbdito vivo (cada 0.8 s)
        -- (después de ver los 4 emotes: los ground pounds cambian la persecución)
        if mega and fightT and z.state == 'fight' and #rests >= 4 then
            nextGP = nextGP or t + 1
            local pa = players[2]
            if t >= nextGP and not pa.dying and pa.alive ~= false then
                nextGP = t + 0.8
                for _, e in ipairs(ents) do
                    if e.summonOf and e.alive and e.state ~= 'spawning' and e.state ~= 'dead' then
                        -- (encima del suelo que tenga, a 1,2 casillas del súbdito)
                        local side = (math.random() < 0.5) and -1 or 1
                        pa.x = math.max(z.x0 + 40, math.min(z.x1 - 40, e.x + side * 1.2 * T))
                        pa.y, pa.vx, pa.vy = e.y - 60, 0, 0
                        pa.onGround, pa.gpPhase, pa.gpT = false, 'fall', 0
                        pa.invT = 5                    -- (que el jugador no muera aquí)
                        gps = gps + 1
                        break
                    end
                end
            end
        end
        -- Ningún súbdito salta más de lo posible en un paso (caída máx. ~25 px)
        for _, e in ipairs(ents) do
            if e.summonOf then
                local lp = lastPos[e]
                if e.alive and lp and lp.alive and lp.state ~= 'reserve' and e.state ~= 'spawning' and lp.state ~= 'spawning' then
                    local d = math.sqrt((e.x - lp.x) ^ 2 + (e.y - lp.y) ^ 2)
                    worstJump = math.max(worstJump, d)
                    if d > 40 then
                        jumps[#jumps + 1] = ('%.1fs %s→%s %.0f px (%d,%d)→(%d,%d)'):format(t, lp.state, e.state, d, lp.x, lp.y, e.x, e.y)
                    end
                end
                lastPos[e] = { x = e.x, y = e.y, alive = e.alive, state = e.state }
            end
        end
        -- Súbditos que acaban de salir: separados entre sí y del Mega
        local born = {}
        for _, e in ipairs(ents) do
            if e.summonOf and e.alive and e.state == 'spawning' and not wasSpawning[e] then born[#born + 1] = e end
            wasSpawning[e] = e.summonOf and e.alive and e.state == 'spawning' or nil
        end
        if #born > 0 then
            for _, e in ipairs(born) do
                spawnN = spawnN + 1
                local gb = math.abs(e.x - boss.x) - boss.outerW / 2 - e.outerW / 2
                spawnMinBoss = math.min(spawnMinBoss, gb)
                for _, o in ipairs(ents) do
                    if o ~= e and o.summonOf and o.alive then
                        local g = math.abs(o.x - e.x)
                        spawnMinGap = math.min(spawnMinGap, g)
                        if g < T then spawnBad = spawnBad + 1 end
                    end
                end
                if gb < 0 then spawnBad = spawnBad + 1 end
            end
        end
        if (not mega or (#rests >= 4 and spawnN >= 6 and gps >= 20)) and #spawns >= 4 then break end
    end
    local want = mega and { 'dormant', 'fall_in', 'land_in', 'roar_in', 'ready', 'chase' }
                 or { 'dormant', 'intro', 'ready', ({ miniboss1 = 'patrol', snowboss = 'idle' })[boss.def.name] or 'fight' }
    local okSeq = true
    for i, s in ipairs(want) do if seq[i] ~= s then okSeq = false end end
    check('orden', introSeen and okSeq, table.concat(seq, ' → ', 1, math.min(#seq, 7)))
    check('congelados', frozenMoved == 0, ('pasos con movimiento durante la entrada: %d'):format(frozenMoved))
    check('silencio', silenceBad == 0 and fightT ~= nil and BossZones.music(level) ~= BossZones.SILENCE,
        ('pasos con música durante la entrada: %d; después: %s'):format(silenceBad, tostring(BossZones.music(level))))
    check('intocable', solidBad == 0, ('pasos sólido/activo escondido o cayendo: %d'):format(solidBad))
    check('camara', camRef ~= nil and camBad == 0, ('pasos de la entrada con la cámara distinta o moviéndose: %d'):format(camBad))
    local safe = boss.outerW / 2 + 2.5 * T
    if not mega then
        check('sin daño', hurtIntro == 0, ('daño en la entrada: %d'):format(hurtIntro))
        local snd = ({ miniboss1 = { 'miniAppear', 'spikesOut' }, snowboss = { 'snowIntroRoll', 'snowLaugh', 'snowSpit' } })[boss.def.name]
                    or { 'mirrorLaugh' }
        local okSnd, txt = true, {}
        for _, n in ipairs(snd) do okSnd = okSnd and (sounds[n] or 0) >= 1; txt[#txt + 1] = n .. '=' .. (sounds[n] or 0) end
        check('sonidos', okSnd, table.concat(txt, ' '))
        if boss.def.name == 'mirror' then
            check('apoyado', landGap and math.abs(landGap) <= 2,
                ('pies respecto al suelo al acabar la entrada: %s px (+ = enterrado)'):format(tostring(landGap)))
        end
    end
    if mega then
    check('lejos', landClear and landClear >= safe - 1 and hurtIntro == 0,
        ('jugador más cercano al aterrizar: %.0f px (mín %.0f); daño en la entrada: %d'):format(landClear or -1, safe, hurtIntro))
    check('sonidos', (sounds.megaFall or 0) >= 1 and (sounds.megaRoar or 0) >= 1,
        ('megaFall=%d megaRoar=%d'):format(sounds.megaFall or 0, sounds.megaRoar or 0))
    end
    check('libres', freeMoved > 20, ('se movieron %.0f px en 0.5 s de pelea'):format(freeMoved))
    local ks = { 1, 2, 1, 3 }
    local okR = #rests >= 3
    for i, k in ipairs(rests) do if k ~= ks[i] then okR = false end end
    if mega then check('emotes', okR, 'descansos: ' .. table.concat(rests, ', ')) end
    local okS, minD = #spawns >= 3, math.huge
    for _, sp in ipairs(spawns) do
        okS = okS and sp.inZone and sp.stand and not sp.wet
        minD = math.min(minD, sp.d)
    end
    check('reaparece', okS and minD >= 2 * T,
        ('%d reapariciones; todas en la zona, de pie y secas=%s; la más cercana al jefe a %.1f casillas'):format(#spawns,
            tostring(okS), minD / T))
    if mega then
        check('gp_subditos', gps >= 10 and #jumps == 0,
            ('%d ground pounds junto a súbditos; mayor salto en un paso %.0f px; saltos imposibles %d%s'):format(
                gps, worstJump, #jumps, #jumps > 0 and (': ' .. table.concat(jumps, ' | ', 1, math.min(#jumps, 4))) or ''))
    end
    if mega then check('invocar', spawnN >= 6 and spawnBad == 0,
        ('%d súbditos invocados (3 por vez, 6 máx.); separación mínima entre súbditos %.0f px, hueco mínimo con el Mega %.0f px; solapes %d'):format(
            spawnN, spawnMinGap, spawnMinBoss, spawnBad)) end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
