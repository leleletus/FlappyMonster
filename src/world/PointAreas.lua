-- src/world/PointAreas.lua
-- Zonas de puntos: rectángulos del nivel que dan puntos a quien está dentro
-- (el objetivo del modo "Rey de la Colina", pero funcionan en cualquier modo
-- y en un jugador). Se colocan con la entidad "Zona de puntos"
-- (types/pointarea.lua); el nivel las construye a partir de esas colocaciones.
--
--  * Cada jugador dentro (su centro) acumula tiempo; cada `interval` segundos
--    recibe `points`. Al salir, su contador vuelve a cero.
--  * `contested`: si hay más de un jugador dentro, nadie suma (hay que
--    echar a los demás).
--
--  * UNA SOLA ZONA ACTIVA A LA VEZ (el usuario: con varias a la vez cada uno se queda en la suya sumando y nadie
--    se pelea): con dos o más zonas en el nivel, sus sitios son las PARADAS de una única zona que va de una a
--    otra — `HOLD` s en cada parada (`FIRST` más en la primera) y `MOVE` s de viaje hasta la siguiente (viajando no da puntos) —. Cuál toca
--    es una función pura del reloj de las zonas (`level.zoneClock`): igual en un jugador, en el servidor (que lo
--    manda en la instantánea, `zc`) y en el cliente. Con una sola zona, nada cambia.
--      PointAreas.state(level)  → activa | nil, desde, hacia, u (0..1 del viaje), s que le quedan en la parada
--      PointAreas.isActive(level, a) · PointAreas.target(level) (adónde ir: la activa, o ya la siguiente si
--      está a punto de irse) · PointAreas.live(level) (lista con la activa, o vacía mientras viaja)
--
-- Los puntos los reparte quien manda: el modo un jugador y el servidor
-- (PointAreas.update con una función `award`). El cliente online solo dibuja:
-- PointAreas.clientUpdate calcula quién está dentro y el progreso del
-- jugador local para la barra (los puntos, el sonido y las partículas le
-- llegan como eventos).

local PointAreas = {}

local function num(v, d) v = tonumber(v); return v or d end

function PointAreas.fromPlacement(pl)
    local p = pl.props or {}
    local cr = p.corner or {}
    local c0, c1 = math.min(pl.col, num(cr.col, pl.col)), math.max(pl.col, num(cr.col, pl.col))
    local r0, r1 = math.min(pl.row, num(cr.row, pl.row)), math.max(pl.row, num(cr.row, pl.row))
    local T = TILE_PX
    return {
        col0 = c0, row0 = r0, col1 = c1, row1 = r1,
        x0 = (c0 - 1) * T, x1 = c1 * T, y0 = (r0 - 1) * T, y1 = r1 * T,
        points    = math.max(0, math.floor(num(p.points, 1))),
        interval  = math.max(0.05, num(p.interval, 1)),
        contested = p.contested == true,
        timers    = setmetatable({}, { __mode = 'k' }),   -- [jugador] = s acumulados
        count     = 0,        -- jugadores dentro (para el dibujo)
        scoring   = false,    -- ¿está dando puntos ahora mismo?
        flash     = 0,        -- destello al dar puntos (visual)
    }
end

