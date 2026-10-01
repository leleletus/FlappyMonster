-- src/ui/PixelFont.lua
-- La fuente pixel de 5 px de alto de los botones grandes de los menús
-- (AVENTURA / CLÁSICO, dificultades, CONFIGURACIÓN...). Antes esos botones
-- eran imágenes con el texto dibujado (no se podían traducir); ahora se
-- generan con esta fuente, que copia las letras de aquellas imágenes y
-- completa el resto en el mismo estilo: blanco sobre un rectángulo negro
-- ajustado al texto, una columna negra entre letras.
--
--   PixelFont.draw('AVENTURA', x, y, 8)          -- y = arriba de las letras
--   PixelFont.width('AVENTURA', 8), PixelFont.height(8)
--
-- Tiene 2 filas extra arriba para tildes y la eñe (no cambian la posición
-- de las letras: `y` sigue siendo la parte de arriba del cuerpo de 5 px).

local PixelFont = {}

local ACC = 2          -- filas para tildes encima de la letra
local H   = 5          -- alto de la letra

-- Cuerpo de cada letra (5 filas). Las de las imágenes originales, copiadas
-- tal cual; el resto, en su estilo.
local G = {
    A = { '.##.', '#..#', '####', '#..#', '#..#' },
    B = { '###.', '#..#', '###.', '#..#', '###.' },
    C = { '.###', '#...', '#...', '#...', '.###' },
    D = { '###.', '#..#', '#..#', '#..#', '###.' },
    E = { '###', '#..', '##.', '#..', '###' },
    F = { '###', '#..', '##.', '#..', '#..' },
    G = { '####', '#...', '#.##', '#..#', '####' },
    H = { '#..#', '#..#', '####', '#..#', '#..#' },
    I = { '###', '.#.', '.#.', '.#.', '###' },
    J = { '..#', '..#', '..#', '#.#', '.#.' },
    K = { '#..#', '#.#.', '##..', '#.#.', '#..#' },
    L = { '#..', '#..', '#..', '#..', '###' },
    M = { '#...#', '##.##', '#.#.#', '#...#', '#...#' },
    N = { '#..#', '##.#', '#.##', '#..#', '#..#' },
    O = { '.##.', '#..#', '#..#', '#..#', '.##.' },
    P = { '###.', '#..#', '###.', '#...', '#...' },
    Q = { '.##.', '#..#', '#..#', '#.##', '.###' },
    R = { '###', '#.#', '##.', '#.#', '#.#' },
    S = { '.###', '#...', '.##.', '...#', '###.' },
    T = { '###', '.#.', '.#.', '.#.', '.#.' },
    U = { '#..#', '#..#', '#..#', '#..#', '.##.' },
    V = { '#..#', '#..#', '#..#', '####', '.##.' },
    W = { '#...#', '#...#', '#.#.#', '##.##', '#...#' },
    X = { '#..#', '#..#', '.##.', '#..#', '#..#' },
    Y = { '#...#', '#...#', '.###.', '..#..', '..#..' },
    Z = { '####', '...#', '.##.', '#...', '####' },
    ['0'] = { '###', '#.#', '#.#', '#.#', '###' },
    ['1'] = { '.#.', '##.', '.#.', '.#.', '###' },
    ['2'] = { '###', '..#', '###', '#..', '###' },
    ['3'] = { '###', '..#', '.##', '..#', '###' },
    ['4'] = { '#.#', '#.#', '###', '..#', '..#' },
    ['5'] = { '###', '#..', '###', '..#', '###' },
    ['6'] = { '###', '#..', '###', '#.#', '###' },
    ['7'] = { '###', '..#', '.#.', '.#.', '.#.' },
    ['8'] = { '###', '#.#', '###', '#.#', '###' },
    ['9'] = { '###', '#.#', '###', '..#', '###' },
    [' '] = { '..', '..', '..', '..', '..' },
    ['!'] = { '#', '#', '#', '.', '#' },
    ['¡'] = { '#', '.', '#', '#', '#' },
    ['?'] = { '###', '..#', '.#.', '...', '.#.' },
    ['¿'] = { '.#.', '...', '.#.', '#..', '###' },
    ['.'] = { '.', '.', '.', '.', '#' },
    [','] = { '.', '.', '.', '#', '#' },
    [':'] = { '.', '#', '.', '#', '.' },
    ['-'] = { '...', '...', '###', '...', '...' },
    ['+'] = { '...', '.#.', '###', '.#.', '...' },
    ["'"] = { '#', '#', '.', '.', '.' },
    ['/'] = { '..#', '..#', '.#.', '#..', '#..' },
    ['('] = { '.#', '#.', '#.', '#.', '.#' },
    ['<'] = { '..#', '.#.', '#..', '.#.', '..#' },
    ['>'] = { '#..', '.#.', '..#', '.#.', '#..' },
    [')'] = { '#.', '.#', '.#', '.#', '#.' },
}
-- Letras con tilde / eñe / diéresis: la base + marca en las filas de arriba
local MARKS = {
    ['Á'] = { 'A', { '..#.', '.#..' } }, ['É'] = { 'E', { '..#', '.#.' } },
    ['Í'] = { 'I', { '..#', '.#.' } },   ['Ó'] = { 'O', { '..#.', '.#..' } },
    ['Ú'] = { 'U', { '..#.', '.#..' } }, ['Ñ'] = { 'N', { '.#.#', '#.#.' } },
    ['Ü'] = { 'U', { '#..#', '....' } },
}
for ch, m in pairs(MARKS) do G[ch] = { base = m[1], mark = m[2] } end

