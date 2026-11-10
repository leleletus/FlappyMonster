-- src/core/Rumble.lua
-- VIBRACIÓN (0.5.188): el mando vibra con los golpes fuertes — un ground pound que aterriza, un golpe recibido, los
-- temblores de pantalla de explosiones y jefes (Particles: shake_*) —; en un móvil sin mando, el teléfono. Opción
-- Settings.rumble (Ajustes → VIBRACIÓN, sí por defecto). Solo en el cliente: el servidor no tiene mandos.
--   Rumble.play(strength 0..1, seconds)
local Rumble = {}

Rumble.MAX_T = 0.6                     -- s como mucho (por si alguien pide de más)
local mobile

function Rumble.play(strength, secs)
    local Settings = package.loaded['src/core/Settings']
    if Settings and Settings.rumble == false then return end
    if not (love.joystick and strength and strength > 0) then return end
    strength = math.min(1, strength)
    secs = math.min(Rumble.MAX_T, secs or 0.15)
    local any = false
    for _, j in ipairs(love.joystick.getJoysticks()) do
        if j:isVibrationSupported() then
            -- (motor grande = el golpe; el pequeño, algo menos: se nota más "seco")
            j:setVibration(strength, strength * 0.7, secs)
            any = true
        end
    end
    if not any then
        if mobile == nil then
            local os = love.system and love.system.getOS()
            mobile = os == 'Android' or os == 'iOS'
        end
        -- (el teléfono no tiene fuerza: solo los golpes que importan, y cortos)
        if mobile and strength >= 0.4 and love.system.vibrate then love.system.vibrate(math.min(secs, 0.12)) end
    end
end

-- Lo que hace el propio jugador (PlayerAdventure.fx, solo el jugador de este aparato)
local FX = { gp_land = { 0.55, 0.16 } }
function Rumble.onPlayerFx(kind)
    local r = FX[kind]
    if r then Rumble.play(r[1], r[2]) end
end

-- Le bajó la vida al jugador de este aparato
function Rumble.hurt() Rumble.play(0.7, 0.22) end

return Rumble
