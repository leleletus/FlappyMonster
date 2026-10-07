-- src/fx/Snowfall.lua
-- Nieve cayendo por todo el nivel (JSON "snow": true; editor: pestaña Nivel →
-- Clima). SOLO dibujo: no choca con nada ni afecta al juego. Los copos viven
-- alrededor de la cámara (siempre hay nieve donde se mira) y tienen tres
-- "profundidades": los de lejos, pequeños, lentos y más tenues; los de cerca,
-- grandes y rápidos. Se mecen con un viento suave.
-- Sprites: assets/images/fx/snowflakes.png (4 cuadros de 7x7), generados por
-- tools/art/world/make_snow_sprites.py.
--   Snowfall.render(level, camX, camY)   (delante de todo, antes del HUD)

local SpriteStrip = require 'src/fx/SpriteStrip'

local Snowfall = {}
local sheet
local COUNT = 90
-- profundidad: { escala, velocidad, alfa, cuadros posibles }
local LAYERS = {
    { s = 1, vy = { 28, 45 },  a = 0.55, frames = { 4, 1 } },
    { s = 2, vy = { 50, 80 },  a = 0.8,  frames = { 1, 2, 4 } },
    { s = 3, vy = { 85, 130 }, a = 0.95, frames = { 2, 3 } },
}

local function spawn(f, camX, camY, top)
    local L = LAYERS[math.random(#LAYERS)]
    f.layer = L
    f.frame = L.frames[math.random(#L.frames)]
    f.x = camX - 60 + math.random() * (WINDOW_W + 120)
    f.y = top and (camY - 20 - math.random() * 60) or (camY - 20 + math.random() * (WINDOW_H + 40))
    f.vy = L.vy[1] + math.random() * (L.vy[2] - L.vy[1])
    f.sway, f.phase = 10 + math.random() * 22, math.random() * 6.28
end

function Snowfall.render(level, camX, camY)
    if not level.snow then return end
    sheet = sheet or SpriteStrip.load('assets/images/fx/snowflakes.png', 7)
    local dt = math.min(0.05, love.timer.getDelta())
    local list = level._snow
    if not list then
        list = {}
        for i = 1, COUNT do list[i] = {}; spawn(list[i], camX, camY, false) end
        level._snow = list
    end
    local now = love.timer.getTime()
    local wind = 12 + 10 * math.sin(now * 0.3)
    for _, f in ipairs(list) do
        f.y = f.y + f.vy * dt
        f.x = f.x + wind * dt * f.layer.s * 0.6
        local x = f.x + math.sin(now * 1.3 + f.phase) * f.sway
        -- Fuera de la vista (cayó, o la cámara se movió): vuelve arriba / al otro lado
        if f.y > camY + WINDOW_H + 20 then spawn(f, camX, camY, true)
        elseif x < camX - 80 then f.x = f.x + WINDOW_W + 140
        elseif x > camX + WINDOW_W + 80 then f.x = f.x - WINDOW_W - 140
        elseif f.y < camY - 120 then spawn(f, camX, camY, false) end
        love.graphics.setColor(1, 1, 1, f.layer.a)
        sheet:draw(f.frame, math.floor(x - camX), math.floor(f.y - camY), 0, f.layer.s, f.layer.s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Snowfall
