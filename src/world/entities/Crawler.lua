-- src/world/entities/Crawler.lua
-- Movimiento "trepador": una entidad pegada a la superficie de los bloques que
-- la rodea entera — suelo, paredes y techo — girando en las esquinas (como
-- los bichos que dan vueltas a los bloques en los plataformas clásicos).
-- Lo usan los Crabbies con la propiedad "Anda por paredes y techos".
--
-- Estado en la entidad:
--   e.cnx, e.cny   normal de la superficie (hacia donde queda el aire):
--                  suelo (0,-1), techo (0,1), pared a su izquierda (1,0)...
--   e.cdir         ±1 sentido de avance a lo largo de la superficie
-- El avance es t = r * cdir, con r = (-cny, cnx) (la "derecha" local).
-- El centro queda a outerH/2 de la superficie: la misma altura a la que se
-- apoya un Crabby normal en el suelo (así se ve igual y el pincho o el
-- trampolín quedan pegados al caparazón escondido, no flotando).
--
-- Esquinas (giro rígido de 90° alrededor de la esquina real, medida píxel a
-- píxel: la posición respecto a la esquina se conserva, sin saltos):
--   * cóncava (pared delante): gira hacia arriba de esa pared.
--   * convexa (se acaba el bloque): da la vuelta al borde y sigue por el
--     otro lado del mismo bloque.
-- Si se queda sin nada a lo que agarrarse (p. ej. rompen el bloque), se
-- suelta y cae (Crawler.detach): vuelve a agarrarse al tocar el suelo.
--
-- Giro en las esquinas: la superficie (cnx, cny) cambia de golpe, pero el
-- cuerpo tarda `turnDur` s en rodar alrededor de la esquina. Ese giro es
-- parte de la SIMULACIÓN (no solo del dibujo): Crawler.pose da dónde está de
-- verdad (pies + ángulo) y Crawler.poseBox gira con esa pose las cajas de
-- choque, así la hitbox coincide con lo que se ve. Estado en escalares (el
-- servidor rebobina copiando los campos escalares): turnT, turnDur, tsx/tsy
-- (pies al empezar), tsang, tonx/tony (normal anterior).

local Crawler = {}

-- Tiles (con su forma real) y objetos sólidos (trampolines, morteros...).
-- Una entidad puede añadir lo suyo con e:crawlSolidAt(level, x, y) (p. ej. el
-- Mega Crabby trepa por los bordes de su zona de jefe).
local function baseSolid(level, x, y) return level:entitySolidAt(x, y) end
local function solidFor(e)
    if e.crawlSolidAt then return function(level, x, y) return e:crawlSolidAt(level, x, y) end end
    return baseSolid
end

local function halfH(e) return e.outerH / 2 end
local function halfW(e) return e.sprW * 0.45 end

-- Ángulo de dibujo: el "arriba" del sprite apunta a la normal
function Crawler.angle(e)
    return math.atan2(e.cnx, -e.cny)
end

-- ¿Está en una pared (no en suelo ni techo)?
function Crawler.onWall(e) return e.crawl and e.cnx ~= 0 end

-- Vectores locales: derecha (r) y abajo (d = -n)
function Crawler.axes(e)
    return -e.cny, e.cnx, -e.cnx, -e.cny
end

-- Caja local (lx, ly = esquina sup-izq con el origen en el centro, "arriba"
-- = normal) → caja en el mundo (las rotaciones son de 90°)
function Crawler.toWorldBox(e, lx, ly, w, h)
    local rx, ry, dx, dy = Crawler.axes(e)
    local x0, y0 = math.huge, math.huge
    local x1, y1 = -math.huge, -math.huge
    for _, c in ipairs({ { lx, ly }, { lx + w, ly }, { lx, ly + h }, { lx + w, ly + h } }) do
        local wx = e.x + rx * c[1] + dx * c[2]
        local wy = e.y + ry * c[1] + dy * c[2]
        x0, y0 = math.min(x0, wx), math.min(y0, wy)
        x1, y1 = math.max(x1, wx), math.max(y1, wy)
    end
    return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

-- ── Giro (pose) ───────────────────────────────────────────────────────────────
local TURN_MIN, TURN_MAX = 0.14, 0.32     -- s del giro (según su velocidad)

local function wrapAng(a) return (a + math.pi) % (2 * math.pi) - math.pi end

-- Pies (centro de la base del sprite) según la superficie actual
function Crawler.feet(e) return e.x - e.cnx * e.sprH / 2, e.y - e.cny * e.sprH / 2 end

function Crawler.turning(e) return e.turnT ~= nil and e.crawl and e.cattached end

