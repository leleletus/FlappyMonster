-- tools/tests/groovecrab_rules — reglas de EL GROOVE (types/groovecrab.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_groove.json). El reloj del jefe es su canción: cada caso lo pone en el compás que prueba.
--   reloj      la canción → sección, compás y semicorchea (intro 8 + bucle A16 B16 SOLO8 SUBIDA8 CLÍMAX16 VUELTA4,
--              y vuelve a la A); dónde posa (último compás de cada 4: en la 12; en el solo, los impares enteros)
--   salto      en la A: agachado con la diana sobre ti, salta en la semicorchea 8 y CAE en la 0 del compás siguiente
--              (± un paso) en la diana (≤ 4 px): dos ondas de arena; una onda le quita 1 a quien está en el suelo
--   notas      en la B dispara en los pops (2 en un compás: semicorcheas 4 y 8) hacia el jugador; una nota quita 1
--   pose       justo antes de la 12 del compás 4 no es vulnerable; en la 12, sí (y esconde el trampolín) hasta la 4
--              del siguiente; pisotón -1 (→ 'hurt'), otra vez en la misma pose no; ground pound -2
--   trampolin  fuera de la pose, caerle encima te LANZA (vy ≈ salto × 1,85), también con ground pound, sin daño;
--              posando, el pisotón le da
--   tocar      tocar su cuerpo de lado quita 1; su pinza, no; posando, no
--   enfado     a media vida se enfada; enfadado salta también en los compases pares de la A (tranquilo, no)
--   solo       en el solo posa los compases impares enteros; en los pares da un saltito que cae en el golpe
--              siguiente, sin ondas
--   derrota    el último golpe: aturdido, se va de un bote hacia arriba (libera la zona) hasta irse; sin fragmento
--   red        netPackExtra → otro Groove (cliente): canción, enfado, diana, ondas y notas iguales; interact igual
--
--   tools/tests/run.sh groovecrab_rules   (CASE=nombre)
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
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Interactions = require 'src/world/entities/base/Interactions'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 13

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_groove.json'
local GC
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
    for _, e in ipairs(es) do if e.def.name == 'groovecrab' then boss = e end end
    GC = boss
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }
    boss.levelRef = level
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
    for _ = 1, math.floor(secs * 60 + 0.5) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        for k in pairs(stub.state) do stub.state[k] = false end
        for _, pa in ipairs(players) do pa:update(DT, level) end
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        if each and each() then return true end
    end
end

-- Pone la canción en el compás `bar` (absoluto, desde 0) y la semicorchea `step`
local function songAt(boss, bar, step)
    local t = bar * boss.BAR + (step or 0) * boss.S16
    boss.songT, boss.prevT = t, t - 1e-4
    boss.hop, boss.waves, boss.notes = nil, {}, {}
    boss.x = 24 * T - T / 2
    boss.y = boss.floorY - boss.outerH / 2
    boss:enter('groove')
end
-- compás absoluto de (sección, compás de la sección) en la primera vuelta
local START = { I = 0, A = 8, B = 24, K = 40, S = 48, C = 56, O = 72 }
local function barOf(sec, k) return START[sec] + k - 1 end

local function dropOn(level, cx, topY, gp)
    local pa = playerAt(level, 2)
    local ob = pa:getOuterBounds()
    pa.x = cx
    pa.y = topY + 6 - ob.h / 2
    pa.vy = 400
    pa.onGround = false
    if gp then pa.gpPhase = 'fall' end
    return pa
end

local cases = {}

function cases.reloj()
    local _, _, boss = arena()
    local W = boss.where
    local function is(t, sec, k) local _, s, kk = W(t); return s == sec and kk == k end
    local B = boss.BAR
    local ok = is(0, 'I', 1) and is(8 * B + 0.01, 'A', 1) and is(24 * B + 0.01, 'B', 1) and is(40 * B + 0.01, 'K', 1)
        and is(48 * B + 0.01, 'S', 1) and is(56 * B + 0.01, 'C', 1) and is(72 * B + 0.01, 'O', 1)
        and is((8 + 68) * B + 0.01, 'A', 1) and is((8 + 68 + 35) * B + 0.01, 'K', 4)
    local poses = boss.poseStart('A', 4) == 12 and boss.poseStart('A', 3) == nil and boss.poseStart('K', 1) == 0
        and boss.poseStart('K', 2) == nil and boss.poseStart('I', 4) == nil and boss.poseStart('O', 4) == nil
    check('reloj', ok and poses and boss.LOOP == 68,
        ('secciones=%s · poses=%s · bucle %d compases (%.1f s)'):format(tostring(ok), tostring(poses), boss.LOOP, boss.LOOP * B))
