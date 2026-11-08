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
-- Y el jefe (types/bosses/netcopter.lua), en una sala Flappy con su zona, tras su entrada:
--   vida     12 de vida con un jugador (sin dificultad); la dificultad la escala (`bossHp`)
--   fase2    con la mitad de vida pasa a la fase 2 y se dibuja con el globo reventado (machine_popped)
--   especial una ráfaga de potencia 3 le quita 3; otra dentro de su INV_TIME, nada
--   no_pisa  un jugador que vuela y le cae encima nunca le pisa: el jefe sigue igual y el jugador pierde 1
--   red      la red sale a la altura del jugador y, si le da, −1 y ctrlLock 0,4 s
--   garra    la garra (fase 2) solo hace daño en la franja marcada: dentro −2, fuera nada
--   huye     a 0 de vida: explosiones, sin sprite de muerte, se va por la derecha fuera de la zona y la zona queda
--            superada ('cleared')
--   bomba    la góndola suelta una bomba suya (owner = el jefe); devuelta subiendo, le quita 2
--   azar     dos semillas de rollStart → la primera red sale a tiempos distintos
--   paquete  netPackExtra → otro Redcóptero (cliente): mismo aspecto, la misma franja y la misma garra
-- Y su etapa de la campaña (assets/levels/valle_redcoptero.json, el nivel de verdad):
--   etapa_jefe       un piloto sencillo llega a la arena sin morir: la cámara automática 'stop' y la zona 'fight';
--                    el jefe vencido a la fuerza → sin paredes, vuela a la derecha y toca la meta (→ onFinish)
--   muerte_en_pelea  morir en la pelea → reaparece EN EL AIRE dentro de la zona con toda la vida (el suelo, que en
--                    vuelo hace daño, no le toca), el jefe con la misma vida y como mucho una carga a la vez
--   pilar            los pilares (enemySolid) paran la red y la bomba
--   red_repetida     una red lanzada dos veces llega exacta a su altura la segunda
--   derrota_bombas   vencido el jefe no queda ninguna bomba cayendo ni hace daño
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

-- ── El Redcóptero ────────────────────────────────────────────────────────────────────────────────────────────────
-- Sala Flappy de 36 x 11 (suelo en las filas 10-11), zona de jefe en las columnas 9-28 (toda la altura, música tuffi),
-- el jefe en (24, 5) y un jugador volando dentro (12, 5). Pasa la entrada con el controlador de zonas de verdad y
-- vuelve con la pelea empezada. El jugador NO se mueve solo (se le coloca a mano: si no, caería al suelo)
local Difficulty = require 'src/core/Difficulty'
local BossZones = require 'src/world/systems/BossZones'
local NW = 36
local function fight(diff)
    local tiles = {}
    for r = 1, H do
        tiles[r] = {}
        for c = 1, NW do tiles[r][c] = (r >= FLOOR) and SOLID or 0 end
    end
    local level = Level.fromData({ name = 'redcoptero', width = NW, height = H, playerStart = { 3, 5 }, tiles = tiles,
        flappy = true, difficulty = diff,
        bossZones = { { id = 1, col = 9, row = 1, w = 20, h = 11, music = 'tuffi' } },
        entities = { { type = 'netcopter', col = 24, row = 5 } } })
    level.difficulty = diff
    Difficulty.bind(level)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    local boss
    for _, e in ipairs(es) do if e.def.name == 'netcopter' then boss = e end end
    level.liveEntities, level.players = es, {}
    local pa = player(level, 12 * T, 5 * T, 0)
    pa.invT = 0
    local ctrl = BossZones.newController(level, es)
    local z = boss.zone
    for _ = 1, 8 * 60 do
        ctrl:update(DT)
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        if z.state == 'fight' then break end
    end
    return level, es, boss, pa, ctrl, z
end
-- Pasos de la pelea: entidades (con ctrl, la zona); el jugador se queda donde se le pone (hold lo recoloca)
local function run(level, es, secs, stop, ctrl, hold)
    for _ = 1, math.floor(secs * 60) do
        if hold then hold() end
        if ctrl then ctrl:update(DT) end
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if stop and stop() then return true end
    end
    return false
