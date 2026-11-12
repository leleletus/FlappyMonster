-- src/fx/Edge.lua
-- EL BORDE DE CONTRASTE de los personajes (docs/design/entity-edge-shader.md): un filo claro u oscuro que separa al
-- jugador, a los enemigos, a los jefes y a los objetos de lo que tienen detrás, solo donde se pierden. Dos modos
-- (ajuste BORDE, pestaña AYUDAS; por defecto según el aparato):
--   'shader'  los personajes se dibujan en su propio lienzo; por cada uno se mira qué parte de su contorno se pierde
--             contra lo que tiene detrás (con la luz del nivel) y, si es bastante, el filo rodea TODO su sprite, con
--             fundido (ver «Modo shader»)
--   'simple'  (aparatos modestos) la silueta de siempre — 8 copias corridas de un color, src/fx/Silhouette.lua — en
--             todo personaje con el rasgo `edge`, clara donde está oscuro, con fundido; se decide por nivel y altura,
--             no por píxel
--
--   Edge.mode()                      'shader' | 'simple' (el ajuste, o el de su aparato; sin shaders, simple)
--   Edge.level                       el nivel que se está dibujando (lo pone quien dibuja la escena; nil fuera)
--   Edge.draw(owner, x, y, fn, ...)  dibuja a `owner` (en el mundo: x, y) con su borde; fn(dx, dy, ...) lo dibuja
--                                    corrido esos píxeles de pantalla
--   Edge.direct(fn, ...)             lo que dibuje fn(...) va SIN borde y DETRÁS de los personajes (sombras, el suelo)
--   Edge.over(fn, ...)               SIN borde y ENCIMA (estrellas de delante, nombres, focos, marcas, lo que cae)
--   Edge.simpleKind(level, x, y)     'light' | nil: ¿lleva el filo claro del modo simple en ese sitio?
local Silhouette = require 'src/fx/Silhouette'
local Shaders    = require 'src/fx/Shaders'

local Edge = {}

-- (escenas abiertas del modo shader — ver Edge.open —: aquí arriba porque Edge.draw las mira)
local stack, depth, actorPool, overPool, idPool = {}, 0, {}, {}, {}
local function top() return stack[depth] end
-- (el filo del modo simple forzado por una cinemática — Edge.scene —; un escenario de nivel dentro lo suspende)
local forceKind = nil

Edge.W     = 2                                   -- grosor (px de pantalla) en modo shader
Edge.T_LO, Edge.T_HI = 0.03, 0.10                -- diferencia de luminancia: filo entero / ninguno (antes 0.08 / 0.22: salía
                                                 -- demasiado; el usuario, 2026-11-12: "que requiera mucha más oscuridad")
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
local tintBuf = { 0, 0, 0, 0 }
local passDepth = 0
function Edge.inPass() return passDepth > 0 end

-- LAS COPIAS NO TIENEN EFECTOS: el dibujo de un jefe se llama 9 veces (8 copias + la de verdad) y muchos apuntan algo
-- al dibujar (cuánto se movió desde el dibujo anterior, cuándo soltó polvo...), sueltan partículas o tiran del azar.
-- Durante las copias: el shader plano no se cambia, las partículas no salen, el azar es otro (el de la partida no se
-- mueve: el fondo de los menús es una carrera fija) y lo que se apunte en el dueño se deshace al acabar.
local function keepFlat() end
local function keepBlend() end
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

