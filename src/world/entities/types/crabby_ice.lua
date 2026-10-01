-- Crabby HELADO: el mismo Crabby (anda, trepa, cae del techo, súbdito...) con el aspecto del
-- cangrejo antártico (assets/images/crabby_ice/, tools/ui/make_icecrabby_sprites.py) y una TAPA
-- a elegir para esconderse, en suelo, pared o techo (en el editor: una sola ficha "Crabby
-- helado" con selector "Se esconde bajo"):
--   púa de hielo  como el Crabby normal: tocarla mata; cae del techo como un pincho (mata)
--   trampolín     como el Crabby trampolín: rebota; del techo aplasta (crabbytramp.lua)
--   carámbano     el carámbano de la Gran Bola de Nieve: tocarlo = 2 de vida + empujón; cae del
--                 techo como un carámbano (2 de vida + empujón) y se queda clavado como el pincho
--   nieve         un MONTÓN DE NIEVE (pasa por una decoración): escondido es inofensivo.
--                 Tocarlo: se agrieta SNOW_CRACK s (sin daño: da tiempo a apartarse) y revienta:
--                 quien siga encima pierde 1 de vida y sale empujado. Caerle encima: revienta
--                 debajo y te lanza hacia arriba (sin daño). Ground pound encima: lo aplasta.
--                 Del techo cae como un pegote de nieve: a quien pille, 1 de vida y aturdido.
-- Esconderse: con objeto (púa, carámbano, trampolín) le sale del lomo y baja con el caparazón,
-- que se hunde fila a fila; con nieve el montón crece DELANTE mientras se hunde detrás.
-- Todo lo que se dibuja sale de state + deadTimer + spikeProgress (igual online).

local Entity          = require 'src/world/entities/Entity'
local Interactions    = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Crawler         = require 'src/world/entities/Crawler'
local Crabby          = require('src/world/entities/types/crabby').class
local TC              = require('src/world/entities/types/crabbytramp').class

local S = GUMMY_SCALE
local D = 'assets/images/crabby_ice/'
local SNOW_CRACK = 0.25          -- s agrietándose (sin daño) antes de reventar
local SNOW_BURST = 0.35          -- s saliendo del montón
local SNOW_W, SNOW_H = 18 * S, 8 * S
local ICICLE_W, ICICLE_H = 8 * S, 14 * S
local ICICLE_DMG = 2
local LUMP_STUN = 0.8            -- s aturdido si le cae encima el pegote de nieve

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

local imgSnow, imgSnowCracked, imgIcicle, imgTN, imgTE
local function loadIce()
    if imgSnow then return end
    local function img(f)
        local i = love.graphics.newImage(D .. f)
        if i.setFilter then i:setFilter('nearest', 'nearest') end
        return i
    end
    imgSnow, imgSnowCracked, imgIcicle = img('snow.png'), img('snow_cracked.png'), img('icicle.png')
    imgTN, imgTE = img('tramp_normal.png'), img('tramp_extended.png')
end

local Ice = Entity.extend(Crabby, { debugColor = { 1, 0.55, 0.25 } })
Ice.skinId = 'ice'
function Ice.loadAssets() Crabby.loadAssets(); loadIce() end
function Ice.sizeImage() return Crabby.SKINS.ice.idle1 end

function Ice:init()
    Crabby.init(self)
    self.cover = self.def.cover or 'spike'
    if self.cover == 'spike' then self.spikeFile = D .. 'spike.png' end
    -- púa y carámbano encajados 2 px de arte en el caparazón (como la púa del Mega helado)
    if self.cover == 'spike' or self.cover == 'icicle' then self.topperDy = 2 end
    if self.cover == 'snow' then self.coverFront, self.noPeek = true, true end
end

-- ── Carámbano: medidas, daño y dibujo ─────────────────────────────────────────
function Ice:spikeDims()
    if self.cover == 'icicle' then return ICICLE_W, ICICLE_H, ICICLE_W * 0.6, ICICLE_H * 0.8 end
    return Crabby.spikeDims(self)
end

function Ice:getHazardBoxes()
    if self.cover == 'snow' then return nil end
    local b = self:getSpikeHitbox()
    if not b then return nil end
    if self.cover == 'icicle' then b.effect, b.dmg = 'hurt', ICICLE_DMG end
    return { b }
end

-- (el carámbano: además del daño, empujón hacia fuera)
function Ice:onHurtPlayer(pa)
    if self.cover == 'icicle' then pa:recoil((pa.x >= self.x) and 1 or -1) end
end

function Ice:drawTopper(cx, baseY, progress, dir)
    if progress <= 0.01 then return end
    love.graphics.setColor(1, 1, 1, 1)
    if self.cover == 'icicle' then
        -- (dibujado con la punta abajo: base del carámbano en baseY, crece hacia fuera)
        love.graphics.draw(imgIcicle, cx, baseY, 0, S, (dir < 0 and -S or S) * progress, 4, 0)
    elseif self.cover == 'snow' then
        local img = (self.state == 'snow_crack') and imgSnowCracked or imgSnow
        local sh = 0
        if self.state == 'snow_crack' then sh = math.floor(math.sin(love.timer.getTime() * 60) * 2) end
        love.graphics.draw(img, cx + sh, baseY, 0, S, (dir < 0 and S or -S) * progress, 9, 8)
    else
        Crabby.drawTopper(self, cx, baseY, progress, dir)
    end
end

function Ice:drawStuckTopper(cx, baseY)
    if self.cover == 'icicle' then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(imgIcicle, cx, baseY, 0, S, S, 4, 0)
    else
        Crabby.drawStuckTopper(self, cx, baseY)
    end
end

-- ── Nieve: el montón ──────────────────────────────────────────────────────────
-- Caja del montón (sobre la superficie: suelo, techo o pared)
function Ice:moundBox()
    local h = SNOW_H * math.max(0.3, self.spikeProgress)
    if (Crawler.onWall(self) and self.cattached) or Crawler.turning(self) then
        return Crawler.poseBox(self, -SNOW_W / 2, self.sprH / 2 - h, SNOW_W, h)
    end
    if self.flipped then return { x = self.x - SNOW_W / 2, y = self.y - self.sprH / 2, w = SNOW_W, h = h } end
    return { x = self.x - SNOW_W / 2, y = self.y + self.sprH / 2 - h, w = SNOW_W, h = h }
end

local SNOW_HIDING = { hidden = true, snow_crack = true }
function Ice:snowHiding()
    return self.cover == 'snow' and (SNOW_HIDING[self.state] or (self.state == 'hide_in' and self.spikeProgress > 0.6))
end

-- Escondido en la nieve se le puede aplastar (ground pound encima)
function Ice:canBeStomped()
    if self:snowHiding() then return true end
    return Crabby.canBeStomped(self)
end

-- (sin efectos: el cliente online lo usa para predecir el rebote)
function Ice:interact(pa)
    if self.cover == 'snow' then
        if self:snowHiding() then
            local mb, pob = self:moundBox(), pa:getOuterBounds()
            if not overlap(pob, mb) then return nil end
            local fromAbove = not self.flipped and not (Crawler.onWall(self) and self.cattached)
                              and pob.y + pob.h <= mb.y + mb.h * 0.6 + 8
            if fromAbove and pa.gpPhase == 'fall' then
                return 'stomp', -math.abs(ADV_JUMP_VEL) * Interactions.BOUNCE, self.props.points
            end
            if fromAbove and pa.vy > 0 then
                return 'bounce', -math.abs(ADV_JUMP_VEL) * 0.9
            end
            return nil                                       -- (tocarlo lo agrieta: ver updateCustom)
        end
        if self.state == 'snow_burst' or self.state == 'drop_fall' then return nil end
    end
    return Interactions.defaultCheck(pa, self)
end

-- Le cae encima al montón: revienta debajo y lo lanza (a él no le hace daño)
function Ice:onBounced(pa)
    self.spare = pa
    self:burst()
end

-- Revienta: sale del montón; quien siga encima (salvo `spare`) pierde 1 de vida y sale empujado
function Ice:burst(level)
    level = level or self.levelRef
    self.state, self.deadTimer = 'snow_burst', 0
    self.spikeProgress = 0
    self.currentImg = self.sk.idle2
    Sound.play('crabPop')
    Sound.play('snowSplat', 1.2, 0.7)
    Entity.emitFx('snow_puff', self.x, self.y + (self.flipped and -1 or 1) * self.sprH * 0.3)
    local players = level and level.players or {}
    local box = self:getOuterBounds()
    for _, pa in ipairs(players) do
        if pa ~= self.spare and not pa.dying and pa.alive ~= false and not pa:isInvulnerable()
           and overlap(pa:getOuterBounds(), box) then
            local dir = (pa.x >= self.x) and 1 or -1
            PlayerAdventure.asOwner(pa, function()
                if not pa:hurt(1) then pa:recoil(dir) end
            end)
        end
    end
    self.spare = nil
end

function Ice:endBurst(level)
    self.spikeProgress = 0
    self.currentImg = self.sk.idle2
    if self.fromDrop then
        self.fromDrop = nil
        self.dropped = true
        if self.crawl then Crawler.detach(self); Crawler.attach(self, level); self.cdir = self.facing end
    end
    self.vx = self.moving and self.speed * self.facing or 0
    self:startWalk()
end

function Ice:updateCustom(dt, level)
    self.levelRef = level
    if self.cover == 'snow' and level.canBreak ~= false then
        local st = self.state
        if st == 'hidden' then
            -- Alguien toca el montón: se agrieta (aviso, sin daño)
            local mb = self:moundBox()
            mb = { x = mb.x - 2, y = mb.y - 2, w = mb.w + 4, h = mb.h + 4 }
            for _, pa in ipairs(level.players or {}) do
                local pob = pa:getOuterBounds()
                -- (cayendo encima no: eso es el rebote de interact, que lo revienta debajo)
                local landing = not self.flipped and pa.vy > 0 and pob.y + pob.h <= mb.y + mb.h * 0.6 + 8
                if not pa.dying and pa.alive ~= false and not landing and overlap(pob, mb) then
                    self.state, self.deadTimer = 'snow_crack', 0
                    Sound.play('snowCrack', 1.4, 0.6)
                    return true
                end
            end
        elseif st == 'snow_crack' then
            self.deadTimer = self.deadTimer + dt
            self:fall(level, dt)
            if self.deadTimer >= SNOW_CRACK then self:burst(level) end
            return true
        elseif st == 'snow_burst' then
            self.deadTimer = self.deadTimer + dt
            self:fall(level, dt)
            if self.deadTimer >= SNOW_BURST then self:endBurst(level) end
            return true
        end
    end
    return Crabby.updateCustom(self, dt, level)
end

-- Del techo con nieve: cae como un pegote; a quien pille, 1 de vida y aturdido; al llegar
-- al suelo revienta y sigue andando
function Ice:updateDrop(dt, level)
    if self.cover ~= 'snow' or self.state ~= 'drop_fall' then return Crabby.updateDrop(self, dt, level) end
    self.deadTimer = self.deadTimer + dt
    self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1300)
    local b0 = self.y + self.sprH / 2
    self.y = self.y + self.vy * dt
    local b1 = self.y + self.sprH / 2
    local box = { x = self.x - SNOW_W / 2, y = self.y - self.sprH / 2, w = SNOW_W, h = self.sprH }
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() and pa.y > self.y
           and overlap(pa:getOuterBounds(), box) then
            PlayerAdventure.asOwner(pa, function()
                if not pa:hurt(1) then
                    pa.stunT = math.max(pa.stunT or 0, LUMP_STUN)
                    Sound.play('stunned')
                end
            end)
            Sound.play('snowSplat')
            Entity.emitFx('snow_puff', pa.x, pa.y - 30)
        end
    end
    for _, fx in ipairs({ -0.3, 0, 0.3 }) do
        local t, top = level:landingCross(self.x + SNOW_W * fx, b0, b1)
        if t then
            self.y = top - self.sprH / 2
            self.vy, self.flipped, self.onGround = 0, false, true
            self.fromDrop = true
            Sound.play('snowLand', 1.4, 0.6)
            self:burst(level)
            return true
        end
    end
    if self.y > level.heightPx + TILE_PX * 4 then self.alive = false end
    return true
