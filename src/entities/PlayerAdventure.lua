-- src/entities/PlayerAdventure.lua
local Class = require 'libs/class'
local Tiles = require 'src/world/Tiles'
local PlayerAdventure = Class:new()

local sprites    = nil
local spriteDead = nil
local spriteCrouch = nil
local function loadSprites()
    if sprites then return end
    sprites = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
    spriteDead  = love.graphics.newImage('assets/images/player/monstrito4.png')
    spriteCrouch = love.graphics.newImage('assets/images/player/monstrito5.png')
end

local WALK_FPS   = 8
local FALL_FPS   = 6
local PUFF_SCALE = 1.15
local PUFF_SPD   = 14

local DEATH_FREEZE_TIME = 0.05
local DEATH_JUMP_VEL    = -560
local DEATH_FALL_DIST   = WINDOW_H + 100

-- La física dentro de líquidos (gravedad, salto, velocidad, arrastre) y la de
-- cada superficie (fricción, cintas...) viene del MATERIAL del tile:
-- src/world/tiles/materials/.

-- Contacto con materiales 'hurt': invulnerabilidad tras recibir daño
local HURT_COOLDOWN = 1.0

-- Ahogamiento
local DROWN_TOTAL     = 20     -- segundos hasta empezar drowning.ogg
local DROWN_CHIME_INT = 5      -- intervalo de chime de advertencia (s)
local DROWN_CHIMES    = 3      -- número de chimes antes de drowning
local DROWN_AUDIO_DUR = 12     -- duración de drowning.ogg (s) — mata al final

-- HUD aire: barra única
local AIR_BAR_W  = 160
local AIR_BAR_H  = 12

-- Bajar por plataformas traspasables
local DROP_DELAY = 0.25    -- s agachado sobre la plataforma antes de atravesarla
local DROP_PUSH  = 60      -- empujoncito hacia abajo al empezar a caer

local DIR_UP    = 0
local DIR_DOWN  = 1
local DIR_LEFT  = 2
local DIR_RIGHT = 3

-- ── Hitboxes ──────────────────────────────────────────────────────────────────
local SPRITE_H   = 16 * PLAYER_SCALE
local OUTER_W    = 9  * PLAYER_SCALE * 0.72
local OUTER_H    = SPRITE_H * 0.78
local OUTER_YOFF = SPRITE_H / 2 - OUTER_H / 2
local INNER_W    = OUTER_W * 0.60
local INNER_H    = OUTER_H * 0.65

-- Hitbox agachado: más baja, misma anchura
local CROUCH_OUTER_H  = OUTER_H * 0.50
local CROUCH_OUTER_YOFF = SPRITE_H / 2 - CROUCH_OUTER_H / 2
local CROUCH_INNER_H  = INNER_H * 0.50

function PlayerAdventure:new(x, y)
    loadSprites()
    local o = setmetatable({}, self)
    self.__index = self
    o.x=x; o.y=y; o.vx=0; o.vy=0
    o.w=OUTER_W; o.h=OUTER_H
    o.onGround=false; o.alive=true; o.inWater=false
    o.dying=false; o.deathPhase=nil; o.deathTimer=0; o.deathY=0
    o.facing=1; o.jumpsLeft=2
    o.animT=0; o.frame=3; o.puff=1
    o.lives=3; o.spawnX=x; o.spawnY=y
    o.prevInWater = false   -- para detectar entrada/salida del agua
    -- Ahogamiento
    o.drownTimer  = 0      -- segundos con cabeza bajo agua
    o.drownChime  = 0      -- chimes ya emitidos
    o.drownPhase  = 'none' -- 'none' | 'warning' | 'drowning' | 'dead'
    o.drownAudT   = 0      -- tiempo transcurrido en fase 'drowning'
    o.drownDead   = false  -- bandera: matar en el próximo frame
    -- Animación barra de aire
    o.airBarAlpha = 0
    o.airBarBobT  = 0
    o.airBarBobOn = false
    o.airBarShakeX= 0
    o.hp=3; o.hpMax=3; o.showHpBar=false
    o.crouching=false
    o.dropHoldT=0         -- tiempo agachado sobre una plataforma traspasable
    o.dropping=false      -- atravesando una plataforma traspasable hacia abajo
    o.dropTop=0           -- Y de la cara superior de la plataforma que se atraviesa
    o.liquid=nil          -- material líquido en el que está (nil = fuera)
    o.prevLiquid=nil
    o.groundDef=nil       -- tipo de tile sobre el que está de pie (material de suelo)
    o.hurtT=0             -- invulnerabilidad restante tras daño por contacto
    return o
