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
-- (El código que elige un cuadro por su número — p. ej. por lo cerca que está la bomba de estallar — ve los cuadros
-- de la animación numerados en su orden.) Sin animación para la tira, se corta la imagen tal cual.
-- FM_ANIM_CAPTURE=<archivo>: apunta ahí cada tira que se carga sin animación y, de todas, a qué velocidad las pide
-- el código (tools/anim/make_strip_sets.py las añade al conjunto de su carpeta).

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
    local name, raw
    for n, a in pairs(data.anims or {}) do
        if a.sheet == file and (not frameW or a.frameW == frameW) then name, raw = n, a; break end
    end
    if not name then return nil end
    local set = Anim.load(dir)
    local seq = set.anims[name]
    local n = #seq.frames
    local s = setmetatable({ quads = {}, images = {}, count = n, set = set, seq = seq, anim = name, nominal = tonumber(raw.codeFps) }, SpriteStrip)
    s.custom = type(raw.durations) == 'table' and #raw.durations > 0
    for i = 1, n do
        local f = set.frames[seq.frames[i]]
        if not (f and f.image) then return nil end
        s.quads[i], s.images[i] = f.quad, f.image
    end
    local f1 = set.frames[seq.frames[1]]
    s.image, s.w, s.h = f1.image, f1.w, f1.h
    return s
end

function SpriteStrip.load(path, frameW)
    local key = path .. '#' .. tostring(frameW or '')
    if cache[key] then return cache[key] end
    local ok, viaSet = pcall(fromSet, path, frameW)
    if ok and viaSet then viaSet.path = path; cache[key] = viaSet; return viaSet end
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
    fps = fps or 10
    if CAPTURE and not self.logged then
        self.logged = true
        local f = io.open(CAPTURE, 'a')
        if f then f:write('@fps\t', self.path, '\t', tostring(fps), '\t', loop == false and '0' or '1', '\n'); f:close() end
    end
    local seq = self.seq
    -- (el conjunto pide otra velocidad que la del código, o duraciones propias: el tiempo se escala y manda él)
    if seq and self.nominal and self.nominal > 0 and (seq.fps ~= self.nominal or self.custom) then
        local _, _, k = self.set:frameAt(self.anim, (t or 0) * fps / self.nominal)
        return math.max(1, math.min(self.count, k or 1))
    end
    local k = math.floor((t or 0) * fps)
    if loop == false then return math.min(self.count, k + 1) end
    return k % self.count + 1
end

-- Dibuja el cuadro `i` centrado en (x, y)
function SpriteStrip:draw(i, x, y, r, sx, sy)
    i = math.max(1, math.min(self.count, i or 1))
    love.graphics.draw(self.images and self.images[i] or self.image, self.quads[i], x, y, r or 0, sx or 1, sy or sx or 1, self.w / 2, self.h / 2)
end

return SpriteStrip
