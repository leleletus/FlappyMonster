-- src/player/PlayerFlight.lua
-- PARTE de src/player/PlayerAdventure.lua: el VUELO de los niveles Flappy (nivel con `"flappy": true`; la campaña
-- precuela, docs/design/flappy-prequel.md). La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P).
--   · Se aletea con SALTAR (sin límite) y se mueve a los lados a voluntad DENTRO de la ventana de la cámara
--     automática: sin tocar nada, el monstruo va con la ventana (como en un juego de naves), no se queda atrás.
--   · Gravedad y aleteo PROPIOS, más flotantes que los del Flappy de siempre (GRAVITY 1800 / FLAP_VELOCITY -480): el
--     usuario, 0.5.164, "la gravedad es más fuerte de lo que debería".
--   · Hacia ATRÁS (contra la cámara) va más rápido en pantalla: FLY_SPD + lo que avanza la ventana, lo mismo que
--     recorre hacia delante en el mundo (el usuario: hacia la izquierda "todo se siente más pesado y lento").
--   · Sin agacharse, ground pound, cargar ni saltos de plataformas.
--   · Los PILARES (tile `pillar`) no son sólidos: tocarlos quita 1 de vida y la invulnerabilidad deja atravesarlos.
--   · El SUELO (lo sólido por debajo) también hace daño al tocarlo y lo devuelve hacia arriba de un bote; el techo y
--     las paredes solo paran.
-- Es simulación compartida (golden rule 1): lee el Input del paso como el resto del jugador y nada de dibujo.
return function(PlayerAdventure, P)
local PUFF_SCALE, PUFF_SPD, OUTER_W = P.PUFF_SCALE, P.PUFF_SPD, P.OUTER_W

local FLY_SPD    = 330      -- px/s a los lados respecto a la ventana (hacia atrás, más lo que avanza la ventana)
local FLY_GRAVITY = 1350    -- px/s² (el Flappy de siempre: 1800)
local FLY_FLAP    = -450    -- px/s del aleteo (el Flappy de siempre: -480)
local FLY_ACC    = 12       -- lo rápido que llega a esa velocidad (1/s)
local MAX_FALL   = 900      -- px/s cayendo como mucho
local FLOOR_HOP  = -560     -- px/s del bote al tocar el suelo
local GLIDE_FPS  = 6
PlayerAdventure.FLY_SPD, PlayerAdventure.FLOOR_HOP = FLY_SPD, FLOOR_HOP
PlayerAdventure.FLY_GRAVITY, PlayerAdventure.FLY_FLAP = FLY_GRAVITY, FLY_FLAP

-- CARGA del ataque especial (docs/design/flappy-plan-4-attack-and-cages.md): 0..CHARGE_MAX, +1 por cada carga de
-- aleteo (types/items/flapcharge.lua); morir no la quita; cada etapa empieza en 0 (jugador nuevo)
PlayerAdventure.CHARGE_MAX = 5
function PlayerAdventure:addCharge(n)
    self.charge = math.min(PlayerAdventure.CHARGE_MAX, (self.charge or 0) + (n or 1))
end

-- Lo que avanza la ventana de la cámara automática ahora (px/s; 0 si está parada o no hay)
local function windowSpeed(level)
    local a = level and level.autoScroll
    return (a and a.state == 'run') and a.speed or 0
end

-- ── ATAQUE ESPECIAL ────────────────────────────────────────────────────────────
-- ESPECIAL con carga: una RÁFAGA de magia de aleteo sale por delante con potencia = la carga (que se gasta entera) y
-- avanza BURST_SPD px/s hasta BURST_RANGE casillas. "Por delante" = `facing`, la misma regla que al lanzar lo que se
-- carga (systems/Carry): en vuelo, la última dirección que pidió el jugador a los lados (empieza a la derecha; el
-- usuario, 2026-11-08: "solo va hacia la derecha; que salga hacia donde está yendo o estaba por última vez"). La para un bloque SÓLIDO (los pilares no lo son) o una entidad que
-- la absorba (`onSpecialHit(potencia, jugador)` → true: base/Entity.lua — los enemigos mueren —, base/Boss.lua — daño
-- = potencia —, la jaula, el muro agrietado). A cada entidad le da una vez. Estado del jugador (`bursts`), simulado
-- igual en todas partes; se dibuja en renderBursts.
local BURST_SPD, BURST_RANGE, BURST_R = 900, 8, 22
PlayerAdventure.BURST_SPD, PlayerAdventure.BURST_RANGE = BURST_SPD, BURST_RANGE