end

function cases.salto()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    songAt(boss, barOf('A', 1), 0)
    local B = boss.BAR
    local mark, jumpT, landT, landX, crouched, waves
    stepAll(level, es, { pa }, 1.7, function()
        pa.x, pa.vx, pa.invT = 18 * T - T / 2, 0, 9
        if boss.state == 'crouch' then crouched = true; mark = boss.markX end
        if boss.state == 'hop' and not jumpT then jumpT = boss.songT end
        if jumpT and not landT and boss.state == 'groove' then landT, landX, waves = boss.songT, boss.x, #boss.waves end
    end)
    local t0 = barOf('A', 1) * B
    local onBeat = landT and math.abs(landT - (t0 + B)) <= 1.5 / 60
    local jumpOk = jumpT and math.abs(jumpT - (t0 + 8 * boss.S16)) <= 1.5 / 60
    -- una onda le da a quien está en el suelo
    local pb = playerAt(level, 30)
    pb.invT = 0
    local hp0 = pb.hp
    stepAll(level, es, { pb }, 1.4, function() pb.vx = 0 end)
    check('salto', crouched and jumpOk and onBeat and mark and landX and math.abs(landX - mark) <= 4 and waves == 2 and pb.hp < hp0,
        ('agachado=%s · salta en la 8: %s · cae en el compás: %s · en la diana: %s px · ondas %s · la onda le quita: %d→%d'):format(
            tostring(crouched), tostring(jumpOk), tostring(onBeat), landX and mark and math.floor(math.abs(landX - mark)) or '?',
            tostring(waves), hp0, pb.hp))
end

function cases.notas()
    local level, es, boss = arena()
    local pa = playerAt(level, 16)
    songAt(boss, barOf('B', 1), 0)
    local fired, toward = 0, true
    local seen = {}
    stepAll(level, es, { pa }, boss.BAR - 0.05, function()
        pa.x, pa.vx, pa.invT = 16 * T - T / 2, 0, 9
        for _, n in ipairs(boss.notes) do
            if not seen[n.id] then seen[n.id] = true; fired = fired + 1; if (n.vx < 0) ~= (pa.x < boss.x) then toward = false end end
        end
    end)
    -- una nota le da
    pa.invT = 0
    local hp0 = pa.hp
    songAt(boss, barOf('B', 1), 3.5)
    stepAll(level, es, { pa }, 1.5, function() pa.vx = 0 end)
    check('notas', fired == 2 and toward and pa.hp < hp0,
        ('notas en el compás B1: %d (pops 4 y 8) · hacia él: %s · le quita: %d→%d'):format(fired, tostring(toward), hp0, pa.hp))
end

function cases.pose()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    songAt(boss, barOf('A', 4), 11)
    stepAll(level, es, { pa }, 0.05)
    local before = boss:isVulnerable()
    stepAll(level, es, { pa }, 0.1)
    local during = boss:isVulnerable() and boss.state == 'pose' and not boss:trampOut()
    -- un pisotón
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, boss.x, gob.y, false)
    local r1 = boss:interact(p1)
    local hp0 = boss.hp
    if r1 == 'stomp' then boss:stomp() end
    local afterHit = boss.hp
    stepAll(level, es, { pa }, 0.1)
    local r2 = boss:interact(dropOn(level, boss.x, gob.y, false))
    -- fin de la pose: en la 4 del compás siguiente
    songAt(boss, barOf('A', 4), 13)
    boss.poseHit = nil
    local still, ended
    local tA5 = barOf('A', 5) * boss.BAR
    stepAll(level, es, { pa }, 0.9, function()
        if boss.songT >= tA5 + 3.5 * boss.S16 and not still then still = boss.state end
        if boss.songT >= tA5 + 4.5 * boss.S16 and ended == nil then ended = boss.state ~= 'pose' end
    end)
    -- ground pound: -2
    songAt(boss, barOf('A', 8), 12.5)
    boss.poseHit, boss.inv = nil, 0
    stepAll(level, es, { pa }, 0.05)
    local p3 = dropOn(level, boss.x, gob.y, true)
    local r3 = boss:interact(p3)
    local hp1 = boss.hp
    if r3 == 'pound' then boss:pound(p3) end
    check('pose', not before and during and r1 == 'stomp' and afterHit == hp0 - 1 and boss.state ~= 'pose' and r2 ~= 'stomp'
        and still == 'pose' and ended and r3 == 'pound' and boss.hp == hp1 - 2,
        ('antes de la 12: %s · en la 12: %s · pisotón %s (%d→%d), otra vez: %s · sigue en la 3 siguiente: %s, acaba: %s · GP %s (%d→%d)'):format(
            tostring(before), tostring(during), tostring(r1), hp0, afterHit, tostring(r2), tostring(still), tostring(ended),
            tostring(r3), hp1, boss.hp))