-- Dibuja fn(dx, dy, ...) con `shader` puesto y SIN efectos (ver arriba): `dirs` = desplazamientos (las 8 copias del
-- modo simple) o nil (una vez, en su sitio: la pasada de identidad del modo shader). `keepBlendMode`: nada lo cambia
local ONE = { { 0, 0 } }
local function quietDraw(owner, shader, dirs, px, keepBlendMode, fn, ...)
    local prev = love.graphics.getShader()
    love.graphics.setShader(shader)
    Particles = Particles or require 'src/fx/Particles'
    local realSetShader, realBlend = love.graphics.setShader, love.graphics.setBlendMode
    local realEmit, realRandom = Particles.emit, math.random
    love.graphics.setShader, Particles.emit, math.random = keepFlat, noEmit, passRandom
    if keepBlendMode then love.graphics.setBlendMode = keepBlend end
    local _, _, _, sa = love.graphics.getColor()
    snapshot(owner)
    passDepth = passDepth + 1
    local ok, err = true, nil
    for _, d in ipairs(dirs or ONE) do
        love.graphics.setColor(1, 1, 1, sa)
        ok, err = pcall(fn, d[1] * px, d[2] * px, ...)
        if not ok then break end
    end
    passDepth = passDepth - 1
    restore(owner)
    love.graphics.setShader, love.graphics.setBlendMode = realSetShader, realBlend
    Particles.emit, math.random = realEmit, realRandom
    love.graphics.setShader(prev)
    if not ok then error(err, 0) end
end

local busy = setmetatable({}, { __mode = 'k' })     -- dueños que se están dibujando ahora (Edge.draw dentro de otro)
local function simpleDraw(owner, x, y, fn, ...)
    -- (dentro de las copias de otro, o el mismo dueño otra vez — una subclase que llama al dibujo de su base —: sin copias)
    if passDepth > 0 or busy[owner] then return fn(0, 0, ...) end
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
        tintBuf[1], tintBuf[2], tintBuf[3], tintBuf[4] = c[1], c[2], c[3], f.a * Edge.MAX_A
        flat:send('tint', tintBuf)
        quietDraw(owner, flat, DIRS, px, false, fn, ...)
        love.graphics.setColor(r, g, b, sa)
    end
    busy[owner] = true
    local ok, err = pcall(fn, 0, 0, ...)
    busy[owner] = nil
    if not ok then error(err, 0) end
end

local shaderBody                                     -- (modo shader: más abajo)
function Edge.draw(owner, x, y, fn, ...)
    if Edge.mode() == 'simple' then return simpleDraw(owner, x, y, fn, ...) end
    local f = top()
    if not f or passDepth > 0 or busy[owner] then return fn(0, 0, ...) end
    local cur = love.graphics.getCanvas()
    -- (una escena abierta y se dibuja EN ella: el cuerpo, al lienzo de los personajes; en otro lienzo — un reflejo, un
    -- lienzo propio de un jefe — se queda donde está)
    if cur == f.scene then
        f.on = true
        love.graphics.setCanvas(f.actor)
        shaderBody(f, owner, x, y, fn, ...)
        f.on = false
        love.graphics.setCanvas(f.scene)
        return
    elseif cur == f.actor then
        return shaderBody(f, owner, x, y, fn, ...)
    end
    fn(0, 0, ...)
end

-- Lo que se dibuje por fn(...) en una cinemática va con el filo forzado SUSPENDIDO (un escenario de nivel dentro)
function Edge.pauseForce() local p = forceKind; forceKind = nil; return p end
function Edge.resumeForce(p) forceKind = p end
function Edge.suspendForce(fn, ...)
    local p = Edge.pauseForce()
    local ok, err = pcall(fn, ...)
    Edge.resumeForce(p)
    if not ok then error(err, 0) end
end

-- ── Modo shader ──────────────────────────────────────────────────────────────
-- POR PERSONAJE, SPRITE ENTERO (el usuario, 2026-11-12: "lo hace o no lo hace, pero con el fundido"; antes se decidía
-- píxel a píxel y el filo salía solo en los trozos que se perdían):
--   1. Los personajes se dibujan en el LIENZO DE LOS PERSONAJES (transparente) y, otra vez y sin efectos, su NÚMERO en
--      el LIENZO DE IDENTIDAD (cada dueño tiene uno fijo mientras exista: hasta SLOTS).
--   2. Una pasada por personaje (un píxel de la textura de ESTADO por número) mira su zona: de los píxeles del CONTORNO,
--      cuántos se pierden — luminancia del personaje y del fondo parecidas, con la luz del sitio (a oscuras, fuera de la
--      luz, no cuenta: no delata) —. Si son al menos NEED, su filo va hacia 1; si no, hacia 0, en FADE s. El estado
--      (alfa del filo y si el fondo es oscuro → filo claro) vive en la GPU, de fotograma en fotograma: nada se lee.
--   3. La composición pone el filo alrededor de TODO el sprite con el alfa de su personaje.
-- Las pasadas leen la escena y escriben en su pareja: un shader no puede leer el lienzo en que dibuja.
Edge.NEED  = 0.3                                 -- parte del contorno que se pierde para que lleve el filo
Edge.SLOTS = 255                                 -- números de personaje (el 0 = ninguno; caben en un canal de 8 bits)
local GRID = 24                                  -- muestras por lado de la zona de cada personaje

