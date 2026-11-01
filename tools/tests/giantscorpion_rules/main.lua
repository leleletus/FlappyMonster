-- tools/tests/giantscorpion_rules — reglas del ESCORPIÓN (types/enemies/scorpion.lua) y del ESCORPIÓN TRIPLE AGUIJÓN
-- (types/bosses/giantscorpion.lua) caso a caso, en una copia fija de su arena (arena.json):
--   chico_cola    jugador a su alcance: clic, cola atrás, clava donde estaba; quita 1 y se queda clavada
--   chico_esquiva si el jugador se aparta durante el aviso, el aguijón no le da
--   chico_pinza   muy cerca cierra la pinza: quita 1
--   chico_pisar   pisarlo lo mata
--   atravesable   su cuerpo no es sólido ni hace daño: se pasa a través y, encima, nada (fuera de su ventana)
--   chico_espalda ataca aunque estés a su espalda (se gira) y si saltas por encima (al aire)
--   chico_va      lejos de su alcance pero cerca: va a por ti, y más rápido que antes
--   salto         a otra altura salta a tu plataforma y luego de vuelta al suelo; lejos, salto largo
--   pared         corre a la pared, trepa, lanza desde allí y se deja caer
--   predice       apunta por delante de un jugador que corre; las marcas, repartidas
--   chico_anda    tras atacar vuelve a andar DE VERDAD (se desplaza)
--   llega         la cola llega a su marca: el pincho a menos de 12 px, en el pequeño y en el jefe
--   sin_rebote    un cambio de postura no se pasa de su objetivo y tarda lo que la matraca
--   matraca       enrollarse: la matraca suena al EMPEZAR y dura lo que el movimiento (0,21 s); igual al desenrollarse
--   enrollada     marca, golpe fuerte (quita 2 en la marca, nada fuera) y se queda clavada
--   ventana       clavada: pisotón -1, ground pound -2, también sobre la cola; tras el golpe se levanta en GETUP_T
--   arrancar      al acabar la ventana: arranca la cola, se desenrolla y vuelve a descansar
--   separadas     3 marcas distintas; cada aguijón golpea en su turno y solo en su marca; luego vuelven
--   dos_y_uno     en la última fase, el patrón 2 + 1: dos a la vez y luego la tercera
--   pinza         abre avisando y atrapa (como la planta: no se ve, machacar para salir, sonidos de la pinza)
--   pinza_falla   si se aparta durante el último tramo del aviso, no lo atrapa
--   pinza_otro    golpear al jefe con alguien atrapado lo libera
--   pinza_muerde  sin machacar pierde vida poco a poco
--   un_golpe      TODOS los jefes: un solo golpe por noqueo
--   fases         baja de fase a 2/3 y 1/3 de la vida (más rápido)
--   alcance       una marca nunca sale de la zona ni del alcance de la cola
--   derrota       el último golpe: tumbado, huye atravesando la pared, libera la zona y suelta su pieza
--   red           netPackExtra → otro (cliente): fase, marcas, orden y mano iguales; interact igual
--
--   tools/tests/run.sh giantscorpion_rules   (CASE=nombre)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
Sound = setmetatable({}, { __index = function(_, name)
    return function(snd) if name == 'play' or name == 'playAt' then played[#played + 1] = snd end end
end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local BossZones = require 'src/world/systems/BossZones'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 15

local fails = 0
local function check(case, ok, msg)
    print(('%-14s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function count(name) local n = 0; for _, s in ipairs(played) do if s == name then n = n + 1 end end; return n end

local function arena(diff)
    local f = assert(io.open('tools/tests/giantscorpion_rules/arena.json', 'r'))   -- (su propia copia: el usuario retoca la de levelgen en el editor)
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.difficulty = diff
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss, small
    for _, e in ipairs(es) do
        if e.def.name == 'giantscorpion' then boss = e end
        if e.def.name == 'scorpion' then small = e end
    end
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }
    boss.levelRef = level
    played = {}
    return level, es, boss, small
end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end
local function stepAll(level, es, players, secs, each, input)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        clear()
        if input then input() end
        for _, pa in ipairs(players) do pa:update(DT, level) end
        level.liveEntities = es
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        for _, pa in ipairs(players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end
local function feet() return (FLOOR - 1) * T end
local function playerAt(level, es, x)
    local pa = PlayerAdventure:new(x, feet() - 60)
    clear(); level.players = { pa }
    pa.invT = 0
    for _ = 1, 20 do pa:update(DT, level) end
    pa.invT = 0
    return pa
end
-- El jefe quieto en el centro, descansando sin atacar
local function still(boss, x)
    boss.x, boss.y = x or 28 * T, feet() - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround, boss.inv = 0, 0, true, 0
    boss.ghost, boss.downHitState, boss.clawCd = false, nil, 99
    boss.leapCd, boss.climbCd, boss.wall = 99, 99, nil
    boss.restLen = 99
    boss:enter('rest')
end
local function drop(pa, x, y, gp)
    local ob = pa:getOuterBounds()
    pa.x, pa.y, pa.vy, pa.onGround = x, y - ob.h / 2 + 6, 400, false
    pa.invT = 0
    if gp then pa.gpPhase = 'fall' end
end
local function waitState(level, es, pl, boss, st, secs)
    return stepAll(level, es, pl, secs or 3, function() return boss.state == st end)
end

local function smallOnly(level, es, small)
    local keep = { small }
    for _, e in ipairs(es) do if e ~= small and e.def.name ~= 'giantscorpion' then keep[#keep + 1] = e end end
    return keep
end
local function smallReady(level, es, small)
    small.x, small.y = 8 * T, feet() - small.outerH / 2
    small.facing, small.vx, small.vy, small.onGround = 1, 0, 0, true
    small.cd, small.deadTimer = 0, 0
    small:startWalk(); small.vx = 0
end

local CASES = {}
function CASES.chico_cola()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    local pa = playerAt(level, list, small.x + 85)
    local hp, seen = pa.hp, {}
    stepAll(level, list, { pa }, 1.2, function() seen[small.state] = true end)
    check('chico_cola', seen.sting_wind and seen.sting and seen.stuck, 'aviso, aguijón y clavada: ' .. tostring(seen.sting_wind) .. ' ' .. tostring(seen.stuck))
    check('chico_cola', count('scorpionClick') == 1 and count('scorpionSting') == 1, 'un clic y un pinchazo')
    check('chico_cola', pa.hp == hp - 1, ('quita 1 (%d → %d)'):format(hp, pa.hp))
    local again = false
    stepAll(level, list, { pa }, 1, function() pa.invT = 1; again = again or small.state == 'walk' or small.state == 'idle' end)
    check('chico_cola', again, 'luego vuelve a andar')
end
function CASES.chico_esquiva()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    local pa = playerAt(level, list, small.x + 85)
    local hp = pa.hp
    stepAll(level, list, { pa }, 2, function()
        if small.state == 'sting_wind' then pa.x = small.x + 6 * T end
    end)
    check('chico_esquiva', pa.hp == hp, 'apartado durante el aviso no le da')
end
function CASES.chico_pinza()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    local pa = playerAt(level, list, small.x + 50)
    local hp, seen = pa.hp, {}
    stepAll(level, list, { pa }, 0.7, function() seen[small.state] = true; pa.x = small.x + 50 end)
    check('chico_pinza', seen.pinch_wind and seen.pinch and count('scorpionSnap') == 1, 'avisa y cierra la pinza')
    check('chico_pinza', pa.hp < hp, 'quita vida')
end
function CASES.chico_pisar()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    small.cd = 9
    local pa = playerAt(level, list, 3 * T)
    drop(pa, small.x, small:getOuterBounds().y)
    stepAll(level, list, { pa }, 0.15)
    check('chico_pisar', small.state == 'dead' or not small.alive, 'pisado muere: ' .. tostring(small.state))
end
function CASES.atravesable()
    local level, es, boss = arena('normal')
    still(boss)
    check('atravesable', not boss:isSolidBody(), 'no es sólido')
    local pa = playerAt(level, es, boss.x + boss.outerW / 2 + 40)
    local h, x0 = pa.hp, pa.x
    stepAll(level, es, { pa }, 2, nil, function() stub.state.left = true end)
    check('atravesable', pa.x < boss.x - boss.outerW / 2 and pa.hp == h, ('lo cruza andando sin daño (%d → %d, vida %d)'):format(x0, pa.x, pa.hp))
    still(boss)
    local hp0 = boss.hp
    drop(pa, boss.x, boss:getOuterBounds().y)
    check('atravesable', boss:interact(pa) == nil, 'caerle encima fuera de su ventana: nada')
    stepAll(level, es, { pa }, 0.2)
    check('atravesable', boss.hp == hp0, 'ni le hace daño')
end
function CASES.chico_anda()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    local pa = playerAt(level, list, small.x + 85)
    stepAll(level, list, { pa }, 1.5, function() pa.invT = 1; return small.state == 'walk' and small.cd > 0 end)
    pa.x = 3 * T
    local x0 = small.x
    stepAll(level, list, { pa }, 0.8, function() pa.invT = 1 end)
    check('chico_anda', math.abs(small.x - x0) > 20, ('tras atacar anda de verdad (%d → %d, %s)'):format(x0, small.x, small.state))
end
function CASES.chico_espalda()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    small.facing = 1
    local pa = playerAt(level, list, small.x - 85)
    local seen = {}
    stepAll(level, list, { pa }, 0.3, function() seen[small.state] = true end)
    check('chico_espalda', seen.sting_wind and small.facing == -1, 'a su espalda: se gira y ataca')
    smallReady(level, list, small)
    small.facing = 1
    pa.x, pa.y, pa.vx, pa.vy, pa.onGround = small.x, small.y - 110, 0, 0, false
    pa.invT = 9
    seen = {}
    local my
    stepAll(level, list, { pa }, 0.2, function() seen[small.state] = true; pa.y = small.y - 110; pa.vy = 0; pa.onGround = false; my = small.markY end)
    check('chico_espalda', seen.sting_wind and my and my < small.y - 40, ('saltando por encima: apunta al aire (marca a %s, él en %d)'):format(tostring(my), small.y))
end
function CASES.chico_va()
    local level, es, boss, small = arena('normal')
    local list = smallOnly(level, es, small)
    smallReady(level, list, small)
    small.facing, small.vx, small.cd = -1, -100, 0
    small.x = 10 * T
    local pa = playerAt(level, list, small.x + 4.5 * T)
    local x0 = small.x
    stepAll(level, list, { pa }, 0.5, function() pa.invT = 1 end)
    check('chico_va', small.x > x0 + 30, ('va a por ti (%d → %d)'):format(x0, small.x))
end
function CASES.salto()
    local level, es, boss = arena('normal')
    still(boss, 45 * T)
    boss.climbCd = 99; boss.leapCd = 0
    -- de pie en la plataforma de en medio (columnas 33-38, fila 11)
    local pa = playerAt(level, es, 35 * T)
    pa.x, pa.y = 35.5 * T, 10 * T - 60
    pa.vy = 0
    for _ = 1, 30 do pa:update(DT, level) end
    check('salto', pa.onGround and pa.y < 11 * T, 'el jugador, en la plataforma')
    boss.restLen = 0; boss.deadTimer = 1
    local top
    stepAll(level, es, { pa }, 2.5, function() pa.invT = 1; pa.vx = 0; if boss.state == 'land' then top = boss:feetY(); return true end end)
    check('salto', top and math.abs(top - 10 * T) < 4, ('sube a tu plataforma (pies en %s, plataforma en %d)'):format(tostring(top), 10 * T))
    -- de vuelta al suelo
    still(boss, 35.5 * T); boss.y = 10 * T - boss.outerH / 2; boss.climbCd = 99; boss.leapCd = 0
    pa.x, pa.y = 25 * T, feet() - 40
    for _ = 1, 30 do pa:update(DT, level) end
    boss.restLen = 0; boss.deadTimer = 1
    top = nil
    stepAll(level, es, { pa }, 2.5, function() pa.invT = 1; if boss.state == 'land' then top = boss:feetY(); return true end end)
    check('salto', top and math.abs(top - feet()) < 4, 'baja al suelo a por ti')
    -- lejos: salto largo
    still(boss, 20 * T); boss.climbCd = 99; boss.leapCd = 0
    pa.x, pa.y = 50 * T, feet() - 40
    for _ = 1, 30 do pa:update(DT, level) end
    boss.restLen = 0
    local x0, jumped = boss.x, false
    for _ = 1, 20 do
        boss.deadTimer = 1; boss.restLen = 0; boss.leapCd = 0; boss:enter('rest')
        boss.restLen = 0; boss.deadTimer = 1
        stepAll(level, es, { pa }, 2 / 60, function() pa.invT = 1 end)
        if boss.state == 'leap_wind' then jumped = true; break end
    end
    stepAll(level, es, { pa }, 2.2, function() pa.invT = 1; return boss.state == 'land' end)
    check('salto', jumped and boss.x - x0 > 8 * T, ('salto largo (%d → %d)'):format(x0, boss.x))
end
function CASES.pared()
    local level, es, boss = arena('normal')
    still(boss, 22 * T)
    boss.climbCd = 0; boss.leapCd = 99; boss.clawCd = 99
    local pa = playerAt(level, es, 30 * T)
    boss.toWall = -1
    boss:enter('to_wall')
    local order, wallAt = {}, nil
    stepAll(level, es, { pa }, 12, function()
        pa.invT = 1; pa.x = 30 * T
        if order[#order] ~= boss.state then order[#order + 1] = boss.state end
        if boss.state == 'sting' then wallAt = wallAt or boss.wall end
        return boss.state == 'rest' and #order > 3
    end)
    local s = table.concat(order, ' ')
    check('pared', s:find('to_wall climb split_coil split_aim sting split_back', 1, true) ~= nil and s:find('wall_drop land', 1, true) ~= nil, s)
    check('pared', wallAt == -1, 'lanza agarrado a la pared')
    check('pared', boss.wall == nil and boss.onGround, 'y acaba en el suelo')
    still(boss, 22 * T); boss.wall = -1; boss.facing = -1; boss.y = 500
    local p = boss:netPack()
    local other = Entities.create({ type = 'giantscorpion', col = boss.col, row = boss.row, props = {} })
    other:netApply(p, p, 1)
    check('pared', other.wall == -1, 'la pared viaja por red')
    boss.wall = nil
end
function CASES.predice()
    local level, es, boss = arena('normal')
    still(boss, 28 * T); boss.climbCd, boss.leapCd = 99, 99
    local pa = playerAt(level, es, 22 * T)
    boss:startJoin(level, pa)
    pa.vx = 200
    local x0
    stepAll(level, es, { pa }, 1, function() pa.vx = 200; pa.invT = 1; x0 = x0 or pa.x; if boss.state == 'join_wind' then return true end end, function() stub.state.right = true end)
    check('predice', boss.marks[1].x > pa.x + 40, ('la marca, por delante de quien corre (marca %d, jugador %d)'):format(boss.marks[1].x, pa.x))
end
function CASES.llega()
    local Chain = require 'src/world/entities/base/SegmentChain'
    local Kit = require 'src/world/entities/base/ScorpionKit'
    local function tip(n, gap, k, bx, by, f, tx, ty, stretch)
        local c = Chain.new(n, gap)
        c:place(Kit.fan, bx, by, k, f, 2, 0, 1)
        for _ = 1, 40 do c:advance(1 / 30, Kit.FAST_K, Kit.FAST_DAMP, stretch, Kit.strike, bx, by, k, f, tx, ty) end
        local x, y = c:pos(n)
        return math.sqrt((x - (tx - Kit.TIP_D * k * f)) ^ 2 + (y - (ty - Kit.TIP_D * k)) ^ 2)
    end
    local c = Chain.new(12, 9.6)
    c:place(Kit.fan, 0, 0, 3, 1, 2, 0, 1)
    for _ = 1, 40 do c:advance(1 / 30, Kit.FAST_K, Kit.FAST_DAMP, 1.7, Kit.aim, 0, 0, 3, 155, 39) end
    local cx, cy = c:pos(12)
    local d = math.sqrt((cx - (155 - 155 / 160 * 18)) ^ 2 + (cy - (39 - 39 / 160 * 18)) ^ 2)
    check('llega', d < 12, ('el pequeño, a su máximo: a %.1f px'):format(d))
    d = tip(19, 23.8, 7, 0, 0, 1, 520, 91, 1.4)
    check('llega', d < 12, ('el jefe, a su máximo: a %.1f px'):format(d))
end
function CASES.sin_rebote()
    local Chain = require 'src/world/entities/base/SegmentChain'
    local Kit = require 'src/world/entities/base/ScorpionKit'
    local c = Chain.new(19, 23.8)
    c:place(Kit.fan, 0, 0, 7, 1, 3, 0, 1)
    local x0, y0 = c:pos(19)
    local tg = {}
    for i = 1, 19 do tg[i] = { x = 0, y = 0 } end
    Kit.fan(tg, 19, 0, 0, 7, 1, 1, 0, 1)
    local dist0 = math.sqrt((tg[19].x - x0) ^ 2 + (tg[19].y - y0) ^ 2)
    local maxOver, t90 = 0, nil
    for f = 1, 60 do
        c:advance(1 / 30, Kit.COIL_K, Kit.COIL_DAMP, nil, Kit.fan, 0, 0, 7, 1, 1, 0, 1)
        local x, y = c:pos(19)
        local along = ((x - x0) * (tg[19].x - x0) + (y - y0) * (tg[19].y - y0)) / dist0
        maxOver = math.max(maxOver, along - dist0)
        if not t90 and along >= dist0 * 0.9 then t90 = f / 30 end
    end
    check('sin_rebote', maxOver < dist0 * 0.08, ('se pasa %.1f px de %.0f'):format(maxOver, dist0))
    check('sin_rebote', t90 and t90 <= 0.27, ('llega en %.2f s (la matraca dura 0,21 s)'):format(t90 or -1))
end
function CASES.matraca()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    boss:startJoin(level, pa)
    check('matraca', played[#played] == 'scorpionRattleJoin', 'enrollarse: suena al empezar')
    local n = 0
    stepAll(level, es, { pa }, 1, function() if boss.state == 'join_coil' then n = n + 1 else return true end end)
    check('matraca', math.abs(n / 60 - 0.21) < 0.03, ('dura lo del movimiento (%.2f s)'):format(n / 60))
    still(boss)
    boss:startSplit(true)
    check('matraca', played[#played] == 'scorpionRattleSplit', 'desenrollarse: suena al empezar')
end
function CASES.enrollada()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    local hp = pa.hp
    boss:startJoin(level, pa)
    waitState(level, es, { pa }, boss, 'join_wind')
    local mk = boss.marks[1]
    check('enrollada', math.abs(mk.x - pa.x) < 2 and mk.y == FLOOR * T - T or math.abs(mk.y - feet()) < T, ('marca bajo el jugador (%d, %d)'):format(mk.x, mk.y))
    waitState(level, es, { pa }, boss, 'stuck')
    check('enrollada', pa.hp == hp - 2, ('en la marca quita 2 (%d → %d)'):format(hp, pa.hp))
    check('enrollada', count('scorpionStrike') == 1, 'suena el golpe')
    still(boss)
    local pb = playerAt(level, es, 19 * T)
    hp = pb.hp
    boss:startJoin(level, pb)
    waitState(level, es, { pb }, boss, 'join_wind')
    stepAll(level, es, { pb }, 2, function() if boss.state == 'stuck' then return true end; pb.x = 37 * T; pb.invT = 0 end)
    check('enrollada', pb.hp == hp, 'lejos de la marca no le da')
end
function CASES.ventana()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    boss:startJoin(level, pa)
    waitState(level, es, { pa }, boss, 'stuck')
    pa.invT, boss.inv = 0, 0
    local hp0 = boss.hp
    drop(pa, boss.x, boss:getOuterBounds().y)
    stepAll(level, es, { pa }, 0.2, function() return boss.hp < hp0 end)
    check('ventana', boss.hp == hp0 - 1, ('pisotón en el cuerpo -1 (%d → %d)'):format(hp0, boss.hp))
    -- ground pound, en la cola clavada (lejos del cuerpo)
    still(boss); boss.stuckLen = 9
    local pc = playerAt(level, es, 22 * T)
    boss:startJoin(level, pc)
    waitState(level, es, { pc }, boss, 'stuck')
    boss.stuckLen, boss.inv = 9, 0
    pc.invT = 0
    hp0 = boss.hp
    local mk = boss.marks[1]
    local Kit = require 'src/world/entities/base/ScorpionKit'
    local line = Kit.strikeLine({}, 10, boss:tailX(), boss:tailY(), 7, boss.facing, mk.x, mk.y)
    local ob = pc:getOuterBounds()
    pc.x, pc.y, pc.vy, pc.onGround, pc.gpPhase = line[8].x, line[8].y - 20 - ob.h / 2, 300, false, 'fall'
    check('ventana', math.abs(pc.x - boss.x) > boss.outerW / 2 + 20, 'la cola, fuera del cuerpo')
    stepAll(level, es, { pc }, 0.3, function() return boss.hp < hp0 end)
    check('ventana', boss.hp == hp0 - 2, ('ground pound sobre la COLA -2 (%d → %d)'):format(hp0, boss.hp))
    local t0 = boss.deadTimer
    local n = 0
    stepAll(level, es, { pc }, 3, function() n = n + DT; pc.invT = 1; return boss.state ~= 'stuck' end)
    check('ventana', n <= boss.GETUP_T + 0.1, ('tras el golpe se levanta pronto (%.1f s)'):format(n))
end
function CASES.arrancar()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    boss:startJoin(level, pa)
    local order = {}
    stepAll(level, es, { pa }, 8, function()
        pa.invT = 1
        if order[#order] ~= boss.state then order[#order + 1] = boss.state end
        return boss.state == 'rest'
    end)
    local s = table.concat(order, ' ')
    check('arrancar', s:find('stuck pull split_coil rest', 1, true) ~= nil, s)
    check('arrancar', count('scorpionPull') == 1 and count('scorpionRattleSplit') == 1, 'arranca y se desenrolla con su matraca')
end
function CASES.separadas()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    local hp = pa.hp
    boss:startSplit(false)
    waitState(level, es, { pa }, boss, 'split_aim')
    local m = boss.marks
    check('separadas', m[1].x ~= m[2].x and m[2].x ~= m[3].x and m[1].x ~= m[3].x, ('3 marcas (%d, %d, %d)'):format(m[1].x, m[2].x, m[3].x))
    local o = boss.order
    local first
    for i = 1, 3 do if math.abs(m[i].x - pa.x) < 2 then first = i end end
    check('separadas', first ~= nil, 'una va a por el jugador')
    played = {}
    local hits, at = {}, {}
    stepAll(level, es, { pa }, 3, function()
        pa.x = 37 * T; pa.invT = 0
        if boss.state == 'sting' then
            for i = 1, 3 do if not at[i] and boss.deadTimer >= boss:stingAt(i) then at[i] = boss.deadTimer end end
        end
        return boss.state == 'rest'
    end)
    check('separadas', count('scorpionSting') == 3, 'tres pinchazos: ' .. count('scorpionSting'))
    check('separadas', at[1] and at[2] and at[3] and at[1] ~= at[2] and at[2] ~= at[3], 'cada una en su turno')
    check('separadas', pa.hp == hp, 'fuera de las marcas no le da')
    -- en su marca: quita 1
    still(boss)
    local pb = playerAt(level, es, 22 * T)
    hp = pb.hp
    boss:startSplit(false)
    waitState(level, es, { pb }, boss, 'sting')
    local i1 = require('src/world/entities/types/bosses/giantscorpion').class and 1
    local mk
    local best = 99
    for i = 1, 3 do if boss:stingAt(i) < best then best, mk = boss:stingAt(i), boss.marks[i] end end
    pb.x, pb.invT = mk.x, 0
    stepAll(level, es, { pb }, best + 0.05)
    check('separadas', pb.hp == hp - 1, ('en su marca quita 1 (%d → %d)'):format(hp, pb.hp))
end
function CASES.dos_y_uno()
    local level, es, boss = arena('normal')
    still(boss)
    boss.two, boss.gapT, boss.order = true, 0.26, 1
    local a, b, c = boss:stingAt(1), boss:stingAt(2), boss:stingAt(3)
    check('dos_y_uno', a == b and c > a, ('dos a la vez y la tercera después (%.2f %.2f %.2f)'):format(a, b, c))
    boss.two = false
    a, b, c = boss:stingAt(1), boss:stingAt(2), boss:stingAt(3)
    check('dos_y_uno', a < b and b < c, 'sin el patrón, una a una')
end
local function startClaw(level, es, boss, pa)
    boss.clawCd = 0
    boss.restLen = 0
    boss.deadTimer = 1
    stepAll(level, es, { pa }, 0.05)
    return boss.state
end
function CASES.pinza()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, boss.x + 3.8 * T)
    check('pinza', startClaw(level, es, boss, pa) == 'claw_wind', 'a tiro: abre la pinza avisando: ' .. boss.state)
    check('pinza', count('scorpionHiss') == 1, 'con su siseo')
    stepAll(level, es, { pa }, 2, function() return boss.state == 'hold' end)
    check('pinza', boss.state == 'hold' and pa.gulped and boss.held == pa and pa.gulpKind == 1, 'lo atrapa')
    check('pinza', pa.gulpBy == boss, 'quien lo tiene es el jefe')
    stepAll(level, es, { pa }, 2, function() return not pa.gulped end, function() stub.state.jump_pressed = true end)
    local mashed = not pa.gulped
    check('pinza', mashed, 'machacando sale')
    played = {}
    stepAll(level, es, { pa }, 0.8, function() pa.invT = 1 end)
    check('pinza', boss.state == 'rest' or boss.state == 'claw_back', 'la pinza vuelve: ' .. boss.state)
end
function CASES.pinza_falla()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, boss.x + 3.8 * T)
    startClaw(level, es, boss, pa)
    stepAll(level, es, { pa }, 2, function()
        if boss.state == 'claw_wind' and boss.deadTimer > 0.55 then pa.x = 18 * T end
        return boss.state == 'claw_back' or boss.state == 'hold'
    end)
    check('pinza_falla', boss.state == 'claw_back' and not pa.gulped, 'se apartó en el último tramo: falla')
end
function CASES.pinza_otro()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, boss.x + 3.8 * T)
    startClaw(level, es, boss, pa)
    stepAll(level, es, { pa }, 2, function() return boss.state == 'hold' end)
    local hp0 = boss.hp
    boss:stomp()
    check('pinza_otro', boss.hp == hp0 - 1 and boss.state == 'claw_back', 'con alguien atrapado se le puede golpear y lo suelta')
    stepAll(level, es, { pa }, 0.1)
    check('pinza_otro', not pa.gulped, 'el atrapado sale')
end
function CASES.pinza_muerde()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, boss.x + 3.8 * T)
    startClaw(level, es, boss, pa)
    stepAll(level, es, { pa }, 2, function() return boss.state == 'hold' end)
    local hp = pa.hp
    played = {}
    stepAll(level, es, { pa }, 2.0)
    check('pinza_muerde', pa.hp == hp - 1 and count('scorpionSnap') >= 1 and count('plantCrunch') == 0, ('pierde vida con el sonido de la pinza (%d → %d)'):format(hp, pa.hp))
end
-- UN GOLPE POR NOQUEO, en TODOS los jefes (el usuario): dos golpes en la misma ventana, separados por más que INV_TIME
function CASES.un_golpe()
    local level, es, boss = arena('normal')
    local WINDOWS = { giantscorpion = 'stuck', giantbeetle = 'flipped', gianthopper = 'scared', giantpuffer = 'gasp',
                      groovecrab = 'stunned', megagummy = 'dazed', megacrabby = 'stuck', megacrabby_ice = 'stuck',
                      miniboss1 = 'stuck', snowboss = 'dizzy', megagloomy = 'dazzled' }
    for name, st in pairs(WINDOWS) do
        local e = Entities.create({ type = name, col = 30, row = 14, props = {} })
        e.hp, e.hpMax, e.inv, e.state, e.deadTimer, e.phase = 50, 50, 0, st, 0, 1
        e.zone = nil
        local first = e.isVulnerable and e:isVulnerable()
        local hit1 = first and e:damage(1, 'stomp')
        local hp1 = e.hp
        local reopened = false
        for k = 1, 16 do                       -- (lo que dura la ventana tras el golpe, sin que el tipo cambie de estado)
            e.inv = math.max(0, e.inv - 0.1)
            if k <= 15 and e.state == st then
                e.state = st
                if k <= 14 and e:isVulnerable() and e.inv <= 0 then reopened = true end
            end
        end
        check('un_golpe', first and hit1 and hp1 == 49 and not reopened, name .. ' en ' .. st .. ': un golpe y no se reabre en 1,4 s (invulnerable ' .. ('%.1f'):format(e.inv) .. ')')
    end
end
function CASES.fases()
    local level, es, boss = arena('normal')
    still(boss)
    boss.hp, boss.hpMax = 12, 12
    check('fases', boss:ph() == 1, 'empieza en la 1')
    boss:enter('stuck'); boss.inv = 0
    boss.hp = 9; boss:damage(1, 'stomp')
    check('fases', boss:ph() == 2, 'a 2/3: fase 2')
    boss.inv = 0; boss.hp = 5; boss:damage(1, 'stomp')
    check('fases', boss:ph() == 3 and boss:angryPhase(), 'a 1/3: fase 3')
end
function CASES.alcance()
    local level, es, boss = arena('normal')
    still(boss, 18 * T + 40)
    local zx0, zx1 = boss:zoneBounds()
    local x = boss:markAt(level, zx1 + 900, feet() - 40)
    check('alcance', x <= zx1 and x <= boss:tailX() + 520, ('no pasa del alcance (%d)'):format(x))
    x = boss:markAt(level, zx0 - 900, feet() - 40)
    check('alcance', x >= zx0, ('ni sale de la zona (%d, zona %d)'):format(x, zx0))
    -- lejos: anda hacia el jugador
    still(boss, 18 * T + 40)
    local pa = playerAt(level, es, 39 * T)
    local x0 = boss.x
    stepAll(level, es, { pa }, 1)
    check('alcance', boss.x > x0 + 50 or boss.state == 'leap_wind', ('se acerca andando (%d → %d)'):format(x0, boss.x))
end
function CASES.derrota()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 18 * T)
    boss:enter('stuck'); boss.inv = 0; boss.hp = 1
    boss:stomp()
    check('derrota', boss.state == 'dying_out' and boss:isDying(), 'último golpe: tumbado')
    check('derrota', not boss:shardDrop(), 'aún lleva su pieza')
    stepAll(level, es, { pa }, 2.4, function() return boss.state == 'dying_flee' end)
    check('derrota', boss.state == 'dying_flee' and boss:releasesZone(), 'huye y libera la zona')
    check('derrota', boss:shardDrop(), 'suelta la pieza')
    local x0 = boss.x
    stepAll(level, es, { pa }, 17, function() return boss.state == 'dead' end)
    check('derrota', boss.state == 'dead' and math.abs(boss.x - x0) > 300, 'se va lejos y acaba')
end
function CASES.red()
    local level, es, boss = arena('normal')
    still(boss)
    local pa = playerAt(level, es, 22 * T)
    boss:startSplit(false)
    waitState(level, es, { pa }, boss, 'split_aim')
    boss.phase = 3
    boss.handX, boss.handY = 1234, 567
    local pack = boss:netPack()
    local other = Entities.create({ type = 'giantscorpion', col = boss.col, row = boss.row, props = {} })
    other:netApply(pack, pack, 1)
    local same = other.phase == 3 and other.order == boss.order and other.handX == 1234 and other.two == boss.two
    for i = 1, 3 do same = same and other.marks[i].x == boss.marks[i].x and other.marks[i].y == boss.marks[i].y end
    check('red', same, 'fase, marcas, orden y mano iguales')
    check('red', math.abs(other:stingAt(1) - boss:stingAt(1)) < 0.011, 'y el turno de cada aguijón')
    local s = Entities.create({ type = 'scorpion', col = 8, row = 14, props = {} })
    s.markX, s.markY = 300, 400
    local o = Entities.create({ type = 'scorpion', col = 8, row = 14, props = {} })
    o:netApply(s:netPack(), s:netPack(), 1)
    check('red', o.markX == 300 and o.markY == 400, 'el pequeño: su marca')
end

function love.load()
    local only = os.getenv('CASE')
    local names = {}
    for k in pairs(CASES) do names[#names + 1] = k end
    table.sort(names)
    for _, k in ipairs(names) do
        if not only or only == k then
            played = {}
            local ok, err = xpcall(CASES[k], debug.traceback)
            if not ok then check(k, false, 'ERROR ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'RESULTADO: OK' or ('RESULTADO: ' .. fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
