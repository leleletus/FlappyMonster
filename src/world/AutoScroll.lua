-- src/world/AutoScroll.lua
-- Cámara automática: el nivel avanza solo hacia la derecha. Se configura por
-- nivel (JSON "autoScroll", panel Nivel del editor) y funciona igual en un
-- jugador, en el servidor y en la predicción del cliente online.
--
--  * La "ventana" mide `width` casillas y empieza en la columna `startCol`.
--  * 'wait': hasta que TODOS los jugadores activos estén dentro de la ventana
--    (no se puede salir de ella). Luego 'countdown' (cuenta atrás) y 'run'.
--  * 'run': avanza `speed` px/s. No se puede adelantar a la cámara (pared a la
--    derecha); quien se queda atrás más de `margin` casillas por la izquierda
--    MUERE y reaparece en el centro de la ventana (respawnPoint).
--  * 'stop': al llegar a `endCol` o cuando alguien toca la meta. Sin paredes.
--
-- En el JSON:  "autoScroll": { "startCol":1, "endCol":200, "speed":90,
--               "width":20, "margin":0.6, "countdown":3 }

local AutoScroll = {}

AutoScroll.STATES = { 'wait', 'countdown', 'run', 'stop' }
local CODE = {}
for i, s in ipairs(AutoScroll.STATES) do CODE[s] = i end

AutoScroll.DEFAULTS = { startCol = 1, endCol = 0, speed = 90, width = 20, margin = 0.6, countdown = 3 }

local function num(v, d, lo, hi)
    v = tonumber(v); if not v or v ~= v then v = d end
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end

-- Datos del nivel → configuración limpia (nil = nivel sin cámara automática)
function AutoScroll.normalize(d)
    if type(d) ~= 'table' or d.enabled == false then return nil end
    local D = AutoScroll.DEFAULTS
    return {
        startCol  = math.floor(num(d.startCol, D.startCol, 1)),
        endCol    = math.floor(num(d.endCol, D.endCol, 0)),      -- 0 = hasta el final del nivel
        speed     = num(d.speed, D.speed, 5, 2000),
        width     = math.floor(num(d.width, D.width, 6, 200)),
        margin    = num(d.margin, D.margin, 0, 20),
        countdown = num(d.countdown, D.countdown, 0, 10),
    }
end

function AutoScroll.serialize(c)
    if not c then return nil end
    return { startCol = c.startCol, endCol = c.endCol, speed = c.speed, width = c.width,
             margin = c.margin, countdown = c.countdown }
end

-- Estado de juego (Level.fromData)
function AutoScroll.build(d, level)
    local c = AutoScroll.normalize(d)
    if not c then return nil end
    local T = TILE_PX
    local W = c.width * T
    c.W      = W
    c.startX = math.max(0, math.min(level.widthPx - W, (c.startCol - 1) * T))
    local endCol = (c.endCol > 0) and math.min(c.endCol, level.tileW) or level.tileW
    c.endX   = math.max(c.startX, math.min(level.widthPx - W, endCol * T - W))
    c.x      = c.startX
    c.state  = 'wait'
    c.cd     = 0
    return c
end

-- Ventana actual (px de mundo)
function AutoScroll.window(level)
    local a = level.autoScroll
    if not a then return nil end
    return a.x, a.x + a.W
end

-- Paredes que ve la física del jugador (Level:arenaAt)
function AutoScroll.arena(level)
    local a = level.autoScroll
    if not a or a.state == 'stop' then return nil end
    local box = a._box or {}
    a._box = box
    box.x0 = (a.state == 'run') and -math.huge or a.x    -- corriendo: atrás no hay pared (se muere)
    box.x1 = a.x + a.W
    box.y0 = -math.huge
    return box
end

local function isFinished(level, pa)
    local ob = pa:getOuterBounds()
    return level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'finish')
end

