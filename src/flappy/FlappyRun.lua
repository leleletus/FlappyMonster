-- src/flappy/FlappyRun.lua
-- La PARTIDA de la campaña Flappy en curso (como src/story/Run.lua para la historia): el hueco abierto, qué está
-- superado y qué se puede jugar. Las reglas de progreso son las de src/story/RunCore.lua; aquí, lo propio:
--   FlappyRun.complete(id, result)  etapa superada: nota, récord, puntos y el premio de la nota; con la ÚLTIMA etapa de la última zona,
--                                   la campaña está terminada (Campaign.finished: desbloquea Aventura). Guarda.
--   FlappyRun.gameOver()            sin vidas: de vuelta al principio de la zona en la que va
local FlappySave = require 'src/flappy/FlappySave'
local Zones = require 'src/flappy/Zones'

local FlappyRun = {}
require('src/story/RunCore').install(FlappyRun, FlappySave, Zones)

function FlappyRun.complete(id, result)
    if not FlappyRun.data then return nil end
    local out = FlappyRun.score(id, result)
    out.first = nil
    FlappyRun.giveReward(out.reward)          -- (el premio de la nota, la primera vez: S +1 vida, A +500 puntos)
    local last = Zones.nodes(Zones.count())
    if last[#last] and last[#last].id == id then require('src/flappy/Campaign').finished() end
    FlappyRun.save()
    return out
end

function FlappyRun.gameOver()
    return FlappyRun.restartWorld((FlappyRun.frontier()))
end

return FlappyRun
