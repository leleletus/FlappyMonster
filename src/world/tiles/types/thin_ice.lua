-- Hielo fino: losa de MEDIA casilla (arriba de la celda), SÓLIDA por todos los
-- lados (no se atraviesa ni subiendo ni bajando: no es una plataforma).
-- Semitransparente y gotea si debajo no hay nada. 4 estados (un tile cada uno):
--   thin_ice (normal) → thin_ice_1 (dañado) → thin_ice_2 (muy dañado) →
--   thin_ice_3 (a punto de romperse) → se rompe.
-- Avanza un estado cada THIN_ICE_WEAR s con un jugador de pie encima; un
-- ground pound encima avanza 3 de golpe; un cabezazo desde abajo, 1; una
-- explosión lo rompe (ver Level:crackIce). Texturas thin_ice_0..3.png.
local TileTypes = require 'src/world/tiles/TileTypes'

local ALPHA = 0.8
local NAMES = { 'thin_ice', 'thin_ice_1', 'thin_ice_2', 'thin_ice_3' }
local LABELS = { 'Hielo fino', 'Hielo fino (dañado)', 'Hielo fino (muy dañado)', 'Hielo fino (a punto de romperse)' }

local defs = {}
for i = 1, 4 do
    local tex = { image = ('assets/images/world/tiles/thin_ice_%d.png'):format(i - 1) }
    defs[i] = {
        id = 30 + i, name = NAMES[i], label = LABELS[i], category = 'Plataformas',
        collision = 'solid', material = 'ice', iceDrip = true,
        hitbox = { x = 0, y = 0, w = 1, h = 0.5 },          -- media casilla (arriba)
        thinIce = { stage = i - 1, next = NAMES[i + 1] },  -- (next nil = se rompe)
        editorHide = i > 1 or nil,
        editorColor = { 0.72, 0.84, 1 },
        texture = tex,
        draw = function(t, ctx) TileTypes.drawTexture(tex, ctx, ALPHA) end,
    }
end
return defs
