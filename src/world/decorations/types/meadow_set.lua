-- Decoraciones de PRADERA (sprites: assets/images/world/decorations/meadow/, generados por tools/art/world/make_biome_art.py).
-- No chocan ni hacen daño.
--   grandes:  Roble, Pino (se mecen un poco; del roble cae alguna hoja)
--   celda:    Arbusto redondo, Tronco caído
--   subcelda: Margaritas, Hierba alta (se mece), Seta roja, Roca con musgo, Girasol (se balancea)
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/world/decorations/meadow/'
-- (sus animaciones, por nombre: assets/anim/world/decorations/meadow.json)
local function A(n) return DecoFx.anim('world/decorations/meadow', n) end
local CAT = 'Pradera'

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, file, extra)
    local def = base { name = name, label = label, placement = placement,
        editor = { previewScale = placement == 'sub' and 1.5 or 0.8 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(file)) end }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

local function leaves(d, y)
    DecoFx.emit(d, { x = (math.random() - 0.5) * 70, y = y, vx = 20 * (math.random() < 0.5 and -1 or 1),
                     vy = 10, g = 40, drag = 1.2, life = 2.4, wob = 10,
                     sheet = DecoFx.fx('leaf'), scale = 3, fade = 0.6 })
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
            DecoFx.wave(d, sx, sy, A('oak_tree'), nil, 0.35, 0.8)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'pine_tree', label = 'Pino', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.5 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('pine_tree'), nil, 0.4, 0.9) end,
    },
    base {
        name = 'round_bush', label = 'Arbusto redondo', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('round_bush'), nil, 0.4, 1.1) end,
    },
    static('fallen_log', 'Tronco caído', 'cell', 'fallen_log.png', { layer = 'back' }),
    static('flower_patch', 'Margaritas', 'sub', 'flower_patch.png'),
    base {
        name = 'tall_grass', label = 'Hierba alta', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('tall_grass'), nil, 0.8, 1.5) end,
    },
    static('red_mushroom', 'Seta roja', 'sub', 'red_mushroom.png'),
    static('mossy_rock', 'Roca con musgo', 'sub', 'mossy_rock.png'),
    base {
        name = 'sunflower', label = 'Girasol', placement = 'sub',
        editor = { previewScale = 1.2 },
        draw = function(d, sx, sy)
            local rot = math.sin(d.animT * 1.2 + d.phase * 6) * 0.05
            DecoFx.sheet(d, sx, sy, A('sunflower'), nil, { rot = rot })
        end,
    },
}
