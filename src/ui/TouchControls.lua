-- src/ui/TouchControls.lua
-- Controles táctiles de los niveles (móvil), en píxeles REALES de la pantalla
-- (fuera de lovesize): en móviles alargados el juego lleva bandas a los lados
-- y los controles se ponen en ellas; si no hay sitio, encima del juego.
--
--   * CRUCETA (izquierda): izquierda / derecha / abajo (= agacharse; pulsado
--     en el aire = ground pound) / arriba (= coger / lanzar: systems/Carry). Diagonales abajo-izq / abajo-der = agachado
--     + dirección (el salto agachado usa la dirección que se mantiene).
--     Zona táctil GRANDE: toda la mitad izquierda de abajo; cuenta la
--     dirección del dedo respecto al centro de la cruceta (se puede deslizar).
--   * CORRER (0.5.190): botón pequeño a la izquierda del salto, se mantiene (no en los niveles Flappy).
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
--   TouchControls.layout(sw, sh[, custom])   posiciones (lo usan las pruebas). custom = la disposición PROPIA del
--                                  jugador (0.5.207, el editor: src/states/menu/TouchEditorState.lua; docs/design/
--                                  touch-editor.md): { pad = {fx, fy, size}, jump, run, extra, alpha, moved }; nil = la
--                                  guardada (Settings.touchLayout); false = la de siempre
--   TouchControls.buttons(L, ex, run)        { {key, x, y, r}, ... } los botones a la vista (círculos)
--   TouchControls.clampLayout(t, sw, sh[, order])   la disposición t colocada: dentro, bajo la franja del HUD y sin
--                                            pisarse (order: en qué orden se colocan; el primero se queda donde pidió)

local SpriteStrip = require 'src/fx/SpriteStrip'

local TC = {}
local dpad, jump, lightBtn
local state = { l = false, r = false, d = false, j = false, f = false, u = false, x = false, rn = false }
-- El botón de CORRER (0.5.190, el usuario: «un botón especial en pantalla, para más control»): a la izquierda del de
-- salto, se MANTIENE. No en los niveles Flappy (no se corre volando)
local runOn = false
local prev = { d = false, j = false, f = false, u = false, x = false }
-- El botón EXTRA, encima del salto: 'light' (niveles a oscuras: la linterna) · 'special' (niveles Flappy: el ATAQUE
-- ESPECIAL — src/player/PlayerFlight.lua —) · nil. (`true` = 'light', como antes)
local extra = nil
local LIGHT_FRAC = 0.13       -- su tamaño (fracción del alto)

local TOP_FRAC  = 0.30        -- por encima de esta altura (fracción) no hay controles
TC.TOP_FRAC = TOP_FRAC
TC.KEYS = { 'pad', 'jump', 'run', 'extra' }
TC.ZONE_K, TC.PAD_ZONE_K = 1.35, 1.5   -- (disposición propia: cada botón responde en un círculo así de mayor que el dibujo)
TC.SIZE_MIN, TC.SIZE_MAX = 0.6, 1.6
TC.ALPHA_MIN = 0.2
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
function TC.layout(sw, sh, custom)
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
    -- Correr: del tamaño de la linterna, a la izquierda del salto y un poco más abajo (el pulgar llega sin soltar el salto)
    L.runX = math.floor(L.jumpX - jumpW * 0.5 - L.lightW * 0.8)
    L.runY = math.floor(L.jumpY + jumpW * 0.18)
    L.runPx, L.runW = L.lightPx, L.lightW
    -- LA DISPOSICIÓN PROPIA del jugador (el editor): cada botón donde la dejó (fracciones de la pantalla) y de su tamaño
    if custom == nil then
        local S = package.loaded['src/core/Settings']
        custom = S and S.touchLayout or nil
    end
    L.alpha = (type(custom) == 'table' and tonumber(custom.alpha)) or 1
    if type(custom) == 'table' and custom.moved then
        L.custom = true
        local function px(base, size) return math.max(2, math.floor(base * (tonumber(size) or 1) + 0.5)) end
        local p, j, r, e = custom.pad, custom.jump, custom.run, custom.extra
        if p then L.padPx = px(padPx, p[3]); L.padW = 40 * L.padPx; L.padX, L.padY = math.floor(p[1] * sw), math.floor(p[2] * sh) end
        if j then L.jumpPx = px(jumpPx, j[3]); L.jumpW = 32 * L.jumpPx; L.jumpX, L.jumpY = math.floor(j[1] * sw), math.floor(j[2] * sh) end
        local lp = L.lightPx
        if r then L.runPx = px(lp, r[3]); L.runW = 24 * L.runPx; L.runX, L.runY = math.floor(r[1] * sw), math.floor(r[2] * sh) end
        if e then L.lightPx = px(lp, e[3]); L.lightW = 24 * L.lightPx; L.lightX, L.lightY = math.floor(e[1] * sw), math.floor(e[2] * sh) end
    end
    return L
