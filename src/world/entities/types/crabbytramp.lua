-- Crabby trampolín: un Crabby que, al esconderse, en vez del pincho saca un
-- trampolín: es un trampolín con patas. Caerle encima mientras está escondido
-- te lanza bien alto (si está en el techo, al saltar contra él te lanza hacia
-- abajo). Sin esconder se le pisotea como a cualquier Crabby.
--
-- Del techo (Cae al ver al jugador): se esconde temblando, cae boca abajo
-- con el trampolín por delante y, al tocar el suelo, REBOTA, se da la vuelta
-- en el aire, cae de pie, recoge el trampolín y sigue como si nada. Si cae
-- encima de un jugador, lo aplasta: sale empujado a un lado, agachado y
-- aturdido (y pierde `crushDamage` de vida, 1 por defecto).

local Entity          = require 'src/world/entities/Entity'
local Interactions    = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local base            = require 'src/world/entities/types/crabby'
local Crawler         = require 'src/world/entities/Crawler'
local Crabby          = base.class

local TC = Entity.extend(Crabby, { debugColor = { 1, 0.85, 0.2 } })

local S           = GUMMY_SCALE
local TRAMP_H     = 9 * S            -- filas 7..15 del sprite del trampolín
local TRAMP_W     = 14 * S
local COOLDOWN    = 0.5              -- s extendido tras lanzar
local WINDOW      = 0.1              -- s en los que lanza a todos los que lleguen a la vez
local BOUNCE_VY   = -660             -- rebote contra el suelo al caer del techo
local FLIP_T      = 0.45             -- s dándose la vuelta en el aire

local imgTNormal, imgTExt, imgShell
function TC.loadAssets()
    Crabby.loadAssets()
    if imgTNormal then return end
    imgTNormal = love.graphics.newImage('assets/images/trampoline/normal.png')
    imgTExt    = love.graphics.newImage('assets/images/trampoline/extended.png')
    imgShell   = love.graphics.newImage('assets/images/crabby/hid.png')
    if imgTNormal.setFilter then imgTNormal:setFilter('nearest', 'nearest'); imgTExt:setFilter('nearest', 'nearest') end
end

function TC:init()
    Crabby.init(self)
    self.bounceAge = 99
end

-- Sin pincho: no hace daño al esconderse
function TC:getHazardBoxes() return nil end

-- ── Trampolín ─────────────────────────────────────────────────────────────────
function TC:trampActive()
    local st = self.state
    return self.spikeProgress >= 0.9 and (st == 'hidden' or st == 'hide_in' or st == 'hide_out')
end

-- Caja del cojín (encima del caparazón, o debajo si está en el techo)
function TC:trampBox()
    local imgH = (self.currentImg and self.currentImg:getHeight() or 1) * S
    local h = TRAMP_H * self.spikeProgress
    if (Crawler.onWall(self) and self.cattached) or Crawler.turning(self) then
        -- En la pared (o girando en una esquina): la misma caja "encima de la cabeza", girada
        return Crawler.poseBox(self, -TRAMP_W / 2, self.sprH / 2 - imgH - h, TRAMP_W, h)
    end
    if self.flipped then
        local b = self.y - self.sprH / 2 + imgH
        return { x = self.x - TRAMP_W / 2, y = b, w = TRAMP_W, h = h }
    end
    local b = self.y + self.sprH / 2 - imgH
    return { x = self.x - TRAMP_W / 2, y = b - h, w = TRAMP_W, h = h }
end

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function TC:canBounce() return self.bounceAge >= COOLDOWN or self.bounceAge < WINDOW end

-- (sin efectos: el cliente online lo usa para predecir el lanzamiento)
function TC:interact(pa)
    if self:trampActive() then
        local tb, pob = self:trampBox(), pa:getOuterBounds()
        if self:canBounce() and overlap(pob, tb) then
            local P = math.abs(ADV_JUMP_VEL) * (self.props.power or 1.6)
            local nx, ny = Crawler.poseNormal(self)
            local flipped = self.flipped
            if self.crawl and self.cattached then flipped = (ny == 1) end
            if self.crawl and self.cattached and nx ~= 0 then
                -- En la pared: al ir contra el cojín, lanza de lado (como un trampolín lateral)
                if (pa.vx or 0) * nx < 0 then return 'launch', nx * P * 0.85, -380 end
            elseif not flipped and pa.vy > 0 and pob.y + pob.h <= tb.y + tb.h * 0.6 + 10 then
                return 'launch', 0, -P
            elseif flipped and pa.vy < 0 and pob.y >= tb.y + tb.h * 0.4 - 10 then
                return 'launch', 0, P * 0.6
            end
        end
        return nil
    end
    return Interactions.defaultCheck(pa, self)
end

function TC:onLaunch(pa)
    if self.bounceAge >= COOLDOWN then
        self.bounceAge = 0
        Sound.play('trampoline')
    end
end

function TC:updateCustom(dt, level)
    self.bounceAge = math.min(99, self.bounceAge + dt)
    return Crabby.updateCustom(self, dt, level)
