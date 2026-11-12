-- Jefe secreto TIFÓN, el Soplón Supremo (types/bosses/tifon.lua): el Soplón de la fortaleza crecido al tocar una astilla,
-- una nube de tormenta gigante con cola de tornado que flota sobre los tejados (docs/bosses/tifon.md; aspecto elegido por el
-- usuario el 2026-11-04: la forma de Remolino con los colores de Nubarrón, a x6). La astilla es la punta de su VELETA.
--   · VAGA por lo alto de la zona, mirándote; la veleta apunta hacia donde soplará.
--   · SOPLA ('warn' 1 s: rachas discontinuas, coge aire → 'blow' 2,6 s): viento por TODA la zona que te empuja a ti, a las
--     cajas, a las bombas (systems/Push). Detrás de una chimenea o una caja no llega (`sheltered`). En fase 2, a mitad
--     del soplo la veleta gira (aviso, `tifonVane`) y el viento CAMBIA DE LADO.
--   · ASPIRA ('inhale' 2 s, tras abrir la boca 0,35 s): tira de todo hacia su boca. LA VENTANA: una bomba LANZADA y
--     encendida que llega a la boca se la traga ('bomb' — el nombre que espera BombCore —), le revienta dentro ('boom'),
--     cae al tejado ('fall') y queda ATURDIDO ('stun'): pisotón 1 / ground pound 2 en lo alto de la nube, un golpe por
--     noqueo. Lo demás que llega a la boca (una bomba apagada, una caja) lo TOSE hacia ti ('cough'); y si llegas tú, te
--     escupe (−1).
--   · RAYOS ('charge' 1 s: marcas en el tejado que se encienden → 'strike' 0,3 s): −1 en la columna de cada marca. En
--     fase 2 además un ARCO a ras del tejado entre parejas de marcas (se salta).
--   · GRANIZO (fase 2, 'hail' 3 s): piedras que caen de lo alto; las cornisas y las cajas te tapan.
--   · Fase 2 a mitad de vida: ruge y gira ('roar'), todo más deprisa.
--   · Su cuerpo se atraviesa y no hace daño (como la Reina): lo que pega es lo que hace.
-- Todo lo que se dibuja y lo que empuja (pushAt, que también corre en el cliente para predecir al jugador) sale del
-- estado, deadTimer y netPackExtra.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local BossFx = require 'src/fx/BossFx'
local Edge   = require 'src/fx/Edge'
local Anim   = require 'src/fx/Anim'

local TF = Entity.extend(Boss, {
    ATTACKS  = { warn = true, blow = true, inhale = true, charge = true, strike = true, hail = true },
    OPENINGS = { stun = true },
    debugColor = { 0.6, 0.6, 0.75 },
    hitbox = { outerW = 0.6, outerH = 0.55, innerW = 0.5, innerH = 0.45 },
})
TF.hurtSound   = 'megaHurt'
TF.introLength = 3.2
TF.wantsLevel  = true
TF.animId      = 'bosses/tifon'

local T  = TILE_PX
local MS = 6                                     -- escala del arte (la del jugador: el usuario, 2026-11-04)
local FW, FH = 46, 44
-- Medidas del arte (px de arte desde el centro del cuadro, mirando a la izquierda; make_tifon.py --apply las imprime)
local TAIL_Y   = 19 * MS                         -- lo más bajo de la cola
local STUN_BOT, STUN_TOP, STUN_W = 13 * MS, -3 * MS, 18 * MS     -- tumbado: abajo, arriba y medio ancho
local MOUTH_DX, MOUTH_DY = 4 * MS, 4 * MS        -- la boca, delante y abajo del centro
local VANE_FOOT = { blow = 13, cough = 13, gulp = 11, boom = 11, stun = 22 }   -- fila del pie de la veleta (12 si no)
local VANE_DX  = 1.5 * MS                        -- el mástil, delante del centro

-- Ritmo (fase 1, 2)
local CRUISE   = 4.3 * T                         -- su centro, por encima del tejado
local DRIFT_V  = { 110, 150 }                    -- px/s que se desplaza
local KEEP     = 5.5 * T                         -- se queda a esta distancia de lado del jugador
local IDLE_T   = { 1.8, 1.3 }
local WARN_T, BLOW_T = 1.0, 2.6
local SWAP_AT, SWAP_WARN = 1.3, 0.55             -- fase 2: el viento cambia de lado a los SWAP_AT s (aviso antes)
local POWER    = { 400, 450 }                    -- px/s del viento (andar: 240 → no se le puede plantar cara)
local FADE     = 0.25
local SHELTER  = 3 * T                           -- un bloque a esta distancia contra el viento te tapa
local OPEN_T, INHALE_T = 0.35, 2.0
local SUCK_P   = 170                             -- px/s: lo que tira de un jugador hacia debajo de su boca
local SUCK_E   = 520                             -- px/s: lo que tira de un objeto hacia la boca (y lo levanta)
local SUCK_R   = 7 * T                           -- alcance de la aspiración (objetos)
local EAT_R    = 1.1 * T                         -- a esta distancia de la boca se traga / tose lo que llega
local SPIT_R   = 0.9 * T                         -- ...y te escupe a ti
local HIT_SPIT = { 1, 520, -420, 0.35, 0 }
local COUGH_T, COUGH_V = 0.5, { 620, -380 }
local CHARGE_T, STRIKE_T = { 1.0, 0.85 }, 0.3
local MARKS    = { 3, 4 }
local BOLT_W   = 0.45 * T                        -- medio ancho de la columna del rayo
local ARC_H    = 0.7 * T                         -- alto del arco a ras del tejado (se salta)
local ARC_MAX  = 6 * T
local HIT_BOLT = { 1, 320, -520, 0.3, 0 }
local HAIL_T, HAIL_EVERY, HAIL_V = 3.0, 0.2, 560
local HAIL_R   = 14
local HIT_HAIL = { 1, 180, -300, 0.2, 0 }
local BOMB_T   = 1.4                             -- (BombCore.EATEN_FUSE: 1,2 s y revienta)
local BOOM_T, FALL_T, RISE_T = 0.4, 0.55, 0.8
local STUN_T   = { easy = 6, normal = 5, hard = 4.2, extreme = 3.8, xtra = 3.5 }
local ROAR_T   = 1.6
local OUT_D, FLEE_T = 1.8, 1.8
local DEATH    = { dying_out = true, dying_flee = true }

