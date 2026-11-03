-- src/world/systems/Sim.lua
-- El PEGAMENTO de la simulación que comparten un jugador (AdventureState) y el servidor (server/srv/sim.lua): las
-- piezas del paso que antes eran dos copias a mano. Las REGLAS siguen en su sitio (Interactions, BossZones, AutoScroll...);
-- aquí solo lo que los dos bucles hacían igual. El ORDEN del paso todavía no es el mismo en los dos (ver
-- docs/architecture/known-debt.md): no se cambia aquí, cambiaría el juego.
local Entities   = require 'src/world/entities/Entities'
local Push       = require 'src/world/systems/Push'
local AutoScroll = require 'src/world/systems/AutoScroll'
local BossZones  = require 'src/world/systems/BossZones'
local Difficulty = require 'src/core/Difficulty'
local Interactions = require 'src/world/entities/base/Interactions'

local Sim = {}

Sim.TIME_LIMIT = 600        -- s: el límite de un nivel; al llegar, mueren todos con todas sus vidas

-- Antes de mover a los jugadores: los cuerpos sólidos (jefes, cajas, platillos) y lo que sopla
function Sim.bodies(level, entities)
    level.solidBodies = Entities.solidBodies(entities)
    level.pushers = Push.collect(entities)
end

-- Dónde reaparece quien murió: con cámara automática, en el centro de lo que se ve; en una zona de jefe con el suelo
-- roto, en un sitio firme de la zona; si no, su punto de control (lo deja como estaba)
function Sim.respawnPoint(level, pa)
    local rx, ry = AutoScroll.respawnPoint(level)
    if not rx then rx, ry = BossZones.respawnPoint(level, pa) end
    if rx then pa.spawnX, pa.spawnY = rx, ry end
end

-- Un paso de las entidades, cada una a su ritmo (la dificultad). `emit(x, y)` pone de dónde salen sus sonidos (nil al
-- acabar); `prune` quita las que murieron (salvo los súbditos de reserva de un jefe, que él reutiliza)
function Sim.stepEntities(level, entities, dt, emit, prune)
    level.liveEntities = entities                    -- (obstáculos entre entidades)
    for i = #entities, 1, -1 do
        local e = entities[i]
        if emit then emit(e.x, e.y) end
        e:update(Difficulty.dt(e, dt), level)
        if prune and not e.alive and not e.summonOf then table.remove(entities, i) end
    end
    if emit then emit(nil, nil) end
end

-- El impacto del ground pound de `pa` empuja a los OTROS jugadores que alcanza (Interactions.poundReaches).
-- `each(o, fn)` opcional: cómo hacerlo (el servidor, con el sonido a nombre de nadie y desde el empujado)
function Sim.poundPlayers(pa, others, each)
    if not pa.gpLanded then return end
    for _, o in ipairs(others) do
        if o ~= pa and not o.dying and Interactions.poundReaches(pa, o) then
            local push = function() o:knockback(o.x >= pa.x and 1 or -1) end
            if each then each(o, push) else push() end
        end
    end
end

return Sim
