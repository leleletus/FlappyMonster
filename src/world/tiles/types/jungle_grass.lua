-- Césped de la jungla (0.5.83): barro con una capa de musgo y hierba (con raíces y gotas) cuando su cara de arriba da
-- al aire (tapado se ve como barro) y tallitos por encima — como el césped de siempre. Texturas
-- (tools/art/world/make_jungle_sky.py): jungle_grass.png, mud.png y jungle_blades.png (3 variantes, como grass_blades).
-- Se une con 'ground'.
local TileTypes = require 'src/world/tiles/TileTypes'

local TOP  = { image = 'assets/images/world/tiles/jungle_grass.png' }
local BODY = { image = 'assets/images/world/tiles/mud.png' }
local blades, quads

local function loadBlades()
    if blades == nil then
        local ok, img = pcall(require('src/fx/Anim').image, 'assets/images/world/tiles/jungle_blades.png')
        blades = ok and img or false
        if blades then
            blades:setFilter('nearest', 'nearest')
            local w, h = blades:getDimensions()
            quads = {}
            -- (la imagen está a x4 — 3 variantes de 16x4 del arte —: cada mitad, 32x16 de la imagen)
            for v = 0, 2 do          -- [variante][mitad]
                quads[v + 1] = { love.graphics.newQuad(v * 64, 0, 32, 16, w, h), love.graphics.newQuad(v * 64 + 32, 0, 32, 16, w, h) }
            end
        end
    end
    return blades
end

return {
    id = 41, name = 'jungle_grass', label = 'Césped de la jungla', category = 'Terreno',
    collision = 'solid', material = 'grass', joinGroup = 'ground',
    editorColor = { 0.18, 0.48, 0.23 },
    texture = TOP,
    draw = function(t, ctx)
        local x, y, s = ctx.x, ctx.y, ctx.size
        local e = TileTypes.edges(t, ctx)
        TileTypes.drawTexture(e.top and TOP or BODY, ctx, 1, e.top and 0 or nil)
        love.graphics.setColor(0.62, 0.45, 0.28, 1)
        TileTypes.drawEdges(ctx, e, 2, true)
        if e.top then
            -- (junto a la capa de musgo, el borde de los lados es verde)
            local cap = math.floor(s * (ctx.quarter and 6 / 8 or 6 / 16))
            love.graphics.setColor(0.65, 0.85, 0.38, 1)
            if TileTypes.half(e.left, 1) then love.graphics.rectangle('fill', x, y, 2, cap) end
            if TileTypes.half(e.right, 1) then love.graphics.rectangle('fill', x + s - 2, y, 2, cap) end
        end
        if e.top and loadBlades() then
            local v = ((ctx.col or 1) * 5 + (ctx.row or 1) * 3) % 3 + 1
            local k = s / 16
            love.graphics.setColor(1, 1, 1, 1)
            for h = 1, 2 do
                if TileTypes.half(e.top, h) then
                    love.graphics.draw(blades, quads[v][h], x + (h - 1) * 8 * k, y - 4 * k, 0, k / 4, k / 4)
                end
            end
        end
    end,
}
