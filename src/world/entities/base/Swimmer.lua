-- src/world/entities/base/Swimmer.lua
-- NADADOR "de serie" (0.5.97): lo que comparten los peces que viven en el agua — el Pez globo
-- (types/enemies/pufferfish.lua) y la Piraña (types/enemies/piranha.lua) —. Un tipo lo enciende llamando a estas
-- funciones desde su update / render (no se copia el código de otro pez):
--   · ÁREA DE NADO: un polígono (prop `area`, de 3 a 24 puntos = centros de casilla; irregular y cóncavo valen). Sin
--     área, un rectángulo alrededor de donde se colocó (`e.swimFallback` = { medio ancho, medio alto } en casillas).
--   · NADAR (Swimmer.move): elige puntos al azar dentro del área a los que se llega en línea recta sin salir de ella
--     (casi siempre el más lejano: llega a los extremos de cada brazo), nada hasta allí frenando al llegar, a veces
--     descansa un momento y vuelve a elegir. Sigue el nivel del agua: si la superficie le baja del lomo, nada hacia
--     abajo (solo hacia más agua). Oscila un poco (`swimBob`).
--     `e.swimPass = true` (el pez globo, que nada en un plano por delante): atraviesa bloques (dentro de uno cuenta
--     como mojado). Sin él (la piraña): solo agua libre — nunca elige un destino ni un camino que cruce un bloque o
--     salga del agua, y no avanza hacia donde no hay agua.
--   · EN SECO (Swimmer.updateDry): si se queda fuera del agua CAE ('dry_fall', con choques) y en el suelo da botes y
--     coletazos salvajes cada vez más cansados ('dry_flop'); si vuelve a caer al agua, `e:onBackToWater(level)`; si
--     pasa `props.dryTime` s (5) fuera, se MUERE ('dry_die': panza arriba y se desvanece, DIE_T s; luego
--     finishDeath). `e.dryDeadly`: pinchos / lava / el vacío en seco lo revientan.
--   · DIBUJO en seco (Swimmer.dryPose): la animación, giro, volteo y transparencia de cada estado seco.
-- Posición: `e.px, e.py` = sin la oscilación; e.x, e.y = lo que se ve y choca. Todo lo que se dibuja sale de estado +
-- deadTimer + x, y + facing: igual online. (Solo simula quien manda: un jugador / servidor.)
local Swimmer = {}

Swimmer.DRY = { dry_fall = true, dry_flop = true, dry_die = true }
local DRY_G    = 1500          -- gravedad en seco (px/s²)
local SINK_SPD = 140           -- px/s hacia abajo cuando el agua le baja del lomo
local ARRIVE   = 14            -- px: ha llegado a su destino
Swimmer.DIE_T  = 1.0           -- s de la muerte en seco (panza arriba, se desvanece)
local BOB_W    = 1.7           -- rad/s de la oscilación

-- ── Área de nado (polígono en px de mundo: centros de las casillas) ──────────
local function inside(poly, x, y)
    local c, n = false, #poly
    local j = n
    for i = 1, n do
        local a, b = poly[i], poly[j]
        if (a[2] > y) ~= (b[2] > y) and x < (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1] then c = not c end
        j = i
    end
    return c
end
Swimmer.inside = inside

-- ¿Agua en el punto? (el que atraviesa bloques: un bloque también cuenta)
function Swimmer.wet(e, level, x, y)
    if e.swimPass then return level:liquidAt(x, y) ~= nil or level:collisionAt(x, y) ~= nil end
    return level:liquidAt(x, y) ~= nil and not level:isEnemySolidAt(x, y)
end
local wet = Swimmer.wet

-- Medio ancho / medio alto que tiene que caber en agua libre (con la oscilación: lo que se ve no se mete en un bloque)
local function halfBody(e)
    return e.outerW * 0.5, e.outerH * 0.5 + math.abs(e.props.swimBob or e.swimBob or 6)
end
-- ¿Cabe el cuerpo en agua libre en (x, y)?
local function bodyWet(e, level, x, y)
    local hw, hh = halfBody(e)
    return wet(e, level, x, y) and wet(e, level, x - hw, y) and wet(e, level, x + hw, y)
       and wet(e, level, x, y - hh) and wet(e, level, x, y + hh)
