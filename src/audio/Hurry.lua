-- src/audio/Hurry.lua
-- ¡DATE PRISA! (0.5.215; el usuario: un jingle de aviso cuando falta poco para que acabe el nivel y, desde ahí, la
-- música más rápida). Al quedar AT segundos del límite del nivel (Sim.limitOf: 10 min, o el `timeLimit` del nivel):
-- suena el jingle `hurryUp` (assets/sounds/jingles/hurry.wav, tools/sounds/hurry.py), la música baja mientras suena y
-- vuelve RATE veces más rápida (Sound.setMusicRate: LÖVE sube también el tono — el clásico «¡deprisa!» —). Un jugador y
-- el cliente online (cada uno con su reloj); el servidor no suena. Solo sonido.
--   Hurry.update(owner, timeLeft, dt)   cada fotograma (owner = el estado: guarda su aviso)
--   Hurry.reset(owner)                  al salir / volver a empezar: la música a su velocidad
local Hurry = {}

Hurry.AT   = 60           -- s que faltan cuando avisa (cuando el reloj del HUD se pone rojo)
Hurry.RATE = 1.15         -- la música, así de rápida desde el aviso
Hurry.DUCK = 1.2          -- s con la música baja mientras suena la alarma (dura 1,19 s)
Hurry.DUCK_K = 0.3        -- … a este tanto de su volumen

function Hurry.update(owner, timeLeft, dt)
    local h = owner._hurry
    if not h then
        if not timeLeft or timeLeft > Hurry.AT or timeLeft <= 0 then return end
        h = { t = 0, vol = Sound.musicVolume() }
        owner._hurry = h
        Sound.play('hurryUp')
        Sound.setMusicVolume(h.vol * Hurry.DUCK_K)
        Sound.setMusicRate(Hurry.RATE)
        return
    end
    if h.t < Hurry.DUCK then
        h.t = h.t + (dt or 0)
        if h.t >= Hurry.DUCK then Sound.setMusicVolume(h.vol) end      -- (vuelve, ya rápida)
    end
end

function Hurry.reset(owner)
    local h = owner._hurry
    if h and h.t < Hurry.DUCK then Sound.setMusicVolume(h.vol) end
    owner._hurry = nil
    Sound.setMusicRate(1)
end

-- ¿Ya avisó? (las pruebas)
function Hurry.active(owner) return owner._hurry ~= nil end

return Hurry
