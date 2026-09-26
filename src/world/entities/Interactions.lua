-- src/world/entities/Interactions.lua
-- Reglas jugador ↔ entidad, en UN solo lugar. Las usan el modo un jugador
-- (AdventureState), el servidor online y la predicción del cliente.
--
-- Interactions.check(player, entity) devuelve:
--   nil                           sin contacto relevante
--   'kill'                        el jugador muere (pinchos, entidad hostil)
--   'hurt'                        el jugador pierde 1 HP (entidad onTouch='hurt')
--   'stomp', bounceVy, points     el jugador pisotea a la entidad
--   'pickup'                      coleccionable (estrella, vida extra...)
--   'checkpoint'                  punto de control
--
-- Interactions.run(pa, entities, cb, rewind) aplica todo lo anterior (y el
-- impacto del ground pound) para un jugador; el juego solo pone los efectos
-- propios en `cb` (puntos, vidas, eventos online...).

local Interactions = {}

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and
           a.y < b.y + b.h and a.y + a.h > b.y
end

local BOUNCE = 0.40   -- fracción de la velocidad de salto al rebotar

function Interactions.check(pa, e)
    if not e.alive or e.state == 'dead' or (e.isGhost and e:isGhost()) then return nil end
    local pob = pa:getOuterBounds()

    -- Coleccionables y checkpoints: basta con tocarlos
    local def = e.def or {}
    if def.pickup or def.checkpoint then
        -- Margen de "imán": que no se escape por un píxel al pasar por debajo
        local b, m = e:getOuterBounds(), 12
        if overlap(pob, { x = b.x - m, y = b.y - m, w = b.w + 2 * m, h = b.h + 2 * m }) then
            return def.pickup and 'pickup' or 'checkpoint'
        end
        return nil
    end

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
        -- Ground pound: cae en picado; cualquier contacto desde arriba aplasta
        if pa.gpPhase == 'fall' and not e.flipped and pob.y + pob.h * 0.5 < gob.y + gob.h * 0.5 then
            return 'stomp', -math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
        end
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

-- Zona aplastada al impactar un ground pound: SOLO justo bajo los pies (lo
-- que queda debajo del jugador; lo de los lados solo sale despedido)
function Interactions.poundZone(pa)
    local ob = pa:getOuterBounds()
    return { x = ob.x + 4, y = ob.y + ob.h - 24, w = ob.w - 8, h = 30 }
end

-- Aplica las interacciones de un jugador con todas las entidades.
--   cb.stomp(e, points, i)  cb.pickup(e, pickupDef, i)  cb.checkpoint(e, i)
--   rewind(i, e, fn)        opcional (servidor): evalúa fn() con el estado
--                           del enemigo que veía el jugador
function Interactions.run(pa, entities, cb, rewind)
    if pa.dying or not pa.alive then return end
    for i, e in ipairs(entities) do
        local result, a, b
        if rewind then
            result, a, b = rewind(i, e, function() return Interactions.check(pa, e) end)
        else
            result, a, b = Interactions.check(pa, e)
        end
        if result == 'kill' then
            pa:die(); return
        elseif result == 'hurt' then
            if pa:hurt() then return end
        elseif result == 'stomp' then
            e:stomp()
            pa:bounce(a)
            if cb.stomp then cb.stomp(e, b, i) end
        elseif result == 'pickup' then
            if e:collect() and cb.pickup then cb.pickup(e, e.def.pickup, i) end
        elseif result == 'checkpoint' then
            if cb.checkpoint then cb.checkpoint(e, i) end
        end
    end
    -- Impacto del ground pound: muere solo lo que queda aplastado justo
    -- debajo; lo que está cerca sale despedido y queda aturdido, igual que
    -- los otros jugadores.
    if pa.gpLanded then
        local z = Interactions.poundZone(pa)
        local rx, ry = pa.GP_RADIUS_X or 170, pa.GP_RADIUS_Y or 110
        for i, e in ipairs(entities) do
            if e.alive and e.state ~= 'dead' and not (e.isGhost and e:isGhost()) then
                if e.props.stompable and e:canBeStomped() and overlap(z, e:getInnerBounds()) then
                    e:stomp()
                    if cb.stomp then cb.stomp(e, e.props.points, i) end
                else
                    local dx, dy = e.x - pa.x, e.y - pa.y
                    if math.abs(dx) <= rx and math.abs(dy) <= ry and e:canBeKnocked() then
                        e:knockback(dx >= 0 and 1 or -1)
                    end
                end
            end
        end
    end
end

return Interactions