function PointAreas.build(placements)
    local out = {}
    for _, pl in ipairs(placements or {}) do
        if pl.type == 'pointarea' then out[#out+1] = PointAreas.fromPlacement(pl) end
    end
    return out
end

local function inside(a, x, y) return x >= a.x0 and x < a.x1 and y >= a.y0 and y < a.y1 end

-- ── La zona única que se mueve ───────────────────────────────────────────────
PointAreas.HOLD = 18          -- s en cada parada (con 12 casi no daba tiempo a llegar: las paradas pueden quedar a 10 s de camino)
PointAreas.FIRST = 6          -- s de más en la PRIMERA (todos salen lejos de ella)
PointAreas.MOVE = 2.5         -- s de viaje a la siguiente
PointAreas.SOON = 3           -- s antes de irse en que la siguiente parada ya avisa (parpadea)
PointAreas.LEAVE = 1.2        -- s antes de irse en que `target` ya es la siguiente (el bot sale con ventaja)

-- Orden de las paradas: empieza por la más CÉNTRICA (ni tu lado ni el del rival) y sigue en el orden del nivel
local function order(level)
    local list = level.pointAreas or {}
    if level._zoneOrder and #level._zoneOrder == #list then return level._zoneOrder end
    local mid = (level.tileW or 0) * TILE_PX / 2
    local first, bd = 1, nil
    for i, a in ipairs(list) do
        local d = math.abs((a.x0 + a.x1) / 2 - mid)
        if not bd or d < bd - 1 then first, bd = i, d end
    end
    local o = {}
    for k = 0, #list - 1 do o[#o + 1] = (first - 1 + k) % #list + 1 end
    level._zoneOrder = o
    return o
end

function PointAreas.state(level)
    local list = level.pointAreas or {}
    local n = #list
    if n == 0 then return nil end
    if n == 1 then return list[1], list[1], list[1], 0, math.huge end
    local o = order(level)
    local C = PointAreas.HOLD + PointAreas.MOVE
    local t = math.max(0, level.zoneClock or 0)
    if t < PointAreas.HOLD + PointAreas.FIRST then return list[o[1]], list[o[1]], list[o[2]], 0, PointAreas.HOLD + PointAreas.FIRST - t end
    t = t - PointAreas.FIRST
    local k = math.floor(t / C)
    local ph = t - k * C
    local from, to = list[o[k % n + 1]], list[o[(k + 1) % n + 1]]
    if ph < PointAreas.HOLD then return from, from, to, 0, PointAreas.HOLD - ph end
    return nil, from, to, (ph - PointAreas.HOLD) / PointAreas.MOVE, 0
end
function PointAreas.isActive(level, a) return (PointAreas.state(level)) == a end
function PointAreas.live(level)
    local a = PointAreas.state(level)
    return a and { a } or {}
end
-- Adónde conviene ir: la activa; si se va a ir enseguida (o ya viaja), la siguiente
function PointAreas.target(level)
    local a, _, to, _, left = PointAreas.state(level)
    if not a or left < PointAreas.LEAVE then return to end
    return a
end
function PointAreas.netPack(level)
    if #(level.pointAreas or {}) < 2 then return nil end
    return math.floor((level.zoneClock or 0) * 100 + 0.5)
end
function PointAreas.netApply(level, zc)
    if zc then level.zoneClock = zc / 100 end
end
PointAreas.inside = inside

-- Autoritativo (un jugador y servidor). players = lista de PlayerAdventure
-- activos; award(pa, points, area) reparte los puntos.
function PointAreas.update(level, dt, players, award)
    level.zoneClock = (level.zoneClock or 0) + dt
    local active = PointAreas.state(level)
    for _, a in ipairs(level.pointAreas or {}) do
        local here = {}
        if a == active then
            for _, pa in ipairs(players) do
                if not pa.dying and pa.alive ~= false and inside(a, pa.x, pa.y) then here[#here+1] = pa end
            end
        end
        a.count = #here
        a.scoring = #here > 0 and not (a.contested and #here > 1)
        -- Quien no está dentro (o está disputada) pierde su progreso
        for pa in pairs(a.timers) do
            local stay = false
            if a.scoring then for _, q in ipairs(here) do if q == pa then stay = true end end end
            if not stay then a.timers[pa] = nil end
        end
        if a.scoring then
            for _, pa in ipairs(here) do
                local t = (a.timers[pa] or 0) + dt
                if t >= a.interval - 1e-6 then          -- (tolerancia: 30 × 1/60 = 0,4999…)
                    t = t - a.interval
                    a.flash = 1
                    if a.points > 0 and award then award(pa, a.points, a) end
                end
                a.timers[pa] = t
            end
        end
        a.flash = math.max(0, a.flash - dt * 3)
    end
end

-- Cliente online: solo lo visual. `positions` = { {x, y, isLocal}, ... }
function PointAreas.clientUpdate(level, dt, positions)
    level.zoneClock = (level.zoneClock or 0) + dt          -- (entre instantáneas; el servidor la corrige: netApply)
    local active = PointAreas.state(level)
    for _, a in ipairs(level.pointAreas or {}) do
        local n, localIn = 0, false
        if a == active then
            for _, p in ipairs(positions) do
                if inside(a, p[1], p[2]) then n = n + 1; if p[3] then localIn = true end end
            end
        end
        a.count = n
        a.scoring = n > 0 and not (a.contested and n > 1)
        if localIn and a.scoring then
            a.localT = (a.localT or 0) + dt
            if a.localT >= a.interval - 1e-6 then a.localT = a.localT - a.interval end
        else
            a.localT = nil
        end
        a.flash = math.max(0, a.flash - dt * 3)
    end
end

-- Destello al dar puntos (el cliente lo pide al llegar el evento)
function PointAreas.flashAt(level, x, y)
    for _, a in ipairs(level.pointAreas or {}) do
        if inside(a, x, y) then a.flash = 1 end
    end
end

-- Progreso (0..1) del jugador `pa` en la zona en la que está, o nil
function PointAreas.progressOf(level, pa)
    for _, a in ipairs(level.pointAreas or {}) do
        local t = a.timers[pa] or (pa.isLocalView and a.localT)
        if t and PointAreas.isActive(level, a) and inside(a, pa.x, pa.y) then return t / a.interval, a end
    end
    return nil
end

-- ── Dibujo (pixel art) ────────────────────────────────────────────────────────
local GOLD  = { 1.00, 0.82, 0.22 }
local RED   = { 1.00, 0.35, 0.30 }

-- Área: suelo dorado que late, borde a trazos que avanza y esquinas marcadas.
-- Disputada (varios dentro sin sumar): roja.
-- Contorno de una parada (o de la zona viajando): esquinas + borde fino
local function ghost(x, y, w, h, col, alpha)
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
        love.graphics.rectangle('fill', c[3] > 0 and c[1] or c[1] - 12, c[4] > 0 and c[2] or c[2] - 4, 12, 4)
        love.graphics.rectangle('fill', c[3] > 0 and c[1] or c[1] - 4, c[4] > 0 and c[2] or c[2] - 12, 4, 12)
    end
    love.graphics.setColor(col[1], col[2], col[3], alpha * 0.35)
    love.graphics.rectangle('line', x, y, w, h)
end

function PointAreas.render(level, camX, camY)
    local t = love.timer.getTime()
    local active, from, to, u, left = PointAreas.state(level)
    for _, a in ipairs(level.pointAreas or {}) do
        local x, y = math.floor(a.x0 - camX), math.floor(a.y0 - camY)
        local w, h = a.x1 - a.x0, a.y1 - a.y0
        if a ~= active then
            -- una PARADA sin la zona: su contorno tenue; la siguiente parpadea cuando la zona está al llegar
            if x < WINDOW_W and y < WINDOW_H and x + w > 0 and y + h > 0 then
                local soon = a == to and (not active or left < PointAreas.SOON)
                ghost(x, y, w, h, GOLD, soon and (0.35 + 0.45 * math.abs(math.sin(t * 9))) or 0.22)
            end
        elseif x < WINDOW_W and y < WINDOW_H and x + w > 0 and y + h > 0 then
            local col = (a.count > 0 and not a.scoring) and RED or GOLD
            local on  = a.scoring and 1 or 0
            -- Relleno (más vivo cuando da puntos) + destello
            local pulse = 0.5 + 0.5 * math.sin(t * (on > 0 and 6 or 2.5))
            love.graphics.setColor(col[1], col[2], col[3], 0.07 + 0.06 * pulse + 0.08 * on + 0.25 * a.flash)
            love.graphics.rectangle('fill', x, y, w, h)
            -- Columnas de luz que suben (4 px)
            love.graphics.setColor(col[1], col[2], col[3], 0.18 + 0.2 * on)
            for k = 0, math.floor(w / 32) - 1 do
                local ph = (t * (0.6 + 0.9 * on) + k * 0.37) % 1
                local py = math.floor(y + h - ph * h)
                love.graphics.rectangle('fill', x + k * 32 + 14, py, 4, math.min(12, y + h - py))
            end
            -- Borde a trazos que avanza
            local dash, off = 12, math.floor(t * 30) % 24
            love.graphics.setColor(col[1], col[2], col[3], 0.75 + 0.25 * on)
            for xx = x - off, x + w, 24 do
                local a0, a1 = math.max(x, xx), math.min(x + w, xx + dash)
                if a1 > a0 then
                    love.graphics.rectangle('fill', a0, y, a1 - a0, 3)
                    love.graphics.rectangle('fill', a0, y + h - 3, a1 - a0, 3)
                end
            end
            for yy = y - off, y + h, 24 do
                local b0, b1 = math.max(y, yy), math.min(y + h, yy + dash)
                if b1 > b0 then
                    love.graphics.rectangle('fill', x, b0, 3, b1 - b0)
                    love.graphics.rectangle('fill', x + w - 3, b0, 3, b1 - b0)
                end
            end
            -- Esquinas
            love.graphics.setColor(1, 1, 1, 0.9)
            for _, c in ipairs({ { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }) do
                love.graphics.rectangle('fill', c[3] > 0 and c[1] or c[1] - 12, c[4] > 0 and c[2] or c[2] - 4, 12, 4)
                love.graphics.rectangle('fill', c[3] > 0 and c[1] or c[1] - 4, c[4] > 0 and c[2] or c[2] - 12, 4, 12)
            end
            -- Etiqueta "+N" arriba
            if FONT_SMALL then
                local label = '+' .. a.points
                love.graphics.setFont(FONT_SMALL)
                local lw = FONT_SMALL:getWidth(label)
                local lx, ly = math.floor(x + w / 2 - lw / 2), y + 8
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.print(label, lx + 2, ly + 2)
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.print(label, lx, ly)
            end
        end
    end
    -- VIAJANDO: el rectángulo entre las dos paradas (no da puntos) con su estela
    if not active and from and to then
        local q = u * u * (3 - 2 * u)
        local function lerp(a, b) return a + (b - a) * q end
        local x, y = math.floor(lerp(from.x0, to.x0) - camX), math.floor(lerp(from.y0, to.y0) - camY)
        local w, h = lerp(from.x1 - from.x0, to.x1 - to.x0), lerp(from.y1 - from.y0, to.y1 - to.y0)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.16)
        love.graphics.rectangle('fill', x, y, w, h)
        ghost(x, y, w, h, GOLD, 0.9)
    end
    -- ¿La zona (o adonde va) queda FUERA de la pantalla? Una flecha en el borde dice hacia dónde está
    if #(level.pointAreas or {}) > 1 then
        local a = active or to
        local ax, ay = (a.x0 + a.x1) / 2 - camX, (a.y0 + a.y1) / 2 - camY
        if ax < 0 or ax > WINDOW_W or ay < 0 or ay > WINDOW_H then
            local m = 54
            local px, py = math.max(m, math.min(WINDOW_W - m, ax)), math.max(m + 60, math.min(WINDOW_H - m, ay))
            local ang = math.atan2(ay - py, ax - px)
            local k = 1 + 0.15 * math.sin(t * 8)
            love.graphics.push()
            love.graphics.translate(math.floor(px), math.floor(py))
            love.graphics.rotate(ang)
            love.graphics.scale(k, k)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.polygon('fill', 22, 3, -12, -15, -12, 21)
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], active and 1 or 0.6)
            love.graphics.polygon('fill', 20, 0, -12, -16, -12, 16)
            love.graphics.pop()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Barra de progreso sobre la cabeza del jugador (hasta el próximo punto)
function PointAreas.drawProgress(level, pa, sx, sy)
    local k, a = PointAreas.progressOf(level, pa)
    if not k then return end
    local w, h = 44, 6
    local x, y = math.floor(sx - w / 2), math.floor(sy - 70)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', x - 2, y - 2, w + 4, h + 4)
    love.graphics.setColor(GOLD[1] * 0.4, GOLD[2] * 0.4, GOLD[3] * 0.4, 1)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
    love.graphics.rectangle('fill', x, y, math.floor(w * math.min(1, k)), h)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle('fill', x, y, math.floor(w * math.min(1, k)), 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return PointAreas
