-- tools/tests/mechanics — bloques ON/OFF, bloque invisible y Gummy con casco,
-- con el jugador real (PlayerAdventure + Input de prueba) y las reglas de
-- Interactions. Salas pequeñas hechas a mano. Casos:
--   onoff_head   un cabezazo cambia ON→OFF, otro OFF→ON (y va a brokenQueue)
--   onoff_pound  un ground pound encima lo cambia UNA vez y el jugador se queda encima
--   hidden_up    se atraviesa subiendo y se queda de pie encima
--   hidden_drop  agachado encima no se baja (no traspasable)
--   hidden_side  se atraviesa andando de lado
--   hidden_vis   aparece al tocarlo, sigue mientras lo toca, luego desaparece
--   helmet_jump  con casco: caer encima (muchas velocidades y desplazamientos)
--                SIEMPRE rebota, casco intacto, sin daño
--   helmet_ride  rebotando 6 s sobre uno que anda: nunca daño
--   helmet_gp    ground pound: casco roto y muerto, sin daño al jugador
--   helmet_side  de lado sí hace daño (como un Gummy normal)
--   stomp_fast   Gummy normal: caer rapidísimo encima es pisotón, no muerte
--   puffer_through el pez globo atraviesa bloques nadando
--   puffer_cycle   jugador en el agua cerca: aviso → hinchado (pincha 1) → deshincha
--   puffer_dry     jugador fuera del agua: no se hincha
-- SHOT=1: además guarda <save>/mechanics.png (bloques, invisible visible,
-- Gummies con y sin casco) a tamaño real.
--
--   tools/tests/run.sh mechanics
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Interactions = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local T = TILE_PX

-- Sala W x H con suelo y paredes; `put` = { {col,row,tileName}, ... }
local function room(W, H, put, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(put or {}) do tiles[p[2]][p[1]] = _G['TILE_' .. p[3]:upper()] end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    return level, es
end

-- Jugador de pie en la casilla (col, fila de apoyo = row)
local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, row * T - 60)
    for _ = 1, 30 do pa:update(1 / 60, level) end            -- (que se asiente)
    level.players = { pa }
    return pa
end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end
local function run(level, pa, secs, each, es)
    for _ = 1, math.floor(secs * 60) do
        if each then each() end
        pa:update(1 / 60, level)
        for _, e in ipairs(es or {}) do if e.alive then e:update(1 / 60, level) end end
        if es then Interactions.run(pa, es, {}) end
    end
end
local function name(level, c, r) return level:getDef(c, r).name end

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local cases = {}

