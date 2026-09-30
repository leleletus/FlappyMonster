-- Decoraciones de CUEVA (sprites: assets/images/decorations/cave/, generados por
-- tools/ui/make_decorations.py). No chocan ni hacen daño.
--   celda:    Estalactita (cuelga y gotea), Estalagmita, Cristales brillantes
--             (brillan y sueltan destellos), Telaraña (en la esquina de arriba de
--             su casilla; Espejar = la otra esquina; con araña que sube y baja)
--   subcelda: Estalagmita pequeña, Seta luminosa (brilla y suelta esporas),
--             Antorcha (llama animada, luz y brasas), Huesos
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/decorations/cave/'
local CAT = 'Cueva'
local S = DecoFx.SCALE
local WATER = { 0.7, 0.8, 0.95 }
local PURPLE = { 0.75, 0.5, 1 }
local CYAN = { 0.35, 0.95, 1 }
local FIRE = { 1, 0.62, 0.25 }

local function fx(name, fw) return DecoFx.strip(DecoFx.FX .. name, fw) end

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, file, fw, extra)
    local def = base { name = name, label = label, placement = placement,
        editor = { previewScale = placement == 'sub' and 1.5 or 0.8 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. file, fw), 1) end }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

-- Brasa que sube de una llama
local function ember(d, x, y)
    DecoFx.emit(d, { x = x + (math.random() - 0.5) * 8, y = y, vx = (math.random() - 0.5) * 18, vy = -50 - math.random() * 40,
                     drag = 0.6, life = 0.7 + math.random() * 0.6, sheet = fx('ember-Sheet.png', 2), frame = math.random(2),
                     scale = 3, fade = 0.4, wob = 4, add = true })
end

-- Llama con luz: tira de cuadros, halo que parpadea y brasas
local function flameDraw(d, sx, sy, s, fps, lightY, lightR)
    local flick = 0.2 + 0.05 * math.sin(d.animT * 13) + 0.03 * math.sin(d.animT * 31 + d.phase * 9)
    DecoFx.glow(sx, sy + lightY, lightR, FIRE, flick)
    DecoFx.sheet(d, sx, sy, s, s and s:frameAt(d.animT + d.phase, fps) or 1)
end

return {
    base {
        name = 'stalactite', label = 'Estalactita', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            -- (punta del cono grande: x 6.5 de 16, 15 de largo)
            if DecoFx.every(d, 'drip', dt, 1.8, 4.5) then DecoFx.drip(d, -6 * d.flip, -TILE_PX + 15 * S - 2, WATER) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'stalactite.png', 16), 1, { hang = true })
            DecoFx.draw(d, sx, sy)
        end,
    },
    static('stalagmite', 'Estalagmita', 'cell', 'stalagmite.png', 16, { layer = 'back' }),
    static('stalagmite_small', 'Estalagmita pequeña', 'sub', 'stalagmite_small.png', 8),
    base {
        name = 'cave_crystals', label = 'Cristales brillantes', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'spark', dt, 0.4, 1.2) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 44, y = -10 - math.random() * 36, vy = -14, life = 0.9,
                                 sheet = fx('sparkle-Sheet.png', 5), frames = true, fps = 4, scale = 2, fade = 0.3,
                                 color = { 0.9, 0.8, 1 }, add = true })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.glow(sx, sy - 24, 48, PURPLE, 0.16 + 0.06 * math.sin(d.animT * 1.6))
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'crystals.png', 16), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'glow_mushroom', label = 'Seta luminosa', placement = 'sub',
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'spore', dt, 0.6, 1.6) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 20, y = -22, vy = -18 - math.random() * 10, life = 2.2,
                                 sheet = fx('spore-Sheet.png', 3), frame = math.random(2), scale = 3, fade = 0.8,
                                 fadeIn = 0.3, wob = 6, add = true })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.glow(sx, sy - 16, 28, CYAN, 0.18 + 0.07 * math.sin(d.animT * 1.9))
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'glow_mushroom.png', 8), 1)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'torch', label = 'Antorcha', placement = 'sub',
        editor = { previewScale = 1.2 },
        update = function(d, dt)
            if DecoFx.every(d, 'ember', dt, 0.25, 0.7) then ember(d, 0, -40) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            -- (tira de 8x12: palo abajo, llama en las 6 filas de arriba)
            flameDraw(d, sx, sy, DecoFx.strip(DIR .. 'torch-Sheet.png', 8), 9, -34, 46)
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'cobweb', label = 'Telaraña', placement = 'cell',
        description = 'Se pega a la esquina de arriba de su casilla (Espejar = la otra esquina).',
        editor = { previewScale = 0.8 },
        props = { { key = 'spider', kind = 'bool', label = 'Araña', group = 'Aspecto', default = true } },
        draw = function(d, sx, sy)
            local sp = DecoFx.strip(DIR .. 'spider-Sheet.png', 7)
            DecoFx.sheet(d, sx, sy, DecoFx.strip(DIR .. 'cobweb.png', 16), 1, { hang = true })
            if d.props.spider ~= false and sp then
                -- Cuelga de un hilo que sale de la tela; sube y baja despacio
                local x = math.floor(sx - 10 * d.flip)
                local top = sy - TILE_PX + 16
                local len = 14 + 20 * (0.5 + 0.5 * math.sin(d.animT * 0.8))
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.draw(sp.image, sp.quads[3], x, top, 0, 2, len / 5, 3.5, 0)   -- (hilo: 2 px)
                love.graphics.setColor(1, 1, 1, 1)
                sp:draw((math.floor(d.animT * 3) % 7 == 0) and 2 or 1, x, math.floor(top + len + 6), 0, 3)
            end
        end,
    },
    static('bones', 'Huesos', 'sub', 'bones.png', 8),
}
