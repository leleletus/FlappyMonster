-- src/world/entities/base/GloomyNav.lua
-- CAMINO de un trepador que además SALTA (el Crabby lúgubre) hasta un punto del nivel: de superficie en
-- superficie. Antes solo sabía recorrer la superficie en la que estaba y dar UN salto directo al sitio si lo tenía
-- a la vista: con el jugador en una plataforma alta se quedaba debajo, intentándolo sin parar.
--
-- Aquí se busca (A*) entre dos clases de pasos, los que de verdad sabe dar:
--   · TREPAR: `STEP` px por su superficie en un sentido — con el mismo código con el que anda (Crawler.move sobre
--     una copia): suelo, paredes, techo, esquinas hacia dentro y hacia fuera;
--   · SALTAR: a un punto de apoyo (suelo, pared o techo de alguna casilla) a `LEAP` como mucho y con el paso libre
--     — de la pared a una plataforma, del suelo a una repisa, del techo abajo… — (cuesta más que andar lo mismo:
--     tiene que agacharse y recuperarse);
--   · SOLTARSE: desde un techo o una pared, dejarse caer en vertical hasta el primer suelo de debajo.
-- El resultado son TRAMOS que su estado 'hunt' ejecuta uno tras otro:
--   { kind = 'crawl', dir = ±1, left = px, x, y, nx, ny }   (x, y, nx, ny: dónde y en qué superficie acaba)
--   { kind = 'leap', x, y, nx, ny }     { kind = 'drop', x, y, nx, ny }
-- Si no encuentra cómo llegar del todo devuelve el camino hasta el punto MÁS CERCANO que alcanza (y `false`).
-- Solo simulación (un jugador / servidor): el cliente dibuja lo que le llega. Acotado: `MAX_NODES` expansiones.
local Crawler = require 'src/world/entities/base/Crawler'

local Nav = {}
local T = TILE_PX
Nav.STEP = 48                 -- px por paso de trepar
Nav.LEAP = 5 * T              -- alcance de un salto
Nav.LEAP_MIN = 1.6 * T        -- no salta a lo que tiene al lado (para eso anda)
Nav.LEAP_COST = 260           -- px "de más" que cuesta un salto (agacharse + recuperarse)
Nav.MAX_NODES = 600
Nav.GREED = 1.6               -- peso de "lo que falta" (busca más derecho al sitio: menos nodos)
Nav.DROP_MAX = 14 * T         -- lo más que se deja caer
Nav.ARRIVE = 1.1 * T

local function keyOf(x, y, nx, ny)
    return math.floor(x / 32) + math.floor(y / 32) * 4096 + ((nx + 1) + (ny + 1) * 3) * 16777216
end

-- ¿Paso libre en línea recta? (y por el arco del salto: a mitad de camino sube ~1 casilla sobre la recta)
local function clear(level, x0, y0, x1, y1)
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.floor(d / 16))
    for i = 1, n - 1 do
        local k = i / n
        local x, y = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        if level:collisionAt(x, y) then return false end
        if level:collisionAt(x, y - 60 * 4 * k * (1 - k)) then return false end
    end
    return true
end

-- Copia "de papel" del trepador en ese punto: lo justo para Crawler.move
local function ghost(e, s, dir)
    return { x = s.x, y = s.y, cnx = s.nx, cny = s.ny, cdir = dir, outerH = e.outerH, outerW = e.outerW,
             sprW = e.sprW, sprH = e.sprH, speed = e.speed, crawl = true, cattached = true }
end

