-- Decoraciones TROPICALES (sprites: assets/images/world/decorations/tropical/,
-- generados por tools/art/world/make_decorations.py). No chocan ni hacen daño.
-- (La Palmera, palmtree.lua, también es de esta categoría.)
--   celda:    Helecho, Arbusto tropical (se mecen; al arbusto se le cae alguna
--             hoja), Antorcha tiki (llama, luz y brasas), Mariposas (revolotean
--             por su casilla; cuántas: 1-3)
--   subcelda: Hibisco (se balancea), Piña
--   de tools/art/world/make_big_trees.py: Cocotero y Palmeras gemelas (7 casillas), Palmera joven: tres capas
--             del mismo tamaño (tronco, cocos, hojas; conjunto world/decorations/tropical/<nombre>) que se mecen
--             juntas, las hojas algo más; Hierba de playa (se mece), Madera de deriva, Rocas de playa
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/world/decorations/tropical/'
-- (sus animaciones, por nombre: assets/anim/world/decorations/tropical.json)
local function A(n) return DecoFx.anim('world/decorations/tropical', n) end
local CAT = 'Tropical'
local FIRE = { 1, 0.62, 0.25 }

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

-- PALMERA GRANDE en tres capas del mismo tamaño (tronco, cocos, hojas), mecidas por filas con el mismo ritmo para
-- que sigan pegadas; las hojas, algo más. baseDx = px de arte que el pie está a la izquierda del centro del dibujo
-- (las que se inclinan): se corre para que el pie quede en el centro de su casilla
local PALM_LAYERS = { 'trunk', 'coconuts', 'fronds' }
local function palm(name, label, preview, cull, amp, baseDx, layers)
    local function L(n) return DecoFx.anim('world/decorations/tropical/' .. name, n) end
    return base { name = name, label = label, placement = 'cell', layer = 'back', cullMargin = cull,
        editor = { previewScale = preview },
        draw = function(d, sx, sy)
            local x = sx + baseDx * DecoFx.SCALE * d.flip
            for _, ln in ipairs(layers or PALM_LAYERS) do
                DecoFx.wave(d, x, sy, L(ln), nil, ln == 'fronds' and amp * 1.3 or amp, 0.7)
            end
        end,
    }
end

return {
    palm('coconut_palm', 'Cocotero', 0.12, 9, 1.2, 8),
    palm('twin_palm', 'Palmeras gemelas', 0.12, 9, 1.2, 2),
    palm('young_palm', 'Palmera joven', 0.31, 4, 0.9, 0, { 'trunk', 'fronds' }),      -- (sin cocos)
    base {
        name = 'beach_grass', label = 'Hierba de playa', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.75 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('beach_grass'), nil, 0.8, 1.5) end,
    },
    base {
        name = 'driftwood', label = 'Madera de deriva', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.47 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A('driftwood')) end,
    },
    base {
        name = 'beach_rocks', label = 'Rocas de playa', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.62 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A('beach_rocks')) end,
    },
    base {
        name = 'hibiscus', label = 'Hibisco', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy)
            local rot = math.sin(d.animT * 1.6 + d.phase * 6) * 0.08
            DecoFx.sheet(d, sx, sy, A('hibiscus'), nil, { rot = rot })
        end,
    },
    base {
        name = 'pineapple', label = 'Piña', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A('pineapple')) end,
    },
    base {
        name = 'fern', label = 'Helecho', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('fern'), nil, 0.9, 1.3) end,
    },
    base {
        name = 'tropical_bush', label = 'Arbusto tropical', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 5, 11) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 40, y = -44, vx = 20 * (math.random() < 0.5 and -1 or 1),
                                 vy = 10, g = 40, drag = 1.2, life = 2.2, wob = 10,
                                 sheet = DecoFx.fx('leaf'),
                                 scale = 3, fade = 0.6 })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('bush'), nil, 0.6, 1.2)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'tiki_torch', label = 'Antorcha tiki', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.55 },
        update = function(d, dt)
            if DecoFx.every(d, 'ember', dt, 0.2, 0.6) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 12, y = -104, vx = (math.random() - 0.5) * 20,
                                 vy = -55 - math.random() * 40, drag = 0.6, life = 0.8 + math.random() * 0.6,
                                 sheet = DecoFx.fx('ember'), variant = true,
                                 scale = 3, fade = 0.4, wob = 4, add = true })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            local flick = 0.2 + 0.05 * math.sin(d.animT * 12) + 0.03 * math.sin(d.animT * 29 + d.phase * 9)
            -- (tira de 8x28: llama en las 8 filas de arriba, cuenco en la 7-9)
            DecoFx.glow(sx, sy - 96, 50, FIRE, flick)
            local s = A('tiki_torch')
            DecoFx.sheet(d, sx, sy, s)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'butterflies', label = 'Mariposas', placement = 'cell',
        editor = { previewScale = 0.8 },
        props = { { key = 'count', kind = 'int', label = 'Cuántas', group = 'Aspecto', default = 2, min = 1, max = 3 } },
        draw = function(d, sx, sy)
            -- (un color = una animación butterfly_<n>: tantas como haya en el conjunto)
            local kinds = {}
            while A('butterfly_' .. (#kinds + 1)) do kinds[#kinds + 1] = A('butterfly_' .. (#kinds + 1)) end
            if #kinds == 0 then return end
            love.graphics.setColor(1, 1, 1, 1)
            for i = 1, d.props.count or 2 do
                -- Trayectoria de Lissajous alrededor del centro de la casilla
                local t = d.animT * (0.9 + i * 0.17) + i * 2.1 + d.phase * 6
                local x = math.sin(t * 1.3) * 26 + math.sin(t * 3.1) * 5
                local y = -TILE_PX / 2 + math.sin(t * 1.9 + i) * 18 + math.sin(t * 5.3) * 3
                local s = kinds[(i + math.floor(d.phase * 3)) % #kinds + 1]
                local dir = math.cos(t * 1.3) >= 0 and 1 or -1
                s:play(d.animT + i * 0.3, math.floor(sx + x), math.floor(sy + y), 0, 3 * dir, 3)
            end
        end,
    },
}
