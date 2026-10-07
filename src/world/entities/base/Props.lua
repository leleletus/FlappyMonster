-- src/world/entities/base/Props.lua
-- Tipos de PROPIEDAD editables de una entidad. Cada entidad declara un
-- esquema (lista de propiedades); el juego lo usa para validar/rellenar los
-- datos del nivel y el editor para generar su panel automáticamente.
--
-- Una propiedad:
--   { key='speed', kind='number', label='Velocidad', default=50,
--     min=0, max=400, step=5, group='Movimiento', help='px/s',
--     showIf=function(p) return p.movement ~= 'static' end }
--
-- kinds:
--   int, number   numéricos (min/max/step)
--   bool          verdadero/falso
--   enum          options = { {value='walk', label='Camina'}, ... }
--   text          cadena (maxLen)
--   patrol        límites horizontales de la ruta en columnas de tile:
--                 { left=col, right=col } o false (sin límites). El editor
--                 lo dibuja como una línea con dos cajitas arrastrables.
--   point         una celda { col, row } (para futuros destinos/puntos)
--   points        lista de celdas { {col,row}, ... } en orden (rutas con varios
--                 puntos, p. ej. los waypoints de un jefe). En el editor: cajitas
--                 numeradas arrastrables + botones para añadir / quitar puntos.
--                 min / max = número de puntos permitido.
--
-- `default` puede ser una función(data) (p. ej. ruta alrededor de la
-- posición donde se colocó la entidad).

local Props = {}

local function clamp(v, lo, hi)
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end

Props.kinds = {
    int = function(p, v)
        v = tonumber(v); if not v then return nil end
        return clamp(math.floor(v + 0.5), p.min, p.max)
    end,
    number = function(p, v)
        v = tonumber(v); if not v or v ~= v then return nil end
        return clamp(v, p.min, p.max)
    end,
    bool = function(p, v)
        if type(v) == 'boolean' then return v end
        return nil
    end,
    enum = function(p, v)
        for _, o in ipairs(p.options) do if o.value == v then return v end end
        return nil
    end,
    text = function(p, v)
        if type(v) ~= 'string' then return nil end
        return v:sub(1, p.maxLen or 200)
    end,
    patrol = function(p, v)
        if v == false then return false end
        if type(v) ~= 'table' then return nil end
        local l, r = tonumber(v.left), tonumber(v.right)
        if not l or not r then return nil end
        l, r = math.floor(l), math.floor(r)
        if r < l then l, r = r, l end
        return { left = l, right = r }
    end,
    point = function(p, v)
        if type(v) ~= 'table' or not tonumber(v.col) or not tonumber(v.row) then return nil end
        return { col = math.floor(v.col), row = math.floor(v.row) }
    end,
    points = function(p, v)
        if type(v) ~= 'table' then return nil end
        local out = {}
        for i = 1, math.min(#v, p.max or 32) do
            local q = v[i]
            if type(q) ~= 'table' or not tonumber(q.col) or not tonumber(q.row) then return nil end
            out[i] = { col = math.floor(q.col), row = math.floor(q.row) }
        end
        if #out < (p.min or 1) then return nil end
        return out
    end,
}

-- Igualdad profunda (para no guardar valores iguales al por defecto)
local function same(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, x in pairs(a) do if not same(x, b[k]) then return false end end
    for k, x in pairs(b) do if a[k] == nil then return false end end
    return true
end

function Props.default(p, data)
    local d = p.default
    if type(d) == 'function' then return d(data) end
    if type(d) == 'table' then
        local c = {}; for k, x in pairs(d) do c[k] = x end; return c
    end
    return d
end

-- Valores finales de todas las propiedades del esquema para una colocación:
-- valor del nivel si es válido, si no el por defecto.
function Props.resolve(schema, raw, data)
    local out = {}
    raw = raw or {}
    for _, p in ipairs(schema) do
        local v, val = raw[p.key], nil
        if v ~= nil then val = Props.kinds[p.kind](p, v) end
        if val == nil then val = Props.default(p, data) end
        out[p.key] = val
    end
    return out
end

-- Solo las propiedades que difieren del valor por defecto (para guardar
-- niveles limpios; lo que no se guarda toma el default al cargar).
function Props.diff(schema, values, data)
    local out, any = {}, false
    for _, p in ipairs(schema) do
        local v, d = values[p.key], Props.default(p, data)
        if not same(v, d) then out[p.key] = v; any = true end
    end
    return any and out or nil
end

return Props