-- Puntos de apoyo a los que saltar desde `s`: por cada casilla libre cercana, el suelo de debajo, el techo de
-- encima y las paredes de los lados (los que tenga). Solo los que ACERCAN al destino (saltar por saltar, no).
local function landings(e, level, s, gx, gy, hNow)
    local out = {}
    local hh = (e.outerH or 40) / 2
    local c0, r0 = math.floor(s.x / T), math.floor(s.y / T)
    local R = math.ceil(Nav.LEAP / T)
    for r = r0 - R, r0 + R do
        for c = c0 - R, c0 + R do
            local cx, cy = c * T + T / 2, r * T + T / 2
            if c >= 0 and r >= 0 and c < level.tileW and r < level.tileH and not level:collisionAt(cx, cy) then
                local cand
                if level:collisionAt(cx, cy + T) then cand = { cx, r * T + T - hh, 0, -1 }                 -- suelo
                elseif level:collisionAt(cx + T, cy) then cand = { c * T + T - hh, cy, -1, 0 }             -- pared a la derecha
                elseif level:collisionAt(cx - T, cy) then cand = { c * T + hh, cy, 1, 0 }                  -- pared a la izquierda
                elseif level:collisionAt(cx, cy - T) then cand = { cx, r * T + hh, 0, 1 } end              -- techo
                if cand then
                    local d = math.sqrt((cand[1] - s.x) ^ 2 + (cand[2] - s.y) ^ 2)
                    local h = math.sqrt((cand[1] - gx) ^ 2 + (cand[2] - gy) ^ 2)
                    if d <= Nav.LEAP and d >= Nav.LEAP_MIN and h < hNow - T * 0.5 and clear(level, s.x, s.y, cand[1], cand[2]) then
                        out[#out + 1] = { x = cand[1], y = cand[2], nx = cand[3], ny = cand[4], d = d }
                    end
                end
            end
        end
    end
    return out
end

-- Dejarse caer desde `s` (techo o pared): el suelo de debajo, o nil
local function dropTo(e, level, s)
    if s.ny == -1 then return nil end
    local hh = (e.outerH or 40) / 2
    local y = s.y + hh + 2
    if level:collisionAt(s.x, y) then return nil end
    local y1 = math.min(s.y + Nav.DROP_MAX, (level.heightPx or 1e9) - 1)
    while y < y1 do
        y = y + 8
        if level:collisionAt(s.x, y) then
            local top = math.floor(y / 8) * 8
            while top > s.y and level:collisionAt(s.x, top - 1) do top = top - 1 end
            return { x = s.x, y = top - hh, nx = 0, ny = -1, d = top - hh - s.y }
        end
    end
    return nil
end

-- → tramos, llega (true / false)   |   nil si no hay nada que mejore lo de quedarse donde está
function Nav.path(e, level, gx, gy)
    if not e.cattached then return nil end
    local start = { x = e.x, y = e.y, nx = e.cnx, ny = e.cny, g = 0 }
    start.h = math.sqrt((gx - e.x) ^ 2 + (gy - e.y) ^ 2)
    local open, seen = { start }, { [keyOf(start.x, start.y, start.nx, start.ny)] = 0 }
    local best = start
    local found
    local n = 0
    while #open > 0 and n < Nav.MAX_NODES do
        n = n + 1
        local bi, bf = 1, open[1].g + open[1].h * Nav.GREED
        for i = 2, #open do
            local f = open[i].g + open[i].h * Nav.GREED
            if f < bf then bi, bf = i, f end
        end
        local s = table.remove(open, bi)
        if s.h < best.h then best = s end
        if s.h <= Nav.ARRIVE then found = s; break end
        local function push(x, y, nx, ny, cost, via)
            local k = keyOf(x, y, nx, ny)
            local g = s.g + cost
            if seen[k] and seen[k] <= g then return end
            seen[k] = g
            open[#open + 1] = { x = x, y = y, nx = nx, ny = ny, g = g, h = math.sqrt((gx - x) ^ 2 + (gy - y) ^ 2), from = s, via = via }
        end
        for _, dir in ipairs({ 1, -1 }) do
            local gh = ghost(e, s, dir)
            if Crawler.move(gh, level, Nav.STEP) then
                -- (al doblar una esquina el sentido cambia de signo: el tramo guarda con el que EMPEZÓ)
                push(gh.x, gh.y, gh.cnx, gh.cny, Nav.STEP, { kind = 'crawl', dir = dir })
            end
        end
        for _, l in ipairs(landings(e, level, s, gx, gy, s.h)) do
            push(l.x, l.y, l.nx, l.ny, l.d + Nav.LEAP_COST, { kind = 'leap' })
        end
        local dr = dropTo(e, level, s)
        if dr then push(dr.x, dr.y, dr.nx, dr.ny, dr.d * 0.5 + 120, { kind = 'drop' }) end
    end
    local goal = found or best
    if goal == start or goal.h > start.h - T * 0.5 then return nil end
    -- reconstruir: del final al principio, juntando los pasos de trepar seguidos en el mismo sentido
    local rev = {}
    local s = goal
    while s.from do rev[#rev + 1] = s; s = s.from end
    local steps = {}
    for i = #rev, 1, -1 do
        local node = rev[i]
        local last = steps[#steps]
        if node.via.kind == 'crawl' then
            -- mismo tramo si sigue en la misma superficie y sentido (una esquina empieza tramo nuevo: tras girar,
            -- "delante" es otro sentido y hay que volver a fijarlo)
            if last and last.kind == 'crawl' and last.dir == node.via.dir and last.nx == node.from.nx and last.ny == node.from.ny
               and node.nx == node.from.nx and node.ny == node.from.ny then
                last.left = last.left + Nav.STEP
                last.x, last.y = node.x, node.y
            else
                steps[#steps + 1] = { kind = 'crawl', dir = node.via.dir, left = Nav.STEP, x = node.x, y = node.y, nx = node.nx, ny = node.ny,
                                      fnx = node.from.nx, fny = node.from.ny }
            end
        else
            steps[#steps + 1] = { kind = node.via.kind, x = node.x, y = node.y, nx = node.nx, ny = node.ny }
        end
    end
    return steps, found ~= nil
end

return Nav
