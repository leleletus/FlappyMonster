-- src/world/tiles/TileTypes.lua
-- Registro de TIPOS DE TILE. Cada tipo es una tabla declarativa (un archivo en
-- src/world/tiles/types/) y el motor, el servidor y el editor leen de aquí.
--
-- Campos de un tipo (solo `id` y `name` son obligatorios):
--
--   id          número guardado en el nivel (0..255). ÚNICO y PERMANENTE:
--               nunca reutilizar ni cambiar el de un tipo existente.
--   name        nombre interno. Genera la constante global TILE_<NAME>.
--   label       nombre visible (editor).
--   category    grupo en la paleta del editor ('Terreno', 'Plataformas'...).
--
--   collision   'none'  : se atraviesa (aire, agua, decoración)
--               'solid' : bloquea por todos los lados
--               'oneway': solo se apoya desde arriba (se atraviesa subiendo)
--   dropThrough (oneway) se puede bajar manteniendo agachado
--   hitbox      {x, y, w, h} en fracciones del tile (0..1). Define la forma de
--               colisión y de contacto. Por defecto el tile completo.
--   enemySolid  los enemigos lo pisan/chocan (por defecto: collision ~= 'none')
--
--   material    nombre de material (Materials.lua): fricción, daño, líquido...
--   joinGroup   tiles del mismo grupo "se unen": no dibujan borde entre sí
--               (ver TileTypes.edges). Los líquidos también ocultan bordes.
--
--   Aspecto (uno de los tres; se usa el primero que exista):
--   draw        function(def, ctx) dibujo por código (ver ctx abajo)
--   texture     { image='assets/...png', frames=1, fps=0 } imagen (o tira
--               horizontal de `frames` cuadros animada a `fps`) escalada al tile
--   color       {r,g,b[,a]} relleno plano
--   editorColor color de respaldo para la paleta si no hay otro aspecto
--
--   ctx (dibujo): { x, y, size, col, row, raw, level, time }
--   `level` es nil al dibujar miniaturas del editor: el dibujo debe tolerarlo.

local TileCodec = require 'src/world/tiles/TileCodec'
local Materials = require 'src/world/tiles/Materials'

local TileTypes = { byId = {}, byName = {}, list = {}, reserved = {} }

local COLLISIONS = { none = true, solid = true, oneway = true }
local FULL = { x = 0, y = 0, w = 1, h = 1 }

-- Reserva ids que no deben usarse (históricos) para que nadie los reutilice.
function TileTypes.reserve(id, why)
    TileTypes.reserved[id] = why or true
end

function TileTypes.register(def)
    assert(type(def) == 'table', "tipo de tile invalido")
    local id, name = def.id, def.name
    assert(type(id) == 'number' and id == math.floor(id) and id >= 0 and id <= TileCodec.MAX_ID,
           "tile '" .. tostring(name) .. "': id debe ser entero 0.." .. TileCodec.MAX_ID)
    assert(type(name) == 'string' and name:match('^[%a_][%w_]*$'), "tile id " .. id .. ": name invalido")
    assert(not TileTypes.byId[id], "id de tile duplicado: " .. id .. " (" .. name .. ")")
    assert(not TileTypes.reserved[id], "id de tile reservado: " .. id)
    assert(not TileTypes.byName[name], "nombre de tile duplicado: " .. name)

    local t = {}
    for k, v in pairs(def) do t[k] = v end
    t.collision   = t.collision or 'none'
    assert(COLLISIONS[t.collision], "tile " .. name .. ": collision invalido")
    t.dropThrough = (t.collision == 'oneway') and t.dropThrough or false
    t.hitbox      = t.hitbox or FULL
    t.fullHitbox  = t.hitbox.x == 0 and t.hitbox.y == 0 and t.hitbox.w == 1 and t.hitbox.h == 1
    if t.enemySolid == nil then t.enemySolid = t.collision ~= 'none' end
    t.material    = t.material or 'default'
    assert(Materials.byName[t.material], "tile " .. name .. ": material desconocido '" .. t.material .. "'")
    t.mat         = Materials.get(t.material)
    t.label       = t.label or name
    t.category    = t.category or 'Otros'

    TileTypes.byId[id]     = t
    TileTypes.byName[name] = t
    table.insert(TileTypes.list, t)
    table.sort(TileTypes.list, function(a, b) return a.id < b.id end)
    _G['TILE_' .. name:upper()] = id          -- compatibilidad: TILE_SOLID, TILE_WATER...
    return t
