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
    -- los FLAPPIES ENJAULADOS liberados en la etapa (types/items/cage.lua): solo ahora, al terminarla (golden rule 7)
    if result and result.rescued and #result.rescued > 0 then
        local d = FlappyRun.data
        d.rescued = d.rescued or {}
        local t = d.rescued[id] or {}
        for _, i in ipairs(result.rescued) do t[i] = true end
        d.rescued[id] = t
    end
    local last = Zones.nodes(Zones.count())
    if last[#last] and last[#last].id == id then require('src/flappy/Campaign').finished() end
    FlappyRun.save()
    return out
end

-- Flappies liberados en una etapa (guardados) y cuántas jaulas tiene (lee el nivel una vez) → liberados, total
local cageCount = {}
function FlappyRun.rescuedCount(id)
    if cageCount[id] == nil then
        local ok, src = pcall(love.filesystem.read, require('src/flappy/Zones').path(id))
        local data = ok and src and select(2, pcall(require('libs/json').decode, src))
        local n = 0
        for _, e in ipairs(type(data) == 'table' and data.entities or {}) do if e.type == 'cage' then n = n + 1 end end
        cageCount[id] = n
    end
    local freed = 0
    for _ in pairs((FlappyRun.data and FlappyRun.data.rescued and FlappyRun.data.rescued[id]) or {}) do freed = freed + 1 end
    return freed, cageCount[id]
end

-- ── POWER-UPS (docs/design/powerups.md): inventario de la partida, 6 en total y 3 de cada tipo ───────────────────────
FlappyRun.MAX_TOTAL, FlappyRun.MAX_TYPE = 6, 3

function FlappyRun.inventoryCount()
    local n = 0
    for _, c in pairs((FlappyRun.data and FlappyRun.data.inventory) or {}) do n = n + c end
    return n
end

-- Añade uno (ganado AL TERMINAR una etapa: golden rule 7) → 'ok' | 'full' (6 en total) | 'type_full' (3 de ese tipo).
-- No guarda: quien lo llama guarda una vez
function FlappyRun.addPowerup(id)
    local d = FlappyRun.data
    if not d then return 'full' end
    d.inventory = d.inventory or {}
    if FlappyRun.inventoryCount() >= FlappyRun.MAX_TOTAL then return 'full' end
    if (d.inventory[id] or 0) >= FlappyRun.MAX_TYPE then return 'type_full' end
    d.inventory[id] = (d.inventory[id] or 0) + 1
    return 'ok'
end

-- Gasta uno: se GUARDA YA, pase lo que pase después (el usuario: "en el momento justo en que lo usas ya se gasta")
function FlappyRun.spendPowerup(id)
    local d = FlappyRun.data
    if not (d and d.inventory and (d.inventory[id] or 0) > 0) then return false end
    d.inventory[id] = d.inventory[id] - 1
    if d.inventory[id] <= 0 then d.inventory[id] = nil end
    FlappyRun.save()
    return true
end

function FlappyRun.gameOver()
    return FlappyRun.restartWorld((FlappyRun.frontier()))
end

return FlappyRun
