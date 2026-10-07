-- src/player/PlayerAdventure.lua
local Difficulty = require 'src/core/Difficulty'
local Class = require 'libs/class'
local DeadEyes = require 'src/player/DeadEyes'
local Tiles = require 'src/world/tiles/Tiles'
local PlayerAdventure = Class:new()
local P = {}        -- locales de archivo que comparten las partes (ver abajo "Partes")
local dropPlatformTop, ICE_FREE_INV, ICE_MASH, loadSprites      -- (de las partes: se rellenan al cargarlas)


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
-- INVULNERABILIDAD (un solo sistema, sea cual sea la causa): mientras dura
-- (invT) no recibe daño, no muere salvo ahogado o por el límite de tiempo, no
-- le empujan, atraviesa a los jefes y PARPADEA (también para los demás
-- jugadores online: PF_INVULN). La dan reaparecer (SPAWN_INV) y cualquier
-- golpe que no mata (HIT_INV): nadie encadena golpes ni atrapa en una esquina.
local HIT_INV     = 1.6
local HURT_FLASH  = 0.5      -- s del destello rojo al recibir un golpe
-- Al reaparecer: invulnerable a TODO (parpadea) durante este tiempo
local SPAWN_INV     = 2.5
PlayerAdventure.SPAWN_INV = SPAWN_INV

-- Ahogamiento
local DROWN_TOTAL     = 20     -- segundos hasta empezar drowning.ogg
local DROWN_CHIME_INT = 5      -- intervalo de chime de advertencia (s)
local DROWN_CHIMES    = 3      -- número de chimes antes de drowning
local DROWN_AUDIO_DUR = 12     -- duración de drowning.ogg (s) — mata al final

-- HUD aire: barra única
local AIR_BAR_W  = 160
local AIR_BAR_H  = 12

-- Ground pound: agacharse en el aire → se frena un instante y cae en picado
local GP_WINDUP     = 0.22     -- s suspendido en el aire antes de caer
local GP_SPEED      = 1500     -- px/s de caída (bajo el agua ×GP_WATER)
local GP_WATER      = 0.55
-- Empujón que reciben otros jugadores cerca del impacto (online)
local GP_PUSH_VX    = 900
local GP_PUSH_VY    = -420
local GP_STUN       = 0.8      -- s aturdido (sin control)
PlayerAdventure.GP_RADIUS_X = 170
PlayerAdventure.GP_RADIUS_Y = 110

-- Efectos visuales (partículas): los pone el juego; el servidor los reenvía
-- a los clientes y la re-simulación de la predicción los silencia.
PlayerAdventure.fx = nil       -- function(kind, x, y, player)
local function fx(self, kind, x, y)
    if PlayerAdventure.fx then PlayerAdventure.fx(kind, x, y, self) end
end

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

-- Aplastado: aún más bajo (el sprite agachado se dibuja aplastado a SQUASH_K)
local SQUASH_K        = 0.55
local SQUASH_OUTER_H  = CROUCH_OUTER_H * SQUASH_K
local SQUASH_INNER_H  = CROUCH_INNER_H * SQUASH_K
PlayerAdventure.SQUASH_K = SQUASH_K

local Noise = require 'src/world/systems/Noise'       -- (ruidos que oyen los enemigos: pasos, saltos, ground pound...)

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
    o.hurtT=0             -- destello rojo tras un golpe (solo dibujo)
    o.gpPhase=nil         -- ground pound: nil | 'windup' | 'fall'
    o.gpT=0
    o.gpLanded=false      -- true SOLO en el paso en que impactó (lo leen juego/servidor)
    o.stunT=0             -- aturdido (empujado por un ground pound ajeno)
    o.invT=0              -- invulnerable (reaparecer, tras un golpe...: ver HIT_INV)
    o.squashT=0           -- aplastado (agachado y aturdido)
    o.iceT=0              -- congelado en un bloque de hielo (congelador)
    o.ctrlLockT=0         -- sin control un instante (lanzado de lado por un trampolín)
    o.lightOn=false       -- linterna (niveles a oscuras): encendida
    o.lightBat=1          -- batería 0..1
    o.lightCd=0           -- s sin poder encenderla (agotada / apagada por un golpe)
    return o
