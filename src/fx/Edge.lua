-- src/fx/Edge.lua
-- EL BORDE DE CONTRASTE de los personajes (docs/design/entity-edge-shader.md): un filo claro u oscuro que separa al
-- jugador, a los enemigos, a los jefes y a los objetos de lo que tienen detrás, solo donde se pierden. Dos modos
-- (ajuste BORDE, pestaña AYUDAS; por defecto según el aparato):
--   'shader'  los personajes se dibujan en su propio lienzo y UNA pasada de pantalla entera compara, píxel a píxel,
--             cada borde con lo que tiene detrás (ya con la luz del nivel) y hace aparecer el filo solo ahí
--   'simple'  (aparatos modestos) la silueta de siempre — 8 copias corridas de un color, src/fx/Silhouette.lua — en
--             todo personaje con el rasgo `edge`, clara donde está oscuro, con fundido; se decide por nivel y altura,
--             no por píxel
--
--   Edge.mode()                      'shader' | 'simple' (el ajuste, o el de su aparato; sin shaders, simple)
--   Edge.level                       el nivel que se está dibujando (lo pone quien dibuja la escena; nil fuera)
--   Edge.draw(owner, x, y, fn, ...)  dibuja a `owner` (en el mundo: x, y) con su borde; fn(dx, dy, ...) lo dibuja
--                                    corrido esos píxeles de pantalla
--   Edge.direct(fn, ...)             lo que dibuje fn(...) va SIN borde (sombras, marcas, brillos, nombres, barras)
--   Edge.simpleKind(level, x, y)     'light' | nil: ¿lleva el filo claro del modo simple en ese sitio?
local Silhouette = require 'src/fx/Silhouette'
local Shaders    = require 'src/fx/Shaders'

local Edge = {}

-- (escenas abiertas del modo shader — ver Edge.open —: aquí arriba porque Edge.draw las mira)
local stack, depth, actorPool = {}, 0, {}
local function top() return stack[depth] end

Edge.W     = 2                                   -- grosor (px de pantalla) en modo shader
Edge.T_LO, Edge.T_HI = 0.08, 0.22                -- diferencia de luminancia: filo entero / ninguno
Edge.L_LO, Edge.L_HI = 0.12, 0.3                 -- luz del sitio: sin filo / filo entero (a oscuras no delata nada)
Edge.LIGHT = { 1, 1, 1 }
Edge.DARK  = { 0.05, 0.06, 0.10 }
Edge.MAX_A = 0.9
Edge.FADE  = 0.3                                 -- s del fundido del modo simple
Edge.HALO  = 118                                 -- px: a oscuras, lo que alumbra el halo de un jugador (Darkness HALO_ON)
Edge.clock = love.timer and love.timer.getTime or os.clock
Edge.level = nil

local DESKTOP = { Windows = true, ['OS X'] = true, Linux = true }
function Edge.defaultMode(os) return DESKTOP[os] and 'shader' or 'simple' end

local Settings
function Edge.mode()
    Settings = Settings or require 'src/core/Settings'
    local m = Settings.edge
    if m ~= 'shader' and m ~= 'simple' then
        m = Edge.defaultMode(love.system and love.system.getOS() or 'Linux')
    end
    if m == 'shader' and not Shaders.get('edge_composite') then m = 'simple' end
    return m
end

-- ── Modo simple ──────────────────────────────────────────────────────────────
local Lights, Particles
function Edge.simpleKind(level, x, y)
    if not level then return nil end
    if Silhouette.on(level, y) then
        if not level.dark then return 'light' end
        -- (a oscuras: solo lo que se ve — la linterna o el halo de un jugador —; lo demás, sin filo que lo delate)
        Lights = Lights or require 'src/world/level/Lights'
        if Lights.lit(level, x, y) then return 'light' end
        for _, p in ipairs(level.players or {}) do
            local dx, dy = (p.x or 0) - x, (p.y or 0) - y
            if dx * dx + dy * dy <= Edge.HALO * Edge.HALO then return 'light' end
        end
        return nil
    end
    -- (en fondos claros de día — nieve — NADA: probado y quitado, el usuario 2026-11-12: los sprites ya llevan su
    -- contorno oscuro justo por eso y el filo oscuro de nivel entero no quedaba bien. En modo shader se decide por
    -- píxel: ese contorno ya contrasta y no sale nada)
    return nil
end

local fade = setmetatable({}, { __mode = 'k' })     -- owner → { a, t, kind }
function Edge.alphaOf(owner) local f = fade[owner]; return f and f.a or 0 end

local DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local passDepth = 0
function Edge.inPass() return passDepth > 0 end

-- LAS COPIAS NO TIENEN EFECTOS: el dibujo de un jefe se llama 9 veces (8 copias + la de verdad) y muchos apuntan algo
-- al dibujar (cuánto se movió desde el dibujo anterior, cuándo soltó polvo...), sueltan partículas o tiran del azar.
-- Durante las copias: el shader plano no se cambia, las partículas no salen, el azar es otro (el de la partida no se
-- mueve: el fondo de los menús es una carrera fija) y lo que se apunte en el dueño se deshace al acabar.
local realSetShader
local function keepFlat() end
local function noEmit() end
local passRng
local function passRandom(a, b)
    passRng = passRng or love.math.newRandomGenerator(1)
    if a then return passRng:random(a, b) end
    return passRng:random()
