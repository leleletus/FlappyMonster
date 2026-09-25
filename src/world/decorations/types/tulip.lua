-- Tulipán: planta pequeña (subcelda) que "respira" suavemente.
local SCALE         = 3
local BREATHE_SPEED = 1.8
local BREATHE_AMP   = 0.05

local img

return {
    name = 'tulip', label = 'Tulipan', placement = 'sub',
    editor = { icon = 'assets/images/foliage/tulip.png' },
    loadAssets = function()
        if img == nil then
            local ok, i = pcall(love.graphics.newImage, 'assets/images/foliage/tulip.png')
            img = ok and i or false
        end
    end,
    draw = function(d, sx, sy)
        if not img then return end
        local breathe = math.sin(d.animT * BREATHE_SPEED * math.pi)
        local scY = SCALE * (1.0 + breathe * BREATHE_AMP)
        local scX = SCALE * (1.0 - breathe * BREATHE_AMP * 0.3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, sx, sy, 0, scX * d.flip, scY, img:getWidth()/2, img:getHeight())
    end,
}
