-- TRAMPOLÍN DE COMPÁS (Vía Estelar, docs/design/starway-rhythm-objects.md): una estrella dorada sobre un muelle. Es
-- un TRAMPOLÍN (la clase de mechanisms/trampoline.lua: cara que lanza, ventana, extendido, red, predicción) mirando
-- arriba, con UNA diferencia: la fuerza depende de CUÁNDO se cae en él. En el pulso de la música (a `window` s de
-- música o menos: BeatClock.offBeat) lanza muy alto (`high`, unas 7 casillas); fuera, un saltito (`low`, unas 2). Un
-- aro que se cierra hacia cada pulso marca el momento. `interact` sigue sin efectos (el cliente lo predice con su
-- reloj de compás, que el servidor corrige: src/world/systems/BeatClock.lua).
-- Arte: tools/art/world/make_starway_objects.py (assets/anim/mechanisms/beatspring.json).
local Entity    = require 'src/world/entities/base/Entity'
local BeatClock = require 'src/world/systems/BeatClock'
local Tramp     = require('src/world/entities/types/mechanisms/trampoline').Base

local B = Entity.extend(Tramp)
B.animId = 'mechanisms/beatspring'
B.wantsLevel = true
function B.loadAssets() B.anims(B) end

-- ¿Cae EN el pulso?
function B:onBeat()
    return BeatClock.offBeat(self.levelRef) <= (self.props.window or 0.1)
end

function B:launchVelocity()
    local k = self:onBeat() and (self.props.high or 2.1) or (self.props.low or 1.1)
    return 0, -math.abs(ADV_JUMP_VEL) * k
end

function B:onLaunch(pa)
    local fresh = self.state == 'ready'
    Tramp.onLaunch(self, pa)
    if fresh and self:onBeat() then
        self.high = true
        Sound.play('beepSwitch')                         -- (el «clin» de cristal: lo hiciste a tiempo)
        local b = self:getOuterBounds()
        Entity.emitFx('gp_start', b.x + b.w / 2, b.y)
    elseif fresh then
        self.high = false
    end
end

function B:render(camX, camY)
    local ext = self:isExtended()
    local x, y = math.floor(self.x - camX), math.floor(self.y - camY)
    local A = B.anims(B)
    love.graphics.setColor(1, 1, 1, 1)
    A:draw(ext and 'bounce' or 'idle', 0, x, y, 0, 4, 4, 0.5, 0.5)
    -- el aro: grande justo después de un pulso, pequeño justo antes del siguiente
    if self.levelRef and self.levelRef.beat then
        local beats = BeatClock.beats(self.levelRef)
        local i = 1 + math.min(3, math.floor((beats - math.floor(beats)) * 4))
        A:draw('ring' .. i, 0, x, y, 0, 4, 4, 0.5, 0.5)
    end
end

local function editorIcon(x, y, s)
    B.loadAssets()
    love.graphics.setColor(1, 1, 1, 1)
    B.anims(B):draw('idle', 0, x + s / 2, y + s / 2, 0, s / 16, s / 16, 0.5, 0.5)
end

return {
    name = 'beatspring', label = 'Trampolín de compás', category = 'Mecanismos', class = B, dir = 'up', beat = true,
    description = 'Estrella con muelle: caer en ella EN el pulso de la música lanza muy alto; fuera del pulso, un saltito (Vía Estelar).',
    defaults = { movement = 'static' },
    props = {
        { key = 'high', kind = 'number', label = 'Fuerza en el pulso', group = 'Trampolín de compás', default = 2.1,
          min = 0.5, max = 4, step = 0.05, help = 'Multiplicador del salto normal al caer en el pulso (2.1 = unas 7 casillas)' },
        { key = 'low', kind = 'number', label = 'Fuerza fuera del pulso', group = 'Trampolín de compás', default = 1.1,
          min = 0.5, max = 4, step = 0.05, help = 'Fuera del pulso (1.1 = unas 2 casillas)' },
        { key = 'window', kind = 'number', label = 'Margen (s)', group = 'Trampolín de compás', default = 0.1,
          min = 0.02, max = 0.25, step = 0.01, help = 'Cuánto antes o después del pulso cuenta como «en el pulso»' },
        { key = 'cooldown', kind = 'number', label = 'Extendido tras lanzar (s)', group = 'Trampolín de compás', default = 0.3,
          min = 0, max = 10, step = 0.05 },
    },
    editor = { sprite = 'assets/images/mechanisms/beatspring/idle.png', draw = editorIcon },
}
