-- src/fx/Anim.lua
-- ANIMACIONES COMO DATOS. Un "conjunto de animación" es un archivo assets/anim/<id>.json que dice de qué imágenes
-- salen los CUADROS y qué SECUENCIAS hay (quieto, andar, ataque...). Lo crea y lo cambia el editor de animaciones
-- (love . --anim), sin tocar código; el juego solo pregunta "¿qué cuadro toca?" y lo dibuja.
--
--   {
--     "id": "gummy",
--     "scale": 4,                            -- px de pantalla por píxel de arte (orientativo: lo usa quien dibuja)
--     "origin": [0.5, 1],                    -- ancla por defecto dentro del cuadro (0..1): 0.5, 1 = los pies
--     "frames": [                            -- CUADROS, numerados desde 1
--       { "image": "assets/images/enemies/gummy/gummy.png" },                        -- la imagen entera
--       { "image": "assets/.../hoja-Sheet.png", "x": 16, "y": 0, "w": 16, "h": 21 }   -- un recorte
--     ],
--     "anims": {                             -- SECUENCIAS
--       "walk": { "frames": [2, 3], "fps": 7, "loop": true,
--                 "durations": [0.1, 0.2],   -- (opcional) segundos de cada cuadro, en vez de 1/fps
--                 "events": { "2": "step" }, -- (opcional) nombre de un aviso al ENTRAR en ese cuadro de la secuencia
--                 "next": "idle" }           -- (opcional) secuencia que sigue al acabar (si loop = false)
--     },
--     "fallback": "idle",                    -- secuencia que se usa si se pide una que no existe
--     "variants": {                          -- el MISMO conjunto con otras imágenes (aspectos / islas)
--       "ice": { "from": "assets/images/enemies/gummy/", "to": "assets/images/enemies/gummy_ice/" }
--     }
--   }
--
-- Uso:
--   local Anim = require 'src/fx/Anim'
--   local set = Anim.load('gummy')            -- o Anim.load('gummy', 'ice'); se cachea
--   set:draw('walk', t, x, y, 0, sx, sy)      -- el cuadro que toca a los `t` segundos, anclado en su origen
--   local i, done = set:frameAt('dead', t)    -- índice de cuadro (y si la secuencia ya acabó)
--   set:drawFrame(i, x, y, r, sx, sy)         -- un cuadro concreto;  set:frameN('walk', k) = el k-ésimo de la secuencia
--   set:size()  → ancho, alto del primer cuadro (px de arte)
--
-- REGLA: el cuadro es una función PURA del nombre de la secuencia y del tiempo. Así el dibujo sale de lo que ya
-- viaja por red (estado + tiempo en el estado) y se ve igual en un jugador, en el servidor y online.
-- Funciona en el servidor sin gráficos (solo usa los tamaños de las imágenes).
local json = require 'libs/json'

local Anim = {}
Anim.DIR = 'assets/anim/'

local Set = {}
Set.__index = Set

local cache, images = {}, {}

local function image(path)
    if images[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            if img.setFilter then img:setFilter('nearest', 'nearest') end
            images[path] = img
        else
            images[path] = false
        end
    end
    return images[path] or nil
end

-- Ruta de un conjunto a partir de su id (o la propia ruta si ya lo es)
function Anim.path(id)
    if id:match('%.json$') then return id end
    return Anim.DIR .. id .. '.json'
end

-- Los ids de todos los conjuntos que hay (ordenados)
function Anim.list()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(Anim.DIR:gsub('/$', ''))) do
        local id = f:match('^(.+)%.json$')
        if id and not id:match('^_') then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- Datos crudos de un conjunto (tabla del JSON), o nil + error
function Anim.read(id)
    local text = love.filesystem.read(Anim.path(id))
    if not text then return nil, 'no existe ' .. Anim.path(id) end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then return nil, 'JSON no válido en ' .. Anim.path(id) end
    return data
end

