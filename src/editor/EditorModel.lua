-- src/editor/EditorModel.lua
-- Datos del nivel que se está editando + operaciones, guardado y validación.
-- El formato de salida es el mismo que carga el juego (Level.fromData).

local json     = require 'libs/json'
local Tiles    = require 'src/world/Tiles'
local Entities = require 'src/world/Entities'
local Level    = require 'src/world/Level'
local DT       = require('src/world/Decorations').types

local Codec = Tiles.codec
local ET    = Entities.types

local Model = {}
Model.__index = Model

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end
Model.deepcopy = deepcopy

-- ── Crear / cargar ────────────────────────────────────────────────────────────
function Model.new(w, h, name)
    local m = setmetatable({}, Model)
    m.name, m.width, m.height = name or 'nuevo', w, h
    m.tiles = {}
    for r = 1, h do
        m.tiles[r] = {}
        for c = 1, w do
            local edge = (r == 1 or c == 1 or r == h or c == w)
            m.tiles[r][c] = edge and TILE_BORDER or TILE_EMPTY
        end
    end
    m.playerStart = { 3, h - 2 }
    m.entities, m.foliage, m.vents = {}, {}, {}
    m.path = nil
    return m
end

function Model.fromData(lvl, path)
    local m = setmetatable({}, Model)
    m.name   = lvl.name or 'nivel'
    m.width  = lvl.width
    m.height = lvl.height
    m.tiles  = {}
    for r = 1, m.height do
        m.tiles[r] = {}
        for c = 1, m.width do
            m.tiles[r][c] = math.floor(tonumber(lvl.tiles[r] and lvl.tiles[r][c]) or 0)
        end
    end
    m.playerStart = deepcopy(lvl.playerStart or { 2, 2 })
    m.entities = {}
    for _, ed in ipairs(lvl.entities or lvl.enemies or {}) do
        local n = ET.normalize(ed)
        if n then table.insert(m.entities, n) end
    end
    m.foliage = {}
    for _, fd in ipairs(lvl.foliage or {}) do
        local n = DT.normalize(fd)
        if n then table.insert(m.foliage, n) end
    end
    m.vents   = deepcopy(lvl.vents or {})
    m.path    = path
    return m
end

function Model.load(path)
    local data = love.filesystem.read(path)
    if not data then return nil, 'No se pudo leer ' .. tostring(path) end
    local ok, lvl = pcall(json.decode, data)
    if not ok or type(lvl) ~= 'table' or not lvl.tiles then return nil, 'JSON invalido: ' .. tostring(path) end
    return Model.fromData(lvl, path)
end

-- ── Serializar ────────────────────────────────────────────────────────────────
function Model:toData()
    local ents = {}
    for _, e in ipairs(self.entities) do table.insert(ents, ET.serialize(e)) end
    local decos = {}
    for _, d in ipairs(self.foliage) do table.insert(decos, DT.serialize(d)) end
    return {
        name = self.name, width = self.width, height = self.height,
        playerStart = self.playerStart, tiles = self.tiles,
        entities = ents, foliage = decos, vents = self.vents,
    }
end

