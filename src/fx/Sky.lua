-- src/fx/Sky.lua
-- Cielo y fondo con paralaje de los niveles (solo dibujo). Dos partes:
--   SUPERFICIE  (JSON "background", bioma con cielo o sin él) hasta la línea de
--               superficie: por defecto el suelo bajo la salida del jugador, o la fila
--               "surfaceRow" del JSON (el suelo de esa fila); sus capas de suelo se apoyan
--               en esa línea
--   PROFUNDIDAD (JSON "depth", opcional: cueva, submarino, abismo, cueva helada,
--               subsuelo) por debajo de la línea; se ve según baja la cámara (la línea
--               va con el mundo y casi siempre la tapa el propio suelo del nivel)
-- y una HORA (JSON "time", "clouds"; editor: pestaña Nivel → Fondo y clima):
--   cielo   degradado en franjas de píxel según la hora (o el de cueva / submarino)
--   astros  sol (día, atardecer: bajo y anaranjado) o luna + estrellas (noche)
--   nubes   a la deriva, con un poco de paralaje (se pueden quitar)
--   capas   siluetas que se repiten a lo ancho, cada una a su velocidad (las de
--           lejos se mueven menos): las de suelo se apoyan en el fondo del nivel
--           (en niveles altos se van quedando abajo y se ve más cielo) y las de
--           techo (cueva) cuelgan de arriba del nivel
-- De noche / al atardecer las capas y nubes se tiñen. Arte en assets/images/sky/
-- (tools/ui/make_sky.py). Un bioma nuevo = sus PNG + una entrada en BIOMES.
--   Sky.render(level, camX, camY)   (antes que el nivel, en lugar del fondo)
local Sky = {}

local DIR = 'assets/images/sky/'
local S = 4                              -- escala del arte

-- Degradados (cuadros de gradients.png)
local GRAD = { day = 1, dusk = 2, night = 3, cave = 4, water = 5, abyss = 6, icecave = 7, underground = 8 }

Sky.TIMES = {
    { id = 'day',   label = 'Día',       tint = { 1, 1, 1 } },
    { id = 'dusk',  label = 'Atardecer', tint = { 1, 0.8, 0.72 } },
    { id = 'night', label = 'Noche',     tint = { 0.42, 0.48, 0.72 } },
}

-- capas: { archivo, paralaje, top = cuelga de arriba, add = aditiva }
Sky.BIOMES = {
    { id = 'meadow',   label = 'Pradera',   sky = true, layers = { { 'meadow_far', 0.1 }, { 'meadow_mid', 0.22 }, { 'meadow_near', 0.4 } } },
    { id = 'coast',    label = 'Costa',     sky = true, layers = { { 'coast_far', 0.08 }, { 'coast_mid', 0.22 }, { 'coast_near', 0.4 } } },
    { id = 'mountain', label = 'Montaña',   sky = true, layers = { { 'mountain_far', 0.08 }, { 'mountain_mid', 0.2 }, { 'mountain_near', 0.38 } } },
    { id = 'snow',     label = 'Nieve',     sky = true, layers = { { 'snow_far', 0.08 }, { 'snow_mid', 0.2 }, { 'snow_near', 0.38 } } },
    { id = 'forest',   label = 'Bosque / selva', sky = true, layers = { { 'forest_far', 0.1 }, { 'forest_mid', 0.22 }, { 'forest_near', 0.4 } } },
    { id = 'fortress', label = 'Fortaleza', sky = true, layers = { { 'fortress_far', 0.08 }, { 'fortress_mid', 0.25 } } },
    -- (estos también valen de PROFUNDIDAD: depth = true)
    { id = 'cave',     label = 'Cueva',     grad = 'cave', depth = true,
      layers = { { 'cave_far', 0.12 }, { 'cave_mid', 0.28 }, { 'cave_top', 0.2, top = true } } },
    { id = 'underwater', label = 'Submarino', grad = 'water', depth = true,
      layers = { { 'underwater_far', 0.12 }, { 'underwater_mid', 0.28 }, { 'rays', 0.1, top = true, add = true } } },
    { id = 'abyss',    label = 'Abismo',    grad = 'abyss', depth = true, onlyDepth = true,
      layers = { { 'abyss_far', 0.12 }, { 'abyss_mid', 0.28 }, { 'abyss_top', 0.2, top = true } } },
    { id = 'icecave',  label = 'Cueva helada', grad = 'icecave', depth = true, onlyDepth = true,
      layers = { { 'icecave_far', 0.12 }, { 'icecave_mid', 0.28 }, { 'icecave_top', 0.2, top = true } } },
    { id = 'underground', label = 'Subsuelo', grad = 'underground', depth = true, onlyDepth = true,
      layers = { { 'underground_far', 0.12 }, { 'underground_mid', 0.28 }, { 'underground_top', 0.2, top = true } } },
}
Sky.byId = {}
for _, b in ipairs(Sky.BIOMES) do Sky.byId[b.id] = b end
Sky.timeById = {}
for _, t in ipairs(Sky.TIMES) do Sky.timeById[t.id] = t end
Sky.DEFAULT = 'meadow'

