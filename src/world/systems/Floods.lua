-- src/world/systems/Floods.lua
-- Inundaciones: un rectángulo del nivel cuyo nivel de agua sube y baja en
-- ciclo. Se colocan en el editor con la entidad "Inundacion" (types/flood.lua);
-- el nivel las construye a partir de esas colocaciones (Level.fromData).
--
-- Ciclo (todo configurable en el editor):
--   espera inicial → SUBE (a riseSpeed, opcionalmente por escalones de
--   riseStep casillas con pausas) → se queda ARRIBA holdTime → BAJA → se
--   queda ABAJO lowTime → vuelve a subir...
--
-- El nivel del agua es una FUNCIÓN PURA del tiempo del nivel
-- (level.floodTime): un jugador lo avanza con dt, el servidor usa su tick y
-- el cliente online estima el tick del servidor en el que se procesarán sus
-- inputs. Así no hay que enviar nada por red y la predicción coincide.
--
-- Para la física es agua normal: Level:liquidAt la devuelve bajo la
-- superficie, así que nadar, ahogarse, salpicar, apagar bolas de fuego...
-- funciona sin nada especial.
--
-- CONTROL (prop `control` de la entidad):
--   'cycle'  (por defecto) el ciclo de arriba, siempre.
--   'boss'   conectada a una zona de jefe (prop `zone`; 0 = la que se solapa
--            con ella): mientras la pelea está activa hace su ciclo (desde
--            que empieza la pelea: la espera inicial cuenta desde ahí); cuando
--            el jefe entra en su secuencia de muerte, baja a su mínimo y se
--            queda (y antes de la pelea está en el mínimo).
--   'switch' conectada a bloques ON/OFF (level.links: {col, row, to=id}):
--            con alguno en ON sube hasta el máximo y se queda; con todos en
--            OFF baja hasta el mínimo y se queda (por escalones y pausas si
--            los tiene).
-- RESACA (prop `undertow`, px/s con signo: + hacia la derecha): mientras el agua BAJA (fase 'fall'), arrastra a
-- quien está dentro hacia ese lado (Floods.currentAt; el jugador la suma a su avance como una cinta). La fase es
-- función pura del tiempo, así que el cliente online la predice igual. Se ve: espuma que corre hacia ese lado, y al
-- empezar a arrastrar, si quien juega está cerca, suena un aviso y el HUD enseña "¡RESACA!" con flechas hacia ese
-- lado mientras dure (`f.alertAt`, solo clientes: BossHud.drawUndertow).
-- MAREA (control 'tide'): sube y baja SOLA en un ciclo suave (seno) entre el nivel mínimo (marea baja) y el máximo
-- (marea alta), con su periodo (`tidePeriod` s) y su desfase (`tidePhase`, fracción del periodo: 0 = empieza en marea
-- baja, subiendo). Es función pura del tiempo como el ciclo: no se manda nada por red. La fase ('rise' / 'fall' / 'hold'
-- arriba / 'low' abajo) sale de hacia dónde va, así la resaca también arrastra con la marea bajando.
-- AGUA HELADA (prop `cold`, s; 0 = normal): quien está dentro tanto tiempo se congela (PlayerAir: updateFrost); se ve
-- de otro color (`coldTint` del material). También el agua de las casillas, con la clave del nivel `coldWater`
-- (Level:coldAt).
-- Una controlada guarda solo {active, t0, L0}: si está activa, desde cuándo
-- y a qué nivel estaba entonces. El nivel en el instante t sigue siendo una
-- función pura de t y de eso (Floods.levelAt), así que el cliente online
-- calcula el agua en su tiempo predicho igual que con las de ciclo: el
-- servidor (y un jugador) deciden los cambios en Floods.control y los manda
-- en cada snapshot (Floods.netPack → 'fc').

local Floods = {}
local WaterSurface = require 'src/fx/WaterSurface'
local Particles                                    -- (solo clientes: la espuma de la resaca)

local function num(v, d) v = tonumber(v); return v or d end

-- Distancia recorrida tras `u` s moviéndose `dist` casillas a `speed`
-- casillas/s, por escalones de `step` (0 = seguido) con `pause` s entre
-- ellos. Devuelve (recorrido, duración total).
local function travel(dist, speed, step, pause, u)
    speed = math.max(0.01, speed)
    if dist <= 0 then return 0, 0 end
    if not step or step <= 0 or step >= dist then
        return math.min(dist, u * speed), dist / speed
    end
    local n = math.ceil(dist / step - 1e-9)
    local total = dist / speed + (n - 1) * pause
    local done, rem = 0, u
    for i = 1, n do
        local d = math.min(step, dist - (i - 1) * step)
        local tt = d / speed
        if rem <= tt then return done + rem * speed, total end
        done, rem = done + d, rem - tt
        if i < n then
            if rem <= pause then return done, total end
            rem = rem - pause
        end
    end
    return dist, total