Shaders.define('edge_id', [[
    extern float slot;
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
        if (Texel(t, uv).a < 0.02) discard;
        return vec4(slot / 255.0, 0.0, 0.0, 1.0);
    }
]])

Shaders.define('edge_decide', [[
    extern Image actors;
    extern Image scene;
    extern Image light;
    extern Image prev;
    extern vec2 lightK;
    extern vec2 texel;
    extern vec4 box;           // zona del personaje en uv: x0, y0, x1, y1
    extern vec4 th;            // T_LO, T_HI, L_LO, L_HI
    extern vec4 step;          // dt / FADE, reiniciar (1/0), NEED, W
    extern float statsW;       // ancho de la textura de estado (este píxel = sc.x)
    float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
    vec4 effect(vec4 col, Image t, vec2 uv, vec2 sc) {
        float total = 0.0, lost = 0.0, darkBg = 0.0;
        vec2 o1 = texel * step.w;
        for (int j = 0; j < ]]..GRID..[[; j++) {
            for (int i = 0; i < ]]..GRID..[[; i++) {
                vec2 p = mix(box.xy, box.zw, (vec2(float(i), float(j)) + 0.5) / ]]..GRID..[[.0);
                if (Texel(actors, p).a > 0.0) continue;
                vec4 q = Texel(actors, p + vec2(o1.x, 0.0));
                vec4 r = Texel(actors, p - vec2(o1.x, 0.0)); if (r.a > q.a) q = r;
                r = Texel(actors, p + vec2(0.0, o1.y)); if (r.a > q.a) q = r;
                r = Texel(actors, p - vec2(0.0, o1.y)); if (r.a > q.a) q = r;
                if (q.a <= 0.0) continue;
                float L = lum(Texel(light, p * lightK).rgb);
                float lb = lum(Texel(scene, p).rgb) * L;
                float c = abs(lum(q.rgb / q.a) * L - lb);
                total += 1.0;
                lost += (1.0 - smoothstep(th.x, th.y, c)) * smoothstep(th.z, th.w, L);
                darkBg += (lb < 0.5) ? 1.0 : 0.0;
            }
        }
        vec4 was = Texel(prev, vec2(sc.x / statsW, 0.5));
        float a = (step.y > 0.5) ? 0.0 : was.r;
        float want = (total > 0.0 && lost / total >= step.z) ? 1.0 : 0.0;
        a = (want > a) ? min(want, a + step.x) : max(want, a - step.x);
        float lightEdge = (total > 0.0) ? ((darkBg / total >= 0.5) ? 1.0 : 0.0) : was.g;
        return vec4(a, lightEdge, 0.0, 1.0);
    }
]])

Shaders.define('edge_composite', [[
    extern Image actors;
    extern Image ids;
    extern Image stats;
    extern vec2 texel;         // 1 / tamaño
    extern float W;
    extern float slots;        // ancho de la textura de estado
    extern vec3 lightC;
    extern vec3 darkC;
    extern float maxA;
    vec4 effect(vec4 col, Image scene, vec2 uv, vec2 sc) {
        vec4 s = Texel(scene, uv);
        vec4 a = Texel(actors, uv);
        if (a.a > 0.0) return vec4(a.rgb + s.rgb * (1.0 - a.a), a.a + s.a * (1.0 - a.a));
        float n = 0.0;
        vec2 at = uv;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                for (int k = 1; k <= 4; k++) {
                    if (float(k) > W) break;
                    vec2 q = uv + vec2(float(dx), float(dy)) * texel * float(k);
                    if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) continue;
                    float pa = Texel(actors, q).a;
                    if (pa > n) { n = pa; at = q; }
                }
            }
        }
        if (n <= 0.0) return s;
        float id = floor(Texel(ids, at).r * 255.0 + 0.5);
        if (id < 0.5) return s;
        vec4 st = Texel(stats, vec2((id + 0.5) / slots, 0.5));
        float k = st.r * maxA * n;
        if (k <= 0.0) return s;
        vec3 e = (st.g > 0.5) ? lightC : darkC;
        return vec4(s.rgb * (1.0 - k) + e * k, s.a * (1.0 - k) + k);
    }
]])