end

-- Caja exterior de un jugador DE PIE con el centro del sprite en (x, y)
-- (jugadores remotos online, de los que solo se conoce la posición)
function PlayerAdventure.outerBoxAt(x, y)
    return { x = x - OUTER_W / 2, y = y + OUTER_YOFF - OUTER_H / 2, w = OUTER_W, h = OUTER_H }
end

function PlayerAdventure:getOuterBounds()
    if self.crouching then
        -- Agachado (o aplastado): hitbox más baja, alineada al suelo
        local h = ((self.squashT or 0) > 0) and SQUASH_OUTER_H or CROUCH_OUTER_H
        local normalBot = self.y + OUTER_YOFF + OUTER_H/2
        local crouchTop = normalBot - h
        return {x=self.x-self.w/2, y=crouchTop, w=self.w, h=h}
    end
    return {x=self.x-self.w/2, y=self.y+OUTER_YOFF-self.h/2, w=self.w, h=self.h}
end
function PlayerAdventure:getInnerBounds()
    if self.crouching then
        local h = ((self.squashT or 0) > 0) and SQUASH_INNER_H or CROUCH_INNER_H
        local normalBot = self.y + OUTER_YOFF + OUTER_H/2
        local crouchTop = normalBot - h
        return {x=self.x-INNER_W/2, y=crouchTop, w=INNER_W, h=h}
    end
    return {x=self.x-INNER_W/2, y=self.y-INNER_H/2, w=INNER_W, h=INNER_H}
end

function PlayerAdventure:getHeadPoint()
    local ob = self:getOuterBounds()
    return ob.x + ob.w * 0.5, ob.y + ob.h * 0.05
end

-- ¿Cabe de pie? (la hitbox de pie, con los mismos pies, no toca nada sólido).
-- Agachado en un hueco de 1 casilla de alto no hay sitio: sigue agachado.
function PlayerAdventure:canStand(level)
    local foot = self.y + OUTER_YOFF + OUTER_H / 2
    local top  = foot - OUTER_H
    for _, px in ipairs({ self.x - self.w/2 + 4, self.x, self.x + self.w/2 - 4 }) do
        local py = top + 1
        while true do
            if level:collisionAt(px, py) then return false end
            if py >= foot - 2 then break end
            py = math.min(py + 12, foot - 2)
        end
    end
    return true
end

-- ── Acciones ──────────────────────────────────────────────────────────────────
function PlayerAdventure:jump()
    if self.jumpsLeft > 0 then
        local vel = ADV_JUMP_VEL * (self.inWater and self.liquid.jumpMult or 1.0) * (self.jumpMult or 1)
        self.vy=vel; self.jumpsLeft=self.jumpsLeft-1
        self.puff=PUFF_SCALE; Sound.play('jump')
    end
end

-- Lo que el MUNDO le hace a un jugador (un jefe le cae encima, la cámara
-- automática lo deja atrás...) suena como suyo: online, su cliente lo genera
-- al ver bajar su vida. El servidor pone aquí cómo atribuirlo.
PlayerAdventure.soundOwner = nil      -- function(pa, fn)
function PlayerAdventure.asOwner(pa, fn)
    if PlayerAdventure.soundOwner then return PlayerAdventure.soundOwner(pa, fn) end
    return fn()
end

-- ¿Invulnerable? (por lo que sea: reaparecer, un golpe reciente...)
-- (congelado en la entrada de un jefe también: sin control, nada le hace daño)
function PlayerAdventure:isInvulnerable() return (self.invT or 0) > 0 or self.frozen == true end
-- Da invulnerabilidad `t` s (se queda con la que dure más)
function PlayerAdventure:grantInvulnerability(t)
    self.invT = math.max(self.invT or 0, t)