end

-- ¿El tramo recto de (x0,y0) a (x1,y1) queda dentro del área (y, si no atraviesa bloques, con TODO el cuerpo en agua
-- libre)? (cada 12 px). `outside` = sale de fuera del área (vuelve a ella): solo cuenta el agua
local function segOk(e, level, x0, y0, x1, y1, outside)
    local d = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local n = math.max(1, math.ceil(d / 12))
    for i = 1, n do
        local k = i / n
        local x, y = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
        if not outside and not inside(e.poly, x, y) then return false end
        if not e.swimPass and level and not bodyWet(e, level, x, y) then return false end
    end
    return true
end

function Swimmer.buildArea(e)
    local T, pts = TILE_PX, e.props.area
    local poly = {}
    for _, q in ipairs(type(pts) == 'table' and pts or {}) do poly[#poly + 1] = { (q.col - 0.5) * T, (q.row - 0.5) * T } end
    if #poly < 3 then                -- (sin área: un rectángulo alrededor de donde se colocó)
        local fb = e.swimFallback or { 3, 1 }
        local x, y, hw, hh = e.home.x, e.home.y, fb[1] * T, fb[2] * T
        poly = { { x - hw, y - hh }, { x + hw, y - hh }, { x + hw, y + hh }, { x - hw, y + hh } }
    end
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, v in ipairs(poly) do
        x0, y0 = math.min(x0, v[1]), math.min(y0, v[2]); x1, y1 = math.max(x1, v[1]), math.max(y1, v[2])
    end
    e.poly, e.bx0, e.by0, e.bx1, e.by1 = poly, x0, y0, x1, y1
end

-- Nuevo destino: un punto del área al que se llega en línea recta sin salir de ella. Se juntan varios candidatos y
-- casi siempre gana el MÁS LEJANO: así llega a los extremos de cada brazo del área (y desde ahí ve los demás) en vez
-- de quedarse dando vueltas por la parte más grande. Si no encuentra ninguno, vuelve a donde se colocó (o se queda).
function Swimmer.pickTarget(e)
    local poly, best, level = e.poly, nil, e.levelRef
    local here = inside(poly, e.px, e.py)
    local cands = {}
    for _ = 1, 60 do
        local x = e.bx0 + math.random() * (e.bx1 - e.bx0)
        local y = e.by0 + math.random() * (e.by1 - e.by0)
        if inside(poly, x, y) and (not level or wet(e, level, x, y - e.outerH * 0.5))      -- (nunca a un sitio seco)
           and ((not here and e.swimPass) or segOk(e, level, e.px, e.py, x, y, not here)) then
            cands[#cands + 1] = { x, y }
            if #cands >= 8 then break end
        end
    end
    if #cands > 0 then
        if math.random() < 0.65 then
            local bd = -1
            for _, c in ipairs(cands) do
                local d = (c[1] - e.px) ^ 2 + (c[2] - e.py) ^ 2
                if d > bd then best, bd = c, d end
            end
        else
            best = cands[math.random(#cands)]
        end
    end
    if not best then
        local hx, hy = e.home.x, e.home.y
        best = (inside(poly, hx, hy) and (e.swimPass or not level or segOk(e, level, e.px, e.py, hx, hy, not here))) and { hx, hy }
               or { e.px, e.py }
    end
    e.tx, e.ty = best[1], best[2]
    local d = math.sqrt((e.tx - e.px) ^ 2 + (e.ty - e.py) ^ 2)
    e.goT = d / math.max(10, e.speed) * 2 + 2          -- (tiempo máximo para llegar)
end

function Swimmer.init(e)
    e.dryT  = 0                 -- s seguidos fuera del agua
    e.swimT = 0
    e.px, e.py, e.vy = e.x, e.y, 0     -- posición sin la oscilación
    e.restT = 0
    e.poly  = nil               -- (el área se prepara en el primer paso: Swimmer.ready)
end

-- (primer paso) el área y el primer destino
function Swimmer.ready(e, level)
    e.levelRef = level
    if not e.poly then Swimmer.buildArea(e); Swimmer.pickTarget(e) end
end

-- Vuelve a la posición sin oscilación desde la que se ve (tras moverse por su cuenta: saltar, lanzarse)
function Swimmer.sync(e)
    e.px, e.py = e.x, e.y - math.sin((e.swimT or 0) * BOB_W) * (e.props.swimBob or e.swimBob or 6)
end

function Swimmer.topY(e) return e.py - e.outerH * 0.5 end          -- (el lomo)

-- ¿En seco? (el centro fuera del agua)
function Swimmer.isDry(e, level) return not wet(e, level, e.px, e.py) end

-- Se queda en seco: cae
function Swimmer.goDry(e)
    e.state, e.deadTimer, e.onGround, e.hopT = 'dry_fall', 0, false, 0
    e.vx = (e.vx or 0) * 0.5
end

-- Un paso nadando. `swimming` = va hacia su destino (si no, frena en el sitio: hinchado, avisando...).
function Swimmer.move(e, dt, level, swimming)
    local wx, wy = 0, 0
    if swimming then
        local dx, dy = e.tx - e.px, e.ty - e.py
        local d = math.sqrt(dx * dx + dy * dy)
        e.goT = e.goT - dt
        if e.restT > 0 then
            e.restT = e.restT - dt
            if e.restT <= 0 then Swimmer.pickTarget(e) end
        elseif d < ARRIVE or e.goT <= 0 then
            if math.random() < 0.4 then e.restT = 0.3 + math.random() * 0.9 else Swimmer.pickTarget(e) end
        else
            -- (frena al acercarse al destino)
            local sp = e.speed * math.min(1, d / (TILE_PX * 0.75) + 0.25)
            wx, wy = dx / d * sp, dy / d * sp
        end
    end
    -- Sigue el nivel del agua: si la superficie le baja del lomo, nada hacia abajo (sea cual sea su destino)
    -- (solo hacia más agua: nunca se hunde en un bloque; si debajo no hay agua, se queda y al bajar más el agua, cae)
    local sinking = not wet(e, level, e.px, Swimmer.topY(e))
    if sinking and level:liquidAt(e.px, e.py + e.outerH * 0.5) then wy = math.max(wy, SINK_SPD)
    elseif sinking then wy = math.min(wy, 0) end
    local k = math.min(1, dt * ((swimming and not sinking) and 3 or 6))
    e.vx = e.vx + (wx - e.vx) * k
    e.vy = e.vy + (wy - e.vy) * k
    local nx, ny = e.px + e.vx * dt, e.py + e.vy * dt
    if not e.swimPass then
        -- (agua libre: no avanza hacia donde no hay agua ni hacia un bloque; si choca, otro destino)
        local hw, hh = halfBody(e)
        if e.vx ~= 0 and not wet(e, level, nx + (e.vx > 0 and hw or -hw), e.py) then nx, e.vx, e.goT = e.px, 0, 0 end
        if e.vy > 0 and not wet(e, level, nx, ny + hh) then ny, e.vy, e.goT = e.py, 0, 0
        elseif e.vy < 0 and not sinking and not wet(e, level, nx, ny - hh) then ny, e.vy, e.goT = e.py, 0, 0 end
    end
    e.px, e.py = nx, ny
    if swimming and math.abs(e.vx) > 6 then e.facing = e.vx > 0 and 1 or -1 end
    e.swimT = e.swimT + dt * (swimming and 1 or 0.4)
    e.x = e.px
    e.y = e.py + math.sin(e.swimT * BOB_W) * (e.props.swimBob or e.swimBob or 6)
end

-- En seco: cae con choques, bota y coletea en el suelo; si vuelve al agua, nada; si tarda, se muere
function Swimmer.updateDry(e, dt, level)
    local p, st = e.props, e.state
    if st == 'dry_die' then
        if e.deadTimer >= Swimmer.DIE_T then e:finishDeath(); if e.alive then e.state = 'gone' else e.state = 'dead' end end
        return
    end
    local dryTime = p.dryTime or 5
    e.dryT = e.dryT + dt
    if e.dryT >= dryTime then
        e.state, e.deadTimer, e.vx = 'dry_die', 0, 0
        local s = e.dryDieSound or { 'pufferDeflate', 1.3 }
        Sound.play(s[1], s[2], s[3])
        return
    end
    e.vy = math.min(e.vy + DRY_G * dt, 900)
    e.x, e.y = e.px, e.py
    e.leftBoundPx, e.rightBoundPx = -1e9, 1e9            -- (sin ruta: choca solo con lo sólido)
    local was = e.onGround
    e:moveAndCollide(level, e.vx * dt, e.vy * dt)
    e.px, e.py = e.x, e.y
    if e.dryDeadly and (e:onDeadlyGround(level) or e:inVoid(level)) then e:dieBurst(); return end
    if e.dryDeadly and e:fellOut(level) then e.alive = false; return end
    if wet(e, level, e.px, e.py) and not level:collisionAt(e.px, e.py) then    -- ¡de vuelta al agua!
        e.state, e.deadTimer, e.dryT = 'walk', 0, 0
        e.vy = math.min(e.vy, 120)
        if e.onBackToWater then e:onBackToWater(level) else Sound.play('waterSplash', 1.5, 0.5) end
        Swimmer.pickTarget(e)
        return
    end
    if e.onGround then
        if not was then e.vx = e.vx * 0.3 end
        if st ~= 'dry_flop' then e.state, e.deadTimer = 'dry_flop', 0 end
        -- coletazos salvajes: botes cortos al azar, cada vez más cansados
        e.hopT = (e.hopT or 0) - dt
        if e.hopT <= 0 then
            local tired = 1 - 0.5 * math.min(1, e.dryT / dryTime)
            e.vy = -(260 + math.random() * 320) * tired
            e.vx = (math.random() * 2 - 1) * 170 * tired
            e.facing = (math.random() < 0.5) and -1 or 1
            e.onGround = false
            e.hopT = 0.18 + math.random() * 0.3
            Sound.play('kingHop', 2.4, 0.35)
        end
    end
end

-- Pose en seco: (tiempo de la animación de nadar, giro, volteo vertical, transparencia). Coletea (los cuadros de nadar,
-- rápido) dando vueltas; muriendo, panza arriba (sy = -1) y se desvanece
function Swimmer.dryPose(e)
    local st, t = e.state, e.deadTimer or 0
    local at, rot, sy, a = t * 4, 0, 1, 1
    if st == 'dry_flop' then rot = math.sin(t * 23) * 0.5
    elseif st == 'dry_fall' then rot = math.sin(t * 11) * 0.3
    else at, sy, a = 0, -1, 1 - math.max(0, (t - Swimmer.DIE_T * 0.4) / (Swimmer.DIE_T * 0.6)) end
    return at, rot, sy, a
end

-- Editor: el área de nado (relleno) al seleccionarlo
function Swimmer.drawArea(props, ctx, zoom)
    if not (ctx and type(props.area) == 'table' and #props.area >= 3) then return end
    local vs = {}
    for _, q in ipairs(props.area) do
        vs[#vs + 1] = (q.col - 0.5) * ctx.t - ctx.camX
        vs[#vs + 1] = (q.row - 0.5) * ctx.t - ctx.camY
    end
    local ok, tris = pcall(love.math.triangulate, vs)        -- (cóncavo: en triángulos)
    love.graphics.setColor(0.2, 0.9, 0.6, 0.16)
    if ok then for _, tri in ipairs(tris) do love.graphics.polygon('fill', tri) end end
    love.graphics.setColor(0.2, 0.9, 0.6, 0.9)
    love.graphics.setLineWidth(3 / zoom)
    love.graphics.polygon('line', vs)
    love.graphics.setLineWidth(1)
end

-- La prop del editor (la misma en todos los nadadores)
function Swimmer.areaProp(group, help)
    return { key = 'area', kind = 'points', label = 'Área de nado', group = group, min = 3, max = 24,
             default = function(d)
                 local c, r = d.col or 1, d.row or 1
                 return { { col = c - 3, row = r - 1 }, { col = c + 3, row = r - 1 },
                          { col = c + 3, row = r + 1 }, { col = c - 3, row = r + 1 } }
             end,
             help = help or 'Contorno de la zona por la que nada (puede ser irregular). Explora libremente todo su interior' }
end
function Swimmer.dryTimeProp(group)
    return { key = 'dryTime', kind = 'number', label = 'Aguanta en seco (s)', group = group, default = 5,
             min = 1, max = 30, step = 0.5, help = 'Fuera del agua bota y coletea; pasado este tiempo, se muere' }
end

return Swimmer
