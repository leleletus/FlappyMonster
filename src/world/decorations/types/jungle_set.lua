-- Decoraciones de la ISLA DE LA SELVA (sprites: assets/images/world/decorations/jungle/, generados por
-- tools/art/world/make_jungle_decor.py; partículas fx/jungle_leaf, firefly, pollen, mist, drip). No chocan ni hacen daño.
--   grandes:  Ceiba gigante (8 casillas) e Higuera estranguladora (6): tronco quieto y copa que se mece (capas
--             <nombre>_trunk / _canopy), sueltan hojas que caen hasta el suelo
--   celda:    Platanera, Helecho arborescente, Heliconia (polen), Oreja de elefante, Helecho gigante (se mecen);
--             Arco en ruinas (gotea), Columna rota, Ídolo de piedra (ojos que laten, luz turquesa), Bloque caído,
--             Brasero de piedra (fuego, luz, brasas, chisporroteo), Tronco con setas (esporas), Raíces,
--             Charco de barro (burbuja, bruma); Musgo colgante (gotea) y Enredadera con flores (cuelgan);
--             Libélula (vuela a tirones por su casilla), Luciérnagas (solo luces que laten)
--   subcelda: Lianas larga / media / corta y Orquídea colgante (cuelgan), Bromelia, Orquídea, Setas de la selva (brillan)
-- (La rana, el tucán y el mono del generador NO están: quizá sean enemigos más adelante.)
local DecoFx = require 'src/world/decorations/DecoFx'

-- (sus animaciones, por nombre: assets/anim/world/decorations/jungle.json)
local function A(n) return DecoFx.anim('world/decorations/jungle', n) end
local CAT = 'Jungla'
local S = DecoFx.SCALE
local FIRE = { 1, 0.55, 0.2 }
local TEAL = { 0.35, 1, 0.9 }
local LIME = { 0.8, 1, 0.35 }
local WATER = { 0.75, 0.9, 0.85 }

local function base(def)
    def.category = CAT
    def.update = def.update or function(d, dt) DecoFx.update(d, dt) end
    return def
end

local function static(name, label, placement, preview, extra)
    local def = base { name = name, label = label, placement = placement,
        editor = { previewScale = preview },
        draw = function(d, sx, sy) DecoFx.sheet(d, sx, sy, A(name)) end }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

-- Planta que se mece (raíz quieta)
local function sway(name, label, preview, amp, speed, extra)
    return static(name, label, 'cell', preview, (function()
        local e = { layer = 'back', draw = function(d, sx, sy) DecoFx.wave(d, sx, sy, A(name), nil, amp, speed) end }
        for k, v in pairs(extra or {}) do e[k] = v end
        return e
    end)())
end

-- Lo que cuelga del techo de su casilla / subcelda y se mece (la punta, abajo)
local function hanging(name, label, placement, preview, lift, amp, speed, extra)
    local def = base { name = name, label = label, placement = placement, layer = 'back',
        editor = { previewScale = preview, previewLift = lift },
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A(name), nil, amp, speed, { hang = true })
            DecoFx.draw(d, sx, sy)
        end }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

-- Gota de agua de la selva (se forma, cae y salpica en el suelo)
local function drip(d, x, y)
    DecoFx.drip(d, x, y, WATER, DecoFx.fx('drip'), DecoFx.fx('drip_splash'))
end

-- Árbol GRANDE de dos capas del mismo tamaño: tronco quieto y copa que se mece; suelta hojas de la copa
-- (leafY = alto de la copa en px desde el ancla, leafX = ancho)
local function bigTree(name, label, preview, cull, amp, leafX, leafY0, leafY1)
    return base { name = name, label = label, placement = 'cell', layer = 'back', cullMargin = cull, plane = 'bg',
        editor = { previewScale = preview },
        update = function(d, dt)
            if DecoFx.every(d, 'leaf', dt, 2.5, 6) then
                DecoFx.leaf(d, (math.random() - 0.5) * 2 * leafX, leafY0 + math.random() * (leafY1 - leafY0), DecoFx.fx('jungle_leaf'))
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, A(name .. '_trunk'))
            DecoFx.wave(d, sx, sy, A(name .. '_canopy'), nil, amp, 0.8)
            DecoFx.draw(d, sx, sy)
        end,
    }
