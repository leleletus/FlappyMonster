-- src/world/systems/Sim.lua
-- El PEGAMENTO de la simulación que comparten un jugador (AdventureState) y el servidor (server/srv/sim.lua): las
-- piezas del paso que antes eran dos copias a mano, y desde 0.5.185 EL ORDEN DEL PASO (Sim.step): antes cada bucle
-- llevaba el suyo y lo que funcionaba en un jugador podía ir distinto online. Las REGLAS siguen en su sitio
-- (Interactions, BossZones, AutoScroll...).
local Entities   = require 'src/world/entities/Entities'
local Push       = require 'src/world/systems/Push'
local AutoScroll = require 'src/world/systems/AutoScroll'
local BossZones  = require 'src/world/systems/BossZones'
local Difficulty = require 'src/core/Difficulty'
local Interactions = require 'src/world/entities/base/Interactions'
local Carry      = require 'src/world/systems/Carry'
local PointAreas = require 'src/world/systems/PointAreas'

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

-- ── EL PASO: uno, en el mismo orden para un jugador (AdventureState) y para el servidor (server/srv/sim.lua) ───────
-- Es el orden que ya tenía el servidor (el que obliga el juego en red: cada jugador choca con lo que VEÍA justo al
-- moverse, y otra vez cuando ya se movieron las entidades). Lo que es solo de uno de los dos va en `h` (ganchos):
--   1  h.floods()                    el agua de las inundaciones (un jugador: su reloj; el servidor: el del tick)
--   2  Sim.bodies                    cuerpos sólidos y lo que sopla
--   3  h.players()                   mover a los jugadores; cada uno, al moverse: oxígeno, 1ª PASADA de choques con
--                                    las entidades y las metas. Devolver 'stop' corta el paso (el bonus terminó)
--   4  Carry.step                    coger / lanzar (level.players)
--   5  level:update                  ON/OFF pendientes, hielo fino, bloques golpeados, burbujas
--   6  Sim.stepEntities              las entidades (h.emit: de dónde salen sus sonidos; h.prune: quitar las muertas)
--   7  h.afterEntities()             (opcional; el servidor: daño de prueba, la historia para compensar el lag)
--   8  PointAreas.update             zonas de puntos: h.zonePlayers() quién cuenta, h.zonePoints(pa, pts)
--   9  h.bosses()                    las zonas de jefe (llegadas, inicio y fin de cada pelea)
--  10  h.autoScroll()                la cámara automática
--  11  h.interactions()              2ª PASADA de choques: una entidad que se movió alcanza a un jugador quieto
-- Devuelve false si h.players cortó el paso.
function Sim.step(level, entities, dt, h)
    if h.floods then h.floods() end
    Sim.bodies(level, entities)
    if h.players() == 'stop' then return false end
    Carry.step(level, level.players or {}, entities)
    level:update(dt)
    Sim.stepEntities(level, entities, dt, h.emit, h.prune)
    if h.afterEntities then h.afterEntities() end
    if h.zonePlayers then PointAreas.update(level, dt, h.zonePlayers(), h.zonePoints) end
    if h.bosses then h.bosses() end
    if h.autoScroll then h.autoScroll() end
    if h.interactions then h.interactions() end
    return true
end

return Sim
