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
--               pilares, mata a un enemigo y la para un bloque sólido; sale hacia donde mira (`facing`, como al lanzar
--               lo que se carga): sin haberse movido, a la derecha; tras ir a la izquierda y soltar, a la izquierda
--               (y el monstruo se dibuja mirando allí), matando a un enemigo de ese lado
--   jaula       flappy enjaulado: una ráfaga con menos potencia que su mínimo no la abre (y se para); con más, la abre;
--               una ya liberada en una partida terminada sale vacía
--   lanzarredes torreta del Valle: lejos no dispara; cerca brilla y lanza una red recta hacia arriba; encima, −1 y ctrlLock;
--               la ráfaga la revienta; `trapPace` acelera su reloj
--   muro        muro agrietado: sólido; una ráfaga más floja que su mínimo no lo rompe (y se para); con bastante, se rompe
--               y se pasa
--   powerups    escudo (para un golpe; no una muerte forzada), corazón, fuerza (×2 a jefes, no abre jaulas de más), imanes,
--               pequeño, fantasma (atraviesa pilares; acabarse dentro = invulnerable), lo que no se puede usar
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
    -- la dirección: sin haberse movido, a la derecha (la de antes); tras ir a la izquierda y soltar, a la izquierda
    local right = b ~= nil and b.dir == 1 and pa3.facing == 1
    local lv4 = stage(40, nil, nil, true,
        { { type = 'gummy', col = 12, row = 5, props = { movement = 'fly', speed = 0 } } })
    local pa4 = player(lv4, 22 * T, 4.5 * T)
    local g4 = lv4.liveEntities[1]
    pa4.charge = 2
    stub.state.left = true
    step(lv4, 0.4, function() hover(pa4, 4.5 * T) end)
    clearInput()
    step(lv4, 0.3, function() hover(pa4, 4.5 * T) end)               -- (ya sin pulsar nada)
    local x0 = pa4.x
    stub.state.special_pressed = true
    step(lv4, DT)
    local b4 = pa4.bursts and pa4.bursts[1]
    local bx0 = b4 and b4.x
    step(lv4, 0.15, function() hover(pa4, 4.5 * T) end)
    local wentLeft = b4 ~= nil and b4.dir == -1 and bx0 < x0 and b4.x < bx0 - 100 and pa4.facing == -1
    step(lv4, 1, function() hover(pa4, 4.5 * T) end)
    local killedL = tostring(g4.state):find('dead') ~= nil or not g4.alive
    clearInput()
    check('ataque', right and wentLeft and killedL,
          ('sin moverse sale a la derecha=%s; tras ir a la izquierda y soltar sale a la izquierda (x %.0f → %.0f, mira a %s)=%s; el Gummy de la izquierda muere=%s'):format(
           tostring(right), bx0 or -1, b4 and b4.x or -1, tostring(pa4.facing), tostring(wentLeft), tostring(killedL)))
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

