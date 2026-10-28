-- src/world/systems/Carry.lua
-- CARGAR objetos (el usuario, 0.5.68): acercarse a algo que se puede cargar y pulsar ARRIBA (acción `grab`) lo coge y
-- lo lleva sobre la cabeza (también agachado); ARRIBA otra vez lo LANZA hacia delante (más lejos andando); AGACHADO +
-- ARRIBA lo DEJA con cuidado a su lado (para no hacer explotar nada); un GROUND POUND con él en las manos lo suelta
-- debajo... NO: lo sigue llevando (el impacto es del jugador: ni la caja se rompe ni la bomba se enciende; el usuario);
-- solo un tipo con `onCarriedPound` lo usa (la Semilla se planta). Lo lanzado no le da a quien lo lanzó (THROW_SAFE s).
-- Al acercarse sale encima del objeto la AYUDA con el botón de ARRIBA del aparato que se usa (teclado, mando, táctil).
--
-- Un sistema para todos: un tipo solo se declara `carryable = true` (clase) y, si quiere, los ganchos
--   canBeCarried()           ¿se puede coger ahora? (por defecto: vivo y en reposo)
--   onPickUp(pa)             al cogerlo
--   onThrow(pa, vx, vy)      al lanzarlo (por defecto: sale con esa velocidad, estado 'thrown' de su física)
--   onPutDown(pa)            al dejarlo a los pies
--   onCarriedPound(pa)       ground pound con él en las manos (sin él: no pasa nada, lo sigue llevando)
-- Mientras va en las manos la entidad no hace su paso (Entity:update → Carry.follow), no choca ni interactúa con
-- nadie y el aire no la mueve. Quien lo lleva: `e.carriedBy` (la simulación) y `e.carrierIdx` (lo que viaja: el
-- índice del jugador; 0 = nadie). Se suelta al morir quien lo lleva.
-- Dónde corre: Carry.step en un jugador (AdventureState) y en el servidor, tras mover a los jugadores; el cliente
-- solo dibuja (lo suyo, pegado a SU jugador predicho: Carry.clientFollow).
local Carry = {}

local REACH    = 28        -- px de margen alrededor del objeto para cogerlo
local THROW_VX = 430       -- px/s hacia delante al lanzar (+ la mitad de lo que corre)
local THROW_VY = -330
local THROW_SAFE = 0.5     -- s en los que lo lanzado no golpea a quien lo lanzó

local OB = {}
local function overlap(a, b, m)
    return a.x - m < b.x + b.w and a.x + a.w + m > b.x and a.y - m < b.y + b.h and a.y + a.h + m > b.y
end

function Carry.canTake(e)
    if not (e.carryable and e.alive) or e.carriedBy then return false end
    if e.canBeCarried then return e:canBeCarried() end
    return e.state ~= 'dead' and not (e.isGhost and e:isGhost())
end

-- Lo que el jugador tiene al alcance para coger (el más cercano), o nil
function Carry.reachable(pa, entities)
    if pa.dying or pa.carrying then return nil end
    local pb = pa:getOuterBounds(OB)
    local best, bd
    for _, e in pairs(entities or {}) do
        if Carry.canTake(e) and overlap(pb, e:getOuterBounds(), REACH) then
            local d = math.abs(e.x - pa.x) + math.abs(e.y - pa.y)
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

-- Dónde va lo que se lleva: sobre la cabeza de un jugador con el centro en (x, y)
function Carry.holdAt(x, y, e)
    local PA = require 'src/player/PlayerAdventure'
    local b = PA.outerBoxAt(x, y)
    return x, b.y - (e.outerH or TILE_PX) / 2 - 4             -- (un poco por encima de la cabeza: el usuario lo subió 10 px)
end

local function release(e, pa)
    e.carriedBy, e.carrierIdx = nil, 0
    if pa and pa.carrying == e then pa.carrying = nil end
    e.state = e.carryPrevState or e.state
    e.carryPrevState = nil
    e.onGround = false
end

function Carry.pickUp(pa, e)
    e.carriedBy, e.carrierIdx, pa.carrying = pa, pa.ownerIdx or 1, e
    e.carryPrevState = e.state
    e.state = 'carried'
    e.vx, e.vy = 0, 0
    Carry.follow(e)
    if e.onPickUp then e:onPickUp(pa) end
end

