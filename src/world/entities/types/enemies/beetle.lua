-- El ESCARABAJO RINOCERONTE (types/enemies/beetle.lua): enemigo EXCLUSIVO de la jungla (isla futura; diseño aprobado
-- por el usuario el 2026-10-28, docs/entities/enemies.md § Escarabajo Rinoceronte). Su gigante es el jefe del templo
-- (types/bosses/giantbeetle.lua).
--   · Anda (patrulla) y gira en paredes y bordes. Si ve a un jugador DELANTE y a su altura, escarba (aviso, WIND_T) y
--     EMBISTE en línea recta, mucho más rápido; contra una pared se queda aturdido un momento; en un borde frena.
--   · Tocarlo de lado quita 1 de vida (el cuerno y el caparazón).
--   · PISARLO lo pone PATAS ARRIBA (BACK_T s, pataleando): no hace daño y se puede COGER y LANZAR (systems/Carry: como
--     la caja pequeña). Pisado otra vez o con un ground pound, muere; si no, se da la vuelta solo y sigue.
--   · LANZADO derriba a los enemigos con los que choca y rompe las cajas; cae otra vez patas arriba.
--   · Cae en LAVA, en PINCHOS o al VACÍO (andando, patas arriba o lanzado): REVIENTA (el usuario).
--   · Un ground pound cerca (el empujón) también lo pone patas arriba.
-- 0.5.78 (el usuario): embistiendo, lanzado, en las manos o patas arriba NO le frena su ruta (`freeOfRoute`: antes
-- chocaba con su límite como con una pared y lo lanzado volvía hacia ella); luego vuelve andando a su ruta. Al volcarse
-- te aparta de lado y no se le puede pisar en INV_FLIP s (lo matabas sin querer con el rebote). En las MANOS sigue
-- pataleando; antes de darse la vuelta TIEMBLA (aviso) y, si no lo sueltas, se suelta solo y te hace daño. Su caja es
-- la del CUERPO (sin el cuerno), centrada en él: el dibujo se corre 2 px.
-- 0.5.79 (el usuario): lanzarlo NO le reinicia la cuenta patas arriba (a punto de levantarse, se levanta al caer).
-- EMBISTIENDO el impacto empuja al jugador (invulnerable, lo atraviesa; 0.5.80) y arrolla lo que pilla delante — enemigos
-- (los noquea: knockback; a las bombas las patea y las enciende) y lo ligero que se coge (lo despide). Muerto, se queda
-- APLASTADO en el suelo. Con `wings` (los súbditos del jefe) es el ESCARABAJO VOLADOR: vuela con sus alas (vuelo
-- libre) sin embestir; pisado cae patas arriba como el de suelo y, si se levanta, vuelve a volar. 0.5.80: al acabar
-- la embestida sin chocar FRENA derrapando ('brake': polvo y sonido) en vez de pararse en seco.
-- Arte: assets/anim/enemies/beetle.json (hoja de 22x20 a escala 4, mira a la DERECHA; tools/art/enemies/
-- make_beetle.py — sus patas, retocadas a mano por el usuario). Todo lo que se dibuja sale del estado, deadTimer,
-- frame y facing (lo que viaja en las instantáneas): online se ve igual.
local Entity       = require 'src/world/entities/base/Entity'
local Interactions = require 'src/world/entities/base/Interactions'

local Beetle = Entity.extend(Entity, {
    walkFps = 8, walkFrames = 4,
    idleEvery = { 3.0, 6.0 }, idleFor = { 0.8, 1.6 },
    debugColor = { 0.55, 0.75, 0.3 },
    -- (el cuerpo mide ~16 de los 22 px del cuadro y ~12 de alto con las patas)
    -- (0.5.78: el cuerpo del dibujo, sin el cuerno ni el aire: 14 de 22 px de ancho, 11 de 20 de alto con las patas)
    hitbox = { outerW = 0.64, outerH = 0.55, innerW = 0.54, innerH = 0.42 },
})

