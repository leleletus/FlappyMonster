-- src/ui/RichText.lua
-- TEXTO CON ICONOS DE BOTONES (0.5.198; el usuario: «los iconos de los botones en absolutamente todo el juego»): cada
-- nombre de botón entre corchetes — `[Space]`, `[A]`, `[Esc]`, `[FLECHAS]`, `[<]`… lo que dan Input.label y
-- Input.hints — se dibuja como su ICONO (assets/images/ui/glyphs/, tools/art/ui/make_input_glyphs.py) según el aparato
-- en uso: teclado o mando. Con el dedo, o si un corchete no es un botón conocido, queda el texto tal cual.
--   RichText.printf(text, x, y, w, align, o)   como love.graphics.printf (parte en líneas y alinea) con la fuente y el
--                                              color actuales; o.shadow = true: los iconos también en el color actual
--                                              (la pasada de la sombra); si no, los iconos van en blanco (con su alfa)
--   RichText.width(text, font) · RichText.wrap(text, font, w) → ancho, líneas (lo que ocupa)
--   RichText.has(text)  ¿lleva algún botón con icono? (para no cambiar lo que no lo necesita)
local G = {}

-- nombre entre corchetes (en minúsculas) → iconos, para teclado y para mando
local PC = {
    space = { 'key_space' }, shift = { 'key_shift' }, f = { 'key_f' }, x = { 'key_x' }, q = { 'key_q' }, e = { 'key_e' },
    tab = { 'key_tab' }, enter = { 'key_enter' }, esc = { 'key_esc' }, del = { 'key_del' }, supr = { 'key_del' },
    up = { 'key_up' }, arriba = { 'key_up' }, ['^'] = { 'key_up' }, down = { 'key_down' }, abajo = { 'key_down' }, v = { 'key_down' },
    left = { 'key_left' }, izq = { 'key_left' }, ['<'] = { 'key_left' }, right = { 'key_right' }, der = { 'key_right' }, ['>'] = { 'key_right' },
    arrows = { 'key_arrows' }, flechas = { 'key_arrows' },
    ['left/right'] = { 'key_left', 'key_right' }, ['izq/der'] = { 'key_left', 'key_right' },
    ['up/down'] = { 'key_up', 'key_down' }, ['arriba/abajo'] = { 'key_up', 'key_down' },
}
local PAD = {
    a = { 'pad_a' }, b = { 'pad_b' }, x = { 'pad_x' }, y = { 'pad_y' }, l = { 'pad_l' }, r = { 'pad_r' },
    ['+'] = { 'pad_plus' }, ['-'] = { 'pad_minus' },
    ['^'] = { 'pad_up' }, v = { 'pad_down' }, ['<'] = { 'pad_left' }, ['>'] = { 'pad_right' },
    ['d-pad'] = { 'pad_dpad' }, cruceta = { 'pad_dpad' },
}
G.PC, G.PAD = PC, PAD

local cache = {}
local function image(name)
    local im = cache[name]
    if im == nil then
        local ok, res = pcall(love.graphics.newImage, 'assets/images/ui/glyphs/' .. name .. '.png')
        im = ok and res or false
        if im then im:setFilter('nearest', 'nearest') end
        cache[name] = im
    end
    return im or nil
end

-- Los iconos de un nombre entre corchetes en el aparato de ahora (o nil)
function G.icons(token)
    if Input.lastDevice == 'touch' then return nil end
    local names = (Input.usingPad() and PAD or PC)[token:lower()]
    if not names then return nil end
    local out = {}
    for i, n in ipairs(names) do
        local im = image(n)
        if not im then return nil end
        out[i] = im
    end
    return out
end

-- (como mínimo ×2: a ×1, junto a la letra pequeña, no se distinguían)
function G.scaleFor(font) return math.max(2, math.floor(font:getHeight() * 1.6 / 11 + 0.5)) end

function G.has(text)
    if type(text) ~= 'string' or not text:find('[', 1, true) then return false end
    for tok in text:gmatch('%[([^%]]+)%]') do if G.icons(tok) then return true end end
    return false
