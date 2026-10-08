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

-- CONJUNTO DE ANIMACIÓN (src/fx/Anim.lua; se edita con `love . --anim`): cada carpeta de imágenes tiene el suyo
-- (assets/anim/<carpeta>.json) y en él cada tira es UNA ANIMACIÓN con nombre, marcada con "sheet" = el archivo de
-- la tira y "frameW" = el ancho de cuadro que pide el código. Si existe, MANDA ELLA: los cuadros de la tira son los
-- de esa animación, en su orden y con su número (cada uno con la imagen o el recorte que tenga), y su velocidad
-- también: "codeFps" guarda los cuadros/s que pide el código; si la animación va a otra velocidad (o tiene
-- duraciones por cuadro), el tiempo se escala para que el juego la vea así.
-- Una hoja con varios ESTADOS (la del Gloomy: andar, quieto, agachado, salto, susto, muerto) va repartida en una
-- animación por estado; cada una dice con "at" qué números de cuadro de la hoja son los suyos (los que pide el código).
-- Sin animación para la tira, se corta la imagen tal cual.
-- FM_ANIM_CAPTURE=<archivo>: apunta ahí cada tira que se carga sin animación (compatibilidad: el juego ya pide sus
-- animaciones por nombre con Anim.clip; tools/anim/make_strip_sets.py las añade al conjunto de su carpeta).

local SpriteStrip = {}
SpriteStrip.__index = SpriteStrip

local cache = {}
local Anim
local CAPTURE = os.getenv('FM_ANIM_CAPTURE')

-- La tira desde el conjunto de su carpeta (nil si no hay, o si no casa con lo que pide el código)
local function fromSet(path, frameW)
    Anim = Anim or require 'src/fx/Anim'
    local dir, file = path:match('^assets/images/(.+)/([^/]+)$')
    if not dir then return nil end
    local data = Anim.read(dir)
    if not data then return nil end
    -- Una hoja puede estar repartida en VARIAS animaciones (una por estado: quieto, andar, saltar…): cada una dice
    -- con "at" a qué números de cuadro de la hoja responde (los que usa el código); sin "at", es la hoja entera.
    local parts = {}
    for n, a in pairs(data.anims or {}) do
        if a.sheet == file and (not frameW or a.frameW == frameW) then parts[#parts + 1] = { name = n, raw = a } end
    end
    if #parts == 0 then return nil end
    -- (lo normal: la hoja es UNA animación → es su clip, el mismo objeto que da Anim.clip(conjunto, nombre))
    if #parts == 1 and not parts[1].raw.at then return Anim.clip(dir, parts[1].name) end
    local set = Anim.load(dir)
    local s = setmetatable({ quads = {}, images = {}, count = 0, set = set }, SpriteStrip)
    for _, p in ipairs(parts) do
        local seq = set.anims[p.name]
        local at = p.raw.at
        for k = 1, at and #at or #seq.frames do
            local idx = at and at[k] or k
            local f = set.frames[seq.frames[(k - 1) % #seq.frames + 1]]      -- (con menos cuadros que huecos, se repiten)
            if not (f and f.image) then return nil end
            s.quads[idx], s.images[idx] = f.quad, f.image
            s.count = math.max(s.count, idx)
            if idx == 1 then s.image, s.w, s.h = f.image, f.w, f.h end
        end
    end
    for i = 1, s.count do if not s.quads[i] then return nil end end           -- (un número sin cuadro: se corta la imagen)
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
    local s = setmetatable({ image = img, quads = quads, count = n, w = fw, h = h, path = path }, SpriteStrip)
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
