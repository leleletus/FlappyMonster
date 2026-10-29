-- Arnés: FOTO de un nivel entero (para revisar sin jugar cómo queda: terreno, decoraciones,
-- fondo, entidades). Dibuja el nivel de verdad (cielo, tiles, decoraciones, entidades tras 1 s de
-- simulación) a trozos de pantalla y los junta en una imagen reducida.
--   tools/tests/run.sh level_shots -- assets/levels/a.json [b.json ...]
--   SCALE=0.25 (por defecto; 1 = tamaño real)   LIGHT=1 (los niveles a oscuras, sin la oscuridad)
--   CROP=c0,r0,c1,r1  solo ese trozo del nivel (casillas, desde 1, ambos incluidos): para mirar de cerca unos bloques
--   TAG=texto  se añade al nombre de la salida (shot_<nivel>_<texto>.png): antes / después sin pisarse
--   TIME=day|dusk|night  la hora del nivel (un fondo a las tres horas: TIME=night TAG=night)
--   SECS=n  segundos de simulación antes de la foto (1 por defecto): ver una trampa con reloj a su hora (el alud de
--           la_cima cayendo: SECS=11)
--   FIXED=1  foto REPETIBLE (azar con semilla fija y reloj parado): dos ejecuciones dan el mismo PNG, para
--            comparar antes / después de mover o rehacer algo que no debe cambiar el dibujo
-- Salida: <save>/shot_<nivel>.png  (~/.local/share/love/fm_test_levelshots/)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
love.graphics.setDefaultFilter('nearest', 'nearest')    -- (como game.lua: píxeles nítidos)
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
    -- (fuera de assets/ — las arenas de prueba de tools/levelgen/arenas/ —: se lee del disco, desde la raíz del repo)
    local raw = love.filesystem.read(path)
    if not raw then local f = io.open(path, 'r'); if f then raw = f:read('*a'); f:close() end end
    local data = json.decode(raw)
    -- (TIME: la hora del nivel, para ver un fondo a las tres horas sin tocar el nivel)
    if os.getenv('TIME') and os.getenv('TIME') ~= '' then data.time = os.getenv('TIME') end
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    BossZones.link(level, es)
    for _ = 1, math.max(1, math.floor((tonumber(os.getenv('SECS')) or 1) * 60 + 0.5)) do
        level.solidBodies = Entities.solidBodies(es)
        level:update(1 / 60); level:updateFoliage(1 / 60)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
    end
    local k = tonumber(os.getenv('SCALE')) or 0.25
    local W, H = level.tileW * TILE_PX, level.tileH * TILE_PX
    -- (CROP: el trozo [x0, x0 + W) x [y0, y0 + H) del nivel, en píxeles)
    local x0, y0 = 0, 0
    local crop = os.getenv('CROP')
    if crop and crop ~= '' then
        local c0, r0, c1, r1 = crop:match('^(%d+),(%d+),(%d+),(%d+)$')
        assert(c0, 'CROP=c0,r0,c1,r1')
        c0, r0 = math.max(1, tonumber(c0)), math.max(1, tonumber(r0))
        c1, r1 = math.min(level.tileW, tonumber(c1)), math.min(level.tileH, tonumber(r1))
        x0, y0 = (c0 - 1) * TILE_PX, (r0 - 1) * TILE_PX
        W, H = (c1 - c0 + 1) * TILE_PX, (r1 - r0 + 1) * TILE_PX
    end
    local out = love.graphics.newCanvas(math.ceil(W * k), math.ceil(H * k))
    WINDOW_W, WINDOW_H = 1280, 720
    local view = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    local water = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    local warned
    for oy = 0, H - 1, WINDOW_H do
        for ox = 0, W - 1, WINDOW_W do
            local cx, cy = x0 + ox, y0 + oy
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
            -- el AGUA (tinte, olas, distorsión): se dibuja la escena ya hecha en OTRO lienzo con el agua encima (antes
            -- se le pedía dibujar `view` sobre sí mismo: el error se tragaba con pcall y el agua no salía en las fotos)
            if level.renderWaterEffect then
                love.graphics.setCanvas(water)
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.setColor(1, 1, 1, 1)
                local ok, err = pcall(level.renderWaterEffect, level, cx, cy, view)
                if not ok and not warned then warned = true; print('[agua] ' .. tostring(err)) end
                love.graphics.setCanvas(view)
                love.graphics.setColor(1, 1, 1, 1)
                if ok then love.graphics.draw(water, 0, 0) end
            end
            -- la LUZ AMBIENTE del nivel (atardecer, noche, cueva, a oscuras; src/fx/Darkness.lua), con un "jugador"
            -- en su salida para ver el halo (LIGHT=0: sin luz, el nivel tal cual)
            if os.getenv('LIGHT') ~= '0' and Darkness.active(level) then
                local sx, sy = level:getSpawnPx()
                Darkness.render(level, cx, cy, { { x = sx, y = sy, facing = 1, on = true } })
                Darkness.renderGlow(level, es, cx, cy)
            end
            love.graphics.setCanvas(out)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(view, math.floor(ox * k), math.floor(oy * k), 0, k, k)
        end
    end
    love.graphics.setCanvas()
    local tag = os.getenv('TAG')
    local name = 'shot_' .. path:match('([^/]+)%.json$') .. ((tag and tag ~= '') and ('_' .. tag) or '') .. '.png'
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
