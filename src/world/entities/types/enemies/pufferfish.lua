-- Pez globo: enemigo exclusivo del agua. Nada en un plano POR DELANTE del
-- juego (atraviesa bloques, plataformas y objetos; se dibuja delante de los
-- jugadores: renderFront) explorando libremente su ÁREA DE NADO: un polígono
-- (prop `area`, de 3 a 24 puntos = centros de casilla; puede ser irregular y
-- cóncavo). Elige puntos al azar dentro del área a los que se llega en línea
-- recta SIN salir de ella, nada hasta allí, a veces se para un momento y
-- vuelve a elegir. (Solo simula quien manda: un jugador / servidor.)
-- Cuando un jugador que está EN EL AGUA se le acerca (`range` casillas):
--   warn (medio hinchado, aviso) → inflated (hinchado: pincha, 1 de vida y
--   empujón) → deflate → sigue nadando (`cooldown` s sin volver a hincharse).
-- Deshinchado no hace nada. No se le puede matar (no cuenta para Cacería).
-- SIN AGUA (0.5.31, como el Pez Globo Gigante): sigue el nivel del agua — si la superficie baja de su lomo, nada hacia
-- abajo, y no elige destinos secos —; si se queda en seco (una inundación que baja más rápido que él, o un área que
-- sale del agua) CAE ('dry_fall', con choques) y en el suelo da botes y coletazos salvajes ('dry_flop'). Si vuelve a
-- caer al agua, sigue nadando; si pasa `dryTime` s fuera, se MUERE ('dry_die': panza arriba y se desvanece).
-- Dentro de un bloque cuenta como mojado (su área puede atravesarlos). Nadar y estar en seco: base/Swimmer.lua (0.5.97,
-- lo comparte con la Piraña).
--
-- Sprites: assets/images/enemies/pufferfish/puffer_fish-Sheet.png, cuadros de 16x16
-- mirando a la DERECHA (a la izquierda se espeja): nadar (1 o 2 cuadros, se
-- alternan), medio hinchado, hinchado. Con 3 cuadros nada con el primero.
-- Sonidos: pufferWarn / pufferInflate / pufferDeflate / pufferPrick.
local Entity      = require 'src/world/entities/base/Entity'
local Swimmer     = require 'src/world/entities/base/Swimmer'

local S = 5                    -- escala del pixel art
local SHEET = 'assets/images/enemies/pufferfish/puffer_fish-Sheet.png'
-- Cuerpo hinchado dentro del cuadro (px del sprite, mirando a la derecha):
-- columnas 4..14, filas 4..13 (sin la cola). La caja que pincha es un poco
-- menor (HURT_K) para que no pinche "por el aire" en las esquinas.
local BODY_X0, BODY_X1, BODY_Y0, BODY_Y1 = 4, 15, 4, 14
local HURT_K = 0.85
local DEFLATE_T = 0.4          -- s de la animación de deshincharse
local POP_T     = 0.12         -- s del "pop" al hincharse del todo (solo dibujo)
local SWIM_FPS  = 2.5          -- cambios de cuadro por segundo al nadar (no cambia su velocidad)
local DRY = Swimmer.DRY        -- (en seco: base/Swimmer.lua)

local Puffer = Entity.extend(Entity, {
    debugColor = { 1, 0.8, 0.2 },
    hitbox = { outerW = 0.6, outerH = 0.5, innerW = 0.5, innerH = 0.4 },
})
Puffer.renderFront = true
Puffer.freezeFloats = true      -- (congelado: el bloque de hielo flota donde estaba)

Puffer.animId = 'enemies/pufferfish'
function Puffer.loadAssets() Puffer.anims(Puffer) end

function Puffer.sizePx() return 16 * S, 16 * S end

function Puffer:topY() return Swimmer.topY(self) end          -- (el lomo)
function Puffer:pickTarget() Swimmer.pickTarget(self) end

function Puffer:init()
    self.flying = true              -- (sin gravedad; su movimiento es propio)
    self.swimPass = true            -- (nada por delante: atraviesa bloques — base/Swimmer.lua —)
    self.state  = 'walk'
    self.cool   = 0
    Swimmer.init(self)
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
    if self.state ~= 'inflated' or not self.alive then return nil end
    local w = (BODY_X1 - BODY_X0) * S * HURT_K
    local h = (BODY_Y1 - BODY_Y0) * S * HURT_K
    local cx = ((BODY_X0 + BODY_X1) / 2 - 8) * S * self.facing
    local cy = ((BODY_Y0 + BODY_Y1) / 2 - 8) * S
    return { { x = self.x + cx - w / 2, y = self.y + cy - h / 2, w = w, h = h, effect = 'hurt' } }
end

-- El jugador más cercano que esté en el agua y a su alcance
function Puffer:targetIn(level)
    local r = (self.props.range or 2.5) * TILE_PX * require('src/core/Difficulty').k('sense')
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

