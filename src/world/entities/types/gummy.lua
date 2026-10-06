-- Gummy: enemigo básico que camina, hace pausas "respirando" y muere al
-- pisotearlo. Todo el movimiento y combate viene de Entity + propiedades.
--
-- Casco (prop `helmet`, solo Gummies). Reglas SIN casos ambiguos:
--   · pies del jugador en la mitad de ARRIBA del Gummy (casco incluido):
--       ground pound → se rompe el casco y muere ('stomp');
--       cayendo o quieto → rebota y el casco sigue intacto ('helmet');
--       subiendo (acaba de rebotar) → nada. Nunca daña al jugador.
--   · de lado o desde abajo: las reglas normales del Gummy (le hace daño).
-- La caja exterior sube lo que sobresale el casco (se rebota en lo que se ve).
-- assets/images/gummy/casco.png va dibujado encima del sprite (misma rejilla de
-- 16x16), algo más grande (HELMET_K) alrededor de su borde de abajo.
local Entity       = require 'src/world/entities/Entity'
local Interactions = require 'src/world/entities/Interactions'

local HELMET_K    = 1.10             -- escala del casco sobre la del Gummy
local HELMET_AX, HELMET_AY = 8, 7    -- punto del casco que no se mueve al escalar (borde de abajo)
local HELMET_TOP  = 1                -- primera fila con píxeles del casco (casco.png)
local BONK_TIME   = 0.25             -- s del "bonk" del casco al rebotar (solo dibujo)

local Gummy = Entity.extend(Entity, {
    walkFps = 7, walkFrames = 2,
    idleEvery = { 3.0, 7.0 }, idleFor = { 1.0, 2.2 },
    debugColor = { 1, 0.55, 0 },
})

local imgHelmet, imgChute

-- Arte por carpeta (el Gummy normal y sus variantes: gummy_ice.lua pone `artDir`):
-- gummy.png (quieto), gummy1/2.png (andar), dead.png, todos en la misma rejilla 16x16
local ART_DIR = 'assets/images/gummy/'
local arts = {}
function Gummy.loadArt(dir)
    if arts[dir] then return arts[dir] end
    local function img(f) return love.graphics.newImage(dir .. f) end
    arts[dir] = { idle = img('gummy.png'), walk1 = img('gummy1.png'), walk2 = img('gummy2.png'), dead = img('dead.png') }
    return arts[dir]
end
function Gummy:art() return arts[self.artDir or ART_DIR] or Gummy.loadArt(self.artDir or ART_DIR) end

function Gummy.loadAssets()
    if imgHelmet then return end
    Gummy.loadArt(ART_DIR)
    imgHelmet = love.graphics.newImage('assets/images/gummy/casco.png')
    imgChute = love.graphics.newImage('assets/images/gummy/parachute.png')
    for _, i in ipairs({ imgHelmet, imgChute }) do if i.setFilter then i:setFilter('nearest', 'nearest') end end
end

function Gummy:init()
    self.helmet = self.props.helmet == true
    self.bonkT  = 0
end

-- (Guardia de reserva del Rey Gummy: Entity:makeReserve, genérico)

-- ── Paracaídas (la guardia del Rey Gummy que entra por el techo) ─────────────
-- Estado 'para': baja despacio, en vertical, hasta posarse en lo primero que encuentre (suelo o
-- plataforma: quien lo suelta marca ese sitio). Sigue siendo un Gummy: de lado hace daño y se
-- le puede pisotear en el aire. Al posarse suelta el paracaídas y echa a andar.
local PARA_SPEED = 150               -- px/s de caída con el paracaídas
function Gummy:startParachute()
    self.state, self.deadTimer = 'para', 0
    self.vx, self.vy, self.onGround = 0, 0, false
end

function Gummy:updateCustom(dt, level)
    if self.state == 'reserve' then return true end
    if self.state == 'para' then
        self.deadTimer = self.deadTimer + dt
        local facing = self.facing
        self:moveAndCollide(level, 0, PARA_SPEED * dt)
        self.facing = facing
        if self.onGround then
            self.vx = self.speed * self.facing
            self:startWalk()
            Sound.play('gpImpact', 1.5, 0.5)
            Entity.emitFx('spawn', self.x, self.y - self.sprH / 2 - 20)
        elseif level and self.y > (level.heightPx or 1e9) + TILE_PX * 4 then
            self.alive = false
        end
        return true
    end
    if self.bonkT > 0 then self.bonkT = math.max(0, self.bonkT - dt) end
    return false                       -- (el resto: comportamiento normal)
end

-- Cuánto sobresale el casco por encima de la caja exterior normal (px)
local function helmetExtra(self)
    local top = self.y - self.sprH / 2 + ((self.helmetDy or 0) + HELMET_AY - (HELMET_AY - HELMET_TOP) * HELMET_K) * GUMMY_SCALE
    return math.max(0, (self.y - self.outerH / 2) - top)
end

function Gummy:getOuterBounds()
    local b = Entity.getOuterBounds(self)
    if self.helmet and not self.flipped and self.state ~= 'dead' then
        local ex = helmetExtra(self)
        b.y, b.h = b.y - ex, b.h + ex
    end
    return b
