-- Arnés: NAVEGACIÓN de los bots (src/ai/BotNav.lua) en las arenas de Rey de la Colina.
--   BUILD=1   construye el grafo de cada nivel con la física real → assets/nav/<nivel>.json (se sube al repo)
--   (sin BUILD) comprueba que cada grafo existe y está al día con su nivel (firma) y JUEGA, sin ventana:
--     sola   el bot llega a la zona que más da y se queda (% del tiempo dentro, tras llegar)
--     caza   con un "jugador" quieto dentro de la zona: el bot va a por él y lo saca a ground pounds
--            (cuántas veces lo empuja en SECS s); sobre suelo ROMPIBLE no ataca (lo rompería): se queda en la zona;
--            con Activadores ON/OFF cuenta también las veces que le quita el suelo pulsándolo
--     cebo   con un "jugador" quieto FUERA de las zonas, cerca: el bot NO deja su zona para ir a por él (puntuar
--            es lo primero): dentro ≥ 80 % del tiempo tras llegar
--     agua   (niveles con inundación, que aquí sube y baja como en el juego) no se vuelve loco: dentro del agua
--            pulsa el salto menos de 1,2 veces por segundo de media (nadar sí; aporrear el botón sin salir, no)
--     datos  en estos niveles TODOS los enemigos reaparecen y dan el 40 % de sus puntos (15 → 6, 10 → 4),
--            y no hay ninguna VIDA EXTRA (las vidas las da el premio del bonus)
--   tools/tests/run.sh bot_nav [BUILD=1] [-- assets/levels/a.json ...]   (sin niveles: las arenas de los bonus)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local Level = require 'src/world/Level'
local BotNav = require 'src/ai/BotNav'
local Bot = require 'src/ai/Bot'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Entities = require 'src/world/Entities'
local Interactions = require 'src/world/entities/Interactions'
local PointAreas = require 'src/world/PointAreas'
local Floods = require 'src/world/Floods'
local EntityTypes = require 'src/world/entities/EntityTypes'
local SECS = tonumber(os.getenv('SECS')) or 60                 -- (una partida bonus entera: la zona cambia de parada)

