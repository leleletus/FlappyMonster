-- src/world/SubTiles.lua
-- SUBTILES: versiones pequeñas (un cuarto de casilla) de algunos bloques,
-- colocadas en cualquiera de las 4 subceldas de una celda (como los vents o
-- los pinchos). Para detalles y decoración sin ocupar la casilla entera.
--
-- JSON del nivel: "subtiles": [{col, row, sub (1=TL 2=TR 3=BL 4=BR), kind,
-- solid}]; `kind` = nombre del tile del catálogo (KINDS) y `solid` = false
-- para que sea solo decoración (por defecto son sólidos para todos: jugadores
-- y entidades). El editor solo guarda solid cuando es false.
--
-- Física: una subcelda sólida se comporta como un tile cuya hitbox es ese
-- cuarto de casilla. Level:getDefAt la devuelve (SubTiles.defAt) en las celdas
-- sin colisión propia, así que collisionAt / landingCross / entitySolidAt...
-- (jugador, entidades, servidor, predicción y solver) la ven sin más.
--
-- Añadir una subtile nueva = el nombre de su tile en KINDS.

local TileTypes = require 'src/world/tiles/TileTypes'
local TileCodec = require 'src/world/tiles/TileCodec'

local SubTiles = {}

SubTiles.KINDS = { 'solid', 'dirt', 'grass' }     -- piedra, tierra, césped

local QUAD = { { 0, 0 }, { 0.5, 0 }, { 0, 0.5 }, { 0.5, 0.5 } }   -- esquina de cada subcelda (fracción)
SubTiles.QUAD = QUAD

local function key(col, row) return row * 65536 + col end
SubTiles.key = key

function SubTiles.isKind(kind)
    for _, k in ipairs(SubTiles.KINDS) do if k == kind then return TileTypes.byName[k] ~= nil end end
    return false
end

-- Tipo "pequeño": el del bloque con la hitbox de su cuarto (hereda todo lo demás)
local defs = {}
function SubTiles.def(kind, q)
    local k = kind .. q
    local d = defs[k]
    if not d then
        local base = TileTypes.byName[kind]
        local o = QUAD[q]
        d = setmetatable({ hitbox = { x = o[1], y = o[2], w = 0.5, h = 0.5 }, fullHitbox = false,
                           sub = q, base = base }, { __index = base })
        defs[k] = d
    end
    return d
end

-- Entrada válida del JSON (o nil)
function SubTiles.normalize(o)
    if type(o) ~= 'table' then return nil end
    local col, row, sub = tonumber(o.col), tonumber(o.row), tonumber(o.sub)
    if not (col and row and sub) or sub < 1 or sub > 4 or not SubTiles.isKind(o.kind) then return nil end
    return { col = math.floor(col), row = math.floor(row), sub = math.floor(sub), kind = o.kind,
             solid = o.solid ~= false }
end

-- Prepara level.subtiles (lista), level.subCells[key] = {[q] = entrada} (dibujo)
-- y level.subSolid[key] = {[q] = def} (física; nil si no hay ninguna sólida)
function SubTiles.build(level, list)
    level.subtiles, level.subCells, level.subSolid = {}, nil, nil
    for _, raw in ipairs(list or {}) do
        local o = SubTiles.normalize(raw)
        if o then
            level.subtiles[#level.subtiles + 1] = o
            local k = key(o.col, o.row)
            level.subCells = level.subCells or {}
            level.subCells[k] = level.subCells[k] or {}
            level.subCells[k][o.sub] = o
            if o.solid then
                level.subSolid = level.subSolid or {}
                level.subSolid[k] = level.subSolid[k] or {}
                level.subSolid[k][o.sub] = SubTiles.def(o.kind, o.sub)
            end
        end
    end
end

-- Subcelda sólida que contiene el punto de mundo, o nil
function SubTiles.defAt(level, wx, wy)
    local T = TILE_PX
    local col, row = math.floor(wx / T) + 1, math.floor(wy / T) + 1
    local c = level.subSolid[key(col, row)]
    if not c then return nil end
    local q = ((wx % T) >= T / 2 and 2 or 1) + ((wy % T) >= T / 2 and 2 or 0)
    return c[q]
end

-- ¿Hay alguna subcelda sólida en la celda?
function SubTiles.solidInCell(level, col, row)
    return level.subSolid ~= nil and level.subSolid[key(col, row)] ~= nil
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Aristas expuestas de la subcelda (gx, gy en la rejilla de subceldas): se
-- ocultan hacia un tile o una subtile del mismo joinGroup, o hacia el agua
local function hiddenTowards(level, def, gx, gy)
    local col, row = math.floor(gx / 2) + 1, math.floor(gy / 2) + 1
    local cells = level.subCells and level.subCells[key(col, row)]
    local s = cells and cells[(gx % 2) + (gy % 2) * 2 + 1]
    if s then
        local n = TileTypes.byName[s.kind]
        return n.joinGroup ~= nil and n.joinGroup == def.joinGroup
    end
    -- (misma regla que los bloques grandes: bloque del grupo, líquido o bloque de jefe)
    return TileTypes.joinsCell(level, col, row, def.joinGroup)
end

local function edgesOf(level, def, gx, gy)
    if not def.joinGroup then return { top = true, bottom = true, left = true, right = true } end
    return {
        top    = not hiddenTowards(level, def, gx, gy - 1),
        bottom = not hiddenTowards(level, def, gx, gy + 1),
        left   = not hiddenTowards(level, def, gx - 1, gy),
        right  = not hiddenTowards(level, def, gx + 1, gy),
    }
end

-- Dibuja las subtiles de la celda (col, row) con su esquina de pantalla en
-- (px, py). `ctx` = el contexto de dibujo de tiles (se restaura al acabar).
-- En el editor (EDITOR_VIEW) las que no son sólidas llevan un marco de puntos.
function SubTiles.renderCell(level, col, row, px, py, ctx)
    local cells = level.subCells and level.subCells[key(col, row)]
    if not cells then return end
    local T, H = TILE_PX, TILE_PX / 2
    local x0, y0, size, c0, r0 = ctx.x, ctx.y, ctx.size, ctx.col, ctx.row
    for q = 1, 4 do
        local s = cells[q]
        if s then
            local def = TileTypes.byName[s.kind]
            local gx, gy = (col - 1) * 2 + (q - 1) % 2, (row - 1) * 2 + math.floor((q - 1) / 2)
            ctx.x, ctx.y, ctx.size = px + QUAD[q][1] * T, py + QUAD[q][2] * T, H
            ctx.col, ctx.row = gx, gy
            ctx.edges = edgesOf(level, def, gx, gy)
            TileTypes.drawTile(def, ctx)
            ctx.edges = nil
            if EDITOR_VIEW and not s.solid then
                love.graphics.setColor(1, 1, 1, 0.8)
                for i = 0, H - 4, 8 do
                    love.graphics.rectangle('fill', ctx.x + i, ctx.y, 4, 2)
                    love.graphics.rectangle('fill', ctx.x + i, ctx.y + H - 2, 4, 2)
                    love.graphics.rectangle('fill', ctx.x, ctx.y + i, 2, 4)
                    love.graphics.rectangle('fill', ctx.x + H - 2, ctx.y + i, 2, 4)
                end
            end
        end
    end
    ctx.x, ctx.y, ctx.size, ctx.col, ctx.row = x0, y0, size, c0, r0
end

return SubTiles
