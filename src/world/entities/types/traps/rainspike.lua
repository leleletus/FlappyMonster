-- Pincho de lluvia: el mismo pincho que cae del techo (spikefall.lua), pero NO
-- detecta a nadie por su cuenta: lo hace caer una "Lluvia de pinchos"
-- (spikerain.lua) de su mismo grupo, que decide cuáles, cuándo y cuántos.
-- Se "pinta" en el editor arrastrando a lo largo de un techo.
local Entity   = require 'src/world/entities/base/Entity'
local base     = require 'src/world/entities/types/traps/spikefall'

local RainSpike = Entity.extend(base.class, { debugColor = { 1, 0.45, 0.8 } })
RainSpike.autoDetect = false

-- En el editor se distingue del pincho normal con una marca rosa
function RainSpike:render(camX, camY)
    base.class.render(self, camX, camY)
    if EDITOR_VIEW then
        love.graphics.setColor(1, 0.35, 0.8, 0.9)
        love.graphics.rectangle('fill', math.floor(self.x - camX) - 3, math.floor(self.y - camY - self.outerH / 2), 6, 4)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return {
    name = 'rainspike', label = 'Pincho de lluvia', category = 'Trampas',
    description = 'Pincho que solo cae cuando se lo ordena una Lluvia de pinchos de su grupo. Arrastra para pintar varios.',
    class = RainSpike,
    placement = 'sub',
    ceilingOnly = true,
    paint = true,                   -- en el editor se colocan arrastrando
    hide = base.hide,
    props = {
        { key='group', kind='int', label='Grupo de lluvia', group='Lluvia', default=1, min=1, max=99, step=1,
          help='La Lluvia de pinchos con este mismo grupo es la que lo hace caer' },
        { key='fallDelay', kind='number', label='Aviso por defecto (s)', group='Trampa', default=0.5,
          min=0.1, max=3, step=0.05, help='Temblor antes de caer. Normalmente lo decide la lluvia según la dificultad' },
        { key='stuckTime', kind='number', label='Clavado en el suelo (s)', group='Trampa', default=1.2,
          min=0.2, max=20, step=0.1, help='Luego desaparece y vuelve a salir del techo' },
        { key='fallSpeed', kind='number', label='Velocidad de caída', group='Trampa', default=1,
          min=0.3, max=3, step=0.1, help='Multiplicador (1 = como el pincho que cae normal)' },
    },
    editor = { sprite = 'assets/images/items/spikefall.png' },
}
