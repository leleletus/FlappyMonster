-- src/ui/HitStop.lua
-- HIT-STOP: el juego se CONGELA unos fotogramas y sigue. Solo AL MORIR (0.5.189, el usuario: «no me termina de
-- convencer en los ground pounds, mejor solo al morir. Nada más»; en 0.5.188 también el ground pound, los golpes a un
-- jefe y el daño). Música y sonido siguen sonando.
--   · Un jugador: se congela de verdad (AdventureState:update no avanza).
--   · Online: SOLO EN LA PANTALLA de quien lo provoca — la partida sigue en el servidor y en los demás —: se mantiene la
--     última imagen de la escena y luego se pone al día. Nada de la simulación cambia: no se puede desincronizar.
--   · Entre uno y el siguiente, como poco COOLDOWN s (una cadena de golpes no se queda trabada).
--   · Opción Ajustes → CONGELAR LOS GOLPES (Settings.hitStop, sí por defecto).
--   HitStop.trigger(frames)   HitStop.step(dt) → true si este fotograma está congelado   HitStop.reset()
local HitStop = {}

HitStop.COOLDOWN = 0.15
HitStop.DEATH = 5                -- fotogramas (a 60 Hz) al morir

local left, cd = 0, 0

function HitStop.trigger(frames)
    local Settings = package.loaded['src/core/Settings']
    if Settings and Settings.hitStop == false then return end
    if left > 0 or cd > 0 then return end
    left = (frames or 3) / 60 - 1e-6        -- (sin el redondeo: 3 pasos de 1/60 s son 3 fotogramas, no 4)
end

function HitStop.step(dt)
    if left > 0 then
        left = left - dt
        if left <= 0 then left, cd = 0, HitStop.COOLDOWN end
        return true
    end
    if cd > 0 then cd = math.max(0, cd - dt) end
    return false
end

function HitStop.frozen() return left > 0 end
function HitStop.reset() left, cd = 0, 0 end

return HitStop
