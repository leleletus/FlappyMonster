-- tools/tests/giantpuffer_rules — reglas del PEZ GLOBO GIGANTE (types/giantpuffer.lua) caso a caso, en su arena real
-- (tools/levelgen/arenas/jefe_pez.json, con la marea de la pelea corriendo):
--   varado      con la marea baja (empieza así) da coletazos hacia el jugador, cae en su marca (≤ 32 px) y queda
--               BOQUEANDO; solo boqueando se le hace daño (pisotón -1, ground pound -2, y se hincha y aparta: un
--               golpe por ocasión); en cualquier otro momento, caerle encima solo rebota
--   coletazo    deshinchado no hace daño (0.5.31): en el aire a su lado, nada; si CAE encima de alguien, aplasta: -1
--   marea       cuando sube el agua, nada hacia el jugador; tocarlo NO hace nada (deshinchado)
--   hincha      con el jugador cerca, en el agua: avisa (tiembla) y se hincha; hinchado pincha -1
--   aro_hueco   aros de {12,14,16} púas con un hueco de 3 que gira; en el hueco a salvo; 2 aros en la fase 1; pared
--   embestida   aviso 0,8 s con línea (se fija 0,2 s antes), cruza a 700 px/s pinchando sin salir del agua; fase 3: aros
--   remolino    fases 2-3: tira de lado hacia él a quien está en el agua; fuera del agua nada; ni peces ni cajas
--   resaca      mientras el agua BAJA arrastra al jugador quieto hacia la derecha (≈ la velocidad de la resaca);
--               con el agua quieta arriba, no; al empezar a arrastrar suena el aviso y salta el cartel "¡RESACA!"
--               (f.alertAt) si el jugador está cerca, lejos no, y se quita al dejar de bajar
--   fases       6 de vida; fase 2 con 4 (enfadado), fase 3 con 2; un nivel viejo con rageAt 0.5: fase 2 con 3
--   una_ocasion UNA ocasión por marea baja: tras el golpe, bola de púas (no se le daña, pincha) y no boquea hasta el agua
--   bola        la bola rebota dentro de la zona (3 casillas en la fase 1), no se para, pincha, con el agua nada
--   bola_baja   la bola en una plataforma con el jugador debajo baja a por él (la atraviesa)
--   ultima_ocasion golpe justo cuando vuelve el agua: bola → nada; la ocasión no vuelve hasta nadar
--   ola_suelo   al caer de un coletazo, dos olas de púas por el suelo; de pie -1, saltándola nada; se acaban en la
--               pared y en el borde de la superficie; fase 3: otra pareja 0,35 s después
--   derrota     el último golpe: se deshincha y queda APLASTADO también aturdido (no vuelve de golpe a su forma),
--               huye de un salto que atraviesa el suelo (libera la zona) y se va del todo
--   peces       enfadado y nadando suelta peces globo, tantos a la vez como diga la dificultad (Difícil 3, Fácil 1),
--               ninguno antes de enfadarse; con la marea baja se mueren en seco; al vencerlo, se mueren todos
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
local Push = require 'src/world/systems/Push'
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
        level.pushers = Push.collect(es)                -- (lo que empuja: como systems/Sim)
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

