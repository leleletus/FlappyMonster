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
--   joinAlso    { 'grupo' o 'nombre de tile', ... }: con qué MÁS se une (sin borde) aunque sea de otro
--               grupo (la nieve con el hielo y al revés). Solo dibujo.
--
--   Aspecto (uno de los cuatro; se usa el primero que exista):
--   draw        function(def, ctx) dibujo por código (ver ctx abajo)
--   skin        piel de bloque por capas (TileTypes.drawSkin, 2026-10-29): un CUERPO sin costuras y capas que
--               solo se ponen en las caras al aire, así una pared de bloques se ve como UNA masa:
--                 body   = { image, span }   el cuerpo (span 2: el dibujo cubre 2x2 casillas)
--                 top / bottom / left / right = { image }   capa de esa cara (16x16 de arte, transparente fuera de
--                          su franja) solo si la cara da al aire (o a medias: se pone en su mitad)
--                 over   = { image }   capa que va siempre (la ventana de un muro)
--                 alpha  = 0.78        el hielo, semitransparente
--                 blend  = { image, of = { <tile> = cuadro } }   franjas tramadas hacia el vecino (como la arena)
--                 edges  = { top = {r,g,b[,a]}, bottom = …, left = …, right = … }   filo de 2 px en las caras al aire
--                 capEdge = { {r,g,b}, filas }   el filo de los lados junto a la capa de arriba (filas de 16)
--   spill       { image, frame, onto = { <tile>, … } }: COSTURA que este tipo deja sobre los bloques de `onto` que lo
--               tocan, dibujada por ellos (la nieve sobre la tierra, la piedra…; TileTypes.drawSpill). Solo dibujo.
--   texture     { anim='id', seq='idle' } = un conjunto de animación (assets/anim, `love . --anim`), o
--               { image='assets/...png', frames=1, fps=0 } imagen (o tira
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
    if t.spill then                            -- (de quién recibe la costura: TileTypes.drawSpill)
        t.spill.set = {}
        for _, n in ipairs(t.spill.onto) do t.spill.set[n] = true; TileTypes.spillTargets[n] = true end
    end
    if t.joinAlso then                         -- (lista → conjunto: grupos o nombres de tile)
        local set = {}
        for _, v in ipairs(t.joinAlso) do set[v] = true end
        t.joinAlsoSet = set
    end

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

-- ¿Se une el tipo `n` con el grupo `group` (o con el conjunto `also` de grupos / nombres: joinAlso)?
function TileTypes.joinsDef(n, group, also)
    if group and n.joinGroup == group then return true end
    return also ~= nil and (also[n.name] or (n.joinGroup ~= nil and also[n.joinGroup])) == true
end

-- ¿Se une con `group` (o con `also`, el joinAlso del que se dibuja) la celda (c, r)? Bloque grande del grupo,
-- líquido, o un cuerpo que se dibuja como bloque (level.joinOverlay: bloques de jefe sólidos)
function TileTypes.joinsCell(level, c, r, group, also)
    local raw = level:getRaw(c, r)
    local n = TileTypes.get(TileCodec.id(raw))
    if TileTypes.joinsDef(n, group, also) or n.mat.liquid or TileCodec.isWaterlogged(raw) then return true end
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
local function subJoined(cells, k, group, also)
    local s = cells[k]
    local def = s and TileTypes.byName[s.kind]
    return def ~= nil and TileTypes.joinsDef(def, group, also)
end
function TileTypes.sideExposure(level, c, r, side, group, also)
    local d = SIDE[side]
    local nc, nr = c + d[1], r + d[2]
    if TileTypes.joinsCell(level, nc, nr, group, also) then return false end
    local cells = group and level.subCells and level.subCells[nr * 65536 + nc]
    if not cells then return true end
    local a, b = not subJoined(cells, d[3][1], group, also), not subJoined(cells, d[3][2], group, also)
    if a == b then return a end
    return { a, b }
end

-- ¿Está expuesta la mitad `i` (1 o 2) de una arista? (true/false o {a, b})
function TileTypes.half(v, i)
    if type(v) == 'table' then return v[i] end
    return v and true or false
end

-- Las aristas expuestas de la casilla que se dibuja. Se llama por cada casilla visible en cada fotograma: devuelve
-- una tabla REUTILIZADA (válida hasta la siguiente llamada; para guardarla, copiarla).
local ALL_EDGES = { top = true, bottom = true, left = true, right = true }
local EDGES = {}
function TileTypes.edges(t, ctx)
    if ctx.edges then return ctx.edges end
    local level = ctx.level
    if not level or not t.joinGroup then return ALL_EDGES end
    local col, row, g, also = ctx.col, ctx.row, t.joinGroup, t.joinAlsoSet
    EDGES.top    = TileTypes.sideExposure(level, col, row, 'top', g, also)
    EDGES.bottom = TileTypes.sideExposure(level, col, row, 'bottom', g, also)
    EDGES.left   = TileTypes.sideExposure(level, col, row, 'left', g, also)
    EDGES.right  = TileTypes.sideExposure(level, col, row, 'right', g, also)
    return EDGES
end

-- Dibuja un borde de `thick` px en las aristas (o medias aristas) expuestas.
-- (noTop: sin la arista de arriba, para los que la pintan a su manera: hierba, ceniza)
function TileTypes.drawEdges(ctx, edges, thick, noTop)
    local x, y, s = ctx.x, ctx.y, ctx.size
    thick = thick or 2
    local h1 = math.floor(s / 2)
    local h2 = s - h1
    local half, rect = TileTypes.half, love.graphics.rectangle
    if not noTop then
        if half(edges.top, 1)    then rect('fill', x,      y,         h1, thick) end
        if half(edges.top, 2)    then rect('fill', x + h1, y,         h2, thick) end
    end
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
local Anim
local function getTexture(tex)
    local entry = textureCache[tex.image]
    if entry == nil then
        local ok, img = pcall(require('src/fx/Anim').image, tex.image)
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

function TileTypes.drawTexture(tex, ctx, alpha, capRow, capCol)
    -- Textura ANIMADA con un conjunto de animación (assets/anim/<id>.json, editor: love . --anim):
    --   texture = { anim = 'mi_tile', seq = 'idle' }   → el cuadro que toca, estirado a la casilla
    -- (todas las casillas van a la vez: el cuadro sale del reloj; con ctx.quarter, su cuarto del cuadro)
    if tex.anim then
        Anim = Anim or require 'src/fx/Anim'
        local set = Anim.load(tex.anim)
        local f = set:frame((set:frameAt(tex.seq or set.fallback, love.timer.getTime())))
        if not (f and f.image) then return end
        love.graphics.setColor(1, 1, 1, alpha or 1)
        local sx, sy, sw, sh = f.x, f.y, f.w, f.h
        local q = ctx.quarter
        if q then sw, sh = f.w / 2, f.h / 2; sx, sy = f.x + (capCol or q[1]) * sw, f.y + (capRow or q[2]) * sh end
        tex._q = tex._q or {}
        local key = sx .. ',' .. sy .. ',' .. sw .. ',' .. sh
        local quad = tex._q[key]
        if not quad then quad = love.graphics.newQuad(sx, sy, sw, sh, f.iw, f.ih); tex._q[key] = quad end
        love.graphics.draw(f.image, quad, ctx.x, ctx.y, 0, ctx.size / sw, ctx.size / sh)
        return
    end
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
        sx, sy = sx + (capCol or q[1]) * sw, sy + (capRow or q[2]) * sh
    end
    love.graphics.draw(e.img, texQuad(e, sx, sy, sw, sh, w, h), ctx.x, ctx.y, 0, ctx.size / sw, ctx.size / sh)
end

-- ── Pieles por capas (def.skin) ───────────────────────────────────────────────
-- Capa de una cara (`side`) de 16x16 de arte: entera si la cara da al aire (true), o solo en la mitad de la cara que da
-- al aire ({a, b}); en un mini bloque, el cuarto de la capa que toca a esa cara (escala de los bloques grandes)
local OVER_ROW = { top = 0, bottom = 1 }
local OVER_COL = { left = 0, right = 1 }
local function drawOverlay(tex, ctx, side, exp, alpha)
    if ctx.quarter then
        if exp then TileTypes.drawTexture(tex, ctx, alpha, OVER_ROW[side], OVER_COL[side]) end
        return
    end
    if type(exp) ~= 'table' then
        if exp then TileTypes.drawTexture(tex, ctx, alpha) end
        return
    end
    local e = getTexture(tex)
    if not e then return end
    local w, h = e.img:getWidth(), e.img:getHeight()
    local k = ctx.size / w
    love.graphics.setColor(1, 1, 1, alpha or 1)
    local vertical = (side == 'left' or side == 'right')
    for i = 1, 2 do
        if exp[i] then
            local o = (i - 1) / 2
            if vertical then
                love.graphics.draw(e.img, texQuad(e, 0, o * h, w, h / 2, w, h), ctx.x, ctx.y + o * ctx.size, 0, k, k)
            else
                love.graphics.draw(e.img, texQuad(e, o * w, 0, w / 2, h, w, h), ctx.x + o * ctx.size, ctx.y, 0, k, k)
            end
        end
    end
end

-- Franjas tramadas de transición hacia los vecinos (la arena hacia la tierra, la nieve hacia la piedra, el hielo hacia
-- la nieve), por MEDIAS casillas — así también hacia mini bloques y en los mini bloques —. `spec` = { image, of =
-- { <nombre del tile vecino> = cuadro } }: cada cuadro es de 16x16 de arte con la franja a la IZQUIERDA (5 columnas),
-- que se gira para cada lado.
local BLEND_SIDES = { { -1, 0, 0 }, { 0, -1, math.pi / 2 }, { 1, 0, math.pi }, { 0, 1, -math.pi / 2 } }
local SubTilesMod
local function blendQuads(spec)
    local e = getTexture(spec)
    if not e then return nil end
    if not e.blend then
        local w, h = e.img:getWidth(), e.img:getHeight()
        e.blend = {}
        -- [cuadro][mitad 1|2]: el cuarto izquierdo de arriba / de abajo de cada cuadro
        for i = 1, math.floor(w / h) do
            e.blend[i] = { love.graphics.newQuad((i - 1) * h, 0, h / 2, h / 2, w, h),
                           love.graphics.newQuad((i - 1) * h, h / 2, h / 2, h / 2, w, h) }
        end
    end
    return e
end
-- (la franja `f` de `e` en la media casilla (gx, gy) dibujada en (x, y, u), hacia el lado `sd`)
local function band(e, f, sd, gx, gy, x, y, u)
    if not e.blend[f] then return end
    local fh = e.img:getHeight()
    local k = u / (fh / 2)
    local half = ((sd[1] ~= 0) and gy or gx) % 2 + 1        -- (sigue el dibujo a lo largo del lado)
    love.graphics.draw(e.img, e.blend[f][half], x + u / 2, y + u / 2, sd[3], k, k, fh / 4, fh / 4)
end
local function blendHalf(spec, e, level, gx, gy, x, y, u)
    for _, sd in ipairs(BLEND_SIDES) do
        local n = SubTilesMod.kindAt(level, gx + sd[1], gy + sd[2])
        local f = n and spec.of[n]
        if f then band(e, f, sd, gx, gy, x, y, u) end
    end
end
function TileTypes.drawBlend(spec, ctx)
    local level = ctx.level
    if not (level and ctx.col) then return end
    local e = blendQuads(spec)
    if not e then return end
    SubTilesMod = SubTilesMod or require 'src/world/level/SubTiles'
    love.graphics.setColor(1, 1, 1, 1)
    if ctx.quarter then
        blendHalf(spec, e, level, ctx.col, ctx.row, ctx.x, ctx.y, ctx.size)          -- (ctx.col/row = media casilla)
    else
        local u = ctx.size / 2
        for qy = 0, 1 do
            for qx = 0, 1 do
                blendHalf(spec, e, level, (ctx.col - 1) * 2 + qx, (ctx.row - 1) * 2 + qy, ctx.x + qx * u, ctx.y + qy * u, u)
            end
        end
    end
end

-- ── Costura que DERRAMA un vecino (def.spill, 2026-10-29) ─────────────────────
-- Al revés que `blend` (que dibuja el bloque sobre sí mismo): un tipo con `spill = { image, frame, onto = { <tile>, … } }`
-- se derrama sobre los bloques de `onto` que lo tocan — la nieve deja su labio y sus grumos sobre la tierra, la piedra…
-- (arriba, abajo y a los lados; también mini bloques y el plano de fondo) —. El dibujo es un cuadro como los de `blend`
-- (franja a la IZQUIERDA, girada hacia el lado del vecino) y lo pone el bloque que RECIBE, dentro de su casilla, al
-- dibujarse (TileTypes.drawTile): nunca tapa al que se derrama.
TileTypes.spillTargets = {}            -- [nombre del tile que recibe] = true (si nadie se derrama en él, no se mira nada)
local function spillOf(n, name)
    local d = n and TileTypes.byName[n]
    local sp = d and d.spill
    return sp and sp.set[name] and sp or nil
end
local function spillHalf(name, level, gx, gy, x, y, u)
    for _, sd in ipairs(BLEND_SIDES) do
        local sp = spillOf(SubTilesMod.kindAt(level, gx + sd[1], gy + sd[2]), name)
        if sp then
            local e = blendQuads(sp)
            if e then band(e, sp.frame or 1, sd, gx, gy, x, y, u) end
        end
    end
end
local function spills(level, c, r, name)
    local sp = level:getDef(c, r).spill
    return sp ~= nil and sp.set[name] == true
end
local function spillNear(level, name, c, r)
    -- (antes de mirar por medias casillas: ¿algún vecino grande se derrama aquí? Con mini bloques, siempre se mira)
    if level.subCells then return true end
    return spills(level, c - 1, r, name) or spills(level, c + 1, r, name) or spills(level, c, r - 1, name)
        or spills(level, c, r + 1, name)
end
function TileTypes.drawSpill(t, ctx)
    local level = ctx.level
    if not (level and ctx.col and level.getDef) then return end
    local name = t.mimics or t.name
    if not TileTypes.spillTargets[name] then return end
    SubTilesMod = SubTilesMod or require 'src/world/level/SubTiles'
    love.graphics.setColor(1, 1, 1, 1)
    if ctx.quarter then
        spillHalf(name, level, ctx.col, ctx.row, ctx.x, ctx.y, ctx.size)
    elseif spillNear(level, name, ctx.col, ctx.row) then
        local u = ctx.size / 2
        for qy = 0, 1 do
            for qx = 0, 1 do
                spillHalf(name, level, (ctx.col - 1) * 2 + qx, (ctx.row - 1) * 2 + qy, ctx.x + qx * u, ctx.y + qy * u, u)
            end
        end
    end
end

-- Dibuja un bloque con piel por capas (def.skin; ver la cabecera)
local SKIN_SIDES = { 'bottom', 'left', 'right', 'top' }       -- (la de arriba, la última: tapa a las otras)
local function edgeRect(side, x, y, s, i, h1, h2)
    local a = (i == 1) and 0 or h1
    local len = (i == 1) and h1 or h2
    if side == 'top' then return x + a, y, len, 2
    elseif side == 'bottom' then return x + a, y + s - 2, len, 2
    elseif side == 'left' then return x, y + a, 2, len
    else return x + s - 2, y + a, 2, len end
end
function TileTypes.drawSkin(t, ctx)
    local sk = t.skin
    local e = TileTypes.edges(t, ctx)
    local alpha = sk.alpha
    if sk.body then TileTypes.drawTexture(sk.body, ctx, alpha) end
    if sk.over then TileTypes.drawTexture(sk.over, ctx, alpha) end
    if sk.blend then TileTypes.drawBlend(sk.blend, ctx) end
    for _, side in ipairs(SKIN_SIDES) do
        local tex = sk[side]
        if tex and e[side] then drawOverlay(tex, ctx, side, e[side], alpha) end
    end
    local x, y, s = ctx.x, ctx.y, ctx.size
    local ed = sk.edges
    if ed then
        local h1 = math.floor(s / 2)
        local h2 = s - h1
        local half, rect = TileTypes.half, love.graphics.rectangle
        for _, side in ipairs(SKIN_SIDES) do
            local c = ed[side]
            if c and e[side] then
                love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
                for i = 1, 2 do
                    if half(e[side], i) then rect('fill', edgeRect(side, x, y, s, i, h1, h2)) end
                end
            end
        end
    end
    local ce = sk.capEdge
    if ce and e.top then
        -- (junto a la capa de arriba el filo de los lados es del color de la capa)
        local cap = math.floor(s * ce[2] / (ctx.quarter and 8 or 16))
        local c = ce[1]
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
        if TileTypes.half(e.left, 1) then love.graphics.rectangle('fill', x, y, 2, math.min(cap, s)) end
        if TileTypes.half(e.right, 1) then love.graphics.rectangle('fill', x + s - 2, y, 2, math.min(cap, s)) end
    end
end

-- Dibuja un tile completo (aspecto del tipo) en ctx.x, ctx.y, tamaño ctx.size.
function TileTypes.drawTile(t, ctx)
    if t.draw then
        t.draw(t, ctx)
    elseif t.skin then
        TileTypes.drawSkin(t, ctx)
    elseif t.texture and t.texture.anim then
        TileTypes.drawTexture(t.texture, ctx)          -- (animada con un conjunto de animación)
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
    if TileTypes.spillTargets[t.mimics or t.name] then TileTypes.drawSpill(t, ctx) end     -- (la costura de un vecino)
end

return TileTypes
