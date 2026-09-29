-- Pez globo: enemigo exclusivo del agua. Nada en un plano POR DELANTE del
-- juego (atraviesa bloques, plataformas y objetos; se dibuja delante de los
-- jugadores: renderFront) de un lado a otro de su ruta, subiendo y bajando.
-- Cuando un jugador que está EN EL AGUA se le acerca (`range` casillas):
--   warn (medio hinchado, aviso) → inflated (hinchado: pincha, 1 de vida y
--   empujón) → deflate → sigue nadando (`cooldown` s sin volver a hincharse).
-- Deshinchado no hace nada. No se le puede matar (no cuenta para Cacería).
--
-- Sprites: assets/images/puffer_fish/puffer_fish-Sheet.png, cuadros de 16x16
-- mirando a la DERECHA (a la izquierda se espeja): nadar (1 o 2 cuadros, se
-- alternan), medio hinchado, hinchado. Con 3 cuadros nada con el primero.
-- Sonidos: pufferWarn / pufferInflate / pufferDeflate / pufferPrick.
local Entity      = require 'src/world/entities/Entity'
local SpriteStrip = require 'src/fx/SpriteStrip'

local S = 5                    -- escala del pixel art
local SHEET = 'assets/images/puffer_fish/puffer_fish-Sheet.png'
-- Cuerpo hinchado dentro del cuadro (px del sprite, mirando a la derecha):
-- columnas 4..14, filas 4..13 (sin la cola). La caja que pincha es un poco
-- menor (HURT_K) para que no pinche "por el aire" en las esquinas.
local BODY_X0, BODY_X1, BODY_Y0, BODY_Y1 = 4, 15, 4, 14
local HURT_K = 0.85
local DEFLATE_T = 0.4          -- s de la animación de deshincharse
local POP_T     = 0.12         -- s del "pop" al hincharse del todo (solo dibujo)

local Puffer = Entity.extend(Entity, {
    debugColor = { 1, 0.8, 0.2 },
    hitbox = { outerW = 0.6, outerH = 0.5, innerW = 0.5, innerH = 0.4 },
})
Puffer.renderFront = true

local strip

function Puffer.loadAssets()
    if strip then return end
    strip = SpriteStrip.load(SHEET, 16)
end

function Puffer.sizePx() return 16 * S, 16 * S end

function Puffer:init()
    self.flying = true              -- (sin gravedad; su movimiento es propio)
    self.state  = 'walk'
    self.cool   = 0
    self.swimT  = 0
end

-- Nada nunca le afecta: ni empujones, ni trampolines, ni es un obstáculo
function Puffer:canBeStomped() return false end
function Puffer:canBeKnocked() return false end
function Puffer:canBeLaunched() return false end
function Puffer:isObstacle() return false end
function Puffer:isBodyDisabled() return true end      -- (solo pincha con la caja de peligro)
function Puffer:canDropNow() return false end

-- Caja que pincha (solo hinchado)
function Puffer:getHazardBoxes()
    if self.state ~= 'inflated' then return nil end
    local w = (BODY_X1 - BODY_X0) * S * HURT_K
    local h = (BODY_Y1 - BODY_Y0) * S * HURT_K
    local cx = ((BODY_X0 + BODY_X1) / 2 - 8) * S * self.facing
    local cy = ((BODY_Y0 + BODY_Y1) / 2 - 8) * S
    return { { x = self.x + cx - w / 2, y = self.y + cy - h / 2, w = w, h = h, effect = 'hurt' } }
end

-- El jugador más cercano que esté en el agua y a su alcance
function Puffer:targetIn(level)
    local r = (self.props.range or 2.5) * TILE_PX
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if pa.inWater and not pa.dying and pa.alive ~= false then
            local dx, dy = pa.x - self.x, pa.y - self.y
            local d = dx * dx + dy * dy
            if d <= r * r and (not bd or d < bd) then best, bd = pa, d end
        end
    end
    return best
end

-- Pinchazo (Interactions.run, cuando de verdad le quitó vida): suena y lo aparta
function Puffer:onHurtPlayer(pa)
    Sound.play('pufferPrick')
    pa:recoil(pa.x >= self.x and 1 or -1)
end

