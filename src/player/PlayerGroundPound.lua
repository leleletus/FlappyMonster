-- src/player/PlayerGroundPound.lua
-- PARTE de src/player/PlayerAdventure.lua: el ground pound (preparación, caída, aterrizaje y empujón) y estar congelado en hielo.
-- La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P): añade sus funciones a la tabla PlayerAdventure. P = lo que
-- antes eran locales del archivo y comparten las partes.
local Noise = require 'src/world/systems/Noise'       -- (ruidos que oyen los enemigos: pasos, saltos, ground pound...)

return function(PlayerAdventure, P)
local PUFF_SCALE, PUFF_SPD, GP_WINDUP, GP_SPEED, GP_WATER, GP_PUSH_VX = P.PUFF_SCALE, P.PUFF_SPD, P.GP_WINDUP, P.GP_SPEED, P.GP_WATER, P.GP_PUSH_VX
local GP_PUSH_VY, GP_STUN, fx = P.GP_PUSH_VY, P.GP_STUN, P.fx

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
                if (t.breakable or t.toggle or t.thinIce) and not done[c] then
                    done[c] = true
                    local how = level:hitTile(c, r, 'pound')
                    if how == 'break' then
                        broke = true
                        if not t.thinIce then fx(self, 'block_break', (c-1)*T, (r-1)*T) end   -- (hielo: crackIce)
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
                Sound.play('gpImpact'); Noise.emit(self.x, self.y, Noise.R.pound)
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
-- `jumps` = saltos que le quedan en el aire (por defecto 1; el cristal roto
-- de los jefes los recarga todos)
function PlayerAdventure:launch(vx, vy, jumps)
    self.vy = vy
    if vx and vx ~= 0 then
        -- Un instante sin control (el impulso no se pierde), pero SIN aturdir
        self.vx = vx
        self.ctrlLockT = math.max(self.ctrlLockT or 0, 0.25)
    end
    self.onGround, self.crouching = false, false
    self.jumpsLeft = jumps or 1              -- queda el salto en el aire
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

-- Congelado (chorro del congelador, types/cryo.lua): dentro de un bloque de hielo
-- `t` s, sin control (la gravedad sigue y resbala lo que traía). Cada pulsación
-- (saltar o agacharse: lo único "recién pulsado" que viaja por red) le quita ICE_MASH s; al acabar se rompe el hielo y
-- queda invulnerable un instante (no lo vuelve a congelar el mismo chorro).
local ICE_MASH, ICE_FREE_INV = 0.22, 0.7
function PlayerAdventure:freeze(t)
    if self.dying or not self.alive or self:isInvulnerable() or (self.iceT or 0) > 0 then return false end
    self.iceT = t or 3
    self.gpPhase, self.gpT = nil, 0
    self.dropping, self.dropHoldT = false, 0
    self.vy = math.max(self.vy, -100)
    Sound.play('cryoFreeze')
    fx(self, 'ice_freeze', self.x, self.y)
    return true
end

P.ICE_FREE_INV = ICE_FREE_INV; P.ICE_MASH = ICE_MASH
end
