-- src/story/films/common.lua
-- Lo que comparten las películas de la historia (intro, final, persecución y guarida): medidas de los decorados
-- (el cráter, la ladera), el "equipo" del modo Flappy (el jugador y las tuberías DE VERDAD, pilotados), los
-- sitios del mapa donde caen los fragmentos, el Reflejo corriendo, los fragmentos que lleva el monstruo y unas
-- cuantas curvas. CUÁNTOS jefes y fragmentos hay y dónde está cada uno NO se escribe aquí: sale del catálogo
-- (assets/story/shards.json, src/story/Shards.lua) y del mapa (Worlds.LIST, overworld.json); las escenas que van
-- uno por uno (y su música) se alargan solas con `plus` en films.json (src/story/Film.lua).
local Stage = require 'src/story/Stage'
local Shards = require 'src/story/Shards'

local C = {}
C.FINAL = tostring(Shards.FINAL)                -- el fragmento del Espejo (el del centro)
local function base(id) return tostring(id):match('^%d+') end

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

-- ── El monstruo, como en los niveles (PlayerAdventure): quieto = cuadro 3; andar = 3↔2 a 8 por segundo (con su
-- "hinchazo" y su PASO en cada 3); subiendo = 2; cayendo = 1↔3 a 6 por segundo; agachado = 5 (mismo centro: no se hunde)
function C.pose(kind, t)
    t = t or 0
    if kind == 'walk' then
        local k = math.floor(t * 8)
        local on3 = k % 2 == 0
        return { frame = on3 and 3 or 2, puff = on3 and (1 + 0.08 * math.exp(-(t * 8 - k) * 3)) or 1 }
    elseif kind == 'rise' then return { frame = 2 }
    elseif kind == 'fall' then return { frame = (math.floor(t * 6) % 2 == 0) and 1 or 3 }
    elseif kind == 'crouch' then return { frame = 5 }
    end
    return { frame = 3 }
end
-- Un salto: altura (px hacia arriba) en u = 0..1 y la pose que toca (sube / cae / ya en el suelo: quieto al momento)
function C.hop(u, h, t)
    if u <= 0 or u >= 1 then return 0, C.pose('idle') end
    return math.sin(u * math.pi) * h, C.pose(u < 0.5 and 'rise' or 'fall', t)
end
-- Los PASOS de un tramo andando (t0..t1): suenan como en el juego, uno cada dos cuadros. Llamar desde update
function C.steps(c, t, dt, t0, t1)
    if t < t0 or t - dt >= t1 then return end
    local prev = t - dt
    if prev < t0 or math.floor((math.min(t, t1) - t0) * 4) > math.floor((prev - t0) * 4) then c.sfx('step') end
end

-- EL REFLEJO del monstruo en el espejo: su imagen de verdad — misma pose, vuelta, más pequeña cuanto más lejos
-- está del cristal, con los pies en el suelo de "dentro" y moviéndose al revés. (x, y, o) = lo mismo que se le
-- pasa a Stage.monster para el de fuera
function C.reflect(x, y, o)
    return function(gx, gy)
        local dist = math.max(0, C.MX - x)
        local k = C.clamp(dist / 560)
        local sc = 5.2 - 2.4 * k                                  -- cerca, casi a su tamaño; lejos, pequeño
        local q = {}
        for key, v in pairs(o or {}) do q[key] = v end
        q.scale, q.facing = sc, -(o and o.facing or 1)
        q.angle = o and o.angle and -o.angle or nil
        q.color, q.alpha, q.outline, q.noLight = { 0.78, 0.9, 1 }, 0.92, false, true
        local floorY = gy + 76 - 30 * k                           -- el suelo de dentro sube al alejarse (perspectiva)
        Stage.monster(gx - dist * 0.085, floorY - 8 * sc + (y - C.FLOOR) * sc / PLAYER_SCALE, q)
    end
end

-- ── El cráter (assets/story/sets/crater.json; tools/levelgen/make_sets.py) ──────
C.CAMX, C.CAMY = 64, 112            -- la cámara del decorado (22x13 casillas: se ven 20 x 11,25)
C.FLOOR = 592                       -- y del centro del monstruo de pie en el suelo (suelo en y = 640)
C.MX, C.MF = 928, 576               -- el espejo: x de su centro, y de sus pies (sobre el pedestal)
C.HOLE_X = 352                      -- la chimenea del cráter (por donde se entra y se sale)

