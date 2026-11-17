-- src/fx/CameraZoom.lua
-- ZOOM DE LA CÁMARA (el usuario, 2026-11-17: «modesto», para la llegada a la meta y reutilizable): agranda la escena
-- ya dibujada alrededor de un punto de la PANTALLA (el jugador). Solo dibujo: la cámara, la simulación y lo que se ve
-- en el borde no cambian (la escena se dibuja en su lienzo con `origin()` — SceneLayers — y es al ponerla en pantalla
-- cuando se agranda). Con k ≥ 1 y el punto dentro de la pantalla, la escena siempre cubre la pantalla entera.
--   local z = CameraZoom.new()
--   z:to(k, secs)             ir a k (1 = sin zoom) en `secs` s, con aceleración y frenada suaves
--   z:update(dt)
--   z:focus(sx, sy)           el punto fijo (px de pantalla; se recorta a la pantalla)
--   z:push() … z:pop()        lo dibujado en medio, agrandado (sin zoom: nada)
--   z:point(sx, sy) → sx, sy  dónde queda en pantalla un punto de la escena (los textos del HUD que van sobre el mundo)
local CameraZoom = {}
CameraZoom.__index = CameraZoom

function CameraZoom.new()
    return setmetatable({ k = 1, from = 1, target = 1, t = 0, dur = 0, fx = 0, fy = 0 }, CameraZoom)
end

function CameraZoom:to(k, secs)
    self.from, self.target, self.t, self.dur = self.k, k, 0, math.max(0, secs or 0)
    if self.dur == 0 then self.k = k end
end

local function smooth(u) u = math.max(0, math.min(1, u)); return u * u * (3 - 2 * u) end

function CameraZoom:update(dt)
    if self.k == self.target then return end
    self.t = self.t + dt
    local u = self.dur > 0 and self.t / self.dur or 1
    self.k = (u >= 1) and self.target or (self.from + (self.target - self.from) * smooth(u))
end

function CameraZoom:focus(sx, sy)
    self.fx = math.floor(math.max(0, math.min(WINDOW_W, sx)) + 0.5)
    self.fy = math.floor(math.max(0, math.min(WINDOW_H, sy)) + 0.5)
end

function CameraZoom:active() return self.k ~= 1 end

function CameraZoom:push()
    love.graphics.push()
    if self.k == 1 then return end
    love.graphics.translate(self.fx, self.fy)
    love.graphics.scale(self.k, self.k)
    love.graphics.translate(-self.fx, -self.fy)
end

function CameraZoom:pop() love.graphics.pop() end

function CameraZoom:point(sx, sy)
    if self.k == 1 then return sx, sy end
    return self.fx + (sx - self.fx) * self.k, self.fy + (sy - self.fy) * self.k
end

return CameraZoom
