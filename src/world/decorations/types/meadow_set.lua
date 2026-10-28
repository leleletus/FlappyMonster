-- Decoraciones de PRADERA (sprites: assets/images/world/decorations/meadow/, generados por tools/art/world/make_biome_art.py).
-- No chocan ni hacen daño.
--   grandes:  Roble, Pino (se mecen un poco; del roble cae alguna hoja); Roble grande, Abedul y Abeto (6-7
--             casillas, de tools/art/world/make_big_trees.py: se mecen, de los de hoja caen hojas hasta el suelo)
--   celda:    Avellano, Tocón, Peña, Altramuces (make_big_trees.py)
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
    -- ── Grandes (5-8 casillas: margen de descarte = su alto + 2) ──
    base {
        name = 'big_oak', label = 'Roble grande', placement = 'cell', layer = 'back', cullMargin = 8,
        editor = { previewScale = 0.14 },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 2.5, 6) then DecoFx.leaf(d, (math.random() - 0.5) * 300, -370 + math.random() * 180) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('big_oak'), nil, 0.3, 0.7)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'big_birch', label = 'Abedul', placement = 'cell', layer = 'back', cullMargin = 9,
        editor = { previewScale = 0.13 },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 3, 7) then DecoFx.leaf(d, (math.random() - 0.5) * 170, -400 + math.random() * 200) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('big_birch'), nil, 0.45, 0.8)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'big_fir', label = 'Abeto', placement = 'cell', layer = 'back', cullMargin = 9,
        editor = { previewScale = 0.12 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('big_fir'), nil, 0.35, 0.7) end,
    },
    base {
        name = 'hazel_bush', label = 'Avellano', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.42 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('hazel_bush'), nil, 0.4, 1.1) end,
    },
    static('stump', 'Tocón', 'cell', 'stump.png', { layer = 'back', editor = { previewScale = 0.68 } }),
    static('boulder', 'Peña', 'cell', 'boulder.png', { layer = 'back', editor = { previewScale = 0.54 } }),
    base {
        name = 'lupines', label = 'Altramuces', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.67 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('lupines'), nil, 0.6, 1.4) end,
    },
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
