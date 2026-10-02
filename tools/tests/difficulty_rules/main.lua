-- Arnés: la DIFICULTAD como marco genérico de modificadores (src/Difficulty.lua), caso a caso:
--   neutro     sin dificultad (juego libre, online sin elegirla, los demás arneses) todo vale 1: nada cambia
--   enemigos   un Gummy anda 0,8× en Fácil y 1,25× en Extremo (su tiempo escalado: Difficulty.dt)
--   categorias enemigos, trampas y jefes llevan cada uno su ritmo; lo demás (objetos, mecanismos), ninguno;
--              un tipo puede salirse (`pace = false`)
--   jefe       su vida se escala al empezar la pelea (bossHp) y su ritmo es bossPace
--   jugador    vida 4 en Fácil; invulnerable más (Fácil) o menos (Extremo) tiempo tras un golpe;
--              aire bajo el agua × airTime
--   peligros   los pinchos matan… salvo en Fácil: 1 de vida y un bote hacia arriba
--   salas      varias a la vez (servidor): Difficulty.bind cambia de una a otra sin mezclarlas
--   tools/tests/run.sh difficulty_rules   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Interactions = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Difficulty = require 'src/Difficulty'
local BossZones = require 'src/world/BossZones'
local json = require 'libs/json'
local T = TILE_PX

