-- MiniBoss1: la nave del Monstruo Malvado (port de MiniBoss1.cs).
--
-- Dos piezas visuales independientes en la misma entidad:
--  * La NAVE: se da la vuelta (flip) cada segundo; al atacar saca pinchos
--    por debajo; tiene un escape de humo debajo.
--  * El MONSTRUO MALVADO, detrás del cristal: alterna cada pocos segundos
--    entre Idle, Idle1 e Idle2 (Idle1 volteado) y pone cara de dolor al
--    recibir un golpe.
--
-- Entrada (cinemática genérica de Boss.lua, con jugadores congelados): baja
-- desde fuera de la pantalla, por encima de la zona, frenando hasta su altura
-- con su sonido de aparición, y enseña los pinchos un momento como amenaza.
--
-- Pelea (tiempos del original, Level1.unity):
--  * (Sin zona de jefe no hay entrada: baja al empezar la pelea, 'intro_fight'.)
--  * Patrulla por sus waypoints (editables en el editor) en línea recta de uno
--    a otro: deciden por dónde va y a qué altura.
--  * Si tiene un jugador debajo detectionTime s: se para, saca los pinchos y
--    se lanza en picado ('slam'). Cae hasta chocar con lo que haya debajo
--    (o hasta slamMax casillas): si son bloques rompibles los rompe todos a lo
--    ancho de la nave. Quien esté debajo MUERE. Nunca baja del suelo de su
--    zona: si ahí ya hay un agujero, se clava igual a esa altura.
--  * Tras el golpe se queda clavado stuckTime s ('stuck') y sube despacio
--    ('rise'): es el momento de saltarle encima (solo clavado y al empezar a
--    subir se le puede hacer daño: ~2 golpes por picado). Como el suelo va desapareciendo, cada golpe cae hasta donde
--    de verdad haya algo.
--  * Muerte: se queda quieta explotando; suena la muerte y el Monstruo sale
--    despedido en arco (animación de muerte, ojos en X, cae fuera de la
--    pantalla) mientras la nave sigue estallando hasta una explosión final.

local Entity   = require 'src/world/entities/Entity'
local Boss     = require 'src/world/entities/Boss'
local DeadEyes = require 'src/entities/DeadEyes'

local Ship = Entity.extend(Boss, {
    -- (aliados en Xtra extremo: qué estados son atacar)
    ATTACKS = { prep = true, slam = true },
    debugColor = { 0.3, 0.9, 1 },
    hitbox = { outerW = 0.92, outerH = 0.95, innerW = 0.8, innerH = 0.8 },
})

local S           = 5                  -- escala del pixel art (26x21 → 130x105)
local IDLE_EVERY  = { 2.0, 4.0 }       -- s entre cambios de idle del monstruo
local HURT_SHOW   = 0.8                -- s con cara de dolor tras un golpe
local FLIP_EVERY  = 1.0                -- la nave se voltea cada segundo
local SPIKE_GROW  = 0.3
local SPIKE_LEN   = 5 * S
local HOLD_T      = 1.8                -- s explotando antes de expulsar al monstruo
local EJECT_T     = 1.4                -- s más hasta la explosión final
local EJECT_VX, EJECT_VY = 260, -760
local DEAD_FPS    = 6                  -- animación de muerte (brazos arriba / abajo)

local function rand(a, b) return a + math.random() * (b - a) end

-- Dónde tiene los ojos el Monstruo Malvado (medido en sus sprites):
--  * vivo / con cara de dolor (lienzo 26x21, dibujado desde 13, 10.5):
--    fila 7, columnas 12 y 14 → punto medio (+0.5, -3) px de sprite, ±1 px
--  * expulsado (down/up, 11x15, dibujado desde su centro 5.5, 7.5):
--    fila 6, columnas 4 y 6 → punto medio (0, -1), ±1 px
local EYES_LIVE_DX, EYES_LIVE_DY = 0.5, -3
local EYES_DEAD_DX, EYES_DEAD_DY = 0, -1
local EYES_SEP = 1