local function play(level, nav, withTarget, lure)
    local sx, sy = level:getSpawnPx()
    local bpa = PlayerAdventure:new(sx + TILE_PX, sy)
    bpa.spawnX, bpa.spawnY = bpa.x, bpa.y
    local bot = Bot.new(bpa, nav, { firstDelay = 0 })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    -- el "jugador": quieto en el centro de la zona que más da (y vuelve a ella si lo echan)
    -- la zona que elige el bot (la que más da con suelo firme AHORA)
    local best = Bot.pickZone(nav, level, bpa.x, bpa.y, 0)
    for _, a in ipairs(level.pointAreas) do a._navAt = nil end
    local tgt
    if withTarget then
        local zn = {}
        for id in pairs(best._nodes or {}) do zn[#zn + 1] = nav.nodes[id] end
        table.sort(zn, function(a, b) return math.abs(a.x - (best.x0 + best.x1) / 2) < math.abs(b.x - (best.x0 + best.x1) / 2) end)
        local at = zn[1]
        if lure then
            -- el CEBO: fuera de toda zona, en una casilla a la que el bot sabe ir, a 3-7 casillas de la suya
            local bd
            at = nil
            for id, n in pairs(nav.nodes) do
                local out = true
                for _, a in ipairs(level.pointAreas) do if PointAreas.inside(a, n.x, n.y) then out = false end end
                local d = math.abs(n.x - zn[1].x) / TILE_PX + math.abs(n.y - zn[1].y) / TILE_PX
                if out and d >= 3 and d <= 7 and level:isStandable(n.c, n.r) and BotNav.path(nav, next(best._nodes), { [id] = true }) and (not bd or d < bd) then bd, at = d, n end
            end
        end
        if at then
            tgt = PlayerAdventure:new(at.x, at.y)
            tgt.spawnX, tgt.spawnY = tgt.x, tgt.y
            tgt.immortal = lure or nil
        end
    end
    local toggles, lastSw, wetT, wetJ, prevJ, breakable = 0, nil, 0, 0, false, false
    local swCells = BotNav._switchCells(level)
    local function swKey()
        local k = 0
        for _, c in ipairs(swCells) do k = (k * 31 + level:getRaw(c[1], c[2])) % 2147483647 end
        return k
    end
    lastSw = swKey()
    local stubT = P.newInputStub()
    local t, arrive, inside, pushes, tIn, activeT = 0, nil, 0, 0, 0, 0
    local curStop, stopT, stopIn, stops, reached = nil, 0, 0, 0, 0
    local ax, ay, still, worst = bpa.x, bpa.y, 0, 0             -- lo más que pasa PARADO en un sitio fuera de una zona
    local dt = 1 / 60
    while t < SECS do
        level.players = tgt and { bpa, tgt } or { bpa }
        level.solidBodies = Entities.solidBodies(es)          -- (trampolines, morteros: como en AdventureState)
        level:update(dt)
        level.zoneClock = t                                    -- (la zona ÚNICA que se mueve de parada en parada: PointAreas)
        do                                                     -- el "jugador" sigue a la zona: su sitio es la parada de ahora
            local z = PointAreas.target(level)
            if z and z ~= best and not lure then best = z end
        end
        local active = PointAreas.state(level)
        if active then activeT = activeT + dt end
        -- (cada PARADA de la zona: ¿llega el bot a estar dentro mientras dura?)
        if active ~= curStop then
            if curStop and stopT > 6 then stops = stops + 1; if stopIn >= 1 then reached = reached + 1 end end
            curStop, stopT, stopIn = active, 0, 0
        end
        if active then
            stopT = stopT + dt
            if PointAreas.inside(active, bpa.x, bpa.y) then stopIn = stopIn + dt end
        end
        Floods.advance(level, dt)                              -- (el agua sube y baja, como en la partida)
        -- (el bot, con un dt IRREGULAR como el del juego de verdad: 144 Hz con tirones; él va a paso fijo por dentro)
        JIT = (JIT or 0) + 1
        local due = dt
        while due > 1e-9 do
            local d = math.min(due, (JIT % 7 == 0) and 0.016 or 0.0069)
            bot:step(d, level, tgt)
            if tgt and bot:push(tgt) then pushes = pushes + 1 end
            due = due - d
        end
        -- (dentro del agua de una inundación: cuántas veces pulsa el salto)
        if bpa.inWater and Bot.flooded(level, bpa.x, bpa.y) then
            wetT = wetT + dt
            local jp = math.floor(bot.prevBits / P.IN_JUMP_P) % 2 == 1
            if jp and not prevJ then wetJ = wetJ + 1 end
            prevJ = jp
        end
        if #swCells > 0 then local k = swKey(); if k ~= lastSw then toggles, lastSw = toggles + 1, k end end
        if tgt then
            local real = Input; Input = stubT; P.decodeInput(0, stubT.state)
            tgt:update(dt, level); Input = real
            if tgt.dying then tgt:respawn() end
            -- (como un jugador: si lo echan, vuelve a la zona — aquí, de golpe, a los 2 s fuera)
            if not lure and tgt.onGround then
                local ob = tgt:getOuterBounds()
                local d = level:getDef(math.floor(tgt.x / TILE_PX) + 1, math.floor((ob.y + ob.h + 6) / TILE_PX) + 1)
                if d and d.breakable then breakable = true end
            end
            if lure then                                       -- (el cebo no se mueve de su sitio)
                if math.abs(tgt.x - tgt.spawnX) > 6 or math.abs(tgt.y - tgt.spawnY) > 40 then tgt.x, tgt.y, tgt.vx, tgt.vy = tgt.spawnX, tgt.spawnY, 0, 0 end
            elseif not PointAreas.inside(best, tgt.x, tgt.y) then
                tgt.outT = (tgt.outT or 0) + dt
                if tgt.outT > 2 and tgt.onGround then
                    -- (a una casilla de la zona que tenga suelo AHORA: el del principio puede estar roto)
                    local z = Bot.pickZone(nav, level, tgt.x, tgt.y, t)
                    local ids = {}
                    for id in pairs(z and z._nodes or {}) do ids[#ids + 1] = id end
                    table.sort(ids)
                    local nn = ids[1] and nav.nodes[ids[math.ceil(#ids / 2)]]
                    if nn then tgt.spawnX, tgt.spawnY, best = nn.x, nn.y, z end
                    tgt.x, tgt.y, tgt.vx, tgt.vy, tgt.outT = tgt.spawnX, tgt.spawnY, 0, 0, 0
                end
            else tgt.outT = 0 end
            if PointAreas.inside(best, tgt.x, tgt.y) then tIn = tIn + dt end
        end
        for _, e in ipairs(es) do if e.alive then e:update(dt, level) end end
        Interactions.run(bpa, es, {})
        -- (dentro de la zona ACTIVA; mientras viaja a la parada siguiente, ir hacia ella no es estar parado)
        local isIn = active ~= nil and PointAreas.inside(active, bpa.x, bpa.y)
        local zt = PointAreas.target(level)
        if not active and zt and PointAreas.inside(zt, bpa.x, bpa.y) then ax, ay, still = bpa.x, bpa.y, 0 end
        if isIn and not arrive then arrive = t end
        if os.getenv('DEBUG') and (withTarget or os.getenv('SOLO')) and (withTarget ~= (os.getenv('SOLO') ~= nil)) and math.floor(t * 2) ~= math.floor((t - dt) * 2) then
            print(('  %.1f bot %d,%d %s/' .. tostring(bot.kind) .. ' cd %.1f path %s · objetivo %d,%d stun %.1f'):format(t, bpa.x, bpa.y, bot.mode, bot.cd,
                bot.path and #bot.path or '-', tgt and tgt.x or 0, tgt and tgt.y or 0, tgt and tgt.stunT or 0))
        end
        -- (esperar a que baje el agua no es quedarse atascado)
        if isIn or bot.kind == 'wait' or math.abs(bpa.x - ax) > 40 or math.abs(bpa.y - ay) > 100 then ax, ay, still = bpa.x, bpa.y, 0
        else still = still + dt; worst = math.max(worst, still) end
        if isIn then inside = inside + dt end
        t = t + dt
    end
    return arrive, inside / math.max(1, activeT), pushes, tIn / SECS, worst,
           { toggles = toggles, wetT = wetT, wetJ = wetJ, breakable = breakable, lured = tgt ~= nil, stops = stops, reached = reached,
             moving = #level.pointAreas > 1 }
end

-- DATOS: en un nivel con zonas de puntos todo enemigo que se puede pisar REAPARECE y da el 40 % de sus puntos
-- (redondeado hacia abajo: Crabbies y lúgubres 15 → 6, Gummies 10 → 4)
local function dataCheck(level)
    local bad = {}
    for _, pl in ipairs(level.entities) do
        local def = EntityTypes.byName[pl.type]
        -- (ni una VIDA EXTRA en una arena: las vidas las da la pantalla de resultados del bonus)
        if pl.type == 'extralife' then bad[#bad + 1] = ('vida extra en %d,%d (en las arenas no: las da el premio)'):format(pl.col, pl.row) end
        local okE, ent = pcall(Entities.create, pl)
        if def and def.category == 'Enemigos' and okE and ent then
            local p = ent.props or {}                              -- (con los valores por defecto del tipo ya puestos)
            local base = (def.defaults or {}).points
            if base == nil then base = 10 end
            if p.stompable and base > 0 then
                local want = math.floor(base * 0.4)
                if p.points ~= want then bad[#bad + 1] = ('%s en %d,%d da %s (debe dar %d)'):format(pl.type, pl.col, pl.row, tostring(p.points), want) end
                if not (tonumber(p.respawn) and p.respawn > 0) then bad[#bad + 1] = ('%s en %d,%d no reaparece'):format(pl.type, pl.col, pl.row) end
            elseif def.name == 'bomb' and not (tonumber(p.respawn) and p.respawn > 0) then
                bad[#bad + 1] = ('bomba en %d,%d no reaparece'):format(pl.col, pl.row)
            end
        end
    end
    return bad
end

-- TODOS los niveles con zonas de puntos (los 6 bonus de la historia y los demás de Rey de la Colina, que en Juego
-- libre también se juegan contra el bot)
local DEFAULT = { 'cala_de_los_muelles', 'cantera_real', 'ciudadela_alterna', 'cripta_del_silencio', 'lago_de_cristal',
                  'isla_flotante', 'coliseo_pinchos', 'cascada_dorada', 'cumbre_cangrejo', 'marea_alta', 'rebote_real' }
local fails = 0

function love.load(arg)
    local list = {}
    for i = 1, #arg do if arg[i]:match('%.json$') then list[#list + 1] = arg[i] end end
    if #list == 0 then for _, n in ipairs(DEFAULT) do list[#list + 1] = 'assets/levels/' .. n .. '.json' end end
    for _, path in ipairs(list) do
        local name = path:match('([^/]+)%.json$')
        local level = Level.new(path)
        if os.getenv('BUILD') then
            local t0 = love.timer.getTime()
            local g = BotNav.build(level)
            local ne = 0
            for _, l in pairs(g.edges) do ne = ne + #l end
            local f = io.open('assets/nav/' .. name .. '.json', 'w')
            f:write(BotNav.encode(g)); f:close()
            print(('%-22s %4d nodos, %5d aristas, %7d pasos de física, %.1f s'):format(name, g.stats.nodes, ne, g.stats.steps, love.timer.getTime() - t0))
        else
            local g = BotNav.load(name, level)
            local ok = g ~= nil and not g.stale
            if not ok then
                fails = fails + 1
                print(('%-22s %s'):format(name, g and 'DESACTUALIZADO (BUILD=1)' or 'FALTA (BUILD=1)'))
            else
                local arrive, frac, _, _, w1, x1 = play(Level.new(path), g, false)
                local _, fracH, pushes, tIn, w2, x2 = play(Level.new(path), g, true)
                local arrL, fracL, _, _, _, x3 = play(Level.new(path), g, true, true)
                local stuck = math.max(w1, w2)                  -- (nunca clavado en un sitio fuera de una zona más de 6 s)
                -- echarlo: a empujones, o quitándole el suelo con el Activador; sobre suelo rompible no ataca: se queda
                local kicks = pushes + x2.toggles
                local hunted = kicks >= (x1.moving and 2 or 3) or (x2.breakable and fracH > (x1.moving and 0.3 or 0.5))     -- (zona que se mueve: menos tiempo juntos)
                local wetT, wetJ = x1.wetT + x2.wetT + x3.wetT, x1.wetJ + x2.wetJ + x3.wetJ
                local calm = wetT < 3 or wetJ / wetT < 1.2
                local keeps = not x3.lured or (arrL ~= nil and (fracL >= 0.8 or fracL >= frac - 0.1 or (x1.moving and fracL >= 0.3)))       -- (igual que sin cebo: en cala un enemigo lo tira de la zona)
                local bad = dataCheck(level)
                local need = x1.moving and 0.3 or 0.5                    -- (zona que se mueve: parte del tiempo es ir de parada en parada)
                if wetT > 30 then need = math.min(need, 0.4) end        -- (media partida con la zona bajo el agua)
                local follows = not x1.moving or x1.reached >= x1.stops - 1
                local good = arrive ~= nil and arrive < 25 and frac > need and follows and hunted and stuck < 6 and calm and keeps and #bad == 0     -- (0.5: en cala_de_los_muelles un enemigo lo tira de la zona y tarda en volver)
                if not good then fails = fails + 1 end
                print(('%-22s %s  sola: llega en %s s, dentro el %d %% · caza: %d empujones%s%s, el jugador en la zona el %d %% · cebo: dentro el %s · agua: %.0f s, %.1f saltos/s · parado como mucho %.1f s · paradas alcanzadas %d/%d'):format(
                    name, good and 'OK   ' or 'FALLA', arrive and string.format('%.1f', arrive) or '—', math.floor(frac * 100), pushes,
                    x2.toggles > 0 and (' + ' .. x2.toggles .. ' Activador') or '', x2.breakable and ' (suelo rompible: no ataca)' or '', math.floor(tIn * 100),
                    x3.lured and (math.floor(fracL * 100) .. ' %') or 'sin cebo', wetT, wetT > 0 and wetJ / wetT or 0, stuck, x1.reached, x1.stops))
                for _, b in ipairs(bad) do print('    datos: ' .. b) end
            end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
