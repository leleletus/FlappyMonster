-- tools/tests/flappy_flight — el VUELO de los niveles Flappy (src/player/PlayerFlight.lua; paso 2 de
-- docs/design/flappy-prequel.md), caso a caso en niveles hechos en el arnés:
--   aleteo      SALTAR pone la velocidad del aleteo (FLY_FLAP), sin límite de aleteos; sin pulsar cae con su gravedad
--               (FLY_GRAVITY)
--   ventana     sin tocar nada va con la ventana de la cámara automática; a la derecha no la adelanta; a la izquierda el
--               borde lo lleva (no se queda atrás ni muere); en pantalla, a la derecha FLY_SPD y a la izquierda FLY_SPD +
--               lo que avanza la ventana
--   pilar       volar contra un pilar quita 1 de vida UNA vez y lo atraviesa (invulnerable)
--   suelo       tocar el suelo quita 1 y lo devuelve hacia arriba de un bote
--   reaparece   en un nivel Flappy se reaparece en el aire, en una casilla libre (no dentro de un pilar)
--   exclusivo   un pilar en un nivel normal es un error del editor (validate); en un nivel Flappy, no
--   carga       las cargas de aleteo suben el medidor hasta CHARGE_MAX (5); morir y reaparecer la conserva
--   ataque      ESPECIAL sin carga: nada; con carga: una ráfaga con esa potencia que gasta toda la carga, atraviesa
--               pilares, mata a un enemigo y la para un bloque sólido
--   jaula       flappy enjaulado: una ráfaga con menos potencia que su mínimo no la abre (y se para); con más, la abre;
--               una ya liberada en una partida terminada sale vacía
--   muro        muro agrietado: sólido; una ráfaga más floja que su mínimo no lo rompe (y se para); con bastante, se rompe
--               y se pasa
--   normal      en un nivel normal el jugador NO vuela (salto de plataformas de siempre)
--   etapa       la etapa de prueba (assets/levels/_flappy_vuelo.json) se puede pasar: un piloto sencillo (aletea
--               cuando está por debajo del centro del hueco siguiente) llega a la meta sin morir
--
--   tools/tests/run.sh flappy_flight   (CASE=nombre: solo ese)
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
local AutoScroll = require 'src/world/systems/AutoScroll'
local Model = require 'src/editor/EditorModel'
local T = TILE_PX
local DT = 1 / 60
local Codec = require 'src/world/tiles/TileCodec'
local PILLAR, GRASS = Codec.encode(59), Codec.encode(17)
local PILLAR_ID = 59

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Nivel W x 11 con suelo en la fila 10-11; `pillars` = { {col, filaHuecoArriba, alto}, ... }; `scroll` = velocidad
local function stage(W, pillars, scroll, flappy, ents)
    local tiles = {}
    for r = 1, 11 do
        local row = {}
        for c = 1, W do row[c] = (r >= 10) and GRASS or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(pillars or {}) do
        for r = 1, 9 do if not (r >= p[2] and r < p[2] + p[3]) then tiles[r][p[1]] = PILLAR end end
    end
    local data = { name = 't', width = W, height = 11, playerStart = { 4, 5 }, tiles = tiles, entities = ents or {},
                   flappy = flappy ~= false or nil }
    if scroll then data.autoScroll = { startCol = 1, endCol = 0, speed = scroll, width = 20, margin = 0.6, countdown = 0 } end
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    level.liveEntities, level.players = es, {}
    return level
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end
local function player(level, x, y)
    clearInput()
    local pa = PlayerAdventure:new(x, y)
    pa.spawnX, pa.spawnY = x, y
    level.players[#level.players + 1] = pa
    return pa
end

-- Un paso como AdventureState: jugadores → nivel → cámara automática → interacciones
local function step(level, secs, each)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.solidBodies = Entities.solidBodies(level.liveEntities)
        for _, pa in ipairs(level.players) do pa:update(DT, level) end
        level:update(DT)
        for _, e in ipairs(level.liveEntities) do if e.alive then e:update(DT, level) end end
        AutoScroll.update(level, DT)
        for _, pa in ipairs(level.players) do Interactions.run(pa, level.liveEntities, {}) end
        if each and each() then return true end
    end
end

local cases = {}

function cases.aleteo()
    local level = stage(40, nil, nil)
    local pa = player(level, 8 * T, 5 * T)
    step(level, 0.05)
    stub.state.jump_pressed = true
    step(level, DT)
    local v1 = pa.vy
    step(level, 0.1)
    stub.state.jump_pressed = true                   -- (otro aleteo en el aire: siempre se puede)
    step(level, DT)
    local v2 = pa.vy
    local vA = pa.vy
    step(level, 0.2)
    local g = (pa.vy - vA) / 0.2
    local tol = PlayerAdventure.FLY_GRAVITY * DT * 2
    check('aleteo', pa.flight and math.abs(v1 - PlayerAdventure.FLY_FLAP) <= tol and math.abs(v2 - PlayerAdventure.FLY_FLAP) <= tol
          and math.abs(g - PlayerAdventure.FLY_GRAVITY) < PlayerAdventure.FLY_GRAVITY * 0.05,
          ('vuela=%s; aleteo %.0f y otro en el aire %.0f (FLY_FLAP %d); gravedad %.0f (FLY_GRAVITY %d)'):format(
           tostring(pa.flight), v1, v2, PlayerAdventure.FLY_FLAP, g, PlayerAdventure.FLY_GRAVITY))
end

-- Mantiene la altura (aletea al bajar de `y`)
local function hover(pa, y) if pa.y > y and pa.vy > -100 then stub.state.jump_pressed = true end end

function cases.ventana()
    local level = stage(200, nil, 200)
    local pa = player(level, 6 * T, 5 * T)
    local a = level.autoScroll
    step(level, 0.5, function() hover(pa, 5 * T) end)
    local rel0 = pa.x - a.x
    step(level, 2, function() hover(pa, 5 * T) end)
    local drift = math.abs((pa.x - a.x) - rel0)
    stub.state.right = true
    local maxR = 0
    step(level, 3, function() hover(pa, 5 * T); maxR = math.max(maxR, pa.x - a.x) end)
    -- (velocidad EN PANTALLA a cada lado, a media ventana: hacia atrás, FLY_SPD + lo que avanza la ventana)
    local function screenSpeed(dir)
        clearInput()
        step(level, 0.6, function() hover(pa, 5 * T); if pa.x - a.x > a.W / 2 + 40 then stub.state.left = true end end)
        clearInput()
        while pa.x - a.x > a.W / 2 do step(level, DT, function() hover(pa, 5 * T); stub.state.left = true end) end
        clearInput()
        while pa.x - a.x < a.W / 2 - 200 do step(level, DT, function() hover(pa, 5 * T); stub.state.right = true end) end
        clearInput()
        stub.state[dir] = true
        step(level, 0.4, function() hover(pa, 5 * T) end)
        local r0 = pa.x - a.x
        step(level, 0.25, function() hover(pa, 5 * T) end)
        clearInput()
        return math.abs((pa.x - a.x) - r0) / 0.25
    end
    local vR = screenSpeed('right')
    local vL = screenSpeed('left')
    SPEEDS = ('en pantalla: derecha %.0f, izquierda %.0f px/s'):format(vR, vL)
    SPEED_OK = math.abs(vR - PlayerAdventure.FLY_SPD) < 25 and math.abs(vL - (PlayerAdventure.FLY_SPD + a.speed)) < 25
    stub.state.right = false
    stub.state.left = true
    local minL = math.huge
    step(level, 6, function() hover(pa, 5 * T); minL = math.min(minL, pa.x - a.x) end)
    clearInput()
    local ob = pa:getOuterBounds()
    check('ventana', SPEED_OK and a.state == 'run' and drift < 8 and maxR <= a.W + 1 and minL >= ob.w / 2 - a.speed * DT - 1 and not pa.dying,
          (SPEEDS .. '; quieto se aleja %.1f px de su sitio en la ventana; a la derecha llega a %.0f de %d; a la izquierda baja a %.0f (el borde, menos lo que avanza la ventana en un paso); vivo=%s'):format(
           drift, maxR, a.W, minL, tostring(not pa.dying)))
end

function cases.pilar()
    -- (un pilar entero en la columna 12, sin hueco a la altura del jugador)
    local level = stage(40, { { 12, 10, 0 } }, nil)
    local pa = player(level, 8 * T, 5 * T)
    local hp0 = pa.hp
    stub.state.right = true
    local hits, lastHp = 0, pa.hp
    step(level, 2, function()
        hover(pa, 5 * T)
        if pa.hp < lastHp then hits = hits + 1 end
        lastHp = pa.hp
    end)
    clearInput()
    check('pilar', hits == 1 and pa.hp == hp0 - 1 and pa.x > 13 * T and not pa.dying,
          ('golpes %d (vida %d → %d); pasa al otro lado: x %.0f (pilar acaba en %d)'):format(hits, hp0, pa.hp, pa.x, 12 * T))
end

function cases.suelo()
    local level = stage(40, nil, nil)
    local pa = player(level, 8 * T, 7 * T)
    local hp0, minVy, hitAt = pa.hp, 0, nil
    step(level, 1.2, function()
        if pa.hp < hp0 and not hitAt then hitAt = true end
        if hitAt then minVy = math.min(minVy, pa.vy) end
    end)
    check('suelo', pa.hp == hp0 - 1 and minVy < -300 and not pa.dying,
          ('vida %d → %d; bote hacia arriba %.0f px/s'):format(hp0, pa.hp, minVy))
end

function cases.reaparece()
    -- (pilar en la columna donde se reaparece: un tercio de la ventana, columna 7)
    local level = stage(60, { { 7, 2, 2 } }, 200)
    local pa = player(level, 6 * T, 3 * T)
    step(level, 0.1, function() hover(pa, 3 * T) end)
    local x, y = AutoScroll.respawnPoint(level)
    local def = level:getDef(math.floor(x / T) + 1, math.floor(y / T) + 1)
    check('reaparece', x and def.collision == 'none' and not def.mat.contact and y < 9 * T,
          ('punto (%.0f, %.0f): casilla %s, por encima del suelo'):format(x or -1, y or -1, def.name))
end

function cases.exclusivo()
    local function warns(flappy)
        local m = Model.new and Model.new(20, 11) or nil
        if not m then
            m = Model.fromData({ name = 't', width = 20, height = 11, playerStart = { 2, 5 }, tiles = (function()
                local t = {}
                for r = 1, 11 do t[r] = {}; for c = 1, 20 do t[r][c] = 0 end end
                return t end)(), entities = {} }, nil)
        end
        m.tiles[3][10] = PILLAR
        m.flappy = flappy or nil
        local n = 0
        for _, w in ipairs(m:validate()) do if w[1] == 'error' and w[2]:find('exclusiva', 1, true) then n = n + 1 end end
        return n
    end
    local normal, flappy = warns(false), warns(true)
    check('exclusivo', normal == 1 and flappy == 0, ('pilar: error en un nivel normal=%d; en uno Flappy=%d'):format(normal, flappy))
    -- (una ENTIDAD exclusiva de Flappy: un tipo de usar y tirar registrado aquí)
    local ET = require 'src/world/entities/base/EntityTypes'
    local Entity = require 'src/world/entities/base/Entity'
    if not ET.get('_t_flappy') then
        ET.register({ name = '_t_flappy', label = 'prueba', category = 'Flappy', flappyOnly = true,
                      class = Entity.extend(Entity, {}) })
    end
    local function entWarns(fl)
        local m = Model.new(20, 11)
        m.entities[#m.entities + 1] = { type = '_t_flappy', col = 10, row = 5, props = {} }
        m.flappy = fl or nil
        local n = 0
        for _, w in ipairs(m:validate()) do if w[1] == 'error' and w[2]:find('exclusiv', 1, true) then n = n + 1 end end
        return n
    end
    local en, ef = entWarns(false), entWarns(true)
    check('exclusivo', en == 1 and ef == 0, ('entidad: error en un nivel normal=%d; en uno Flappy=%d'):format(en, ef))
end

function cases.normal()
    local level = stage(40, nil, nil, false)
    local pa = player(level, 8 * T, 8 * T)
    step(level, 0.6)
    stub.state.jump_pressed = true
    step(level, DT)
    local v1 = pa.vy
    check('normal', not pa.flight and math.abs(v1 - ADV_JUMP_VEL) < 60,
          ('vuela=%s; salta %.0f (ADV_JUMP_VEL %d)'):format(tostring(pa.flight), v1, ADV_JUMP_VEL))
end

-- El hueco del siguiente pilar por delante de x: centro en px (nil = no hay más)
local function nextGap(level, x)
    local c0 = math.floor(x / T) + 1
    for c = c0, level.tileW do
        if level:getTile(c, 1) == PILLAR_ID or level:getTile(c, 9) == PILLAR_ID then
            local top, bot
            for r = 1, 9 do
                if level:getTile(c, r) ~= PILLAR_ID then top = top or r; bot = r end
            end
            if top then return (top - 1) * T, bot * T, c end
        end
    end
end

local function runStage(path)
    local level = Level.new(path)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    level.liveEntities, level.players = es, {}
    local sx, sy = level:getSpawnPx()
    local pa = player(level, sx, sy)
    local hp0, deaths, done, t = pa.hp, 0, false, 0
    step(level, 90, function()
        t = t + DT
        if pa.dying then deaths = deaths + 1; return true end
        local top, bot = nextGap(level, pa.x - 40)
        local target = top and (top + bot) / 2 + 20 or 5 * T
        if pa.y > target and pa.vy > -60 then stub.state.jump_pressed = true end
        stub.state.right = level.autoScroll.state == 'stop'      -- (la cámara se para al final: a la meta volando)
        local ob = pa:getOuterBounds()
        if level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'finish') then done = true; return true end
    end)
    clearInput()
    check('etapa', level.flappy and level.autoScroll and done and deaths == 0,
          ('%s: nivel Flappy=%s con cámara=%s; llega a la meta SIN CARGA=%s en %.1f s; vida %d → %d; muertes %d'):format(
           path:match('[^/]+$'), tostring(level.flappy), tostring(level.autoScroll ~= nil), tostring(done), t, hp0, pa.hp, deaths))
end

-- La etapa de prueba y las del Valle: el piloto sencillo, SIN usar el ataque especial, llega a la meta sin morir (la ruta
-- principal nunca depende de romper un muro)
function cases.etapa()
    runStage('assets/levels/_flappy_vuelo.json')
    for _, id in ipairs(require('src/flappy/Zones').get(1).stages) do runStage('assets/levels/' .. id .. '.json') end
end

function cases.carga()
    local ents = {}
    for i = 0, 5 do ents[#ents + 1] = { type = 'flapcharge', col = 10 + i * 2, row = 5, props = {} } end
    local level = stage(40, nil, nil, true, ents)
    local pa = player(level, 8 * T, 4.5 * T)
    local c0 = pa.charge
    stub.state.right = true
    step(level, 3, function() hover(pa, 4.5 * T) end)
    clearInput()
    local got = pa.charge
    pa:die(nil, true)
    step(level, 2)
    pa:respawn()
    check('carga', c0 == 0 and got == PlayerAdventure.CHARGE_MAX and PlayerAdventure.CHARGE_MAX == 5 and pa.charge == got,
          ('al empezar %s; tras 6 cargas %s (máximo %s); tras morir y reaparecer %s'):format(
           tostring(c0), tostring(got), tostring(PlayerAdventure.CHARGE_MAX), tostring(pa.charge)))
end

function cases.ataque()
    -- sin carga: nada
    local level = stage(40, nil, nil, true)
    local pa = player(level, 8 * T, 4.5 * T)
    step(level, 0.1, function() hover(pa, 4.5 * T) end)
    stub.state.special_pressed = true
    step(level, DT)
    local none = #(pa.bursts or {}) == 0 and pa.charge == 0
    -- con carga 3: una ráfaga, la carga a 0, un Gummy volando 4 casillas delante muere; un pilar en medio no la para
    local lv2 = stage(40, { { 10, 10, 0 } }, nil, true,
        { { type = 'gummy', col = 13, row = 5, props = { movement = 'fly', speed = 0 } } })
    local pa2 = player(lv2, 7 * T, 4.5 * T)
    pa2.charge = 3
    local g = lv2.liveEntities[1]
    step(lv2, 0.1, function() hover(pa2, 4.5 * T) end)
    stub.state.special_pressed = true
    step(lv2, DT)
    local fired = #(pa2.bursts or {}) == 1 and pa2.charge == 0 and pa2.bursts[1].power == 3
    step(lv2, 1, function() hover(pa2, 4.5 * T) end)
    local killed = tostring(g.state):find('dead') ~= nil or not g.alive
    -- un bloque sólido 3 casillas delante la para
    local lv3 = stage(40, nil, nil, true)
    for r = 1, 9 do lv3.tiles[r][12] = require('src/world/tiles/TileCodec').encode(1) end
    local pa3 = player(lv3, 8 * T, 4.5 * T)
    pa3.charge = 2
    step(lv3, 0.1, function() hover(pa3, 4.5 * T) end)
    stub.state.special_pressed = true
    step(lv3, DT)
    local b = pa3.bursts and pa3.bursts[1]
    local maxX = 0
    step(lv3, 1, function()
        hover(pa3, 4.5 * T)
        local bb = pa3.bursts and pa3.bursts[1]
        if bb then maxX = math.max(maxX, bb.x) end
    end)
    local stopped = b ~= nil and maxX <= 11 * T + 1 and #pa3.bursts == 0
    clearInput()
    check('ataque', none and fired and killed and stopped,
          ('sin carga no pasa nada=%s; con 3: una ráfaga de 3 y carga a 0=%s; el Gummy tras el pilar muere=%s; el bloque la para (llega a %.0f, bloque en %d)=%s'):format(
           tostring(none), tostring(fired), tostring(killed), maxX, 11 * T, tostring(stopped)))
end

-- Dispara con `power` contra lo que haya delante (a la altura y) y deja volar la ráfaga 1 s
local function shoot(level, pa, power, y)
    pa.charge = power
    step(level, 0.1, function() hover(pa, y) end)
    stub.state.special_pressed = true
    step(level, 1, function() hover(pa, y) end)
    clearInput()
end

function cases.jaula()
    local lv = stage(40, nil, nil, true, { { type = 'cage', col = 13, row = 5, props = { minCharge = 2 } } })
    local c = lv.liveEntities[1]
    local pa = player(lv, 7 * T, 4.5 * T)
    shoot(lv, pa, 1, 4.5 * T)
    local weak = c.state == 'closed' and not c.rescuedNow and #(pa.bursts or {}) == 0
    shoot(lv, pa, 3, 4.5 * T)
    local opened = c.state == 'open' and c.rescuedNow == true
    -- una jaula ya liberada en una partida TERMINADA (`freed`) sale vacía
    local lv2 = stage(40, nil, nil, true, { { type = 'cage', col = 13, row = 5, props = {} } })
    lv2.liveEntities[1].freed = true
    step(lv2, 0.1)
    local empty = lv2.liveEntities[1].state == 'empty'
    check('jaula', weak and opened and empty,
          ('mínimo 2 con potencia 1: cerrada y para la ráfaga=%s; con 3: abierta=%s; ya liberada: vacía=%s'):format(
           tostring(weak), tostring(opened), tostring(empty)))
end

function cases.muro()
    -- muro de 7 casillas de alto (filas 3..9) en la columna 12, carga mínima 3
    local lv = stage(40, nil, nil, true, { { type = 'crackwall', col = 12, row = 9, props = { minCharge = 3, rows = 7 } } })
    local w = lv.liveEntities[1]
    local pa = player(lv, 8 * T, 4.5 * T)
    stub.state.right = true
    step(lv, 1.5, function() hover(pa, 5.5 * T) end)
    clearInput()
    local blocked = pa.x < 11 * T + 4 and w.alive and w:isSolidBody()
    shoot(lv, pa, 2, 5.5 * T)
    local held = w:isSolidBody() and #(pa.bursts or {}) == 0
    shoot(lv, pa, 3, 5.5 * T)
    local broken = not w:isSolidBody()
    stub.state.right = true
    step(lv, 1.5, function() hover(pa, 5.5 * T) end)
    clearInput()
    check('muro', blocked and held and broken and pa.x > 13 * T,
          ('intacto para al jugador (x %.0f)=%s; potencia 2 < 3: aguanta y para la ráfaga=%s; potencia 3: se rompe=%s; luego pasa (x %.0f)'):format(
           pa.x, tostring(blocked), tostring(held), tostring(broken), pa.x))
end

local ORDER = { 'aleteo', 'ventana', 'pilar', 'suelo', 'reaparece', 'exclusivo', 'normal', 'carga', 'ataque', 'jaula', 'muro', 'etapa' }
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