end
-- ¿No se le puede empujar ahora? Invulnerable, salvo el empujón que acompaña
-- al MISMO golpe (hitNow: solo durante el paso en que lo recibió)
function PlayerAdventure:isPushProtected()
    return self:isInvulnerable() and not self.hitNow
end

-- INMORTAL (`immortal = true`: los bots rivales del modo historia, src/ai/Bot.lua): los golpes y los empujones
-- le llegan (destello, invulnerable un momento, sale despedido), pero ni pierde vida ni muere ni se ahoga.
function PlayerAdventure:takeDamage()
    if self.dying or not self.alive or self:isInvulnerable() then return false end
    if self.immortal then return false end
    self.hp=self.hp-1
    if self.hp<=0 then self.hp=self.hpMax; self:die(); return true end
    Sound.play('dies'); Noise.emit(self.x, self.y, Noise.R.hurt); return false
end

-- Golpe de `n` de vida (1 por defecto): tiles 'hurt', entidades onTouch='hurt',
-- jefes... Si no lo mata, queda invulnerable HIT_INV s. true si lo mató.
function PlayerAdventure:hurt(n)
    if self.dying or not self.alive or self:isInvulnerable() then return false end
    for _ = 1, math.max(1, n or 1) do
        if self:takeDamage() then return true end
    end
    self:grantInvulnerability(HIT_INV * Difficulty.k('invuln'))
    self.hurtT, self.hitNow = HURT_FLASH, true
    return false
end

-- Devuelve false si no murió (invulnerable tras reaparecer). `force` = muere
-- igual (límite de tiempo del nivel).
function PlayerAdventure:die(drownDeath, force)
    if self.dying then return end
    if self.immortal then                                  -- (pinchos, lava, un aplastón: un bote y sigue)
        if self:isInvulnerable() then return false end
        self.vy, self.onGround = -620, false
        self.gpPhase, self.gpT = nil, 0
        self:grantInvulnerability(1.2)
        self.hurtT, self.hitNow = HURT_FLASH, true
        Sound.play('dies')
        return false
    end
    if self:isInvulnerable() and not drownDeath and not force then return false end
    self.dying=true; self.vx=0; self.vy=0
    self.gpPhase=nil; self.stunT=0; self.squashT=0; self.iceT=0
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

-- La dificultad del nivel (src/core/Difficulty.lua) en lo que es del jugador: su vida. Lo llama quien lo
-- crea, con el nivel ya enlazado (un jugador, el servidor y el cliente: los tres igual).
function PlayerAdventure:applyDifficulty()
    self.hpMax = Difficulty.k('playerHp', 3)
    self.hp = self.hpMax
end

-- Pinchos y lava: matan… salvo que la dificultad los rebaje a 1 de vida (`hazardHurt`): entonces
-- hacen daño y te sacan de un bote hacia arriba (para poder salir del foso). true = ha muerto.
function PlayerAdventure:hazardHit()
    if not Difficulty.flag('hazardHurt') then return self:die() ~= false end
    if self:isInvulnerable() then return false end
    if self:hurt() then return true end
    self.vy, self.onGround = -620, false
    self.gpPhase, self.gpT = nil, 0
    return false
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
    self.splashSt='out'; self.splashCD=0
    self.gpPhase=nil; self.gpT=0; self.gpLanded=false; self.stunT=0; self.squashT=0; self.ctrlLockT=0; self.iceT=0
    self.lightOn=false; self.lightBat=1; self.lightCd=0
    self:grantInvulnerability(SPAWN_INV * Difficulty.k('invuln'))
    Sound.stopTracked('drowning')
    Sound.playMusic('level')
    self.airBarAlpha=0; self.airBarBobT=0; self.airBarBobOn=false; self.airBarShakeX=0
