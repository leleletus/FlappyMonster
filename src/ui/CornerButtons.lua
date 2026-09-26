-- src/ui/CornerButtons.lua
-- Botones de esquina para ratón/táctil: PAUSA (arriba a la derecha, bajo el
-- contador de vidas) y VOLVER (arriba a la izquierda) en menús que solo se
-- podían dejar con teclado/mando.
-- Solo se dibujan si el último dispositivo usado fue ratón o táctil.

local CornerButtons = {}

local PAUSE = { x = 0, y = 76, w = 56, h = 56 }     -- x se calcula con WINDOW_W
-- Dentro del marco interior de los menús (fondo MenuDif), arriba a la izquierda
local BACK  = { x = 120, y = 118, w = 176, h = 52 }

local function hit(r, x, y, pad)
    pad = pad or 6
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function CornerButtons.pointerMode()
    return Input.isMobile or Input.lastDevice == 'mouse' or Input.lastDevice == 'touch'
end

-- ── Pausa ─────────────────────────────────────────────────────────────────────

function CornerButtons.pauseRect()
    PAUSE.x = WINDOW_W - PAUSE.w - 20
    return PAUSE
end

function CornerButtons.hitPause(x, y) return hit(CornerButtons.pauseRect(), x, y) end

-- Estilo pixel: cuadrado negro con borde blanco en ángulo recto y dos barras
function CornerButtons.drawPause(hover)
    if not CornerButtons.pointerMode() then return end
    local r = CornerButtons.pauseRect()
    local b = 4                                        -- grosor del borde
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', r.x, r.y, r.w, b)
    love.graphics.rectangle('fill', r.x, r.y + r.h - b, r.w, b)
    love.graphics.rectangle('fill', r.x, r.y, b, r.h)
    love.graphics.rectangle('fill', r.x + r.w - b, r.y, b, r.h)
    if hover then
        love.graphics.setColor(1, 0.85, 0, 1)
    end
    local bw, bh = 8, 24
    local cx, cy = math.floor(r.x + r.w / 2), math.floor(r.y + r.h / 2)
    love.graphics.rectangle('fill', cx - bw - 4, cy - bh / 2, bw, bh)
    love.graphics.rectangle('fill', cx + 4,      cy - bh / 2, bw, bh)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Volver ────────────────────────────────────────────────────────────────────

function CornerButtons.hitBack(x, y) return hit(BACK, x, y) end

-- Mismo aspecto que los botones VOLVER de los menús (pixel, sin redondeos):
-- normal = fondo negro con borde blanco; ratón encima = relleno blanco
function CornerButtons.drawBack(hover)
    if not CornerButtons.pointerMode() then return end
    local r = BACK
    if hover then
        love.graphics.setColor(0.18, 0.18, 0.18, 1)
        love.graphics.rectangle('fill', r.x + 4, r.y + 4, r.w, r.h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
        love.graphics.setColor(0, 0, 0, 1)
    else
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', r.x, r.y, r.w, 2)
        love.graphics.rectangle('fill', r.x, r.y + r.h - 2, r.w, 2)
        love.graphics.rectangle('fill', r.x, r.y, 2, r.h)
        love.graphics.rectangle('fill', r.x + r.w - 2, r.y, 2, r.h)
    end
    -- Flecha pixel + texto
    local cy = math.floor(r.y + r.h / 2)
    local ax = r.x + 16
    love.graphics.rectangle('fill', ax, cy - 1, 18, 3)                       -- asta
    for i = 1, 5 do
        love.graphics.rectangle('fill', ax + i * 2, cy - 1 - i * 2, 3, 3)     -- punta superior
        love.graphics.rectangle('fill', ax + i * 2, cy - 1 + i * 2, 3, 3)     -- punta inferior
    end
    love.graphics.setFont(FONT_MED)
    love.graphics.print('VOLVER', ax + 30, cy - FONT_MED:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return CornerButtons
