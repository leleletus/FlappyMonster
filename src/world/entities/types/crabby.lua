-- Crabby: cangrejo que camina por suelo o techo (propiedad attach). Tras una
-- pausa puede esconderse en su caparazón: saca un pincho (zona de peligro) y
-- mientras está escondido no se le puede pisotear. De vez en cuando se asoma.
local Entity = require 'src/world/entities/Entity'

local Crabby = Entity.extend(Entity, {
    walkFps = 5, walkFrames = 3,
    idleEvery = { 2.5, 6.0 }, idleFor = { 1.0, 2.0 },
    debugColor = { 0.10, 0.55, 1.0 },
})

local randRange = Entity.randRange

-- Crabby de techo que cae al ver a un jugador: se esconde temblando, cae como
-- un pincho, se queda clavado boca abajo (vulnerable, pataleando) y, si
-- consigue levantarse, se da la vuelta y sigue como un Crabby de suelo.
Crabby.customDrop = true
local DROP_SHAKE   = 0.5    -- s temblando mientras se esconde
local STUCK_HID    = 0.5    -- s clavado aún escondido
local STUCK_TIME   = 3.6    -- s clavado en total antes de levantarse
local STUCK_EMBED  = 0.5    -- fracción del pincho dentro del suelo
local GETUP_TIME   = 0.35   -- s del giro al levantarse
local WIGGLE_FPS   = 12

local HIDE_DURATION_MIN = 2.5
local HIDE_DURATION_MAX = 6.0
local PEEK_INTERVAL_MIN = 1.5
local PEEK_INTERVAL_MAX = 4.0
local PEEK_DURATION_MIN = 0.4
local PEEK_DURATION_MAX = 1.2

-- Pincho: se dibuja justo encima del tope del sprite; como todos los sprites
-- tienen la base alineada, el pincho baja solo al esconderse.
local SPIKE_GROW_TIME  = 0.30
local SPRITE_FRAME_DUR = 0.25
local SPRITE_SEQ_TIME  = SPRITE_FRAME_DUR * 3
local HIDE_TRANSITION  = SPIKE_GROW_TIME + SPRITE_SEQ_TIME

local imgIdle1, imgIdle2, imgIdle3, imgDead, imgHid, imgLookin, imgMeat
local hideInFrames, hideOutFrames, walkFrames
local IMG_NAMES, IMG_BY_NAME

function Crabby.loadAssets()
    if imgIdle1 then return end
    imgIdle1  = love.graphics.newImage('assets/images/crabby/crab1.png')
    imgIdle2  = love.graphics.newImage('assets/images/crabby/crab2.png')
    imgIdle3  = love.graphics.newImage('assets/images/crabby/crab3.png')
    imgDead   = love.graphics.newImage('assets/images/gummy/dead.png')
    imgHid    = love.graphics.newImage('assets/images/crabby/hid.png')
    imgLookin = love.graphics.newImage('assets/images/crabby/lookin.png')
    imgMeat   = love.graphics.newImage('assets/images/crabby/MeatCrabby.png')
    hideInFrames  = { imgMeat, imgLookin, imgHid }    -- crab2 → Meat → lookin → hid
    hideOutFrames = { imgLookin, imgMeat, imgIdle2 }  -- hid → lookin → Meat → crab2
    walkFrames    = { imgIdle1, imgIdle2, imgIdle3 }
    -- Nombres para sincronizar el sprite actual online
    IMG_NAMES = { [imgIdle1]='idle1', [imgIdle2]='idle2', [imgIdle3]='idle3', [imgDead]='dead',
                  [imgHid]='hid', [imgLookin]='lookin', [imgMeat]='meat' }
    IMG_BY_NAME = {}
    for img, n in pairs(IMG_NAMES) do IMG_BY_NAME[n] = img end
end

function Crabby.sizeImage() return imgIdle1 end

