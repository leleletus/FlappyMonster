-- src/ui/LoadingScreen.lua
-- La PANTALLA DE CARGA (0.5.201; el usuario: «negra, en la esquina de abajo a la derecha el monstruo completamente
-- blanco corriendo y "Cargando..." con los puntitos»). Casi nadie la verá: solo sale cuando cargar un nivel tarda de
-- verdad. Cómo: se mide lo que tarda cada cambio a un estado PESADO (los niveles); si uno pasó de SLOW s, el aparato es
-- lento y desde entonces, antes de cada carga pesada, se dibuja un cuadro de carga (y se enseña) para que no parezca
-- colgado. En los aparatos rápidos nunca sale.
--   LoadingScreen.wrap(stateMachine)   (game.lua) envuelve change() para medir y enseñar
--   LoadingScreen.draw(t)              el dibujo (los arneses lo capturan)
local L = require 'src/core/Lang'
local LS = { SLOW = 0.2, slow = false, HEAVY = { adventure = true, online_adventure = true } }
local img, quads

local function art()
    if img then return end
    img = love.graphics.newImage('assets/images/ui/loading/run-Sheet.png')
    img:setFilter('nearest', 'nearest')
    local fw = img:getWidth() / 3
    quads = {}
    for i = 1, 3 do quads[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, img:getHeight(), img:getDimensions()) end
end

function LS.draw(t)
    t = t or love.timer.getTime()
    art()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    local S = 5
    local fw, fh = img:getWidth() / 3 * S, img:getHeight() * S
    local x, y = WINDOW_W - fw - 40, WINDOW_H - fh - 34
    local bob = (math.floor(t * 10) % 2 == 0) and 0 or -S
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, quads[math.floor(t * 12) % 3 + 1], x, y + bob, 0, S, S)
    local dots = string.rep('.', math.floor(t * 3) % 4)
    love.graphics.setFont(FONT_MED)
    local base = L('loading.text')
    local tx = x - 24 - FONT_MED:getWidth(base .. '...')
    love.graphics.print(base .. dots, tx, y + fh - FONT_MED:getHeight() - 4)
end

-- Un cuadro de carga en pantalla AHORA (antes de una carga larga)
function LS.present()
    if not (love.graphics and love.graphics.isActive and love.graphics.isActive()) then return end
    love.graphics.origin()
    lovesize.begin()
    LS.draw()
    lovesize.finish()
    love.graphics.present()
end

function LS.wrap(sm)
    local change = sm.change
    sm.change = function(self, name, args)
        if not LS.HEAVY[name] then return change(self, name, args) end
        if LS.slow then LS.present() end
        local t0 = love.timer.getTime()
        local r = change(self, name, args)
        if love.timer.getTime() - t0 > LS.SLOW then LS.slow = true end
        return r
    end
end

return LS
