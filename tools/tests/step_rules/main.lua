-- tools/tests/step_rules — ESCALONES BAJOS (src/world/level/StepUp.lua + PlayerCollision): andando por el suelo contra
-- un escalón de como mucho PlayerAdventure.STEP_MAX px (16) con sitio encima, el jugador se sube sin saltar.
--   altura       de un cuerpo (una plataforma de un solo sentido, como la cabina) a casillas que están 4/8/16 px más
--                arriba: sube, sin perder velocidad, y se ve subir poco a poco; 20/24/32 px: no
--   cuerpos      del suelo a un cuerpo sólido (como una caja) de 4/8/16 px: sube y se queda de pie en él; 20/32: no; a
--                uno de un solo sentido (como un platillo) de 8/16: sube; de 24: lo atraviesa como siempre
--   bloques      casillas: un bloque pequeño (32 px), una casilla (64) y una escalera de bloques pequeños no se suben
--                andando (todo lo hecho de casillas sigue igual)
--   techo        hace falta sitio para la cabeza: con 64 px libres encima del escalón no sube; con 96, sí
--   teleferico   de la estación a la cabina (4 px más abajo) y, al llegar al otro extremo, de la cabina a su estación
--                sin saltar; con STEP_MAX = 0 (lo de antes) se queda atascado en el borde
--   balanza      del platillo abajo del todo a un saliente de bloques pequeños 8 px más alto: sube sin saltar
--   estados      no sube en el aire, saltando, agachado, nadando, bajando por una plataforma, en un ground pound,
--                congelado, tragado ni quieto en la entrada de un jefe; y de verdad: cayendo junto al escalón y
--                andando por el fondo del agua no se sube
--   red          la predicción del cliente (Predictor, con reconciliación) hace lo mismo que el servidor: sin
--                correcciones al subir el escalón
--
--   tools/tests/run.sh step_rules   (CASE=nombre: solo ese)
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
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Predictor = require 'src/network/Predictor'
local Push = require 'src/world/systems/Push'
local TileTypes = require 'src/world/tiles/TileTypes'
local T = TILE_PX
local DT = 1 / 60
local STEP_MAX = PlayerAdventure.STEP_MAX

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H: suelo (fila H), techo (fila 1) y paredes; opts.blocks = { {c, r[, id]} }, opts.subtiles (lista del
-- JSON), opts.ents (colocaciones), opts.bodies (cuerpos de prueba), opts.water (las casillas vacías de las filas 2..H-1)
local function room(W, H, opts)
    opts = opts or {}
    local tiles = {}
    local water = TileTypes.byName.water.id
    for r = 1, H do
        local row = {}
        for c = 1, W do
            row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or ((opts.water and r > 1) and water or 0)
        end
        tiles[r] = row
    end
    for _, b in ipairs(opts.blocks or {}) do tiles[b[2]][b[1]] = b[3] or 1 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = opts.ents or {}, subtiles = opts.subtiles })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    level.testBodies = opts.bodies or {}
    return level, es
end

