-- tools/tests/giantpuffer_rules — reglas del PEZ GLOBO GIGANTE (types/giantpuffer.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_pez.json, con la marea de la pelea corriendo):
--   varado      con la marea baja (empieza así) da coletazos hacia el jugador, cae en su marca (≤ 32 px) y queda
--               BOQUEANDO; solo boqueando se le hace daño (pisotón -1, ground pound -2, y se hincha y aparta: un
--               golpe por ocasión); en cualquier otro momento, caerle encima solo rebota
--   coletazo    deshinchado no hace daño (0.5.31): en el aire a su lado, nada; si CAE encima de alguien, aplasta: -1
--   marea       cuando sube el agua, nada hacia el jugador; tocarlo NO hace nada (deshinchado)
--   hincha      con el jugador cerca, en el agua: avisa (tiembla) y se hincha; hinchado pincha -1
--   puas        con el jugador lejos: dos ráfagas en corro (6 púas cada una); una púa le da -1; se paran en la pared
--   resaca      mientras el agua BAJA arrastra al jugador quieto hacia la derecha (≈ la velocidad de la resaca);
--               con el agua quieta arriba, no
--   enfado      a mitad de vida se enfada: tres ráfagas de 8 púas
--   derrota     el último golpe: se deshincha, aturdido, huye (libera la zona), se va del todo
--   red         netPackExtra → otro Pez (cliente): enfado, marca, ráfaga y púas iguales; interact igual
--   pez_chico   el pez globo PEQUEÑO en la marea: sigue el agua al bajar (casi siempre mojado), en seco bota y
--               coletea en el suelo (sin pinchar) y, pasado `dryTime`, se muere
--
--   tools/tests/run.sh giantpuffer_rules   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local BossZones = require 'src/world/systems/BossZones'
local Floods = require 'src/world/systems/Floods'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 13

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_pez.json'
local function arena()
    local f = assert(io.open(ARENA, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    Floods.link(level)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'giantpuffer' then boss = e end end
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }          -- (la marea de la pelea corre: Floods, control 'boss')
    level.floodTime = 0
    return level, es, boss
end

local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, (row or FLOOR - 1) * T - 60)
    for k in pairs(stub.state) do stub.state[k] = false end
    for _ = 1, 30 do pa:update(DT, level) end
    pa.invT = 0
    return pa
end