local imgShip, imgIdle1, imgIdle2, imgHurt, imgDeadDown, imgDeadUp
function Ship.loadAssets()
    if imgShip then return end
    local function load(p)
        local i = love.graphics.newImage(p)
        if i.setFilter then i:setFilter('nearest', 'nearest') end
        return i
    end
    imgShip     = load('assets/images/bosses/miniboss1/ship.png')
    imgIdle1    = load('assets/images/bosses/miniboss1/monster/Idle1.png')
    imgIdle2    = load('assets/images/bosses/miniboss1/monster/idle2_forflipping.png')
    imgHurt     = load('assets/images/bosses/miniboss1/monster/hurt.png')
    imgDeadDown = load('assets/images/bosses/miniboss1/monster_dead/down.png')
    imgDeadUp   = load('assets/images/bosses/miniboss1/monster_dead/up.png')
end
function Ship.sizePx() return 26 * S, 21 * S end

function Ship:initBoss()
    -- Vuela un poco por encima del centro de su casilla (propiedad "lift")
    self.y       = self.y - (self.props.lift or 32)
    self.hoverY  = self.y
    self.idle, self.idleT, self.hurtT = 1, rand(IDLE_EVERY[1], IDLE_EVERY[2]), 0
    self.spike   = 0
    self.detectT = 0
    self.wp      = 1
    self.vy      = 0
    self.stuckFor = 0
    self.mx, self.my, self.mvx, self.mvy = 0, 0, 0, 0
    self.shipGone, self.monFrame = false, 0
end

-- Por encima de lo que enseña la cámara de su zona (fuera de la pantalla)
function Ship:introStartY()
    local z = self.zone
    if not z then return self.hoverY - WINDOW_H end
    local viewTop = math.min(z.y0, (z.y0 + z.y1) / 2 - WINDOW_H / 2)
    return viewTop - self.sprH / 2 - 24
end

-- Entrada: baja frenando (DESC_T s) y amenaza sacando los pinchos
local DESC_T, THREAT_AT, THREAT_T = 2.2, 2.35, 0.7
Ship.introLength = 3.4
function Ship:onIntroStart(level, players)
    self.x, self.y, self.spike = self.home.x, self:introStartY(), 0
    self.introY0 = self.y
    Sound.play('miniAppear')
end
function Ship:updateIntro(dt, level, t)
    local k = math.min(1, t / DESC_T)
    local e = 1 - (1 - k) ^ 3                           -- (frena al llegar)
    self.y = (self.introY0 or self.hoverY) + (self.hoverY - (self.introY0 or self.hoverY)) * e
    -- Amenaza: saca los pinchos de golpe y los recoge
    local a = t - THREAT_AT
    if a >= 0 and a - dt < 0 then
        Sound.play('spikesOut')
        Entity.emitFx('sparks', self.x, self.y + self.sprH / 2)
        Entity.emitFx('shake_small', self.x, self.y)
    end
    if a >= 0 and a < THREAT_T then self.spike = math.min(1, a / 0.12) * math.min(1, (THREAT_T - a) / 0.25)
    else self.spike = 0 end
end
function Ship:introFocus() return self.home.x, self.hoverY end

function Ship:onFightStart(n)
    self.spike = 0
    if self.state == 'ready' or self.introY0 then
        self.y, self.state, self.deadTimer = self.hoverY, 'patrol', 0   -- (ya hizo su entrada)
        return
    end
    self.y = self:introStartY()
    self.state, self.deadTimer = 'intro_fight', 0
    Sound.play('miniAppear')
end

-- ── Estados ───────────────────────────────────────────────────────────────────
function Ship:isDying()
    return self.state:sub(1, 6) == 'dying_' or self.state == 'dead' or not self.alive
end
-- Solo se le puede dañar clavado tras el picado (y justo al empezar a subir)
local RISE_VULN = 0.6
function Ship:isVulnerable()
    return self.state == 'stuck' or (self.state == 'rise' and self.deadTimer < RISE_VULN)
