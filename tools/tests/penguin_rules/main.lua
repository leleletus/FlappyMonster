-- tools/tests/penguin_rules — reglas del PINGÜINO (types/enemies/penguin.lua) y del TRINEO genérico (base/Sled.lua) caso
-- a caso, con el jugador real (PlayerAdventure + Input de prueba) en salas hechas a mano:
--   ve         anda; ve al jugador delante → se tira (dive) → se desliza rápido (≥ 280 px/s); tocarlo deslizándose
--              quita 1; al frenarse se levanta y vuelve a andar
--   hielo      sin nadie a la vista, al pisar hielo se tira de barriga y se desliza
--   cuesta     en un escalón hacia abajo se tira y baja deslizándose; en un borde con caída grande no
--   rebota     deslizándose contra una pared rebota (se da la vuelta y sigue)
--   pisar      pisarlo andando lo deja aturdido de barriga (caja baja); tumbado tocarlo de lado no hace daño; se levanta
--   trineo     aturdido, el jugador se sube: echa a correr (~380 px/s) llevándolo encima, cruza un hueco de 2 casillas
--              por el impulso (ninguno cae); saltar lo baja y el viaje acaba (frena, se levanta y anda)
--   hueco_grande  un hueco de 4 casillas no se cruza: cae
--   levanta    montado sin bajarse: al acabar el viaje se levanta y tira al jugador
--   culetazo   ground pound encima andando, tumbado o montado (el jinete salta y cae en picado): muere; uno cerca lo tumba
--   vacio      deslizándose a un foso sin fondo (y a pinchos): revienta
--   red        el cliente (solo estado, x, y, deadTimer y facing de las instantáneas) tiene las mismas cajas, la misma
--              pieza de trineo e interact; su jugador predicho, de pie en la copia, va con ella como el del servidor
--
--   tools/tests/run.sh penguin_rules   (CASE=nombre; SHOT=1 → <save>/penguin.png con todas las poses y sus cajas)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local Sled = require 'src/world/entities/base/Sled'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local TileCodec = require 'src/world/tiles/TileCodec'
local T = TILE_PX
local DT = 1 / 60
local FLOOR = 9                -- fila del suelo (la cara de arriba: y = (FLOOR - 1) * T)
local FLOOR_Y = (FLOOR - 1) * T

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function f1(x) return ('%.0f'):format(x) end