function Carry.throw(pa, e)
    release(e, pa)
    local dir = pa.facing or 1
    local vx = dir * (THROW_VX + math.abs(pa.vx or 0) * 0.5)
    e.thrownBy, e.thrownT = pa, THROW_SAFE
    if e.onThrow then e:onThrow(pa, vx, THROW_VY)
    else e.vx, e.vy = vx, THROW_VY end
end

-- Dejarlo con cuidado AL LADO (sin tocar al jugador: la bomba se enciende al tocarla), delante; si ahí hay pared,
-- detrás; si tampoco, a los pies
local GAP = 6
function Carry.putDown(pa, e, level)
    release(e, pa)
    local b = pa:getOuterBounds()
    local y = b.y + b.h - (e.outerH or 0) / 2 - 2
    local off = b.w / 2 + (e.outerW or 0) / 2 + GAP
    local x = pa.x
    for _, d in ipairs({ pa.facing or 1, -(pa.facing or 1) }) do
        local cx = pa.x + d * off
        local edge = cx + d * (e.outerW or 0) / 2
        if not (level and (level:entitySolidAt(edge, y) or level:entitySolidAt(cx, y))) then x = cx; break end
    end
    e.x, e.y = x, y
    e.vx, e.vy = 0, 0
    if e.onPutDown then e:onPutDown(pa) end
end

-- Un paso: lo que cada jugador pidió (pa.grabReq = ARRIBA, pa.grabCareful = agachado al pulsarlo, pa.gpLanded)
function Carry.step(level, players, entities)
    for _, pa in ipairs(players or {}) do
        local held = pa.carrying
        if held and (held.carriedBy ~= pa or not held.alive) then pa.carrying, held = nil, nil end
        if held and (pa.dying or not pa.alive) then Carry.putDown(pa, held, level); held = nil end
        if not pa.dying then
            if held and pa.gpLanded and held.onCarriedPound then
                -- (ground pound con algo en las manos: el impacto lo aguanta el JUGADOR y lo cargado sigue en sus manos
                -- — una caja no se rompe, una bomba no se enciende; el usuario —; solo lo que tiene su regla lo usa: la
                -- Semilla se planta)
                release(held, pa)
                local b = pa:getOuterBounds()
                held.x, held.y = pa.x, b.y + b.h - (held.outerH or 0) / 2 - 2
                held.vx, held.vy = 0, 0
                if held.onCarriedPound then held:onCarriedPound(pa) end
            elseif held and pa.grabReq and pa.grabCareful then
                Carry.putDown(pa, held, level)
            elseif held and pa.grabReq then
                Carry.throw(pa, held)
            elseif not held and pa.grabReq then
                local e = Carry.reachable(pa, entities)
                if e then Carry.pickUp(pa, e) end
            end
        end
        pa.grabReq, pa.grabCareful = false, false
    end
end

-- La entidad que se lleva va pegada a quien la lleva (Entity:update, en vez de su paso)
function Carry.follow(e)
    local pa = e.carriedBy
    if not pa then return end
    e.x, e.y = Carry.holdAt(pa.x, pa.y, e)
    e.facing = pa.facing or e.facing
end

-- Cliente online: lo que llevo YO va con mi jugador predicho (la instantánea iría por detrás)
function Carry.clientFollow(renderers, myIdx, x, y)
    if not myIdx then return end
    for _, e in pairs(renderers or {}) do
        if e.carryable and e.carrierIdx == myIdx then e.x, e.y = Carry.holdAt(x, y, e) end
    end
end

-- ── La ayuda (solo dibujo) ───────────────────────────────────────────────────
-- Encima de lo que el jugador local tiene al alcance: el botón de ARRIBA de su aparato, botando un poco.
-- assets/images/ui/prompts/grab-Sheet.png (tools/art/ui/make_prompts.py): 1 teclado, 2 mando, 3 táctil.
local sheet
function Carry.drawPrompt(pa, entities, camX, camY)
    if not pa or pa.dying then return end
    local e = Carry.reachable(pa, entities)
    if not e then return end
    sheet = sheet or require('src/fx/SpriteStrip').load('assets/images/ui/prompts/grab-Sheet.png', 16)
    local i = Input.isMobile and 3 or (Input.usingPad() and 2 or 1)
    local t = love.timer.getTime()
    local x = math.floor(e.x - camX)
    local y = math.floor(e.y - (e.outerH or TILE_PX) / 2 - camY - 34 - math.floor(math.abs(math.sin(t * 4)) * 6))
    love.graphics.setColor(1, 1, 1, 1)
    sheet:draw(i, x, y, 0, 3, 3)
end

return Carry
