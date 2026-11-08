-- src/player/PlayerFlight.lua
-- PARTE de src/player/PlayerAdventure.lua: el VUELO de los niveles Flappy (nivel con `"flappy": true`; la campaña
-- precuela, docs/design/flappy-prequel.md). La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P).
--   · Se aletea con SALTAR (sin límite, como en el Flappy de siempre: misma gravedad GRAVITY y mismo aleteo
--     FLAP_VELOCITY de settings.lua) y se mueve a los lados a voluntad DENTRO de la ventana de la cámara automática:
--     sin tocar nada, el monstruo va con la ventana (como en un juego de naves), no se queda atrás.
--   · Sin agacharse, ground pound, cargar ni saltos de plataformas.
--   · Los PILARES (tile `pillar`) no son sólidos: tocarlos quita 1 de vida y la invulnerabilidad deja atravesarlos.
--   · El SUELO (lo sólido por debajo) también hace daño al tocarlo y lo devuelve hacia arriba de un bote; el techo y
--     las paredes solo paran.
-- Es simulación compartida (golden rule 1): lee el Input del paso como el resto del jugador y nada de dibujo.
return function(PlayerAdventure, P)
local PUFF_SCALE, PUFF_SPD, OUTER_W = P.PUFF_SCALE, P.PUFF_SPD, P.OUTER_W

local FLY_SPD    = 330      -- px/s a los lados respecto a la ventana
local FLY_ACC    = 12       -- lo rápido que llega a esa velocidad (1/s)
local MAX_FALL   = 900      -- px/s cayendo como mucho
local FLOOR_HOP  = -560     -- px/s del bote al tocar el suelo
local GLIDE_FPS  = 6
PlayerAdventure.FLY_SPD, PlayerAdventure.FLOOR_HOP = FLY_SPD, FLOOR_HOP

-- Lo que avanza la ventana de la cámara automática ahora (px/s; 0 si está parada o no hay)
local function windowSpeed(level)
    local a = level and level.autoScroll
    return (a and a.state == 'run') and a.speed or 0
end

function PlayerAdventure:updateFlight(dt, level, pJump, inX)
    self.crouching, self.gpPhase, self.dropping, self.jumpBufT = false, nil, false, 0
    if self.hurtT > 0 then self.hurtT = math.max(0, self.hurtT - dt) end
    local stunned = (self.stunT or 0) > 0 or (self.ctrlLockT or 0) > 0
    if stunned then inX = 0 end

    -- Aleteo: siempre se puede (no gasta saltos)
    if pJump and not stunned then
        self.vy = FLAP_VELOCITY
        self.puff = PUFF_SCALE
        Sound.play('jump')
    end
    -- A los lados: con la ventana, más lo que pida el jugador
    local want = windowSpeed(level) + inX * FLY_SPD
    self.vx = self.vx + (want - self.vx) * math.min(1, FLY_ACC * dt)
    self.vy = math.min(MAX_FALL, self.vy + GRAVITY * dt)

    self:moveSteps(level, self.vx * dt, self.vy * dt)
    if self.dying then return end

    -- No se queda atrás: el borde izquierdo de la ventana lo lleva (si no hay un bloque en medio: entonces, la regla
    -- de siempre de AutoScroll — quedarse atrás mata —)
    local a = level and level.autoScroll
    if a and a.state == 'run' then
        local minX = a.x + OUTER_W / 2
        if self.x < minX and not level:collisionAt(minX + OUTER_W / 2, self.y) then self.x = minX end
    end

    -- El suelo: daño y bote hacia arriba
    if self.onGround then
        self.onGround = false
        self.vy = FLOOR_HOP
        if not self:isInvulnerable() and self:hurt() then return end
    end

    self.facing = 1
    if self.vy < 0 then
        self.frame, self.animT = 2, 0
    else
        self.animT = (self.animT or 0) + dt
        if self.animT >= 1 / GLIDE_FPS then
            self.animT = self.animT - 1 / GLIDE_FPS
            self.frame = (self.frame == 1) and 3 or 1
        end
    end
    self.puff = self.puff + (1 - self.puff) * PUFF_SPD * dt
end

end
