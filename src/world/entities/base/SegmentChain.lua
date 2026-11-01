-- src/world/entities/base/SegmentChain.lua
-- CADENA DE SEGMENTOS animada al momento (la idea del usuario para las colas del Escorpión, 2026-10-31): en vez de un
-- sprite por postura, puntos con muelle que persiguen una curva objetivo, con distancia fija entre vecinos. Genérica:
-- sirve para cualquier cola, tentáculo o cuerda.
-- SOLO DIBUJO: vive en el render de quien la usa y nunca decide nada de la simulación (lo que golpea sale de una
-- función pura del estado). Por eso no viaja por la red: el cliente la mueve con lo que ya llega en las instantáneas.
-- El muelle avanza a paso fijo (STEP) y se dibuja interpolado: se mueve igual a cualquier FPS.
local Chain = {}
Chain.__index = Chain

local STEP = 1 / 30
local SAMPLES = 64

function Chain.new(n, gap)
    local c = setmetatable({ n = n, gap = gap, acc = 0, tg = {} }, Chain)
    c.P, c.V, c.Q = {}, {}, {}
    for i = 1, n do
        c.P[i], c.V[i], c.Q[i] = { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }
        c.tg[i] = { x = 0, y = 0 }
    end
    return c
end

-- Coloca la cadena tal cual sobre sus objetivos (el primer dibujo, sin que salga volando desde 0,0)
function Chain:place(fill, ...)
    fill(self.tg, self.n, ...)
    for i = 1, self.n do
        local t = self.tg[i]
        self.P[i].x, self.P[i].y, self.Q[i].x, self.Q[i].y = t.x, t.y, t.x, t.y
        self.V[i].x, self.V[i].y = 0, 0
    end
    self.placed = true
end

local function stepOnce(self, k, damp, stretch)
    local P, V, Q, tg, n = self.P, self.V, self.Q, self.tg, self.n
    for i = 1, n do Q[i].x, Q[i].y = P[i].x, P[i].y end
    P[1].x, P[1].y = tg[1].x, tg[1].y
    for i = 2, n do
        local kk = k * (1 - 0.45 * (i - 1) / n)                     -- (la punta va un poco por detrás: látigo)
        local p, v, t = P[i], V[i], tg[i]
        v.x = (v.x + (t.x - p.x) * kk) * damp
        v.y = (v.y + (t.y - p.y) * kk) * damp
        p.x, p.y = p.x + v.x, p.y + v.y
    end
    local gap = self.gap
    if stretch then                             -- (`stretch` = hasta cuánto se puede estirar para LLEGAR a su objetivo)
        local len = 0
        for i = 2, n do
            local dx, dy = tg[i].x - tg[i - 1].x, tg[i].y - tg[i - 1].y
            len = len + math.sqrt(dx * dx + dy * dy)
        end
        gap = math.max(gap, math.min(gap * stretch, len / (n - 1)))
    end
    for i = 2, n do
        local a, b = P[i - 1], P[i]
        local dx, dy = b.x - a.x, b.y - a.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 0.001 then d, dx, dy = 1, 0, -1 end
        b.x, b.y = a.x + dx / d * gap, a.y + dy / d * gap
    end
end

-- Avanza dt segundos. fill(tg, n, ...) escribe la curva objetivo en tg (solo se llama en cada paso fijo); opts:
-- k = fuerza del muelle, damp, stretch = cuánto puede estirarse como mucho para llegar a la punta de la curva (nil = nada)
function Chain:advance(dt, k, damp, stretch, fill, ...)
    if not self.placed then self:place(fill, ...) end
    self.acc = math.min(self.acc + math.max(0, dt), STEP * 4)
    while self.acc >= STEP do
        self.acc = self.acc - STEP
        fill(self.tg, self.n, ...)
        stepOnce(self, k, damp, stretch)
    end
end

-- La posición que se dibuja del punto i (interpolada entre los dos últimos pasos fijos)
function Chain:pos(i)
    local f = self.acc / STEP
    local a, b = self.Q[i], self.P[i]
    return a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f
end

function Chain:tipAngle()
    local x0, y0 = self:pos(self.n - 1)
    local x1, y1 = self:pos(self.n)
    return math.atan2(y1 - y0, x1 - x0)
end

-- Curva de Bézier cúbica repartida en n puntos a distancia casi igual, escrita en out[1..n]
local px, py, ds = {}, {}, {}
function Chain.bez(out, n, x0, y0, x1, y1, x2, y2, x3, y3)
    ds[0] = 0
    for i = 0, SAMPLES do
        local t = i / SAMPLES
        local u = 1 - t
        local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
        px[i], py[i] = a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3
        if i > 0 then
            local dx, dy = px[i] - px[i - 1], py[i] - py[i - 1]
            ds[i] = ds[i - 1] + math.sqrt(dx * dx + dy * dy)
        end
    end
    local j = 0
    for i = 1, n do
        local s = ds[SAMPLES] * (i - 1) / (n - 1)
        while j < SAMPLES and ds[j + 1] < s do j = j + 1 end
        out[i].x, out[i].y = px[j], py[j]
    end
    return out
end

return Chain
