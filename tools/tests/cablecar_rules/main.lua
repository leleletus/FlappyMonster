-- tools/tests/cablecar_rules — reglas del TELEFÉRICO (types/mechanisms/cablecar.lua), caso a caso en salas hechas a mano:
--   ruta         la cabina sigue el cable punto a punto a `speed` casillas/s (su plataforma, DECK_Y px bajo el cable)
--   ida_vuelta   ida y vuelta: llega al final y vuelve; a 1,5 vueltas está en medio volviendo
--   circuito     en circuito pasa por el tramo de vuelta (del último punto al primero) y vuelve a empezar
--   esperas      `stops`: al llegar a un extremo espera esos segundos quieta y luego vuelve
--   con_peso     `onWeight`: sin nadie no se mueve; con un jugador encima, sí; al bajarse vuelve al principio
--                (`back`); con `back` no, se queda donde está
--   montado      un jugador de pie en la cabina por un cable en zigzag (sube, baja, esquinas y la vuelta del final):
--                siempre de pie en ella, sin atravesarla ni flotar
--   cabinas      dos cabinas en ida y vuelta: siempre simétricas, se cruzan en medio
--   carga        una caja pequeña y un Gummy encima de la cabina van con ella
--   apoyos       cada polea se sujeta: torre hasta el suelo o, sin suelo debajo, varilla hasta el techo
--   red          el cliente (el avance `u` de la instantánea, interpolado; también al dar la vuelta) pone las cabinas
--                donde el servidor; `netBounds` cubre todo el cable
--   dibujo       se dibuja en cada isla (y en el editor) sin errores
--
--   tools/tests/run.sh cablecar_rules   (CASE=nombre: solo ese; SHOT=1 guarda <save>/cablecar.png)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
local function count(n) played[n] = (played[n] or 0) + 1 end
Sound = setmetatable({ play = count, playAt = count },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Push = require 'src/world/systems/Push'
local Isles = require 'src/world/level/Isles'
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H: suelo (fila H), techo (fila 1) y paredes; `blocks` = { {c, r}, ... } más bloques
local function room(W, H, ents, blocks, noCeil)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = ((r == 1 and not noCeil) or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = b[3] or 1 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    return level, es
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end
local function player(level, x, y)
    clearInput()
    local pa = PlayerAdventure:new(x, y)
    level.players[#level.players + 1] = pa
    return pa
end

-- Un paso como AdventureState: cuerpos y aire → jugadores → nivel → entidades → interacciones
local function step(level, es, secs, each)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.solidBodies = Entities.solidBodies(es)
        level.pushers = Push.collect(es)
        for _, pa in ipairs(level.players) do pa:update(DT, level) end
        level:update(DT)
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end

local function car(col, row, path, props)
    local p = { path = path, speed = 2 }
    for k, v in pairs(props or {}) do p[k] = v end
    return { type = 'cablecar', col = col, row = row, props = p }
end
local function pts(list) local o = {} for _, q in ipairs(list) do o[#o + 1] = { col = q[1], row = q[2] } end return o end
-- La plataforma de la cabina i: centro x y cara de arriba
local function deck(e, i)
    local b = e.parts[i or 1]:getOuterBounds({})
    return b.x + b.w / 2, b.y
end
-- Dónde debería estar (centro de la plataforma) a la distancia d del cable
local function want(e, d)
    local x, y = e.pointAt(e.geo, d)
    return x, y + e.DECK_Y
end

local cases = {}

function cases.ruta()
    -- (3,4) → (13,4) → (13,9): 10 + 5 casillas; a 2 casillas/s
    local level, es = room(20, 14, { car(3, 4, pts({ { 13, 4 }, { 13, 9 } })) })
    local e = es[1]
    local worst, t = 0, 0
    step(level, es, 7, function()
        t = t + DT
        local d = math.min(t * 2 * T, e.geo.len)
        if t * 2 * T < e.geo.len - 4 then
            local wx, wy = want(e, d)
            local x, y = deck(e)
            worst = math.max(worst, math.abs(x - wx), math.abs(y - wy))
        end
    end)
    check('ruta', math.abs(e.geo.len - 15 * T) < 0.5 and worst <= 1, ('cable de %.0f px (%d); la plataforma va donde toca: error máximo %.2f px')
          :format(e.geo.len, 15 * T, worst))
end

function cases.ida_vuelta()
    local level, es = room(20, 10, { car(3, 4, pts({ { 13, 4 } })) })
    local e = es[1]
    local L = e.geo.len
    local secs = L / (2 * T)
    local ends, x0 = {}, deck(e)
    step(level, es, secs); ends[1] = deck(e)
    step(level, es, secs / 2); ends[2] = deck(e)
    step(level, es, secs / 2); ends[3] = deck(e)
    check('ida_vuelta', math.abs(ends[1] - (x0 + L)) <= 2 and math.abs(ends[2] - (x0 + L / 2)) <= 2 and math.abs(ends[3] - x0) <= 2,
          ('principio %.0f → final %.0f (%.0f) → a medio volver %.0f (%.0f) → principio %.0f'):format(x0, ends[1], x0 + L, ends[2], x0 + L / 2, ends[3]))
end

function cases.circuito()
    -- triángulo (3,4) → (11,4) → (7,9) → vuelve a (3,4)
    local level, es = room(16, 14, { car(3, 4, pts({ { 11, 4 }, { 7, 9 } }), { mode = 'loop' }) })
    local e = es[1]
    local L = e.geo.len
    local a, b = e.geo.pts[3], e.geo.pts[1]
    local onBack = false
    local x0, y0 = deck(e)
    step(level, es, L / (2 * T) - 0.05, function()
        -- (en el tramo de vuelta: entre el punto 3 y el 1)
        local x, y = deck(e)
        y = y - e.DECK_Y
        local k = (x - a[1]) / (b[1] - a[1])
        if k > 0.2 and k < 0.8 and math.abs(y - (a[2] + (b[2] - a[2]) * k)) < 2 then onBack = true end
    end)
    step(level, es, 0.05)
    local x1, y1 = deck(e)
    check('circuito', e.geo.loop and onBack and math.abs(x1 - x0) <= 3 and math.abs(y1 - y0) <= 3,
          ('pasa por el tramo de vuelta: %s; tras una vuelta (%.0f px) está donde empezó: (%.0f, %.0f) → (%.0f, %.0f)')
              :format(tostring(onBack), L, x0, y0, x1, y1))
end

function cases.esperas()
    played = {}
    local level, es = room(20, 10, { car(3, 4, pts({ { 13, 4 } }), { stops = 1 }) })
    local e = es[1]
    local L = e.geo.len
    local t, arrive, leave, x0 = 0, nil, nil, deck(e)
    step(level, es, L / (2 * T) + 2, function()
        t = t + DT
        local x = deck(e)
        if not arrive and math.abs(x - (x0 + L)) < 0.5 then arrive = t end
        if arrive and not leave and x < x0 + L - 0.5 then leave = t end
    end)
    local wait = (leave or 0) - (arrive or 0)
    check('esperas', arrive and math.abs(arrive - L / (2 * T)) < 0.05 and math.abs(wait - 1) < 0.05,
          ('llega al final a %.2f s (%.2f) y espera %.2f s (1) antes de volver'):format(arrive or -1, L / (2 * T), wait))
    check('esperas', (played.cablecarStop or 0) >= 2 and (played.cablecarMove or 0) >= 5,
          ('sonidos: llega / arranca %d, moviéndose %d'):format(played.cablecarStop or 0, played.cablecarMove or 0))
end

function cases.con_peso()
    for _, back in ipairs({ true, false }) do
        local level, es = room(24, 12, { car(4, 4, pts({ { 18, 4 } }), { onWeight = true, back = back }) })
        local e = es[1]
        local x0, top = deck(e)
        step(level, es, 1.5)
        local still = math.abs(deck(e) - x0) < 0.5
        -- un jugador encima
        local pa = player(level, x0, top - 50)
        step(level, es, 0.5)
        local onIt = pa.standBody == e.parts[1]
        step(level, es, 2)
        local xRide = deck(e)
        -- se baja (se le quita) y espera
        level.players = {}
        step(level, es, 0.5)
        local xOff = deck(e)
        step(level, es, 5)
        local xEnd = deck(e)
        if back then
            check('con_peso', still and onIt and xRide > x0 + 3 * T and math.abs(xEnd - x0) < 0.5 and e:netAtRest(),
                  ('sin nadie quieta: %s; con un jugador de pie (%s) avanza %.0f px; sin él vuelve al principio: %.0f (%.0f), en reposo: %s')
                      :format(tostring(still), tostring(onIt), xRide - x0, xEnd, x0, tostring(e:netAtRest())))
        else
            check('con_peso', math.abs(xEnd - xOff) < 0.5 and xEnd > x0 + 3 * T,
                  ('sin «vuelve sin peso»: al bajarse se queda donde está (%.0f → %.0f)'):format(xOff, xEnd))
        end
    end
end

function cases.montado()
    -- zigzag: sube, baja, recto; ida y vuelta (la vuelta del final incluida) — y en circuito
    for _, mode in ipairs({ 'pingpong', 'loop' }) do
        local level, es = room(30, 16, { car(3, 9, pts({ { 9, 4 }, { 15, 9 }, { 22, 9 }, { 26, 5 } }), { mode = mode, speed = 3 }) })
        local e = es[1]
        local x0, top = deck(e)
        local pa = player(level, x0, top - 50)
        step(level, es, 0.4)
        local worst, off = 0, 0
        step(level, es, e:cycle() / (3 * T) + 1, function()
            local _, y = deck(e)
            local b = pa:getOuterBounds()
            local d = math.abs(b.y + b.h - y)
            if pa.standBody ~= e.parts[1] then off = off + 1 end
            worst = math.max(worst, d)
        end)
        -- (medido al final del paso: la cabina ya se movió y el jugador la sigue en el paso siguiente — como en todo
        -- cuerpo que se mueve —: como mucho lo que avanza en un paso, 3 casillas/s = 3,2 px)
        check('montado', off == 0 and worst <= 3 * T / 60 + 0.5,
              ('%s: una vuelta entera de pie en la cabina (pasos fuera: %d), pies a %.1f px de la plataforma como mucho')
                  :format(mode, off, worst))
    end
end

function cases.cabinas()
    local level, es = room(20, 10, { car(3, 4, pts({ { 15, 4 } }), { cabins = 2 }) })
    local e = es[1]
    local L = e.geo.len
    local worst, crossed = 0, false
    local x0 = e.geo.pts[1][1]
    step(level, es, L / (2 * T) * 2, function()
        local a, b = deck(e, 1), deck(e, 2)
        worst = math.max(worst, math.abs((a - x0) + (b - x0) - L))
        if math.abs(a - b) < 4 then crossed = true end
    end)
    check('cabinas', worst <= 1 and crossed, ('dos cabinas simétricas (error %.2f px) que se cruzan en medio: %s'):format(worst, tostring(crossed)))
end

function cases.carga()
    for _, kind in ipairs({ 'smallbox', 'gummy' }) do
        local level, es = room(24, 10, { car(4, 3, pts({ { 18, 3 } })), { type = kind, col = 4, row = 4, props = { movement = 'static' } } })
        local e, o = es[1], es[2]
        local x0, top = deck(e)
        o.x, o.y, o.vy = x0, top - o.outerH / 2 - 2, 0
        step(level, es, 0.3)
        local dx0 = o.x - deck(e)
        step(level, es, 3)
        local x1, t1 = deck(e)
        local dx1 = o.x - x1
        local foot = o.y + o.outerH / 2
        check('carga', math.abs(dx1 - dx0) <= 3 and math.abs(foot - t1) <= 4 and x1 > x0 + 4 * T,
              ('%s encima va con la cabina: avanzó %.0f px, se desvía %.1f px, pies a %.1f px de la plataforma')
                  :format(kind, x1 - x0, dx1 - dx0, foot - t1))
    end
end

function cases.apoyos()
    -- sala de 40 filas con techo: bajo el punto 1 el suelo está a 33 casillas (lejos) → varilla hasta el techo
    local level, es = room(30, 40, { car(4, 6, pts({ { 12, 6 } })) })
    local e = es[1]
    local sup = e:supports(level)
    check('apoyos', sup[1][1] == 'hang' and math.abs(sup[1][2] - T) < 1, ('sin suelo cerca y con techo: varilla hasta el techo (%s, %.0f)')
          :format(sup[1][1], sup[1][2]))
    local level2, es2 = room(30, 12, { car(4, 6, pts({ { 12, 6 } })) })
    local s2 = es2[1]:supports(level2)
    check('apoyos', s2[1][1] == 'tower' and math.abs(s2[1][2] - 11 * T) < 1 and s2[2][1] == 'tower',
          ('con suelo debajo: torres hasta el suelo (%s, %.0f; %s)'):format(s2[1][1], s2[1][2], s2[2][1]))
    local level3, es3 = room(30, 40, { car(4, 6, pts({ { 12, 6 } })) }, nil, true)
    local s3 = es3[1]:supports(level3)
    check('apoyos', s3[1][1] == 'tower' and s3[1][2] >= 39 * T - 1,
          ('sin techo y con el suelo lejos: torre hasta el suelo lejano (%s, %.0f)'):format(s3[1][1], s3[1][2]))
end

function cases.red()
    local level, es = room(20, 10, { car(3, 4, pts({ { 11, 4 }, { 7, 8 } }), { mode = 'loop', cabins = 2, speed = 3 }) })
    local srv = es[1]
    local cli = Entities.create({ type = 'cablecar', col = 3, row = 4, props = srv.props })
    cli.levelRef = level
    local worst = 0
    local prev
    step(level, es, 12, function()
        local pk = srv:netPack()
        cli:netApply(prev or pk, pk, 1)
        prev = pk
        for i = 1, 2 do
            local a, b = srv.parts[i]:getOuterBounds({}), cli.parts[i]:getOuterBounds({})
            worst = math.max(worst, math.abs(a.x - b.x), math.abs(a.y - b.y))
        end
    end)
    check('red', worst <= 0.5, ('cabinas del cliente donde el servidor: error máximo %.2f px'):format(worst))
    -- interpolar al dar la vuelta (del final del ciclo al principio) va por el camino corto
    local c = cli:cycle()
    cli:netApply({ math.floor((c - 10) * 4) }, { math.floor(10 * 4) }, 0.5)
    check('red', cli.u < 1 or cli.u > c - 1, ('interpolando por la vuelta (u %.0f → 10 de %.0f): %.1f (≈ 0)'):format(c - 10, c, cli.u))
    local x0, y0, x1, y1 = srv:netBounds()
    local ok = true
    for i = 1, 2 do
        local b = srv.parts[i]:getOuterBounds({})
        if b.x < x0 or b.x + b.w > x1 or b.y < y0 or b.y + b.h > y1 then ok = false end
    end
    check('red', ok, ('netBounds cubre el cable y las cabinas: (%.0f, %.0f)-(%.0f, %.0f)'):format(x0, y0, x1, y1))
end

function cases.dibujo()
    local errs, shots = 0, {}
    local cv = love.graphics.newCanvas(20 * T, 12 * T)
    for _, isle in ipairs(Isles.IDS) do
        local level, es = room(20, 12, { car(4, 4, pts({ { 12, 4 }, { 16, 7 } }), { isle = isle, cabins = 2 }) }, { { 15, 2 } })
        local e = es[1]
        step(level, es, 1)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.4, 0.55, 0.75, 1)
        level:render(0, 0)
        local ok, err = pcall(e.render, e, 0, 0)
        EDITOR_VIEW = true
        local ok2, err2 = pcall(e.render, e, 0, 0)
        EDITOR_VIEW = nil
        love.graphics.setCanvas()
        if not ok or not ok2 then errs = errs + 1; print('   ' .. isle .. ': ' .. tostring(err or err2)) end
        if os.getenv('SHOT') and (isle == 'nieve' or isle == 'pradera') then shots[#shots + 1] = cv:newImageData() end
    end
    check('dibujo', errs == 0, ('se dibuja en las %d islas y en el editor: %d errores'):format(#Isles.IDS, errs))
    if os.getenv('SHOT') and shots[1] then
        local W, H = shots[1]:getWidth(), shots[1]:getHeight()
        local out = love.image.newImageData(W, H * #shots)
        for i, d in ipairs(shots) do out:paste(d, 0, (i - 1) * H, 0, 0, W, H) end
        out:encode('png', 'cablecar.png')
        print('guardado ' .. love.filesystem.getSaveDirectory() .. '/cablecar.png')
    end
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'ruta', 'ida_vuelta', 'circuito', 'esperas', 'con_peso', 'montado', 'cabinas', 'carga', 'apoyos',
                         'red', 'dibujo' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
