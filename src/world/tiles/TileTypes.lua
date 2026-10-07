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
--   breakable   se rompe con un cabezazo desde abajo o un ground pound
--   toggle      nombre del tile en que se convierte con un cabezazo desde
--               abajo o un ground pound (bloques ON/OFF: Level:hitTile)
--   hidden      no se ve hasta que un jugador lo toca (Level:updateHiddenBlocks)
--   switchBlock { kind='on'|'off', active=bool, other='<tile>' }: Bloque ON/OFF
--               que depende de un activador (Level:updateSwitchBlocks)
--   editorHide  no sale en la paleta (p. ej. la variante inactiva de un Bloque ON)
--   fake        tile trampa: se ve como otro (`mimics`) pero no colisiona ni
--               hace daño (los pinchos puestos encima tampoco)
--   trigger     nombre de evento al tocarlo (p. ej. 'finish'); lo consultan
--               los modos de juego con Level:triggerInBox
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
--   debris      { {r,g,b}, ... } colores de sus partículas de impacto (si no,
--               los del material; ver TileTypes.debris)
--
--   ctx (dibujo): { x, y, size, col, row, raw, level, time [, edges] }
--   (`edges` ya calculadas: las subceldas de src/world/level/SubTiles.lua)
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

-- Orden de las categorías en la paleta del editor (las demás, al final)
TileTypes.CATEGORIES = { 'Básicos', 'Terreno', 'Plataformas', 'Mecanismos', 'Líquidos', 'Peligros', 'Objetivos' }
function TileTypes.categoryOrder(c)
    for i, id in ipairs(TileTypes.CATEGORIES) do if id == c then return i end end
    return #TileTypes.CATEGORIES + 1
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
--
-- UNA sola regla para todo lo que se dibuja como bloque (bloques grandes,
-- mini bloques de src/world/level/SubTiles.lua y bloques de jefe): se unen si son
-- del mismo joinGroup. Una arista puede estar expuesta entera (true), oculta
-- (false) o solo a medias ({ primera, segunda } = mitad izquierda/arriba y
-- derecha/abajo) cuando al otro lado hay mini bloques que cubren solo media.

-- ¿Se une con `group` la celda (c, r)? Bloque grande del grupo, líquido, o un
-- cuerpo que se dibuja como bloque (level.joinOverlay: bloques de jefe sólidos)
function TileTypes.joinsCell(level, c, r, group)
    local raw = level:getRaw(c, r)
    local n = TileTypes.get(TileCodec.id(raw))
    if (group and n.joinGroup == group) or n.mat.liquid or TileCodec.isWaterlogged(raw) then return true end
    if group and level.joinOverlay then
        for o in pairs(level.joinOverlay) do
            if o.joinsCell and o:joinsCell(c, r, group) then return true end
        end
    end
    return false
end

-- Mini bloques de la celda vecina que tocan cada mitad de la arista (cuartos:
-- 1 arriba-izq, 2 arriba-der, 3 abajo-izq, 4 abajo-der)
local SIDE = {
    top    = { 0, -1, { 3, 4 } }, bottom = { 0, 1, { 1, 2 } },
    left   = { -1, 0, { 2, 4 } }, right  = { 1, 0, { 1, 3 } },
}
-- Exposición de la arista `side` de la celda (c, r): true / false / {a, b}
function TileTypes.sideExposure(level, c, r, side, group)
    local d = SIDE[side]
    local nc, nr = c + d[1], r + d[2]
    if TileTypes.joinsCell(level, nc, nr, group) then return false end
    local cells = group and level.subCells and level.subCells[nr * 65536 + nc]
    if not cells then return true end
    local function joined(i)
        local s = cells[d[3][i]]
        local def = s and TileTypes.byName[s.kind]
        return def ~= nil and def.joinGroup == group
    end
    local a, b = not joined(1), not joined(2)
    if a == b then return a end
    return { a, b }
end

-- ¿Está expuesta la mitad `i` (1 o 2) de una arista? (true/false o {a, b})
function TileTypes.half(v, i)
    if type(v) == 'table' then return v[i] end
    return v and true or false
end

function TileTypes.edges(t, ctx)
    if ctx.edges then return ctx.edges end
    local level = ctx.level
    if not level or not t.joinGroup then
        return { top = true, bottom = true, left = true, right = true }
    end
    local col, row, g = ctx.col, ctx.row, t.joinGroup
    return {
        top    = TileTypes.sideExposure(level, col, row, 'top', g),
        bottom = TileTypes.sideExposure(level, col, row, 'bottom', g),
        left   = TileTypes.sideExposure(level, col, row, 'left', g),
        right  = TileTypes.sideExposure(level, col, row, 'right', g),
    }
