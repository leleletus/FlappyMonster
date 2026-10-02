-- tools/tests/megagummy_rules — reglas del REY GUMMY (types/megagummy.lua) caso a caso, en su
-- arena real (tools/levelgen/arenas/jefe_gummy.json):
--   persigue      persigue a saltitos hacia el jugador; tocarlo de lado = -1 y empujón (y no
--                 vuelve a dañar enseguida: gracia)
--   panzazo       la marca sigue al jugador y cae EN ella (≤ 24 px); aplasta (-2), salen 2 olas
--                 y queda MAREADO
--   panzazo_plataforma  con el jugador en una plataforma lateral cae encima de esa plataforma
--   ola           la ola de gelatina: a ras de suelo -1 + empujón hacia donde va; saltando por
--                 encima, nada; se para en la pared de la zona
--   inmune        persiguiendo: caerle encima solo rebota (sin daño); mareado: pisotón -1
--                 (y se recupera: un golpe por ocasión), ground pound -2
--   guardia       al pasar a la fase 2: fanfarria y entran Gummies por los LADOS de la arena,
--                 dentro de la zona, de 3 clases (normal / casco / volador entre los de la
--                 reserva); nunca más de `guardMax` a la vez
--   division      el golpe que lo deja en la vida de los trozos lo DIVIDE (no se pierde vida de
--                 más): la corona sale volando, 3 trozos de 2 de vida; pisotón -1 a un trozo,
--                 GP -2; la barra de vida = suma de los trozos; muerto el último, revienta
--                 ('dying_pop'), libera la zona, los guardias desaparecen y acaba 'dead'
--   trozos_dañan  un trozo te toca de lado: -1
--   red           netPackExtra → otro Rey Gummy (cliente): fase, marca, olas y trozos iguales
--
--   tools/tests/run.sh megagummy_rules   (CASE=nombre)
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
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-18s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_gummy.json'
local function arena()
    local f = assert(io.open(ARENA, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'megagummy' then boss = e end end
    level.players = {}
    boss:startFight(1)
    return level, es, boss
end

local FLOOR = 13
local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, (row or FLOOR - 1) * T - 60)
    for k in pairs(stub.state) do stub.state[k] = false end
    for _ = 1, 30 do pa:update(DT, level) end
    return pa
end

local function stepAll(level, es, players, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.players = players
        level.solidBodies = Entities.solidBodies(es)
        for k in pairs(stub.state) do stub.state[k] = false end
        for _, pa in ipairs(players) do pa:update(DT, level) end
        for _, e in ipairs(es) do if e.alive or e.summonOf then e:update(DT, level) end end
        if each and each() then return true end
    end
end

-- Coloca al jefe de pie en la columna `col`
local function putBoss(boss, col)
    boss.x = (col - 0.5) * T
    boss.y = (FLOOR - 1) * T - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
end

local cases = {}

function cases.persigue()
    local level, es, boss = arena()
    putBoss(boss, 26)
    local pa = playerAt(level, 15)
    pa.x = 15.5 * T
    local x0 = boss.x
    boss.flopT = -99                                    -- (que no haga el panzazo)
    local hopped = false
    stepAll(level, es, { pa }, 1.2, function()
        pa.x, pa.vx = 15.5 * T, 0
        if not boss.onGround then hopped = true end
    end)
    local moved = x0 - boss.x
    -- contacto de lado
    local pb = playerAt(level, 1)
    pb.x, pb.y = boss.x + boss.outerW / 2 + pb.w / 2 - 6, boss.y + boss.outerH / 2 - pb:getOuterBounds().h / 2
    pb.onGround, pb.invT = true, 0
    boss.graceT = 0
    local hp0 = pb.hp
    boss.state = 'dazed'; boss:enter('recover')         -- (quieto)
    level.players = { pb }
    local hit1 = boss:touch(level, boss:getOuterBounds(), boss.x)
    local hp1 = pb.hp
    check('persigue', hopped and moved > T and hit1 and hp1 == hp0 - 1 and pb.vx > 300,
        ('se acerca %.1f casillas a saltos=%s; contacto: vida %d→%d, empujón vx %d'):format(
            moved / T, tostring(hopped), hp0, hp1, pb.vx))
end

-- Panzazo completo hacia un jugador quieto en (col, row); devuelve el jugador y el jefe tras caer
local function flopOn(col, row)
    local level, es, boss = arena()
    putBoss(boss, (col < 23) and 29 or 16)
    local pa = playerAt(level, col, row)
    boss:startFlop(level)
    local landed, mx, my
    stepAll(level, es, { pa }, 4, function()
        if boss.state == 'flop_air' and not mx then mx, my = boss.landX, boss.landY end
        if boss.state == 'dazed' or boss.state == 'flop_land' then landed = true; return true end
    end)
    return level, es, boss, pa, landed, mx, my
end

function cases.panzazo()
    local level, es, boss, pa, landed, mx, my = flopOn(20)
    local px = 19.5 * T
    local nWaves = #boss.waves
    check('panzazo', landed and math.abs(boss.x - mx) <= 24 and math.abs(mx - px) <= 24
                     and math.abs(boss:feetY() - my) <= 4 and pa.hp == pa.hpMax - 2 and (pa.squashT or 0) > 0
                     and nWaves == 2 and boss.state == 'dazed',
        ('marca x %.1f (jugador %.1f) cae en %.1f, pies %d/%d; vida %d/%d aplastado=%s; olas %d; estado %s'):format(
            (mx or 0) / T, px / T, boss.x / T, math.floor(boss:feetY()), my or -1, pa.hp, pa.hpMax,
            tostring((pa.squashT or 0) > 0), nWaves, boss.state))
end

function cases.panzazo_plataforma()
    -- plataforma lateral derecha: columnas 30-33, fila 10 (su borde de arriba = 9 * T)
    local level, es, boss, pa, landed, mx, my = flopOn(31, 9)
    check('panzazo_plataforma', landed and my == 9 * T and math.abs(boss:feetY() - 9 * T) <= 4,
        ('marca en y %d (plataforma %d), pies %d, estado %s'):format(my or -1, 9 * T, math.floor(boss:feetY()), boss.state))
end

function cases.ola()
    local level, es, boss = arena()
    putBoss(boss, 22)
    boss:enter('recover')
    local ground = playerAt(level, 27)
    local jumper = playerAt(level, 17)
    local wall = 0
    boss:spawnWaves(level)
    local jy = (FLOOR - 1) * T - 2.2 * T                   -- saltando: 2.2 casillas sobre el suelo
    local maxX = 0
    for _ = 1, math.floor(2 * 60) do
        level.players = { ground, jumper }
        jumper.y, jumper.vy = jy, 0
        boss:updateWaves(level, DT)
        for _, w in ipairs(boss.waves) do maxX = math.max(maxX, w.x) end
    end
    local zx1 = select(2, boss:zoneBounds())
    check('ola', ground.hp == ground.hpMax - 1 and ground.vx > 300 and jumper.hp == jumper.hpMax
                 and #boss.waves == 0 and maxX <= zx1,
        ('en el suelo: vida %d vx %d; saltando: vida %d; olas al final %d (x máx %.1f, pared %.1f)'):format(
            ground.hp, ground.vx, jumper.hp, #boss.waves, maxX / T, zx1 / T))
end

-- Jugador cayendo sobre el jefe (o un trozo con caja ob); gp = ground pound
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

function cases.inmune()
    local level, es, boss = arena()
    putBoss(boss, 22)
    boss:enter('chase')
    local gob = boss:getOuterBounds()
    local r1, a1, b1 = boss:interact(dropOn(level, boss.x, gob.y, false))
    local r2 = boss:interact(dropOn(level, boss.x, gob.y, true))
    boss:enter('dazed')
    local hp0 = boss.hp
    local r3 = boss:interact(dropOn(level, boss.x, gob.y, false))
    boss:stomp()
    local hp1, st1 = boss.hp, boss.state
    boss.inv = 0
    boss:enter('dazed')
    local r4 = boss:interact(dropOn(level, boss.x, gob.y, true))
    boss:pound()
    check('inmune', r1 == 'bounce' and r2 == 'bounce' and r3 == 'stomp' and hp1 == hp0 - 1 and st1 == 'recover'
                    and r4 == 'pound' and boss.hp == hp1 - 2,
        ('persiguiendo: %s / GP %s; mareado: %s vida %d→%d (%s), GP %s → %d'):format(
            tostring(r1), tostring(r2), tostring(r3), hp0, hp1, st1, tostring(r4), boss.hp))
end

function cases.guardia()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 15)
    local zx0, zx1, zy0, zy1 = boss:zoneBounds()
    boss.hp = math.floor(boss:phase2Hp()) + 1
    boss:enter('dazed')
    boss:stomp()
    local st = boss.state
    local seen, kinds, inside, maxAlive = {}, {}, true, 0
    local pool = #boss:minions(level)
    stepAll(level, es, { pa }, 40, function()
        pa.x, pa.y, pa.vx, pa.invT = 15.5 * T, pa.y, 0, 5          -- (invulnerable: no muere)
        boss.flopT = 0                                             -- (solo persigue y llama)
        local alive = 0
        for _, e in ipairs(boss:minions(level)) do
            if e.alive then
                alive = alive + 1
                if not seen[e] then
                    seen[e] = { x = e.x }
                    local k = e.flying and 'vuela' or (e.helmet and 'casco' or 'normal')
                    kinds[k] = true
                end
                if e.x < zx0 - 4 or e.x > zx1 + 4 or e.y < zy0 - 4 or e.y > zy1 + 4 then inside = false end
            end
        end
        maxAlive = math.max(maxAlive, alive)
    end)
    local n, sides = 0, true
    for _, s in pairs(seen) do
        n = n + 1
        if math.min(s.x - zx0, zx1 - s.x) > 1.5 * T then sides = false end
    end
    local nk = 0
    for _ in pairs(kinds) do nk = nk + 1 end
    check('guardia', st == 'phase_up' and boss.phase == 2 and pool == 6 and n >= 3 and sides and inside
                     and maxAlive <= (boss.props.guardMax or 3) and nk >= 2,
        ('tras el golpe: %s, fase %d; reserva %d; llamados %d (por los lados=%s, dentro=%s), clases %d, a la vez máx %d'):format(
            st, boss.phase, pool, n, tostring(sides), tostring(inside), nk, maxAlive))
end

function cases.division()
    local level, es, boss = arena()
    putBoss(boss, 22)
    local pa = playerAt(level, 14)
    local split = boss:splitHp()
    -- llama a la guardia antes (deben irse con él)
    boss:summonGuards(level)
    local guards = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive then guards = guards + 1 end end
    boss.hp = split + 1
    boss:enter('dazed')
    boss:pound()                                         -- (2 de daño: solo quita 1, el resto es de los trozos)
    local hpAfter, st = boss.hp, boss.state
    local crownFlew = false
    stepAll(level, es, { pa }, 1.2, function()
        pa.invT = 5
        if boss.state == 'split' and boss:crownPos() then crownFlew = true end
    end)
    local nParts, partHp = #boss.parts, boss.parts[1] and boss.parts[1].hp
    local hpSum = boss.hp
    -- dejar que caigan
    stepAll(level, es, { pa }, 1.0, function() pa.invT = 5 end)
    -- pisotón a un trozo (1) y GP a los demás (2)
    local p1 = boss.parts[1]
    local ob = p1:box()
    local r = boss:interact(dropOn(level, p1.x, ob.y, false))
    boss:stomp()
    local after1, hpBar1 = p1.hp, boss.hp
    p1.inv = 0
    for i, p in ipairs(boss.parts) do
        if p.st ~= 0 then
            p.inv = 0
            local rr = boss:interact(dropOn(level, p.x, p:box().y, true))
            if rr == 'pound' then boss:pound() end
        end
    end
    local dying = boss.state
    local releases = boss:releasesZone()
    local guardsLeft = 0
    for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'dead' then guardsLeft = guardsLeft + 1 end end
    stepAll(level, es, { pa }, 3, function() pa.invT = 5 end)
    check('division', hpAfter == split and st == 'split' and crownFlew and nParts == 3 and partHp == 2 and hpSum == 6
                      and r == 'stomp' and after1 == 1 and hpBar1 == 5 and dying == 'dying_pop' and releases
                      and guards > 0 and guardsLeft == 0 and boss.state == 'dead' and not boss.alive,
        ('GP con %d de vida → %d (%s), corona vuela=%s; trozos %d de %s (barra %d); pisotón %s → trozo %d, barra %d; '
         .. 'todos muertos: %s libera=%s; guardias %d→%d; al final %s'):format(
            split + 1, hpAfter, st, tostring(crownFlew), nParts, tostring(partHp), hpSum, tostring(r), after1, hpBar1,
            dying, tostring(releases), guards, guardsLeft, boss.state))
end

function cases.trozos_dañan()
    local level, es, boss = arena()
    putBoss(boss, 22)
    boss.hp = boss:splitHp() + 1
    boss:enter('dazed')
    boss:stomp()
    local pa = playerAt(level, 14)
    stepAll(level, es, { pa }, 1.3, function() pa.invT = 5 end)
    local p = boss.parts[2]
    local pb = playerAt(level, 1)
    pb.x, pb.y = p.x + p.outerW / 2 + pb.w / 2 - 6, p.y + p.outerH / 2 - pb:getOuterBounds().h / 2
    pb.invT = 0
    local hp0 = pb.hp
    level.players = { pb }
    boss:touch(level, p:box(), p.x)
    check('trozos_dañan', pb.hp == hp0 - 1, ('vida %d→%d'):format(hp0, pb.hp))
end

function cases.red()
    local level, es, boss = arena()
    putBoss(boss, 22)
    boss:spawnWaves(level)
    boss.landX, boss.landY = 999, 777
    local a = boss:netPackExtra()
    boss.hp = boss:splitHp() + 1
    boss:enter('dazed'); boss:stomp()
    local pa = playerAt(level, 14)
    stepAll(level, es, { pa }, 1.3, function() pa.invT = 5 end)
    boss.parts[1].inv = 0.5
    local b = boss:netPackExtra()
    -- cliente: otro Rey Gummy del mismo nivel
    local level2 = Level.fromData(level.data or json.decode(io.open(ARENA):read('*a')))
    local c
    for _, pl in ipairs(level2.entities) do
        if pl.type == 'megagummy' then c = Entities.create(pl) end
    end
    c:netApplyExtra(a, a, 1)
    local w1 = #c.waves == 2 and c.landX == 999 and c.landY == 777
    c:netApplyExtra(b, b, 1)
    local ok = w1 and c.phase == boss.phase and #c.parts == #boss.parts
    for i, p in ipairs(boss.parts) do
        local q = c.parts[i]
        if not q or math.abs(q.x - p.x) > 1 or math.abs(q.y - p.y) > 1 or q.hp ~= p.hp or q.st ~= p.st
           or math.abs(q.inv - p.inv) > 0.02 then ok = false end
    end
    -- el cliente predice el pisotón sobre un trozo igual que el servidor
    local q = c.parts[2]
    local rs = boss:interact(dropOn(level, boss.parts[2].x, boss.parts[2]:box().y, false))
    c.state = boss.state
    local rc = c:interact(dropOn(level, q.x, q:box().y, false))
    check('red', ok and rs == rc and rs == 'stomp',
        ('olas y marca=%s; fase %d/%d; trozos %d/%d; pisotón servidor %s / cliente %s'):format(
            tostring(w1), c.phase or -1, boss.phase, #c.parts, #boss.parts, tostring(rs), tostring(rc)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'persigue', 'panzazo', 'panzazo_plataforma', 'ola', 'inmune', 'guardia', 'division',
                         'trozos_dañan', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
