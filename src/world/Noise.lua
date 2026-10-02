-- src/world/Noise.lua
-- RUIDOS que los enemigos pueden OÍR (el Crabby lúgubre caza de oído). Quien hace ruido llama a
-- Noise.emit(x, y, radio en casillas): pasos, saltos, ground pound, un golpe a un jugador, un
-- enemigo que muere, un bloque que se rompe... Se apuntan en el nivel que está simulando
-- (Noise.bind(level): lo pone el modo un jugador y el servidor en cada paso; en la predicción
-- del cliente no hay ninguno y no se apunta nada). Cada oyente recuerda el último que procesó
-- (`seq`) y mira los nuevos: level.noises = { seq = n, list = { {x, y, r, seq}, ... } }.
local Noise = {}

local KEEP = 24
Noise.R = { step = 2.5, jump = 3.5, land = 4, bump = 5, hurt = 9, kill = 9, tile = 10, pound = 15, boss = 22 }

function Noise.bind(level) Noise.level = level end

function Noise.emit(x, y, r)
    local level = Noise.level
    if not level or not x then return end
    local n = level.noises
    if not n then n = { seq = 0, list = {} }; level.noises = n end
    n.seq = n.seq + 1
    n.list[#n.list + 1] = { x = x, y = y, r = r * TILE_PX, seq = n.seq }
    if #n.list > KEEP then table.remove(n.list, 1) end
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
