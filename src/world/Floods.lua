-- src/world/Floods.lua
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

local Floods = {}
local WaterSurface = require 'src/fx/WaterSurface'

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
    Floods.setFloodTime(f, 0)
    f.prevLevel, f.moving = f.level, false
    return f
end

function Floods.build(placements, Materials)
    local out = {}
    for _, pl in ipairs(placements or {}) do
        if pl.type == 'flood' then out[#out+1] = Floods.fromPlacement(pl, Materials) end
    end
    return out
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

function Floods.setFloodTime(f, t)
    f.level, f.phase = Floods.levelAt(f, t)
    f.surf = f.y1 - f.level * TILE_PX            -- Y de la superficie (px de mundo)
end

-- Fija el tiempo del nivel (servidor: tick * TICK_DT; cliente: estimación)
function Floods.setTime(level, t)
    level.floodTime = t
    for _, f in ipairs(level.floods or {}) do Floods.setFloodTime(f, t) end
end

-- Un jugador: el tiempo avanza con la partida
function Floods.advance(level, dt)
    if not level.floods or #level.floods == 0 then return end
    Floods.setTime(level, (level.floodTime or 0) + dt)
end

-- ── Física ────────────────────────────────────────────────────────────────────
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
        -- Burbujas que suben hasta la superficie
        if f.level > 0.4 then
            f.bubT = (f.bubT or 0) + dt * (f.x1 - f.x0) / (TILE_PX * 10) * (moving and 2.5 or 1)
            while f.bubT >= BUB_EVERY do
                f.bubT = f.bubT - BUB_EVERY
                if level.spawnBubble then
                    local x = f.x0 + 8 + math.random() * (f.x1 - f.x0 - 16)
                    if not level:collisionAt(x, f.y1 - 6) then level:spawnBubble(x, f.y1 - 6) end
                end
            end
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- ¿Celda que no se pinta de agua? (bloque macizo, o agua de tiles, que ya
-- tiene su propio tinte)
-- (Solo se salta el agua de tile, que ya se pinta sola: no dos tintes. Los
-- bloques NO: la inundación va por delante de todo lo que cubre, bloques,
-- rompibles, entidades... así se ve que el agua los tapa al subir)
local function skipCell(level, col, row, liquidOfCell)
    return liquidOfCell(level, col, row) ~= nil
end

-- Recorre las porciones visibles bajo el agua (una por celda):
-- fn(x, y, w, h, col, isSurface) en px de pantalla. `topMargin` = px que se
-- saltan bajo la superficie (la distorsión no llega hasta la ola)
local function eachWetCell(level, f, camX, camY, liquidOfCell, fn, topMargin)
    local T = TILE_PX
    local c0 = math.max(f.col0, math.floor(camX / T) + 1)
    local c1 = math.min(f.col1, math.floor((camX + WINDOW_W) / T) + 1)
    local rs = math.floor(f.surf / T) + 1
    local r0 = math.max(f.row0, rs, math.floor(camY / T) + 1)
    local r1 = math.min(f.row1, math.floor((camY + WINDOW_H) / T) + 1)
    for row = r0, r1 do
        local top = math.max((row - 1) * T, f.surf + (topMargin or 0))
        local y = math.floor(top - camY)
        local h = math.floor(math.min(row * T, f.y1) - camY) - y
        if h > 0 then
            for col = c0, c1 do
                if not skipCell(level, col, row, liquidOfCell) then
                    fn(math.floor((col - 1) * T - camX), y, T, h, col, row == rs)
                end
            end
        end
    end
end

-- Distorsión: la escena otra vez con el shader, recortada a lo sumergido
function Floods.renderDistort(level, camX, camY, sceneCanvas, setScissor, liquidOfCell)
    for _, f in ipairs(level.floods or {}) do
        if f.level > 0 then
            eachWetCell(level, f, camX, camY, liquidOfCell, function(x, y, w, h)
                setScissor(x, y, w, h)
                love.graphics.draw(sceneCanvas, 0, 0)
            end, WaterSurface.MARGIN)
        end
    end
end

-- Tinte + superficie con olas (la fila de la superficie la pinta
-- WaterSurface, con la parte de arriba siguiendo la ola)
function Floods.renderTint(level, camX, camY, liquidOfCell)
    local t = love.timer.getTime()
    local T = TILE_PX
    for _, f in ipairs(level.floods or {}) do
        if f.level > 0 and f.mat then
            local tint = f.mat.tint or { 0.05, 0.3, 0.9, 0.35 }
            local amp = f.moving and 3 or 2
            eachWetCell(level, f, camX, camY, liquidOfCell, function(x, y, w, h, col, isSurface)
                if isSurface then
                    local row = math.floor(f.surf / T) + 1
                    WaterSurface.draw((col - 1) * T, col * T, f.surf, math.min(row * T, f.y1),
                                      camX, camY, tint, amp, t)
                else
                    love.graphics.setColor(tint)
                    love.graphics.rectangle('fill', x, y, w, h)
                end
            end)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

Floods.travel = travel
return Floods
