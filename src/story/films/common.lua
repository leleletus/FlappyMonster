-- src/story/films/common.lua
-- Lo que comparten las dos películas de la historia (intro y final): medidas del decorado del cráter, el
-- "equipo" del modo Flappy (el jugador y las tuberías DE VERDAD, pilotados), los seis sitios del mapa donde
-- caen los fragmentos y unas cuantas curvas.
local Stage = require 'src/story/Stage'

local C = {}

-- ── Curvas ──────────────────────────────────────────────────────────────────
function C.lerp(a, b, k) return a + (b - a) * k end
function C.clamp(v) return math.max(0, math.min(1, v)) end
function C.smooth(k) k = C.clamp(k); return k * k * (3 - 2 * k) end
function C.easeIn(k) k = C.clamp(k); return k * k end
function C.easeOut(k) k = C.clamp(k); return 1 - (1 - k) * (1 - k) end
-- sobrepasa y vuelve (crecer de golpe)
function C.elastic(k)
    k = C.clamp(k)
    if k >= 1 then return 1 end
    return 1 - math.cos(k * math.pi * 2.5) * (1 - k) ^ 2
end
-- el "hinchazo" del aleteo: 1.18 al aletear y vuelve a 1 (como Player.lua)
function C.puff(t, at) return (t >= at) and (1 + 0.18 * math.exp(-(t - at) * 12)) or 1 end

-- ── El cráter (assets/story/sets/crater.json; tools/story/make_sets.py) ──────
C.CAMX, C.CAMY = 64, 112            -- la cámara del decorado (22x13 casillas: se ven 20 x 11,25)
C.FLOOR = 592                       -- y del centro del monstruo de pie en el suelo (suelo en y = 640)
C.MX, C.MF = 928, 576               -- el espejo: x de su centro, y de sus pies (sobre el pedestal)
C.HOLE_X = 352                      -- la chimenea del cráter (por donde se entra y se sale)

-- Dónde flota cada fragmento alrededor del marco cuando el espejo se rompe (7 = el del centro, arriba)
function C.hover(id, t)
    local n = tonumber(id:sub(1, 1))
    local sx, sy = Stage.shardSlot(id, C.MX, C.MF)
    local gx, gy = Stage.glassCenter(C.MX, C.MF)
    local dx, dy = sx - gx, sy - gy
    local d = math.sqrt(dx * dx + dy * dy)
    if n == 7 or d < 8 then dx, dy, d = 0, -1, 1 end
    local out = (n == 7) and 190 or 120
    local bob = math.sin((t or 0) * 2 + n * 1.3) * 8
    return sx + dx / d * out, sy + dy / d * out + bob
end

-- ── El modo Flappy, de verdad: su jugador y sus tuberías, pilotados ──────────
-- rig = { player, pipes, scroll, spawn (¿siguen saliendo tuberías?), targetY (sin tubería delante) }
local GAPS = { 330, 430, 300, 400, 340, 420, 310 }
function C.flappyRig(firstX, n)
    local Player = require 'src/entities/Player'
    local Pipe = require 'src/entities/Pipe'
    local rig = { player = Player:new(), pipes = {}, scroll = 0, targetY = 360, speed = PIPE_SPEED, flaps = 0, quiet = false }
    for i = 1, n or 0 do
        local p = Pipe:new(firstX + (i - 1) * 380, GAPS[(i - 1) % #GAPS + 1])
        if p.x + p.w <= WINDOW_W then p.entering, p.introT = true, 1 end
        rig.pipes[i] = p
    end
    return rig
end

function C.addPipe(rig, x, i)
    local Pipe = require 'src/entities/Pipe'
    rig.pipes[#rig.pipes + 1] = Pipe:new(x, GAPS[(i - 1) % #GAPS + 1])
end

-- Un paso: las tuberías avanzan, el jugador cae y ALETEA cuando baja de su altura (la del hueco que viene)
function C.flappyStep(rig, dt, mute)
    if dt <= 0 then return end
    local p = rig.player
    rig.scroll = rig.scroll + rig.speed * 0.4 * dt
    local target = rig.targetY
    for i = #rig.pipes, 1, -1 do
        local pipe = rig.pipes[i]
        pipe.x = pipe.x - rig.speed * dt
        pipe:update(dt)
        if pipe.x + pipe.w < -40 then table.remove(rig.pipes, i) end
    end
    for _, pipe in ipairs(rig.pipes) do
        if pipe.x + pipe.w > p.x - 30 and pipe.x < p.x + 520 then target = pipe.gapY + 24; break end
    end
    if p.vy > 30 and p.y > target then
        if mute or rig.quiet then                    -- (aletear sin sonido: el arnés de pruebas)
            p.vy, p.jumpTimer, p.puff = FLAP_VELOCITY, 0.2, 1.18
        else p:flap() end
        rig.flaps = rig.flaps + 1
    end
    p:update(dt)
    p.alive, p.dead = true, false                    -- (aquí nunca muere)
end

function C.flappyDraw(rig, withPipes)
    love.graphics.setColor(1, 1, 1, 1)
    if withPipes ~= false then for _, pipe in ipairs(rig.pipes) do pipe:render() end end
    rig.player:render()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Colores del fondo del Flappy (los de PlayState) y los de la historia
C.SKY_BLUE = { 0.50, 0.80, 1.00 }
C.SKY_DUSK = { 1.00, 0.60, 0.45 }
function C.mix(a, b, k) return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k } end

-- ── El mapa: dónde cae cada fragmento (y crece cada jefe), en el orden de la historia ─────────────────
local SNOW_ART = { img = 'assets/images/bosses/snowboss/body-Sheet.png', fw = 16 }
C.SNOW_ART = SNOW_ART
function C.targets()
    local _, SM = Stage.map()
    local out = {}
    for _, w in ipairs({ 1, 2, 3 }) do
        local bx, by = SM.bossXY(w)
        out[#out + 1] = { w = w, x = bx, y = by }
    end
    local nx, ny = SM.nodeXY(4, 3)                 -- la Gran Bola de Nieve: a media isla (lago_helado)
    out[#out + 1] = { snow = true, x = nx + 44, y = ny + 14 }
    for _, w in ipairs({ 4, 5 }) do
        local bx, by = SM.bossXY(w)
        out[#out + 1] = { w = w, x = bx, y = by }
    end
    return out
end

-- Tamaño de los jefes en el mapa: `sizes[i]` para cada uno de C.targets(); `mirror` = el del volcán
function C.setBosses(map, sizes, mirror)
    for i, tg in ipairs(C.targets()) do
        if tg.w then map.filmBoss[tg.w] = sizes[i] or 0 end
    end
    map.filmBoss[6] = mirror or 0
end

-- La Bola de Nieve no tiene castillo: se dibuja aparte (dentro de `extra` de filmDraw, en coordenadas del mapa)
function C.drawSnow(map, size)
    if not size or size <= 0 then return end
    local tg = C.targets()[4]
    love.graphics.setColor(1, 1, 1, 1)
    map:_drawBossArt(SNOW_ART, tg.x, tg.y, 4, size)
end

C.SMALL = 0.36          -- un enemigo normal, al lado de su versión gigante

return C
