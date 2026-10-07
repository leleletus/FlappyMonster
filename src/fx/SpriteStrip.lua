-- src/fx/SpriteStrip.lua
-- Tiras de animación: una imagen con los cuadros uno al lado del otro (p. ej.
-- assets/images/enemies/mortar/flame.png, 48x16 = 3 cuadros de 16x16).
--
--   local SpriteStrip = require 'src/fx/SpriteStrip'
--   local fire = SpriteStrip.load('assets/images/enemies/mortar/flame.png')   -- cuadros cuadrados
--   local run  = SpriteStrip.load('assets/.../run.png', 24)         -- cuadros de 24 px de ancho
--   fire:draw(fire:frameAt(t, 10), x, y, 0, 4, 4)                   -- centrado en x, y
--
-- Sin ancho de cuadro se asumen cuadros cuadrados (ancho = alto de la imagen).
-- Se cachean por ruta. Funciona en el servidor headless (solo usa tamaños).

local SpriteStrip = {}
SpriteStrip.__index = SpriteStrip

local cache = {}

function SpriteStrip.load(path, frameW)
    local key = path .. '#' .. tostring(frameW or '')
    if cache[key] then return cache[key] end
    local img = love.graphics.newImage(path)
    if img.setFilter then img:setFilter('nearest', 'nearest') end
    local w, h = img:getWidth(), img:getHeight()
    local fw = frameW or h
    local n  = math.max(1, math.floor(w / fw))
    local quads = {}
    for i = 1, n do quads[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, h, w, h) end
    local s = setmetatable({ image = img, quads = quads, count = n, w = fw, h = h }, SpriteStrip)
    cache[key] = s
    return s
end

-- Cuadro (1..count) a los `t` segundos a `fps` cuadros/s (en bucle, o
-- quedándose en el último si loop == false)
function SpriteStrip:frameAt(t, fps, loop)
    local k = math.floor((t or 0) * (fps or 10))
    if loop == false then return math.min(self.count, k + 1) end
    return k % self.count + 1
end

-- Dibuja el cuadro `i` centrado en (x, y)
function SpriteStrip:draw(i, x, y, r, sx, sy)
    local q = self.quads[math.max(1, math.min(self.count, i or 1))]
    love.graphics.draw(self.image, q, x, y, r or 0, sx or 1, sy or sx or 1, self.w / 2, self.h / 2)
end

return SpriteStrip
