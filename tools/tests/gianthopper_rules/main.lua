-- tools/tests/gianthopper_rules — reglas del SALTARÍN GIGANTE (types/gianthopper.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_saltarin.json, A OSCURAS):
--   linterna   lejos y con la linterna APAGADA no te ve (nunca va de caza); ENCENDIDA te ve: se agacha con la diana
--              sobre ti y cae en ella (≤ 40 px)
--   farol      sin linterna, dentro de la luz de su farol, te ve; justo fuera, no
--   roca       el FOGONAZO alumbra a quien está a la vista (lo ve) y no a quien está detrás de una roca; la linterna
--              encendida detrás de una roca tampoco
--   ondas      al caer de un salto de caza suelta dos ondas de roca, una a cada lado; una onda le da -1 a quien
--              está en el suelo; de paseo (saltitos), ninguna
--   susto      un ruido fuerte cerca (ground pound) lo asusta: farol apagado (sin luz) y quieto; lejos, flojo o el de
--              un jugador herido, no; tras el susto tarda en volver a asustarse
--   golpe      solo asustado se le hace daño (pisotón -1, ground pound -2, un golpe por ocasión: luego 'hurt');
--              si no, caerle encima rebota
--   tocar      tocarlo de lado quita 1; asustado, no
--   enfado     a mitad de vida se enfada y suelta saltarines de cueva (Normal 2 a la vez, Fácil 1), ninguno antes
--   derrota    el último golpe: se le apaga el farol, aturdido, y se va de un salto hacia arriba atravesando el
--              techo (libera la zona, suelta el fragmento) hasta irse del todo; sus saltarines se mueren
--   red        netPackExtra → otro Saltarín Gigante (cliente): enfado, caza, diana, ondas y luz iguales; interact igual
--
--   tools/tests/run.sh gianthopper_rules   (CASE=nombre)
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
local Noise = require 'src/world/systems/Noise'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 13

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_saltarin.json'
local function arena(diff)
    local f = assert(io.open(ARENA, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.difficulty = diff
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'gianthopper' then boss = e end end
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }
    boss.levelRef = level
    Noise.bind(level)
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
    boss.waves, boss.memT, boss.flareT, boss.scareCd = {}, 0, 0, 0
    boss.heardSeq = nil
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

function cases.linterna()
    local level, es, boss = arena()
    putBoss(boss, 26)
    boss.flareT = -99                                    -- (sin fogonazos: solo lo que ve)
    local pa = playerAt(level, 15)
    pa.lightOn = false
    local hunted = false
    stepAll(level, es, { pa }, 4, function()
        pa.x, pa.vx, pa.invT, pa.lightOn = 14.5 * T, 0, 9, false
        if boss.state == 'crouch' and boss.hunting then hunted = true end
        boss.flareT = -99
    end)
    -- encendida: va a por él
    putBoss(boss, 26); boss:rest(0.2)
    local mark, landX
    stepAll(level, es, { pa }, 4, function()
        pa.x, pa.vx, pa.invT, pa.lightOn, pa.lightBat = 21.5 * T, 0, 9, true, 1
        if boss.state == 'hop' and boss.hunting and not mark then mark = boss.markX end
        if mark and boss.state == 'rest' then landX = boss.x; return true end
    end)
    check('linterna', not hunted and mark and landX and math.abs(mark - pa.x) < T and math.abs(landX - mark) <= 40,
        ('apagada a 11 casillas: de caza=%s · encendida: diana a %s px de él, cae a %s px de la diana'):format(
            tostring(hunted), mark and math.floor(math.abs(mark - pa.x)) or '?', landX and mark and math.floor(math.abs(landX - mark)) or '?'))
end

function cases.farol()
    local level, es, boss = arena()
    putBoss(boss, 26); boss:rest(9)
    local pa = playerAt(level, 23)
    pa.lightOn = false
    level.players = { pa }
    local near = boss:sees(level, pa)
    pa.x = boss.x - boss.LAMP_R - 1.5 * T
    local far = boss:sees(level, pa)
    boss:enter('scared')
    pa.x = boss.x - 2 * T
    local scared = boss:sees(level, pa)
    check('farol', near and not far and not scared,
        ('sin linterna a 3 casillas: lo ve=%s · fuera de su luz: %s · asustado (farol apagado), cerca: %s'):format(
            tostring(near), tostring(far), tostring(scared)))
end

function cases.roca()
    local level, es, boss = arena()
    putBoss(boss, 25)
    boss.facing = -1
    -- uno a la vista y otro pegado detrás de la roca de la columna 17
    local open, hid = playerAt(level, 21), playerAt(level, 16)
    for _, p in ipairs({ open, hid }) do p.lightOn = false end
    boss:enter('flare_wind'); boss.deadTimer = 5
    level.players = { hid }
    boss:update(DT, level)
    local hiddenSeen = boss.memT > 0
    putBoss(boss, 25)
    boss:enter('flare_wind'); boss.deadTimer = 5
    level.players = { open }
    boss:update(DT, level)
    local openSeen = boss.memT > 0 and math.abs(boss.seenX - open.x) < 1
    -- la linterna encendida detrás de la roca: tampoco
    hid.lightOn = true
    local lampHid = boss:sees(level, hid)
    open.lightOn = true
    local lampOpen = boss:sees(level, open)
    local lit = boss:lights()
    check('roca', not hiddenSeen and openSeen and not lampHid and lampOpen and lit and lit[1].r >= boss.FLARE_R and lit[1].cast,
        ('fogonazo: a la vista lo ve=%s, detrás de la roca=%s · linterna detrás de la roca=%s, a la vista=%s · luz del fogonazo r=%s cortada=%s'):format(
            tostring(openSeen), tostring(hiddenSeen), tostring(lampHid), tostring(lampOpen),
            lit and math.floor(lit[1].r) or '-', lit and tostring(lit[1].cast) or '-'))
end

function cases.ondas()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 27)
    pa.lightOn = true
    level.players = { pa }
    boss.seenX, boss.seenY, boss.memT = 22.5 * T, (FLOOR - 1) * T, 4
    boss:startCrouch(level, true)
    boss.markX = math.floor(boss.x)
    boss.deadTimer = 5
    local n
    stepAll(level, es, { pa }, 2, function()
        pa.x, pa.vx, pa.lightOn, pa.lightBat = 27.5 * T, 0, true, 1
        if boss.state == 'rest' and not n then n = #boss.waves; pa.invT = 0 end
        if n and #boss.waves == 0 then return true end
        if not n then pa.invT = 9 end
    end)
    local hp = pa.hp
    -- de paseo: ninguna
    putBoss(boss, 22)
    boss:startCrouch(level, false)
    local prowl
    stepAll(level, es, {}, 2, function() if boss.state == 'rest' then prowl = #boss.waves; return true end end)
    check('ondas', n == 2 and hp == pa.hpMax - 1 and prowl == 0,
        ('al caer de caza: %s ondas; la onda le quita: vida %d/%d · saltito de paseo: %s ondas'):format(
            tostring(n), hp, pa.hpMax, tostring(prowl)))
end

function cases.susto()
    local level, es, boss = arena()
    local function try(dx, r, from)
        putBoss(boss, 24); boss:rest(9)
        boss:update(DT, level)                           -- (se pone al día con los ruidos de antes)
        Noise.emit(boss.x + dx, boss.y, r, nil, from)
        boss:update(DT, level)
        return boss.state == 'scared'
    end
    local near = try(4 * T, Noise.R.pound)
    local dark = boss:lights() == nil
    local x0 = boss.x
    stepAll(level, es, {}, 1.5)
    local still = boss.state == 'scared' and math.abs(boss.x - x0) < 2
    local far = try(9 * T, Noise.R.pound)
    local weak = try(2 * T, Noise.R.pickup)
    local hurt = try(2 * T, Noise.R.hurt, 'hurt')
    -- tras el susto, un rato sin asustarse
    try(3 * T, Noise.R.pound)
    stepAll(level, es, {}, 3.2, function() return boss.state ~= 'scared' end)
    Noise.emit(boss.x + 3 * T, boss.y, Noise.R.pound)
    boss:update(DT, level)
    local cd = boss.state ~= 'scared'
    check('susto', near and dark and still and not far and not weak and not hurt and cd,
        ('ground pound a 4 casillas: asustado=%s, sin luz=%s, quieto=%s · a 9: %s · ruido flojo: %s · jugador herido: %s · justo después, otro: no=%s'):format(
            tostring(near), tostring(dark), tostring(still), tostring(far), tostring(weak), tostring(hurt), tostring(cd)))
end

function cases.golpe()
    local level, es, boss = arena()
    putBoss(boss, 24)
    local pa = playerAt(level, 15)
    level.players = { pa }
    boss:rest(9)
    local gob = boss:getOuterBounds()
    local r1 = boss:interact(dropOn(level, boss.x, gob.y, false))
    boss:enter('scared'); boss.inv = 0
    local hp0 = boss.hp
    local r2 = boss:interact(dropOn(level, boss.x, gob.y, false))
    boss:stomp()
    local hp1, st1 = boss.hp, boss.state
    local r2b = boss:interact(dropOn(level, boss.x, gob.y, false))      -- (ya no: un golpe por ocasión)
    boss:enter('scared'); boss.inv = 0
    local r3 = boss:interact(dropOn(level, boss.x, gob.y, true))
    boss:pound(pa)
    local hp2 = boss.hp
    check('golpe', r1 == 'bounce' and r2 == 'stomp' and hp1 == hp0 - 1 and st1 == 'hurt' and r2b == 'bounce'
        and r3 == 'pound' and hp2 == hp1 - 2,
        ('sin asustar: %s · asustado: %s (vida %d→%d, %s), otra vez: %s · GP %s (→%d)'):format(
            tostring(r1), tostring(r2), hp0, hp1, st1, tostring(r2b), tostring(r3), hp2))
end

function cases.tocar()
    local level, es, boss = arena()
    putBoss(boss, 24)
    local pa = playerAt(level, 20)
    boss:rest(9)
    local function side()
        pa.invT, boss.graceT = 0, 0
        local hp = pa.hp
        pa.x, pa.y, pa.vx, pa.vy = boss.x - boss.outerW / 2 - 8, (FLOOR - 1) * T - 30, 0, 0
        level.players = { pa }
        boss:update(DT, level)
        return hp - pa.hp
    end
    local a = side()
    boss:enter('scared')
    local b = side()
    check('tocar', a == 1 and b == 0, ('de lado: -%d · asustado: -%d'):format(a, b))
end

local function count(level, boss)
    local n = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive then n = n + 1 end end
    return n
end

function cases.enfado()
    local out = {}
    for _, d in ipairs({ 'normal', 'easy' }) do
        local level, es, boss = arena(d)
        putBoss(boss, 24)
        local pa = playerAt(level, 14)
        level.players = { pa }
        boss:rest(99)
        local before = 0
        stepAll(level, es, { pa }, 8, function() pa.invT = 9; boss.deadTimer = 0; before = math.max(before, count(level, boss)) end)
        while boss.hp > boss.hpMax * 0.5 do boss:enter('scared'); boss.inv = 0; boss:stomp() end
        boss:rest(99)
        local max = 0
        stepAll(level, es, { pa }, 30, function()
            pa.invT = 9
            if boss.state == 'rest' then boss.deadTimer = 0 else boss:rest(99) end
            max = math.max(max, count(level, boss))
        end)
        out[d] = { before = before, max = max, rage = boss.rage, minions = #boss:minions(level) }
    end
    local n, e = out.normal, out.easy
    check('enfado', n.rage and n.before == 0 and n.max == 2 and e.max == 1,
        ('enfadado=%s; antes %d; a la vez: Normal %d, Fácil %d (reserva %d)'):format(tostring(n.rage), n.before, n.max, e.max, n.minions))
end

function cases.derrota()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 14)
    level.players = { pa }
    boss.hp = boss.hpMax * 0.4
    boss.rage = true
    boss.spawnT = 99; boss:spawnMoths(level, 0)
    local m0 = count(level, boss)
    boss.hp = 1
    boss:enter('scared'); boss.inv = 0
    boss:stomp()
    local seen, released, shard, broke = {}, false, false, false
    local floorY = boss:feetY()
    local _, _, zy0 = boss:zoneBounds()
    local outDark = true
    stepAll(level, es, {}, 24, function()
        seen[boss.state] = true
        if boss:releasesZone() then released = true end
        if boss:shardDrop() then shard = true end
        if boss.state == 'dying_out' and boss.deadTimer > 1.3 and boss:lights() then outDark = false end
        if boss.state == 'dying_flee' and boss.y + boss.outerH / 2 < zy0 then broke = true end
        return boss.state == 'dead'
    end)
    local m1 = count(level, boss)
    check('derrota', seen.dying_out and seen.dying_flee and outDark and released and shard and broke and boss.state == 'dead'
        and not boss.alive and m0 >= 1 and m1 == 0,
        ('estados: %s · farol apagado=%s · libera=%s · fragmento=%s · atraviesa el techo=%s · final %s · saltarines %d → %d'):format(
            table.concat((function() local t = {} for k in pairs(seen) do t[#t + 1] = k end table.sort(t) return t end)(), ','),
            tostring(outDark), tostring(released), tostring(shard), tostring(broke), boss.state, m0, m1))
end

function cases.red()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 27)
    level.players = { pa }
    boss.rage = true
    boss.seenX, boss.seenY, boss.memT = pa.x, pa.y, 4
    boss:startCrouch(level, true)
    boss:spawnWaves()
    local data = boss:netPackExtra()
    local def = Entities.TYPES and Entities.TYPES.gianthopper
    local other = Entities.create({ type = 'gianthopper', col = boss.col, row = boss.row, props = {} })
    other.zone, other.levelRef = boss.zone, level
    other.x, other.y, other.state, other.deadTimer, other.facing = boss.x, boss.y, boss.state, boss.deadTimer, boss.facing
    other:netApplyExtra(data, data, 1)
    local same = other.rage == boss.rage and other.hunting == boss.hunting and other.markX == boss.markX
        and other.markY == boss.markY and #other.waves == #boss.waves and other.waves[2].dir == boss.waves[2].dir
    local l1, l2 = boss:lights(), other:lights()
    local light = l1 and l2 and l1[1].x == l2[1].x and l1[1].r == l2[1].r
    boss:enter('scared'); other.state = 'scared'
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, boss.x, gob.y, false)
    local i1, i2 = boss:interact(p1), other:interact(p1)
    check('red', same and light and i1 == i2 and i1 == 'stomp',
        ('datos iguales=%s (%d campos) · luz igual=%s · interact %s / %s'):format(tostring(same), #data, tostring(light), tostring(i1), tostring(i2)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'linterna', 'farol', 'roca', 'ondas', 'susto', 'golpe', 'tocar', 'enfado', 'derrota', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
