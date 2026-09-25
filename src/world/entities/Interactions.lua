-- src/world/entities/Interactions.lua
-- Reglas jugador ↔ entidad, en UN solo lugar. Las usan el modo un jugador
-- (AdventureState), el servidor online y la predicción del cliente.
--
-- Interactions.check(player, entity) devuelve:
--   nil                           sin contacto relevante
--   'kill'                        el jugador muere (pinchos, entidad hostil)
--   'hurt'                        el jugador pierde 1 HP (entidad onTouch='hurt')
--   'stomp', bounceVy, points     el jugador pisotea a la entidad

local Interactions = {}

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and
           a.y < b.y + b.h and a.y + a.h > b.y
end

local BOUNCE = 0.40   -- fracción de la velocidad de salto al rebotar

function Interactions.check(pa, e)
    if not e.alive or e.state == 'dead' then return nil end
    local pob = pa:getOuterBounds()

    -- Zonas de peligro propias (p. ej. el pincho del Crabby): siempre matan
    for _, hb in ipairs(e:getHazardBoxes() or {}) do
        if overlap(pob, hb) then return 'kill' end
    end

    if e:isBodyDisabled() then return nil end

    local gib = e:getInnerBounds()
    if not overlap(pob, gib) then return nil end

    local p = e.props
    if p.stompable then
        local gob = e:getOuterBounds()
        if e.flipped then
            -- Boca abajo (techo): se pisotea desde abajo, subiendo
            if pa.vy < 0 and pob.y > gob.y + gob.h * 0.65 - 10 then
                return 'stomp', math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
            end
        else
            if pa.vy > 0 and pob.y + pob.h < gob.y + gob.h * 0.35 + 10 then
                return 'stomp', -math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
            end
        end
    end

    if p.onTouch == 'none' then return nil end
    return p.onTouch
end

return Interactions
