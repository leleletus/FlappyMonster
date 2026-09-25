-- src/world/entities/EntityTypes.lua
-- Registro de TIPOS DE ENTIDAD (enemigos, NPCs...). Cada tipo es un archivo en
-- src/world/entities/types/ que devuelve su definición; se listan en
-- src/world/Entities.lua.
--
-- Definición de un tipo:
--   name, label, category ('Enemigos', 'NPCs'...)
--   defaults    valores por defecto de las propiedades COMUNES para este tipo
--               (p. ej. { speed = 55, points = 10 })
--   props       propiedades EXTRA propias del tipo (mismo formato que Props)
--   hide        claves de propiedades comunes que no aplican a este tipo
--   class       clase (derivada de Entity) con su comportamiento y dibujo
--   editor      { sprite='assets/...png', scale=4, tint={...} } miniatura
--
-- En el nivel, cada colocación es:
--   { type='crabby', col=10, row=2, props={ attach='ceiling', ... } }
-- Solo se guardan las propiedades que difieren del valor por defecto.

local Props = require 'src/world/entities/Props'

local EntityTypes = { byName = {}, list = {} }

local function opts(...)
    local o = {}
    for _, pair in ipairs({...}) do o[#o+1] = { value = pair[1], label = pair[2] } end
    return o
end

-- Propiedades que toda entidad tiene (y el editor muestra), salvo que el tipo
-- las oculte con `hide`. Los tipos cambian sus valores por defecto con
-- `defaults`. Añadir aquí una propiedad la da a TODAS las entidades.
EntityTypes.COMMON = {
    { key='movement', kind='enum', label='Movimiento', group='Movimiento', default='walk',
      options=opts({'walk','Camina'}, {'fly','Vuela'}, {'static','Quieto'}) },
    { key='attach', kind='enum', label='Superficie', group='Movimiento', default='floor',
      options=opts({'floor','Suelo'}, {'ceiling','Techo (boca abajo)'}),
      showIf=function(p) return p.movement == 'walk' end },
    { key='speed', kind='number', label='Velocidad', group='Movimiento', default=50,
      min=0, max=600, step=5, help='px/s',
      showIf=function(p) return p.movement ~= 'static' end },
    { key='startDir', kind='enum', label='Direccion inicial', group='Movimiento', default='right',
      options=opts({'right','Derecha'}, {'left','Izquierda'}) },
    { key='patrol', kind='patrol', label='Ruta (limites)', group='Movimiento',
      help='Columnas entre las que se mueve. Desactiva para no tener limites.',
      default=function(d) return { left = (d.col or 1) - 3, right = (d.col or 1) + 3 } end,
      showIf=function(p) return p.movement ~= 'static' end },
    { key='turnAtEdges', kind='bool', label='Gira en los bordes', group='Movimiento', default=true,
      help='Da la vuelta antes de caer por un borde',
      showIf=function(p) return p.movement == 'walk' end },
    { key='bobAmp', kind='number', label='Oscilacion vertical', group='Movimiento', default=16,
      min=0, max=200, step=2, help='px (solo voladores)',
      showIf=function(p) return p.movement == 'fly' end },
    { key='pauses', kind='bool', label='Hace pausas', group='Comportamiento', default=true },
    { key='onTouch', kind='enum', label='Al tocarlo', group='Combate', default='kill',
      options=opts({'kill','Mata (hostil)'}, {'hurt','Quita 1 vida de HP'}, {'none','Nada (neutral / NPC)'}) },
    { key='stompable', kind='bool', label='Se puede pisotear', group='Combate', default=true },
    { key='points', kind='int', label='Puntos al pisotearlo', group='Combate', default=10,
      min=0, max=9999, step=5, showIf=function(p) return p.stompable end },
}

function EntityTypes.register(def)
    assert(type(def) == 'table' and type(def.name) == 'string', "entidad sin nombre")
    assert(not EntityTypes.byName[def.name], "entidad duplicada: " .. def.name)
    assert(def.class, "entidad " .. def.name .. " sin class")
    local t = {}
    for k, v in pairs(def) do t[k] = v end
    t.label    = t.label or t.name
    t.category = t.category or 'Enemigos'

    -- Esquema final: comunes (con defaults del tipo) + propios
    local hide = {}
    for _, k in ipairs(t.hide or {}) do hide[k] = true end
    t.schema = {}
    for _, p in ipairs(EntityTypes.COMMON) do
        if not hide[p.key] then
            local c = {}
            for k, v in pairs(p) do c[k] = v end
            if t.defaults and t.defaults[p.key] ~= nil then c.default = t.defaults[p.key] end
            table.insert(t.schema, c)
        end
    end
    for _, p in ipairs(t.props or {}) do table.insert(t.schema, p) end

    -- Agrupar por `group` (orden de primera aparición) para el editor
    local order, byGroup = {}, {}
    for _, p in ipairs(t.schema) do
        local g = p.group or 'General'
        if not byGroup[g] then byGroup[g] = {}; order[#order+1] = g end
        table.insert(byGroup[g], p)
    end
    t.schema = {}
    for _, g in ipairs(order) do for _, p in ipairs(byGroup[g]) do table.insert(t.schema, p) end end

    t.class.def = t
    EntityTypes.byName[t.name] = t
    table.insert(EntityTypes.list, t)
    return t
end

function EntityTypes.get(name)
    return EntityTypes.byName[name]
end

-- Convierte una colocación del nivel (formato nuevo o antiguo) en
-- { type, col, row, props = <valores resueltos> }. nil si el tipo no existe.
function EntityTypes.normalize(data)
    local t = EntityTypes.byName[data.type]
    if not t then return nil end
    local raw = {}
    for k, v in pairs(data.props or {}) do raw[k] = v end
    -- Formato antiguo: leftBound/rightBound/flipped en la raíz
    if raw.patrol == nil and data.leftBound and data.rightBound then
        raw.patrol = { left = data.leftBound, right = data.rightBound }
    end
    if raw.attach == nil and data.flipped then raw.attach = 'ceiling' end
    local base = { type = data.type, col = math.floor(tonumber(data.col) or 1),
                   row = math.floor(tonumber(data.row) or 1) }
    base.props = Props.resolve(t.schema, raw, base)
    return base
end

-- Forma compacta para guardar: solo props distintas del default.
function EntityTypes.serialize(e)
    local t = EntityTypes.byName[e.type]
    local out = { type = e.type, col = e.col, row = e.row }
    out.props = t and Props.diff(t.schema, e.props, e) or nil
    return out
end

return EntityTypes