end
function Ship:canBeKnocked() return false end
function Ship:isSolidBody()
    return self.state ~= 'intro_fight' and Boss.isSolidBody(self)
end

-- Waypoint actual (px): los waypoints deciden por dónde vuela, también la
-- altura (con la misma elevación "lift" que su colocación)
function Ship:waypointPos()
    local list = self.props.waypoints
    if type(list) ~= 'table' or #list == 0 then return self.home.x, self.hoverY end
    if self.wp > #list then self.wp = 1 end
    local q = list[self.wp]
    return (q.col - 0.5) * TILE_PX, (q.row - 0.5) * TILE_PX - (self.props.lift or 32)
end

function Ship:playerBelow(level)
    local half = (self.props.detectWidth or 2.2) * TILE_PX / 2
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and math.abs(pa.x - self.x) <= half and pa.y > self.y then
            return pa
        end
    end
    return nil
end

function Ship:bottomY() return self.y + self.sprH / 2 + SPIKE_LEN * self.spike end

-- Columnas que rompe un picado: `breakTiles` centradas bajo la nave (con 2,
-- la de al lado más cercana). Los pinchos se dibujan justo sobre ellas.
function Ship:breakCols()
    local T = TILE_PX
    local n = math.max(1, self.props.breakTiles or 1)
    local cc = math.floor(self.x / T) + 1
    local c0 = cc - math.floor((n - 1) / 2)
    if n % 2 == 0 and (self.x % T) < T / 2 then c0 = c0 - 1 end     -- par: hacia el lado más cercano
    return c0, c0 + n - 1
end

-- Choque del picado: rompe los bloques rompibles de debajo de los pinchos
function Ship:impact(level, row, top)
    local T = TILE_PX
    local c0, c1 = self:breakCols()
    local broke = 0
    for c = c0, c1 do
        if level:getDef(c, row).breakable and level:breakTile(c, row) then
            broke = broke + 1
            Entity.emitFx('block_break', (c - 1) * T, (row - 1) * T)
        end
    end
    Sound.play('gpImpact', 0.65)
    Sound.play('spikeHit', 0.8)
    Entity.emitFx('gp_land', self.x, top)
    Entity.emitFx('sparks', self.x, top)
    Entity.emitFx('shake_small', self.x, top)
    self.state, self.deadTimer = 'stuck', 0
    self.stuckFor = self.props.stuckTime or 1.5
end

