-- src/fx/Darkness.lua
-- LUZ AMBIENTE de los niveles (solo visual), con un mismo lienzo de luz para todos los casos:
--   * A OSCURAS (level.dark): solo se ve lo que alumbran las linternas (esto sí cuenta para el juego: Lights).
--   * level.light (src/world/level/Level.lua lightMood): 'dusk' = tono cálido; 'night' = frío y más oscuro, con las
--     antorchas / lava / setas brillando; 'cave' = PENUMBRA (se juega normal: se ve bastante); 'day' / 'none' = nada.
--     El jugador NO da luz en estos (el usuario: de noche tiene que ser de noche): solo en los niveles a oscuras,
--     donde la linterna es una mecánica. (`halo` en un ánimo lo volvería a encender.)
--   * Con fondo de PROFUNDIDAD (level.depth), lo que queda bajo la línea de superficie va en penumbra de cueva
--     (con una franja de transición), aunque arriba sea de día.
--   Las fuentes de luz: el halo de los jugadores, las decoraciones con `light` en su tipo y los TILES con
--   `light` en su definición (la lava). Valores por ánimo en Darkness.MOODS.
-- Se dibuja DESPUÉS de la escena (y del efecto del agua) y ANTES del HUD:
--   Darkness.render(level, camX, camY, sources)   sources = { {x, y, facing, on}, ... } (jugadores)
-- Las decoraciones con `light` en su tipo (setas luminosas, cristales, antorchas) dan una luz tenue.
-- Cómo: un lienzo pequeño (1/4: la luz queda pixelada, como el resto del juego) que empieza en
-- la luz AMBIENTE (casi negro) y al que cada jugador suma, en escalones, su halo (siempre: se ve
-- a sí mismo y lo que pisa) y, con la linterna encendida, su cono — trazado con rayos que los
-- bloques cortan (Lights.ray: la misma luz que usa la simulación). Luego se MULTIPLICA sobre la
-- pantalla. Sin sombreadores ni stencil (Switch / Android).
-- Lo que debe verse SIEMPRE (los puntos luminosos de los Crabbies lúgubres) se dibuja después:
-- las entidades con `renderGlow(camX, camY)`.
local Lights = require 'src/world/level/Lights'

local Darkness = {}

local DS = 4                          -- px de pantalla por píxel de luz
local AMBIENT = 0.055                 -- lo que se ve sin luz (casi nada)
local HALO, HALO_ON = 78, 118         -- radio del halo del jugador (apagada / encendida)
local RAYS = 26                       -- rayos del cono
-- Escalones del cono: fracción del alcance y luz que suma cada uno (de fuera adentro)
local BANDS = { { 1.0, 0.26 }, { 0.74, 0.3 }, { 0.46, 0.44 } }

local canvas

-- amb = luz ambiente (multiplica la pantalla); halo = radio y fuerza alrededor de cada jugador;
-- lights = × la fuerza de las luces de decoraciones y tiles
Darkness.MOODS = {
    dusk  = { amb = { 1.0, 0.84, 0.68 }, lights = 0.8 },
    night = { amb = { 0.46, 0.52, 0.78 }, lights = 1.6 },
    cave  = { amb = { 0.5, 0.5, 0.6 }, lights = 2.0 },
}
local DEEP = Darkness.MOODS.cave
local RINGS = 5                        -- escalones de las luces suaves (noche, cueva)
local BAND = 2                         -- casillas de transición entre la superficie y la penumbra de abajo

local function moodOf(level)
    if not level then return nil end
    if level.dark then return 'dark' end
    return level.light
end

-- ¿Hay que dibujar luz en este nivel? (día sin profundidad: no)
function Darkness.active(level)
    local m = moodOf(level)
    if m == 'dark' then return true end
    if not level or m == 'none' then return false end
    return Darkness.MOODS[m] ~= nil or level.depth ~= nil
end