end

-- ── Construcción ──────────────────────────────────────────────────────────────
-- Una inundación a partir de una colocación normalizada de tipo 'flood'
function Floods.fromPlacement(pl, Materials)
    local p = pl.props or {}
    local cr = p.corner or {}
    local c0, c1 = math.min(pl.col, num(cr.col, pl.col)), math.max(pl.col, num(cr.col, pl.col))
    local r0, r1 = math.min(pl.row, num(cr.row, pl.row)), math.max(pl.row, num(cr.row, pl.row))
    local T = TILE_PX
    local f = {
        col0 = c0, row0 = r0, col1 = c1, row1 = r1,
        x0 = (c0 - 1) * T, x1 = c1 * T, y0 = (r0 - 1) * T, y1 = r1 * T,
        hTiles = r1 - r0 + 1,
        mat = Materials and Materials.get('water') or nil,
    }
    f.id      = math.floor(num(p.id, pl.floodIndex or 0))
    f.control = (p.control == 'boss' or p.control == 'switch' or p.control == 'tide') and p.control or 'cycle'
    f.cold = math.max(0, num(p.cold, 0))         -- (agua helada: s hasta congelarse; 0 = normal)
    f.tidePeriod = math.max(1, num(p.tidePeriod, 20))
    f.tidePhase  = num(p.tidePhase, 0) % 1
    f.zoneId  = math.floor(num(p.zone, 0))
    f.undertow = num(p.undertow, 0)              -- (resaca: px/s mientras baja; 0 = ninguna)
    local lo = math.max(0, math.min(f.hTiles, num(p.startLevel, 1)))
    local hi = math.max(lo, math.min(f.hTiles, num(p.maxLevel, f.hTiles)))
    f.lo, f.hi = lo, hi
    f.startDelay = math.max(0, num(p.startDelay, 3))
    f.holdTime   = math.max(0, num(p.holdTime, 4))
    f.lowTime    = math.max(0, num(p.lowTime, 4))
    f.riseSpeed, f.riseStep, f.risePause = num(p.riseSpeed, 0.5), num(p.riseStep, 0), num(p.risePause, 1)
    f.fallSpeed, f.fallStep, f.fallPause = num(p.fallSpeed, 0.5), num(p.fallStep, 0), num(p.fallPause, 1)
    local D = hi - lo
    f.riseT = select(2, travel(D, f.riseSpeed, f.riseStep, f.risePause, 0))
    f.fallT = select(2, travel(D, f.fallSpeed, f.fallStep, f.fallPause, 0))
    f.cycle = f.riseT + f.holdTime + f.fallT + f.lowTime
    -- (controlada: empieza apagada en su mínimo)
    f.active, f.t0, f.L0 = false, 0, lo
    Floods.setFloodTime(f, 0)
    f.prevLevel, f.moving = f.level, false
    return f
end

