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
    if m == 'shader' and not Shaders.get('silhouette_flat') then m = 'simple' end
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
    local kind = Edge.simpleKind(owner.edgeLevel or Edge.level, x, y)      -- (edgeLevel: un actor de cinemática)
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
    fn(0, 0, ...)
end

function Edge.direct(fn, ...)
    if passDepth > 0 then return end                 -- (las copias del modo simple: solo el cuerpo)
    return fn(...)
end

return Edge
