-- Decoraciones de la FORTALEZA (sprites: assets/images/world/decorations/fortress/, generados por
-- tools/art/world/make_big_trees.py). No chocan ni hacen daño.
--   grandes:  Árbol viejo (5 casillas; se mece, suelta hojas), Ciprés (6 casillas; se mece)
--   celda:    Estandarte (cuelga del techo y ondea), Hiedra colgante (cuelga y se mece), Columna partida, Maceta con flores
local DecoFx = require 'src/world/decorations/DecoFx'

-- (sus animaciones, por nombre: assets/anim/world/decorations/fortress.json)
local function A(n) return DecoFx.anim('world/decorations/fortress', n) end
local CAT = 'Fortaleza'

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, preview)
    return base { name = name, label = label, placement = 'cell', layer = 'back',
        editor = { previewScale = preview },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(name)) end }
end

local function hanging(name, label, preview, lift, amp, speed)
    return base { name = name, label = label, placement = 'cell', layer = 'back',
        editor = { previewScale = preview, previewLift = lift },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A(name), nil, amp, speed, { hang = true }) end }
end

return {
    base {
        name = 'old_tree', plane = 'bg', label = 'Árbol viejo', placement = 'cell', layer = 'back', cullMargin = 8,
        editor = { previewScale = 0.16 },
        update = function(d, dt)
            -- (copa: de ~340 a ~150 px sobre el suelo)
            if DecoFx.every(d, 'leaf', dt, 3, 7) then DecoFx.leaf(d, (math.random() - 0.5) * 240, -320 + math.random() * 150) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('old_tree'), nil, 0.3, 0.7)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'cypress', plane = 'bg', label = 'Ciprés', placement = 'cell', layer = 'back', cullMargin = 8,
        editor = { previewScale = 0.14 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('cypress'), nil, 0.4, 0.7) end,
    },
    hanging('banner', 'Estandarte', 0.42, 76, 0.8, 1.6),
    hanging('ivy_hang', 'Hiedra colgante', 0.55, 44, 0.5, 0.9),
    static('broken_column', 'Columna partida', 0.34),
    static('urn', 'Maceta con flores', 0.74),
}