end

-- Trozos de una palabra: { text = s } o { img = Image, sc = n }, y su ancho
local function pieces(word, font, sc)
    local parts, w, pos = {}, 0, 1
    while pos <= #word do
        local a, b, tok = word:find('%[([^%]]+)%]', pos)
        local icons = a and G.icons(tok)
        if not a then a = #word + 1 end
        local cut = icons and a or (b and b + 1 or a)            -- (un corchete sin icono va con el texto)
        if cut > pos then
            local t = word:sub(pos, cut - 1)
            parts[#parts + 1] = { text = t }; w = w + font:getWidth(t)
        end
        if icons then
            for k, im in ipairs(icons) do
                if k > 1 then w = w + sc end
                parts[#parts + 1] = { img = im, sc = sc, gap = k > 1 and sc or 0 }; w = w + im:getWidth() * sc
            end
            pos = b + 1
        else
            pos = cut
        end
    end
    return parts, w
end

-- Partir en líneas: { { parts, w }, ... } y el ancho mayor. Los saltos de línea del texto cuentan
function G.wrap(text, font, maxW)
    local sc = G.scaleFor(font)
    local space = font:getWidth(' ')
    local lines, widest = {}, 0
    for para in (text .. '\n'):gmatch('(.-)\n') do
        local cur, curW = {}, 0
        for word in para:gmatch('%S+') do
            local parts, ww = pieces(word, font, sc)
            local add = (#cur > 0 and space or 0) + ww
            if #cur > 0 and maxW and curW + add > maxW then
                lines[#lines + 1] = { parts = cur, w = curW }; widest = math.max(widest, curW)
                cur, curW, add = {}, 0, ww
            end
            if #cur > 0 then cur[#cur + 1] = { text = ' ' } end
            for _, p in ipairs(parts) do cur[#cur + 1] = p end
            curW = curW + add
        end
        lines[#lines + 1] = { parts = cur, w = curW }; widest = math.max(widest, curW)
    end
    return widest, lines
end

function G.width(text, font) local w = G.wrap(text, font); return w end

-- Como love.graphics.printf, con los iconos (fuente y color actuales)
function G.printf(text, x, y, w, align, o)
    local font = love.graphics.getFont()
    if not G.has(text) then return love.graphics.printf(text, x, y, w, align or 'left') end
    local r, g, b, a = love.graphics.getColor()
    local _, lines = G.wrap(text, font, w)
    local fh = font:getHeight()
    local lh = math.floor(fh * font:getLineHeight())
    local ih = 11 * G.scaleFor(font)
    local ly = y
    for i, line in ipairs(lines) do
        local lx = x
        if align == 'center' then lx = x + math.floor((w - line.w) / 2)
        elseif align == 'right' then lx = x + w - line.w end
        local hasImg = false
        for _, p in ipairs(line.parts) do if p.img then hasImg = true end end
        -- (una línea con icono más alto que la letra: crece hacia abajo lo que le falta, la siguiente va después)
        if i > 1 and hasImg and ih > lh then ly = ly + math.floor((ih - lh) / 2) end
        for _, p in ipairs(line.parts) do
            if p.img then
                lx = lx + (p.gap or 0)
                local ih = p.img:getHeight() * p.sc
                if o and o.shadow then love.graphics.setColor(r, g, b, a) else love.graphics.setColor(1, 1, 1, a) end
                love.graphics.draw(p.img, math.floor(lx), math.floor(ly + (fh - ih) / 2 + 0.5), 0, p.sc, p.sc)
                love.graphics.setColor(r, g, b, a)
                lx = lx + p.img:getWidth() * p.sc
            else
                love.graphics.print(p.text, math.floor(lx), math.floor(ly))
                lx = lx + font:getWidth(p.text)
            end
        end
        ly = ly + ((hasImg and ih > lh) and (lh + math.floor((ih - lh) / 2)) or lh)
    end
end

return G
