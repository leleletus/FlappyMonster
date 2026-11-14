-- Decoraciones de la VÍA ESTELAR (el nivel de los Bloques Beep: docs/design/via-estelar-level.md). Sprites:
-- assets/images/world/decorations/starway/, de tools/art/world/make_starway_decor.py. No chocan ni hacen daño.
--   celda:    Racimo de cristales, Farolillo estelar (titila, luz dorada), Telescopio, Estrella flotante (sube y baja,
--             brilla), Letrero de constelación, Nubecilla (delante), Banderín estelar (ondea)
--   subcelda: Esquirla de cristal, Flor de luna (brilla un poco)
local DecoFx = require 'src/world/decorations/DecoFx'

local function A(n) return DecoFx.anim('world/decorations/starway', n) end
local CAT = 'Estelar'
local S = DecoFx.SCALE
local GOLD = { 1, 0.86, 0.45 }
local MOON = { 0.75, 0.95, 1 }

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, preview, layer)
    return base { name = name, label = label, placement = placement, layer = layer,
        editor = { previewScale = preview },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(name)) end }
end

return {
    static('crystal_cluster', 'Racimo de cristales', 'cell', 0.7, 'back'),
    static('crystal_shard', 'Esquirla de cristal', 'sub', 1.4),
    base {
        name = 'star_lantern', label = 'Farolillo estelar', placement = 'cell', layer = 'back',
        light = { r = 100, color = GOLD, a = 0.18, dy = -100, pulse = 1.2 },
        editor = { previewScale = 0.55 },
        draw = function(d, sx, sy)
            local s = A('star_lantern')
            if not s then return end
            if DecoFx.stepOf(d, s) == 1 then DecoFx.glow(sx, sy - 25 * S, 20, GOLD, 0.25) end
            DecoFx.sheet(d, sx, sy, s)
        end,
    },
    static('telescope', 'Telescopio', 'cell', 0.6, 'back'),
    base {
        name = 'floating_star', label = 'Estrella flotante', placement = 'cell', layer = 'back',
        light = { r = 60, color = GOLD, a = 0.12, dy = -40, pulse = 2 },
        editor = { previewScale = 1 },
        draw = function(d, sx, sy)
            local t = (d.animT or love.timer.getTime()) + (d.phase or 0) * 6.28
            local dy = math.floor(math.sin(t * 1.6) * 2 + 0.5) * S
            DecoFx.glow(sx, sy - 6 * S + dy, 14, GOLD, 0.18)
            DecoFx.sheet(d, sx, sy - 2 * S + dy, A('floating_star'))
        end,
    },
    static('const_sign', 'Letrero de constelación', 'cell', 0.6, 'back'),
    base {
        name = 'moon_flower', label = 'Flor de luna', placement = 'sub',
        light = { r = 40, color = MOON, a = 0.1, dy = -24, pulse = 1 },
        editor = { previewScale = 1.4 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A('moon_flower')) end,
    },
    static('cloud_puff', 'Nubecilla', 'cell', 0.6, 'front'),
    static('star_banner', 'Banderín estelar', 'cell', 0.6, 'back'),
}
