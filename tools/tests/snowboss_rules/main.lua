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
--                 sale de un GRAN salto a lo seco (no al fondo de la poza: se quedaba atascada) y
--                 el hielo se rehace solo DESPUÉS de que salga (nunca con ella en el agua) y en
--                 cuanto sale: ya entero al aterrizar (antes tardaba ~4.6 s: se la podía tirar
--                 otra vez por el mismo agujero); no vuelve a caer en él
--   romper        cae de un salto sobre una bolsa de hielo fino: la rompe y cae al agua (siempre)
--   bola_plataforma una bola de nieve atraviesa una plataforma y solo la para el suelo de la arena
--   salto_bajar   desde la plataforma de arriba, marca en el suelo: llega al suelo (no se queda
--                 en la plataforma de en medio)
--   risa          no se ríe cuando muere un jugador (eso es solo del Espejo)
--   descansa      sin que nadie la golpee, 14 s por fase: el tiempo parada (pausas, aterrizajes,
--                 descansos) baja de fase en fase y en la 3 es < 30 %. (Tras rodar se recupera y la
--                 tanda vuelve a empezar: en la fase 1 casi nunca llega a descansar)
--   fase3_aparece arena real: Activadores del suelo y Congeladores no están hasta la fase 3;
--                 en la fase 3 sale el Activador (en vez de hielo) y el Congelador baja
--   congelada     fase 3, empapada en la bolsa + su Activador → su Congelador la CONGELA;
--                 ground pound = 3
--   congelada_saliendo  en el agua SIN estar empapada (cogiendo impulso para salir) + chorro →
--                 CONGELADA igual (basta con estar en el agua)
--   carambano_fase3  al llegar a la fase 3 los carámbanos se rompen y no vuelven (el que caía
--                 termina de caer y tampoco vuelve)
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

-- Arena real (la del usuario): zona 75-98 filas 4-14, bolsas de hielo fino 79-81 / 92-94 (fila 13,
-- agua debajo), plataformas traspasables medias (fila 8) 79-82 / 91-94 y de arriba (fila 7) 85-88,
-- repisas de nieve a los lados; Activadores 83 y 90 (fila 13), Congeladores (80,5) y (93,5)
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
    local pa = PlayerAdventure:new(80.5 * T, 7 * T - 60)         -- en la plataforma media izquierda
    level.players = { pa }
    for _ = 1, 30 do pa:update(1 / 60, level) end
    local ok0 = boss:startLeap(level, pa)
    local t = leapUntilLanded(level, es, boss)
    local onPlat = math.abs(boss:feetY() - 7 * T) < 2 and boss.x > 78 * T and boss.x < 82 * T + 1
    check('salto_plataforma', ok0 and onPlat and boss.state == 'leap_land',
        ('marca (%.1f, fila %.2f) · cae en x=%.1f casillas, pies a la fila %.2f en %.1f s (%s)'):format(
            boss.landX / T, boss.landY / T, boss.x / T, boss:feetY() / T, t, boss.state))
end