-- Pose real: pies (x, y) y ángulo. Durante un giro los pies ruedan alrededor
-- de la esquina C (cruce de la superficie vieja, por el inicio, y la nueva,
-- por los pies actuales) mientras el cuerpo gira.
function Crawler.pose(e)
    local fx, fy = Crawler.feet(e)
    local ang = Crawler.angle(e)
    if not Crawler.turning(e) then return fx, fy, ang end
    local k = math.max(0, math.min(1, e.turnT / e.turnDur))
    local m = k * k * (3 - 2 * k)
    local x, y = e.tsx + (fx - e.tsx) * m, e.tsy + (fy - e.tsy) * m
    if e.tonx * e.cnx + e.tony * e.cny == 0 then
        local so = e.tsx * e.tonx + e.tsy * e.tony
        local sn = fx * e.cnx + fy * e.cny
        local cx, cy = e.tonx * so + e.cnx * sn, e.tony * so + e.cny * sn
        local ux, uy, vx, vy = e.tsx - cx, e.tsy - cy, fx - cx, fy - cy
        local r0, r1 = math.sqrt(ux * ux + uy * uy), math.sqrt(vx * vx + vy * vy)
        if r0 > 0.5 and r1 > 0.5 then
            local a0 = math.atan2(uy, ux)
            local a = a0 + wrapAng(math.atan2(vy, vx) - a0) * m
            local r = r0 + (r1 - r0) * m
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        end
    end
    return x, y, e.tsang + wrapAng(ang - e.tsang) * m
end

-- Normal "de choque" durante el giro: la de la superficie a la que más mira
-- (vieja en la primera mitad, nueva en la segunda)
function Crawler.poseNormal(e)
    if not Crawler.turning(e) then return e.cnx, e.cny end
    local _, _, a = Crawler.pose(e)
    local nx, ny = math.sin(a), -math.cos(a)
    if math.abs(nx) > math.abs(ny) then return (nx > 0) and 1 or -1, 0 end
    return 0, (ny > 0) and 1 or -1
end

-- Como toWorldBox, pero con la pose real (girando: la caja se lleva al
-- ángulo actual; sus lados se mezclan según el ángulo, sin inflarla)
function Crawler.poseBox(e, lx, ly, w, h)
    if not Crawler.turning(e) then return Crawler.toWorldBox(e, lx, ly, w, h) end
    local fx, fy, a = Crawler.pose(e)
    local c, s = math.cos(a), math.sin(a)
    -- centro de la entidad = pies + normal * sprH/2; ejes: derecha (c, s), abajo (-s, c)
    local ox, oy = fx + s * e.sprH / 2, fy - c * e.sprH / 2
    local lcx, lcy = lx + w / 2, ly + h / 2
    local wx, wy = ox + c * lcx - s * lcy, oy + s * lcx + c * lcy
    local c2, s2 = c * c, s * s
    local W, H = w * c2 + h * s2, w * s2 + h * c2
    return { x = wx - W / 2, y = wy - H / 2, w = W, h = H }
end

-- Lo que dura un giro (según su velocidad)
-- (una entidad grande puede alargarlo: e.turnLength, e.turnMax)
function Crawler.turnDuration(e)
    local sp = math.max(1, e.speed or 50)
    return math.max(TURN_MIN, math.min(e.turnMax or TURN_MAX, e.sprW * (e.turnLength or 0.35) / sp))
end

-- Empieza un giro desde la pose actual (aunque ya estuviera a medio girar)
local function beginTurn(e)
    local fx, fy, ang = Crawler.pose(e)
    e.tsx, e.tsy, e.tsang = fx, fy, ang
    e.tonx, e.tony = e.cnx, e.cny
    e.turnT, e.turnDur = 0, Crawler.turnDuration(e)
end
Crawler.beginTurn = beginTurn

-- Avanza el giro (llamar cada paso, ande o no)
function Crawler.advanceTurn(e, dt)
    if not e.turnT then return end
    e.turnT = e.turnT + dt
    if e.turnT >= e.turnDur or not (e.crawl and e.cattached) then e.turnT = nil end
end

