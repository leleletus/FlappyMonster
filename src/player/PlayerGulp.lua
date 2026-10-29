-- src/player/PlayerGulp.lua
-- PARTE de src/player/PlayerAdventure.lua: TRAGADO por una Planta carnívora (types/enemies/carnivoreplant.lua; 0.5.97,
-- el usuario: "la planta también se come al jugador, como a los escarabajos, y hay que MACHACAR todos los botones para
-- salir"). La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P).
--   · `gulped` = dentro de la planta: no se ve (solo la ayuda de machacar encima, PlayerAdventure.drawMashPrompt), no
--     se mueve (se queda en la boca de la planta, por fuera de su bloque), no toca nada (Interactions.run) y nada le
--     hace daño salvo la planta (isInvulnerable).
--   · Cada pulsación de un botón (saltar, agacharse, ARRIBA, la linterna: lo "recién pulsado" que viaja por red) suma
--     una (`gulpMash`); con GULP_MASH lo ESCUPE hacia fuera de su bloque (`gulpNx, gulpNy`) e invulnerable GULP_FREE_INV s.
--   · Dentro, cada GULP_BITE s (`gulpBiteT`) pierde 1 de vida (con el destello); si llega a 0, muere como siempre.
-- Es estado PROPIO del jugador (Protocol.packOwnState: bandera F_GULP e índices 35-38): el servidor lo traga (la planta
-- solo vive allí) y el cliente lo predice igual que el hielo (iceT); los demás lo ven con PF_GULP (no lo dibujan).
return function(PlayerAdventure, P)
local fx, OUTER_W, OUTER_H, OUTER_YOFF, HURT_FLASH = P.fx, P.OUTER_W, P.OUTER_H, P.OUTER_YOFF, P.HURT_FLASH

local GULP_MASH     = 10       -- pulsaciones para salir
local GULP_BITE     = 1.75     -- s entre dos mordiscos (−1 de vida)
local GULP_FREE_INV = 1.2      -- s invulnerable al salir
local SPIT_V        = 640      -- px/s al salir escupido (hacia fuera del bloque de la planta)
PlayerAdventure.GULP_MASH, PlayerAdventure.GULP_BITE = GULP_MASH, GULP_BITE

-- ¿Se le puede tragar ahora? (ni muriendo, ni invulnerable, ni congelado, ni ya tragado)
function PlayerAdventure:canBeSwallowed()
    return not self.dying and self.alive ~= false and not self:isInvulnerable() and (self.iceT or 0) <= 0 and not self.gulped
end

-- Tragado por una planta cuya base está en (bx, by) con la normal (nx, ny) hacia fuera de su bloque: se queda justo
-- delante de ella (su caja tocando la cara del bloque, por fuera), quieto. true si se lo tragó.
function PlayerAdventure:swallow(bx, by, nx, ny)
    if not self:canBeSwallowed() then return false end
    nx, ny = nx or 0, ny or -1
    local x, y = bx, by
    if ny < 0 then y = by - (OUTER_YOFF + OUTER_H / 2) - 1                  -- (en el suelo: los pies en la cara)
    elseif ny > 0 then y = by + (OUTER_H / 2 - OUTER_YOFF) + 1              -- (en el techo: la cabeza)
    else x, y = bx + nx * (OUTER_W / 2 + 1), by - OUTER_YOFF end            -- (en una pared: de lado)
    self.x, self.y, self.vx, self.vy = x, y, 0, 0
    self.gulped, self.gulpMash, self.gulpBiteT = true, 0, GULP_BITE
    self.gulpNx, self.gulpNy = nx, ny
    self.gpPhase, self.gpT = nil, 0
    self.dropping, self.dropHoldT, self.crouching = false, 0, false
    self.onGround = false
    return true
end

-- Se acaba (muere, reaparece…): sin efectos
function PlayerAdventure:gulpClear()
    self.gulped, self.gulpMash, self.gulpBiteT = false, 0, 0
end

-- Escupido: sale disparado hacia fuera del bloque de la planta, un instante sin control e invulnerable
function PlayerAdventure:gulpEscape()
    local nx, ny = self.gulpNx or 0, self.gulpNy or -1
    self:gulpClear()
    if ny ~= 0 then self.vx, self.vy = 0, ny * SPIT_V
    else self.vx, self.vy = nx * SPIT_V * 0.8, -SPIT_V * 0.55 end
    self.onGround = false
    self.ctrlLockT = math.max(self.ctrlLockT or 0, 0.2)
    self.jumpsLeft = 1
    self:grantInvulnerability(GULP_FREE_INV)
    Sound.play('plantRustle', 1.5)
    Sound.play('jump', 0.8, 0.6)
    fx(self, 'gp_land', self.x, self.y)
end

-- Un mordisco de dentro (la planta: no lo para ser invulnerable). true si lo mató
function PlayerAdventure:gulpBite()
    self.hurtT = HURT_FLASH
    Sound.play('plantCrunch', 1.1, 0.7)
    if self.immortal then return false end                 -- (los bots rivales: les llega el golpe, no pierden vida)
    self.hp = self.hp - 1
    if self.hp <= 0 then
        self.hp = self.hpMax
        self:gulpClear()
        self:die(false, true)
        return true
    end
    Sound.play('dies')
    return false
end

-- El paso de un jugador tragado (lo llama PlayerAdventure:update; `frozenInput` = el Input sin control de siempre).
-- Las pulsaciones se leen UNA vez (el stub de red las consume); el resto del paso (relojes, ahogo…) va sin control y
-- sin moverse.
function PlayerAdventure:updateGulped(dt, level, frozenInput)
    -- (quien lo simula de verdad sabe qué planta lo tiene: si ya no lo tiene — muerta, reventada… —, sale)
    local by = self.gulpBy
    if by and (not by.alive or by.state ~= 'hold' or by.held ~= self) then
        self.gulpBy = nil
        return self:gulpEscape()
    end
    local mash = 0
    for _, a in ipairs({ 'jump', 'crouch', 'grab', 'light' }) do
        if Input.pressed(a) then mash = mash + 1 end
    end
    self.gulpMash = (self.gulpMash or 0) + mash
    local x, y = self.x, self.y
    self.vx, self.vy = 0, 0
    local real = Input
    Input = setmetatable(frozenInput, { __index = real })
    local ok, err = pcall(self._update, self, dt, level)
    Input = real
    if not ok then error(err, 0) end
    if self.dying then self:gulpClear(); return end
    self.x, self.y, self.vx, self.vy, self.onGround = x, y, 0, 0, false
    self.grabReq = false
    if self.gulpMash >= GULP_MASH then return self:gulpEscape() end
    self.gulpBiteT = (self.gulpBiteT or GULP_BITE) - dt
    if self.gulpBiteT <= 0 then
        self.gulpBiteT = self.gulpBiteT + GULP_BITE
        self:gulpBite()
    end
end

-- ── La ayuda de MACHACAR (solo dibujo, el jugador local) ─────────────────────
-- Encima del jugador tragado (o congelado en hielo: el mismo machacar): un botón que se pulsa y se suelta deprisa,
-- el de su aparato. assets/images/ui/prompts/mash-Sheet.png (tools/art/ui/make_prompts.py): 6 cuadros de 16x16 —
-- 1-2 teclado (suelta / pulsada), 3-4 mando, 5-6 táctil —.
local sheet
function PlayerAdventure.drawMashPrompt(pa, camX, camY)
    if not pa or pa.dying or not (pa.gulped or (pa.iceT or 0) > 0) then return end
    sheet = sheet or require('src/fx/SpriteStrip').load('assets/images/ui/prompts/mash-Sheet.png', 16)
    local dev = Input.isMobile and 2 or ((Input.usingPad and Input.usingPad()) and 1 or 0)
    local t = love.timer.getTime()
    local down = math.floor(t * 9) % 2
    local x = math.floor(pa.x - camX)
    local top = pa.y - OUTER_H / 2 + OUTER_YOFF
    if pa.gulped and (pa.gulpNy or -1) > 0 then top = pa.y + OUTER_H / 2 + OUTER_YOFF + 64 end     -- (en el techo: debajo)
    local y = math.floor(top - camY - 40 - down * 3)
    love.graphics.setColor(1, 1, 1, 1)
    sheet:draw(dev * 2 + 1 + down, x + math.floor(math.sin(t * 40) * 2), y, 0, 3, 3)
end

P.GULP_MASH = GULP_MASH
end