end

function PlayerAdventure:getOuterBounds()
    if self.crouching then
        -- Agachado: hitbox más baja, alineada al suelo (parte inferior igual)
        local normalBot = self.y + OUTER_YOFF + OUTER_H/2
        local crouchTop = normalBot - CROUCH_OUTER_H
        return {x=self.x-self.w/2, y=crouchTop, w=self.w, h=CROUCH_OUTER_H}
    end
    return {x=self.x-self.w/2, y=self.y+OUTER_YOFF-self.h/2, w=self.w, h=self.h}
end
function PlayerAdventure:getInnerBounds()
    if self.crouching then
        local normalBot = self.y + OUTER_YOFF + OUTER_H/2
        local crouchTop = normalBot - CROUCH_INNER_H
        return {x=self.x-INNER_W/2, y=crouchTop, w=INNER_W, h=CROUCH_INNER_H}
    end
    return {x=self.x-INNER_W/2, y=self.y-INNER_H/2, w=INNER_W, h=INNER_H}
end

function PlayerAdventure:getHeadPoint()
    local ob = self:getOuterBounds()
    return ob.x + ob.w * 0.5, ob.y + ob.h * 0.05
end

-- ── Colisión ──────────────────────────────────────────────────────────────────
-- Todo se consulta al nivel por TIPO de tile (colisión, hitbox, material); aquí
-- no se nombra ningún tile concreto.

-- Si el jugador (en el suelo) está apoyado SOLO sobre plataformas
-- traspasables, devuelve la Y de su cara superior; si algo no traspasable lo
-- sostiene (sólido, plataforma normal...), devuelve nil.
local function dropPlatformTop(pa, level)
    local ob    = pa:getOuterBounds()
    local footY = ob.y + ob.h + 2
    local top
    for _, cx in ipairs({ pa.x - pa.w/2 + 4, pa.x, pa.x + pa.w/2 - 4 }) do
        local t = level:getDefAt(cx, footY)
        if t.collision == 'oneway' and t.dropThrough then
            top = math.floor(footY / TILE_PX) * TILE_PX + t.hitbox.y * TILE_PX
        elseif t.collision ~= 'none' then
            return nil
        end
    end
    return top
end

-- Comprueba si un pincho dado (dir, pos) realmente golpea al jugador
-- basado en la dirección: la punta debe apuntar hacia el centro del jugador
local function spikeHitsPlayer(spike, pb)
    -- Centro del jugador
    local pcx = pb.x + pb.w/2
    local pcy = pb.y + pb.h/2
    -- Centro del pincho
    local scx = spike.x + spike.w/2
    local scy = spike.y + spike.h/2

    if spike.dir == DIR_UP    then return pcy < scy   end   -- punta hacia arriba, jugador encima
    if spike.dir == DIR_DOWN  then return pcy > scy   end
    if spike.dir == DIR_LEFT  then return pcx < scx   end
    if spike.dir == DIR_RIGHT then return pcx > scx   end
    return true
end

