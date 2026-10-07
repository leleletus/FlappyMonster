-- src/ui/PixelIcons.lua
-- Iconos pixel art pequeños: la corona del host y los iconos de los modos de
-- juego (skull, flag, hill...).

local PixelIcons = {}

-- Los iconos son PNG en assets/images/ui/icons/<nombre>.png (1 píxel del icono =
-- 1 píxel de la imagen). Un icono nuevo (p. ej. el de un modo, campo `icon`)
-- es solo un archivo más. Se dibujan a escala entera `px`, con sombra.
local DIR = 'assets/images/ui/icons/'
local images, dims = {}, {}

local function dimsOf(name)
    local d = dims[name]
    if d == nil then
        local ok, data = pcall(love.image.newImageData, DIR .. name .. '.png')
        d = ok and { data:getWidth(), data:getHeight() } or false
        dims[name] = d
    end
    return d
end

local function imageOf(name)
    local im = images[name]
    if im == nil then
        local ok, i = pcall(love.graphics.newImage, DIR .. name .. '.png')
        im = ok and i or false
        if im then im:setFilter('nearest', 'nearest') end
        images[name] = im
    end
    return im
end

-- Tamaño (en píxeles del icono) de un icono por nombre.
function PixelIcons.size(name)
    local d = dimsOf(name)
    if not d then return 0, 0 end
    return d[1], d[2]
end

PixelIcons.CROWN_W, PixelIcons.CROWN_H = PixelIcons.size('crown')

-- Dibuja el icono `name` con su esquina superior izquierda en (x, y); px =
-- tamaño de cada píxel del icono. Lleva sombra para leerse sobre cualquier fondo.
function PixelIcons.draw(name, x, y, px, alpha)
    local img = imageOf(name)
    if not img then return end
    px, alpha = px or 2, alpha or 1
    x, y = math.floor(x), math.floor(y)
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)                  -- sombra: 1 píxel abajo-derecha
    love.graphics.draw(img, x + px, y + px, 0, px, px)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(img, x, y, 0, px, px)
    love.graphics.setColor(1, 1, 1, 1)
end

function PixelIcons.crown(x, y, px, alpha)
    PixelIcons.draw('crown', x, y, px, alpha)
end

return PixelIcons
