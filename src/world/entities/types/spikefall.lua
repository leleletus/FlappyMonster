-- Pincho que cae: un pincho individual que cuelga del techo en una subcelda
-- (se coloca igual que los pinchos normales, solo bajo un bloque sólido).
-- Si un jugador se pone debajo (dentro del alcance y a la vista) tiemblan,
-- caen y matan a quien golpeen. Al tocar el suelo quedan clavados un rato,
-- desaparecen y vuelven a salir del techo en su sitio.
local Entity = require 'src/world/entities/Entity'

local SpikeFall = Entity.extend(Entity, { debugColor = { 1, 0.3, 0.3 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local SHAKE     = 0.45   -- s temblando antes de caer
local VANISH    = 0.35   -- s desapareciendo tras estar clavados
local REGROW    = 0.6    -- s saliendo del techo
local EMBED     = 0.45   -- fracción que se clava en el suelo

-- Se ve y choca EXACTAMENTE como un pincho normal hacia abajo en una
-- subcelda (mismo dibujo y misma hitbox que los pinchos de tile, ver Level.lua).
local function half() return TILE_PX / 2 end

function SpikeFall.loadAssets() end
function SpikeFall.sizePx() return TILE_PX / 2, TILE_PX / 2 end

function SpikeFall:init()
    self.moving, self.flying = false, true
    self.vx, self.vy = 0, 0
    -- Ocupa su subcelda (Entity.create ya lo centra en ella)
    self.state = 'armed'
    self.deadTimer = 0
end

-- Detecta él solo a los jugadores. Los "pinchos de lluvia" (rainspike.lua)
-- lo desactivan: los hace caer su Lluvia de pinchos con trigger().
SpikeFall.autoDetect = true

-- Empieza a caer (tiembla `warn` s antes; nil = su aviso configurado).
-- Devuelve false si ahora no puede (ya cayendo, clavado, regenerándose...).
function SpikeFall:trigger(warn)
    if self.state ~= 'armed' then return false end
    self.state, self.deadTimer, self.warnFor = 'shake', 0, warn
    Sound.play('spikeShake')
    return true
end

function SpikeFall:canBeStomped() return false end
function SpikeFall:canBeKnocked() return false end

function SpikeFall:updateCustom(dt, level)
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    if st == 'armed' then
        if self.autoDetect and self:seesPlayerBelow(level, self.props.detectRange, TILE_PX / 2) then
            self:trigger()
        end
    elseif st == 'shake' then
        local warn = (self.warnFor and self.warnFor > 0) and self.warnFor or self.props.fallDelay
        if self.deadTimer >= warn then self.state, self.deadTimer, self.vy = 'falling', 0, 0 end
    elseif st == 'falling' then
        self.vy = math.min(self.vy + ADV_GRAVITY * 1.2 * (self.props.fallSpeed or 1) * dt, 1400 * (self.props.fallSpeed or 1))
        local ny = self.y + self.vy * dt
        local tipY = ny + self.outerH / 2
        local t, face = level:landingCross(self.x, self.y + self.outerH / 2, tipY)
        if t or tipY > level.heightPx then
            -- Se clava: la punta entra en el bloque (en su cara de arriba)
            local top = face or (math.floor(tipY / TILE_PX) * TILE_PX)
            self.y = top - self.outerH / 2 + self.outerH * EMBED
            self.state, self.deadTimer = 'stuck', 0
            Sound.play('spikeHit')
            Entity.emitFx('spike_land', self.x, top)
        else
            self.y = ny
        end
    elseif st == 'stuck' then
        if self.deadTimer >= self.props.stuckTime then self.state, self.deadTimer = 'vanish', 0 end
    elseif st == 'vanish' then
        if self.deadTimer >= VANISH then
            self.y = self.home.y
            self.state, self.deadTimer = 'regrow', 0
        end
    elseif st == 'regrow' then
        if self.deadTimer >= REGROW then self.state, self.deadTimer, self.warnFor = 'armed', 0, nil end
    end
    return true
end

-- Peligrosos colgando, temblando y cayendo; clavados/regenerándose no.
-- Hitbox = la de un pincho de tile hacia abajo (Level._spikeHitbox).
local LevelMod
function SpikeFall:getHazardBoxes()
    local st = self.state
    if st ~= 'armed' and st ~= 'shake' and st ~= 'falling' then return nil end
    LevelMod = LevelMod or package.loaded['src/world/Level'] or require('src/world/Level')
    local H  = half()
    local hx, hy, hw, hh = LevelMod._spikeHitbox(self.x - H / 2, self.y - H / 2, H, 1)   -- 1 = DIR_DOWN
    -- Sin crear tablas cada vez (puede haber cientos de pinchos)
    local box = self._hb
    if not box then box = {}; self._hb = { box } else box = box[1] end
    box.x, box.y, box.w, box.h = hx, hy, hw, hh
    return self._hb
end

-- Red: colgando en su sitio no hace falta enviarlo
function SpikeFall:netAtRest() return self.state == 'armed' and self.y == self.home.y end
function SpikeFall:netRest()
    self.state, self.deadTimer, self.y = 'armed', 0, self.home.y
end

function SpikeFall:isBodyDisabled() return true end

-- La púa de los pinchos hacia abajo, con el aspecto de pinchos del nivel (SpikeSkins)
local SpikeSkins = require 'src/world/SpikeSkins'
SpikeFall.wantsLevel = true          -- (solo dibujo: el aspecto de los pinchos del nivel; BossZones.link / editor)
local function drawDownSpike(px, py, sz, alpha, skin)
    local spikeImg = SpikeSkins.image(skin)
    local k = sz / spikeImg:getWidth()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(spikeImg, px, py + sz, 0, k, -k)
end

function SpikeFall:render(camX, camY)
    local st, k, alpha = self.state, 1, 1
    local H  = half()
    local x0 = math.floor(self.x - camX - H / 2)
    local y0 = math.floor(self.y - camY - self.outerH / 2)
    if st == 'shake' then x0 = x0 + math.floor(math.sin(self.deadTimer * 80) * 3) end
    if st == 'vanish' then alpha = 1 - self.deadTimer / VANISH end
    if st == 'regrow' then k = math.min(1, self.deadTimer / REGROW) end
    -- Al regenerarse "sale" del techo: crece desde arriba
    love.graphics.push()
    love.graphics.translate(0, y0)
    love.graphics.scale(1, k)
    drawDownSpike(x0, 0, H, alpha, SpikeSkins.of(self.levelRef))
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'spikefall', label = 'Pincho que cae', category = 'Trampas',
    description = 'Pincho colgado de un techo que cae cuando un jugador pasa por debajo.',
    class = SpikeFall,
    placement = 'sub',              -- como los pinchos: en subceldas
    ceilingOnly = true,             -- solo colgando de un bloque sólido
    hide = 'all',
    props = {
        { key='detectRange', kind='int', label='Alcance de detección (casillas)', group='Trampa', default=6,
          min=1, max=30, step=1, help='casillas hacia abajo: mas lejos no cae (no te pilla sin verlo)' },
        { key='fallDelay', kind='number', label='Aviso antes de caer (s)', group='Trampa', default=SHAKE,
          min=0.1, max=3, step=0.05 },
        { key='stuckTime', kind='number', label='Clavado en el suelo (s)', group='Trampa', default=2.5,
          min=0.5, max=20, step=0.5 },
    },
    editor = { sprite = 'assets/images/items/spikefall.png' },
}
