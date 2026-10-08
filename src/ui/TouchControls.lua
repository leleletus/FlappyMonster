-- src/ui/TouchControls.lua
-- Controles táctiles de los niveles (móvil), en píxeles REALES de la pantalla
-- (fuera de lovesize): en móviles alargados el juego lleva bandas a los lados
-- y los controles se ponen en ellas; si no hay sitio, encima del juego.
--
--   * CRUCETA (izquierda): izquierda / derecha / abajo (= agacharse; pulsado
--     en el aire = ground pound). Diagonales abajo-izq / abajo-der = agachado
--     + dirección (el salto agachado usa la dirección que se mantiene).
--     Zona táctil GRANDE: toda la mitad izquierda de abajo; cuenta la
--     dirección del dedo respecto al centro de la cruceta (se puede deslizar).
--   * SALTO (derecha): toda la mitad derecha de abajo. Salto agachado = pulgar
--     izquierdo abajo + pulgar derecho salta.
-- Arriba de la pantalla (HUD, pausa) no cuenta como control.
-- Sprites: assets/images/ui/touch/dpad-Sheet.png (7 cuadros de 40x40: neutra,
-- izq, der, abajo, abajo-izq, abajo-der, arriba) y jump-Sheet.png (2 de 32x32),
-- generados por tools/art/ui/make_sprites.py (se pueden retocar a mano).
--
--   TouchControls.update(active)   cada frame, en el update del estado (pone
--                                  Input.VirtualPad.down / pressed)
--   TouchControls.draw()           en pantalla real, tras lovesize (game.lua)
--   TouchControls.layout(sw, sh)   posiciones (lo usan las pruebas)

local SpriteStrip = require 'src/fx/SpriteStrip'

local TC = {}
local dpad, jump, lightBtn
local state = { l = false, r = false, d = false, j = false, f = false }
local prev = { d = false, j = false, f = false }
local withLight = false       -- (niveles a oscuras: botón de la linterna, encima del salto)
local LIGHT_FRAC = 0.13       -- su tamaño (fracción del alto)

local TOP_FRAC  = 0.30        -- por encima de esta altura (fracción) no hay controles
local PAD_FRAC  = 0.30        -- diámetro visual de la cruceta (fracción del alto)
local JUMP_FRAC = 0.22        -- del botón de salto
local DEAD_FRAC = 0.16        -- zona muerta del centro de la cruceta (fracción de su tamaño)

local function assets()
end

-- Rectángulo del juego (lovesize) en la pantalla real
function TC.gameRect(sw, sh)
    local s = math.min(sw / WINDOW_W, sh / WINDOW_H)
    local gw, gh = WINDOW_W * s, WINDOW_H * s
    return (sw - gw) / 2, (sh - gh) / 2, gw, gh, s
end

-- Posición y tamaño de todo (píxeles de pantalla). Escala entera de los
-- sprites (pixel art nítido)
function TC.layout(sw, sh)
    local gx = TC.gameRect(sw, sh)
    local padPx = math.max(2, math.floor(sh * PAD_FRAC / 40))
    local jumpPx = math.max(2, math.floor(sh * JUMP_FRAC / 32))
    local padW, jumpW = 40 * padPx, 32 * jumpPx
    local band = gx                                  -- ancho de las bandas negras
    local margin = sh * 0.05
    local L = {
        sw = sw, sh = sh, band = band,
        padPx = padPx, padW = padW, jumpPx = jumpPx, jumpW = jumpW,
        -- (en la banda si cabe; si no, pegado al borde con margen)
        padX = math.floor(math.max(band / 2, padW / 2 + margin)),
        padY = math.floor(sh - padW / 2 - sh * 0.06),
        jumpX = math.floor(sw - math.max(band / 2, jumpW / 2 + margin * 1.4)),
        jumpY = math.floor(sh - jumpW / 2 - sh * 0.11),
        topY = sh * TOP_FRAC,
    }
    -- Linterna: botón pequeño encima y hacia dentro del de salto
    L.lightPx = math.max(2, math.floor(sh * LIGHT_FRAC / 24))
    L.lightW = 24 * L.lightPx
    L.lightX = math.floor(L.jumpX - jumpW * 0.55)
    L.lightY = math.floor(L.jumpY - jumpW * 0.5 - L.lightW * 0.75)
    return L
end

