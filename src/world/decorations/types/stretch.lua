-- Estiradora: planta pequeña (subcelda) animada en ping-pong de 5 cuadros
-- (1→5→1) con un estiramiento continuo.
local SCALE  = 4
local FPS    = 3
local FRAMES = 5
local CYCLE  = (FRAMES - 1) * 2 / FPS     -- ida 1→5 + vuelta 5→1

local imgs

return {
    name = 'stretch', label = 'Estiradora', placement = 'sub',
    editor = { icon = 'assets/images/foliage/strech/strech1.png' },
    loadAssets = function()
        if imgs then return end
        imgs = {}
        for i = 1, FRAMES do
            local ok, im = pcall(love.graphics.newImage, 'assets/images/foliage/strech/strech' .. i .. '.png')
            if ok then imgs[i] = im end
        end
    end,
    init = function(d) d.cycleT = d.phase * CYCLE end,
    update = function(d, dt)
        d.cycleT = d.cycleT + dt
        if d.cycleT >= CYCLE then d.cycleT = d.cycleT - CYCLE end
    end,
    draw = function(d, sx, sy)
        if #imgs < FRAMES then return end
        -- Progreso ping-pong: 0→1 (ida) → 1→0 (vuelta)
        local half = CYCLE / 2
        local progress = (d.cycleT < half) and (d.cycleT / half) or (1 - (d.cycleT - half) / half)
        -- Cuadro discreto: 1→2→3→4→5→4→3→2→1
        local idx = math.max(1, math.min(math.floor(progress * (FRAMES - 1) + 0.5) + 1, FRAMES))
        local img = imgs[idx]
        -- Achatado en el cuadro 1 (-5%), estirado en el 5 (+8%)
        local amount = -0.05 + progress * 0.13
        local scY = SCALE * (1.0 + amount)
        local scX = SCALE * (1.0 - amount * 0.25)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, sx, sy, 0, scX * d.flip, scY, img:getWidth()/2, img:getHeight())
    end,
}
