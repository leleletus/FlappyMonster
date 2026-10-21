-- Arnés: la DIFICULTAD como marco genérico de modificadores (src/core/Difficulty.lua), caso a caso:
--   neutro     sin dificultad (juego libre, online sin elegirla, los demás arneses) todo vale 1: nada cambia
--   enemigos   un Gummy anda 0,8× en Fácil y 1,25× en Extremo (su tiempo escalado: Difficulty.dt)
--   categorias enemigos, trampas y jefes llevan cada uno su ritmo; lo demás (objetos, mecanismos), ninguno;
--              un tipo puede salirse (`pace = false`)
--   jefe       su vida se escala al empezar la pelea (bossHp) y su ritmo es bossPace
--   jugador    vida 4 en Fácil; invulnerable más (Fácil) o menos (Extremo) tiempo tras un golpe;
--              aire bajo el agua × airTime
--   peligros   los pinchos matan… salvo en Fácil: 1 de vida y un bote hacia arriba
--   peligros_ent  igual con los pinchos que son entidades (el que cuelga y cae, la lluvia)
--   salas      varias a la vez (servidor): Difficulty.bind cambia de una a otra sin mezclarlas
--   sentidos   los enemigos te ven desde el techo y oyen ruidos de más lejos en Extremo (× sense) y de más
--              cerca en Fácil
--   doble      XTRA EXTREMO: cada nivel de jefe de la historia lleva DOS jefes (src/world/systems/XtraBosses.lua):
--              la copia dentro de su zona y separada, la misma lista al construir dos veces (servidor y
--              cliente: mismos índices), súbditos de reserva de los dos, vida de cada uno × bossHp × pairHp
--   tools/tests/run.sh difficulty_rules   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Difficulty = require 'src/core/Difficulty'
local BossZones = require 'src/world/systems/BossZones'
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

-- Los pinchos que son ENTIDADES (los que cuelgan y caen, la lluvia de pinchos...) igual que los del suelo: matan…
-- salvo en Fácil (antes en Fácil también mataban)
function cases.peligros_ent()
    local function touch(diff)
        local level, es, sp = room(20, 8, { { type = 'spikefall', col = 8, row = 2, sub = 1, props = {} } }, diff)
        local pa = player(level, 5, 8)
        local hb = sp:getHazardBoxes()[1]
        pa.x, pa.y, pa.vy = hb.x + hb.w / 2, hb.y + hb.h / 2 + 20, 0
        Interactions.run(pa, es, {})
        return pa.dying, pa.hp
    end
    local dN = touch(nil)
    local dE, hE = touch('easy')
    check('peligros_ent', dN == true and dE ~= true and hE == 3,
        ('tocar un pincho colgante: sin dificultad muere=%s; en Fácil muere=%s, vida 4 → %s'):format(tostring(dN), tostring(dE), tostring(hE)))
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

function cases.sentidos()
    local function sees(diff)
        local level, es, e = room(20, 14, { { type = 'gummy', col = 10, row = 2 } }, diff)
        level.players = { { x = e.x, y = e.y + 7 * T, alive = true } }
        local Noise = require 'src/world/systems/Noise'
        level.noises = { seq = 1, list = { { seq = 1, x = e.x + 10.5 * T, y = e.y, r = 9 * T } } }
        return e:seesPlayerBelow(level, 6), Noise.heard(level, e.x, e.y, 0) ~= nil
    end
    local sN, hN = sees('normal')
    local sX, hX = sees('extreme')
    local sE, hE = sees('easy')
    check('sentidos', not sN and sX and not sE and not hN and hX and not hE,
        ('alcance 6 casillas, jugador a 7 debajo: lo ve en Normal=%s, Extremo=%s, Fácil=%s; ruido de 9 a 10,5: lo oye %s / %s / %s'):format(
         tostring(sN), tostring(sX), tostring(sE), tostring(hN), tostring(hX), tostring(hE)))
end