-- Tiles que dan luz (su definición: `light = { r = px, color, a }`), una vez por nivel
local TileTypes, TileCodec
local function lightTiles(level)
    if level._lightTiles then return level._lightTiles end
    TileTypes = TileTypes or require 'src/world/tiles/TileTypes'
    TileCodec = TileCodec or require 'src/world/tiles/TileCodec'
    local out = {}
    for r = 1, level.tileH or 0 do
        for c = 1, level.tileW or 0 do
            local def = TileTypes.get(TileCodec.id(level:getRaw(c, r)))
            if def and def.light then out[#out + 1] = { x = (c - 0.5) * TILE_PX, y = (r - 0.5) * TILE_PX, L = def.light } end
        end
    end
    level._lightTiles = out
    return out
end
function Darkness.invalidate(level) if level then level._lightTiles = nil end end

local function fan(ox, oy, dir, k, level, cache)
    local pts = cache
    for i = 0, RAYS do
        local a = dir - Lights.HALF + 2 * Lights.HALF * i / RAYS
        local d = pts[i] or Lights.ray(level, ox, oy, a)
        pts[i] = d
        d = math.min(d, Lights.range(level) * k)
        pts[i + 100] = ox + math.cos(a) * d
        pts[i + 200] = oy + math.sin(a) * d
    end
end

-- entities = las entidades (las que tengan `e:lights()` → { {x, y, r, color, a}, ... } dan luz: el fuego de los
-- morteros...); sin ellas, level.liveEntities
-- Repone, sin oscurecer, los píxeles de la escena marcados con alfa 0 (lo incandescente del fondo que NO quedó tapado
-- por nada: src/fx/Sky.lua). Se dibuja con la transformación y el recorte de ahora: nunca sale de la zona de juego.
local glowShader
local function restoreGlow(scene)
    if glowShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
                vec4 p = Texel(tex, uv);
                if (p.a > 0.5) discard;
                return vec4(p.rgb, 1.0);
            }
        ]])
        glowShader = ok and sh or false
    end
    if not glowShader then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(glowShader)
    love.graphics.draw(scene, 0, 0)
    love.graphics.setShader()
end

