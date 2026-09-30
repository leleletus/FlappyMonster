-- Decoraciones TROPICALES (sprites: assets/images/decorations/tropical/,
-- generados por tools/ui/make_decorations.py). No chocan ni hacen daño.
-- (La Palmera, palmtree.lua, también es de esta categoría.)
--   celda:    Helecho, Arbusto tropical (se mecen; al arbusto se le cae alguna
--             hoja), Antorcha tiki (llama, luz y brasas), Mariposas (revolotean
--             por su casilla; cuántas: 1-3)
--   subcelda: Hibisco (se balancea), Piña
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/decorations/tropical/'
local CAT = 'Tropical'
local FIRE = { 1, 0.62, 0.25 }

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

return {
    base {
        name = 'hibiscus', label = 'Hibisco', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy)
            local rot = math.sin(d.animT * 1.6 + d.phase * 6) * 0.08
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'hibiscus.png'), 1, { rot = rot })
        end,
    },
    base {
        name = 'pineapple', label = 'Piña', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'pineapple.png'), 1) end,
    },
    base {
        name = 'fern', label = 'Helecho', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'fern.png'), 1, 0.9, 1.3) end,
    },
    base {
        name = 'tropical_bush', label = 'Arbusto tropical', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 5, 11) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 40, y = -44, vx = 20 * (math.random() < 0.5 and -1 or 1),
                                 vy = 10, g = 40, drag = 1.2, life = 2.2, wob = 10,
                                 sheet = DecoFx.strip(DecoFx.FX .. 'leaf-Sheet.png', 2), frames = true, fps = 3,
                                 scale = 3, fade = 0.6 })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'bush.png'), 1, 0.6, 1.2)
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
                                 sheet = DecoFx.strip(DecoFx.FX .. 'ember-Sheet.png', 2), frame = math.random(2),
                                 scale = 3, fade = 0.4, wob = 4, add = true })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            local flick = 0.2 + 0.05 * math.sin(d.animT * 12) + 0.03 * math.sin(d.animT * 29 + d.phase * 9)
            -- (tira de 8x28: llama en las 8 filas de arriba, cuenco en la 7-9)
            DecoFx.glow(sx, sy - 96, 50, FIRE, flick)
            local s = DecoFx.strip(DIR .. 'tiki_torch-Sheet.png', 10)
            DecoFx.sheet(d, sx, sy, s, s and s:frameAt(d.animT + d.phase, 9) or 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'butterflies', label = 'Mariposas', placement = 'cell',
        editor = { previewScale = 0.8 },
        props = { { key = 'count', kind = 'int', label = 'Cuántas', group = 'Aspecto', default = 2, min = 1, max = 3 } },
        draw = function(d, sx, sy)
            local s = DecoFx.strip(DIR .. 'butterfly-Sheet.png', 5)
            if not s then return end
            love.graphics.setColor(1, 1, 1, 1)
            for i = 1, d.props.count or 2 do
                -- Trayectoria de Lissajous alrededor del centro de la casilla
                local t = d.animT * (0.9 + i * 0.17) + i * 2.1 + d.phase * 6
                local x = math.sin(t * 1.3) * 26 + math.sin(t * 3.1) * 5
                local y = -TILE_PX / 2 + math.sin(t * 1.9 + i) * 18 + math.sin(t * 5.3) * 3
                local color = (i + math.floor(d.phase * 3)) % 3
                local flap = (math.floor(d.animT * 10 + i * 3) % 2)
                local dir = math.cos(t * 1.3) >= 0 and 1 or -1
                love.graphics.draw(s.image, s.quads[color * 2 + flap + 1], math.floor(sx + x), math.floor(sy + y),
                                   0, 3 * dir, 3, 2.5, 2)
            end
        end,
    },
}