-- Construye un conjunto a partir de sus datos (los del JSON). `variant` = nombre de una variante (o nil).
function Anim.fromData(data, variant)
    local set = setmetatable({ id = data.id, data = data, variant = variant, frames = {}, anims = {}, names = {} }, Set)
    set.scale = tonumber(data.scale) or 4
    set.ox = data.origin and tonumber(data.origin[1]) or 0.5
    set.oy = data.origin and tonumber(data.origin[2]) or 1
    local v = variant and data.variants and data.variants[variant]
    for i, f in ipairs(data.frames or {}) do
        local path = f.image or ''
        if v and v.from and v.to and path:sub(1, #v.from) == v.from then path = v.to .. path:sub(#v.from + 1) end
        local img = image(path)
        local iw, ih = 16, 16
        if img then iw, ih = img:getWidth(), img:getHeight() end
        local fr = { path = path, image = img, x = f.x or 0, y = f.y or 0, w = f.w or iw, h = f.h or ih, iw = iw, ih = ih,
                     ox = f.ox, oy = f.oy }
        if img and love.graphics.newQuad then fr.quad = love.graphics.newQuad(fr.x, fr.y, fr.w, fr.h, iw, ih) end
        set.frames[i] = fr
    end
    for name, a in pairs(data.anims or {}) do
        local seq = { name = name, frames = {}, loop = a.loop ~= false, fps = tonumber(a.fps) or 8, next = a.next, events = {} }
        for k, idx in ipairs(a.frames or {}) do seq.frames[k] = math.max(1, math.min(math.max(1, #set.frames), tonumber(idx) or 1)) end
        if #seq.frames == 0 then seq.frames[1] = 1 end
        -- cuándo empieza cada cuadro (s) y cuánto dura la secuencia
        seq.starts, seq.length = {}, 0
        for k = 1, #seq.frames do
            seq.starts[k] = seq.length
            local d = a.durations and tonumber(a.durations[k])
            seq.length = seq.length + ((d and d > 0) and d or 1 / math.max(0.01, seq.fps))
        end
        for k, ev in pairs(a.events or {}) do seq.events[tonumber(k) or 0] = ev end
        set.anims[name] = seq
        set.names[#set.names + 1] = name
    end
    table.sort(set.names)
    set.fallback = data.fallback or (set.anims.idle and 'idle') or set.names[1]
    return set
end

-- Carga (y cachea) un conjunto por id. Si no existe o está roto devuelve uno vacío de un cuadro (y lo avisa una vez).
function Anim.load(id, variant)
    local key = id .. '#' .. tostring(variant or '')
    if cache[key] then return cache[key] end
    local data, err = Anim.read(id)
    if not data then
        print('[Anim] ' .. tostring(err))
        data = { id = id, frames = {}, anims = {} }
    end
    data.id = data.id or id
    cache[key] = Anim.fromData(data, variant)
    return cache[key]
end

-- Olvida lo cargado (el editor, tras guardar; `id` = solo ese conjunto)
function Anim.reload(id)
    for k in pairs(cache) do
        if not id or k:sub(1, #id + 1) == id .. '#' then cache[k] = nil end
    end
    if not id then images = {} end
end
-- (el editor cambia una imagen en disco y quiere verla ya)
function Anim.forgetImage(path) images[path] = nil end

-- ── El conjunto ───────────────────────────────────────────────────────────────
function Set:has(name) return self.anims[name] ~= nil end

-- La secuencia `name` (o la de reserva si no existe); nil si el conjunto no tiene ninguna
function Set:seq(name)
    return self.anims[name] or self.anims[self.fallback or ''] or nil
end

-- Segundos que dura la secuencia (una pasada)
function Set:length(name)
    local s = self:seq(name)
    return s and s.length or 0
end

-- → índice de CUADRO del conjunto a los `t` s, ¿acabó? (solo si no se repite), posición k dentro de la secuencia
function Set:frameAt(name, t)
    local s = self:seq(name)
    if not s then return 1, true, 1 end
    t = math.max(0, t or 0)
    local done = false
    if s.loop then
        if s.length > 0 then t = t % s.length end
    elseif t >= s.length then
        return s.frames[#s.frames], true, #s.frames
    end
    local k = 1
    for i = #s.starts, 1, -1 do
        if t >= s.starts[i] then k = i; break end
    end
    return s.frames[k], done, k
end

-- El k-ésimo cuadro de la secuencia (dando la vuelta): para quien lleva su propio contador de cuadros
function Set:frameN(name, k)
    local s = self:seq(name)
    if not s then return 1 end
    return s.frames[((math.floor(k or 1) - 1) % #s.frames) + 1]
end

-- Avisos (`events`) de la secuencia entre los instantes t0 y t1 (t1 > t0): lista de nombres, en orden
function Set:eventsBetween(name, t0, t1)
    local s = self:seq(name)
    local out = {}
    if not s or not next(s.events) or t1 <= t0 then return out end
    local function scan(a, b, base)
        for k = 1, #s.starts do
            local at = base + s.starts[k]
            if s.events[k] and at > a and at <= b then out[#out + 1] = s.events[k] end
        end
    end
    if s.loop and s.length > 0 then
        for n = math.floor(t0 / s.length), math.floor(t1 / s.length) do scan(t0, t1, n * s.length) end
    else
        scan(t0, t1, 0)
    end
    return out
end

-- Ancho y alto (px de arte) de un cuadro (por defecto, el primero)
function Set:size(i)
    local f = self.frames[i or 1]
    if not f then return 16, 16 end
    return f.w, f.h
end

function Set:frame(i) return self.frames[math.max(1, math.min(#self.frames, i or 1))] end

-- Dibuja el cuadro `i` con su ancla en (x, y). ox, oy (0..1) cambian el ancla para esta llamada.
function Set:drawFrame(i, x, y, r, sx, sy, ox, oy)
    local f = self:frame(i)
    if not (f and f.image) then return end
    local ax = (ox or f.ox or self.ox) * f.w
    local ay = (oy or f.oy or self.oy) * f.h
    if f.quad then
        love.graphics.draw(f.image, f.quad, x, y, r or 0, sx or 1, sy or sx or 1, ax, ay)
    else
        love.graphics.draw(f.image, x, y, r or 0, sx or 1, sy or sx or 1, ax, ay)
    end
end

-- Dibuja el cuadro que toca de la secuencia `name` a los `t` s
function Set:draw(name, t, x, y, r, sx, sy, ox, oy)
    self:drawFrame((self:frameAt(name, t)), x, y, r, sx, sy, ox, oy)
end

-- ── Reproductor (para lo que no es simulación: menús, editores, adornos) ─────
-- local p = Anim.player(set, 'idle');  p:update(dt);  p:draw(x, y, r, sx, sy);  p:play('walk')
local Player = {}
Player.__index = Player
function Anim.player(set, name)
    return setmetatable({ set = set, name = name or set.fallback, t = 0, speed = 1, paused = false, onEvent = nil }, Player)
end
function Player:play(name, restart)
    if name ~= self.name or restart then self.name, self.t = name, 0 end
end
function Player:update(dt)
    if self.paused then return end
    local t0 = self.t
    self.t = self.t + dt * self.speed
    if self.onEvent then
        for _, ev in ipairs(self.set:eventsBetween(self.name, t0, self.t)) do self.onEvent(ev) end
    end
    local s = self.set:seq(self.name)
    if s and not s.loop and s.next and self.t >= s.length then self.name, self.t = s.next, self.t - s.length end
end
function Player:frame() return (self.set:frameAt(self.name, self.t)) end
function Player:finished()
    local _, done = self.set:frameAt(self.name, self.t)
    return done
end
function Player:draw(x, y, r, sx, sy, ox, oy) self.set:draw(self.name, self.t, x, y, r, sx, sy, ox, oy) end

return Anim
