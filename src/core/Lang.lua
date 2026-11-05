-- src/core/Lang.lua
-- Idiomas del juego. TODOS los textos viven en UNA hoja de cálculo, assets/lang/translations.csv (se abre con
-- LibreOffice Calc / Excel / Google Sheets): una fila por texto y una columna por idioma —
--
--   key            | es              | en         | notes
--   menu.settings  | CONFIGURACIÓN   | SETTINGS   | (lo que ayude a traducir; el juego no la lee)
--
-- y el código los pide por su clave:
--
--   local L = require 'src/core/Lang'
--   L('menu.settings')                   --> "CONFIGURACIÓN" / "SETTINGS"
--   L('hud.monsters_left', { n = 5 })    --> "Quedan 5 monstruos"
--
-- Valores entre llaves ({n}, {name}...) se sustituyen con `args`; `\n` en una celda es un salto de línea (también
-- vale un salto de verdad dentro de la celda). Una celda VACÍA de otro idioma usa la del español y, si tampoco hay,
-- se ve la propia clave (así un olvido se ve enseguida en pantalla).
--
-- Formato: CSV UTF-8 separado por COMAS, con comillas "..." cuando la celda tiene comas, comillas o saltos (las
-- hojas de cálculo lo hacen solas al guardar como CSV). Puede llevar BOM. Filas sin clave o que empiezan por '#' no
-- cuentan (sirven de separadores).
--
-- Añadir un idioma: una columna nueva en la hoja con su id en la cabecera (p. ej. `fr`) y { id, name } en
-- Lang.LANGUAGES.
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

Lang.FILE = 'assets/lang/translations.csv'

local tables = nil          -- id -> tabla plana { ['menu.play'] = '...' } (todas a la vez, de la hoja)
local current = Lang.DEFAULT
local listeners = {}

-- Las filas de un CSV (RFC 4180: comillas, "" dentro de comillas, saltos dentro de comillas, CRLF o LF). El separador
-- es la coma; si la primera línea no tiene comas pero sí ';' (Excel en español guarda así), el punto y coma.
function Lang.parseCSV(src)
    src = src:gsub('^\239\187\191', '')               -- (el BOM que pone Excel)
    local first = src:match('^[^\r\n]*')
    local sep = (not first:find(',', 1, true) and first:find(';', 1, true)) and ';' or ','
    local stop = '[' .. sep .. '\r\n"]'
    local rows, row, i, n = {}, {}, 1, #src
    local field = {}
    while i <= n do
        local c = src:sub(i, i)
        if c == '"' and #field == 0 then
            local j = i + 1
            while true do
                local q = src:find('"', j, true)
                if not q then field[#field + 1] = src:sub(j); i = n + 1; break end
                field[#field + 1] = src:sub(j, q - 1)
                if src:sub(q + 1, q + 1) == '"' then field[#field + 1] = '"'; j = q + 2
                else i = q + 1; break end
            end
        elseif c == sep then
            row[#row + 1] = table.concat(field); field = {}; i = i + 1
        elseif c == '\r' or c == '\n' then
            row[#row + 1] = table.concat(field); field = {}
            rows[#rows + 1] = row; row = {}
            i = i + ((c == '\r' and src:sub(i + 1, i + 1) == '\n') and 2 or 1)
        else
            local j = src:find(stop, i) or n + 1
            if j == i then j = i + 1 end                -- (una comilla suelta a mitad de celda: va tal cual)
            field[#field + 1] = src:sub(i, j - 1); i = j
        end
    end
    if #field > 0 or #row > 0 then row[#row + 1] = table.concat(field); rows[#rows + 1] = row end
    return rows
end

-- La hoja → { es = {...}, en = {...} }. Columnas: `key`, una por idioma (su id), las demás (notes) no cuentan.
-- (read + parseCSV, no require: el servidor parchea read para leer los assets del juego desde fuera de su carpeta)
local function loadAll()
    if tables then return tables end
    tables = {}
    local ok, src = pcall(love.filesystem.read, Lang.FILE)
    if not ok or type(src) ~= 'string' then print('[Lang] No se pudo cargar ' .. Lang.FILE); return tables end
    local rows = Lang.parseCSV(src)
    local head = rows[1] or {}
    local keyCol, cols = nil, {}
    for c, name in ipairs(head) do
        name = name:match('^%s*(.-)%s*$')
        if name == 'key' then keyCol = c else cols[c] = name; tables[name] = {} end
    end
    for r = 2, #rows do
        local key = keyCol and rows[r][keyCol]
        key = key and key:match('^%s*(.-)%s*$')
        if key and key ~= '' and key:sub(1, 1) ~= '#' then
            for c, id in pairs(cols) do
                local v = rows[r][c]
                -- (vacía: sin texto en ese idioma — usa el español —; el español vacío sí es un texto vacío)
                if v and (v ~= '' or id == Lang.DEFAULT) then
                    tables[id][key] = v:gsub('\\(.)', function(e) return e == 'n' and '\n' or e end)
                end
            end
        end
    end
    return tables
end

local function load(id)
    local t = loadAll()
    t[id] = t[id] or {}
    return t[id]
end

-- `Lang.autoArgs()` (lo pone game.lua: Input.hints) rellena los marcadores que no vienen en `args`: las teclas de
-- las ayudas ({ok}, {back}, {arrows}...) salen así según el aparato sin tocar cada pantalla
local function format(s, args)
    if not s:find('{', 1, true) then return s end
    local auto = Lang.autoArgs and Lang.autoArgs()
    if not args and not auto then return s end
    return (s:gsub('{(%w+)}', function(k)
        local v = args and args[k]
        if v == nil and auto then v = auto[k] end
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

-- Todas las claves de un idioma, solo las de SU columna (para comprobar que las traducciones están completas)
function Lang.keys(id) return load(id) end

-- Vuelve a leer la hoja (las herramientas, tras cambiarla)
function Lang.reload() tables = nil end

return Lang
