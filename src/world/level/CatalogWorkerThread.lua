-- src/world/level/CatalogWorkerThread.lua — el HILO de src/world/level/CatalogWorker.lua (ver allí).
-- Calcula las fichas con el mismo código que el servidor sin ventana (LevelCatalog.load): sin love.graphics de verdad,
-- que en un hilo no se puede tocar. Nada de lo que corre aquí dibuja ni suena.
local files, out, req, overlayBase, version, slice = ...
if not out then return {} end                                  -- (cargado como módulo, sin ser el hilo: project_check)
require 'love.filesystem'
require 'love.timer'
require 'love.image'
require 'love.math'
require 'love.data'
local fs = love.filesystem

-- La SUPERPOSICIÓN de main.lua (Switch: sin montar la actualización) es de cada estado de Lua: aquí hay que repetirla
if overlayBase then
    local rawInfo, rawRead = fs.getInfo, fs.read
    local function res(p)
        if type(p) ~= 'string' or p:sub(1, 7) == 'update/' then return p end
        local q = overlayBase .. (p:gsub('^/+', ''))
        if rawInfo(q) then return q end
        return p
    end
    for _, n in ipairs({ 'getInfo', 'lines', 'load', 'newFile', 'newFileData' }) do
        local f = fs[n]
        if f then fs[n] = function(p, ...) return f(res(p), ...) end end
    end
    fs.read = function(a, b, ...)
        if (a == 'string' or a == 'data') and type(b) == 'string' then return rawRead(a, res(b), ...) end
        return rawRead(res(a), b, ...)
    end
    table.insert(package.loaders, 2, function(name)
        local n = name:gsub('%.', '/')
        for _, p in ipairs({ n .. '.lua', name .. '.lua', n .. '/init.lua' }) do
            if rawInfo(overlayBase .. p) then
                local chunk, err = loadstring(rawRead(overlayBase .. p), '@' .. p)
                return chunk or ('\n\t' .. tostring(err))
            end
        end
    end)
end

-- Por turnos: si el sistema pone este hilo en el mismo núcleo que el juego (Switch), no lo deja sin dibujar
if slice then debug.sethook(function() love.timer.sleep(0.001) end, '', slice) end

local bitser = require 'libs.bitser'
bitser.includeMetatables(false)

local FILE = 'freeplay_cards.dat'
local function keyOf(path)
    local i = fs.getInfo(path)
    return i and ((i.size or 0) .. ':' .. (i.modtime or 0)) or '?'
end

local disk = {}
if fs.getInfo(FILE) then
    local ok, data = pcall(function() return bitser.loads(fs.read(FILE)) end)
    if ok and type(data) == 'table' and data.version == version and type(data.cards) == 'table' then disk = data.cards end
end

-- El juego, cargado solo si hay algo que calcular (con todo en disco, este hilo acaba enseguida)
local LevelCatalog
local function catalog()
    if LevelCatalog then return LevelCatalog end
    local object
    object = setmetatable({}, { __index = function() return function() return 1, 1 end end })
    love.graphics = setmetatable({}, { __index = function(_, k)
        if type(k) == 'string' and k:sub(1, 3) == 'new' then return function() return object end end
        return function() return 1, 1 end
    end })
    Sound = setmetatable({}, { __index = function() return function() end end })
    require 'settings'
    Input = require('src/network/Protocol').newInputStub()
    LevelCatalog = require 'src/world/level/LevelCatalog'
    return LevelCatalog
end

local todo, seen = {}, {}
for i = #files, 1, -1 do todo[#todo + 1] = files[i] end       -- (pila: el último es el siguiente)
local cards, changed = disk, false                             -- (las que no se piden esta vez, se quedan)
local function one(f)
    if seen[f] then return end
    seen[f] = true
    local path = 'assets/levels/' .. f
    local key = keyOf(path)
    local c = disk[f]
    local info = c and c.key == key and c.info or nil
    if not info then
        local err
        info, err = catalog().load(path, f)
        if not info then out:push({ file = f, broken = tostring(err) }); return end
        cards[f], changed = { key = key, info = info }, true
    end
    if not pcall(out.push, out, { file = f, info = info }) then out:push({ file = f, retry = true }) end
end

while #todo > 0 do
    local wanted = req:pop()                                   -- (lo que se ve ahora en la lista, antes)
    if wanted then one(wanted) else
        one(todo[#todo]); todo[#todo] = nil
    end
end
if changed then pcall(function() fs.write(FILE, bitser.dumps({ version = version, cards = cards })) end) end
out:push({ done = true })
