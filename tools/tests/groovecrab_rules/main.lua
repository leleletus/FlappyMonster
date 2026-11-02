-- tools/tests/groovecrab_rules — reglas de EL GROOVE (types/groovecrab.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_groove.json). El reloj del jefe es su canción: cada caso lo pone en el compás que prueba.
--   reloj      la canción → sección, compás y semicorchea (intro 8 + bucle A16 B16 SOLO8 SUBIDA8 CLÍMAX16 VUELTA4,
--              y vuelve a la A); dónde va la nota dorada (último compás de cada 8, en la 12; en el solo, el compás 5
--              en la 0) y dónde la pista de baile (la subida y la 2ª mitad del clímax)
--   salto      en la A: agachado con la diana sobre ti, salta en la semicorchea 8 y CAE en la 0 del compás siguiente
--              (± un paso) en la diana (≤ 4 px): dos ondas de arena; una onda le quita 1 a quien está en el suelo
--   notas      en la B dispara en los pops (2 en un compás: semicorcheas 4 y 8) hacia el jugador; una nota quita 1
--   dorada     en la 12 del compás 8 dispara la DORADA, alta: a un jugador quieto en el suelo le pasa por encima sin
--              tocarle; saltar contra ella la devuelve, le da y le REVIENTA el trampolín → aturdido (vulnerable)
--   aturdido   aturdido: UN solo golpe (-1) y le crece el trampolín ('regrow'), un 3º no le da; sin golpes, a
--              los 2 compases también; con el trampolín de nuevo fuera vuelve a lo suyo
--   trampolin  con el trampolín, caerle encima te LANZA (vy ≈ salto × 1,85), también con ground pound, sin daño;
--              aturdido (sin trampolín), el pisotón le da
--   tocar      tocar su cuerpo de lado quita 1; su pinza, no; aturdido, no
--   pista      en la subida: un dibujo por compás; las baldosas avisan 3 tiempos (1,2 s) y en el 4º lanzan la
--              columna: encima quita 1, en una apagada no, en la plataforma de encima tampoco
--   dibujos    las notas, por parejas de compases de la B: recta, abanico (3 por pop), en arco (cae a menos de 1,5
--              casillas de los pies del jugador), y otra vez; enfadado, sin abanico
--   baile      entre ataques cruza el escenario a pasitos (en la A, compás par: se mueve ≥ media casilla) y no se
--              acerca andando a un jugador que tiene cerca
--   temblor    cada golpe que recibe hace temblar la pantalla
--   platos     2ª FASE: los platos de DJ están en las dos plataformas; en la 1ª fase pisarlos no hace nada; en la 2ª ya
--              no hay dorada, pisar uno lo pone a girar (y rebotas) DECK_T s y luego se apaga; los dos a la vez → el
--              BAJÓN: noqueado y vulnerable, platos apagados; él no va a ponerse bajo el otro (baila como siempre)
--   enfriar    tras el bajón, los platos no se pueden encender DECK_COOL s (0.5.64)
--   ocultos    2ª fase, con la PISTA encendida (la S): los platos y sus plataformas no están (un plato encendido se
--              APAGA: vuelve apagado — 0.5.65) y, al acabar, vuelven
--   publico    el público vitorea cuando le da a un jugador y abuchea cuando le das (lo que llega por red)
--   trepar     (2ª fase: las plataformas son bloques de fase) caerle al trampolín y mantener hacia un lado te deja
--              en la plataforma de ese lado (a 5 casillas: con el doble salto no se llega)
--   enfado     a media vida se enfada (2ª fase); enfadado salta también en el 4º compás de cada 4 de la A (tranquilo, no)
--   solo       en el compás 5 del solo, dorada en la 0 (en el 1 ya no); en el 2, un saltito que cae en el 3 justo en el
--              golpe, sin ondas
--   derrota    el último golpe: aturdido, REVIENTA (libera la zona, explosión grande, abucheo) y, recogido el escenario,
--              se acaba; no se mueve de su sitio; sin fragmento
--   duelo      al principio de "la pista" (8 o 16 compases): un compás de aviso, sin peligros; el jugador sin control e
--              invulnerable y él bailando; acaba solo, sin castigar a quien no dio resultado
--   duelo_ko   un buen resultado lo noquea; un fallo quita 1; en Fácil y Normal no mata, en Difícil sí; online, por mayoría
--   duelo_solo prop duelOnly: el único ataque es un duelo de toda la canción, no se puede fallar y al acabar muere
--   duelo_red  el duelo viaja en netPackExtra
--   red        netPackExtra → otro Groove (cliente): canción, enfado, fase, diana, ondas, notas (con la dorada),
--              platos y bajón iguales; interact igual
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

local ARENA = os.getenv('ARENA') or 'tools/levelgen/arenas/jefe_groove.json'
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

-- (las plataformas de los platos: bloques de fase, solo en la 2ª fase; esto las pone como al llegar a ella)
local function platformsOn(level)
    level.bossZones[1].phase = 2
    require('src/world/systems/PhaseBlocks').update(level)
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