local function rand(a, b) return a + math.random() * (b - a) end
local function sgn(v) return (v >= 0) and 1 or -1 end
function TF.sizePx() return FW * MS, FH * MS end
function TF:ph() return self.phase or 1 end
function TF:bossPhase() return self:ph() end
function TF:angryPhase() return self:ph() == 2 end

function TF:initBoss()
    self.y = self.row * T - T / 2
    self.vx, self.vy, self.onGround, self.flying = 0, 0, false, true
    self.phase, self.facing, self.windDir = 1, -1, -1
    self.marks, self.arcs, self.hail, self.nextId = {}, {}, {}, 0
    self.idleT, self.attackN, self.hailT = IDLE_T[1], 0, 0
    self.swapped, self.roared = false, false
end

function TF:onFightStart(n) self:enter('idle') end
function TF:rollStart(r) self.idleT = r(0.8, 2.2); self.attackN = math.random(0, 1) end

function TF:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function TF:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function TF:isVulnerable() return self:isActive() and self.state == 'stun' end
function TF:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function TF:isSolidBody() return false end
function TF:isObstacle() return false end
function TF:canBeKnocked() return false end
function TF:physicsFixed() return true end
function TF:canBePushed() return false end
function TF:holdsStill() return true end

-- La zona (con lo que llega por red en el cliente)
function TF:zb()
    if self.zone then return self.zone.x0, self.zone.x1, self.zone.y0, self.zone.y1 end
    if self.zx0 then return self.zx0, self.zx1, self.zy0, self.zy1 end
    return Boss.zoneBounds(self)
end

-- La boca en el mundo (para tragar, toser, escupir y lo que aspira)
function TF:mouthPos()
    local f = self.facing or -1
    return self.x + f * MOUTH_DX, self.y + MOUTH_DY
end
-- Lo que traga va dentro (BombCore la lleva aquí)
function TF:podCenter() return self.x, self.y end

-- El tejado bajo un punto (o nil: hueco)
function TF:roofBelow(level, x, y)
    local _, _, _, zy1 = self:zb()
    for yy = y, zy1 + T, 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / T) * T end
    end
end
function TF:floorY()
    local _, _, _, zy1 = self:zb()
    return self.roofY or zy1
end

-- ── La nube aturdida es lo único que se pisa (pura: el cliente predice igual) ─
function TF:interact(pa)
    if not self:isActive() then return nil end
    local ob = pa:getOuterBounds()
    local foot = ob.y + ob.h
    if self.state ~= 'stun' then
        -- volando: caerle encima solo rebota (no se queda nadie de pie en una nube)
        if pa.vy > 0 and math.abs(pa.x - self.x) < 14 * MS and foot > self.y - 14 * MS and foot < self.y - 6 * MS then
            return 'bounce', -math.abs(ADV_JUMP_VEL) * 0.45, (pa.x >= self.x) and 1 or -1
        end
        return nil
    end
    if self.ghost and self.inv > 0 then return nil end
    if pa.vy <= 0 and pa.gpPhase ~= 'fall' then return nil end
    local top = self.y + STUN_TOP
    if ob.x > self.x + STUN_W or ob.x + ob.w < self.x - STUN_W or foot < top - 30 or foot > top + 40 then return nil end
    local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
    if self.inv > 0 then return 'bounce', bvy, (pa.x >= self.x) and 1 or -1 end
    return (pa.gpPhase == 'fall') and 'pound' or 'stomp', bvy, self.props.points or 0
end

-- ── EL AIRE (systems/Push): soplando, de lado por toda la zona; aspirando, hacia su boca ─────────────────────────
-- ¿Hay algo sólido entre (x, y) y de donde viene el aire (dirección ux, uy), cerca? (chimenea, cornisa, caja)
function TF:sheltered(x, y, ux, uy)
    local level = self.levelRef
    if not level then return false end
    for d = T * 0.5, SHELTER, T / 2 do
        local px, py = x + ux * d, y + uy * d
        if level:collisionAt(px, py, false) then return true end
        for _, e in ipairs(level.liveEntities or {}) do
            if e.pushBy and e.alive and e ~= self then
                local b = e:getOuterBounds()
                if px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h then return true end
            end
        end
    end
    return false