function PlayerAdventure:moveAndCollide(level, dx, dy)
    local T      = TILE_PX
    local x, y   = self.x, self.y+OUTER_YOFF
    local hw, hh = self.w/2, self.h/2

    -- X: al chocar, pegarse al borde de la hitbox del tile
    x = x + dx
    local chy = {y-hh+4, y, y+hh-4}
    if dx > 0 then
        for _,py in ipairs(chy) do
            local t = level:collisionAt(x+hw, py)
            if t then
                x = math.floor((x+hw)/T)*T + t.hitbox.x*T - hw; self.vx=0; break
            end
        end
    elseif dx < 0 then
        for _,py in ipairs(chy) do
            local t = level:collisionAt(x-hw, py)
            if t then
                local edge = t.fullHitbox and math.ceil((x-hw)/T)*T
                             or math.floor((x-hw)/T)*T + (t.hitbox.x + t.hitbox.w)*T
                x = edge + hw; self.vx=0; break
            end
        end
    end

    -- Y
    local prevFoot = self.y + hh
    y = y + dy
    self.onGround = false
    self.groundDef = nil
    local chx = {x-hw+4, x, x+hw-4}
    if dy > 0 then
        for _,px in ipairs(chx) do
            local t = level:collisionAt(px, y+hh, true)
            if t then
                local top = math.floor((y+hh)/T)*T + t.hitbox.y*T
                if t.collision == 'oneway' then
                    -- Bajando a través de ESTA plataforma traspasable: no colisionar
                    local passing = self.dropping and t.dropThrough and top==self.dropTop
                    if not passing and prevFoot<=top+2 then
                        y=top-hh; self.vy=0; self.onGround=true; self.jumpsLeft=2
                        self.groundDef=t; break
                    end
                else
                    y=top-hh
                    self.vy=0; self.onGround=true; self.jumpsLeft=2
                    self.groundDef=t; break
                end
            end
        end
    elseif dy < 0 then
        for _,px in ipairs(chx) do
            local t = level:collisionAt(px, y-hh)
            if t then
                local edge = t.fullHitbox and math.ceil((y-hh)/T)*T
                             or math.floor((y-hh)/T)*T + (t.hitbox.y + t.hitbox.h)*T
                y = edge + hh; self.vy=0; break
            end
        end
    end

    self.x, self.y = x, y-OUTER_YOFF

    -- Fin de la bajada: los pies ya pasaron la zona en la que la plataforma
    -- volvería a "atraparlos" (prevFoot se mide OUTER_YOFF más arriba que los
    -- pies reales, más el margen de 2px del aterrizaje), o aterrizó en otra cosa.
    if self.dropping and (self.onGround or y + hh > self.dropTop + OUTER_YOFF + 4) then
        self.dropping = false
    end

    -- Contacto (hitbox interna) con materiales que matan o dañan
    local iw2, ih2 = INNER_W/2, INNER_H/2
    local iy = self.y+OUTER_YOFF
    local corners={
        {x-iw2+2,iy-ih2+2},{x+iw2-2,iy-ih2+2},
        {x-iw2+2,iy+ih2-2},{x+iw2-2,iy+ih2-2},
    }
    for _,c in ipairs(corners) do
        local t = level:contactAt(c[1],c[2])
        if t then
            if t.mat.contact == 'kill' then self:die(); return end
            if t.mat.contact == 'hurt' and self:hurt() then return end
        end
    end

    -- Pinchos: usar outer bounds contra getSpikesInBox
    local ob = self:getOuterBounds()
    local spikeList = level:getSpikesInBox(ob.x, ob.y, ob.w, ob.h)
    for _, sp in ipairs(spikeList) do
        if spikeHitsPlayer(sp, ob) then self:die(); return end
    end

    -- Líquidos
    self.liquid  = level:liquidInBox(ob.x, ob.y, ob.w, ob.h)
    self.inWater = self.liquid ~= nil
    if self.inWater and self.onGround then self.jumpsLeft=2 end
end

-- ── Acciones ──────────────────────────────────────────────────────────────────
function PlayerAdventure:jump()
    if self.jumpsLeft > 0 then
        local vel = ADV_JUMP_VEL * (self.inWater and self.liquid.jumpMult or 1.0)
        self.vy=vel; self.jumpsLeft=self.jumpsLeft-1
        self.puff=PUFF_SCALE; Sound.play('jump')
    end
end

function PlayerAdventure:takeDamage()
    if self.dying or not self.alive then return false end
    self.hp=self.hp-1
    if self.hp<=0 then self.hp=self.hpMax; self:die(); return true end
    Sound.play('dies'); return false
end

-- Daño con invulnerabilidad breve (tiles 'hurt', entidades onTouch='hurt').
-- Devuelve true si el golpe lo mató.
function PlayerAdventure:hurt()
    if self.hurtT > 0 or self.dying or not self.alive then return false end
    self.hurtT = HURT_COOLDOWN
    return self:takeDamage()
end

function PlayerAdventure:die(drownDeath)
    if self.dying then return end
    self.dying=true; self.vx=0; self.vy=0
    self.deathPhase='freeze'; self.deathTimer=0; self.deathY=self.y
    if not drownDeath then
        Sound.play('dies2')
    end
    -- Limpiar estado de ahogamiento sea cual sea la causa de muerte
    self.drownTimer=0; self.drownChime=0; self.drownPhase='none'
    self.drownAudT=0; self.drownDead=false
    Sound.stopTracked('drowning')
    self.airBarAlpha=0; self.airBarBobT=0; self.airBarBobOn=false; self.airBarShakeX=0
