-- tools/tests/boss_intro — la ENTRADA del jefe (Mega Crabby) y sus emotes, con
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
--   reaparece   muriendo en plena pelea (uno cada 6 s) se reaparece con
--               BossZones.respawnPoint (como el servidor y un jugador): siempre
--               dentro de la zona, de pie en suelo seguro, sin la cabeza en el
--               agua y lejos del jefe (≥ 2 casillas de su cuerpo)
--
--   tools/tests/run.sh boss_intro        (LEVEL=..., SECS=90)
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
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local z = boss.zone
    local T = TILE_PX
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
    local spawns, nextKill = {}, nil
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
            for i, pa in ipairs(players) do
                if math.abs(pa.x - x0[i]) > 0.01 then frozenMoved = frozenMoved + 1 end
                if pa.hp < pa.hpMax or pa.dying then hurtIntro = hurtIntro + 1 end
            end
        end
        if (boss.state == 'dormant' or boss.state == 'fall_in') and (boss:isSolidBody() or boss:isActive()) then
            solidBad = solidBad + 1
        end
        if fightT and t - fightT < 0.5 then
            for i, pa in ipairs(players) do freeMoved = freeMoved + math.abs(pa.x - x0[i]) end
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
        if #rests >= 4 and #spawns >= 4 then break end
    end
    local want = { 'dormant', 'fall_in', 'land_in', 'roar_in', 'ready', 'chase' }
    local okSeq = true
    for i, s in ipairs(want) do if seq[i] ~= s then okSeq = false end end
    check('orden', introSeen and okSeq, table.concat(seq, ' → ', 1, math.min(#seq, 7)))
    check('congelados', frozenMoved == 0, ('pasos con movimiento durante la entrada: %d'):format(frozenMoved))
    check('silencio', silenceBad == 0 and fightT ~= nil and BossZones.music(level) ~= BossZones.SILENCE,
        ('pasos con música durante la entrada: %d; después: %s'):format(silenceBad, tostring(BossZones.music(level))))
    check('intocable', solidBad == 0, ('pasos sólido/activo escondido o cayendo: %d'):format(solidBad))
    local safe = boss.outerW / 2 + 2.5 * T
    check('lejos', landClear and landClear >= safe - 1 and hurtIntro == 0,
        ('jugador más cercano al aterrizar: %.0f px (mín %.0f); daño en la entrada: %d'):format(landClear or -1, safe, hurtIntro))
    check('sonidos', (sounds.megaFall or 0) >= 1 and (sounds.megaRoar or 0) >= 1,
        ('megaFall=%d megaRoar=%d'):format(sounds.megaFall or 0, sounds.megaRoar or 0))
    check('libres', freeMoved > 20, ('se movieron %.0f px en 0.5 s de pelea'):format(freeMoved))
    local ks = { 1, 2, 1, 3 }
    local okR = #rests >= 3
    for i, k in ipairs(rests) do if k ~= ks[i] then okR = false end end
    check('emotes', okR, 'descansos: ' .. table.concat(rests, ', '))
    local okS, minD = #spawns >= 3, math.huge
    for _, sp in ipairs(spawns) do
        okS = okS and sp.inZone and sp.stand and not sp.wet
        minD = math.min(minD, sp.d)
    end
    check('reaparece', okS and minD >= 2 * T,
        ('%d reapariciones; todas en la zona, de pie y secas=%s; la más cercana al jefe a %.1f casillas'):format(#spawns,
            tostring(okS), minD / T))
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
