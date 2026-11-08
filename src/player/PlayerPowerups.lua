-- src/player/PlayerPowerups.lua
-- PARTE de src/player/PlayerAdventure.lua: los EFECTOS de los POWER-UPS (docs/design/powerups.md; el catálogo:
-- src/world/powerups/). La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P). Simulación compartida
-- (golden rule 1): estado del jugador y reglas, sin dibujo (el dibujo: PlayerRender).
--   · usePowerup(id) → true si se aplicó (canUse antes). Quien lo gasta del inventario es quien llama (la rueda).
--   · ESCUDO (`shield`): para el siguiente golpe de CUALQUIER tipo — hurt, takeDamage, die sin `force` (pinchos, lava,
--     ahogarse) —; las muertes FORZADAS (quedarse atrás de la cámara, el límite de tiempo) no las para.
--   · CORAZÓN (`heart`): +1 de vida máxima (y +1 de vida) el resto del nivel; se suman.
--   · Con tiempo (`effects[id]` = segundos que quedan; repetir el mismo reinicia su tiempo): FUERZA (damageMult 2),
--     los IMANES (atraen lo coleccionable a IMAN_R casillas), PEQUEÑO (sizeK 0.5: media caja y medio sprite),
--     FANTASMA (los tiles exclusivos de Flappy que hacen daño — los pilares — no le tocan; si se acaba dentro de uno,
--     queda invulnerable un momento en vez de recibir el golpe).
return function(PlayerAdventure, P)
local OUTER_YOFF, INNER_W, INNER_H, HURT_FLASH = P.OUTER_YOFF, P.INNER_W, P.INNER_H, P.HURT_FLASH

local IMAN_R, IMAN_SPD = 4, 640          -- casillas de alcance, px/s a los que vienen
local GHOST_OUT_INV = 1.0                -- s invulnerable al acabarse el fantasma dentro de un pilar
local SMALL_K = 0.5
PlayerAdventure.IMAN_R, PlayerAdventure.SMALL_K = IMAN_R, SMALL_K

function PlayerAdventure:hasEffect(id) return ((self.effects or {})[id] or 0) > 0 end

-- ¿Se puede usar ahora? (la rueda apaga los que no: nunca se gasta uno por error)
function PlayerAdventure:canUse(id)
    if self.dying or not self.alive then return false end
    if id == 'shield' then return not self.shield end
    if id == 'magnet_points' or id == 'magnet_items' then return not self:hasEffect('magnet_all') end
    return require('src/world/powerups/Powerups').get(id) ~= nil
end

function PlayerAdventure:usePowerup(id)
    if not self:canUse(id) then return false end
    local def = require('src/world/powerups/Powerups').get(id)
    self.effects = self.effects or {}
    if id == 'shield' then
        self.shield = true
    elseif id == 'heart' then
        self.hpMax = (self.hpMax or 3) + 1
        self.hp = math.min(self.hpMax, (self.hp or 0) + 1)
    elseif def.duration then
        self.effects[id] = def.duration
        if id == 'magnet_all' then self.effects.magnet_points, self.effects.magnet_items = nil, nil end
    end
    self.puff = P.PUFF_SCALE
    Sound.play('checkpoint', 1.2)
    return true
end

-- El daño que hace el jugador (la ráfaga del ataque especial a los jefes; más adelante, los pisotones en Aventura)
function PlayerAdventure:damageMult() return self:hasEffect('strength') and 2 or 1 end

-- El escudo se rompe parando un golpe: invulnerable como tras un golpe, destello, sin perder nada
function PlayerAdventure:breakShield()
    self.shield = false
    self:grantInvulnerability(1.6 * require('src/core/Difficulty').k('invuln'))
    self.hurtT, self.hitNow = HURT_FLASH, true
    Sound.play('iceBreak', 1.3)
end

-- ¿Los tiles exclusivos de Flappy que hacen daño (los pilares) tocan su caja interna?
local function inFlappyHazard(self, level)
    local ib = self:getInnerBounds()
    for _, c in ipairs({ { ib.x + 2, ib.y + 2 }, { ib.x + ib.w - 2, ib.y + 2 }, { ib.x + 2, ib.y + ib.h - 2 }, { ib.x + ib.w - 2, ib.y + ib.h - 2 } }) do
        local t = level:contactAt(c[1], c[2])
        if t and t.flappyOnly and t.mat.contact == 'hurt' then return true end
    end
    return false
end

-- Cada paso (vivo): los tiempos, el tamaño, el fin del fantasma y los imanes
function PlayerAdventure:tickEffects(dt, level)
    local fx = self.effects
    if not fx then return end
    local ghostWas = (fx.ghost or 0) > 0
    for k, t in pairs(fx) do
        t = t - dt
        fx[k] = (t > 0) and t or nil
    end
    if ghostWas and not fx.ghost and level and inFlappyHazard(self, level) then self:grantInvulnerability(GHOST_OUT_INV) end
    -- tamaño: media caja (w, h; la caja interna y el dibujo leen sizeK)
    local k = fx.small and SMALL_K or 1
    if k ~= (self.sizeK or 1) then
        self.sizeK = k
        self.w, self.h = P.OUTER_W * k, P.OUTER_H * k
    end
    -- imanes
    local pts, items = fx.magnet_points or fx.magnet_all, fx.magnet_items or fx.magnet_all
    if (pts or items) and level then
        local R = IMAN_R * TILE_PX
        for _, e in ipairs(level.liveEntities or {}) do
            local pk = e.alive and e.state ~= 'dead' and e.def and e.def.pickup
            if pk then
                local isItem = pk.lives or pk.heal or pk.charge
                if (isItem and items) or (not isItem and pk.score and pts) then
                    local dx, dy = self.x - e.x, self.y - e.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d > 1 and d <= R then
                        local m = math.min(d, IMAN_SPD * dt)
                        e.x, e.y = e.x + dx / d * m, e.y + dy / d * m
                    end
                end
            end
        end
    end
end

-- ¿Este tile le hace daño ahora? (el fantasma atraviesa los exclusivos de Flappy)
function PlayerAdventure:ghostPasses(t) return t.flappyOnly == true and self:hasEffect('ghost') end
end