-- `scene` = el lienzo de la escena (opcional): con él, lo incandescente del fondo sigue brillando de noche
function Darkness.render(level, camX, camY, sources, entities, scene)
    if not Darkness.active(level) then return end
    local mood = moodOf(level)
    local dark = mood == 'dark'
    local M = Darkness.MOODS[mood]
    local w, h = math.ceil(WINDOW_W / DS), math.ceil(WINDOW_H / DS)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        canvas = love.graphics.newCanvas(w, h)
        canvas:setFilter('nearest', 'nearest')
    end
    -- (dentro del lienzo: sin la transformación ni el recorte de lovesize)
    love.graphics.push()
    love.graphics.origin()
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    -- 1) la luz AMBIENTE: la del ánimo arriba y, con profundidad, la penumbra de cueva bajo la superficie
    local top = dark and { AMBIENT, AMBIENT, AMBIENT * 1.5 } or (M and M.amb) or { 1, 1, 1 }
    love.graphics.clear(top[1], top[2], top[3], 1)
    local deepY
    if not dark and level.depth and mood ~= 'cave' then
        deepY = require('src/fx/Sky').surfaceY(level)
        local y0 = math.floor((deepY - camY) / DS)
        local band = BAND * TILE_PX / DS
        for i = 0, 3 do                                        -- (transición en escalones, pixelada)
            local k = (i + 1) / 5
            love.graphics.setColor(top[1] + (DEEP.amb[1] - top[1]) * k, top[2] + (DEEP.amb[2] - top[2]) * k,
                                   top[3] + (DEEP.amb[3] - top[3]) * k, 1)
            love.graphics.rectangle('fill', 0, y0 + band * i / 4, w, band / 4 + 1)
        end
        love.graphics.setColor(DEEP.amb[1], DEEP.amb[2], DEEP.amb[3], 1)
        love.graphics.rectangle('fill', 0, y0 + band, w, h)
    end
    love.graphics.setBlendMode('add')
    love.graphics.scale(1 / DS, 1 / DS)
    love.graphics.translate(-camX, -camY)
    for _, s in ipairs(sources or {}) do
        local hx, hy = s.x, s.y - 14
        if dark then
            local r = s.on and HALO_ON or HALO
            love.graphics.setColor(0.24, 0.24, 0.27, 1)
            love.graphics.circle('fill', hx, hy, r)
            love.graphics.setColor(0.3, 0.3, 0.33, 1)
            love.graphics.circle('fill', hx, hy, r * 0.6)
        else
            -- (penumbra / noche: un halo amplio y suave, para jugar normal)
            local H = (deepY and hy > deepY) and DEEP or M
            if H and H.halo then
                for i = 0, RINGS - 1 do
                    local q = H.haloA / RINGS
                    love.graphics.setColor(q, q, q * 0.92, 1)
                    love.graphics.circle('fill', hx, hy, H.halo * (1 - i / RINGS * 0.8))
                end
            end
        end
        if dark and s.on then
            local ox, oy, dir = Lights.origin(s.x, s.y, s.facing or 1)
            local cache = {}
            for _, b in ipairs(BANDS) do
                fan(ox, oy, dir, b[1], level, cache)
                love.graphics.setColor(b[2], b[2], b[2] * 0.94, 1)
                for i = 0, RAYS - 1 do
                    love.graphics.polygon('fill', ox, oy, cache[i + 100], cache[i + 200], cache[i + 101], cache[i + 201])
                end
            end
        end
    end
    -- 2) LUCES de decoraciones (su tipo declara `light = { r = px, color = {r, g, b}, a = fuerza, dy = px }`:
    -- setas luminosas, cristales, antorchas...) y de tiles (la lava), en dos escalones. No son linternas (no
    -- cuentan para la simulación: Lights); a oscuras, muy tenues; de noche y en cueva, más
    local now = love.timer.getTime()
    local function glow(lx, ly, L, mult)
        local c = L.color or { 1, 1, 1 }
        local a = (L.a or 0.14) * mult * (1 + 0.12 * math.sin(now * (L.pulse or 1.7) + lx * 0.05))
        if dark then
            love.graphics.setColor(c[1] * a * 0.5, c[2] * a * 0.5, c[3] * a * 0.5, 1)
            love.graphics.circle('fill', lx, ly, L.r)
            love.graphics.setColor(c[1] * a, c[2] * a, c[3] * a, 1)
            love.graphics.circle('fill', lx, ly, L.r * 0.55)
        else
            -- (degradado en RINGS escalones: la luz se va apagando hacia fuera, sin borde de disco)
            for i = 0, RINGS - 1 do
                local q = a / RINGS
                love.graphics.setColor(c[1] * q, c[2] * q, c[3] * q, 1)
                love.graphics.circle('fill', lx, ly, L.r * (1 - i / RINGS * 0.85))
            end
        end
    end
    local function lightsMult(y)
        if dark then return 1 end
        local H = (deepY and y > deepY) and DEEP or M
        return H and H.lights or 0
    end
    for _, d in ipairs(level.decorations or {}) do
        local L = d.def and d.def.light
        if L and d.x > camX - L.r and d.x < camX + WINDOW_W + L.r and d.y > camY - L.r and d.y < camY + WINDOW_H + L.r then
            local k = lightsMult(d.y)
            if k > 0 then glow(d.x, d.y + (L.dy or -16), L, k) end
        end
    end
    for _, t in ipairs(lightTiles(level)) do
        local L = t.L
        if t.x > camX - L.r and t.x < camX + WINDOW_W + L.r and t.y > camY - L.r and t.y < camY + WINDOW_H + L.r then
            local k = lightsMult(t.y)
            if k > 0 then glow(t.x, t.y, L, k) end
            -- (EMISIVO: la propia casilla — la lava — no se oscurece nunca)
            if L.emissive and not dark then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle('fill', t.x - TILE_PX / 2, t.y - TILE_PX / 2, TILE_PX, TILE_PX)
            end
        end
    end
    for _, e in pairs(entities or level.liveEntities or {}) do
        if e.alive ~= false and e.lights then
            for _, L in ipairs(e:lights() or {}) do
                if L.x > camX - L.r and L.x < camX + WINDOW_W + L.r and L.y > camY - L.r and L.y < camY + WINDOW_H + L.r then
                    local k = lightsMult(L.y)
                    if k > 0 then glow(L.x, L.y, L, k) end
                end
            end
        end
    end
    love.graphics.setCanvas(prevCanvas)
    love.graphics.setBlendMode('alpha')
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()
    -- Multiplicar sobre lo ya dibujado
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('multiply', 'premultiplied')
    love.graphics.draw(canvas, 0, 0, 0, DS, DS)
    love.graphics.setBlendMode('alpha')
    -- lo incandescente del fondo (volcanes, coladas, magma) sigue brillando
    if not dark and scene then restoreGlow(scene) end
end

-- Puntos luminosos y demás cosas que se ven en la oscuridad (encima de ella)
function Darkness.renderGlow(level, entities, camX, camY)
    if not (level and level.dark) then return end
    for _, e in pairs(entities) do
        if e.alive and e.renderGlow then e:renderGlow(camX, camY) end
    end
    require('src/fx/NoiseMarks').render(camX, camY)       -- (los "!" rojos de los ruidos)
    love.graphics.setColor(1, 1, 1, 1)
end

return Darkness
