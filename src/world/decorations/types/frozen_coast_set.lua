-- Decoraciones de la COSTA HELADA (la isla del Mega Crabby de hielo: la orilla de un mar polar, un viejo puerto pesquero
-- helado). Sprites: assets/images/world/decorations/frozen_coast/, generados por tools/art/world/make_frozen_coast_decor.py
-- (opción A, elegida por el usuario el 2026-10-29; el iceberg y el témpano, en facetas planas como el hielo de su fondo).
-- No chocan ni hacen daño.
--   celda:    Iceberg, Ancla, Boya con luz (parpadea, luz ámbar), Nasa, Roca con algas, Bote volcado (gotea),
--             Témpano flotante (se mece arriba y abajo: va en la casilla justo encima del agua), Red colgante (cuelga y se mece)
--   subcelda: Trozos de hielo, Bolardo, Estrella de mar en hielo
local DecoFx = require 'src/world/decorations/DecoFx'

-- (sus animaciones, por nombre: assets/anim/world/decorations/frozen_coast.json)
local function A(n) return DecoFx.anim('world/decorations/frozen_coast', n) end
local CAT = 'Costa helada'
local S = DecoFx.SCALE
local AMBER = { 1, 0.62, 0.2 }
local MELT = { 0.8, 0.9, 1 }

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, preview, layer)
    return base { name = name, label = label, placement = placement, layer = layer,
        editor = { previewScale = preview },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(name)) end }
end

return {
    static('iceberg', 'Iceberg', 'cell', 0.45, 'back'),
    static('ice_chunks', 'Trozos de hielo', 'sub', 1.4),
    static('anchor', 'Ancla', 'cell', 0.6, 'back'),
    base {
        -- (la luz va con el cuadro 1 de su animación: encendida 0,5 s, apagada 0,9 s)
        name = 'buoy', label = 'Boya con luz', placement = 'cell', layer = 'back',
        light = { r = 90, color = AMBER, a = 0.18, dy = -84, pulse = 4.5 },
        editor = { previewScale = 0.6 },
        draw = function(d, sx, sy)
            local s = A('buoy')
            if not s then return end
            if DecoFx.stepOf(d, s) == 1 then DecoFx.glow(sx, sy - 22 * S, 22, AMBER, 0.35) end
            DecoFx.sheet(d, sx, sy, s)
        end,
    },
    static('bollard', 'Bolardo', 'sub', 1.4),
    static('crab_pot', 'Nasa', 'cell', 0.8, 'back'),
    static('kelp_rock', 'Roca con algas', 'cell', 0.7, 'back'),
    base {
        name = 'rowboat', label = 'Bote volcado', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.45 },
        update = function(d, dt)
            -- (los carámbanos de la borda acaban ~1 px de arte por encima del suelo)
            if DecoFx.every(d, 'drip', dt, 2.5, 6) then
                DecoFx.drip(d, (math.random() < 0.5 and -1 or 1) * (20 + math.random() * 30), -2 * S, MELT,
                            DecoFx.fx('drip'), DecoFx.fx('drip_splash'))
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, A('rowboat'))
            DecoFx.draw(d, sx, sy)
        end,
    },
    base {
        name = 'net_hang', label = 'Red colgante', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.6, previewLift = 32 },
        draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A('net_hang'), nil, 0.5, 0.8, { hang = true }) end,
    },
    static('starfish_ice', 'Estrella de mar en hielo', 'sub', 1.4),
    base {
        -- (se mece en el agua: sube y baja 1 px de arte; anclado 2 px de arte bajo la superficie)
        name = 'floe', label = 'Témpano flotante', placement = 'cell', layer = 'back',
        editor = { previewScale = 0.8 },
        draw = function(d, sx, sy)
            local bob = math.floor(math.sin((d.animT or 0) * 1.6 + (d.phase or 0) * 6) + 0.5) * S
            DecoFx.sheet(d, sx, sy + 2 * S + bob, A('floe'))
        end,
    },
}
