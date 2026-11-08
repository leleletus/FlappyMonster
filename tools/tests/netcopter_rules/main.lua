-- tools/tests/netcopter_rules — reglas del REDCÓPTERO (docs/design/flappy-plan-5-netcopter.md), pieza a pieza, en salas
-- Flappy hechas aquí:
--   rebote   un jugador que vuela SUBIENDO toca una bomba luminosa que cae: sale devuelta (`returning`) al jefe, que
--            pierde 2 de vida; la explosión de la devuelta no hace daño a nadie
--   de_lado  sin subir (vy = 0) la bomba explota y el jugador pierde 1 de vida
--   falla    el jefe se aparta del camino: la bomba acaba en un bloque sólido, el jugador sigue igual y ella desaparece
--   mecha    sin que nadie la toque explota a los 2,5 s
-- Y la ayuda del jefe en salas Flappy (director bossdrops, docs/design/flappy-plan-5-netcopter.md):
--   cargas   en 30 s a Normal salen cargas y nunca hay dos a la vez
--   lastima  jugador a 0 de carga con el reloj lejos: sale una antes de PITY_T + 1 s (y con carga no sale)
--   aire     cada ayuda que sale está en una casilla sin sólido ni pilar, a ≥ 4 del jefe y a 2-6 del jugador
--   aventura un nivel de jefe que no es Flappy nunca da cargas
--
--   tools/tests/run.sh netcopter_rules   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end, playAt = function() end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local W, H, FLOOR = 24, 11, 10
local SOLID = 1

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala Flappy de W x H con suelo en la fila FLOOR; una bomba y un jefe de relleno (la nave del Monstruo Malvado, que es
-- un Boss de verdad) puestos a mano: la bomba en (bx, by) y el jefe tres casillas a la derecha
local function room(bx, by)
    local tiles = {}
    for r = 1, H do
        tiles[r] = {}
        for c = 1, W do tiles[r][c] = (r >= FLOOR) and SOLID or 0 end
    end
    local level = Level.fromData({ name = 'bomba', width = W, height = H, playerStart = { 3, 5 }, tiles = tiles, flappy = true,
        entities = { { type = 'glowbomb', col = 1, row = 1 }, { type = 'miniboss1', col = 1, row = 1, props = { hp = 3 } } } })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    local bomb, boss = es[1], es[2]
    bomb.x, bomb.y = bx, by
    boss.x, boss.y = bx + 3 * T, by
    boss.state, boss.inv, boss.levelRef = 'stuck', 0, level   -- ('stuck': vulnerable)
    bomb.owner = boss
    level.liveEntities, level.players = { bomb }, {}
    return level, bomb, boss
