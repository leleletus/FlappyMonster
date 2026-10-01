-- tools/tests/snowboss_rules — reglas de la Gran Bola de Nieve contra los jugadores y el
-- escenario, caso a caso (salas hechas a mano + la arena real de lago_helado):
--   bola          una bola de nieve que le da: -1 de vida y empujón fuerte en su dirección;
--                 la bola desaparece. Invulnerable: ni daño ni empujón
--   carambano     un carámbano cayendo sobre un jugador: -2 (y vuelve a crecer luego)
--   carambano_jefe  un carámbano cayendo sobre la bola: MAREADA (sin daño)
--   carambano_sacude un aterrizaje sacude solo los carámbanos a < 2.5 casillas: tiemblan y caen
--   ola           la ola de nieve del gran golpe: -1 y empujón hacia donde va la ola
--   onda_golpe    al aterrizar el gran golpe: cerca y a ras de suelo -1 y empujón MUY
--                 fuerte hacia fuera (y aturdido); lejos o en lo alto, nada
--   rueda_pared   rodando contra la pared: fase 1 mareada al primer choque, fase 2 tras 1
--                 rebote, fase 3 tras 2
--   rueda_escalon rodando contra un escalón de 1 casilla: se estampa (no lo sube)
--   rueda_activa  rodando contra un Activador ON/OFF lo cambia
--   rueda_rompe   rodando contra bloques rompibles / nieve prensada / hielo: NO los rompe
--   rueda_nieve   rodando choca con la nieve prensada (no la atraviesa ni la rompe)
--   rueda_fin     arena real, fase 3 (2 rebotes): el ataque rodando SIEMPRE acaba
--   salto_plataforma  fase 2, jugador en una plataforma media: la bola cae en ESA plataforma
--   salto_debajo  saltando desde justo debajo de una plataforma: la atraviesa y se posa encima
--   empapada      el hielo de una bolsa se rompe bajo ella: cae al agua, EMPAPADA (vulnerable),
--                 sale de un salto a lo seco y el hielo se rehace solo
--   fase3_aparece arena real: Activadores del suelo y Congeladores no están hasta la fase 3;
--                 en la fase 3 sale el Activador (en vez de hielo) y el Congelador baja
--   congelada     fase 3, empapada en la bolsa + su Activador → su Congelador la CONGELA;
--                 ground pound = 3
--   seca_aturdida un Congelador sobre la bola seca: solo aturdida un momento y escarchada
--   encoge        cambio de fase: escala 10 → 8 → 6; en la fase 2 crecen los carámbanos
--
--   tools/tests/run.sh snowboss_rules
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local TileCodec = require 'src/world/tiles/TileCodec'
local PhaseBlocks = require 'src/world/PhaseBlocks'
local T = TILE_PX