-- LANZARREDES (docs/design/flappy-plan-5b-valley.md, tarea 2): torreta en el suelo (col 12, fila 9) que, tras brillar, dispara
-- una red recta hacia arriba
function cases.lanzarredes()
    local NL = require('src/world/entities/types/traps/netlauncher').class
    local Difficulty = require 'src/core/Difficulty'
    local TT = NL.T
    local function mk(px, py, row)
        local lv = stage(80, nil, nil, true, { { type = 'netlauncher', col = 12, row = row or 9, props = {} } })
        local l
        for _, e in ipairs(lv.liveEntities) do if e.def.name == 'netlauncher' then l = e end end
        local nets = {}
        for _, e in ipairs(lv.liveEntities) do if e.def.name == 'netshot' then nets[#nets + 1] = e end end
        return lv, l, nets, player(lv, px, py)
    end
    local function anyNet(nets) for _, n in ipairs(nets) do if n.alive then return n end end end
    -- 1. a más de una pantalla: no dispara nunca
    local lv, l, nets, pa = mk(60 * T, 4.5 * T)
    local firedFar = false
    step(lv, 9, function() hover(pa, 4.5 * T); if l.state ~= 'idle' or anyNet(nets) then firedFar = true end end)
    -- 2. cerca (de lado): brilla TT.AIM_T s y dispara recta hacia arriba a NET_SPD
    local lv2, l2, nets2, pa2 = mk(8 * T, 4.5 * T)
    pa2.hp = 99
    local aimAt, fireAt, n, x0, y0, t0
    local t = 0
    step(lv2, 6, function()
        hover(pa2, 4.5 * T)
        t = t + DT
        if not aimAt and l2.state == 'aim' then aimAt = t end
        n = anyNet(nets2)
        if n and not fireAt then fireAt = t; x0, y0 = n.x, n.y end
        if n and fireAt and not t0 and t > fireAt + 0.2 then t0 = t; n.mark = { n.x, n.y } end
        return t0 ~= nil
    end)
    local up = n and n.mark and n.up == true and math.abs(n.x - x0) < 1 and (n.mark[2] - y0) < -TT.NET_SPD * 0.1
    local telegraph = aimAt and fireAt and math.abs((fireAt - aimAt) - TT.AIM_T) < 0.1
    local slots = #nets2 == TT.NET_POOL
    -- 3. un jugador justo encima: −1 de vida y ctrlLock; la red le envuelve
    local lv3, l3, nets3, pa3 = mk(12 * T - 32, 3.5 * T)
    local hp0 = pa3.hp
    local locked = false
    step(lv3, 5, function()
        hover(pa3, 3.5 * T)
        if (pa3.ctrlLockT or 0) > 0 then locked = true end
        return locked
    end)
    local hit = pa3.hp == hp0 - 1 and locked
    -- 4. la ráfaga (potencia 1) la revienta
    local lv4, l4, nets4, pa4 = mk(7 * T, 4.5 * T, 5)       -- (a la altura de la ráfaga: el jugador aletea en torno a 4,5 casillas)
    shoot(lv4, pa4, 1, 4.5 * T)
    local dead = not l4.alive or l4.state == 'dead_burst'
    -- 5. el ritmo: `trapPace` (dificultad) acelera su reloj
    Difficulty.bind({ difficulty = 'extreme' })
    local fastK = Difficulty.dt(l, 1)
    local fast = fastK > 1.2
    Difficulty.bind(nil)
    local slow = Difficulty.dt(l, 1) == 1
    check('lanzarredes', not firedFar and up and telegraph and slots and hit and dead and fast and slow,
          ('lejos (>1 pantalla) no hace nada=%s; brilla %.2f s (AIM_T %.1f) y la red sale recta arriba=%s; encima: −1 y ctrlLock=%s; la ráfaga la revienta=%s; trapPace extremo acelera (×%.2f) y sin dificultad no=%s; reserva %d redes=%s'):format(
           tostring(not firedFar), (fireAt or 0) - (aimAt or 0), TT.AIM_T, tostring(up and true or false), tostring(hit), tostring(dead),
           fastK, tostring(slow), #nets2, tostring(slots)))
end

-- LANZARREDES, la red hacia arriba: se engancha en un pilar por encima (netSnag, se deshace, nunca lo pasa) y, sin nada
-- encima, se gasta al salir por arriba del nivel; y quien llega a su alcance no recibe un disparo al instante
function cases.lanzarredes_techo()
    local NL = require('src/world/entities/types/traps/netlauncher').class
    local function mk(pillar, px)
        local lv = stage(80, nil, nil, true, { { type = 'netlauncher', col = 12, row = 9, props = {} } })
        if pillar then lv.tiles[6][12] = PILLAR end              -- (3 casillas por encima)
        local l, nets = nil, {}
        for _, e in ipairs(lv.liveEntities) do
            if e.def.name == 'netlauncher' then l = e elseif e.def.name == 'netshot' then nets[#nets + 1] = e end
        end
        local pa = player(lv, px, 4.5 * T)
        pa.hp = 99
        return lv, l, nets, pa
    end
    local snagSounds = 0
    local realPlay = Sound.play
    Sound.play = function(id, ...) if id == 'netSnag' then snagSounds = snagSounds + 1 end end
    -- 1. pilar encima
    local lv, l, nets, pa = mk(true, 8 * T)
    local minY, snagged, spent = math.huge, false, false
    local pillarBottom = 6 * T
    step(lv, 6, function()
        hover(pa, 4.5 * T)
        for _, n in ipairs(nets) do
            if n.alive then
                minY = math.min(minY, n.y)
                if n.state == 'snag' then snagged = true end
            end
        end
        if snagged then
            local live = false
            for _, n in ipairs(nets) do if n.alive then live = true end end
            if not live then spent = true; return true end
        end
    end)
    local snagAfter1 = snagSounds
    local stoppedBelow = minY > pillarBottom - 1 and minY < math.huge
    -- 2. nada encima: sale por arriba y no queda ninguna red viva
    local lv2, l2, nets2, pa2 = mk(false, 8 * T)
    local fired, gone, leaked = false, false, false
    step(lv2, 8, function()
        hover(pa2, 4.5 * T)
        local live = false
        for _, n in ipairs(nets2) do if n.alive then live = true; fired = true end end
        if fired and not live then gone = true; return true end
    end)
    -- 3. a quien llega a su alcance no le dispara al instante
    local lv3, l3, nets3, pa3 = mk(false, 60 * T)
    step(lv3, 8, function() hover(pa3, 4.5 * T) end)                -- (lejos: en reposo, esperando)
    pa3.x = 8 * T
    local t, firedAt = 0, nil
    step(lv3, 3, function()
        hover(pa3, 4.5 * T)
        t = t + DT
        if not firedAt and l3.state ~= 'idle' then firedAt = t; return true end
    end)
    Sound.play = realPlay
    local fair = firedAt and firedAt >= NL.T.FIRST - 0.05
    check('lanzarredes_techo', stoppedBelow and snagged and spent and snagAfter1 == 1 and snagSounds == 1 and gone and fair,
          ('con un pilar 3 casillas encima: se engancha (netSnag x%d, y ninguno al salir por arriba), nunca lo pasa (y mínima %.0f, base del pilar %d) y se deshace=%s; sin nada encima sale por arriba y no queda ninguna red viva=%s; al llegar a su alcance tarda %.2f s en apuntar (FIRST %.1f)=%s'):format(
           snagAfter1, minY, pillarBottom, tostring(spent), tostring(gone), firedAt or -1, NL.T.FIRST, tostring(fair and true or false)))
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
    -- con la CÁMARA corriendo: aguantar contra un muro intacto que tapa todo el alto NO lo atraviesa (el borde de la
    -- ventana no lo empuja a través: o se queda delante o se queda atrás y muere, como contra un bloque)
    local lv4 = stage(80, nil, 200, true, { { type = 'crackwall', col = 20, row = 9, props = { minCharge = 3, rows = 9 } } })
    local w4 = lv4.liveEntities[1]
    local pa4 = player(lv4, 8 * T, 4.5 * T)
    stub.state.right = true
    local through = false
    step(lv4, 8, function()
        hover(pa4, 4.5 * T)
        if not pa4.dying and pa4.x > w4.x1 then through = true end
    end)
    clearInput()
    -- una ráfaga en vuelo al morir no sigue tras reaparecer
    local lv5 = stage(40, nil, nil, true)
    local pa5 = player(lv5, 8 * T, 4.5 * T)
    pa5.charge = 2
    stub.state.special_pressed = true
    step(lv5, DT)
    pa5:die(nil, true); step(lv5, 2); pa5:respawn()
    local cleared = #(pa5.bursts or {}) == 0
    clearInput()
    check('muro', not through and cleared, ('con la cámara, aguantar contra el muro intacto lo atraviesa=%s; la ráfaga desaparece al reaparecer=%s'):format(tostring(through), tostring(cleared)))
    check('muro', blocked and held and broken and pa.x > 13 * T,
          ('intacto para al jugador (x %.0f)=%s; potencia 2 < 3: aguanta y para la ráfaga=%s; potencia 3: se rompe=%s; luego pasa (x %.0f)'):format(
           pa.x, tostring(blocked), tostring(held), tostring(broken), pa.x))
end

function cases.powerups()
    local out = {}
    local function ok(name, v) out[#out + 1] = name .. '=' .. tostring(v); return v end
    -- ESCUDO: para un golpe de pilar (vida igual, escudo fuera); el siguiente sí quita
    -- (el 2º pilar, lejos: que se haya acabado la invulnerabilidad del golpe parado)
    local lv = stage(40, { { 12, 10, 0 }, { 24, 10, 0 } }, nil, true)
    local pa = player(lv, 8 * T, 4.5 * T)
    local used = pa:usePowerup('shield')
    local again = pa:canUse('shield')
    stub.state.right = true
    local hp0 = pa.hp
    step(lv, 0.9, function() hover(pa, 4.5 * T) end)
    local a1 = ok('escudo para el 1º', used and not again and pa.hp == hp0 and not pa.shield)
    step(lv, 3.5, function() hover(pa, 4.5 * T) end)
    clearInput()
    local a2 = ok('el 2º quita', pa.hp == hp0 - 1)
    -- ESCUDO y quedarse atrás de la cámara (muerte forzada): muere y el escudo sigue
    local lv2 = stage(80, nil, 300, true)
    for r = 1, 9 do lv2.tiles[r][14] = require('src/world/tiles/TileCodec').encode(1) end
    local pb = player(lv2, 10 * T, 4.5 * T)
    pb:usePowerup('shield')
    stub.state.right = true
    local died = false
    step(lv2, 6, function() hover(pb, 4.5 * T); if pb.dying then died = true; return true end end)
    clearInput()
    local a3 = ok('atrás muere y conserva el escudo', died and pb.shield == true)
    -- CORAZÓN: vida máxima 4 y +1
    local lv3 = stage(40, nil, nil, true)
    local pc = player(lv3, 8 * T, 4.5 * T)
    pc.hp = 2
    pc:usePowerup('heart')
    local a4 = ok('corazón', pc.hpMax == 4 and pc.hp == 3)
    -- FUERZA: un jefe recibe 2 × la potencia; una jaula de mínimo 4 NO se abre con potencia 3
    local Boss = require 'src/world/entities/base/Boss'
    local boss = { alive = true, x = 13 * T, y = 4.5 * T, dmg = 0, isVulnerable = function() return true end,
                   damage = function(self, n) self.dmg = self.dmg + n end,
                   getOuterBounds = function(self) return { x = self.x - 32, y = self.y - 64, w = 64, h = 128 } end }
    boss.onSpecialHit = Boss.onSpecialHit
    -- (un JEFE de mentira con lo justo: el resto de lo de Entity, por herencia)
    setmetatable(boss, { __index = require('src/world/entities/base/Entity') })
    boss.update = function() end
    boss.isGhost = function() return true end
    local lv4 = stage(40, nil, nil, true, { { type = 'cage', col = 20, row = 5, props = { minCharge = 4 } } })
    table.insert(lv4.liveEntities, 1, boss)
    local pd = player(lv4, 8 * T, 4.5 * T)
    pd:usePowerup('strength')
    shoot(lv4, pd, 3, 4.5 * T)
    local cage = lv4.liveEntities[2]
    local a5 = ok('fuerza ×2 al jefe', boss.dmg == 6)
    table.remove(lv4.liveEntities, 1)
    shoot(lv4, pd, 3, 4.5 * T)
    local a6 = ok('la fuerza no abre jaulas de más', cage.state == 'closed')
    -- IMANES: el de objetos atrae una carga a 3 casillas en 1 s; el de puntos no
    local function magnetTest(id)
        local lv5 = stage(40, nil, nil, true, { { type = 'flapcharge', col = 12, row = 3, props = {} } })
        local pe = player(lv5, 8 * T, 4.5 * T)
        pe:usePowerup(id)
        step(lv5, 1.2, function() hover(pe, 4.5 * T) end)
        return pe.charge
    end
    local a7 = ok('imán de objetos', magnetTest('magnet_items') == 1 and magnetTest('magnet_points') == 0)
    -- PEQUEÑO: media caja
    local pf = player(lv3, 8 * T, 4.5 * T)
    local w0 = pf:getOuterBounds().w
    pf:usePowerup('small')
    step(lv3, DT)
    local a8 = ok('pequeño', math.abs(pf:getOuterBounds().w - w0 / 2) < 1)
    -- FANTASMA: atraviesa un pilar sin perder vida; si se acaba dentro, invulnerable en vez de golpe
    local lv6 = stage(40, { { 12, 10, 0 }, { 13, 10, 0 }, { 14, 10, 0 } }, nil, true)
    local pg = player(lv6, 8 * T, 4.5 * T)
    pg:usePowerup('ghost')
    stub.state.right = true
    local hpG = pg.hp
    step(lv6, 1.0, function() hover(pg, 4.5 * T) end)
    local a9 = ok('fantasma atraviesa', pg.hp == hpG and pg.x > 11 * T)
    clearInput()
    pg.x = 13.5 * T
    pg.effects.ghost = 0.05
    step(lv6, 0.3, function() hover(pg, 4.5 * T) end)
    local a10 = ok('se acaba dentro: invulnerable', pg.hp == hpG and pg:isInvulnerable())
    -- no se pueden gastar mal: imán con el súper imán puesto
    local ph = player(lv3, 8 * T, 4.5 * T)
    ph:usePowerup('magnet_all')
    local a11 = ok('imán bajo súper imán no', not ph:canUse('magnet_points') and not ph:usePowerup('magnet_items'))
    check('powerups', a1 and a2 and a3 and a4 and a5 and a6 and a7 and a8 and a9 and a10 and a11, table.concat(out, '; '))
end

local ORDER = { 'aleteo', 'ventana', 'pilar', 'suelo', 'reaparece', 'exclusivo', 'normal', 'carga', 'ataque', 'jaula', 'lanzarredes', 'lanzarredes_techo', 'muro', 'powerups', 'etapa' }
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
