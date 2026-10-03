-- Decoraciones de PRADERA (sprites: assets/images/decorations/meadow/, generados por tools/ui/make_biome_art.py).
-- No chocan ni hacen daño.
--   grandes:  Roble, Pino (se mecen un poco; del roble cae alguna hoja)
--   celda:    Arbusto redondo, Tronco caído
--   subcelda: Margaritas, Hierba alta (se mece), Seta roja, Roca con musgo, Girasol (se balancea)
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/decorations/meadow/'
local CAT = 'Pradera'

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, file, extra)
    local def = base { name = name, label = label, placement = placement,
        editor = { previewScale = placement == 'sub' and 1.5 or 0.8 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. file), 1) end }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

local function leaves(d, y)
    DecoFx.emit(d, { x = (math.random() - 0.5) * 70, y = y, vx = 20 * (math.random() < 0.5 and -1 or 1),
                     vy = 10, g = 40, drag = 1.2, life = 2.4, wob = 10,
                     sheet = DecoFx.strip(DecoFx.FX .. 'leaf-Sheet.png', 2), frames = true, fps = 3, scale = 3, fade = 0.6 })
end

return {
    base {
        name = 'oak_tree', label = 'Roble', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.4 },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 4, 9) then leaves(d, -100) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'oak_tree.png'), 1, 0.35, 0.8)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'pine_tree', label = 'Pino', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.5 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'pine_tree.png'), 1, 0.4, 0.9) end,
    },
    base {
        name = 'round_bush', label = 'Arbusto redondo', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'round_bush.png'), 1, 0.4, 1.1) end,
    },
    static('fallen_log', 'Tronco caído', 'cell', 'fallen_log.png', { layer = 'back' }),
    static('flower_patch', 'Margaritas', 'sub', 'flower_patch.png'),
    base {
        name = 'tall_grass', label = 'Hierba alta', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'tall_grass.png'), 1, 0.8, 1.5) end,
    },
    static('red_mushroom', 'Seta roja', 'sub', 'red_mushroom.png'),
    static('mossy_rock', 'Roca con musgo', 'sub', 'mossy_rock.png'),
    base {
        name = 'sunflower', label = 'Girasol', placement = 'sub',
        editor = { previewScale = 1.2 },
        draw = function(d, sx, sy)
            local rot = math.sin(d.animT * 1.2 + d.phase * 6) * 0.05
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'sunflower.png'), 1, { rot = rot })
        end,
    },
}
