-- Carámbano: decoración (no choca ni hace daño) que cuelga del techo de su
-- casilla y gotea de vez en cuando. Sprite: assets/images/world/decorations/ice/icicle.png
-- (tools/ui/make_decorations.py; la imagen original del usuario, icespike.png,
-- se guarda fuera del repo: tools/ui/originals.py).
local DecoFx = require 'src/world/decorations/DecoFx'

local S = DecoFx.SCALE
local ICE = { 0.75, 0.88, 1 }

return {
    name = 'icicle', label = 'Carámbano', placement = 'cell', category = 'Hielo y nieve',
    editor = { previewScale = 0.8 },
    update = function(d, dt)
        -- (punta grande: x 7.5 de 16, 15 de largo)
        if DecoFx.every(d, 'drip', dt, 2, 5) then DecoFx.drip(d, -2 * d.flip, -TILE_PX + 15 * S - 2, ICE) end
        DecoFx.update(d, dt)
    end,
    draw = function(d, sx, sy)
        DecoFx.seen(d)
        DecoFx.sheet(d, sx, sy, DecoFx.strip('assets/images/world/decorations/ice/icicle.png'), 1, { hang = true, alpha = 0.92 })
        DecoFx.draw(d, sx, sy)
    end,
}
