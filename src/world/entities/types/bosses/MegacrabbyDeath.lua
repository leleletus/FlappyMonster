-- src/world/entities/types/bosses/MegacrabbyDeath.lua
-- La MUERTE del Mega Crabby (megacrabby.lua): patalea o forcejea, se levanta aturdido y huye gigante.
-- La carga megacrabby.lua con require(...)(Mega, P): añade sus funciones a la misma tabla. P = lo que antes eran locales del
-- archivo compartidos (docs/architecture/project-structure.md, «Split files»).
return function(Mega, P)
local Boss, DAZE_T, Entity, FLEE_HOP_VY, FLEE_JUMP_MAX, FLEE_SPEED = P.Boss, P.DAZE_T, P.Entity, P.FLEE_HOP_VY, P.FLEE_JUMP_MAX, P.FLEE_SPEED
local FLEE_T, GETUP_MAX, GETUP_T, KICK_T, STAND_T = P.FLEE_T, P.GETUP_MAX, P.GETUP_T, P.KICK_T, P.STAND_T

-- ── Muerte: patalea (o forcejea de pie), se levanta, aturdido, y huye gigante ──
function Mega:defeat()
    self.defeatFrom = self.state             -- (de dónde: boca abajo, de pie, con las pinzas congeladas)
    return Boss.defeat(self)
end
function Mega:onDefeat()
    -- boca abajo (cayó de cabeza) → patalea y se da la vuelta; de pie → forcejea de pie, sin darse la vuelta
    -- ('dying_iced' si tenía las pinzas congeladas: el helado; se le rompe el hielo al soltarse)
    local st = self.flipped and 'dying_kick' or 'dying_stand'
    if not self.flipped and self.defeatFrom == 'clap_stuck' then st = 'dying_iced' end
    self.state, self.deadTimer = st, 0
    self.nextSqueak = 0
    self.defeatedMinions = false
end

function Mega:update(dt, level)
    if self.state:sub(1, 6) == 'dying_' then return self:updateDeath(dt, level) end
    return Boss.update(self, dt, level)
end

function Mega:updateDeath(dt, level)
    self.deadTimer = self.deadTimer + dt
    local st, t = self.state, self.deadTimer
    -- Sus súbditos desaparecen con él
    if not self.defeatedMinions then
        self.defeatedMinions = true
        for _, e in ipairs(self:minions(level)) do
            if e.alive and e.state ~= 'dead' then
                e.state, e.deadTimer, e.vx, e.vy = 'dead', 0, 0, 0
                if e.onStomp then e:onStomp() end
                Entity.emitFx('smoke', e.x, e.y)
                Entity.emitFx('spawn', e.x, e.y)
            end
        end
    end
    if st == 'dying_kick' or st == 'dying_stand' or st == 'dying_iced' then
        if t >= self.nextSqueak then
            self.nextSqueak = t + 0.28
            Sound.play('megaClack', 0.9 + math.random() * 0.4)
        end
        if st == 'dying_kick' and t >= KICK_T then
            -- se da la vuelta de un salto (como al levantarse en la pelea), aún gigante
            self.state, self.deadTimer = 'dying_getup', 0
            self.vy, self.onGround, self.flipped = -480, false, false
            Sound.play('crabPop', 0.7)
            Entity.emitFx('spike_pop', self.x, self.floorY - 8)
        elseif st ~= 'dying_kick' and t >= STAND_T then
            self:onStandFree()
            self.state, self.deadTimer = 'dying_daze', 0
            Sound.play('megaShrink', 0.8)
        end
    elseif st == 'dying_getup' then
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        self:clampToZone()
        if (self.onGround and t >= GETUP_T * 0.6) or t >= GETUP_MAX then
            self.state, self.deadTimer = 'dying_daze', 0
            self.floorY = self.y + self.outerH / 2
            Sound.play('megaShrink', 0.8)
            Entity.emitFx('mega_land', self.x, self.floorY)
        end
    elseif st == 'dying_daze' then
        self:walk(level, dt, 0)
        if t >= DAZE_T then
            -- huye por el lado más cercano de la zona (sus paredes ya se van), trepando por lo que haya
            self.fleeDir = self:fleeSide(level)
            self.facing, self.fleeing, self.crawl = self.fleeDir, true, false
            self.leftBoundPx, self.rightBoundPx = -1e9, 1e9          -- (fuera de la zona: sin límites de ruta)
            self.state, self.deadTimer, self.nextSqueak = 'dying_flee', 0, 0
        end
    elseif st == 'dying_flee' then
        self:fleeStep(level, dt)
        self:animWalk(dt, 14, true)
        if t >= self.nextSqueak then
            self.nextSqueak = t + 0.45
            Sound.play('megaFlee', 0.8 + math.random() * 0.2)
        end
        if self:fleeOver(level, dt, t, FLEE_T) then self.state, self.alive = 'dead', false end
    end
end

-- Un paso de la huida: anda hacia fleeDir con gravedad; una pared delante (de hasta FLEE_JUMP_MAX casillas) la
-- salta justo por encima; si el suelo se acaba delante (escalones que bajan, un borde) salta hacia delante y baja
-- de una vez. En el aire sigue avanzando.
function Mega:fleeStep(level, dt)
    local d, T = self.fleeDir or self.facing or 1, TILE_PX
    local was = self.onGround
    local moved = self:walk(level, dt, d * FLEE_SPEED)
    self.facing = d                                           -- (moveAndCollide lo da la vuelta al chocar)
    if not (was and self.onGround) then return end
    local feet = self.y + self.outerH / 2
    local front = self.x + d * (self.outerW / 2 + 6)
    -- (lo normal: salta con antelación, calculado con su velocidad, y pasa por encima sin rozar la pared)
    local vy = self:jumpAhead(level, d, FLEE_SPEED, ADV_GRAVITY, FLEE_JUMP_MAX, self.outerW / 2, feet)
    if vy then
        self.vy, self.onGround = vy, false
        Sound.play('crabPop', 0.6)
    elseif math.abs(moved) < FLEE_SPEED * dt * 0.5 then
        -- pared: ¿cuánto sube? (casillas sólidas seguidas desde los pies)
        local h = 0
        while h < FLEE_JUMP_MAX and level:entitySolidAt(front, feet - 8 - h * T) do h = h + 1 end
        if h > 0 and h < FLEE_JUMP_MAX then
            self.vy = -math.sqrt(2 * ADV_GRAVITY * (h * T + 40))
            self.onGround = false
            Sound.play('crabPop', 0.6)
        end
    elseif not level:entitySolidAt(front, feet + 8) and not level:entitySolidAt(self.x + d * self.outerW * 0.25, feet + 8) then
        self.vy, self.onGround = FLEE_HOP_VY, false            -- (baja de un salto)
    end
end
-- (el helado: se le rompe el hielo de las pinzas al soltarse)
function Mega:onStandFree() end
Mega.STAND_T = STAND_T

end