local cache = {}
local function img(name)
    if cache[name] == nil then
        local ok, im = pcall(love.graphics.newImage, DIR .. name .. '.png')
        if ok then
            im:setFilter('nearest', 'nearest')
            -- color de la fila del borde (abajo / arriba) para rellenar fuera de la capa
            local okd, data = pcall(love.image.newImageData, DIR .. name .. '.png')
            local function at(y)
                if not okd then return { 0, 0, 0, 0 } end
                local r, g, b, a = data:getPixel(math.floor(data:getWidth() / 2), y)
                return { r, g, b, a }
            end
            cache[name] = { img = im, w = im:getWidth(), h = im:getHeight(),
                            bottom = at(im:getHeight() - 1), top = at(0) }
        else
            cache[name] = false
        end
    end
    return cache[name]
end

local quadCache = {}
local function quad(name, i, fw, e)
    local k = name .. i
    if not quadCache[k] then quadCache[k] = love.graphics.newQuad((i - 1) * fw, 0, fw, e.h, e.w, e.h) end
    return quadCache[k]
end

local function setTint(t, a) love.graphics.setColor(t[1], t[2], t[3], a or 1) end

-- Estrellas fijas (posiciones deterministas en la pantalla)
local STARS = {}
for i = 1, 70 do
    local v = math.sin(i * 12.9898) * 43758.5453
    local u = math.sin(i * 78.233) * 12345.678
    STARS[i] = { x = (v - math.floor(v)), y = (u - math.floor(u)) * 0.62, f = i % 3 + 1, ph = i * 0.7 }
end

local CLOUDS = {
    { x = 0.05, y = 70, v = 1, sp = 6 }, { x = 0.32, y = 140, v = 2, sp = 4 }, { x = 0.58, y = 95, v = 3, sp = 7 },
    { x = 0.81, y = 180, v = 1, sp = 5 }, { x = 1.1, y = 120, v = 2, sp = 6 }, { x = 1.4, y = 60, v = 3, sp = 4 },
    { x = 1.7, y = 160, v = 1, sp = 5 },
}

function Sky.biomeOf(level)
    local b = Sky.byId[level.background or Sky.DEFAULT]
    return (b and not b.onlyDepth) and b or Sky.byId[Sky.DEFAULT]
end
function Sky.depthOf(level) local d = level.depth and Sky.byId[level.depth]; return d and d.depth and d or nil end
function Sky.timeOf(level) return Sky.timeById[level.timeOfDay or 'day'] or Sky.TIMES[1] end

local GROUNDISH = { solid = true, oneway = true }
-- Fila del suelo bajo la salida del jugador (la línea de superficie por defecto)
function Sky.autoSurfaceRow(level)
    local ps = level.playerStart or level.spawn
    local c, r = 1, 1
    if type(ps) == 'table' then c, r = ps[1] or ps.col or 1, ps[2] or ps.row or 1 end
    for rr = r, level.tileH or r do
        local d = level:getDef(c, rr)
        if d and GROUNDISH[d.collision] then return rr end
    end
    return level.tileH or r
end

-- Línea de superficie en px de mundo (arriba de la fila del suelo)
function Sky.surfaceY(level)
    if not level._skySurf then
        local row = (level.surfaceRow and level.surfaceRow > 0) and level.surfaceRow or Sky.autoSurfaceRow(level)
        level._skySurf = (row - 1) * TILE_PX
    end
    return level._skySurf
end

