-- game.lua  (el juego; main.lua es solo el arranque con las actualizaciones)
lovesize     = require 'libs/lovesize'
Timer        = require 'libs/timer'

require 'settings'
Input        = require 'input'
Sound        = require 'src/audio/Sound'
StateMachine = require 'src/core/StateMachine'

-- NetworkClient: singleton global para el modo online
NC = require 'src/network/NetworkClient'
Notify = require 'src/ui/Notify'   -- avisos globales (toasts y ventanas)

local TitleState                  = require 'src/states/menu/TitleState'
local MainMenuState               = require 'src/states/menu/MainMenuState'
local DifficultySelectionState    = require 'src/states/flappy/DifficultySelectionState'
local PlayState                   = require 'src/states/flappy/PlayState'
local PauseState                  = require 'src/states/adventure/PauseState'
local AdventureState              = require 'src/states/adventure/AdventureState'
local AdventureModeSelectState    = require 'src/states/menu/AdventureModeSelectState'
local FreePlayState               = require 'src/states/adventure/FreePlayState'
local OnlineLoginState            = require 'src/states/online/OnlineLoginState'
local OnlineHubState              = require 'src/states/online/OnlineHubState'
local OnlineRoomState             = require 'src/states/online/OnlineRoomState'
local OnlineAdventureState        = require 'src/states/online/OnlineAdventureState'
local OnlineErrorState            = require 'src/states/online/OnlineErrorState'
local OnlineResultsState          = require 'src/states/online/OnlineResultsState'
local SettingsState               = require 'src/states/menu/SettingsState'
local UpdateState                 = require 'src/states/menu/UpdateState'
local Settings                    = require 'src/core/Settings'

DEBUG_HITBOX = DEBUG_HITBOX or false   -- F1 para activar/desactivar hitboxes (FM_HITBOX=1: ya encendidas — settings.lua —, para las pruebas)

function love.load()
    -- Autoadaptar la resolución lógica para móviles y tablets (Evitar Zoom excesivo)
    -- (en los niveles se fija a 1280x720: src/ui/View.lua)
    love.graphics.setDefaultFilter('nearest', 'nearest')
    require('src/ui/View').apply()

    -- Fuentes pixel art globales (Press Start 2P)
    -- Archivo: assets/fonts/PressStart2P.ttf
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    FONT_MED   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 16)
    FONT_BIG   = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 28)
    love.graphics.setFont(FONT_MED)

    Settings.load()                 -- idioma guardado (src/core/Lang.lua)
    Input.load()
    Input.lastDevice = Input.isMobile and 'touch' or 'keyboard'
    Sound.load()

    gStateMachine = StateMachine:new({
        update             = function() return UpdateState:new() end,   -- (actualización automática)
        title              = function() return TitleState:new() end,
        main_menu          = function() return MainMenuState:new() end,
        difficulty         = function() return DifficultySelectionState:new() end,
        settings           = function() return SettingsState:new() end,
        play               = function() return PlayState:new() end,
        pause              = function() return PauseState:new() end,
        adventure          = function() return AdventureState:new() end,
        -- Modo online
        adv_mode_select    = function() return AdventureModeSelectState:new() end,
        free_play          = function() return FreePlayState:new() end,       -- Juego libre (pruebas)
        story_slots        = function() return require('src/states/story/StorySlotState'):new() end,   -- Historia: partidas
        story_results      = function() return require('src/states/story/StoryResultsState'):new() end, -- Historia: resultados del nivel
        story_map          = function() return require('src/states/story/StoryMapState'):new() end,    -- Historia: el mapa
        story_film         = function() return require('src/states/story/StoryFilmState'):new() end,   -- Historia: cinemáticas (intro y final)
        online_login       = function() return OnlineLoginState:new() end,
        online_hub         = function() return OnlineHubState:new() end,
        online_room        = function() return OnlineRoomState:new() end,
        online_adventure   = function() return OnlineAdventureState:new() end,
        online_error       = function() return OnlineErrorState:new() end,
        online_results     = function() return OnlineResultsState:new() end,
    })
    gStateMachine:change('update')      -- busca versión nueva y luego va al título
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    Timer.update(dt)
    Sound.update(dt)
    Input.update(dt)
    NC:update(dt)
    local blocked = Notify.blocking()    -- una ventana de aviso abierta se come la entrada
    Notify.update(dt)
    if not blocked then gStateMachine:update(dt) end
end

function love.draw()
    lovesize.begin()
        gStateMachine:render()
        Notify.render()
    lovesize.finish()
    -- En píxeles de PANTALLA (fuera del área del juego, p. ej. en las bandas
    -- negras de los móviles alargados): controles táctiles de los niveles
    local top = gStateMachine:_top()
    if top and top.drawScreen then top:drawScreen() end
end

function love.joystickadded(joystick)
    Input.joystickadded(joystick)
end

-- Actualizar lovesize cuando Android rota o cambia el tamaño real de la ventana
function love.resize(w, h)
    require('src/ui/View').apply()          -- (adaptable en menús, fijo en niveles)
    -- Las miniaturas de niveles están en canvases: al cambiar la ventana (o
    -- girar el móvil) su contenido se puede perder → se rehacen al dibujar
    require('src/ui/ModeSelectMenu').clearPreviews()
end

