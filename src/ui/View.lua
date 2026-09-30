-- src/ui/View.lua
-- Resolución lógica. En menús se ADAPTA a la pantalla (alto 720, ancho según
-- el aspecto, 4:3..21:9). En un NIVEL se FIJA a 1280x720 (16:9): se escala
-- y, si el aspecto no coincide, se ponen bandas negras (lovesize). Así todos
-- los dispositivos ven exactamente la misma zona del nivel (en una zona de
-- jefe nadie ve fuera de la arena ni menos que los demás).
--   View.lockGameplay()  al entrar en un nivel (Adventure / OnlineAdventure)
--   View.unlock()        al salir
--   View.apply()         tras cambiar el tamaño de la ventana (love.resize)
local View = {}

View.GAMEPLAY_W = 1280
local locked = false

function View.adaptiveWidth()
    local sw, sh = love.graphics.getDimensions()
    local aspect = math.max(4 / 3, math.min(21 / 9, sw / sh))
    return math.floor(720 * aspect)
end

function View.apply()
    WINDOW_W = locked and View.GAMEPLAY_W or View.adaptiveWidth()
    if lovesize and lovesize.set then lovesize.set(WINDOW_W, WINDOW_H) end
end

function View.lockGameplay()
    if locked then return end
    locked = true
    View.apply()
end

function View.unlock()
    if not locked then return end
    locked = false
    View.apply()
    -- (las miniaturas de niveles están en canvases del tamaño anterior)
    local ok, M = pcall(require, 'src/ui/ModeSelectMenu')
    if ok and M.clearPreviews then M.clearPreviews() end
end

function View.isLocked() return locked end

return View
