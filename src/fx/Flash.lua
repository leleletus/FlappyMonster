-- src/fx/Flash.lua
-- DESTELLOS Y PARPADEOS, con la opción de accesibilidad (0.5.208, Opciones → ACCESIBILIDAD → DESTELLOS; docs/design/
-- accessibility.md): con ella apagada, nada parpadea deprisa (los jefes golpeados, el jugador invulnerable) — se ve
-- FIJO — y los destellos de pantalla se quedan suaves. Solo dibujo.
--   Flash.on()            ¿destellos como siempre?
--   Flash.blink(hz[, t])  el parpadeo de hz veces por segundo: true / false; sin destellos, siempre true (fijo)
--   Flash.alpha(a)        la opacidad de un destello de pantalla (sin destellos: un tercio)
local Flash = {}

function Flash.on()
    local S = package.loaded['src/core/Settings']
    return not (S and S.flashes == false)
end

function Flash.blink(hz, t)
    if not Flash.on() then return true end
    return math.floor((t or love.timer.getTime()) * hz) % 2 == 0
end

function Flash.alpha(a)
    return Flash.on() and a or a / 3
end

return Flash
