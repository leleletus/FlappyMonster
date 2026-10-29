-- tools/tests/iceberg_rules — las mecánicas de agua de la Costa Helada (2026-10-29), caso a caso en salas hechas aquí:
-- el ICEBERG (types/mechanisms/iceberg.lua), el AGUA HELADA (Level:coldAt + PlayerAir updateFrost) y la MAREA
-- (Floods, control 'tide').
--   flota        cae en una charca de casillas y se queda flotando con su cara a `float` casillas sobre el agua; se mece
--   fondo        sin agua se queda en el suelo
--   inundacion   en el fondo de una inundación vacía; al subir el agua flota y sube con ella
--   marea        la marea (seno, función pura del tiempo) sube y baja entre sus niveles con su periodo y el iceberg la
--                sigue; pasa por 'rise' y 'fall'
--   montar       un jugador de pie en él sube y baja con la marea sin caerse
--   peso         con un jugador encima se hunde un poco; con jugador + caja pequeña (más que `capacity`) avisa, se hunde
--                (el jugador se moja) y, quitada la caja, vuelve a flotar
--   quieto       nadie lo toca: no se mueve de lado (ni deriva)
--   empuje       un jugador en la orilla lo empuja andando: se mueve, se sigue deslizando al soltarlo y se para con el
--                roce, sin pasar de la pared
--   nadando      un jugador nadando también lo empuja
--   viento       el aire (systems/Push) lo lleva hasta la pared y se para; sin aire no se mueve
--   choque       lanzado contra otro iceberg se para en su cara (sin meterse)
--   caja_encima  una caja encima va con él al deslizarse y al subir la marea
--   frio         agua helada (inundación `cold`): congelado a los N s; fuera del agua el contador vuelve a 0; roto el
--                hielo dentro del agua vuelve a empezar; agua normal nunca congela; agua de casillas con `coldWater`
--   red          el estado propio lleva `frostT`; un "cliente" que se corrige con él predice igual (frío y hielo); el
--                iceberg viaja (netPack / netApply) y se dibuja; la marea no manda nada (la calcula cada uno)
--   editor       `coldWater` del nivel y la marea / agua helada de una inundación se guardan y se cargan
--
--   tools/tests/run.sh iceberg_rules   (CASE=nombre)
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
local Floods = require 'src/world/systems/Floods'
local Push = require 'src/world/systems/Push'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local SOLID, WATER = 1, 9
local FREE = 0.3 * T                     -- (lo que asoma vacío por defecto: prop `float`)

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function clear() for k in pairs(stub.state) do stub.state[k] = false end end

-- ── Salas ─────────────────────────────────────────────────────────────────────
-- 24 x 13: paredes y suelo (fila 13); ORILLA de piedra en las columnas 2-7 desde la fila 7; `pool` = charca de agua de
-- casillas en las columnas 8-23, filas 7-12 (superficie en y = 6 casillas)
local W, H = 24, 13
local SURF = 6 * T
local function room(opts)
    opts = opts or {}
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do
            local v = 0
            if r == H or r == 1 or c == 1 or c == W then v = SOLID
            elseif c <= 7 and r >= 7 and not opts.noShore then v = SOLID
            elseif opts.pool and r >= 7 then v = WATER end
            row[c] = v
        end
        tiles[r] = row
    end
    local data = { name = 'iceberg_rules', width = W, height = H, playerStart = { 4, 6 }, tiles = tiles,
                   entities = opts.entities or {}, coldWater = opts.coldWater }
    local level = Level.fromData(json.decode(json.encode(data)))
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    return level, es, data
end
local function berg(col, row, props) return { type = 'iceberg', col = col, row = row, props = props or {} } end
local function flood(props)
    local p = { id = 1, corner = { col = 23, row = 12 } }
    for k, v in pairs(props) do p[k] = v end
    return { type = 'flood', col = 8, row = 2, props = p }
end
local function find(es, name, n)
    local k = 0
    for _, e in ipairs(es) do if e.def.name == name then k = k + 1; if k == (n or 1) then return e end end end
end

