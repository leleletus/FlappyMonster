-- tools/tests/level_check — comprobación rápida de niveles (sin humano):
--  1. Model:validate() del editor (avisos/errores),
--  2. qué modos de juego lo listan (igual que el servidor),
--  3. simula 20 s de entidades con un jugador quieto (errores de Lua, entidades
--     que se caen del mapa, etc.).
--   xvfb-run -a love tools/tests/level_check assets/levels/a.json [b.json ...]
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Modes = require 'src/world/Modes'
local BossZones = require 'src/world/BossZones'
local Model = require 'src/editor/EditorModel'
local PlayerAdventure = require 'src/entities/PlayerAdventure'

local function check(path)
    local bad = 0
    local m = Model.load(path)
    for _, w in ipairs(m:validate()) do
        print(('  [%s] %s'):format(w[1], w[2]))
        if w[1] == 'error' then bad = bad + 1 end
    end
    local lv = Level.new(path)
    local info = Modes.entityInfo(lv.entities)
    info.finish, info.autoScroll = lv:countTrigger('finish'), lv.autoScroll ~= nil
    info.pointAreas = #(lv.pointAreas or {})
    local killable, bosses = info.killable, info.bosses
    local allowed
    if lv.modes then allowed = {}; for _, id in ipairs(lv.modes) do allowed[id] = true end end
    local listed = {}
    for _, md in ipairs(Modes.list) do
        if (not allowed or allowed[md.id]) and md.requires(info) then listed[#listed + 1] = md.id end
    end
    print(('  %dx%d, %d entidades (%d pisoteables), meta=%d jefes=%d zonas=%d → modos: %s'):format(
        lv.tileW, lv.tileH, #lv.entities, killable, info.finish, bosses, info.pointAreas, table.concat(listed, ',')))
    if #listed == 0 then print('  [error] ningún modo lista este nivel'); bad = bad + 1 end
    -- simulación
    local ents = {}
    for _, pl in ipairs(lv.entities) do ents[#ents + 1] = Entities.create(pl) end
    lv.liveEntities = ents
    local sx, sy = lv:getSpawnPx()
    local pa = PlayerAdventure:new(sx, sy)
    lv.players = { pa }
    local ctrl = BossZones.newController(lv, ents)
    local ok, err = pcall(function()
        for step = 1, 1200 do
            pa:update(1 / 60, lv)
            lv.solidBodies = Entities.solidBodies(ents)
            if lv.update then lv:update(1 / 60) end
            ctrl:update(1 / 60)
            for _, e in ipairs(ents) do if e.alive then e:update(1 / 60, lv) end end
            Entities.interactions.run(pa, ents, {})
            if not pa.alive or (pa.dying and pa.deathPhase == 'fall') then pa:respawn() end
        end
    end)
    if not ok then print('  [error] simulación: ' .. tostring(err)); bad = bad + 1 end
    local off = 0
    for _, e in ipairs(ents) do
        if e.alive and (e.y > lv.tileH * TILE_PX + 200 or e.x < -200 or e.x > lv.tileW * TILE_PX + 200) then
            off = off + 1; print(('  [aviso] %s (%d,%d) se cayó del mapa'):format(e.type or '?', e.col or 0, e.row or 0))
        end
    end
    return bad
end

function love.load(arg)
    local total = 0
    for i = 1, #arg do
        if arg[i]:match('%.json$') then
            print(arg[i])
            total = total + check(arg[i])
        end
    end
    print(total == 0 and 'TODO OK' or ('ERRORES: ' .. total))
    love.event.quit(total == 0 and 0 or 1)
end