end
local function player(level, x, y, vy)
    for k in pairs(stub.state) do stub.state[k] = false end
    local pa = PlayerAdventure:new(x, y)
    pa.flight, pa.vy = true, vy
    level.players[#level.players + 1] = pa
    return pa
end
-- Un paso como el del juego: la bomba, luego las reglas jugador ↔ entidad (el jugador queda quieto, con su vy)
local function step(level, bomb, pa)
    local vy = pa.vy
    bomb:update(DT, level)
    pa.vy = vy
    Interactions.run(pa, { bomb }, {})
end

local cases = {}

function cases.rebote()
    local level, bomb, boss = room(5 * T, 4 * T)
    local pa = player(level, 5 * T, 4 * T, -300)
    local hp0, php = boss.hp, pa.hp
    step(level, bomb, pa)
    check('rebote', bomb.state == 'returning', 'subiendo la devuelve: ' .. bomb.state)
    for _ = 1, 60 do
        bomb:update(DT, level)
        if not bomb.alive or bomb.state == 'exploding' then break end
    end
    check('rebote', boss.hp == hp0 - 2, ('el jefe pierde 2: %d -> %d'):format(hp0, boss.hp))
    check('rebote', pa.hp == php, 'la explosión de la devuelta no hiere al jugador')
    check('rebote', bomb.state == 'exploding' or not bomb.alive, 'la bomba revienta: ' .. bomb.state)
end

function cases.de_lado()
    local level, bomb = room(5 * T, 4 * T)
    local pa = player(level, 5 * T, 4 * T, 0)
    local php = pa.hp
    step(level, bomb, pa)
    check('de_lado', bomb.state == 'exploding', 'explota al tocarla de lado: ' .. bomb.state)
    check('de_lado', pa.hp == php - 1, ('el jugador pierde 1: %d -> %d'):format(php, pa.hp))
end

function cases.falla()
    local level, bomb, boss = room(5 * T, 4 * T)
    local pa = player(level, 5 * T, 4 * T, -300)
    local php, hp0 = pa.hp, boss.hp
    step(level, bomb, pa)
    boss.x, boss.y = bomb.x + 3 * T, 0 - 4 * T          -- se aparta (arriba, fuera del camino)
    pa.x, pa.y = 20 * T, 2 * T                          -- el jugador se va lejos
    for _ = 1, 240 do
        bomb:update(DT, level)
        if not bomb.alive then break end
    end
    check('falla', not bomb.alive, 'la bomba desaparece')
    check('falla', pa.hp == php and boss.hp == hp0, 'nadie sale herido')
    check('falla', bomb.y >= (FLOOR - 1) * T - 4 or bomb.y < 0 or bomb.x > W * T or bomb.x < 0, ('acaba en un sólido (y=%.0f)'):format(bomb.y))
end

function cases.mecha()
    local level, bomb = room(5 * T, 2 * T)
    local pa = player(level, 20 * T, 2 * T, 0)
    local t
    for i = 1, 60 * 4 do
        step(level, bomb, pa)
        if bomb.state == 'exploding' then t = i * DT; break end
    end
    check('mecha', t and math.abs(t - 2.5) < 0.1, 'explota a los 2,5 s: ' .. tostring(t))
end

-- ── La ayuda del jefe ────────────────────────────────────────────────────────────────────────────────────────────
-- Sala de 30 x 11 con una zona de jefe en la pelea (columnas 6-25), un pilar (columna 15, filas 1-6), el jefe en la
-- zona y el director con su reserva (lo que añade Level.fromData), todo creado a mano como en room()
local PILLAR = 59
local function arena(flappy, diff)
    local tiles = {}
    for r = 1, H do
        tiles[r] = {}
        for c = 1, 30 do tiles[r][c] = (r >= FLOOR) and SOLID or ((c == 15 and r <= 6 and flappy) and PILLAR or 0) end
    end
    local level = Level.fromData({ name = 'ayuda', width = 30, height = H, playerStart = { 3, 5 }, tiles = tiles,
        flappy = flappy, difficulty = diff,
        bossZones = { { id = 1, col = 6, row = 1, w = 20, h = 11 } },
        entities = { { type = 'miniboss1', col = 22, row = 5, props = { hp = 3 } } } })
    level.difficulty = diff
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    local boss, dir, items = es[1], nil, {}
    for _, e in ipairs(es) do
        if e.def.name == 'bossdrops' then dir = e elseif e.summonOf then items[#items + 1] = e end
    end
    level.liveEntities, level.players = es, {}
    local z = level.bossZones[1]
    z.state, z.bosses = 'fight', { boss }
    return level, dir, items, boss
end
local function alive(items, name)
    local n = 0
    for _, e in ipairs(items) do if e.def.name == name and e.alive and e.state ~= 'reserve' then n = n + 1 end end
    return n
end

function cases.cargas()
    local level, dir, items = arena(true, 'normal')
    local pa = player(level, 10 * T, 5 * T, 0)
    pa.charge = 0
    local maxAt, drops, was = 0, 0, 0
    for i = 1, 30 * 60 do
        dir:updateCustom(DT, level)
        local n = alive(items, 'flapcharge')
        maxAt = math.max(maxAt, n)
        if n > was then drops = drops + 1 end
        was = n
        if n > 0 and i % 30 == 0 then                     -- (el jugador la coge medio segundo después)
            for _, e in ipairs(items) do if e.def.name == 'flapcharge' then e.alive = false end end
            pa:addCharge(1)
            was = 0
        end
    end
    check('cargas', drops >= 3, ('salen cargas en 30 s a Normal: %d'):format(drops))
    check('cargas', maxAt == 1, 'nunca dos a la vez: máximo ' .. maxAt)
    -- sin cogerlas: una sola en el suelo todo el rato
    local level2, dir2, items2 = arena(true, 'normal')
    local pb = player(level2, 10 * T, 5 * T, 0)
    pb.charge = 0
    local mx = 0
    for _ = 1, 30 * 60 do dir2:updateCustom(DT, level2); mx = math.max(mx, alive(items2, 'flapcharge')) end
    check('cargas', mx == 1, 'sin cogerla no sale otra: ' .. mx)
end

function cases.lastima()
    local level, dir, items = arena(true, 'normal')
    local pa = player(level, 10 * T, 5 * T, 0)
    pa.charge = 0
    dir:updateCustom(DT, level)
    dir.cool.charge = 999                                  -- el reloj, lejísimos
    local t
    for i = 1, 20 * 60 do
        dir:updateCustom(DT, level)
        if alive(items, 'flapcharge') > 0 then t = i * DT; break end
    end
    check('lastima', t and t <= 13, 'a 0 de carga sale una a los 12 s: ' .. tostring(t))
    -- con algo de carga la lástima no vale
    local level2, dir2, items2 = arena(true, 'normal')
    local pb = player(level2, 10 * T, 5 * T, 0)
    pb.charge = 2
    dir2:updateCustom(DT, level2)
    dir2.cool.charge = 999
    local got = false
    for _ = 1, 20 * 60 do
        dir2:updateCustom(DT, level2)
        if alive(items2, 'flapcharge') > 0 then got = true end
    end
    check('lastima', not got, 'con carga y el reloj lejos no sale')
end

function cases.aire()
    local level, dir, items, boss = arena(true, 'normal')
    local pa = player(level, 10 * T, 5 * T, 0)
    pa.charge = 0
    local n, bad = 0, {}
    local spots = { { 8, 3 }, { 12, 7 }, { 14, 4 }, { 16, 8 }, { 18, 2 }, { 20, 6 }, { 24, 8 }, { 10, 9 } }
    for i = 1, 300 do
        local sp = spots[i % #spots + 1]
        pa.x, pa.y = (sp[1] - 0.5) * T, (sp[2] - 0.5) * T
        dir.cool.charge, dir.cool.food = 0, 0
        pa.hp = 1                                           -- (herido: también pide comida)
        dir:updateCustom(DT, level)
        for _, e in ipairs(items) do
            if e.alive and e.state ~= 'reserve' then
                n = n + 1
                local c, r = math.floor(e.x / T) + 1, math.floor(e.y / T) + 1
                local d = level:getDef(c, r)
                local db = math.sqrt((boss.x - e.x) ^ 2 + (boss.y - e.y) ^ 2) / T
                local dp = math.sqrt((pa.x - e.x) ^ 2 + (pa.y - e.y) ^ 2) / T
                if d.collision ~= 'none' or d.name == 'pillar' or db < 4 - 0.01 or dp < 2 - 0.01 or dp > 6 + 0.01 then
                    bad[#bad + 1] = ('(%d,%d) %s boss %.1f jug %.1f'):format(c, r, d.name, db, dp)
                end
                e.alive = false
            end
        end
    end
    check('aire', n >= 20, 'salieron ayudas: ' .. n)
    check('aire', #bad == 0, 'todas en aire libre, a ≥ 4 del jefe y a 2-6 del jugador' .. (bad[1] and (' — ' .. bad[1]) or ''))
end

function cases.aventura()
    local level, dir, items = arena(false, 'normal')
    local pa = player(level, 10 * T, 5 * T, 0)
    pa.charge = 0
    local any = 0
    for _ = 1, 40 * 60 do
        if dir then dir:updateCustom(DT, level) end
        any = any + alive(items, 'flapcharge')
    end
    local charges = 0
    for _, e in ipairs(level.entities) do if e.type == 'flapcharge' then charges = charges + 1 end end
    check('aventura', any == 0 and charges == 0, 'ninguna carga en un jefe que no es Flappy')
end

function cases.ultima_vida()
    local level, dir, items = arena(true, 'normal')
    local pa = player(level, 10 * T, 5 * T, 0)
    pa.charge, pa.lives, pa.hpMax = 5, 1, 3
    for hp = 3, 1, -1 do pa.hp = hp; dir:updateCustom(DT, level) end      -- (dos golpes seguidos: le cuesta)
    local t
    for i = 1, 15 * 60 do
        dir:updateCustom(DT, level)
        if alive(items, 'apple') > 0 then t = i * DT; break end
    end
    check('ultima_vida', t and t <= 2, 'en su última vida, herido y sufriendo: sale comida: ' .. tostring(t))
end

local ORDER = { 'rebote', 'de_lado', 'falla', 'mecha', 'cargas', 'lastima', 'aire', 'aventura', 'ultima_vida' }
function love.load()
    local only = os.getenv('CASE')
    for _, name in ipairs(ORDER) do
        if not only or only == name then
            local ok, err = pcall(cases[name])
            if not ok then check(name, false, 'error de Lua: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