function cases.onoff_head()
    local level = room(8, 8, { { 4, 5, 'switch_on' } })
    local pa = playerAt(level, 4, 7)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    run(level, pa, 1.0, function() end)
    local a = name(level, 4, 5)
    clear(); run(level, pa, 0.5)
    stub.state.jump_pressed = true; stub.state.jump = true
    run(level, pa, 1.0)
    local b = name(level, 4, 5)
    local q = level.brokenQueue or {}
    check('onoff_head', a == 'switch_off' and b == 'switch_on' and #q == 2 and q[1][4] == 'toggle',
        ('1º cabezazo → %s, 2º → %s, cola=%d'):format(a, b, #q))
end

function cases.onoff_pound()
    -- Bloque ON en el suelo; el jugador salta encima y hace ground pound
    local level = room(8, 8, { { 4, 7, 'switch_on' } })
    local pa = playerAt(level, 4, 6)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    local t = 0
    run(level, pa, 1.4, function()
        t = t + 1
        if t == 16 then stub.state.jump = false; stub.state.crouch_pressed = true end
    end)
    local q = level.brokenQueue or {}
    check('onoff_pound', name(level, 4, 7) == 'switch_off' and #q == 1 and pa.onGround and pa.y < 6 * T,
        ('→ %s, cambios=%d, de pie encima=%s'):format(name(level, 4, 7), #q, tostring(pa.onGround and pa.y < 6 * T)))
end

function cases.hidden_up()
    local level = room(8, 9, { { 4, 6, 'hidden_block' } })          -- (a 2 casillas sobre la cabeza)
    local pa = playerAt(level, 4, 8)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    local t = 0
    run(level, pa, 2.0, function()
        t = t + 1
        if t == 26 then stub.state.jump_pressed = true end        -- doble salto en lo alto: pasa del todo
        if os.getenv('TRACE') and t % 4 == 0 then
            local b = pa:getOuterBounds()
            print(('    t=%2d pies=%d vy=%d suelo=%s saltos=%s'):format(t, b.y + b.h, pa.vy, tostring(pa.onGround), tostring(pa.jumpsLeft)))
        end
    end)
    local top = 5 * T
    check('hidden_up', pa.onGround and math.abs((pa:getOuterBounds().y + pa:getOuterBounds().h) - top) < 2,
        ('en el suelo=%s, pies=%d (cara de arriba %d)'):format(tostring(pa.onGround),
            pa:getOuterBounds().y + pa:getOuterBounds().h, top))
end

function cases.hidden_drop()
    local level = room(8, 9, { { 4, 5, 'hidden_block' } })
    local pa = PlayerAdventure:new(3.5 * T, 4 * T - 60)
    level.players = { pa }
    clear(); run(level, pa, 0.6)
    local y0 = pa.y
    stub.state.crouch = true
    run(level, pa, 1.2)
    check('hidden_drop', pa.onGround and math.abs(pa.y - y0) < 30,
        ('agachado 1,2 s: y %d → %d'):format(y0, pa.y))
end

function cases.hidden_side()
    local level = room(10, 8, { { 5, 7, 'hidden_block' }, { 5, 6, 'hidden_block' } })
    -- (suelo bajo la columna invisible: la fila 7 es la de apoyo → se usa la 8 como suelo)
    level, _ = room(10, 9, { { 5, 8, 'hidden_block' }, { 5, 7, 'hidden_block' } })
    local pa = playerAt(level, 3, 8)
    local x0 = pa.x
    clear(); stub.state.right = true
    run(level, pa, 1.5)
    check('hidden_side', pa.x > 6 * T, ('x %d → %d (la columna invisible está en %d..%d)'):format(x0, pa.x, 4 * T, 5 * T))
end

function cases.hidden_vis()
    local level = room(8, 9, { { 4, 5, 'hidden_block' } })
    local pa = PlayerAdventure:new(3.5 * T, 4 * T - 60)
    level.players = { pa }
    clear()
    local function step(s)
        for _ = 1, math.floor(s * 60) do pa:update(1 / 60, level); level:updateHiddenBlocks(1 / 60, { pa:getOuterBounds() }) end
    end
    step(0.5)
    local key = 5 * 65536 + 4
    local seen = level.hiddenVis and level.hiddenVis[key] ~= nil
    step(3)
    local still = level.hiddenVis[key] ~= nil
    pa.x = 7 * T                                     -- se va
    step(0.5)
    local blinking = level.hiddenVis[key] ~= nil
    step(1.0)
    local gone = level.hiddenVis[key] == nil
    check('hidden_vis', seen and still and blinking and gone,
        ('al tocar=%s, 3 s encima=%s, al irse (0,5 s)=%s, luego=%s'):format(tostring(seen), tostring(still),
            tostring(blinking), gone and 'invisible' or 'visible'))
end

local function gummyRoom(helmet, movement)
    return room(12, 8, {}, { { type = 'gummy', col = 6, row = 7,
        props = { helmet = helmet, movement = movement or 'static', points = 10, patrol = { left = 3, right = 10 } } } })
end

-- Suelta al jugador encima del Gummy (dx px de lado, velocidad vy, ground
-- pound si gp) y simula como el juego (jugador, entidad, Interactions.run)
-- hasta `secs`. Devuelve lo que pasó.
local function dropOn(g, level, dx, vy, gp, secs)
    local pa = PlayerAdventure:new(g.x + dx, g.y - 170)
    level.players = { pa }
    pa.vy, pa.onGround = vy, false
    if gp then pa.gpPhase, pa.gpT = 'fall', 0 end
    local out = { bounces = 0, hp0 = pa.hp, results = {} }
    clear()
    for _ = 1, math.floor((secs or 1) * 60) do
        pa:update(1 / 60, level)
        if g.alive then g:update(1 / 60, level) end
        local r = Interactions.check(pa, g)
        if r then out.results[r] = (out.results[r] or 0) + 1 end
        Interactions.run(pa, { g }, {})
        if r == 'helmet' then out.bounces = out.bounces + 1 end
        if pa.dying then break end
    end
    out.pa = pa
    return out
end

-- Saltar encima: SIEMPRE rebota, casco intacto, jugador sin daño (muchas
-- caídas: de lado a lado del casco y de lentas a muy rápidas)
function cases.helmet_jump()
    local bad, n = {}, 0
    for _, vy in ipairs({ 60, 300, 700, 1100, 1500, 2000 }) do
        for dx = -40, 40, 8 do
            local level, es = gummyRoom(true)
            local g = es[1]
            local o = dropOn(g, level, dx, vy, false, 0.6)
            n = n + 1
            if o.pa.dying or o.pa.hp < o.hp0 or not g.helmet or g.state == 'dead' or o.bounces < 1 then
                bad[#bad + 1] = ('vy=%d dx=%d: rebotes=%d vida %d→%d %s casco=%s gummy=%s'):format(vy, dx, o.bounces,
                    o.hp0, o.pa.hp, o.pa.dying and 'MUERTO' or '', tostring(g.helmet), g.state)
            end
        end
    end
    check('helmet_jump', #bad == 0, ('%d caídas, %d mal%s'):format(n, #bad, #bad > 0 and (': ' .. bad[1]) or ''))
end

-- Rebotando encima de un Gummy con casco que anda (sin tocar nada) 6 s
function cases.helmet_ride()
    local level, es = gummyRoom(true, 'walk')
    local g = es[1]
    local o = dropOn(g, level, 0, 300, false, 6)
    check('helmet_ride', not o.pa.dying and o.pa.hp == o.hp0 and g.helmet and g.state ~= 'dead',
        ('rebotes=%d, jugador %s vida %d, casco=%s'):format(o.bounces, o.pa.dying and 'MUERTO' or 'vivo', o.pa.hp,
            tostring(g.helmet)))
end

-- Ground pound encima: casco roto y Gummy muerto; jugador sin daño
function cases.helmet_gp()
    local bad, n = {}, 0
    for dx = -36, 36, 12 do
        local level, es = gummyRoom(true)
        local g = es[1]
        local o = dropOn(g, level, dx, 900, true, 0.8)
        n = n + 1
        if g.state ~= 'dead' or g.helmet or o.pa.dying or o.pa.hp < o.hp0 then
            bad[#bad + 1] = ('dx=%d: gummy=%s casco=%s jugador %s vida %d'):format(dx, g.state, tostring(g.helmet),
                o.pa.dying and 'MUERTO' or 'vivo', o.pa.hp)
        end
    end
    check('helmet_gp', #bad == 0, ('%d ground pounds, %d mal%s'):format(n, #bad, #bad > 0 and (': ' .. bad[1]) or ''))
end

-- De lado: le hace daño (como un Gummy normal)
function cases.helmet_side()
    local level, es = gummyRoom(true)
    local g = es[1]
    local pa = playerAt(level, 3, 7)
    clear(); stub.state.right = true
    local hurt = false
    for _ = 1, 120 do
        pa:update(1 / 60, level); Interactions.run(pa, { g }, {})
        if pa.dying or pa.hp < 3 then hurt = true; break end
    end
    check('helmet_side', hurt and g.helmet, ('andar contra él: daño=%s, casco=%s'):format(tostring(hurt), tostring(g.helmet)))
end

-- Gummy normal: caer muy rápido encima es pisotón, no muerte (antes podía
-- saltarse la franja de pisotón en un paso)
function cases.stomp_fast()
    local bad = {}
    for _, vy in ipairs({ 300, 900, 1500, 2000 }) do
        for dx = -30, 30, 10 do
            local level, es = gummyRoom(false)
            local g = es[1]
            local o = dropOn(g, level, dx, vy, false, 0.6)
            if g.state ~= 'dead' or o.pa.dying then
                bad[#bad + 1] = ('vy=%d dx=%d: gummy=%s jugador %s'):format(vy, dx, g.state, o.pa.dying and 'MUERTO' or 'vivo')
            end
        end
    end
    check('stomp_fast', #bad == 0, (#bad == 0 and 'todas las caídas lo pisotean' or (#bad .. ' mal: ' .. bad[1])))
end

-- ── Pez globo ────────────────────────────────────────────────────────────────
-- Estanque de agua con una columna de bloques en medio de su ruta
local function pond()
    local W, H = 16, 9
    local put = {}
    for r = 3, 8 do for c = 2, W - 1 do put[#put + 1] = { c, r, 'water' } end end
    for r = 4, 6 do put[#put + 1] = { 9, r, 'solid' } end
    return room(W, H, put, { { type = 'pufferfish', col = 5, row = 5,
        props = { patrol = { left = 2, right = 15 }, speed = 60, range = 2.5, warnTime = 0.6, inflateTime = 2.5 } } })
end

function cases.puffer_through()
    local level, es = pond()
    local f = es[1]
    level.players = {}
    local minX, maxX = f.x, f.x
    for _ = 1, 60 * 30 do f:update(1 / 60, level); minX = math.min(minX, f.x); maxX = math.max(maxX, f.x) end
    check('puffer_through', maxX > 10 * T and minX < 4 * T and f.state == 'walk',
        ('nada de %d a %d atravesando la columna (x %d..%d), sin hincharse'):format(minX, maxX, 8 * T, 9 * T))
end

function cases.puffer_cycle()
    local level, es = pond()
    local f = es[1]
    local pa = PlayerAdventure:new(f.x + 60, f.y)
    level.players = { pa }
    clear()
    local seen, hurtAt, hp0, hpFirst, hurt2 = {}, nil, pa.hp, nil, nil
    local t = 0
    for _ = 1, 60 * 6 do
        t = t + 1 / 60
        -- Cerca (lo ve) y, ya hinchado, pegado a él (en el agua)
        pa.x, pa.y, pa.vx, pa.vy = f.x + (f.state == 'inflated' and 30 or 60), f.y, 0, 0
        pa:update(1 / 60, level)
        f:update(1 / 60, level)
        seen[f.state] = seen[f.state] or t
        local hp = pa.hp
        Interactions.run(pa, { f }, {})
        if pa.hp ~= hp and os.getenv('TRACE') then print(('    %.2fs vida %d→%d muriendo=%s pez=%s'):format(t, hp, pa.hp, tostring(pa.dying), f.state)) end
        if pa.hp < hp then
            if not hurtAt then hurtAt, hpFirst = t, pa.hp elseif not hurt2 then hurt2 = t end
        end
        if seen.deflate then break end
    end
    -- 1º pinchazo al hincharse (-1), el 2º no antes de que acabe la protección (1,6 s)
    local ok = pa.inWater and seen.warn and seen.inflated and seen.deflate and hurtAt
               and hurtAt >= seen.inflated - 0.001 and hpFirst == hp0 - 1
               and (not hurt2 or hurt2 - hurtAt >= 1.6) or false
    check('puffer_cycle', ok, ('aviso %.2fs → hinchado %.2fs → deshincha %.2fs; pinchazos %.2fs (vida %d→%s) y %s'):format(
        seen.warn or -1, seen.inflated or -1, seen.deflate or -1, hurtAt or -1, hp0, tostring(hpFirst),
        hurt2 and ('%.2fs'):format(hurt2) or 'ninguno más'))
end

function cases.puffer_dry()
    -- Un jugador FUERA del agua junto a él: no se hincha
    local level, es = pond()
    local f = es[1]
    for r = 3, 8 do for c = 2, 15 do level.tiles[r][c] = (c == 9 and r >= 4 and r <= 6) and TILE_SOLID or TILE_EMPTY end end
    local pa = PlayerAdventure:new(f.x + 60, f.y)
    level.players = { pa }
    clear()
    for _ = 1, 60 * 3 do pa.x, pa.y = f.x + 60, f.y; pa:update(1 / 60, level); f:update(1 / 60, level) end
    check('puffer_dry', not pa.inWater and f.state == 'walk', ('jugador en el agua=%s, pez=%s'):format(tostring(pa.inWater), f.state))
end

local shot
function love.load()
    for _, n in ipairs({ 'onoff_head', 'onoff_pound', 'hidden_up', 'hidden_drop', 'hidden_side', 'hidden_vis',
                         'helmet_jump', 'helmet_ride', 'helmet_gp', 'helmet_side', 'stomp_fast',
                         'puffer_through', 'puffer_cycle', 'puffer_dry' }) do cases[n]() end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    if not os.getenv('SHOT') then love.event.quit(fails == 0 and 0 or 1); return end
    -- Escena para la captura
    love.window.setMode(1280, 720)
    local level, es = room(20, 11, { { 4, 7, 'switch_on' }, { 6, 7, 'switch_off' }, { 9, 7, 'hidden_block' },
        { 10, 7, 'hidden_block' }, { 12, 7, 'hidden_block' } }, {
        { type = 'gummy', col = 14, row = 10, props = { helmet = true } },
        { type = 'gummy', col = 16, row = 10, props = {} },
        { type = 'gummy', col = 18, row = 10, props = { helmet = true, movement = 'fly' } },
        { type = 'pufferfish', col = 3, row = 3, props = {} },
        { type = 'pufferfish', col = 6, row = 3, props = {} },
        { type = 'pufferfish', col = 9, row = 3, props = {} } })
    for _, e in ipairs(es) do e.vx = 0 end
    -- Peces: nadando, avisando (medio) e hinchado
    es[4].state = 'walk'; es[5].state, es[5].deadTimer = 'warn', 0.45; es[6].state, es[6].deadTimer = 'inflated', 1
    local pa = PlayerAdventure:new(9.5 * T, 6 * T - 60)
    level.players = { pa }
    clear(); for _ = 1, 40 do pa:update(1 / 60, level) end     -- (de pie encima del 9 y el 10)
    -- el 9 y 10 tocados; el 12 de hace un momento (parpadeando)
    level:updateHiddenBlocks(1, { pa:getOuterBounds() })
    level:updateHiddenBlocks(1, { pa:getOuterBounds(), { x = 11 * T, y = 5 * T, w = 40, h = 64 } })
    level:updateHiddenBlocks(0.3, { pa:getOuterBounds() })
    shot = { level = level, es = es, pa = pa, n = 0 }
end

function love.draw()
    if not shot then return end
    love.graphics.clear(0.35, 0.6, 0.85)
    shot.level:render(0, 0)
    for _, e in ipairs(shot.es) do e:render(0, 0) end
    shot.pa:render(0, 0)
    shot.n = shot.n + 1
    if shot.n == 3 then
        love.graphics.captureScreenshot(function(img) img:encode('png', 'mechanics.png') end)
    end
    if shot.n > 5 then
        print('captura: ' .. love.filesystem.getSaveDirectory() .. '/mechanics.png')
        love.event.quit(fails == 0 and 0 or 1)
    end
end