-- Paso autoritativo (un jugador y servidor). Devuelve eventos.
-- `killFn(pa)` opcional: cómo matar (el servidor atribuye el sonido).
function AutoScroll.update(level, dt, killFn)
    local a = level.autoScroll
    if not a or a.state == 'stop' then return {} end
    local events = {}
    local players = {}
    for _, pa in ipairs(level.players or {}) do
        if pa.alive ~= false then players[#players+1] = pa end
    end
    -- Alguien llegó a la meta: la cámara se para
    local finished = level.finishReached
    for _, pa in ipairs(players) do
        if not pa.dying and isFinished(level, pa) then finished = true end
    end
    if finished then
        a.state = 'stop'
        events[#events+1] = { type = 'scroll_end' }
        return events
    end

    if a.state == 'wait' then
        local inside = 0
        for _, pa in ipairs(players) do
            if not pa.dying and pa.x >= a.x and pa.x <= a.x + a.W then inside = inside + 1 end
        end
        a.arrived, a.needed = inside, #players
        if #players > 0 and inside == #players then
            a.state, a.cd = 'countdown', a.countdown
            events[#events+1] = { type = 'scroll_countdown' }
        end
    end
    if a.state == 'countdown' then
        a.cd = a.cd - dt
        if a.cd <= 0 then
            a.state, a.cd = 'run', 0
            events[#events+1] = { type = 'scroll_start' }
        end
    elseif a.state == 'run' then
        a.x = math.min(a.endX, a.x + a.speed * dt)
        -- Quien se queda atrás, muere
        local limit = a.x - a.margin * TILE_PX
        for _, pa in ipairs(players) do
            if not pa.dying and pa.x < limit then
                if killFn then killFn(pa) else pa:die(nil, true) end
            end
        end
        if a.x >= a.endX then
            a.state = 'stop'
            events[#events+1] = { type = 'scroll_end' }
        end
    end
    return events
end

-- Cliente online: avanza la ventana entre snapshots (el servidor la corrige)
function AutoScroll.clientUpdate(level, dt)
    local a = level.autoScroll
    if a and a.state == 'run' then a.x = math.min(a.endX, a.x + a.speed * dt) end
end

-- ── Reaparecer: en el centro de la ventana, sobre suelo firme ────────────────
function AutoScroll.respawnPoint(level)
    local a = level.autoScroll
    if not a or a.state == 'stop' then return nil end
    local T  = TILE_PX
    local cc = math.floor((a.x + a.W / 2) / T) + 1
    local x, y = level:findGround(cc, math.floor(a.x / T) + 1, math.floor((a.x + a.W) / T), 2, level.tileH - 1)
    if x then return x, y end
    return a.x + a.W / 2, T * 2
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function AutoScroll.netPack(level)
    local a = level.autoScroll
    if not a then return nil end
    return { CODE[a.state] or 1, math.floor(a.x + 0.5), math.floor((a.cd or 0) * 100 + 0.5),
             a.arrived or 0, a.needed or 0 }
end

function AutoScroll.netApply(level, d)
    local a = level.autoScroll
    if not a or type(d) ~= 'table' then return end
    a.state = AutoScroll.STATES[d[1]] or a.state
    local x = tonumber(d[2]) or a.x
    -- Pequeñas diferencias se absorben (la ventana ya avanza sola en el cliente)
    if math.abs(x - a.x) > 48 or a.state ~= 'run' then a.x = x else a.x = a.x + (x - a.x) * 0.3 end
    a.cd      = (tonumber(d[3]) or 0) / 100
    a.arrived = tonumber(d[4]) or 0
    a.needed  = tonumber(d[5]) or 0
end

-- ── Cámara ────────────────────────────────────────────────────────────────────
-- X de la cámara con la ventana activa (nil = cámara normal). La controla
-- SOLO el nivel: siempre centrada en la ventana, pase lo que pase con el
-- jugador. En pantallas más estrechas que la ventana (16:10, 4:3, o el
-- editor) se recorta lo mismo por los dos lados.
function AutoScroll.cameraX(level)
    local a = level.autoScroll
    if not a then return nil end
    local t = a.x + a.W / 2 - WINDOW_W / 2
    return math.max(0, math.min(level.widthPx - WINDOW_W, t))
end

return AutoScroll
