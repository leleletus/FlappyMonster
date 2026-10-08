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

-- CONJUNTO DE ANIMACIÓN de la tira (assets/anim/<ruta de la imagen>.json, src/fx/Anim.lua; se edita con
-- `love . --anim`): si existe y corta la tira con el mismo ancho de cuadro que pide el código, los cuadros salen
-- de él (se pueden recortar a mano o cambiar de imagen sin tocar el código). OJO: el código usa los cuadros POR
-- NÚMERO (el 3 de la bomba es "a punto de estallar"): en esos conjuntos no cambies el orden ni el número.
-- La velocidad la pone el código, salvo que el conjunto diga "timing": "set" (entonces manda su secuencia `all`).
-- FM_ANIM_CAPTURE=<archivo>: apunta ahí cada tira que se carga sin conjunto (tools/anim/make_strip_sets.py los crea).

local SpriteStrip = {}
SpriteStrip.__index = SpriteStrip

local cache = {}
local Anim
local CAPTURE = os.getenv('FM_ANIM_CAPTURE')

-- La tira desde su conjunto (nil si no hay, o si no casa con lo que pide el código)
local function fromSet(path, frameW)
    Anim = Anim or require 'src/fx/Anim'
    local id = Anim.idOfImage(path)
    local data = Anim.read(id)
    if not data or type(data.strip) ~= 'table' or #(data.frames or {}) == 0 then return nil end
    if frameW and data.strip.frameW ~= frameW then return nil end
    local set = Anim.load(id)
    local seq = set.anims.all
    local order = seq and seq.frames or nil
    local n = order and #order or #set.frames
    local s = setmetatable({ quads = {}, images = {}, count = n, set = set, bySet = data.timing == 'set' }, SpriteStrip)
    for i = 1, n do
        local f = set.frames[order and order[i] or i]
        if not (f and f.image) then return nil end
        s.quads[i], s.images[i] = f.quad, f.image
    end
    local f1 = set.frames[order and order[1] or 1]
    s.image, s.w, s.h = f1.image, f1.w, f1.h
    return s
end

function SpriteStrip.load(path, frameW)
    local key = path .. '#' .. tostring(frameW or '')
    if cache[key] then return cache[key] end
    local ok, viaSet = pcall(fromSet, path, frameW)
    if ok and viaSet then cache[key] = viaSet; return viaSet end
    local img = love.graphics.newImage(path)
    if img.setFilter then img:setFilter('nearest', 'nearest') end
    local w, h = img:getWidth(), img:getHeight()
    local fw = frameW or h
    local n  = math.max(1, math.floor(w / fw))
    local quads = {}
    for i = 1, n do quads[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, h, w, h) end
    local s = setmetatable({ image = img, quads = quads, count = n, w = fw, h = h }, SpriteStrip)
    cache[key] = s
    if CAPTURE then
        local f = io.open(CAPTURE, 'a')
        if f then f:write(path, '\t', tostring(fw), '\t', tostring(w), '\t', tostring(h), '\n'); f:close() end
    end
    return s
end
-- (el editor, tras guardar un conjunto: que la tira se vuelva a montar)
function SpriteStrip.forget() cache = {} end

-- Cuadro (1..count) a los `t` segundos a `fps` cuadros/s (en bucle, o
-- quedándose en el último si loop == false)
function SpriteStrip:frameAt(t, fps, loop)
    if self.bySet then                                   -- ("timing": "set": manda la secuencia `all` del conjunto)
        local _, _, k = self.set:frameAt('all', t or 0)
        return k
    end
    local k = math.floor((t or 0) * (fps or 10))
    if loop == false then return math.min(self.count, k + 1) end
    return k % self.count + 1
end

-- Dibuja el cuadro `i` centrado en (x, y)
function SpriteStrip:draw(i, x, y, r, sx, sy)
    i = math.max(1, math.min(self.count, i or 1))
    love.graphics.draw(self.images and self.images[i] or self.image, self.quads[i], x, y, r or 0, sx or 1, sy or sx or 1, self.w / 2, self.h / 2)
end

return SpriteStrip
