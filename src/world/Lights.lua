-- src/world/Lights.lua
-- LUZ en los niveles a oscuras (JSON `"dark": true`): la única luz son las LINTERNAS de los
-- jugadores (PlayerAdventure: lightOn / lightBat / lightCd). Aquí está la geometría, sin
-- nada de dibujo, para que la simulación (un jugador y servidor) y el dibujo (src/fx/
-- Darkness.lua) usen exactamente la misma luz:
--   Lights.RANGE, Lights.HALF     alcance y medio ángulo del cono (hacia donde mira)
--   Lights.ray(level, x, y, ang)  hasta dónde llega un rayo (los bloques sólidos lo cortan)
--   Lights.lit(level, x, y)       ¿le da la linterna de algún jugador de level.players?
--                                 → true, origenX, origenY (lo usa el Crabby lúgubre para huir)
local Lights = {}

local T = TILE_PX
Lights.RANGE = 5.2 * T            -- alcance de la linterna (corto: no quita la oscuridad)
Lights.HALF  = math.rad(27)       -- medio ángulo del cono
Lights.INTO  = 20                 -- px que la luz entra en la pared que la corta (se ve su cara)
local STEP = 16

local function blocks(level, x, y)
    local t = level:collisionAt(x, y)
    return t ~= nil and t ~= false and (type(t) ~= 'table' or t.collision == 'solid')
end

-- Alcance ahora: el grito del Mega Crabby lúgubre lo acorta un rato (level.lightScale)
function Lights.range(level) return Lights.RANGE * ((level and level.lightScale) or 1) end

-- Origen y dirección de la linterna de un jugador (o de sus datos: x, y, facing)
function Lights.origin(x, y, facing)
    return x + facing * 14, y - 22, (facing >= 0) and 0 or math.pi
end

-- Distancia que recorre un rayo desde (x, y) con ángulo `ang` hasta el primer bloque sólido
function Lights.ray(level, x, y, ang, range)
    range = range or Lights.range(level)
    local dx, dy = math.cos(ang), math.sin(ang)
    local d = 0
    while d < range do
        d = d + STEP
        if blocks(level, x + dx * d, y + dy * d) then return math.min(range, d + Lights.INTO), true end
    end
    return range, false
end

-- ¿El punto está dentro del cono de una linterna en (ox, oy) mirando a `dir` y sin pared en medio?
function Lights.inCone(level, ox, oy, dir, px, py)
    local dx, dy = px - ox, py - oy
    local d = math.sqrt(dx * dx + dy * dy)
    if d > Lights.range(level) then return false end
    if d > 8 then
        local a = math.atan2(dy, dx)
        local da = math.abs((a - dir + math.pi) % (2 * math.pi) - math.pi)
        if da > Lights.HALF then return false end
    end
    local n = math.floor(d / STEP)
    for i = 1, n - 1 do
        if blocks(level, ox + dx * i / n, oy + dy * i / n) then return false end
    end
    return true
end

function Lights.lit(level, px, py)
    for _, pa in ipairs(level.players or {}) do
        if pa.lightOn and not pa.dying and pa.alive ~= false then
            local ox, oy, dir = Lights.origin(pa.x, pa.y, pa.facing or 1)
            if Lights.inCone(level, ox, oy, dir, px, py) then return true, ox, oy end
        end
    end
    return false
end

return Lights