end

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

-- Sin efectos: el cliente online lo usa para predecir
function Gummy:interact(pa)
    if not self.helmet then return Interactions.defaultCheck(pa, self) end
    local gp = pa.gpPhase == 'fall'
    local bounceVy = -math.abs(ADV_JUMP_VEL) * Interactions.BOUNCE
    if not self.flipped and self.props.stompable ~= false and not self:isBodyDisabled() then
        local pob, gob = pa:getOuterBounds(), self:getOuterBounds()
        if overlap(pob, gob) and pob.y + pob.h <= self.y then
            if gp then return 'stomp', bounceVy, self.props.points end
            if (pa.vy or 0) >= 0 then return 'helmet', bounceVy end
            return nil
        end
    end
    -- De lado / desde abajo: reglas normales (un pisotón normal nunca lo mata)
    local r, a, b, c = Interactions.defaultCheck(pa, self)
    if r == 'stomp' and not gp then return 'helmet', a end
    return r, a, b, c
end

-- Rebote en el casco (lo llama Interactions.run): suena y el casco se hunde
function Gummy:onHelmetBounce()
    self.bonkT = BONK_TIME
    Sound.play('helmetBounce')
end

-- Muere (ground pound): el casco se rompe
function Gummy:onStomp()
    if self.helmet then
        self.helmet = false
        Sound.play('helmetBreak')
        Entity.emitFx('helmet_break', self.x, self.y - self.sprH / 2 + 8)
    end
end

-- Red: casco y "bonk"
function Gummy:netPack()
    return { self.helmet and 1 or 0, math.floor(self.bonkT * 100 + 0.5) }
end
function Gummy:netApply(a, b)
    self.helmet = b[1] == 1
    self.bonkT  = (tonumber(b[2]) or 0) / 100
end

function Gummy.sizeImage() return Gummy.loadArt(ART_DIR).idle end

function Gummy:render(camX, camY)
    if self.state == 'reserve' then return end
    local img
    local A = self:art()
    local bx, by = self:breatheScale()
    if self.state == 'dead' then
        img = A.dead
    elseif self.state == 'idle' then
        img = A.idle
    else
        img = (self.frame == 1) and A.walk1 or A.walk2
    end
    local scaleX = GUMMY_SCALE * self.facing * bx
    local scaleY = GUMMY_SCALE * by
    if self.flipped then scaleY = -scaleY end

    -- Ancla en la BASE del sprite (los pies): self.y ± sprH/2
    local drawX = math.floor(self.x - camX)
    local feetY = self.flipped and math.floor(self.y - camY - self.sprH / 2)
                               or math.floor(self.y - camY + self.sprH / 2)
    love.graphics.setColor(1, 1, 1, 1)
    if self.state == 'para' then
        -- Paracaídas: encima de la cabeza, meciéndose; se abre al empezar
        local t = self.deadTimer or 0
        local open = math.min(1, t / 0.25)
        local sway = math.sin(t * 3.2) * 0.12
        love.graphics.draw(imgChute, drawX, math.floor(feetY - self.sprH + 3 * GUMMY_SCALE), sway, GUMMY_SCALE * open, GUMMY_SCALE * open,
                           imgChute:getWidth() / 2, imgChute:getHeight())
        img = A.idle
    end
    love.graphics.draw(img, drawX, feetY, 0, scaleX, scaleY, img:getWidth() / 2, img:getHeight())
    -- Casco: la misma rejilla que el sprite, algo más grande alrededor de su borde de abajo
    if self.helmet and self.state ~= 'dead' then
        local ox, oy = img:getWidth() / 2, img:getHeight()
        local hx = drawX + (HELMET_AX + (self.helmetDx or 0) - ox) * scaleX        -- (helmetDx: la cabeza corrida de lado)
        local hy = feetY + (HELMET_AY + (self.helmetDy or 0) - oy) * scaleY          -- (helmetDy: variantes con la cabeza más baja)
        -- Bonk: el casco se aplasta un poco y vuelve
        local k = self.bonkT > 0 and math.sin((1 - self.bonkT / BONK_TIME) * math.pi) or 0
        love.graphics.draw(imgHelmet, math.floor(hx), math.floor(hy + k * 4), 0,
                           scaleX * HELMET_K * (1 + 0.12 * k), scaleY * HELMET_K * (1 - 0.18 * k), HELMET_AX, HELMET_AY)
    end
end

return {
    name = 'gummy', label = 'Gummy', category = 'Enemigos',
    description = 'Enemigo básico: camina, vuela o se queda quieto. Se le pisotea.',
    class = Gummy,
    defaults = { speed = 55, points = 10 },
    props = {
        { key='helmet', kind='bool', label='Casco', group='Combate', default=false,
          help='Saltarle encima solo hace rebotar (el casco aguanta). Solo el ground pound rompe el casco y lo mata' },
    },
    editor = { sprite = 'assets/images/gummy/gummy.png' },
}
