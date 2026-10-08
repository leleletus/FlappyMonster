-- Decoraciones ACUÁTICAS (sprites: assets/images/world/decorations/water/, generados
-- por tools/art/world/make_decorations.py). No chocan ni hacen daño. Las burbujas que
-- sueltan solo suben dentro del agua (fuera, revientan al salir).
--   celda:    Alga (2 casillas de alto, ondea), Coral, Abanico de coral (ondea)
--   subcelda: Alga pequeña, Anémona (tentáculos animados), Estrella de mar,
--             Concha, Almeja (se abre de vez en cuando y suelta burbujas)
local DecoFx = require 'src/world/decorations/DecoFx'

local DIR = 'assets/images/world/decorations/water/'
-- (sus animaciones, por nombre: assets/anim/world/decorations/water.json)
local function A(n) return DecoFx.anim('world/decorations/water', n) end
local CAT = 'Acuático'

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

-- Burbuja que sube bamboleándose y revienta (al final, o al salir del agua)
local function bubble(d, x, y)
    local s = DecoFx.fx('bubble')
    DecoFx.emit(d, { x = x, y = y, vy = -40 - math.random() * 25, life = 1.4 + math.random() * 0.8, sheet = s,
                     scale = 3, wob = 5, fadeIn = 0.15,
        onUpdate = function(p, dt, dd)
            if p.sheet == s then
                local lv = dd.level
                local out = lv and lv.liquidAt and not lv:liquidAt(dd.x + p.x, dd.y + p.y)
                if out or p.t > p.life - 0.12 then p.sheet, p.vy, p.life = DecoFx.fx('bubble_pop') or s, 0, p.t + 0.12 end
            end
        end })
end

local function waving(name, label, placement, file, fw, amp, speed, extra)
    local def = base { name = name, label = label, placement = placement,
        editor = { previewScale = placement == 'sub' and 1.5 or ((extra and extra.tall) and 0.42 or 0.8) },
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A(file), nil, amp, speed)
            DecoFx.draw(d, sx, sy)
        end }
    for k, v in pairs(extra or {}) do def[k] = v end
    def.tall = nil
    return def
end

local function static(name, label, file)
    return base { name = name, label = label, placement = 'sub', editor = { previewScale = 1.5 },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(file)) end }
end

return {
    waving('seaweed', 'Alga', 'cell', 'seaweed.png', 16, 2.2, 1.4, { layer = 'back', tall = true }),
    waving('seaweed_small', 'Alga pequeña', 'sub', 'seaweed_small.png', 8, 0.8, 1.8),
    base {
        name = 'coral', label = 'Coral', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        update = function(d, dt)
            if DecoFx.every(d, 'bubble', dt, 2.5, 6) then bubble(d, (math.random() - 0.5) * 40, -40 - math.random() * 16) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('coral'), nil, 0.35, 1.2)
            DecoFx.draw(d, sx, sy)
        end,
    },
    waving('coral_fan', 'Abanico de coral', 'cell', 'coral_fan.png', 16, 0.8, 1.0, { layer = 'back' }),
    base {
        name = 'anemone', label = 'Anémona', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy)
            local s = A('anemone')                    -- (ida y vuelta: lo dice su animación)
            DecoFx.sheet(d, sx, sy, s, s and s:at(d.animT + d.phase * 4 / 3.5))
        end,
    },
    static('starfish', 'Estrella de mar', 'starfish.png'),
    static('shell', 'Concha', 'shell.png'),
    base {
        name = 'clam', label = 'Almeja', placement = 'sub',
        editor = { previewScale = 1.5 },
        -- Ciclo de 6 s: cerrada 4.2 → entreabierta 0.2 → abierta 1.4 (burbujas) → entreabierta 0.2
        update = function(d, dt)
            local c = (d.animT + d.phase * 6) % 6
            local open = c >= 4.4 and c < 5.8
            if open and not d._open and DecoFx.visible(d) then
                for i = 1, 3 + math.random(0, 2) do bubble(d, (math.random() - 0.5) * 10, -14 - i * 6) end
            end
            d._open = open
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            local s = A('clam')                       -- (cerrada, entreabierta, abierta: su animación)
            DecoFx.sheet(d, sx, sy, s, s and s:at(d.animT + d.phase * 6))
            DecoFx.draw(d, sx, sy)
        end,
    },
}
