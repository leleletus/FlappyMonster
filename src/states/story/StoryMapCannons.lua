-- src/states/story/StoryMapCannons.lua
-- PARTE de src/states/story/StoryMapState.lua: los CAÑONES entre islas (el usuario, 2026-10-29: "para cambiar de isla
-- se usa un puente; estaba pensando en usar un cañón. El cañón se carga con el jugador, apunta y dispara. Se vería
-- mejor y quedaría más cómico"). Cada cruce entre dos islas tiene un cañón en CADA punta (overworld.json `cannons`,
-- tools/art/story/make_overworld.py): el de ida junto al castillo y el de vuelta junto al primer nivel de la isla
-- siguiente. Al cruzar, el monstruo anda hasta el cañón, se mete (el cañón se aplasta), el cañón apunta, la mecha
-- chisporrotea, ¡BUM! (fogonazo, humo, la pantalla tiembla) y sale volando en parábola, dando vueltas y dejando una
-- estela, hasta la otra orilla: cae con un bote y polvo y sigue andando hasta el nodo. Cerrado (la isla siguiente
-- aún no se ha abierto) el cañón está taponado con un corcho y apagado; al abrirse, el corcho salta.
-- El camino del cruce es { castillo, primer nodo } con `fly` en el punto de llegada: "este tramo es un vuelo en
-- cañón" (StoryMapState `reversed` lo mantiene al darle la vuelta). Quien anda (update) se para en ese punto y
-- aquí se hace todo el número; el cañón de salida es el de la punta más cercana al monstruo.
-- La carga StoryMapState.lua con require(...)(StoryMapState, P).
local Worlds = require 'src/story/Worlds'

return function(StoryMapState, P)
local img, frameQ, stateOf, stopIndex, OPEN_AT = P.img, P.frameQ, P.stateOf, P.stopIndex, P.OPEN_AT

local S = 3                                  -- escala de dibujo (como el monstruo)
local FW, PIV = 32, 16                       -- cuadro del cañón y su eje (barrel-Sheet.png)
local CAR_W, CAR_H, TRUN_X, TRUN_Y = 16, 11, 7, 2      -- la cureña y dónde va el eje del cañón
local MOUTH, FOOT = 13, 10                   -- largo hasta la boca (px del sprite) · los pies, bajo el punto del mapa
local REST = 20                              -- grados en reposo
local HOP, AIM, FUSE, LAND = 0.32, 0.45, 0.6, 0.4      -- s de cada momento
local WALK = 300                             -- px/s andando hasta el cañón / desde donde cae
local IMG = 'assets/images/story/cannon/'