function cases.salto_debajo()
    local level, es, boss = lago()
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    putBoss(boss, 87)                                             -- debajo de la plataforma de arriba
    local pa = PlayerAdventure:new(86.5 * T, 6 * T - 60)          -- encima de ella
    level.players = { pa }
    for _ = 1, 30 do pa:update(1 / 60, level) end
    boss:startLeap(level, pa)
    leapUntilLanded(level, es, boss)
    check('salto_debajo', math.abs(boss:feetY() - 6 * T) < 2,
        ('desde debajo: pies a la fila %.2f (plataforma de arriba: 6)'):format(boss:feetY() / T))
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
    local last
    local wetHeal = false
    step(level, es, 10, function()
        t = t + 1 / 60
        if boss:inWater(level) and (level:getDef(79, 13).thinIce or level:getDef(80, 13).thinIce) then wetHeal = true end
        if os.getenv('TRACE') and boss.state ~= last then          -- (TRACE=1: estados de la bola)
            last = boss.state
            print(('      t=%.2f %s x=%.1f pies=%.2f vy=%.0f agua=%s marca=%s'):format(t, boss.state, boss.x / T,
                boss:feetY() / T, boss.vy or 0, tostring(boss:inWater(level)), boss.landX and ('%.1f,%.2f'):format(boss.landX / T, boss.landY / T) or '-'))
        end
        if not boss:inWater(level) and boss.onGround and (boss.state == 'leap_land' or boss.state == 'land' or boss.state == 'idle') then
            out = true; return true
        end
    end)
    -- (mientras está en el agua el hielo no vuelve; lo comprueba wetHeal). Al aterrizar fuera,
    -- el hielo ya está entero (como mucho un paso después)
    step(level, es, 2 / 60)
    local lake = level:getDef(79, 13).name .. ',' .. level:getDef(80, 13).name .. ',' .. level:getDef(81, 13).name
    local healed = level:getDef(79, 13).thinIce and level:getDef(80, 13).thinIce and level:getDef(81, 13).thinIce
    local again = step(level, es, 4.5, function() return boss.state == 'soaked' end)
    check('empapada', soaked == true and vuln and out and healed and not wetHeal and not again,
        ('cae al agua: empapada=%s vulnerable=%s · sale en %.1f s=%s (x=%.1f) · lago al aterrizar: %s · se rehízo con ella dentro=%s · vuelve a caer=%s'):format(
            tostring(soaked), tostring(vuln), t, tostring(out), boss.x / T, lake, tostring(wetHeal), tostring(again or false)))
end

function cases.romper()
    local level, es, boss = lago()
    fight(boss)
    boss:findLake(level)
    boss.x, boss.y, boss.vx, boss.vy, boss.onGround = 80 * T, 9 * T, 0, 0, false
    boss:enter('hop')
    local soaked = step(level, es, 3, function() return boss.state == 'soaked' end)
    check('romper', soaked == true,
        ('cae sobre la bolsa: %s (hielo: %s)'):format(boss.state, level:getDef(80, 13).name))
end

function cases.bola_plataforma()
    local level, es, boss = lago()
    fight(boss)
    -- una bola cayendo en vertical sobre la plataforma media izquierda (fila 8, 79-82)
    boss.proj = { { id = 1, x = 80.5 * T, y = 5 * T, vx = 0, vy = 200, t = 0 } }
    local minY, gone = 0, false
    step(level, es, 2, function()
        local b = boss.proj[1]
        if b then minY = math.max(minY, b.y) else gone = true; return true end
    end)
    check('bola_plataforma', gone and minY > 12 * T - 30 and minY < 12 * T + 4,
        ('la bola llega a y=%.2f casillas (plataforma en la 8; la cara del suelo en la 12.00)'):format(minY / T))
end

function cases.salto_bajar()
    local level, es, boss = lago()
    fight(boss)
    boss.phase = 2; boss:setScale(8)
    boss.x, boss.y = 86.5 * T, 6 * T - boss.outerH / 2          -- encima de la plataforma de arriba
    boss.vy, boss.onGround = 0, true
    local pa = PlayerAdventure:new(81 * T, 12 * T - 60)          -- en el suelo, bajo la plataforma media
    level.players = { pa }
    for _ = 1, 30 do pa:update(1 / 60, level) end
    boss.landX, boss.landY = math.floor(81 * T), math.floor(12 * T)
    boss:enter('leap_wind')
    leapUntilLanded(level, es, boss)
    check('salto_bajar', math.abs(boss:feetY() - 12 * T) < 2,
        ('marca en el suelo (fila 12): pies a la fila %.2f (%s)'):format(boss:feetY() / T, boss.state))
end

function cases.descansa()
    local res = {}
    for ph = 1, 3 do
        local level, es, boss = lago()
        fight(boss)
        boss.phase = ph; boss:setScale(({ 10, 8, 6 })[ph])
        local pa = PlayerAdventure:new(77 * T, 12 * T - 60)
        level.players = { pa }
        local last, attacks, firstRest, still, total = nil, 0, nil, 0, 0
        local PAUSE = { idle = true, rest = true, recover = true, land = true, leap_land = true, slam_land = true }
        local ATT = { hop = true, leap_wind = true, shoot = true, windup = true, slam_up = true }
        step(level, es, 14, function()
            pa.x, pa.y, pa.vx, pa.vy, pa.invT = 77 * T, 12 * T - 60, 0, 0, 9          -- (quieto e intocable)
            total = total + 1
            if PAUSE[boss.state] then still = still + 1 end
            if boss.state ~= last then
                last = boss.state
                if ATT[boss.state] and not firstRest then attacks = attacks + 1 end
                if boss.state == 'rest' and not firstRest then firstRest = attacks end
            end
        end)
        res[ph] = { firstRest = firstRest, still = still / total }
    end
    local ok = res[1].still > res[2].still and res[2].still > res[3].still and res[3].still < 0.3
    check('descansa', ok, ('ataques antes de descansar: %s / %s / %s · tiempo parada: %.0f%% / %.0f%% / %.0f%%'):format(
        tostring(res[1].firstRest), tostring(res[2].firstRest), tostring(res[3].firstRest),
        100 * res[1].still, 100 * res[2].still, 100 * res[3].still))
