-- src/ui/FlappyHud.lua
-- El HUD de los niveles FLAPPY (docs/design/flappy-plan-4-attack-and-cages.md), arriba a la izquierda bajo los puntos
-- y el tiempo: la VIDA en corazones (siempre a la vista: en Flappy cada golpe cuenta) y el medidor de CARGA del ataque
-- especial (PlayerAdventure.CHARGE_MAX celdas; parpadea lleno). Las vidas siguen arriba a la derecha (AdventureState).
-- Solo dibujo; la geometría se calcula al dibujar. Arte: assets/images/ui/flappy/hud-Sheet.png
-- (tools/art/ui/make_flappy_hud.py): corazón lleno · vacío · celda llena · vacía (8x8, ×4).
local FlappyHud = {}

local S = 4                      -- escala del arte (8 px → 32: la de los objetos y el icono de las vidas)
local X0, Y0 = 20, 108           -- (el sitio de la barra de vida de BossHud.drawPlayers)
local img, quads

local function load()
    if img then return end
    img = love.graphics.newImage('assets/images/ui/flappy/hud-Sheet.png')
    img:setFilter('nearest', 'nearest')
    quads = {}
    for i = 1, 4 do quads[i] = love.graphics.newQuad((i - 1) * 8, 0, 8, 8, img:getDimensions()) end
end

-- Dónde va cada cosa (las pruebas lo miran): { hearts = {x, y, step}, cells = {x, y, step} }
function FlappyHud.layout()
    return { hearts = { x = X0, y = Y0, step = 8 * S }, cells = { x = X0, y = Y0 + 9 * S, step = 7 * S } }
end

-- La BOLSA de los power-ups (táctil: abre la rueda; AdventureState:touchpressed): a la derecha de los corazones, en la
-- franja de arriba donde no hay controles táctiles (src/ui/TouchControls.lua TOP_FRAC)
-- (a la derecha de 7 corazones — Fácil con 3 corazones extra —: nunca los pisa)
function FlappyHud.bagRect() return { x = X0 + 7 * 8 * S + 8, y = Y0 - 4, w = 16 * S, h = 16 * S } end

local bagImg
function FlappyHud.drawBag(n)
    if not bagImg then
        bagImg = love.graphics.newImage('assets/images/ui/powerups/bag.png')
        bagImg:setFilter('nearest', 'nearest')
    end
    local b = FlappyHud.bagRect()
    love.graphics.setColor(1, 1, 1, n > 0 and 1 or 0.45)
    love.graphics.draw(bagImg, b.x, b.y, 0, S, S)
    if n > 0 then require('src/ui/PixelFont').shadow(tostring(n), b.x + b.w - 10, b.y + b.h - 18, 3, 1) end
    love.graphics.setColor(1, 1, 1, 1)
end

local iconImg, iconQ
function FlappyHud.drawEffects(pa, x, y)
    local Powerups = require 'src/world/powerups/Powerups'
    if not iconImg then
        iconImg = love.graphics.newImage('assets/images/ui/powerups/icons-Sheet.png')
        iconImg:setFilter('nearest', 'nearest')
        iconQ = {}
        for i = 1, iconImg:getWidth() / 12 do iconQ[i] = love.graphics.newQuad((i - 1) * 12, 0, 12, 12, iconImg:getDimensions()) end
    end
    local list = {}
    if pa.shield then list[#list + 1] = { id = 'shield' } end
    for _, p in ipairs(Powerups.LIST) do
        local t = pa.effects and pa.effects[p.id]
        if t and t > 0 then list[#list + 1] = { id = p.id, t = t } end
    end
    for i, it in ipairs(list) do
        local px = x + (i - 1) * 56
        local blink = (it.t and it.t < 3 and math.floor(love.timer.getTime() * 8) % 2 == 0) and 0.4 or 1
        love.graphics.setColor(1, 1, 1, blink)
        love.graphics.draw(iconImg, iconQ[Powerups.get(it.id).icon], px, y, 0, 4, 4)      -- (×4: la densidad de los objetos)
        if it.t then require('src/ui/PixelFont').shadow(tostring(math.ceil(it.t)), px + 34, y + 34, 2, 1) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function FlappyHud.draw(pa)
    if not pa then return end
    load()
    local Ly = FlappyHud.layout()
    local PA = require 'src/player/PlayerAdventure'
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, pa.hpMax or 3 do
        local full = not pa.dying and i <= (pa.hp or 0)
        love.graphics.draw(img, quads[full and 1 or 2], Ly.hearts.x + (i - 1) * Ly.hearts.step, Ly.hearts.y, 0, S, S)
    end
    -- los POWER-UPS activos (src/player/PlayerPowerups.lua): su icono y los segundos que quedan; el escudo mientras está
    FlappyHud.drawEffects(pa, Ly.cells.x, Ly.cells.y + 9 * S + 6)
    local max, c = PA.CHARGE_MAX or 5, pa.charge or 0
    local blink = (c >= max) and (math.floor(love.timer.getTime() * 6) % 2 == 0) and 0.55 or 1
    for i = 1, max do
        love.graphics.setColor(1, 1, 1, i <= c and blink or 1)
        love.graphics.draw(img, quads[i <= c and 3 or 4], Ly.cells.x + (i - 1) * Ly.cells.step, Ly.cells.y, 0, S, S)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return FlappyHud