end


-- ── Update ────────────────────────────────────────────────────────────────────
-- Entrada de un jefe: el jugador se queda sin control (se lee un Input vacío;
-- la gravedad y lo demás siguen). Igual en un jugador, servidor y predicción.
local FROZEN_INPUT = { pressed = function() return false end, down = function() return false end }
function PlayerAdventure:update(dt, level)
    self.peaceful = level ~= nil and level.peaceful == true          -- (nivel de enemigos inofensivos)
    self.frozen = level ~= nil and level.frozenAt ~= nil and not self.dying and level:frozenAt(self.x, self.y)
    -- (`forceFrozen`: lo pone quien lleva la partida cuando ya ha terminado — el bonus contra el bot —: sin control
    -- e invulnerable, como en la entrada de un jefe)
    if self.forceFrozen and not self.dying then self.frozen = true end
    if (self.iceT or 0) > 0 and not self.dying then
        -- Congelado: las pulsaciones rompen el hielo antes; el cuerpo se queda en
        -- su pose (cuadro y escala) y resbala/cae como un bloque
        local mash = 0
        if Input.pressed('jump') then mash = mash + 1 end
        if Input.pressed('crouch') then mash = mash + 1 end
        self.iceT = math.max(0, self.iceT - dt - mash * ICE_MASH)
        if self.onGround then self.vx = self.vx * math.max(0, 1 - 1.5 * dt) end
        local frame, puff, crouch = self.frame, self.puff, self.crouching
        local real = Input
        Input = setmetatable(FROZEN_INPUT, { __index = real })
        local ok, err = pcall(self._update, self, dt, level)
        Input = real
        if not ok then error(err, 0) end
        if self.iceT > 0 and not self.dying then
            self.frame, self.puff, self.crouching = frame, puff, crouch
        elseif not self.dying then
            -- Se rompe el hielo
            self:grantInvulnerability(ICE_FREE_INV)
            Sound.play('cryoFree')
            fx(self, 'ice_shatter', self.x, self.y)
        end
        return
    end
    if self.frozen then
        -- (quieto de verdad: sin la inercia que traía; la gravedad sigue)
        if not self.stunT or self.stunT <= 0 then self.vx = 0 end
        local real = Input
        Input = setmetatable(FROZEN_INPUT, { __index = real })
        local ok, err = pcall(self._update, self, dt, level)
        Input = real
        if not ok then error(err, 0) end
        return
    end
    return self:_update(dt, level)
end

-- ── Linterna (niveles a oscuras: level.dark) ─────────────────────────────────
-- Se enciende y apaga con 'light'. Encendida gasta batería (LIGHT_TIME s de luz seguida); apagada
-- se recarga (LIGHT_RECHARGE s de vacía a llena). Si se AGOTA se apaga sola y no se puede volver
-- a encender en LIGHT_COOL s (y hasta entonces no recarga). Parte de la simulación (los Crabbies
-- lúgubres huyen de ella): va en el estado propio (31-33) y los demás la ven con PF_LIGHT.
local LIGHT_TIME, LIGHT_RECHARGE, LIGHT_COOL, LIGHT_MIN = 7.0, 9.0, 3.5, 0.12
PlayerAdventure.LIGHT_TIME, PlayerAdventure.LIGHT_COOL = LIGHT_TIME, LIGHT_COOL
function PlayerAdventure:updateLight(dt, level, pressed)
    if not (level and level.dark) then
        self.lightOn = false
        return
    end
    if (self.lightCd or 0) > 0 then self.lightCd = math.max(0, self.lightCd - dt) end
    if pressed then
        if self.lightOn then
            self.lightOn = false
            Sound.play('lightOff')
        elseif self.lightCd <= 0 and (self.lightBat or 1) >= LIGHT_MIN then
            self.lightOn = true
            Sound.play('lightOn')
        else
            Sound.play('lightDead')
        end
    end
    if self.lightOn then
        self.lightBat = (self.lightBat or 1) - dt / LIGHT_TIME
        if self.lightBat <= 0 then
            self.lightBat, self.lightOn, self.lightCd = 0, false, LIGHT_COOL
            Sound.play('lightOut')
        end
    elseif self.lightCd <= 0 then
        self.lightBat = math.min(1, (self.lightBat or 1) + dt / LIGHT_RECHARGE)
    end