end
local saved, savedKeys = {}, {}                     -- (reutilizadas: sin basura)
local function snapshot(owner)
    local n = 0
    for k, v in pairs(owner) do n = n + 1; savedKeys[n] = k; saved[k] = v end
    savedKeys.n = n
end
local function restore(owner)
    for k in pairs(owner) do if saved[k] == nil then owner[k] = nil end end
    for i = 1, savedKeys.n do local k = savedKeys[i]; owner[k] = saved[k]; saved[k] = nil; savedKeys[i] = nil end
end

local function simpleDraw(owner, x, y, fn, ...)
    local now = Edge.clock()
    local kind = forceKind or Edge.simpleKind(owner.edgeLevel or Edge.level, x, y)  -- (edgeLevel: un actor de cinemática)
    local f = fade[owner]
    if not f then f = { a = 0, t = now }; fade[owner] = f end
    local dt = math.max(0, math.min(Edge.FADE, now - f.t))
    f.t = now
    local step = dt / Edge.FADE
    if kind then f.kind = kind; f.a = math.min(1, f.a + step) else f.a = math.max(0, f.a - step) end
    local flat = f.a > 0 and f.kind and Shaders.get('silhouette_flat')
    if flat then
        local c = f.kind == 'dark' and Edge.DARK or Edge.LIGHT
        local r, g, b, sa = love.graphics.getColor()
        local px = owner.edgeThin and 1 or math.max(1, math.floor(PLAYER_SCALE / 3 + 0.5))
        local prev = love.graphics.getShader()
        flat:send('tint', { c[1], c[2], c[3], f.a * Edge.MAX_A })
        love.graphics.setShader(flat)
        Particles = Particles or require 'src/fx/Particles'
        realSetShader = love.graphics.setShader
        local realEmit, realRandom = Particles.emit, math.random
        love.graphics.setShader, Particles.emit, math.random = keepFlat, noEmit, passRandom
        snapshot(owner)
        passDepth = passDepth + 1
        local ok, err = true, nil
        for _, d in ipairs(DIRS) do
            love.graphics.setColor(1, 1, 1, sa)
            ok, err = pcall(fn, d[1] * px, d[2] * px, ...)
            if not ok then break end
        end
        passDepth = passDepth - 1
        restore(owner)
        love.graphics.setShader, Particles.emit, math.random = realSetShader, realEmit, realRandom
        love.graphics.setShader(prev)
        if not ok then error(err, 0) end
        love.graphics.setColor(r, g, b, sa)
    end
    fn(0, 0, ...)
end

function Edge.draw(owner, x, y, fn, ...)
    if Edge.mode() == 'simple' then return simpleDraw(owner, x, y, fn, ...) end
    local f = top()
    if f and not f.on then                           -- (una escena abierta: el cuerpo, al lienzo de los personajes)
        f.on = true
        love.graphics.setCanvas(f.actor)
        fn(0, 0, ...)
        f.on = false
        love.graphics.setCanvas(f.scene)
        return
    end
    fn(0, 0, ...)
end

-- ── Modo shader ──────────────────────────────────────────────────────────────
-- Los personajes se dibujan en el LIENZO DE LOS PERSONAJES (transparente); `finish` junta la escena y ese lienzo en
-- el lienzo PAREJA de la escena con una pasada: donde no hay personaje pero sí a ≤ W px, compara la luminancia del
-- personaje con la del fondo (las dos con la luz del sitio) y, si se parecen, pone el filo (claro sobre fondo oscuro,
-- oscuro sobre claro). La pasada lee la escena y escribe en su pareja: un shader no puede leer el lienzo en que dibuja.
Shaders.define('edge_composite', [[
    extern Image actors;
    extern Image light;
    extern vec2 lightK;        // uv de la pantalla → uv del lienzo de luz (es de 1/4 y redondea hacia arriba)
    extern vec2 texel;         // 1 / tamaño
    extern float W;
    extern vec4 th;            // T_LO, T_HI, L_LO, L_HI
    extern vec3 lightC;
    extern vec3 darkC;
    extern float maxA;
    float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
    vec4 effect(vec4 col, Image scene, vec2 uv, vec2 sc) {
        vec4 s = Texel(scene, uv);
        vec4 a = Texel(actors, uv);
        if (a.a > 0.0) return vec4(a.rgb + s.rgb * (1.0 - a.a), a.a + s.a * (1.0 - a.a));
        float n = 0.0;
        vec3 nc = vec3(0.0);
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                for (int k = 1; k <= 4; k++) {
                    if (float(k) > W) break;
                    vec2 q = uv + vec2(float(dx), float(dy)) * texel * float(k);
                    if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) continue;
                    vec4 p = Texel(actors, q);
                    if (p.a > n) { n = p.a; nc = p.rgb / p.a; }
                }
            }
        }
        if (n <= 0.0) return s;
        float L = lum(Texel(light, uv * lightK).rgb);
        float lb = lum(s.rgb) * L;
        float c = abs(lum(nc) * L - lb);
        float k = (1.0 - smoothstep(th.x, th.y, c)) * smoothstep(th.z, th.w, L) * maxA * n;
        vec3 e = (lb < 0.5) ? lightC : darkC;
        return vec4(s.rgb * (1.0 - k) + e * k, s.a * (1.0 - k) + k);
    }
]])

