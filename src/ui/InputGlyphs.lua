-- src/ui/InputGlyphs.lua
-- ICONOS DE BOTONES (0.5.195): la imagen del botón de una acción en el aparato que se usa, para dibujarla dentro de un
-- texto (los carteles de ayuda, src/world/entities/types/items/hint.lua). Sale del nombre del botón (Input.label), así
-- sigue a A/B intercambiados y a cualquier cambio de teclas. Arte: assets/images/ui/glyphs/ (tools/art/ui/make_input_glyphs.py).
-- Con el dedo no hay icono (nil): el texto lleva el nombre del botón de la pantalla y ese botón se ilumina
-- (TouchControls.highlight).
--   local img = InputGlyphs.get('jump')   → Image o nil
local G = {}

local PC  = { space = 'key_space', shift = 'key_shift', f = 'key_f', x = 'key_x', up = 'key_up', down = 'key_down',
              ['<'] = 'key_left', ['>'] = 'key_right' }
local PAD = { a = 'pad_a', b = 'pad_b', x = 'pad_x', y = 'pad_y', l = 'pad_l', r = 'pad_r', ['^'] = 'pad_up', v = 'pad_down',
              ['<'] = 'pad_left', ['>'] = 'pad_right' }

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

function G.nameFor(action)
    if Input.lastDevice == 'touch' then return nil end
    local key = (Input.label(action) or ''):match('^%[(.-)%]$')
    if not key then return nil end
    local t = Input.usingPad() and PAD or PC
    return t[key:lower()]
end

function G.get(action)
    local n = G.nameFor(action)
    return n and image(n) or nil
end

return G
