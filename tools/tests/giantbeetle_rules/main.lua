-- tools/tests/giantbeetle_rules — reglas del ESCARABAJO RINOCERONTE GIGANTE (types/bosses/giantbeetle.lua) caso a caso,
-- en su arena real (tools/levelgen/arenas/jefe_escarabajo.json, el templo de la balanza):
--   arena      la balanza nivelada deja los platillos colgados 3 casillas SOBRE EL SUELO (sin fosos; 0.5.79)
--   acorazado  de pie no se le hace daño: caerle encima (pisotón o ground pound) rebota
--   vuelco     él en un platillo y un ground pound en el OTRO: sale disparado, se estrella contra el techo y cae
--              PATAS ARRIBA (vulnerable); pasado el tiempo se da la vuelta
--   golpe      patas arriba: pisotón -1, ground pound -2 (con su invulnerabilidad entre golpes)
--   doble_filo él cae de su salto en un platillo con el jugador en el otro: el jugador sale disparado contra el techo
--              y pierde 1
--   cebo       el jugador en un platillo: salta (casi siempre) al OTRO platillo
--   embestida  embiste, choca con la pared (aturdido, sin daño) y caen cascotes con sombra de aviso; el de encima
--              del jugador le quita 1; tocarlo embistiendo quita 1
--   lanzar     arranca un bloque y se lo lanza en arco al jugador: le quita 1 y se rompe
--   ondas      al caer de su salto suelta dos ondas por el suelo, una a cada lado
--   enfado     a mitad de vida se enfada y suelta escarabajos VOLADORES (Normal 2 a la vez, Fácil 1), ninguno antes
--   voladores  sus súbditos vuelan por la mitad de arriba de la zona sin embestir; pisados caen patas arriba y, al
--              levantarse, vuelven a volar
--   madera     el trozo arrancado de una plataforma traspasable o de un platillo es de MADERA (no piedra) y suena a
--              lo que es al romperse (breakSound de su material)
--   derrota    el último golpe: patas arriba, se da la vuelta y se va volando atravesando el techo (libera la zona,
--              suelta el fragmento); sus escarabajos revientan
--   red        netPackExtra → otro (cliente): enfado, diana, bloques, cascotes y ondas iguales; interact igual
--
--   tools/tests/run.sh giantbeetle_rules   (CASE=nombre)
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
local Interactions = require 'src/world/entities/base/Interactions'
local BossZones = require 'src/world/systems/BossZones'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 13

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local ARENA = 'tools/levelgen/arenas/jefe_escarabajo.json'
local function arena(diff)
    local f = assert(io.open(ARENA, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.difficulty = diff
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss, scale
    for _, e in ipairs(es) do
        if e.def.name == 'giantbeetle' then boss = e end
        if e.def.name == 'scale' then scale = e end
    end
    level.players = {}
    boss:startFight(1)
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }
    boss.levelRef = level
    scale.levelRef = level
    return level, es, boss, scale
end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end

-- Un paso como el del juego: cuerpos, jugadores, entidades, interacciones (ground pound incluido)
local function stepAll(level, es, players, secs, each, input)
    for _ = 1, math.max(1, math.floor(secs * 60)) do
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

local function playerAt(level, es, x, feetY)
    local pa = PlayerAdventure:new(x, feetY - 60)
    clear()
    level.players = { pa }
    for _ = 1, 30 do stepAll(level, es, { pa }, DT) end
    pa.invT = 0
    return pa
end

local function panTop(pan) local b = pan:getOuterBounds(); return b.x + b.w / 2, b.y end

-- El jefe de pie en el sitio x (sobre lo que haya debajo), quieto
local function putBoss(level, boss, x, feetY)
    boss.x = x
    boss.y = (feetY or (FLOOR - 1) * T) - boss.outerH / 2
    boss.vx, boss.vy, boss.onGround = 0, 0, true
    boss.waves, boss.blocks, boss.rocks, boss.shot = {}, {}, {}, {}
    boss.graceT, boss.inv = 0, 0
    boss:rest(99)
end

local function dropOn(level, es, cx, topY, gp)
    local pa = playerAt(level, es, 4 * T, (FLOOR - 1) * T)
    local ob = pa:getOuterBounds()
    pa.x, pa.y, pa.vy, pa.onGround = cx, topY + 6 - ob.h / 2, 400, false
    if gp then pa.gpPhase = 'fall' end
    return pa
end

-- Ground pound del jugador desde encima de un platillo (sube, cae y pulsa abajo)
local function poundPan(level, es, pa, pan, secs, each)
    local cx, top = panTop(pan)
    pa.x, pa.y, pa.vy, pa.standBody, pa.onGround = cx, top - 4 * T, 0, nil, false
    stepAll(level, es, { pa }, 0.25)
    local n = 0
    return stepAll(level, es, { pa }, secs or 3, each, function() n = n + 1; if n < 30 then stub.state.crouch_pressed = true end end)
end

local cases = {}

function cases.arena()
    local level, es, boss, scale = arena()
    stepAll(level, es, {}, 0.5)
    local p1, p2 = scale:bodyParts()[1], scale:bodyParts()[2]
    local _, y1 = panTop(p1)
    local _, y2 = panTop(p2)
    local floorY = (FLOOR - 1) * T
    local c1 = panTop(p1)
    local solid = level:collisionAt(c1, floorY + 8) ~= nil
    check('arena', math.abs(y1 - (floorY - 3 * T)) <= 2 and math.abs(y2 - (floorY - 3 * T)) <= 2 and solid,
        ('platillos: arriba en %d y %d (quiere %d), suelo en %d · suelo macizo debajo=%s'):format(y1, y2, floorY - 3 * T,
            floorY, tostring(solid)))
end

function cases.acorazado()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    local hp0 = boss.hp
    local gob = boss:getOuterBounds()
    local r1 = boss:interact(dropOn(level, es, boss.x, gob.y, false))
    local r2 = boss:interact(dropOn(level, es, boss.x, gob.y, true))
    check('acorazado', r1 == 'bounce' and r2 == 'bounce' and boss.hp == hp0,
        ('de pie: pisotón → %s, ground pound → %s · vida %d → %d'):format(tostring(r1), tostring(r2), hp0, boss.hp))
end

function cases.vuelco()
    local level, es, boss, scale = arena()
    stepAll(level, es, {}, 0.3)
    local p1, p2 = scale:bodyParts()[1], scale:bodyParts()[2]
    local cx, top = panTop(p1)
    putBoss(level, boss, cx, top)
    local pa = playerAt(level, es, 33 * T, (FLOOR - 1) * T)
    local seen, minTop, flippedAt = {}, 1e9, nil
    local _, _, zy0 = boss:zoneBounds()
    poundPan(level, es, pa, p2, 3, function()
        seen[boss.state] = true
        minTop = math.min(minTop, boss.y - boss.outerH / 2)
        if boss.state == 'flipped' and not flippedAt then flippedAt = true end
        boss.restLen = 99
    end)
    local vuln = boss:isVulnerable()
    -- pasado el tiempo, se da la vuelta
    stepAll(level, es, { pa }, 5, nil, nil)
    local back = boss.state == 'rest' or boss.state == 'righting' or not boss:isVulnerable()
    check('vuelco', seen.launched and seen.tumble and flippedAt and minTop <= zy0 + 4 and vuln and back,
        ('disparado=%s · llega al techo (%d / techo %d) · cae patas arriba=%s vulnerable=%s · luego se da la vuelta=%s'):format(
            tostring(seen.launched), math.floor(minTop), math.floor(zy0), tostring(flippedAt), tostring(vuln), tostring(back)))
end

-- De verdad (jugador cayendo, con el paso del juego): caer en el caparazón REBOTA sin daño (el usuario, 0.5.79: dolía)
function cases.caparazon()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    local gob = boss:getOuterBounds()
    local pa = playerAt(level, es, 18 * T, (FLOOR - 1) * T)
    local hp0 = pa.hp
    pa.x, pa.y, pa.vy, pa.onGround = boss.x, gob.y - 3 * T, 0, false
    local up = false
    stepAll(level, es, { pa }, 0.9, function()
        boss.restLen = 99
        if pa.vy < -200 and pa.y < gob.y then up = true end
    end)
    check('caparazon', up and pa.hp == hp0 and boss.hp == boss.hpMax,
        ('cae en el caparazón: rebota=%s · vida %d → %d · el jefe %d/%d'):format(tostring(up), hp0, pa.hp, boss.hp, boss.hpMax))
end

-- Los cascotes marcan dónde caen de verdad: sobre un platillo, en el platillo (no en el fondo del foso) y se paran ahí
function cases.cascotes()
    local level, es, boss, scale = arena()
    stepAll(level, es, {}, 0.3)
    putBoss(level, boss, 24 * T)
    local pan = scale:bodyParts()[1]:getOuterBounds()
    local cx = pan.x + pan.w / 2
    local onPan = boss:floorBelow(level, cx, 3 * T)
    local onFloor = boss:floorBelow(level, 20.5 * T, 3 * T)
    local onLedge = boss:floorBelow(level, 13 * T, 3 * T)
    boss.rocks = { { id = 1, x = cx, y = 3 * T, vy = 0, t = 0, floor = onPan, hit = {} } }
    local stopY
    stepAll(level, es, {}, 1.5, function()
        boss.restLen = 99
        if not stopY and #boss.rocks == 0 then stopY = true end
    end)
    check('cascotes', math.abs(onPan - pan.y) <= 1 and onFloor == (FLOOR - 1) * T and onLedge == 9 * T and stopY,
        ('sombra en el platillo %d (su tabla %d) · en el suelo %d · en la plataforma %d · se rompe al llegar=%s'):format(
            onPan, math.floor(pan.y), onFloor, onLedge, tostring(stopY)))
end

function cases.golpe()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    boss:enter('flipped')
    local hp0 = boss.hp
    local gob = boss:getOuterBounds()
    local pa = dropOn(level, es, boss.x, gob.y, false)
    local r = boss:interact(pa)
    boss:stomp()
    local h1 = boss.hp
    boss.inv = 0
    boss:enter('flipped')
    boss:pound(pa)
    local h2 = boss.hp
    check('golpe', r == 'stomp' and h1 == hp0 - 1 and h2 == hp0 - 3,
        ('patas arriba: interact=%s · pisotón %d → %d · ground pound → %d'):format(tostring(r), hp0, h1, h2))
end

function cases.doble_filo()
    local level, es, boss, scale = arena()
    stepAll(level, es, {}, 0.3)
    local p1, p2 = scale:bodyParts()[1], scale:bodyParts()[2]
    local c2, t2 = panTop(p2)
    local pa = playerAt(level, es, c2, t2)
    local onPan = pa.standBody == p2
    local hp0 = pa.hp
    -- el jefe cae de su salto sobre el otro platillo
    local c1, t1 = panTop(p1)
    putBoss(level, boss, c1, t1 - 4 * T)
    boss.onGround, boss.vy = false, 200
    boss.markX, boss.markY = c1, t1
    boss:enter('leap')
    local maxUp = 0
    local y0 = pa.y
    stepAll(level, es, { pa }, 2, function() maxUp = math.max(maxUp, (y0 - pa.y) / T); boss.restLen = 99 end)
    check('doble_filo', onPan and maxUp > 3 and pa.hp == hp0 - 1,
        ('jugador en el otro platillo=%s · sale disparado %.1f casillas · vida %d → %d (contra el techo)'):format(
            tostring(onPan), maxUp, hp0, pa.hp))
end

function cases.cebo()
    local level, es, boss, scale = arena()
    stepAll(level, es, {}, 0.3)
    local p1, p2 = scale:bodyParts()[1], scale:bodyParts()[2]
    local c2, t2 = panTop(p2)
    local c1 = panTop(p1)
    local other = 0
    for i = 1, 12 do
        local pa = playerAt(level, es, c2, t2)
        putBoss(level, boss, 24 * T)
        math.randomseed(i)
        boss.last = nil
        boss:choose(level)
        if boss.state == 'leap_wind' and math.abs(boss.markX - c1) < 8 then other = other + 1 end
    end
    check('cebo', other >= 5, ('en un platillo: salta al otro %d de 12 veces'):format(other))
end

function cases.embestida()
    local level, es, boss = arena()
    putBoss(level, boss, 22 * T)
    boss.facing = 1
    local pa = playerAt(level, es, 33.5 * T, (FLOOR - 1) * T)
    pa.y = 8 * T - 60; pa.vy = 0                                -- (en la plataforma de la derecha: no lo arrolla)
    stepAll(level, es, { pa }, 0.4)
    local hp0 = pa.hp
    math.randomseed(3)
    boss:enter('charge_wind'); boss.charges = 1
    local bonk, warned, rockHit = false, false, false
    stepAll(level, es, { pa }, 4, function()
        boss.restLen = 99
        if boss.state == 'bonk' then bonk = true end
        for _, r in ipairs(boss.rocks) do if r.t < 0 then warned = true end end
        if pa.hp < hp0 then rockHit = true end
    end)
    local bossHp = boss.hp
    -- tocarlo embistiendo
    putBoss(level, boss, 20 * T); boss.facing = 1
    local pb = playerAt(level, es, 26 * T, (FLOOR - 1) * T)
    local hb0 = pb.hp
    boss:enter('charge_wind'); boss.charges = 1
    stepAll(level, es, { pb }, 1.6, function() boss.restLen = 99 end)
    check('embestida', bonk and warned and rockHit and bossHp == boss.hpMax and pb.hp < hb0,
        ('choca con la pared=%s (sin daño: %d/%d) · cascotes con sombra=%s · el de encima quita 1=%s · arrollado: vida %d → %d'):format(
            tostring(bonk), bossHp, boss.hpMax, tostring(warned), tostring(rockHit), hb0, pb.hp))
end

function cases.lanzar()
    local level, es, boss = arena()
    putBoss(level, boss, 20.5 * T)
    local pa = playerAt(level, es, 24.5 * T, 7 * T)              -- (en la plataforma del medio: nada en medio del arco)
    local hp0 = pa.hp
    boss.tossN = 1
    boss:enter('toss_wind')
    local thrown, gone = false, false
    stepAll(level, es, { pa }, 3, function()
        boss.restLen = 99
        pa.vx = 0
        if #boss.blocks > 0 then thrown = true end
        if thrown and #boss.blocks == 0 then gone = true end
    end)
    check('lanzar', thrown and gone and pa.hp == hp0 - 1, ('bloque lanzado=%s, se rompe=%s · vida %d → %d'):format(
        tostring(thrown), tostring(gone), hp0, pa.hp))
end

function cases.ondas()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    local pa = playerAt(level, es, 14 * T, 8 * T)                  -- (en la plataforma de la izquierda: a salvo)
    boss.markX, boss.markY = math.floor(25 * T), (FLOOR - 1) * T
    boss:enter('leap_wind')
    local n = 0
    stepAll(level, es, { pa }, 2.5, function() boss.restLen = 99; n = math.max(n, #boss.waves) end)
    local dirs = {}
    check('ondas', n == 2, ('ondas al caer: %d'):format(n))
end

function cases.enfado()
    local out, ok = {}, true
    for _, d in ipairs({ { diff = 'normal', want = 2 }, { diff = 'easy', want = 1 } }) do
        local level, es, boss = arena(d.diff)
        putBoss(level, boss, 24 * T)
        local pa = playerAt(level, es, 14 * T, 8 * T)
        local before = 0
        stepAll(level, es, { pa }, 8, function()
            boss.restLen = 99
            local n = 0
            for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'reserve' then n = n + 1 end end
            before = math.max(before, n)
        end)
        boss.hp = math.floor(boss.hpMax / 2) + 1
        boss:enter('flipped')
        boss:stomp()
        local rage = boss.rage
        putBoss(level, boss, 24 * T)
        local most = 0
        stepAll(level, es, { pa }, 25, function()
            boss.restLen = 99
            local n = 0
            for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'reserve' and e.state ~= 'dead' then n = n + 1 end end
            most = math.max(most, n)
            pa.invT = 9
        end)
        local good = before == 0 and rage and most == d.want
        ok = ok and good
        out[#out + 1] = ('%s: antes %d · enfadado=%s · a la vez como mucho %d (quiere %d)'):format(d.diff, before, tostring(rage), most, d.want)
    end
    check('enfado', ok, table.concat(out, ' · '))
end

function cases.derrota()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    boss.rage = true
    boss.spawnT = 99
    boss:spawnMinions(level, 1)
    local mins = boss:minions(level)
    boss.hp = 1
    boss:enter('flipped')
    boss:stomp()
    local out = boss.state == 'dying_out'
    local fled, released, shard, gone = false, false, false, false
    stepAll(level, es, {}, 9, function()
        if boss.state == 'dying_flee' then fled = true end
        if boss:releasesZone() then released = true end
        if boss:shardDrop() then shard = true end
        if not boss.alive then gone = true; return true end
    end)
    local dead = true
    for _, e in ipairs(mins) do if e.alive and e.state ~= 'dead_burst' and e.state ~= 'reserve' and e.state ~= 'gone' then dead = false end end
    check('derrota', out and fled and released and shard and gone and dead,
        ('aturdido=%s · huye volando=%s · libera la zona=%s · fragmento=%s · se va=%s · escarabajos fuera=%s'):format(
            tostring(out), tostring(fled), tostring(released), tostring(shard), tostring(gone), tostring(dead)))
end

-- Lo que se mete en la zona desde fuera (cargado o empujado) se rompe / revienta al cerrarse; lo de dentro, no
function cases.purga()
    local level, es, boss = arena()
    local Ent = require 'src/world/entities/Entities'
    local box = Ent.create({ type = 'smallbox', col = 4, row = 12, props = {} })              -- (de fuera: su sitio, la entrada)
    local beetle = Ent.create({ type = 'beetle', col = 5, row = 12, props = { patrol = false } })
    local inner = Ent.create({ type = 'smallbox', col = 22, row = 12, props = {} })           -- (de dentro)
    for _, e in ipairs({ box, beetle, inner }) do es[#es + 1] = e end
    level.liveEntities = es
    box.x, box.y = 20 * T, 11.5 * T
    beetle.x, beetle.y = 26 * T, 11.5 * T
    local ctl = BossZones.newController(level, es)
    ctl:purge(level.bossZones[1])
    local gone = (box.state == 'broken' or box.state == 'gone') and (beetle.state == 'dead_burst' or not beetle.alive)
    check('purga', gone and inner.state == 'rest',
        ('caja traída de fuera: %s · escarabajo de fuera: %s · caja de dentro: %s'):format(box.state, beetle.state, inner.state))
end

-- El trozo que lanza es del suelo que pisa (su tile)
function cases.trozo()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    local pa = playerAt(level, es, 30 * T, (FLOOR - 1) * T)
    boss:throwBlock(level, pa)
    local TileTypes = require 'src/world/tiles/TileTypes'
    local id = boss.blocks[1] and boss.blocks[1].tile
    local under = level:getTileAt(boss.x + boss.outerW * 0.45, (FLOOR - 1) * T + 4)
    check('trozo', id ~= nil and id == under and TileTypes.get(id).collision == 'solid',
        ('trozo de %s (el suelo: %s)'):format(id and TileTypes.get(id).name or '?', TileTypes.get(under).name))
end

-- El trozo de una plataforma traspasable o de un platillo: madera, con su sonido
function cases.madera()
    local level, es, boss, scale = arena()
    local TileTypes = require 'src/world/tiles/TileTypes'
    stepAll(level, es, {}, 0.3)
    putBoss(level, boss, 24 * T, 7 * T)                          -- (de pie en la plataforma del medio)
    boss.facing = 1
    local onLedge = boss:floorTile(level)
    local pan = scale:bodyParts()[1]:getOuterBounds()
    putBoss(level, boss, pan.x + pan.w / 2, pan.y - 6)            -- (los pies, como en la pelea, no siempre al píxel)
    local onPan = boss:floorTile(level)
    local m1, m2 = TileTypes.get(onLedge).mat, TileTypes.get(onPan).mat
    -- (al romperse suena su material)
    local played = {}
    local real = Sound
    Sound = setmetatable({ playAt = function(n) played[#played + 1] = n end }, { __index = function() return function() end end })
    putBoss(level, boss, 20.5 * T)
    boss.blocks = { { id = 1, x = 20.5 * T, y = 10 * T, vx = 0, vy = 300, t = 0, tile = onLedge, hit = {} } }
    stepAll(level, es, {}, 1.0, function() boss.restLen = 99 end)
    Sound = real
    check('madera', m1.name == 'wood' and m2.name == 'wood' and played[1] == 'boxBreak',
        ('plataforma: %s · platillo: %s · al romperse suena %s'):format(m1.name, m2.name, tostring(played[1])))
end

-- Sus súbditos vuelan (mitad de arriba de la zona), no embisten; pisados caen y, levantados, vuelven a volar
function cases.voladores()
    local level, es, boss = arena()
    putBoss(level, boss, 24 * T)
    boss.rage, boss.spawnT = true, 99
    boss:spawnMinions(level, 1)
    local m
    for _, e in ipairs(boss:minions(level)) do if e.alive and e.state ~= 'reserve' then m = e end end
    local pa = playerAt(level, es, 14 * T, (FLOOR - 1) * T)
    local maxY, charged = -1e9, false
    stepAll(level, es, { pa }, 6, function()
        boss.restLen = 99
        pa.invT = 9
        maxY = math.max(maxY, m.y)
        if m.state == 'windup' or m.state == 'charge' then charged = true end
    end)
    local flew = m.flying and m.state == 'walk'
    local _, _, zy0, zy1 = boss:zoneBounds()
    local high = maxY < (zy0 + zy1) / 2 + T
    m:stomp()
    local fell, landed = not m.flying, false
    stepAll(level, es, {}, 1.5, function() boss.restLen = 99; if m.onGround and m.state == 'onback' then landed = true end end)
    stepAll(level, es, {}, 4, function() boss.restLen = 99 end)
    local again = m.flying and m.state == 'walk'
    check('voladores', m.props.wings and flew and high and not charged and fell and landed and again,
        ('vuela=%s (lo más bajo %d, mitad %d) · embiste=%s · pisado cae=%s, patas arriba en el suelo=%s · vuelve a volar=%s'):format(
            tostring(flew), maxY, (zy0 + zy1) / 2 + T, tostring(charged), tostring(fell), tostring(landed), tostring(again)))
end

function cases.red()
    local level, es, boss = arena()
    putBoss(level, boss, 20 * T)
    local pa = playerAt(level, es, 27 * T, (FLOOR - 1) * T)
    level.players = { pa }
    boss.rage = true
    boss.markX, boss.markY = 900, 700
    boss:throwBlock(level, pa)
    boss:dropRocks(level)
    boss:spawnWaves()
    boss:enter('leap_wind')
    local data = boss:netPackExtra()
    local other = Entities.create({ type = 'giantbeetle', col = boss.col, row = boss.row, props = {} })
    other.zone, other.levelRef = boss.zone, level
    other.x, other.y, other.state, other.deadTimer, other.facing = boss.x, boss.y, boss.state, boss.deadTimer, boss.facing
    other:netApplyExtra(data, data, 1)
    local same = other.rage == boss.rage and other.markX == boss.markX and other.markY == boss.markY
        and #other.blocks == #boss.blocks and #other.rocks == #boss.rocks and #other.waves == #boss.waves
        and math.floor(other.blocks[1].x) == math.floor(boss.blocks[1].x) and other.rocks[1].floor == boss.rocks[1].floor
    boss:enter('flipped'); other.state = 'flipped'
    local gob = boss:getOuterBounds()
    local p1 = dropOn(level, es, boss.x, gob.y, false)
    local i1, i2 = boss:interact(p1), other:interact(p1)
    check('red', same and i1 == i2 and i1 == 'stomp',
        ('datos iguales=%s (%d campos: %d bloques, %d cascotes, %d ondas) · interact %s / %s'):format(
            tostring(same), #data, #boss.blocks, #boss.rocks, #boss.waves, tostring(i1), tostring(i2)))
end

function love.load(arg)
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'arena', 'acorazado', 'caparazon', 'cascotes', 'vuelco', 'golpe', 'doble_filo', 'cebo', 'embestida', 'lanzar', 'ondas', 'enfado', 'derrota', 'purga', 'trozo', 'madera', 'voladores', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