-- De vuelta al agua (Swimmer.updateDry): sigue nadando
function Puffer:onBackToWater(level) Sound.play('waterSplash', 1.5, 0.5) end

function Puffer:updateCustom(dt, level)
    local p = self.props
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    self.cool = math.max(0, self.cool - dt)
    Swimmer.ready(self, level)
    -- ¿En seco? (el centro fuera del agua y fuera de un bloque): deja lo que hacía y cae
    if not DRY[st] and Swimmer.isDry(self, level) then Swimmer.goDry(self); st = self.state end
    if DRY[st] then Swimmer.updateDry(self, dt, level); self.x, self.y = self.px, self.py; return true end
    local swimming = st == 'walk' or st == 'idle'
    -- Movimiento: hacia su destino dentro del área, atravesándolo todo; frena al hincharse y, al llegar, a veces
    -- descansa un momento (base/Swimmer.lua)
    Swimmer.move(self, dt, level, swimming)

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
-- Cada estado pide su animación por nombre (assets/anim/enemies/pufferfish.json): `swim` nadando, `warn` (tiembla
-- y se queda a medio hinchar), `puffed` hinchado, `deflate` deshinchándose. Cuadros y ritmo: los del conjunto.
function Puffer:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    if DRY[st] then return self:renderDry(camX, camY) end
    local name, k = 'swim', 1
    if st == 'warn' then name = 'warn'
    elseif st == 'inflated' then
        name = 'puffed'
        if t < POP_T then k = 1 + 0.18 * math.sin(t / POP_T * math.pi) end
    elseif st == 'deflate' then name = 'deflate'
    else t = love.timer.getTime() + (self.home and self.home.x or 0) * 0.01 end
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    -- Temblor del aviso
    if st == 'warn' then x = x + math.floor(math.sin(t * 60) * 2 + 0.5) end
    love.graphics.setColor(1, 1, 1, 1)
    self:anims():draw(name, t, x, y, 0, S * k * self.facing, S * k, 0.5, 0.5)
end

-- En seco (Swimmer.dryPose): coletea (los dos cuadros de nadar, rápido) dando vueltas; muriendo, panza arriba y se
-- desvanece
function Puffer:renderDry(camX, camY)
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local at, rot, sy, a = Swimmer.dryPose(self)
    love.graphics.setColor(1, 1, 1, a)
    self:anims():draw('swim', at, x, y, rot, S * (self.facing or 1), S * sy, 0.5, 0.5)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Editor: área de nado (relleno) y alcance de detección (círculo) al seleccionarlo
function Puffer.drawEditorOverlay(props, cx, cy, zoom, ctx)
    Swimmer.drawArea(props, ctx, zoom)
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
local function drawIcon(x, y, s)
    local c = Puffer.anims(Puffer) and require('src/fx/Anim').clip(Puffer.animId, 'swim')
    c:drawPx(1, x, y, 0, s / c.w, s / c.w)
end

return {
    name = 'pufferfish', label = 'Pez globo', category = 'Enemigos',
    description = 'Solo para el agua: explora su área de nado por delante de todo (atraviesa bloques). Si un jugador que está '
               .. 'en el agua se acerca, avisa, se hincha y pincha (1 de vida y empujón). No se le puede matar. '
               .. 'Sigue el nivel del agua; en seco bota y coletea y, si tarda en volver al agua, se muere.',
    class = Puffer,
    inBlockOk = true,          -- (atraviesa los bloques: dentro de uno no es un aviso)
    hide = { 'movement', 'attach', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses', 'onTouch', 'stompable', 'points',
             'dropOnSight', 'detectRange', 'respawn' },
    defaults = { movement = 'walk', speed = 45, stompable = false, points = 0, onTouch = 'none', pauses = false },
    props = {
        Swimmer.areaProp('Pez globo'),
        { key='range', kind='number', label='Alcance (casillas)', group='Pez globo', default=2.5,
          min=1, max=10, step=0.5, help='Se hincha si un jugador que está en el agua se acerca a esta distancia' },
        { key='warnTime', kind='number', label='Aviso (s)', group='Pez globo', default=0.6,
          min=0.2, max=3, step=0.1, help='Medio hinchado antes de pinchar' },
        { key='inflateTime', kind='number', label='Hinchado (s)', group='Pez globo', default=2.5,
          min=0.5, max=10, step=0.5 },
        { key='cooldown', kind='number', label='Descanso (s)', group='Pez globo', default=1.5,
          min=0, max=10, step=0.5, help='Tras deshincharse, cuánto nada antes de poder hincharse otra vez' },
        { key='swimBob', kind='number', label='Oscilación al nadar (px)', group='Pez globo', default=6,
          min=0, max=80, step=2 },
        Swimmer.dryTimeProp('Pez globo'),
    },
    editor = { draw = drawIcon },
}