local S         = GUMMY_SCALE
local FW, FH    = 22, 20
local SEE       = 6.5                  -- casillas: ve a un jugador delante hasta aquí
local WIND_T    = 0.45                 -- s escarbando antes de embestir
local CHARGE_V  = 380                  -- px/s embistiendo (anda a 50; el jugador, 240)
local CHARGE_MAX = 2.4                 -- s como mucho embistiendo
local DAZE_T    = 0.9                  -- s aturdido tras chocar con una pared
local COOLDOWN  = 1.2                  -- s sin volver a embestir
local BACK_T    = 3.0                  -- s patas arriba
local RIGHT_T   = 0.35                 -- s dándose la vuelta
local FLIP_HOP  = 300                  -- px/s: el saltito al volcarse
local THROWN_BOUNCE = 0.3
local INV_FLIP  = 0.4                  -- s tras volcarse en los que no se le puede pisar (te aparta de lado)
local WARN_T    = 0.9                  -- s antes de darse la vuelta en los que tiembla (el aviso)
local HIT_CARRY = 1                    -- vida que quita al soltarse de las manos
local BRAKE_T   = 0.4                  -- s frenando al acabar la embestida (derrapa: polvo y sonido)
local SWEEP_VX, SWEEP_VY = 420, -260    -- px/s: lo ligero que arrolla embistiendo sale despedido así
local BODY_DX   = 2                    -- px del cuadro: el cuerpo está 2 px a la izquierda del centro (el cuerno, delante)
local FREE = { windup = true, charge = true, brake = true, daze = true, onback = true, righting = true, thrown = true, carried = true }

Beetle.animId    = 'enemies/beetle'
Beetle.carryable = true                -- (patas arriba: canBeCarried)
Beetle.weight    = 1
Beetle.edible    = true                -- (la Planta carnívora se lo come: lanzado o andando a su alcance)
Beetle.wantsLevel = true
Beetle.ownStunLook = true
function Beetle.sizePx() return FW * S, FH * S end

local BACK = { onback = true, righting = true }

function Beetle:init()
    self.cd, self.invT = 0, 0
    -- (el volador: vuela de nuevo cada vez que vuelve a casa — resetToHome llama a init —)
    if self.props.wings then self.flying, self.freeFly = true, true end
    -- (sus reglas de contacto son fijas: no se cambian en el editor — `hide` —, así que se ponen aquí)
    self.props.stompable, self.props.onTouch = true, 'hurt'
end

-- ── Reglas ────────────────────────────────────────────────────────────────────
-- El volador en el aire (lo que se dibuja: sale del estado; derribado no vuelve a 'walk' hasta volar otra vez)
function Beetle:winged()
    local st = self.state
    return self.props.wings == true and (st == 'walk' or st == 'idle' or st == 'spawning')
end
function Beetle:onBack() return BACK[self.state] == true end
function Beetle:freeOfRoute() return FREE[self.state] == true end
function Beetle:canBeCarried() return self.alive and self:onBack() and self.onGround ~= false end
function Beetle:isObstacle() return self.alive and not self:onBack() and self.state ~= 'thrown' and Entity.isObstacle(self) end

-- Sin efectos (el cliente la usa para predecir). Patas arriba: solo cuenta caerle encima (lo mata); de lado no hace
-- nada (se coge). Normal: encima = pisotón (lo vuelca) o ground pound (lo mata); de lado, 1 de vida.
function Beetle:interact(pa)
    local st = self.state
    if st == 'thrown' then return nil end
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    local side = (pa.x >= self.x) and 1 or -1
    if r == 'stomp' then
        if (self.invT or 0) > 0 then return 'bounce', a, side end      -- (recién volcado: rebota de lado, sin matarlo)
        if pa.gpPhase == 'fall' then return 'pound', a, b end
        return r, a, b, side                                           -- (el pisotón te aparta de lado)
    end
    if self:onBack() then return nil end
    return r, a, b, c
end

-- Pisotón: de pie → patas arriba; patas arriba → muere
function Beetle:stomp()
    if self:onBack() or self.state == 'frozen' then return Entity.stomp(self) end
    if self.state == 'dead' then return end
    self:flipOver(0)
