-- src/ui/Clip.lua
-- Recorte rectangular para la interfaz y el nivel, igual en PC, Switch y
-- Android. setScissor trabaja en píxeles REALES de la pantalla (o del canvas
-- activo), pero dibujamos dentro de lovesize (desplazado y escalado): aquí se
-- transforma el rectángulo con la transformación actual y se INTERSECA con el
-- recorte que ya hubiera (las bandas negras de lovesize); pop lo restaura.
-- (No se usan stencils: en Switch/Android la pantalla puede no tener buffer
-- de stencil y el recorte no hace nada o deja la zona en blanco.)

local Clip = {}
local stack = {}

function Clip.push(x, y, w, h)
    local ox, oy, ow, oh = love.graphics.getScissor()
    stack[#stack + 1] = { ox, oy, ow, oh }
    local sx, sy = love.graphics.transformPoint(x, y)
    local ex, ey = love.graphics.transformPoint(x + w, y + h)
    local x0, y0 = math.floor(math.min(sx, ex)), math.floor(math.min(sy, ey))
    local x1, y1 = math.ceil(math.max(sx, ex)), math.ceil(math.max(sy, ey))
    love.graphics.intersectScissor(x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0))
end

function Clip.pop()
    local s = table.remove(stack)
    if s and s[1] then love.graphics.setScissor(s[1], s[2], s[3], s[4])
    else love.graphics.setScissor() end
end

return Clip