end
local function liveOf(es, name)
    local out = {}
    for _, e in ipairs(es) do if e.def.name == name and e.alive then out[#out + 1] = e end end
    return out
end

function cases.vida()
    local _, _, boss, _, _, z = fight(nil)
    check('vida', z.state == 'fight' and boss.props.hp == 12 and boss.hpMax == 12 and boss.hp == 12,
        ('12 de vida con un jugador: zona %s, vida %d/%d'):format(z.state, boss.hp, boss.hpMax))
    for _, d in ipairs({ 'normal', 'extreme' }) do
        local _, _, b2 = fight(d)
        local want = math.max(1, math.floor(12 * Difficulty.k('bossHp') + 0.5))
        check('vida', b2.hpMax == want, ('%s: bossHp × %.2f → %d (esperado %d)'):format(d, Difficulty.k('bossHp'), b2.hpMax, want))
    end
    Difficulty.bind(nil)
end

function cases.fase2()
    local _, _, boss = fight(nil)
    local p1, l1 = boss:phase(), boss:look()
    boss.inv = 0
    boss:damage(6)
    check('fase2', p1 == 1 and l1 == 'machine', ('al empezar: fase %d, %s'):format(p1, l1))
    check('fase2', boss.hp == 6 and boss:phase() == 2 and boss:bossPhase() == 2 and boss:look() == 'machine_popped',
        ('con 6 de 12: fase %d, %s'):format(boss:phase(), boss:look()))
end

function cases.especial()
    local _, _, boss, pa = fight(nil)
    boss.inv = 0
    local hp0 = boss.hp
    local ok1 = boss:onSpecialHit(3, pa)
    local hp1 = boss.hp
    boss:onSpecialHit(3, pa)
    check('especial', ok1 and hp1 == hp0 - 3, ('ráfaga de 3: %d → %d'):format(hp0, hp1))
    check('especial', boss.hp == hp1 and boss.inv > 0, ('otra dentro de INV_TIME: %d → %d'):format(hp1, boss.hp))
end

function cases.no_pisa()
    local level, es, boss, pa = fight(nil)
    boss.inv, boss.bombT, boss.netT = 0, 99, 99
    local hp0, php = boss.hp, pa.hp
    local ob = boss:getOuterBounds()
    local r0
    run(level, es, 0.5, function() return pa.hp < php end, nil, function()
        -- cayendo encima, en vuelo, con los pies justo en lo alto de su caja
        pa.x, pa.vy = boss.x, 500
        pa.y = ob.y + 20 - pa:getOuterBounds().h / 2
        pa.prevY = pa.y - 12
        r0 = r0 or Interactions.check(pa, boss)
    end)
    check('no_pisa', r0 == nil, 'nunca se le pisa: ' .. tostring(r0))
    check('no_pisa', boss.hp == hp0 and pa.hp == php - 1, ('jefe %d → %d, jugador %d → %d'):format(hp0, boss.hp, php, pa.hp))
end

function cases.red()
    local level, es, boss, pa = fight(nil)
    boss.bombT = 99
    pa.x, pa.y = 13 * T, 6.5 * T
    boss:enter('aim_net')
    local net
    run(level, es, 1.5, function() net = liveOf(es, 'netshot')[1]; return net ~= nil end)
    check('red', net ~= nil and math.abs(net.ty - pa.y) < 1, ('sale a la altura del jugador: %s vs %.0f'):format(
        net and ('%.0f'):format(net.ty) or 'sin red', pa.y))
    if not net then return end
    local php = pa.hp
    local hitX = net.x
    run(level, es, 3, function() return pa.hp < php or not net.alive end)
    check('red', pa.hp == php - 1 and (pa.ctrlLockT or 0) >= 0.39,
        ('le da (desde x=%.0f): vida %d → %d, ctrlLock %.2f'):format(hitX, php, pa.hp, pa.ctrlLockT or 0))
    check('red', not net.alive, 'la red desaparece al dar')
end

-- Una red disparada dos veces llega EXACTO a `ty` la segunda vez (settled se reinicia al lanzarla)
function cases.red_repetida()
    local level, es, boss, pa = fight(nil)
    local net = Entities.create({ type = 'netshot', col = 20, row = 3, props = {} })
    level.liveEntities = { net }
    local function shot(ty)
        net.alive, net.x, net.y = true, 24 * T, 3 * T
        net:launch(ty, 0, -math.huge)
        for _ = 1, 60 do net:update(DT, level) end
        return net.y
    end
    local y1 = shot(6 * T)
    net:spend()
    local y2 = shot(2 * T + 17)
    check('red_repetida', y1 == 6 * T and y2 == 2 * T + 17, ('primera y=%.2f (ty %.0f), segunda y=%.2f (ty %.0f)'):format(y1, 6 * T, y2, 2 * T + 17))
end

local function sweep(dodge)
    local level, es, boss, pa = fight(nil)
    boss.inv = 0
    boss:damage(6)                                        -- (fase 2)
    boss.bombT, boss.netT, boss.inv = 99, 99, 0
    pa.x, pa.y = 13 * T, 6 * T
    boss:enter('sweep_warn')
    local php, band = pa.hp, nil
    local seen = {}
    run(level, es, 4, function()
        seen[boss.state] = true
        band = band or boss.bandY
        return seen.sweep and boss.state ~= 'sweep' and boss.state ~= 'sweep_warn'
    end, nil, function()
        if dodge and boss.state == 'sweep_warn' and boss.deadTimer > 0.4 then pa.y = 6 * T + 2.2 * T end
        if pa.hp < php then pa.invT = 99 end            -- (un golpe basta)
    end)
    return php, pa.hp, band, seen
end
function cases.garra()
    local php, hp, band, seen = sweep(false)
    check('garra', seen.sweep_warn and seen.sweep and band and math.abs(band - 6 * T) < 1,
        ('marca la franja a la altura del jugador: %s'):format(tostring(band)))
    check('garra', hp == php - 2, ('dentro de la franja: %d → %d'):format(php, hp))
    local php2, hp2 = sweep(true)
    check('garra', hp2 == php2, ('fuera de la franja: %d → %d'):format(php2, hp2))
end

-- Pilares (tile 59, enemySolid): ¿paran la red y la bomba? Sí: las entidades los tratan como un bloque
function cases.pilar()
    local PIL = 59 % 16 + math.floor(59 / 16) * 2 ^ 17
    local tiles = {}
    for r = 1, H do
        tiles[r] = {}
        for c = 1, W do tiles[r][c] = (r >= FLOOR) and SOLID or ((c == 10 and r >= 3 and r <= 7) and PIL or 0) end
    end
    local level = Level.fromData({ name = 'pilar', width = W, height = H, playerStart = { 3, 5 }, tiles = tiles, flappy = true,
        entities = { { type = 'glowbomb', col = 1, row = 1 }, { type = 'netshot', col = 1, row = 1 } } })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    local bomb, net = es[1], es[2]
    level.liveEntities, level.players = es, {}
    -- la bomba cae sobre el pilar (columna 10, fila 3): explota encima, lejos del suelo
    bomb.x, bomb.y = 9.5 * T, 1 * T
    for _ = 1, 120 do
        bomb:update(DT, level)
        if bomb.state ~= 'falling' then break end
    end
    check('pilar', bomb.state == 'exploding' and bomb.y < 3 * T, ('la bomba explota sobre el pilar (y=%.0f)'):format(bomb.y))
    -- la red vuela a la izquierda por la fila 5: el pilar (columna 10) la para
    net.alive, net.x, net.y = true, 16 * T, 4.5 * T
    net:launch(4.5 * T, 0, -math.huge)
    for _ = 1, 120 do
        net:update(DT, level)
        if not net.alive then break end
    end
    check('pilar', not net.alive and net.x > 9 * T, ('la red se para en el pilar (x=%.0f)'):format(net.x))
end

function cases.huye()
    local level, es, boss, pa, ctrl, z = fight(nil)
    pa.invT = 999
    boss.inv = 0
    boss:damage(boss.hp)
    local seen, looks, order = {}, {}, {}
    run(level, es, 30, function()
        if not seen[boss.state] then order[#order + 1] = boss.state end
        seen[boss.state] = true
        looks[boss:look()] = true
        return not boss.alive
    end, ctrl)
    check('huye', seen.dying_hold and seen.fleeing and not seen.dying_fall and boss.state == 'dead',
        'estados: ' .. table.concat(order, ' → '))
    check('huye', looks.pilot_flee and not looks.dead, 'sin sprite de muerte, huye en su tabla')
    check('huye', boss.x - boss.sprW / 2 > z.x1, ('fuera de la zona por la derecha: x=%.0f, borde %.0f'):format(boss.x, z.x1))
    check('huye', z.state == 'cleared', 'zona: ' .. z.state)
end

-- Tras la derrota (onDefeat) no queda ninguna bomba cayendo y nadie recibe daño de las bombas
function cases.derrota_bombas()
    local level, es, boss, pa, ctrl, z = fight(nil)
    pa.invT = 0
    boss.inv, boss.netT, boss.bombT = 0, 99, 0
    local bomb
    run(level, es, 1, function() bomb = liveOf(es, 'glowbomb')[1]; return bomb ~= nil end, ctrl)
    check('derrota_bombas', bomb ~= nil, 'hay una bomba cayendo antes de la derrota')
    if not bomb then return end
    bomb.x, bomb.y = pa.x, pa.y - 40                      -- justo sobre el jugador: explotaría en un paso
    boss:damage(boss.hp)
    local falling, php = 0, pa.hp
    for _, e in ipairs(liveOf(es, 'glowbomb')) do if e.state == 'falling' then falling = falling + 1 end end
    check('derrota_bombas', falling == 0, 'sin bombas en estado falling tras la derrota: ' .. falling)
    run(level, es, 4, nil, ctrl, function() pa.x, pa.y, pa.vy = bomb.x, bomb.y, 0 end)
    check('derrota_bombas', pa.hp == php, ('el jugador no recibe daño de bombas tras la derrota: %d → %d'):format(php, pa.hp))
end

function cases.bomba()
    local level, es, boss, pa = fight(nil)
    boss.netT, boss.bombT, boss.inv = 99, 0, 0
    local bomb
    run(level, es, 0.2, function() bomb = liveOf(es, 'glowbomb')[1]; return bomb ~= nil end)
    check('bomba', bomb ~= nil and bomb.owner == boss and bomb.state == 'falling',
        'la góndola suelta una bomba suya: ' .. (bomb and bomb.state or 'ninguna'))
    if not bomb then return end
    local hp0 = boss.hp
    pa.vy = -300
    run(level, es, 1.5, function() return boss.hp < hp0 or not bomb.alive end, nil, function()
        if bomb.state == 'falling' then pa.x, pa.y = bomb.x, bomb.y + 10 else pa.x, pa.y = 12 * T, 8 * T end
        pa.vy = -300
    end)
    check('bomba', boss.hp == hp0 - 2, ('devuelta subiendo: el jefe %d → %d'):format(hp0, boss.hp))
end

function cases.azar()
    local t = {}
    for i, seed in ipairs({ 1, 2 }) do
        math.randomseed(seed)
        local _, _, boss = fight(nil)
        t[i] = boss.netT
    end
    check('azar', t[1] and t[2] and math.abs(t[1] - t[2]) > 0.01, ('primera red: %.2f s / %.2f s'):format(t[1] or -1, t[2] or -1))
end

function cases.paquete()
    local level, es, boss, pa = fight(nil)
    boss.inv = 0
    boss:damage(6)
    boss.bombT, boss.netT, boss.inv = 99, 99, 0
    pa.x, pa.y = 13 * T, 5 * T
    boss:enter('sweep_warn')
    run(level, es, 1.2, function() return boss.state == 'sweep' and boss.deadTimer > 0.3 end)
    local _, _, cl = fight(nil)
    cl.x, cl.y, cl.state, cl.deadTimer = boss.x, boss.y, boss.state, boss.deadTimer
    local pk = boss:netPack()
    cl:netApply(pk, pk, 1)
    local a, b = boss:clawBox(), cl:clawBox()
    check('paquete', cl:look() == boss:look() and cl.bandY == boss.bandY and a and b and a.x == b.x and a.w == b.w,
        ('aspecto %s/%s, franja %s/%s, garra %s/%s'):format(boss:look(), cl:look(), tostring(boss.bandY), tostring(cl.bandY),
        a and ('%.0f'):format(a.x) or '-', b and ('%.0f'):format(b.x) or '-'))
end

-- ── La etapa del jefe en la campaña (assets/levels/valle_redcoptero.json) ────────────────────────────────────────
-- Se carga el nivel de verdad y se juega con un paso como el de AdventureState: cuerpos → jugadores → nivel → entidades
-- → cámara automática → zonas de jefe → interacciones. Quien muere reaparece como en AdventureState (Sim.respawnPoint
-- y respawn). La META: tocarla es lo que en AdventureState lanza win() → onFinish
local AutoScroll = require 'src/world/systems/AutoScroll'
local Sim = require 'src/world/systems/Sim'
local STAGE = 'assets/levels/valle_redcoptero.json'
local function stageLevel()
    local level = Level.new(STAGE)
    Difficulty.bind(level)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    level.liveEntities, level.players = es, {}
    local boss
    for _, e in ipairs(es) do if e.def.name == 'netcopter' then boss = e end end
    local sx, sy = level:getSpawnPx()
    local pa = player(level, sx, sy, 0)
    pa.spawnX, pa.spawnY = sx, sy
    local ctrl = BossZones.newController(level, es)
    return level, es, boss, pa, ctrl, level.bossZones[1]
end
local function stageStep(level, es, ctrl, pa)
    Sim.bodies(level, es)
    pa:update(DT, level)
    level:update(DT)
    Sim.stepEntities(level, es, DT)
    AutoScroll.update(level, DT)
    ctrl:update(DT)
    if not pa.dying then Interactions.run(pa, es, {}) end
    if pa.dying and not pa.alive then
        Sim.respawnPoint(level, pa)
        pa:respawn()
        return 'respawn'
    end
end
-- El hueco del siguiente pilar por delante de x: centro en px (nil = no hay más)
local function nextGap(level, x, xMax)
    for c = math.floor(x / T) + 1, math.floor(xMax / T) + 1 do
        if level:getTile(c, 1) == PILLAR or level:getTile(c, 9) == PILLAR then
            local top, bot
            for r = 1, 9 do if level:getTile(c, r) ~= PILLAR then top = top or r; bot = r end end
            if top then return ((top - 1) * T + bot * T) / 2 end
        end
    end
end

function cases.etapa_jefe()
    local level, es, boss, pa, ctrl, z = stageLevel()
    check('etapa_jefe', boss and z and level.autoScroll and boss.zone == z and z.music == 'tuffi',
        ('el nivel: jefe %s en su zona, música %s'):format(boss and boss.def.name or '-', z and z.music or '-'))
    if not (boss and z) then return end
    local deaths, phase, finished, t = 0, 'pilares', false, 0
    local reached, scroll
    for _ = 1, 150 * 60 do
        t = t + DT
        for k in pairs(stub.state) do stub.state[k] = false end
        if pa.x >= z.x0 then pa.invT = math.max(pa.invT or 0, 1) end      -- (en la arena no se prueba esquivar)
        -- El piloto: el centro del siguiente hueco antes de la arena; dentro y después, la fila 4
        local target = (pa.x < z.x0 - T) and nextGap(level, pa.x - 40, z.x0 - T) or (4.5 * T)
        if pa.y > target + 20 and pa.vy > -60 then stub.state.jump_pressed = true end
        if phase == 'pilares' and z.state == 'fight' then
            phase, reached, scroll = 'pelea', t, level.autoScroll.state
            boss.inv = 0
            boss:damage(boss.hp)                                -- (vencido a la fuerza)
        elseif phase == 'pelea' and z.state == 'cleared' then
            phase = 'meta'
        end
        stub.state.right = phase == 'meta'
        if stageStep(level, es, ctrl, pa) == 'respawn' then deaths = deaths + 1 end
        local ob = pa:getOuterBounds()
        if phase == 'meta' and not pa.dying and level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'finish') then finished = true; break end
        if pa.lives and pa.lives <= 0 then break end
    end
    for k in pairs(stub.state) do stub.state[k] = false end
    check('etapa_jefe', reached and scroll == 'stop' and deaths == 0,
        ('llega a la arena sin morir (%s s), cámara %s, zona en pelea; muertes %d'):format(
        reached and ('%.1f'):format(reached) or 'no', tostring(scroll), deaths))
    check('etapa_jefe', z.state == 'cleared' and level:arenaAt(pa.x, pa.y) == nil, 'vencido: zona ' .. z.state .. ', sin paredes')
    check('etapa_jefe', finished, ('vuela a la derecha y toca la meta (→ onFinish) en %.1f s; x=%.0f'):format(t, pa.x))
    Difficulty.bind(nil)
end

function cases.muerte_en_pelea()
    local level, es, boss, pa, ctrl, z = stageLevel()
    -- (directamente a la arena: el jugador en su tercio izquierdo, la ventana parada encima)
    local a = level.autoScroll
    a.x, a.state = a.endX, 'stop'
    pa.x, pa.y = z.x0 + 4 * T, 5 * T
    for _ = 1, 8 * 60 do
        pa.x, pa.y, pa.vy = z.x0 + 4 * T, 5 * T, 0
        stageStep(level, es, ctrl, pa)
        if z.state == 'fight' then break end
    end
    check('muerte_en_pelea', z.state == 'fight', 'la pelea empieza: ' .. z.state)
    run(level, es, 1, nil, ctrl, function() pa.x, pa.y, pa.vy, pa.invT = z.x0 + 4 * T, 5 * T, 0, 1 end)
    local hp0 = boss.hp
    pa.invT = 0
    pa:die(nil, true)
    local back
    local maxCharges, maxBombs = 0, 0
    local function pool() local n = 0 for _, e in ipairs(es) do if e.def.name == 'glowbomb' then n = n + 1 end end return n end
    local poolStart = pool()
    for _ = 1, 5 * 60 do
        if stageStep(level, es, ctrl, pa) == 'respawn' then back = true; break end
    end
    local x, y = pa.x, pa.y
    local def = level:getDef(math.floor(x / T) + 1, math.floor(y / T) + 1)
    check('muerte_en_pelea', back and BossZones.contains(z, x, y) and z.state == 'fight',
        ('reaparece dentro de la zona (%.0f, %.0f) con la pelea en marcha'):format(x, y))
    check('muerte_en_pelea', def.collision == 'none' and not def.mat.contact and y < (FLOOR - 2) * T,
        ('en el AIRE (casilla %s, %.1f casillas sobre el suelo), no de pie en el suelo'):format(def.name, ((FLOOR - 1) * T - y) / T))
    -- (sin la invulnerabilidad de reaparecer y sin tocar nada: no toca el suelo)
    pa.invT = 0
    for _ = 1, 18 do stageStep(level, es, ctrl, pa) end
    check('muerte_en_pelea', pa.hp == pa.hpMax, ('vida al reaparecer: %d/%d (sin golpe del suelo)'):format(pa.hp, pa.hpMax))
    check('muerte_en_pelea', boss.hp == hp0, ('el jefe sigue con su vida: %d → %d'):format(hp0, boss.hp))
    -- (la ayuda del jefe sigue: nunca más de una carga a la vez en pantalla — la arena —; las de los pilares no cuentan)
    pa.charge = 0
    for _ = 1, 20 * 60 do
        pa.invT = 1
        pa.x, pa.y, pa.vy = z.x0 + 4 * T, 5 * T, 0
        stageStep(level, es, ctrl, pa)
        local n = 0
        for _, e in ipairs(es) do
            if e.def.name == 'flapcharge' and e.alive and e.state ~= 'reserve' and BossZones.contains(z, e.x, e.y) then n = n + 1 end
        end
        maxCharges = math.max(maxCharges, n)
        local nb = 0
        for _, e in ipairs(es) do
            if e.def.name == 'glowbomb' and e.alive and e.state ~= 'reserve' then nb = nb + 1 end
        end
        maxBombs = math.max(maxBombs, nb)
    end
    local poolEnd = pool()
    check('muerte_en_pelea', poolEnd == poolStart and maxBombs <= poolStart,
        ('bombas sin duplicarse tras morir: reserva %d → %d, como mucho %d vivas'):format(poolStart, poolEnd, maxBombs))
    check('muerte_en_pelea', maxCharges == 1, 'sale alguna carga y nunca dos a la vez: como mucho ' .. maxCharges)
    Difficulty.bind(nil)
end

local ORDER = { 'rebote', 'de_lado', 'falla', 'mecha', 'cargas', 'lastima', 'aire', 'aventura', 'ultima_vida',
                'vida', 'fase2', 'especial', 'no_pisa', 'red', 'garra', 'huye', 'bomba', 'azar', 'paquete',
                'etapa_jefe', 'muerte_en_pelea', 'pilar', 'red_repetida', 'derrota_bombas' }
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
