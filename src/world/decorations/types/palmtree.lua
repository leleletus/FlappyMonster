-- Palmera: ocupa una celda; tronco, cocos y hojas se mecen con distinta
-- intensidad.
local SCALE      = 4
local SWAY_SPEED = 1.2
local SWAY_AMP   = 0.06

local parts   -- { {img, swayMult}, ... } de atrás hacia delante

return {
    name = 'palmtree', label = 'Palmera', placement = 'cell',
    editor = { icon = 'assets/images/foliage/Palmtree/palmtree.png', previewScale = 0.36 },
    loadAssets = function()
        if parts then return end
        parts = {}
        for _, p in ipairs({ { 'palmtree.png', 0.3 }, { 'coques.png', 0.8 }, { 'palmleaves.png', 1.0 } }) do
            local ok, im = pcall(love.graphics.newImage, 'assets/images/foliage/Palmtree/' .. p[1])
            if ok then parts[#parts+1] = { img = im, swayMult = p[2] } end
        end
    end,
    draw = function(d, sx, sy)
        local sway = math.sin(d.animT * SWAY_SPEED * math.pi) * SWAY_AMP
        love.graphics.setColor(1, 1, 1, 1)
        for _, part in ipairs(parts) do
            love.graphics.draw(part.img, sx, sy, sway * part.swayMult * d.flip,
                               SCALE * d.flip, SCALE, part.img:getWidth()/2, part.img:getHeight())
        end
    end,
}
