-- src/fx/Silhouette.lua
-- EL BORDE BLANCO del monstruo: el monstruo es casi negro y sobre un fondo oscuro (niveles a oscuras, de noche,
-- cuevas; las cinemáticas del cráter; la pantalla de resultados) solo se le veía la cara. Se dibuja DETRÁS su
-- propio sprite entero de blanco, corrido un poco (`WIDTH`: un tercio de píxel de arte) hacia los ocho lados: queda
-- un filo blanco del mismo grosor en todas partes, pegado a su forma.
-- (La primera idea — el mismo sprite más GRANDE, en blanco, detrás — no vale para una figura tan fina: al
-- escalar, cada parte se aleja del centro una distancia distinta y brazos, piernas y antenas quedaban
-- descolocados respecto al cuerpo. Con copias corridas el borde mide lo mismo en todas partes.)
--   Silhouette.draw(img, x, y, r, sx, sy[, alpha, color])   antes de dibujar el sprite (mismo x, y, giro y escala;
--                                                           origen = el centro de la imagen, como el monstruo)
--   Silhouette.on(level, y)   ¿hace falta en ese nivel, a esa altura? (a oscuras, noche, cueva, o bajo la línea
--                             de superficie de un nivel con profundidad: ahí también hay penumbra)
local Silhouette = {}

Silhouette.COLOR = { 1, 1, 1 }
Silhouette.WIDTH = 1 / 3          -- grosor del borde, en píxeles de ARTE (un píxel entero quedaba muy ancho: el usuario)
local DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

local shader
local function get()
    if shader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(c.rgb, Texel(t, uv).a * c.a); }
        ]])
        shader = ok and sh or false
    end
    return shader or nil
end

function Silhouette.draw(img, x, y, r, sx, sy, alpha, color)
    local sh = get()
    if not (sh and img) then return end
    r = r or 0
    local iw, ih = img:getDimensions()
    local px = math.max(1, math.floor(math.abs(sy) * Silhouette.WIDTH + 0.5))      -- grosor, en píxeles de pantalla
    local c = color or Silhouette.COLOR
    local pr, pg, pb, pa = love.graphics.getColor()
    local prev = love.graphics.getShader()
    love.graphics.setShader(sh)
    love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
    x, y = math.floor(x), math.floor(y)
    for _, d in ipairs(DIRS) do
        love.graphics.draw(img, x + d[1] * px, y + d[2] * px, r, sx, sy, iw / 2, ih / 2)
    end
    love.graphics.setShader(prev)
    love.graphics.setColor(pr, pg, pb, pa)
end

function Silhouette.on(level, y)
    if not level then return false end
    if level.dark then return true end
    local m = level.light
    if m == 'night' or m == 'cave' then return true end
    if level.depth and m ~= 'none' and y then
        return y > require('src/fx/Sky').surfaceY(level)
    end
    return false
end

return Silhouette
