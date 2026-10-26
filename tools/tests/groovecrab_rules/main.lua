-- tools/tests/groovecrab_rules — reglas de EL GROOVE (types/groovecrab.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_groove.json). El reloj del jefe es su canción: cada caso lo pone en el compás que prueba.
--   reloj      la canción → sección, compás y semicorchea (intro 8 + bucle A16 B16 SOLO8 SUBIDA8 CLÍMAX16 VUELTA4,
--              y vuelve a la A); dónde va la nota dorada (último compás de cada 4, en la 12; en el solo, compases 1
--              y 5 en la 0) y dónde la pista de baile (la subida y la 2ª mitad del clímax)
--   salto      en la A: agachado con la diana sobre ti, salta en la semicorchea 8 y CAE en la 0 del compás siguiente
--              (± un paso) en la diana (≤ 4 px): dos ondas de arena; una onda le quita 1 a quien está en el suelo
--   notas      en la B dispara en los pops (2 en un compás: semicorcheas 4 y 8) hacia el jugador; una nota quita 1
--   dorada     en la 12 del compás 4 dispara la DORADA, alta: a un jugador quieto en el suelo le pasa por encima sin
--              tocarle; saltar contra ella la devuelve, le da y le REVIENTA el trampolín → aturdido (vulnerable)
--   aturdido   aturdido: pisotón -1, otro -1 y con el 2º le crece el trampolín ('regrow'), un 3º no le da; sin golpes, a
--              los 2 compases también; con el trampolín de nuevo fuera vuelve a lo suyo
--   trampolin  con el trampolín, caerle encima te LANZA (vy ≈ salto × 1,85), también con ground pound, sin daño;
--              aturdido (sin trampolín), el pisotón le da
--   tocar      tocar su cuerpo de lado quita 1; su pinza, no; aturdido, no
--   pista      en la subida: unas baldosas avisan (tiempo 1) y en el 2 lanzan la columna: encima quita 1, en una
--              apagada no, en la plataforma de encima tampoco
--   conga      en el solo entra una fila de 4 cangrejos que avanza una casilla por tiempo; tocarlos de lado quita 1;
--              pisarlos los quita (y rebotas)
--   enfado     a media vida se enfada; enfadado salta también en los compases pares de la A (tranquilo, no)
--   solo       en el compás 1 del solo, dorada en la 0; en el 2, un saltito que cae en el 3 justo en el golpe, sin ondas
--   derrota    el último golpe: aturdido, se va de un bote hacia arriba (libera la zona) hasta irse; sin fragmento
--   red        netPackExtra → otro Groove (cliente): canción, enfado, diana, ondas, notas (con la dorada) y conga
--              iguales; interact igual
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
    boss.hop, boss.waves, boss.notes, boss.congas = nil, {}, {}, {}
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

-- aturde al jefe como en el juego: dispara la dorada y un jugador salta contra ella
local function stunIt(level, es, boss, pa)
    songAt(boss, barOf('A', 4), 11.5)
    local stunned
    stepAll(level, es, { pa }, 3, function()
        pa.vx, pa.invT = 0, 9
        for _, n in ipairs(boss.notes) do if n.c == 4 then pa.x, pa.y = n.x, n.y end end
        if boss.state == 'stunned' then stunned = true; return true end
    end)
    return stunned
end

function cases.reloj()
    local _, _, boss = arena()
    local W = boss.where
    local function is(t, sec, k) local _, s, kk = W(t); return s == sec and kk == k end
    local B = boss.BAR
    local ok = is(0, 'I', 1) and is(8 * B + 0.01, 'A', 1) and is(24 * B + 0.01, 'B', 1) and is(40 * B + 0.01, 'K', 1)
        and is(48 * B + 0.01, 'S', 1) and is(56 * B + 0.01, 'C', 1) and is(72 * B + 0.01, 'O', 1)
        and is((8 + 68) * B + 0.01, 'A', 1) and is((8 + 68 + 35) * B + 0.01, 'K', 4)
    local gold = boss.goldAt('A', 4) == 12 and boss.goldAt('A', 3) == nil and boss.goldAt('K', 1) == 0
        and boss.goldAt('K', 3) == nil and boss.goldAt('K', 5) == 0 and boss.goldAt('I', 4) == nil and boss.goldAt('O', 4) == nil
    local floor = boss.floorOn('S', 1) and boss.floorOn('C', 9) and not boss.floorOn('C', 8) and not boss.floorOn('A', 1)
    check('reloj', ok and gold and floor and boss.LOOP == 68,
        ('secciones=%s · dorada=%s · pista=%s · bucle %d compases (%.1f s)'):format(tostring(ok), tostring(gold), tostring(floor),
            boss.LOOP, boss.LOOP * B))
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
    pa.invT = 0
    local hp0 = pa.hp
    songAt(boss, barOf('B', 1), 3.5)
    stepAll(level, es, { pa }, 1.5, function() pa.vx = 0 end)
    check('notas', fired == 2 and toward and pa.hp < hp0,
        ('notas en el compás B1: %d (pops 4 y 8) · hacia él: %s · le quita: %d→%d'):format(fired, tostring(toward), hp0, pa.hp))