end
function Beetle:pound(pa) Entity.stomp(self) end

-- El empujón de un ground pound cercano: lo vuelca hacia ese lado
function Beetle:canBeKnocked() return self.alive and not self:onBack() and self.state ~= 'thrown' and Entity.canBeKnocked(self) end
function Beetle:knockback(dirX) self:flipOver(dirX * 220) end

function Beetle:flipOver(vx)
    self.flying = false                                               -- (el volador cae: sin alas hasta levantarse)
    self.state, self.deadTimer, self.invT = 'onback', 0, INV_FLIP
    self.vx, self.vy, self.onGround = vx or 0, -FLIP_HOP, false
    Sound.play('stunned')
    Entity.emitFx('gp_start', self.x, self.y + self.outerH / 2)
end

-- (su cuenta patas arriba — deadTimer — sigue: lanzado no vuelve a empezar; el usuario)
function Beetle:onThrow(pa, vx, vy)
    self.state, self.airT = 'thrown', 0
    self.vx, self.vy, self.onGround = vx, vy, false
end

-- ── Qué ve: un jugador DELANTE, a su altura, sin pared en medio ──────────────
function Beetle:sees(level)
    local f = self.facing or 1
    local feet = self.y + self.outerH / 2
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local pb = pa:getOuterBounds()
            local dx = (pa.x - self.x) * f
            if dx > 8 and dx < SEE * TILE_PX and math.abs(pb.y + pb.h - feet) < TILE_PX * 0.9 then
                local clear, y = true, self.y
                for x = self.x, pa.x, f * 16 do
                    if level:collisionAt(x, y, true) then clear = false; break end
                end
                if clear then return pa end
            end
        end
    end
    return nil
end

-- ── Lanzado: derriba enemigos y rompe cajas ───────────────────────────────────
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end
function Beetle:thrownHits(level)
    local ob = self:getOuterBounds()
    local b = { x = ob.x - 6, y = ob.y, w = ob.w + 12, h = ob.h }     -- (una caja lo para antes de tocarla: un poco más)
    local dir = (self.vx >= 0) and 1 or -1
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and e.state ~= 'dead' and e.state ~= 'carried' and not (e.isGhost and e:isGhost()) then
            local cat = e.def and e.def.category
            if overlap(b, e:getOuterBounds()) then
                if cat == 'Enemigos' and e.dieFling and not Entity.SPECIAL_DEATH[e.state] then
                    e:dieFling(dir)
                    Sound.play('crabPop')
                    self.vx = -self.vx * THROWN_BOUNCE
                    return
                elseif e.breakApart and e.state == 'rest' then
                    e:breakApart()
                    self.vx = -self.vx * THROWN_BOUNCE
                    return
                end
            end
        end
    end
end