end

-- Los botones a la vista como círculos (posición y radio del dibujo, en píxeles de pantalla)
function TC.buttons(L, ex, run)
    local out = { { key = 'pad', x = L.padX, y = L.padY, r = L.padW / 2 }, { key = 'jump', x = L.jumpX, y = L.jumpY, r = L.jumpW / 2 } }
    if run ~= false then out[#out + 1] = { key = 'run', x = L.runX, y = L.runY, r = L.runW / 2 } end
    if ex ~= false then out[#out + 1] = { key = 'extra', x = L.lightX, y = L.lightY, r = L.lightW / 2 } end
    return out
end

-- La disposición `t` COLOCADA en una pantalla sw × sh: cada botón dentro, bajo la franja del HUD y sin pisar a los que
-- ya se colocaron (se aparta de ellos lo justo). Devuelve otra tabla (fracciones), con `moved` y `alpha` de `t`
function TC.clampLayout(t, sw, sh, order)
    local out = { alpha = t.alpha, moved = true }
    local D = TC.layout(sw, sh, false)
    -- (el radio como lo dibuja TC.layout: escala entera de su arte)
    local art = { pad = { D.padPx, 40 }, jump = { D.jumpPx, 32 }, run = { D.lightPx, 24 }, extra = { D.lightPx, 24 } }
    local defs = { pad = { D.padX, D.padY }, jump = { D.jumpX, D.jumpY }, run = { D.runX, D.runY }, extra = { D.lightX, D.lightY } }
    local placed = {}
    for _, k in ipairs(order or TC.KEYS) do         -- (order: el primero manda — el que se arrastra —)
        local v = t[k] or { defs[k][1] / sw, defs[k][2] / sh, 1 }
        local size = math.max(TC.SIZE_MIN, math.min(TC.SIZE_MAX, tonumber(v[3]) or 1))
        local r = art[k][2] * math.max(2, math.floor(art[k][1] * size + 0.5)) / 2
        local x0 = math.max(r, math.min(sw - r, (tonumber(v[1]) or 0.5) * sw))
        local y0 = math.max(sh * TOP_FRAC + r, math.min(sh - r, (tonumber(v[2]) or 0.8) * sh))
        local function free(x, y)
            if x < r or x > sw - r or y < sh * TOP_FRAC + r or y > sh - r then return false end
            for _, o in ipairs(placed) do
                if (x - o.x) ^ 2 + (y - o.y) ^ 2 < (r + o.r + 2) ^ 2 then return false end
            end
            return true
        end
        -- (donde se pidió o, si ahí pisa a otro, el sitio libre más cercano: anillos cada vez más anchos)
        local x, y = x0, y0
        if not free(x, y) then
            local found
            for ring = 1, 60 do
                local d = ring * r * 0.25
                for i = 0, 23 do
                    local ang = i / 24 * math.pi * 2
                    local cx, cy = x0 + math.cos(ang) * d, y0 + math.sin(ang) * d
                    if free(cx, cy) then found = { cx, cy }; break end
                end
                if found then break end
            end
            if found then x, y = found[1], found[2] end
        end
        x, y = math.floor(x), math.floor(y)
        placed[#placed + 1] = { x = x, y = y, r = r }
        out[k] = { x / sw, y / sh, size }
    end
    return out
end

-- ¿Qué pulsa cada dedo? (posiciones de pantalla)
function TC.read(L, touches, ex, run)
    if ex == true then ex = 'light' end
    local s = { l = false, r = false, d = false, j = false, f = false, u = false, x = false, rn = false }
    local dead = L.padW * DEAD_FRAC
    if L.custom then
        -- (disposición propia: cada dedo, al botón cuyo círculo — algo mayor que el dibujo — lo contiene; el más cercano)
        local bs = TC.buttons(L, ex and true or false, run and true or false)
        for _, t in ipairs(touches) do
            local x, y = t[1], t[2]
            local best, bd
            for _, b in ipairs(bs) do
                local k = (b.key == 'pad') and TC.PAD_ZONE_K or TC.ZONE_K
                local d = math.sqrt((x - b.x) ^ 2 + (y - b.y) ^ 2)
                if d <= b.r * k and (not bd or d / b.r < bd) then best, bd = b, d / b.r end
            end
            if best and best.key == 'pad' then
                local dx, dy = x - L.padX, y - L.padY
                if math.abs(dx) > dead and math.abs(dx) > 0.45 * math.abs(dy) then
                    if dx < 0 then s.l = true else s.r = true end
                end
                if dy > dead and dy > 0.45 * math.abs(dx) then s.d = true end
                if -dy > dead and -dy > 0.45 * math.abs(dx) then s.u = true end
            elseif best and best.key == 'jump' then s.j = true
            elseif best and best.key == 'run' then s.rn = true
            elseif best and best.key == 'extra' then
                if ex == 'special' then s.x = true else s.f = true end
            end
        end
        return s
    end
    for _, t in ipairs(touches) do
        local x, y = t[1], t[2]
        if y >= L.topY then
            if x < L.sw / 2 then
                local dx, dy = x - L.padX, y - L.padY
                if math.abs(dx) > dead and math.abs(dx) > 0.45 * math.abs(dy) then
                    if dx < 0 then s.l = true else s.r = true end
                end
                if dy > dead and dy > 0.45 * math.abs(dx) then s.d = true end
                if -dy > dead and -dy > 0.45 * math.abs(dx) then s.u = true end
            elseif run and (x - L.runX) ^ 2 + (y - L.runY) ^ 2 <= (L.runW * 0.75) ^ 2 then
                s.rn = true                                      -- (correr: tiene prioridad sobre el salto)
            elseif ex and (x - L.lightX) ^ 2 + (y - L.lightY) ^ 2 <= (L.lightW * 0.75) ^ 2 then
                -- (el botón extra tiene prioridad sobre el salto)
                if ex == 'special' then s.x = true else s.f = true end
            else
                s.j = true
            end
        end
    end
    return s
end

-- Cada frame: lee los dedos y pone las acciones del jugador. `active` = el
-- estado quiere controles (nivel en marcha, no muerto / espectador)
function TC.update(active, ex, run)
    local VP = Input.VirtualPad
    extra = (ex == true) and 'light' or ((ex == 'light' or ex == 'special') and ex or nil)
    runOn = run == true
    if not (active and Input.isMobile) then
        state = { l = false, r = false, d = false, j = false, f = false, u = false, x = false, rn = false }
        VP.down['run'] = false
        prev.d, prev.j, prev.f, prev.u, prev.x = false, false, false, false, false
        return
    end
    local sw, sh = love.graphics.getDimensions()
    local L = TC.layout(sw, sh)
    local touches = {}
    for _, id in ipairs(love.touch.getTouches()) do
        local x, y = love.touch.getPosition(id)
        touches[#touches + 1] = { x, y }
    end
    state = TC.read(L, touches, extra, runOn)
    VP.down['run'] = state.rn
    VP.down['move_left'], VP.down['move_right'] = state.l, state.r
    VP.down['crouch'], VP.down['jump'] = state.d, state.j
    -- "Recién pulsado" (este mismo frame: saltar, y abajo en el aire = ground pound)
    if state.j and not prev.j then VP.pressed['jump'] = true end
    if state.d and not prev.d then VP.pressed['crouch'] = true end
    if state.f and not prev.f then VP.pressed['light'] = true end
    if state.u and not prev.u then VP.pressed['grab'] = true end
    if state.x and not prev.x then VP.pressed['special'] = true end
    VP.down['grab'] = state.u
    prev.d, prev.j, prev.f, prev.u, prev.x = state.d, state.j, state.f, state.u, state.x
end

-- Cuadro de la cruceta según lo pulsado
-- La animación de la cruceta según lo pulsado (conjunto ui/touch)
local function padFrame(s)
    if s.d and s.l then return 'dpad_down_left' end
    if s.d and s.r then return 'dpad_down_right' end
    if s.d then return 'dpad_down' end
    if s.l then return 'dpad_left' end
    if s.r then return 'dpad_right' end
    if s.u then return 'dpad_up' end
    return 'dpad_neutral'
end
local function T(name) return require('src/fx/Anim').clip('ui/touch', name) end
local function show(name, x, y, px) T(name):play(love.timer.getTime(), x, y, 0, px, px) end

-- RESALTAR un botón (0.5.195; el usuario: el tutorial marca, brillante y botando, el botón que nombra): quien lo pide
-- lo llama cada fotograma (el cartel de ayuda, mientras se lee); se apaga solo al dejar de pedirlo. Acciones: 'jump',
-- 'run', 'light' (o el botón extra que haya), y las de la cruceta ('move_left', 'move_right', 'grab', 'crouch').
local lit = {}
local PAD_ACT = { move_left = true, move_right = true, grab = true, crouch = true }
function TC.highlight(action)
    lit[PAD_ACT[action] and 'pad' or action] = love.timer.getTime()
end
local function litNow(k) return love.timer.getTime() - (lit[k] or -9) < 0.2 end
-- Bote (px de pantalla hacia arriba) y brillo encima: el mismo cuadro sumado (blend 'add'), que late
local function bounce(k, px)
    if not litNow(k) then return 0 end
    return -math.floor(math.abs(math.sin(love.timer.getTime() * 6)) * 3 * px + 0.5)
end
local function glow(k, name, x, y, px, fade)
    if not litNow(k) then return end
    local t = love.timer.getTime()
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 0.85, 0.35, (0.45 + 0.25 * math.sin(t * 8)) * fade)
    show(name, x, y, px)
    love.graphics.setBlendMode('alpha')
end

-- Dibuja en píxeles de pantalla (fuera de lovesize). `st` = lo pulsado (por
-- defecto, lo del último update)
function TC.draw(L, st, fade, ex, run)
    fade = fade or 1                              -- (entrada de un jefe: se van)
    ex = ex or extra                              -- (el botón extra: el del último update, o el que pida quien dibuja)
    if fade <= 0.001 then return end
    assets()
    st = st or state
    L = L or TC.layout(love.graphics.getDimensions())
    -- (semitransparentes: en pantallas 16:9 no hay bandas y van encima del juego;
    -- donde hay bandas negras se ven igual de claros)
    local a = ((L.band >= L.padW * 0.75) and 0.7 or 0.38) * (L.alpha or 1)       -- (la opacidad elegida en el editor)
    -- (sombra negra, como el resto de la interfaz)
    local sh = math.max(2, math.floor(L.padPx))
    love.graphics.setColor(0, 0, 0, 0.35 * a / 0.7 * fade)
    show(padFrame(st), L.padX + sh, L.padY + sh, L.padPx)
    show(st.j and 'jump_pressed' or 'jump_up', L.jumpX + sh, L.jumpY + sh, L.jumpPx)
    love.graphics.setColor(1, 1, 1, ((st.l or st.r or st.d) and 0.8 * (L.alpha or 1) or a) * fade)
    local by = bounce('pad', L.padPx)
    show(padFrame(st), L.padX, L.padY + by, L.padPx)
    glow('pad', padFrame(st), L.padX, L.padY + by, L.padPx, fade)
    love.graphics.setColor(1, 1, 1, (st.j and 0.8 * (L.alpha or 1) or a) * fade)
    local jn, jy = st.j and 'jump_pressed' or 'jump_up', L.jumpY + (st.j and L.jumpPx or 0) + bounce('jump', L.jumpPx)
    show(jn, L.jumpX, jy, L.jumpPx)
    glow('jump', jn, L.jumpX, jy, L.jumpPx, fade)
    if run == nil then run = runOn end
    if run then
        local name = st.rn and 'run_pressed' or 'run_up'
        love.graphics.setColor(0, 0, 0, 0.35 * a / 0.7 * fade)
        show(name, L.runX + sh, L.runY + sh, L.runPx or L.lightPx)
        love.graphics.setColor(1, 1, 1, (st.rn and 0.8 * (L.alpha or 1) or a) * fade)
        local rp = L.runPx or L.lightPx
        local ry = L.runY + bounce('run', rp)
        show(name, L.runX, ry, rp)
        glow('run', name, L.runX, ry, rp, fade)
    end
    if ex then
        local on = (ex == 'special') and st.x or st.f
        local name = ex .. (on and '_pressed' or '_up')
        love.graphics.setColor(0, 0, 0, 0.35 * a / 0.7 * fade)
        show(name, L.lightX + sh, L.lightY + sh, L.lightPx)
        love.graphics.setColor(1, 1, 1, (on and 0.8 * (L.alpha or 1) or a) * fade)
        local k = (ex == 'special') and 'special' or 'light'
        local ly = L.lightY + bounce(k, L.lightPx)
        show(name, L.lightX, ly, L.lightPx)
        glow(k, name, L.lightX, ly, L.lightPx, fade)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ¿Se ven los controles? (móvil y último uso táctil)
function TC.visible() return Input.isMobile and Input.lastDevice == 'touch' end

return TC
