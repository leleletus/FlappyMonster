-- Crabby: cangrejo que camina por suelo o techo (propiedad attach). Tras una
-- pausa puede esconderse en su caparazón: saca un pincho (zona de peligro) y
-- mientras está escondido no se le puede pisotear. De vez en cuando se asoma.
local Entity  = require 'src/world/entities/Entity'
local Crawler = require 'src/world/entities/Crawler'

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

-- ASPECTO (skin): las imágenes de cada momento. El Crabby normal usa 'normal'; el Crabby
-- helado (crabby_ice.lua) usa 'ice': su propio cangrejo y, al esconderse, se HUNDE fila a
-- fila (8 cuadros) en vez de pasar de golpe de meat → lookin → nada. Cada instancia guarda
-- el suyo en self.sk (los nombres de red llevan el prefijo de la skin: son únicos).
local imgIdle1, imgIdle2, imgHid
local IMG_NAMES, IMG_BY_NAME = {}, {}
Crabby.SKINS = {}

local function addSkin(id, dir, o)
    local sk = { id = id }
    local function img(f) return love.graphics.newImage(dir .. f) end
    sk.idle1, sk.idle2, sk.idle3 = img('crab1.png'), img('crab2.png'), img('crab3.png')
    sk.dead   = img('dead.png')                           -- (aplastado: el suyo, no el del Gummy)
    sk.hid    = img('hid.png')
    sk.lookin = img(o.lookin or 'lookin.png')
    sk.meat   = img(o.meat or 'meat.png')
    -- inset[img] = filas vacías ARRIBA del cuadro (los de hundirse del helado conservan el lienzo
    -- 18x8 y van bajando: sin esto la tapa flotaba sobre el caparazón; ver Crabby:headH)
    sk.inset = {}
    if o.sink then
        sk.hideIn = {}
        for i = 1, o.sink do
            sk.hideIn[i] = img('sink' .. i .. '.png')
            sk.inset[sk.hideIn[i]] = i - 1
        end
        sk.inset[sk.hid] = 1                              -- (escondido: la tapa apoya en la superficie)
        sk.hideIn[#sk.hideIn + 1] = sk.hid
        sk.hideOut = {}
        for i = o.sink, 1, -1 do sk.hideOut[#sk.hideOut + 1] = sk.hideIn[i] end
        sk.hideOut[#sk.hideOut + 1] = sk.idle2
    else
        sk.hideIn  = { sk.meat, sk.lookin, sk.hid }       -- crab2 → Meat → lookin → hid
        sk.hideOut = { sk.lookin, sk.meat, sk.idle2 }     -- hid → lookin → Meat → crab2
    end
    sk.walk = { sk.idle1, sk.idle2, sk.idle3 }
    -- (la secuencia dura lo mismo con 3 o con 9 cuadros)
    sk.frameDur = (0.25 * 3) / #sk.hideIn
    local pre = (id == 'normal') and '' or (id .. '_')
    for n, im in pairs({ idle1 = sk.idle1, idle2 = sk.idle2, idle3 = sk.idle3, hid = sk.hid,
                         lookin = sk.lookin, meat = sk.meat, dead = sk.dead }) do
        IMG_NAMES[im], IMG_BY_NAME[pre .. n] = pre .. n, im
    end
    for i, im in ipairs(sk.hideIn) do
        if not IMG_NAMES[im] then IMG_NAMES[im], IMG_BY_NAME[pre .. 's' .. i] = pre .. 's' .. i, im end
    end
    Crabby.SKINS[id] = sk
    return sk
end

function Crabby.loadAssets()
    if imgIdle1 then return end
    local sk = addSkin('normal', 'assets/images/crabby/', { meat = 'MeatCrabby.png' })
    imgIdle1, imgIdle2, imgHid = sk.idle1, sk.idle2, sk.hid
    addSkin('ice', 'assets/images/crabby_ice/', { sink = 8 })
    addSkin('fortress', 'assets/images/crabby_fortress/', {})        -- (acero con remaches: types/crabby_fortress.lua)
    -- Especies con OTRA forma (tools/ui/make_crab_species.py): se hunden fila a fila como el helado y llevan las
    -- pinzas del juego en su color. `claw`: x desde el centro, y desde los pies (px de arte), cuánto se mete
    addSkin('river', 'assets/images/crabby_river/', { sink = 5 })    -- (types/crabby_river.lua)
    Crabby.SKINS.river.claw = { file = 'assets/images/crabby_river/claw_left-Sheet.png', w = 5, x = 4.4, y = -1.6, inset = 0.5 }
    addSkin('cave', 'assets/images/crabby_cave/', { sink = 6 })      -- (types/crabby_cave.lua; sin pinzas)
    addSkin('lava', 'assets/images/crabby_lava/', { sink = 6 })      -- (types/crabby_lava.lua)
    Crabby.SKINS.lava.claw = { file = 'assets/images/crabby_lava/claw_left-Sheet.png', w = 5, x = 5.4, y = -1.6, inset = 0.5 }
    -- Pinzas pequeñas del Crabby helado (tools/ui/make_icecrabby_claws.py, opción A "Mini Mega"):
    -- 2 cuadros 7x7 (abierta / cerrada), pinza IZQUIERDA (la derecha es su espejo); dónde van en
    -- px de arte del cuerpo como en el Mega (x desde el centro, y desde los pies, hacia dentro)
    Crabby.SKINS.ice.claw = { file = 'assets/images/crabby_ice/claw_left-Sheet.png', w = 7,
                              x = 5.6, y = -0.6, inset = 1.0 }
end

function Crabby.sizeImage() return imgIdle1 end
function Crabby:skin() return self.sk or Crabby.SKINS.normal end

-- Propiedad propia de los Crabbies (también la usa el Crabby trampolín)
Crabby.WALL_PROP = { key='wallWalk', kind='bool', label='Anda por paredes y techos', group='Movimiento',
    default=false, help='Da la vuelta a los bloques: suelo, paredes y techo, girando en las esquinas',
    showIf=function(p) return p.movement == 'walk' end }

local function seqFrame(elapsed, frames, dur)
    local idx = math.floor(elapsed / (dur or SPRITE_FRAME_DUR)) + 1
    return frames[math.max(1, math.min(idx, #frames))]
end

function Crabby:init()
    self.sk = self.sk or Crabby.SKINS[self.skinId or 'normal'] or Crabby.SKINS.normal
    self.hideTransTimer = 0
    self.hideTimer, self.hideDuration = 0, 0
    self.peekCountdown = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
    self.peekTimer, self.peekDuration = 0, 0
    self.peeking       = false
    self.currentImg    = self.sk.idle1
    self.spikeProgress = 0
    -- Anda por paredes y techos (Crawler): se agarra a la superficie al empezar
    self.crawl = (self.props.wallWalk == true) and self.moving and not self.flying
    if self.crawl then
        self.cnx, self.cny = 0, self.flipped and 1 or -1
        self.cdir = self.flipped and -self.facing or self.facing
        self.cattached = nil
    end
end

-- (Súbdito de reserva: Entity:makeReserve / netAtRest / netRest, genérico. Sin ruta: heredaban la
-- ruta por defecto de un Crabby alrededor del sitio del jefe y el empujón de un ground pound los
-- "teletransportaba" al borde de esa ruta, a veces encima del jugador.)

-- Atado a una zona (súbditos): los bordes de la zona cuentan como paredes
function Crabby:crawlSolidAt(level, x, y)
    if level:entitySolidAt(x, y) then return true end
    local z = self.leashZone
    return z ~= nil and (x < z.x0 or x > z.x1 or y < z.y0 or y > z.y1)
end

-- ── Por paredes y techos ──────────────────────────────────────────────────────
function Crabby:tryAttach(level)
    if self.crawl and not self.cattached then Crawler.attach(self, level, self.cattached == nil and TILE_PX or nil) end
end

-- Pegado a una superficie no cae
function Crabby:fall(level, dt)
    if self.crawl and self.cattached then return end
    Entity.fall(self, level, dt)
end

-- Se suelta (empujón de un ground pound, caída desde el techo...): vuelve a
-- agarrarse cuando toque el suelo
function Crabby:releaseCrawl()
    if not self.crawl then return end
    Crawler.detach(self)
    self.flipped = false
end

function Crabby:knockback(dir)
    self:releaseCrawl()
    Entity.knockback(self, dir)
end

-- Andar trepando (sustituye al andar normal)
function Crabby:crawlWalk(dt, level)
    local tn = self.tuning
    if not self.cattached then
        -- Suelto: cae hasta el suelo y se vuelve a agarrar
        self.flipped = false
        Entity.fall(self, level, dt)
        if self.onGround then
            self.cnx, self.cny = 0, -1
            -- (en el canto de una plataforma no hay superficie bajo su centro: se arrima hasta poder agarrarse)
            if not Crawler.attach(self, level) then Crawler.edgeRescue(self, level, dt) end
            self.cdir = self.facing
        end
        return true
    end
    self:onWalk(dt)
    if self.props.pauses then
        self.idleCountdown = self.idleCountdown - dt
        if self.idleCountdown <= 0 then self:startIdle(); return true end
    end
    -- Otra entidad delante: media vuelta
    if Crawler.entityAhead(self, level) then self.cdir = -self.cdir end
    if not Crawler.move(self, level, self.speed * dt) then return true end
    -- Encima de la cara que lanza de un trampolín: ¡BOOM!
    local body, face = Crawler.supportBody(self, level)
    if body and self:touchBody(body, face) then return true end
    -- Orientación: techo = boca abajo; de frente según hacia dónde avanza
    self.flipped = (self.cny == 1)
    -- De vuelta en el techo tras caer: puede volver a dejarse caer (el
    -- Crabby de techo normal se queda en el suelo; el trepador repite)
    if self.flipped and self.dropped then self.dropped = false end
    if self.cnx ~= 0 then self.facing = self.cdir
    else self.facing = ((-self.cny * self.cdir) >= 0) and 1 or -1 end
    self.animT = self.animT + dt
    if self.animT >= 1 / tn.walkFps then
        self.animT = self.animT - 1 / tn.walkFps
        self.frame = (self.frame % tn.walkFrames) + 1
    end
    return true
end

-- En una pared la hitbox está girada; girando en una esquina, con la pose real
local stuckCenterY, dropTipY      -- (del clavado boca abajo: se definen con la caída, más abajo)
function Crabby:getOuterBounds()
    if Crawler.turning(self) then
        return Crawler.poseBox(self, -self.outerW / 2, -self.outerH / 2, self.outerW, self.outerH)
    end
    if Crawler.onWall(self) and self.cattached then
        return { x = self.x - self.outerH / 2, y = self.y - self.outerW / 2, w = self.outerH, h = self.outerW }
    end
    if self.state == 'drop_stuck' then              -- (clavado boca abajo: la caja, donde se ve el cuerpo)
        return { x = self.x - self.outerW / 2, y = stuckCenterY(self) - self.outerH / 2, w = self.outerW, h = self.outerH }
    end
    return Entity.getOuterBounds(self)
end
function Crabby:getInnerBounds()
    if Crawler.turning(self) then
        return Crawler.poseBox(self, -self.innerW / 2, -self.innerH / 2, self.innerW, self.innerH)
    end
    if Crawler.onWall(self) and self.cattached then
        return { x = self.x - self.innerH / 2, y = self.y - self.innerW / 2, w = self.innerH, h = self.innerW }
    end
    if self.state == 'drop_stuck' then
        return { x = self.x - self.innerW / 2, y = stuckCenterY(self) - self.innerH / 2, w = self.innerW, h = self.innerH }
    end
    return Entity.getInnerBounds(self)
end

-- ── Estados comunes con sprite/pincho propios ────────────────────────────────
function Crabby:onWalk()
    self.spikeProgress = 0
    self.currentImg = self.sk.walk[self.frame] or self.sk.idle2
end

function Crabby:onIdle()
    self.currentImg    = self.sk.idle2
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
    self.currentImg    = self.sk.dead
    self.spikeProgress = 0
end

function Crabby:onStomp()
    self.spikeProgress = 0
    self.currentImg    = self.sk.dead
end

-- Aplastado mientras estaba clavado boca abajo: queda boca abajo (flipped viaja por red) y en
-- el suelo donde tenía clavado el pincho, no dibujado de pie donde estaba su caja
function Crabby:stomp()
    local stuck = self.state == 'drop_stuck'
    local floorY
    if stuck then
        local _, maxH = self:spikeDims()
        floorY = dropTipY(self) - maxH * STUCK_EMBED
    end
    Entity.stomp(self)
    if stuck and self.state == 'dead' then
        self.flipped = true
        self.y = floorY - self.sk.dead:getHeight() * GUMMY_SCALE + self.sprH / 2
    end
end

function Crabby:canBeStomped() return not self:isBodyDisabled() end

-- Del techo: detecta al jugador también escondido y cae directamente
local HIDE_STATES = { hide_in = true, hidden = true, hide_out = true }
function Crabby:isHiding() return HIDE_STATES[self.state] == true end
function Crabby:canDropNow() return self.state == 'walk' or self.state == 'idle' or self:isHiding() end
function Crabby:isBodyDisabled() return self.currentImg == self.sk.hid end

-- ── Caída desde el techo ──────────────────────────────────────────────────────
-- w, maxH (lo que se ve) y hitW, hitMaxH: la zona de peligro es la de un
-- pincho de tile (Level._spikeHitbox), un rectángulo en la BASE del 60% del
-- ancho y el 40% del alto (sin la punta)
local function spikeDims()
    local w, h = 9 * GUMMY_SCALE, 9 * GUMMY_SCALE
    return w, h, w * 0.6, h * 0.4
end

-- Base del pincho (boca abajo): pies arriba, cabeza abajo y el pincho debajo.
-- Se mide siempre con el sprite escondido, así el pincho no se mueve aunque
-- cambie el sprite: clavado, el cangrejo "sale" hacia arriba desde el pincho.
function Crabby:spikeDims() return spikeDims() end

local function dropSpikeBaseY(self)
    return self.y - self.sprH / 2 + self.sk.hid:getHeight() * GUMMY_SCALE
end
dropTipY = function(self)
    local _, maxH = self:spikeDims()
    return dropSpikeBaseY(self) + maxH
end
-- Clavado (boca abajo): la línea de la CABEZA. El pincho no se mueve; la cabeza se apoya en su
-- base, `topperDy` px de arte más adentro (la púa de hielo y el carámbano van encajados en el
-- caparazón, igual que de pie: sin esto quedaba un hueco de 2 px entre la púa y la cabeza)
local function stuckHeadY(self)
    return dropSpikeBaseY(self) + (self.topperDy or 0) * GUMMY_SCALE
end
-- … y el centro de su CUERPO: está ENCIMA del pincho, no donde dice self.y (que es donde está
-- el pincho). Lo usan sus cajas (el pisotón) y el dibujo.
stuckCenterY = function(self) return stuckHeadY(self) - self.sprH / 2 end

function Crabby:updateDrop(dt, level)
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    local t = self.deadTimer
    if st == 'drop_shake' then
        -- Tiembla y se esconde: sale el pincho y se mete en el caparazón
        -- (si ya estaba escondido, tiembla dentro del caparazón)
        self.vx = 0
        if self.dropHidden then
            self.currentImg, self.spikeProgress = self.sk.hid, 1
        elseif t < 0.2 then
            self.currentImg, self.spikeProgress = self.sk.idle2, math.min(1, t / 0.2)
        else
            self.spikeProgress = 1
            self.currentImg = self.sk.hideIn[math.min(#self.sk.hideIn, math.floor((t - 0.2) / (0.3 / #self.sk.hideIn)) + 1)]
        end
        if t >= DROP_SHAKE then
            self.state, self.deadTimer, self.vy = 'drop_fall', 0, 0
            self.currentImg, self.spikeProgress = self.sk.hid, 1
            -- Trepador: se suelta del techo. Si no, seguiría "boca abajo" para
            -- las reglas (pisotón solo desde abajo) aunque ya esté clavado en
            -- el suelo, y saltarle encima mataría al jugador
            self:releaseCrawl()
            self.flipped = true
        end
    elseif st == 'drop_fall' then
        -- Cae como un pincho (sigue boca abajo) hasta clavarse en el suelo
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1400)
        local tip0 = dropTipY(self)
        self.y = self.y + self.vy * dt
        local tip = dropTipY(self)
        -- (solo lo que cruza desde arriba: la losa de la que colgaba no cuenta)
        local hit, top = level:landingCross(self.x, tip0, tip)
        if hit then
            local _, maxH = self:spikeDims()
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
            self.currentImg = self.sk.hid
        elseif t < STUCK_HID + SPRITE_SEQ_TIME then
            self.currentImg = seqFrame(t - STUCK_HID, self.sk.hideOut, self.sk.frameDur)
        else
            local k = math.floor((t - STUCK_HID - SPRITE_SEQ_TIME) * WIGGLE_FPS) % #self.sk.walk + 1
            self.currentImg = self.sk.walk[k]
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
        self.currentImg = self.sk.idle2
        self.vy = self.vy + ADV_GRAVITY * dt
        self:moveAndCollide(level, 0, self.vy * dt)
        if self.onGround and t >= GETUP_TIME * 0.6 then
            self.dropped = true
            self.spikeProgress = 0
            self.vx = self.moving and self.speed * self.facing or 0
            if self.crawl then Crawler.detach(self); Crawler.attach(self, level); self.cdir = self.facing end
            self:startWalk()
        end
    end
    return true
end

-- ── Esconderse / asomarse ────────────────────────────────────────────────────
function Crabby:updateCustom(dt, level)
    if self.state == 'reserve' then return true end
    Crawler.advanceTurn(self, dt)             -- giro en una esquina (ver Crawler)
    local st = self.state
    if st:sub(1, 5) == 'drop_' then self.turnT = nil; return self:updateDrop(dt, level) end
    if self.crawl then
        if self.cattached == nil then Crawler.attach(self, level, TILE_PX) end   -- (al colocarla)
        if st == 'walk' then return self:crawlWalk(dt, level) end
    end
    if st == 'hide_in' then
        -- Fase 1: pincho crece 0→1 (sprite crab2). Fase 2: Meat→lookin→hid
        self.hideTransTimer = self.hideTransTimer + dt
        self:fall(level, dt)
        if self.coverFront then
            -- Tapa DELANTE (montón de nieve): crece desde la superficie mientras se hunde detrás
            self.spikeProgress = math.min(1, self.hideTransTimer / HIDE_TRANSITION)
            self.currentImg = seqFrame(self.hideTransTimer, self.sk.hideIn, self.sk.frameDur)
        elseif self.hideTransTimer < SPIKE_GROW_TIME then
            self.currentImg    = self.sk.idle2
            self.spikeProgress = math.min(1, self.hideTransTimer / SPIKE_GROW_TIME)
        else
            self.spikeProgress = 1
            self.currentImg = seqFrame(self.hideTransTimer - SPIKE_GROW_TIME, self.sk.hideIn, self.sk.frameDur)
        end
        if self.hideTransTimer >= HIDE_TRANSITION then
            self.state         = 'hidden'
            self.currentImg    = self.sk.hid
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
        if self.noPeek then
            self.currentImg = self.sk.hid                 -- (disfraz: nunca se asoma)
        elseif self.peeking then
            self.currentImg = self.sk.lookin
            self.peekTimer  = self.peekTimer + dt
            if self.peekTimer >= self.peekDuration then
                self.peeking       = false
                self.currentImg    = self.sk.hid
                self.peekCountdown = randRange(PEEK_INTERVAL_MIN, PEEK_INTERVAL_MAX)
            end
        else
            self.currentImg    = self.sk.hid
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
        if self.coverFront then
            self.spikeProgress = math.max(0, 1 - self.hideTransTimer / HIDE_TRANSITION)
            self.currentImg = seqFrame(self.hideTransTimer, self.sk.hideOut, self.sk.frameDur)
        elseif self.hideTransTimer < SPRITE_SEQ_TIME then
            self.spikeProgress = 1
            self.currentImg = seqFrame(self.hideTransTimer, self.sk.hideOut, self.sk.frameDur)
        else
            self.currentImg = self.sk.idle2
            self.spikeProgress = math.max(0, 1 - (self.hideTransTimer - SPRITE_SEQ_TIME) / SPIKE_GROW_TIME)
        end
        if self.hideTransTimer >= HIDE_TRANSITION then
            self.state         = 'walk'
            self.currentImg    = self.sk.idle2
            self.spikeProgress = 0
            self.idleCountdown = randRange(self.tuning.idleEvery[1], self.tuning.idleEvery[2])
        end
        return true
    end
    return false
end

-- ── Pincho (zona de peligro) ─────────────────────────────────────────────────
-- Alto (px de pantalla) desde los pies hasta donde se apoya la tapa: la parte de arriba
-- VISIBLE del cuadro actual (sk.inset) menos `topperDy` px de arte (la púa encajada en el
-- caparazón: Crabby helado). Lo usan el dibujo, la zona de peligro y el trampolín.
function Crabby:headH(img)
    img = img or self.currentImg or self.sk.idle2
    local rows = img:getHeight() - ((self.sk.inset and self.sk.inset[img]) or 0)
    return math.max(0, rows - (self.topperDy or 0)) * GUMMY_SCALE
end

function Crabby:getSpikeHitbox()
    if self.spikeProgress <= 0 then return nil end
    -- Clavado en el suelo / levantándose: el pincho no hace daño
    if self.state == 'drop_stuck' or self.state == 'drop_getup' then return nil end
    local _, _, hitW, hitMaxH = self:spikeDims()
    local hitH = hitMaxH * self.spikeProgress
    if hitH < 1 then return nil end
    local spriteVisH = self:headH()
    local sx = self.x - hitW / 2
    if (Crawler.onWall(self) and self.cattached) or Crawler.turning(self) then
        -- En la pared (o girando): la misma caja "encima de la cabeza", girada
        local headLocal = self.sprH / 2 - spriteVisH
        return Crawler.poseBox(self, -hitW / 2, headLocal - hitH, hitW, hitH)
    end
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
function Crabby:getImgName() return IMG_NAMES[self.currentImg or self.sk.idle2] or 'idle2' end
function Crabby:setImgFromName(n) if IMG_BY_NAME[n] then self.currentImg = IMG_BY_NAME[n] end end

Crabby.NET_N = 4          -- campos de red del Crabby (los tipos derivados añaden detrás)

-- Normal de la superficie para las reglas de pisotón (girando: a la que más
-- mira; ver Interactions.defaultCheck)
function Crabby:surfaceNormal()
    if self.crawl and self.cattached then return Crawler.poseNormal(self) end
    return nil
end

function Crabby:netPack()
    -- 3º y 4º: superficie del trepador y progreso del giro (ver Crawler.netPack)
    local surf, turn = Crawler.netPack(self)
    return { math.floor((self.spikeProgress or 0) * 1000 + 0.5), self:getImgName(), surf, turn }
end

function Crabby:netApply(a, b, f)
    a = a or b
    if type(b[1]) == 'number' and type(a[1]) == 'number' then
        self.spikeProgress = (a[1] + (b[1] - a[1]) * f) / 1000
    end
    self:setImgFromName((f < 0.5 and a or b)[2])
    Crawler.netApply(self, b[3], a[4], b[4], f, self.state:sub(1, 5) == 'drop_')
end

-- ── Render ────────────────────────────────────────────────────────────────────
-- Pincho: assets/images/crabby/spike.png (36x36 hacia arriba + 1 px de margen
-- para el contorno). Al salir crece desde la base: se estira en alto.
local spikeImgs = {}
local function drawSpike(cx, baseY, sH, dir, file)
    if sH < 1 then return end
    file = file or 'assets/images/crabby/spike.png'
    local spikeImg = spikeImgs[file]
    if not spikeImg then
        spikeImg = love.graphics.newImage(file)
        spikeImg:setFilter('nearest', 'nearest')
        spikeImgs[file] = spikeImg
    end
    local _, maxH = spikeDims()
    local iw, ih = spikeImg:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(spikeImg, cx, baseY, 0, 1, -dir * sH / maxH, iw / 2, ih - 1)
end

-- Lo que saca del caparazón al esconderse (dir = -1 hacia arriba, 1 hacia
-- abajo). El Crabby normal, su pincho; el trampolín lo cambia (crabbytramp.lua).
function Crabby:drawTopper(cx, baseY, progress, dir)
    local _, maxH = spikeDims()
    drawSpike(cx, baseY, maxH * progress, dir, self.spikeFile)
end
-- Clavado en el suelo tras caer del techo: la tapa entera, punta abajo
function Crabby:drawStuckTopper(cx, baseY)
    local _, maxH = spikeDims()
    drawSpike(cx, baseY, maxH, 1, self.spikeFile)
end
function Crabby:bounceRotation() return 0 end

-- ── Pinzas (solo dibujo; skins con `claw`: el Crabby helado) ─────────────────
-- La animación de las pinzas del Mega, en pequeño: al andar se balancean con el paso y
-- chasquean al azar (se cierran un momento); al pararse (idle) las levantan y chasquean dos
-- veces; escondiéndose / saliendo van cerradas y BAJAN con el caparazón fila a fila (lo que
-- queda por debajo de la superficie no se dibuja); escondido / asomándose / muerto, nada.
-- Todo sale del estado, del cuadro actual y del reloj: igual en un jugador y online.
local clawArt = {}
local CLAW_CLOSED = { hide_in = true, hide_out = true, drop_shake = true, drop_fall = true,
                      drop_stuck = true, drop_getup = true, drop_bounce = true, snow_crack = true }
function Crabby:drawClaws(drawX, feetY, flipped)
    local cfg = self.sk.claw
    if not cfg then return end
    local img = self.currentImg or self.sk.idle2
    local st = self.state or 'walk'
    if img == self.sk.hid or img == self.sk.lookin or img == self.sk.dead or st:sub(1, 4) == 'dead'
       or st == 'hidden' or st == 'reserve' then return end
    local a = clawArt[cfg.file]
    if not a then
        local im = love.graphics.newImage(cfg.file)
        im:setFilter('nearest', 'nearest')
        a = { img = im, quad = love.graphics.newQuad(0, 0, 1, 1, im:getDimensions()) }
        clawArt[cfg.file] = a
    end
    local S = GUMMY_SCALE
    local now = love.timer.getTime()
    local fw, fh = cfg.w, a.img:getHeight()
    local inset = self.sk.inset and self.sk.inset[img]
    local sink = inset and (inset + 1) or 0               -- (hundiéndose: filas que ha bajado)
    if st ~= self._clawSt then self._clawSt, self._clawAt = st, now end
    local since = now - (self._clawAt or now)
    self._claws = self._claws or { { next = now + math.random() * 1.5 }, { next = now + math.random() * 1.5 } }
    love.graphics.push()
    love.graphics.translate(drawX, feetY)
    if flipped then love.graphics.scale(1, -1) end
    love.graphics.setColor(1, 1, 1, 1)
    for i, side in ipairs({ -1, 1 }) do
        local cl = self._claws[i]
        local fr, dx, dy = 1, 0, 0                        -- 1 abierta, 2 cerrada; desplazamiento en px de arte
        if sink > 0 then
            fr, dy = 2, sink
        elseif CLAW_CLOSED[st] then
            fr = 2
        elseif st == 'idle' and since < 0.9 then
            -- Parado: las alza (subida y bajada suaves) y chasquea dos veces arriba
            local up = math.min(1, since / 0.14) * math.min(1, (0.9 - since) / 0.18)
            up = up * up * (3 - 2 * up)
            dy, dx = -2.2 * up, side * 0.5 * up
            local ph = (since - 0.14) * 7
            if since > 0.14 and since < 0.72 and ph % 2 >= 1 then fr = 2 end
        else
            if st == 'walk' then
                -- Andando: se balancean con el paso, cada una a su fase (como las del Mega)
                local ph = (i == 1) and 0 or 1.9
                dy = math.sin(now * 9 + ph) * 0.55
                dx = side * (0.15 + 0.15 * math.sin(now * 4.5 + ph))
            else
                dy = math.sin(now * 3 + i) * 0.2            -- (quieto de otro modo: respira)
            end
            if now >= cl.next then cl.snapTo, cl.next = now + 0.12, now + 0.6 + math.random() * 1.8 end
            if now < (cl.snapTo or 0) then fr = 2 end
        end
        -- (posición al píxel de PANTALLA: pasos de 1/4 de píxel de arte, sin saltos de un píxel
        -- entero; y solo se recorta lo que queda bajo la superficie AL HUNDIRSE — antes se
        -- recortaba siempre contra la línea de los pies y al bajar la pinza perdía una fila)
        local cx = side * (cfg.x * S + fw * S / 2 - cfg.inset * S) + math.floor(dx * S + 0.5)
        local top = math.floor(cfg.y * S - fh * S + dy * S + 0.5)
        local rows = fh
        if sink > 0 then rows = math.min(fh, math.floor(-top / S)) end
        if rows > 0 then
            a.quad:setViewport((fr - 1) * fw, 0, fw, rows)
            love.graphics.draw(a.img, a.quad, cx, top, 0, -side * S, S, fw / 2, 0)
        end
    end
    love.graphics.pop()
end

-- Dibuja "como en el suelo" con los pies en (px, py) de pantalla, girado `ang`
function Crabby:renderLocal(px, py, ang)
    local fl, fc, ox, oy = self.flipped, self.facing, self.x, self.y
    -- De frente en local = sentido de avance (en el techo facing va al revés)
    if self.crawl and self.cny == 1 then self.facing = -fc end
    self.flipped, self.x, self.y = false, 0, -self.sprH / 2
    love.graphics.push()
    love.graphics.translate(px, py); love.graphics.rotate(ang)
    self:renderBody(0, 0)
    love.graphics.pop()
    self.flipped, self.facing, self.x, self.y = fl, fc, ox, oy
end

-- Escombros al meterse en la superficie (o salir de ella): piedrecitas con física del
-- material del bloque de debajo (solo dibujo: sale del estado, igual online)
local Particles
local DIG = { hide_in = 0.07, hide_out = 0.12, drop_shake = 0.08 }
function Crabby:renderDig()
    local every = DIG[self.state]
    if not every or EDITOR_VIEW then return end
    local img = self.currentImg
    if img == self.sk.idle2 or img == self.sk.idle1 or img == self.sk.idle3 or img == self.sk.hid then return end
    local now = love.timer.getTime()
    if (self._digT or 0) + every > now then return end
    self._digT = now
    local nx, ny = 0, self.flipped and 1 or -1
    if self.crawl and self.cattached then nx, ny = self.cnx or 0, self.cny or -1 end
    local h = self.sprH / 2
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit('crab_dig', self.x - nx * h, self.y - ny * h, { nx = nx, ny = ny })
end

-- En una pared se dibuja como en el suelo, girado
function Crabby:render(camX, camY)
    self:renderDig()
    -- Girando en una esquina: con la pose real (la misma que la hitbox)
    if Crawler.turning(self) and self.state:sub(1, 5) ~= 'drop_' then
        local fx, fy, ang = Crawler.pose(self)
        self:renderLocal(math.floor(fx - camX + 0.5), math.floor(fy - camY + 0.5), ang)
        return
    end
    if Crawler.onWall(self) and self.cattached and self.state:sub(1, 5) ~= 'drop_' then
        -- Girado alrededor del punto de apoyo ajustado al píxel del borde del
        -- bloque (girar desde el centro sin redondear lo dejaba 1 px separado)
        self:renderLocal(math.floor(self.x - self.cnx * self.sprH / 2 - camX + 0.5),
                         math.floor(self.y - camY), Crawler.angle(self))
        return
    end
    self:renderBody(camX, camY)
end

function Crabby:renderBody(camX, camY)
    local img = self.currentImg or self.sk.idle2
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
    local stuckBase, partial
    if stuck then
        -- El pincho queda fijo; la cabeza del cangrejo se apoya en su base (encajada `topperDy`)
        -- y el cuerpo crece hacia ARRIBA según el sprite de cada momento. Los cuadros que dejan
        -- filas vacías arriba (hundirse del helado: sk.inset) se colocan por su parte VISIBLE:
        -- si no, el cuerpo aparecía arriba, separado de la púa, y bajaba hacia ella
        stuckBase = math.floor(dropSpikeBaseY(self) - camY)
        local inset = (self.sk.inset and self.sk.inset[img]) or 0
        partial = inset > 0 and img ~= self.sk.hid
        if img == self.sk.hid then inset = 0 end
        feetY = math.floor(stuckHeadY(self) - camY) - (ih - inset) * math.abs(scaleY)
    end

    -- Levantándose: gira 180° alrededor de su centro
    local rot = 0
    if st == 'drop_getup' then rot = math.pi * (1 - math.min(1, t / GETUP_TIME)) end
    if st == 'drop_bounce' then rot = self:bounceRotation() end      -- (Crabby trampolín)
    if rot ~= 0 then
        local cx, cy = self.x - camX, self.y - camY
        love.graphics.push()
        love.graphics.translate(cx, cy); love.graphics.rotate(rot * self.facing); love.graphics.translate(-cx, -cy)
    end

    if stuck then
        -- Entero, igual que un pincho que cae clavado (la punta dentro del suelo)
        self:drawStuckTopper(math.floor(self.x - camX), stuckBase)
    elseif self.spikeProgress > 0 and not self.coverFront then
        local headH = self:headH(img) * math.abs(by)              -- (sigue a la cabeza: respira, se hunde)
        if flipped then self:drawTopper(drawX, feetY + headH, self.spikeProgress, 1)
        else            self:drawTopper(drawX, feetY - headH, self.spikeProgress, -1) end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, drawX, feetY, 0, scaleX, flipped and -scaleY or scaleY,
                       img:getWidth() / 2, ih)
    if self.sk.claw and not partial then self:drawClaws(drawX, feetY, flipped) end
    -- Tapa DELANTE (montón de nieve): sale de la superficie, por delante del cangrejo
    if self.coverFront and self.spikeProgress > 0 and not stuck then
        self:drawTopper(drawX, feetY, self.spikeProgress, flipped and 1 or -1)
    end
    if rot ~= 0 then love.graphics.pop() end
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'crabby', label = 'Crabby', category = 'Enemigos',
    description = 'Camina y a veces se esconde sacando un pincho. Puede andar por paredes y techos.',
    class = Crabby,
    defaults = { speed = 50, points = 15 },
    props = {
        { key='canHide', kind='bool', label='Se esconde (pincho)', group='Comportamiento', default=true,
          showIf=function(p) return p.pauses end },
        { key='hideChance', kind='number', label='Probabilidad de esconderse', group='Comportamiento',
          default=0.75, min=0, max=1, step=0.05,
          showIf=function(p) return p.pauses and p.canHide end },
        Crabby.WALL_PROP,
    },
    editor = { sprite = 'assets/images/crabby/crab1.png' },
}