-- Números fijos por dueño (mientras exista): el estado de su filo es el píxel `slot` de la textura de estado
local slotOf = setmetatable({}, { __mode = 'k' })
local ownerOf = setmetatable({}, { __mode = 'v' })
local lastT, fresh, used = {}, {}, {}
local function slotFor(owner)
    local now = Edge.clock()
    local s = slotOf[owner]
    if s and ownerOf[s] == owner then used[s] = now; return s end
    -- (uno libre; si no queda ninguno — entidades de niveles anteriores que aún no recogió la basura —, el que lleva más
    -- tiempo sin dibujarse: su dueño, si vuelve, empieza de nuevo con el filo apagado)
    local pick, oldest = nil, math.huge
    for i = 1, Edge.SLOTS do
        if ownerOf[i] == nil then pick = i; break end
        if (used[i] or -math.huge) < oldest then pick, oldest = i, used[i] or -math.huge end
    end
    local old = ownerOf[pick]
    if old then slotOf[old] = nil end
    ownerOf[pick], slotOf[owner], fresh[pick], lastT[pick], used[pick] = owner, pick, true, nil, now
    return pick
end
Edge._slotFor = slotFor                             -- (para las pruebas)

-- La ZONA del personaje en pantalla (su caja de golpe con margen; sin ella, una de tamaño de monstruo): en el mundo
-- (x, y) y con la cámara de la escena (Edge.camX / camY; 0 donde todo va ya trasladado), por la transformación actual
Edge.camX, Edge.camY = 0, 0
local boundsBuf = {}
local function screenBox(owner, x, y)
    local bx, by, bw, bh
    if owner.getOuterBounds then
        local b = owner:getOuterBounds(boundsBuf)
        bx, by, bw, bh = b.x, b.y, b.w, b.h
    else
        bw, bh = owner.edgeW or 100, owner.edgeH or 130
        bx, by = x - bw / 2, y - bh / 2
    end
    local m = math.max(16, 0.4 * math.max(bw, bh))
    local x0, y0 = love.graphics.transformPoint(bx - m - Edge.camX, by - m - Edge.camY)
    local x1, y1 = love.graphics.transformPoint(bx + bw + m - Edge.camX, by + bh + m - Edge.camY)
    return math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1)
end

local idShader
shaderBody = function(f, owner, x, y, fn, ...)
    busy[owner] = true
    local ok, err = pcall(fn, 0, 0, ...)
    busy[owner] = nil
    if not ok then error(err, 0) end
    local slot = slotFor(owner)
    idShader = idShader or Shaders.get('edge_id')
    if not (slot and idShader) then return end
    local n = f.nSlots + 1
    f.nSlots = n
    local b = f.boxes[n] or {}
    f.boxes[n] = b
    b.slot, b[1], b[2], b[3], b[4] = slot, screenBox(owner, x, y)
    local cur = love.graphics.getCanvas()
    love.graphics.setCanvas(f.ids)
    local bm, am = love.graphics.getBlendMode()
    love.graphics.setBlendMode('replace', 'premultiplied')
    idShader:send('slot', slot)
    quietDraw(owner, idShader, nil, 0, true, fn, ...)
    love.graphics.setBlendMode(bm, am)
    love.graphics.setCanvas(cur)
end