end

-- Un golpe fuerte (jefe) le apaga la linterna `t` s (sin gastar batería)
function PlayerAdventure:blindLight(t)
    if self.lightOn then Sound.play('lightOut') end
    self.lightOn = false
    self.lightCd = math.max(self.lightCd or 0, t)
end

function PlayerAdventure:_update(dt, level)
    self.hitNow = nil
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

    self.gpLanded = false
    if self.stunT > 0 then self.stunT = math.max(0, self.stunT - dt) end
    if (self.invT or 0) > 0 then self.invT = math.max(0, self.invT - dt) end
    if (self.squashT or 0) > 0 then self.squashT = math.max(0, self.squashT - dt) end
    local stunned = self.stunT > 0
    if (self.ctrlLockT or 0) > 0 then self.ctrlLockT = math.max(0, self.ctrlLockT - dt) end
    local locked = stunned or (self.ctrlLockT or 0) > 0      -- sin control (lanzado de lado)

    -- Input de este paso (los "recién pulsado" se leen UNA vez: el stub de red
    -- los consume). Se apunta lo que el jugador PULSA, pueda o no hacerlo:
    -- el jefe espejo lo reproduce con retardo (ver entities/types/mirror.lua).
    local pJump, pCrouch = Input.pressed('jump'), Input.pressed('crouch')
    self:updateLight(dt, level, Input.pressed('light'))
    local hCrouch = Input.down('crouch')
    local inX = Input.down('move_left') and -1 or (Input.down('move_right') and 1 or 0)
    self.inMoveX, self.inCrouch = inX, hCrouch
    if pJump   then self.inJumpN   = (self.inJumpN or 0) + 1 end
    if pCrouch then self.inCrouchN = (self.inCrouchN or 0) + 1 end

    -- Ground pound: agacharse (pulsar) en el aire o nadando
    if pCrouch and not self.onGround and not stunned
       and not self.gpPhase and not self.dropping
       and (not self.crouching or self:canStand(level)) then     -- (en un túnel bajo no cabe)
        self.gpPhase, self.gpT = 'windup', 0
        self.vx, self.vy = 0, 0
        self.crouching = false
        self.puff = PUFF_SCALE
        Sound.play('gpStart')
        fx(self, 'gp_start', self.x, self.y)
    end
    if self.gpPhase then
        self:updateGroundPound(dt, level)
        return
    end

    local moveX=0
    -- Agacharse: en el suelo (también bajo el agua) no se anda, pero se puede
    -- saltar (salto agachado). En el aire solo sigue agachado quien saltó
    -- agachado, mientras mantenga agachar. Sin sitio para ponerse de pie
    -- (hueco de 1 casilla de alto) sigue agachado pase lo que pase.
    local wantCrouch = hCrouch
    if self.onGround then
        self.crouching = (wantCrouch and not stunned) or (self.squashT or 0) > 0   -- (aplastado: aunque esté aturdido)
    else
        self.crouching = self.crouching and wantCrouch
    end
    if not self.crouching and not self:canStand(level) then self.crouching = true end

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

    -- Agachado en el suelo no se anda; en el aire (salto agachado) sí se dirige
    if (not self.crouching or not self.onGround) and not locked then
        if Input.down('move_right') then moveX=1 end
        if Input.down('move_left')  then moveX=-1 end
    end
    if pJump and not stunned then
        local crouchJump = self.crouching and self.onGround and (self.squashT or 0) <= 0
        if not self.crouching or crouchJump then
            self:jump()
            -- Salto agachado con dirección: sale ya lanzado hacia ese lado
            if crouchJump and inX ~= 0 and not locked then
                local liqM = (self.inWater and self.liquid) and self.liquid.speedMult or 1
                self.vx = inX * ADV_MOVE_SPD * liqM * (self.speedMult or 1)
                self.facing = inX
            end
        end
    end

    -- Materiales: el líquido en el que está y la superficie que pisa
    local liq    = self.inWater and self.liquid or nil
    local ground = (self.onGround and self.groundDef) and self.groundDef.mat or nil
    local speedM = liq and liq.speedMult   or 1.0
    local gravM  = liq and liq.gravityMult or 1.0
    local fric   = self.onGround and ADV_FRICTION * (ground and ground.friction or 1) or ADV_AIR_FRIC
    local walkM  = ground and ground.speedMult or 1
    local convey = ground and ground.conveyor  or 0

    if self.hurtT > 0 then self.hurtT = math.max(0, self.hurtT - dt) end

    -- (lanzado de lado: el impulso se mantiene mientras dura el bloqueo)
    if (self.ctrlLockT or 0) <= 0 then
        self.vx = self.vx + (moveX*ADV_MOVE_SPD*speedM*walkM*(self.speedMult or 1) - self.vx)*fric*dt
    end
    self.vy = self.vy + ADV_GRAVITY*gravM*dt
    if liq then self.vy=self.vy+(-self.vy*liq.drag*dt) end

    self:moveAndCollide(level, (self.vx + convey)*dt, self.vy*dt)

    self:updateSplash(dt, level)
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

    -- Aplastado: agachado (sprite) desde el golpe, también en el saltito; y
    -- el salto agachado también se ve agachado
    if (self.squashT or 0) > 0 or self.crouching then self.frame, self.animT = 5, 0 end

    self.puff=self.puff+(1-self.puff)*PUFF_SPD*dt

    self:updateDrowning(dt, level)
    self:updateAirBarAnim(dt)
