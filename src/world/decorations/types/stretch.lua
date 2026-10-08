local DecoFx = require 'src/world/decorations/DecoFx'
-- Estiradora: planta pequeña (subcelda) animada en ping-pong de 5 cuadros
-- (1→5→1) con un estiramiento continuo.
local SCALE  = 4
local FPS    = 3
local FRAMES = 5
local CYCLE  = (FRAMES - 1) * 2 / FPS     -- ida 1→5 + vuelta 5→1

local clip
local function anim() return DecoFx.anim('world/decorations/foliage/stretch', 'stretch') end

return {
    name = 'stretch', label = 'Estiradora', placement = 'sub', category = 'Plantas',
    editor = { icon = 'assets/images/world/decorations/foliage/stretch/stretch1.png' },
    loadAssets = function() clip = anim() end,
    -- (el ciclo dura lo que dure su animación `stretch`: ida 1→5 y vuelta, cuadro a cuadro, la define el conjunto)
    init = function(d) d.cycleT = d.phase * ((anim() or {}).seq and anim():length() or CYCLE) end,
    update = function(d, dt)
        local cycle = clip and clip:length() or CYCLE
        d.cycleT = d.cycleT + dt
        if d.cycleT >= cycle then d.cycleT = d.cycleT - cycle end
    end,
    draw = function(d, sx, sy)
        if not clip then return end
        -- Progreso ping-pong: 0→1 (ida) → 1→0 (vuelta)
        local half = clip:length() / 2
        local progress = (d.cycleT < half) and (d.cycleT / half) or (1 - (d.cycleT - half) / half)
        -- Achatado al principio (-5%), estirado en lo más alto (+8%)
        local amount = -0.05 + progress * 0.13
        local scY = SCALE * (1.0 + amount)
        local scX = SCALE * (1.0 - amount * 0.25)
        love.graphics.setColor(1, 1, 1, 1)
        clip:play(d.cycleT, sx, sy, 0, scX * d.flip, scY, 0.5, 1)
    end,
}
