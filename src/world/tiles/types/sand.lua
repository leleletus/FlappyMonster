-- Arena: bloque sólido de terreno (se une con 'ground'). Textura
-- assets/images/world/tiles/sand.png. Donde toca tierra, césped o piedra (bloque grande o
-- mini bloque, también siendo ella un mini bloque) no cambia de golpe: dibuja por
-- ese lado una franja tramada con los colores del vecino
-- (assets/images/world/tiles/sand_blend.png: cuadro 1 tierra —también bajo el césped—,
-- 2 piedra, 3 roca abisal, 4 borde; la franja está a la izquierda y se gira para
-- cada lado). sand.png: tools/ui/make_terrain.py; sand_blend.png: make_world_art.py.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/world/tiles/sand.png' }
local BLEND_OF = { dirt = 1, grass = 1, solid = 2, deep_stone = 3, border = 4, basalt = 4, ash = 4 }
-- lado → { dx, dy en medias casillas, ángulo } (la franja del dibujo está a la izquierda)
local SIDES = { { -1, 0, 0 }, { 0, -1, math.pi / 2 }, { 1, 0, math.pi }, { 0, 1, -math.pi / 2 } }
local SubTiles
local blend, quads

local function loadBlend()
    if blend == nil then
        local ok, img = pcall(love.graphics.newImage, 'assets/images/world/tiles/sand_blend.png')
        blend = ok and img or false
        if blend then
            blend:setFilter('nearest', 'nearest')
            local w, h = blend:getDimensions()
            quads = {}
            -- [cuadro][mitad 1|2]: el cuarto izquierdo de arriba / de abajo de cada cuadro
            -- (16x16 de arte; la franja ocupa sus 5 columnas de la izquierda)
            for i = 1, math.floor(w / h) do
                quads[i] = { love.graphics.newQuad((i - 1) * h, 0, h / 2, h / 2, w, h),
                             love.graphics.newQuad((i - 1) * h, h / 2, h / 2, h / 2, w, h) }
            end
        end
    end
    return blend
end

-- Franjas de transición de la media casilla de arena (gx, gy), dibujada en el
-- cuadrado de pantalla (x, y, u): por cada lado cuyo vecino (bloque grande o mini
-- bloque) es tierra, césped, piedra, roca abisal o borde
local function bands(level, gx, gy, x, y, u)
    SubTiles = SubTiles or require 'src/world/level/SubTiles'
    local fh = blend:getHeight()
    local k = u / (fh / 2)
    for _, sd in ipairs(SIDES) do
        local n = SubTiles.kindAt(level, gx + sd[1], gy + sd[2])
        local f = n and BLEND_OF[n]
        if f and quads[f] then
            local half = ((sd[1] ~= 0) and gy or gx) % 2 + 1        -- (sigue el dibujo a lo largo del lado)
            love.graphics.draw(blend, quads[f][half], x + u / 2, y + u / 2, sd[3], k, k, fh / 4, fh / 4)
        end
    end
end

return {
    id = 35, name = 'sand', label = 'Arena', category = 'Terreno',
    collision = 'solid', material = 'sand', joinGroup = 'ground',
    editorColor = { 0.86, 0.74, 0.49 },
    texture = TEX,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        TileTypes.drawTexture(TEX, ctx)
        -- Transiciones hacia los bloques vecinos, por medias casillas (así también
        -- hacia mini bloques, y en los mini bloques de arena)
        local level = ctx.level
        if level and ctx.col and loadBlend() then
            love.graphics.setColor(1, 1, 1, 1)
            if ctx.quarter then
                bands(level, ctx.col, ctx.row, x, y, s)                 -- (ctx.col/row = media casilla)
            else
                local u = s / 2
                for qy = 0, 1 do
                    for qx = 0, 1 do
                        bands(level, (ctx.col - 1) * 2 + qx, (ctx.row - 1) * 2 + qy, x + qx * u, y + qy * u, u)
                    end
                end
            end
        end
        love.graphics.setColor(0.95, 0.86, 0.64, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
