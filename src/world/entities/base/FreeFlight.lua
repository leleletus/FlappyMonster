-- VUELO LIBRE: un volador que recorre toda una zona en vez de ir y venir por una ruta
-- (prop común `flyMode = 'free'`, o `e.freeFly = true` + `e.flyArea` puestos por quien lo
-- crea: la guardia voladora del Rey Gummy). Reutilizable por cualquier entidad voladora.
--
-- Cómo se mueve: elige un DESTINO dentro de su zona — un punto donde CABE su caja (con
-- margen) y al que llega en línea recta sin tocar nada — y vuela hacia él; al llegar (o si
-- algo lo frena, o tarda demasiado) elige otro. De varios candidatos se queda la mitad de
-- las veces con el más cercano a un jugador (estorba de verdad) y la otra mitad con el más
-- lejano (recorre toda la zona, también sus rincones). Así nunca se queda atrapado:
--   (al explorar prefiere los sectores de su zona que menos ha visitado: no se queda dando
--   vueltas por el mismo lado)
--   · bajo una plataforma, en un hueco o en una esquina: solo acepta destinos con el camino
--     libre, así que sale por donde entró;
--   · sin ningún destino a la vista: prueba escapes cortos en 8 direcciones;
--   · metido DENTRO de algo (un bloque de jefe que apareció encima): va al hueco más cercano
--     atravesándolo, sin colisiones, hasta salir.
-- Zona: `e.flyArea` {x0, y0, x1, y1} (px) o, si no, `flyRange` casillas alrededor de su sitio.
-- Solo simulación (un jugador / servidor); el cliente online lo dibuja desde las instantáneas.

local FF = {}

local T       = TILE_PX
local MARGIN  = 6           -- px libres alrededor de la caja en un destino / camino
local ARRIVE  = 14          -- px: llegó
local STEER   = 5           -- 1/s: lo rápido que gira hacia el destino
local BLOCK_T = 0.3         -- s frenado antes de buscar otro destino
local TRIES   = 12          -- candidatos por elección

function FF.area(e, level)
    if e.flyArea then return e.flyArea end
    if not e.ffArea then
        local r = (e.props.flyRange or 6) * T
        local h = e.home or e
        e.ffArea = { x0 = math.max(0, h.x - r), y0 = math.max(0, h.y - r),
                     x1 = math.min(level.widthPx or 1e9, h.x + r), y1 = math.min(level.heightPx or 1e9, h.y + r) }
    end
    return e.ffArea
end

-- ¿Cabe la caja (con `m` px de margen) en (x, y), dentro de la zona?
function FF.fits(e, level, x, y, a, m)
    m = m or MARGIN
    local hw, hh = e.outerW / 2 + m, e.outerH / 2 + m
    if x - hw < a.x0 or x + hw > a.x1 or y - hh < a.y0 or y + hh > a.y1 then return false end
    local nx, ny = math.max(2, math.ceil(2 * hw / 24) + 1), math.max(2, math.ceil(2 * hh / 24) + 1)
    for i = 0, nx - 1 do
        for j = 0, ny - 1 do
            if level:entitySolidAt(x - hw + 2 * hw * i / (nx - 1), y - hh + 2 * hh * j / (ny - 1), e) then return false end
        end
    end
    return true
end

-- ¿Camino libre en línea recta?
function FF.clear(e, level, x0, y0, x1, y1, a)
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.ceil(d / 16))
    for i = 1, n do
        local k = i / n
        if not FF.fits(e, level, x0 + (x1 - x0) * k, y0 + (y1 - y0) * k, a, 2) then return false end
    end
    return true
end

local SECTOR = 3 * T         -- lado de los sectores de la memoria de exploración
local function sector(x, y) return math.floor(x / SECTOR) * 4096 + math.floor(y / SECTOR) end

local function nearestPlayer(level, x, y)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if pa.alive ~= false and not pa.dying then
            local d = (pa.x - x) ^ 2 + (pa.y - y) ^ 2
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best
end

