-- Arnés: NAVEGACIÓN de los bots (src/ai/BotNav.lua) en las arenas de Rey de la Colina.
--   BUILD=1   construye el grafo de cada nivel con la física real → assets/nav/<nivel>.json (se sube al repo)
--   (sin BUILD) comprueba que cada grafo existe y está al día con su nivel (firma) y JUEGA, sin ventana:
--     sola   el bot llega a la zona que más da y se queda (% del tiempo dentro, tras llegar)
--     caza   con un "jugador" quieto dentro de la zona: el bot va a por él y lo saca a ground pounds
--            (cuántas veces lo empuja en SECS s)
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
local SECS = tonumber(os.getenv('SECS')) or 40

local function play(level, nav, withTarget)
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
        tgt = PlayerAdventure:new(zn[1].x, zn[1].y)
        tgt.spawnX, tgt.spawnY = tgt.x, tgt.y
    end
    local stubT = P.newInputStub()
    local t, arrive, inside, pushes, tIn = 0, nil, 0, 0, 0
    local dt = 1 / 60
    while t < SECS do
        level.players = tgt and { bpa, tgt } or { bpa }
        level.solidBodies = Entities.solidBodies(es)          -- (trampolines, morteros: como en AdventureState)
        level:update(dt)
        bot:step(dt, level, tgt or bpa)
        if tgt then
            local real = Input; Input = stubT; P.decodeInput(0, stubT.state)
            tgt:update(dt, level); Input = real
            if tgt.dying then tgt:respawn() end
            -- (como un jugador: si lo echan, vuelve a la zona — aquí, de golpe, a los 2 s fuera)
            if not PointAreas.inside(best, tgt.x, tgt.y) then
                tgt.outT = (tgt.outT or 0) + dt
                if tgt.outT > 2 and tgt.onGround then
                    tgt.x, tgt.y, tgt.vx, tgt.vy, tgt.outT = tgt.spawnX, tgt.spawnY, 0, 0, 0
                end
            else tgt.outT = 0 end
            if bot:push(tgt) then pushes = pushes + 1 end
            if PointAreas.inside(best, tgt.x, tgt.y) then tIn = tIn + dt end
        end
        for _, e in ipairs(es) do if e.alive then e:update(dt, level) end end
        Interactions.run(bpa, es, {})
        local isIn = PointAreas.inside(best, bpa.x, bpa.y)
        if isIn and not arrive then arrive = t end
        if os.getenv('DEBUG') and withTarget and math.floor(t * 2) ~= math.floor((t - dt) * 2) then
            print(('  %.1f bot %d,%d %s cd %.1f path %s · objetivo %d,%d stun %.1f'):format(t, bpa.x, bpa.y, bot.mode, bot.cd,
                bot.path and #bot.path or '-', tgt.x, tgt.y, tgt.stunT or 0))
        end
        if arrive and isIn then inside = inside + dt end
        t = t + dt
    end
    return arrive, arrive and inside / (SECS - arrive) or 0, pushes, tIn / SECS
end

local DEFAULT = { 'cala_de_los_muelles', 'cantera_real', 'ciudadela_alterna', 'cripta_del_silencio', 'lago_de_cristal',
                  'isla_flotante', 'coliseo_pinchos', 'cascada_dorada' }
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
                local arrive, frac = play(Level.new(path), g, false)
                local _, _, pushes, tIn = play(Level.new(path), g, true)
                local good = arrive ~= nil and arrive < 25 and frac > 0.7 and pushes >= 3
                if not good then fails = fails + 1 end
                print(('%-22s %s  sola: llega a la zona en %s s, dentro el %d %% después · caza: %d empujones, el jugador quieto en la zona el %d %% del tiempo'):format(
                    name, good and 'OK   ' or 'FALLA', arrive and string.format('%.1f', arrive) or '—', math.floor(frac * 100), pushes, math.floor(tIn * 100)))
            end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