end

function cases.dorada()
    local level, es, boss = arena()
    local pa = playerAt(level, 16)
    -- quieto en el suelo: le pasa por encima
    -- (la dorada no hace daño nunca: no tiene golpe; aquí solo se mira que no la toque. invT: que el salto del
    -- compás siguiente no le cuente)
    songAt(boss, barOf('A', 4), 11.5)
    local fired, returned = false, false
    stepAll(level, es, { pa }, 3, function()
        pa.x, pa.vx, pa.invT = 16 * T - T / 2, 0, 9
        for _, n in ipairs(boss.notes) do if n.c == 4 then fired = true elseif n.c == 5 then returned = true end end
    end)
    local over = fired and not returned and boss.state ~= 'stunned'
    -- saltando contra ella: se la devuelve y le revienta el trampolín
    local stunned = stunIt(level, es, boss, pa)
    check('dorada', over and stunned and boss:isVulnerable() and not boss:trampOut(),
        ('disparada en la 12: %s · quieto en el suelo le pasa por encima (no la devuelve): %s · saltando contra ella: aturdido=%s, vulnerable=%s, sin trampolín=%s'):format(
            tostring(fired), tostring(over), tostring(stunned), tostring(boss:isVulnerable()), tostring(not boss:trampOut())))
end

function cases.aturdido()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    stunIt(level, es, boss, pa)
    local gob = boss:getOuterBounds()
    local hp0 = boss.hp
    local r1 = boss:interact(dropOn(level, boss.x, gob.y, false)); if r1 == 'stomp' then boss:stomp() end
    boss.inv = 0
    local r2 = boss:interact(dropOn(level, boss.x, gob.y, false)); if r2 == 'stomp' then boss:stomp() end
    local after2 = boss.state
    boss.inv = 0
    local r3 = boss:interact(dropOn(level, boss.x, gob.y, false))
    local hits = hp0 - boss.hp
    -- sin golpes: a los 2 compases le crece el trampolín y vuelve a lo suyo
    local level2, es2, boss2 = arena()
    local pb = playerAt(level2, 14)
    stunIt(level2, es2, boss2, pb)
    local t0 = boss2.songT
    local regrowT, backT
    stepAll(level2, es2, { pb }, 5, function()
        pb.vx, pb.invT = 0, 9
        if boss2.state == 'regrow' and not regrowT then regrowT = boss2.songT - t0 end
        if regrowT and boss2:trampOut() and not backT then backT = boss2.songT - t0 end
        if backT and boss2.state ~= 'regrow' then return true end
    end)
    check('aturdido', r1 == 'stomp' and r2 == 'stomp' and hits == 2 and after2 == 'regrow' and r3 ~= 'stomp'
        and regrowT and math.abs(regrowT - 2 * boss.BAR) < 0.05 and backT and boss2.state ~= 'stunned',
        ('pisotones %s, %s (-%d) → %s; un 3º: %s · sin golpes, le crece a los %.2f s (2 compases = %.2f) y lanza otra vez a los %.2f s'):format(
            tostring(r1), tostring(r2), hits, tostring(after2), tostring(r3), regrowT or -1, 2 * boss.BAR, backT or -1))
end

