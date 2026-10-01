-- src/fx/IceEncase.lua
-- El bloque de hielo que encierra a lo que congela el congelador (jugador,
-- enemigos, jefes): assets/images/fx/ice_block.png (16x16 de 9 trozos, esquinas de
-- 4 px) estirado alrededor de la caja, a escala de píxel entera, con un brillo que
-- pasa. Al final parpadea (`left` = s que le quedan). Solo dibujo.
--   IceEncase.draw(x, y, w, h, t, left)   (px de pantalla; t = tiempo congelado)
local IceEncase = {}

local img, quads
local S = 4                                  -- escala del arte
local C = 4                                  -- esquina (px del arte)

local function load()
    if img ~= nil then return img end
    local ok, im = pcall(love.graphics.newImage, 'assets/images/fx/ice_block.png')
    img = ok and im or false
    if img then
        img:setFilter('nearest', 'nearest')
        local W = img:getWidth()
        local m = W - 2 * C
        local q = function(x, y, w, h) return love.graphics.newQuad(x, y, w, h, W, W) end
        quads = {
            q(0, 0, C, C), q(C, 0, m, C), q(W - C, 0, C, C),
            q(0, C, C, m), q(C, C, m, m), q(W - C, C, C, m),
            q(0, W - C, C, C), q(C, W - C, m, C), q(W - C, W - C, C, C),
        }
    end
    return img
end

-- Shader que tiñe de hielo lo que se dibuje con él (el cuerpo congelado). nil si no hay shaders
local tint
function IceEncase.tint()
    if tint == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
                vec4 p = Texel(tex, uv) * c;
                float l = dot(p.rgb, vec3(0.3, 0.59, 0.11));
                return vec4(mix(p.rgb, vec3(0.55, 0.8, 1.0) * (0.45 + 0.7 * l), 0.6), p.a);
            }]])
        tint = ok and sh or false
    end
    return tint or nil
end

-- Dibuja fn() teñido de hielo
function IceEncase.tinted(fn)
    local sh = IceEncase.tint()
    local prev = love.graphics.getShader()
    if sh then love.graphics.setShader(sh) end
    fn()
    love.graphics.setShader(prev)
end

function IceEncase.draw(x, y, w, h, t, left)
    if not load() then return end
    local pad = 6
    x, y = math.floor(x - pad), math.floor(y - pad)
    w, h = math.floor(w + pad * 2), math.floor(h + pad * 2)
    local a = 1
    if left and left < 0.6 and math.floor(left * 12) % 2 == 0 then a = 0.5 end      -- a punto de romperse
    local c = C * S
    local mw, mh = math.max(0, w - 2 * c), math.max(0, h - 2 * c)
    local m = img:getWidth() - 2 * C
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, quads[1], x, y, 0, S, S)
    love.graphics.draw(img, quads[2], x + c, y, 0, mw / m, S)
    love.graphics.draw(img, quads[3], x + c + mw, y, 0, S, S)
    love.graphics.draw(img, quads[4], x, y + c, 0, S, mh / m)
    love.graphics.draw(img, quads[5], x + c, y + c, 0, mw / m, mh / m)
    love.graphics.draw(img, quads[6], x + c + mw, y + c, 0, S, mh / m)
    love.graphics.draw(img, quads[7], x, y + c + mh, 0, S, S)
    love.graphics.draw(img, quads[8], x + c, y + c + mh, 0, mw / m, S)
    love.graphics.draw(img, quads[9], x + c + mw, y + c + mh, 0, S, S)
    -- brillo que cruza el bloque de vez en cuando (franja diagonal de píxeles)
    local k = ((t or 0) % 1.6) / 1.6
    if k < 0.35 then
        local sx = x + (w + h) * (k / 0.35) - h
        love.graphics.setColor(1, 1, 1, 0.5 * a)
        for i = 0, h - 8, 4 do
            local px = sx + i
            if px > x + 4 and px < x + w - 8 then love.graphics.rectangle('fill', math.floor(px), y + h - 4 - i, 4, 4) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return IceEncase