local fails = 0
local function check(case, ok, msg)
    print(('%-13s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H (suelo y paredes de piedra); `put` = { {col,row,tileName}, ... }
local function room(W, H, put, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(put or {}) do tiles[p[2]][p[1]] = TileCodec.encode(_G['TILE_' .. p[3]:upper()]) end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    level.players = {}
    local boss
    for _, e in ipairs(es) do if e.def.name == 'snowboss' then boss = e end end
    return level, es, boss
end

local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, row * T - 60)
    for k in pairs(stub.state) do stub.state[k] = false end
    for _ = 1, 30 do pa:update(1 / 60, level) end
    level.players = { pa }
    return pa
end

-- Recorrido horizontal del jugador en `secs` s tras el golpe (sin pulsar nada)
local function travel(level, pa, secs)
    local x0 = pa.x
    for _ = 1, math.floor(secs * 60) do pa:update(1 / 60, level) end
    return pa.x - x0
end

local function fight(boss)
    boss.state, boss.deadTimer, boss.phase = 'idle', 0, 1
    boss.lake = {}
end

local cases = {}

function cases.bola()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    local hp0 = pa.hp
    boss.proj = { { id = 1, x = pa.x - 10, y = pa.y, vx = 500, vy = 0, t = 0 } }
    boss:hitWithShots(level)
    local vx, dx = pa.vx, travel(level, pa, 0.6)
    local okHit = pa.hp == hp0 - 1 and vx >= 500 and dx > 3 * T and #boss.proj == 0
    -- invulnerable: nada
    local pb = playerAt(level, 14, 9)
    pb:grantInvulnerability(2)
    boss.proj = { { id = 2, x = pb.x - 10, y = pb.y, vx = 500, vy = 0, t = 0 } }
    boss:hitWithShots(level)
    check('bola', okHit and pb.hp == pb.hpMax and math.abs(pb.vx) < 50 and #boss.proj == 1,
        ('vida %d→%d, vx %d, recorre %.1f casillas; invulnerable: vida %d vx %d'):format(
            hp0, pa.hp, vx, dx / T, pb.hp, pb.vx))
end

function cases.ola()
    local level, es, boss = room(30, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    boss.shockX, boss.shockY = math.floor(pa.x - 0.3 * 560), 9 * T
    boss.shockT = 0.3
    boss:hitWithShots(level)
    local vx, dx = pa.vx, travel(level, pa, 0.8)
    check('ola', pa.hp == pa.hpMax - 1 and vx >= 900 and dx > 5 * T,
        ('vida %d, vx %d, recorre %.1f casillas'):format(pa.hp, vx, dx / T))
end

function cases.onda_golpe()
    local level, es, boss = room(40, 12, { { 30, 8, 'solid' }, { 31, 8, 'solid' }, { 32, 8, 'solid' } },
                                 { { type = 'snowboss', col = 15, row = 11 } })
    fight(boss)
    local near = PlayerAdventure:new((17.5) * T, 11 * T - 60)     -- 3 casillas a la derecha, en el suelo
    local far  = PlayerAdventure:new((5.5) * T, 11 * T - 60)      -- a 10 casillas
    local high = PlayerAdventure:new((31.5) * T, 7 * T - 60)      -- encima de un bloque alto (lejos)
    level.players = { near, far, high }
    for _ = 1, 30 do for _, p in ipairs(level.players) do p:update(1 / 60, level) end end
    boss:slamWave(level)
    local vx, stun = near.vx, near.stunT
    local dx = travel(level, near, 1.0)
    check('onda_golpe', near.hp == near.hpMax - 1 and vx >= 1300 and dx > 8 * T and stun > 0
                        and far.hp == far.hpMax and far.vx == 0 and high.hp == high.hpMax,
        ('cerca: vida %d vx %d recorre %.1f casillas; lejos: vida %d; en alto: vida %d'):format(
            near.hp, vx, dx / T, far.hp, high.hp))
end

-- Hace rodar al jefe hacia `dir` hasta que choque (o 3 s)
local function rollInto(level, boss, dir, bounces)
    boss.state, boss.deadTimer = 'roll', 0
    boss.dir, boss.vx, boss.bounces, boss.phase = dir, dir * 500, bounces or 0, boss.phase or 1
    boss.rollLeft, boss.crashes = 3.2, 0
    for _ = 1, 180 do
        boss:update(1 / 60, level)
        if boss.state ~= 'roll' then break end
    end
end

function cases.rueda_activa()
    local level, es, boss = room(20, 10, { { 1, 9, 'switch_off' }, { 1, 8, 'switch_off' } },
                                 { { type = 'snowboss', col = 8, row = 9 } })
    fight(boss)
    level.players = {}
    rollInto(level, boss, -1)
    local a, b = level:getDef(1, 9).name, level:getDef(1, 8).name
    check('rueda_activa', a == 'switch_on' or b == 'switch_on',
        ('activadores tras el choque: (1,9)=%s (1,8)=%s; jefe en %s'):format(a, b, boss.state))
end

function cases.rueda_rompe()
    local level, es, boss = room(20, 10, { { 19, 9, 'breakable' }, { 19, 8, 'breakable' }, { 19, 7, 'thin_ice' },
                                           { 17, 9, 'packed_snow' } },
                                 { { type = 'snowboss', col = 8, row = 9 } })
    fight(boss)
    level.players = {}
    rollInto(level, boss, 1)
    local n = {}
    for _, cr in ipairs({ { 19, 9 }, { 19, 8 }, { 19, 7 }, { 17, 9 } }) do n[#n + 1] = level:getDef(cr[1], cr[2]).name end
    check('rueda_rompe', n[1] == 'breakable' and n[2] == 'breakable' and n[3] == 'thin_ice' and n[4] == 'packed_snow',
        ('tras chocar: %s'):format(table.concat(n, ', ')))
end

local function lago()
    local data = json.decode(love.filesystem.read('assets/levels/lago_helado.json'))
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'snowboss' then boss = e end end
    level.players = {}
    return level, es, boss
end

-- Pasos de la simulación con todas las entidades (congeladores...) y el nivel
local function step(level, es, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.solidBodies = Entities.solidBodies(es)
        if level.update then level:update(1 / 60) end
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
        if each and each() then return true end
    end
end

local function putBoss(boss, col)
    boss.x = (col - 0.5) * T
    boss.y = 12 * T - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
end

function cases.rueda_nieve()
    local level, es, boss = room(24, 10, { { 15, 8, 'packed_snow' }, { 15, 9, 'packed_snow' } },
                                 { { type = 'snowboss', col = 7, row = 9 } })
    fight(boss)
    rollInto(level, boss, 1)
    check('rueda_nieve', boss.x < 14 * T and level:getDef(15, 9).name == 'packed_snow',
        ('choca con la nieve prensada: x = %.1f casillas (nieve en la 15), nieve intacta=%s'):format(
            boss.x / T, tostring(level:getDef(15, 9).name == 'packed_snow')))
end

local IC = nil
local function icicleAt(boss, x, top, st)
    IC = IC or boss.IC
    boss.icicles = { { x = x, top = top, y = top, vy = 0, st = st or IC.ready, t = 0 } }
    return boss.icicles[1]
end

function cases.carambano()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 4, row = 9 } })
    fight(boss)
    local pa = playerAt(level, 14, 9)
    local c = icicleAt(boss, math.floor(pa.x), 2 * T, boss.IC.fall)
    local hit
    for _ = 1, 120 do boss:updateIcicles(level, 1 / 60); if c.st ~= boss.IC.fall then hit = true; break end end
    local hp = pa.hp
    for _ = 1, math.floor(6.5 * 60) do boss:updateIcicles(level, 1 / 60) end
    check('carambano', hit and hp == pa.hpMax - 2 and (c.st == boss.IC.grow or c.st == boss.IC.ready),
        ('vida %d/%d; después de 6.5 s el carámbano vuelve a crecer (estado %d)'):format(hp, pa.hpMax, c.st))
end

function cases.carambano_jefe()
    local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 10, row = 9 } })
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    local hp0 = boss.hp
    local c = icicleAt(boss, math.floor(boss.x), 1 * T, boss.IC.fall)
    for _ = 1, 120 do boss:updateIcicles(level, 1 / 60); if c.st ~= boss.IC.fall then break end end
    check('carambano_jefe', boss.state == 'dizzy' and boss.hp == hp0 and boss:isVulnerable(),
        ('al caerle: %s, vida %d→%d, vulnerable=%s'):format(boss.state, hp0, boss.hp, tostring(boss:isVulnerable())))