end

-- El viento del soplo (dirección) en este instante: con el giro de la fase 2
function TF:windNow()
    local t = self.deadTimer or 0
    local d = self.windDir or -1
    if self.swapped and t >= SWAP_AT then d = -d end
    return d
end

function TF:pushAt(x, y, o)
    local st = self.state
    if st ~= 'blow' and st ~= 'inhale' then return nil end
    local zx0, zx1, zy0, zy1 = self:zb()
    if x < zx0 or x > zx1 or y < zy0 - T or y > zy1 + T then return nil end
    local t = self.deadTimer or 0
    local isPlayer = o ~= nil and o.def == nil                 -- (las entidades llevan su def; el jugador no)
    if st == 'blow' then
        local k = math.min(1, t / FADE, (BLOW_T - t) / FADE)
        if self.swapped then                                   -- (al cambiar de lado, un respiro)
            k = math.min(k, math.abs(t - SWAP_AT) / 0.2)
        end
        if k <= 0 then return nil end
        local d = self:windNow()
        if self:sheltered(x, y, -d, 0) then return nil end
        return d * POWER[self:ph()] * k, 0
    end
    if t < OPEN_T then return nil end
    local mx, my = self:mouthPos()
    local dx, dy = mx - x, my - y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return nil end
    local ux, uy = dx / dist, dy / dist
    local k = math.min(1, (t - OPEN_T) / FADE, (INHALE_T - t) / FADE)
    if k <= 0 or self:sheltered(x, y, ux, uy) then return nil end
    if isPlayer then
        -- a ti solo te arrastra hacia debajo de él (no te levanta: lo que te escupe es saltarle a la boca)
        if math.abs(dx) < 12 then return nil end
        return sgn(dx) * SUCK_P * k, 0
    end
    if dist > SUCK_R then return nil end
    -- a lo demás lo lleva a la boca y lo levanta (brusco: contra la gravedad de una bomba)
    return ux * SUCK_E * k, uy * SUCK_E * k, 8
end

-- Para los bots (src/ai/Bot.lua): por dónde sopla
function TF:windArea()
    if self.state ~= 'blow' and self.state ~= 'warn' then return nil end
    local zx0, zx1, zy0, zy1 = self:zb()
    return { x0 = zx0, y0 = zy0, x1 = zx1, y1 = zy1 }
end

-- ── Lo que llega a la boca aspirando ─────────────────────────────────────────
function TF:mouthCatch(level)
    local mx, my = self:mouthPos()
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and e.state ~= 'carried' and e.state ~= 'reserve' and not (e.def and e.def.boss) then
            local dx, dy = e.x - mx, e.y - my
            if dx * dx + dy * dy < EAT_R * EAT_R then
                if e.onEaten and e.canBeEaten and e:canBeEaten() and e.state == 'lit' then
                    self.inside = e
                    e:onEaten(self)
                    self:enter('bomb')
                    Sound.play('tifonGulp')
                    return true
                end
                local P = require 'src/world/systems/Push'
                if P.canPush(e) then
                    -- lo TOSE hacia el jugador más cercano
                    local pa = self:nearestPlayer(level)
                    local dir = pa and sgn(pa.x - e.x) or (self.facing or -1)
                    if e.throw then e:throw(dir * COUGH_V[1], COUGH_V[2], false)
                    else e.vx, e.vy, e.onGround = dir * COUGH_V[1], COUGH_V[2], false end
                    e.x = mx + dir * EAT_R
                    self:enter('cough')
                    Sound.play('tifonCough')
                    return true
                end
            end
        end
    end
    for _, pa in ipairs(level.players or {}) do
        local dx, dy = pa.x - mx, pa.y - my
        if not pa.dying and pa.alive ~= false and dx * dx + dy * dy < SPIT_R * SPIT_R then
            Boss.strike(pa, HIT_SPIT, (dx >= 0) and 1 or -1, require('src/player/DamageSource').of(self, 'projectile'))
            self:enter('cough')
            Sound.play('tifonCough')
            return true
        end
    end
end

-- ── Rayos ─────────────────────────────────────────────────────────────────────
function TF:nid() self.nextId = self.nextId % 999 + 1; return self.nextId end