-- JSON estable y legible: claves ordenadas, una fila de tiles por línea.
local function enc(v, ind)
    if type(v) ~= 'table' then return json.encode(v) end
    if #v > 0 or next(v) == nil then
        local parts = {}
        for i = 1, #v do parts[i] = enc(v[i], ind) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}
    for k in pairs(v) do keys[#keys+1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts+1] = json.encode(k) .. ':' .. enc(v[k], ind) end
    return '{' .. table.concat(parts, ',') .. '}'
end

function Model:encode()
    local d = self:toData()
    local out = { '{' }
    local function line(s, last) out[#out+1] = '  ' .. s .. (last and '' or ',') end
    line('"name": ' .. json.encode(d.name))
    line('"width": ' .. d.width)
    line('"height": ' .. d.height)
    line('"playerStart": ' .. enc(d.playerStart))
    local rows = {}
    for r = 1, d.height do rows[r] = '    ' .. enc(d.tiles[r]) end
    out[#out+1] = '  "tiles": [\n' .. table.concat(rows, ',\n') .. '\n  ],'
    local function list(name, items, last)
        if #items == 0 then line('"' .. name .. '": []', last); return end
        local l = {}
        for i, it in ipairs(items) do l[i] = '    ' .. enc(it) end
        out[#out+1] = '  "' .. name .. '": [\n' .. table.concat(l, ',\n') .. '\n  ]' .. (last and '' or ',')
    end
    list('entities', d.entities)
    list('foliage', d.foliage)
    list('vents', d.vents, true)
    out[#out+1] = '}'
    return table.concat(out, '\n') .. '\n'
end

-- Guarda en la carpeta del juego (assets/levels/...). Requiere ejecutar el
-- juego desde su carpeta (no empaquetado en .love).
function Model:save(relPath)
    local src = love.filesystem.getSource()
    local info = love.filesystem.getInfo('main.lua')
    if not src or not info or src:match('%.love$') then
        return false, 'Solo se puede guardar ejecutando el juego desde su carpeta'
    end
    local f, err = io.open(src .. '/' .. relPath, 'w')
    if not f then return false, tostring(err) end
    f:write(self:encode()); f:close()
    self.path = relPath
    return true
end

-- Nivel del juego (para dibujar) a partir de estos datos
function Model:buildLevel()
    return Level.fromData(deepcopy(self:toData()))
end

-- ── Copias (deshacer) ─────────────────────────────────────────────────────────
function Model:snapshot()
    return deepcopy({ name=self.name, width=self.width, height=self.height, tiles=self.tiles,
                      playerStart=self.playerStart, entities=self.entities,
                      foliage=self.foliage, vents=self.vents })
end

function Model:restore(s)
    s = deepcopy(s)
    for k, v in pairs(s) do self[k] = v end
end

-- ── Celdas ────────────────────────────────────────────────────────────────────
function Model:inBounds(c, r) return c >= 1 and r >= 1 and c <= self.width and r <= self.height end
function Model:get(c, r) return self:inBounds(c, r) and self.tiles[r][c] or nil end

function Model:set(c, r, raw)
    if not self:inBounds(c, r) or self.tiles[r][c] == raw then return false end
    self.tiles[r][c] = raw
    return true
end

-- Cambia el tipo conservando agua y pinchos de la celda
function Model:setId(c, r, id)
    local raw = self:get(c, r); if not raw then return false end
    local _, wl, sp = Codec.decode(raw)
    return self:set(c, r, Codec.encode(id, wl, sp))
end

function Model:setWater(c, r, on)
    local raw = self:get(c, r); if not raw then return false end
    local id, _, sp = Codec.decode(raw)
    return self:set(c, r, Codec.encode(id, on, sp))
end

function Model:setSpike(c, r, sub, present, dir)
    local raw = self:get(c, r); if not raw then return false end
    local id, wl, sp = Codec.decode(raw)
    sp[sub] = { present = present, dir = dir or 0 }
    return self:set(c, r, Codec.encode(id, wl, sp))
end

-- Relleno por inundación: todas las celdas conectadas con la misma "clave"
function Model:flood(c, r, keyFn, apply)
    local start = self:get(c, r); if not start then return 0 end
    local key = keyFn(start)
    local seen, q, n = {}, { { c, r } }, 0
    seen[r * 100000 + c] = true
    local head = 1
    while head <= #q do
        local cc, rr = q[head][1], q[head][2]; head = head + 1
        if apply(cc, rr) then n = n + 1 end
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nc, nr = cc + d[1], rr + d[2]
            local k = nr * 100000 + nc
            if not seen[k] and self:inBounds(nc, nr) and keyFn(self.tiles[nr][nc]) == key then
                seen[k] = true; q[#q+1] = { nc, nr }
            end
        end
    end
    return n
end

-- Redimensionar (anclado arriba-izquierda). Objetos fuera se descartan.
function Model:resize(w, h)
    local t = {}
    for r = 1, h do
        t[r] = {}
        for c = 1, w do t[r][c] = (self.tiles[r] and self.tiles[r][c]) or TILE_EMPTY end
    end
    self.tiles, self.width, self.height = t, w, h
    local function keep(list) local o = {} for _, x in ipairs(list) do if x.col <= w and x.row <= h then o[#o+1] = x end end return o end
    self.entities, self.foliage, self.vents = keep(self.entities), keep(self.foliage), keep(self.vents)
    self.playerStart[1] = math.min(self.playerStart[1], w)
    self.playerStart[2] = math.min(self.playerStart[2], h)
end

-- Rodear el mapa con el tile de borde
function Model:frame(id)
    for c = 1, self.width do self:setId(c, 1, id); self:setId(c, self.height, id) end
    for r = 1, self.height do self:setId(1, r, id); self:setId(self.width, r, id) end
end

-- ── Objetos ───────────────────────────────────────────────────────────────────
function Model:entityAt(c, r)
    for i = #self.entities, 1, -1 do
        local e = self.entities[i]
        if e.col == c and e.row == r then return e, i end
    end
end

function Model:addEntity(typeName, c, r)
    local n = ET.normalize({ type = typeName, col = c, row = r })
    if n then table.insert(self.entities, n) end
    return n
end

function Model:findObject(list, c, r, sub)
    for i = #list, 1, -1 do
        local o = list[i]
        if o.col == c and o.row == r and (sub == nil or o.sub == sub) then return o, i end
    end
end

-- ── Validación ────────────────────────────────────────────────────────────────
function Model:validate()
    local w = {}
    local ps = self.playerStart
    if not ps or not self:inBounds(ps[1], ps[2]) then
        w[#w+1] = { 'error', 'El punto de inicio esta fuera del mapa' }
    elseif Tiles.get(Codec.id(self.tiles[ps[2]][ps[1]])).collision == 'solid' then
        w[#w+1] = { 'error', 'El punto de inicio esta dentro de un bloque solido' }
    end
    for _, e in ipairs(self.entities) do
        local t = ET.get(e.type)
        local where = (t and t.label or e.type) .. ' (' .. e.col .. ',' .. e.row .. ')'
        if not self:inBounds(e.col, e.row) then
            w[#w+1] = { 'error', where .. ' esta fuera del mapa', e }
        elseif Tiles.get(Codec.id(self.tiles[e.row][e.col])).collision == 'solid' then
            w[#w+1] = { 'warn', where .. ' esta dentro de un bloque', e }
        end
        local p = e.props
        if p.patrol and (e.col < p.patrol.left or e.col > p.patrol.right) then
            w[#w+1] = { 'warn', where .. ': su ruta no la contiene', e }
        end
    end
    if #self.entities == 0 then w[#w+1] = { 'info', 'El nivel no tiene entidades' } end
    return w
end

return Model