-- Táctil (Switch / Android / iOS): reenviar al estado del tope de la pila
function love.touchpressed(id, x, y, dx, dy, pressure)
    if not gStateMachine then return end

    -- Convertir coordenadas de pantalla (Android) a lógicas (1280x720) para los botones
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX = (sw - WINDOW_W * scale) / 2
    local offY = (sh - WINDOW_H * scale) / 2
    local lx = (x - offX) / scale
    local ly = (y - offY) / scale

    if Notify.touch(lx, ly) then return end
    local state = gStateMachine:_top()
    if state and state.touchpressed then
        state:touchpressed(id, lx, ly, dx, dy, pressure)
        else
            -- Fallback global para menús: dividir la pantalla en 3 zonas
            local sh = love.graphics.getHeight()
            if y < sh * 0.33 then
                Input.VirtualPad._pressedThisFrame['nav_up'] = true
            elseif y > sh * 0.66 then
                Input.VirtualPad._pressedThisFrame['nav_down'] = true
            else
                Input.VirtualPad._pressedThisFrame['confirm'] = true
            end
    end
end

function love.focus(f)
    -- (los arneses de tools/tests corren con FM_TEST=1: perder el foco no pausa ni silencia, así la
    -- prueba sigue aunque se use otra ventana)
    if os.getenv('FM_TEST') then return end
    if not f then
        if gStateMachine then
            local state = gStateMachine:_top()
            if state and state.pauseGame then state:pauseGame() end
        end
        love.audio.setVolume(0)
    else
        love.audio.setVolume(1)
    end
end

function love.keypressed(k)
    if k == 'f1' then DEBUG_HITBOX = not DEBUG_HITBOX end
    Input.lastDevice = 'keyboard'
    -- Reenviar al estado actual (para campos de texto en menús online)
    local state = gStateMachine:_top()
    if state and state.keypressed then state:keypressed(k) end
    if k == 'escape' then return true end -- Evita que Android cierre el juego abruptamente
end

-- Reenviar entrada de texto al estado actual (menús online)
function love.textinput(t)
    local state = gStateMachine:_top()
    if state and state.textinput then state:textinput(t) end
end

function love.joystickpressed(joystick, button)
    Input.lastDevice = 'gamepad'
end

-- Registrar cuando se toca la pantalla
local oldTouchpressed = love.touchpressed
function love.touchpressed(id, x, y, dx, dy, pressure)
    Input.lastDevice = 'touch'
    oldTouchpressed(id, x, y, dx, dy, pressure)
end

-- Movimiento del mouse: actualiza hover en el estado actual
function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    if not gStateMachine then return end
    Input.lastDevice = 'mouse'
    local sw, sh  = love.graphics.getWidth(), love.graphics.getHeight()
    local scale   = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX    = (sw - WINDOW_W * scale) / 2
    local offY    = (sh - WINDOW_H * scale) / 2
    local lx      = (x - offX) / scale
    local ly      = (y - offY) / scale
    if Notify.hover(lx, ly) then return end
    local state   = gStateMachine:_top()
    if state and state.mousemoved then
        state:mousemoved(lx, ly)
    end
end

-- Clic del mouse (PC / pantalla táctil de escritorio): redirige al mismo manejador que el toque
function love.mousepressed(x, y, button, istouch, presses)
    if istouch then return end          -- ya lo maneja love.touchpressed (evita doble disparo)
    if button ~= 1 then return end      -- solo botón izquierdo
    if not gStateMachine then return end
    Input.lastDevice = 'mouse'

    local sw, sh  = love.graphics.getWidth(), love.graphics.getHeight()
    local scale   = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local offX    = (sw - WINDOW_W * scale) / 2
    local offY    = (sh - WINDOW_H * scale) / 2
    local lx      = (x - offX) / scale
    local ly      = (y - offY) / scale

    if Notify.touch(lx, ly) then return end
    local state = gStateMachine:_top()
    if state and state.touchpressed then
        state:touchpressed('mouse', lx, ly, 0, 0, 1)
    else
        -- Fallback: dividir la pantalla en 3 zonas (igual que touchpressed)
        if y < sh * 0.33 then
            Input.VirtualPad._pressedThisFrame['nav_up'] = true
        elseif y > sh * 0.66 then
            Input.VirtualPad._pressedThisFrame['nav_down'] = true
        else
            Input.VirtualPad._pressedThisFrame['confirm'] = true
        end
    end
end

-- Arrastrar el dedo / soltarlo → estado actual (listas desplazables en el
-- móvil), en coordenadas lógicas como touchpressed
local function toLogical(x, y)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local scale  = math.min(sw / WINDOW_W, sh / WINDOW_H)
    return (x - (sw - WINDOW_W * scale) / 2) / scale, (y - (sh - WINDOW_H * scale) / 2) / scale
end
function love.touchmoved(id, x, y)
    local state = gStateMachine and gStateMachine:_top()
    if state and state.touchmoved then state:touchmoved(id, toLogical(x, y)) end
end
function love.touchreleased(id, x, y)
    local state = gStateMachine and gStateMachine:_top()
    if state and state.touchreleased then state:touchreleased(id, toLogical(x, y)) end
end

-- Rueda del ratón → estado actual (listas desplazables)
function love.wheelmoved(dx, dy)
    local state = gStateMachine and gStateMachine:_top()
    if state and state.wheelmoved then state:wheelmoved(dx, dy) end
end

function love.quit() end

-- ── Herramientas de edición ──────────────────────────────────────────────────
-- love . --editor [assets/levels/x.json]   editor de NIVELES
-- love . --anim   [id]                     editor de ANIMACIONES (assets/anim/<id>.json)
-- love . --enemy  [id]                     editor de ENEMIGOS    (assets/enemies/<id>.json)
-- (reemplazan los callbacks del juego; el juego se usa para "Probar" desde ellas)
for i, a in ipairs(arg or {}) do
    if a == '--editor' then
        local nxt = arg[i + 1]
        require('src/editor/Editor').install(nxt and nxt:match('%.json$') and nxt or nil)
        break
    elseif a == '--anim' then
        require('src/editor/AnimEditor').install()
        break
    elseif a == '--enemy' then
        require('src/editor/EnemyEditor').install()
        break
    end
end