-- ── Datos: los cruces del overworld.json → en píxeles, y el tramo con `fly` ──────────────────────────────────────
-- (lo llama loadMap; sin `cannons` en el mapa se queda el puente de siempre)
function StoryMapState._buildCannons(MAP, dots)
    local list = MAP.d.cannons
    if not list then return end
    local C = MAP.C
    local function px(q) return { (q[1] + 0.5) * C, (q[2] + 0.5) * C } end
    for w = 1, Worlds.count() - 1 do
        local c, M, N = list[w], MAP.worlds[w], MAP.worlds[w + 1]
        if c and M and N then
            local castle, first = M.node[#Worlds.nodes(w)], N.node[1]
            local K = { w = w, a = px(c.a), b = px(c.b), la = px(c.la), lb = px(c.lb) }
            K.faceA = (K.b[1] >= K.a[1]) and 1 or -1
            K.faceB = -K.faceA
            M.cannon = K
            M.bridge = { { castle[1], castle[2] }, { first[1], first[2], fly = K } }
            -- (los puntos del camino: del castillo a su cañón y del otro cañón al primer nivel; el mar, sin nada)
            dots({ castle, K.a }, { w + 1, 1 })
            dots({ K.b, first }, { w + 1, 1 })
        end
    end
end

-- geometría de un cañón: el eje del cañón y la boca a `deg` grados (px del mapa)
local function trunnion(x, y, face)
    return x + face * (TRUN_X - CAR_W / 2) * S, y + FOOT - (CAR_H - TRUN_Y) * S
end
local function muzzle(x, y, face, deg)
    local tx, ty = trunnion(x, y, face)
    local a = math.rad(deg)
    return tx + face * math.cos(a) * MOUTH * S, ty - math.sin(a) * MOUTH * S
end
local function fuseTip(x, y, face, deg)
    local tx, ty = trunnion(x, y, face)
    local a = math.rad(deg)
    local u, v = -3, -5.4
    return tx + face * (math.cos(a) * u + math.sin(a) * v) * S, ty + (-math.sin(a) * u + math.cos(a) * v) * S
end
StoryMapState._cannonMuzzle = muzzle

local function ease(u) u = math.max(0, math.min(1, u)); return u * u * (3 - 2 * u) end

-- un efecto (humo, polvo, fogonazo) en px del mapa
function StoryMapState:_cfx(k, x, y, o)
    self.cfx = self.cfx or {}
    o = o or {}
    self.cfx[#self.cfx + 1] = { k = k, x = x, y = y, t = 0, life = o.life or 0.6, vx = o.vx or 0, vy = o.vy or 0,
                                s = o.s or S, c = o.c or { 1, 1, 1 } }
end

-- empieza el número del cañón para el punto `p` (el siguiente de la cola, con `fly`)
function StoryMapState:_flightStart(p)
    local K = p.fly
    local da = (self.heroX - K.a[1]) ^ 2 + (self.heroY - K.a[2]) ^ 2
    local db = (self.heroX - K.b[1]) ^ 2 + (self.heroY - K.b[2]) ^ 2
    local side = (da <= db) and 'a' or 'b'
    local can = K[side]
    local land = (side == 'a') and K.lb or K.la
    local face = (side == 'a') and K.faceA or K.faceB
    local F = { p = p, K = K, side = side, can = can, land = land, face = face, ph = 'walk', t = 0 }
    -- la parábola: de la boca al sitio donde cae; alto y duración según lo lejos que esté
    local deg = 50
    for _ = 1, 3 do
        local mx, my = muzzle(can[1], can[2], face, deg)
        local D = math.sqrt((land[1] - mx) ^ 2 + (land[2] - my) ^ 2)
        F.H = math.max(80, math.min(360, D * 0.3))
        F.T = math.max(0.8, math.min(2.4, 0.55 + D / 900))
        local vx = (land[1] - mx) * face
        local vy = (land[2] - can[2]) - 4 * F.H + (can[2] - my)
        deg = (vx <= 0) and 90 or math.max(30, math.min(90, math.deg(math.atan2(-vy, vx))))
    end
    F.aim = math.floor(deg / 10 + 0.5) * 10
    F.mx, F.my = muzzle(can[1], can[2], face, F.aim)
    self.flight = F
    return F
end

-- el ángulo del cañón `side` del cruce K ahora mismo (reposo, apuntando, de vuelta tras el disparo)
function StoryMapState:_cannonAngle(K, side)
    local F = self.flight
    if not F or F.K ~= K or F.side ~= side then return REST end
    if F.ph == 'walk' or F.ph == 'hop' then return REST end
    if F.ph == 'aim' then return REST + (F.aim - REST) * ease(F.t / AIM) end
    if F.ph == 'fuse' then return F.aim end
    return F.aim + (REST - F.aim) * ease((F.tBoom and (self.t - F.tBoom) or 0) / 0.9)
end

-- cada cuadro (desde update): el número del cañón si toca, los efectos y que salte el corcho de lo que se abre
function StoryMapState:_cannonTick(dt)
    self.boomShake = math.max(0, (self.boomShake or 0) - dt)
    self.flyH = 0
    for i = #(self.cfx or {}), 1, -1 do
        local e = self.cfx[i]
        e.t = e.t + dt
        e.x, e.y = e.x + e.vx * dt, e.y + e.vy * dt
        e.vx, e.vy = e.vx * (1 - math.min(1, dt * 3)), e.vy * (1 - math.min(1, dt * 3))
        if e.t >= e.life then table.remove(self.cfx, i) end
    end
    -- (lo recién abierto: el corcho de los dos cañones del cruce salta con una bocanada)
    if self.opening and not self.corksOut and self.t >= OPEN_AT then
        self.corksOut = true
        for w, M in ipairs(P.loadMap().worlds) do
            if M.cannon and self.opening[stopIndex(w + 1, 1)] then
                for _, side in ipairs({ 'a', 'b' }) do
                    local can = M.cannon[side]
                    local x, y = muzzle(can[1], can[2], M.cannon['face' .. side:upper()], REST)
                    self:_cfx('smoke', x, y, { life = 0.7, vy = -30 })
                end
            end
        end
    end
    local p = self.queue[1]
    if not (p and p.fly) then self.flight = nil; return end
    local F = self.flight
    if not F or F.p ~= p then F = self:_flightStart(p) end
    F.t = F.t + dt
    local function nextPh(ph) F.ph, F.t = ph, 0 end
    local function walkTo(x, y)                  -- anda; true al llegar
        local dx, dy = x - self.heroX, y - self.heroY
        local d = math.sqrt(dx * dx + dy * dy)
        if math.abs(dx) > 0.5 then self.facing = (dx > 0) and 1 or -1 end
        local step = WALK * dt
        if d <= step then self.heroX, self.heroY = x, y; return true end
        self.heroX, self.heroY = self.heroX + dx / d * step, self.heroY + dy / d * step
        return false
    end
    if F.ph == 'walk' then
        if walkTo(F.can[1], F.can[2]) then nextPh('hop') end
    elseif F.ph == 'hop' then
        if F.t >= HOP then
            Sound.play('cannonLoad')
            F.tLoad = self.t
            nextPh('aim')
        end
    elseif F.ph == 'aim' then
        if F.t >= AIM then Sound.play('cannonFuse'); nextPh('fuse') end
    elseif F.ph == 'fuse' then
        if F.t >= FUSE then
            -- ¡BUM!
            Sound.play('cannonBoom'); Sound.play('cannonWhoosh')
            F.tBoom = self.t
            self.boomShake = 0.35
            self.cannonShots = (self.cannonShots or 0) + 1          -- (para las pruebas: cuántos disparos)
            local a = math.rad(F.aim)
            self:_cfx('flash', F.mx, F.my, { life = 0.15 })
            for k = 1, 4 do
                local spd = 50 + k * 22
                self:_cfx('smoke', F.mx, F.my, { life = 0.7 + k * 0.12, vx = F.face * math.cos(a) * spd + (k - 2.5) * 12,
                                                 vy = -math.sin(a) * spd - 10, s = 3 })
            end
            nextPh('fly')
        end
    elseif F.ph == 'fly' then
        local u = math.min(1, F.t / F.T)
        self.heroX = F.mx + (F.land[1] - F.mx) * u
        self.heroY = F.can[2] + (F.land[2] - F.can[2]) * u
        self.flyH = F.H * 4 * u * (1 - u) + (F.can[2] - F.my) * (1 - u)
        self.facing = F.face
        F.trail = (F.trail or 0) + dt
        if F.trail >= 0.06 and u < 0.95 then
            F.trail = 0
            self:_cfx('smoke', self.heroX, self.heroY - self.flyH, { life = 0.45, s = 1.5 })
        end
        if u >= 1 then
            self.heroX, self.heroY, self.flyH = F.land[1], F.land[2], 0
            Sound.play('cannonLand')
            for _, side in ipairs({ -1, 1 }) do
                self:_cfx('smoke', F.land[1] + side * 10, F.land[2] + 6, { life = 0.5, vx = side * 60, vy = -12, s = 2, c = { 0.82, 0.72, 0.56 } })
            end
            nextPh('land')
        end
    elseif F.ph == 'land' then
        if F.t >= LAND then nextPh('walk2') end
    elseif F.ph == 'walk2' then
        if walkTo(p[1], p[2]) then
            table.remove(self.queue, 1)
            self.flight = nil
        end
    end
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────────────────────────────────────────
function StoryMapState:_drawCannon(K, side, cx, cy)
    local can = K[side]
    local face = (side == 'a') and K.faceA or K.faceB
    local x, y = can[1] - cx, can[2] - cy
    if x < -100 or x > WINDOW_W + 100 or y < -100 or y > WINDOW_H + 60 then return end
    -- cerrado = taponado y apagado (también un momento al volver al mapa, hasta que se abre a la vista)
    local locked = stateOf(K.w + 1, 1) == 'locked'
    if self.opening and self.opening[stopIndex(K.w + 1, 1)] and self.t < OPEN_AT then locked = true end
    local F = self.flight
    local mine = F and F.K == K and F.side == side
    local deg = self:_cannonAngle(K, side)
    local sy, ox = 1, 0
    if mine and F.tLoad and self.t - F.tLoad < 0.25 then sy = 1 - 0.18 * (1 - (self.t - F.tLoad) / 0.25) end   -- (se aplasta al meterse)
    if mine and F.ph == 'fuse' then ox = (math.floor(self.t * 30) % 2 == 0) and 1 or -1 end                -- (tiembla)
    if mine and F.tBoom and self.t - F.tBoom < 0.5 then ox = ox - face * math.floor(8 * (1 - (self.t - F.tBoom) / 0.5)) end   -- (culatazo)
    x = math.floor(x + ox)
    local tone = locked and 0.55 or 1
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle('fill', x - 22, math.floor(y + FOOT - 3), 44, 6)
    love.graphics.setColor(tone, tone, tone * (locked and 1.08 or 1), 1)
    local bar = img(IMG .. 'barrel-Sheet.png')
    local tx, ty = trunnion(x, y, face)
    local fi = locked and 11 or math.max(1, math.min(10, math.floor(deg / 10 + 0.5) + 1))
    local by = y + FOOT
    love.graphics.draw(bar, frameQ(bar, FW, fi), math.floor(tx), math.floor(by + (ty - by) * sy), 0, face * S, S * sy, PIV, PIV)
    local car = img(IMG .. 'carriage.png')
    love.graphics.draw(car, math.floor(x - face * CAR_W * S / 2), math.floor(by - CAR_H * S * sy), 0, face * S, S * sy)
    -- la mecha encendida
    if mine and F.ph == 'fuse' then
        local sx, sy2 = fuseTip(x, y, face, deg)
        local sp = img(IMG .. 'spark-Sheet.png')
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sp, frameQ(sp, 7, (math.floor(self.t * 18) % 3) + 1), math.floor(sx), math.floor(sy2), 0, S, S, 3.5, 3.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- todos los cañones (desde _drawPaths: bajo los bichos y el monstruo)
function StoryMapState:_drawCannons(cx, cy)
    for _, M in ipairs(P.loadMap().worlds) do
        if M.cannon then
            self:_drawCannon(M.cannon, 'a', cx, cy)
            self:_drawCannon(M.cannon, 'b', cx, cy)
        end
    end
end

-- los efectos y el monstruo mientras está en el número del cañón. true = ya dibujó al monstruo (_drawHero no)
function StoryMapState:_drawFlight(cx, cy)
    for _, e in ipairs(self.cfx or {}) do
        local u = e.t / e.life
        local im = img(IMG .. (e.k == 'flash' and 'flash-Sheet.png' or 'smoke-Sheet.png'))
        local fw = (e.k == 'flash') and 16 or 12
        local fi = math.min(e.k == 'flash' and 3 or 4, math.floor(u * (e.k == 'flash' and 3 or 4)) + 1)
        love.graphics.setColor(e.c[1], e.c[2], e.c[3], (e.k == 'flash') and 1 or math.min(1, (1 - u) * 2.5))
        love.graphics.draw(im, frameQ(im, fw, fi), math.floor(e.x - cx), math.floor(e.y - cy), 0, e.s, e.s, fw / 2, fw / 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
    local F = self.flight
    if not F or F.ph == 'walk' or F.ph == 'walk2' then return false end
    if F.ph == 'aim' or F.ph == 'fuse' then return true end            -- (dentro del cañón)
    if F.ph == 'hop' then
        -- un saltito hasta la boca y adentro, encogiéndose
        local u = math.min(1, F.t / HOP)
        local mx, my = muzzle(F.can[1], F.can[2], F.face, REST)
        local x = F.can[1] + (mx - F.can[1]) * u
        local y = F.can[2] + 8 + (my - F.can[2] - 8) * u - math.sin(u * math.pi) * 34
        local k = 1 - 0.6 * math.max(0, (u - 0.6) / 0.4)
        local im = img('assets/images/player/monstrito5.png')
        love.graphics.draw(im, math.floor(x - cx), math.floor(y - cy), 0, F.face * S * k, S * k, 4.5, 16)
        return true
    end
    -- volando (hecho una bola, dando vueltas) o cayendo con un bote
    local x, y = math.floor(self.heroX - cx), math.floor(self.heroY - cy)
    if F.ph == 'fly' then
        local h = self.flyH or 0
        local sw = math.max(8, 24 - math.floor(h / 20))
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle('fill', x - math.floor(sw / 2), y + 6, sw, 5)
        love.graphics.setColor(1, 1, 1, 1)
        local im = img('assets/images/player/monstrito5.png')
        love.graphics.draw(im, x, math.floor(y - h), F.t * 12 * F.face, F.face * S, S, 4.5, 12)
        return true
    end
    local u = math.min(1, F.t / LAND)
    local squash = math.max(0, 1 - u * 3)                       -- (aplastado al caer…)
    local hop = (u > 0.3) and math.floor(math.sin((u - 0.3) / 0.7 * math.pi) * 14) or 0   -- (…y un bote)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', x - 12, y + 6, 24, 6)
    love.graphics.setColor(1, 1, 1, 1)
    local im = img('assets/images/player/monstrito1.png')
    love.graphics.draw(im, x, y + 8 - hop, 0, F.face * S * (1 + 0.3 * squash), S * (1 - 0.3 * squash), 4.5, 16)
    return true
end
end