-- ── Embistiendo: empuja a los jugadores y arrolla lo que pilla delante ────────
-- Solo EL IMPACTO (0.5.80, el usuario: "así queda más cómodo y legible"): un jugador que se puede golpear pierde 1, sale
-- apartado de su caja hacia donde embiste y rebota (recoil); invulnerable — también justo después del golpe — lo
-- ATRAVIESA. Si al apartarlo no cabe (contra una pared), el escarabajo se para ahí: true = chocó (aturdido, como en
-- una pared). Enemigos: knockback, una vez por embestida (luego los atraviesa); lo ligero que se coge: despedido.
function Beetle:chargeHits(level, f, dt)
    local ob = self:getOuterBounds()
    local pinned = false
    local feetTop = ob.y + ob.h * 0.35
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not self.swept[pa] and not pa:isInvulnerable() then
            local pb = pa:getOuterBounds()
            if overlap(ob, pb) and pb.y + pb.h > feetTop and (pa.x - self.x) * f > -ob.w * 0.25 then
                -- (arrollado: quita 1 aquí — el empujón lo saca de su caja antes de Interactions —)
                self.swept[pa] = true
                if not pa.peaceful and pa:hurt(1) then return false end
                local edge = (f > 0) and (ob.x + ob.w - pb.x) or (pb.x + pb.w - ob.x)
                if edge > 0 and pa.moveSteps then
                    local px0 = pa.x
                    pa:moveSteps(level, f * edge, 0)
                    local left = edge - math.abs(pa.x - px0)
                    if left > 1 then self.x, pinned = self.x - f * left, true end      -- (aplastado contra la pared)
                end
                -- (rebote casi plano: con el salto de recoil caía encima y lo pisaba sin querer)
                if pa.recoil and pa:recoil(f) then pa.vy = math.max(pa.vy, -120) end
            end
        end
    end
    local b = { x = (f > 0) and ob.x + ob.w * 0.5 or ob.x - 8, y = ob.y, w = ob.w * 0.5 + 8, h = ob.h }
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and not self.swept[e] and e.state ~= 'dead' and e.state ~= 'carried'
           and not (e.isGhost and e:isGhost()) and not (e.def and e.def.boss) and overlap(b, e:getOuterBounds()) then
            if e.canBeKnocked and e:canBeKnocked() then
                self.swept[e] = true
                e:knockback(f)
                Sound.play('crabPop', 1.1, 0.7)
            elseif e.carryable and e.canBeCarried and e:canBeCarried() and e.onThrow then
                self.swept[e] = true
                e:onThrow(nil, f * SWEEP_VX, SWEEP_VY)
                Sound.play('boxLand', 1.2, 0.8)
            end
        end
    end
    return pinned
end

-- Acaba la embestida sin chocar: FRENA derrapando (0.5.80, el usuario: se paraba de golpe) con `vx` de partida
function Beetle:brake(vx)
    self.state, self.deadTimer, self.vx = 'brake', 0, vx
    Sound.play('boxPush', 0.9, 0.8)
    Entity.emitFx('gp_land', self.x + (self.facing or 1) * self.outerW * 0.3, self.y + self.outerH / 2)
end

-- ── Update ────────────────────────────────────────────────────────────────────
local function fallBurst(self, level)
    if self:onDeadlyGround(level) or self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
    return false
end

-- En las manos de un jugador (Entity:update → whileCarried): sigue pataleando y contando; al acabarse su tiempo
-- patas arriba se suelta solo — al lado — y le hace daño a quien lo lleva
function Beetle:whileCarried(dt, level)
    self.deadTimer = self.deadTimer + dt
    if self.invT > 0 then self.invT = math.max(0, self.invT - dt) end
    if self.deadTimer < BACK_T then return end
    local pa = self.carriedBy
    require('src/world/systems/Carry').putDown(pa, self, level)
    self.state, self.deadTimer = 'righting', 0
    self.vy, self.onGround = -FLIP_HOP * 0.5, false
    if pa and not pa.dying then
        local dir = (pa.x >= self.x) and 1 or -1
        pa:hurt(HIT_CARRY)
        if pa.recoil then pa:recoil(dir) end
    end
    Sound.play('crabPop', 0.8, 0.9)
end