function FF.pick(e, level)
    local a = FF.area(e, level)
    e.ffSeen = e.ffSeen or {}
    local inside = FF.fits(e, level, e.x, e.y, a, 0)
    e.ffGhost = false
    if not inside then
        -- Metido en algo (o fuera de su zona): al hueco más cercano, atravesando
        local best, bd
        for ring = 1, 6 do
            for k = 0, 7 do
                local an = k * math.pi / 4
                local x, y = e.x + math.cos(an) * ring * T * 0.75, e.y + math.sin(an) * ring * T * 0.75
                if FF.fits(e, level, x, y, a) then
                    local d = (x - e.x) ^ 2 + (y - e.y) ^ 2
                    if not bd or d < bd then best, bd = { x, y }, d end
                end
            end
            if best then break end
        end
        if best then e.ffx, e.ffy, e.ffGhost = best[1], best[2], true end
        if not best then e.ffx, e.ffy = math.max(a.x0, math.min(a.x1, e.x)), math.max(a.y0, math.min(a.y1, e.y)); e.ffGhost = true end
        e.ffLeft = 2
        return
    end
    local pa = nearestPlayer(level, e.x, e.y)
    local chase = pa ~= nil and math.random() < 0.5
    local best, bs
    for _ = 1, TRIES do
        local x = a.x0 + math.random() * (a.x1 - a.x0)
        local y = a.y0 + math.random() * (a.y1 - a.y0)
        if FF.fits(e, level, x, y, a) and FF.clear(e, level, e.x, e.y, x, y, a) then
            local s
            if chase then s = -((x - pa.x) ^ 2 + (y - (pa.y - T * 0.5)) ^ 2)
            else
                -- (explorar: primero lo MENOS visitado de su zona — memoria por sectores de
                -- SECTOR casillas —; a igualdad, lo más lejano)
                s = -(e.ffSeen[sector(x, y)] or 0) * 1e9 + (x - e.x) ^ 2 + (y - e.y) ^ 2
            end
            if (x - e.x) ^ 2 + (y - e.y) ^ 2 > (T * 0.75) ^ 2 and (not bs or s > bs) then best, bs = { x, y }, s end
        end
    end
    if not best then
        -- Sin destinos a la vista: un escape corto en cualquiera de 8 direcciones
        local k0 = math.random(0, 7)
        for ring = 2, 1, -1 do
            for k = 0, 7 do
                local an = ((k + k0) % 8) * math.pi / 4
                local x, y = e.x + math.cos(an) * ring * T, e.y + math.sin(an) * ring * T
                if FF.fits(e, level, x, y, a) and FF.clear(e, level, e.x, e.y, x, y, a) then best = { x, y }; break end
            end
            if best then break end
        end
    end
    if best then
        e.ffx, e.ffy = best[1], best[2]
        local d = math.sqrt((best[1] - e.x) ^ 2 + (best[2] - e.y) ^ 2)
        e.ffLeft = d / math.max(20, e.speed) * 1.6 + 0.8
    else
        e.ffx, e.ffy, e.ffLeft = e.x, e.y, 0.4          -- (encerrado de verdad: espera y reintenta)
    end
end

function FF.update(e, dt, level)
    local a = FF.area(e, level)
    e.leftBoundPx, e.rightBoundPx = a.x0, a.x1
    e.ffLeft = (e.ffLeft or 0) - dt
    local dx, dy = (e.ffx or e.x) - e.x, (e.ffy or e.y) - e.y
    local d = math.sqrt(dx * dx + dy * dy)
    if not e.ffx or e.ffLeft <= 0 or d < ARRIVE or (e.ffBlock or 0) > BLOCK_T then
        FF.pick(e, level)
        e.ffBlock = 0
        dx, dy = e.ffx - e.x, e.ffy - e.y
        d = math.sqrt(dx * dx + dy * dy)
    end
    local sp = e.speed
    local tvx, tvy = 0, 0
    if d > 1 then tvx, tvy = dx / d * sp, dy / d * sp end
    local k = math.min(1, dt * STEER)
    e.fvx = (e.fvx or 0) + (tvx - (e.fvx or 0)) * k
    e.fvy = (e.fvy or 0) + (tvy - (e.fvy or 0)) * k
    local ox, oy = e.x, e.y
    local mx, my = e.fvx * dt, e.fvy * dt
    if e.ffGhost then
        e.x, e.y = e.x + mx, e.y + my
    else
        e:moveAndCollide(level, mx, my)
        e.vy = 0
    end
    -- Frenado (chocó con algo que no estaba al elegir): cuenta y, si sigue, otro destino
    local moved = math.sqrt((e.x - ox) ^ 2 + (e.y - oy) ^ 2)
    local want = math.sqrt(mx * mx + my * my)
    if want > 0.01 and moved < want * 0.4 then
        e.ffBlock = (e.ffBlock or 0) + dt
        e.fvx, e.fvy = e.fvx * 0.5, e.fvy * 0.5
    else
        e.ffBlock = 0
    end
    -- memoria de por dónde ha pasado (para ir a lo que le falta)
    e.ffSeen = e.ffSeen or {}
    local sk = sector(e.x, e.y)
    if sk ~= e.ffSector then e.ffSector = sk; e.ffSeen[sk] = (e.ffSeen[sk] or 0) + 1 end
    e.vx = e.fvx
    if math.abs(e.fvx) > 8 then e.facing = (e.fvx > 0) and 1 or -1 end
    e.baseY = e.y
end

return FF