local LOWER = { ['á'] = 'Á', ['é'] = 'É', ['í'] = 'Í', ['ó'] = 'Ó', ['ú'] = 'Ú', ['ñ'] = 'Ñ', ['ü'] = 'Ü' }

-- Mayúsculas también con tildes (string.upper no toca los caracteres UTF-8)
function PixelFont.upper(s)
    s = s:upper()
    return (s:gsub('[\195][\128-\191]', function(c) return LOWER[c] or c end))
end

local font
local function build()
    if font then return font end
    -- Orden de glifos y su ancho
    local order, total = {}, 1
    for ch, g in pairs(G) do
        local rows = g.base and G[g.base] or g
        order[#order + 1] = ch
        total = total + #rows[1] + 1
    end
    table.sort(order)
    -- ImageData: columna separadora (magenta) antes de cada glifo
    local img = love.image.newImageData(total, ACC + H)
    img:mapPixel(function() return 0, 0, 0, 0 end)
    local x = 0
    local sep = { 1, 0, 1, 1 }
    for _, ch in ipairs(order) do
        for y = 0, ACC + H - 1 do img:setPixel(x, y, sep[1], sep[2], sep[3], sep[4]) end
        x = x + 1
        local g = G[ch]
        local rows = g.base and G[g.base] or g
        local w = #rows[1]
        for r = 1, H do
            for c = 1, w do
                if rows[r]:sub(c, c) == '#' then img:setPixel(x + c - 1, ACC + r - 1, 1, 1, 1, 1) end
            end
        end
        if g.mark then
            for r, line in ipairs(g.mark) do
                for c = 1, math.min(w, #line) do
                    if line:sub(c, c) == '#' then img:setPixel(x + c - 1, r - 1, 1, 1, 1, 1) end
                end
            end
        end
        x = x + w
    end
    font = love.graphics.newImageFont(img, table.concat(order), 1)
    font:setFilter('nearest', 'nearest')
    return font
end

-- Ancho (px de pantalla) del texto a escala `s` (sin la columna final)
function PixelFont.width(text, s)
    return (build():getWidth(PixelFont.upper(text)) - 1) * s
end
function PixelFont.height(s) return H * s end

-- Dibuja el texto: blanco sobre negro ajustado, con la esquina superior
-- izquierda del cuerpo de las letras en (x, y). `alpha` afecta a todo.
-- color (opcional) = el de las letras ({r, g, b}); el fondo sigue negro
function PixelFont.draw(text, x, y, s, alpha, color)
    local f = build()
    text = PixelFont.upper(text)
    alpha = alpha or 1
    local w = (f:getWidth(text) - 1) * s
    -- (si lleva tildes/eñe, el fondo negro también las cubre)
    local top = text:find('[\195]') and ACC * s or 0
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle('fill', x, y - top, w, H * s + top)
    local prev = love.graphics.getFont()
    love.graphics.setFont(f)
    local c = color or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.print(text, x, y - ACC * s, 0, s, s)
    love.graphics.setFont(prev)
end

return PixelFont
