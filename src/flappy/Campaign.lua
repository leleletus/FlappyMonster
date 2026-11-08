-- src/flappy/Campaign.lua
-- LA CAMPAÑA FLAPPY (la precuela: docs/design/flappy-prequel.md) y EL CANDADO DE AVENTURA.
--   · READY: la campaña ya se puede jugar y terminar. Mientras sea false (hoy) el candado de Aventura está apagado
--     y CLÁSICO ofrece todavía el modo infinito: así los probadores no se quedan sin Aventura ni sin Flappy.
--     Se pone a true cuando la campaña tenga final (paso 3+ del plan).
--   · Aventura (historia, juego libre, en línea) queda bloqueada hasta terminar la campaña en CUALQUIER ranura
--     Flappy: el desbloqueo es global (story.sav, `adventure = true`), como las dificultades.
--   · El MENÚ DE DEPURACIÓN puede abrir Aventura sin el candado: solo durante esta sesión (`debugOpen`).
local Save = require 'src/story/Save'

local Campaign = { READY = false, debugOpen = false }

-- ¿Está Aventura bloqueada ahora mismo?
function Campaign.adventureLocked()
    if not Campaign.READY or Campaign.debugOpen then return false end
    return Save.global().adventure ~= true
end

-- La campaña se terminó (en cualquier ranura): Aventura queda abierta para siempre en esta instalación
function Campaign.unlockAdventure()
    local g = Save.global()
    if g.adventure == true then return end
    g.adventure = true
    Save.writeGlobal(g)
end

-- La ÚLTIMA etapa de la última zona superada (src/flappy/FlappyRun.lua): la campaña está terminada. Solo cuenta con la
-- campaña LISTA (READY): terminar la zona provisional de hoy no puede dejar Aventura abierta para siempre
function Campaign.finished()
    if Campaign.READY then Campaign.unlockAdventure() end
end

return Campaign
