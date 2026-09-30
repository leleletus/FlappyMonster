-- Arena: bloque sólido de terreno (se une con 'ground'). Textura
-- assets/images/tiles/sand.png. Donde toca tierra, césped o piedra no cambia de
-- golpe: dibuja por ese lado una franja tramada con los colores del vecino
-- (assets/images/tiles/sand_blend.png: cuadro 1 tierra —también bajo el césped—,
-- 2 piedra; la franja está a la izquierda y se gira para cada lado).
-- Ambas de tools/ui/make_terrain.py.
local TileTypes = require 'src/world/tiles/TileTypes'

local TEX = { image = 'assets/images/tiles/sand.png' }
local BLEND_OF = { dirt = 1, grass = 1, solid = 2 }
-- lado → { dc, dr, ángulo } (la franja del dibujo está a la izquierda)
local SIDES = { left = { -1, 0, 0 }, top = { 0, -1, math.pi / 2 }, right = { 1, 0, math.pi }, bottom = { 0, 1, -math.pi / 2 } }
local blend, quads

local function loadBlend()
    if blend == nil then
        local ok, img = pcall(love.graphics.newImage, 'assets/images/tiles/sand_blend.png')
        blend = ok and img or false
        if blend then
            blend:setFilter('nearest', 'nearest')
            local w, h = blend:getDimensions()
            quads = {}
            for i = 1, math.floor(w / h) do quads[i] = love.graphics.newQuad((i - 1) * h, 0, h, h, w, h) end   -- (cuadros cuadrados)
        end
    end
    return blend
end

return {
    id = 35, name = 'sand', label = 'Arena', category = 'Terreno',
    collision = 'solid', material = 'sand', joinGroup = 'ground',
    editorColor = { 0.86, 0.74, 0.49 },
    texture = TEX,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        TileTypes.drawTexture(TEX, ctx)
        -- Transiciones hacia los bloques vecinos (solo bloques enteros en el nivel)
        local level = ctx.level
        if level and not ctx.quarter and ctx.col and loadBlend() then
            local fh = blend:getHeight()
            local k = s / fh
            love.graphics.setColor(1, 1, 1, 1)
            for _, sd in pairs(SIDES) do
                local n = level:getDef(ctx.col + sd[1], ctx.row + sd[2])
                local f = n and BLEND_OF[n.name]
                if f and quads[f] then
                    love.graphics.draw(blend, quads[f], x + s / 2, y + s / 2, sd[3], k, k, fh / 2, fh / 2)
                end
            end
        end
        love.graphics.setColor(0.95, 0.86, 0.64, 1)
        TileTypes.drawEdges(ctx, TileTypes.edges(t, ctx), 2)
    end,
}
