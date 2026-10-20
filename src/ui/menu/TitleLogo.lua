-- src/ui/menu/TitleLogo.lua
-- EL LOGO DEL JUEGO remasterizado (assets/images/ui/menus/title_logo.png + .json, de tools/art/ui/make_menu_ui.py):
-- el recuadro blanco y cada letra por separado, para animarlas. Lo usan el título (src/states/menu/TitleState.lua)
-- y el final de la historia (src/story/films/ending.lua).
--   TitleLogo.size(s)                       → ancho, alto en pantalla a escala s
--   TitleLogo.draw(x, y, s, o)              esquina de arriba a la izquierda; o:
--       t       s desde que empezó a salir (con intro = true: el recuadro cae botando y las letras salen una a una)
--       intro   animar la entrada
--       wave    las letras se mecen en ola (t)
--       alpha, shadow (px de la sombra negra; 4 por defecto, false = sin)
--   TitleLogo.introTime()                   s que dura la entrada
local json = require 'libs/json'

local TitleLogo = {}

TitleLogo.BOX_T = 0.45        -- s que tarda el recuadro en caer
TitleLogo.DROP = 0.06         -- s entre letra y letra al salir
TitleLogo.POP_T = 0.16        -- s que tarda cada letra en asentarse

local logo
local function load()
    if logo then return logo end
    local im = love.graphics.newImage('assets/images/ui/menus/title_logo.png')
    im:setFilter('nearest', 'nearest')
    local data = json.decode(love.filesystem.read('assets/images/ui/menus/title_logo.json'))
    local b = data.box
    logo = { img = im, w = data.w, h = data.h, letters = {}, box = love.graphics.newQuad(b.sx, b.sy, b.w, b.h, im:getDimensions()) }
    for i, l in ipairs(data.letters) do
        logo.letters[i] = { q = love.graphics.newQuad(l.sx, l.sy, l.w, l.h, im:getDimensions()), x = l.x, y = l.y }
    end
    return logo
end

local function back(k) k = math.max(0, math.min(1, k)) - 1; return 1 + k * k * (2.7 * k + 1.7) end

function TitleLogo.size(s) local lg = load(); return lg.w * s, lg.h * s end
function TitleLogo.introTime() return TitleLogo.BOX_T + (#load().letters - 1) * TitleLogo.DROP + TitleLogo.POP_T end

function TitleLogo.draw(x, y, s, o)
    o = o or {}
    local lg = load()
    local t, alpha = o.t or 0, o.alpha or 1
    x, y = math.floor(x), math.floor(y)
    local intro = o.intro and t < TitleLogo.introTime()
    -- el recuadro cae desde arriba con rebote (desde fuera de la pantalla, a saltos de un píxel del logo)
    local by = 0
    if intro then by = math.floor((1 - back(t / TitleLogo.BOX_T)) * -(y + lg.h * s + 40) / s) * s end
    if o.shadow ~= false then
        local sh = o.shadow or 4
        love.graphics.setColor(0, 0, 0, 0.4 * alpha)
        love.graphics.draw(lg.img, lg.box, x + sh, y + by + sh, 0, s, s)
    end
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(lg.img, lg.box, x, y + by, 0, s, s)
    for i, l in ipairs(lg.letters) do
        local dy, a = 0, 1
        if intro then
            -- cada letra sale con un saltito de 2 píxeles del logo y se asienta
            local k = (t - TitleLogo.BOX_T - (i - 1) * TitleLogo.DROP) / TitleLogo.POP_T
            if k <= 0 then a = 0
            else
                k = math.min(1, k)
                dy = -math.floor((1 - back(k)) * 2 + 0.5) * s
                a = k < 0.34 and 0.4 or (k < 0.67 and 0.75 or 1)
            end
        end
        -- la ola: cada letra sube un píxel del logo y baja, desfasada
        local wave = (o.wave and math.sin(t * 3 - i * 0.55) > 0.6) and -s or 0
        if a > 0 then
            love.graphics.setColor(1, 1, 1, a * alpha)
            love.graphics.draw(lg.img, l.q, x + l.x * s, y + by + l.y * s + dy + wave, 0, s, s)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return TitleLogo