function cases.trampolin()
    local level, es, boss = arena()
    songAt(boss, barOf('A', 2), 2)
    level.players = {}
    stepAll(level, es, {}, 0.05)
    local tb = boss:trampBox()
    local r1, _, vy = boss:interact(dropOn(level, boss.x, tb.y + 10, false))
    local r2 = boss:interact(dropOn(level, boss.x, tb.y + 10, true))
    local want = -math.abs(ADV_JUMP_VEL) * 1.85
    local pa = playerAt(level, 14)
    stunIt(level, es, boss, pa)
    local r3 = boss:interact(dropOn(level, boss.x, boss:getOuterBounds().y, false))
    check('trampolin', r1 == 'launch' and math.abs(vy - want) < 1 and r2 == 'launch' and r3 == 'stomp',
        ('caerle encima: %s (vy %s, quiere %.0f) · con ground pound: %s · aturdido (sin trampolín): %s'):format(tostring(r1),
            tostring(vy), want, tostring(r2), tostring(r3)))
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
    local pc = playerAt(level, 14)
    local f = boss.facing or 1
    pc.x, pc.y, pc.invT = boss.x + f * 15 * boss.MS, boss.floorY - pc:getOuterBounds().h / 2 - 2, 0
    boss.graceT = 0
    level.players = { pc }
    local hpc = pc.hp
    boss:touch(level)
    local claw = hpc - pc.hp
    local pd = playerAt(level, 14)
    stunIt(level, es, boss, pd)
    local pb = playerAt(level, 14)
    local b2 = boss:getOuterBounds()
    pb.x, pb.y, pb.invT = b2.x - 10, boss.floorY - pb:getOuterBounds().h / 2 - 2, 0
    boss.graceT = 0
    level.players = { pb }
    local hp1 = pb.hp
    boss:touch(level)
    check('tocar', side == 1 and claw == 0 and pb.hp == hp1, ('el cuerpo de lado: -%d · la pinza: -%d · aturdido: -%d'):format(side, claw, hp1 - pb.hp))
end

function cases.pista()
    local level, es, boss = arena()
    songAt(boss, barOf('S', 1), 0.5)
    stepAll(level, es, {}, 0.02)
    local f0 = boss:floorNow()
    local n, x0 = boss:panels()
    local litI, darkI
    for i = 0, n - 1 do if f0.lit[i] and not litI and math.abs(x0 + (i + 0.5) * boss.PANEL - boss.x) > 3 * T then litI = i end end
    for i = 0, n - 1 do if not f0.lit[i] and not darkI and math.abs(x0 + (i + 0.5) * boss.PANEL - boss.x) > 3 * T then darkI = i end end
    local warn = f0.warn and not f0.boom
    local function standOn(i, row)
        local pa = playerAt(level, math.floor((x0 + (i + 0.5) * boss.PANEL) / T) + 1, row)
        pa.invT = 0
        return pa
    end
    local p1, p2 = standOn(litI), standOn(darkI)
    local pl = standOn(0, 7)                                                 -- (la plataforma de la izquierda, fila 8)
    songAt(boss, barOf('S', 1), 3.9)
    local h1, h2, hl = p1.hp, p2.hp, pl.hp
    local boomSeen
    stepAll(level, es, { p1, p2, pl }, 0.3, function()
        p1.vx, p2.vx, pl.vx = 0, 0, 0
        local f = boss:floorNow(); if f and f.boom then boomSeen = true end
    end)
    local onPlat = boss:floorNow().lit[0]
    check('pista', warn and boomSeen and p1.hp < h1 and p2.hp == h2 and pl.hp == hl,
        ('tiempo 1: aviso=%s · tiempo 2: columna=%s · encima de una encendida: %d→%d · en una apagada: %d→%d · en la plataforma (baldosa 0 encendida=%s): %d→%d'):format(
            tostring(warn), tostring(boomSeen), h1, p1.hp, h2, p2.hp, tostring(onPlat), hl, pl.hp))
end

function cases.conga()
    local level, es, boss = arena()
    songAt(boss, barOf('K', 1) - 1, 15.9)                                    -- (justo antes del solo: entra al pasar de compás)
    local pa = playerAt(level, 2)
    stepAll(level, es, { pa }, 0.05, function() pa.vx = 0 end)
    local line = boss.congas[1]
    local x0 = line and boss:congaPos(line, 0)
    stepAll(level, es, { pa }, 3 * 0.4, function() pa.vx = 0 end)
    local x3 = line and boss:congaPos(line, 0)
    local moved = x0 and x3 and math.floor(math.abs(x3 - x0) / T + 0.5)
    -- tocarlo de lado quita 1
    local x, feet = boss:congaPos(line, 0)
    local pb = playerAt(level, 2)
    pb.x, pb.y, pb.invT = x + line.dir * 20, feet - pb:getOuterBounds().h / 2 - 1, 0
    local hp0 = pb.hp
    level.players = { pb }
    boss:updateConga(level, -1, 'B', 2, 0, function() return false end)
    local side = hp0 - pb.hp
    -- pisarlo lo quita
    local x1, feet1 = boss:congaPos(line, 1)
    local pc = playerAt(level, 2)
    local ob = pc:getOuterBounds()
    pc.x, pc.y, pc.vy, pc.onGround = x1, feet1 - 34 - ob.h / 2 + 6, 400, false
    level.players = { pc }
    boss:updateConga(level, -1, 'B', 2, 0, function() return false end)
    local stomped = boss.bit(line.dead, 1) and pc.vy < 0
    check('conga', line ~= nil and moved == 3 and side == 1 and stomped,
        ('fila al empezar el solo: %s (desde %s) · en 3 tiempos avanza %s casillas · de lado: -%d · pisado: fuera=%s'):format(
            tostring(line ~= nil), line and (line.dir > 0 and 'la izquierda' or 'la derecha') or '?', tostring(moved), side, tostring(stomped)))