function Puffer:updateCustom(dt, level)
    local p = self.props
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    self.cool = math.max(0, self.cool - dt)
    local swimming = st == 'walk' or st == 'idle'
    -- Movimiento: a lo largo de su ruta atravesándolo todo; frena al hincharse
    local want = swimming and self.speed * self.facing or 0
    self.vx = self.vx + (want - self.vx) * math.min(1, dt * (swimming and 3 or 6))
    self.x = self.x + self.vx * dt
    local hw = self.outerW / 2
    local left  = math.max(self.leftBoundPx, 0)
    local right = math.min(self.rightBoundPx, level.widthPx or math.huge)
    if self.x + hw >= right and self.facing > 0 then self.x, self.facing = right - hw, -1
    elseif self.x - hw <= left and self.facing < 0 then self.x, self.facing = left + hw, 1 end
    self.swimT = self.swimT + dt * (swimming and 1 or 0.4)
    self.y = self.baseY + math.sin(self.swimT * 1.7) * (p.swimBob or 10)

    if swimming then
        self.state = 'walk'
        local pa = self.cool <= 0 and self:targetIn(level)
        if pa then
            self.state, self.deadTimer = 'warn', 0
            self.facing = (pa.x >= self.x) and 1 or -1
            Sound.play('pufferWarn')
        end
    elseif st == 'warn' then
        if self.deadTimer >= (p.warnTime or 0.6) then
            self.state, self.deadTimer = 'inflated', 0
            Sound.play('pufferInflate')
            Entity.emitFx('puffer_pop', self.x, self.y)
        end
    elseif st == 'inflated' then
        if self.deadTimer >= (p.inflateTime or 2.5) then
            self.state, self.deadTimer = 'deflate', 0
            Sound.play('pufferDeflate')
        end
    elseif st == 'deflate' then
        if self.deadTimer >= DEFLATE_T then
            self.state, self.deadTimer = 'walk', 0
            self.cool = p.cooldown or 1.5
        end
    end
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function Puffer:render(camX, camY)
    local n = strip.count
    local half, full = math.max(1, n - 1), n
    local st, t = self.state, self.deadTimer or 0
    local f, k = 1, 1
    if st == 'warn' then
        -- Aviso: primero tiembla entre deshinchado y medio, luego medio hinchado
        f = (t < 0.3 and math.floor(t / 0.06) % 2 == 0) and 1 or half
    elseif st == 'inflated' then
        f = full
        if t < POP_T then k = 1 + 0.18 * math.sin(t / POP_T * math.pi) end
    elseif st == 'deflate' then
        f = (t < DEFLATE_T * 0.6) and half or 1
    elseif n >= 4 then
        f = strip:frameAt(love.timer.getTime() + (self.home and self.home.x or 0) * 0.01, 5) % 2 + 1
    end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    -- Temblor del aviso
    if st == 'warn' then x = x + math.floor(math.sin(t * 60) * 2 + 0.5) end
    love.graphics.setColor(1, 1, 1, 1)
    strip:draw(f, x, y, 0, S * k * self.facing, S * k)
end

-- Editor: alcance de detección (círculo) al seleccionarlo
function Puffer.drawEditorOverlay(props, cx, cy, zoom)
    local r = (props.range or 2.5) * TILE_PX
    love.graphics.setColor(0.3, 0.8, 1, 0.12)
    love.graphics.circle('fill', cx, cy, r)
    love.graphics.setColor(0.3, 0.8, 1, 0.8)
    love.graphics.setLineWidth(2 / zoom)
    love.graphics.circle('line', cx, cy, r)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Icono de la paleta: el primer cuadro
local iconImg, iconQuad
local function drawIcon(x, y, s)
    if not iconImg then
        iconImg = love.graphics.newImage(SHEET)
        iconImg:setFilter('nearest', 'nearest')
        iconQuad = love.graphics.newQuad(0, 0, 16, 16, iconImg:getWidth(), iconImg:getHeight())
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(iconImg, iconQuad, x, y, 0, s / 16, s / 16)
end

return {
    name = 'pufferfish', label = 'Pez globo', category = 'Enemigos',
    description = 'Solo para el agua: nada por delante de todo (atraviesa bloques). Si un jugador que está '
               .. 'en el agua se acerca, avisa, se hincha y pincha (1 de vida y empujón). No se le puede matar.',
    class = Puffer,
    hide = { 'movement', 'attach', 'turnAtEdges', 'bobAmp', 'pauses', 'onTouch', 'stompable', 'points',
             'dropOnSight', 'detectRange', 'respawn' },
    defaults = { movement = 'walk', speed = 45, stompable = false, points = 0, onTouch = 'none', pauses = false },
    props = {
        { key='range', kind='number', label='Alcance (casillas)', group='Pez globo', default=2.5,
          min=1, max=10, step=0.5, help='Se hincha si un jugador que está en el agua se acerca a esta distancia' },
        { key='warnTime', kind='number', label='Aviso (s)', group='Pez globo', default=0.6,
          min=0.2, max=3, step=0.1, help='Medio hinchado antes de pinchar' },
        { key='inflateTime', kind='number', label='Hinchado (s)', group='Pez globo', default=2.5,
          min=0.5, max=10, step=0.5 },
        { key='cooldown', kind='number', label='Descanso (s)', group='Pez globo', default=1.5,
          min=0, max=10, step=0.5, help='Tras deshincharse, cuánto nada antes de poder hincharse otra vez' },
        { key='swimBob', kind='number', label='Oscilación al nadar (px)', group='Pez globo', default=10,
          min=0, max=80, step=2 },
    },
    editor = { draw = drawIcon },
}
