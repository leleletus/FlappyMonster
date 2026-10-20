-- src/ui/menu/MenuAnim.lua
-- ANIMACIONES DE ENTRADA Y SALIDA de una pantalla de menú (docs/architecture/menus.md). Cada pantalla tiene una; sus
-- elementos (título, botones...) piden su desplazamiento por número de orden y entran ESCALONADOS (uno detrás de
-- otro) con un rebote al final; al salir se van rápido hacia el otro lado y, al acabar, se llama a la función de
-- salida (el cambio de estado). Todo a saltos de píxel (múltiplos de STEP px): nada de posiciones con decimales.
--   local A = MenuAnim.new()
--   A:update(dt)                  (en el update de la pantalla)
--   A:leave(fn)                   empieza la salida; fn() al acabar (una sola vez)
--   A:busy()                      true mientras sale (la pantalla no atiende al mando)
--   A:slide(i, dx, dy[, ex, ey])  → ox, oy, alpha del elemento i (entra desde dx, dy; sale hacia ex, ey o -dx, -dy)
--   A:pop(i)                      → escala 0..~1.1..1 (aparece "botando")
local MenuAnim = {}
MenuAnim.__index = MenuAnim

MenuAnim.IN = 0.42          -- s que tarda en entrar cada elemento
MenuAnim.OUT = 0.22         -- s que tarda en salir
MenuAnim.STAGGER = 0.06     -- s entre un elemento y el siguiente
MenuAnim.STEP = 4           -- px: los desplazamientos van a saltos de STEP

local function clamp(v) return v < 0 and 0 or (v > 1 and 1 or v) end
-- 0..1 que se pasa un poco y vuelve (entrada con rebote)
local function back(k) k = k - 1; return 1 + k * k * (2.6 * k + 1.6) end
local function quant(v) return math.floor(v / MenuAnim.STEP + 0.5) * MenuAnim.STEP end

function MenuAnim.new(o)
    o = o or {}
    return setmetatable({ t = o.t or 0, out = nil, fn = nil, n = o.n or 6 }, MenuAnim)
end

function MenuAnim:update(dt)
    self.t = self.t + dt
    if self.out then
        self.out = self.out + dt
        if self.fn and self.out >= MenuAnim.OUT + MenuAnim.STAGGER * 0.5 * self.n then
            local fn = self.fn
            self.fn = nil
            fn()
        end
    end
end

function MenuAnim:leave(fn, n)
    if self.out then return end
    self.out, self.fn, self.n = 0, fn, n or self.n
end

function MenuAnim:busy() return self.out ~= nil end
function MenuAnim:leaving() return self.out ~= nil end

-- Progreso de entrada (con rebote) y de salida del elemento i
function MenuAnim:k(i)
    local kin = back(clamp((self.t - (i - 1) * MenuAnim.STAGGER) / MenuAnim.IN))
    local kout = 0
    if self.out then
        local k = clamp((self.out - (i - 1) * MenuAnim.STAGGER * 0.5) / MenuAnim.OUT)
        kout = k * k
    end
    return kin, kout
end

-- (ex, ey: hacia dónde SALE; por defecto, al lado contrario del que entra. El logo y los rótulos de arriba entran
-- desde arriba y salen también por arriba: hacia abajo cruzaban la pantalla)
function MenuAnim:slide(i, dx, dy, ex, ey)
    local kin, kout = self:k(i)
    dx, dy = dx or 0, dy or 0
    ex, ey = ex or -dx, ey or -dy
    local a = clamp(math.min(kin * 3, 1 - kout))
    return quant(dx * (1 - kin) + ex * kout), quant(dy * (1 - kin) + ey * kout), a
end

function MenuAnim:pop(i)
    local kin, kout = self:k(i)
    return math.max(0, kin * (1 - kout))
end

return MenuAnim