-- Sala W x H: paredes a los lados; `floor(c)` → fila de arriba del suelo en esa columna (nil = hueco hasta abajo);
-- `tile(c)` → nombre del bloque de arriba (por defecto el sólido)
local function room(W, H, floor, tile, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do
            local top = FLOOR
            if floor then top = floor(c) end           -- (nil = hueco)
            local v = 0
            if c == 1 or c == W then v = 1
            elseif top and r >= top then
                v = 1
                local name = tile and tile(c)
                if name and r == top then v = TileCodec.encode(_G['TILE_' .. name:upper()]) end
            end
            row[c] = v
        end
        tiles[r] = row
    end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, FLOOR - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    level.players = {}
    return level, es
end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end

-- Un paso como el del juego: cuerpos, jugadores, entidades, interacciones (ground pound incluido)
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

local function playerAt(level, es, x, feetY)
    local pa = PlayerAdventure:new(x, (feetY or FLOOR_Y) - 60)
    for _ = 1, 30 do stepAll(level, es, { pa }, DT) end
    pa.invT = 0
    return pa
end

local function penguin(col, dir, extra)
    local props = { pauses = false, patrol = false, startDir = dir or 'right' }
    for k, v in pairs(extra or {}) do props[k] = v end
    return { type = 'penguin', col = col, row = FLOOR - 1, props = props }
end

local function feet(e) return e.y + e.outerH / 2 end
local function onIt(pa, p) return pa.standBody == p.sledPart end

local cases = {}

function cases.ve()
    local level, es = room(30, 11, nil, nil, { penguin(6, 'right') })
    local p = es[1]
    stepAll(level, es, {}, 0.3)
    p.cd = 99                                         -- (mientras el jugador se asienta, aún no)
    local pa = playerAt(level, es, 11 * T)
    p.cd = 0
    local hp0 = pa.hp
    local seen, slid, maxV, rose, walkAgain = false, false, 0, false, false
    local tr = 0
    stepAll(level, es, { pa }, 5, function()
        tr = tr + 1
        if os.getenv('TRACE') and tr % 15 == 0 then print(('  %s x=%.0f y=%.0f suelo=%s cd=%.2f f=%s vx=%.0f'):format(p.state, p.x, p.y, tostring(p.onGround), p.cd or -1, tostring(p.facing), p.vx)) end
        if p.state == 'dive' then seen = true end
        if p.state == 'slide' then slid = true; maxV = math.max(maxV, math.abs(p.vx)) end
        if slid and p.state == 'getup' then rose = true end
        if rose and p.state == 'walk' then walkAgain = true; return true end
    end)
    local hurt = pa.hp < hp0
    check('ve', seen and slid and maxV >= 280 and hurt and rose and walkAgain,
        ('se tira=%s desliza=%s (%s px/s) quita vida=%s (%d → %d) se levanta=%s anda otra vez=%s'):format(
            tostring(seen), tostring(slid), f1(maxV), tostring(hurt), hp0, pa.hp, tostring(rose), tostring(walkAgain)))
end

function cases.hielo()
    -- sin jugador: sobre piedra anda; donde empieza el hielo se tira y se desliza
    local level, es = room(30, 11, nil, function(c) return c >= 9 and 'ice' or nil end, { penguin(5, 'right') })
    local p = es[1]
    local stoneSlide, slid, x0 = false, false, nil
    stepAll(level, es, {}, 8, function()
        if p.state == 'slide' then
            slid = true
            x0 = x0 or p.x
            if p.x < 8 * T - 20 then stoneSlide = true end
            return true
        end
        if (p.state == 'dive') and p.x < 8 * T - 20 then stoneSlide = true end
    end)
    check('hielo', slid and not stoneSlide and x0 and x0 >= 8 * T - 30,
        ('se desliza=%s en x=%s (el hielo empieza en %d) · en la piedra no=%s'):format(
            tostring(slid), x0 and f1(x0) or '-', 8 * T, tostring(not stoneSlide)))
end

function cases.cuesta()
    -- escalón de 1 casilla hacia abajo en la columna 14
    local level, es = room(30, 12, function(c) return c < 14 and FLOOR or FLOOR + 1 end, nil, { penguin(11, 'right') })
    local p = es[1]
    local slid, xs, lowered = false, nil, false
    stepAll(level, es, {}, 6, function()
        if (p.state == 'dive' or p.state == 'slide') and not xs then xs = p.x end
        if p.state == 'slide' then slid = true end
        if slid and feet(p) > FLOOR_Y + T * 0.9 and p.x > 14 * T then lowered = true; return true end
    end)
    -- borde con caída grande (5 casillas): no se tira, se da la vuelta (no es una cuesta)
    local lv2, e2 = room(30, 15, function(c) return c < 14 and FLOOR or 14 end, nil, { penguin(11, 'right', { turnAtEdges = true }) })
    local q = e2[1]
    local dove = false
    stepAll(lv2, e2, {}, 5, function() if q.state == 'dive' or q.state == 'slide' then dove = true end end)
    check('cuesta', slid and lowered and xs and xs > 12 * T and not dove,
        ('escalón: se tira en x=%s y baja deslizándose=%s · caída de 5: no se tira=%s'):format(
            xs and f1(xs) or '-', tostring(lowered), tostring(not dove)))
end

function cases.rebota()
    local level, es = room(16, 11, nil, nil, { penguin(10, 'right') })
    local p = es[1]
    stepAll(level, es, {}, 0.3)
    p:startDive(false)
    local flips, last, maxX = 0, nil, 0
    stepAll(level, es, {}, 1.5, function()
        if p.state == 'slide' then
            if last and p.facing ~= last then flips = flips + 1 end
            last = p.facing
            maxX = math.max(maxX, p.x + p:getOuterBounds().w / 2)
        end
    end)
    check('rebota', flips >= 1 and maxX <= 15 * T + 1,
        ('rebotes en la pared=%d · nunca dentro de ella (borde %s ≤ %d)'):format(flips, f1(maxX), 15 * T))
end

function cases.pisar()
    local level, es = room(24, 11, nil, nil, { penguin(10, 'right', { speed = 0 }) })
    local p = es[1]
    stepAll(level, es, {}, 0.3)
    local standH = p:getOuterBounds().h
    local pa = PlayerAdventure:new(p.x, p.y - 3 * T); pa.vy = 300
    local dazed
    stepAll(level, es, { pa }, 0.6, function()
        if p.state == 'dazed' and not dazed then dazed = true; pa.x = p.x + 4 * T end     -- (y se aparta)
    end)
    local bellyH = p:getOuterBounds().h
    local hp0 = pa.hp
    pa.x, pa.y, pa.vy = p.x + 24, feet(p) - 50, 0
    stepAll(level, es, { pa }, 0.3)
    local sideSafe = pa.hp == hp0
    pa.x = p.x + 6 * T
    local up = false
    stepAll(level, es, { pa }, 4.5, function() if p.state == 'walk' or p.state == 'idle' then up = true; return true end end)
    check('pisar', dazed and bellyH < standH * 0.7 and sideSafe and up and p.alive,
        ('aturdido=%s caja %s → %s px · de lado sin daño=%s · se levanta y anda=%s · vivo=%s'):format(
            tostring(dazed), f1(standH), f1(bellyH), tostring(sideSafe), tostring(up), tostring(p.alive)))
end

-- Un trineo: aturdido en la columna c mirando a dir, con el jugador cayendo encima
local function mount(level, es, p)
    stepAll(level, es, {}, 0.3)
    p:daze(0)
    stepAll(level, es, {}, 0.6)
    local top = feet(p) - Sled.part(p):getOuterBounds().h
    local pa = PlayerAdventure:new(p.x, top - 120); pa.vy = 100
    pa.invT = 0
    return pa
end

function cases.trineo()
    -- hueco de 2 casillas (columnas 17 y 18) hasta el fondo
    local level, es = room(44, 13, function(c) if c == 17 or c == 18 then return nil end return FLOOR end, nil, { penguin(6, 'right') })
    local p = es[1]
    local pa = mount(level, es, p)
    local rode, x0, t0, maxV, onSteps, steps = false, nil, 0, 0, 0, 0
    local crossed, fell = false, false
    local n = 0
    stepAll(level, es, { pa }, 3.5, function()
        n = n + 1
        if os.getenv('TRACE') and n % 10 == 0 then print(('  %s x=%.0f pies=%.0f vx=%.0f suelo=%s · jugador x=%.0f encima=%s'):format(p.state, p.x, feet(p), p.vx, tostring(p.onGround), pa.x, tostring(onIt(pa, p)))) end
        if p.state == 'sled' then
            rode = true
            x0 = x0 or pa.x
            maxV = math.max(maxV, math.abs(p.vx))
            steps = steps + 1
            if onIt(pa, p) then onSteps = onSteps + 1 end
        end
        if p.x > 19.5 * T then crossed = true end
        if feet(p) > FLOOR_Y + 8 or pa.dying or pa.y > FLOOR_Y then fell = true end
        if crossed and p.x > 24 * T then return true end
    end)
    local carried = x0 and (pa.x - x0) or 0
    local playerOver = crossed and math.abs(pa.x - p.x) < 40
    -- saltar lo baja: el viaje se acaba, frena y al rato se levanta
    local jumped = false
    stepAll(level, es, { pa }, 1 / 60, nil, function() stub.state.jump_pressed = true; stub.state.jump = true end)
    local ended, stopped, standing = false, false, false
    stepAll(level, es, { pa }, 3, function()
        if p.state == 'dazed' then ended = true end
        if ended and p.vx == 0 then stopped = true end
        if p.state == 'walk' or p.state == 'idle' then standing = true; return true end
    end)
    check('trineo', rode and maxV >= 360 and carried > 6 * T and onSteps >= steps * 0.9 and crossed and not fell
        and playerOver and ended and stopped and standing,
        ('monta=%s (%s px/s) lo lleva %s px · encima %d/%d pasos · cruza el hueco=%s sin caer=%s jugador encima=%s · '
         .. 'saltar lo acaba=%s frena=%s se levanta=%s'):format(tostring(rode), f1(maxV), f1(carried), onSteps, steps,
            tostring(crossed), tostring(not fell), tostring(playerOver), tostring(ended), tostring(stopped), tostring(standing)))
end

-- un hueco GRANDE (4 casillas) no se cruza: el trineo cae (y revienta en el vacío)
function cases.hueco_grande()
    local level, es = room(44, 13, function(c) if c >= 17 and c <= 20 then return nil end return FLOOR end, nil, { penguin(6, 'right') })
    local p = es[1]
    local pa = mount(level, es, p)
    local fell = false
    stepAll(level, es, { pa }, 3, function()
        if feet(p) > FLOOR_Y + T or p.state == 'dead_burst' then fell = true; return true end
    end)
    check('hueco_grande', fell and p.x < 21 * T, ('4 casillas: cae=%s (x=%s, el otro lado en %d)'):format(tostring(fell), f1(p.x), 20 * T))
end

function cases.levanta()
    local level, es = room(22, 11, nil, nil, { penguin(8, 'right') })
    local p = es[1]
    local pa = mount(level, es, p)
    local rode, bucked, upT = false, false, nil
    local t = 0
    stepAll(level, es, { pa }, 7, function()
        t = t + DT
        if p.state == 'sled' then rode = true end
        if rode and p.state == 'getup' and not upT then upT = t; bucked = not onIt(pa, p) and pa.vy < 0 end
        if upT and (p.state == 'walk' or p.state == 'idle') then return true end
    end)
    check('levanta', rode and upT and bucked and (p.state == 'walk' or p.state == 'idle'),
        ('montado=%s · se levanta a los %s s · tira al jugador=%s · anda=%s'):format(tostring(rode),
            upT and ('%.1f'):format(upT) or '-', tostring(bucked), p.state))
end

function cases.culetazo()
    local function gpOn(prep)
        local level, es = room(24, 11, nil, nil, { penguin(10, 'right', { speed = 0 }) })
        local p = es[1]
        stepAll(level, es, {}, 0.3)
        if prep == 'dazed' then p:daze(0); stepAll(level, es, {}, 0.6) end
        local pa = PlayerAdventure:new(p.x, feet(p) - 4 * T)
        pa.invT = 0
        if prep == 'sled' then
            -- con su jinete, otro jugador le cae encima en picado
            local rider = mount(level, es, p)
            stepAll(level, es, { rider }, 0.5)
            local q = PlayerAdventure:new(p.x + Sled.V * 0.12, feet(p) - 2.2 * T)
            q.invT, q.vy, q.gpPhase, q.onGround = 0, 900, 'fall', false
            stepAll(level, es, { rider, q }, 0.6, function() return p.state == 'dead' or not p.alive end)
            return p.state == 'dead' or not p.alive, p.state
        end
        pa.vy, pa.gpPhase, pa.onGround = 400, 'fall', false
        stepAll(level, es, { pa }, 0.6, function() return p.state == 'dead' end)
        return p.state == 'dead' or not p.alive, p.state
    end
    local a, sa = gpOn('walk')
    local b, sb = gpOn('dazed')
    local c, sc = gpOn('sled')
    -- un ground pound a 2 casillas lo tumba de barriga
    local level, es = room(24, 11, nil, nil, { penguin(10, 'right', { speed = 0 }) })
    local p = es[1]
    stepAll(level, es, {}, 0.3)
    local pa = PlayerAdventure:new(p.x + 2 * T, FLOOR_Y - 4 * T)
    pa.vy, pa.gpPhase, pa.onGround = 400, 'fall', false
    local knocked = false
    stepAll(level, es, { pa }, 0.8, function() if p.state == 'dazed' then knocked = true; return true end end)
    check('culetazo', a and b and c and knocked,
        ('andando muere=%s (%s) · tumbado=%s (%s) · montado=%s (%s) · cerca: tumbado=%s'):format(
            tostring(a), sa, tostring(b), sb, tostring(c), sc, tostring(knocked)))
end

function cases.vacio()
    local level, es = room(30, 12, function(c) if c >= 14 and c <= 21 then return nil end return FLOOR end, nil, { penguin(10, 'right') })
    local p = es[1]
    stepAll(level, es, {}, 0.3)
    p:startDive(false)
    local burst, n = false, 0
    stepAll(level, es, {}, 4, function()
        n = n + 1
        if os.getenv('TRACE') and n % 10 == 0 then print(('  %s x=%.0f pies=%.0f vx=%.0f suelo=%s'):format(p.state, p.x, feet(p), p.vx, tostring(p.onGround))) end
        if p.state == 'dead_burst' or not p.alive then burst = true; return true end
    end)
    -- a pinchos
    local up = { present = true, dir = TileCodec.DIR_UP }
    local lv2, e2 = room(30, 11, nil, nil, { penguin(6, 'right') })
    for c = 14, 20 do lv2.tiles[FLOOR - 1][c] = TileCodec.encode(0, false, { nil, nil, up, up }) end
    local q = e2[1]
    stepAll(lv2, e2, {}, 0.3)
    q:startDive(false)
    local spiked = false
    stepAll(lv2, e2, {}, 3, function() if q.state == 'dead_burst' or not q.alive then spiked = true; return true end end)
    check('vacio', burst and spiked, ('al vacío revienta=%s · en pinchos=%s (%s)'):format(tostring(burst), tostring(spiked), q.state))
end

-- El cliente: una copia que solo recibe lo que viaja (x, y, state, deadTimer, facing) `lag` pasos tarde; su jugador
-- (predicho, con las mismas entradas) en un nivel cuyos cuerpos salen de la copia
function cases.red()
    local function run(lag)
        local level, es = room(44, 11, nil, nil, { penguin(6, 'right') })
        local p = es[1]
        local pa = mount(level, es, p)
        local cl, ce = room(44, 11, nil, nil, { penguin(6, 'right') })
        local copy = ce[1]
        local cpa = PlayerAdventure:new(pa.x, pa.y)
        cpa.vy, cpa.invT = pa.vy, 0
        local hist = {}
        local sameBoxes, sameParts, sameI = true, true, true
        local maxDx, onCopy, steps = 0, 0, 0
        for i = 1, 150 do
            stepAll(level, es, { pa }, DT)
            hist[i] = { x = p.x, y = p.y, state = p.state, deadTimer = p.deadTimer, facing = p.facing }
            local s = hist[math.max(1, i - lag)]
            copy.x, copy.y, copy.state, copy.deadTimer, copy.facing = s.x, s.y, s.state, s.deadTimer, s.facing
            cl.players = { cpa }
            cl.solidBodies = Entities.solidBodies(ce)
            clear()
            cpa:update(DT, cl)
            if lag == 0 then
                local a, b = p:getOuterBounds(), copy:getOuterBounds()
                if a.x ~= b.x or a.y ~= b.y or a.w ~= b.w or a.h ~= b.h then sameBoxes = false end
                local pp, cp = p:bodyParts(), copy:bodyParts()
                if #pp ~= #cp or (pp[1] and (pp[1]:getOuterBounds().y ~= cp[1]:getOuterBounds().y)) then sameParts = false end
                if p:interact(pa) ~= copy:interact(pa) then sameI = false end
            end
            if p.state == 'sled' then
                steps = steps + 1
                maxDx = math.max(maxDx, math.abs(cpa.x - pa.x))
                if cpa.standBody == copy.sledPart then onCopy = onCopy + 1 end
            end
        end
        return sameBoxes and sameParts and sameI, maxDx, onCopy, steps
    end
    local same, dx0, on0, n0 = run(0)
    local _, dx6, on6, n6 = run(6)
    check('red', same and n0 > 60 and dx0 <= Sled.V / 60 + 1 and on0 >= n0 * 0.9 and on6 >= n6 * 0.9,
        ('cajas, pieza e interact iguales=%s · jugador predicho: sin retraso Δx ≤ %s px (un paso), encima %d/%d · con 6 pasos de '
         .. 'retraso Δx ≤ %s px, encima %d/%d'):format(tostring(same), f1(dx0), on0, n0, f1(dx6), on6, n6))
end

-- SHOT=1: captura <save>/penguin.png — cada pose sobre hielo (andar, quieto, tirarse, deslizarse, aturdido con estrellas,
-- montado con el jugador encima, levantarse, muerto) y debajo las mismas con las cajas (F1)
local function shot()
    local poses = { { 'walk', 0 }, { 'idle', 0 }, { 'dive', 0.1 }, { 'slide', 0 }, { 'dazed', 0.2 }, { 'sled', 0.1 },
                    { 'getup', 0.1 }, { 'dead', 0.05 } }
    local W = 2 + #poses * 3
    local ents = {}
    for i = 1, #poses do
        ents[#ents + 1] = penguin(i * 3, 'right', { speed = 0 })
        ents[#ents + 1] = { type = 'penguin', col = i * 3, row = 12, props = { speed = 0, patrol = false, pauses = false } }
    end
    local level, es = room(W, 14, function(c) return FLOOR end, function() return 'ice' end, ents)
    for c = 2, W - 1 do level.tiles[13][c] = TileCodec.encode(TILE_ICE) end
    for r = FLOOR + 1, 12 do for c = 2, W - 1 do level.tiles[r][c] = 0 end end
    stepAll(level, es, {}, 0.3)
    for i, ps in ipairs(poses) do
        for k = 0, 1 do
            local e = es[(i - 1) * 2 + 1 + k]
            e.state, e.deadTimer, e.facing, e.frame = ps[1], ps[2], 1, 1
            e:stepAlways()
        end
    end
    local pa = PlayerAdventure:new(es[11].x, feet(es[11]) - Sled.part(es[11]):getOuterBounds().h - 60)
    local ob = pa:getOuterBounds()
    pa.y = pa.y + (feet(es[11]) - Sled.part(es[11]):getOuterBounds().h) - (ob.y + ob.h)
    local canvas = love.graphics.newCanvas(W * T, 14 * T)
    local ww = WINDOW_W
    WINDOW_W = W * T
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.72, 0.82, 0.92, 1)
    level:render(0, 0)
    for _, e in ipairs(es) do e:render(0, 0) end
    pa:render(0, 0)
    for k = 2, #es, 2 do es[k]:renderDebug(0, 0) end
    love.graphics.setCanvas()
    WINDOW_W = ww
    canvas:newImageData():encode('png', 'penguin.png')
    print('captura: ' .. love.filesystem.getSaveDirectory() .. '/penguin.png')
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 've', 'hielo', 'cuesta', 'rebota', 'pisar', 'trineo', 'hueco_grande', 'levanta', 'culetazo', 'vacio', 'red' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    if os.getenv('SHOT') then
        local ok, err = xpcall(shot, debug.traceback)
        if not ok then check('captura', false, 'error: ' .. tostring(err)) end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