-- AROS CON HUECO (2026-11-16): {12, 14, 16} púas con un hueco de 3 que gira de un aro al siguiente (3 púas); quien
-- está en el hueco del primero no recibe; las púas se paran en la pared
function cases.aro_hueco()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 18); boss.y = boss.y - T
    local pa = playerAt(level, 29, 12)
    level.players = { pa }
    boss.levelRef = level
    boss:enter('spines'); boss.burst = 0; boss.spines = {}
    boss:fireBurst(level, 0)
    local n1, g1 = #boss.spines, boss.gapA
    -- el jugador en el hueco del primer aro, a 4 casillas
    pa.x, pa.y = boss.x + math.cos(g1) * 4 * T, boss.y + math.sin(g1) * 4 * T
    pa.invT = 0
    local hp0 = pa.hp
    for _ = 1, 50 do pa.vx, pa.vy = 0, 0; boss:updateSpines(level, DT) end
    local safe = pa.hp == hp0
    boss:fireBurst(level, 1)
    local g2 = boss.gapA
    local step = 2 * math.pi / 12
    local moved = math.abs(((g2 - g1) % (2 * math.pi)) - 3 * step) < 0.01
    -- cuántos aros en la fase 1
    local level2, es2, boss2 = arena()
    tideTo(level2, 'hold', 5.9)
    putBoss(boss2, 18); boss2.y = boss2.y - T
    local pb = playerAt(level2, 29, 12)
    boss2:enter('spines_warn')
    local rings = 0
    stepAll(level2, es2, { pb }, 2.5, function() pb.invT = 9; rings = math.max(rings, boss2.burst or 0) end)
    -- una púa contra la pared de la zona se para
    local zx0 = boss:zoneBounds()
    boss.spines = { { id = 2, x = zx0 + 4, y = boss.y, a = math.pi, t = 0, hit = {} } }
    boss:updateSpines(level, 0.05)
    check('aro_hueco', n1 == 9 and safe and moved and rings == 2 and #boss.spines == 0,
        ('púas en el aro %d (12 - 3); en el hueco a salvo=%s; el hueco gira 3 púas=%s; aros en la fase 1: %d; en la pared se para=%s'):format(
            n1, tostring(safe), tostring(moved), rings, tostring(#boss.spines == 0)))
end

-- EMBESTIDA: aviso 0,8 s con una línea que sigue al jugador hasta 0,2 s antes; luego cruza por ella a {700, 800, 900}
-- px/s con las púas fuera (-1 y empujón), sin salir del agua, hasta la pared; fase 3: después, aros (combo)
function cases.embestida()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 15); boss.y = (FLOOR - 1) * T - 2 * T
    local pa = playerAt(level, 30, 11)
    level.players = { pa }
    boss.levelRef = level
    boss:enter('charge_warn')
    local tgtY = (FLOOR - 1) * T - 2 * T
    local t, warnLen, followed, lockedOk, startX = 0, nil, false, true, nil
    local lockLine
    local maxSp, above, hit, ended = 0, false, false, nil
    local hp0 = pa.hp
    local f = flood(level)
    local lx = boss.x
    stepAll(level, es, { pa }, 4, function()
        t = t + DT
        pa.vx, pa.vy = 0, 0
        pa.x = 30.5 * T
        if boss.state == 'charge_warn' then
            pa.invT = 9
            pa.y = tgtY + ((t < 0.5) and 0 or 60)           -- (se mueve a los 0,5 s y a los 0,65: lo primero se sigue)
            if t >= 0.65 then pa.y = tgtY - 60 end
            if t > 0.55 and t < 0.6 and math.abs(boss.lineY - pa.y) < 4 then followed = true end
            if t > 0.62 and not lockLine then lockLine = boss.lineY end
            if t > 0.7 and lockLine and boss.lineY ~= lockLine then lockedOk = false end
        elseif boss.state == 'charge' then
            if not warnLen then warnLen = t - DT; pa.invT = 0; pa.y = boss.lineY end
            maxSp = math.max(maxSp, math.abs(boss.x - lx) / DT)
            if boss.y - boss.outerH * 0.45 < f.surf - 2 then above = true end
            if pa.hp < hp0 then hit = true end
        elseif warnLen and not ended then ended = boss.state end
        lx = boss.x
        return ended ~= nil
    end)
    -- combo de la fase 3
    local level3, es3, boss3 = arena()
    tideTo(level3, 'hold', 5.9)
    putBoss(boss3, 15); boss3.y = (FLOOR - 1) * T - 2 * T
    local pc = playerAt(level3, 30, 11)
    boss3.levelRef = level3
    boss3.phase = 3
    boss3:enter('charge_warn')
    local after
    stepAll(level3, es3, { pc }, 4, function()
        pc.invT = 9; pc.x, pc.y, pc.vx, pc.vy = 30.5 * T, tgtY, 0, 0
        if boss3.state ~= 'charge_warn' and boss3.state ~= 'charge' then after = boss3.state; return true end
    end)
    check('embestida', warnLen and math.abs(warnLen - 0.8) < 0.05 and followed and lockedOk and maxSp > 650 and maxSp < 760
        and hit and not above and ended == 'deflate' and after == 'spines_warn',
        ('aviso %.2f s; la línea sigue=%s y se fija=%s; velocidad %.0f px/s; pincha=%s; asoma del agua=%s; acaba en %s; fase 3 → %s'):format(
            warnLen or -1, tostring(followed), tostring(lockedOk), maxSp, tostring(hit), tostring(above), tostring(ended), tostring(after)))
end

-- REMOLINO (fases 2 y 3): aviso, y 1,6 s tirando de lado hacia él a quien está EN EL AGUA ({0, 220, 280} px/s); fuera
-- del agua, nada; a los peces y a las cajas, nada; en la fase 1 nunca lo elige
function cases.remolino()
    local level, es, boss = arena()
    tideTo(level, 'hold', 5.9)
    putBoss(boss, 24); boss.y = (FLOOR - 1) * T - 2 * T
    boss.phase, boss.rage = 2, true
    local pa = playerAt(level, 16, 11)
    level.players = { pa }
    boss.levelRef = level
    boss:enter('whirl')
    local x0 = pa.x
    stepAll(level, es, { pa }, 1.5, function() pa.invT = 9; boss.atkT = -99 end)
    local pulled = (pa.x - x0) / T
    -- fuera del agua (en la plataforma del centro, siempre seca): nada
    local level2, es2, boss2 = arena()
    tideTo(level2, 'hold', 5.9)
    putBoss(boss2, 24); boss2.y = (FLOOR - 1) * T - 2 * T
    boss2.phase, boss2.rage = 2, true
    local pb = PlayerAdventure:new(20.5 * T, 5 * T - 60)
    level2.players = { pb }
    for _ = 1, 30 do pb:update(DT, level2) end
    boss2.levelRef = level2
    boss2:enter('whirl')
    local xb = pb.x
    stepAll(level2, es2, { pb }, 1.5, function() pb.invT = 9; boss2.atkT = -99 end)
    local dry = math.abs(pb.x - xb) / T
    -- un pez globo: nada
    local fish = Entities.create({ type = 'pufferfish', col = 18, row = 11, props = {} })
    local fx = boss:pushAt(fish.x, fish.y, fish)
    -- ¿cuándo lo elige?
    local p1, p2 = false, false
    boss.phase = 1
    for _ = 1, 300 do boss.lastAtk = nil; if boss:pickAttack(false) == 'whirl' then p1 = true end end
    boss.phase = 2
    for _ = 1, 300 do boss.lastAtk = nil; if boss:pickAttack(false) == 'whirl' then p2 = true end end
    check('remolino', pulled >= 1.5 and dry < 0.2 and not fx and not p1 and p2,
        ('en el agua tira %.1f casillas hacia él; fuera del agua %.2f; a un pez: %s; lo elige en la fase 1=%s, en la 2=%s'):format(
            pulled, dry, tostring(fx), tostring(p1), tostring(p2)))
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
    -- el aviso (Floods.updateFx, lo de los clientes): suena y sale el cartel solo cerca, y se quita al dejar de bajar
    local played, lx, ly = {}, 18 * T, 11 * T
    local S0 = Sound
    Sound = setmetatable({ play = function(n) played[n] = (played[n] or 0) + 1 end,
                           getListener = function() return lx, ly end }, getmetatable(S0))
    local function fx() f.alertAt = nil; f.prevLevel = f.level; Floods.updateFx(level, DT); return f.alertAt ~= nil end
    local near = fx()
    local n1 = played.undertowAlert or 0
    lx = 200 * T
    local far = fx()
    tideTo(level, 'hold', 1)
    lx = 18 * T
    local held = fx()
    Sound = S0
    check('resaca', near and n1 == 1 and not far and not held and played.undertowAlert == 1,
        ('aviso: cerca %s (sonó %d), lejos %s, agua quieta %s'):format(tostring(near), n1, tostring(far), tostring(held)))
end

-- Fases por la vida (2026-11-16): fase 2 a ≤ 4 de 6 (rageAt 0.67), fase 3 a ≤ 2 (phase3At 0.34); un nivel viejo
-- con su `rageAt` (0.5) entra en la fase 2 con 3
function cases.fases()
    local level, es, boss = arena()
    local pa = playerAt(level, 28)
    level.players = { pa }
    boss.levelRef = level
    local function hitTo(b, hp) while b.hp > hp do b:enter('gasp'); b.inv = 0; b.opened = false; b:stomp() end end
    local hp0, p1 = boss.hpMax, boss:ph()
    hitTo(boss, 5); local p5 = boss:ph()
    hitTo(boss, 4); local p4, r4 = boss:ph(), boss.rage
    hitTo(boss, 3); local p3 = boss:ph()
    hitTo(boss, 2); local p2 = boss:ph()
    local props = {}
    for k, v in pairs(boss.props) do props[k] = v end
    props.rageAt, props.phase3At = 0.5, nil
    local old = Entities.create({ type = 'giantpuffer', col = 23, row = 12, props = props })
    old.levelRef = level
    old:startFight(1)
    hitTo(old, 4); local o4 = old:ph()
    hitTo(old, 3); local o3 = old:ph()
    check('fases', hp0 == 6 and p1 == 1 and p5 == 1 and p4 == 2 and r4 and p3 == 2 and p2 == 3 and o4 == 1 and o3 == 2,
        ('vida %d; fase con 6/5/4/3/2: %d/%d/%d/%d/%d (enfadado con 4=%s); nivel viejo rageAt 0.5: con 4 → %d, con 3 → %d'):format(
            hp0, p1, p5, p4, p3, p2, tostring(r4), o4, o3))
end

-- UNA ocasión por marea baja (2026-11-16, el usuario: "con ground pounds seguidos se le baja en 2 mareas"): tras el
-- golpe se hace BOLA DE PÚAS (no se le puede dañar; tocarla pincha) y no vuelve a boquear hasta que vuelva el agua.
-- Con dos jugadores, la ocasión es del jefe, no de cada uno.
function cases.una_ocasion()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa, pb = playerAt(level, 14), playerAt(level, 30)
    level.players = { pa, pb }
    boss.levelRef = level
    boss:enter('gasp'); boss.inv = 0
    local hp0 = boss.hp
    boss:stomp()
    local hp1 = boss.hp
    local ballAt, t = nil, 0
    stepAll(level, es, { pa, pb }, 1.5, function()
        t = t + DT
        pa.invT, pb.invT = 9, 9
        pa.x, pb.x = 13.5 * T, 31.5 * T
        if boss.state == 'ball' then ballAt = t; return true end
    end)
    local vuln = boss:isVulnerable()
    -- el segundo jugador le cae encima: rebota, el jefe no pierde vida y a él le pincha
    local gob = boss:getOuterBounds()
    local p2 = dropOn(level, boss.x, gob.y, true)
    pb.x, pb.y, pb.vy, pb.gpPhase, pb.invT = p2.x, p2.y, p2.vy, 'fall', 0
    level.players = { pa, pb }
    local r = boss:interact(pb)
    local hpB0 = pb.hp
    boss:update(DT, level)
    local hurtB = pb.hp == hpB0 - 1
    -- hasta que vuelve el agua, nunca boquea otra vez
    pb.y = 5 * T
    local regasp = false
    stepAll(level, es, { pa, pb }, 12, function()
        pa.invT, pb.invT = 9, 9
        pa.x, pb.x = 13.5 * T, 31.5 * T
        if boss.state == 'gasp' then regasp = true end
        return flood(level).level > 0.5
    end)
    check('una_ocasion', hp1 == hp0 - 1 and ballAt and ballAt <= 0.9 and not vuln and r == 'bounce' and boss.hp == hp1
        and hurtB and not regasp,
        ('golpe %d→%d; bola a los %.2f s; vulnerable siendo bola=%s; el 2º encima: %s, vida jefe %d, le pincha=%s; vuelve a boquear antes del agua=%s'):format(
            hp0, hp1, ballAt or -1, tostring(vuln), tostring(r), boss.hp, tostring(hurtB), tostring(regasp)))
end

-- La BOLA DE PÚAS rebota por la cala sin salirse ni pararse (altura de la fase 1: 3 casillas), pincha al tocarla y,
-- cuando el agua la alcanza, se deshincha y nada
function cases.bola()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 14)
    level.players = { pa }
    boss.levelRef = level
    boss.opened = true
    boss:enter('ball')
    local zx0, zx1, zy0, zy1 = boss:zoneBounds()
    local floorY = (FLOOR - 1) * T
    local inside, maxH, stillT, maxStill = true, 0, 0, 0
    local lx, ly = boss.x, boss.y
    local wetAt, swimAt, t = nil, nil, 0
    local touched = false
    stepAll(level, es, { pa }, 25, function()
        t = t + DT
        pa.invT = 9; pa.x = 13.5 * T
        if boss.state == 'ball' then
            if boss.x < zx0 or boss.x > zx1 or boss.y < zy0 or boss.y > zy1 then inside = false end
            maxH = math.max(maxH, floorY - boss:feetY())
            if math.abs(boss.x - lx) + math.abs(boss.y - ly) < 0.5 then stillT = stillT + DT else stillT = 0 end
            maxStill = math.max(maxStill, stillT)
            lx, ly = boss.x, boss.y
            if not touched and t > 2 then
                -- tocarla: -1
                touched = true
                pa.x, pa.y, pa.invT = boss.x + 20, boss.y, 0
                local h0 = pa.hp
                boss:update(DT, level)
                touched = (pa.hp == h0 - 1) and 'hit' or 'nohit'
                pa.invT = 9
            end
        end
        if not wetAt and boss:wet(level) then wetAt = t end
        if boss.state == 'swim' then swimAt = t; return true end
    end)
    local late = (wetAt and swimAt) and (swimAt - wetAt) or 99
    check('bola', inside and maxH >= 2.5 * T and maxH <= 3.5 * T and maxStill < 0.5 and touched == 'hit' and late <= 2,
        ('dentro de la zona=%s; altura %.1f casillas; parada como mucho %.2f s; tocarla=%s; del agua a nadar %.2f s'):format(
            tostring(inside), maxH / T, maxStill, tostring(touched), late))
end

-- La última ocasión: le pegas boqueando justo cuando ya vuelve el agua → bola → nada; la ocasión se gasta y no se
-- recupera hasta que nada (y nunca vuelve a boquear esa marea)
-- La bola sobre una plataforma con el jugador DEBAJO baja a por él (atraviesa la plataforma; si no, se quedaba
-- botando encima toda la marea: boss_frames 2026-11-16)
function cases.bola_baja()
    local level, es, boss = arena()
    local pa = playerAt(level, 14)
    level.players = { pa }
    boss.levelRef = level
    boss.x, boss.y = 13 * T, 8 * T - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
    boss.opened = true
    boss:enter('ball')
    local floorY, low, t, downAt = (FLOOR - 1) * T, false, 0, nil
    stepAll(level, es, { pa }, 4, function()
        t = t + DT
        pa.invT = 9; pa.x, pa.vx = 13.5 * T, 0
        if boss:feetY() >= floorY - 4 then downAt = t; return true end
    end)
    check('bola_baja', downAt ~= nil, ('en la plataforma con el jugador debajo: llega al suelo a los %.2f s'):format(downAt or -1))
end

function cases.ultima_ocasion()
    local level, es, boss = arena()
    tideTo(level, 'rise', 0)
    putBoss(boss, 22)
    local pa = playerAt(level, 14)
    level.players = { pa }
    boss.levelRef = level
    boss:enter('gasp'); boss.inv = 0; boss.opened = false
    boss:stomp()
    local seen, openedBeforeSwim, regasp = {}, true, false
    stepAll(level, es, { pa }, 10, function()
        pa.invT = 9; pa.x = 13.5 * T
        if boss.state ~= 'hurt_puff' and boss.state ~= 'swim' and not boss.opened then openedBeforeSwim = false end
        seen[boss.state] = true
        if boss.state == 'gasp' then regasp = true end
        return boss.state == 'swim'
    end)
    check('ultima_ocasion', seen.ball and boss.state == 'swim' and openedBeforeSwim and boss.opened == false and not regasp,
        ('bola=%s; final %s; gastada hasta nadar=%s; al nadar se recupera=%s; reboquea=%s'):format(
            tostring(seen.ball), boss.state, tostring(openedBeforeSwim), tostring(boss.opened == false), tostring(regasp)))
end

-- OLA DE PÚAS por el suelo al caer de cada coletazo: dos (izquierda y derecha) a {500, 560, 620} px/s; quita 1 a quien
-- está de pie en su camino, no a quien la salta; se para en la pared y donde se acaba la superficie; fase 3: otra pareja
-- 0,35 s después
local function landFlop(level, boss)
    boss:enter('flop')
    boss.deadTimer = 0.2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
    boss:update(DT, level)
end

function cases.ola_suelo()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 27)
    level.players = { pa }
    boss.levelRef = level
    pa.invT = 9
    landFlop(level, boss)
    local n, dirs = #(boss.waves or {}), {}
    for _, w in ipairs(boss.waves or {}) do dirs[w.dir] = true end
    local x0 = {}
    for _, w in ipairs(boss.waves or {}) do x0[w.id] = w.x end
    -- velocidad
    for _ = 1, 15 do boss:updateWaves(level, DT) end
    local spd = 0
    for _, w in ipairs(boss.waves or {}) do spd = math.max(spd, math.abs(w.x - x0[w.id]) / (15 * DT)) end
    -- de pie en su camino: -1
    local hp0 = pa.hp
    pa.invT = 0
    for _ = 1, 60 do
        pa.vx, pa.vy = 0, 0
        boss:updateWaves(level, DT)
        if pa.hp < hp0 then break end
    end
    local hitStand = pa.hp == hp0 - 1
    -- saltándola (pies 0,8 casillas por encima): nada
    local level2, es2, boss2 = arena()
    putBoss(boss2, 22)
    local pb = playerAt(level2, 27)
    level2.players = { pb }
    boss2.levelRef = level2
    pb.invT = 9
    landFlop(level2, boss2)
    pb.invT = 0
    local hpB = pb.hp
    local ob = pb:getOuterBounds()
    for _ = 1, 60 do
        pb.y = (FLOOR - 1) * T - 0.8 * T - ob.h / 2
        boss2:updateWaves(level2, DT)
    end
    local jumped = pb.hp == hpB
    -- en la pared de la zona se acaba
    for _ = 1, 240 do boss2:updateWaves(level2, DT) end
    local wallGone = #boss2.waves == 0
    -- donde se acaba la superficie (la plataforma de la izquierda: x 11-15 casillas, fila 9)
    boss2.waves = { { id = 50, x = 12 * T, y = 8 * T, dir = 1, t = 0, hit = {} } }
    local lastX = 0
    for _ = 1, 60 do
        if boss2.waves[1] then lastX = boss2.waves[1].x end
        boss2:updateWaves(level2, DT)
    end
    local edgeGone = #boss2.waves == 0 and lastX <= 15.5 * T
    -- fase 3: cuatro, la segunda pareja 0,35 s después
    local level3, es3, boss3 = arena()
    putBoss(boss3, 22)
    level3.players = {}
    boss3.levelRef = level3
    boss3.phase = 3
    landFlop(level3, boss3)
    local first = #(boss3.waves or {})
    local secondAt, t = nil, 0
    for _ = 1, 40 do
        t = t + DT
        boss3:update(DT, level3)
        if not secondAt and (boss3.waveN or 0) >= 4 then secondAt = t end
    end
    check('ola_suelo', n == 2 and dirs[1] and dirs[-1] and math.abs(spd - 500) < 25 and hitStand and jumped and wallGone
        and edgeGone and first == 2 and secondAt and math.abs(secondAt - 0.35) < 0.05,
        ('olas %d (izq=%s der=%s) a %.0f px/s; de pie: -1=%s; saltándola sin daño=%s; en la pared se acaba=%s; en el borde de la plataforma=%s (x %.1f); fase 3: %d y la segunda pareja a %.2f s'):format(
            n, tostring(dirs[-1]), tostring(dirs[1]), spd, tostring(hitStand), tostring(jumped), tostring(wallGone),
            tostring(edgeGone), lastX / T, first, secondAt or -1))
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
    local floorY = boss:feetY()
    local dazeSy, below, maxUp = 0, false, 0
    stepAll(level, es, {}, 24, function()
        seen[boss.state] = true
        if boss:releasesZone() then released = true end
        if boss.state == 'dying_daze' then dazeSy = math.max(dazeSy, select(5, boss:pose())) end
        if boss.state == 'dying_flee' then
            maxUp = math.max(maxUp, floorY - boss:feetY())
            if boss.y - boss.outerH / 2 > floorY + T then below = true end
        end
        return boss.state == 'dead'
    end)
    check('derrota', seen.dying_deflate and seen.dying_daze and dazeSy <= 0.62 and seen.dying_flee and maxUp > 3 * T
        and below and released and boss.state == 'dead',
        ('deshincha=%s, aturdido aplastado (alto %.2f), salta %.1f casillas y atraviesa el suelo=%s, libera la zona=%s, final=%s'):format(
            tostring(seen.dying_deflate), dazeSy, maxUp / T, tostring(below), tostring(released), boss.state))