function TF:placeMarks(level)
    local zx0, zx1 = self:zb()
    self.marks, self.arcs = {}, {}
    local want = MARKS[self:ph()]
    local xs = {}
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and #xs < want then xs[#xs + 1] = pa.x end
    end
    local tries = 0
    while #xs < want and tries < 60 do
        tries = tries + 1
        local x = rand(zx0 + T, zx1 - T)
        local ok = true
        for _, o in ipairs(xs) do if math.abs(o - x) < 2.2 * T then ok = false end end
        if ok then xs[#xs + 1] = x end
    end
    for _, x in ipairs(xs) do
        local y = self:roofBelow(level, x, self.y + TAIL_Y)
        if y then self.marks[#self.marks + 1] = { x = math.floor(x), y = y } end
    end
    -- fase 2: arcos a ras del tejado entre marcas vecinas del mismo tejado
    if self:ph() >= 2 then
        table.sort(self.marks, function(a, b) return a.x < b.x end)
        for i = 1, #self.marks - 1, 2 do
            local a, b = self.marks[i], self.marks[i + 1]
            if a.y == b.y and b.x - a.x <= ARC_MAX then self.arcs[#self.arcs + 1] = { i, i + 1 } end
        end
    end
end

function TF:strikeHits(level)
    local _, _, zy0 = self:zb()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local b = pa:getOuterBounds()
            local hit, dir = false, 1
            for _, m in ipairs(self.marks) do
                if b.x + b.w > m.x - BOLT_W and b.x < m.x + BOLT_W and b.y < m.y and b.y + b.h > zy0 then
                    hit, dir = true, sgn(pa.x - m.x)
                end
            end
            for _, a in ipairs(self.arcs) do
                local p, q = self.marks[a[1]], self.marks[a[2]]
                if p and q and b.x + b.w > p.x and b.x < q.x and b.y + b.h > p.y - ARC_H and b.y < p.y then
                    hit, dir = true, sgn(pa.x - (p.x + q.x) / 2)
                end
            end
            if hit then Boss.strike(pa, HIT_BOLT, dir, require('src/player/DamageSource').of(self, 'beam')) end
        end
    end
end

-- ── Granizo ───────────────────────────────────────────────────────────────────
function TF:dropHail(level)
    local zx0, zx1, zy0 = self:zb()
    local pa = self:nearestPlayer(level)
    local x
    for _ = 1, 6 do
        x = (pa and math.random() < 0.45) and (pa.x + rand(-2.5, 2.5) * T) or rand(zx0 + 0.5 * T, zx1 - 0.5 * T)
        x = math.max(zx0 + HAIL_R, math.min(zx1 - HAIL_R, x))
        local ok = true
        for _, h in ipairs(self.hail) do if not h.broke and math.abs(h.x - x) < 0.8 * T and h.y < zy0 + 2 * T then ok = false end end
        if ok then break end
    end
    self.hail[#self.hail + 1] = { id = self:nid(), x = math.floor(x), y = zy0 + 8, t = 0, broke = false }
end

function TF:updateHail(level, dt)
    for i = #self.hail, 1, -1 do
        local h = self.hail[i]
        h.t = h.t + dt
        if h.broke then
            if h.t >= 0.25 then table.remove(self.hail, i) end
        else
            h.y = h.y + HAIL_V * dt
            local stop = level:collisionAt(h.x, h.y + HAIL_R, true) ~= nil
            if not stop then
                for _, e in ipairs(level.liveEntities or {}) do
                    if e.pushBy and e.alive then
                        local b = e:getOuterBounds()
                        if h.x > b.x and h.x < b.x + b.w and h.y + HAIL_R > b.y and h.y < b.y + b.h then stop = true end
                    end
                end
            end
            for _, pa in ipairs(level.players or {}) do
                local b = pa:getOuterBounds()
                if not stop and not pa.dying and pa.alive ~= false and h.x + HAIL_R > b.x and h.x - HAIL_R < b.x + b.w
                   and h.y + HAIL_R > b.y and h.y - HAIL_R < b.y + b.h then
                    Boss.strike(pa, HIT_HAIL, sgn(pa.x - h.x), require('src/player/DamageSource').of(self, 'ice'))
                    stop = true
                end
            end
            local _, _, _, zy1 = self:zb()
            if stop or h.y > zy1 + 2 * T then
                h.broke, h.t = true, 0
                Sound.play('tifonHail', rand(0.9, 1.15), 0.7)
            end
        end
    end
end

-- ── Golpes y derrota ──────────────────────────────────────────────────────────
function TF:onDamaged(n, kind)
    if self:isDying() then return end
    if self:ph() < 2 and self.hp / self.hpMax <= (self.props.angerAt or 0.5) then
        self.phase = 2
        Entity.emitFx('shake_small', self.x, self.y)
    end
end

function TF:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.marks, self.arcs, self.hail = {}, {}, {}
    self:enter('dying_out')
    Sound.play('megaHurt', 0.7, 0.9)
    Sound.play('tifonDizzy', 0.8)
    self:onDefeat()
end

-- ── Moverse por lo alto ───────────────────────────────────────────────────────
function TF:cruise(level, dt, target)
    local zx0, zx1, zy0, zy1 = self:zb()
    local roof = self.cruiseRoof or zy1
    local pa = target or self:nearestPlayer(level)
    local tx = self.x
    if pa then
        local side = sgn(self.x - pa.x)
        tx = pa.x + side * KEEP
        if tx < zx0 + 2.5 * T or tx > zx1 - 2.5 * T then tx = pa.x - side * KEEP end
        self.facing = sgn(pa.x - self.x)
    end
    tx = math.max(zx0 + 2.5 * T, math.min(zx1 - 2.5 * T, tx))
    local v = DRIFT_V[self:ph()]
    local dx = tx - self.x
    self.x = self.x + math.max(-v * dt, math.min(v * dt, dx))
    local ty = math.max(zy0 + 2.2 * T, roof - CRUISE) + math.sin((self.fightT or 0) * 1.7) * 10
    self.y = self.y + (ty - self.y) * math.min(1, 3 * dt)
end

-- La siguiente: aspira cada dos ataques como mucho (la ventana no puede tardar); en fase 2 hay granizo
function TF:nextAttack(level)
    self.attackN = self.attackN + 1
    if self.attackN % 2 == 0 then return 'inhale' end
    local pool = (self:ph() >= 2) and { 'blow', 'charge', 'hail', 'blow' } or { 'blow', 'charge', 'blow' }
    return pool[math.random(#pool)]
end

-- ── Update ────────────────────────────────────────────────────────────────────
function TF:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    local st, t, ph = self.state, self.deadTimer, self:ph()
    local zx0, zx1, zy0, zy1 = self:zb()
    self.zx0, self.zx1, self.zy0, self.zy1 = zx0, zx1, zy0, zy1
    self.cruiseRoof = self.cruiseRoof or zy1
    self:updateHail(level, dt)
    if st == 'fight' then self:enter('idle'); return end

    if st == 'idle' then
        self:cruise(level, dt)
        self.idleT = self.idleT - dt
        if ph >= 2 and not self.roared then
            self.roared = true
            self:enter('roar')
            Sound.play('tifonRoar')
            Sound.play('tifonSpin', 0.9)
            Entity.emitFx('shake_big', self.x, self.y)
            return
        end
        if self.idleT <= 0 and self:mayAttack(level) then
            local a = self:nextAttack(level)
            local pa = self:nearestPlayer(level)
            if pa then self.facing = sgn(pa.x - self.x) end
            if a == 'blow' then
                self.windDir = self.facing
                self.swapped = ph >= 2 and math.random() < 0.6
                self:enter('warn')
                Sound.play('tifonWarn')
                Sound.play('tifonVane', 1, 0.6)
            elseif a == 'inhale' then
                self:enter('inhale')
                Sound.play('tifonInhale')
            elseif a == 'charge' then
                self:placeMarks(level)
                self:enter('charge')
                Sound.play('tifonCharge')
            else
                self.hailT = 0
                self:enter('hail')
                Sound.play('tifonRoar', 1.25, 0.5)
            end
        end
    elseif st == 'roar' then
        if t >= ROAR_T then self.idleT = 0.6; self:enter('idle') end
    elseif st == 'warn' then
        self:cruise(level, dt * 0.3)
        self.facing = self.windDir
        if t >= WARN_T then
            self:enter('blow')
            Sound.play('tifonBlow')
            Entity.emitFx('shake_small', self.x, self.y)
        end
    elseif st == 'blow' then
        if self.swapped and t >= SWAP_AT - SWAP_WARN and not self.swapWarned then
            self.swapWarned = true
            Sound.play('tifonVane')
            Sound.play('tifonSpin', 1.1, 0.7)
        end
        self.facing = self:windNow()
        if t >= BLOW_T then
            self.swapWarned = false
            self.idleT = IDLE_T[ph]
            self:enter('idle')
        end
    elseif st == 'inhale' then
        self:cruise(level, dt * 0.2)
        if t >= OPEN_T and self:mouthCatch(level) then return end
        if t >= INHALE_T then self.idleT = IDLE_T[ph]; self:enter('idle') end
    elseif st == 'cough' then
        if t >= COUGH_T then self.idleT = IDLE_T[ph] * 0.6; self:enter('idle') end
    elseif st == 'bomb' then
        local b = self.inside
        if not b or not b.alive or b.state ~= 'eaten' or t >= BOMB_T then
            self.inside = nil
            self:enter('boom')
            Sound.play('tifonBoom')
            Entity.emitFx('shake_big', self.x, self.y)
            local mx, my = self:mouthPos()
            Entity.emitFx('boss_blast', mx, my)
        end
    elseif st == 'boom' then
        if t >= BOOM_T then
            -- cae al tejado: donde haya tejado debajo, buscando el más cercano si está sobre un hueco
            local land, lx
            for d = 0, 6 * T, T / 2 do
                for _, s in ipairs({ 1, -1 }) do
                    local x = self.x + s * d
                    if not land and x > zx0 + STUN_W and x < zx1 - STUN_W then
                        local y = self:roofBelow(level, x, self.y)
                        if y then land, lx = y, x end
                    end
                end
                if land then break end
            end
            self.fromX, self.fromY = self.x, self.y
            self.toX, self.toY = lx or self.x, (land or zy1) - STUN_BOT + MS
            self:enter('fall')
            Sound.play('tifonDizzy')
        end
    elseif st == 'fall' then
        local u = math.min(1, t / FALL_T)
        self.x = self.fromX + (self.toX - self.fromX) * u
        self.y = self.fromY + (self.toY - self.fromY) * u * u
        if u >= 1 then
            self.stunLen = STUN_T[level.difficulty or ''] or STUN_T.normal
            self:enter('stun')
            Sound.play('boxLand', 0.5, 1)
            Entity.emitFx('shake_small', self.x, self.y + STUN_BOT)
        end
    elseif st == 'stun' then
        if t >= self:downTime(self.stunLen or STUN_T.normal) then
            self.fromY = self.y
            self:enter('rise')
            Sound.play('tifonSpin', 0.9, 0.8)
        end
    elseif st == 'rise' then
        local ty = math.max(zy0 + 2.2 * T, (self.cruiseRoof or zy1) - CRUISE)
        local u = math.min(1, t / RISE_T)
        self.y = self.fromY + (ty - self.fromY) * (1 - (1 - u) * (1 - u))
        if u >= 1 then self.idleT = IDLE_T[ph]; self:enter('idle') end
    elseif st == 'charge' then
        self:cruise(level, dt * 0.4)
        if t >= CHARGE_T[ph] then
            self:enter('strike')
            Sound.play('tifonThunder')
            if #self.arcs > 0 then Sound.play('tifonChain') end
            Entity.emitFx('shake_small', self.x, self.y)
            self:strikeHits(level)
        end
    elseif st == 'strike' then
        self:strikeHits(level)
        if t >= STRIKE_T then
            self.marks, self.arcs = {}, {}
            self.idleT = IDLE_T[ph]
            self:enter('idle')
        end
    elseif st == 'hail' then
        self:cruise(level, dt * 0.5)
        self.hailT = (self.hailT or 0) + dt
        while self.hailT >= HAIL_EVERY and t < HAIL_T - 0.6 do
            self.hailT = self.hailT - HAIL_EVERY
            self:dropHail(level)
        end
        if t >= HAIL_T then self.idleT = IDLE_T[ph]; self:enter('idle') end
    elseif st == 'dying_out' then
        if t >= OUT_D then
            self.fromY = self.y
            self:enter('dying_flee')
            Sound.play('tifonSpin', 0.8)
            Sound.play('tifonRoar', 0.8, 0.7)
        end
    elseif st == 'dying_flee' then
        self.y = self.fromY - (t * t) * 520
        if t >= FLEE_T then self.state, self.alive = 'dead', false end
    end
end

-- ── Entrada: la tormenta se forma arriba y baja girando; ruge ────────────────
local ROAR_AT = 1.7
function TF:introFocus()
    local zx0, zx1, zy0, zy1 = self:zb()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function TF:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
    local zx0, zx1, zy0, zy1 = self:zb()
    self.zx0, self.zx1, self.zy0, self.zy1 = zx0, zx1, zy0, zy1
    self.cruiseRoof = self:roofBelow(level, self.home.x, self.home.y) or zy1
    self.fromY = zy0 - 2 * T
end
function TF:updateIntro(dt, level, t)
    local ty = math.max((self.zy0 or self.home.y) + 2.2 * T, (self.cruiseRoof or self.home.y) - CRUISE)
    local u = math.min(1, t / 1.5)
    self.x = self.home.x
    self.y = (self.fromY or ty) + (ty - (self.fromY or ty)) * (1 - (1 - u) * (1 - u))
    if t >= 0.2 and self.introStep < 1 then self.introStep = 1; Sound.play('tifonSpin', 0.8, 0.9) end
    if t >= ROAR_AT and self.introStep < 2 then
        self.introStep = 2
        Sound.play('tifonRoar')
        Entity.emitFx('shake_big', self.x, self.y)
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function TF:netPackExtra()
    local out = { self:ph(), self.facing or -1, self.windDir or -1, self.swapped and 1 or 0,
                  math.floor(self.zx0 or 0), math.floor(self.zx1 or 0), math.floor(self.zy0 or 0), math.floor(self.zy1 or 0),
                  #self.marks }
    for _, m in ipairs(self.marks) do out[#out + 1] = m.x; out[#out + 1] = m.y end
    out[#out + 1] = #self.arcs
    for _, a in ipairs(self.arcs) do out[#out + 1] = a[1]; out[#out + 1] = a[2] end
    out[#out + 1] = #self.hail
    for _, h in ipairs(self.hail) do
        local n = #out
        out[n + 1], out[n + 2], out[n + 3], out[n + 4], out[n + 5] = h.id, h.x, math.floor(h.y), math.floor(h.t * 100), h.broke and 1 or 0
    end
    return out
end

function TF:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    self.phase, self.facing, self.windDir, self.swapped = b[1], b[2], b[3], b[4] == 1
    self.zx0, self.zx1, self.zy0, self.zy1 = b[5], b[6], b[7], b[8]
    local k = 9
    local ms = {}
    for _ = 1, b[k] or 0 do ms[#ms + 1] = { x = b[k + 1], y = b[k + 2] }; k = k + 2 end
    k = k + 1
    local as = {}
    for _ = 1, b[k] or 0 do as[#as + 1] = { b[k + 1], b[k + 2] }; k = k + 2 end
    k = k + 1
    local hs = {}
    for _ = 1, b[k] or 0 do
        hs[#hs + 1] = { id = b[k + 1], x = b[k + 2], y = b[k + 3], t = b[k + 4] / 100, broke = b[k + 5] == 1 }
        k = k + 5
    end
    self.marks, self.arcs, self.hail = ms, as, hs
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local vaneSet, fxSet
function TF.loadAssets()
    vaneSet = vaneSet or Anim.load('bosses/tifon_vane')
    fxSet = fxSet or Anim.load('bosses/tifon_fx')
end

-- El cuadro del cuerpo y de la veleta según el estado (lo dibujado sale de state + deadTimer)
function TF:pose(now)
    local st, t = self.state, self.deadTimer or 0
    local name, vane = 'idle', nil
    if st == 'warn' then name = 'warn'
    elseif st == 'blow' then
        name = 'blow'
        if self.swapped and t >= SWAP_AT - SWAP_WARN and t < SWAP_AT + 0.1 then name, vane = 'spin', 'edge' end
    elseif st == 'inhale' then name = (t < OPEN_T) and 'inhale' or 'inhale2'
    elseif st == 'bomb' then name = 'gulp'
    elseif st == 'boom' then name = 'boom'
    elseif st == 'cough' then name = 'cough'
    elseif st == 'charge' or st == 'strike' then name = 'charge'
    elseif st == 'roar' or st == 'rise' or st == 'dying_flee' then name, vane = 'spin', 'edge'
    elseif st == 'fall' or st == 'stun' or st == 'dying_out' then name, vane = 'stun', 'edge'
    elseif st == 'intro' or st == 'ready' then
        if st == 'intro' and t < 1.5 then name, vane = 'spin', 'edge' end
    end
    return name, vane
end

function TF:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' then return end
    self.loadAssets()
    local set = self:anims()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local alpha = self:ghostAlpha()
    if st == 'intro' then alpha = alpha * math.min(1, t / 0.8) end
    if st == 'dying_flee' then alpha = alpha * math.max(0, 1 - t / FLEE_T) end
    local name, vaneEdge = self:pose(now)
    local fr
    if name == 'inhale2' then fr = set:frameN('inhale', 2)
    elseif name == 'inhale' then fr = set:frameN('inhale', 1)
    elseif name == 'idle' or name == 'blow' or name == 'spin' or name == 'stun' then fr = set:frameAt(name, now)
    else fr = set:frameAt(name, 0) end
    local face = self.facing or -1
    local x, y = math.floor(self.x - camX + 0.5), math.floor(self.y - camY + 0.5)
    if st == 'warn' or (st == 'charge' and math.floor(t * 20) % 2 == 0) then x = x + ((math.floor(t * 30) % 2 == 0) and MS or -MS) end
    local r, g, b = 1, 1, 1
    if self:flashRed() then r, g, b = 1, 0.35, 0.35 end
    -- la veleta: detrás del cuerpo, con el pie clavado en la nube; apunta hacia donde sopla
    local vk = (name == 'stun') and 'stun' or name
    local foot = (VANE_FOOT[vk] or 12) + 1 - 22
    local vname = vaneEdge or ((((st == 'blow' or st == 'warn') and self:windNow() or face) < 0) and 'left' or 'right')
    if self:shardDrop() or self.props.wear == false then vname = vname .. '_empty' end
    love.graphics.setColor(r, g, b, alpha)
    vaneSet:drawFrame(vaneSet:frameN(vname, 1), x - face * VANE_DX, y + foot * MS, 0, MS, MS, 0.5, 1)
    set:drawFrame(fr, x, y, 0, -face * MS, MS, 0.5, 0.5)
    if name == 'stun' then BossFx.stars(x, y + STUN_TOP - 10 * MS, 8 * MS, 1.2 * MS, 5, alpha, 'back') end
    love.graphics.setColor(1, 1, 1, 1)
    Edge.over(self.renderWeather, self, camX, camY, alpha)      -- (rachas, marcas, rayos: sin borde — src/fx/Edge.lua —)
end

-- Rachas, marcas, rayos, arcos y granizo (todo de state + deadTimer + lo que llega en el netPack)
function TF:renderWeather(camX, camY, alpha)
    local st, t = self.state, self.deadTimer or 0
    local zx0, zx1, zy0, zy1 = self:zb()
    local S = 4
    -- las rachas: el aviso (discontinuas) y el viento (corren en su dirección); de la zona entera
    if st == 'warn' or st == 'blow' then
        local warn = st == 'warn' or (self.swapped and t >= SWAP_AT - SWAP_WARN and t < SWAP_AT)
        local d = (st == 'warn') and (self.windDir or -1) or self:windNow()
        if warn and st == 'blow' then d = -d end                       -- (avisa hacia dónde va a cambiar)
        local a = 1
        if st == 'blow' then a = math.min(1, t / FADE, (BLOW_T - t) / FADE) end
        local w = zx1 - zx0
        for n = 0, 13 do
            local u = (warn and (n * w / 14)) or ((t * POWER[self:ph()] * 1.6 + n * w / 14) % w)
            local px = (d > 0) and (zx0 + u) or (zx1 - u)
            local py = zy0 + T * 0.6 + ((n * 53) % 9) / 9 * (zy1 - zy0 - T * 1.2)
            love.graphics.setColor(1, 1, 1, alpha * a * (warn and (0.5 + 0.5 * math.abs(math.sin(t * 8 + n))) or 0.85))
            local fr = fxSet:frameN(warn and 'streak_warn' or 'streak', n + math.floor(t * 12))
            fxSet:drawFrame(fr, math.floor(px - camX), math.floor(py - camY), 0, d * S, S, 0.5, 0.5)
        end
    end
    -- las marcas del rayo (se encienden), los rayos y los arcos
    if st == 'charge' or st == 'strike' then
        local ch = CHARGE_T[self:ph()]
        love.graphics.setColor(1, 1, 1, alpha)
        for _, m in ipairs(self.marks or {}) do
            local k = (st == 'strike') and 3 or math.min(3, 1 + math.floor(t / ch * 3))
            if st == 'charge' and t > ch * 0.66 and math.floor(t * 16) % 2 == 1 then k = 2 end
            fxSet:drawFrame(fxSet:frameN('mark', k), math.floor(m.x - camX), math.floor(m.y - camY) - 2 * S, 0, S, S, 0.5, 0.5)
            if st == 'strike' then
                local fr = fxSet:frameN('bolt', 1 + math.floor(t * 30) % 2)
                local bh = 40 * S
                for yy = zy0, m.y - 8, bh do
                    fxSet:drawFrame(fr, math.floor(m.x - camX), math.floor(yy - camY), 0, S, S, 0.5, 0)
                end
                fxSet:drawFrame(fxSet:frameN('scorch', 1), math.floor(m.x - camX), math.floor(m.y - camY), 0, S, S, 0.5, 1)
            end
        end
        for _, a in ipairs(self.arcs or {}) do
            local p, q = self.marks[a[1]], self.marks[a[2]]
            if p and q then
                local seg = 32 * S
                for xx = p.x, q.x - 8, seg do
                    local w = math.min(seg, q.x - xx) / seg
                    if st == 'strike' then
                        love.graphics.setColor(1, 1, 1, alpha)
                        fxSet:drawFrame(fxSet:frameN('arc', 1 + math.floor(t * 30 + xx) % 2), math.floor(xx - camX), math.floor(p.y - camY - ARC_H / 2), 0, S * w, S, 0, 0.5)
                    else                                               -- (el aviso: chispitas a ras del tejado)
                        love.graphics.setColor(1, 1, 1, alpha * (0.4 + 0.4 * math.abs(math.sin(t * 10))))
                        fxSet:drawFrame(fxSet:frameN('mark', 1), math.floor(xx + seg / 2 - camX), math.floor(p.y - camY) - 2 * S, 0, S, S, 0.5, 0.5)
                    end
                end
            end
        end
    end
    -- el granizo
    love.graphics.setColor(1, 1, 1, alpha)
    for _, h in ipairs(self.hail or {}) do
        local fr = h.broke and fxSet:frameN('hail_break', 1 + math.min(1, math.floor(h.t / 0.12))) or fxSet:frameN('hail', 1 + math.floor(h.y / 40) % 2)
        fxSet:drawFrame(fr, math.floor(h.x - camX), math.floor(h.y - camY), 0, S, S, 0.5, 0.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function TF:debugBoxes()
    local out = {}
    for _, m in ipairs(self.marks or {}) do
        local _, _, zy0 = self:zb()
        out[#out + 1] = { x = m.x - BOLT_W, y = zy0, w = BOLT_W * 2, h = m.y - zy0, kind = 'hazard' }
    end
    for _, a in ipairs(self.arcs or {}) do
        local p, q = self.marks[a[1]], self.marks[a[2]]
        if p and q then out[#out + 1] = { x = p.x, y = p.y - ARC_H, w = q.x - p.x, h = ARC_H, kind = 'hazard' } end
    end
    for _, h in ipairs(self.hail or {}) do
        if not h.broke then out[#out + 1] = { x = h.x - HAIL_R, y = h.y - HAIL_R, w = HAIL_R * 2, h = HAIL_R * 2, kind = 'hazard' } end
    end
    if self.state == 'inhale' then
        local mx, my = self:mouthPos()
        out[#out + 1] = { x = mx - EAT_R, y = my - EAT_R, w = EAT_R * 2, h = EAT_R * 2, kind = 'area' }
    end
    if self.state == 'stun' then
        out[#out + 1] = { x = self.x - STUN_W, y = self.y + STUN_TOP - 30, w = STUN_W * 2, h = 70, kind = 'area' }
    end
    return out
end

local G = 'Tifón'
return {
    name = 'tifon', label = 'Tifón (Soplón Supremo)', category = 'Jefes',
    description = 'Jefe secreto de la fortaleza: una nube de tormenta. Sopla toda la zona (cúbrete tras una chimenea o una caja), '
               .. 'aspira hacia su boca, rayos y granizo. Lánzale una bomba encendida mientras aspira: se la traga, le revienta '
               .. 'dentro y cae al tejado aturdido.',
    class = TF,
    boss = { title = 'TIFÓN' },
    hide = Boss.HIDE,
    defaults = { points = 30 },
    props = Boss.props({ hp = 6, hpPerPlayer = 2 }, {
        Boss.WEAR_PROP,
        { key = 'angerAt', kind = 'number', label = 'Fase 2 con (fracción de vida)', group = G, default = 0.5,
          min = 0.2, max = 0.95, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/bosses/tifon/body-Sheet.png', frameW = FW },
}