-- Dónde flota cada fragmento alrededor del marco cuando el espejo se rompe (el del centro, arriba)
function C.hover(id, t)
    local n = tonumber(base(id))
    local final = base(id) == C.FINAL
    local sx, sy = Stage.shardSlot(id, C.MX, C.MF)
    local gx, gy = Stage.glassCenter(C.MX, C.MF)
    local dx, dy = sx - gx, sy - gy
    local d = math.sqrt(dx * dx + dy * dy)
    if final or d < 8 then dx, dy, d = 0, -1, 1 end
    local out = final and 190 or 120
    local bob = math.sin((t or 0) * 2 + n * 1.3) * 8
    return sx + dx / d * out, sy + dy / d * out + bob
end

-- ── La ladera del volcán (assets/story/sets/ladera.json y ladera_noche.json; make_sets.py) ──────
C.LCAMY = 48                        -- la cámara, en y (12 filas: se ven 11,25)
C.LFLOOR = 528                      -- y del centro del monstruo de pie (suelo en y = 576)
C.DITCH = { 1728, 1856 }            -- la zanja de lava (columnas 28-29), en x del mundo
C.LAKE = { 2688, 2880 }             -- el lago de lava (columnas 43-45: con un salto no llega; con el doble, sí)

-- Los fragmentos que LLEVA el monstruo (los de los jefes, todos menos el del Espejo; Xtra: sus mitades)
function C.carryIds(xtra)
    local out = {}
    for _, id in ipairs(Stage.shardIds(xtra)) do if base(id) ~= C.FINAL then out[#out + 1] = id end end
    return out
end

-- El BRILLO de un fragmento: su propia forma, más clara y sumada (un filo de luz de un píxel del dibujo alrededor y
-- otro más tenue a dos), y alguna chispa suelta. Pixel art: nada de cuadrados ni degradados
function C.shardGlow(id, x, y, s, rot, k, t)
    if not k or k <= 0 then return end
    love.graphics.setBlendMode('add')
    for ring = 2, 1, -1 do
        local d, a = s * ring, k * (ring == 1 and 0.55 or 0.22)
        for _, o in ipairs({ { d, 0 }, { -d, 0 }, { 0, d }, { 0, -d } }) do
            Stage.shard(id, x + o[1], y + o[2], { s = s, rot = rot, alpha = a, color = { 0.55, 0.85, 1 } })
        end
    end
    Stage.shard(id, x, y, { s = s, rot = rot, alpha = 0.35 * k * (0.7 + 0.3 * math.sin(t * 9)) })
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- Dónde va cada fragmento que lleva: en ARCO por encima de la cabeza (como una corona que flota), separados y
-- balanceándose cada uno a su aire. (Probado y descartado: un corro a la altura de los hombros y un corro estrecho
-- sobre la cabeza — de tres en tres se juntaban y parecían ALAS, y el monstruo NO tiene alas.) Con `lead`, en fila
-- por DELANTE de él, señalando hacia (dx, dy) (hacia el séptimo)
local function slot(i, n, x, y, t, lead, dx, dy)
    local a = math.pi * (1.1 + 0.8 * (i - 0.5) / n)          -- de 198° a 342°: el arco de arriba
    local rx = x + math.cos(a) * 82 + math.sin(t * 1.3 + i * 1.7) * 3
    local ry = y - 62 + math.sin(a) * 40 + math.sin(t * 2.6 + i * 2.1) * 4
    if not lead or lead <= 0 then return rx, ry, 1 end
    local d = 90 + (i - 1) * 38
    local lx = x + dx * d + math.sin(t * 4 + i) * 4
    local ly = y - 60 + dy * d + math.cos(t * 3 + i) * 5
    return C.lerp(rx, lx, C.smooth(lead)), C.lerp(ry, ly, C.smooth(lead)), 1
end

-- Los fragmentos que lleva. o: out 0..1 (cuánto los ha SACADO: cada uno sale de su cuerpo por turno; 0 = guardados,
-- no se ven), glow 0..1, shake (px), lead 0..1 + dx, dy (dirección, normalizada) = en fila por delante señalando
function C.carry(x, y, t, ids, o)
    o = o or {}
    local n = #ids
    local out = o.out == nil and 1 or o.out
    if out <= 0 then return end
    for i, id in ipairs(ids) do
        local k = C.clamp((out * n - (i - 1) * 0.6) / 1.6)  -- (cada uno sale un poco después del anterior)
        if k > 0 then
            local sx, sy, depth = slot(i, n, x, y, t, o.lead, o.dx or 1, o.dy or 0)
            local e = C.easeOut(k)
            sx, sy = C.lerp(x, sx, e), C.lerp(y - 8, sy, e)
            if o.shake and o.shake > 0 then sx = sx + (math.random() * 2 - 1) * o.shake end
            sx, sy = math.floor(sx), math.floor(sy)
            local rot = math.sin(t * 1.5 + i * 2.3) * 0.15
            local s = (k < 0.5) and 1 or 2                     -- (sale pequeño de su cuerpo)
            C.shardGlow(id, sx, sy, s, rot, (o.glow or 0) * (0.75 + 0.25 * math.sin(t * 6 + i)), t)
            Stage.shard(id, sx, sy, { s = s, rot = rot, alpha = (depth < -0.3 and not (o.lead and o.lead > 0.5)) and 0.8 or 1 })
            if (o.glow or 0) > 0.3 and math.random() < 0.02 * o.glow then
                Stage.spark(sx, sy, 1, 10, 30, { life = 0.5, s = 2 })
            end
        end
    end
end

-- EL REFLEJO a la carrera (como el Espejo perseguidor del nivel: colores invertidos y estela). o = lo de
-- Stage.monster; trail = cuántas copias detrás (0 = sin estela); (tx, ty) = hacia dónde queda la estela por
-- cada copia (por defecto, detrás de él: -14 px en su sentido)
function C.reflex(x, y, o, trail, tx, ty)
    o = o or {}
    local f = o.facing or 1
    tx, ty = tx or -f * 14, ty or 0
    for i = (trail or 0), 1, -1 do
        local q = {}
        for k, v in pairs(o) do q[k] = v end
        q.invert, q.alpha = true, 0.14 * (4 - i)
        Stage.monster(x + tx * i, y + ty * i, q)
    end
    local q = {}
    for k, v in pairs(o) do q[k] = v end
    q.invert = true
    Stage.monster(x, y, q)
end

-- El espejo flotante del jefe (types/bosses/mirror.lua: drawPortal), k 0..1 = cuánto se ha abierto
function C.portal(x, y, k, t)
    if k <= 0 then return end
    require('src/world/entities/types/bosses/mirror').class.drawPortal(math.floor(x), math.floor(y), k, t)
    love.graphics.setColor(1, 1, 1, 1)
end

-- La marca en el suelo de donde caerá el Reflejo (la del jefe: drawMark)
function C.mark(x, y, t)
    require('src/world/entities/types/bosses/mirror').class.drawMark(math.floor(x), math.floor(y), t)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── El modo Flappy, de verdad: su jugador y sus tuberías, pilotados ──────────
-- rig = { player, pipes, scroll, spawn (¿siguen saliendo tuberías?), targetY (sin tubería delante) }
local GAPS = { 330, 430, 300, 400, 340, 420, 310 }
function C.flappyRig(firstX, n)
    local Player = require 'src/flappy/Player'
    local Pipe = require 'src/flappy/Pipe'
    local rig = { player = Player:new(), pipes = {}, scroll = 0, targetY = 360, speed = PIPE_SPEED, flaps = 0, quiet = false }
    for i = 1, n or 0 do
        local p = Pipe:new(firstX + (i - 1) * 380, GAPS[(i - 1) % #GAPS + 1])
        if p.x + p.w <= WINDOW_W then p.entering, p.introT = true, 1 end
        rig.pipes[i] = p
    end
    return rig
end

function C.addPipe(rig, x, i)
    local Pipe = require 'src/flappy/Pipe'
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
-- Uno por jefe del catálogo (Shards.BOSSES): el de un castillo, junto a él (`castle`: lo dibuja el mapa, filmBoss); uno
-- de MITAD de isla (un nivel normal con jefe: la Gran Bola de Nieve), junto a su nodo con su arte del mapa (`art`:
-- `nodeBoss` del overworld.json, lo dibuja C.drawExtras). `normal` = su enemigo normal de antes del fragmento.
local TARGETS
function C.targets()
    if TARGETS then return TARGETS end
    local _, SM = Stage.map()
    local Worlds = require 'src/story/Worlds'
    local map = SM.loadMap()
    TARGETS = {}
    for _, s in ipairs(Shards.BOSSES) do
        for w = 1, Worlds.count() do
            for k, n in ipairs(Worlds.nodes(w)) do
                if n.id == s.level then
                    local tg = { w = w, normal = s.normal, shard = tostring(s.id) }
                    if n.boss then
                        tg.x, tg.y = SM.bossXY(w)
                        tg.castle = true
                    else
                        local nx, ny = SM.nodeXY(w, k)
                        tg.x, tg.y = nx + 44, ny + 14
                        tg.art = (map.worlds[w].def.nodeBoss or {})[n.id]
                    end
                    TARGETS[#TARGETS + 1] = tg
                end
            end
        end
    end
    return TARGETS
end
-- Cuántos jefes con fragmento (sin el Espejo) y una lista con `v` para cada uno (tamaños para setBosses)
function C.count() return #C.targets() end
function C.all(v)
    local out = {}
    for i = 1, C.count() do out[i] = v end
    return out
end
-- El mundo del Espejo (el volcán: el del nivel del fragmento final) y dónde está su jefe en el mapa
function C.mirrorWorld()
    local Worlds = require 'src/story/Worlds'
    for w = 1, Worlds.count() do
        if Shards.LEVEL[Worlds.get(w).boss] == Shards.FINAL then return w end
    end
    return Worlds.count()
end
function C.volcanoXY()
    local _, SM = Stage.map()
    return SM.bossXY(C.mirrorWorld())
end
-- La cámara de los planos GENERALES del mapa: TODAS las islas (la caja de la tierra del overworld.json, con una
-- casilla de margen), centradas entre las franjas de cine, con el zoom que las deja enteras (como mucho 0,5: el de
-- siempre; con más islas — una expansión — se aleja solo). → x, y, zoom
local LANDBOX
function C.far()
    local _, SM = Stage.map()
    if not LANDBOX then
        local M = SM.loadMap()
        local x0, y0, x1, y1 = math.huge, math.huge, -1, -1
        for y, row in ipairs(M.d.rows) do
            for x = 1, #row do
                if row:sub(x, x) ~= '~' then
                    x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
                end
            end
        end
        LANDBOX = { (x0 - 2) * M.C, (y0 - 2) * M.C, (x1 + 1) * M.C, (y1 + 1) * M.C }
    end
    local b = LANDBOX
    local bw, bh = b[3] - b[1], b[4] - b[2]
    local z = math.min(0.5, WINDOW_W / bw, (WINDOW_H - 2 * Stage.BAR_H) / bh)
    return (b[1] + b[3]) / 2 - WINDOW_W / z / 2, (b[2] + b[4]) / 2 - WINDOW_H / z / 2, z
end

-- La nota (semitonos sobre la tónica) del fragmento i de n al encajar: SUBEN la escala mayor y el último (el del
-- Espejo) cae en la tónica de arriba — 7: 0 2 4 5 7 9 12; 8: 0 2 4 5 7 9 11 12 (= tools/music/story_music.py rise)
local MAJOR = { 0, 2, 4, 5, 7, 9, 11 }
function C.note(i, n)
    local function deg(k) return MAJOR[(k - 1) % 7 + 1] + 12 * math.floor((k - 1) / 7) end
    if i < n then return deg(i) end
    return 12 * (math.floor(deg(math.max(1, n - 1)) / 12) + 1)
end

C.SMALL = 0.42          -- un enemigo normal, al lado de su versión gigante

local function isSmall(size) return size and size <= C.SMALL + 0.005 end

-- Tamaño de los jefes en el mapa: `sizes[i]` para cada uno de C.targets() (C.SMALL = todavía su enemigo normal);
-- `mirror` = el del volcán. Los de mitad de isla y los enemigos normales los dibuja C.drawExtras
function C.setBosses(map, sizes, mirror)
    for i, tg in ipairs(C.targets()) do
        if tg.castle then
            local size = sizes[i] or 0
            map.filmBoss[tg.w] = (isSmall(size) and tg.normal) and 0 or size
        end
    end
    map.filmBoss[C.mirrorWorld()] = mirror or 0
end

-- Lo que el mapa no dibuja solo (dentro de `extra` de filmDraw, en coordenadas del mapa): los jefes de mitad de isla
-- (no tienen castillo) y los enemigos normales de antes del fragmento
function C.drawExtras(map, sizes)
    love.graphics.setColor(1, 1, 1, 1)
    for i, tg in ipairs(C.targets()) do
        local size = sizes[i] or 0
        if isSmall(size) and tg.normal then
            map:_drawBossArt(tg.normal, tg.x, tg.y, tg.w, 0.62)          -- (su sprite, al tamaño de un enemigo del mapa)
        elseif tg.art and size > 0 then
            map:_drawBossArt(tg.art, tg.x, tg.y, tg.w, size)
        end
    end
end

return C