end

function cases.red()
    local level, es, boss = arena()
    putBoss(boss, 20)
    boss.phase, boss.rage, boss.markX, boss.markY, boss.burst = 2, true, 999, 777, 2
    boss.lineX, boss.lineY, boss.opened, boss.gapA = 1234, 567, true, 2.345
    boss.spines = { { id = 5, x = 100, y = 200, a = 1.25, t = 0.4, hit = {} }, { id = 6, x = 300, y = 210, a = -2, t = 0.1, hit = {} } }
    boss.waves = { { id = 7, x = 800, y = 768, dir = -1, t = 0.2, hit = {} }, { id = 8, x = 1100, y = 768, dir = 1, t = 0.2, hit = {} },
                   { id = 9, x = 1300, y = 512, dir = 1, t = 0.1, hit = {} } }
    local b = boss:netPackExtra()
    local c = Entities.create({ type = 'giantpuffer', col = 20, row = 12, props = {} })
    c:netApplyExtra(b, b, 1)
    local ok = c.rage and c:ph() == 2 and c.markX == 999 and c.markY == 777 and c.burst == 2 and #c.spines == 2
        and c.lineX == 1234 and c.lineY == 567 and c.opened == true and math.abs((c.gapA or 0) - 2.345) < 0.002
        and #(c.waves or {}) == 3
    for i, s in ipairs(boss.spines) do
        local q = c.spines[i]
        if not q or math.abs(q.x - s.x) > 1 or math.abs(q.y - s.y) > 1 or math.abs(q.a - s.a) > 0.002 then ok = false end
    end
    for i, w in ipairs(boss.waves) do
        local q = (c.waves or {})[i]
        if not q or math.abs(q.x - w.x) > 1 or q.y ~= w.y or q.dir ~= w.dir then ok = false end
    end
    -- el remolino tira igual en el cliente (estado y x llegan en la instantánea)
    boss:enter('whirl'); c.state, c.x = 'whirl', boss.x
    local probe = { inWater = true }
    local ps, pc = boss:pushAt(boss.x - 5 * T, boss.y, probe), c:pushAt(boss.x - 5 * T, boss.y, probe)
    ok = ok and ps ~= nil and ps == pc
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

