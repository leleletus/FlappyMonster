-- src/ui/HintBubble.lua
-- El BOCADILLO de ayuda (0.5.196, sacado del cartel de ayuda, src/world/entities/types/items/hint.lua, para que lo
-- usen también las jaulas Flappy, types/items/cage.lua): un texto de assets/lang/translations.csv con los BOTONES del
-- aparato que se usa ({jump}, {run}, {crouch}, {grab}, {light}, {left}, {right}, {special}). Con teclado o mando cada
-- {botón} es su ICONO (src/ui/InputGlyphs.lua) dentro del texto; con el dedo, el nombre del botón de la pantalla, y ese
-- botón se ilumina (TouchControls.highlight). Solo dibujo: cada cliente lo dibuja para su jugador (renderOverlay).
--   local B = require 'src/ui/HintBubble'
--   self.show = B.fade(self.show, near, dt)                     -- (aparece / se va)
--   B.draw(self, 'tut.run', nil, nil, cx, top, bottom, self.show, near)  -- `self` guarda la caché del texto partido (self._lines…)
local L = require 'src/core/Lang'
local Glyphs = require 'src/ui/InputGlyphs'
local TouchControls = require 'src/ui/TouchControls'

local B = {}
local FADE = 6                 -- 1/s: lo que tarda en aparecer / irse
local PAD = 10                 -- px de margen dentro
local MAXW = 380               -- px de ancho como mucho (luego parte en líneas)
local GAP = 18                 -- px entre el bocadillo y lo que señala

local ACT = { jump = 'jump', run = 'run', crouch = 'crouch', grab = 'grab', light = 'light', left = 'move_left',
              right = 'move_right', special = 'special' }
local MARK = {}
for k in pairs(ACT) do MARK[k] = '\1' .. k .. '\2' end

function B.fade(show, near, dt)
    return math.max(0, math.min(1, (show or 0) + (near and 1 or -1) * FADE * (dt or 1 / 60)))
end