-- aturde al jefe como en el juego: dispara la dorada y un jugador salta contra ella
local function stunIt(level, es, boss, pa)
    songAt(boss, barOf('A', 8), 11.5)
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
        and is(48 * B + 0.01, 'S', 1) and is(56 * B + 0.01, 'C', 1) and is(72 * B + 0.01, 'D', 1) and is(88 * B + 0.01, 'O', 1)
        and boss.plan('D', 1).hop and #boss.plan('D', 2).notes == 2 and boss.goldAt('D', 8) == 12 and boss.floorOn('D', 9) and not boss.floorOn('D', 8)
        and is((8 + 84) * B + 0.01, 'A', 1) and is((8 + 84 + 35) * B + 0.01, 'K', 4)
    local gold = boss.goldAt('A', 8) == 12 and boss.goldAt('A', 4) == nil and boss.goldAt('B', 16) == 12 and boss.goldAt('K', 1) == nil
        and boss.goldAt('K', 3) == nil and boss.goldAt('K', 5) == 0 and boss.goldAt('I', 8) == nil and boss.goldAt('O', 4) == nil
    local floor = boss.floorOn('S', 1) and boss.floorOn('C', 9) and not boss.floorOn('C', 8) and not boss.floorOn('A', 1)
    check('reloj', ok and gold and floor and boss.LOOP == 84,
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
    stepAll(level, es, { pb }, 2.0, function() pb.vx = 0 end)              -- (la onda, a 420 px/s: 12 casillas)
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
    songAt(boss, barOf('A', 8), 11.5)
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
    check('aturdido', r1 == 'stomp' and r2 ~= 'stomp' and hits == 1 and after2 == 'regrow' and r3 ~= 'stomp'
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
    local d1 = dropOn(level, boss.x, tb.y + 10, false)
    local r1, _, vy = boss:interact(d1)
    local r2 = boss:interact(dropOn(level, boss.x, tb.y + 10, true))
    -- (0.5.149: hasta una altura fija —el centro a LAUNCH_APEX del suelo—, no × 1,85)
    local want = -math.sqrt(2 * ADV_GRAVITY * (d1.y - (boss.floorY - boss.LAUNCH_APEX)))
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
    -- (en la plataforma de la izquierda, fila 8 —solo está en la 2ª fase—, la columna no llega; en la 1ª, tampoco está)
    local gone = level:getDef(14, 8).collision == 'none'
    platformsOn(level)
    local pl = standOn(0, 7)
    songAt(boss, barOf('S', 1), 11.9)
    local h1, h2, hl = p1.hp, p2.hp, pl.hp
    local boomSeen
    stepAll(level, es, { p1, p2, pl }, 0.3, function()
        p1.vx, p2.vx, pl.vx = 0, 0, 0
        local f = boss:floorNow(); if f and f.boom then boomSeen = true end
    end)
    local onPlat = boss:floorNow().lit[0]
    check('pista', warn and boomSeen and p1.hp < h1 and p2.hp == h2 and pl.hp == hl and gone,
        ('tiempo 1: aviso=%s · tiempo 4: columna=%s · encima de una encendida: %d→%d · en una apagada: %d→%d · en la plataforma (baldosa 0 encendida=%s): %d→%d · plataforma en la 1ª fase: %s'):format(
            tostring(warn), tostring(boomSeen), h1, p1.hp, h2, p2.hp, tostring(onPlat), hl, pl.hp, gone and 'no está' or 'ESTÁ'))
end

-- pasa a la 2ª fase como en el juego (aturdido, el golpe que lo deja a media vida) y espera a que vuelva a lo suyo
-- cae sobre un plato: los pies 6 px por debajo de su cara de arriba
local function onDeck(level, boss, d)
    local box = boss:deckBox(d)
    local pa = dropOn(level, d.x, box.y, false)
    local pb = pa:getOuterBounds()
    pa.y = pa.y + (box.y + 6) - (pb.y + pb.h)
    pa.prevY = pa.y - 6
    return pa
end
local function phase2(level, es, boss, pa)
    boss.hp = math.floor(boss.hpMax * 0.5) + 1
    stunIt(level, es, boss, pa)
    boss:stomp()
    boss.inv = 0
    boss:enter('groove')
end

function cases.dibujos()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    local function bar(k, secs)
        songAt(boss, barOf('B', k), 3.5)
        local seen, list = {}, {}
        stepAll(level, es, { pa }, secs or 0.15, function()
            pa.x, pa.vx, pa.invT = 14 * T - T / 2, 0, 9
            for _, n in ipairs(boss.notes) do if not seen[n.id] then seen[n.id] = true; list[#list + 1] = n end end
        end)
        return list
    end
    local aim = #bar(1)
    local fan = #bar(3)
    -- en arco: cae cerca de los pies
    local lob = bar(5, 0.1)[1]
    local landX
    if lob then
        stepAll(level, es, { pa }, 1.5, function()
            pa.x, pa.vx, pa.invT = 14 * T - T / 2, 0, 9
            local alive = false
            for _, n in ipairs(boss.notes) do if n.id == lob.id then alive = true; landX = n.x end end
            return not alive
        end)
    end
    local near = landX and math.abs(landX - pa.x) < 1.5 * T
    local rageFan = boss.noteKind('B', 3, true)
    local kinds = boss.noteKind('B', 1) .. ',' .. boss.noteKind('B', 3) .. ',' .. boss.noteKind('B', 5) .. ',' .. boss.noteKind('B', 7)
    check('dibujos', aim == 1 and fan == 3 and near and rageFan ~= 'fan' and kinds == 'aim,fan,lob,aim',
        ('B1 recta: %d nota · B3 abanico: %d · B5 en arco: cae a %s px de los pies · enfadado, B3: %s · B1/3/5/7: %s'):format(
            aim, fan, landX and math.floor(math.abs(landX - pa.x)) or '?', rageFan, kinds))
end

function cases.baile()
    local level, es, boss = arena()
    local pa = playerAt(level, 34)
    songAt(boss, barOf('A', 2), 0)
    local x0 = boss.x
    stepAll(level, es, { pa }, boss.BAR - 0.05, function() pa.x, pa.vx, pa.invT = 34 * T - T / 2, 0, 9 end)
    local moved = math.abs(boss.x - x0)
    -- con un jugador cerca en el sentido en que va, no se le acerca
    local level2, es2, boss2 = arena()
    songAt(boss2, barOf('A', 2), 0)
    local dir = (math.floor(barOf('A', 2) / 2) % 2 == 0) and -1 or 1
    local pb = playerAt(level2, 24 + dir * 2)
    local d0 = math.abs(pb.x - boss2.x)
    stepAll(level2, es2, { pb }, boss2.BAR - 0.05, function() pb.x, pb.vx, pb.invT = (24 + dir * 2) * T - T / 2, 0, 9 end)
    local d1 = math.abs(pb.x - boss2.x)
    check('baile', moved >= 0.5 * T and d1 >= d0 - 1,
        ('en un compás de baile (A2) se mueve %.0f px · con un jugador cerca delante: %.0f → %.0f px (no se acerca)'):format(moved, d0, d1))
end

function cases.temblor()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    stunIt(level, es, boss, pa)
    local shakes = 0
    local Entity = require 'src/world/entities/base/Entity'
    local fx = Entity.fx
    Entity.fx = function(kind, ...) if kind == 'shake_big' then shakes = shakes + 1 end; if fx then return fx(kind, ...) end end
    boss:stomp()
    Entity.fx = fx
    check('temblor', shakes >= 1, ('al recibir un golpe: %d temblores de pantalla'):format(shakes))
end

function cases.platos()
    local level, es, boss = arena()
    local pa = playerAt(level, 24)
    stepAll(level, es, { pa }, 0.05, function() pa.vx, pa.invT = 0, 9 end)
    local decks = boss.decks
    local found = decks and #decks == 2 and decks[1].x == 14 * T and decks[2].x == 32 * T and decks[1].y == 7 * T
    -- 1ª fase: pisarlo no hace nada
    local p1 = onDeck(level, boss, decks[1])
    stepAll(level, es, { p1 }, 2 / 60)
    local p1off = decks[1].on == 0
    -- 2ª fase
    phase2(level, es, boss, pa)
    local p2 = boss.phase == 2 and boss.rage
    songAt(boss, barOf('A', 8), 11.5)
    local gold = false
    stepAll(level, es, { pa }, 1.0, function()
        pa.vx, pa.invT = 0, 9
        for _, n in ipairs(boss.notes) do if n.c >= 4 then gold = true end end
    end)
    boss:enter('groove')
    local pl = onDeck(level, boss, decks[1])
    stepAll(level, es, { pl }, 2 / 60, function() pl.invT = 9 end)
    local spun, bounced = decks[1].on > boss.DECK_T - 0.1, pl.vy < 0
    stepAll(level, es, {}, boss.DECK_T + 0.1)
    local stopped = decks[1].on == 0
    -- los dos: el bajón
    local hp0 = boss.hp
    local a1 = onDeck(level, boss, decks[1])
    stepAll(level, es, { a1 }, 2 / 60, function() a1.invT = 9 end)
    local a2 = onDeck(level, boss, decks[2])
    stepAll(level, es, { a2 }, 2 / 60, function() a2.invT = 9 end)
    local ko = boss.state == 'stunned' and boss:isVulnerable() and not boss:trampOut() and boss.dropT ~= nil
        and decks[1].on == 0 and decks[2].on == 0
    check('platos', found and p1off and p2 and not gold and spun and bounced and stopped and ko and boss.hp == hp0,
        ('platos en las plataformas: %s (x %s, %s; y %s) · 1ª fase, pisarlo: nada=%s · 2ª fase=%s, dorada=%s · pisado: gira=%s, rebota=%s, a los %.1f s se apaga=%s · los dos: noqueado=%s'):format(
            tostring(found), decks and math.floor(decks[1].x) or '?', decks and math.floor(decks[2].x) or '?',
            decks and math.floor(decks[1].y) or '?', tostring(p1off), tostring(p2), tostring(gold), tostring(spun),
            tostring(bounced), boss.DECK_T, tostring(stopped), tostring(ko)))
end

-- (las casillas de las plataformas: ¿están todas puestas / todas quitadas?)
local function platCells(level)
    local on, n = 0, 0
    for _, pb in ipairs(level.phaseBlocks or {}) do
        for _, cell in ipairs(pb.cells) do
            n = n + 1
            if level:getRaw(cell.c, cell.r) == cell.raw then on = on + 1 end
        end
    end
    return on, n
end

function cases.ocultos()
    local level, es, boss = arena()
    local pa = playerAt(level, 24)
    phase2(level, es, boss, pa)
    platformsOn(level)
    songAt(boss, barOf('A', 8), 0)
    stepAll(level, es, { pa }, 0.1, function() pa.vx, pa.invT = 0, 9 end)
    local on0, n = platCells(level)
    boss.decks[1].on = boss.DECK_T
    songAt(boss, barOf('S', 2), 0)
    stepAll(level, es, { pa }, 1.0, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T end)
    local onS = platCells(level)
    local away, live, left = boss:decksAway(), boss:decksLive(), boss.decks[1].on
    songAt(boss, barOf('C', 1), 0)
    stepAll(level, es, { pa }, 0.5, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T end)
    local onC = platCells(level)
    check('ocultos', n > 0 and on0 == n and onS == 0 and away and not live and left == 0 and boss.decks[1].on == 0
        and onC == n and not boss:decksAway(),
        ('plataformas antes: %d/%d · con la pista: %d (platos fuera=%s, pisables=%s, encendido → apagado y sigue apagado al volver=%s) · después: %d'):format(
            on0, n, onS, tostring(away), tostring(live), tostring(left == 0 and boss.decks[1].on == 0), onC))
end

function cases.publico()
    local level, es, boss = arena()
    local pa = playerAt(level, 30)
    songAt(boss, barOf('B', 1), 0)
    stepAll(level, es, { pa }, 0.1, function() pa.vx, pa.invT = 0, 9 end)
    local calm = boss:crowdMood()
    pa.invT = 0
    pa:hurt(1)
    stepAll(level, es, { pa }, 0.1, function() pa.vx, pa.invT = 0, 9 end)
    local cheer = boss:crowdMood()
    -- por red
    local data = boss:netPackExtra()
    local cl = Entities.create({ type = 'groovecrab', col = boss.col, row = boss.row, props = {} })
    cl.zone, cl.levelRef, cl.state = boss.zone, level, boss.state
    cl:netApplyExtra(data, data, 1)
    local netCheer = cl:crowdMood()
    stepAll(level, es, { pa }, boss.MOOD_T + 0.2, function() pa.vx, pa.invT = 0, 9 end)
    local over = boss:crowdMood()
    stunIt(level, es, boss, pa)
    boss:stomp()
    local boo = boss:crowdMood()
    check('publico', calm == nil and cheer == boss.CHEER and netCheer == boss.CHEER and over == nil and boo == boss.BOO,
        ('tranquilo: %s · te da: %s (cliente: %s) · %.0f s después: %s · le das: %s'):format(tostring(calm), tostring(cheer),
            tostring(netCheer), boss.MOOD_T + 0.2, tostring(over), tostring(boo)))
end

-- Lo que pide la 2ª fase se puede hacer: del trampolín a cada plataforma, manteniendo hacia ese lado
function cases.trepar()
    local results = {}
    for _, side in ipairs({ -1, 1 }) do
        local level, es, boss = arena()
        platformsOn(level)
        songAt(boss, barOf('B', 1), 0)                                     -- (la B: no salta)
        boss.x = 23 * T + side * 3 * T
        local tb = boss:trampBox()
        local pa = playerAt(level, 2)
        local ob = pa:getOuterBounds()
        pa.x, pa.y, pa.vy, pa.onGround = boss.x, tb.y - ob.h / 2 - 4, 300, false
        local landedY
        for _ = 1, 3 * 60 do
            level.players = { pa }
            level.solidBodies = Entities.solidBodies(es)
            for k in pairs(stub.state) do stub.state[k] = false end
            stub.state[side < 0 and 'left' or 'right'] = true
            pa.invT = 9
            pa:update(DT, level)
            local r, a, b, c = boss:interact(pa)
            if r == 'launch' then pa:launch(a, b, c) end
            boss.songT, boss.prevT = barOf('B', 1) * boss.BAR, barOf('B', 1) * boss.BAR - 1e-4  -- (quieto: sin notas)
            if pa.onGround and pa.vy >= 0 and pa.y < boss.floorY - 3 * T then landedY = pa.y; break end
        end
        results[#results + 1] = landedY ~= nil
    end
    for k in pairs(stub.state) do stub.state[k] = false end
    check('trepar', results[1] and results[2], ('del trampolín a la plataforma izquierda: %s · derecha: %s'):format(
        tostring(results[1]), tostring(results[2])))
end

function cases.enfado()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    local calm = boss.plan('A', 4, false).hop
    boss.hp = math.floor(boss.hpMax / 2) + 1
    stunIt(level, es, boss, pa)
    boss:stomp()
    local angry = boss.rage and boss.phase == 2
    local hopped
    songAt(boss, barOf('A', 4), 0)
    stepAll(level, es, { pa }, 1.0, function()
        pa.vx, pa.invT = 0, 9
        if boss.state == 'hop' then hopped = true end
    end)
    check('enfado', angry and not calm and hopped, ('enfadado a media vida: %s · A4 tranquilo salta: %s · enfadado: %s'):format(
        tostring(angry), tostring(calm), tostring(hopped)))
end

function cases.solo()
    local level, es, boss = arena()
    local pa = playerAt(level, 18)
    songAt(boss, barOf('K', 5) - 1, 15.9)
    local gold
    stepAll(level, es, { pa }, 0.15, function() pa.vx, pa.invT = 0, 9; for _, n in ipairs(boss.notes) do if n.c == 4 then gold = true end end end)
    songAt(boss, barOf('K', 1) - 1, 15.9)
    local gold1
    stepAll(level, es, { pa }, 0.15, function() pa.vx, pa.invT = 0, 9; for _, n in ipairs(boss.notes) do if n.c == 4 then gold1 = true end end end)
    songAt(boss, barOf('K', 2), 0)
    local landT, waves
    stepAll(level, es, { pa }, boss.BAR + 0.1, function()
        pa.vx, pa.invT = 0, 9
        if boss.state == 'hop' then landT = false end
        if landT == false and boss.state ~= 'hop' then landT, waves = boss.songT, #boss.waves end
    end)
    local onHit = landT and math.abs(landT - barOf('K', 3) * boss.BAR) <= 1.5 / 60
    check('solo', gold and not gold1 and onHit and waves == 0,
        ('K5: dorada en la 0=%s · K1: %s · el saltito de K2 cae en el golpe de K3: %s · ondas %s'):format(tostring(gold),
            tostring(gold1 == true), tostring(onHit), tostring(waves)))
end

function cases.derrota()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    stunIt(level, es, boss, pa)
    boss.hp, boss.inv = 1, 0
    boss:stomp()
    local states, seen = {}, {}
    local rel, moved = false, 0
    local x0, y0 = boss.x, boss.y
    local Entity = require 'src/world/entities/base/Entity'
    local fx, big = Entity.fx, 0
    Entity.fx = function(kind, ...) if kind == 'boss_big_blast' then big = big + 1 end; if fx then return fx(kind, ...) end end
    local booT
    stepAll(level, es, { pa }, 8, function()
        pa.vx, pa.invT = 0, 9
        if not seen[boss.state] then seen[boss.state] = true; states[#states + 1] = boss.state end
        if boss:releasesZone() then rel = true end
        moved = math.max(moved, math.abs(boss.x - x0), math.abs(boss.y - y0))
        return boss.state == 'dead'
    end)
    Entity.fx = fx
    check('derrota', states[1] == 'dying_daze' and seen.dying_burst and seen.dead and rel and big == 1 and moved < 1
        and boss:shardDrop() == false,
        ('estados: %s · libera=%s · explosión grande: %d · se movió %.0f px · fragmento=%s'):format(
            table.concat(states, ','), tostring(rel), big, moved, tostring(boss:shardDrop())))
end

function cases.red()
    local level, es, boss = arena()
    local pa = playerAt(level, 16)
    songAt(boss, barOf('B', 8), 0)
    stepAll(level, es, { pa }, 1.35, function() pa.vx, pa.invT = 0, 9 end)
    boss.rage, boss.phase, boss.p2T, boss.dropT = true, 2, 3.5, 7.25
    boss.decks = boss.decks or boss:findDecks(level)
    require('src/world/entities/base/BossWaves').spawn(boss, boss.floorY, boss.outerW / 2)
    boss.decks[2].on = 4.25
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
    local od = other.decks
    local decksSame = od and #od == 2 and od[1].x == boss.decks[1].x and od[2].y == boss.decks[2].y and od[1].on == 0
        and math.abs(od[2].on - 4.25) < 0.11
    local same = math.abs(other.songT - boss.songT) < 0.011 and other.rage and other.phase == 2 and other.markX == boss.markX
        and #other.waves == #boss.waves and notesSame and nNotes >= 1 and decksSame and other.p2T == 3.5 and other.dropT == 7.25
    local pd = playerAt(level, 14)
    boss.phase = 1                                                          -- (la dorada: solo en la 1ª fase)
    stunIt(level, es, boss, pd)
    other.state, other.deadTimer, other.stunHits, other.x, other.y = boss.state, boss.deadTimer, boss.stunHits, boss.x, boss.y
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, boss.x, gob.y, false)
    local i1, i2 = boss:interact(p1), other:interact(p1)
    check('red', same and hasGold and i1 == i2 and i1 == 'stomp',
        ('datos iguales=%s (%d campos, %d notas, dorada=%s, platos=%s) · interact %s / %s'):format(tostring(same), #data, nNotes,
            tostring(hasGold), tostring(decksSame), tostring(i1), tostring(i2)))
end

-- (0.5.64) ENFRIAMIENTO: tras el bajón los platos no se pueden encender DECK_COOL s (el usuario: "se puede spamear")
function cases.enfriar()
    local level, es, boss = arena()
    local pa = playerAt(level, 24)
    stepAll(level, es, { pa }, 0.05, function() pa.vx, pa.invT = 0, 9 end)
    phase2(level, es, boss, pa)
    songAt(boss, START.A + 1, 0)
    boss:bassDrop()
    local cool0 = boss:deckCool()
    boss.state = 'groove'                                  -- (ya despierto: solo cuenta el enfriamiento)
    local liveDuring = boss:decksLive()
    boss.songT = boss.dropT + GC.DECK_COOL + 0.1
    local liveAfter = boss:decksLive()
    check('enfriar', cool0 > 0 and not liveDuring and liveAfter and boss:deckCool() == 0,
        ('tras el bajón faltan %.1f s; se pueden pisar: durante %s, después %s'):format(cool0, tostring(liveDuring), tostring(liveAfter)))
end

local function duelBar(boss)                                       -- (el compás en que empieza "la pista")
    return boss.INTRO_BARS + 16 + 16 + 8 + 8 + 16
end
function cases.duelo()
    local level, es, boss = arena('normal')
    local pa = playerAt(level, 14)
    local start = duelBar(boss)
    songAt(boss, start - 2, 15)
    boss.prevT = boss.songT - 0.01
    level.players = { pa }
    local seen = {}
    for _ = 1, 20 do
        stepAll(level, es, { pa }, 1 / 60)
        if boss.duel then break end
    end
    check('duelo', boss.duel and boss.duel.bar == start and (boss.duel.bars == 8 or boss.duel.bars == 16),
          ('se anuncia: compás %s, %s compases'):format(tostring(boss.duel and boss.duel.bar), tostring(boss.duel and boss.duel.bars)))
    boss.notes = { { id = 1, x = pa.x, y = pa.y, vx = 0, vy = 0, c = 0, t = 0 } }
    pa.hp = 3
    local bars = boss.duel.bars
    local still, hurt, moved = true, false, false
    local x0
    stepAll(level, es, { pa }, boss.BAR * (bars + 1) + 1.2, function()
        if boss:duelLive() then
            x0 = x0 or pa.x
            stub.state.move_right = true
            if not pa.frozen or not pa:isInvulnerable() then still = false end
            if #boss.notes > 0 or #boss.waves > 0 or boss.state ~= 'groove' or boss:floorNow() then hurt = true end
            if math.abs(pa.x - x0) > 2 then moved = true end
        end
    end)
    check('duelo', still and not hurt and not moved and pa.hp == 3, ('congelado=%s peligros=%s se movió=%s vida %d'):format(tostring(still), tostring(hurt), tostring(moved), pa.hp))
    check('duelo', boss.duel == nil and boss.state ~= 'stunned', 'acaba solo y sin resultado no pasa nada: ' .. boss.state)
end
function cases.duelo_ko()
    local function run(diff, acc, failed, hp)
        local level, es, boss = arena(diff)
        local pa = playerAt(level, 14)
        pa.hp = hp or 3
        local start = duelBar(boss)
        songAt(boss, start - 1, 1)
        boss.duel = { bar = start, bars = 8, res = {} }
        stepAll(level, es, { pa }, 0.1)
        boss:duelReport(pa, start, acc, failed)
        stepAll(level, es, { pa }, 0.05)
        return boss, pa
    end
    local b, p = run('normal', 0.95, false)
    check('duelo_ko', b.state ~= 'stunned' and b.hp == b.hpMax - 1, ('buen resultado: le quita 1 directamente (vida %d/%d), sin noquearlo: %s'):format(b.hp, b.hpMax, b.state))
    b, p = run('normal', 0.7, false)
    check('duelo_ko', b.state ~= 'stunned' and p.hp == 3, 'a medias: nada, vida ' .. p.hp)
    b, p = run('normal', 0.1, true, 3)
    check('duelo_ko', p.hp == 2 and b.duel == nil, 'falla: −1, vida ' .. p.hp)
    b, p = run('easy', 0.1, true, 1)
    check('duelo_ko', p.hp == 1 and not p.dying, 'en Fácil no mata')
    b, p = run('hard', 0.1, true, 1)
    check('duelo_ko', p.dying or p.lives < 3 or p.hp == p.hpMax, 'en Difícil, sí')
    -- Online: mayoría
    local level, es, boss = arena('normal')
    local p1, p2, p3 = playerAt(level, 12), playerAt(level, 14), playerAt(level, 16)
    local start = duelBar(boss)
    songAt(boss, start - 1, 1)
    boss.duel = { bar = start, bars = 8, res = {} }
    boss:duelReport(p1, start, 0.95, false)
    boss:duelReport(p2, start, 0.95, false)
    boss:duelReport(p3, start, 0.5, false)
    stepAll(level, es, { p1, p2, p3 }, 0.05)
    check('duelo_ko', boss.state ~= 'stunned' and boss.hp == boss.hpMax - 2, ('online, dos de tres bien: −2 (vida %d/%d)'):format(boss.hp, boss.hpMax))
end

-- (0.5.149) NOQUEADO SE PARA lo que hacía: en la pista de baile (la subida), con un aviso en marcha, la dorada lo noquea →
-- sin pista aturdido, recomponiéndose ni en el compás en que vuelve; las notas en vuelo se deshacen
function cases.ko_para()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    songAt(boss, barOf('S', 8), 4)
    stepAll(level, es, { pa }, 0.05, function() pa.vx, pa.invT = 0, 9 end)
    local before = boss:floorNow() ~= nil
    boss.notes[#boss.notes + 1] = { id = 77, x = 20 * T, y = 9 * T, vx = 100, vy = 0, c = 1, t = 0 }
    boss:knockOut()
    local notes = #boss.notes
    local during, woke, sameBar, nextBar = false, nil, nil, nil
    stepAll(level, es, { pa }, 6, function()
        pa.vx, pa.invT = 0, 9
        if (boss.state == 'stunned' or boss.state == 'regrow') and boss:floorNow() then during = true end
        if woke == nil and boss.state == 'groove' then woke = boss.songT end
    end)
    -- en el compás en que vuelve, no; en el siguiente (si es de pista), sí
    local b = math.floor(woke / boss.BAR)
    boss.songT = b * boss.BAR + 13 * boss.S16
    sameBar = boss:floorNow()
    check('ko_para', before and notes == 0 and not during and woke and sameBar == nil,
        ('pista antes=%s · notas tras el noqueo: %d · pista aturdido=%s · vuelve a los %.2f s; ese compás, pista=%s'):format(
            tostring(before), notes, tostring(during), woke or -1, tostring(sameBar ~= nil)))
end

-- (0.5.149) TECHO DE PINCHOS Y CORCOVEO: el lanzamiento normal + doble salto no llega a los pinchos; quien rebota CAMP_N
-- veces seguidas sin pisar el suelo hace que corcovee y el siguiente rebote lo estampa contra el techo
local function bounceLoop(level, es, boss, pa, secs, dbl)
    local minTop, launches, states = 1e9, 0, {}
    for i = 1, math.floor(secs * 60) do
        level.players = { pa }
        level.solidBodies = Entities.solidBodies(es)
        for k in pairs(stub.state) do stub.state[k] = false end
        -- (doble salto en lo más alto)
        if dbl and not pa.onGround and pa.vy > -20 and pa.vy < 40 and (pa.jumpsLeft or 0) > 0 then stub.state.jump, stub.state.jump_pressed = true, true end
        pa.x = boss.x
        pa:update(DT, level)
        local r, a, b, c = boss:interact(pa)
        if r == 'launch' then
            if os.getenv('DBG') then print(('  t=%d launch vy=%.0f estado=%s dt=%.2f y=%.0f'):format(i, b, boss.state, boss.deadTimer, pa.y)) end
            pa:launch(a, b, c); boss:onLaunch(pa); launches = launches + 1
        end
        boss:update(DT, level)
        boss.songT, boss.prevT = barOf('B', 8) * boss.BAR, barOf('B', 8) * boss.BAR - 1e-4  -- (sin notas)
        states[boss.state] = true
        if not pa.dying then minTop = math.min(minTop, pa:getOuterBounds().y) end
        if os.getenv('DBG') and i % 6 == 0 then print(('    y=%.0f top=%.0f vy=%.0f'):format(pa.y, pa:getOuterBounds().y, pa.vy)) end
        if pa.dying then break end
    end
    return minTop, launches, states
end
function cases.techo()
    local level, es, boss = arena('hard')
    local spikes = #level:getSpikesInBox(12 * T, 2 * T, 24 * T, T)
    songAt(boss, barOf('B', 8), 0)
    boss.x = 24 * T
    local tb = boss:trampBox()
    local pa = playerAt(level, 2)
    local ob = pa:getOuterBounds()
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, tb.y - ob.h / 2 - 4, 300, false
    pa.invT = 0
    -- UN rebote y doble salto arriba: no llega
    boss.CAMP_N_TEST = nil
    local top1, n1 = bounceLoop(level, es, boss, pa, 1.25, true)
    local safe = not pa.dying and n1 == 1
    -- se queda rebotando: corcovea y lo estampa
    local top2, n2, states = bounceLoop(level, es, boss, pa, 8, false)
    -- desde él en pleno salto (el trampolín más alto) se llega a lo mismo
    local _, _, boss2 = arena('hard')
    songAt(boss2, barOf('A', 1), 0)
    boss2.y = boss2.floorY - boss2.outerH / 2 - 3 * T
    local hi = dropOn(level, boss2.x, boss2:trampBox().y + 10, false)
    local _, _, vyHop = boss2:interact(hi)
    local apexHop = hi.y - vyHop * vyHop / (2 * ADV_GRAVITY)
    local apexWant = boss2.floorY - boss2.LAUNCH_APEX
    check('techo', spikes >= 24 and safe and top1 > 2 * T + 13 + 15 and states.buck and pa.dying and math.abs(apexHop - apexWant) < 2,
        ('pinchos en el techo: %d · un rebote + doble salto: lo más alto %.0f px (pinchos hasta 141), vivo=%s · rebotando: %d rebotes, corcovea=%s, muere en los pinchos=%s (lo más alto %.0f) · lanzado con él saltando: centro a %.0f (quiere %.0f)'):format(
            spikes, top1, tostring(safe), n2 + n1, tostring(states.buck == true), tostring(pa.dying == true), top2, apexHop, apexWant))
end

-- (0.5.149) LAS PLATAFORMAS REVIENTAN durante el enfriamiento de los platos (tras el destello del bajón) y vuelven al acabar
function cases.revientan()
    local level, es, boss = arena()
    local pa = playerAt(level, 24)
    phase2(level, es, boss, pa)
    platformsOn(level)
    songAt(boss, barOf('A', 2), 0)
    stepAll(level, es, { pa }, 0.1, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T end)
    local on0, n = platCells(level)
    local Entity = require 'src/world/entities/base/Entity'
    local fx, chunks = Entity.fx, 0
    Entity.fx = function(kind, ...) if kind == 'chunk_break' then chunks = chunks + 1 end; if fx then return fx(kind, ...) end end
    boss:bassDrop()
    stepAll(level, es, { pa }, 0.3, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T end)
    local onFlash = platCells(level)
    stepAll(level, es, { pa }, 1.0, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T end)
    local onCool, away = platCells(level), boss:decksAway()
    Entity.fx = fx
    stepAll(level, es, { pa }, boss.DECK_COOL, function() pa.vx, pa.invT = 0, 9; pa.x = 24 * T; if boss.state ~= 'stunned' and boss.state ~= 'regrow' then boss.songT = math.max(boss.songT, 0) end end)
    local onAfter = platCells(level)
    check('revientan', on0 == n and onFlash == n and onCool == 0 and away and chunks == n and onAfter == n and not boss:decksAway(),
        ('plataformas: antes %d/%d · en el destello del bajón %d · enfriándose %d (cascotes %d, platos fuera=%s) · al acabar %d'):format(
            on0, n, onFlash, onCool, chunks, tostring(away), onAfter))
end

-- (0.5.149) EL BAILE DEL DUELO: canta las flechas del chart, cada una con su pose y la boca abierta
function cases.canta()
    local level, es, boss = arena('normal')
    local start = duelBar(boss)
    songAt(boss, start, 0)
    boss.duel = { bar = start, bars = 8, res = {} }
    local lanes, sung = {}, 0
    for i = 0, 8 * 16 * 4 do
        boss.songT = start * boss.BAR + i * boss.S16 / 4
        boss._chart = nil
        local lane = boss:singNow()
        if lane then lanes[lane] = true; sung = sung + 1 end
    end
    local n = 0
    for _ in pairs(lanes) do n = n + 1 end
    boss.duel = nil
    local off = boss:singNow()
    check('canta', n == 4 and sung > 50 and off == nil, ('en el duelo canta: %d de 4 poses (%d muestras cantando) · fuera del duelo: %s'):format(n, sung, tostring(off)))
end
function cases.duelo_solo()
    local level, es, boss = arena('normal')
    boss.props.duelOnly = true
    local pa = playerAt(level, 14)
    songAt(boss, 0, 0)
    stepAll(level, es, { pa }, 0.1)
    local total = boss.INTRO_BARS + boss.LOOP
    check('duelo_solo', boss.duel and boss.duel.bar == 0 and boss.duel.bars == total and boss:duelLive() and pa.frozen,
          'empieza ya, de toda la canción: ' .. tostring(boss.duel and boss.duel.bars))
    songAt(boss, total - 1, 15)
    boss.duel = { bar = 0, bars = total, res = {} }
    stepAll(level, es, { pa }, 0.1)
    check('duelo_solo', boss.duel and boss:duelLive(), 'sigue hasta el final')
    boss:duelReport(pa, 0, 0.1, false)
    local hp = pa.hp
    stepAll(level, es, { pa }, 0.1)
    check('duelo_solo', boss.duel == nil and boss:isDying() and pa.hp == hp, 'al acabar muere, sin castigo: ' .. boss.state)
    stepAll(level, es, { pa }, 8, function() return boss:releasesZone() end)
    check('duelo_solo', boss:releasesZone(), 'y libera la zona')
end
function cases.duelo_red()
    local level, es, boss = arena('normal')
    songAt(boss, duelBar(boss) - 1, 1)
    boss.duel = { bar = duelBar(boss), bars = 16, res = {} }
    local pack = boss:netPackExtra()
    local _, _, other = arena('normal')
    other:netApplyExtra(pack, pack, 1)
    check('duelo_red', other.duel and other.duel.bar == boss.duel.bar and other.duel.bars == 16 and other:duelLive() and other:freezesPlayers(),
          'el cliente sabe del duelo y congela igual')
end
function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'reloj', 'salto', 'notas', 'dorada', 'aturdido', 'trampolin', 'tocar', 'pista', 'dibujos', 'baile', 'temblor', 'platos', 'enfriar', 'ocultos', 'publico', 'trepar', 'enfado',
                         'solo', 'derrota', 'duelo', 'duelo_ko', 'duelo_solo', 'duelo_red', 'ko_para', 'techo', 'revientan', 'canta', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