local partner = setmetatable({}, { __mode = 'k' })  -- lienzo de la escena → su pareja (mismo tamaño)
local whiteImg
local function sized(cv, w, h)
    if cv and cv:getWidth() == w and cv:getHeight() == h then return cv end
    local c = love.graphics.newCanvas(w, h)
    c:setFilter('nearest', 'nearest')
    return c
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
    idPool[depth] = sized(idPool[depth], w, h)
    f.scene, f.actor, f.ids, f.on, f.overUsed = scene, actorPool[depth], idPool[depth], false, false
    f.nSlots, f.boxes = 0, f.boxes or {}
    love.graphics.setCanvas(f.ids)
    love.graphics.clear(0, 0, 0, 0)
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

-- La textura de ESTADO (alfa del filo y color por número), en dos para ir y volver
local statsA, statsB
local buf2a, buf2b, buf4a, buf4b, buf4c = { 0, 0 }, { 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
local function statsCanvas()
    if not statsA then
        statsA = sized(nil, Edge.SLOTS + 1, 1)
        statsB = sized(nil, Edge.SLOTS + 1, 1)
        for _, c in ipairs({ statsA, statsB }) do love.graphics.setCanvas(c); love.graphics.clear(0, 0, 0, 1) end
    end
    return statsA
end
function Edge.stateOf(owner)                         -- (para las pruebas: alfa y ¿filo claro? del modo shader)
    local s = slotOf[owner]
    if not (s and statsA) then return 0, 0 end
    local r, g = statsA:newImageData():getPixel(s, 0)
    return r, g
end

local function whiteTex()
    if not whiteImg then
        local d = love.image.newImageData(1, 1); d:setPixel(0, 0, 1, 1, 1, 1)
        whiteImg = love.graphics.newImage(d)
    end
    return whiteImg
end

-- Decide el filo de cada personaje dibujado en esta escena (ver arriba)
local function decide(f, scene, light, w, h)
    local sh = Shaders.get('edge_decide')
    if not sh or f.nSlots == 0 then return end
    statsCanvas()
    local now = Edge.clock()
    love.graphics.setCanvas(statsB)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.setShader()
    love.graphics.draw(statsA, 0, 0)                -- (los que no se dibujan ahora se quedan como estaban)
    love.graphics.setShader(sh)
    sh:send('actors', f.actor)
    sh:send('scene', scene)
    sh:send('light', light or whiteTex())
    sh:send('prev', statsA)
    if light then buf2a[1], buf2a[2] = w / (light:getWidth() * 4), h / (light:getHeight() * 4) else buf2a[1], buf2a[2] = 1, 1 end
    sh:send('lightK', buf2a)
    buf2b[1], buf2b[2] = 1 / w, 1 / h
    sh:send('texel', buf2b)
    buf4a[1], buf4a[2], buf4a[3], buf4a[4] = Edge.T_LO, Edge.T_HI, Edge.L_LO, Edge.L_HI
    sh:send('th', buf4a)
    sh:send('statsW', Edge.SLOTS + 1)
    for i = 1, f.nSlots do
        local b = f.boxes[i]
        local s = b.slot
        local dt = lastT[s] and math.max(0, math.min(Edge.FADE, now - lastT[s])) or 0
        lastT[s] = now
        buf4b[1], buf4b[2], buf4b[3], buf4b[4] = b[1] / w, b[2] / h, b[3] / w, b[4] / h
        sh:send('box', buf4b)
        buf4c[1], buf4c[2], buf4c[3], buf4c[4] = dt / Edge.FADE, fresh[s] and 1 or 0, Edge.NEED, Edge.W
        sh:send('step', buf4c)
        fresh[s] = nil
        love.graphics.rectangle('fill', s, 0, 1, 1)
    end
    statsA, statsB = statsB, statsA
    love.graphics.setShader()
end

-- Junta la escena y los personajes con el filo en la pareja de la escena; la deja de destino y la devuelve
function Edge.finish(light)
    local f = top()
    depth = depth - 1
    local scene, actorCv, overCv = f.scene, f.actor, f.overUsed and f.over
    local w, h = scene:getDimensions()
    local out = sized(partner[scene], w, h)
    partner[scene] = out
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
    decide(f, scene, light, w, h)
    local sh = Shaders.get('edge_composite')
    sh:send('actors', actorCv)
    sh:send('ids', f.ids)
    sh:send('stats', statsCanvas())
    buf2b[1], buf2b[2] = 1 / w, 1 / h
    sh:send('texel', buf2b)
    sh:send('W', Edge.W)
    sh:send('slots', Edge.SLOTS + 1)
    sh:send('lightC', Edge.LIGHT)
    sh:send('darkC', Edge.DARK)
    sh:send('maxA', Edge.MAX_A)
    love.graphics.setCanvas(out)
    love.graphics.setShader(sh)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.draw(scene, 0, 0)
    love.graphics.setShader()
    if overCv then                                   -- (lo de ENCIMA de los personajes: Edge.over)
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(overCv, 0, 0)
    end
    love.graphics.pop()
    f.scene, f.actor, f.ids, f.on, f.overUsed, f.nSlots = nil, nil, nil, false, false, 0
    love.graphics.setCanvas(out)
    return out
end

-- ¿Es una FUENTE DE LUZ ahora? (el usuario, 2026-11-12: el Saltarín de cueva con su farol no lleva filo: él es la
-- luz). Genérico: una entidad cuya `lights()` da alguna luz centrada en ella (dentro de su caja, con margen); las que
-- da lejos — las bolas de fuego del mortero — no cuentan
local litBuf = {}
function Edge.selfLit(e)
    if not e.lights then return false end
    local list = e:lights()
    if not list or #list == 0 then return false end
    local bx, by, bw, bh
    if e.getOuterBounds then
        local b = e:getOuterBounds(litBuf)
        bx, by, bw, bh = b.x, b.y, b.w, b.h
    else
        bx, by, bw, bh = (e.x or 0) - 32, (e.y or 0) - 32, 64, 64
    end
    local m = 0.5 * math.max(bw, bh)
    for _, L in ipairs(list) do
        local lx, ly = L.x or e.x, L.y or e.y
        if lx >= bx - m and lx <= bx + bw + m and ly >= by - m and ly <= by + bh + m then return true end
    end
    return false
end

-- ¿Va al lienzo de los personajes? (modo shader y el rasgo `edge`)
function Edge.wants(e) return e.edge == true end

function Edge.direct(fn, ...)
    if passDepth > 0 then return end                 -- (las copias del modo simple: solo el cuerpo)
    local f = top()
    if f and f.on and love.graphics.getCanvas() == f.actor then   -- (modo shader: a la escena, no a los personajes)
        f.on = false
        love.graphics.setCanvas(f.scene)
        local a, b, c = fn(...)
        f.on = true
        love.graphics.setCanvas(f.actor)
        return a, b, c
    end
    return fn(...)
end

-- Lo que dibuje fn(...) va SIN borde y ENCIMA de los personajes (estrellas de delante, nombres, focos, lo que cae
-- encima): en modo shader, a un lienzo que se pone sobre la escena ya juntada; si no, como Edge.direct
function Edge.over(fn, ...)
    if passDepth > 0 then return end
    local f = top()
    local cur = love.graphics.getCanvas()
    if f and (cur == f.actor or cur == f.scene) then
        if not f.overUsed then
            local w, h = f.scene:getDimensions()
            overPool[depth] = sized(overPool[depth], w, h)
            f.over, f.overUsed = overPool[depth], true
            love.graphics.setCanvas(f.over)
            love.graphics.clear(0, 0, 0, 0)
        end
        love.graphics.setCanvas(f.over)
        local a, b, c = fn(...)
        love.graphics.setCanvas(cur)
        return a, b, c
    end
    return fn(...)
end

-- UNA ESCENA SUELTA (cada plano de una cinemática: src/story/Film.lua): fn(...) se dibuja en un lienzo propio con una
-- escena abierta — los monstruos (Edge.draw) a los personajes, lo demás de fondo — y el resultado, ya con el filo, va
-- a donde se estaba dibujando. `o.simple` = el filo del modo simple, forzado mientras dura ('light': el monstruo es
-- casi negro y en las cinemáticas siempre lo llevaba)
local sceneCvs = {}
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
    local pcx, pcy = Edge.camX, Edge.camY
    Edge.camX, Edge.camY = 0, 0
    Edge.open(cv)
    local ok, err = pcall(fn, ...)
    Edge.camX, Edge.camY = pcx, pcy
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