local function stepAll(level, es, players, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        Floods.advance(level, DT)
        for k in pairs(stub.state) do stub.state[k] = false end
        for _, pa in ipairs(players) do pa:update(DT, level) end
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        if each and each() then return true end
    end
end

local function putBoss(boss, col)
    boss.x = (col - 0.5) * T
    boss.y = (FLOOR - 1) * T - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
end

local function flood(level) return level.floods[1] end
-- Avanza la marea (sin nadie) hasta la fase `phase` y el nivel ≥ `minLevel`
local function tideTo(level, phase, minLevel)
    for _ = 1, 60 * 90 do
        Floods.advance(level, DT)
        local f = flood(level)
        if f.phase == phase and f.level >= (minLevel or 0) then return true end
    end
    return false
end

local function dropOn(level, cx, topY, gp)
    local pa = playerAt(level, 1)
    local ob = pa:getOuterBounds()
    pa.x = cx
    pa.y = topY + 6 - ob.h / 2
    pa.vy = 400
    pa.onGround = false
    if gp then pa.gpPhase = 'fall' end
    return pa
end

local cases = {}

function cases.varado()
    local level, es, boss = arena()
    putBoss(boss, 26)
    local pa = playerAt(level, 17)
    local mark, landX, gasp
    stepAll(level, es, { pa }, 6, function()
        pa.x, pa.vx = 16.5 * T, 0
        pa.invT = 1                                   -- (que no le haga daño: se mira dónde cae)
        if boss.state == 'flop' and not mark then mark = boss.markX end
        if mark and boss.state == 'gasp' then landX, gasp = boss.x, true; return true end
    end)
    local dry = flood(level).level <= 0                -- (marea baja = sin nada de agua)
    -- inmune fuera de la boqueada; boqueando, pisotón -1
    boss:enter('flop_wind')
    local gob = boss:getOuterBounds()
    local r1 = boss:interact(dropOn(level, boss.x, gob.y, false))
    boss:enter('gasp'); boss.inv = 0
    local hp0 = boss.hp
    local r2 = boss:interact(dropOn(level, boss.x, gob.y, false))
    level.players = { pa }
    boss:stomp()
    local hp1, st1 = boss.hp, boss.state
    boss:enter('gasp'); boss.inv = 0
    local r3 = boss:interact(dropOn(level, boss.x, gob.y, true))
    boss:pound(pa)
    local hp2 = boss.hp
    check('varado', dry and gasp and mark and math.abs(landX - mark) <= 32 and r1 == 'bounce' and r2 == 'stomp'
        and hp1 == hp0 - 1 and st1 == 'hurt_puff' and r3 == 'pound' and hp2 == hp1 - 2,
        ('marea baja=%s; cae a %s px de su marca; encima sin boquear: %s; boqueando: %s (vida %d→%d, %s), GP %s (→%d)'):format(
            tostring(dry), landX and mark and math.floor(math.abs(landX - mark)) or '?', tostring(r1), tostring(r2),
            hp0, hp1, st1, tostring(r3), hp2))
end

function cases.coletazo()
    local level, es, boss = arena()
    putBoss(boss, 20)
    local pa = playerAt(level, 22)
    boss:enter('flop'); boss.vx, boss.vy, boss.onGround = 0, -600, false
    boss.graceT = 0
    boss.y = boss.y - 2 * T
    level.players = { pa }
    -- subiendo, con el jugador a su lado: nada
    pa.x, pa.y, pa.invT = boss.x + boss.outerW / 2 + 10, boss.y, 0
    local hp0 = pa.hp
    boss:update(DT, level)
    local side = pa.hp == hp0
    -- cayendo, con el jugador debajo: aplasta
    boss.vy, boss.graceT = 500, 0
    pa.x, pa.y, pa.invT = boss.x, boss.y + boss.outerH / 2, 0
    local hp1 = pa.hp
    boss:update(DT, level)
    check('coletazo', side and pa.hp == hp1 - 1,
        ('a su lado en el aire: sin daño=%s; cayéndole encima: vida %d→%d'):format(tostring(side), hp1, pa.hp))
end

function cases.marea()
    local level, es, boss = arena()
    putBoss(boss, 27)
    local ok = tideTo(level, 'hold', 5.9)
    local pa = playerAt(level, 16, 10)
    boss.y = (FLOOR - 1) * T - boss.outerH / 2 - T
    boss:enter('swim'); boss.atkT = -99
    local x0 = boss.x
    local swam = false
    stepAll(level, es, { pa }, 1.5, function()
        pa.x, pa.y, pa.vx, pa.vy = 16.5 * T, 10 * T, 0, 0
        pa.invT = 1
        if boss.state == 'swim' then swam = true end
    end)
    local moved = x0 - boss.x
    -- contacto de lado, nadando (deshinchado): nada
    local hp0 = pa.hp
    boss.atkT = -99
    stepAll(level, es, { pa }, 0.5, function()
        pa.invT = 0
        pa.x, pa.y, pa.vx, pa.vy = boss.x - boss.outerW / 2 + 10, boss.y, 0, 0
    end)
    check('marea', ok and swam and moved > 1.5 * T and pa.hp == hp0,
        ('agua arriba=%s; nada=%s y se acerca %.1f casillas; tocarlo nadando: vida %d→%d'):format(
            tostring(ok), tostring(swam), moved / T, hp0, pa.hp))
end

function cases.hincha()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 22); boss.y = boss.y - T
    boss:enter('swim'); boss.atkT = 99
    local pa = playerAt(level, 24, 11)
    local seen = {}
    local pricked
    local hp0
    stepAll(level, es, { pa }, 3, function()
        pa.x, pa.vx = boss.x + 2.5 * T, 0
        pa.y = boss.y
        seen[boss.state] = true
        if boss.state == 'puffed' then
            if not hp0 then hp0 = pa.hp; pa.invT = 0; pa.x = boss.x + 60 end
            pa.x = boss.x + 60
            if pa.hp < hp0 then pricked = true; return true end
        else pa.invT = 1 end
    end)
    check('hincha', seen.puff_warn and seen.puffed and pricked == true,
        ('aviso=%s, hinchado=%s, pincha=%s'):format(tostring(seen.puff_warn), tostring(seen.puffed), tostring(pricked)))
