-- Decoraciones de la ISLA VOLCÁNICA (sprites: assets/images/decorations/volcano/, generados por
-- tools/ui/make_biome_art.py). No chocan ni hacen daño.
--   celda:    Árbol calcinado (suelta alguna brasa), Columnas de basalto, Cascada de lava (cuelga del techo,
--             fluye, alumbra y gotea brasas)
--   subcelda: Matorral seco, Piedras de basalto, Montón de ceniza, Respiradero (humo y brasas, alumbra),
--             Obsidiana ardiente (brilla), Aguas termales (corro de piedras que suelta VAPOR: para charcas)
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/decorations/volcano/'
local CAT = 'Volcán'
local FIRE = { 1, 0.5, 0.18 }

local function fx(name, fw) return DecoFx.strip(DecoFx.FX .. name, fw) end

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

local function ember(d, x, y, up)
    DecoFx.emit(d, { x = x + (math.random() - 0.5) * 10, y = y, vx = (math.random() - 0.5) * 20, vy = -(up or 50) - math.random() * 40,
                     drag = 0.6, life = 0.8 + math.random() * 0.7, sheet = fx('ember-Sheet.png', 2), frame = math.random(2),
                     scale = 3, fade = 0.4, wob = 5, add = true })
end
local function puff(d, x, y, col, size)
    DecoFx.emit(d, { x = x + (math.random() - 0.5) * 6, y = y, vx = (math.random() - 0.5) * 10, vy = -26 - math.random() * 16,
                     drag = 0.3, life = 1.8 + math.random() * 0.8, sheet = fx('smoke-Sheet.png', 6), frames = true, fps = 1.4,
                     scale = size or 4, fade = 1.0, fadeIn = 0.3, wob = 8, color = col, alpha = 0.55 })
end

return {
    base {
        name = 'charred_tree', label = 'Árbol calcinado', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.6 },
        update = function(d, dt)
            if DecoFx.every(d, 'ember', dt, 1.5, 4) then ember(d, (math.random() - 0.5) * 30, -70, 20) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'charred_tree.png'), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    static('basalt_rock', 'Columnas de basalto', 'cell', 'basalt_rock.png', { layer = 'back' }),
    static('dead_bush', 'Matorral seco', 'sub', 'dead_bush.png'),
    static('basalt_pebbles', 'Piedras de basalto', 'sub', 'basalt_pebbles.png'),
    static('ash_pile', 'Montón de ceniza', 'sub', 'ash_pile.png'),
    base {
        name = 'lava_vent', label = 'Respiradero', placement = 'sub',
        light = { r = 90, color = FIRE, a = 0.2, dy = -10, pulse = 3 },
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'smoke', dt, 0.35, 0.8) then puff(d, 0, -18, { 0.45, 0.42, 0.44 }) end
            if DecoFx.every(d, 'ember', dt, 0.6, 1.6) then ember(d, 0, -14) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.glow(sx, sy - 12, 22, FIRE, 0.18 + 0.06 * math.sin(d.animT * 3))
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'lava_vent.png'), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'glow_rock', label = 'Obsidiana ardiente', placement = 'sub',
        light = { r = 70, color = FIRE, a = 0.16, dy = -12, pulse = 1.4 },
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy)
            DecoFx.glow(sx, sy - 12, 18, FIRE, 0.14 + 0.06 * math.sin(d.animT * 1.4 + d.phase * 6))
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'glow_rock.png'), 1)
        end,
    },
    base {
        name = 'lava_fall', label = 'Cascada de lava', placement = 'cell',
        description = 'Cuelga del techo de su casilla: lava que cae, alumbra y suelta brasas (solo se ve: no hace daño).',
        light = { r = 140, color = FIRE, a = 0.26, dy = 34, pulse = 2.5 },
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'ember', dt, 0.4, 1.0) then ember(d, 0, TILE_PX - 8 - TILE_PX, 30) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            local s = DecoFx.strip(DIR .. 'lava_fall-Sheet.png', 10)
            DecoFx.glow(sx, sy - TILE_PX / 2, 40, FIRE, 0.22)
            DecoFx.sheet(d, sx, sy, s, s and s:frameAt(d.animT + d.phase, 8) or 1, { hang = true })
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'steam_stones', label = 'Aguas termales (vapor)', placement = 'sub',
        description = 'Corro de piedras que suelta vapor: junto a una charca, la vuelve "aguas termales" (solo se ve).',
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'steam', dt, 0.3, 0.7) then puff(d, (math.random() - 0.5) * 24, -8, { 0.95, 0.95, 1 }, 5) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'steam_stones.png'), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
}