-- Un paso como el del juego (AdventureState): agua, cuerpos, aire, jugadores, entidades
local function step(level, es, players, wind, input)
    level.players = players or {}
    Floods.advance(level, DT)
    level.solidBodies = Entities.solidBodies(es)
    level.pushers = Push.collect(es)
    if wind then level.pushers[#level.pushers + 1] = wind end
    clear()
    if input then input() end
    for _, pa in ipairs(level.players) do pa:update(DT, level) end
    level.liveEntities = es
    for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
    for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
end
local function run(level, es, players, secs, each, wind, input)
    for i = 1, math.floor(secs * 60 + 0.5) do
        step(level, es, players, wind, input)
        if each and each(i) then return true end
    end
end
local function top(e) return e:getOuterBounds().y end
local function feet(pa) local b = pa:getOuterBounds(); return b.y + b.h end
local function playerOn(e)
    local b = e:getOuterBounds()
    local pa = PlayerAdventure:new(b.x + b.w / 2, b.y - 60)
    pa.invT = 0
    return pa
end
local function windAll(wx) return { alive = true, pushAt = function() return wx, 0 end } end

local cases = {}

function cases.flota()
    local level, es = room({ pool = true, entities = { berg(12, 3) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 4)
    local lo, hi = math.huge, -math.huge
    run(level, es, {}, 3, function() lo, hi = math.min(lo, top(b)), math.max(hi, top(b)) end)
    local mid = (lo + hi) / 2
    check('flota', b.state == 'float' and math.abs(mid - (SURF - FREE)) < 4 and hi - lo >= 1 and hi - lo <= 7,
        ('estado %s; cara de arriba %.1f..%.1f (esperado ≈ %.1f: superficie %d - %.1f); cabeceo %.1f px'):format(
            b.state, lo, hi, SURF - FREE, SURF, FREE, hi - lo))
end

function cases.fondo()
    local level, es = room({ entities = { berg(12, 3) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 3)
    local bb = b:getOuterBounds()
    check('fondo', b.state == 'ground' and math.abs(bb.y + bb.h - 12 * T) < 1,
        ('estado %s; cara de abajo %.1f (suelo %d)'):format(b.state, bb.y + bb.h, 12 * T))
end

function cases.inundacion()
    local level, es = room({ noShore = true, entities = { berg(12, 9), flood({ startLevel = 0, maxLevel = 6, startDelay = 2,
        riseSpeed = 1, holdTime = 30, lowTime = 30 }) } })
    local b, f = find(es, 'iceberg'), level.floods[1]
    run(level, es, {}, 1.5)
    local bottomAt = b.state
    local y0 = top(b)
    run(level, es, {}, 9)
    local err = math.abs(top(b) - (f.surf - FREE))
    check('inundacion', bottomAt == 'ground' and b.state == 'float' and f.level >= 5.9 and err < 5 and y0 - top(b) > 4 * T,
        ('sin agua: %s; agua a %.2f casillas → estado %s, cara %.1f (superficie %.1f - %.1f), subió %.0f px'):format(
            bottomAt, f.level, b.state, top(b), f.surf, FREE, y0 - top(b)))
end

local function tideRoom(extra, bergProps, bergRow)
    local ents = { berg(12, bergRow or 9, bergProps), flood({ control = 'tide', startLevel = 1, maxLevel = 6, tidePeriod = 8 }) }
    for _, e in ipairs(extra or {}) do ents[#ents + 1] = e end
    return room({ noShore = true, entities = ents })
end

function cases.marea()
    local level, es = tideRoom()
    local b, f = find(es, 'iceberg'), level.floods[1]
    run(level, es, {}, 3)
    local err, pure, seen, lo, hi = 0, 0, {}, math.huge, -math.huge
    run(level, es, {}, 16, function()
        err = math.max(err, math.abs(top(b) - (f.surf - FREE)))
        local lv = Floods.tideAt(f, level.floodTime)
        pure = math.max(pure, math.abs(lv - f.level))
        seen[f.phase] = true
        lo, hi = math.min(lo, f.level), math.max(hi, f.level)
    end)
    check('marea', err < 12 and pure < 1e-9 and seen.rise and seen.fall and lo < 1.05 and hi > 5.95,
        ('agua de %.2f a %.2f casillas (fases: subiendo=%s bajando=%s), igual a Floods.tideAt (%.1e); el iceberg la sigue a ≤ %.1f px'):format(
            lo, hi, tostring(seen.rise), tostring(seen.fall), pure, err))
end

function cases.montar()
    local level, es = tideRoom()
    local b = find(es, 'iceberg')
    run(level, es, {}, 3)
    local pa = playerOn(b)
    run(level, es, { pa }, 1)
    local on, n, gap, ylo, yhi = 0, 0, 0, math.huge, -math.huge
    run(level, es, { pa }, 10, function()
        n = n + 1
        if pa.standBody == b then on = on + 1 end
        gap = math.max(gap, math.abs(feet(pa) - top(b)))
        ylo, yhi = math.min(ylo, pa.y), math.max(yhi, pa.y)
    end)
    check('montar', on / n > 0.97 and gap <= 3 and yhi - ylo > 3 * T and not pa.dying,
        ('de pie en él %.0f %% de los pasos; pies a ≤ %.1f px de su cara; subió y bajó %.0f px con la marea'):format(
            100 * on / n, gap, yhi - ylo))
end

function cases.peso()
    local level, es = room({ pool = true, entities = { berg(11, 5, { width = 4 }),
        { type = 'smallbox', col = 4, row = 6, props = {} } } })
    local b, box = find(es, 'iceberg'), find(es, 'smallbox')
    run(level, es, {}, 4)
    local empty = 0
    run(level, es, {}, 2, function() empty = empty + top(b) / 120 end)
    local pa = playerOn(b)
    pa.x = b.x - T
    run(level, es, { pa }, 3)
    local loaded = 0
    run(level, es, { pa }, 2, function() loaded = loaded + top(b) / 120 end)
    local st1 = b.state
    -- una caja pequeña al lado del jugador: 1 + 1 > 1,5 → avisa y se hunde
    box.x, box.y, box.vx, box.vy = b.x + T, top(b) - box.outerH / 2 - 2, 0, 0
    local warnAt, sunkAt, wet, t = nil, nil, false, 0
    run(level, es, { pa }, 4, function()
        t = t + DT
        if b.state == 'warn' and not warnAt then warnAt = t end
        if b.state == 'sunk' and not sunkAt then sunkAt = t end
        if pa.inWater then wet = true end
    end)
    local under = top(b) - SURF
    -- se quita la caja (a la orilla): vuelve a flotar
    box.x, box.y, box.vx, box.vy = 3.5 * T, 5.5 * T, 0, 0
    local backAt
    t = 0
    run(level, es, { pa }, 5, function() t = t + DT; if b.state == 'float' and not backAt then backAt = t end end)
    check('peso', st1 == 'float' and loaded - empty > 4 and warnAt and warnAt < 0.2 and sunkAt and sunkAt - warnAt > 0.6
        and under > 0.5 * T and wet and backAt and top(b) < SURF and not pa.dying,
        ('vacío cara %.1f, con el jugador %.1f (+%.1f px, %s); + caja pequeña: aviso a %s s, hundido a %s s, cara %.0f px bajo el agua, jugador mojado=%s; sin la caja flota a %s s (cara %.1f)'):format(
            empty, loaded, loaded - empty, st1, tostring(warnAt and ('%.2f'):format(warnAt)), tostring(sunkAt and ('%.2f'):format(sunkAt)),
            under, tostring(wet), tostring(backAt and ('%.2f'):format(backAt)), top(b)))
end

function cases.quieto()
    local level, es = room({ pool = true, entities = { berg(12, 6) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 2)
    local x0, dx = b.x, 0
    run(level, es, {}, 8, function() dx = math.max(dx, math.abs(b.x - x0)) end)
    check('quieto', dx == 0, ('8 s sin que nadie lo toque: se movió de lado %.3f px'):format(dx))
end

function cases.empuje()
    local level, es = room({ pool = true, entities = { berg(8, 6) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 3)
    local pa = PlayerAdventure:new(5 * T, SURF - 60)
    run(level, es, { pa }, 0.5)
    local x0 = b.x
    run(level, es, { pa }, 1.0, nil, nil, function() stub.state.right = true end)
    local xRel = b.x
    run(level, es, { pa }, 1.0)
    local xGlide = b.x
    local still, wallOk = false, true
    run(level, es, { pa }, 10, function()
        if b:getOuterBounds().x + b.outerW > (W - 1) * T + 0.5 then wallOk = false end
        if b.vx == 0 then still = true end
    end)
    check('empuje', xRel - x0 > 30 and xGlide - xRel > 5 and still and wallOk,
        ('empujado 1 s: +%.0f px; suelto, se desliza +%.0f px más; se para=%s (x final %.0f); sin pasar la pared=%s'):format(
            xRel - x0, xGlide - xRel, tostring(still), b.x, tostring(wallOk)))
end

function cases.nadando()
    local level, es = room({ pool = true, entities = { berg(14, 6) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 3)
    local pa = PlayerAdventure:new(b:getOuterBounds().x - 40, SURF + 20)
    run(level, es, { pa }, 0.2)
    local x0 = b.x
    -- (nada hacia él dando brazadas para no hundirse por debajo)
    local k = 0
    run(level, es, { pa }, 1.5, nil, nil, function()
        k = k + 1
        stub.state.right = true
        if k % 18 == 0 then stub.state.jump_pressed, stub.state.jump = true, true end
    end)
    check('nadando', pa.inWater and b.x - x0 > 10, ('nadando contra él (en el agua=%s): +%.0f px'):format(tostring(pa.inWater), b.x - x0))
end

function cases.viento()
    local level, es = room({ pool = true, entities = { berg(12, 6) } })
    local b = find(es, 'iceberg')
    run(level, es, {}, 3)
    local x0 = b.x
    run(level, es, {}, 14, nil, windAll(300))
    local right = b:getOuterBounds().x + b.outerW
    local atWall = math.abs(right - (W - 1) * T) < 1.5
    run(level, es, {}, 1)
    local x1 = b.x
    run(level, es, {}, 4)
    check('viento', b.x > x0 and atWall and math.abs(b.x - x1) < 0.01 and b.vx == 0,
        ('con aire a 300 px/s: de x %.0f a la pared (borde %.1f, pared %d: %s); sin aire quieto (%.3f px)'):format(
            x0, right, (W - 1) * T, tostring(atWall), math.abs(b.x - x1)))
end

function cases.choque()
    local level, es = room({ pool = true, entities = { berg(9, 6), berg(17, 6) } })
    local a, c = find(es, 'iceberg', 1), find(es, 'iceberg', 2)
    run(level, es, {}, 3)
    local c0 = c.x
    a.vx = 400
    local overlap = 0
    run(level, es, {}, 5, function()
        local ab, cb = a:getOuterBounds(), c:getOuterBounds()
        overlap = math.max(overlap, ab.x + ab.w - cb.x)
    end)
    local ab, cb = a:getOuterBounds(), c:getOuterBounds()
    check('choque', overlap <= 0.5 and math.abs(ab.x + ab.w - cb.x) < 2 and a.vx == 0 and math.abs(c.x - c0) < 1,
        ('lanzado a 400 px/s: se para a %.1f px del otro (se mete %.1f px como mucho); el otro se movió %.1f px'):format(
            cb.x - (ab.x + ab.w), math.max(0, overlap), math.abs(c.x - c0)))
end

function cases.caja_encima()
    -- (el iceberg ya casi flotando — fila 11 — y la caja encima desde el principio)
    local level, es = tideRoom({ { type = 'box', col = 13, row = 10, props = {} } }, { width = 4, capacity = 4 }, 11)
    local b, box = find(es, 'iceberg'), find(es, 'box')
    run(level, es, {}, 1)
    local off0 = box.x - b.x
    b.vx = 120
    local gap, drift = 0, 0
    local k = 0
    run(level, es, {}, 8, function()
        k = k + 1
        if os.getenv('DEBUG') and k % 20 == 0 then print(('%.2f berg x %.1f top %.1f vy %.1f | box x %.1f bottom %.1f st %s og %s'):format(k / 60, b.x, top(b), b.vy, box.x, box.y + T / 2, box.state, tostring(box.onGround))) end
        gap = math.max(gap, math.abs(box.y + T / 2 - top(b)))
        drift = math.max(drift, math.abs(box.x - b.x - off0))
    end)
    check('caja_encima', box.state == 'rest' and gap <= 4 and drift <= 4,
        ('la caja va encima mientras se desliza y sube / baja la marea: separación ≤ %.1f px, se corre ≤ %.1f px'):format(gap, drift))
end

-- Un jugador metido en el agua de la sala `level` (en medio de la charca, a media altura)
local function swimmer(level, x)
    local pa = PlayerAdventure:new(x or 14 * T, 9 * T)
    pa.invT = 0
    return pa
end
function cases.frio()
    local N = 2
    local level, es = room({ noShore = true, entities = { flood({ startLevel = 10, maxLevel = 10, cold = N }) } })
    local pa = swimmer(level)
    local t, iceAt, maxFrost = 0, nil, 0
    run(level, es, { pa }, 3, function()
        t = t + DT
        maxFrost = math.max(maxFrost, pa.frostT or 0)
        if (pa.iceT or 0) > 0 and not iceAt then iceAt = t; return true end
    end)
    local okIce = iceAt and iceAt >= N - 0.05 and iceAt <= N + 0.1
    -- fuera del agua el contador vuelve a 0
    local pb = swimmer(level)
    run(level, es, { pb }, 1)
    local mid = pb.frostT
    pb.x, pb.y, pb.vx, pb.vy = 14 * T, 1.5 * T, 0, 0                -- (fuera: encima del agua, cae)
    level.floods[1].hi, level.floods[1].lo = 7, 7                  -- (el agua baja: superficie en la fila 6)
    Floods.setTime(level, level.floodTime)
    step(level, es, { pb })
    local out = pb.frostT
    -- vuelve a entrar: empieza de 0 (no se congela antes de N s)
    level.floods[1].hi, level.floods[1].lo = 10, 10
    Floods.setTime(level, level.floodTime)
    pb.x, pb.y = 14 * T, 9 * T
    local t2, ice2 = 0, nil
    run(level, es, { pb }, 3, function() t2 = t2 + DT; if (pb.iceT or 0) > 0 and not ice2 then ice2 = t2; return true end end)
    -- machacando sale del hielo y, dentro del agua, vuelve a empezar y se congela otra vez a los N s
    local frees, t3, ice3, k = nil, 0, nil, 0
    run(level, es, { pb }, 6, function()
        t3 = t3 + DT
        if not frees and (pb.iceT or 0) <= 0 then frees = t3 end
        if frees and not ice3 and (pb.iceT or 0) > 0 then ice3 = t3 - frees; return true end
    end, nil, function() k = k + 1; if not frees and k % 4 == 0 then stub.state.jump_pressed = true end end)
    -- agua normal: nunca
    local level2, es2 = room({ noShore = true, entities = { flood({ startLevel = 10, maxLevel = 10 }) } })
    local pc = swimmer(level2)
    local never = true
    run(level2, es2, { pc }, 6, function() if (pc.iceT or 0) > 0 or (pc.frostT or 0) > 0 then never = false end end)
    -- agua de casillas con la clave del nivel `coldWater`
    local level3, es3 = room({ pool = true, coldWater = 1.5 })
    local pd = swimmer(level3)
    local t4, ice4 = 0, nil
    run(level3, es3, { pd }, 3, function() t4 = t4 + DT; if (pd.iceT or 0) > 0 and not ice4 then ice4 = t4; return true end end)
    check('frio', okIce and mid > 0.9 and out == 0 and ice2 and ice2 >= N - 0.05 and frees and ice3 and math.abs(ice3 - N) < 0.15
        and never and ice4 and math.abs(ice4 - 1.5) < 0.1,
        ('inundación helada %d s: congelado a los %s s; 1 s dentro (%.2f) y fuera → %.2f; al volver a entrar, a los %s s; machacando sale a los %s s y se vuelve a congelar %s s después; agua normal nunca=%s; agua de casillas con coldWater 1,5 → a los %s s'):format(
            N, tostring(iceAt and ('%.2f'):format(iceAt)), mid, out, tostring(ice2 and ('%.2f'):format(ice2)),
            tostring(frees and ('%.2f'):format(frees)), tostring(ice3 and ('%.2f'):format(ice3)), tostring(never),
            tostring(ice4 and ('%.2f'):format(ice4))))
end

function cases.red()
    -- estado propio: frostT de ida y vuelta
    local a = PlayerAdventure:new(100, 100)
    a.frostT = 1.25
    local s = P.packOwnState(a)
    local bb = PlayerAdventure:new(0, 0)
    P.applyOwnState(s, bb)
    local okPack = bb.frostT == 1.25 and P.isValidOwnState(s)
    -- predicción: el "servidor" y el "cliente" con los mismos inputs; el cliente se corrige con el estado propio cada
    -- 10 pasos (como la reconciliación) y nunca se separa: frío, hielo y machacar incluidos
    local lvS, esS = room({ noShore = true, entities = { flood({ startLevel = 10, maxLevel = 10, cold = 1 }) } })
    local lvC, esC = room({ noShore = true, entities = { flood({ startLevel = 10, maxLevel = 10, cold = 1 }) } })
    local sv, cl = swimmer(lvS), swimmer(lvC)
    local diff, iced = 0, false
    for i = 1, 300 do
        local mash = i > 80 and i % 5 == 0
        step(lvS, esS, { sv }, nil, function() stub.state.jump_pressed = mash end)
        step(lvC, esC, { cl }, nil, function() stub.state.jump_pressed = mash end)
        if (sv.iceT or 0) > 0 then iced = true end
        diff = math.max(diff, math.abs(sv.frostT - cl.frostT), math.abs((sv.iceT or 0) - (cl.iceT or 0)), math.abs(sv.y - cl.y))
        if i % 10 == 0 then P.applyOwnState(P.packOwnState(sv), cl) end
    end
    -- el iceberg: lo que manda el servidor (x, y, estado + netPack) lo ve el cliente y lo dibuja en cada estado
    local level, es = room({ pool = true, entities = { berg(12, 6, { width = 5, height = 2 }) } })
    local srv = find(es, 'iceberg')
    run(level, es, {}, 2)
    local _, es2 = room({ pool = true, entities = { berg(12, 6, { width = 5, height = 2 }) } })
    local cli = find(es2, 'iceberg')
    local pk = srv:netPack()
    cli.x, cli.y, cli.state = srv.x, srv.y, srv.state
    cli:netApply(pk, pk, 1)
    local drawn = true
    for _, stt in ipairs({ 'float', 'warn', 'sunk', 'ground' }) do
        cli.state = stt
        local ok = pcall(cli.render, cli, 0, 0)
        drawn = drawn and ok
    end
    local cb, sb = cli:getOuterBounds(), srv:getOuterBounds()
    local okBerg = cli.clientView and cb.w == 5 * T and cb.h == 2 * T and cb.x == sb.x and cb.y == sb.y and drawn
    -- la marea no viaja: Floods.netPack no la manda y un cliente con solo el reloj tiene la misma agua
    local lvT = tideRoom()
    local lvT2 = tideRoom()
    local same = 0
    for k = 1, 600 do
        Floods.advance(lvT, DT)
        Floods.setTime(lvT2, k * DT)
        same = math.max(same, math.abs(lvT.floods[1].surf - lvT2.floods[1].surf))
    end
    check('red', okPack and diff < 1e-6 and iced and okBerg and Floods.netPack(lvT, P.TICK_DT) == nil and same < 1e-6,
        ('estado propio frostT=%s (válido=%s); cliente predicho vs servidor: diferencia %.1e (se congeló=%s); iceberg 5x2 en el cliente: misma caja=%s, se dibuja en sus 4 estados=%s; marea: netPack=%s, agua del cliente igual (%.1e)'):format(
            tostring(bb.frostT), tostring(P.isValidOwnState(s)), diff, tostring(iced), tostring(okBerg), tostring(drawn),
            tostring(Floods.netPack(lvT, P.TICK_DT)), same))
end

function cases.editor()
    local Model = require 'src/editor/EditorModel'
    local _, _, data = room({ pool = true, coldWater = 4.5, entities = { berg(12, 6, { width = 6, capacity = 3 }),
        flood({ control = 'tide', tidePeriod = 30, tidePhase = 0.25, cold = 3 }) } })
    local m = Model.fromData(json.decode(json.encode(data)))
    local back = json.decode(m:encode())
    local lv = Level.fromData(back)
    local f = lv.floods[1]
    local bp
    for _, e in ipairs(back.entities) do if e.type == 'iceberg' then bp = e.props end end
    check('editor', back.coldWater == 4.5 and lv.coldWater == 4.5 and f.control == 'tide' and f.tidePeriod == 30
        and f.tidePhase == 0.25 and f.cold == 3 and bp and bp.width == 6 and bp.capacity == 3,
        ('guardado y cargado: coldWater=%s; inundación control=%s periodo=%s desfase=%s fría=%s; iceberg ancho=%s aguanta=%s'):format(
            tostring(back.coldWater), f.control, tostring(f.tidePeriod), tostring(f.tidePhase), tostring(f.cold),
            tostring(bp and bp.width), tostring(bp and bp.capacity)))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'flota', 'fondo', 'inundacion', 'marea', 'montar', 'peso', 'quieto', 'empuje', 'nadando', 'viento',
                          'choque', 'caja_encima', 'frio', 'red', 'editor' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