function cases.doble()
    -- (dos jefes aliados — `bossExtra` —: hoy ninguna dificultad lo pone, se guarda para más adelante; se prueba
    --  encendiéndolo en Xtra extremo solo durante este caso)
    Difficulty.MODS.xtra.bossExtra = true
    local ok, err = pcall(function()
    local Worlds = require 'src/story/Worlds'
    local EntityTypes = require 'src/world/entities/base/EntityTypes'
    local list = {}
    for w = 1, Worlds.count() do
        for _, n in ipairs(Worlds.nodes(w)) do
            local d = json.decode(love.filesystem.read(Worlds.path(n.id)))
            if d.bossZones and #d.bossZones > 0 then list[#list + 1] = n.id end
        end
    end
    local function bosses(level)
        local b, res = {}, 0
        for _, n in ipairs(level.entities) do
            local def = EntityTypes.byName[n.type]
            if def and def.category == 'Jefes' then b[#b + 1] = n end
            if n.reserve and n.summonKey ~= 'bossdrops' then res = res + 1 end   -- (la ayuda del jefe: caso 'ayuda')
        end
        return b, res
    end
    local bad = {}
    for _, id in ipairs(list) do
        local path = Worlds.path(id)
        local one, r1 = bosses(Level.new(path))
        local lv2 = Level.new(path, 'xtra')
        local two, r2 = bosses(lv2)
        local again = Level.new(path, 'xtra')
        local same = #again.entities == #lv2.entities
        for i, n in ipairs(lv2.entities) do
            local m = again.entities[i]
            if not m or m.type ~= n.type or m.col ~= n.col or m.row ~= n.row then same = false end
        end
        local inside, sep, pair = true, true, true
        for _, z in ipairs(lv2.bossZones) do end
        local d = json.decode(love.filesystem.read(path))
        for i, b in ipairs(two) do
            local inZ = false
            for _, z in ipairs(d.bossZones) do
                if b.col >= z.col and b.col < z.col + z.w and b.row >= z.row and b.row < z.row + z.h then inZ = true end
            end
            inside = inside and inZ
            pair = pair and b.props.xtraPair == true
            if i > #one then sep = sep and math.abs(b.col - two[i - #one].col) >= 5 end
        end
        -- vida de cada uno al empezar la pelea
        lv2.difficulty = 'xtra'
        Difficulty.bind(lv2)
        local e = Entities.create(two[1])
        e:startFight(1)
        local want = math.floor(((two[1].props.hp or 1) * 1.15 * 0.65) + 0.5)
        local hpOk = e.hpMax == math.max(want, e.hpMax) and e.hpMax <= math.max(want, (two[1].props.hp or 1))
        Difficulty.bind(nil)
        local ok = #two == 2 * #one and #one > 0 and r2 == 2 * r1 and same and inside and sep and pair and hpOk
        if not ok then bad[#bad + 1] = ('%s (jefes %d→%d, reserva %d→%d, igual=%s, dentro=%s, separados=%s, pareja=%s, vida %d)'):format(
            id, #one, #two, r1, r2, tostring(same), tostring(inside), tostring(sep), tostring(pair), e.hpMax) end
    end
    check('doble', #list >= 6 and #bad == 0,
        ('%d niveles de jefe en la historia, todos con dos jefes con bossExtra%s'):format(#list, #bad > 0 and (': MAL ' .. table.concat(bad, '; ')) or ''))
    end)
    Difficulty.MODS.xtra.bossExtra = nil
    if not ok then error(err, 0) end
end

-- ENFADO GENÉRICO de Xtra extremo (`bossFury`): UN jefe por arena; empieza enfadado (× ritmo) y se le quita al
-- llegar a su fase enfadada (Mega Crabby: poca vida; Bola de Nieve: fase 3, aunque se le sigue viendo); el Rey Gummy
-- lo lleva toda la pelea;
-- en Extremo, nada
function cases.enfado()
    local Worlds = require 'src/story/Worlds'
    local EntityTypes = require 'src/world/entities/base/EntityTypes'
    local function bossesIn(level)
        local n = 0
        for _, pl in ipairs(level.entities) do
            local def = EntityTypes.byName[pl.type]
            if def and def.category == 'Jefes' then n = n + 1 end
        end
        return n
    end
    local single = true
    for w = 1, Worlds.count() do
        for _, nd in ipairs(Worlds.nodes(w)) do
            local path = Worlds.path(nd.id)
            if bossesIn(Level.new(path, 'xtra')) ~= bossesIn(Level.new(path)) then single = false end
        end
    end
    local function fight(path, diff, typeName)
        local level = Level.new(path, diff)
        level.difficulty = diff
        Difficulty.bind(level)
        for _, pl in ipairs(level.entities) do
            if pl.type == typeName then
                local e = Entities.create(pl)
                e.zone = level.bossZones[1]
                if e.zone then e.zone.state = 'fight' end
                e.introPlayed = true
                e:startFight(1)
                return e, level
            end
        end
    end
    local out = {}
    -- Mega Crabby: enfadado al empezar, sin enfado genérico con poca vida (su enfado de siempre)
    local m = fight('assets/levels/guarida_cangrejo_rey.json', 'xtra', 'megacrabby')
    local k0 = Difficulty.dt(m, 1)
    local f0 = m:furyActive()
    m.hp = 1
    local f1, k1 = m:furyActive(), Difficulty.dt(m, 1)
    out[#out + 1] = ('Mega Crabby: al empezar %s (×%.2f), con poca vida %s (×%.2f)'):format(tostring(f0), k0, tostring(f1), k1)
    -- Bola de Nieve: hasta su fase 2
    local s = fight('assets/levels/lago_helado.json', 'xtra', 'snowboss')
    local s1 = s:furyActive()
    s.phase = 2
    local s2 = s:furyActive()
    s.phase = 3
    local s3, l3 = s:furyActive(), s:furyLook()
    out[#out + 1] = ('Bola de Nieve: × ritmo en fase 1 %s, 2 %s, 3 %s; se le ve enfadada en la 3 %s'):format(tostring(s1), tostring(s2), tostring(s3), tostring(l3))
    -- Rey Gummy: toda la pelea
    local g = fight('assets/levels/reino_gummy.json', 'xtra', 'megagummy')
    local g1 = g:furyActive()
    g.phase = 3
    local g3 = g:furyActive()
    out[#out + 1] = ('Rey Gummy: fase 1 %s, fase 3 %s (×%.2f)'):format(tostring(g1), tostring(g3), Difficulty.dt(g, 1))
    -- Extremo: nada
    local x = fight('assets/levels/guarida_cangrejo_rey.json', 'extreme', 'megacrabby')
    local xf = x:furyActive()
    Difficulty.bind(nil)
    check('enfado', single and f0 and not f1 and k0 > k1 * 1.15 and s1 and s2 and not s3 and l3 and not m:furyLook() and g1 and g3 and not xf,
        ('un jefe por arena en Xtra extremo=%s · %s · en Extremo enfadado=%s'):format(tostring(single), table.concat(out, ' · '), tostring(xf)))
end

-- AYUDA EN LAS PELEAS DE JEFE: en Extremo caen comidas y en Xtra extremo además vidas, dentro de la zona y hasta
-- posarse en su suelo (no en el agua ni en la lava); en las demás, nada
function cases.ayuda()
    local W, H = 24, 12
    local function build(diff)
        local tiles = {}
        for r = 1, H do
            local row = {}
            for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
            tiles[r] = row
        end
        for c = 8, 10 do tiles[H - 1][c] = 3 end            -- un charco de lava: ahí no cae nada
        local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 3, H - 1 }, tiles = tiles, entities = {},
                                       bossZones = { { id = 1, col = 4, row = 2, w = 16, h = H - 2 } } }, diff)
        level.difficulty = diff
        Difficulty.bind(level)
        local es = {}
        for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
        level.liveEntities, level.players = es, {}
        return level, es
    end
    local function count(level)
        local n = { bossdrops = 0, apple = 0, extralife = 0 }
        for _, pl in ipairs(level.entities) do
            if pl.type == 'bossdrops' then n.bossdrops = n.bossdrops + 1
            elseif pl.summonKey == 'bossdrops' then n[pl.type] = n[pl.type] + 1 end
        end
        return n
    end
    local nh, ne, nx = count((build('hard'))), count((build('extreme'))), count((build('xtra')))
    local level, es = build('xtra')
    step(level, es, 5)                                       -- (sin pelea: nada)
    local before = 0
    for _, e in ipairs(es) do if e.summonOf == 'bossdrops' and e.alive then before = before + 1 end end
    level.bossZones[1].state = 'fight'
    step(level, es, 60)                                      -- (la primera vida, a 0,4-0,8 de `bossLives`)
    local z = level.bossZones[1]
    local floor = (H - 1) * T
    local landed, food, life, bad = 0, 0, 0, {}
    for _, e in ipairs(es) do
        if e.summonOf == 'bossdrops' and e.alive then
            local feet = e.y + e.outerH / 2 + (e.skyLift or 0)
            local ok = e.state ~= 'skyfall' and math.abs(feet - floor) < 2 and e.x > z.x0 and e.x < z.x1
                       and not (e.x > 7 * T and e.x < 10 * T)
            if ok then landed = landed + 1 else bad[#bad + 1] = ('%s x=%d pies=%d %s'):format(e.def.name, e.x, feet, e.state) end
            if e.def.name == 'apple' then food = food + 1 else life = life + 1 end
        end
    end
    Difficulty.bind(nil)
    check('ayuda', nh.bossdrops == 0 and ne.bossdrops == 1 and ne.apple == 2 and ne.extralife == 0
                   and nx.apple == 2 and nx.extralife == 1 and before == 0 and food == 2 and life == 1 and #bad == 0,
        ('reserva difícil %d/%d/%d, extremo %d/%d/%d, xtra %d/%d/%d (director/comidas/vidas); en 60 s de pelea (Xtra) cayeron %d comidas y %d vidas, %d posadas en el suelo de la zona (fuera de la lava)%s; sin pelea %d')
        :format(nh.bossdrops, nh.apple, nh.extralife, ne.bossdrops, ne.apple, ne.extralife, nx.bossdrops, nx.apple, nx.extralife,
                food, life, landed, #bad > 0 and (': MAL ' .. table.concat(bad, '; ')) or '', before))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'neutro', 'enemigos', 'categorias', 'jefe', 'jugador', 'peligros', 'peligros_ent', 'salas', 'sentidos', 'doble', 'ayuda', 'enfado' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