end

function cases.puas()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 18); boss.y = boss.y - T
    boss:enter('spines_warn')
    local pa = playerAt(level, 29, 12)
    local maxN, bursts = 0, 0
    local hp0 = pa.hp
    stepAll(level, es, { pa }, 2.5, function()
        maxN = math.max(maxN, #boss.spines)
        bursts = math.max(bursts, boss.burst or 0)
        pa.vx = 0
    end)
    -- una púa que va derecha hacia el jugador
    boss.spines = { { id = 1, x = pa.x - 8, y = pa.y, a = 0, t = 0, hit = {} } }
    pa.invT = 0
    local hpA = pa.hp
    level.players = { pa }
    boss:updateSpines(level, DT)
    local hitP = pa.hp == hpA - 1
    -- una púa contra la pared de la zona se para
    local zx0 = boss:zoneBounds()
    boss.spines = { { id = 2, x = zx0 + 4, y = boss.y, a = math.pi, t = 0, hit = {} } }
    boss:updateSpines(level, 0.05)
    check('puas', bursts == 2 and maxN >= 10 and hitP and #boss.spines == 0,
        ('ráfagas %d, púas a la vez hasta %d, una púa: vida %d→%d, en la pared se para=%s'):format(
            bursts, maxN, hpA, pa.hp, tostring(#boss.spines == 0)))
end

function cases.resaca()
    local level, es, boss = arena()
    boss.alive = true
    local f = flood(level)
    tideTo(level, 'hold', 5.9)
    local pa = playerAt(level, 18, 11)
    local function drift(secs)
        local x0
        local n = 0
        for _ = 1, math.floor(secs * 60) + 1 do
            if n == 1 then x0 = pa.x end            -- (desde el primer paso: el choque de colocarlo no cuenta)
            level.players = { pa }
            Floods.advance(level, DT)
            for k in pairs(stub.state) do stub.state[k] = false end
            pa.x = math.min(pa.x, 30 * T)
            pa:update(DT, level)
            pa.vy = 0                               -- (que no se hunda ni salga del agua: se mide solo lo de lado)
            n = n + 1
        end
        return (pa.x - x0) / secs, n
    end
    local still = drift(1.0)                         -- arriba, quieta: nada
    tideTo(level, 'fall', 0)
    pa.x, pa.y, pa.vx, pa.vy = 18.5 * T, 11.5 * T, 0, 0
    local fall = drift(1.0)
    check('resaca', math.abs(still) < 15 and fall > 0.7 * f.undertow,
        ('agua quieta: %.0f px/s; bajando: %.0f px/s hacia la derecha (resaca %d)'):format(still, fall, f.undertow))
end

function cases.enfado()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 18); boss.y = boss.y - T
    local pa = playerAt(level, 28)
    level.players = { pa }
    boss.levelRef = level
    while boss.hp > boss.hpMax * 0.5 do boss:enter('gasp'); boss.inv = 0; boss:stomp() end
    boss:enter('spines'); boss.burst = 0; boss.spines = {}
    boss:fireBurst(level, 0)
    local per = #boss.spines
    boss.spines = {}
    boss:enter('spines'); boss.burst = 0
    for _ = 1, 50 do boss:update(DT, level) end
    check('enfado', boss.rage and per == 8 and boss.burst == 3,
        ('vida %d/%d: enfadado=%s, púas por ráfaga %d, ráfagas %d'):format(boss.hp, boss.hpMax, tostring(boss.rage), per, boss.burst))
end

function cases.derrota()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 14)
    level.players = { pa }
    boss.levelRef = level
    boss.hp = 1
    boss:enter('gasp'); boss.inv = 0
    boss:stomp()
    local seen, released = {}, false
    stepAll(level, es, {}, 24, function()
        seen[boss.state] = true
        if boss:releasesZone() then released = true end
        return boss.state == 'dead'
    end)
    check('derrota', seen.dying_deflate and seen.dying_daze and seen.dying_flee and released and boss.state == 'dead',
        ('deshincha=%s, aturdido=%s, huye=%s, libera la zona=%s, final=%s'):format(tostring(seen.dying_deflate),
            tostring(seen.dying_daze), tostring(seen.dying_flee), tostring(released), boss.state))
end

function cases.red()
    local level, es, boss = arena()
    putBoss(boss, 20)
    boss.rage, boss.markX, boss.markY, boss.burst = true, 999, 777, 2
    boss.spines = { { id = 5, x = 100, y = 200, a = 1.25, t = 0.4, hit = {} }, { id = 6, x = 300, y = 210, a = -2, t = 0.1, hit = {} } }
    local b = boss:netPackExtra()
    local c = Entities.create({ type = 'giantpuffer', col = 20, row = 12, props = {} })
    c:netApplyExtra(b, b, 1)
    local ok = c.rage and c.markX == 999 and c.markY == 777 and c.burst == 2 and #c.spines == 2
    for i, s in ipairs(boss.spines) do
        local q = c.spines[i]
        if not q or math.abs(q.x - s.x) > 1 or math.abs(q.y - s.y) > 1 or math.abs(q.a - s.a) > 0.002 then ok = false end
    end
    c.x, c.y, c.state, c.inv = boss.x, boss.y, 'gasp', 0
    boss:enter('gasp'); boss.inv = 0
    local gob = boss:getOuterBounds()
    local rs = boss:interact(dropOn(level, boss.x, gob.y, false))
    c.hp, c.hpMax = boss.hp, boss.hpMax
    local rc = c:interact(dropOn(level, c.x, gob.y, false))
    check('red', ok and rs == rc and rs == 'stomp',
        ('datos iguales=%s; pisotón servidor %s / cliente %s'):format(tostring(ok), tostring(rs), tostring(rc)))
end

function cases.pez_chico()
    local level, es, boss = arena()
    boss.alive = true
    tideTo(level, 'hold', 5.9)
    local f = flood(level)
    local fish = Entities.create({ type = 'pufferfish', col = 22, row = 8, props = { dryTime = 4, range = 0.1,
        area = { { col = 14, row = 6 }, { col = 31, row = 6 }, { col = 31, row = 12 }, { col = 14, row = 12 } } } })
    local all = { boss, fish }
    boss.state = 'dormant'                                         -- (el jefe quieto: solo se mira el pez)
    local wetN, n, seen, hops, lastVy, pricks = 0, 0, {}, 0, 0, false
    local diedT, t = nil, 0
    stepAll(level, all, {}, 40, function()
        t = t + DT
        seen[fish.state] = true
        if f.phase == 'fall' and f.level > 1.2 then
            n = n + 1
            if level:liquidAt(fish.x, fish.y) then wetN = wetN + 1 end
        end
        if fish.state == 'dry_flop' and fish.vy < -100 and lastVy >= 0 then hops = hops + 1 end
        lastVy = fish.vy or 0
        if fish:getHazardBoxes() then pricks = true end
        if os.getenv("TRACE") and math.floor(t * 2) ~= math.floor((t - DT) * 2) then print(("%5.1f %-9s y=%4d surf=%4d ph=%s lv=%.2f wet=%s"):format(t, fish.state, fish.y, f.surf, f.phase, f.level, tostring(level:liquidAt(fish.x, fish.y) ~= nil))) end
        if not fish.alive then diedT = t; return true end
    end)
    local follow = n > 0 and wetN / n
    check('pez_chico', follow and follow > 0.9 and seen.dry_flop and hops >= 3 and seen.dry_die and diedT and not pricks,
        ('al bajar el agua, mojado el %d %%; en seco: coletea=%s (%d botes), se muere=%s, pincha en seco=%s'):format(
            math.floor((follow or 0) * 100), tostring(seen.dry_flop), hops, tostring(diedT ~= nil), tostring(pricks)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'varado', 'coletazo', 'marea', 'hincha', 'puas', 'resaca', 'enfado', 'derrota', 'red', 'pez_chico' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