function Beetle:updateCustom(dt, level)
    local st = self.state
    if self.cd > 0 then self.cd = math.max(0, self.cd - dt) end
    if self.invT > 0 then self.invT = math.max(0, self.invT - dt) end

    if st == 'walk' or st == 'idle' then
        if self.flying then return false end                           -- (el volador patrulla el cielo: no embiste)
        if self.onGround and self.cd <= 0 and self.props.movement ~= 'static' then
            local pa = self:sees(level)
            if pa then
                self.state, self.deadTimer, self.vx = 'windup', 0, 0
                Sound.play('hopWind', 1.3, 0.8)
                Entity.emitFx('gp_land', self.x - (self.facing or 1) * self.outerW / 2, self.y + self.outerH / 2)
                return true
            end
        end
        if self:fellOut(level) or self:inVoid(level) then self:dieBurst(); return true end
        return false                                                   -- (andar: lo normal de Entity)
    end

    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer

    if st == 'windup' then
        self.vx = 0
        self:fall(level, dt)
        if t >= WIND_T then
            self.state, self.deadTimer, self.swept = 'charge', 0, {}
            self.vx = (self.facing or 1) * CHARGE_V
            Sound.play('crabPop', 0.6, 0.7)
        end
        return true

    elseif st == 'charge' then
        local f = self.facing or 1
        if self.onGround and not self:groundAhead(level, f) then           -- (en un borde frena: no se tira)
            self:brake(0)                                                  -- (en un borde: frena en seco, sin derrapar)
            return true
        end
        local x0 = self.x
        self.vx = f * CHARGE_V
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        local pinned = self:chargeHits(level, f, dt)
        if pinned or math.abs(self.x - x0) < CHARGE_V * dt * 0.5 then                -- (contra una pared: aturdido)
            self.state, self.deadTimer, self.vx, self.cd = 'daze', 0, 0, COOLDOWN
            Sound.play('blockBreak', 0.8, 0.6)
            Entity.emitFx('shake_small', self.x, self.y)
            return true
        end
        if t >= CHARGE_MAX then self:brake(self.vx) end
        return fallBurst(self, level) or true

    elseif st == 'brake' then
        -- (derrapa hasta pararse: no se tira por un borde; polvo que levanta cada 0,1 s)
        local f = self.facing or 1
        self.vx = self.vx * math.max(0, 1 - 9 * dt)
        if self.onGround and not self:groundAhead(level, f) then self.vx = 0 end
        local vx0 = self.vx
        self:fall(level, dt, self.vx)
        self.facing = f
        if self.vx ~= vx0 then self.vx = 0 end
        if self.vx ~= 0 and math.floor(t * 10) ~= math.floor((t - dt) * 10) then
            Entity.emitFx('gp_land', self.x + f * self.outerW * 0.3, self.y + self.outerH / 2)
        end
        if t >= BRAKE_T then
            self.vx, self.cd = f * (self.speed or 50), COOLDOWN
            self:startWalk()
        end
        return fallBurst(self, level) or true

    elseif st == 'daze' then
        self.vx = 0
        self:fall(level, dt)
        if t >= DAZE_T then
            self.facing = -(self.facing or 1)
            self.vx = self.facing * (self.speed or 50)
            self:startWalk()
        end
        return fallBurst(self, level) or true

    elseif st == 'onback' or st == 'righting' then
        if self.onGround then self.vx = self.vx * math.max(0, 1 - 8 * dt) end
        local vx0 = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local f = self.facing
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        if self.vx ~= vx0 then self.vx = 0 end
        if fallBurst(self, level) then return true end
        if st == 'onback' and t >= BACK_T and self.onGround then
            self.state, self.deadTimer = 'righting', 0
        elseif st == 'righting' and t >= RIGHT_T then
            self.vy, self.onGround = -FLIP_HOP * 0.6, false
            self.vx = self.facing * (self.speed or 50)
            self.cd = COOLDOWN
            if self.props.wings then                                   -- (el volador: abre las alas y vuelve a volar)
                self.flying, self.vy, self.baseY = true, 0, self.y
                self.ffx, self.ffy, self.ffBlock = nil, nil, nil
                Sound.play('gustBlow', 1.6, 0.5)
            end
            self:startWalk()
        end
        return true

    elseif st == 'thrown' then
        local vx0 = self.vx
        self.vy = self.vy + ADV_GRAVITY * dt
        local f = self.facing
        self:moveAndCollide(level, self.vx * dt, self.vy * dt)
        self.facing = f
        if self.vx ~= vx0 then self.vx = -vx0 * THROWN_BOUNCE end
        if fallBurst(self, level) then return true end
        self:thrownHits(level)
        self.airT = (self.airT or 0) + dt
        if self.onGround and self.airT > 0.08 then
            self.state = 'onback'                                      -- (con la cuenta que llevaba)
            Sound.play('boxLand')
        end
        return true
    end
    return false
end

