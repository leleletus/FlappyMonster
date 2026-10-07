-- Arnés: FOTO de un nivel entero (para revisar sin jugar cómo queda: terreno, decoraciones,
-- fondo, entidades). Dibuja el nivel de verdad (cielo, tiles, decoraciones, entidades tras 1 s de
-- simulación) a trozos de pantalla y los junta en una imagen reducida.
--   tools/tests/run.sh level_shots -- assets/levels/a.json [b.json ...]
--   SCALE=0.25 (por defecto; 1 = tamaño real)   LIGHT=1 (los niveles a oscuras, sin la oscuridad)
--   FIXED=1  foto REPETIBLE (azar con semilla fija y reloj parado): dos ejecuciones dan el mismo PNG, para
--            comparar antes / después de mover o rehacer algo que no debe cambiar el dibujo
-- Salida: <save>/shot_<nivel>.png  (~/.local/share/love/fm_test_levelshots/)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Sky = require 'src/fx/Sky'
local Darkness = require 'src/fx/Darkness'
local BossZones = require 'src/world/systems/BossZones'

local FIXED = os.getenv('FIXED') == '1'
if FIXED then love.timer.getTime = function() return 100 end end

local function shot(path)
    if FIXED then math.randomseed(7); love.math.setRandomSeed(7) end
    local data = json.decode(love.filesystem.read(path))
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    BossZones.link(level, es)
    for _ = 1, 60 do
        level.solidBodies = Entities.solidBodies(es)
        level:update(1 / 60); level:updateFoliage(1 / 60)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
    end
    local k = tonumber(os.getenv('SCALE')) or 0.25
    local W, H = level.tileW * TILE_PX, level.tileH * TILE_PX
    local out = love.graphics.newCanvas(math.ceil(W * k), math.ceil(H * k))
    WINDOW_W, WINDOW_H = 1280, 720
    local view = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    for cy = 0, H - 1, WINDOW_H do
        for cx = 0, W - 1, WINDOW_W do
            love.graphics.setCanvas(view)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setColor(1, 1, 1, 1)
            Sky.render(level, cx, cy)
            level:render(cx, cy)
            level:renderFoliageBack(cx, cy)
            require('src/fx/Silhouette').level = level        -- (filo de los enemigos oscuros: `darkEdge`)
            for _, e in ipairs(es) do if e.alive and not e.renderFront then e:render(cx, cy) end end
            for _, e in ipairs(es) do if e.alive and e.renderFront then e:render(cx, cy) end end
            level:renderFoliage(cx, cy)
            if level.renderWaterEffect then pcall(level.renderWaterEffect, level, cx, cy, view) end
            -- la LUZ AMBIENTE del nivel (atardecer, noche, cueva, a oscuras; src/fx/Darkness.lua), con un "jugador"
            -- en su salida para ver el halo (LIGHT=0: sin luz, el nivel tal cual)
            if os.getenv('LIGHT') ~= '0' and Darkness.active(level) then
                local sx, sy = level:getSpawnPx()
                Darkness.render(level, cx, cy, { { x = sx, y = sy, facing = 1, on = true } })
                Darkness.renderGlow(level, es, cx, cy)
            end
            love.graphics.setCanvas(out)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(view, math.floor(cx * k), math.floor(cy * k), 0, k, k)
        end
    end
    love.graphics.setCanvas()
    local name = 'shot_' .. path:match('([^/]+)%.json$') .. '.png'
    out:newImageData():encode('png', name)
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
end

function love.load(arg)
    local bad = 0
    for i = 1, #arg do
        if arg[i]:match('%.json$') then
            local ok, err = pcall(shot, arg[i])
            if not ok then bad = bad + 1; print('FALLA ' .. arg[i] .. ': ' .. tostring(err)) end
        end
    end
    print(bad == 0 and 'TODO OK' or ('FALLOS: ' .. bad))
    love.event.quit(bad == 0 and 0 or 1)
end