local function seqFrame(elapsed, frames)
    local idx = math.floor(elapsed / SPRITE_FRAME_DUR) + 1
    return frames[math.max(1, math.min(idx, #frames))]
end

function Crabby:init()
    self.hideTransTimer = 0
    self.hideTimer, self.hideDuration = 0, 0
    self.peekCountdown = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
    self.peekTimer, self.peekDuration = 0, 0
    self.peeking       = false
    self.currentImg    = imgIdle1
    self.spikeProgress = 0
end

-- ── Estados comunes con sprite/pincho propios ────────────────────────────────
function Crabby:onWalk()
    self.spikeProgress = 0
    self.currentImg = walkFrames[self.frame] or imgIdle2
end

function Crabby:onIdle()
    self.currentImg    = imgIdle2
    self.spikeProgress = 0
end

function Crabby:onIdleEnd()
    if self.props.canHide and math.random() < self.props.hideChance then
        self.state          = 'hide_in'
        self.hideTransTimer = 0
        self.spikeProgress  = 0
        return true
    end
    return false
end

function Crabby:onDead()
    self.currentImg    = imgDead
    self.spikeProgress = 0
end

function Crabby:onStomp()
    self.spikeProgress = 0
    self.currentImg    = imgDead
end

function Crabby:canBeStomped() return not self:isBodyDisabled() end
function Crabby:isBodyDisabled() return self.currentImg == imgHid end

-- ── Caída desde el techo ──────────────────────────────────────────────────────
local function spikeDims()
    return 9 * GUMMY_SCALE, 9 * GUMMY_SCALE, 7 * GUMMY_SCALE, 8 * GUMMY_SCALE  -- w, maxH, hitW, hitMaxH
end

-- Base del pincho (boca abajo): pies arriba, cabeza abajo y el pincho debajo.
-- Se mide siempre con el sprite escondido, así el pincho no se mueve aunque
-- cambie el sprite: clavado, el cangrejo "sale" hacia arriba desde el pincho.
local function dropSpikeBaseY(self)
    return self.y - self.sprH / 2 + imgHid:getHeight() * GUMMY_SCALE
end
local function dropTipY(self)
    local _, maxH = spikeDims()
    return dropSpikeBaseY(self) + maxH
end

function Crabby:updateDrop(dt, level)
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    if st == 'drop_shake' then
        -- Tiembla y se esconde: sale el pincho y se mete en el caparazón
        self.vx = 0
        if t < 0.2 then
            self.currentImg, self.spikeProgress = imgIdle2, math.min(1, t / 0.2)
        else
            self.spikeProgress = 1
            self.currentImg = hideInFrames[math.min(#hideInFrames, math.floor((t - 0.2) / 0.1) + 1)]
        end
        if t >= DROP_SHAKE then
            self.state, self.deadTimer, self.vy = 'drop_fall', 0, 0
            self.currentImg, self.spikeProgress = imgHid, 1
        end
    elseif st == 'drop_fall' then
        -- Cae como un pincho (sigue boca abajo) hasta clavarse en el suelo
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1400)
        self.y = self.y + self.vy * dt
        local tip = dropTipY(self)
        if level:collisionAt(self.x, tip, true) then
            local _, maxH = spikeDims()
            local top = math.floor(tip / TILE_PX) * TILE_PX
            self.y = self.y - (tip - (top + maxH * STUCK_EMBED))
            self.state, self.deadTimer, self.vy = 'drop_stuck', 0, 0
            -- Para pisotearlo cuenta como "de suelo" (se le pisa desde arriba)
            self.flipped = false
            Sound.play('spikeHit')
            Entity.emitFx('spike_land', self.x, top)
        elseif self.y > level.heightPx + TILE_PX * 4 then
            self.alive = false
        end
    elseif st == 'drop_stuck' then
        -- Clavado: primero escondido, luego se asoma y patalea boca abajo
        self.spikeProgress = 1
        if t < STUCK_HID then
            self.currentImg = imgHid
        elseif t < STUCK_HID + SPRITE_SEQ_TIME then
            self.currentImg = seqFrame(t - STUCK_HID, hideOutFrames)
        else
            local k = math.floor((t - STUCK_HID - SPRITE_SEQ_TIME) * WIGGLE_FPS) % #walkFrames + 1
            self.currentImg = walkFrames[k]
        end
        if t >= STUCK_TIME then
            -- Se levanta: salta, se gira y vuelve a caer de pie
            self.state, self.deadTimer = 'drop_getup', 0
            self.vy = -420
            self.facing = -self.facing
            self.onGround = false
            Sound.play('crabPop')
            Entity.emitFx('spike_pop', self.x, dropTipY(self) - 8)
        end
    elseif st == 'drop_getup' then
        self.spikeProgress = math.max(0, 1 - t / GETUP_TIME)
        self.currentImg = imgIdle2
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.onGround and t >= GETUP_TIME * 0.6 then
            self.dropped = true
            self.spikeProgress = 0
            self.vx = self.moving and self.speed * self.facing or 0
            self:startWalk()
        end
    end
    return true
end

-- ── Esconderse / asomarse ────────────────────────────────────────────────────
function Crabby:updateCustom(dt, level)
    local st = self.state
    if st:sub(1, 5) == 'drop_' then return self:updateDrop(dt, level) end
    if st == 'hide_in' then
        -- Fase 1: pincho crece 0→1 (sprite crab2). Fase 2: Meat→lookin→hid
        self.hideTransTimer = self.hideTransTimer + dt
        self:fall(level, dt)
        if self.hideTransTimer < SPIKE_GROW_TIME then
            self.currentImg    = imgIdle2
            self.spikeProgress = math.min(1, self.hideTransTimer / SPIKE_GROW_TIME)
        else
            self.spikeProgress = 1
            self.currentImg = seqFrame(self.hideTransTimer - SPIKE_GROW_TIME, hideInFrames)
        end
        if self.hideTransTimer >= HIDE_TRANSITION then
            self.state         = 'hidden'
            self.currentImg    = imgHid
            self.spikeProgress = 1
            self.hideTimer     = 0
            self.hideDuration  = randRange(HIDE_DURATION_MIN, HIDE_DURATION_MAX)
            self.peekCountdown = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
            self.peeking       = false
        end
        return true

    elseif st == 'hidden' then
        self.spikeProgress = 1
        self.hideTimer     = self.hideTimer + dt
        self:fall(level, dt)
        if self.peeking then
            self.currentImg = imgLookin
            self.peekTimer  = self.peekTimer + dt
            if self.peekTimer >= self.peekDuration then
                self.peeking       = false
                self.currentImg    = imgHid
                self.peekCountdown = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
            end
        else
            self.currentImg    = imgHid
            self.peekCountdown = self.peekCountdown - dt
            if self.peekCountdown <= 0 then
                self.peeking      = true
                self.peekTimer    = 0
                self.peekDuration = randRange(PEEK_DURATION_MIN, PEEK_DURATION_MAX)
            end
        end
        if self.hideTimer >= self.hideDuration then
            self.state          = 'hide_out'
            self.hideTransTimer = 0
        end
        return true

    elseif st == 'hide_out' then
        -- Fase 1: lookin→Meat→crab2 con pincho. Fase 2: pincho se retrae 1→0
        self.hideTransTimer = self.hideTransTimer + dt
        self:fall(level, dt)
        if self.hideTransTimer < SPRITE_SEQ_TIME then
            self.spikeProgress = 1
            self.currentImg = seqFrame(self.hideTransTimer, hideOutFrames)
        else
            self.currentImg = imgIdle2
            self.spikeProgress = math.max(0, 1 - (self.hideTransTimer - SPRITE_SEQ_TIME) / SPIKE_GROW_TIME)
        end
        if self.hideTransTimer >= HIDE_TRANSITION then
            self.state         = 'walk'
            self.currentImg    = imgIdle2
            self.spikeProgress = 0
            self.idleCountdown = randRange(self.tuning.idleEvery[1], self.tuning.idleEvery[2])
        end
        return true
    end
    return false
end

-- ── Pincho (zona de peligro) ─────────────────────────────────────────────────
function Crabby:getSpikeHitbox()
    if self.spikeProgress <= 0 then return nil end
    -- Clavado en el suelo / levantándose: el pincho no hace daño
    if self.state == 'drop_stuck' or self.state == 'drop_getup' then return nil end
    local _, _, hitW, hitMaxH = spikeDims()
    local hitH = hitMaxH * self.spikeProgress
    if hitH < 1 then return nil end
    local spriteVisH = (self.currentImg or imgIdle2):getHeight() * GUMMY_SCALE
    local sx = self.x - hitW / 2
    if self.flipped then
        local headY = (self.y - self.sprH / 2) + spriteVisH   -- cabeza abajo: crece hacia abajo
        return { x = sx, y = headY, w = hitW, h = hitH }
    else
        local headY = (self.y + self.sprH / 2) - spriteVisH   -- cabeza arriba: crece hacia arriba
        return { x = sx, y = headY - hitH, w = hitW, h = hitH }
    end
end

function Crabby:getHazardBoxes()
    local s = self:getSpikeHitbox()
    return s and { s } or nil
end

-- ── Red: pincho y sprite actual ──────────────────────────────────────────────
function Crabby:getImgName() return IMG_NAMES[self.currentImg or imgIdle2] or 'idle2' end
function Crabby:setImgFromName(n) if IMG_BY_NAME[n] then self.currentImg = IMG_BY_NAME[n] end end

function Crabby:netPack()
    return { math.floor((self.spikeProgress or 0) * 1000 + 0.5), self:getImgName() }
end

function Crabby:netApply(a, b, f)
    a = a or b
    if type(b[1]) == 'number' and type(a[1]) == 'number' then
        self.spikeProgress = (a[1] + (b[1] - a[1]) * f) / 1000
    end
    self:setImgFromName((f < 0.5 and a or b)[2])
end

-- ── Render ────────────────────────────────────────────────────────────────────
local function drawSpike(cx, baseY, sH, dir)
    if sH < 1 then return end
    local halfW = spikeDims() / 2
    local tipY  = baseY + sH * dir
    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.polygon('fill', cx, tipY, cx - halfW, baseY, cx + halfW, baseY)
    love.graphics.setColor(0.55, 0.55, 0.60, 0.8)
    love.graphics.polygon('line', cx, tipY, cx - halfW, baseY, cx + halfW, baseY)
end

function Crabby:render(camX, camY)
    local img = self.currentImg or imgIdle2
    local st  = self.state
    local bx, by = self:breatheScale()
    local scaleX = GUMMY_SCALE * self.facing * bx
    local scaleY = GUMMY_SCALE * by
    local ih = img:getHeight()
    local drawX = math.floor(self.x - camX)
    -- Clavado en el suelo: boca abajo (pies arriba) aunque ya cuente como de suelo
    local stuck   = (st == 'drop_stuck')
    local flipped = self.flipped or stuck
    local t = self.deadTimer or 0
    if stuck and t >= STUCK_HID + SPRITE_SEQ_TIME then
        drawX = drawX + math.floor(math.sin(t * 45) * 2)          -- forcejea
    end
    local feetY = flipped and math.floor(self.y - camY - self.sprH / 2)
                          or math.floor(self.y - camY + self.sprH / 2)
    local spriteVisH = ih * math.abs(scaleY)
    if stuck then
        -- El pincho queda fijo; la cabeza del cangrejo se apoya en su base y
        -- el cuerpo crece hacia arriba según el sprite de cada momento
        local baseY = math.floor(dropSpikeBaseY(self) - camY)
        feetY = baseY - spriteVisH
    end

    -- Levantándose: gira 180° alrededor de su centro
    local rot = 0
    if st == 'drop_getup' then rot = math.pi * (1 - math.min(1, t / GETUP_TIME)) end
    if rot ~= 0 then
        local cx, cy = self.x - camX, self.y - camY
        love.graphics.push()
        love.graphics.translate(cx, cy); love.graphics.rotate(rot * self.facing); love.graphics.translate(-cx, -cy)
    end

    if stuck then
        -- Entero, igual que un pincho que cae clavado (la punta dentro del suelo)
        local _, maxH = spikeDims()
        drawSpike(math.floor(self.x - camX), feetY + spriteVisH, maxH, 1)
    elseif self.spikeProgress > 0 then
        local _, maxH = spikeDims()
        local sH = maxH * self.spikeProgress
        if flipped then drawSpike(drawX, feetY + spriteVisH, sH, 1)
        else            drawSpike(drawX, feetY - spriteVisH, sH, -1) end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, drawX, feetY, 0, scaleX, flipped and -scaleY or scaleY,
                       img:getWidth() / 2, ih)
    if rot ~= 0 then love.graphics.pop() end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'crabby', label = 'Crabby', category = 'Enemigos',
    class = Crabby,
    defaults = { speed = 50, points = 15 },
    props = {
        { key='canHide', kind='bool', label='Se esconde (pincho)', group='Comportamiento', default=true,
          showIf=function(p) return p.pauses end },
        { key='hideChance', kind='number', label='Prob. de esconderse', group='Comportamiento',
          default=0.75, min=0, max=1, step=0.05,
          showIf=function(p) return p.pauses and p.canHide end },
    },
    editor = { sprite = 'assets/images/crabby/crab1.png' },
}