end

-- Tipo por id. Ids desconocidos (nivel hecho con un catálogo más nuevo) → vacío.
function TileTypes.get(id)
    return TileTypes.byId[id] or TileTypes.byId[0]
end

-- Rectángulo de la hitbox en coordenadas de mundo para la celda (col,row).
function TileTypes.worldHitbox(t, col, row)
    local T, hb = TILE_PX, t.hitbox
    return (col-1)*T + hb.x*T, (row-1)*T + hb.y*T, hb.w*T, hb.h*T
end

-- ¿El punto de mundo (wx,wy) cae dentro de la hitbox del tipo en su celda?
function TileTypes.hitboxContains(t, wx, wy)
    if t.fullHitbox then return true end
    local T, hb = TILE_PX, t.hitbox
    local fx = (wx % T) / T
    local fy = (wy % T) / T
    return fx >= hb.x and fx < hb.x + hb.w and fy >= hb.y and fy < hb.y + hb.h
end

-- ── Utilidades de dibujo ──────────────────────────────────────────────────────

-- ¿Qué aristas de la celda están expuestas? Una arista se oculta si el vecino
-- pertenece al mismo joinGroup o es líquido (un bloque sumergido no dibuja el
-- borde que mira al agua). Sin nivel (miniaturas) todas están expuestas.
function TileTypes.edges(t, ctx)
    local level = ctx.level
    if not level or not t.joinGroup then
        return { top = true, bottom = true, left = true, right = true }
    end
    local function hidden(c, r)
        local raw = level:getRaw(c, r)
        local n = TileTypes.get(TileCodec.id(raw))
        return n.joinGroup == t.joinGroup or n.mat.liquid or TileCodec.isWaterlogged(raw)
    end
    local col, row = ctx.col, ctx.row
    return {
        top    = not hidden(col,   row-1),
        bottom = not hidden(col,   row+1),
        left   = not hidden(col-1, row),
        right  = not hidden(col+1, row),
    }
end

-- Dibuja un borde de `thick` px en las aristas expuestas.
function TileTypes.drawEdges(ctx, edges, thick)
    local x, y, s = ctx.x, ctx.y, ctx.size
    thick = thick or 2
    if edges.top    then love.graphics.rectangle('fill', x,           y,           s, thick) end
    if edges.bottom then love.graphics.rectangle('fill', x,           y+s-thick,   s, thick) end
    if edges.left   then love.graphics.rectangle('fill', x,           y,           thick, s) end
    if edges.right  then love.graphics.rectangle('fill', x+s-thick,   y,           thick, s) end
end

local textureCache = {}
local function getTexture(tex)
    local entry = textureCache[tex.image]
    if entry == nil then
        local ok, img = pcall(love.graphics.newImage, tex.image)
        entry = ok and { img = img, quads = {} } or false
        textureCache[tex.image] = entry
    end
    return entry or nil
end

-- Dibuja un tile completo (aspecto del tipo) en ctx.x, ctx.y, tamaño ctx.size.
function TileTypes.drawTile(t, ctx)
    if t.draw then
        t.draw(t, ctx)
    elseif t.texture then
        local tex, e = t.texture, getTexture(t.texture)
        if e then
            local frames = tex.frames or 1
            local fw, fh = e.img:getWidth() / frames, e.img:getHeight()
            local f = (frames > 1 and (tex.fps or 0) > 0)
                      and (math.floor((ctx.time or 0) * tex.fps) % frames) or 0
            local q = e.quads[f]
            if not q then
                q = love.graphics.newQuad(f*fw, 0, fw, fh, e.img:getWidth(), fh)
                e.quads[f] = q
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(e.img, q, ctx.x, ctx.y, 0, ctx.size/fw, ctx.size/fh)
        end
    elseif t.color then
        love.graphics.setColor(t.color)
        love.graphics.rectangle('fill', ctx.x, ctx.y, ctx.size, ctx.size)
    end
end

return TileTypes