end

-- Saliendo del montón: un saltito (solo dibujo, del reloj del estado)
function Ice:renderBody(camX, camY)
    if self.state == 'snow_burst' then
        local k = math.min(1, (self.deadTimer or 0) / SNOW_BURST)
        local hop = math.floor(math.sin(k * math.pi) * 10)
        return Crabby.renderBody(self, camX, camY + (self.flipped and -hop or hop))
    end
    return Crabby.renderBody(self, camX, camY)
end

-- ── Trampolín helado ──────────────────────────────────────────────────────────
local IceTramp = Entity.extend(TC, { debugColor = { 1, 0.55, 0.25 } })
IceTramp.skinId = 'ice'
function IceTramp.loadAssets() TC.loadAssets(); loadIce() end
function IceTramp.sizeImage() return Crabby.SKINS.ice.idle1 end
function IceTramp:trampImages() return imgTN, imgTE end

-- ── Definiciones: una ficha "Crabby helado" con selector de tapa ─────────────
local HIDE_PROPS = function(label, chance)
    return {
        { key='canHide', kind='bool', label='Se esconde (' .. label .. ')', group='Comportamiento', default=true,
          showIf=function(p) return p.pauses end },
        { key='hideChance', kind='number', label='Probabilidad de esconderse', group='Comportamiento',
          default=chance, min=0, max=1, step=0.05, showIf=function(p) return p.pauses and p.canHide end },
    }