-- ── Red: todo sale de state / deadTimer / frame / facing (nada propio) ───────

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Beetle:pose()
    local st, t = self.state, self.deadTimer or 0
    local set = self:anims()
    if self:winged() then
        return set:frameN('fly', self.frame or 1), 0, 0                    -- (el volador: las alas, con el paso de andar)
    end
    if st == 'walk' then return set:frameN('walk', self.frame or 1), 0, 0 end
    if st == 'windup' then
        local ox = (math.floor(t * 30) % 2 == 0) and 1 or -1                -- (escarba: tiembla)
        return set:frameAt('charge', 0), ox, 0
    end
    if st == 'charge' then return set:frameAt('charge', t), 0, 0 end
    if st == 'brake' then                                                  -- (derrapa: echado atrás, temblando)
        return set:frameAt('charge', 0), (math.floor(t * 24) % 2 == 0) and 0 or -(self.facing or 1), 0
    end
    if st == 'daze' then return set:frameAt('idle', 0), (math.floor(t * 16) % 2 == 0) and 1 or 0, 0 end
    if st == 'onback' or st == 'carried' then                              -- (a punto de darse la vuelta: tiembla)
        local warn = t >= BACK_T - WARN_T
        return set:frameAt('flip', warn and t * 3 or t), warn and ((math.floor(t * 30) % 2 == 0) and 1 or -1) or 0, 0
    end
    if st == 'thrown' then return set:frameAt('flip', t), 0, 0 end
    if st == 'righting' then return set:frameAt('flip', t * 3), 0, -math.floor(math.sin(t / RIGHT_T * math.pi) * 2) end
    if st == 'dead' then return set:frameAt('dead', t), 0, 0 end
    if st == 'dead_fling' then return set:frameAt('flip', t * 2), 0, 0 end
    return set:frameAt('idle', 0), 0, 0
end

function Beetle:render(camX, camY)
    local fr, ox, oy = self:pose()
    local f = self.facing or 1
    local x = math.floor(self.x - camX) + ox * S + BODY_DX * S * f       -- (el cuerpo, no el cuadro, sobre su x)
    -- (cada cuadro con su último píxel en el suelo — Anim footGap —; lanzado o en las manos, tal cual)
    local air = self.state == 'thrown' or self.state == 'carried' or self.state == 'dead_fling' or not self.onGround
                or self:winged()
    -- (+1: las patas de delante son 1 px más largas: las de detrás tocan el suelo, las de delante lo atraviesan 1 px)
    local gap = air and 1 or (self:anims():footGap(fr) + 1)
    local feet = math.floor(self.y + self.outerH / 2 - camY) + gap * S + oy * S
    local bx, by = 1, 1
    if self.state == 'idle' then bx, by = self:breatheScale() end
    local a = 1
    if self.state == 'dead' then a = math.max(0, 1 - (self.deadTimer or 0) / self.tuning.deadDuration) end
    love.graphics.setColor(1, 1, 1, a)
    local r = (self.state == 'dead_fling') and (self.deadTimer or 0) * 10 * f or 0
    self:anims():drawFrame(fr, x, feet, r, S * f * bx, S * by, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'beetle', label = 'Escarabajo Rinoceronte', category = 'Enemigos',
    description = 'De la jungla. Anda; si te ve delante, escarba y EMBISTE. Pisarlo lo pone patas arriba: inofensivo, se '
               .. 'coge y se lanza (derriba enemigos, rompe cajas). Pisado otra vez o con ground pound, muere. Revienta en '
               .. 'lava, pinchos y al vacío.',
    class = Beetle,
    defaults = { speed = 50, points = 20, onTouch = 'hurt' },
    hide = { 'movement', 'attach', 'dropOnSight', 'detectRange', 'flyMode', 'flyRange', 'bobAmp', 'stompable', 'onTouch' },
    props = {
        { key = 'wings', kind = 'bool', label = 'Con alas (vuela, no embiste)', group = 'Escarabajo', default = false,
          help = 'El escarabajo VOLADOR (los súbditos del jefe): vuela por la zona; pisado cae y, al levantarse, vuelve a volar' },
    },
    editor = { sprite = 'assets/images/enemies/beetle/beetle-Sheet.png', frameW = FW },
}
