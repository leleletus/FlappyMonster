-- tools/tests/tifon_rules — reglas de TIFÓN, el Soplón Supremo (types/bosses/tifon.lua) caso a caso, en una copia fija de su arena
-- (tools/levelgen/arenas/jefe_tifon.json → arena.json):
--   soplo        aviso 1 s sin viento; luego te empuja hacia donde sopla, más deprisa de lo que andas
--   cobijo       pegado a una chimenea (contra el viento) no te mueve; detrás de una caja tampoco
--   cambio       fase 2: a mitad del soplo el viento cambia de lado (con el aviso de la veleta antes)
--   aspira       te arrastra hacia debajo de su boca, sin levantarte; a una bomba suelta la levanta hacia la boca
--   traga        una bomba LANZADA y encendida que llega a la boca: se la traga, revienta, cae al tejado y queda aturdido
--   tose         una bomba apagada que llega a la boca: la tose hacia ti y sigue sin aturdirse
--   escupe       si llegas tú a la boca aspirando: −1 y te escupe
--   rayo         marcas en el tejado (ninguna sobre el hueco); al caer, −1 en la columna de la marca y nada fuera
--   arco         fase 2: arco a ras del tejado entre dos marcas; saltándolo no te da
--   granizo      fase 2: cae granizo; te da al descubierto, la cornisa te tapa
--   pisar        aturdido: pisotón −1, ground pound −2, un golpe por noqueo; volando, caerle encima solo rebota
--   atravesable  su cuerpo no es sólido ni hace daño
--   fase         a mitad de vida pasa a la fase 2 y ruge al volver a vagar
--   derrota      el último golpe: se va hacia arriba, libera la zona y suelta la astilla
--   red          netPackExtra → otro (cliente): fase, viento, marcas, arcos, granizo iguales; su aire empuja igual
--
--   tools/tests/run.sh tifon_rules   (CASE=nombre)
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
local Push = require 'src/world/systems/Push'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 14
local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function arena()
    local f = assert(io.open('tools/tests/tifon_rules/arena.json', 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.difficulty = 'normal'
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'tifon' then boss = e end end
    level.players = {}
    local z = level.bossZones[1]
    boss.zone = z
    boss:onIntroStart(level, {})
    boss:startFight(1)
    z.state, z.bosses = 'fight', { boss }
    boss.levelRef = level
    played = {}
    return level, es, boss
end
local function clear() for k in pairs(stub.state) do stub.state[k] = false end end
local function stepAll(level, es, players, secs, each, input)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        level.pushers = Push.collect(es)
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
local function playerAt(level, x, y)
    local pa = PlayerAdventure:new(x, (y or feet()) - 60)
    clear(); level.players = { pa }
    for _ = 1, 20 do pa:update(DT, level) end
    pa.invT = 0
    return pa
end
-- Quieto, sin atacar por su cuenta, en un sitio fijo
local function still(boss, x)
    boss.idleT, boss.inv = 999, 0
    boss.marks, boss.arcs, boss.hail = {}, {}, {}
    boss.roared = true
    boss:enter('idle')
    if x then boss.x = x end
end
local function count(name) local n = 0; for _, s in ipairs(played) do if s == name then n = n + 1 end end; return n end
local function find(es, name, i)
    local k = 0
    for _, e in ipairs(es) do if e.def.name == name and e.alive then k = k + 1; if k == (i or 1) then return e end end end
end
-- Lo pone a hacer un ataque ya (sin esperar a que le toque)
local function attack(boss, st, dir)
    boss.windDir = dir or boss.windDir
    boss:enter(st)
end
-- El jefe no se mueve en los casos que miden el aire (vagar cambia hacia dónde mira)
local function freeze(boss) local x, y = boss.x, boss.y; return function() boss.x, boss.y = x, y end end

local CASES = {}
function CASES.soplo()
    local level, es, boss = arena()
    still(boss, 18 * T)
    level.tiles[12][32], level.tiles[13][32] = 0, 0          -- (sin la chimenea ni la caja de delante: sitio para que te lleve)
    find(es, 'box', 2).alive = false
    local pa = playerAt(level, 30.3 * T)
    local hold = freeze(boss)
    attack(boss, 'warn', 1)
    local x0 = pa.x
    stepAll(level, es, { pa }, 0.9, function() hold(); pa.invT = 9 end)
    check('soplo', math.abs(pa.x - x0) < 4 and count('tifonWarn') == 0 and boss.state == 'warn', 'el aviso: sin viento')
    stepAll(level, es, { pa }, 0.3, function() hold() end)
    check('soplo', boss.state == 'blow', 'después sopla')
    x0 = pa.x
    stepAll(level, es, { pa }, 0.8, function() hold(); pa.invT = 9 end, function() stub.state.left = true end)
    check('soplo', pa.x > x0 + 40, ('andando contra el viento te lleva igual (%d → %d)'):format(x0, pa.x))
end
function CASES.cobijo()
    local level, es, boss = arena()
    still(boss, 18 * T)
    -- la chimenea de 2 de alto de la columna 25: el viento hacia la derecha, tú pegado a su lado derecho
    local pa = playerAt(level, 25 * T + 30)
    local hold = freeze(boss)
    attack(boss, 'blow', 1)
    local x0 = pa.x
    stepAll(level, es, { pa }, 1.2, function() hold(); pa.invT = 9 end)
    check('cobijo', math.abs(pa.x - x0) < 6, ('tras la chimenea no te mueve (%d → %d)'):format(x0, pa.x))
    -- tras la caja: el viento hacia la izquierda, la caja de la columna 35 a tu derecha
    local box = find(es, 'box', 2)
    local pb = playerAt(level, box.x - box.outerW / 2 - 30)
    still(boss, 40 * T)
    attack(boss, 'blow', -1)
    hold = freeze(boss)
    x0 = pb.x
    local bx0 = box.x
    stepAll(level, es, { pb }, 1.0, function() hold(); pb.invT = 9 end)
    check('cobijo', math.abs(pb.x - x0) < 40 + math.abs(box.x - bx0), ('tras la caja, solo lo que se mueva la caja (%d → %d; caja %d → %d)'):format(x0, pb.x, bx0, box.x))
end
function CASES.cambio()
    local level, es, boss = arena()
    still(boss, 20 * T)
    boss.phase = 2
    local hold = freeze(boss)
    attack(boss, 'blow', 1)
    boss.swapped = true
    local a = boss:windNow()
    local vane = 0
    stepAll(level, es, {}, 1.0, function() hold() end)
    vane = count('tifonVane')
    stepAll(level, es, {}, 0.5, function() hold() end)
    local b = boss:windNow()
    check('cambio', a == 1 and b == -1, ('el viento cambia de lado (%d → %d)'):format(a, b))
    check('cambio', vane >= 1, 'la veleta avisa antes (tifonVane)')
end
function CASES.aspira()
    local level, es, boss = arena()
    still(boss, 26 * T)
    boss.facing = -1
    local hold = freeze(boss)
    local pa = playerAt(level, 30.3 * T)
    attack(boss, 'inhale')
    local x0, y0 = pa.x, pa.y
    stepAll(level, es, { pa }, 1.2, function() hold(); pa.invT = 9 end)
    check('aspira', pa.x < x0 - 40 and pa.onGround, ('te arrastra hacia él por el tejado, sin levantarte (%d → %d)'):format(x0, pa.x))
    -- una bomba suelta cerca: la levanta hacia la boca
    local level2, es2, boss2 = arena()
    still(boss2, 26 * T)
    boss2.facing = -1
    local hold2 = freeze(boss2)
    local bm = find(es2, 'bombobject')
    local mx = boss2:mouthPos()
    bm.x, bm.y = mx + 2 * T, feet() - 20
    attack(boss2, 'inhale')
    local by0 = bm.y
    local rose = false
    stepAll(level2, es2, {}, 1.3, function() hold2(); if bm.y < by0 - 40 then rose = true end; return boss2.state ~= 'inhale' end)
    check('aspira', rose, 'a una bomba suelta la levanta hacia la boca')
end
function CASES.traga()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.facing = 1
    local hold = freeze(boss)
    local pa = playerAt(level, 33 * T)
    local bm = find(es, 'bombobject')
    attack(boss, 'inhale')
    stepAll(level, es, { pa }, 0.4, function() hold(); pa.invT = 9 end)
    local mx, my = boss:mouthPos()
    bm.x, bm.y, bm.onGround = mx + 2.5 * T, my + 1.2 * T, false
    bm:throw(-200, -300, true)
    bm.thrown, bm.thrownBy = true, pa
    local order = {}
    stepAll(level, es, { pa }, 5, function()
        pa.invT = 9
        if boss.state == 'inhale' then hold() end
        if order[#order] ~= boss.state then order[#order + 1] = boss.state end
        return boss.state == 'stun'
    end)
    check('traga', table.concat(order, ' '):find('inhale bomb boom fall stun', 1, true) ~= nil, table.concat(order, ' '))
    local roof = feet()
    local bottom = boss.y + 13 * 6
    check('traga', math.abs(bottom - roof) <= 8, ('cae tumbado sobre el tejado (abajo %d, tejado %d)'):format(bottom, roof))
    check('traga', boss:isVulnerable() and count('tifonGulp') == 1 and count('tifonBoom') == 1, 'vulnerable; se oye el trago y la explosión')
    stepAll(level, es, { pa }, 8, function() pa.invT = 9; return boss.state == 'idle' end)
    check('traga', boss.state == 'idle' and boss.y < feet() - 3 * T, 'se levanta y vuelve arriba')
end
function CASES.tose()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.facing = 1
    local hold = freeze(boss)
    local pa = playerAt(level, 34 * T)
    local bm = find(es, 'bombobject')
    attack(boss, 'inhale')
    stepAll(level, es, { pa }, 0.4, function() hold(); pa.invT = 9 end)
    local mx, my = boss:mouthPos()
    bm.state, bm.thrown, bm.thrownBy = 'rest', false, nil
    bm.x, bm.y, bm.vx, bm.vy, bm.onGround = mx + 0.3 * T, my, 0, 0, false
    stepAll(level, es, { pa }, 0.3, function() hold(); pa.invT = 9; return boss.state == 'cough' end)
    check('tose', boss.state == 'cough' and count('tifonCough') == 1, 'una bomba apagada: la tose')
    check('tose', bm.alive and bm.state ~= 'eaten' and (bm.vx or 0) > 200, ('sale disparada hacia ti (vx %d)'):format(bm.vx or 0))
    stepAll(level, es, { pa }, 1.0, function() pa.invT = 9 end)
    check('tose', boss.state ~= 'stun' and boss.state ~= 'bomb', 'y no se aturde')
end
function CASES.escupe()
    local level, es, boss = arena()
    still(boss, 26 * T)
    boss.facing = -1
    local hold = freeze(boss)
    local pa = playerAt(level, 30 * T)
    attack(boss, 'inhale')
    stepAll(level, es, { pa }, 0.4, function() hold(); pa.invT = 9 end)
    local mx, my = boss:mouthPos()
    pa.x, pa.y, pa.invT = mx, my, 0
    local hp = pa.hp
    stepAll(level, es, { pa }, 0.1, function() hold() end)
    check('escupe', pa.hp == hp - 1 and boss.state == 'cough', ('−1 y te escupe (%d → %d, %s)'):format(hp, pa.hp, boss.state))
end
function CASES.rayo()
    local level, es, boss = arena()
    still(boss, 22 * T)
    local hold = freeze(boss)
    local pa = playerAt(level, 33 * T)
    boss:placeMarks(level)
    local overGap = false
    for _, m in ipairs(boss.marks) do if m.x > 27 * T and m.x < 29 * T then overGap = true end end
    check('rayo', #boss.marks >= 2 and not overGap, ('%d marcas en el tejado, ninguna sobre el hueco'):format(#boss.marks))
    local near = false
    for _, m in ipairs(boss.marks) do if math.abs(m.x - pa.x) < 10 then near = true end end
    check('rayo', near, 'una marca donde estás')
    boss:enter('charge')
    local hp = pa.hp
    stepAll(level, es, { pa }, 1.4, function() hold() end)
    check('rayo', pa.hp == hp - 1, ('quedarte en la marca: −1 (%d → %d)'):format(hp, pa.hp))
    -- apartado no da
    local level2, es2, boss2 = arena()
    still(boss2, 22 * T)
    local hold2 = freeze(boss2)
    local pb = playerAt(level2, 33 * T)
    boss2:placeMarks(level2)
    boss2:enter('charge')
    local moved = false
    hp = pb.hp
    stepAll(level2, es2, { pb }, 1.4, function() hold2(); if not moved then moved = true; pb.x = pb.x - 1.6 * T end end)
    local hit = false
    for _, m in ipairs(boss2.marks) do if math.abs(m.x - pb.x) < 0.6 * T then hit = true end end
    check('rayo', hit or pb.hp == hp, ('apartado de la marca: nada (%d → %d)'):format(hp, pb.hp))
end
function CASES.arco()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.phase = 2
    local hold = freeze(boss)
    boss.marks = { { x = 22.3 * T, y = feet() }, { x = 24 * T, y = feet() } }      -- (entre la caja y la chimenea)
    boss.arcs = { { 1, 2 } }
    local pa = playerAt(level, 23.2 * T)
    boss:enter('strike')
    local hp = pa.hp
    stepAll(level, es, { pa }, 0.05, function() hold() end)
    check('arco', pa.hp == hp - 1, ('entre las marcas, a ras del tejado: −1 (%d → %d)'):format(hp, pa.hp))
    local pb = playerAt(level, 23.2 * T)
    pb.y, pb.vy, pb.onGround = feet() - 48 - 70, 0, false        -- (los pies 70 px por encima: el arco mide 45)
    boss:enter('strike')
    hp = pb.hp
    stepAll(level, es, { pb }, 0.02, function() hold() end)
    check('arco', pb.hp == hp, ('saltándolo no da (%d → %d)'):format(hp, pb.hp))
    -- en fase 2 los arcos salen solos entre marcas del mismo tejado
    local n = 0
    for _ = 1, 20 do boss:placeMarks(level); n = n + #boss.arcs end
    check('arco', n > 0, ('fase 2: arcos entre marcas (%d en 20 tandas)'):format(n))
end
function CASES.granizo()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.phase = 2
    local hold = freeze(boss)
    local pa = playerAt(level, 30.3 * T)
    boss.hail = { { id = 1, x = math.floor(pa.x), y = feet() - 5 * T, t = 0, broke = false } }
    local hp = pa.hp
    stepAll(level, es, { pa }, 0.8, function() hold() end)
    check('granizo', pa.hp == hp - 1, ('al descubierto te da (%d → %d)'):format(hp, pa.hp))
    -- bajo la cornisa de las columnas 17-19 (fila 10)
    local pb = playerAt(level, 18 * T)
    boss.hail = { { id = 2, x = math.floor(pb.x), y = 3 * T, t = 0, broke = false } }
    hp = pb.hp
    stepAll(level, es, { pb }, 1.0, function() hold() end)
    check('granizo', pb.hp == hp and boss.hail[1] == nil or (boss.hail[1] and boss.hail[1].broke), ('la cornisa te tapa (%d → %d)'):format(hp, pb.hp))
    -- el ataque: cae granizo varias veces
    boss:enter('hail')
    local most = 0
    stepAll(level, es, {}, 3.1, function() hold(); most = math.max(most, #boss.hail) end)
    check('granizo', most >= 3 and boss.state == 'idle', ('granizada: hasta %d piedras a la vez, y acaba'):format(most))
end
function CASES.pisar()
    local level, es, boss = arena()
    still(boss, 22 * T)
    find(es, 'box', 1).alive = false                       -- (la caja de la columna 22 está justo debajo)
    local pa = playerAt(level, 33 * T)
    -- volando: caerle encima rebota
    local ob = pa:getOuterBounds()
    pa.x, pa.y, pa.vy = boss.x, boss.y - 10 * 6 - ob.h / 2, 300
    check('pisar', boss:interact(pa) == 'bounce', 'volando, caerle encima solo rebota')
    -- aturdido, en el tejado
    boss.x, boss.y = 22 * T, feet() - 13 * 6 + 6
    boss:enter('stun')
    local hp0 = boss.hp
    pa.x, pa.y, pa.vy, pa.onGround, pa.gpPhase = boss.x, boss.y - 3 * 6 - ob.h / 2 + 4, 300, false, nil
    stepAll(level, es, { pa }, 0.15, function() return boss.hp < hp0 end)
    check('pisar', boss.hp == hp0 - 1, ('pisotón: −1 (%d → %d)'):format(hp0, boss.hp))
    local h1 = boss.hp
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, boss.y - 3 * 6 - ob.h / 2 + 4, 300, false
    stepAll(level, es, { pa }, 0.15)
    check('pisar', boss.hp == h1, 'un solo golpe por noqueo')
    boss:enter('stun'); boss.inv, boss.ghost = 0, false
    hp0 = boss.hp
    pa = playerAt(level, 33 * T)
    pa.x, pa.y, pa.vy, pa.onGround, pa.gpPhase = boss.x, boss.y - 3 * 6 - ob.h / 2 + 4, 900, false, 'fall'
    stepAll(level, es, { pa }, 0.15, function() return boss.hp < hp0 end)
    check('pisar', boss.hp == hp0 - 2, ('ground pound: −2 (%d → %d)'):format(hp0, boss.hp))
end
function CASES.atravesable()
    local level, es, boss = arena()
    still(boss, 35.5 * T)
    boss.x, boss.y = 35.5 * T, feet() - 13 * 6 + 6
    boss:enter('stun')
    find(es, 'box', 2).alive = false                       -- (sin la caja de en medio)
    check('atravesable', not boss:isSolidBody(), 'no es sólido')
    local pa = playerAt(level, 36.7 * T)
    local h = pa.hp
    stepAll(level, es, { pa }, 1.6, function() pa.invT = 0 end, function() stub.state.left = true end)
    check('atravesable', pa.x < boss.x - 2 * T and pa.hp == h, ('lo cruzas andando sin daño (x %d, vida %d → %d)'):format(pa.x, h, pa.hp))
end
function CASES.fase()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.roared = false
    boss:enter('stun'); boss.inv = 0
    boss.hp = math.floor(boss.hpMax / 2) + 1
    boss:stomp()
    check('fase', boss:ph() == 2, ('a mitad de vida, fase 2 (%d/%d)'):format(boss.hp, boss.hpMax))
    boss:enter('idle'); boss.idleT = 99
    stepAll(level, es, {}, 0.05)
    check('fase', boss.state == 'roar' and count('tifonRoar') >= 1, 'ruge al volver a vagar')
end
function CASES.derrota()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.x, boss.y = 22 * T, feet() - 13 * 6 + 6
    boss:enter('stun'); boss.inv = 0; boss.hp = 1
    boss:stomp()
    check('derrota', boss.state == 'dying_out' and not boss:shardDrop(), 'último golpe: aún con su pieza')
    local y0 = boss.y
    stepAll(level, es, {}, 2.0, function() return boss.state == 'dying_flee' end)
    check('derrota', boss:releasesZone() and boss:shardDrop(), 'libera la zona y suelta su astilla')
    stepAll(level, es, {}, 2.2, function() return boss.state == 'dead' end)
    check('derrota', boss.state == 'dead' and boss.y < y0 - 4 * T, 'se va hacia arriba y acaba')
end
function CASES.red()
    local level, es, boss = arena()
    still(boss, 22 * T)
    boss.phase = 2
    boss:placeMarks(level)
    boss.arcs = { { 1, 2 } }
    boss.hail = { { id = 7, x = 900, y = 300, t = 0.2, broke = false } }
    attack(boss, 'blow', 1)
    boss.swapped = true
    boss.deadTimer = 0.6
    local pack = boss:netPack()
    local o = Entities.create({ type = 'tifon', col = boss.col, row = boss.row, props = {} })
    o.x, o.y, o.state, o.deadTimer, o.alive = boss.x, boss.y, boss.state, boss.deadTimer, true
    o:netApply(pack, pack, 1)
    check('red', o.phase == 2 and o.windDir == 1 and o.swapped and #o.marks == #boss.marks and #o.arcs == 1
        and o.hail[1] and o.hail[1].id == 7, 'fase, viento, marcas, arcos y granizo iguales')
    local pa = playerAt(level, 30.3 * T)
    local ax = boss:pushAt(pa.x, pa.y, pa)
    o.levelRef = level
    local bx = o:pushAt(pa.x, pa.y, pa)
    check('red', ax ~= nil and ax == bx, ('su aire empuja igual en el cliente (%s / %s)'):format(tostring(ax), tostring(bx)))
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