end

local function editorIcon(cover)
    return function(x, y, s)
        Ice.loadAssets()
        local k = s / 18
        local body = Crabby.SKINS.ice.idle1
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(body, x, y + s - body:getHeight() * k, 0, k, k)
        if cover == 'snow' then
            love.graphics.draw(imgSnow, x, y + s - 8 * k, 0, k, k)
        elseif cover == 'icicle' then
            love.graphics.draw(imgIcicle, x + 9 * k, y + s - 13 * k, 0, k, -k, 4, 0)
        elseif cover == 'tramp' then
            love.graphics.draw(imgTN, x + 1 * k, y - 2 * k, 0, k, k)
        end
    end
end

local DESC = {
    spike  = 'Crabby helado que se esconde bajo una púa de hielo (mata, como la púa del Crabby).',
    icicle = 'Crabby helado que se esconde bajo un carámbano: tocarlo quita 2 de vida y empuja. '
          .. 'Del techo cae como un carámbano.',
    snow   = 'Crabby helado que se esconde en un montón de nieve (parece decoración). Al tocarlo se '
          .. 'agrieta y revienta: 1 de vida + empujón. Caerle encima te lanza; ground pound, lo aplasta.',
    tramp  = 'Crabby helado con trampolín de hielo: como el Crabby trampolín.',
}