end

function PlayerAdventure:respawn()
    self.x=self.spawnX; self.y=self.spawnY
    self.vx=0; self.vy=0; self.onGround=false; self.jumpsLeft=2
    self.dying=false; self.alive=true; self.deathPhase=nil; self.deathTimer=0
    self.frame=3; self.puff=1; self.hp=self.hpMax; self.inWater=false
    self.crouching=false; self.dropHoldT=0; self.dropping=false; self.dropTop=0
    self.liquid=nil; self.prevLiquid=nil; self.groundDef=nil; self.hurtT=0
    self.drownTimer=0; self.drownChime=0; self.drownPhase='none'
    self.drownAudT=0; self.drownDead=false
    self.prevInWater=false
    Sound.stopTracked('drowning')
    Sound.playMusic('level')
    self.airBarAlpha=0; self.airBarBobT=0; self.airBarBobOn=false; self.airBarShakeX=0
end


-- ── Ahogamiento ───────────────────────────────────────────────────────────────
-- La "cabeza" es la franja superior del 25% de la outerBounds.
-- Mientras esté sumergida avanza el temporizador; al salir → reset total.
function PlayerAdventure:updateDrowning(dt, level)
    if self.dying then return end

    local headX, headY = self:getHeadPoint()
    local liq = level:liquidAt(headX, headY)
    local headUnder = liq ~= nil and liq.drown

    -- ── Salió del agua: reset total ──────────────────────────────────────────
    if not headUnder then
        if self.drownPhase ~= 'none' then
            self.drownTimer  = 0
            self.drownChime  = 0
            self.drownAudT   = 0
            self.drownDead   = false
            if self.drownPhase == 'drowning' then
                -- Solo suena al tomar aire si drowning.ogg estaba sonando
                Sound.play('airGasp')
                Sound.stopTracked('drowning')
                Sound.playMusic('level')
            end
            self.drownPhase = 'none'
        end
        return
    end

    -- ── Cabeza bajo el agua ───────────────────────────────────────────────────
    if self.drownPhase == 'none' then
        self.drownPhase  = 'warning'
        self.airBarBobT  = 0
        self.airBarBobOn = true
    end

    if self.drownPhase == 'warning' then
        self.drownTimer = self.drownTimer + dt

        -- Chimes cada DROWN_CHIME_INT segundos (máx DROWN_CHIMES)
        local needed = math.floor(self.drownTimer / DROWN_CHIME_INT)
        while self.drownChime < needed and self.drownChime < DROWN_CHIMES do
            self.drownChime = self.drownChime + 1
            Sound.play('waterWarning')
        end

        -- A los 20 s arrancar drowning.ogg
        if self.drownTimer >= DROWN_TOTAL then
            self.drownPhase = 'drowning'
            self.drownAudT  = 0
            self.drownTimer = 0
            Sound.stopMusic()
            Sound.playTracked('drowning')
        end
        return
    end

    if self.drownPhase == 'drowning' then
        self.drownAudT = self.drownAudT + dt
        -- Matar cuando termina el audio (~12 s)
        if self.drownAudT >= DROWN_AUDIO_DUR then
            Sound.stopTracked('drowning')
            Sound.play('glugluglu')
            self:die(true)   -- true = muerte por ahogamiento, sin dies2
        end
        return
    end
end

