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
PointAreas.inside = inside

-- Autoritativo (un jugador y servidor). players = lista de PlayerAdventure
-- activos; award(pa, points, area) reparte los puntos.
function PointAreas.update(level, dt, players, award)
    for _, a in ipairs(level.pointAreas or {}) do
        local here = {}
        for _, pa in ipairs(players) do
            if not pa.dying and pa.alive ~= false and inside(a, pa.x, pa.y) then here[#here+1] = pa end
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
    for _, a in ipairs(level.pointAreas or {}) do
        local n, localIn = 0, false
        for _, p in ipairs(positions) do
            if inside(a, p[1], p[2]) then n = n + 1; if p[3] then localIn = true end end
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
        if t and inside(a, pa.x, pa.y) then return t / a.interval, a end
    end
    return nil
end

-- ── Dibujo (pixel art) ────────────────────────────────────────────────────────
local GOLD  = { 1.00, 0.82, 0.22 }
local RED   = { 1.00, 0.35, 0.30 }

-- Área: suelo dorado que late, borde a trazos que avanza y esquinas marcadas.
-- Disputada (varios dentro sin sumar): roja.
function PointAreas.render(level, camX, camY)
    local t = love.timer.getTime()
    for _, a in ipairs(level.pointAreas or {}) do
        local x, y = math.floor(a.x0 - camX), math.floor(a.y0 - camY)
        local w, h = a.x1 - a.x0, a.y1 - a.y0
        if x < WINDOW_W and y < WINDOW_H and x + w > 0 and y + h > 0 then
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
