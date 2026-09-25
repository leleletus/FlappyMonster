-- src/entities/Crabby.lua
local Class = require 'libs/class'
local Crabby = Class:new()

-- ── Sprites ───────────────────────────────────────────────────────────────────
local imgIdle1, imgIdle2, imgIdle3   = nil, nil, nil
local imgDead                         = nil
local imgHid                          = nil
local imgLookin                       = nil
local imgMeatCrabby                   = nil

local function loadSprites()
    if imgIdle1 then return end
    imgIdle1      = love.graphics.newImage('assets/images/crabby/crab1.png')
    imgIdle2      = love.graphics.newImage('assets/images/crabby/crab2.png')
    imgIdle3      = love.graphics.newImage('assets/images/crabby/crab3.png')
    imgDead       = love.graphics.newImage('assets/images/gummy/dead.png')
    imgHid        = love.graphics.newImage('assets/images/crabby/hid.png')
    imgLookin     = love.graphics.newImage('assets/images/crabby/lookin.png')
    imgMeatCrabby = love.graphics.newImage('assets/images/crabby/MeatCrabby.png')
end

-- ── Constantes ────────────────────────────────────────────────────────────────
local WALK_FPS       = 5
local CRABBY_SPEED   = 50
local DEAD_DURATION  = 1.4

local IDLE_INTERVAL_MIN = 2.5
local IDLE_INTERVAL_MAX = 6.0
local IDLE_DURATION_MIN = 1.0
local IDLE_DURATION_MAX = 2.0
local BREATHE_SPEED     = 3.2
local BREATHE_AMP       = 0.06

local HIDE_CHANCE       = 0.75
local HIDE_DURATION_MIN = 2.5
local HIDE_DURATION_MAX = 6.0

local PEEK_INTERVAL_MIN = 1.5
local PEEK_INTERVAL_MAX = 4.0
local PEEK_DURATION_MIN = 0.4
local PEEK_DURATION_MAX = 1.2

local OUTER_W_FRAC = 0.72
local OUTER_H_FRAC = 0.80
local INNER_W_FRAC = 0.44
local INNER_H_FRAC = 0.50

-- ── Pincho ───────────────────────────────────────────────────────────────────
-- Se dibuja SIEMPRE justo encima del tope del sprite.
-- Como todos los sprites tienen la misma altura con la base alineada abajo,
-- el tope del sprite sube conforme el crabby se esconde → el pincho baja solo.
local SPIKE_W         = 9 * GUMMY_SCALE
local SPIKE_MAX_H     = 9 * GUMMY_SCALE
local SPIKE_HIT_W     = 7 * GUMMY_SCALE
local SPIKE_HIT_H_MAX = 8 * GUMMY_SCALE

-- ── Tiempos de transición ────────────────────────────────────────────────────
local SPIKE_GROW_TIME  = 0.30    -- pincho crece/retrae rápido
local SPRITE_FRAME_DUR = 0.25    -- duración de cada frame de la secuencia
-- hide_in:  crab2 → MeatCrabby → lookin → hid  (3 frames nuevos)
-- hide_out: hid → lookin → MeatCrabby → crab2  (3 frames nuevos)
local SPRITE_SEQ_TIME  = SPRITE_FRAME_DUR * 3
local HIDE_TRANSITION  = SPIKE_GROW_TIME + SPRITE_SEQ_TIME

-- Las secuencias de frames se construyen bajo demanda (lazy) porque los
-- sprites son nil hasta que loadSprites() se llama en el constructor.
local hideInFrames  = nil
local hideOutFrames = nil

local function getHideInFrames()
    if not hideInFrames then
        hideInFrames = { imgMeatCrabby, imgLookin, imgHid }
    end
    return hideInFrames
end

local function getHideOutFrames()
    if not hideOutFrames then
        hideOutFrames = { imgLookin, imgMeatCrabby, imgIdle2 }
    end
    return hideOutFrames
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function solidAt(level, wx, wy)
    return level:isEnemySolidAt(wx, wy)   -- según el catálogo de tiles (enemySolid)
end

local function randRange(a, b)
    return a + math.random() * (b - a)
end

