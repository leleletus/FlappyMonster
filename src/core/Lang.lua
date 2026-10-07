-- src/core/Lang.lua
-- Idiomas del juego. Los textos viven en assets/lang/<id>.lua (una tabla por
-- idioma, agrupada por pantalla) y el código los pide por su clave:
--
--   local L = require 'src/core/Lang'
--   L('menu.settings')                   --> "CONFIGURACIÓN" / "SETTINGS"
--   L('hud.monsters_left', { n = 5 })    --> "Quedan 5 monstruos"
--
-- Valores entre llaves ({n}, {name}...) se sustituyen con `args`. Si a un
-- idioma le falta una clave se usa la del español y, si tampoco existe, la
-- propia clave (así un olvido se ve enseguida en pantalla).
--
-- Añadir un idioma: copia assets/lang/es.lua a assets/lang/<id>.lua, tradúcelo
-- y añade { id, name } a Lang.LANGUAGES.
--
-- Los mensajes del servidor viajan como { key, args, msg }: cada cliente los
-- muestra en SU idioma con L.fromServer(data) (msg = texto en español por
-- compatibilidad con clientes antiguos).

local Lang = {}

Lang.LANGUAGES = {
    { id = 'es', name = 'Español' },
    { id = 'en', name = 'English' },
}
Lang.DEFAULT = 'es'

local tables = {}           -- id -> tabla plana { ['menu.play'] = '...' }
local current = Lang.DEFAULT
local listeners = {}

-- Aplana { menu = { play = 'X' } } -> { ['menu.play'] = 'X' }
local function flatten(t, prefix, out)
    for k, v in pairs(t) do
        local key = prefix and (prefix .. '.' .. k) or k
        if type(v) == 'table' then flatten(v, key, out) else out[key] = v end
    end
    return out
end

local function load(id)
    if tables[id] then return tables[id] end
    local path = 'assets/lang/' .. id .. '.lua'
    -- read + loadstring (no filesystem.load): el servidor parchea read para
    -- leer los assets del juego desde fuera de su carpeta
    local ok, src = pcall(love.filesystem.read, path)
    local chunk = ok and src and loadstring(src, '@' .. path)
    local data
    if chunk then
        setfenv(chunk, {})                     -- solo datos: sin acceso a nada
        local ok2, res = pcall(chunk)
        if ok2 and type(res) == 'table' then data = res end
    end
    if not data then print('[Lang] No se pudo cargar ' .. path) end
    tables[id] = flatten(data or {}, nil, {})
    return tables[id]
end

local function format(s, args)
    if not args then return s end
    return (s:gsub('{(%w+)}', function(k)
        local v = args[k]
        if v == nil then return '{' .. k .. '}' end
        return tostring(v)
    end))
end

-- Texto de una clave en el idioma actual
function Lang.get(key, args)
    local s = load(current)[key]
    if s == nil and current ~= Lang.DEFAULT then s = load(Lang.DEFAULT)[key] end
    if s == nil then return key end
    return format(s, args)
end
setmetatable(Lang, { __call = function(_, key, args) return Lang.get(key, args) end })

function Lang.has(key) return load(current)[key] ~= nil or load(Lang.DEFAULT)[key] ~= nil end

-- Mensaje del servidor { key, args, msg } en el idioma de este cliente;
-- si no trae texto, el de la clave `fallback` (o '')
function Lang.fromServer(data, fallback)
    local s
    if type(data) == 'table' then
        if data.key and Lang.has(data.key) then s = Lang.get(data.key, data.args)
        else s = data.msg end
    elseif data ~= nil then
        s = tostring(data)
    end
    if (s == nil or s == '') and fallback then return Lang.get(fallback) end
    return s or ''
end

-- Mensaje para ENVIAR desde el servidor: clave + valores + texto en español
function Lang.message(key, args, extra)
    local m = extra or {}
    m.key, m.args = key, args
    local es = load(Lang.DEFAULT)[key]
    m.msg = es and format(es, args) or key
    return m
end

function Lang.current() return current end

-- Nombre de algo con versiones por idioma (niveles: JSON "name" = español y
-- "name_en", "name_<idioma>"...): el del idioma elegido, o el de siempre
function Lang.localName(t)
    if not t then return nil end
    local v = t['name_' .. current]
    return (type(v) == 'string' and v ~= '') and v or t.name
end

-- Nombre de un jefe en el idioma elegido: el que le puso el nivel (props `title` = español,
-- `title_en`, `title_<idioma>`: como "name"/"name_en" de los niveles) o, si no tiene, el de
-- siempre del tipo (clave boss.<tipo>). nil si no hay ninguno.
function Lang.bossName(typeName, props)
    local custom = props and props.title
    if type(custom) == 'string' and custom ~= '' then
        local t = { name = custom }
        for k, v in pairs(props) do
            local l = type(k) == 'string' and k:match('^title_(.+)$')
            if l then t['name_' .. l] = v end
        end
        return Lang.localName(t)
    end
    local key = 'boss.' .. tostring(typeName)
    if Lang.has(key) then return Lang.get(key) end
end

function Lang.set(id)
    local valid = false
    for _, l in ipairs(Lang.LANGUAGES) do if l.id == id then valid = true end end
    if not valid then id = Lang.DEFAULT end
    if id == current then return end
    current = id
    load(id)
    for _, fn in ipairs(listeners) do pcall(fn, id) end
end

-- fn(id) al cambiar de idioma (p. ej. para rehacer cachés con textos)
function Lang.onChange(fn) listeners[#listeners + 1] = fn end

-- Todas las claves de un idioma (para comprobar que las traducciones están completas)
function Lang.keys(id) return load(id) end

return Lang