function Ship:updateBoss(dt, level)
    local p, T = self.props, TILE_PX
    -- Monstruo: cambia de idle cada pocos segundos; cara de dolor tras un golpe
    if self.hurtT > 0 then self.hurtT = math.max(0, self.hurtT - dt) end
    self.idleT = self.idleT - dt
    if self.idleT <= 0 then
        local nxt = math.random(1, 2); if nxt >= self.idle then nxt = nxt + 1 end
        self.idle, self.idleT = nxt, rand(IDLE_EVERY[1], IDLE_EVERY[2])
    end

    local st = self.state
    self.deadTimer = self.deadTimer + dt
    if st == 'dormant' then
        return
    elseif st == 'intro_fight' then
        -- InitialDescent (sin zona de jefe: sin entrada cinemática)
        self.y = math.min(self.hoverY, self.y + (p.descendSpeed or 110) * dt)
        if self.y >= self.hoverY then self.state, self.deadTimer = 'patrol', 0 end
    elseif st == 'patrol' then
        -- PatrolWaypoints: en línea recta hacia el siguiente punto (x e y)
        local tx, ty = self:waypointPos()
        local step = (p.moveSpeed or 200) * dt
        local dx, dy = tx - self.x, ty - self.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= step then
            self.x, self.y = tx, ty
            self.wp = self.wp % math.max(1, #(p.waypoints or {})) + 1
        else
            self.x, self.y = self.x + dx / d * step, self.y + dy / d * step
        end
        -- DetectPlayer: un jugador debajo un rato → ataque
        if self:playerBelow(level) then
            self.detectT = self.detectT + dt
            if self.detectT >= (p.detectTime or 0.25) and self:mayAttack(level) then   -- (aliado: por turnos)
                self.state, self.deadTimer, self.detectT = 'prep', 0, 0
                Sound.play('spikesOut')
                Entity.emitFx('sparks', self.x, self.y + self.sprH / 2)
            end
        else
            self.detectT = 0
        end
    elseif st == 'prep' then
        -- Se para y saca los pinchos
        self.spike = math.min(1, self.deadTimer / SPIKE_GROW)
        if self.deadTimer >= math.max(SPIKE_GROW, p.prepTime or 0.35) then
            self.state, self.deadTimer, self.vy, self.slamFrom = 'slam', 0, 200, self.y
            Sound.play('slamStart')
        end
    elseif st == 'slam' then
        -- Picado hasta lo primero que encuentre debajo (el suelo va desapareciendo)
        self.vy = math.min(p.slamSpeed or 1300, self.vy + 5000 * dt)
        local ny = self.y + self.vy * dt
        local bottom = ny + self.sprH / 2 + SPIKE_LEN * self.spike
        local hit, hitTile
        for _, fx in ipairs({ -0.4, 0, 0.4 }) do
            local t = level:collisionAt(self.x + self.sprW * fx, bottom, true)
            if t then hit, hitTile = t, true; break end
        end
        -- Nunca por debajo del suelo de su zona: si allí ya no queda suelo (lo
        -- rompió antes), se clava igual a esa altura, al alcance de quien esté
        -- en el borde del agujero
        local floorLine = self.zone and self.zone.y1 or math.huge
        if hitTile then
            local row = math.floor(bottom / T) + 1
            local top = (row - 1) * T + hit.hitbox.y * T
            self.y = top - (self.sprH / 2 + SPIKE_LEN * self.spike)
            self:impact(level, row, top)
        elseif bottom >= floorLine then
            self.y = floorLine - (self.sprH / 2 + SPIKE_LEN * self.spike)
            self:impact(level, math.floor(floorLine / T) + 1, floorLine)
        elseif ny - self.slamFrom >= (p.slamMax or 10) * T or bottom >= level.heightPx then
            -- No había nada debajo: se para un instante sin quedarse clavado
            self.y = ny
            self.state, self.deadTimer, self.stuckFor = 'stuck', 0, 0.4
        else
            self.y = ny
        end
    elseif st == 'stuck' then
        if self.deadTimer >= self.stuckFor then self.state, self.deadTimer = 'rise', 0 end
    elseif st == 'rise' then
        -- Vuelve a la altura desde la que atacó y sigue su ruta
        local backY = self.slamFrom or self.hoverY
        self.spike = math.max(0, self.spike - dt / SPIKE_GROW)
        self.y = self.y - (p.riseSpeed or 130) * dt
        if self.y <= backY then
            self.y = backY
            self.state, self.deadTimer, self.detectT = 'patrol', 0, 0
        end
    end
end

-- El picado mata a quien pille debajo (pinchos y casco de la nave)
function Ship:getHazardBoxes()
    if self.state ~= 'slam' and self.state ~= 'prep' then return nil end
    local w = self.sprW * 0.9
    local b = self._hz or { {} }
    self._hz = b
    local box = b[1]
    box.x, box.w = self.x - w / 2, w
    box.y = self.y + self.sprH * 0.1
    box.h = self.sprH * 0.4 + SPIKE_LEN * self.spike
    box.effect = 'kill'
    return b
end

function Ship:interact(pa)
    for _, hb in ipairs(self:getHazardBoxes() or {}) do
        local ob = pa:getOuterBounds()
        if ob.x < hb.x + hb.w and ob.x + ob.w > hb.x and ob.y < hb.y + hb.h and ob.y + ob.h > hb.y then
            return 'kill'
        end
    end
    return Boss.interact(self, pa)
end

function Ship:onDamaged(n, kind)
    self.hurtT = HURT_SHOW
end

-- ── Muerte: explota, sale disparado el monstruo y la nave revienta ───────────
function Ship:onDefeat()
    self.vy, self.hurtT = 0, HURT_SHOW * 3
end

function Ship:update(dt, level)
    local st = self.state
    if st == 'dying_hold' or st == 'dying_eject' or st == 'dying_boom' then
        return self:updateDeath(dt, level)
    end
    return Boss.update(self, dt, level)
end

local function blasts(self, every)
    local n = math.floor(self.deadTimer / every)
    while self.blastN <= n do
        Sound.play(self.blastN % 2 == 0 and 'bossExplode' or 'bossHurt', 0.9 + math.random() * 0.2)
        Entity.emitFx('boss_blast', self.x + (math.random() - 0.5) * self.sprW * 0.9,
                                    self.y + (math.random() - 0.5) * self.sprH * 0.8)
        self.blastN = self.blastN + 1
    end
end

function Ship:updateMonster(dt)
    self.mvy = self.mvy + ADV_GRAVITY * dt
    self.mx, self.my = self.mx + self.mvx * dt, self.my + self.mvy * dt
    self.monFrame = math.floor(self.deadTimer * DEAD_FPS) % 2
end

function Ship:updateDeath(dt, level)
    self.deadTimer = self.deadTimer + dt
    local st = self.state
    if st == 'dying_hold' then
        blasts(self, 0.5)
        if self.deadTimer >= HOLD_T then
            -- Suena la muerte y el monstruo sale despedido en arco
            Sound.play('dies2', 0.9)
            self.mx, self.my = self.x, self.y - 4 * S
            Entity.emitFx('boss_hit', self.mx, self.my)          -- sale disparado del cristal
            self.mvx = (math.random() < 0.5 and -1 or 1) * EJECT_VX
            self.mvy = EJECT_VY
            self.deathY = self.y
            self.state, self.deadTimer, self.blastN = 'dying_eject', 0, 0
        end
    elseif st == 'dying_eject' then
        self:updateMonster(dt)
        blasts(self, 0.22)                         -- la nave sigue reventando, más rápido
        if self.deadTimer >= EJECT_T then
            Sound.play('bossExplode', 0.6)
            Sound.play('bossExplode', 0.85)
            Entity.emitFx('boss_big_blast', self.x, self.y)
            Entity.emitFx('shake_big', self.x, self.y)
            self.shipGone = true
            self.state, self.deadTimer = 'dying_boom', 0
        end
    elseif st == 'dying_boom' then
        self:updateMonster(dt)
        if self.deadTimer > 1.0 and self.my > self.deathY + WINDOW_H + 200 then
            self.state = 'dead'
            self.alive = false
        end
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Ship:netPackExtra()
    return { self.hurtT > 0 and 4 or self.idle, math.floor(self.spike * 100 + 0.5),
             math.floor(self.mx + 0.5), math.floor(self.my + 0.5), self.shipGone and 1 or 0, self.monFrame }
end

function Ship:netApplyExtra(a, b, f)
    a = a or b
    self.idle = tonumber(b[1]) or 1
    self.hurtT = (self.idle == 4) and 1 or 0
    if type(b[2]) == 'number' then
        local s0 = type(a[2]) == 'number' and a[2] or b[2]
        self.spike = (s0 + (b[2] - s0) * f) / 100
    end
    if type(b[3]) == 'number' and type(b[4]) == 'number' then
        local ax, ay = tonumber(a[3]) or b[3], tonumber(a[4]) or b[4]
        if math.abs(ax - b[3]) > 200 then ax, ay = b[3], b[4] end
        self.mx, self.my = ax + (b[3] - ax) * f, ay + (b[4] - ay) * f
    end
    self.shipGone = b[5] == 1
    self.monFrame = tonumber(b[6]) or 0
end

-- ── Dibujo: nave y monstruo por separado ─────────────────────────────────────
local function drawExhaust(x, y)
    local t = love.timer.getTime()
    for i = 0, 3 do
        local w = (4 - i) * 5 + math.floor(math.sin(t * 30 + i) * 2)
        love.graphics.setColor(0.92, 0.92, 0.95, 0.55 - i * 0.1)
        love.graphics.rectangle('fill', x - w / 2, y + i * 7, w, 7)
    end
end

-- Pinchos de tamaño fijo (como los del diseño original: 5 a lo ancho de la
-- nave); salen menos cuantos menos bloques rompe: 2 con 1 bloque, 3 con 2...
local SPIKE_W = 24 * S / 5
local spikeImg
local function drawSpikes(x, bottomY, len, nTiles)
    if len < 1 then return end
    local n  = math.min(5, nTiles + 1)
    local sw = SPIKE_W
    local w  = n * sw
    -- assets/images/bosses/miniboss1/spike.png: una púa de SPIKE_W x SPIKE_LEN
    -- hacia abajo (+1 px de margen para el contorno); al salir se estira
    if not spikeImg then
        spikeImg = love.graphics.newImage('assets/images/bosses/miniboss1/spike.png')
        spikeImg:setFilter('nearest', 'nearest')
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i = 0, n - 1 do
        local sx = x - w / 2 + i * sw
        love.graphics.draw(spikeImg, sx - 1, bottomY, 0, 1, len / SPIKE_LEN, 0, 1)
    end
end

local Particles
function Ship:render(camX, camY)
    local st = self.state
    if st == 'dormant' and not EDITOR_VIEW then return end        -- aún fuera de escena
    -- Efectos que solo ve el cliente: humo del motor y, muy dañada, humo negro
    if not EDITOR_VIEW and not self.shipGone then
        Particles = Particles or require 'src/fx/Particles'
        local now = love.timer.getTime()
        if (st == 'intro' or st == 'intro_fight' or st == 'ready' or st == 'patrol' or st == 'rise') and now - (self._exT or 0) > 0.05 then
            self._exT = now
            Particles.emit('exhaust', self.x, self.y + self.sprH / 2 + 8)
        end
        local low = (self.hpMax or 1) > 0 and (self.hp or 0) / self.hpMax <= 0.4
        if (low or st:sub(1, 6) == 'dying_') and now - (self._smT or 0) > 0.12 then
            self._smT = now
            Particles.emit('smoke', self.x + (math.random() - 0.5) * self.sprW * 0.6, self.y - self.sprH * 0.1)
        end
    end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local dying = st:sub(1, 6) == 'dying_'
    if dying and not self.shipGone then
        x = x + math.floor((math.random() * 2 - 1) * 3)
        y = y + math.floor((math.random() * 2 - 1) * 3)
    end
    local ox, oy = 13, 10.5                                        -- centro del lienzo 26x21

    if not self.shipGone then
        -- Escape de humo bajo la nave
        if st == 'intro' or st == 'intro_fight' or st == 'ready' or st == 'patrol' or st == 'rise' then drawExhaust(x, y + self.sprH / 2) end
        -- Monstruo Malvado (detrás del cristal), si sigue dentro
        if st ~= 'dying_eject' and st ~= 'dying_boom' then
            local img, fx = imgIdle1, 1
            local hurt = self.idle == 4 or (self.hurtT or 0) > 0 or dying
            if hurt then img = imgHurt
            elseif self.idle == 2 then img = imgIdle2
            elseif self.idle == 3 then img, fx = imgIdle2, -1 end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y, 0, S * fx, S, ox, oy)
            -- La cara de dolor no tiene ojos: van en X (golpe y muerte)
            if hurt then DeadEyes.drawPair(x + EYES_LIVE_DX * S, y + EYES_LIVE_DY * S, EYES_SEP, S) end
        end
        -- Pinchos por debajo al atacar
        drawSpikes(x, y + self.sprH / 2 - S, SPIKE_LEN * (self.spike or 0), math.max(1, self.props.breakTiles or 1))
        -- Nave: se voltea cada segundo; roja al recibir daño o explotando
        local flip = (math.floor(love.timer.getTime() / FLIP_EVERY) % 2 == 0) and 1 or -1
        if self:flashRed() or (dying and math.floor(love.timer.getTime() * 12) % 2 == 0) then
            love.graphics.setColor(1, 0.25, 0.25, 1)
        else
            love.graphics.setColor(1, 1, 1, self:ghostAlpha())
        end
        love.graphics.draw(imgShip, x, y, 0, S * flip, S, ox, oy)
    end

    -- Monstruo expulsado: animación de muerte con ojos en X
    if st == 'dying_eject' or st == 'dying_boom' then
        local mx, my = math.floor(self.mx - camX), math.floor(self.my - camY)
        local img = (self.monFrame == 1) and imgDeadUp or imgDeadDown
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, mx, my, 0, S, S, img:getWidth() / 2, img:getHeight() / 2)
        DeadEyes.drawPair(mx + EYES_DEAD_DX * S, my + EYES_DEAD_DY * S, EYES_SEP, S)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'miniboss1', label = 'Nave Malvada', category = 'Jefes',
    description = 'Nave que patrulla por su ruta y se lanza en picado rompiendo el suelo.',
    class = Ship,
    boss = { title = 'MONSTRUO MALVADO' },
    hide = Boss.HIDE,
    defaults = { points = 50 },
    props = Boss.props({ hp = 5, hpPerPlayer = 3 }, {
        { key='waypoints', kind='points', label='Ruta (puntos)', group='Nave', min=1, max=16,
          default=function(d) return { { col = (d.col or 1) - 4, row = d.row or 1 }, { col = (d.col or 1) + 4, row = d.row or 1 } } end,
          help='Puntos por los que vuela, en orden y en línea recta (columna y fila: también deciden la altura)' },
        { key='lift', kind='int', label='Altura de vuelo (px)', group='Nave', default=32,
          min=-64, max=192, step=8, help='Cuánto vuela por encima del centro de la casilla donde se coloca' },
        { key='moveSpeed', kind='number', label='Velocidad de patrulla', group='Nave', default=200,
          min=20, max=800, step=10, help='px/s (el jugador anda a 240)' },
        { key='descendSpeed', kind='number', label='Velocidad al aparecer', group='Nave', default=110,
          min=20, max=800, step=10, help='px/s bajando desde fuera de la pantalla al empezar' },
        { key='detectTime', kind='number', label='Tiempo detectando', group='Ataque', default=0.25,
          min=0, max=3, step=0.05, help='Segundos con un jugador debajo antes de atacar' },
        { key='detectWidth', kind='number', label='Ancho de detección (casillas)', group='Ataque', default=2.2,
          min=0.2, max=10, step=0.1 },
        { key='prepTime', kind='number', label='Aviso (saca pinchos, s)', group='Ataque', default=0.35,
          min=0.3, max=3, step=0.05 },
        { key='slamSpeed', kind='number', label='Velocidad del picado', group='Ataque', default=1300,
          min=100, max=3000, step=50 },
        { key='slamMax', kind='int', label='Picado máximo (casillas)', group='Ataque', default=10,
          min=1, max=60, step=1, help='Si no encuentra nada debajo, no baja más que esto' },
        { key='breakTiles', kind='int', label='Bloques que rompe', group='Ataque', default=1,
          min=1, max=3, step=1, help='Bloques rompibles que destruye cada picado (los de debajo de los pinchos)' },
        { key='stuckTime', kind='number', label='Clavado tras el golpe (s)', group='Ataque', default=1.5,
          min=0, max=10, step=0.1, help='El momento de saltarle encima' },
        { key='riseSpeed', kind='number', label='Velocidad al subir', group='Ataque', default=130,
          min=20, max=1000, step=10, help='px/s volviendo a su altura' },
    }),
    editor = { sprite = 'assets/images/bosses/miniboss1/ship.png' },
}