function PlayerAdventure:fireSpecial()
    if (self.charge or 0) <= 0 then return false end
    self.bursts = self.bursts or {}
    local dir = (self.facing or 1) < 0 and -1 or 1
    self.bursts[#self.bursts + 1] = { x = self.x + dir * OUTER_W / 2, y = self.y, dir = dir, power = self.charge, dist = 0,
                                      hit = {} }
    self.charge = 0
    self.puff = PUFF_SCALE
    Sound.play('gpStart', 1.3)
    return true
end

function PlayerAdventure:updateBursts(dt, level)
    local list = self.bursts
    if not list or #list == 0 then return end
    local range = BURST_RANGE * TILE_PX
    for i = #list, 1, -1 do
        local b = list[i]
        local dir = b.dir or 1
        local dx = BURST_SPD * dt
        b.x, b.dist = b.x + dir * dx, b.dist + dx
        local done = b.dist >= range or (level and level:collisionAt(b.x + dir * BURST_R / 2, b.y) ~= nil)
        if not done and level then
            for _, e in ipairs(level.liveEntities or {}) do
                if e.alive and not b.hit[e] and e.onSpecialHit then
                    local o = e:getOuterBounds()
                    if b.x + BURST_R > o.x and b.x - BURST_R < o.x + o.w and b.y + BURST_R > o.y and b.y - BURST_R < o.y + o.h then
                        b.hit[e] = true
                        if e:onSpecialHit(b.power, self, dir) then done = true; break end
                    end
                end
            end
        end
        if done then table.remove(list, i) end
    end
end

-- (solo dibujo) assets/images/fx/flapburst-Sheet.png: 4 cuadros de 12x12, siempre ×4 (la densidad de los objetos;
-- tools/art/items/make_flappy_items.py)
local burstImg, burstQuads
function PlayerAdventure:renderBursts(camX, camY)
    if not self.bursts or #self.bursts == 0 then return end
    if not burstImg then
        burstImg = love.graphics.newImage('assets/images/fx/flapburst-Sheet.png')
        burstImg:setFilter('nearest', 'nearest')
        burstQuads = {}
        for i = 1, 4 do burstQuads[i] = love.graphics.newQuad((i - 1) * 12, 0, 12, 12, burstImg:getDimensions()) end
    end
    for _, b in ipairs(self.bursts) do
        local f = math.floor(b.dist / 40) % 4 + 1
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(burstImg, burstQuads[f], math.floor(b.x - camX), math.floor(b.y - camY), 0, 4 * (b.dir or 1), 4, 6, 6)
    end
end

function PlayerAdventure:updateFlight(dt, level, pJump, inX)
    self.crouching, self.gpPhase, self.dropping, self.jumpBufT = false, nil, false, 0
    if self.hurtT > 0 then self.hurtT = math.max(0, self.hurtT - dt) end
    local stunned = (self.stunT or 0) > 0 or (self.ctrlLockT or 0) > 0
    if stunned then inX = 0 end

    -- Aleteo: siempre se puede (no gasta saltos)
    if pJump and not stunned then
        self.vy = FLY_FLAP
        self.puff = PUFF_SCALE
        Sound.play('jump')
    end
    if Input.pressed('special') and not stunned then self:fireSpecial() end
    self:updateBursts(dt, level)
    -- A los lados: con la ventana, más lo que pida el jugador (hacia atrás, además, lo que avanza la ventana)
    local ws = windowSpeed(level)
    local want = ws + (inX > 0 and FLY_SPD or (inX < 0 and -(FLY_SPD + ws) or 0))
    self.vx = self.vx + (want - self.vx) * math.min(1, FLY_ACC * dt)
    self.vy = math.min(MAX_FALL, self.vy + FLY_GRAVITY * dt)

    self:moveSteps(level, self.vx * dt, self.vy * dt)
    if self.dying then return end

    -- No se queda atrás: el borde izquierdo de la ventana lo lleva (si no hay un bloque ni un CUERPO sólido en medio
    -- — un muro agrietado intacto —: entonces, la regla de siempre de AutoScroll — quedarse atrás mata —; antes el borde
    -- lo metía dentro del muro y salía por el otro lado sin romperlo: revisión del Plan 4)
    local a = level and level.autoScroll
    if a and a.state == 'run' then
        local minX = a.x + OUTER_W / 2
        local px = minX + OUTER_W / 2
        if self.x < minX and not level:collisionAt(px, self.y) and not level:bodyAt(px, self.y, self) then self.x = minX end
    end

    -- El suelo: daño y bote hacia arriba
    if self.onGround then
        self.onGround = false
        self.vy = FLOOR_HOP
        if not self:isInvulnerable() and self:hurt() then return end
    end

    -- Mira hacia la última dirección que pidió a los lados (la del ataque especial; el dibujo se gira con ella)
    if inX ~= 0 then self.facing = inX end
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
