-- src/fx/Darkness.lua
-- OSCURIDAD de los niveles a oscuras (level.dark): solo se ve lo que alumbran las linternas.
-- Se dibuja DESPUÉS de la escena (y del efecto del agua) y ANTES del HUD:
--   Darkness.render(level, camX, camY, sources)   sources = { {x, y, facing, on}, ... } (jugadores)
-- Cómo: un lienzo pequeño (1/4: la luz queda pixelada, como el resto del juego) que empieza en
-- la luz AMBIENTE (casi negro) y al que cada jugador suma, en escalones, su halo (siempre: se ve
-- a sí mismo y lo que pisa) y, con la linterna encendida, su cono — trazado con rayos que los
-- bloques cortan (Lights.ray: la misma luz que usa la simulación). Luego se MULTIPLICA sobre la
-- pantalla. Sin sombreadores ni stencil (Switch / Android).
-- Lo que debe verse SIEMPRE (los puntos luminosos de los Crabbies lúgubres) se dibuja después:
-- las entidades con `renderGlow(camX, camY)`.
local Lights = require 'src/world/Lights'

local Darkness = {}

local DS = 4                          -- px de pantalla por píxel de luz
local AMBIENT = 0.055                 -- lo que se ve sin luz (casi nada)
local HALO, HALO_ON = 78, 118         -- radio del halo del jugador (apagada / encendida)
local RAYS = 26                       -- rayos del cono
-- Escalones del cono: fracción del alcance y luz que suma cada uno (de fuera adentro)
local BANDS = { { 1.0, 0.26 }, { 0.74, 0.3 }, { 0.46, 0.44 } }

local canvas

function Darkness.active(level) return level ~= nil and level.dark == true end

local function fan(ox, oy, dir, k, level, cache)
    local pts = cache
    for i = 0, RAYS do
        local a = dir - Lights.HALF + 2 * Lights.HALF * i / RAYS
        local d = pts[i] or Lights.ray(level, ox, oy, a)
        pts[i] = d
        d = math.min(d, Lights.range(level) * k)
        pts[i + 100] = ox + math.cos(a) * d
        pts[i + 200] = oy + math.sin(a) * d
    end
end

function Darkness.render(level, camX, camY, sources)
    if not Darkness.active(level) then return end
    local w, h = math.ceil(WINDOW_W / DS), math.ceil(WINDOW_H / DS)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        canvas = love.graphics.newCanvas(w, h)
        canvas:setFilter('nearest', 'nearest')
    end
    -- (dentro del lienzo: sin la transformación ni el recorte de lovesize)
    love.graphics.push()
    love.graphics.origin()
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(AMBIENT, AMBIENT, AMBIENT * 1.5, 1)
    love.graphics.setBlendMode('add')
    love.graphics.scale(1 / DS, 1 / DS)
    love.graphics.translate(-camX, -camY)
    for _, s in ipairs(sources or {}) do
        local hx, hy = s.x, s.y - 14
        local r = s.on and HALO_ON or HALO
        love.graphics.setColor(0.24, 0.24, 0.27, 1)
        love.graphics.circle('fill', hx, hy, r)
        love.graphics.setColor(0.3, 0.3, 0.33, 1)
        love.graphics.circle('fill', hx, hy, r * 0.6)
        if s.on then
            local ox, oy, dir = Lights.origin(s.x, s.y, s.facing or 1)
            local cache = {}
            for _, b in ipairs(BANDS) do
                fan(ox, oy, dir, b[1], level, cache)
                love.graphics.setColor(b[2], b[2], b[2] * 0.94, 1)
                for i = 0, RAYS - 1 do
                    love.graphics.polygon('fill', ox, oy, cache[i + 100], cache[i + 200], cache[i + 101], cache[i + 201])
                end
            end
        end
    end
    love.graphics.setCanvas(prevCanvas)
    love.graphics.setBlendMode('alpha')
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()
    -- Multiplicar sobre lo ya dibujado
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('multiply', 'premultiplied')
    love.graphics.draw(canvas, 0, 0, 0, DS, DS)
    love.graphics.setBlendMode('alpha')
end

-- Puntos luminosos y demás cosas que se ven en la oscuridad (encima de ella)
function Darkness.renderGlow(level, entities, camX, camY)
    if not Darkness.active(level) then return end
    for _, e in pairs(entities) do
        if e.alive and e.renderGlow then e:renderGlow(camX, camY) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Darkness