-- Busca a qué superficie agarrarse alrededor de su posición (preferencia:
-- la normal que ya tenga, luego suelo, techo y paredes)
-- `maxD` = hasta dónde buscar (px más allá de hh). Por defecto media casilla;
-- al colocarla, una casilla entera (bajo una losa fina, su cara de abajo
-- queda más lejos que el borde de la celda).
function Crawler.attach(e, level, maxD)
    local solid = solidFor(e)
    local hh = halfH(e)
    maxD = maxD or TILE_PX / 2
    local cands = { { e.cnx or 0, e.cny or -1 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }
    for _, n in ipairs(cands) do
        local nx, ny = n[1], n[2]
        -- La superficie tiene que estar a menos de media casilla; se busca
        -- píxel a píxel para quedar exactamente apoyado
        for d = -8, maxD do
            if solid(level, e.x - nx * (hh + d), e.y - ny * (hh + d))
               and not solid(level, e.x - nx * (hh + d - 1), e.y - ny * (hh + d - 1)) then
                e.cnx, e.cny = nx, ny
                e.x, e.y = e.x - nx * (d - 1), e.y - ny * (d - 1)        -- pegado
                e.cattached = true
                return true
            end
        end
    end
    e.cattached = false
    return false
end

-- Objeto sólido (trampolín...) sobre el que está apoyado y cuál de sus caras
-- pisa (según la normal: suelo → su cara 'top', techo → 'bottom'...), o nil
local FACE_OF = { ['0,-1'] = 'top', ['0,1'] = 'bottom', ['1,0'] = 'right', ['-1,0'] = 'left' }
function Crawler.supportBody(e, level)
    if not e.cattached then return nil end
    local hh = halfH(e)
    local o = level:bodyAt(e.x - e.cnx * (hh + 1), e.y - e.cny * (hh + 1), e)
    if not o then return nil end
    return o, FACE_OF[(e.cnx + 0) .. ',' .. (e.cny + 0)]
end

function Crawler.detach(e)
    e.cattached = false
    e.turnT = nil
    e.cnx, e.cny = 0, -1
end

-- Avanza `dist` px a lo largo de la superficie, girando en las esquinas.
-- Devuelve false si se ha soltado (no hay superficie).
function Crawler.move(e, level, dist)
    local solid = solidFor(e)
    local hh, hw = halfH(e), halfW(e)
    local left = math.abs(dist)
    local guard = 0
    while left > 0 and guard < 40 do
        guard = guard + 1
        local s = math.min(left, 4)
        local nx, ny = e.cnx, e.cny
        local tx, ty = -ny * e.cdir, nx * e.cdir
        -- Esquina cóncava: pared justo delante → subirse a ella
        if solid(level, e.x + tx * (hw + 1), e.y + ty * (hw + 1)) then
            -- Distancia exacta a la pared (píxel a píxel) y giro rígido de 90°
            -- alrededor de la esquina: la distancia a la pared pasa a ser la
            -- altura sobre el suelo, y queda a hh de la pared (como attach)
            local D = hw + 1
            for d = 1, hw + 1 do
                if solid(level, e.x + tx * d, e.y + ty * d) then D = d; break end
            end
            beginTurn(e)
            local k = D - (hh + 1)
            e.x, e.y = e.x + tx * k + nx * k, e.y + ty * k + ny * k
            local nnx, nny = -tx, -ty                        -- normal de la pared
            local rx, ry = -nny, nnx
            e.cnx, e.cny = nnx, nny
            e.cdir = (rx * nx + ry * ny >= 0) and 1 or -1     -- avanzar hacia la antigua normal
        else
            e.x, e.y = e.x + tx * s, e.y + ty * s
            left = left - s
            -- Esquina convexa: ya no hay bloque debajo → dar la vuelta al borde
            if not solid(level, e.x - nx * (hh + 2), e.y - ny * (hh + 2)) then
                -- ¿Cuánto se ha pasado del borde? Se busca hacia atrás, en la
                -- primera fila sólida bajo él, la última columna del bloque
                local sx, sy = e.x - nx * (hh + 1), e.y - ny * (hh + 1)
                local J
                for j = 1, math.ceil(hw) + 8 do
                    if solid(level, sx - tx * j, sy - ty * j) then J = j; break end
                end
                if not J then Crawler.detach(e); return false end
                beginTurn(e)
                -- Giro rígido de 90° alrededor de la esquina: lo que se había
                -- pasado del borde pasa a ser lo que baja por el lado nuevo, y
                -- queda a hh del lado (primera columna sólida a hh + 1)
                e.x = e.x - nx * (hh + J) + tx * (hh + 1 - J)
                e.y = e.y - ny * (hh + J) + ty * (hh + 1 - J)
                local nnx, nny = tx, ty                          -- normal: hacia donde avanzaba
                local rx, ry = -nny, nnx
                e.cnx, e.cny = nnx, nny
                e.cdir = (rx * (-nx) + ry * (-ny) >= 0) and 1 or -1   -- bajar por el lado
                -- ¿Hay de verdad algo en el que apoyarse? Si no, se suelta
                if not solid(level, e.x - nnx * (hh + 2), e.y - nny * (hh + 2)) then
                    Crawler.detach(e)
                    return false
                end
            end
        end
    end
    return true
end

-- ── Red (cliente online) ──────────────────────────────────────────────────────
-- Superficie: 0 = normal / suelto, 1 suelo, 2 techo, 3 pared (normal +x),
-- 4 pared (normal -x). Giro: progreso + 1 (0 = no gira).
local SURF = { { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }
-- ¿Otra entidad (obstáculo) justo DELANTE, en el sentido en que avanza por su superficie? Los
-- trepadores no se atraviesan entre sí ni a los demás enemigos: quien lo use da media vuelta
-- (Crabby, Crabby lúgubre...). A los cuerpos sólidos (trampolines, morteros) se suben: no cuentan.
function Crawler.entityAhead(e, level)
    local tx, ty = -e.cny * e.cdir, e.cnx * e.cdir
    local px, py = e.x + tx * (e.sprW * 0.5 + 4), e.y + ty * (e.sprW * 0.5 + 4)
    if e.outerW and e.outerW < e.sprW then                -- (caja más estrecha que el dibujo: desde la caja)
        px, py = e.x + tx * (e.outerW * 0.5 + 4), e.y + ty * (e.outerW * 0.5 + 4)
    end
    for _, o in ipairs(level.liveEntities or {}) do
        if o ~= e and not o.solidFull and o:isObstacle() then
            local b = o:getOuterBounds()
            if px > b.x and px < b.x + b.w and py > b.y and py < b.y + b.h then return o end
        end
    end
    return nil
end

function Crawler.netPack(e)
    local surf = 0
    if e.crawl and e.cattached then
        for i, n in ipairs(SURF) do if n[1] == e.cnx and n[2] == e.cny then surf = i end end
    end
    local turn = Crawler.turning(e) and (math.floor(e.turnT / e.turnDur * 100 + 0.5) + 1) or 0
    return surf, turn
end

-- Aplica superficie y giro recibidos. El giro empieza cuando cambia la
-- superficie (desde la última pose dibujada: x, y ya son los nuevos cuando
-- llega aquí) y avanza con el reloj, a la vez que en el servidor; el progreso
-- que manda el servidor solo lo adelanta (nunca atrás) y el final lo pone el
-- reloj. `noTurn` = ahora no gira (p. ej. cayendo del techo).
function Crawler.netApply(e, surfB, turnA, turnB, f, noTurn)
    local sc = tonumber(surfB) or 0
    local was = e.crawl and e.cattached and e.cnx and (e.cnx .. ',' .. e.cny)
    if sc > 0 then
        e.crawl, e.cattached = true, true
        e.cnx, e.cny = SURF[sc][1], SURF[sc][2]
    elseif e.crawl then
        e.cattached = false
    end
    local now = love.timer.getTime()
    local elapsed = e.netClock and math.min(0.1, now - e.netClock) or 0
    e.netClock = now
    local tb, ta = tonumber(turnB) or 0, tonumber(turnA) or 0
    -- (solo los trepadores tienen superficie; los que no trepan no tienen cnx/cny)
    local cur = sc > 0 and (e.cnx .. ',' .. e.cny) or nil
    local changed = was and cur and was ~= cur
    if changed then e.turnDoneOn = nil end
    if sc == 0 or noTurn then
        e.turnT = nil
    elseif changed or (tb > 0 and not e.turnT and e.turnDoneOn ~= cur) then
        if e.pfx and e.lastNx and changed then
            e.tsx, e.tsy, e.tsang = e.pfx, e.pfy, e.pang
            e.tonx, e.tony = e.lastNx, e.lastNy
        else
            e.tsx, e.tsy = Crawler.feet(e)
            e.tsang, e.tonx, e.tony = Crawler.angle(e), e.cnx, e.cny
        end
        e.turnDur = Crawler.turnDuration(e)
        -- Progreso a la hora que se está dibujando (interpolado como la
        -- posición; el snapshot nuevo va por delante)
        local kb = tb > 0 and (tb - 1) / 100 or 0
        local ka = ta > 0 and ta <= tb and (ta - 1) / 100 or 0
        e.turnT = (ka + (kb - ka) * f) * e.turnDur
    elseif e.turnT then
        e.turnT = e.turnT + elapsed
        if tb > 0 then
            -- (interpolado; si el snapshot anterior aún no giraba, desde 0)
            local kb = (tb - 1) / 100
            local ka = (ta > 0 and ta <= tb) and (ta - 1) / 100 or 0
            e.turnT = math.max(e.turnT, (ka + (kb - ka) * f) * e.turnDur)
        end
        if e.turnT >= e.turnDur then e.turnT = nil; e.turnDoneOn = cur end   -- (no repetirlo)
    end
    if e.crawl and e.cattached then
        e.pfx, e.pfy, e.pang = Crawler.pose(e)
        e.lastNx, e.lastNy = e.cnx, e.cny
    end
end

return Crawler