end

-- ── Caída desde el techo: rebota en vez de clavarse ──────────────────────────
function TC:startBounce()
    self.state, self.deadTimer = 'drop_bounce', 0
    self.vy, self.flipped, self.onGround = BOUNCE_VY, false, false
    self.bounceAge = 0
    Sound.play('trampoline')
    Entity.emitFx('gp_land', self.x, self.y + self.sprH / 2)
end

-- Aplasta a quien pille debajo
function TC:crush(level, box)
    local hit = false
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and pa.y > box.y then
            if overlap(pa:getOuterBounds(), box) then
                local dir = (pa.x >= self.x) and 1 or -1
                local dmg = self.props.crushDamage or 1
                PlayerAdventure.asOwner(pa, function()
                    pa:squash(dir)
                    pa:hurt(dmg)
                end)
                hit = true
            end
        end
    end
    return hit
end

function TC:updateDrop(dt, level)
    local st = self.state
    if st == 'drop_shake' then return Crabby.updateDrop(self, dt, level) end   -- tiembla y se esconde
    self.deadTimer = self.deadTimer + dt
    if st == 'drop_fall' then
        -- Boca abajo con el trampolín por delante
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1300)
        local tb0 = self:trampBox()
        local tip0 = tb0.y + tb0.h
        self.y  = self.y + self.vy * dt
        local tb = self:trampBox()
        if self:crush(level, tb) then self:startBounce(); return true end
        local tip = tb.y + tb.h
        for _, fx in ipairs({ -0.3, 0, 0.3 }) do
            -- (solo lo que cruza desde arriba: la losa de la que colgaba no cuenta)
            local t, top = level:landingCross(self.x + TRAMP_W * fx, tip0, tip)
            if t then
                self.y = self.y - (tip - top)
                self:startBounce()
                return true
            end
        end
        if self.y > level.heightPx + TILE_PX * 4 then self.alive = false end
    elseif st == 'drop_bounce' then
        -- Se da la vuelta en el aire y cae de pie; luego recoge el trampolín
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.onGround and self.deadTimer >= FLIP_T * 0.7 then
            self.dropped = true
            self.vy = 0
            self.vx = self.moving and self.speed * self.facing or 0     -- vuelve a andar
            if self.crawl then Crawler.detach(self); Crawler.attach(self, level); self.cdir = self.facing end
            self.state, self.hideTransTimer = 'hide_out', 0
        end
    end
    return true
end

function TC:bounceRotation()
    return math.pi * (1 - math.min(1, (self.deadTimer or 0) / FLIP_T))
end

-- ── Red: además, cuándo lanzó por última vez ─────────────────────────────────
function TC:netPack()
    local out = Crabby.netPack(self)
    out[#out+1] = math.floor(math.min(9.99, self.bounceAge) * 100 + 0.5)
    return out
end

function TC:netApply(a, b, f)
    Crabby.netApply(self, a, b, f)
    local k = Crabby.NET_N + 1
    if type(b[k]) == 'number' then self.bounceAge = b[k] / 100 end
end

-- ── Dibujo: el trampolín sale del caparazón ──────────────────────────────────
function TC:drawTopper(cx, baseY, progress, dir)
    if progress <= 0.01 then return end
    local img = (self.bounceAge < COOLDOWN) and imgTExt or imgTNormal
    love.graphics.setColor(1, 1, 1, 1)
    -- Anclado por su base (fila 16 del sprite) y creciendo hacia fuera
    love.graphics.draw(img, cx, baseY, 0, S, (dir < 0) and S * progress or -S * progress, 8, 16)
end

local function editorIcon(x, y, s)
    TC.loadAssets()
    local k = s / 16
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgTNormal, x, y - k * 2, 0, k, k)
    love.graphics.draw(imgShell, x, y + s - k * 2, 0, k, k * 2)
end

return {
    name = 'crabbytramp', label = 'Crabby trampolín', category = 'Enemigos',
    description = 'Crabby que al esconderse saca un trampolín. Desde el techo cae, rebota y aplasta.',
    class = TC,
    defaults = { speed = 50, points = 15 },
    props = {
        { key='canHide', kind='bool', label='Se esconde (trampolín)', group='Comportamiento', default=true,
          showIf=function(p) return p.pauses end },
        { key='hideChance', kind='number', label='Probabilidad de esconderse', group='Comportamiento',
          default=0.85, min=0, max=1, step=0.05,
          showIf=function(p) return p.pauses and p.canHide end },
        { key='power', kind='number', label='Fuerza del trampolín', group='Trampolín', default=1.6,
          min=0.5, max=4, step=0.05 },
        { key='crushDamage', kind='int', label='Daño al caer encima', group='Trampolín', default=1,
          min=0, max=3, step=1, help='Vida que quita si cae del techo sobre un jugador (siempre lo aplasta y aturde)' },
        Crabby.WALL_PROP,
    },
    editor = { sprite = 'assets/images/crabby/crab1.png', draw = editorIcon },
}