-- ── Animación barra de aire ──────────────────────────────────────────────────
function PlayerAdventure:updateAirBarAnim(dt)
    local targetAlpha = (self.drownPhase ~= 'none') and 1 or 0
    local lerpSpeed   = (targetAlpha > self.airBarAlpha) and 6 or 3
    self.airBarAlpha  = self.airBarAlpha + (targetAlpha - self.airBarAlpha) * lerpSpeed * dt
    if self.airBarAlpha < 0.005 then self.airBarAlpha = 0 end

    -- Bob de entrada
    if self.airBarBobOn then
        self.airBarBobT = self.airBarBobT + dt
        if self.airBarBobT > 0.5 then
            self.airBarBobOn = false
            self.airBarBobT  = 0
        end
    end

    -- Agitación durante drowning: crece con drownAudT
    if self.drownPhase == 'drowning' then
        local t         = self.drownAudT / DROWN_AUDIO_DUR  -- 0→1
        local intensity = 1 + t * 6     -- 1→7 px
        local freq      = 18 + t * 34   -- 18→52 rad/s
        self.airBarShakeX = math.sin(love.timer.getTime() * freq) * intensity
    else
        self.airBarShakeX = 0
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────
function PlayerAdventure:update(dt, level)
    if self.dying then
        self.deathTimer=self.deathTimer+dt
        if self.deathPhase=='freeze' then
            if self.deathTimer>=DEATH_FREEZE_TIME then
                self.deathPhase='jump'; self.deathTimer=0; self.vy=DEATH_JUMP_VEL
            end
        elseif self.deathPhase=='jump' or self.deathPhase=='fall' then
            self.vy=self.vy+ADV_GRAVITY*dt; self.y=self.y+self.vy*dt
            if self.vy>0 then self.deathPhase='fall' end
            if self.y>self.deathY+DEATH_FALL_DIST then self.alive=false end
        end
        return
    end

    local moveX=0
    -- Agacharse: solo en el suelo, bloquea movimiento
    local wantCrouch = Input.down('crouch')
    if wantCrouch and self.onGround and not self.inWater then
        self.crouching = true
    else
        self.crouching = false
    end

    -- Bajar por plataforma traspasable: hay que MANTENER agachado DROP_DELAY
    -- segundos (margen contra agachados accidentales). Las plataformas no
    -- traspasables nunca dejan bajar.
    local dropTop = (self.crouching and self.onGround) and dropPlatformTop(self, level) or nil
    if dropTop then
        self.dropHoldT = self.dropHoldT + dt
        if self.dropHoldT >= DROP_DELAY then
            self.dropHoldT = 0
            self.dropping  = true
            self.dropTop   = dropTop
            self.onGround  = false
            self.crouching = false
            self.vy        = DROP_PUSH
        end
    else
        self.dropHoldT = 0
    end

    if not self.crouching then
        if Input.down('move_right') then moveX=1 end
        if Input.down('move_left')  then moveX=-1 end
    end
    if Input.pressed('jump') and not self.crouching then self:jump() end

    -- Materiales: el líquido en el que está y la superficie que pisa
    local liq    = self.inWater and self.liquid or nil
    local ground = (self.onGround and self.groundDef) and self.groundDef.mat or nil
    local speedM = liq and liq.speedMult   or 1.0
    local gravM  = liq and liq.gravityMult or 1.0
    local fric   = self.onGround and ADV_FRICTION * (ground and ground.friction or 1) or ADV_AIR_FRIC
    local walkM  = ground and ground.speedMult or 1
    local convey = ground and ground.conveyor  or 0

    if self.hurtT > 0 then self.hurtT = math.max(0, self.hurtT - dt) end

    self.vx = self.vx + (moveX*ADV_MOVE_SPD*speedM*walkM - self.vx)*fric*dt
    self.vy = self.vy + ADV_GRAVITY*gravM*dt
    if liq then self.vy=self.vy+(-self.vy*liq.drag*dt) end

    self:moveAndCollide(level, (self.vx + convey)*dt, self.vy*dt)

    -- Splash al entrar/salir de un líquido (cualquier parte del cuerpo)
    if self.inWater and not self.prevInWater then
        if self.liquid.splashIn then Sound.play(self.liquid.splashIn) end
    elseif not self.inWater and self.prevInWater then
        local prev = self.prevLiquid
        if prev and prev.splashOut then Sound.play(prev.splashOut) end
    end
    self.prevInWater = self.inWater
    self.prevLiquid  = self.liquid

    if self.vx>20 then self.facing=1 elseif self.vx<-20 then self.facing=-1 end

    local moving  = math.abs(self.vx)>20
    local falling = not self.onGround and self.vy>0
    local rising  = not self.onGround and self.vy<0

    if rising then
        self.frame=2; self.animT=0
    elseif falling then
        self.animT=self.animT+dt
        if self.animT>=1/FALL_FPS then
            self.animT=self.animT-1/FALL_FPS
            self.frame=(self.frame==1) and 3 or 1
        end
    elseif self.crouching then
        self.frame=5; self.animT=0   -- frame agachado
    elseif moving then
        self.animT=self.animT+dt
        if self.animT>=1/WALK_FPS then
            self.animT=self.animT-1/WALK_FPS
            self.frame=(self.frame==3) and 2 or 3
            if self.frame==3 then self.puff=1.08; Sound.play('step') end
        end
    else
        self.frame=3; self.animT=0
    end

    self.puff=self.puff+(1-self.puff)*PUFF_SPD*dt

    self:updateDrowning(dt, level)
    self:updateAirBarAnim(dt)