-- Cuerpo de prueba (quieto): una caja sólida (oneway = de un solo sentido)
local function body(x, y, w, h, oneway)
    return { solidFull = true, oneway = oneway or nil, alive = true, x = x, y = y, w = w, h = h,
             getOuterBounds = function(o, into)
                 local b = into or {}
                 b.x, b.y, b.w, b.h = o.x, o.y, o.w, o.h
                 return b
             end }
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end
local function feet(pa) local b = pa:getOuterBounds(); return b.y + b.h end
local function right(pa) return pa.x + pa.w / 2 end
-- Jugador con los pies en `fy` y el centro en x
local function player(level, x, fy)
    clearInput()
    local pa = PlayerAdventure:new(x, 0)
    pa.y = fy - feet(pa)
    pa.invT = 0
    level.players[#level.players + 1] = pa
    return pa
end

-- Un paso como AdventureState: cuerpos y aire → jugadores → nivel → entidades → interacciones
local function bodiesOf(level, es)
    local list = Entities.solidBodies(es)
    for _, b in ipairs(level.testBodies) do list[#list + 1] = b end
    return list
end
local function step(level, es, secs, each)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.solidBodies = bodiesOf(level, es)
        level.pushers = Push.collect(es)
        for _, pa in ipairs(level.players) do pa:update(DT, level) end
        level:update(DT)
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end

local function near(a, b) return math.abs(a - b) < 0.01 end

local cases = {}

-- Sala de las alturas: suelo a 576 (fila 10); la "estación" = casillas de la fila 9 desde la columna 11 (x 640, cara
-- de arriba 512); `k` px más abajo, una plataforma de un solo sentido de x 64 a 640 (como la cabina del teleférico)
local STATION_X, STATION_Y = 10 * T, 8 * T
local function heights(k, opts)
    opts = opts or {}
    local blocks = opts.blocks or {}
    for c = 11, 19 do blocks[#blocks + 1] = { c, 9 } end
    local deck = body(T, STATION_Y + k, STATION_X - T, 24, true)
    local level, es = room(20, 10, { blocks = blocks, subtiles = opts.subtiles, water = opts.water,
                                     bodies = { deck } })
    return level, es, deck
end

-- Anda a la derecha `secs` s y devuelve el jugador + lo que se vio: la mayor bajada / subida del pie DIBUJADO en un
-- paso (con stepVis) y cuándo stepVis volvió a 0
local function walk(level, es, pa, secs)
    step(level, es, 0.25)                         -- (se apoya)
    stub.state.right = true
    local drawn0 = feet(pa) + (pa.stepVis or 0)
    local maxJump, liftT, easeT, t = 0, nil, nil, 0
    step(level, es, secs, function()
        t = t + DT
        local d = feet(pa) + (pa.stepVis or 0)
        maxJump = math.max(maxJump, math.abs(d - drawn0))
        drawn0 = d
        if (pa.stepVis or 0) > 0 and not liftT then liftT = t end
        if liftT and not easeT and (pa.stepVis or 0) == 0 then easeT = t - liftT end
    end)
    clearInput()
    return { maxJump = maxJump, easeT = easeT }
end

function cases.altura()
    -- referencia: lo que anda en 1,5 s en llano (la misma sala sin escalón: la plataforma a la altura de la estación)
    local lv0, es0 = heights(0)
    local p0 = player(lv0, 400, STATION_Y)
    walk(lv0, es0, p0, 1.5)
    local flatX = p0.x
    for _, k in ipairs({ 4, 8, 16 }) do
        local level, es = heights(k)
        local pa = player(level, 400, STATION_Y + k)
        local seen = walk(level, es, pa, 1.5)
        local up = near(feet(pa), STATION_Y) and pa.onGround and pa.standBody == nil and pa.groundDef ~= nil
        local loss = flatX - pa.x
        check('altura', up and right(pa) > STATION_X + 40 and loss < 2 and seen.maxJump <= 6 and seen.easeT and seen.easeT <= 0.1,
              ('%2d px: sube a la estación (pies %.1f → %.0f, en la casilla), sin saltar; pierde %.2f px de 1,5 s andando; el pie dibujado se mueve como mucho %.1f px por paso y llega en %.3f s')
              :format(k, STATION_Y + k, feet(pa), loss, seen.maxJump, seen.easeT or -1))
    end
    -- desde PARADO pegado al escalón (empieza a andar despacio): sube sin volver a caer abajo ni despegarse del suelo
    for _, k in ipairs({ 4, 16 }) do
        local level, es = heights(k)
        local pa = player(level, 0, STATION_Y + k)
        pa.x = STATION_X - pa.w / 2
        step(level, es, 0.25)
        stub.state.right = true
        local f0, back, air = feet(pa), 0, 0
        step(level, es, 0.6, function()
            back = math.max(back, feet(pa) - f0); f0 = feet(pa)
            if not pa.onGround then air = air + 1 end
        end)
        clearInput()
        check('altura', near(feet(pa), STATION_Y) and back < 0.01 and air == 0,
              ('%2d px desde parado y pegado: sube (pies %.1f), nunca vuelve a bajar (%.2f px) ni se despega del suelo (%d pasos)')
              :format(k, feet(pa), back, air))
    end
    -- hacia la IZQUIERDA (la sala al revés: la estación a la izquierda, la plataforma a la derecha)
    do
        local blocks = {}
        for c = 2, 9 do blocks[#blocks + 1] = { c, 9 } end
        local deck = body(9 * T, STATION_Y + 8, 10 * T, 24, true)
        local level, es = room(20, 10, { blocks = blocks, bodies = { deck } })
        local pa = player(level, 12.5 * T, STATION_Y + 8)
        step(level, es, 0.25)
        stub.state.left = true
        step(level, es, 1.5)
        clearInput()
        check('altura', near(feet(pa), STATION_Y) and pa.x < 9 * T - 40 and pa.standBody == nil and pa.groundDef ~= nil,
              ('8 px andando a la izquierda: sube igual (pies %.1f, x %.0f)'):format(feet(pa), pa.x))
    end
    for _, k in ipairs({ 20, 24, 32 }) do
        local level, es = heights(k)
        local pa = player(level, 400, STATION_Y + k)
        walk(level, es, pa, 1.5)
        check('altura', right(pa) <= STATION_X + 0.01 and near(feet(pa), STATION_Y + k),
              ('%2d px: no sube (más de %d): se queda en el borde (lado %.1f ≤ %d, pies %.1f)'):format(k, STEP_MAX, right(pa), STATION_X, feet(pa)))
    end
end

function cases.cuerpos()
    local FLOOR = 9 * T
    for _, k in ipairs({ 4, 8, 16, 20, 32 }) do
        local b = body(STATION_X, FLOOR - k, 260, k)
        local level, es = room(20, 10, { bodies = { b } })
        local pa = player(level, 400, FLOOR)
        walk(level, es, pa, 1.5)
        if k <= STEP_MAX then
            check('cuerpos', pa.standBody == b and near(feet(pa), FLOOR - k) and right(pa) > STATION_X + 40,
                  ('sólido de %2d px: sube y se queda de pie en él (pies %.1f)'):format(k, feet(pa)))
        else
            check('cuerpos', right(pa) <= STATION_X + 0.01 and near(feet(pa), FLOOR),
                  ('sólido de %2d px: no sube, se para en su lado (%.1f)'):format(k, right(pa)))
        end
    end
    for _, k in ipairs({ 8, 16, 24 }) do
        local b = body(STATION_X, FLOOR - k, 260, k, true)
        local level, es = room(20, 10, { bodies = { b } })
        local pa = player(level, 400, FLOOR)
        walk(level, es, pa, 1.5)
        if k <= STEP_MAX then
            check('cuerpos', pa.standBody == b and near(feet(pa), FLOOR - k),
                  ('de un solo sentido de %2d px (un platillo): sube y se queda de pie en él (pies %.1f)'):format(k, feet(pa)))
        else
            check('cuerpos', near(feet(pa), FLOOR) and pa.standBody == nil and right(pa) > STATION_X + 40,
                  ('de un solo sentido de %2d px: lo atraviesa andando como siempre (pies %.1f)'):format(k, feet(pa)))
        end
    end
end

function cases.bloques()
    local FLOOR = 9 * T
    local function run(name, blocks, subtiles)
        local level, es = room(20, 10, { blocks = blocks, subtiles = subtiles })
        local pa = player(level, 400, FLOOR)
        walk(level, es, pa, 1.5)
        check('bloques', right(pa) <= STATION_X + 0.01 and near(feet(pa), FLOOR),
              ('%s: no se sube andando (lado %.1f ≤ %d, pies %.0f)'):format(name, right(pa), STATION_X, feet(pa)))
    end
    run('bloque pequeño (32 px)', {}, { { col = 11, row = 9, sub = 3, kind = 'solid' }, { col = 11, row = 9, sub = 4, kind = 'solid' } })
    run('casilla (64 px)', { { 11, 9 } })
    -- escalera de bloques pequeños: cada peldaño 32 px más alto y 32 px más allá
    run('escalera de bloques pequeños', { { 12, 9 }, { 13, 9 }, { 13, 8 } }, {
        { col = 11, row = 9, sub = 3, kind = 'solid' },
        { col = 11, row = 9, sub = 2, kind = 'solid' }, { col = 11, row = 9, sub = 4, kind = 'solid' },
        { col = 12, row = 8, sub = 3, kind = 'solid' },
        { col = 12, row = 8, sub = 2, kind = 'solid' }, { col = 12, row = 8, sub = 4, kind = 'solid' } })
end

function cases.techo()
    -- 8 px de escalón; techo sobre la estación con 64 px libres (fila 7): no cabe (el monstruo mide 75)
    local level, es = heights(8, { blocks = (function() local b = {} for c = 11, 19 do b[#b + 1] = { c, 7 } end return b end)() })
    local pa = player(level, 400, STATION_Y + 8)
    walk(level, es, pa, 1.5)
    check('techo', right(pa) <= STATION_X + 0.01 and near(feet(pa), STATION_Y + 8),
          ('64 px libres encima del escalón: no sube (lado %.1f, pies %.1f)'):format(right(pa), feet(pa)))
    -- con bloques pequeños en la mitad de arriba de la fila 7: 96 px libres → cabe
    local subs = {}
    for c = 11, 19 do subs[#subs + 1] = { col = c, row = 7, sub = 1, kind = 'solid' }; subs[#subs + 1] = { col = c, row = 7, sub = 2, kind = 'solid' } end
    local lv2, es2 = heights(8, { subtiles = subs })
    local pb = player(lv2, 400, STATION_Y + 8)
    walk(lv2, es2, pb, 1.5)
    check('techo', near(feet(pb), STATION_Y) and right(pb) > STATION_X + 40,
          ('96 px libres: sube (pies %.1f, lado %.1f)'):format(feet(pb), right(pb)))
end

-- El teleférico de verdad: cable de (6,4) a (12,4), con peso (`onWeight`), espera 3 s en cada extremo. La plataforma
-- queda 4 px bajo la cara de arriba de la fila 6 (las estaciones: columnas 2-4 y 14-17)
local function cablecarRoom()
    local blocks = {}
    for c = 2, 4 do blocks[#blocks + 1] = { c, 6 } end
    for c = 14, 17 do blocks[#blocks + 1] = { c, 6 } end
    return room(18, 10, { blocks = blocks, ents = { { type = 'cablecar', col = 6, row = 4,
        props = { path = { { col = 12, row = 4 } }, speed = 2, onWeight = true, back = false, stops = 3 } } } })
end
local function rideCable()
    local level, es = cablecarRoom()
    local cc = es[1]
    local ST = 5 * T
    local deckTop = cc.parts[1]:getOuterBounds({}).y
    local pa = player(level, 3 * T, ST)
    step(level, es, 0.25)
    -- de la estación a la cabina (más abajo: se baja sin más)
    local air, maxAir = 0, 0
    stub.state.right = true
    step(level, es, 1.2, function()
        if pa.onGround then air = 0 else air = air + 1; maxAir = math.max(maxAir, air) end
        return pa.standBody == cc.parts[1] and pa.x > 6 * T - 32
    end)
    clearInput()
    local boarded = pa.standBody == cc.parts[1]
    -- va al otro extremo y espera: entonces, a la derecha
    step(level, es, 8, function() return cc.state == 'waiting' and cc.u > 0 end)
    local arrived = cc.state == 'waiting'
    stub.state.right = true
    local jumped = false
    step(level, es, 1.5, function() if pa.vy < -1 then jumped = true end end)
    clearInput()
    return { pa = pa, deckTop = deckTop, ST = ST, boarded = boarded, arrived = arrived, jumped = jumped, maxAir = maxAir }
end

function cases.teleferico()
    local r = rideCable()
    local pa = r.pa
    check('teleferico', r.boarded and r.maxAir <= 8,
          ('la plataforma queda %.0f px bajo la estación; de la estación a la cabina se baja sin más (en el aire como mucho %d pasos)')
          :format(r.deckTop - r.ST, r.maxAir))
    check('teleferico', r.arrived and pa.onGround and pa.standBody == nil and near(feet(pa), r.ST) and pa.x > 14 * T and not r.jumped,
          ('al otro extremo, de la cabina a la estación ANDANDO, sin saltar (pies %.1f = %d, x %.0f)'):format(feet(pa), r.ST, pa.x))
    -- lo de antes (sin escalones): se queda atascado en el borde
    PlayerAdventure.STEP_MAX = 0
    local ok, old = pcall(rideCable)
    PlayerAdventure.STEP_MAX = STEP_MAX
    if not ok then error(old, 0) end
    check('teleferico', old.arrived and old.pa.standBody ~= nil and right(old.pa) <= 13 * T + 0.01,
          ('con STEP_MAX = 0 (antes de 2026-10-29) se queda en la cabina contra el borde (lado %.1f ≤ %d): por eso hacía falta saltar')
          :format(right(old.pa), 13 * T))
end

function cases.balanza()
    -- La Balanza (span 6, drop 5, travel 2): con peso en el platillo izquierdo, este baja del todo
    local SC = { type = 'scale', col = 14, row = 2, props = { span = 6, drop = 5, travel = 2 } }
    local function build(subs, blocks, box)
        local ents = { SC }
        if box then ents[2] = { type = 'box', col = 12, row = 6 } end      -- (una caja grande en el mismo platillo)
        return room(28, 14, { ents = ents, subtiles = subs, blocks = blocks })
    end
    -- medir dónde queda el platillo abajo
    local level, es = build()
    local pan = es[1].pans[1]
    local b0 = pan:getOuterBounds({})
    local pa = player(level, b0.x + b0.w / 2, b0.y)
    step(level, es, 4)
    local b = pan:getOuterBounds({})
    local top = b.y
    -- saliente de bloques pequeños 8 px más arriba, a la izquierda del platillo (hasta su borde)
    local ledge = top - 8
    local col1 = math.floor(b.x / T)                    -- (columnas 2..col1, enteras a la izquierda del platillo)
    local subs, blocks = {}, {}
    local r = math.floor(ledge / T) + 1
    local half = (ledge % T) >= T / 2
    for c = 2, col1 do
        if half then
            subs[#subs + 1] = { col = c, row = r, sub = 3, kind = 'solid' }; subs[#subs + 1] = { col = c, row = r, sub = 4, kind = 'solid' }
        else blocks[#blocks + 1] = { c, r } end
        for rr = r + 1, 13 do blocks[#blocks + 1] = { c, rr } end
    end
    local okGeo = (ledge % (T / 2)) == 0 and col1 * T <= b.x
    for _, box in ipairs({ true, false }) do
        local lv2, es2 = build(subs, blocks, box)
        local pan2 = es2[1].pans[1]
        local pb = player(lv2, b.x + 40, pan2:getOuterBounds({}).y)
        step(lv2, es2, 4)
        local onPan = pb.standBody == pan2 and near(pan2:getOuterBounds({}).y, top)
        stub.state.left = true
        local rise = 0
        step(lv2, es2, 1.5, function() rise = math.max(rise, ledge - feet(pb)) end)
        clearInput()
        local landed = okGeo and onPan and near(feet(pb), ledge) and pb.standBody == nil and pb.groundDef ~= nil
        if box then
            check('balanza', landed and rise < 0.01,
                  ('platillo abajo del todo (cara %.0f; una caja lo mantiene abajo), saliente de bloques pequeños 8 px más alto: del platillo al saliente andando (pies %.1f = %.0f), sin saltito')
                  :format(top, feet(pb), ledge))
        else
            -- (sin la caja el platillo vuelve a subir al quitarse el peso y recoge el pie de detrás — Scale:sweepPlayers,
            -- de antes —: un saltito de lo que suba mientras aún lo pisa)
            check('balanza', landed,
                  ('solo con el jugador encima: también llega al saliente andando (pies %.1f); el platillo, al subir sin peso, lo levanta %.0f px (Scale:sweepPlayers, como antes)')
                  :format(feet(pb), rise))
        end
    end
end

function cases.estados()
    -- canStepUp en cada estado
    local level = heights(8)
    local pa = player(level, 400, STATION_Y + 8)
    pa.onGround, pa.vy = true, 0
    local base = pa:canStepUp()
    local states = {
        { 'en el aire', function(p) p.onGround = false end },
        { 'saltando', function(p) p.vy = -400 end },
        { 'agachado', function(p) p.crouching = true end },
        { 'nadando', function(p) p.inWater = true end },
        { 'bajando por una plataforma', function(p) p.dropping = true end },
        { 'ground pound', function(p) p.gpPhase = 'fall' end },
        { 'congelado', function(p) p.iceT = 1 end },
        { 'tragado', function(p) p.gulped = true end },
        { 'entrada de un jefe', function(p) p.frozen = true end },
    }
    local bad = {}
    for _, s in ipairs(states) do
        local p = PlayerAdventure:new(400, 0)
        p.onGround, p.vy = true, 0
        s[2](p)
        if p:canStepUp() then bad[#bad + 1] = s[1] end
    end
    check('estados', base and #bad == 0, ('de pie sí; ' .. (#bad == 0 and 'en ninguno de los %d estados' or ('FALLA en: ' .. table.concat(bad, ', '))))
          :format(#states))
    -- cayendo junto al escalón (sin la plataforma: pies 8 px bajo la estación), andando hacia él: no se sube
    local lv, es = room(20, 10, { blocks = (function() local b = {} for c = 11, 19 do b[#b + 1] = { c, 9 } end return b end)() })
    local pf = player(lv, STATION_X - 20, STATION_Y + 8)
    pf.onGround, pf.vy = false, 0
    stub.state.right = true
    local stood = false
    step(lv, es, 0.6, function() if pf.onGround and near(feet(pf), STATION_Y) then stood = true end end)
    clearInput()
    check('estados', not stood and right(pf) <= STATION_X + 0.01,
          ('cayendo junto a un escalón de 8 px andando hacia él: no se sube (cae al suelo, pies %.0f)'):format(feet(pf)))
    -- andando por el fondo del agua contra un escalón de 8 px: no se sube
    local lw, ew = heights(8, { water = true })
    local pw = player(lw, 400, STATION_Y + 8)
    local seenWater = false
    step(lw, ew, 0.3)
    stub.state.right = true
    step(lw, ew, 1.5, function() if pw.inWater then seenWater = true end end)
    clearInput()
    check('estados', seenWater and right(pw) <= STATION_X + 0.01,
          ('nadando por el fondo contra un escalón de 8 px: no se sube (lado %.1f)'):format(right(pw)))
end

function cases.red()
    -- el "servidor" y el cliente (Predictor: predice cada tick y se reconcilia con el estado propio que llega con 4
    -- ticks de retraso) en la sala del escalón de 8 px: deben hacer lo mismo, sin correcciones
    local lvS, esS = heights(8)
    local lvC, esC = heights(8)
    local sv = player(lvS, 400, STATION_Y + 8)
    lvS.players = { sv }
    local cl = PlayerAdventure:new(sv.x, sv.y)
    cl.invT = 0
    local pred = Predictor.new(cl, lvC)
    local own, maxErr, maxDiff = {}, 0, 0
    local srvStub = P.newInputStub()
    for i = 1, 150 do
        local bits = P.encodeInput(false, i > 15, false, false, false, false, false, false)
        lvC.solidBodies = bodiesOf(lvC, esC)
        local seq = pred:tick(bits)
        lvS.solidBodies = bodiesOf(lvS, esS)
        P.decodeInput(bits, srvStub.state)
        local real = Input
        Input = srvStub
        sv:update(P.TICK_DT, lvS)
        Input = real
        own[seq] = P.packOwnState(sv)
        if seq > 4 then
            pred:reconcile(seq - 4, own[seq - 4], 0)
            maxErr = math.max(maxErr, pred.lastError or 0)
        end
        maxDiff = math.max(maxDiff, math.abs(sv.x - cl.x), math.abs(sv.y - cl.y))
    end
    check('red', near(feet(sv), STATION_Y) and maxErr < 0.01 and maxDiff < 0.01,
          ('escalón de 8 px: servidor arriba (pies %.1f); cliente: corrección máxima %.4f px, diferencia máxima %.4f px'):format(feet(sv), maxErr, maxDiff))
    -- el teleférico: servidor y cliente con su cabina (las entidades al mismo paso); se sube en la estación, va al otro
    -- extremo y se baja a la estación andando. Se miran las correcciones al bajarse (la cabina quieta esperando)
    local lS, eS = cablecarRoom()
    local lC, eC = cablecarRoom()
    local s2 = player(lS, 3 * T, 5 * T)
    local c2 = PlayerAdventure:new(s2.x, s2.y)
    lC.players = { c2 }
    local pr = Predictor.new(c2, lC)
    local own2, err2, diff2, phase, waitN = {}, 0, 0, 1, 0
    for _ = 1, 60 * 12 do
        local ccS = eS[1]
        if phase == 1 and s2.standBody == ccS.parts[1] and s2.x > 6 * T - 32 then phase = 2 end
        if phase == 2 and ccS.state == 'waiting' and ccS.u > 0 then phase = 3 end
        local bits = P.encodeInput(false, phase ~= 2, false, false, false, false, false, false)
        lC.solidBodies = bodiesOf(lC, eC)
        local seq = pr:tick(bits)
        lC:update(P.TICK_DT)
        for _, e in ipairs(eC) do if e.alive then e:update(P.TICK_DT, lC) end end
        lS.solidBodies = bodiesOf(lS, eS)
        P.decodeInput(bits, srvStub.state)
        local real = Input
        Input = srvStub
        s2:update(P.TICK_DT, lS)
        Input = real
        lS:update(P.TICK_DT)
        for _, e in ipairs(eS) do if e.alive then e:update(P.TICK_DT, lS) end end
        own2[seq] = P.packOwnState(s2)
        -- (se mira desde que la cabina lleva 8 pasos quieta: al pararse y arrancar, la re-simulación con la cabina donde
        -- está AHORA ya corregía unos px antes de los escalones — lo de ir montado en algo que se mueve, de siempre —)
        if phase == 3 then waitN = waitN + 1 end
        if seq > 4 then
            pr:reconcile(seq - 4, own2[seq - 4], 0)
            if waitN > 8 then err2 = math.max(err2, pr.lastError or 0) end
        end
        if waitN > 8 then
            diff2 = math.max(diff2, math.abs(s2.x - c2.x), math.abs(s2.y - c2.y))
            if waitN > 90 then break end
        end
    end
    check('red', phase == 3 and near(feet(s2), 5 * T) and s2.standBody == nil and err2 < 0.01 and diff2 < 0.01,
          ('teleférico: de la cabina a la estación (servidor pies %.1f, en la casilla); cliente al bajarse: corrección máxima %.4f px, diferencia máxima %.4f px')
          :format(feet(s2), err2, diff2))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'altura', 'cuerpos', 'bloques', 'techo', 'teleferico', 'balanza', 'estados', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