local partner = setmetatable({}, { __mode = 'k' })  -- lienzo de la escena → su pareja (mismo tamaño)
local whiteImg
local function sized(cv, w, h)
    if cv and cv:getWidth() == w and cv:getHeight() == h then return cv end
    return love.graphics.newCanvas(w, h)
end
-- ESCENAS ABIERTAS, una dentro de otra (una cinemática entera — Edge.scene — y dentro un decorado — Stage.drawSet —):
-- cada nivel con su lienzo de personajes. `on` = el destino es ahora el de los personajes

-- Abre una escena en `scene` (el destino sigue siendo la escena): lo que se dibuje por Edge.draw irá a los personajes
function Edge.open(scene)
    depth = depth + 1
    local f = stack[depth] or {}
    stack[depth] = f
    local w, h = scene:getDimensions()
    actorPool[depth] = sized(actorPool[depth], w, h)
    f.scene, f.actor, f.on = scene, actorPool[depth], false
    love.graphics.setCanvas(f.actor)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setCanvas(scene)
end

-- Abre una escena y empieza a dibujar personajes: el lienzo de los personajes pasa a ser el destino
function Edge.begin(scene)
    Edge.open(scene)
    local f = top()
    f.on = true
    love.graphics.setCanvas(f.actor)
end

-- Junta la escena y los personajes con el filo en la pareja de la escena; la deja de destino y la devuelve
function Edge.finish(light)
    local f = top()
    depth = depth - 1
    local scene, actorCv = f.scene, f.actor
    f.scene, f.actor, f.on = nil, nil, false
    local w, h = scene:getDimensions()
    local out = sized(partner[scene], w, h)
    partner[scene] = out
    local sh = Shaders.get('edge_composite')
    if not whiteImg then
        local d = love.image.newImageData(1, 1); d:setPixel(0, 0, 1, 1, 1, 1)
        whiteImg = love.graphics.newImage(d)
    end
    local L = light or whiteImg
    sh:send('actors', actorCv)
    sh:send('light', L)
    if light then sh:send('lightK', { w / (light:getWidth() * 4), h / (light:getHeight() * 4) }) else sh:send('lightK', { 1, 1 }) end
    sh:send('texel', { 1 / w, 1 / h })
    sh:send('W', Edge.W)
    sh:send('th', { Edge.T_LO, Edge.T_HI, Edge.L_LO, Edge.L_HI })
    sh:send('lightC', Edge.LIGHT)
    sh:send('darkC', Edge.DARK)
    sh:send('maxA', Edge.MAX_A)
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(out)
    love.graphics.setShader(sh)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(scene, 0, 0)
    love.graphics.pop()
    love.graphics.setCanvas(out)
    return out
end

-- ¿Va al lienzo de los personajes? (modo shader y el rasgo `edge`)
function Edge.wants(e) return e.edge == true end

function Edge.direct(fn, ...)
    if passDepth > 0 then return end                 -- (las copias del modo simple: solo el cuerpo)
    local f = top()
    if f and f.on then                               -- (modo shader: a la escena, no al lienzo de los personajes)
        f.on = false
        love.graphics.setCanvas(f.scene)
        local a, b, c = fn(...)
        f.on = true
        love.graphics.setCanvas(f.actor)
        return a, b, c
    end
    return fn(...)
end

-- UNA ESCENA SUELTA (cada plano de una cinemática: src/story/Film.lua): fn(...) se dibuja en un lienzo propio con una
-- escena abierta — los monstruos (Edge.draw) a los personajes, lo demás de fondo — y el resultado, ya con el filo, va
-- a donde se estaba dibujando. `o.simple` = el filo del modo simple, forzado mientras dura ('light': el monstruo es
-- casi negro y en las cinemáticas siempre lo llevaba)
local sceneCvs, forceKind = {}, nil
function Edge.scene(fn, o, ...)
    if Edge.mode() ~= 'shader' then
        local prevForce = forceKind
        forceKind = o and o.simple
        local ok, err = pcall(fn, ...)
        forceKind = prevForce
        if not ok then error(err, 0) end
        return
    end
    local d = depth + 1
    sceneCvs[d] = sized(sceneCvs[d], WINDOW_W, WINDOW_H)
    local cv = sceneCvs[d]
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    Edge.open(cv)
    local ok, err = pcall(fn, ...)
    if not ok then while depth >= d do depth = depth - 1 end; love.graphics.pop(); error(err, 0) end
    local out = Edge.finish(nil)
    love.graphics.pop()
    love.graphics.push('all')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(out, 0, 0)
    love.graphics.pop()
end

return Edge
