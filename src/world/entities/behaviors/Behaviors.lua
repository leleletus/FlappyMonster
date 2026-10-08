-- src/world/entities/behaviors/Behaviors.lua
-- Catálogo de COMPORTAMIENTOS para los enemigos hechos con datos (src/world/entities/base/DataEnemy.lua; se montan
-- en el editor de enemigos, `love . --enemy`). Un comportamiento es una pieza suelta: decide cuándo toma el mando
-- del enemigo, qué hace mientras lo tiene y qué estados (= animaciones) usa.
--
-- ── Añadir un comportamiento nuevo (receta) ──────────────────────────────────
--  1. Crea src/world/entities/behaviors/<nombre>.lua que devuelva:
--       { name = 'chase', label = 'Perseguir', description = '…',
--         states = { 'run' },                        -- estados que usa (el editor pide una animación para cada uno)
--         params = { { key='range', kind='number', label='Alcance (casillas)', default=5, min=1, max=20, step=0.5 } },
--         think  = function(e, cfg, dt, level) … return true end,   -- en 'walk' / 'idle': ¿toma el mando? (e:enter(estado))
--         update = function(e, cfg, dt, level) … end,               -- cada paso mientras e.state es uno de sus estados
--         hazards = function(e, cfg) return { {x,y,w,h, effect='hurt', dmg=1} } end,    -- (opcional) cajas que dañan
--         disabled = function(e, cfg) return true end,       -- (opcional) ¿ahora no se le puede tocar ni pisar?
--         anim = function(e, cfg, set, map) return 'hide', t end,   -- (opcional) secuencia y tiempo dentro de su estado
--         crawlOk = true }                                    -- (opcional) vale también para un enemigo que trepa
--  2. Añade su nombre a TYPES abajo.
--  Listo: sale en el editor de enemigos con sus parámetros, y funciona en un jugador y online (solo simulan un
--  jugador y el servidor; el cliente dibuja el estado y su reloj `deadTimer`, que ya viajan por red).
-- Reglas: nada de love.graphics ni de estado que el dibujo necesite y no viaje; el tiempo dentro de un estado es
-- `e.deadTimer` (e:enter lo pone a 0); para ver a los jugadores, `e:nearestPlayer(level)`.
local TYPES = { 'chase', 'melee', 'leap', 'shoot', 'hide' }

local Behaviors = { byName = {}, list = {} }
for _, name in ipairs(TYPES) do
    local b = require('src/world/entities/behaviors/' .. name)
    assert(b.name == name, 'comportamiento ' .. name .. ': name no coincide')
    b.states, b.params = b.states or {}, b.params or {}
    Behaviors.byName[name] = b
    Behaviors.list[#Behaviors.list + 1] = b
end

-- Valores de un comportamiento colocado: los del enemigo sobre los de por defecto
function Behaviors.config(entry)
    local b = Behaviors.byName[entry.type]
    local cfg = {}
    if not b then return cfg end
    for _, p in ipairs(b.params) do
        local v = entry[p.key]
        if v == nil then v = p.default end
        cfg[p.key] = v
    end
    return cfg
end

return Behaviors
