-- src/story/Stage.lua
-- Las PIEZAS con que se montan las cinemáticas de la historia (src/story/Film.lua): todo son sprites, fondos y
-- sistemas del propio juego, colocados y animados por código.
--   Stage.monster(x, y, o)        el monstruo (los mismos cuadros y escala que en los niveles); o.invert = el Reflejo
--   Stage.laugh(x, y, t, o)       el Reflejo riéndose (la animación de risa del jefe Espejo)
--   Stage.mirror(x, feetY, o)     el espejo: marco + los fragmentos que tenga (o.shards) o el cristal entero (o.whole)
--   Stage.shard(id, x, y, o)      un fragmento suelto ('1'..'7'; Xtra: '1a', '1b'...); Stage.shardSlot = su sitio en el espejo
--   Stage.orb / Stage.spark       el aleteo hecho magia (orbe) y sus chispas
--   Stage.flappyBg(scroll, col)   el fondo del modo Flappy
--   Stage.sky(def, camX)          el cielo de los niveles (src/fx/Sky.lua) sin nivel
--   Stage.set(nombre) / drawSet   un DECORADO: un nivel de verdad (assets/story/sets/<nombre>.json), dibujado
--                                 como en el juego (cielo, bloques, lava, decoraciones, luz)
--   Stage.map()                   el mapa del mundo como decorado (StoryMapState:filmDraw)
--   Stage.flash / bars / rays     destello, franjas de cine, rayos de luz
local Sky = require 'src/fx/Sky'
local Darkness = require 'src/fx/Darkness'
local LavaFx = require 'src/fx/LavaFx'
local Particles = require 'src/fx/Particles'
local DeadEyes = require 'src/player/DeadEyes'
local Clip = require 'src/ui/Clip'
local Silhouette = require 'src/fx/Silhouette'

local Stage = {}
local floor = math.floor

Stage.MIRROR_S = 4                     -- escala del espejo (48x64 px de arte → 192x256)
Stage.MIRROR_W, Stage.MIRROR_H = 48, 64
Stage.BAR_H = 56                       -- franjas de cine

-- ── Imágenes ────────────────────────────────────────────────────────────────
local images, quads = {}, {}
local function img(path)
    if images[path] == nil then
        local ok, im = pcall(love.graphics.newImage, path)
        images[path] = ok and im or false
        if ok then im:setFilter('nearest', 'nearest') end
    end
    return images[path] or nil
end
Stage.img = img

local function frameQ(im, fw, i)
    local key = tostring(im) .. ':' .. fw .. ':' .. i
    if not quads[key] then quads[key] = love.graphics.newQuad((i - 1) * fw, 0, fw, im:getHeight(), im:getDimensions()) end
    return quads[key]
end

local invertShader
local function invert(on)
    if not on then love.graphics.setShader(); return end
    if invertShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv); return vec4(1.0 - p.rgb, p.a) * c; }
        ]])
        invertShader = ok and sh or false
    end
    if invertShader then love.graphics.setShader(invertShader) end
end

local maskShader
-- (recorta una imagen con el alfa de otra: el reflejo, con la forma del cristal)
local function getMaskShader()
    if maskShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            extern Image mask;
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv); return vec4(p.rgb, p.a * Texel(mask, uv).a) * c; }
        ]])
        maskShader = ok and sh or false
    end
    return maskShader or nil
end

