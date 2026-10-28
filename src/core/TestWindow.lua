-- src/core/TestWindow.lua
-- Las VENTANAS de las pruebas (tools/tests): con FM_TEST_HIDE=1 (lo pone tools/tests/run.sh; FM_TEST_SHOW=1 para
-- verlas) se abren SIN BORDE y FUERA DE LA PANTALLA: siguen dibujando y las capturas (captureScreenshot, canvas) salen
-- igual, pero ya no aparecen ventanas parpadeando encima de lo que hace el usuario (en macOS, además, run.sh pone
-- SDL_MAC_BACKGROUND_APP=1: no roban el foco ni salen en el Dock). Fuera de las pruebas no hace nada.
-- Cada tools/tests/<arnés>/conf.lua termina con `require('src/core/TestWindow').conf(t)`. Con FM_TEST, además, un error
-- de Lua termina la prueba al momento (ver TW.conf).
local TW = {}

local OFF = -30000

local function hide(flags)
    flags = flags or {}
    flags.borderless, flags.x, flags.y = true, OFF, OFF
    return flags
end

function TW.conf(t)
    -- Un ERROR de Lua en una prueba (run.sh pone FM_TEST): se imprime y la prueba SALE (código 1) en vez de quedarse en
    -- la pantalla de error hasta el límite de tiempo (15 min perdidos por arnés roto). run.sh lo detecta por el texto.
    if os.getenv('FM_TEST') then
        love.errorhandler = function(msg)
            print('Error: ' .. tostring(msg))
            print(debug.traceback('', 2))
            io.stdout:flush()
            return function() return 1 end
        end
    end
    if not os.getenv('FM_TEST_HIDE') or os.getenv('FM_TEST_SHOW') then return end
    if t.window then hide(t.window) end
    -- (lo que el arnés o el juego cambie DESPUÉS con setMode / updateMode — p. ej. una captura a 1280x720 — también
    -- fuera de la pantalla: se envuelven en cuanto se carga love.window)
    local mt = getmetatable(love) or {}
    local prev = mt.__newindex
    mt.__newindex = function(tbl, k, v)
        if k == 'window' and type(v) == 'table' and not v._fmHidden then
            v._fmHidden = true
            local setMode, updateMode, setPosition = v.setMode, v.updateMode, v.setPosition
            v.setMode = function(w, h, flags) return setMode(w, h, hide(flags)) end
            if updateMode then v.updateMode = function(w, h, flags) return updateMode(w, h, hide(flags)) end end
            if setPosition then v.setPosition = function() end end
        end
        if prev then prev(tbl, k, v) else rawset(tbl, k, v) end
    end
    setmetatable(love, mt)
end

return TW
