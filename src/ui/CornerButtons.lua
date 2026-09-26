-- src/ui/CornerButtons.lua
-- Botones de esquina para ratón/táctil: PAUSA (arriba a la derecha, bajo el
-- contador de vidas) y VOLVER (arriba a la izquierda) en menús que solo se
-- podían dejar con teclado/mando.
-- Solo se dibujan si el último dispositivo usado fue ratón o táctil.

local CornerButtons = {}

local PAUSE = { x = 0, y = 76, w = 56, h = 56 }     -- x se calcula con WINDOW_W
local BACK  = { x = 20, y = 18, w = 150, h = 40 }

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

function CornerButtons.drawPause(hover)
    if not CornerButtons.pointerMode() then return end
    local r = CornerButtons.pauseRect()
    love.graphics.setColor(0, 0, 0, hover and 0.65 or 0.45)
    love.graphics.rectangle('fill', r.x, r.y, r.w, r.h, 8, 8)
    love.graphics.setColor(1, 1, 1, hover and 1 or 0.7)
    love.graphics.rectangle('line', r.x, r.y, r.w, r.h, 8, 8)
    local bw, bh = 8, 24
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    love.graphics.rectangle('fill', cx - bw - 4, cy - bh / 2, bw, bh)
    love.graphics.rectangle('fill', cx + 4,      cy - bh / 2, bw, bh)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Volver ────────────────────────────────────────────────────────────────────

function CornerButtons.hitBack(x, y) return hit(BACK, x, y) end

function CornerButtons.drawBack(hover)
    if not CornerButtons.pointerMode() then return end
    local r = BACK
    love.graphics.setColor(0, 0, 0, hover and 0.75 or 0.55)
    love.graphics.rectangle('fill', r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 1, 1, hover and 1 or 0.6)
    love.graphics.rectangle('line', r.x, r.y, r.w, r.h)
    local cy = r.y + r.h / 2
    love.graphics.polygon('fill', r.x + 14, cy, r.x + 24, cy - 8, r.x + 24, cy + 8)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.print('VOLVER', r.x + 34, cy - FONT_SMALL:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return CornerButtons