-- ── El monstruo ─────────────────────────────────────────────────────────────
-- x, y = el centro del sprite (como PlayerAdventure). o: frame 1-3 andar / 2 subir / 4 caído / 5 agachado,
-- facing, puff (el "hinchazo" del aleteo), angle, alpha, scale, invert (el Reflejo), eyes (ojos en X)
function Stage.monster(x, y, o)
    o = o or {}
    local im = img('assets/images/player/monstrito' .. (o.frame or 1) .. '.png')
    if not im then return end
    local s = (o.scale or PLAYER_SCALE) * (o.puff or 1)
    local f = o.facing or 1
    -- FONDO BLANCO (src/fx/Silhouette.lua): dentro de un decorado (o con o.outline) el mismo sprite, algo más
    -- grande y en blanco, detrás: el monstruo es casi negro y en la penumbra solo se le veía la cara
    if (o.outline or (Stage._lit and o.outline ~= false)) and not o.invert and (o.alpha or 1) > 0.5 then
        Silhouette.draw(im, x, y, o.angle or 0, s * f * (o.sx or 1), s * (o.sy or 1), o.alpha or 1)
    end
    invert(o.invert)
    local c = o.color or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], o.alpha or 1)
    love.graphics.draw(im, floor(x), floor(y), o.angle or 0, s * f * (o.sx or 1), s * (o.sy or 1), im:getWidth() / 2, im:getHeight() / 2)
    if Stage._lit and (o.alpha or 1) > 0.5 and not o.noLight then Stage._lit[#Stage._lit + 1] = { x = x, y = y } end
    if o.eyes and not o.angle then DeadEyes.draw(floor(x), floor(y), s, f) end
    invert(false)
    love.graphics.setColor(1, 1, 1, 1)
end

-- El Reflejo riéndose: la animación de risa del jefe (types/mirror.lua): cuadro A = cabeza arriba + brazos
-- abajo; cuadro B = cabeza abajo + brazos arriba; ojos de alegría
local LAUGH_FRAME = 1 / 6
function Stage.laugh(x, y, t, o)
    o = o or {}
    local s = (o.scale or PLAYER_SCALE) * (o.puff or 1)
    local f = o.facing or 1
    local k = floor(t / LAUGH_FRAME) % 2
    local bob = (k == 1) and floor(s / 2) or 0
    local body = img('assets/images/bosses/mirror/' .. ((k == 1) and 'Body_ArmsUp' or 'Body_ArmsDown') .. '.png')
    local head = img('assets/images/bosses/mirror/' .. ((k == 1) and 'Head_Down' or 'Head_Up') .. '.png')
    local eyes = img('assets/images/bosses/mirror/JoyEyes.png')
    if not (body and head and eyes) then return end
    x, y = floor(x), floor(y)
    invert(o.invert ~= false)
    love.graphics.setColor(1, 1, 1, o.alpha or 1)
    local iw, ih = body:getDimensions()
    love.graphics.draw(body, x, y, 0, s * f, s, iw / 2, ih / 2)
    love.graphics.draw(head, x, y + bob, 0, s * f, s, iw / 2, ih / 2)
    local cell = math.max(1, floor(s / 2 + 0.5))
    local ew, eh = eyes:getDimensions()
    for _, side in ipairs({ -1, 1 }) do
        local cx = floor(x + side * 1.2 * s * f + 0.5)
        local cy = floor(y + bob - 2.5 * s + 0.5)
        love.graphics.draw(eyes, cx - floor(ew * cell / 2), cy - floor(eh * cell / 2), 0, cell, cell)
    end
    invert(false)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── El espejo y sus fragmentos ──────────────────────────────────────────────
local DIR = 'assets/images/story/mirror/'
local boxes = {}         -- id → { quad, cx, cy (centro del trozo en el lienzo), w, h }
local function shardInfo(id)
    if boxes[id] == nil then
        local path = DIR .. 'shard_' .. id .. '.png'
        local ok, data = pcall(love.image.newImageData, path)
        local im = img(path)
        if not (ok and im) then boxes[id] = false; return nil end
        local x0, y0, x1, y1 = data:getWidth(), data:getHeight(), -1, -1
        for y = 0, data:getHeight() - 1 do
            for x = 0, data:getWidth() - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0 then
                    if x < x0 then x0 = x end
                    if x > x1 then x1 = x end
                    if y < y0 then y0 = y end
                    if y > y1 then y1 = y end
                end
            end
        end
        local w, h = x1 - x0 + 1, y1 - y0 + 1
        boxes[id] = { im = im, quad = love.graphics.newQuad(x0, y0, w, h, data:getDimensions()), cx = x0 + w / 2, cy = y0 + h / 2, w = w, h = h }
    end
    return boxes[id] or nil
end
Stage.shardInfo = shardInfo

-- Los fragmentos, en el orden en que se ganan: 7 enteros o (Xtra extremo) 14 mitades
function Stage.shardIds(xtra)
    local out = {}
    for n = 1, 7 do
        if xtra then out[#out + 1] = n .. 'a'; out[#out + 1] = n .. 'b' else out[#out + 1] = tostring(n) end
    end
    return out
end

-- Dónde queda el centro de un fragmento cuando está en el espejo (espejo con los pies en x, feetY)
function Stage.shardSlot(id, x, feetY, s)
    s = s or Stage.MIRROR_S
    local b = shardInfo(id)
    if not b then return x, feetY - Stage.MIRROR_H * s / 2 end
    return x - Stage.MIRROR_W * s / 2 + b.cx * s, feetY - Stage.MIRROR_H * s + b.cy * s
end

-- Un fragmento suelto, centrado en x, y. o: s (escala), rot, alpha
function Stage.shard(id, x, y, o)
    o = o or {}
    local b = shardInfo(id)
    if not b then return end
    local s = o.s or Stage.MIRROR_S
    love.graphics.setColor(1, 1, 1, o.alpha or 1)
    love.graphics.draw(b.im, b.quad, floor(x), floor(y), o.rot or 0, s, s, b.w / 2, b.h / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- El centro del cristal (para reflejos, destellos y luces)
function Stage.glassCenter(x, feetY, s)
    s = s or Stage.MIRROR_S
    return x, feetY - (Stage.MIRROR_H - 27.5) * s
end

-- El espejo, con los pies en (x, feetY). o: shards = lista de ids puestos, whole = cristal entero,
-- reflection = function(gx, gy) (se dibuja DENTRO del cristal, recortado), shake (px), s (escala), alpha
function Stage.mirror(x, feetY, o)
    o = o or {}
    local s = o.s or Stage.MIRROR_S
    local sx = (o.shake and o.shake > 0) and floor((math.random() * 2 - 1) * o.shake) or 0
    local ox, oy = floor(x - Stage.MIRROR_W * s / 2) + sx, floor(feetY - Stage.MIRROR_H * s)
    local frame, glass = img(DIR .. 'frame.png'), img(DIR .. 'glass.png')
    love.graphics.setColor(1, 1, 1, o.alpha or 1)
    if frame then love.graphics.draw(frame, ox, oy, 0, s, s) end
    if o.whole and glass then
        love.graphics.setColor(1, 1, 1, (o.alpha or 1) * (o.glassAlpha or 1))
        love.graphics.draw(glass, ox, oy, 0, s, s)
    end
    for _, id in ipairs(o.shards or {}) do
        local b = shardInfo(id)
        if b then love.graphics.draw(b.im, ox, oy, 0, s, s) end
    end
    if o.reflection and glass then
        -- LO REFLEJADO: se dibuja en un lienzo del tamaño del espejo y se recorta con la FORMA del cristal (su
        -- alfa); encima, el brillo del propio cristal, para que quede "dentro". `reflection(gx, gy)` dibuja en
        -- las mismas coordenadas que el resto (gx, gy = centro del cristal)
        local cw, chh = Stage.MIRROR_W * s, Stage.MIRROR_H * s
        if not Stage._refl or Stage._refl:getWidth() ~= cw or Stage._refl:getHeight() ~= chh then
            Stage._refl = love.graphics.newCanvas(cw, chh)
            Stage._refl:setFilter('nearest', 'nearest')
        end
        local gx, gy = Stage.glassCenter(x + sx, feetY, s)
        local lit = Stage._lit
        Stage._lit = nil                                   -- (lo reflejado no da luz ni lleva contorno)
        love.graphics.push('all')
        love.graphics.setCanvas(Stage._refl)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.setScissor()
        love.graphics.translate(-ox, -oy)
        o.reflection(gx, gy)
        love.graphics.pop()
        Stage._lit = lit
        local sh = getMaskShader()
        if sh then sh:send('mask', glass); love.graphics.setShader(sh) end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Stage._refl, ox, oy)
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 0.3)               -- el brillo del cristal, por encima
        love.graphics.draw(glass, ox, oy, 0, s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Luz del espejo para la penumbra del decorado (Darkness la pide con e:lights())
function Stage.mirrorLight(x, feetY, a, r)
    local gx, gy = Stage.glassCenter(x, feetY)
    return { alive = true, lights = function() return { { x = gx, y = gy, r = r or 360, color = { 0.8, 0.92, 1 }, a = a or 0.5, pulse = 2.2 } } end }
end
function Stage.light(x, y, r, a, color)
    return { alive = true, lights = function() return { { x = x, y = y, r = r, color = color or { 0.8, 0.92, 1 }, a = a, pulse = 3 } } end }
end

-- ── Magia: el orbe del aleteo y las chispas ─────────────────────────────────
function Stage.orb(x, y, t, s, alpha)
    local im = img('assets/images/story/fx/magic-Sheet.png')
    if not im then return end
    s = s or 4
    local fr = ({ 1, 2, 3, 2 })[floor(t * 8) % 4 + 1]
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(im, frameQ(im, 11, fr), floor(x), floor(y), 0, s, s, 5.5, 5.5)
    love.graphics.setColor(1, 1, 1, 1)
end

local sparks = {}
-- n chispas desde (x, y): spread = radio en que nacen, speed = px/s, o: { vx, vy (deriva), life, s, g }
function Stage.spark(x, y, n, spread, speed, o)
    o = o or {}
    for _ = 1, n or 1 do
        local a = math.random() * math.pi * 2
        local r = math.random() * (spread or 0)
        local v = (speed or 0) * (0.4 + math.random() * 0.6)
        sparks[#sparks + 1] = { x = x + math.cos(a) * r, y = y + math.sin(a) * r,
                                vx = math.cos(a) * v + (o.vx or 0), vy = math.sin(a) * v + (o.vy or 0), g = o.g or 0,
                                t = 0, life = (o.life or 0.6) * (0.7 + math.random() * 0.6), s = o.s or 3,
                                tx = o.tx, ty = o.ty }
    end
end

-- ── Fondos ──────────────────────────────────────────────────────────────────
local FLAPPY_BG_SCALE = 15
function Stage.flappyBg(scroll, col, alpha)
    local im = img('assets/images/flappy/Background.png')
    alpha = alpha or 1
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    if not im then return end
    local bw, bh = im:getWidth() * FLAPPY_BG_SCALE, im:getHeight() * FLAPPY_BG_SCALE
    local x = -(floor(scroll) % bw)
    while x < WINDOW_W do
        local y = 0
        while y < WINDOW_H do
            love.graphics.draw(im, x, y, 0, FLAPPY_BG_SCALE, FLAPPY_BG_SCALE)
            y = y + bh
        end
        x = x + bw
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- El cielo de los niveles, sin nivel: def = { background = 'volcano', time = 'dusk', tileH }
function Stage.sky(def, camX, camY)
    local lv = { background = def.background, timeOfDay = def.time or 'day', tileH = def.tileH or 12, clouds = def.clouds,
                 playerStart = { 1, 8 } }
    Sky.render(lv, camX or 0, camY or 0)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Decorados (niveles de verdad) ───────────────────────────────────────────
local sets = {}
function Stage.set(name)
    if not sets[name] then
        local Level = require 'src/world/level/Level'
        local lv = Level.new('assets/story/sets/' .. name .. '.json')
        lv.players, lv.canBreak = {}, false
        sets[name] = { level = lv }
    end
    Stage.current = sets[name]
    return sets[name]
end

-- Dibuja el decorado como el juego dibuja un nivel. `actors(camX, camY)` = lo que va entre los bloques y las
-- decoraciones de delante (en coordenadas del MUNDO: ya está trasladado); `lights` = luces para la penumbra
-- (Stage.mirrorLight...); `glow` = lo que se dibuja ENCIMA de la penumbra (lo que brilla), también en mundo
function Stage.drawSet(set, camX, camY, actors, lights, glow)
    local level = set.level
    camX, camY = floor(camX), floor(camY)
    if not set.canvas or set.canvas:getWidth() ~= WINDOW_W or set.canvas:getHeight() ~= WINDOW_H then
        set.canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end
    love.graphics.push()
    love.graphics.origin()
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    local prev = love.graphics.getCanvas()
    love.graphics.setCanvas(set.canvas)
    love.graphics.clear(0, 0, 0, 1)
    local mood = Darkness.active(level)
    Sky.punch = mood and not level.dark
    Sky.render(level, camX, camY)
    Sky.punch = false
    level:render(camX, camY)
    LavaFx.render(level, camX, camY)
    level:renderFoliageBack(camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
    -- (cada monstruo que se dibuje aquí lleva su halo de luz: es casi negro y el decorado está en penumbra)
    Stage._lit = {}
    if actors then
        love.graphics.push()
        love.graphics.translate(-camX, -camY)
        actors(camX, camY)
        love.graphics.pop()
    end
    local all = {}
    for _, l in ipairs(lights or {}) do all[#all + 1] = l end
    for _, m in ipairs(Stage._lit) do all[#all + 1] = Stage.light(m.x, m.y, 210, 0.6, { 1, 0.93, 0.82 }) end
    Stage._lit = nil
    Particles.render(camX, camY)
    level:renderFoliage(camX, camY)
    love.graphics.setCanvas(prev)
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    level:renderWaterEffect(camX, camY, set.canvas)
    if mood then Darkness.render(level, camX, camY, {}, all, set.canvas) end
    love.graphics.push()
    love.graphics.translate(-camX, -camY)
    if glow then glow(camX, camY) end
    Stage.drawSparks()
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── El mapa ─────────────────────────────────────────────────────────────────
local mapState
function Stage.map()
    local SM = require 'src/states/story/StoryMapState'
    if not mapState then mapState = SM:new():stage() end
    return mapState, SM
end

-- ── Remates ─────────────────────────────────────────────────────────────────
function Stage.flash(a, r, g, b)
    if not a or a <= 0 then return end
    love.graphics.setColor(r or 1, g or 1, b or 1, math.min(1, a))
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

function Stage.bars()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, Stage.BAR_H)
    love.graphics.rectangle('fill', 0, WINDOW_H - Stage.BAR_H, WINDOW_W, Stage.BAR_H)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Rayos de luz girando desde (x, y): cuñas duras, a escalones (estilo del juego)
function Stage.rays(x, y, t, n, len, a, col)
    col = col or { 1, 1, 0.85 }
    love.graphics.setBlendMode('add')
    for i = 1, n do
        local ang = t * 0.5 + i / n * math.pi * 2
        local w = 0.11
        love.graphics.setColor(col[1], col[2], col[3], a * (i % 2 == 0 and 1 or 0.6))
        love.graphics.polygon('fill', x, y, x + math.cos(ang - w) * len, y + math.sin(ang - w) * len,
                              x + math.cos(ang + w) * len, y + math.sin(ang + w) * len)
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Vida de la escena ───────────────────────────────────────────────────────
function Stage.reset()
    sparks = {}
    Particles.clear()
    Particles.setLevel(nil)
    if mapState then mapState:stage() end
end

function Stage.update(dt)
    for i = #sparks, 1, -1 do
        local p = sparks[i]
        p.t = p.t + dt
        if p.tx then                                  -- (atraída hacia un punto)
            local k = math.min(1, dt * 5)
            p.x, p.y = p.x + (p.tx - p.x) * k, p.y + (p.ty - p.y) * k
        end
        p.vy = p.vy + p.g * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.t >= p.life then table.remove(sparks, i) end
    end
    Particles.update(dt)
    if Stage.current then
        local lv = Stage.current.level
        lv:update(dt)
        if lv.updateFoliage then lv:updateFoliage(dt) end
    end
    if mapState then mapState.t = mapState.t + dt end
end

function Stage.drawSparks()
    local im = img('assets/images/story/fx/sparkle-Sheet.png')
    if not im then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, p in ipairs(sparks) do
        local fr = math.min(4, floor(p.t / p.life * 4) + 1)
        love.graphics.draw(im, frameQ(im, 7, fr), floor(p.x), floor(p.y), 0, p.s, p.s, 3.5, 3.5)
    end
end

return Stage