local fails = 0
local function check(case, ok, msg)
    print(('%-11s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local function room(W, H, ents, diff, spikes)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 3, H - 1 }, tiles = tiles, entities = ents or {} })
    level.difficulty = diff
    Difficulty.bind(level)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    return level, es, es[1]
end

local function step(level, es, secs, players)
    for _ = 1, math.floor(secs * 60) do
        Difficulty.bind(level)
        for _, pa in ipairs(players or {}) do pa:update(1 / 60, level) end
        level.solidBodies = Entities.solidBodies(es)
        level:update(1 / 60)
        for _, e in ipairs(es) do if e.alive then e:update(Difficulty.dt(e, 1 / 60), level) end end
        for _, pa in ipairs(players or {}) do Interactions.run(pa, es, {}) end
    end
end

local function player(level, col, H)
    for k in pairs(stub.state) do stub.state[k] = false end
    Difficulty.bind(level)
    local pa = PlayerAdventure:new((col - 0.5) * T, (H - 1) * T - 60)
    pa:applyDifficulty()
    level.players = { pa }
    for _ = 1, 40 do pa:update(1 / 60, level) end
    pa.invT = 0
    return pa
end

local cases = {}

function cases.neutro()
    Difficulty.bind(nil)
    local a = Difficulty.k('enemyPace') == 1 and Difficulty.k('bossHp') == 1 and Difficulty.k('playerHp', 3) == 3 and not Difficulty.flag('hazardHurt')
    local level, es, g = room(20, 8, { { type = 'gummy', col = 6, row = 7, props = {} } }, nil)
    local same = Difficulty.dt(g, 0.5) == 0.5
    local pa = player(level, 3, 8)
    check('neutro', a and same and pa.hpMax == 3 and not Difficulty.valid('nope') and Difficulty.valid('easy'),
        ('sin dificultad todo a 1=%s; el tiempo de un enemigo no cambia=%s; vida %d'):format(tostring(a), tostring(same), pa.hpMax))
end

function cases.enemigos()
    local function walk(diff)
        local level, es, g = room(40, 8, { { type = 'gummy', col = 6, row = 7, props = { pauses = false, patrol = { left = 2, right = 38 } } } }, diff)
        step(level, es, 0.2)
        local x0 = g.x
        step(level, es, 3)
        return math.abs(g.x - x0)
    end
    local n, e, x = walk(nil), walk('easy'), walk('extreme')
    check('enemigos', math.abs(e / n - 0.8) < 0.04 and math.abs(x / n - 1.25) < 0.04,
        ('un Gummy en 3 s: %.0f px; en Fácil %.0f (×%.2f); en Extremo %.0f (×%.2f)'):format(n, e, e / n, x, x / n))
end

function cases.categorias()
    local level, es = room(30, 10, { { type = 'gummy', col = 4, row = 9, props = {} }, { type = 'spikefall', col = 8, row = 2, sub = 1, props = {} },
                                    { type = 'star', col = 12, row = 8, props = {} }, { type = 'trampoline', col = 16, row = 9, props = {} },
                                    { type = 'megagummy', col = 22, row = 8, props = {} } }, 'easy')
    local k = {}
    for _, e in ipairs(es) do k[e.def.name] = Difficulty.dt(e, 1) end
    local gdef = es[1].def
    gdef.pace = false
    local out = Difficulty.dt(es[1], 1)
    gdef.pace = nil
    check('categorias', k.gummy == 0.8 and k.spikefall == 0.8 and k.megagummy == 0.7 and k.star == 1 and k.trampoline == 1 and out == 1,
        ('Fácil: enemigo ×%s, trampa ×%s, jefe ×%s, estrella ×%s, trampolín ×%s; con pace=false ×%s'):format(k.gummy, k.spikefall,
         k.megagummy, k.star, k.trampoline, out))
end

function cases.jefe()
    local function hp(diff, players)
        local level, es, boss = room(30, 12, { { type = 'megagummy', col = 15, row = 10, props = { hp = 12, hpPerPlayer = 4 } } }, diff)
        boss:startFight(players)
        return boss.hpMax
    end
    check('jefe', hp(nil, 1) == 12 and hp('hard', 1) == 12 and hp('normal', 1) == 11 and hp('easy', 1) == 9 and hp('extreme', 2) == 18,
        ('vida 12 (+4 por jugador): sin dificultad %d, Difícil %d, Normal %d, Fácil %d, Extremo con 2 jugadores %d'):format(hp(nil, 1),
         hp('hard', 1), hp('normal', 1), hp('easy', 1), hp('extreme', 2)))
end

function cases.jugador()
    local function inv(diff)
        local level = room(20, 8, {}, diff)
        local pa = player(level, 5, 8)
        pa:hurt(1)
        return pa.hpMax, pa.invT
    end
    local hpE, invE = inv('easy')
    local hpN, invN = inv('normal')
    local _, invX = inv('extreme')
    -- aire: con la cabeza bajo el agua, segundos de aviso hasta que empieza a ahogarse (sala inundada)
    local function air(diff)
        local level = room(12, 10, {}, diff)
        for r = 2, 9 do for c = 2, 11 do level.tiles[r][c] = 9 end end
        local pa = player(level, 5, 10)
        local t, t0 = 0, nil
        while t < 60 do
            pa:update(1 / 60, level)
            t = t + 1 / 60
            if pa.drownPhase == 'warning' and not t0 then t0 = t end
            if pa.drownPhase == 'drowning' then break end
        end
        return t - (t0 or 0)
    end
    local aE, aN, aX = air('easy'), air('normal'), air('extreme')
    check('jugador', hpE == 4 and hpN == 3 and math.abs(invE / invN - 1.3) < 0.02 and math.abs(invX / invN - 0.75) < 0.02
        and math.abs(aE / aN - 1.4) < 0.03 and math.abs(aX / aN - 0.8) < 0.03 and aN > 15,
        ('vida: Fácil %d, Normal %d; invulnerable tras un golpe %.2f / %.2f / %.2f s (fácil/normal/extremo); aire %.1f / %.1f / %.1f s'):format(
         hpE, hpN, invE, invN, invX, aE, aN, aX))
end

function cases.peligros()
    local function onSpikes(diff)
        local level = room(20, 8, {}, diff)
        local c = 8
        level.tiles[7][c] = 2 ^ 13 + 2 ^ 16              -- pinchos hacia arriba en la casilla (subceldas de abajo)
        local pa = player(level, 5, 8)
        pa.x, pa.y, pa.vy = (c - 0.5) * T, 6 * T - 40, 200
        local up = false
        for _ = 1, 50 do
            pa:update(1 / 60, level)
            if pa.vy < -300 then up = true end
            if pa.dying then break end
        end
        return pa.dying, pa.hp, up
    end
    local dN, hN = onSpikes(nil)
    local dE, hE, upE = onSpikes('easy')
    check('peligros', dN == true and dE ~= true and hE == 3 and upE,
        ('caer en pinchos: sin dificultad muere=%s; en Fácil muere=%s, vida 4 → %d y sale de un bote=%s'):format(tostring(dN), tostring(dE), hE, tostring(upE)))
end

function cases.salas()
    local a = room(10, 6, {}, 'easy')
    local b = room(10, 6, {}, 'extreme')
    local c = room(10, 6, {}, nil)
    Difficulty.bind(a); local ka = Difficulty.k('bossPace')
    Difficulty.bind(b); local kb = Difficulty.k('bossPace')
    Difficulty.bind(c); local kc = Difficulty.k('bossPace')
    Difficulty.bind(a); local ka2 = Difficulty.k('bossPace')
    check('salas', ka == 0.7 and kb == 1.2 and kc == 1 and ka2 == 0.7,
        ('tres salas (fácil, extremo, ninguna): ritmo del jefe %s, %s, %s; y de vuelta a la primera %s'):format(ka, kb, kc, ka2))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'neutro', 'enemigos', 'categorias', 'jefe', 'jugador', 'peligros', 'salas' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