end

-- Dibuja un borde de `thick` px en las aristas (o medias aristas) expuestas.
function TileTypes.drawEdges(ctx, edges, thick)
    local x, y, s = ctx.x, ctx.y, ctx.size
    thick = thick or 2
    local h1 = math.floor(s / 2)
    local h2 = s - h1
    local half, rect = TileTypes.half, love.graphics.rectangle
    if half(edges.top, 1)    then rect('fill', x,      y,         h1, thick) end
    if half(edges.top, 2)    then rect('fill', x + h1, y,         h2, thick) end
    if half(edges.bottom, 1) then rect('fill', x,      y+s-thick, h1, thick) end
    if half(edges.bottom, 2) then rect('fill', x + h1, y+s-thick, h2, thick) end
    if half(edges.left, 1)   then rect('fill', x,         y,      thick, h1) end
    if half(edges.left, 2)   then rect('fill', x,         y + h1, thick, h2) end
    if half(edges.right, 1)  then rect('fill', x+s-thick, y,      thick, h1) end
    if half(edges.right, 2)  then rect('fill', x+s-thick, y + h1, thick, h2) end
end

-- Colores de las partículas que suelta al golpearlo / romperlo: los del
-- tile, los de su material o, si no, tonos de su color
local debrisCache = setmetatable({}, { __mode = 'k' })
function TileTypes.debris(t)
    if t.debris then return t.debris end
    if t.mat and t.mat.debris then return t.mat.debris end
    local d = debrisCache[t]
    if not d then
        local c = t.editorColor or (t.mat and t.mat.color) or { 0.6, 0.6, 0.6 }
        d = { { c[1], c[2], c[3] }, { c[1] * 0.75, c[2] * 0.75, c[3] * 0.75 },
              { math.min(1, c[1] * 1.2), math.min(1, c[2] * 1.2), math.min(1, c[3] * 1.2) } }
        debrisCache[t] = d
    end
    return d
end

local textureCache = {}
local function getTexture(tex)
    local entry = textureCache[tex.image]
    if entry == nil then
        local ok, img = pcall(love.graphics.newImage, tex.image)
        if ok then img:setFilter('nearest', 'nearest') end        -- (pixel art: sin suavizar)
        entry = ok and { img = img, quads = {} } or false
        textureCache[tex.image] = entry
    end
    return entry or nil
end

-- Dibuja una textura de tile (def.texture o { image = ... }) en la celda del
-- contexto, con transparencia opcional (hielo: semitransparente).
--   tex.span = n : el dibujo cubre n x n casillas y se repite (la piedra: sus grietas
--                  siguen de un bloque al de al lado); cada casilla usa su trozo según
--                  su columna/fila.
--   ctx.quarter = {qx, qy} : un mini bloque dibuja SU cuarto de ese trozo, a la misma
--                  escala que los bloques grandes (casan sin costura); `capRow` fuerza
--                  la fila de cuartos (el césped al aire siempre usa la de arriba).
local function texQuad(e, sx, sy, sw, sh, w, h)
    e.sub = e.sub or {}
    local k = sx .. ',' .. sy .. ',' .. sw
    local q = e.sub[k]
    if not q then q = love.graphics.newQuad(sx, sy, sw, sh, w, h); e.sub[k] = q end
    return q
end

function TileTypes.drawTexture(tex, ctx, alpha, capRow)
    local e = getTexture(tex)
    if not e then return end
    local w, h = e.img:getWidth(), e.img:getHeight()
    love.graphics.setColor(1, 1, 1, alpha or 1)
    local span, q = tex.span or 1, ctx.quarter
    if span == 1 and not q then
        love.graphics.draw(e.img, ctx.x, ctx.y, 0, ctx.size / w, ctx.size / h)
        return
    end
    local cw, ch = w / span, h / span
    local cx, cy = 0, 0
    if span > 1 and ctx.col and ctx.row then
        if q then cx, cy = math.floor(ctx.col / 2) % span, math.floor(ctx.row / 2) % span   -- (rejilla de medias casillas, desde 0)
        else cx, cy = (ctx.col - 1) % span, (ctx.row - 1) % span end
    end
    local sx, sy, sw, sh = cx * cw, cy * ch, cw, ch
    if q then
        sw, sh = cw / 2, ch / 2
        sx, sy = sx + q[1] * sw, sy + (capRow or q[2]) * sh
    end
    love.graphics.draw(e.img, texQuad(e, sx, sy, sw, sh, w, h), ctx.x, ctx.y, 0, ctx.size / sw, ctx.size / sh)
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
