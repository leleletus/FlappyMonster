-- Césped: tierra con una capa de hierba cuando su cara de arriba da al aire
-- (tapado por otro bloque se ve como tierra) y unos tallitos que asoman por
-- encima. Texturas (tools/ui/make_terrain.py): assets/images/tiles/grass.png,
-- dirt.png y grass_blades.png (3 variantes de 16x4, se elige una por celda).
-- Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TOP  = { image = 'assets/images/tiles/grass.png' }
local DIRT = { image = 'assets/images/tiles/dirt.png' }
local blades, quads

local function loadBlades()
    if blades == nil then
        local ok, img = pcall(love.graphics.newImage, 'assets/images/tiles/grass_blades.png')
        blades = ok and img or false
        if blades then
            blades:setFilter('nearest', 'nearest')
            local w, h = blades:getDimensions()
            quads = {}
            for v = 0, 2 do          -- [variante][mitad]
                quads[v + 1] = { love.graphics.newQuad(v * 16, 0, 8, 4, w, h), love.graphics.newQuad(v * 16 + 8, 0, 8, 4, w, h) }
            end
        end
    end
    return blades
end

return {
    id = 17, name = 'grass', label = 'Césped', category = 'Terreno',
    collision = 'solid', material = 'grass', joinGroup = 'ground',
    editorColor = { 0.3, 0.62, 0.24 },
    texture = TOP,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local e = TileTypes.edges(t, ctx)
        TileTypes.drawTexture(e.top and TOP or DIRT, ctx, 1, e.top and 0 or nil)
        love.graphics.setColor(0.62, 0.45, 0.28, 1)
        TileTypes.drawEdges(ctx, { left = e.left, right = e.right, bottom = e.bottom }, 2)
        if e.top and loadBlades() then
            -- Tallitos por encima (solo en la mitad de arriba que da al aire)
            local v = ((ctx.col or 1) * 5 + (ctx.row or 1) * 3) % 3 + 1
            local k = s / 16
            love.graphics.setColor(1, 1, 1, 1)
            for h = 1, 2 do
                if TileTypes.half(e.top, h) then
                    love.graphics.draw(blades, quads[v][h], x + (h - 1) * 8 * k, y - 4 * k, 0, k, k)
                end
            end
        end
    end,
}
