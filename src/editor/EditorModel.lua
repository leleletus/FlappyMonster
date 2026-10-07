-- src/editor/EditorModel.lua
-- Datos del nivel que se está editando + operaciones, guardado y validación.
-- El formato de salida es el mismo que carga el juego (Level.fromData).

local json     = require 'libs/json'
local Tiles    = require 'src/world/tiles/Tiles'
local Entities = require 'src/world/entities/Entities'
local Level    = require 'src/world/level/Level'
local DT       = require('src/world/decorations/Decorations').types
local BossZones = require 'src/world/systems/BossZones'
local AutoScroll = require 'src/world/systems/AutoScroll'
local SubTiles  = require 'src/world/level/SubTiles'

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
    m.entities, m.foliage, m.vents, m.subtiles, m.links, m.blockLinks = {}, {}, {}, {}, {}, {}
    m.bossZones = {}
    m.autoScroll = nil
    m.path = nil
    return m
end

function Model.fromData(lvl, path)
    local m = setmetatable({}, Model)
    m.name   = lvl.name or 'nivel'
    m.name_en = lvl.name_en                                -- (nombre en inglés)
    m.parTime = tonumber(lvl.parTime)                      -- (tiempo objetivo, s; nil = automático por el ancho)
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
    m.links = {}
    for _, l in ipairs(lvl.links or {}) do
        local c, r, id = tonumber(l.col), tonumber(l.row), tonumber(l.to or l.flood)   -- (flood: nombre antiguo)
        if c and r and id then m.links[#m.links + 1] = { col = c, row = r, to = id } end
    end
    m.blockLinks = {}
    for _, l in ipairs(lvl.blockLinks or {}) do
        local c, r, f = tonumber(l.col), tonumber(l.row), l.from
        if c and r and type(f) == 'table' and tonumber(f[1]) and tonumber(f[2]) then
            m.blockLinks[#m.blockLinks + 1] = { col = c, row = r, from = { tonumber(f[1]), tonumber(f[2]) } }
        end
    end
    m.subtiles = {}
    for _, o in ipairs(lvl.subtiles or {}) do
        local n = SubTiles.normalize(o)
        if n then table.insert(m.subtiles, n) end
    end
    m.bossZones = {}
    for i, z in ipairs(lvl.bossZones or {}) do
        local n = BossZones.normalize(z, i)
        if n then table.insert(m.bossZones, n) end
    end
    m.autoScroll = AutoScroll.normalize(lvl.autoScroll)
    -- Modos en los que se ofrece (nil = todos los que admitan el nivel) y
    -- duración de las partidas con tiempo
    m.modes     = (type(lvl.modes) == 'table' and #lvl.modes > 0) and deepcopy(lvl.modes) or nil
    m.matchTime = tonumber(lvl.matchTime)
    m.music     = type(lvl.music) == 'string' and lvl.music or nil
    m.snow      = lvl.snow == true or nil                 -- (nieve cayendo: solo visual)
    m.peaceful  = lvl.peaceful == true or nil             -- (enemigos inofensivos: niveles de prueba)
    m.dark      = lvl.dark == true or nil                 -- (nivel a oscuras, con linterna)
    m.echo      = lvl.echo                                 -- (eco: nil = como 'dark')
    m.light     = lvl.light                                -- (luz ambiente: nil = automática, Level.lightMood)
    m.spikeSkin = (lvl.spikeSkin ~= 'normal') and lvl.spikeSkin or nil   -- (aspecto de los pinchos: solo visual)
    m.background = lvl.background                          -- (fondo: bioma de src/fx/Sky.lua)
    m.time      = lvl.time                                 -- (hora: day/dusk/night)
    m.clouds    = (lvl.clouds == false) and false or nil
    m.depth     = lvl.depth                                -- (fondo de profundidad)
    m.surfaceRow = tonumber(lvl.surfaceRow)               -- (fila de la línea de superficie; nil = auto)
    m.path    = path
    m:fixActivatableIds()
    m:pruneLinks()
    return m
end

function Model.load(path)
    local data = love.filesystem.read(path)
    if not data then return nil, 'No se pudo leer ' .. tostring(path) end
    local ok, lvl = pcall(json.decode, data)
    if not ok or type(lvl) ~= 'table' or not lvl.tiles then return nil, 'JSON inválido: ' .. tostring(path) end
    return Model.fromData(lvl, path)
end

-- ── Serializar ────────────────────────────────────────────────────────────────
function Model:toData()
    local ents = {}
    for _, e in ipairs(self.entities) do table.insert(ents, ET.serialize(e)) end
    local decos = {}
    for _, d in ipairs(self.foliage) do table.insert(decos, DT.serialize(d)) end
    local zones = {}
    for _, z in ipairs(self.bossZones) do table.insert(zones, BossZones.serialize(z)) end
    -- (solo se guarda `solid` cuando es false: por defecto son sólidos)
    local subs = {}
    for _, o in ipairs(self.subtiles or {}) do
        local d = { col = o.col, row = o.row, sub = o.sub, kind = o.kind }
        if o.solid == false then d.solid = false end
        subs[#subs+1] = d
    end
    return {
        name = self.name, name_en = self.name_en, parTime = self.parTime, width = self.width, height = self.height,
        playerStart = self.playerStart, tiles = self.tiles,
        entities = ents, foliage = decos, vents = self.vents, bossZones = zones, subtiles = subs, links = self.links or {}, blockLinks = self.blockLinks or {},
        autoScroll = AutoScroll.serialize(self.autoScroll),
        modes = self.modes, matchTime = self.matchTime, music = self.music, snow = self.snow, peaceful = self.peaceful, dark = self.dark, echo = self.echo, light = self.light, spikeSkin = self.spikeSkin,
        background = self.background, time = self.time, clouds = self.clouds,
        depth = self.depth, surfaceRow = self.surfaceRow,
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
    if d.name_en and d.name_en ~= '' then line('"name_en": ' .. json.encode(d.name_en)) end
    if d.parTime then line('"parTime": ' .. json.encode(d.parTime)) end
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
    -- Campos opcionales al final (solo si existen)
    local tail = {}
    if #d.subtiles > 0 then tail[#tail+1] = function(last) list('subtiles', d.subtiles, last) end end
    if #d.links > 0 then tail[#tail+1] = function(last) list('links', d.links, last) end end
    if #d.blockLinks > 0 then tail[#tail+1] = function(last) list('blockLinks', d.blockLinks, last) end end
    if #d.bossZones > 0 then tail[#tail+1] = function(last) list('bossZones', d.bossZones, last) end end
    if d.autoScroll then tail[#tail+1] = function(last) line('"autoScroll": ' .. enc(d.autoScroll), last) end end
    if d.modes then tail[#tail+1] = function(last) line('"modes": ' .. enc(d.modes), last) end end
    if d.matchTime then tail[#tail+1] = function(last) line('"matchTime": ' .. json.encode(d.matchTime), last) end end
    if d.music then tail[#tail+1] = function(last) line('"music": ' .. json.encode(d.music), last) end end
    if d.snow then tail[#tail+1] = function(last) line('"snow": true', last) end end
    if d.peaceful then tail[#tail+1] = function(last) line('"peaceful": true', last) end end
    if d.dark then tail[#tail+1] = function(last) line('"dark": true', last) end end
    if d.echo ~= nil then tail[#tail+1] = function(last) line('"echo": ' .. tostring(d.echo == true), last) end end
    if d.light then tail[#tail+1] = function(last) line('"light": "' .. d.light .. '"', last) end end
    if d.spikeSkin then tail[#tail+1] = function(last) line('"spikeSkin": "' .. d.spikeSkin .. '"', last) end end
    if d.background then tail[#tail+1] = function(last) line('"background": ' .. json.encode(d.background), last) end end
    if d.time then tail[#tail+1] = function(last) line('"time": ' .. json.encode(d.time), last) end end
    if d.clouds == false then tail[#tail+1] = function(last) line('"clouds": false', last) end end
    if d.depth then tail[#tail+1] = function(last) line('"depth": ' .. json.encode(d.depth), last) end end
    if d.surfaceRow then tail[#tail+1] = function(last) line('"surfaceRow": ' .. json.encode(d.surfaceRow), last) end end
    list('vents', d.vents, #tail == 0)
    for i, f in ipairs(tail) do f(i == #tail) end
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
    local d = deepcopy(self:toData())
    d._editor = true                  -- (los bloques de fase se ven tal cual: PhaseBlocks)
    return Level.fromData(d)
end

-- ── Copias (deshacer) ─────────────────────────────────────────────────────────
function Model:snapshot()
    return deepcopy({ name=self.name, name_en=self.name_en, parTime=self.parTime, width=self.width, height=self.height, tiles=self.tiles,
                      playerStart=self.playerStart, entities=self.entities,
                      foliage=self.foliage, vents=self.vents, bossZones=self.bossZones, subtiles=self.subtiles, links=self.links, blockLinks=self.blockLinks,
                      autoScroll=self.autoScroll, modes=self.modes, matchTime=self.matchTime, music=self.music, snow=self.snow, peaceful=self.peaceful, dark=self.dark, echo=self.echo, light=self.light, spikeSkin=self.spikeSkin,
                      background=self.background, time=self.time, clouds=self.clouds,
                      depth=self.depth, surfaceRow=self.surfaceRow })
end

function Model:restore(s)
    s = deepcopy(s)
    -- (los campos opcionales pueden faltar en la copia: se vacían a mano)
    self.autoScroll, self.modes, self.matchTime, self.music, self.snow = nil, nil, nil, nil, nil
    self.dark, self.echo, self.light, self.peaceful = nil, nil, nil, nil
    self.spikeSkin = nil
    self.background, self.time, self.clouds, self.depth, self.surfaceRow = nil, nil, nil, nil, nil
    self.name_en = nil
    self.parTime = nil
    for k, v in pairs(s) do self[k] = v end
end

-- ── Celdas ────────────────────────────────────────────────────────────────────
function Model:inBounds(c, r) return c >= 1 and r >= 1 and c <= self.width and r <= self.height end
function Model:get(c, r) return self:inBounds(c, r) and self.tiles[r][c] or nil end

function Model:set(c, r, raw)
    if not self:inBounds(c, r) or self.tiles[r][c] == raw then return false end
    self.tiles[r][c] = raw
    -- (si deja de ser un activador ON/OFF, sus conexiones desaparecen con él;
    -- si deja de ser un Bloque ON/OFF, la suya también)
    if self.links and #self.links > 0 and not self:isSwitch(c, r) then self:setLink(c, r, nil) end
    if self.blockLinks and #self.blockLinks > 0 then
        if not self:isSwitchBlock(c, r) then self:setBlockLink(c, r, nil) end
        if not self:isSwitch(c, r) then
            for i = #self.blockLinks, 1, -1 do
                local l = self.blockLinks[i]
                if l.from[1] == c and l.from[2] == r then table.remove(self.blockLinks, i) end
            end
        end
    end
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
    self.subtiles = keep(self.subtiles or {})
    self.links = keep(self.links or {})
    self.blockLinks = keep(self.blockLinks or {})
    self.bossZones = keep(self.bossZones)
    for _, z in ipairs(self.bossZones) do
        z.w = math.max(4, math.min(z.w, w - z.col + 1)); z.h = math.max(3, math.min(z.h, h - z.row + 1))
    end
    self.playerStart[1] = math.min(self.playerStart[1], w)
    self.playerStart[2] = math.min(self.playerStart[2], h)
end

-- Rodear el mapa con el tile de borde
function Model:frame(id)
    for c = 1, self.width do self:setId(c, 1, id); self:setId(c, self.height, id) end
    for r = 1, self.height do self:setId(1, r, id); self:setId(self.width, r, id) end
end

-- ── Objetos ───────────────────────────────────────────────────────────────────
-- Entidad en la celda (las de subcelda solo si coincide la subcelda)
function Model:entityAt(c, r, sub)
    for i = #self.entities, 1, -1 do
        local e = self.entities[i]
        if e.col == c and e.row == r and (sub == nil or e.sub == nil or e.sub == sub) then return e, i end
    end
end

-- ¿Hay un bloque sólido justo encima de esa subcelda (techo)?
function Model:ceilingAbove(c, r, sub)
    local rr = (sub and sub <= 2 or not sub) and r - 1 or r
    local raw = (rr >= 1) and self:get(c, rr) or TILE_SOLID
    if not raw then return false end
    local def = Tiles.get(Codec.id(raw))
    return def ~= nil and def.collision == 'solid' and not def.fake
end

-- Devuelve la entidad nueva, o nil y el motivo si no se puede colocar ahí
function Model:addEntity(typeName, c, r, sub)
    local def = ET.get(typeName)
    if def and def.ceilingOnly and not self:ceilingAbove(c, r, def.placement == 'sub' and sub or nil) then
        return nil, def.label .. ': solo se puede colocar justo debajo de un bloque sólido (techo)'
    end
    local n = ET.normalize({ type = typeName, col = c, row = r, sub = sub })
    if n then table.insert(self.entities, n) end
    if n and def and def.activatable then self:fixActivatableIds() end
    return n
end

-- ── Conexiones: bloques ON/OFF → objetos activables ──────────────────────────
-- (entidades cuyo tipo tiene `activatable`: inundaciones...)
function Model:activatables()
    local out = {}
    for _, e in ipairs(self.entities) do
        local t = ET.get(e.type)
        if t and t.activatable then out[#out + 1] = e end
    end
    return out
end
function Model:floods()
    local out = {}
    for _, e in ipairs(self.entities) do if e.type == 'flood' then out[#out + 1] = e end end
    return out
end
function Model:activatableById(id)
    for _, e in ipairs(self:activatables()) do if (tonumber(e.props.id) or 1) == id then return e end end
end

-- Cada objeto activable con un número (id) distinto: los repetidos (o los
-- antiguos, que no lo tenían: todos valen 1) reciben el siguiente libre
function Model:fixActivatableIds()
    local used, maxId = {}, 0
    for _, e in ipairs(self:activatables()) do maxId = math.max(maxId, tonumber(e.props.id) or 1) end
    for _, e in ipairs(self:activatables()) do
        local id = tonumber(e.props.id) or 1
        if used[id] then maxId = maxId + 1; id = maxId end
        e.props.id, used[id] = id, true
    end
end

function Model:isSwitch(c, r)
    local raw = self:get(c, r)
    local n = raw and Tiles.get(Codec.id(raw)).name
    return n == 'switch_on' or n == 'switch_off'
end

function Model:linkAt(c, r)
    for i, l in ipairs(self.links or {}) do if l.col == c and l.row == r then return l, i end end
end

-- Conecta el bloque (c, r) al objeto `id` (nil = desconectar)
function Model:setLink(c, r, id)
    self.links = self.links or {}
    local l, i = self:linkAt(c, r)
    if not id then if l then table.remove(self.links, i); return true end return false end
    if l then if l.to == id then return false end l.to = id; return true end
    self.links[#self.links + 1] = { col = c, row = r, to = id }
    return true
end

-- ── Bloques ON/OFF → su activador ────────────────────────────────────────────
function Model:isSwitchBlock(c, r)
    local raw = self:get(c, r)
    return raw ~= nil and Tiles.get(Codec.id(raw)).switchBlock ~= nil
end
function Model:blockLinkAt(c, r)
    for i, l in ipairs(self.blockLinks or {}) do if l.col == c and l.row == r then return l, i end end
end
-- Conecta el Bloque ON/OFF (c, r) al activador src = {c, r} (nil = desconectar)
function Model:setBlockLink(c, r, src)
    self.blockLinks = self.blockLinks or {}
    local l, i = self:blockLinkAt(c, r)
    if not src then if l then table.remove(self.blockLinks, i); return true end return false end
    if l then l.from = { src[1], src[2] }; return true end
    self.blockLinks[#self.blockLinks + 1] = { col = c, row = r, from = { src[1], src[2] } }
    return true
end
-- Activador del que depende el bloque: el conectado o el más cercano (y si es implícito)
function Model:blockSource(c, r)
    local l = self:blockLinkAt(c, r)
    if l and self:isSwitch(l.from[1], l.from[2]) then return l.from, false end
    local best, bd
    for rr = 1, self.height do
        for cc = 1, self.width do
            if self:isSwitch(cc, rr) then
                local d = (cc - c) ^ 2 + (rr - r) ^ 2
                if not bd or d < bd then best, bd = { cc, rr }, d end
            end
        end
    end
    return best, true
end

-- Quita las conexiones de casillas que ya no son un bloque ON/OFF (devuelve cuántas)
function Model:pruneLinks()
    local n = 0
    for i = #(self.blockLinks or {}), 1, -1 do
        local l = self.blockLinks[i]
        if not self:isSwitchBlock(l.col, l.row) or not self:isSwitch(l.from[1], l.from[2]) then
            table.remove(self.blockLinks, i); n = n + 1
        end
    end
    for i = #(self.links or {}), 1, -1 do
        local l = self.links[i]
        if not self:isSwitch(l.col, l.row) then table.remove(self.links, i); n = n + 1 end
    end
    return n
end

function Model:findObject(list, c, r, sub)
    for i = #list, 1, -1 do
        local o = list[i]
        if o.col == c and o.row == r and (sub == nil or o.sub == sub) then return o, i end
    end
end

-- ── Subtiles (bloques de un cuarto de casilla, src/world/level/SubTiles.lua) ───────
function Model:subtileAt(c, r, sub)
    return self:findObject(self.subtiles, c, r, sub)
end

-- Pone (kind = nombre de tile) o quita (kind = nil) la subtile de esa
-- subcelda. Devuelve true si cambió algo.
function Model:setSubtile(c, r, sub, kind, solid)
    if not self:inBounds(c, r) then return false end
    local o, i = self:subtileAt(c, r, sub)
    if not kind then
        if o then table.remove(self.subtiles, i); return true end
        return false
    end
    solid = solid ~= false
    if o then
        if o.kind == kind and o.solid == solid then return false end
        o.kind, o.solid = kind, solid
        return true
    end
    table.insert(self.subtiles, { col = c, row = r, sub = sub, kind = kind, solid = solid })
    return true
end

-- ── Zonas de jefe ─────────────────────────────────────────────────────────────
function Model:zoneAt(c, r)
    for i = #self.bossZones, 1, -1 do
        local z = self.bossZones[i]
        if BossZones.containsCell(z, c, r) then return z, i end
    end
end

function Model:zoneById(id)
    for _, z in ipairs(self.bossZones) do if z.id == id then return z end end
end

-- Nueva zona entre dos celdas (id libre más bajo)
function Model:addZone(c0, r0, c1, r1)
    local id = 1
    while self:zoneById(id) do id = id + 1 end
    local z = BossZones.normalize({ id = id, col = math.min(c0, c1), row = math.min(r0, r1),
                                    w = math.abs(c1 - c0) + 1, h = math.abs(r1 - r0) + 1 }, id)
    z.w = math.min(z.w, self.width - z.col + 1)
    z.h = math.min(z.h, self.height - z.row + 1)
    table.insert(self.bossZones, z)
    return z
end

-- Zona a la que pertenece un jefe (su prop `zone`, o la que lo contiene)
function Model:zoneOfBoss(e)
    local want = e.props.zone or 0
    if want > 0 then return self:zoneById(want) end
    return self:zoneAt(e.col, e.row)
end

-- Jefes de una zona
function Model:bossesOf(z)
    local out = {}
    for _, e in ipairs(self.entities) do
        local t = ET.get(e.type)
        if t and t.boss and self:zoneOfBoss(e) == z then out[#out+1] = e end
    end
    return out
end

-- ── Validación ────────────────────────────────────────────────────────────────
function Model:validate()
    local w = {}
    local ps = self.playerStart
    if not ps or not self:inBounds(ps[1], ps[2]) then
        w[#w+1] = { 'error', 'El punto de inicio está fuera del mapa' }
    elseif Tiles.get(Codec.id(self.tiles[ps[2]][ps[1]])).collision == 'solid' then
        w[#w+1] = { 'error', 'El punto de inicio está dentro de un bloque sólido' }
    end
    for _, e in ipairs(self.entities) do
        local t = ET.get(e.type)
        local where = (t and t.label or e.type) .. ' (' .. e.col .. ',' .. e.row .. ')'
        if not self:inBounds(e.col, e.row) then
            w[#w+1] = { 'error', where .. ' está fuera del mapa', e }
        elseif Tiles.get(Codec.id(self.tiles[e.row][e.col])).collision == 'solid' and not (t and t.inBlockOk) then
            w[#w+1] = { 'warn', where .. ' está dentro de un bloque', e }
        elseif t and t.ceilingOnly and not self:ceilingAbove(e.col, e.row, e.sub) then
            w[#w+1] = { 'warn', where .. ' no cuelga de un techo sólido', e }
        end
        local p = e.props
        if p.patrol and (e.col < p.patrol.left or e.col > p.patrol.right) then
            w[#w+1] = { 'warn', where .. ': su ruta no la contiene', e }
        end
    end
    -- Conexiones ON/OFF → objetos activables
    local linked = {}
    for _, l in ipairs(self.links or {}) do
        local e = self:activatableById(l.to)
        if not self:isSwitch(l.col, l.row) then
            w[#w+1] = { 'warn', 'Conexión en (' .. l.col .. ',' .. l.row .. '): ahí ya no hay un bloque ON/OFF' }
        elseif not e then
            w[#w+1] = { 'error', 'Bloque ON/OFF (' .. l.col .. ',' .. l.row .. ') conectado al #' .. l.to .. ', que no existe (capa Bloques → Conectar para cambiarlo)' }
        elseif e.type == 'flood' and e.props.control ~= 'switch' then
            w[#w+1] = { 'warn', 'Bloque ON/OFF (' .. l.col .. ',' .. l.row .. ') conectado a la inundación #' .. l.to
                                 .. ', pero esta no se mueve con bloques ON/OFF (propiedad "Se mueve")', e }
        end
        linked[l.to] = true
    end
    local floodById = {}
    for _, e in ipairs(self:floods()) do floodById[tonumber(e.props.id) or 1] = e end
    for id, f in pairs(floodById) do
        if f.props.control == 'switch' and not linked[id] then
            w[#w+1] = { 'warn', 'Inundación #' .. id .. ': se mueve con bloques ON/OFF pero no tiene ninguno conectado (capa Bloques → Conectar)', f }
        elseif f.props.control == 'boss' and #self.bossZones == 0 then
            w[#w+1] = { 'warn', 'Inundación #' .. id .. ': se mueve con la pelea de jefe pero no hay zonas de jefe', f }
        end
    end
    -- (un mini bloque dentro de un bloque no es un aviso: el bloque grande manda y
    -- puede quedarse ahí para cuando el bloque se rompa o se cambie)
    for _, o in ipairs(self.subtiles or {}) do
        if ps and o.col == ps[1] and (o.row == ps[2] or o.row == ps[2] - 1) and o.solid then
            w[#w+1] = { 'warn', 'Mini bloque sólido en el punto de inicio (' .. o.col .. ',' .. o.row .. ')' }
        end
    end
    -- Jefes y zonas de jefe
    for _, e in ipairs(self.entities) do
        local t = ET.get(e.type)
        if t and t.boss then
            local where = t.label .. ' (' .. e.col .. ',' .. e.row .. ')'
            local z = self:zoneOfBoss(e)
            if (e.props.zone or 0) > 0 and not z then
                w[#w+1] = { 'error', where .. ': no existe la zona de jefe #' .. e.props.zone, e }
            elseif not z then
                w[#w+1] = { 'error', where .. ' no está dentro de una zona de jefe (capa Especial)', e }
            elseif not BossZones.containsCell(z, e.col, e.row) then
                w[#w+1] = { 'warn', where .. ' está fuera de su zona #' .. z.id, e }
            end
        end
    end
    local ids = {}
    for _, z in ipairs(self.bossZones) do
        if ids[z.id] then w[#w+1] = { 'error', 'Hay dos zonas de jefe con el id #' .. z.id } end
        ids[z.id] = true
        if #self:bossesOf(z) == 0 then
            w[#w+1] = { 'warn', 'La zona de jefe #' .. z.id .. ' no tiene jefe (no bloqueará nada)' }
        end
        if ps and BossZones.containsCell(z, ps[1], ps[2]) then
            w[#w+1] = { 'warn', 'El inicio del jugador está dentro de la zona de jefe #' .. z.id }
        end
    end
    -- Cámara automática
    local a = self.autoScroll
    if a then
        if ps and (ps[1] < a.startCol or ps[1] >= a.startCol + a.width) then
            w[#w+1] = { 'error', 'Cámara automática: el inicio del jugador debe estar dentro de la ventana inicial (columnas '
                        .. a.startCol .. '-' .. (a.startCol + a.width - 1) .. ')' }
        end
        local fin = 0
        for r = 1, self.height do for c = 1, self.width do
            if Tiles.get(Codec.id(self.tiles[r][c])).trigger == 'finish' then fin = fin + 1 end
        end end
        if fin == 0 then w[#w+1] = { 'warn', 'Cámara automática sin meta: la cámara solo parará al final' } end
        if a.width > self.width then w[#w+1] = { 'warn', 'Cámara automática: la ventana es más ancha que el nivel' } end
        if self.height * TILE_PX > 720 then
            w[#w+1] = { 'warn', 'Cámara automática: el nivel mide más de 11 filas; la cámara no enseñará todo el alto (p. ej. un techo de pinchos)' }
        end
    end
    if #self.entities == 0 then w[#w+1] = { 'info', 'El nivel no tiene entidades' } end
    local Music = require 'src/audio/Music'
    if self.music and not (Music.get(self.music) and Music.get(self.music).level) then
        w[#w+1] = { 'warn', 'La música "' .. self.music .. '" no está en assets/music/index.json: sonará la de siempre' }
    end
    -- Rey de la Colina sin zonas de puntos
    local zones = 0
    for _, e in ipairs(self.entities) do if e.type == 'pointarea' then zones = zones + 1 end end
    local wantsKoth = false
    for _, id in ipairs(self.modes or {}) do if id == 'koth' then wantsKoth = true end end
    if wantsKoth and zones == 0 then
        w[#w+1] = { 'warn', 'Solo para Rey de la Colina, pero no tiene ninguna Zona de puntos (Entidades › Mecanismos): no saldrá en ningún modo' }
    end
    return w
end

return Model