-- Capas de un bioma. groundY = donde se apoyan las de suelo (px de mundo);
-- topY = de donde cuelgan las de techo; restY = altura de pantalla en la que una
-- capa de suelo toca su línea cuando la línea está ahí (con paralaje se separa)
local function drawLayers(biome, tint, camX, camY, groundY, topY, now, restY)
    local W, H = WINDOW_W, WINDOW_H
    local mode, am = love.graphics.getBlendMode()
    for _, L in ipairs(biome.layers) do
        local e = img(L[1])
        if e then
            local p = L[2]
            local w, h = e.w * S, e.h * S
            local x0 = -((camX * p) % w)
            local y
            if L.top then
                y = math.floor((topY - camY) + (camY - topY) * (1 - p))       -- cuelga, con paralaje
            else
                local r0 = restY or H
                y = math.floor(r0 + (groundY - camY - r0) * p - h)             -- apoyada, con paralaje
            end
            if L.add then
                love.graphics.setBlendMode('add')
                love.graphics.setColor(1, 1, 1, 0.35 + 0.1 * math.sin(now * 0.7))
            else
                setTint(tint)
            end
            local x = math.floor(x0)
            while x < W do
                love.graphics.draw(e.img, x, y, 0, S, S)
                x = x + w
            end
            if not L.add then
                local c = L.top and e.top or e.bottom
                if c[4] > 0 then
                    love.graphics.setColor(c[1] * tint[1], c[2] * tint[2], c[3] * tint[3], 1)
                    if L.top and y > 0 then love.graphics.rectangle('fill', 0, 0, W, y) end
                    if not L.top and y + h < H then love.graphics.rectangle('fill', 0, y + h, W, H - y - h) end
                end
            end
            love.graphics.setBlendMode(mode, am)
        end
    end
end

function Sky.render(level, camX, camY)
    local biome, time = Sky.biomeOf(level), Sky.timeOf(level)
    local tint = time.tint
    local W, H = WINDOW_W, WINDOW_H
    local now = love.timer.getTime()
    local levelTop, levelBottom = 0, (level.tileH or 12) * TILE_PX
    local surfY = Sky.surfaceY(level)
    local g = img('gradients')

    -- ══ SUPERFICIE ══════════════════════════════════════════════════════════
    if g then
        local gi = biome.grad and GRAD[biome.grad] or GRAD[time.id]
        if biome.grad then setTint(tint) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(g.img, quad('gradients', gi, 8, g), 0, 0, 0, W / 8, H / g.h)
    end
    if biome.sky then
        -- ── Estrellas y astros ───────────────────────────────────────────────
        if time.id == 'night' then
            local st = img('stars')
            if st then
                for i, s in ipairs(STARS) do
                    local f = (math.floor(now * 1.5 + s.ph) % 7 == 0) and 2 or s.f
                    love.graphics.setColor(1, 1, 1, 0.85)
                    local x = ((s.x * W - camX * 0.01) % W)
                    love.graphics.draw(st.img, quad('stars', f, 3, st), math.floor(x), math.floor(s.y * H), 0, 3, 3)
                end
            end
            local m = img('moon')
            if m then love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(m.img, math.floor(W * 0.78), 70, 0, S, S) end
        else
            local sun = img('sun')
            if sun then
                local dusk = time.id == 'dusk'
                love.graphics.setColor(1, dusk and 0.75 or 1, dusk and 0.55 or 1, 1)
                love.graphics.draw(sun.img, math.floor(W * (dusk and 0.8 or 0.76)), dusk and 330 or 60, 0, S, S)
            end
        end
        -- ── Nubes ────────────────────────────────────────────────────────────
        local cl = level.clouds ~= false and img('clouds')
        if cl then
            setTint(tint, time.id == 'night' and 0.7 or 0.95)
            local span = W * 2
            local dy = math.max(-200, math.min(200, (surfY - H - camY) * 0.04))
            for _, c in ipairs(CLOUDS) do
                local x = (c.x * W + now * c.sp - camX * 0.06) % span - 200
                love.graphics.draw(cl.img, quad('clouds', c.v, 48, cl), math.floor(x), math.floor(c.y + dy), 0, S, S)
            end
        end
    end
    -- (sin profundidad, las capas de suelo se apoyan en el fondo del nivel)
    local depth = Sky.depthOf(level)
    -- (con profundidad se apoyan en la línea de superficie, que suele verse a ~¾ de la pantalla)
    drawLayers(biome, tint, camX, camY, depth and surfY or math.max(surfY, levelBottom), levelTop, now,
               depth and math.floor(H * 0.78) or nil)

    -- ══ PROFUNDIDAD (por debajo de la línea de superficie) ═══════════════════
    local B = math.floor(surfY - camY)
    if depth and B < H then
        local top = math.max(0, B)
        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor(0, top, W, H - top)
        if g then
            -- degradado anclado al mundo: más oscuro cuanto más hondo
            -- (hasta el fondo del nivel y una pantalla más: siempre tapa lo que se ve)
            local span = math.max(H, levelBottom - surfY) + H
            setTint(tint)
            love.graphics.draw(g.img, quad('gradients', GRAD[depth.grad], 8, g), 0, B, 0, W / 8, span / g.h)
        end
        drawLayers(depth, tint, camX, camY, levelBottom, surfY, now)
        love.graphics.setScissor(sx, sy, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Sky