function cases.peces()
    local function count(level, boss)
        local n = 0
        for _, e in ipairs(boss:minions(level)) do if e.alive then n = n + 1 end end
        return n
    end
    local out = {}
    for _, diff in ipairs({ 'hard', 'easy' }) do
        local level, es, boss = arena()
        level.difficulty = diff
        local pa = playerAt(level, 14, 4)
        tideTo(level, 'hold', 5.9)
        putBoss(boss, 24); boss.y = boss.y - 2 * T
        boss:enter('swim'); boss.atkT = -999
        local before, maxN, outZone = 0, 0, false
        local zx0, zx1 = boss:zoneBounds()
        stepAll(level, es, { pa }, 4, function() pa.invT = 9; boss.atkT = -999; before = math.max(before, count(level, boss)) end)
        boss.rage = true
        stepAll(level, es, { pa }, 14, function()
            pa.invT = 9; boss.atkT = -999
            if boss.state ~= 'swim' and boss:wet(level) then boss:enter('swim') end
            maxN = math.max(maxN, count(level, boss))
            for _, e in ipairs(boss:minions(level)) do if e.alive and (e.x < zx0 or e.x > zx1) then outZone = true end end
            return flood(level).phase == 'low'
        end)
        stepAll(level, es, { pa }, 4, function() pa.invT = 9 end)
        local afterLow = count(level, boss)
        out[diff] = { before = before, max = maxN, low = afterLow, out = outZone }
        if diff == 'hard' then
            -- al vencerlo se mueren
            tideTo(level, 'hold', 5.9)
            boss.y = (FLOOR - 3) * T
            boss.spawnT = 99; boss:spawnPuffers(level, 0)
            boss.spawnT = 99; boss:spawnPuffers(level, 0)
            local n0 = count(level, boss)
            boss.levelRef = level
            boss:defeat()
            stepAll(level, es, { pa }, 1.5, function() pa.invT = 9 end)
            out.defeat = { n0, count(level, boss) }
        end
    end
    local h, e = out.hard, out.easy
    check('peces', h.before == 0 and h.max == 3 and e.max == 1 and h.low == 0 and e.low == 0 and not h.out
        and out.defeat[1] >= 1 and out.defeat[2] == 0,
        ('antes de enfadarse %d; a la vez: Difícil %d, Fácil %d; dentro de la zona=%s; tras la marea baja quedan %d/%d; '
         .. 'al vencerlo %d → %d'):format(h.before, h.max, e.max, tostring(not h.out), h.low, e.low, out.defeat[1], out.defeat[2]))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'varado', 'coletazo', 'marea', 'hincha', 'aro_hueco', 'embestida', 'remolino', 'resaca', 'fases', 'una_ocasion', 'bola', 'bola_baja', 'ultima_ocasion', 'ola_suelo', 'derrota', 'red', 'pez_chico', 'peces' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