end

function cases.trampolin()
    local level, es, boss = arena()
    songAt(boss, barOf('A', 2), 2)
    level.players = {}
    stepAll(level, es, {}, 0.05)
    local tb = boss:trampBox()
    local p1 = dropOn(level, boss.x, tb.y + 10, false)
    local r1, _, vy = boss:interact(p1)
    local p2 = dropOn(level, boss.x, tb.y + 10, true)
    local r2 = boss:interact(p2)
    local want = -math.abs(ADV_JUMP_VEL) * 1.85
    -- posando, le da
    songAt(boss, barOf('A', 4), 12.5)
    stepAll(level, es, {}, 0.05)
    local r3 = boss:interact(dropOn(level, boss.x, boss:getOuterBounds().y, false))
    check('trampolin', r1 == 'launch' and math.abs(vy - want) < 1 and r2 == 'launch' and r3 == 'stomp',
        ('caerle encima: %s (vy %s, quiere %.0f) · con ground pound: %s · posando: %s'):format(tostring(r1), tostring(vy), want,
            tostring(r2), tostring(r3)))
end

function cases.tocar()
    local level, es, boss = arena()
    songAt(boss, barOf('A', 2), 2)
    local pa = playerAt(level, 14)
    local b = boss:getOuterBounds()
    pa.x, pa.y = b.x - 10, boss.floorY - pa:getOuterBounds().h / 2 - 2
    pa.invT = 0
    local hp0 = pa.hp
    level.players = { pa }
    boss:touch(level)
    local side = hp0 - pa.hp
    -- contra la PINZA grande (fuera del cuerpo): nada
    local pc = playerAt(level, 14)
    local f = boss.facing or 1
    pc.x, pc.y, pc.invT = boss.x + f * 15 * boss.MS, boss.floorY - pc:getOuterBounds().h / 2 - 2, 0
    boss.graceT = 0
    level.players = { pc }
    local hpc = pc.hp
    boss:touch(level)
    local claw = hpc - pc.hp
    songAt(boss, barOf('A', 4), 12.5)
    stepAll(level, es, {}, 0.05)
    local pb = playerAt(level, 14)
    pb.x, pb.y, pb.invT = b.x - 10, boss.floorY - pb:getOuterBounds().h / 2 - 2, 0
    local hp1 = pb.hp
    level.players = { pb }
    boss.graceT = 0
    stepAll(level, es, { pb }, 0.05, function() pb.x, pb.vx = b.x - 10, 0 end)
    check('tocar', side == 1 and claw == 0 and pb.hp == hp1, ('el cuerpo de lado: -%d · la pinza: -%d · posando: -%d'):format(side, claw, hp1 - pb.hp))
end

function cases.enfado()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    local calm = boss.plan('A', 2, false).hop
    songAt(boss, barOf('A', 4), 12.5)
    boss.hp = math.floor(boss.hpMax / 2) + 1
    stepAll(level, es, { pa }, 0.05)
    boss:stomp()
    local angry = boss.rage
    local hopped
    songAt(boss, barOf('A', 2), 0)
    stepAll(level, es, { pa }, 1.0, function()
        pa.vx, pa.invT = 0, 9
        if boss.state == 'hop' then hopped = true end
    end)
    check('enfado', angry and not calm and hopped, ('enfadado a media vida: %s · A2 tranquilo salta: %s · enfadado: %s'):format(
        tostring(angry), tostring(calm), tostring(hopped)))