-- Parte el texto en líneas con los iconos (se rehace al cambiar de texto, de idioma, de aparato o de A/B): `lines` =
-- lista de líneas, cada una una lista de trozos { text = s } o { img = Image }, y su ancho. `c` = la tabla donde se
-- guarda (la entidad); `vars` = otras variables del texto ({n}…; si cambian, cambia `sig`)
local function layout(c, key, vars, sig, font)
    local dev, lang, pad = Input.lastDevice, L.current(), Input.usingPad() and Input.label('jump') or ''
    if c._lines and c._dev == dev and c._lang == lang and c._pad == pad and c._tkey == key and c._sig == sig and c._font == font then
        return c._lines, c._w, c._acts
    end
    local subs = MARK
    if vars then
        subs = {}
        for k, v in pairs(MARK) do subs[k] = v end
        for k, v in pairs(vars) do subs[k] = v end
    end
    local raw = L(key, subs)
    local gh = font:getHeight()
    local sc = math.max(2, math.floor(gh * 1.6 / 11 + 0.5))      -- (el icono, algo más alto que las letras)
    local acts, words = {}, {}
    for word in raw:gmatch('%S+') do
        local parts, w = {}, 0
        local pos = 1
        while pos <= #word do
            local a, b, name = word:find('\1(%a+)\2', pos)
            if not a then a = #word + 1 end
            if a > pos then
                local t = word:sub(pos, a - 1)
                parts[#parts + 1] = { text = t }; w = w + font:getWidth(t)
            end
            if not name then break end
            acts[ACT[name]] = true
            local img = Glyphs.get(ACT[name])
            if img then
                parts[#parts + 1] = { img = img, sc = sc }; w = w + img:getWidth() * sc
            else
                local t = Input.label(ACT[name])
                parts[#parts + 1] = { text = t }; w = w + font:getWidth(t)
            end
            pos = b + 1
        end
        words[#words + 1] = { parts = parts, w = w }
    end
    local space = font:getWidth(' ')
    local lines, cur, curW, maxW = {}, {}, 0, 0
    for _, wd in ipairs(words) do
        local add = (#cur > 0 and space or 0) + wd.w
        if #cur > 0 and curW + add > MAXW then
            lines[#lines + 1] = { parts = cur, w = curW }; maxW = math.max(maxW, curW)
            cur, curW, add = {}, 0, wd.w
        end
        if #cur > 0 then cur[#cur + 1] = { text = ' ' } end
        for _, p in ipairs(wd.parts) do cur[#cur + 1] = p end
        curW = curW + add
    end
    if #cur > 0 then lines[#lines + 1] = { parts = cur, w = curW }; maxW = math.max(maxW, curW) end
    c._lines, c._w, c._acts, c._dev, c._lang, c._pad, c._tkey, c._sig, c._font = lines, maxW, acts, dev, lang, pad, key, sig, font
    c._lh = math.max(gh, 11 * sc) + 4
    return lines, maxW, acts
end

-- Dibuja el bocadillo (en px de pantalla) sobre lo que señala: `cx` = su centro, `top` / `bottom` = su borde de arriba /
-- de abajo. Va ENCIMA; si no cabe en la pantalla, DEBAJO (con la punta hacia arriba). `show` = 0..1 (el fundido);
-- `lit` = mientras sea true, con el dedo, el botón de la pantalla que nombra brilla y bota.
-- La letra de los carteles: la de siempre o GRANDE (ACCESIBILIDAD: Opciones → LETRA DE LOS CARTELES)
function B.font()
    local S = package.loaded['src/core/Settings']
    return (S and S.signText == 'large') and FONT_MED or FONT_SMALL
end

function B.draw(c, key, vars, sig, cx, top, bottom, show, lit)
    if (show or 0) <= 0 then return end
    local font = B.font()
    local lines, w, acts = layout(c, key, vars, sig, font)
    if lit and Input.lastDevice == 'touch' then
        for a in pairs(acts) do TouchControls.highlight(a) end
    end
    local lh = c._lh or (font:getHeight() + 4)
    local bw, bh = w + PAD * 2, #lines * lh + PAD * 2 - 4
    cx = math.floor(cx + 0.5)
    local slide = math.floor((1 - show) * 10 + 0.5)
    local y = math.floor(top - GAP - bh + 0.5) + slide
    local below = y < 8
    if below then y = math.floor(bottom + GAP + 0.5) - slide end
    local bx = math.max(8, math.min(WINDOW_W - 8 - bw, cx - math.floor(bw / 2)))
    local a = show
    love.graphics.setColor(0.07, 0.07, 0.11, 0.88 * a)                     -- (rectángulo duro, sin curvas)
    love.graphics.rectangle('fill', bx, y, bw, bh)
    love.graphics.setColor(1, 0.85, 0.4, a)
    love.graphics.rectangle('fill', bx, y, bw, 2)
    if below then love.graphics.rectangle('fill', cx - 4, y - 6, 8, 6)      -- (la punta, hacia lo que señala)
    else love.graphics.rectangle('fill', cx - 4, y + bh, 8, 6) end
    love.graphics.setFont(font)
    local fh = font:getHeight()
    local ty = math.floor((lh - 4 - fh) / 2)                               -- (las letras, centradas en la línea)
    for i, l in ipairs(lines) do
        local x, ly = bx + PAD, y + PAD + (i - 1) * lh
        for _, p in ipairs(l.parts) do
            if p.img then
                local ih = p.img:getHeight() * p.sc
                local iy = ly + math.floor((lh - 4 - ih) / 2 + 0.5)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.draw(p.img, x, iy, 0, p.sc, p.sc)
                x = x + p.img:getWidth() * p.sc
            else
                love.graphics.setColor(0, 0, 0, 0.75 * a)
                love.graphics.print(p.text, x + 2, ly + ty + 2)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.print(p.text, x, ly + ty)
                x = x + font:getWidth(p.text)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return B
