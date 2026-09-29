-- src/entities/PlayerAdventure.lua
local Class = require 'libs/class'
local DeadEyes = require 'src/entities/DeadEyes'
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
    o.ctrlLockT=0         -- sin control un instante (lanzado de lado por un trampolín)
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
    -- Caja con la que choca: la de pie o, agachado, la baja (mismos pies)
    local yoff, hh = OUTER_YOFF, self.h/2
    if self.crouching then
        local ob = self:getOuterBounds()
        hh = ob.h / 2
        yoff = ob.y + hh - self.y
    end
    local x, y   = self.x, self.y+yoff
    local hw     = self.w/2
    -- Choque de este paso contra un cuerpo sólido: { o, face, speed }. Cara
    -- del CUERPO que se tocó ('top', 'bottom', 'left', 'right') y velocidad
    -- con la que se llegó (los trampolines la usan para saber si rebotar).
    self.bodyHit = nil

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

    -- Cuerpos sólidos (p. ej. el jefe espejo): de lado se chocan y se paran,
    -- sin empujones. Desde arriba no (eso es pisar / caer encima).
    local x0 = self.x
    local bodies
    if self.solidAgainst then bodies = self.solidAgainst(level)
    elseif not self:isInvulnerable() then bodies = level.solidBodies
    elseif level.solidBodies then
        -- Invulnerable: atraviesa a los jefes, pero no los objetos sólidos (morteros...)
        bodies = {}
        for _, o in ipairs(level.solidBodies) do if o.solidFull then bodies[#bodies+1] = o end end
    end
    if bodies then
        for _, o in ipairs(bodies) do
            if o ~= self and not o.dying and o.alive ~= false then
                local ob = o:getOuterBounds()
                local myTop, myBot = y - hh, y + hh
                -- Solapan en vertical "de lado": en los sólidos completos (solidFull,
                -- p. ej. el mortero) de verdad; en los demás, sin contar la zona de
                -- la cabeza (eso es pisarlo) ni los pies
                local sideTop = o.solidFull and (ob.y + 1) or (ob.y + ob.h * 0.35 + 10)
                local sideBot = o.solidFull and (ob.y + ob.h - 1) or (ob.y + ob.h - 8)
                if myBot > sideTop and myTop < sideBot
                   and x + hw > ob.x and x - hw < ob.x + ob.w then
                    local was = x0 + hw > ob.x and x0 - hw < ob.x + ob.w
                    if not was and dx ~= 0 then
                        -- Choque al moverse: se queda pegado a su costado
                        x = (dx > 0) and (ob.x - hw) or (ob.x + ob.w + hw)
                        self.bodyHit = { o = o, face = (dx > 0) and 'left' or 'right', speed = math.abs(self.vx) }
                        self.vx = 0
                    elseif was then
                        -- Ya estaban metidos (p. ej. cayó a su lado): se separan
                        -- poco a poco, sin atravesar paredes
                        local dir = (x < ob.x + ob.w / 2) and -1 or 1
                        if dx * dir < 0 then x = x - dx end        -- no avanzar hacia dentro
                        local nx = x + dir * 3
                        if not level:collisionAt(nx + dir * hw, y) then x = nx end
                        if (self.vx or 0) * dir < 0 then self.vx = 0 end
                    end
                end
            end
        end
    end

    -- Zona de jefe activa: paredes invisibles (no se puede salir del área).
    -- La zona se mira desde donde ESTABA: ningún empujón la atraviesa.
    local arena = level.arenaAt and (level:arenaAt(x0, y) or level:arenaAt(x, y))
    if arena then
        if x - hw < arena.x0 then x = arena.x0 + hw; self.vx = 0 end
        if x + hw > arena.x1 then x = arena.x1 - hw; self.vx = 0 end
    end

    -- Y
    local prevFoot = self.y + yoff - OUTER_YOFF + hh     -- (misma referencia que de pie)
    y = y + dy
    self.onGround = false
    self.groundDef = nil
    local chx = {x-hw+4, x, x+hw-4}
    if dy > 0 then
        for _,px in ipairs(chx) do
            -- (una losa fina cuenta desde su cara hasta el fondo de la celda: un
            -- paso rápido no la atraviesa; abajo se comprueba que venía de arriba)
            local t = level:collisionAt(px, y+hh, true) or level:onewayCellAt(px, y+hh)
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
        -- El centro primero: si hay un bloque rompible sobre la cabeza, es el que se rompe
        for _,px in ipairs({x, x-hw+4, x+hw-4}) do
            local t = level:collisionAt(px, y-hh)
            if t then
                local edge = t.fullHitbox and math.ceil((y-hh)/T)*T
                             or math.floor((y-hh)/T)*T + (t.hitbox.y + t.hitbox.h)*T
                y = edge + hh; self.vy=0
                -- Cabezazo: rompe bloques rompibles y cambia los ON/OFF (desde abajo)
                local c, r = math.floor(px/T)+1, math.floor((y-hh-2)/T)+1
                local how = (t.breakable or t.toggle) and level:hitTile(c, r)
                if how == 'break' then
                    fx(self, 'block_break', (c-1)*T, (r-1)*T)
                elseif how == 'toggle' then
                    fx(self, 'switch_hit', (c-1)*T, (r-1)*T)
                elseif not self.crouching then       -- (saltitos agachado en un túnel: sin "bonk")
                    Sound.play('headBump')
                end
                break
            end
        end
    end

    -- Sólidos completos (solidFull): se puede estar de pie encima y darse con
    -- la cabeza por debajo, como con un bloque
    if bodies then
        local footWas = self.y + yoff + hh
        local headWas = self.y + yoff - hh
        for _, o in ipairs(bodies) do
            if o.solidFull and o ~= self and o.alive ~= false then
                local ob = o:getOuterBounds()
                if x + hw - 2 > ob.x and x - hw + 2 < ob.x + ob.w then
                    if dy > 0 and footWas <= ob.y + 2 and y + hh >= ob.y then
                        self.bodyHit = { o = o, face = 'top', speed = self.vy }
                        y = ob.y - hh; self.vy = 0; self.onGround = true; self.jumpsLeft = 2
                        self.groundDef = nil
                    elseif dy < 0 and headWas >= ob.y + ob.h - 2 and y - hh <= ob.y + ob.h then
                        self.bodyHit = { o = o, face = 'bottom', speed = -self.vy }
                        y = ob.y + ob.h + hh; self.vy = 0
                        if not o.bouncyFace then Sound.play('headBump') end
                    end
                end
            end
        end
    end

    -- Techo invisible de la zona de jefe
    if arena and y - hh < arena.y0 then y = arena.y0 + hh; if self.vy < 0 then self.vy = 0 end end

    self.x, self.y = x, y-yoff

    -- Fin de la bajada: los pies ya pasaron la zona en la que la plataforma
    -- volvería a "atraparlos" (prevFoot se mide OUTER_YOFF más arriba que los
    -- pies reales, más el margen de 2px del aterrizaje), o aterrizó en otra cosa.
    if self.dropping and (self.onGround or y + hh > self.dropTop + OUTER_YOFF + 4) then
        self.dropping = false
    end

    -- Contacto (hitbox interna) con materiales que matan o dañan
    local iw2, ih2 = INNER_W/2, INNER_H/2
    local iy = self.y+OUTER_YOFF
    if self.crouching then                      -- agachado: la caja interna baja
        local ib = self:getInnerBounds()
        ih2, iy = ib.h/2, ib.y + ib.h/2
    end
    local corners={
        {x-iw2+2,iy-ih2+2},{x+iw2-2,iy-ih2+2},
        {x-iw2+2,iy+ih2-2},{x+iw2-2,iy+ih2-2},
    }
    for _,c in ipairs(corners) do
        local t = level:contactAt(c[1],c[2])
        if t then
            if t.mat.contact == 'kill' and self:die() ~= false then return end
            if t.mat.contact == 'hurt' and self:hurt() then return end
        end
    end

    -- Pinchos: usar outer bounds contra getSpikesInBox
    local ob = self:getOuterBounds()
    local spikeList = level:getSpikesInBox(ob.x, ob.y, ob.w, ob.h)
    for _, sp in ipairs(spikeList) do
        if spikeHitsPlayer(sp, ob) and self:die() ~= false then return end
    end

    -- Líquidos
    self.liquid  = level:liquidInBox(ob.x, ob.y, ob.w, ob.h)
    self.inWater = self.liquid ~= nil
    if self.inWater and self.onGround then self.jumpsLeft=2 end
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
function PlayerAdventure:isInvulnerable() return (self.invT or 0) > 0 end
-- Da invulnerabilidad `t` s (se queda con la que dure más)
function PlayerAdventure:grantInvulnerability(t)
    self.invT = math.max(self.invT or 0, t)
end
-- ¿No se le puede empujar ahora? Invulnerable, salvo el empujón que acompaña
-- al MISMO golpe (hitNow: solo durante el paso en que lo recibió)
function PlayerAdventure:isPushProtected()
    return self:isInvulnerable() and not self.hitNow
end

function PlayerAdventure:takeDamage()
    if self.dying or not self.alive or self:isInvulnerable() then return false end
    self.hp=self.hp-1
    if self.hp<=0 then self.hp=self.hpMax; self:die(); return true end
    Sound.play('dies'); return false
end

-- Golpe de `n` de vida (1 por defecto): tiles 'hurt', entidades onTouch='hurt',
-- jefes... Si no lo mata, queda invulnerable HIT_INV s. true si lo mató.
function PlayerAdventure:hurt(n)
    if self.dying or not self.alive or self:isInvulnerable() then return false end
    for _ = 1, math.max(1, n or 1) do
        if self:takeDamage() then return true end
    end
    self:grantInvulnerability(HIT_INV)
    self.hurtT, self.hitNow = HURT_FLASH, true
    return false
end

-- Devuelve false si no murió (invulnerable tras reaparecer). `force` = muere
-- igual (límite de tiempo del nivel).
function PlayerAdventure:die(drownDeath, force)
    if self.dying then return end
    if self:isInvulnerable() and not drownDeath and not force then return false end
    self.dying=true; self.vx=0; self.vy=0
    self.gpPhase=nil; self.stunT=0; self.squashT=0
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
    self.splashSt='out'; self.splashCD=0
    self.gpPhase=nil; self.gpT=0; self.gpLanded=false; self.stunT=0; self.squashT=0; self.ctrlLockT=0
    self:grantInvulnerability(SPAWN_INV)
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

-- ── Splash al entrar / salir del agua ────────────────────────────────────────
-- splashSt: 'out'      fuera del líquido
--           'wading'   pies dentro, la cabeza aún no se ha hundido
--           'under'    cabeza sumergida
--           'surfaced' sacó la cabeza (para respirar) pero sigue en el agua
-- Suena al tocar el agua con los pies, al SACAR LA CABEZA (no hace falta
-- salir del todo) y al volver a hundirla. Margen de unos píxeles y un
-- intervalo mínimo para que flotar en la superficie no dispare repeticiones.
local SPLASH_HYST = 5       -- px por encima/debajo de la superficie
local SPLASH_MIN  = 0.25    -- s entre dos splashes

local function playSplash(self, liq, which)
    if not liq or self.splashCD > 0 then return end
    local name = (which == 'in') and liq.splashIn or liq.splashOut
    if name then Sound.play(name); self.splashCD = SPLASH_MIN end
end

function PlayerAdventure:updateSplash(dt, level)
    self.splashCD = math.max(0, (self.splashCD or 0) - dt)
    local st = self.splashSt or 'out'
    if not self.inWater then
        if st == 'under' or st == 'wading' then playSplash(self, self.prevLiquid, 'out') end
        self.splashSt = 'out'
        return
    end
    local hx, hy = self:getHeadPoint()
    local headUnder = level:liquidAt(hx, hy - SPLASH_HYST) ~= nil   -- claramente bajo el agua
    local headOut   = level:liquidAt(hx, hy + SPLASH_HYST) == nil   -- claramente fuera
    if st == 'out' then
        playSplash(self, self.liquid, 'in')
        st = headUnder and 'under' or 'wading'
    elseif st == 'wading' then
        if headUnder then st = 'under' end
    elseif st == 'under' then
        if headOut then playSplash(self, self.liquid, 'out'); st = 'surfaced' end
    elseif st == 'surfaced' then
        if headUnder then playSplash(self, self.liquid, 'in'); st = 'under' end
    end
    self.splashSt = st
end

-- ── Cuenta regresiva de ahogamiento (estilo Sonic) ──────────────────────────
-- Mientras suena drowning.ogg, su duración se reparte en 6 tramos: 5,4,3,2,1,0.
local COUNTDOWN_FROM = 5

function PlayerAdventure:drownCountdown()
    if self.drownPhase ~= 'drowning' or self.dying then return nil end
    local step = DROWN_AUDIO_DUR / (COUNTDOWN_FROM + 1)
    local k    = math.floor(self.drownAudT / step)
    return math.max(0, COUNTDOWN_FROM - k), (self.drownAudT - k * step) / step
end

-- Número junto al jugador, en pantalla (sx, sy = centro del jugador en pantalla).
-- Solo lo ve el propio jugador (lo dibuja el HUD local).
function PlayerAdventure:renderDrownCountdown(sx, sy)
    local n, f = self:drownCountdown()
    if not n then return end
    local text = tostring(n)
    local pop  = 1 + 0.6 * math.max(0, 1 - f / 0.15)      -- salta al cambiar
    local x, y = math.floor(sx + 46), math.floor(sy - 70)
    love.graphics.setFont(FONT_BIG)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(pop * 1.5, pop * 1.5)
    local w, h = FONT_BIG:getWidth(text), FONT_BIG:getHeight()
    love.graphics.setColor(0, 0, 0, 1)
    for _, o in ipairs({ {-2,0},{2,0},{0,-2},{0,2},{-2,-2},{2,2},{-2,2},{2,-2} }) do
        love.graphics.print(text, -w / 2 + o[1], -h / 2 + o[2])
    end
    if n <= 1 then love.graphics.setColor(1, 0.3, 0.3, 1) else love.graphics.setColor(1, 1, 1, 1) end
    love.graphics.print(text, -w / 2, -h / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
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

-- ── Ground pound ──────────────────────────────────────────────────────────────
function PlayerAdventure:updateGroundPound(dt, level)
    self.gpT = self.gpT + dt
    self.vx = 0
    if self.gpPhase == 'windup' then
        -- Suspendido: sin gravedad ni desplazamiento (sí contactos: pinchos, agua...)
        self.vy = 0
        self:moveAndCollide(level, 0, 0)
        if self.dying then return end
        if self.gpT >= GP_WINDUP then self.gpPhase, self.gpT = 'fall', 0 end
    else
        self.vy = GP_SPEED * (self.inWater and GP_WATER or 1)
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.dying then return end
        if self.onGround then
            -- Bloques rompibles bajo los pies: se rompen y sigue cayendo. Los
            -- ON/OFF cambian (una vez cada uno) y el impacto es normal.
            local T  = TILE_PX
            local ob = self:getOuterBounds()
            local footY, broke, done = ob.y + ob.h + 2, false, {}
            for _, px in ipairs({ self.x - self.w/2 + 4, self.x, self.x + self.w/2 - 4 }) do
                local t = level:getDefAt(px, footY)
                local c, r = math.floor(px/T)+1, math.floor(footY/T)+1
                if (t.breakable or t.toggle) and not done[c] then
                    done[c] = true
                    local how = level:hitTile(c, r)
                    if how == 'break' then
                        broke = true
                        fx(self, 'block_break', (c-1)*T, (r-1)*T)
                    elseif how == 'toggle' then
                        fx(self, 'switch_hit', (c-1)*T, (r-1)*T)
                    end
                end
            end
            if broke then
                self.onGround = false
            else
                -- Impacto
                self.gpPhase, self.gpT = nil, 0
                self.gpLanded  = true
                self.jumpsLeft = 2
                self.puff      = PUFF_SCALE
                Sound.play('gpImpact')
                fx(self, 'gp_land', self.x, ob.y + ob.h)
            end
        end
    end
    self:updateSplash(dt, level)
    self.prevInWater = self.inWater
    self.prevLiquid  = self.liquid
    self.frame, self.animT = 2, 0            -- monstrito2 quieto, sin mover brazos
    self.puff = self.puff + (1 - self.puff) * PUFF_SPD * dt
    self:updateDrowning(dt, level)
    self:updateAirBarAnim(dt)
end

-- Rebote tras pisotear (termina el ground pound y recarga el doble salto)
function PlayerAdventure:bounce(vy, dirX, soft)
    self.vy = vy; self.jumpsLeft = 2; self.onGround = false
    self.gpPhase, self.gpT = nil, 0
    -- Pisotón de lado (Crabby en una pared): sale despedido hacia fuera, un
    -- instante sin control pero sin aturdirse
    if dirX and soft then
        self.vx = dirX * 300
        self.ctrlLockT = math.max(self.ctrlLockT or 0, 0.12)
        return
    end
    -- Rebote con empujón lateral (p. ej. un jefe invulnerable): no se puede
    -- quedar rebotando encima; un instante sin control para que se note
    if dirX then
        self.vx = dirX * 460
        self.stunT = math.max(self.stunT or 0, 0.18)
    end
end

-- Lanzado por un trampolín: velocidad (vx, vy). Si empuja de lado, un
-- instante sin control para que el impulso no se pierda.
function PlayerAdventure:launch(vx, vy)
    self.vy = vy
    if vx and vx ~= 0 then
        -- Un instante sin control (el impulso no se pierde), pero SIN aturdir
        self.vx = vx
        self.ctrlLockT = math.max(self.ctrlLockT or 0, 0.25)
    end
    self.onGround, self.crouching = false, false
    self.jumpsLeft = 1                       -- queda el salto en el aire
    self.gpPhase, self.gpT = nil, 0
    self.puff = PUFF_SCALE * 1.1
end

-- Aplastado (p. ej. le cae encima un Crabby trampolín): sale empujado a un
-- lado, agachado y aturdido un rato
local SQUASH_T = 1.8
PlayerAdventure.SQUASH_T = SQUASH_T
function PlayerAdventure:squash(dirX)
    if self.dying or self:isPushProtected() then return false end
    self.vx, self.vy = dirX * 560, -240          -- saltito hacia un lado
    self.onGround = false
    self.gpPhase, self.gpT = nil, 0
    self.stunT   = math.max(self.stunT or 0, SQUASH_T)
    self.squashT = SQUASH_T
    Sound.play('stunned')
    return true
end

-- Empujón de un ground pound cercano: sale despedido y queda aturdido
function PlayerAdventure:knockback(dirX)
    if self.dying or self:isPushProtected() then return end
    self.vx, self.vy = dirX * GP_PUSH_VX, GP_PUSH_VY
    self.onGround, self.crouching = false, false
    self.gpPhase, self.gpT = nil, 0
    self.stunT = GP_STUN
    Sound.play('stunned')
end

-- Empujón leve al chocar con un cuerpo (p. ej. el jefe espejo): sale
-- rebotado hacia un lado sin quedar aturdido del todo.
local RECOIL_VX, RECOIL_VY, RECOIL_STUN = 520, -300, 0.22
function PlayerAdventure:recoil(dirX)
    if self.dying or self.stunT > 0 or self:isPushProtected() then return false end
    self.vx, self.vy = dirX * RECOIL_VX, RECOIL_VY
    self.onGround, self.crouching = false, false
    self.gpPhase, self.gpT = nil, 0
    self.stunT = RECOIL_STUN
    return true
end

-- ── Update ────────────────────────────────────────────────────────────────────
function PlayerAdventure:update(dt, level)
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
    local r, g, b = PlayerAdventure.hurtTint(self.dying and 0 or self.hurtT)
    love.graphics.setColor(r, g, b, PlayerAdventure.invulnAlpha(not self.dying and self.invT or 0))
    local squashed = not self.dying and (self.squashT or 0) > 0
    if squashed then
        -- Aplastado: agachado y achatado de arriba abajo, con los pies en el suelo
        love.graphics.draw(spriteCrouch, math.floor(self.x-camX), math.floor(self.y-camY+SPRITE_H/2),
            0, s*self.facing, s*SQUASH_K, iw/2, ih)
    else
        love.graphics.draw(img,
            math.floor(self.x-camX), math.floor(self.y-camY),
            0, s*self.facing, s, iw/2, ih/2)
    end
    if self.dying then
        DeadEyes.draw(math.floor(self.x-camX), math.floor(self.y-camY), s, self.facing)
    elseif (self.stunT or 0) > 0 then
        PlayerAdventure.drawStunStars(self.x - camX, self.y - camY, squashed)
    end
end

-- Destello rojo al recibir un golpe. También para jugadores remotos.
function PlayerAdventure.hurtTint(hurtT, a)
    if (hurtT or 0) > 0 and math.floor(love.timer.getTime() * 12) % 2 == 0 then
        return 1, 0.22, 0.22, a or 1
    end
    return 1, 1, 1, a or 1
end

-- Parpadeo (transparencia) mientras es invulnerable (por lo que sea)
function PlayerAdventure.invulnAlpha(invT, a)
    if (invT == true or (tonumber(invT) or 0) > 0) and math.floor(love.timer.getTime() * 15) % 2 == 0 then
        return (a or 1) * 0.25
    end
    return a or 1
end

-- Estrellitas girando sobre la cabeza (aturdido). También para jugadores remotos.
-- squashed = aplastado: la cabeza está mucho más abajo (sprite agachado,
-- 9 filas visibles, achatado a SQUASH_K)
function PlayerAdventure.drawStunStars(sx, sy, squashed)
    local t = love.timer.getTime()
    local headY = squashed and (sy + SPRITE_H / 2 - 9 * PLAYER_SCALE * SQUASH_K) or (sy - SPRITE_H / 2)
    for i = 0, 2 do
        local a  = t * 6 + i * (math.pi * 2 / 3)
        local x  = math.floor(sx + math.cos(a) * 22)
        local y  = math.floor(headY - 10 + math.sin(a) * 6)
        love.graphics.setColor(1, 0.9, 0.3, 1)
        love.graphics.rectangle('fill', x - 4, y - 1, 8, 2)
        love.graphics.rectangle('fill', x - 1, y - 4, 2, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
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