end

function cases.solo()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    songAt(boss, barOf('K', 1), 0.5)
    local whole = true
    stepAll(level, es, { pa }, boss.BAR - 0.1, function() pa.vx, pa.invT = 0, 9; if boss.state ~= 'pose' then whole = false end end)
    songAt(boss, barOf('K', 2), 0)
    local landT, waves, posed
    stepAll(level, es, { pa }, boss.BAR + 0.1, function()
        pa.vx, pa.invT = 0, 9
        if boss.state == 'hop' then landT = false end
        if landT == false and boss.state ~= 'hop' then landT, waves, posed = boss.songT, #boss.waves, boss.state end
    end)
    local onHit = landT and math.abs(landT - barOf('K', 3) * boss.BAR) <= 1.5 / 60
    check('solo', whole and onHit and waves == 0 and posed == 'pose',
        ('K1 entero posando: %s · el saltito cae en el golpe de K3: %s · ondas %s · y posa: %s'):format(
            tostring(whole), tostring(onHit), tostring(waves), tostring(posed)))
end

function cases.derrota()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    songAt(boss, barOf('A', 4), 12.5)
    stepAll(level, es, { pa }, 0.05)
    boss.hp, boss.inv = 1, 0
    boss:stomp()
    local states, seen = {}, {}
    local rel, flew = false, false
    local y0 = boss.y
    stepAll(level, es, { pa }, 12, function()
        pa.vx, pa.invT = 0, 9
        if not seen[boss.state] then seen[boss.state] = true; states[#states + 1] = boss.state end
        if boss:releasesZone() then rel = true end
        if boss.y < y0 - 6 * T then flew = true end
        return boss.state == 'dead'
    end)
    check('derrota', states[1] == 'dying_daze' and seen.dying_flee and seen.dead and rel and flew and boss:shardDrop() == false,
        ('estados: %s · libera=%s · se va hacia arriba=%s · fragmento=%s'):format(table.concat(states, ','), tostring(rel),
            tostring(flew), tostring(boss:shardDrop())))
end

function cases.red()
    local level, es, boss = arena()
    local pa = playerAt(level, 16)
    songAt(boss, barOf('B', 1), 0)
    stepAll(level, es, { pa }, 1.0, function() pa.vx, pa.invT = 0, 9 end)
    boss.rage = true
    require('src/world/entities/base/BossWaves').spawn(boss, boss.floorY, boss.outerW / 2)
    local data = boss:netPackExtra()
    local other = Entities.create({ type = 'groovecrab', col = boss.col, row = boss.row, props = {} })
    other.zone, other.levelRef = boss.zone, level
    other.x, other.y, other.state, other.deadTimer, other.facing = boss.x, boss.y, boss.state, boss.deadTimer, boss.facing
    other:netApplyExtra(data, data, 1)
    local notesSame = #other.notes == #boss.notes
    for i, n in ipairs(boss.notes) do
        local o = other.notes[i]
        if not o or math.abs(o.x - n.x) > 1 or math.abs(o.y - n.y) > 1 or o.c ~= n.c then notesSame = false end
    end
    local nNotes = #boss.notes
    local same = math.abs(other.songT - boss.songT) < 0.011 and other.rage and other.markX == boss.markX
        and #other.waves == #boss.waves and notesSame and #boss.notes >= 1
    songAt(boss, barOf('A', 4), 12.5)
    stepAll(level, es, { pa }, 0.05, function() pa.vx, pa.invT = 0, 9 end)
    other.state, other.deadTimer = boss.state, boss.deadTimer
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, boss.x, gob.y, false)
    local i1, i2 = boss:interact(p1), other:interact(p1)
    check('red', same and i1 == i2 and i1 == 'stomp',
        ('datos iguales=%s (%d campos, %d notas) · interact %s / %s'):format(tostring(same), #data, nNotes, tostring(i1), tostring(i2)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'reloj', 'salto', 'notas', 'pose', 'trampolin', 'tocar', 'enfado', 'solo', 'derrota', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
