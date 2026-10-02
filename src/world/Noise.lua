-- src/world/Noise.lua
-- RUIDOS que los enemigos pueden OÍR (el Crabby lúgubre caza de oído). Quien hace ruido llama a
-- Noise.emit(x, y, radio en casillas): saltos, ground pound, un golpe a un jugador, un
-- enemigo que muere, un bloque que se rompe... Se apuntan en el nivel que está simulando
-- (Noise.bind(level): lo pone el modo un jugador y el servidor en cada paso; en la predicción
-- del cliente no hay ninguno y no se apunta nada). Cada oyente recuerda el último que procesó
-- (`seq`) y mira los nuevos: level.noises = { seq = n, list = { {x, y, r, seq}, ... } }.
local Noise = {}

local KEEP = 24
-- Radio (casillas) de cada ruido. NO hay ruido de pasos: andar es silencioso (así se puede pasar
-- con sigilo y las marcas no llenan la pantalla). Saltar se oye cerca; un golpe, lejos.
Noise.R = { jump = 3.5, bump = 5, hurt = 9, kill = 9, tile = 10, pound = 15, boss = 22 }

function Noise.bind(level) Noise.level = level end

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
