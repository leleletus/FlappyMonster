-- src/world/entities/base/Sled.lua
-- EL TRINEO: lo que se tumba, DESLIZA con impulso y se puede MONTAR. Genérico: un tipo lo enciende con
-- `Sled.mixin(Clase, { states = {…}, top = px, w = px })` y lo mueve con `Sled.move`; no nombra a ningún tipo. Lo usa el
-- Pingüino (types/enemies/penguin.lua): aturdido de barriga es un trineo.
--   · PLATAFORMA: en los estados `states` aporta una pieza (bodyParts: `oneway` + `moves`, docs/gameplay/carry-and-
--     push.md) de `w` px de ancho cuya cara de arriba está `top` px sobre sus pies. Un jugador de pie en ella va con
--     ella (PlayerAdventure: `standBody` / `rideBody`, igual que en un platillo de la Balanza), en un jugador, el servidor
--     y la predicción del cliente (la pieza sale del estado y la posición, que viajan en las instantáneas).
--   · JINETE: `Sled.rider(e, level)` = el jugador de pie en su pieza (la simulación decide con él: empezar a correr,
--     acabar el viaje cuando se baja); `Sled.buck(e, level, vy)` lo tira (al levantarse).
--   · DESLIZAR (`Sled.move`): la velocidad de lado se mantiene (en el suelo, con el rozamiento que se pida × el de su
--     material: en el hielo casi nada), al salir de un borde sigue HANG s sin caer (el impulso cruza un hueco pequeño),
--     sube escalones de hasta STEP px y REBOTA en las paredes (devuelve 'wall'). Sin dibujo: solo simulación.
-- El tipo debe tener la altura de su caja (`outerH`) fija (los pies = y + outerH/2) y `freeOfRoute()` cierto mientras
-- desliza (si no, el límite de su ruta lo para como una pared).
local Entity = require 'src/world/entities/base/Entity'

local Sled = {}
Sled.V        = 380        -- px/s: montado (el jugador corre a 240)
Sled.HANG     = 0.12       -- s sin caer al salir de un borde
Sled.STEP     = 14         -- px: el escalón más alto que sube deslizando
Sled.BOUNCE_K = 0.85       -- × la velocidad al rebotar en una pared
Sled.MIN_V    = 30         -- px/s: más despacio que esto, se para

local EMPTY = {}

-- Enciende el trineo en la clase. cfg = { states = { estado = true, … }, top = px, w = px }
function Sled.mixin(Class, cfg)
    Class.sledCfg = cfg
    Class.bodyParts = Sled.bodyParts
end

-- (los pies: la caja de movimiento tiene la altura fija)
local function feetY(e) return e.y + e.outerH / 2 end

-- La pieza (una por instancia: la misma tabla siempre, así `standBody` la reconoce paso a paso)
function Sled.part(e)
    local p = e.sledPart
    if p then return p end
    p = { owner = e, solidFull = true, oneway = true, moves = true, alive = true }
    function p.getOuterBounds(_, into)
        local c = e.sledCfg
        return Entity.box(into, e.x - c.w / 2, feetY(e) - c.top, c.w, c.top)
    end
    e.sledPart = p
    return p
end

-- (Entities.solidBodies) la pieza, solo en los estados de trineo. Al volver a aparecer no arrastra a nadie por lo
-- que se movió mientras no estaba (Entities: `lastBX`)
function Sled.bodyParts(e)
    local p = Sled.part(e)
    if e.alive and e.sledCfg.states[e.state] then
        if not p.on then p.lastBX, p.lastBY, p.on = nil, nil, true end
        p.list = p.list or { p }
        return p.list
    end
    p.on = false
    return EMPTY
end

-- El jugador de pie en la pieza (o nil)
function Sled.rider(e, level)
    local p = e.sledPart
    if not p or not p.on then return nil end
    for _, pa in ipairs(level.players or EMPTY) do
        if pa.standBody == p and not pa.dying and pa.alive ~= false then return pa end
    end
    return nil
end

-- Tira a quien esté encima: un saltito (vy) hacia atrás
function Sled.buck(e, level, vy)
    local p = e.sledPart
    if not p then return end
    for _, pa in ipairs(level.players or EMPTY) do
        if pa.standBody == p and not pa.dying then
            pa.standBody = nil
            pa:bounce(vy or -320, -(e.facing or 1), true)
        end
    end
end

-- Rozamiento del suelo que pisa (el del material: hielo 0.2; nada = 1)
function Sled.friction(e, level)
    local m = e:groundMat(level)
    return (m and m.friction) or 1
end

-- Desliza un paso. fric = rozamiento por segundo en el suelo (× el del material; 0 = sin frenar). Devuelve 'wall' si
-- rebotó en una pared, 'air' en el aire, nil si no
function Sled.move(e, level, dt, fric)
    if e.onGround then
        e.hangT = Sled.HANG
        if fric and fric > 0 then e.vx = e.vx * math.max(0, 1 - fric * Sled.friction(e, level) * dt) end
        if math.abs(e.vx) < Sled.MIN_V then e.vx = 0 end
    end
    -- (recién salido de un borde sin subir: un momento sin caer)
    if not e.onGround and (e.hangT or 0) > 0 and e.vy >= 0 then
        e.hangT, e.vy = e.hangT - dt, 0
    else
        if not e.onGround then e.hangT = 0 end
        e.vy = e.vy + ADV_GRAVITY * dt
    end
    local vx0, f = e.vx, e.facing or 1
    local x0, y0, vy0, g0 = e.x, e.y, e.vy, e.onGround
    e:moveAndCollide(level, vx0 * dt, e.vy * dt)
    if vx0 ~= 0 and e.vx ~= vx0 then
        -- chocó de lado: ¿un escalón bajo? sube y sigue; si no, rebota
        local hx, hy, hvy, hg = e.x, e.y, e.vy, e.onGround
        e.x, e.y, e.vy = x0, y0, 0
        e:moveAndCollide(level, 0, -Sled.STEP)
        local up = y0 - e.y
        e.vx = vx0
        if up >= Sled.STEP - 0.5 then e:moveAndCollide(level, vx0 * dt, 0) end
        if up >= Sled.STEP - 0.5 and e.vx == vx0 then
            e:moveAndCollide(level, 0, Sled.STEP + 1)
            e.vy = math.max(0, vy0)
            if not e.onGround then e.onGround = g0 end
            e.facing = f
            return nil
        end
        e.x, e.y, e.vy, e.onGround = hx, hy, hvy, hg
        e.vx, e.facing = -vx0 * Sled.BOUNCE_K, -f
        return 'wall'
    end
    if e.vx ~= 0 then e.facing = e.vx > 0 and 1 or -1 else e.facing = f end
    return (not e.onGround) and 'air' or nil
end

return Sled
