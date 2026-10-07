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

-- Sprites: assets/images/ui/ping/ping-Sheet.png, 5 cuadros de 20x12 (0 = X
-- roja, 1..4 = barras; los genera tools/art/ui/make_sprites.py y se pueden retocar)
local SpriteStrip = require 'src/fx/SpriteStrip'
local sheet
local TEXT_COL = { [1] = { 0.95, 0.2, 0.2 }, [2] = { 1, 0.82, 0.15 }, [3] = { 1, 0.82, 0.15 }, [4] = { 0.3, 0.9, 0.35 } }
PingIcon.W, PingIcon.H = 20, 12

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

-- Ancho total (antena + texto) a escala `px`, para colocarla
function PingIcon:width(px)
    px = px or 3
    local tw = (FONT_SMALL and self.shown > 0) and (FONT_SMALL:getWidth('000 ms') + 3 * px) or 0
    return PingIcon.W * px + tw
end

-- Dibuja la antena con su esquina inferior izquierda en (x, y). `px` = tamaño
-- de un píxel del arte (3 por defecto)
function PingIcon:draw(x, y, px)
    px = px or 3
    sheet = sheet or SpriteStrip.load('assets/images/ui/ping/ping-Sheet.png', PingIcon.W)
    x, y = math.floor(x), math.floor(y)
    local lv = self.shown
    local cx, cy = x + PingIcon.W * px / 2, y - PingIcon.H * px / 2
    -- (sombra negra, como el resto de la interfaz)
    love.graphics.setColor(0, 0, 0, 0.6)
    sheet:draw(lv + 1, cx + 2, cy + 2, 0, px, px)
    love.graphics.setColor(1, 1, 1, 1)
    sheet:draw(lv + 1, cx, cy, 0, px, px)
    -- Ping en ms al lado (pequeño)
    if FONT_SMALL and lv > 0 then
        local col = TEXT_COL[lv]
        love.graphics.setFont(FONT_SMALL)
        local txt = string.format('%d ms', math.floor(self.ping + 0.5))
        local tx, ty = x + (PingIcon.W + 3) * px, y - PingIcon.H * px / 2 - FONT_SMALL:getHeight() / 2
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print(txt, math.floor(tx) + 2, math.floor(ty) + 2)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.print(txt, math.floor(tx), math.floor(ty))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PingIcon
