-- src/world/entities/base/ScorpionKit.lua
-- Lo común del ESCORPIÓN (types/enemies/scorpion.lua) y del ESCORPIÓN TRIPLE AGUIJÓN (types/bosses/giantscorpion.lua):
-- dónde nace cada pieza en la hoja del cuerpo, las curvas de la cola y cómo se dibujan segmentos, aguijones y pinzas
-- (hojas de tools/art/enemies/make_scorpion.py). Las curvas se escribieron mirando a la DERECHA; `f` las refleja.
-- Solo dibujo salvo `strikeLine`, que es pura y también la usa la simulación (la cola clavada se puede pisar).
local Chain = require 'src/world/entities/base/SegmentChain'

local K = {}
K.FW, K.FH = 30, 24
-- Anclas en px de arte desde los pies, en el centro del cuadro (hoja: columna 15, última fila de patas 22)
K.TAIL = { -11, -13 }
K.NEAR = { 9.4, -7 }
K.FAR  = { 6.4, -8 }
K.HAND = { 18.8, -9 }
K.HAND_FAR = { 15.8, -15 }
-- (2026-10-31, el usuario: "muy jelly, rebotan y se sacuden demasiado": muelles casi sin rebote)
K.COIL_K, K.COIL_DAMP = 0.7, 0.5         -- (enrollarse / desenrollarse: unos 0,2 s)
K.FAST_K, K.FAST_DAMP = 0.85, 0.45         -- (el golpe)
K.CALM_K, K.CALM_DAMP = 0.3, 0.45
K.TIP_D = 6                                -- px de arte: del centro del aguijón a su pincho, al clavarse en diagonal

local TAU = math.pi * 2

-- ── Curvas objetivo: fill(tg, n, ...) para SegmentChain ──────────────────────
-- Tres colas abiertas como un tridente sobre el lomo, cada punta hacia delante. i = 1, 2, 3
local FAN = { { -14, -29 }, { 6, -41 }, { 27, -29 } }
function K.fan(tg, n, bx, by, k, f, i, t, up)
    local sway = math.sin(t * 1.2 + (i - 1) * 2.1) * 0.4 * k
    local tx, ty = bx + FAN[i][1] * k * f + sway, by + FAN[i][2] * k * (up or 1)
    Chain.bez(tg, n, bx, by, bx + (-11 + (i - 1) * 7) * k * f, by - 11 * k, tx - 11 * k * f, ty - 9 * k, tx, ty)
end

-- Entrelazadas: una sola curva gruesa hasta (tx, ty) y cada cola da vueltas alrededor. Fase de la vuelta del punto j:
function K.braidPhase(j, n, i, t) return (j - 1) / n * TAU * 2.2 + (i - 1) * TAU / 3 + t * 0.3 end
local ctr = {}
function K.braid(tg, n, bx, by, k, f, i, t, tx, ty, up, amp)
    for j = #ctr + 1, n do ctr[j] = { x = 0, y = 0 } end
    up, amp = up or 1, amp or 1.5
    Chain.bez(ctr, n, bx, by, bx - 9 * k * f, by - 16 * k, tx - 12 * k * f, ty - 26 * k * up, tx, ty)
    for j = 1, n do
        local a0, a1 = ctr[math.max(1, j - 1)], ctr[math.min(n, j + 1)]
        local nx, ny = -(a1.y - a0.y), a1.x - a0.x
        local d = math.sqrt(nx * nx + ny * ny)
        if d < 0.001 then d = 1 end
        local s = math.sin(K.braidPhase(j, n, i, t)) * amp * k * math.min(1, (j - 1) / 2) * (1 - 0.5 * (j - 1) / n)
        tg[j].x, tg[j].y = ctr[j].x + nx / d * s, ctr[j].y + ny / d * s
    end
end

-- Un aguijón directo: su PINCHO en (tx, ty)
function K.strike(tg, n, bx, by, k, f, tx, ty)
    tx, ty = tx - K.TIP_D * k * f, ty - K.TIP_D * k
    Chain.bez(tg, n, bx, by, bx + 10 * k * f, by - 18 * k, tx - 12 * k * f, ty - 12 * k, tx, ty)
end

-- PURA: los `m` puntos de la cola clavada, de la base a la punta (la simulación pisa aquí, el dibujo va por ahí cerca)
function K.strikeLine(out, m, bx, by, k, f, tx, ty)
    for j = #out + 1, m do out[j] = { x = 0, y = 0 } end
    return Chain.bez(out, m, bx, by, bx + 10 * k * f, by - 18 * k, tx - 12 * k * f, ty - 12 * k, tx, ty)
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function dirIndex(a) return math.floor(a / TAU * 16 + 0.5) % 16 + 1 end
K.dirIndex = dirIndex

local function segIndex(j, n) return math.min(5, math.floor((j - 1) * 5 / n) + 1) end

-- El segmento j de una cadena (shade: la cola de atrás, más oscura; a = alfa)
function K.drawSeg(set, chain, j, k, camX, camY, shade, a)
    local x, y = chain:pos(j)
    love.graphics.setColor(shade or 1, shade or 1, shade or 1, a or 1)
    set:drawFrame(set:frameN('segment', segIndex(j, chain.n)), math.floor(x - camX), math.floor(y - camY), 0, k, k, 0.5, 0.5)
end

function K.drawStinger(set, chain, name, flash, k, camX, camY, a)
    local x, y = chain:pos(chain.n)
    love.graphics.setColor(1, 1, 1, a or 1)
    set:drawFrame(set:frameN(flash and 'stinger_flash' or name, dirIndex(chain:tipAngle())),
                  math.floor(x - camX), math.floor(y - camY), 0, k, k, 0.5, 0.5)
end

function K.drawTail(set, chain, name, flash, k, camX, camY, shade, a)
    for j = 1, chain.n - 1 do K.drawSeg(set, chain, j, k, camX, camY, shade, a) end
    K.drawStinger(set, chain, name, flash, k, camX, camY, a)
end

-- Un brazo: del hombro a la mano, sus segmentos y la pinza
function K.drawArm(set, sx, sy, hx, hy, ang, opened, k, camX, camY, shade, a)
    local s = shade or 1
    love.graphics.setColor(s, s, s, a or 1)
    local fr = set:frameN('segment', 4)
    local dx, dy = hx - sx, hy - sy
    local segs = math.max(3, math.floor(math.sqrt(dx * dx + dy * dy) / (3.2 * k)))     -- (estirado, más: que no se vea suelto)
    for i = 0, segs - 1 do
        local t = i / segs
        set:drawFrame(fr, math.floor(sx + (hx - sx) * t - camX),
                      math.floor(sy + (hy - sy) * t + math.sin(t * math.pi) * k - camY), 0, k, k, 0.5, 0.5)
    end
    set:drawFrame(set:frameN(opened and 'pincer_open' or 'pincer_closed', dirIndex(ang)),
                  math.floor(hx - camX), math.floor(hy - camY), 0, k, k, 0.5, 0.5)
end

return K
