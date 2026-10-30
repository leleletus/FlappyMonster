-- LANZADO FUERTE CONTRA EL TECHO (2026-10-30, el usuario: "la mecánica de la balanza que usa el boss para hacerle daño
-- al jugador y que usa el jugador también para hacerle daño a él no se debe quedar solo en la pelea del boss: en
-- cualquier otra circunstancia en la que se use una balanza como catapulta, si se lanza muy fuerte a cualquier entidad
-- contra el techo, ésta debería quedar aturdida (y en el caso del jugador, recibir daño)").
-- Regla de la BASE, no de un tipo. Lo que dispara una catapulta (la Balanza: Scale:catapult / sweepPlayers; cualquier
-- otra catapulta llama a `mark` después de lanzar) queda MARCADO hasta que deja de subir. Si subiendo a más de
-- `MIN_VY` px/s algo de ARRIBA lo frena en seco (el techo, una casilla, un cuerpo):
--   · una entidad lanzada (estado 'launched' de Entity) → `e:onCeilingSmash(vy, level)`. Entity: aturdida con su
--     `knockback` si se puede (cada tipo con su aturdimiento: estrellitas; el Escarabajo, patas arriba); si no (una
--     caja, algo ya patas arriba), solo se para. Un jefe lo sobrescribe con lo suyo (el Escarabajo Gigante: su vuelco).
--   · un jugador → `player`: pierde 1 (reglas normales: invulnerable, no) y queda aturdido un momento (los mismos
--     valores que el golpe contra el techo de la pelea del Escarabajo Gigante, HIT_CEIL). Si lo disparó un jefe que
--     lleva la cuenta de a quién disparó (`onScaleCatapult`: el Escarabajo Gigante), el golpe es suyo y aquí no se hace.
-- Igual en un jugador, en el servidor y en el cliente: la catapulta no se predice (la mueve el servidor), así que en
-- línea el daño y el aturdimiento llegan en el estado propio (vida, hurtT, invT, stunT, ctrlLockT).
local H = {}

H.MIN_VY   = 250      -- px/s subiendo justo antes del frenazo: "fuerte" (el mismo umbral del Escarabajo Gigante)
H.STOP_VY  = -20      -- px/s: después, ya no sube (lo frenó algo)
H.HURT     = 1        -- vida que pierde el jugador
H.PUSH_VY  = 260      -- px/s: rebota hacia abajo
H.LOCK_T   = 0.3      -- s sin control
H.DAZE_T   = 0.6      -- s aturdido

-- Marca lo que una catapulta acaba de lanzar (después de su launch, que borra la marca). `by` = quien la disparó
function H.mark(o, by)
    o.hardLaunch, o.hardBy = true, by
end
function H.clear(o) o.hardLaunch, o.hardBy = nil, nil end

-- ¿Se acaba de estrellar subiendo? vy0 = la velocidad con la que empezó el paso; borra la marca al dejar de subir
function H.crashed(o, vy0)
    if vy0 >= 0 then H.clear(o); return false end
    if vy0 < -H.MIN_VY and (o.vy or 0) >= H.STOP_VY and not o.onGround then H.clear(o); return true end
    return false
end

-- El jugador (PlayerAdventure:update, tras moverse): vy0 = su vy antes de moverse
function H.player(pa, level, vy0)
    local by = pa.hardBy
    if not H.crashed(pa, vy0) then return false end
    if by and by.onScaleCatapult then return false end                -- (el jefe que lo disparó hace lo suyo)
    local pb = pa:getOuterBounds()
    if not (level:collisionAt(pa.x, pb.y - 6) or (level.bodyAt and level:bodyAt(pa.x, pb.y - 6))) then return false end
    local Entity = require 'src/world/entities/base/Entity'
    Sound.play('headBump')
    Entity.emitFx('shake_small', pa.x, pb.y)
    if pa.dying or pa.alive == false or pa:isInvulnerable() then return true end
    if pa:hurt(H.HURT) or pa.dying then return true end
    pa.vx, pa.vy = 0, H.PUSH_VY
    pa.onGround, pa.crouching = false, false
    pa.gpPhase, pa.gpT = nil, 0
    pa.ctrlLockT = math.max(pa.ctrlLockT or 0, H.LOCK_T)
    pa.stunT = math.max(pa.stunT or 0, H.DAZE_T)
    Sound.play('stunned')
    return true
end

return H
