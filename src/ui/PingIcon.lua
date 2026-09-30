-- src/ui/PingIcon.lua
-- Indicador de conexión en partida online (pixel art): una antena y 4 barras.
--   4 barras verdes      buena conexión
--   3 / 2 amarillas      regular / no ideal
--   1 roja               mala
--   vacía con una X roja sin datos: probablemente desconectado
-- La calidad sale del ping (RTT de ENet) y de cuánto hace que llegó el último
-- snapshot (el servidor manda 30 por segundo: si dejan de llegar, el RTT de
-- ENet se queda congelado y no lo diría). Cambia con un poco de retraso para
-- no parpadear (empeorar mucho se ve al momento).
--
--   local PingIcon = require 'src/ui/PingIcon'
--   local ind = PingIcon.new()
--   ind:update(dt, pingMs, snapAgeS, connected)   -- cada frame
--   ind:draw(x, y)                                 -- esquina inferior izquierda de la antena

local PingIcon = {}
PingIcon.__index = PingIcon

-- Nivel (0..4) a partir del ping y la edad del último snapshot
function PingIcon.level(ping, snapAge, connected)
    if not connected or snapAge > 1.5 then return 0 end
    if snapAge > 0.5 or ping >= 250 then return 1 end
    if ping >= 160 or snapAge > 0.25 then return 2 end
    if ping >= 90 then return 3 end
    return 4
end

local COLORS = {
    [1] = { 0.95, 0.2, 0.2 },
    [2] = { 1, 0.82, 0.15 },
    [3] = { 1, 0.82, 0.15 },
    [4] = { 0.3, 0.9, 0.35 },
}

function PingIcon.new()
    return setmetatable({ shown = 4, want = 4, holdT = 0, ping = 0 }, PingIcon)
end

function PingIcon:update(dt, ping, snapAge, connected)
    self.ping = ping or 0
    local lv = PingIcon.level(self.ping, snapAge or 0, connected ~= false)
    if lv ~= self.want then self.want, self.holdT = lv, 0 end
    self.holdT = self.holdT + dt
    -- (empeorar 2 niveles o más, o perder la conexión, se ve ya; lo demás tras 0,6 s)
    if lv ~= self.shown and (self.holdT >= 0.6 or lv <= self.shown - 2 or lv == 0) then self.shown = lv end
end

-- Dibuja la antena con su esquina inferior izquierda en (x, y). `px` = tamaño
-- de un píxel del arte (3 por defecto)
function PingIcon:draw(x, y, px)
    px = px or 3
    x, y = math.floor(x), math.floor(y)
    local lv = self.shown
    local col = COLORS[lv] or COLORS[1]
    local function rect(cx, cy, w, h, c, a)
        -- (con sombra negra, como el resto de la interfaz)
        love.graphics.setColor(0, 0, 0, 0.6 * (a or 1))
        love.graphics.rectangle('fill', x + cx * px + 2, y - (cy + h) * px + 2, w * px, h * px)
        love.graphics.setColor(c[1], c[2], c[3], a or 1)
        love.graphics.rectangle('fill', x + cx * px, y - (cy + h) * px, w * px, h * px)
    end
    -- Antena: mástil y travesaño
    local grey = { 0.85, 0.85, 0.9 }
    rect(1, 0, 1, 9, grey)
    rect(0, 8, 3, 1, grey)
    -- Barras (2 px de ancho, 1 de hueco; alturas 2, 4, 6, 8)
    for i = 1, 4 do
        local bx, h = 4 + (i - 1) * 3, i * 2
        if i <= lv then rect(bx, 0, 2, h, col)
        else rect(bx, 0, 2, h, { 0.25, 0.25, 0.3 }, 0.8) end
    end
    -- Sin conexión: X roja encima de las barras
    if lv == 0 then
        local red = { 0.95, 0.15, 0.15 }
        for k = 0, 4 do
            rect(5 + k, 1 + k, 1, 1, red)
            rect(9 - k, 1 + k, 1, 1, red)
        end
    end
    -- Ping en ms al lado (pequeño)
    if FONT_SMALL and lv > 0 then
        love.graphics.setFont(FONT_SMALL)
        local txt = string.format('%d ms', math.floor(self.ping + 0.5))
        local tx, ty = x + 17 * px, y - 4 * px - FONT_SMALL:getHeight() / 2
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print(txt, math.floor(tx) + 2, math.floor(ty) + 2)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.print(txt, math.floor(tx), math.floor(ty))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PingIcon