-- Dado un tiempo dentro de la fase de sprites, devuelve el frame de la tabla.
local function getSeqFrame(elapsed, frames)
    local idx = math.floor(elapsed / SPRITE_FRAME_DUR) + 1
    idx = math.max(1, math.min(idx, #frames))
    return frames[idx]
end

-- ── Constructor ───────────────────────────────────────────────────────────────
function Crabby:new(data)
    loadSprites()
    local o = setmetatable({}, self)
    self.__index = self

    o.x  = (data.col - 1) * TILE_PX + TILE_PX / 2
    o.y  = (data.row - 1) * TILE_PX + TILE_PX / 2
    o.vx = CRABBY_SPEED
    o.vy = 0

    o.flipped = data.flipped or false

    o.leftBoundPx  = (data.leftBound  - 1) * TILE_PX
    o.rightBoundPx =  data.rightBound      * TILE_PX

    local iw = imgIdle1:getWidth()  * GUMMY_SCALE
    local ih = imgIdle1:getHeight() * GUMMY_SCALE
    o.sprW   = iw
    o.sprH   = ih
    o.outerW = iw * OUTER_W_FRAC
    o.outerH = ih * OUTER_H_FRAC
    o.innerW = iw * INNER_W_FRAC
    o.innerH = ih * INNER_H_FRAC

    o.onGround  = false
    o.facing    = 1
    o.state     = 'walk'
    o.deadTimer = 0
    o.alive     = true

    o.animT = 0
    o.frame = 1

    o.idleCountdown  = randRange(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
    o.idleTimer      = 0
    o.idleDuration   = 0
    o.breatheT       = 0

    o.hideTransTimer = 0
    o.hideTimer      = 0
    o.hideDuration   = 0

    o.peekCountdown  = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
    o.peekTimer      = 0
    o.peekDuration   = 0
    o.peeking        = false

    o.currentImg     = imgIdle1
    o.spikeProgress  = 0

    return o
end

-- ── Hitboxes ──────────────────────────────────────────────────────────────────
function Crabby:getOuterBounds()
    return { x = self.x - self.outerW / 2,
             y = self.y - self.outerH / 2,
             w = self.outerW, h = self.outerH }
end

function Crabby:getInnerBounds()
    return { x = self.x - self.innerW / 2,
             y = self.y - self.innerH / 2,
             w = self.innerW, h = self.innerH }
end

-- ── Consultas de estado ──────────────────────────────────────────────────────
function Crabby:isBodyDisabled()
    return self.currentImg == imgHid
end

function Crabby:isHiding()
    return self:isBodyDisabled()
end

function Crabby:isVulnerable()
    return not self:isBodyDisabled()
end

function Crabby:isDangerous()
    return not self:isBodyDisabled()
end

-- ── Hitbox del pincho ────────────────────────────────────────────────────────
function Crabby:getSpikeHitbox()
    if self.spikeProgress <= 0 then return nil end

    local hitH = SPIKE_HIT_H_MAX * self.spikeProgress
    if hitH < 1 then return nil end

    local img = self.currentImg or imgIdle2
    local ih  = img:getHeight()
    local spriteVisH = ih * GUMMY_SCALE

    local sx = self.x - SPIKE_HIT_W / 2

    if self.flipped then
        -- Pies arriba, cabeza abajo
        local feetY = self.y - self.sprH / 2
        local headY = feetY + spriteVisH
        -- Pincho crece hacia abajo desde headY
        return { x = sx, y = headY, w = SPIKE_HIT_W, h = hitH }
    else
        -- Pies abajo, cabeza arriba
        local feetY = self.y + self.sprH / 2
        local headY = feetY - spriteVisH
        -- Pincho crece hacia arriba desde headY
        return { x = sx, y = headY - hitH, w = SPIKE_HIT_W, h = hitH }
    end
end

-- ── Colisión con nivel ────────────────────────────────────────────────────────
function Crabby:moveAndCollide(level, dx, dy)
    local hw = self.outerW / 2
    local hh = self.outerH / 2
    local x, y = self.x, self.y

    if self.flipped then
        x = x + dx
        if dx > 0 then
            if solidAt(level, x + hw, y - hh + 4) or solidAt(level, x + hw, y + hh - 4) then
                x = math.floor((x + hw) / TILE_PX) * TILE_PX - hw
                self.vx = -CRABBY_SPEED;  self.facing = -1
            elseif x + hw >= self.rightBoundPx then
                x = self.rightBoundPx - hw
                self.vx = -CRABBY_SPEED;  self.facing = -1
            end
        elseif dx < 0 then
            if solidAt(level, x - hw, y - hh + 4) or solidAt(level, x - hw, y + hh - 4) then
                x = math.ceil((x - hw) / TILE_PX) * TILE_PX + hw
                self.vx =  CRABBY_SPEED;  self.facing = 1
            elseif x - hw <= self.leftBoundPx then
                x = self.leftBoundPx + hw
                self.vx =  CRABBY_SPEED;  self.facing = 1
            end
        end
        y = y + dy
        self.onGround = false
        local chx = { x - hw + 4, x, x + hw - 4 }
        if dy < 0 then
            for _, px in ipairs(chx) do
                if solidAt(level, px, y - hh) then
                    y = math.ceil((y - hh) / TILE_PX) * TILE_PX + hh
                    self.vy = 0;  self.onGround = true;  break
                end
            end
        elseif dy > 0 then
            for _, px in ipairs(chx) do
                if solidAt(level, px, y + hh) then
                    y = math.floor((y + hh) / TILE_PX) * TILE_PX - hh
                    self.vy = 0;  break
                end
            end
        end
    else
        x = x + dx
        if dx > 0 then
            if solidAt(level, x + hw, y - hh + 4) or solidAt(level, x + hw, y + hh - 4) then
                x = math.floor((x + hw) / TILE_PX) * TILE_PX - hw
                self.vx = -CRABBY_SPEED;  self.facing = -1
            elseif x + hw >= self.rightBoundPx then
                x = self.rightBoundPx - hw
                self.vx = -CRABBY_SPEED;  self.facing = -1
            end
        elseif dx < 0 then
            if solidAt(level, x - hw, y - hh + 4) or solidAt(level, x - hw, y + hh - 4) then
                x = math.ceil((x - hw) / TILE_PX) * TILE_PX + hw
                self.vx =  CRABBY_SPEED;  self.facing = 1
            elseif x - hw <= self.leftBoundPx then
                x = self.leftBoundPx + hw
                self.vx =  CRABBY_SPEED;  self.facing = 1
            end
        end
        y = y + dy
        self.onGround = false
        local chx = { x - hw + 4, x, x + hw - 4 }
        if dy > 0 then
            for _, px in ipairs(chx) do
                if solidAt(level, px, y + hh) then
                    y = math.floor((y + hh) / TILE_PX) * TILE_PX - hh
                    self.vy = 0;  self.onGround = true;  break
                end
            end
        elseif dy < 0 then
            for _, px in ipairs(chx) do
                if solidAt(level, px, y - hh) then
                    y = math.ceil((y - hh) / TILE_PX) * TILE_PX + hh
                    self.vy = 0;  break
                end
            end
        end
    end

    self.x, self.y = x, y
end

-- ── Muerte ────────────────────────────────────────────────────────────────────
function Crabby:stomp()
    if self.state == 'dead' then return end
    if self:isBodyDisabled() then return end
    self.state         = 'dead'
    self.deadTimer     = 0
    self.vx            = 0
    self.vy            = 0
    self.spikeProgress = 0
    self.currentImg    = imgDead
    Sound.play('enemyExplode')
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Crabby:update(dt, level)
    local gravDir = self.flipped and -1 or 1

    -- ── Muerto ───────────────────────────────────────────────────────────────
    if self.state == 'dead' then
        self.currentImg    = imgDead
        self.spikeProgress = 0
        self.deadTimer     = self.deadTimer + dt
        if self.deadTimer >= DEAD_DURATION then self.alive = false end
        return
    end

    -- ── Hide_in ──────────────────────────────────────────────────────────────
    -- Fase 1 (0 → SPIKE_GROW_TIME):   sprite=crab2, pincho crece 0→1
    -- Fase 2 (SPIKE_GROW_TIME → fin):  pincho=1, sprites: MeatCrabby→lookin→hid
    if self.state == 'hide_in' then
        self.hideTransTimer = self.hideTransTimer + dt
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        self:moveAndCollide(level, 0, self.vy * dt)

        if self.hideTransTimer < SPIKE_GROW_TIME then
            self.currentImg    = imgIdle2
            self.spikeProgress = math.min(1, self.hideTransTimer / SPIKE_GROW_TIME)
        else
            self.spikeProgress = 1
            local spriteElapsed = self.hideTransTimer - SPIKE_GROW_TIME
            self.currentImg = getSeqFrame(spriteElapsed, getHideInFrames())
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
        return
    end

    -- ── Hidden ───────────────────────────────────────────────────────────────
    if self.state == 'hidden' then
        self.spikeProgress = 1
        self.hideTimer     = self.hideTimer + dt
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        self:moveAndCollide(level, 0, self.vy * dt)

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
        return
    end

    -- ── Hide_out ─────────────────────────────────────────────────────────────
    -- Fase 1 (0 → SPRITE_SEQ_TIME):   pincho=1, sprites: lookin→MeatCrabby→crab2
    -- Fase 2 (SPRITE_SEQ_TIME → fin):  sprite=crab2, pincho retrae 1→0
    if self.state == 'hide_out' then
        self.hideTransTimer = self.hideTransTimer + dt
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        self:moveAndCollide(level, 0, self.vy * dt)

        if self.hideTransTimer < SPRITE_SEQ_TIME then
            self.spikeProgress = 1
            self.currentImg = getSeqFrame(self.hideTransTimer, getHideOutFrames())
        else
            self.currentImg = imgIdle2
            local retractElapsed = self.hideTransTimer - SPRITE_SEQ_TIME
            self.spikeProgress = math.max(0, 1 - retractElapsed / SPIKE_GROW_TIME)
        end

        if self.hideTransTimer >= HIDE_TRANSITION then
            self.state         = 'walk'
            self.currentImg    = imgIdle2
            self.spikeProgress = 0
            self.idleCountdown = randRange(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
        end
        return
    end

    -- ── Idle ─────────────────────────────────────────────────────────────────
    if self.state == 'idle' then
        self.currentImg    = imgIdle2
        self.spikeProgress = 0
        self.idleTimer     = self.idleTimer + dt
        self.breatheT      = self.breatheT  + dt
        self.vy = self.vy + ADV_GRAVITY * dt * gravDir
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.idleTimer >= self.idleDuration then
            if math.random() < HIDE_CHANCE then
                self.state          = 'hide_in'
                self.hideTransTimer = 0
                self.spikeProgress  = 0
            else
                self.state         = 'walk'
                self.idleCountdown = randRange(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)
                self.idleTimer     = 0
                self.breatheT      = 0
            end
        end
        return
    end

    -- ── Walk ─────────────────────────────────────────────────────────────────
    self.spikeProgress = 0
    local walkFrames = { imgIdle1, imgIdle2, imgIdle3 }
    self.currentImg = walkFrames[self.frame] or imgIdle2

    self.idleCountdown = self.idleCountdown - dt
    if self.idleCountdown <= 0 and self.onGround then
        self.state        = 'idle'
        self.idleTimer    = 0
        self.idleDuration = randRange(IDLE_DURATION_MIN, IDLE_DURATION_MAX)
        self.breatheT     = 0
        return
    end

    if self.onGround then
        local hw    = self.outerW / 2
        local lookX = self.x + (self.vx > 0 and (hw + 2) or -(hw + 2))
        if self.flipped then
            local ceilY = self.y - self.outerH / 2 - TILE_PX / 2
            if not solidAt(level, lookX, ceilY) then
                self.vx = -self.vx;  self.facing = -self.facing
            end
        else
            local floorY = self.y + self.outerH / 2 + TILE_PX / 2
            if not solidAt(level, lookX, floorY) then
                self.vx = -self.vx;  self.facing = -self.facing
            end
        end
    end

    self.vy = self.vy + ADV_GRAVITY * dt * gravDir
    self:moveAndCollide(level, self.vx * dt, self.vy * dt)

    self.animT = self.animT + dt
    if self.animT >= 1 / WALK_FPS then
        self.animT = self.animT - 1 / WALK_FPS
        self.frame = (self.frame % 3) + 1
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────
local function drawSpike(cx, topY, sH, spikeDir)
    if sH < 1 then return end
    local halfW = SPIKE_W / 2
    local baseY = topY
    local tipY  = topY + sH * spikeDir

    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.polygon('fill',
        cx,          tipY,
        cx - halfW,  baseY,
        cx + halfW,  baseY)
    love.graphics.setColor(0.55, 0.55, 0.60, 0.8)
    love.graphics.polygon('line',
        cx,          tipY,
        cx - halfW,  baseY,
        cx + halfW,  baseY)
end

function Crabby:render(camX, camY)
    local img    = self.currentImg or imgIdle2
    local scaleX = GUMMY_SCALE * self.facing
    local scaleY = GUMMY_SCALE

    if self.state == 'idle' then
        local breathe = math.sin(self.breatheT * BREATHE_SPEED * math.pi)
        scaleY = GUMMY_SCALE * (1.0 + breathe * BREATHE_AMP)
        scaleX = GUMMY_SCALE * self.facing * (1.0 - breathe * BREATHE_AMP * 0.4)
    end

    love.graphics.setColor(1, 1, 1, 1)

    local iw = img:getWidth()
    local ih = img:getHeight()
    local drawX = math.floor(self.x - camX)

    -- Posición de los "pies" en pantalla.
    -- Normal:  pies abajo  → self.y + sprH/2
    -- Flipped: pies arriba → self.y - sprH/2
    local feetY
    if self.flipped then
        feetY = math.floor(self.y - camY - self.sprH / 2)
    else
        feetY = math.floor(self.y - camY + self.sprH / 2)
    end

    -- Altura visual del sprite actual en px mundo
    local spriteVisH = ih * math.abs(scaleY)

    -- ── Pincho: en la "cabeza" del sprite (lado opuesto a los pies) ──────────
    if self.spikeProgress > 0 then
        local sH = SPIKE_MAX_H * self.spikeProgress
        if self.flipped then
            -- Invertido: cabeza está abajo → pincho crece hacia abajo
            local headY = feetY + spriteVisH
            drawSpike(drawX, headY, sH, 1)
        else
            -- Normal: cabeza está arriba → pincho crece hacia arriba
            local headY = feetY - spriteVisH
            drawSpike(drawX, headY, sH, -1)
        end
    end

    -- ── Sprite: siempre anclado por la base de la imagen (ih) ────────────────
    -- Para flipped: scaleY negativo invierte el sprite verticalmente.
    -- El origen (iw/2, ih) corresponde a los pies del bicho.
    -- Con scaleY negativo, el sprite se extiende hacia arriba desde feetY →
    -- pero feetY está arriba (techo), así que realmente se extiende hacia abajo.
    -- Con scaleY positivo (normal), se extiende hacia arriba desde feetY (suelo).
    love.graphics.setColor(1, 1, 1, 1)
    local finalScaleY = self.flipped and -scaleY or scaleY
    love.graphics.draw(img,
        drawX, feetY,
        0, scaleX, finalScaleY,
        iw / 2, ih)

    love.graphics.setColor(1, 1, 1, 1)
end

function Crabby:renderDebug(camX, camY)
    if self:isBodyDisabled() then
        local ob = self:getOuterBounds()
        love.graphics.setColor(0.5, 0.5, 0.5, 0.25)
        love.graphics.rectangle('line', ob.x - camX, ob.y - camY, ob.w, ob.h)
    else
        local ob = self:getOuterBounds()
        love.graphics.setColor(0.10, 0.55, 1.0, 0.55)
        love.graphics.rectangle('line', ob.x - camX, ob.y - camY, ob.w, ob.h)
        local ib = self:getInnerBounds()
        love.graphics.setColor(0.10, 0.15, 1.0, 0.55)
        love.graphics.rectangle('line', ib.x - camX, ib.y - camY, ib.w, ib.h)
    end

    local spk = self:getSpikeHitbox()
    if spk then
        love.graphics.setColor(1, 0.3, 0.3, 0.6)
        love.graphics.rectangle('line', spk.x - camX, spk.y - camY, spk.w, spk.h)
    end

    love.graphics.setColor(0.2, 0.6, 1, 0.22)
    love.graphics.line(self.leftBoundPx  - camX, 0, self.leftBoundPx  - camX, WINDOW_H)
    love.graphics.line(self.rightBoundPx - camX, 0, self.rightBoundPx - camX, WINDOW_H)
end

-- ── Helpers de imagen para sincronización online ─────────────────────────────
-- Devuelve un nombre de string para la imagen actual (usado por el servidor).
function Crabby:getImgName()
    local img = self.currentImg or imgIdle2
    if img == imgIdle1      then return 'idle1'  end
    if img == imgIdle2      then return 'idle2'  end
    if img == imgIdle3      then return 'idle3'  end
    if img == imgDead       then return 'dead'   end
    if img == imgHid        then return 'hid'    end
    if img == imgLookin     then return 'lookin' end
    if img == imgMeatCrabby then return 'meat'   end
    return 'idle2'
end

-- Establece currentImg desde el nombre de string (usado por el cliente).
function Crabby:setImgFromName(name)
    if not name then return end
    if name == 'idle1'  then self.currentImg = imgIdle1      end
    if name == 'idle2'  then self.currentImg = imgIdle2      end
    if name == 'idle3'  then self.currentImg = imgIdle3      end
    if name == 'dead'   then self.currentImg = imgDead       end
    if name == 'hid'    then self.currentImg = imgHid        end
    if name == 'lookin' then self.currentImg = imgLookin     end
    if name == 'meat'   then self.currentImg = imgMeatCrabby end
end

return Crabby