end

function cases.risa()
    local level, es, boss = lago()
    fight(boss)
    local played = {}
    local real = Sound
    Sound = setmetatable({ play = function(n) played[n] = true end }, { __index = function() return function() end end })
    local pa = PlayerAdventure:new(80 * T, 12 * T - 60)
    boss:onPlayerDeath(pa)
    Sound = real
    check('risa', not played.snowLaugh, ('al morir un jugador: risa=%s'):format(tostring(played.snowLaugh or false)))
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

function cases.congelada_saliendo()
    local level, es, boss = lago()
    fight(boss)
    boss:findLake(level)
    boss.phase = 3; boss:setScale(6)
    putBoss(boss, 80)
    for c = 79, 81 do level:crackIce(c, 13, 4, 'pound') end
    local soaked = step(level, es, 1.5, function() return boss.state == 'soaked' end)
    -- espera a que deje de estar empapada y coja impulso para salir (sigue en el agua)
    local wind = step(level, es, 6, function() return boss.state ~= 'soaked' and boss:inWater(level) end)
    local st = boss.state
    local ok = boss:freeze(3)
    local frozen = boss.state == 'frozen'
    step(level, es, 0.5)
    local stays = boss.state == 'frozen' and boss:inWater(level)
    check('congelada_saliendo', soaked == true and wind == true and st ~= 'soaked' and ok and frozen and stays,
        ('empapada=%s · luego %s en el agua=%s · chorro → %s (sigue congelada en el agua=%s)'):format(
            tostring(soaked), st, tostring(wind or false), boss.state, tostring(stays)))
end

function cases.carambano_fase3()
    local level, es, boss = room(30, 12, nil, { { type = 'snowboss', col = 15, row = 11 } })
    fight(boss)
    boss.hp, boss.hpMax = 9, 14
    boss:phaseNow()
    for _ = 1, 200 do boss:update(1 / 60, level) end           -- fase 2: crecen
    local list = boss:icicleList()
    local ready = 0
    for _, c in ipairs(list) do if c.st == boss.IC.ready then ready = ready + 1 end end
    list[1].st, list[1].t, list[1].vy = boss.IC.fall, 0, 0       -- uno cayendo al cambiar de fase
    boss.hp = 4
    boss:phaseNow()
    for _ = 1, 150 do boss:update(1 / 60, level) end
    for _ = 1, 600 do                                          -- 10 s más en la fase 3
        boss.state, boss.deadTimer = 'recover', 0              -- (quieta: que no salte ni ruede)
        boss:update(1 / 60, level)
    end
    local left = 0
    for _, c in ipairs(list) do if c.st ~= boss.IC.hidden then left = left + 1 end end
    check('carambano_fase3', ready > 0 and boss.phase == 3 and left == 0,
        ('fase 2: %d carámbanos listos · fase 3 y 10 s después: %d sin desaparecer'):format(ready, left))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'bola', 'carambano', 'carambano_jefe', 'carambano_sacude', 'ola', 'onda_golpe',
                         'rueda_pared', 'rueda_escalon', 'rueda_activa', 'rueda_rompe', 'rueda_nieve', 'rueda_fin',
                         'salto_plataforma', 'salto_debajo', 'empapada', 'romper', 'bola_plataforma', 'salto_bajar',
                         'risa', 'descansa', 'fase3_aparece', 'congelada', 'congelada_saliendo', 'carambano_fase3',
                         'seca_aturdida', 'encoge' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