end

-- ── Render ────────────────────────────────────────────────────────────────────
function PlayerAdventure:render(camX, camY)
    local img
    if self.dying then
        img = spriteDead
    elseif self.frame == 5 then
        img = spriteCrouch
    else
        img = sprites[self.frame] or sprites[3]
    end
    local iw=img:getWidth(); local ih=img:getHeight()
    local s=PLAYER_SCALE*self.puff
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img,
        math.floor(self.x-camX), math.floor(self.y-camY),
        0, s*self.facing, s, iw/2, ih/2)
end

-- ── HUD: barra de aire pixel-art ─────────────────────────────────────────────
function PlayerAdventure:renderAirBar()
    if self.airBarAlpha <= 0 then return end

    local a = self.airBarAlpha

    local progress
    if self.drownPhase == 'warning' then
        progress = 1 - (self.drownTimer / DROWN_TOTAL)
    else
        progress = 0
    end

    -- Bob de entrada: offset Y amortiguado
    local bobY = 0
    if self.airBarBobOn then
        local t   = self.airBarBobT
        local env = 1 - (t / 0.5)
        bobY = math.sin(t * math.pi * 3.5) * 12 * env
    end

    local bx = math.floor((WINDOW_W - AIR_BAR_W) / 2) + math.floor(self.airBarShakeX)
    local by = math.floor(WINDOW_H - 60 + bobY)

    -- Sombra pixel-art
    love.graphics.setColor(0, 0, 0, 0.75 * a)
    love.graphics.rectangle('fill', bx + 2, by + 2, AIR_BAR_W, AIR_BAR_H)

    -- Fondo
    love.graphics.setColor(0.10, 0.10, 0.15, a)
    love.graphics.rectangle('fill', bx, by, AIR_BAR_W, AIR_BAR_H)

    -- Fill de aire
    local fillW = math.floor(AIR_BAR_W * progress)
    if fillW > 0 then
        local pulse = 1.0
        if progress < 0.25 then
            pulse = 0.4 + math.abs(math.sin(love.timer.getTime() * 7)) * 0.6
        end
        local r = math.min(1, 2 - progress * 2)
        local g = math.min(1, progress * 2) * 0.55
        local b = math.max(0, progress)
        love.graphics.setColor(r * pulse, g * pulse, b * pulse, a)
        love.graphics.rectangle('fill', bx, by, fillW, AIR_BAR_H)
        love.graphics.setColor(1, 1, 1, 0.20 * a)
        love.graphics.rectangle('fill', bx, by, fillW, 2)
    end

    -- Parpadeo rojo durante drowning
    if self.drownPhase == 'drowning' then
        local pulse = 0.35 + math.abs(math.sin(love.timer.getTime() * 7)) * 0.65
        love.graphics.setColor(0.9, 0.05, 0.05, pulse * a)
        love.graphics.rectangle('fill', bx, by, AIR_BAR_W, AIR_BAR_H)
    end

    -- Borde
    love.graphics.setColor(0.55, 0.55, 0.65, a)
    love.graphics.rectangle('line', bx, by, AIR_BAR_W, AIR_BAR_H)

    -- Icono "~"
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0.4, 0.7, 1, a * 0.9)
    love.graphics.print('~', bx - 14, by + 1)

    love.graphics.setColor(1, 1, 1, 1)
end
function PlayerAdventure:renderDebug(camX, camY)
    local ob=self:getOuterBounds()
    love.graphics.setColor(0,1,0,0.4)
    love.graphics.rectangle('line',ob.x-camX,ob.y-camY,ob.w,ob.h)
    local ib=self:getInnerBounds()
    love.graphics.setColor(1,0,0,0.4)
    love.graphics.rectangle('line',ib.x-camX,ib.y-camY,ib.w,ib.h)
    -- Punto de boca (hitbox de ahogamiento) — círculo cyan
    local hx, hy = self:getHeadPoint()
    love.graphics.setColor(0.2, 0.8, 1, 0.9)
    love.graphics.circle('fill', hx-camX, hy-camY, 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle('line', hx-camX, hy-camY, 3)
end

return PlayerAdventure