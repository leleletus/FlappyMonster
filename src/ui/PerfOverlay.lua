-- src/ui/PerfOverlay.lua
-- El MEDIDOR de rendimiento en pantalla (Configuración → Rendimiento, o F3): para ver en el aparato de verdad (Switch,
-- móvil) a dónde se va el fotograma. Cada medio segundo: FPS, ms de CPU de update y de dibujo (media y peor), memoria de
-- Lua y de texturas, llamadas de dibujo. Si los FPS caen y los ms de CPU son bajos, lo que falta es GPU.
-- Ver docs/testing/performance.md.
local Settings = require 'src/core/Settings'

local PerfOverlay = {}

local PERIOD = 0.5
local LINE_H = 20
local acc, frames = 0, 0
local upd, updMax, dr, drMax = 0, 0, 0, 0
local lines = nil
local t0 = 0

function PerfOverlay.toggle() Settings.setShowPerf(not Settings.showPerf) end

function PerfOverlay.beginStep() if Settings.showPerf then t0 = love.timer.getTime() end end

function PerfOverlay.endUpdate(dt)
    if not Settings.showPerf then return end
    local ms = (love.timer.getTime() - t0) * 1000
    upd, updMax = upd + ms, math.max(updMax, ms)
    acc, frames = acc + dt, frames + 1
end

-- Después de dibujar el juego; lo suyo no cuenta
function PerfOverlay.endDraw()
    if not Settings.showPerf then return end
    local ms = (love.timer.getTime() - t0) * 1000
    dr, drMax = dr + ms, math.max(drMax, ms)
    local s = love.graphics.getStats()
    if acc >= PERIOD and frames > 0 then
        lines = lines or {}
        lines[1] = string.format('%d FPS', frames / acc + 0.5)
        lines[2] = string.format('update %.1f ms (peor %.1f)', upd / frames, updMax)
        lines[3] = string.format('dibujo %.1f ms (peor %.1f)', dr / frames, drMax)
        lines[4] = string.format('Lua %.1f MB  texturas %.0f MB', collectgarbage('count') / 1024, s.texturememory / 1048576)
        lines[5] = string.format('llamadas %d', s.drawcalls)
        acc, frames, upd, updMax, dr, drMax = 0, 0, 0, 0, 0, 0
    end
    if lines then
        love.graphics.push('all')
        love.graphics.origin()
        love.graphics.setScissor()
        love.graphics.setShader()
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 4, 4, 300, #lines * LINE_H + 8)
        love.graphics.setColor(0.6, 1, 0.6, 1)
        for i, line in ipairs(lines) do love.graphics.print(line, 10, 8 + (i - 1) * LINE_H) end
        love.graphics.pop()
    end
end

return PerfOverlay
