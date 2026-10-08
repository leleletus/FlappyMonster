local DecoFx = require 'src/world/decorations/DecoFx'
-- Tulipán: planta pequeña (subcelda) que "respira" suavemente.
local SCALE         = 3
local BREATHE_SPEED = 1.8
local BREATHE_AMP   = 0.05

local img

return {
    name = 'tulip', label = 'Tulipán', placement = 'sub', category = 'Plantas',
    editor = { icon = 'assets/images/world/decorations/foliage/tulip.png' },
    loadAssets = function()
        if img == nil then img = DecoFx.anim('world/decorations/foliage', 'tulip') end
    end,
    draw = function(d, sx, sy)
        if not img then return end
        local breathe = math.sin(d.animT * BREATHE_SPEED * math.pi)
        local scY = SCALE * (1.0 + breathe * BREATHE_AMP)
        local scX = SCALE * (1.0 - breathe * BREATHE_AMP * 0.3)
        love.graphics.setColor(1, 1, 1, 1)
        img:play(d.animT, sx, sy, 0, scX * d.flip, scY, 0.5, 1)
    end,
}
