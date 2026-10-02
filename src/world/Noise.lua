-- src/world/Noise.lua
-- RUIDOS que los enemigos pueden OÍR (los Crabbies lúgubres cazan de oído; el jugador puede usar
-- un ruido para DISTRAERLOS: van a mirar donde sonó). Se apuntan en el nivel que está simulando
-- (Noise.bind(level): lo pone el modo un jugador y el servidor en cada paso; en la predicción
-- del cliente no hay ninguno y no se apunta nada). Cada oyente recuerda el último que procesó
-- (`seq`) y mira los nuevos: level.noises = { seq = n, list = { {x, y, r, seq}, ... } }.
--
-- TODO lo que suena y con qué FUERZA (radio en casillas) se decide AQUÍ, en dos tablas:
--   Noise.R       lo que no es un sonido de una entidad: lo emite quien lo hace con
--                 Noise.emit(x, y, Noise.R.algo) (el jugador, los bloques, coger algo).
--   Noise.SOUNDS  SONIDOS que además son ruido: cualquier Sound.play de ese sonido hecho por una
--                 entidad (o por el nivel) mientras simula suelta su ruido solo, donde está quien
--                 lo hace. Una entidad nueva no toca este archivo: declara en su tipo
--                 `noises = { suSonido = casillas }` (lo registra EntityTypes) o, si se coge,
--                 `noise = casillas`.
-- De dónde sale: Noise.src (lo pone Interactions.run con la entidad que trata) o, si no, el
-- emisor de Sound (los estados lo ponen alrededor del update de cada entidad). Sin sitio, nada
-- (interfaz, música, sonidos propios del jugador).
local Noise = {}

local KEEP = 24
-- Andar y SALTAR no hacen ruido (así se puede pasar con sigilo y las marcas no llenan la
-- pantalla). De menos a más: coger algo < un interruptor < dar un golpe a un jefe < romper un
-- bloque < recibir un golpe < matar a un enemigo < un ground pound.
-- `faint` = la marca de la ecolocalización del jefe (no es un ruido del jugador).
Noise.R = { faint = 3.5, pickup = 4, life = 5, crack = 4, switch = 7, hit = 8, icebreak = 8, tile = 9, hurt = 10,
            kill = 12, pound = 15, boss = 22 }

Noise.SOUNDS = {
    trampoline = 8, helmetBounce = 6, helmetBreak = 8,
    mortarShoot = 10, spikeHit = 8, cryoBlast = 9, pufferInflate = 7,
    bombIgnite = 4, bombKick = 6, bombBlast = 26,                     -- (una explosión se oye en media cueva)
}

-- Más sonidos que son ruido (los tipos de entidad: `noises`)
function Noise.register(t)
    for name, r in pairs(t or {}) do Noise.SOUNDS[name] = r end
end

-- Engancha el Sound global de ahora (el de verdad, el del servidor o el de una prueba): cada
-- Sound.play de un sonido de Noise.SOUNDS suelta su ruido
local function hook()
    local S = Sound
    if not S or not S.play or S._noisePlay == S.play then return end
    local play = S.play
    S.play = function(name, ...)
        local r = Noise.SOUNDS[name]
        if r and Noise.level then
            local x, y = Noise.srcX, Noise.srcY
            if not x and S.getEmitter then x, y = S.getEmitter() end
            if x then Noise.emit(x, y, r) end
        end
        return play(name, ...)
    end
    S._noisePlay = S.play
end

function Noise.bind(level)
    Noise.level = level
    if level then hook() end
end

-- Quién está haciendo ruido ahora (nil = nadie en particular: vale el emisor de Sound)
function Noise.src(x, y) Noise.srcX, Noise.srcY = x, y end

-- Apunta el ruido (solo en niveles a oscuras: es donde hay quien lo oiga) y suelta su MARCA: un
-- "!" rojo en el sitio, con un aro hasta donde se oye (fx 'noise_s' / 'noise_m' / 'noise_l' →
-- src/fx/NoiseMarks.lua; llega igual a los clientes online). Así el jugador ve qué ha hecho
-- ruido, dónde y hasta dónde: es adonde irán los Crabbies lúgubres.
-- `quiet` = sin marca (el golpe del propio jefe, que ya se ve).
function Noise.emit(x, y, r, quiet)
    local level = Noise.level
    if not level or not level.dark or not x or not r then return end
    local n = level.noises
    if not n then n = { seq = 0, list = {} }; level.noises = n end
    n.seq = n.seq + 1
    n.list[#n.list + 1] = { x = x, y = y, r = r * TILE_PX, seq = n.seq }
    if #n.list > KEEP then table.remove(n.list, 1) end
    if not quiet then
        local Entity = require 'src/world/entities/Entity'
        Entity.emitFx((r >= 12) and 'noise_l' or ((r >= 6) and 'noise_m' or 'noise_s'), x, y)
    end
end

-- El ruido nuevo (posterior a `since`) más fuerte que se oye desde (x, y) con un oído `k`
-- (multiplica el radio: 1 = normal). Devuelve el ruido y el último seq visto.
function Noise.heard(level, x, y, since, k)
    local n = level and level.noises
    if not n then return nil, since or 0 end
    local best, bs
    for _, z in ipairs(n.list) do
        if z.seq > (since or 0) then
            local d = math.sqrt((z.x - x) ^ 2 + (z.y - y) ^ 2)
            local r = z.r * (k or 1)
            if d <= r then
                local s = r - d                                   -- cuánto "sobra": lo fuerte que llega
                if not bs or s > bs then best, bs = z, s end
            end
        end
    end
    return best, n.seq
end

return Noise