local defs = {}
for _, d in ipairs({ { 'spike', 'crabby_ice', 'Púa de hielo', 0.75 }, { 'icicle', 'crabby_ice_icicle', 'Carámbano', 0.75 },
                     { 'snow', 'crabby_ice_snow', 'Nieve', 0.85 } }) do
    local cls = Entity.extend(Ice)
    local props = HIDE_PROPS(d[3]:lower(), d[4])
    props[#props + 1] = Crabby.WALL_PROP
    defs[#defs + 1] = {
        name = d[2], label = 'Crabby helado (' .. d[3]:lower() .. ')', category = 'Enemigos', class = cls,
        cover = d[1], description = DESC[d[1]],
        variant = { group = 'crabby_ice', label = d[3], groupLabel = 'Crabby helado', prop = 'Se esconde bajo' },
        defaults = { speed = 50, points = 15 }, props = props,
        editor = { sprite = D .. 'crab1.png', draw = editorIcon(d[1]) },
    }
end
do
    local props = HIDE_PROPS('trampolín', 0.85)
    props[#props + 1] = { key='power', kind='number', label='Fuerza del trampolín', group='Trampolín', default=1.6,
                          min=0.5, max=4, step=0.05 }
    props[#props + 1] = { key='crushDamage', kind='int', label='Daño al caer encima', group='Trampolín', default=1,
                          min=0, max=3, step=1, help='Vida que quita si cae del techo sobre un jugador (siempre lo aplasta y aturde)' }
    props[#props + 1] = Crabby.WALL_PROP
    defs[#defs + 1] = {
        name = 'crabbytramp_ice', label = 'Crabby helado (trampolín)', category = 'Enemigos', class = IceTramp,
        cover = 'tramp', description = DESC.tramp,
        variant = { group = 'crabby_ice', label = 'Trampolín', groupLabel = 'Crabby helado', prop = 'Se esconde bajo' },
        defaults = { speed = 50, points = 15 }, props = props,
        editor = { sprite = D .. 'crab1.png', draw = editorIcon('tramp') },
    }
end
return defs
