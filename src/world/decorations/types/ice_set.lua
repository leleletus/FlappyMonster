-- Decoraciones de HIELO Y NIEVE (sprites: assets/images/decorations/ice/,
-- generados por tools/ui/make_decorations.py). No chocan ni hacen daño.
--   subcelda: Carámbanos pequeños (cuelgan y gotean), Montón de nieve (brillos),
--             Cristal de hielo (brilla)
--   celda:    Arbusto helado, Pino nevado (2 casillas de alto; se mecen y les cae
--             nieve), Muñeco de nieve (parpadea, la bufanda ondea)
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/decorations/ice/'
local CAT = 'Hielo y nieve'
local S = DecoFx.SCALE
local ICE = { 0.75, 0.88, 1 }

local function sparkle() return DecoFx.strip(DecoFx.FX .. 'sparkle-Sheet.png', 5) end
local function clump() return DecoFx.strip(DecoFx.FX .. 'clump-Sheet.png', 3) end

-- Destello en un punto al azar de la mitad de arriba del dibujo (w, h en px de arte)
local function glint(d, w, h, hang)
    local x = (math.random() - 0.5) * w * S
    local y = hang and (-(d.def.placement == 'sub' and TILE_PX / 2 or TILE_PX) + math.random() * h * S * 0.6)
                   or (-h * S + math.random() * h * S * 0.6)
    DecoFx.emit(d, { x = x, y = y, life = 0.45, sheet = sparkle(), frames = true, fps = 7, scale = 2, fade = 0.15, add = true })
end

-- Pegote de nieve que cae de las ramas
local function fallSnow(d, x, y)
    DecoFx.emit(d, { x = x, y = y, vx = (math.random() - 0.5) * 20, g = 500, life = 0.9, sheet = clump(), frame = 1,
                     scale = 3, fade = 0.3 })
    for _ = 1, 3 do
        DecoFx.emit(d, { x = x + (math.random() - 0.5) * 10, y = y, vx = (math.random() - 0.5) * 60, vy = -30 - math.random() * 40,
                         g = 300, drag = 2, life = 0.6, sheet = clump(), frame = 2, scale = 2, fade = 0.3 })
    end
end

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

return {
    base {
        name = 'icicle_small', label = 'Carámbanos pequeños', placement = 'sub',
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'drip', dt, 2.5, 6) then
                -- (puntas del arte: x 1.5 / 4.5 / 7 de 8, largos 7 / 5 / 3)
                local tips = { { -10, 7 }, { 2, 5 }, { 12, 3 } }
                local tip = tips[math.random(#tips)]
                DecoFx.drip(d, tip[1] * d.flip, -TILE_PX / 2 + tip[2] * S - 2, ICE)
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'icicle_small.png', 8), 1, { hang = true, alpha = 0.92 })
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'snow_pile', label = 'Montón de nieve', placement = 'sub',
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'glint', dt, 1.5, 4) then glint(d, 6, 4) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'snow_pile.png', 8), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'ice_crystal', label = 'Cristal de hielo', placement = 'sub',
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'glint', dt, 0.8, 2.2) then glint(d, 6, 7) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            local pulse = 0.14 + 0.06 * math.sin(d.animT * 2.2)
            DecoFx.glow(sx, sy - 14, 24, ICE, pulse)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'ice_crystal.png', 8), 1, { alpha = 0.9 })
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'frozen_bush', label = 'Arbusto helado', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'snow', dt, 4, 9) then fallSnow(d, (math.random() - 0.5) * 40, -40) end
            if DecoFx.every(d, 'glint', dt, 2, 5) then glint(d, 14, 10) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'frozen_bush.png', 16), 1, 0.6, 1.1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'snowy_pine', label = 'Pino nevado', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.42 },
        update = function(d, dt)
            if DecoFx.every(d, 'snow', dt, 3, 7) then
                -- (borde de uno de los 3 pisos)
                local tier = math.random(3)
                local y = ({ -84, -52, -20 })[tier]
                fallSnow(d, (math.random() < 0.5 and -1 or 1) * ({ 12, 20, 28 })[tier], y)
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, DecoFx.strip(DIR .. 'snowy_pine.png', 16), 1, 1.2, 0.9)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'snowman', label = 'Muñeco de nieve', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            -- Parpadea 0.15 s cada ~4 s; la bufanda cambia cada 0.5 s
            local t = d.animT
            local frame = (t % 4.1 < 0.15) and 2 or ((math.floor(t / 0.5) % 2 == 0) and 1 or 3)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'snowman-Sheet.png', 16), frame)
            DecoFx.draw(d, sx, sy)
        end,
    },
}