function Floods.build(placements, Materials)
    local out = {}
    for _, pl in ipairs(placements or {}) do
        -- (sin id guardado: su número de orden entre las inundaciones)
        if pl.type == 'flood' then
            pl.floodIndex = #out + 1
            out[#out+1] = Floods.fromPlacement(pl, Materials)
        end
    end
    return out
end

-- Inundación con ese id, o nil
function Floods.byId(level, id)
    for _, f in ipairs(level.floods or {}) do if f.id == id then return f end end
    return nil
end

-- Enlaza las controladas: zona de jefe (por id, o la que se solapa con su
-- área, o la más cercana) y bloques ON/OFF (level.links)
function Floods.link(level)
    for _, f in ipairs(level.floods or {}) do
        f.zone, f.switches = nil, {}
        if f.control == 'boss' then
            local best, bd
            for _, z in ipairs(level.bossZones or {}) do
                if f.zoneId > 0 then
                    if z.id == f.zoneId then best = z end
                else
                    local ix = math.min(f.x1, z.x1) - math.max(f.x0, z.x0)
                    local iy = math.min(f.y1, z.y1) - math.max(f.y0, z.y0)
                    local d = (ix > 0 and iy > 0) and -ix * iy
                              or math.abs((f.x0 + f.x1) / 2 - (z.x0 + z.x1) / 2) + math.abs((f.y0 + f.y1) / 2 - (z.y0 + z.y1) / 2)
                    if not bd or d < bd then best, bd = z, d end
                end
            end
            f.zone = best
        end
    end
    for _, f in ipairs(level.floods or {}) do
        f.switches = level.linkedCells and level:linkedCells(f.id) or {}
    end
end

-- ── Línea de tiempo ──────────────────────────────────────────────────────────
-- Nivel (casillas sobre el fondo del rectángulo) y fase en el instante t
function Floods.levelAt(f, t)
    local D = f.hi - f.lo
    if t < f.startDelay or D <= 0 or f.cycle <= 0 then return f.lo, 'low' end
    local u = (t - f.startDelay) % f.cycle
    if u < f.riseT then return f.lo + travel(D, f.riseSpeed, f.riseStep, f.risePause, u), 'rise' end
    u = u - f.riseT
    if u < f.holdTime then return f.hi, 'hold' end
    u = u - f.holdTime
    if u < f.fallT then return f.hi - travel(D, f.fallSpeed, f.fallStep, f.fallPause, u), 'fall' end
    return f.lo, 'low'
end

-- Marea: nivel y fase en el instante t (seno entre lo y hi; 'hold' / 'low' en el 4 % de arriba / abajo)
function Floods.tideAt(f, t)
    local D = f.hi - f.lo
    if D <= 0 then return f.lo, 'low' end
    local a = 2 * math.pi * (t / f.tidePeriod + f.tidePhase)
    local u = 0.5 - 0.5 * math.cos(a)                -- (0 = marea baja, 1 = alta)
    local ph
    if u > 0.96 then ph = 'hold' elseif u < 0.04 then ph = 'low'
    else ph = (math.sin(a) > 0) and 'rise' or 'fall' end
    return f.lo + D * u, ph
end

-- ¿La deciden los bloques ON/OFF o una pelea? (las demás son función pura del tiempo)
local function controlled(f) return f.control == 'boss' or f.control == 'switch' end
Floods.controlled = controlled

-- Controlada: desde el cambio en t0 (nivel L0) sube / hace su ciclo (activa)
-- o baja a su mínimo (apagada)
function Floods.controlledLevelAt(f, t)
    local u = math.max(0, t - f.t0)
    if f.active then
        if f.control == 'boss' then return Floods.levelAt(f, u) end
        local D = f.hi - f.L0
        local d = travel(D, f.riseSpeed, f.riseStep, f.risePause, u)
        return f.L0 + d, (d < D - 1e-6) and 'rise' or 'hold'
    end
    local D = f.L0 - f.lo
    local d = travel(D, f.fallSpeed, f.fallStep, f.fallPause, u)
    return f.L0 - d, (d < D - 1e-6) and 'fall' or 'low'
end

function Floods.setFloodTime(f, t)
    if f.control == 'tide' then f.level, f.phase = Floods.tideAt(f, t)
    elseif controlled(f) then f.level, f.phase = Floods.controlledLevelAt(f, t)
    else f.level, f.phase = Floods.levelAt(f, t) end
    f.surf = f.y1 - f.level * TILE_PX            -- Y de la superficie (px de mundo)
end

-- Fija el tiempo del nivel (servidor: tick * TICK_DT; cliente: estimación)
function Floods.setTime(level, t)
    level.floodTime = t
    for _, f in ipairs(level.floods or {}) do Floods.setFloodTime(f, t) end
end

-- ¿Debe estar activa ahora? (solo un jugador y el servidor: el cliente lo
-- recibe en los snapshots)
local function wantsActive(level, f)
    if f.control == 'boss' then
        local z = f.zone
        if not z or z.state ~= 'fight' then return false end
        for _, b in ipairs(z.bosses or {}) do
            if b.alive and not (b.isDying and b:isDying()) then return true end
        end
        return false
    end
    for _, c in ipairs(f.switches or {}) do
        if level:getDef(c[1], c[2]).name == 'switch_on' then return true end
    end
    return false
end

-- Decide los cambios de las controladas en el instante t (autoritativo: un
-- jugador y el servidor). El nivel al cambiar pasa a ser el nuevo L0.
function Floods.control(level, t)
    for _, f in ipairs(level.floods or {}) do
        if controlled(f) then
            local want = wantsActive(level, f)
            if want ~= f.active then
                f.L0 = Floods.controlledLevelAt(f, t)
                f.active, f.t0 = want, t
            end
        end
    end
end

-- Un jugador: el tiempo avanza con la partida
function Floods.advance(level, dt)
    if not level.floods or #level.floods == 0 then return end
    local t = (level.floodTime or 0) + dt
    Floods.control(level, t)
    Floods.setTime(level, t)
end

-- ── Red: estado de las controladas en cada snapshot ──────────────────────────
-- { {activa 0/1, t0 en ticks, L0 × 1000}, ... } en el orden de level.floods
-- (las de ciclo van como 0 y no se usan). nil si no hay ninguna controlada.
function Floods.netPack(level, tickDt)
    local out, any = {}, false
    for i, f in ipairs(level.floods or {}) do
        if controlled(f) then
            any = true
            out[i] = { f.active and 1 or 0, math.floor(f.t0 / tickDt + 0.5), math.floor(f.L0 * 1000 + 0.5) }
        else
            out[i] = 0
        end
    end
    return any and out or nil
end

function Floods.netApply(level, list, tickDt)
    if type(list) ~= 'table' then return end
    for i, f in ipairs(level.floods or {}) do
        local d = list[i]
        if controlled(f) and type(d) == 'table' then
            f.active = d[1] == 1
            f.t0 = (tonumber(d[2]) or 0) * tickDt
            f.L0 = (tonumber(d[3]) or 0) / 1000
        end
    end
end

-- ── Física ────────────────────────────────────────────────────────────────────
-- Resaca en el punto (px/s con signo, 0 = ninguna): la de la inundación cuya agua lo cubre, solo mientras BAJA
function Floods.currentAt(level, x, y)
    for _, f in ipairs(level.floods or {}) do
        if f.undertow ~= 0 and f.phase == 'fall' and x >= f.x0 and x < f.x1 and y >= f.surf and y < f.y1 then
            return f.undertow
        end
    end
    return 0
end

-- Agua HELADA de una inundación en el punto: sus s hasta congelarse, o nil (no helada, o fuera de su agua)
function Floods.coldAt(floods, x, y)
    for i = 1, #floods do
        local f = floods[i]
        if f.cold > 0 and x >= f.x0 and x < f.x1 and y >= f.surf and y < f.y1 then return f.cold end
    end
    return nil
end

-- Material líquido de una inundación en el punto, o nil
function Floods.liquidAt(floods, x, y)
    for i = 1, #floods do
        local f = floods[i]
        if x >= f.x0 and x < f.x1 and y >= f.surf and y < f.y1 then return f.mat end
    end
    return nil
end

-- ── Efectos (solo clientes: un jugador y online; nunca el servidor) ──────────
local BUB_EVERY = 0.35      -- s entre burbujas por cada 10 casillas de ancho

local function clampToRect(f, x, y)
    return math.max(f.x0, math.min(f.x1, x)), math.max(f.surf, math.min(f.y1, y))
end

-- Sonido al empezar a moverse el agua (también en cada escalón) y burbujas
function Floods.updateFx(level, dt)
    for _, f in ipairs(level.floods or {}) do
        local moving = math.abs(f.level - (f.prevLevel or f.level)) > 1e-4
        if moving and not f.moving then
            local rising = f.level > f.prevLevel
            -- Suena desde el punto de la inundación más cercano a quien escucha
            local lx, ly = Sound.getListener()
            local sx, sy = clampToRect(f, lx or (f.x0 + f.x1) / 2, ly or f.surf)
            Sound.playAt(rising and 'floodRise' or 'floodFall', sx, sy)
        end
        f.moving, f.prevLevel = moving, f.level
        -- Aviso de la resaca: al empezar a arrastrar, si quien escucha está en el agua o cerca (4 casillas)
        local drag = f.undertow ~= 0 and f.phase == 'fall' and f.level > 0.3
        if drag and not f.alertAt then
            local lx, ly, m = Sound.getListener()
            m = TILE_PX * 4
            if lx and lx >= f.x0 - m and lx < f.x1 + m and ly >= f.y0 - m and ly < f.y1 + m then
                f.alertAt = love.timer.getTime()
                Sound.play('undertowAlert')
            end
        elseif not drag then
            f.alertAt = nil
        end
        -- Resaca: espuma que corre por la superficie hacia donde arrastra (el aviso de la corriente)
        if f.undertow ~= 0 and f.phase == 'fall' and f.level > 0.3 then
            f.foamT = (f.foamT or 0) + dt * (f.x1 - f.x0) / (TILE_PX * 10)
            Particles = Particles or require 'src/fx/Particles'
            while f.foamT >= 0.12 do
                f.foamT = f.foamT - 0.12
                local x = f.x0 + math.random() * (f.x1 - f.x0)
                local y = f.surf + 6 + math.random() * math.min(f.y1 - f.surf - 12, TILE_PX * 2.5)
                if not level:collisionAt(x, y) then Particles.emit('undertow_foam', x, y, { dir = f.undertow }) end
            end
        end
        -- Burbujas que suben hasta la superficie
        if f.level > 0.4 then
            f.bubT = (f.bubT or 0) + dt * (f.x1 - f.x0) / (TILE_PX * 10) * (moving and 2.5 or 1)
            while f.bubT >= BUB_EVERY do
                f.bubT = f.bubT - BUB_EVERY
                if level.spawnBubble then
                    -- Nace en el punto de agua libre más hondo de una columna al azar: el
                    -- rectángulo de la inundación puede empezar DENTRO de bloques (agua que
                    -- sube desde bajo el suelo) y antes no salía ninguna burbuja
                    for _ = 1, 4 do
                        local x = f.x0 + 8 + math.random() * (f.x1 - f.x0 - 16)
                        local y = f.y1 - 6
                        while y > f.surf + 12 and level:collisionAt(x, y) do y = y - TILE_PX / 4 end
                        if y > f.surf + 12 then level:spawnBubble(x, y); break end
                    end
                end
            end
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Reglas (solo el dibujo: la física sigue siendo Floods.liquidAt, agua en todo el rectángulo bajo la superficie):
--  · El agua de casillas se pinta sola (Level:renderWaterEffect): aquí se salta, no dos tintes.
--  · Un bloque macizo se tiñe solo si lo TAPA agua que se ve encima (la inundación va por delante de los bloques y
--    rompibles que cubre, 3.7.1); el tinte entra poco a poco con la hondura de esa agua (COVER_FADE px), sin saltos
--    cuando la superficie cruza la cara de arriba del suelo. Si la superficie está DENTRO del bloque (la marea bajo
--    tierra) no se pinta nada en él: ni tinte ni olas.
--  · La superficie (olas, línea clara) solo se pinta en celdas abiertas y si encima no hay más agua (otra inundación
--    o agua de casillas): dos aguas que se juntan son UN cuerpo con una sola superficie, la de arriba.
--  · Donde dos inundaciones se solapan, cada trozo es de la primera de la lista (como Floods.liquidAt): un solo tinte.
local COVER_FADE = TILE_PX / 2

function Floods.tintOf(f)
    return (f.cold > 0 and f.mat and f.mat.coldTint) or (f.mat and f.mat.tint) or { 0.05, 0.3, 0.9, 0.35 }
end

-- La inundación cuya agua entra en [a, b) de la columna col (la primera de la lista, como la física) y el trozo
-- que ocupa, o nil. Lo usa el agua de casillas para su tinte y su superficie.
function Floods.coverIn(floods, col, a, b)
    for i = 1, #floods do
        local f = floods[i]
        if f.level > 0 and col >= f.col0 and col <= f.col1 then
            local pa, pb = math.max(a, f.surf), math.min(b, f.y1)
            if pb > pa then return f, pa, pb end
        end
    end
    return nil
end

local function closedCell(level, col, row)
    local d = level:getDef(col, row)
    return d.collision == 'solid' and d.fullHitbox
end

-- Tramos de la columna col que son agua de la inundación i y no de una anterior (SEGS = a1, b1, a2, b2...; n = cuántos
-- números)
local SEGS = {}
local function ownSegments(floods, i, col)
    local f = floods[i]
    for k = #SEGS, 1, -1 do SEGS[k] = nil end
    local n = 2
    SEGS[1], SEGS[2] = f.surf, f.y1
    for j = 1, i - 1 do
        local g = floods[j]
        if g.level > 0 and col >= g.col0 and col <= g.col1 then
            local k = 1
            while k < n do
                local a, b = SEGS[k], SEGS[k + 1]
                if g.surf < b and g.y1 > a then              -- (le quita [g.surf, g.y1): quedan 0, 1 o 2 tramos)
                    local keepA, keepB = g.surf > a, g.y1 < b
                    if keepA and keepB then
                        table.insert(SEGS, k + 2, b); table.insert(SEGS, k + 2, g.y1)
                        SEGS[k + 1] = g.surf
                        n = n + 2; k = k + 4
                    elseif keepA then SEGS[k + 1] = g.surf; k = k + 2
                    elseif keepB then SEGS[k] = g.y1; k = k + 2
                    else table.remove(SEGS, k); table.remove(SEGS, k); n = n - 2 end
                else
                    k = k + 2
                end
            end
        end
    end
    return SEGS, n
end

-- Recorre los trozos de agua de la inundación i que se pintan (en pantalla):
-- fn(x, y, w, h, kTinte, superficie, wa, wb) — x, y, w, h en px de pantalla; wa, wb = el trozo en px de mundo;
-- kTinte < 1 = bloque tapado por poca agua; superficie = el trozo empieza en la superficie y se ve.
local function eachWetPiece(level, i, camX, camY, liquidOfCell, fn)
    local floods = level.floods
    local f = floods[i]
    local T = TILE_PX
    local c0 = math.max(f.col0, math.floor(camX / T) + 1)
    local c1 = math.min(f.col1, math.floor((camX + WINDOW_W) / T) + 1)
    local rs = math.max(f.row0, math.floor(f.surf / T) + 1)
    local rTop = math.floor(camY / T) + 1
    local r1 = math.min(f.row1, math.floor((camY + WINDOW_H) / T) + 1)
    for col = c0, c1 do
        local segs, n = ownSegments(floods, i, col)
        if n > 0 then
            local xw = (col - 1) * T
            local x = math.floor(xw - camX)
            -- (¿se ve la superficie? encima no hay más agua: ni otra inundación ni agua de casillas)
            local surfOk = not level:liquidAt(xw + T / 2, f.surf - 0.5)
            local depth, prevClosed = 0, false   -- (px de agua ABIERTA justo encima del bloque en el que se está)
            for row = rs, r1 do
                local cT, cB = (row - 1) * T, row * T
                local wa, wb = math.max(cT, f.surf), math.min(cB, f.y1)
                if wb > wa then
                    local closed = closedCell(level, col, row)
                    local k = 1
                    if closed then
                        k = math.min(1, depth / COVER_FADE)
                    else
                        if prevClosed then depth = 0 end
                        depth = depth + (wb - wa)
                    end
                    prevClosed = closed
                    if row >= rTop and k > 0 and liquidOfCell(level, col, row) == nil then
                        for s = 1, n - 1, 2 do
                            local pa, pb = math.max(wa, segs[s]), math.min(wb, segs[s + 1])
                            if pb > pa then
                                local y = math.floor(pa - camY)
                                local h = math.floor(pb - camY) - y
                                if h > 0 then
                                    fn(x, y, T, h, k, surfOk and not closed and pa == f.surf, pa, pb, col)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Distorsión: la escena otra vez con el shader, recortada a lo sumergido (sin distorsión justo bajo la ola)
-- addRect(x, y, w, h): añade a la malla de la distorsión (Level:renderWaterEffect) cada trozo mojado
function Floods.renderDistort(level, camX, camY, addRect, liquidOfCell)
    local M = WaterSurface.MARGIN
    for i, f in ipairs(level.floods or {}) do
        if f.level > 0 then
            eachWetPiece(level, i, camX, camY, liquidOfCell, function(x, y, w, h, _, surf)
                if surf then addRect(x, y + M, w, h - M) else addRect(x, y, w, h) end
            end)
        end
    end
end

-- Tinte + superficie con olas (el trozo de la superficie lo pinta WaterSurface, con la parte de arriba siguiendo la
-- ola)
local FADED = { 0, 0, 0, 0 }
function Floods.renderTint(level, camX, camY, liquidOfCell)
    local t = love.timer.getTime()
    local T = TILE_PX
    for i, f in ipairs(level.floods or {}) do
        if f.level > 0 and f.mat then
            local tint = Floods.tintOf(f)
            local amp = f.moving and 3 or 2
            eachWetPiece(level, i, camX, camY, liquidOfCell, function(x, y, w, h, k, surf, wa, wb, col)
                if surf then
                    WaterSurface.draw((col - 1) * T, col * T, f.surf, wb, camX, camY, tint, amp, t)
                else
                    if k < 1 then
                        FADED[1], FADED[2], FADED[3], FADED[4] = tint[1], tint[2], tint[3], (tint[4] or 1) * k
                        love.graphics.setColor(FADED)
                    else
                        love.graphics.setColor(tint)
                    end
                    love.graphics.rectangle('fill', x, y, w, h)
                end
            end)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

Floods.travel = travel
return Floods
