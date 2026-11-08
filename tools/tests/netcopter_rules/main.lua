-- tools/tests/netcopter_rules — reglas del REDCÓPTERO (docs/design/flappy-plan-5-netcopter.md), pieza a pieza, en salas
-- Flappy hechas aquí:
--   rebote   un jugador que vuela SUBIENDO toca una bomba luminosa que cae: sale devuelta (`returning`) al jefe, que
--            pierde 2 de vida; la explosión de la devuelta no hace daño a nadie
--   de_lado  sin subir (vy = 0) la bomba explota y el jugador pierde 1 de vida
--   falla    el jefe se aparta del camino: la bomba acaba en un bloque sólido, el jugador sigue igual y ella desaparece
--   mecha    sin que nadie la toque explota a los 2,5 s
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

local ORDER = { 'rebote', 'de_lado', 'falla', 'mecha' }
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
