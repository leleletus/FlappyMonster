-- tools/tests/carnqueen_rules — reglas de la REINA CARNÍVORA (types/bosses/carnqueen.lua) caso a caso, en una copia fija de su arena:
--   boca          se abre el agujero (aviso), sale hacia ti y te traga; machacando sales y la boca vuelve
--   esquiva       apartado en el último tramo del aviso, se cierra en el vacío
--   muerde        tragado sin machacar pierde vida poco a poco
--   superficies   lejos de todo sale del suelo; pegado a una pared puede salir de ella; bajo el techo, del techo
--   fases         a 2/3 y 1/3 de vida cambia de fase, con más bocas a la vez
--   semilla       escupe una semilla que brota en una planta carnívora, sin pasar del límite
--   bomba         una bomba lanzada: se la traga, le explota dentro y queda aturdida; las bocas se retiran y sueltan
--   flor          aturdida: pisar la FLOR -1, ground pound -2; un solo golpe por noqueo; el cuerpo no cuenta
--   atravesable   su cuerpo no es sólido ni hace daño; pisarla fuera de la ventana no hace nada
--   derrota       el último golpe: sus plantas revientan, se hunde, libera la zona
--   red           netPackExtra → otro (cliente): fase, bocas y semillas iguales
--
--   tools/tests/run.sh carnqueen_rules   (CASE=nombre)
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
local FLOOR = 14
local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function arena()
    local f = assert(io.open('tools/tests/carnqueen_rules/arena.json', 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.difficulty = 'normal'
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'carnqueen' then boss = e end end
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
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
-- Quieta y sin hacer nada por su cuenta
local function still(boss)
    boss.mouthT, boss.spitT, boss.inv = 99, 99, 0
    boss.mouths, boss.seeds = {}, {}
    boss:enter('idle')
end
local function count(name) local n = 0; for _, s in ipairs(played) do if s == name then n = n + 1 end end; return n end
local function bomb(es, boss, pa)
    for _, e in ipairs(es) do
        if e.def.name == 'bombobject' and e.alive then
            e.state, e.deadTimer = 'idle', 0
            e.x, e.y, e.thrown, e.thrownBy, e.onGround, e.vx, e.vy = boss.x, boss:feetY() - 60, true, pa, false, 0, -5
            return e
        end
    end
end
local function stun(level, es, boss, pa)
    still(boss)
    bomb(es, boss, pa)
    pa.invT = 9
    stepAll(level, es, { pa }, 4, function() pa.invT = 9; return boss.state == 'stun' end)
    pa.invT = 0
end
local CASES = {}
function CASES.boca()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss:spawnMouth(level, pa)
    local m = boss.mouths[1]
    check('boca', m and m.state == 'warn' and count('plantRustle') == 1, 'avisa: se abre el agujero')
    local order, caught = {}, false
    stepAll(level, es, { pa }, 3, function()
        if order[#order] ~= m.state then order[#order + 1] = m.state end
        return m.state == 'hold'
    end)
    check('boca', table.concat(order, ' ') == 'warn out bite hold', table.concat(order, ' '))
    check('boca', pa.gulped and pa.gulpBy == m and (pa.gulpKind or 0) == 0, 'te traga, como la planta')
    stepAll(level, es, { pa }, 2, function() return not pa.gulped end, function() stub.state.jump_pressed = true end)
    check('boca', not pa.gulped, 'machacando sales')
    stepAll(level, es, { pa }, 0.8, function() pa.invT = 1 end)
    check('boca', #boss.mouths == 0, 'la boca vuelve y se va')
end
function CASES.esquiva()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss:spawnMouth(level, pa)
    local m = boss.mouths[1]
    stepAll(level, es, { pa }, 3, function()
        if m.state == 'warn' and m.t > m.warnT - 0.15 then pa.x = 34 * T end
        return m.state == 'shut' or m.state == 'hold'
    end)
    check('esquiva', m.state == 'shut' and not pa.gulped, 'apartado en el último tramo no te pilla: ' .. m.state)
end
function CASES.muerde()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss:spawnMouth(level, pa)
    local m = boss.mouths[1]
    stepAll(level, es, { pa }, 3, function() return m.state == 'hold' end)
    local hp = pa.hp
    stepAll(level, es, { pa }, 2)
    check('muerde', pa.hp == hp - 1 and m.state == 'hold', ('pierde vida (%d → %d)'):format(hp, pa.hp))
end
function CASES.superficies()
    local level, es, boss = arena()
    still(boss)
    local zx0, _, zy0 = boss:zoneBounds()
    local pa = playerAt(level, 26 * T)
    local seen = {}
    local function roll(p, n)
        local out = {}
        for _ = 1, n do
            boss.mouths = {}
            boss:spawnMouth(level, p)
            local m = boss.mouths[1]
            out[(m.ny < 0 and 'suelo') or (m.ny > 0 and 'techo') or 'pared'] = m
        end
        return out
    end
    local a = roll(pa, 30)
    check('superficies', a.suelo and not a.pared and not a.techo, 'en medio y abajo: solo del suelo')
    pa.x = zx0 + T
    a = roll(pa, 60)
    check('superficies', a.pared and a.pared.bx == math.floor(zx0), 'pegado a la pared: también de la pared')
    pa.x, pa.y = 26 * T, zy0 + 2 * T
    a = roll(pa, 60)
    check('superficies', a.techo and a.techo.by == math.floor(zy0), 'cerca del techo: también del techo')
    for _ = 1, 60 do
        boss.mouths = {}
        pa.x, pa.y = 26 * T, feet() - 60
        boss:spawnMouth(level, pa)
        local m = boss.mouths[1]
        if math.sqrt((m.tx - m.bx) ^ 2 + (m.ty - m.by) ^ 2) > 4.6 * T + 1 then check('superficies', false, 'tallo demasiado largo') end
    end
    check('superficies', true, 'ningún tallo pasa de 4,6 casillas')
end
function CASES.fases()
    local level, es, boss = arena()
    still(boss)
    boss.hp, boss.hpMax = 12, 12
    boss:enter('stun'); boss.hp = 9; boss:damage(1, 'stomp')
    check('fases', boss:ph() == 2, 'a 2/3: fase 2')
    boss.inv = 0; boss:enter('stun'); boss.hp = 5; boss:damage(1, 'stomp')
    check('fases', boss:ph() == 3, 'a 1/3: fase 3')
    still(boss); boss.mouthT = 0
    local pa = playerAt(level, 20 * T)
    local most = 0
    stepAll(level, es, { pa }, 6, function() pa.invT = 9; if boss.mouthT > 0.3 then boss.mouthT = 0.01 end; most = math.max(most, #boss.mouths) end)
    check('fases', most == 3, 'en la 3ª, tres bocas a la vez: ' .. most)
end
function CASES.semilla()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss.spitT = 0
    local active, states = 0, {}
    stepAll(level, es, { pa }, 3, function()
        pa.invT = 9; states[boss.state] = true
        local _, a = boss:activePlants(level); active = a
        return a > 0
    end)
    check('semilla', states.spit_wind and states.spit and active == 1, 'escupe y brota una planta')
    boss.spitT = 0
    stepAll(level, es, { pa }, 3, function() pa.invT = 9; if boss.spitT > 0.1 and boss.state == 'idle' then boss.spitT = 0 end end)
    local _, a = boss:activePlants(level)
    check('semilla', a == 1, 'en la fase 1, no más de una: ' .. a)
end
function CASES.bomba()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss:spawnMouth(level, pa)
    local m = boss.mouths[1]
    stepAll(level, es, { pa }, 3, function() return m.state == 'hold' end)
    local b = bomb(es, boss, pa)
    local order = {}
    stepAll(level, es, { pa }, 4, function()
        if order[#order] ~= boss.state then order[#order + 1] = boss.state end
        return boss.state == 'stun'
    end)
    check('bomba', table.concat(order, ' '):find('bomb blast stun', 1, true) ~= nil, table.concat(order, ' '))
    stepAll(level, es, { pa }, 0.1)
    check('bomba', m.state == 'back' and not pa.gulped, 'la boca se retira y suelta al tragado')
    still(boss)
    bomb(es, boss, pa).thrown = false
    stepAll(level, es, { pa }, 0.05)
    check('bomba', boss.state == 'idle', 'una bomba que no va lanzada no se la traga')
end
function CASES.flor()
    local level, es, boss = arena()
    local pa = playerAt(level, 34 * T)
    stun(level, es, boss, pa)
    local hp0 = boss.hp
    local fx, fy = boss:flowerPos()
    local ob = pa:getOuterBounds()
    pa.x, pa.y, pa.vy, pa.onGround = fx, fy - 48 - ob.h / 2, 300, false
    stepAll(level, es, { pa }, 0.2, function() return boss.hp < hp0 end)
    check('flor', boss.hp == hp0 - 1, ('pisar la flor: -1 (%d → %d)'):format(hp0, boss.hp))
    local n = 0
    boss:enter('stun'); boss.downHitState = nil; boss.inv = 0; boss:damage(1, 'stomp')
    local h1 = boss.hp
    for _ = 1, 14 do boss.inv = math.max(0, boss.inv - 0.1) end
    check('flor', boss.inv > 0 and not boss:damage(1, 'stomp') and boss.hp == h1, 'un solo golpe por noqueo: no se reabre en 1,4 s')
    stun(level, es, boss, pa)
    boss.inv = 0
    hp0 = boss.hp
    fx, fy = boss:flowerPos()
    pa.x, pa.y, pa.vy, pa.onGround, pa.gpPhase = fx, fy - 48 - ob.h / 2, 900, false, 'fall'
    stepAll(level, es, { pa }, 0.15, function() return boss.hp < hp0 end)
    check('flor', boss.hp == hp0 - 2, ('ground pound: -2 (%d → %d)'):format(hp0, boss.hp))
    stun(level, es, boss, pa)
    boss.inv = 0
    pa.x, pa.y, pa.vy, pa.onGround, pa.gpPhase = boss.x + 100, boss:feetY() - 60 - ob.h / 2, 300, false, nil
    check('flor', boss:interact(pa) == nil, 'el cuerpo no cuenta: solo la flor')
end
function CASES.atravesable()
    local level, es, boss = arena()
    still(boss)
    check('atravesable', not boss:isSolidBody(), 'no es sólida')
    local pa = playerAt(level, boss.x + boss.outerW / 2 + 40)
    local h, x0 = pa.hp, pa.x
    stepAll(level, es, { pa }, 2, nil, function() stub.state.left = true end)
    check('atravesable', pa.x < boss.x - boss.outerW / 2 and pa.hp == h, ('la cruzas andando sin daño (%d → %d)'):format(x0, pa.x))
    pa.vy = 300
    check('atravesable', boss:interact(pa) == nil, 'fuera de la ventana, pisarla no hace nada')
end
function CASES.derrota()
    local level, es, boss = arena()
    local pa = playerAt(level, 34 * T)
    still(boss); boss.spitT = 0
    stepAll(level, es, { pa }, 3, function() pa.invT = 9; local _, a = boss:activePlants(level); return a > 0 end)
    boss:enter('stun'); boss.inv = 0; boss.hp = 1
    boss:stomp()
    local _, a = boss:activePlants(level)
    check('derrota', boss.state == 'dying_out' and a == 0, 'último golpe: sus plantas revientan')
    stepAll(level, es, { pa }, 2.2, function() pa.invT = 9; return boss.state == 'dying_flee' end)
    check('derrota', boss:releasesZone() and boss:shardDrop(), 'libera la zona y suelta su pieza')
    stepAll(level, es, { pa }, 2, function() pa.invT = 9; return boss.state == 'dead' end)
    check('derrota', boss.state == 'dead', 'se hunde y acaba')
end
function CASES.red()
    local level, es, boss = arena()
    still(boss)
    local pa = playerAt(level, 20 * T)
    boss:spawnMouth(level, pa)
    boss:spitSeed(level)
    boss.phase = 2
    local pack = boss:netPack()
    local o = Entities.create({ type = 'carnqueen', col = boss.col, row = boss.row, props = {} })
    o:netApply(pack, pack, 1)
    local m, q = boss.mouths[1], o.mouths[1]
    check('red', o.phase == 2 and q and q.id == m.id and q.state == m.state and q.bx == m.bx and q.ny == m.ny and #o.seeds == 1, 'fase, bocas y semillas iguales')
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