end

-- ── Partes (el resto de PlayerAdventure.lua, por sistemas) ────────────────────
P.PUFF_SCALE = PUFF_SCALE; P.PUFF_SPD = PUFF_SPD; P.DROWN_TOTAL = DROWN_TOTAL; P.DROWN_CHIME_INT = DROWN_CHIME_INT; P.DROWN_CHIMES = DROWN_CHIMES
P.DROWN_AUDIO_DUR = DROWN_AUDIO_DUR; P.AIR_BAR_W = AIR_BAR_W; P.AIR_BAR_H = AIR_BAR_H; P.GP_WINDUP = GP_WINDUP; P.GP_SPEED = GP_SPEED
P.GP_WATER = GP_WATER; P.GP_PUSH_VX = GP_PUSH_VX; P.GP_PUSH_VY = GP_PUSH_VY; P.GP_STUN = GP_STUN; P.fx = fx
P.DIR_UP = DIR_UP; P.DIR_DOWN = DIR_DOWN; P.DIR_LEFT = DIR_LEFT; P.DIR_RIGHT = DIR_RIGHT; P.SPRITE_H = SPRITE_H
P.OUTER_YOFF = OUTER_YOFF; P.INNER_W = INNER_W; P.INNER_H = INNER_H; P.SQUASH_K = SQUASH_K
require('src/player/PlayerCollision')(PlayerAdventure, P)
require('src/player/PlayerAir')(PlayerAdventure, P)
require('src/player/PlayerGroundPound')(PlayerAdventure, P)
require('src/player/PlayerRender')(PlayerAdventure, P)
dropPlatformTop, ICE_FREE_INV, ICE_MASH, loadSprites = P.dropPlatformTop, P.ICE_FREE_INV, P.ICE_MASH, P.loadSprites

return PlayerAdventure