-- tools/tests/flyers — enemigos voladores contra paredes, plataformas y objetos.
-- En TODOS los niveles convierte cada enemigo que puede volar (Gummy, Crabby...)
-- en volador con una oscilación grande y simula sin jugadores. Cuenta:
--   dentro  = fotogramas con el centro del cuerpo metido en un tile sólido
--   convuls = giros de más en poco tiempo (>3 giros en 0.5 s)
--   atasco  = 2 s seguidos sin moverse en horizontal
-- SHOT=1: además guarda shot_flyers.png con los voladores de jardin_gummies
-- (alas incluidas) a escala real.
--
--   tools/tests/run.sh flyers   (BOB=px cambia la oscilación, 40 por defecto; SEED=n otra
--                               secuencia de azar; WHY=1 dice qué se atascó; TRACE_AT=s
--                               TRACE_LEVEL= TRACE_COL= TRACE_ROW= sigue a una entidad; ONLY=patrón
--                               solo esos niveles; PROGRESS=1 dice el tiempo simulado y la última
--                               entidad actualizada cada segundo: si se cuelga, se ve dónde)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
Input = require('src/network/Protocol').newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local EntityTypes = require 'src/world/entities/EntityTypes'

local BOB = tonumber(os.getenv('BOB')) or 40

local function canFly(def)
    if not def or def.boss or def.pickup or def.checkpoint or def.hide == 'all' then return false end
    for _, k in ipairs(type(def.hide) == 'table' and def.hide or {}) do if k == 'movement' then return false end end
    return def.category == 'Enemigos'
end

local function simLevel(path)
    local data = json.decode(love.filesystem.read(path))
    local nfly = 0
    for _, pl in ipairs(data.entities or {}) do
        if canFly(EntityTypes.get(pl.type)) then
            pl.props = pl.props or {}
            pl.props.movement, pl.props.bobAmp = 'fly', BOB
            pl.props.speed = pl.props.speed or 70
            if (pl.props.speed or 0) <= 0 then pl.props.speed = 70 end
            pl.props.attach = nil
            nfly = nfly + 1
        end
    end
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities, level.players = ents, {}
    local stats = { inside = 0, convuls = 0, stuck = 0, n = nfly }
    local track = {}
    local dt, t = 1 / 60, 0
    while t < 40 do
        t = t + dt
        level.solidBodies = Entities.solidBodies and Entities.solidBodies(ents) or level.solidBodies
        if level.update then level:update(dt) end
        for i, e in ipairs(ents) do
            if e.alive then
                if os.getenv('PROGRESS') then io.stderr:write(('\r%s t=%.2f ent %d %s %s     '):format(path, t, i, e.def.name, e.state)) end
                e:update(dt, level)
            end
        end
        if os.getenv('TRACE_AT') and path:match(os.getenv('TRACE_LEVEL') or '.') then
            local ta = tonumber(os.getenv('TRACE_AT'))
            if t >= ta and t < ta + 0.25 then
                for _, e in ipairs(ents) do
                    if e.col == tonumber(os.getenv('TRACE_COL')) and (not os.getenv('TRACE_ROW') or e.row == tonumber(os.getenv('TRACE_ROW'))) and e.def.name == (os.getenv('TRACE_TYPE') or 'gummy') then
                        print(('    t=%.3f %s x=%.1f y=%.1f vx=%.1f facing=%d state=%s'):format(t, e.def.name, e.x, e.y, e.vx, e.facing, e.state))
                    end
                end
            end
        end
        for i, e in ipairs(ents) do
            if e.flying and e.props.movement == 'fly' and e.alive and e.state == 'walk' then
                local tr = track[i] or { flips = {}, lastX = e.x, stillT = 0, facing = e.facing }
                track[i] = tr
                if level:isEnemySolidAt(e.x, e.y) then stats.inside = stats.inside + 1; if os.getenv("WHY") and not tr.told then tr.told = true; print("  dentro:", e.def.name, e.col, e.row, math.floor(e.x), math.floor(e.y), e.home.x, e.home.y, t) end end
                if e.facing ~= tr.facing then
                    tr.facing = e.facing
                    table.insert(tr.flips, t)
                    while tr.flips[1] and tr.flips[1] < t - 0.5 do table.remove(tr.flips, 1) end
                    if #tr.flips > 3 then
                        stats.convuls = stats.convuls + 1
                        if os.getenv('WHY') and not tr.toldC then
                            tr.toldC = true
                            print(('  convulsiona: %s col %d fila %d en x=%d y=%d patrulla %s..%s t=%.1f'):format(e.def.name,
                                e.col, e.row, e.x, e.y, tostring(e.leftBoundPx), tostring(e.rightBoundPx), t))
                        end
                    end
                end
                if math.abs(e.x - tr.lastX) < 0.01 then tr.stillT = tr.stillT + dt else tr.stillT = 0 end
                if tr.stillT > 2 and not tr.stuckOnce then
                    tr.stuckOnce = true; stats.stuck = stats.stuck + 1
                    if os.getenv('WHY') then
                        print(('  atasco: %s col %d fila %d en x=%d y=%d vx=%.1f patrulla %s..%s t=%.1f'):format(e.def.name, e.col, e.row,
                            e.x, e.y, e.vx, tostring(e.leftBoundPx), tostring(e.rightBoundPx), t))
                    end
                end
                tr.lastX = e.x
            end
        end
    end
    return stats, level, ents
end

local shotLevel, shotEnts
function love.load()
    if os.getenv('SEED') then math.randomseed(tonumber(os.getenv('SEED'))) end   -- (pausas al azar: otras secuencias)
    local total = { inside = 0, convuls = 0, stuck = 0 }
    local files = love.filesystem.getDirectoryItems('assets/levels')
    table.sort(files)
    for _, f in ipairs(files) do
        if f:match('%.json$') and f:match(os.getenv('ONLY') or '.') then
            local s, level, ents = simLevel('assets/levels/' .. f)
            if s.n > 0 then
                print(('%-28s voladores=%3d  dentro=%4d  convuls=%3d  atasco=%3d'):format(f, s.n, s.inside, s.convuls, s.stuck))
                for k in pairs(total) do total[k] = total[k] + s[k] end
            end
            if f == 'jardin_gummies.json' then shotLevel, shotEnts = level, ents end
        end
    end
    print(('TOTAL dentro=%d convuls=%d atasco=%d'):format(total.inside, total.convuls, total.stuck))
    local bad = total.inside + total.convuls + total.stuck
    print(bad == 0 and 'TODO OK' or 'FALLOS')
    if not os.getenv('SHOT') then love.event.quit(bad == 0 and 0 or 1) end
end

local frames = 0
function love.draw()
    if not shotLevel then return end
    love.window.setMode(1280, 720)
    -- el volador más cercano al principio, a tamaño real
    local f
    for _, e in ipairs(shotEnts) do if e.props.movement == 'fly' and e.alive and (not f or e.x < f.x) then f = e end end
    local camX, camY = math.floor(f.x - 640), math.floor(f.y - 360)
    love.graphics.clear(0.35, 0.6, 0.85)
    shotLevel:render(camX, camY)
    for _, e in ipairs(shotEnts) do if e.alive then e:render(camX, camY) end end
    frames = frames + 1
    if frames % 7 == 3 then
        local name = 'shot_flyers_' .. frames .. '.png'
        love.graphics.captureScreenshot(function(img) img:encode('png', name) end)
    end
    if frames > 20 then love.event.quit() end
end