end

function cases.enfado()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    local calm = boss.plan('A', 2, false).hop
    boss.hp = math.floor(boss.hpMax / 2) + 1
    stunIt(level, es, boss, pa)
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
    songAt(boss, barOf('K', 1) - 1, 15.9)
    local gold
    stepAll(level, es, { pa }, 0.15, function() pa.vx, pa.invT = 0, 9; for _, n in ipairs(boss.notes) do if n.c == 4 then gold = true end end end)
    songAt(boss, barOf('K', 2), 0)
    local landT, waves
    stepAll(level, es, { pa }, boss.BAR + 0.1, function()
        pa.vx, pa.invT = 0, 9
        if boss.state == 'hop' then landT = false end
        if landT == false and boss.state ~= 'hop' then landT, waves = boss.songT, #boss.waves end
    end)
    local onHit = landT and math.abs(landT - barOf('K', 3) * boss.BAR) <= 1.5 / 60
    check('solo', gold and onHit and waves == 0,
        ('K1: dorada en la 0=%s · el saltito de K2 cae en el golpe de K3: %s · ondas %s'):format(tostring(gold), tostring(onHit), tostring(waves)))
end

function cases.derrota()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    stunIt(level, es, boss, pa)
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
    songAt(boss, barOf('B', 4), 0)
    stepAll(level, es, { pa }, 1.35, function() pa.vx, pa.invT = 0, 9 end)
    boss.rage = true
    require('src/world/entities/base/BossWaves').spawn(boss, boss.floorY, boss.outerW / 2)
    boss:startConga(barOf('K', 1), -1)
    boss.congas[1].dead = 2
    local data = boss:netPackExtra()
    local other = Entities.create({ type = 'groovecrab', col = boss.col, row = boss.row, props = {} })
    other.zone, other.levelRef = boss.zone, level
    other.x, other.y, other.state, other.deadTimer, other.facing = boss.x, boss.y, boss.state, boss.deadTimer, boss.facing
    other:netApplyExtra(data, data, 1)
    local notesSame, hasGold = #other.notes == #boss.notes, false
    for i, n in ipairs(boss.notes) do
        local o = other.notes[i]
        if n.c == 4 then hasGold = true end
        if not o or math.abs(o.x - n.x) > 1 or math.abs(o.y - n.y) > 1 or o.c ~= n.c then notesSame = false end
    end
    local nNotes = #boss.notes
    local cg = other.congas[1]
    local same = math.abs(other.songT - boss.songT) < 0.011 and other.rage and other.markX == boss.markX
        and #other.waves == #boss.waves and notesSame and nNotes >= 1 and cg and cg.b0 == barOf('K', 1) and cg.dir == -1 and cg.dead == 2
    local pd = playerAt(level, 14)
    stunIt(level, es, boss, pd)
    other.state, other.deadTimer, other.stunHits = boss.state, boss.deadTimer, boss.stunHits
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, boss.x, gob.y, false)
    local i1, i2 = boss:interact(p1), other:interact(p1)
    check('red', same and hasGold and i1 == i2 and i1 == 'stomp',
        ('datos iguales=%s (%d campos, %d notas, dorada=%s, conga=%s) · interact %s / %s'):format(tostring(same), #data, nNotes,
            tostring(hasGold), tostring(cg ~= nil), tostring(i1), tostring(i2)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'reloj', 'salto', 'notas', 'dorada', 'aturdido', 'trampolin', 'tocar', 'pista', 'conga', 'enfado',
                         'solo', 'derrota', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