end

function cases.carambano_sacude()
    local level, es, boss = room(30, 10, nil, { { type = 'snowboss', col = 10, row = 9 } })
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    boss.icicles = {
        { x = boss.x + 1.5 * T, top = T, y = T, vy = 0, st = boss.IC.ready, t = 0 },   -- cerca
        { x = boss.x + 5 * T, top = T, y = T, vy = 0, st = boss.IC.ready, t = 0 },     -- lejos
    }
    boss:landed(level, 1)
    local s1, s2 = boss.icicles[1].st, boss.icicles[2].st
    local fell = false
    for _ = 1, 90 do boss:updateIcicles(level, 1 / 60); if boss.icicles[1].st == boss.IC.fall then fell = true end end
    check('carambano_sacude', s1 == boss.IC.shake and s2 == boss.IC.ready and fell,
        ('cerca: %d (3 = tiembla), lejos: %d (2 = quieto), cae después=%s'):format(s1, s2, tostring(fell)))
end

function cases.rueda_pared()
    local out, ok = {}, true
    for ph = 1, 3 do
        local level, es, boss = room(24, 10, nil, { { type = 'snowboss', col = 12, row = 9 } })
        fight(boss)
        boss.phase = ph; boss:setScale(boss.SC[ph])
        boss.state, boss.deadTimer = 'windup', 0
        boss.bounces = ({ 0, 1, 2 })[ph]
        boss.dir = -1
        local level0 = level
        for _ = 1, 60 * 10 do
            boss:update(1 / 60, level0)
            if boss.state ~= 'windup' and boss.state ~= 'roll' and boss.state ~= 'slide' then break end
        end
        out[#out + 1] = ('fase %d: %s tras %d choques'):format(ph, boss.state, boss.crashes or 0)
        if boss.state ~= 'dizzy' or (boss.crashes or 0) ~= ph then ok = false end
    end
    check('rueda_pared', ok, table.concat(out, ' · '))
end

function cases.rueda_escalon()
    local level, es, boss = room(24, 10, { { 4, 9, 'snow' } }, { { type = 'snowboss', col = 14, row = 9 } })
    fight(boss)
    rollInto(level, boss, -1)
    check('rueda_escalon', boss.state == 'dizzy' and boss.x > 4 * T,
        ('contra el escalón (columna 4): %s, x = %.1f casillas'):format(boss.state, boss.x / T))
end

function cases.rueda_fin()
    local level, es, boss = lago()
    fight(boss)
    boss.phase = 3
    boss:setScale(6)
    putBoss(boss, 86)
    boss.bounces = 2
    boss:enter('windup')
    local t = 0
    local ended = step(level, es, 20, function()
        t = t + 1 / 60
        return boss.state ~= 'windup' and boss.state ~= 'roll' and boss.state ~= 'slide'
    end)
    check('rueda_fin', ended == true and t < 8,
        ('acaba a los %.1f s en %s (choques %d)'):format(t, boss.state, boss.crashes or 0))
end

-- Arena real: zona 75-98, bolsas 79-81 / 92-94, plataformas medias (fila 8) 82-85 / 88-91,
-- de arriba (fila 6) 85-88, laterales (fila 10) 75-78 / 95-98; Activadores 83 y 90 (fila 13),
-- Congeladores (80,3) y (93,3)
local function leapUntilLanded(level, es, boss)
    local t = 0
    step(level, es, 6, function()
        t = t + 1 / 60
        return boss.state == 'leap_land' or boss.state == 'land'
    end)
    return t
end

function cases.salto_plataforma()
    local level, es, boss = lago()
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    putBoss(boss, 95)
    local pa = PlayerAdventure:new(83 * T, 7 * T - 60)           -- en la plataforma media izquierda
    level.players = { pa }
    for _ = 1, 30 do pa:update(1 / 60, level) end
    local ok0 = boss:startLeap(level, pa)
    local t = leapUntilLanded(level, es, boss)
    local onPlat = math.abs(boss:feetY() - 7 * T) < 2 and boss.x > 81 * T and boss.x < 85 * T + 1
    check('salto_plataforma', ok0 and onPlat and boss.state == 'leap_land',
        ('marca (%.1f, fila %.2f) · cae en x=%.1f casillas, pies a la fila %.2f en %.1f s (%s)'):format(
            boss.landX / T, boss.landY / T, boss.x / T, boss:feetY() / T, t, boss.state))
end

function cases.salto_debajo()
    local level, es, boss = lago()
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    putBoss(boss, 87)                                             -- debajo de la plataforma de arriba
    local pa = PlayerAdventure:new(86.5 * T, 5 * T - 60)          -- encima de ella
    level.players = { pa }
    for _ = 1, 30 do pa:update(1 / 60, level) end
    boss:startLeap(level, pa)
    leapUntilLanded(level, es, boss)
    check('salto_debajo', math.abs(boss:feetY() - 5 * T) < 2,
        ('desde debajo: pies a la fila %.2f (plataforma de arriba: 5)'):format(boss:feetY() / T))
end

function cases.empapada()
    local level, es, boss = lago()
    fight(boss)
    boss:findLake(level)
    putBoss(boss, 80)                                             -- encima de la bolsa izquierda
    for c = 79, 81 do level:crackIce(c, 13, 4, 'pound') end
    local soaked = step(level, es, 1.5, function() return boss.state == 'soaked' end)
    local vuln = boss:isVulnerable()
    local t, out = 0, false
    step(level, es, 10, function()
        t = t + 1 / 60
        if not boss:inWater(level) and boss.onGround and (boss.state == 'leap_land' or boss.state == 'land' or boss.state == 'idle') then
            out = true; return true
        end
    end)
    step(level, es, 4.5)
    local lake = level:getDef(79, 13).name .. ',' .. level:getDef(80, 13).name .. ',' .. level:getDef(81, 13).name
    local healed = level:getDef(79, 13).thinIce and level:getDef(80, 13).thinIce and level:getDef(81, 13).thinIce
    check('empapada', soaked == true and vuln and out and healed,
        ('cae al agua: empapada=%s vulnerable=%s · sale en %.1f s=%s (x=%.1f) · lago: %s'):format(
            tostring(soaked), tostring(vuln), t, tostring(out), boss.x / T, lake))
end

local function cryoAt(es, col)
    for _, e in ipairs(es) do if e.def.name == 'cryo' and e.col == col then return e end end
end

function cases.fase3_aparece()
    local level, es, boss = lago()
    fight(boss)
    local z = boss.zone
    local before = level:getDef(83, 13).name
    local cz = cryoAt(es, 80)
    step(level, es, 0.2)
    local solid0 = cz:isSolidBody()
    z.phase = 2; PhaseBlocks.update(level)
    local mid = level:getDef(83, 13).name
    z.phase = 3; PhaseBlocks.update(level)
    local after, after2 = level:getDef(83, 13).name, level:getDef(90, 13).name
    step(level, es, 1.3)
    local solid1 = cz:isSolidBody()
    check('fase3_aparece', before == 'ice' and mid == 'ice' and after == 'switch_off' and after2 == 'switch_off'
                           and not solid0 and solid1,
        ('Activador: fase 1 %s, fase 2 %s, fase 3 %s/%s · Congelador sólido: antes %s, tras bajar %s'):format(
            before, mid, after, after2, tostring(solid0), tostring(solid1)))
end

function cases.congelada()
    local level, es, boss = lago()
    fight(boss)
    boss:findLake(level)
    boss.phase = 3; boss:setScale(6)
    boss.zone.phase = 3; PhaseBlocks.update(level)
    step(level, es, 1.3)                                          -- (bajan los Congeladores)
    putBoss(boss, 80)
    for c = 79, 81 do level:crackIce(c, 13, 4, 'pound') end
    local soaked = step(level, es, 1.5, function() return boss.state == 'soaked' end)
    level:hitTile(83, 13, 'pound')                                -- su Activador
    local frozen = step(level, es, 2.5, function() return boss.state == 'frozen' end)
    local hp0 = boss.hp
    boss:pound(nil)
    check('congelada', soaked == true and frozen == true and boss.hp == hp0 - 3,
        ('empapada=%s → Activador → congelada=%s · ground pound: vida %d→%d'):format(
            tostring(soaked), tostring(frozen or false), hp0, boss.hp))
end

function cases.seca_aturdida()
    local level, es, boss = room(20, 10, nil, { { type = 'snowboss', col = 8, row = 9 } })
    fight(boss)
    local ok1 = boss:freeze(3)
    local st, dz, fr = boss.state, boss.dizzyFor, boss.frostT
    for _ = 1, 100 do boss:update(1 / 60, level) end
    local st2 = boss.state
    local again = boss:canFreeze()
    check('seca_aturdida', ok1 and st == 'dizzy' and dz < 2 and fr > 5 and st2 ~= 'dizzy' and not again,
        ('seca + chorro: %s %.1f s, escarchada %.1f s · a los 1.7 s: %s · otro chorro le afecta=%s'):format(
            st, dz or 0, fr or 0, st2, tostring(again)))
end

function cases.encoge()
    local level, es, boss = room(30, 12, nil, { { type = 'snowboss', col = 15, row = 11 } })
    fight(boss)
    local sc = { boss.sc }
    local grew
    boss.hp, boss.hpMax = 9, 14
    boss:phaseNow()
    for _ = 1, 150 do boss:update(1 / 60, level) end
    sc[#sc + 1] = boss.sc
    for _, c in ipairs(boss.icicles or {}) do if c.st == boss.IC.grow or c.st == boss.IC.ready then grew = true end end
    boss.hp = 4
    boss:phaseNow()
    for _ = 1, 150 do boss:update(1 / 60, level) end
    sc[#sc + 1] = boss.sc
    check('encoge', sc[1] == 10 and sc[2] == 8 and sc[3] == 6 and boss.phase == 3 and grew == true,
        ('escalas %d → %d → %d, fase %d, carámbanos crecen=%s'):format(sc[1], sc[2], sc[3], boss.phase, tostring(grew)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'bola', 'carambano', 'carambano_jefe', 'carambano_sacude', 'ola', 'onda_golpe',
                         'rueda_pared', 'rueda_escalon', 'rueda_activa', 'rueda_rompe', 'rueda_nieve', 'rueda_fin',
                         'salto_plataforma', 'salto_debajo', 'empapada', 'fase3_aparece', 'congelada',
                         'seca_aturdida', 'encoge' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