end

-- Posición pseudoaleatoria estable (la libélula): un número en [0,1) a partir de k y una semilla
local function hash(k, seed)
    local v = math.sin(k * 127.1 + seed * 311.7) * 43758.5453
    return v - math.floor(v)
end

return {
    -- ── Grandes ──────────────────────────────────────────────────────────────────────────────────
    -- (ceiba: 129 px de arte de alto = 8 casillas, copa en las 70 filas de arriba)
    bigTree('ceiba', 'Ceiba gigante', 0.11, 10, 0.6, 100, -480, -280),
    bigTree('strangler_fig', 'Higuera estranguladora', 0.14, 8, 0.5, 70, -360, -160),
    sway('banana_plant', 'Platanera', 0.34, 0.7, 1.1),
    sway('tree_fern', 'Helecho arborescente', 0.31, 0.8, 1.0),
    sway('elephant_ear', 'Oreja de elefante', 0.42, 0.5, 1.2),
    sway('jungle_fern', 'Helecho gigante', 0.62, 0.9, 1.3),
    sway('heliconia', 'Heliconia', 0.48, 0.6, 1.2, {
        update = function(d, dt)
            if DecoFx.every(d, 'pollen', dt, 1.2, 3) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 24, y = -60 - math.random() * 40, vx = (math.random() - 0.5) * 10,
                                 vy = -8 - math.random() * 8, life = 2.6, sheet = DecoFx.fx('pollen'), variant = true,
                                 scale = 3, fade = 0.8, fadeIn = 0.3, wob = 8, color = { 1, 0.95, 0.6 } })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.wave(d, sx, sy, A('heliconia'), nil, 0.6, 1.2)
            DecoFx.draw(d, sx, sy)
        end,
    }),

    -- ── Ruinas y templo ──────────────────────────────────────────────────────────────────────────
    static('ruined_arch', 'Arco en ruinas', 'cell', 0.33, {
        layer = 'back',
        update = function(d, dt)
            -- (gotea del dintel: su cara de abajo queda a ~31 px de arte del suelo)
            if DecoFx.every(d, 'drip', dt, 2.5, 6) then drip(d, (math.random() - 0.5) * 40, -122) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, A('ruined_arch'))
            DecoFx.draw(d, sx, sy)
        end,
    }),
    static('broken_pillar', 'Columna rota', 'cell', 0.34, { layer = 'back' }),
    base {
        name = 'stone_idol', label = 'Ídolo de piedra', placement = 'cell', layer = 'back',
        light = { r = 110, color = TEAL, a = 0.16, dy = -54, pulse = 1.6 },
        editor = { previewScale = 0.56 },
        draw = function(d, sx, sy)
            local s = A('stone_idol')
            if not s then return end
            local k = s:at(d.animT + d.phase * 3)
            -- (ojos a 13-14 px de arte del suelo, ±4.5 px del centro; brillan en el 2º cuadro)
            if k == 2 then
                DecoFx.glow(sx - 18, sy - 54, 16, TEAL, 0.35)
                DecoFx.glow(sx + 18, sy - 54, 16, TEAL, 0.35)
            end
            DecoFx.sheet(d, sx, sy, s, k)
        end,
    },
    static('fallen_block', 'Bloque caído', 'cell', 0.68, { layer = 'back' }),
    base {
        name = 'stone_brazier', label = 'Brasero de piedra', placement = 'cell', layer = 'back',
        light = { r = 180, color = { 1, 0.7, 0.4 }, a = 0.42, dy = -70, pulse = 9 },
        editor = { previewScale = 0.56 },
        update = function(d, dt)
            if DecoFx.every(d, 'ember', dt, 0.2, 0.55) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 20, y = -80, vx = (math.random() - 0.5) * 20,
                                 vy = -55 - math.random() * 40, drag = 0.6, life = 0.8 + math.random() * 0.6,
                                 sheet = DecoFx.fx('ember'), variant = true, scale = 3, fade = 0.4, wob = 4, add = true })
            end
            if DecoFx.every(d, 'crackle', dt, 2, 4) then DecoFx.sound('fireCrackle', d.x, d.y - 70, 0.2) end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            -- (cuenco a 15 px de arte del suelo; la llama encima)
            local flick = 0.22 + 0.05 * math.sin(d.animT * 12) + 0.03 * math.sin(d.animT * 29 + d.phase * 9)
            DecoFx.glow(sx, sy - 72, 60, FIRE, flick)
            DecoFx.sheet(d, sx, sy, A('stone_brazier'))
            DecoFx.draw(d, sx, sy)
        end,
    },

    -- ── Suelo ────────────────────────────────────────────────────────────────────────────────────
    static('mossy_log', 'Tronco con setas', 'cell', 0.44, {
        layer = 'back',
        update = function(d, dt)
            if DecoFx.every(d, 'spore', dt, 1.5, 4) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 90, y = -40, vy = -12 - math.random() * 8, life = 2.2,
                                 sheet = DecoFx.fx('spore'), variant = true, scale = 3, fade = 0.8, fadeIn = 0.3,
                                 wob = 6, color = { 0.85, 1, 0.6 } })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, A('mossy_log'))
            DecoFx.draw(d, sx, sy)
        end,
    }),
    static('roots', 'Raíces', 'cell', 0.75),
    static('mud_puddle', 'Charco de barro', 'cell', 0.8, {
        update = function(d, dt)
            if DecoFx.every(d, 'mist', dt, 3, 7) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 40, y = -10, vx = 6 + math.random() * 8, vy = -4,
                                 life = 3.5, sheet = DecoFx.fx('mist'), variant = true, scale = 4, alpha = 0.18,
                                 fade = 1.2, fadeIn = 1.0, color = { 0.85, 0.95, 0.85 } })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.sheet(d, sx, sy, A('mud_puddle'))
            DecoFx.draw(d, sx, sy)
        end,
    }),
    static('bromeliad', 'Bromelia', 'sub', 1.5),
    base {
        name = 'orchid', label = 'Orquídea', placement = 'sub',
        editor = { previewScale = 1.5 },
        draw = function(d, sx, sy)
            DecoFx.sheet(d, sx, sy, A('orchid'), nil, { rot = math.sin(d.animT * 1.5 + d.phase * 6) * 0.07 })
        end,
    },
    base {
        name = 'jungle_mushrooms', label = 'Setas de la selva', placement = 'sub',
        light = { r = 70, color = TEAL, a = 0.14, dy = -20, pulse = 1.7 },
        editor = { previewScale = 1.5 },
        update = function(d, dt)
            if DecoFx.every(d, 'spore', dt, 0.8, 2) then
                DecoFx.emit(d, { x = (math.random() - 0.5) * 24, y = -30, vy = -16 - math.random() * 10, life = 2.0,
                                 sheet = DecoFx.fx('spore'), variant = true, scale = 3, fade = 0.8, fadeIn = 0.3,
                                 wob = 6, add = true, color = TEAL })
            end
            DecoFx.update(d, dt)
        end,
        draw = function(d, sx, sy)
            DecoFx.seen(d)
            DecoFx.glow(sx, sy - 22, 24, TEAL, 0.14 + 0.06 * math.sin(d.animT * 1.7 + d.phase * 6))
            DecoFx.sheet(d, sx, sy, A('jungle_mushrooms'))
            DecoFx.draw(d, sx, sy)
        end,
    },

    -- ── Colgantes ────────────────────────────────────────────────────────────────────────────────
    hanging('liana_long', 'Liana (larga)', 'sub', 0.3, 166, 1.2, 0.9),
    hanging('liana_mid', 'Liana (media)', 'sub', 0.45, 100, 1.0, 1.0),
    hanging('liana_short', 'Liana (corta)', 'sub', 0.9, 36, 0.8, 1.1),
    hanging('hanging_moss', 'Musgo colgante', 'cell', 0.7, 20, 0.6, 0.9, {
        update = function(d, dt)
            -- (las hebras acaban ~19 px de arte por debajo del techo de su casilla)
            if DecoFx.every(d, 'drip', dt, 2, 5) then drip(d, (math.random() - 0.5) * 40, -TILE_PX + 18 * S) end
            DecoFx.update(d, dt)
        end,
    }),
    hanging('flower_vine', 'Enredadera con flores', 'cell', 0.4, 84, 1.0, 1.0),
    base {
        name = 'hanging_orchid', label = 'Orquídea colgante', placement = 'sub', layer = 'back',
        editor = { previewScale = 0.8, previewLift = 44 },
        draw = function(d, sx, sy)
            DecoFx.sheet(d, sx, sy, A('hanging_orchid'), nil, { hang = true, rot = math.sin(d.animT * 1.3 + d.phase * 6) * 0.1 })
        end,
    },

    -- ── Bichos y luces ───────────────────────────────────────────────────────────────────────────
    base {
        name = 'dragonfly', label = 'Libélula', placement = 'cell',
        editor = { previewScale = 0.8 },
        props = { { key = 'count', kind = 'int', label = 'Cuántas', group = 'Aspecto', default = 1, min = 1, max = 2 } },
        draw = function(d, sx, sy)
            local s = A('dragonfly')
            if not s then return end
            love.graphics.setColor(1, 1, 1, 1)
            for i = 1, d.props.count or 1 do
                -- Se queda quieta en el aire y sale disparada a otro punto de su casilla (y algo más) cada ~1.8 s
                local T = d.animT / (1.6 + i * 0.3) + i * 0.37 + d.phase * 5
                local seg, u = math.floor(T), T % 1
                local seed = i + d.phase * 10
                local x0, y0 = (hash(seg, seed) - 0.5) * 90, (hash(seg, seed + 7) - 0.5) * 44
                local x1, y1 = (hash(seg + 1, seed) - 0.5) * 90, (hash(seg + 1, seed + 7) - 0.5) * 44
                local m = math.min(1, u / 0.18)
                m = m * m * (3 - 2 * m)
                local x = x0 + (x1 - x0) * m
                local y = -TILE_PX * 0.6 + y0 + (y1 - y0) * m + math.sin(d.animT * 5 + i) * 2
                local dir = (x1 >= x0) and 1 or -1            -- (el dibujo mira a la derecha)
                s:play(d.animT + i * 0.05, math.floor(sx + x), math.floor(sy + y), 0, S * dir, S)
            end
        end,
    },
    base {
        name = 'fireflies', label = 'Luciérnagas', placement = 'cell',
        light = { r = 80, color = LIME, a = 0.1, dy = -56, pulse = 2 },
        editor = { previewScale = 0.8 },
        props = { { key = 'count', kind = 'int', label = 'Cuántas', group = 'Aspecto', default = 5, min = 1, max = 8 } },
        draw = function(d, sx, sy)
            local s = DecoFx.fx('firefly')
            if not s then return end
            local mode, am = love.graphics.getBlendMode()
            for i = 1, d.props.count or 5 do
                -- Vagan despacio por su casilla y las de al lado, y se encienden y apagan cada una a su ritmo
                local t = d.animT * 0.5 + i * 1.9 + d.phase * 6
                local x = math.sin(t * 0.9 + i) * 60 + math.sin(t * 2.3) * 10
                local y = -TILE_PX * 0.9 + math.sin(t * 0.7 + i * 2) * 40 + math.sin(t * 1.9) * 8
                local p = 0.5 + 0.5 * math.sin(d.animT * (1.8 + i * 0.27) + i * 2.4 + d.phase * 6)
                if p > 0.12 then
                    DecoFx.glow(sx + x, sy + y, 10 + 6 * p, LIME, 0.22 * p)
                    love.graphics.setBlendMode('add')
                    love.graphics.setColor(1, 1, 1, p)
                    s:draw(s:atProgress(p), math.floor(sx + x), math.floor(sy + y), 0, 3)
                    love.graphics.setBlendMode(mode, am)
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
        end,
    },
}