-- ¿Qué pulsa cada dedo? (posiciones de pantalla)
function TC.read(L, touches, light)
    local s = { l = false, r = false, d = false, j = false, f = false }
    local dead = L.padW * DEAD_FRAC
    for _, t in ipairs(touches) do
        local x, y = t[1], t[2]
        if y >= L.topY then
            if x < L.sw / 2 then
                local dx, dy = x - L.padX, y - L.padY
                if math.abs(dx) > dead and math.abs(dx) > 0.45 * math.abs(dy) then
                    if dx < 0 then s.l = true else s.r = true end
                end
                if dy > dead and dy > 0.45 * math.abs(dx) then s.d = true end
            elseif light and (x - L.lightX) ^ 2 + (y - L.lightY) ^ 2 <= (L.lightW * 0.75) ^ 2 then
                s.f = true                                  -- (la linterna tiene prioridad sobre el salto)
            else
                s.j = true
            end
        end
    end
    return s
end

-- Cada frame: lee los dedos y pone las acciones del jugador. `active` = el
-- estado quiere controles (nivel en marcha, no muerto / espectador)
function TC.update(active, light)
    local VP = Input.VirtualPad
    withLight = light == true
    if not (active and Input.isMobile) then
        state = { l = false, r = false, d = false, j = false, f = false }
        prev.d, prev.j, prev.f = false, false, false
        return
    end
    local sw, sh = love.graphics.getDimensions()
    local L = TC.layout(sw, sh)
    local touches = {}
    for _, id in ipairs(love.touch.getTouches()) do
        local x, y = love.touch.getPosition(id)
        touches[#touches + 1] = { x, y }
    end
    state = TC.read(L, touches, withLight)
    VP.down['move_left'], VP.down['move_right'] = state.l, state.r
    VP.down['crouch'], VP.down['jump'] = state.d, state.j
    -- "Recién pulsado" (este mismo frame: saltar, y abajo en el aire = ground pound)
    if state.j and not prev.j then VP.pressed['jump'] = true end
    if state.d and not prev.d then VP.pressed['crouch'] = true end
    if state.f and not prev.f then VP.pressed['light'] = true end
    prev.d, prev.j, prev.f = state.d, state.j, state.f
end

-- Cuadro de la cruceta según lo pulsado
-- La animación de la cruceta según lo pulsado (conjunto ui/touch)
local function padFrame(s)
    if s.d and s.l then return 'dpad_down_left' end
    if s.d and s.r then return 'dpad_down_right' end
    if s.d then return 'dpad_down' end
    if s.l then return 'dpad_left' end
    if s.r then return 'dpad_right' end
    return 'dpad_neutral'
end
local function T(name) return require('src/fx/Anim').clip('ui/touch', name) end
local function show(name, x, y, px) T(name):play(love.timer.getTime(), x, y, 0, px, px) end

-- Dibuja en píxeles de pantalla (fuera de lovesize). `st` = lo pulsado (por
-- defecto, lo del último update)
function TC.draw(L, st, fade)
    fade = fade or 1                              -- (entrada de un jefe: se van)
    if fade <= 0.001 then return end
    assets()
    st = st or state
    L = L or TC.layout(love.graphics.getDimensions())
    -- (semitransparentes: en pantallas 16:9 no hay bandas y van encima del juego;
    -- donde hay bandas negras se ven igual de claros)
    local a = (L.band >= L.padW * 0.75) and 0.7 or 0.38
    -- (sombra negra, como el resto de la interfaz)
    local sh = math.max(2, math.floor(L.padPx))
    love.graphics.setColor(0, 0, 0, 0.35 * a / 0.7 * fade)
    show(padFrame(st), L.padX + sh, L.padY + sh, L.padPx)
    show(st.j and 'jump_pressed' or 'jump_up', L.jumpX + sh, L.jumpY + sh, L.jumpPx)
    love.graphics.setColor(1, 1, 1, ((st.l or st.r or st.d) and 0.8 or a) * fade)
    show(padFrame(st), L.padX, L.padY, L.padPx)
    love.graphics.setColor(1, 1, 1, (st.j and 0.8 or a) * fade)
    show(st.j and 'jump_pressed' or 'jump_up', L.jumpX, L.jumpY + (st.j and L.jumpPx or 0), L.jumpPx)
    if withLight then
        love.graphics.setColor(0, 0, 0, 0.35 * a / 0.7 * fade)
        show(st.f and 'light_pressed' or 'light_up', L.lightX + sh, L.lightY + sh, L.lightPx)
        love.graphics.setColor(1, 1, 1, (st.f and 0.8 or a) * fade)
        show(st.f and 'light_pressed' or 'light_up', L.lightX, L.lightY, L.lightPx)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ¿Se ven los controles? (móvil y último uso táctil)
function TC.visible() return Input.isMobile and Input.lastDevice == 'touch' end

return TC
