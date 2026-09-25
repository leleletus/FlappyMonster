-- src/world/decorations/DecorationTypes.lua
-- Registro de DECORACIONES (plantas, árboles, adornos): no colisionan, solo se
-- dibujan (y se animan). Cada tipo es un archivo en
-- src/world/decorations/types/ listado en src/world/Decorations.lua.
--
-- Definición de un tipo:
--   name, label, category      identificación y grupo en la paleta del editor
--   placement   'sub'  : se coloca en una subcelda (cuarto de bloque);
--                        anclado al centro-abajo de la subcelda
--               'cell' : ocupa la celda; anclado al centro-abajo de la celda
--   layer       'front' (por defecto, delante de jugador y enemigos) | 'back'
--   cullMargin  px extra de margen al descartar fuera de pantalla (por defecto 4 tiles)
--   props       propiedades EXTRA editables (formato de entities/Props.lua)
--   editor      { previewScale = 0.4 } escala de la miniatura (se dibuja con
--               su propio draw); icon = imagen opcional
--   loadAssets()               carga sus imágenes (una vez)
--   init(d)                    estado propio de la instancia (d.phase ∈ [0,1) es
--                              una fase estable derivada de la posición)
--   update(d, dt)              animación propia (d.animT ya avanza solo)
--   draw(d, sx, sy)            dibujo en pantalla; (sx,sy) = punto de anclaje.
--                              d.flip = -1 si está espejada, 1 si no.

local Props = require 'src/world/entities/Props'

local DecorationTypes = { byName = {}, list = {} }

-- Propiedades que tienen todas las decoraciones
DecorationTypes.COMMON = {
    { key='flip',  kind='bool', label='Espejar', group='Aspecto', default=false },
    { key='layer', kind='enum', label='Capa', group='Aspecto', default='front',
      options = { { value='front', label='Delante' }, { value='back', label='Detras' } },
      help='Delante o detras del jugador y los enemigos' },
}

function DecorationTypes.register(def)
    assert(type(def) == 'table' and type(def.name) == 'string', "decoracion sin nombre")
    assert(not DecorationTypes.byName[def.name], "decoracion duplicada: " .. def.name)
    assert(def.placement == 'sub' or def.placement == 'cell', "decoracion " .. def.name .. ": placement invalido")
    assert(type(def.draw) == 'function', "decoracion " .. def.name .. " sin draw")
    local t = {}
    for k, v in pairs(def) do t[k] = v end
    t.label      = t.label or t.name
    t.category   = t.category or (t.placement == 'sub' and 'Pequenas (subcelda)' or 'Grandes')
    t.cullMargin = t.cullMargin or 4
    t.schema = {}
    for _, p in ipairs(DecorationTypes.COMMON) do
        local c = {}
        for k, v in pairs(p) do c[k] = v end
        if p.key == 'layer' and t.layer then c.default = t.layer end
        table.insert(t.schema, c)
    end
    for _, p in ipairs(t.props or {}) do table.insert(t.schema, p) end
    DecorationTypes.byName[t.name] = t
    table.insert(DecorationTypes.list, t)
    return t
end

function DecorationTypes.get(name) return DecorationTypes.byName[name] end

-- Colocación del nivel → { type, col, row, sub?, props } (nil si el tipo no existe)
function DecorationTypes.normalize(data)
    local t = DecorationTypes.byName[data.type or 'tulip']
    local col, row = tonumber(data.col), tonumber(data.row)
    if not t or not col or not row then return nil end
    local n = { type = t.name, col = math.floor(col), row = math.floor(row) }
    if t.placement == 'sub' then
        local sub = math.floor(tonumber(data.sub) or 1)
        n.sub = (sub >= 1 and sub <= 4) and sub or 1
    end
    n.props = Props.resolve(t.schema, data.props, n)
    return n
end

function DecorationTypes.serialize(d)
    local t = DecorationTypes.byName[d.type]
    return { type = d.type, col = d.col, row = d.row, sub = d.sub,
             props = t and Props.diff(t.schema, d.props, d) or nil }
end

-- Punto de anclaje (pies) en px de mundo
function DecorationTypes.anchor(t, col, row, sub)
    local T = TILE_PX
    if t.placement == 'sub' and sub then
        local offX = ((sub - 1) % 2) * (T / 2)
        local offY = math.floor((sub - 1) / 2) * (T / 2)
        return (col - 1) * T + offX + T / 4, (row - 1) * T + offY + T / 2
    end
    return (col - 1) * T + T / 2, (row - 1) * T + T
end

-- Fase estable en [0,1) a partir de la posición: las animaciones de dos
-- decoraciones vecinas no van sincronizadas, y no cambia al reconstruir el
-- nivel (editor) ni consume math.random del juego.
local function phaseOf(col, row, sub)
    local v = math.sin(col * 12.9898 + row * 78.233 + (sub or 0) * 37.719) * 43758.5453
    return v - math.floor(v)
end

-- Crea la instancia que el nivel anima y dibuja
function DecorationTypes.instantiate(n)
    local t = DecorationTypes.byName[n.type]
    if t.loadAssets then t.loadAssets() end
    local x, y = DecorationTypes.anchor(t, n.col, n.row, n.sub)
    local d = {
        def = t, type = t.name, col = n.col, row = n.row, sub = n.sub, props = n.props,
        x = x, y = y, phase = phaseOf(n.col, n.row, n.sub),
        flip = n.props.flip and -1 or 1, layer = n.props.layer,
    }
    d.animT = d.phase * 10
    if t.init then t.init(d) end
    return d
end

return DecorationTypes
