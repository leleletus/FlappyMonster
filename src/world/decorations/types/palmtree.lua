local DecoFx = require 'src/world/decorations/DecoFx'
-- Palmera: ocupa una celda; tronco, cocos y hojas se mecen con distinta
-- intensidad.
local SCALE      = 4
local SWAY_SPEED = 1.2
local SWAY_AMP   = 0.06

local parts   -- { {img, swayMult}, ... } de atrás hacia delante

return {
    name = 'palmtree', label = 'Palmera', placement = 'cell', category = 'Tropical',
    editor = { icon = 'assets/images/world/decorations/foliage/palmtree/palmtree.png', previewScale = 0.36 },
    loadAssets = function()
        if parts then return end
        parts = {}
        -- (animaciones del conjunto world/decorations/foliage/palmtree, de atrás hacia delante)
        for _, p in ipairs({ { 'palmtree', 0.3 }, { 'coques', 0.8 }, { 'palmleaves', 1.0 } }) do
            local c = DecoFx.anim('world/decorations/foliage/palmtree', p[1])
            if c then parts[#parts+1] = { clip = c, swayMult = p[2] } end
        end
    end,
    draw = function(d, sx, sy)
        local sway = math.sin(d.animT * SWAY_SPEED * math.pi) * SWAY_AMP
        love.graphics.setColor(1, 1, 1, 1)
        for _, part in ipairs(parts) do
            part.clip:play(d.animT, sx, sy, sway * part.swayMult * d.flip, SCALE * d.flip, SCALE, 0.5, 1)
        end
    end,
}
