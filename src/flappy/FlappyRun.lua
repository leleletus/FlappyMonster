-- src/flappy/FlappyRun.lua
-- La PARTIDA de la campaña Flappy en curso (como src/story/Run.lua para la historia): el hueco abierto, qué está
-- superado y qué se puede jugar. Las reglas de progreso son las de src/story/RunCore.lua; aquí, lo propio:
--   FlappyRun.complete(id, result)  etapa superada: nota, récord, puntos (también al MONEDERO) y el premio de la nota; con la
--                                   ÚLTIMA etapa de la última zona, la campaña está terminada (Campaign.finished: desbloquea
--                                   Aventura). Guarda.
--   FlappyRun.buy(id, precio)       comprar un power-up en una tienda del mapa (src/flappy/Shops.lua) con el monedero
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
    -- el MONEDERO: los puntos de la etapa (y los del premio) entran SOLO aquí, al terminarla (golden rule 7). Aparte del
    -- récord `points` (que solo sube con lo que mejora): comprar gasta el monedero y el récord no baja
    local d = FlappyRun.data
    d.wallet = (d.wallet or 0) + (out.points or 0) + ((out.reward and out.reward.points) or 0)
    -- los FLAPPIES ENJAULADOS liberados en la etapa (types/items/cage.lua): solo ahora, al terminarla (golden rule 7).
    -- Cada uno liberado POR PRIMERA VEZ en esta partida regala su power-up (`gift`); con el inventario lleno se pierde
    -- (`lostGifts`, para el aviso de los resultados) y la jaula cuenta igual como liberada
    if result and result.rescued and #result.rescued > 0 then
        d.rescued = d.rescued or {}
        local t = d.rescued[id] or {}
        for _, i in ipairs(result.rescued) do
            if not t[i] then
                local gift = FlappyRun.cageGift(id, i)
                if gift then
                    if FlappyRun.addPowerup(gift) == 'ok' then
                        out.gifts = out.gifts or {}; out.gifts[#out.gifts + 1] = gift
                    else
                        out.lostGifts = out.lostGifts or {}; out.lostGifts[#out.lostGifts + 1] = gift
                    end
                end
            end
            t[i] = true
        end
        d.rescued[id] = t
    end
    local last = Zones.nodes(Zones.count())
    if last[#last] and last[#last].id == id then require('src/flappy/Campaign').finished() end
    FlappyRun.save()
    return out
end

-- Las colocaciones de una etapa (lee su archivo una vez)
local placements = {}
local function entitiesOf(id)
    if placements[id] == nil then
        local ok, src = pcall(love.filesystem.read, require('src/flappy/Zones').path(id))
        local data = ok and src and select(2, pcall(require('libs/json').decode, src))
        placements[id] = type(data) == 'table' and data.entities or {}
    end
    return placements[id]
end

-- El power-up que regala la jaula de la colocación i (su prop `gift`; por defecto, el escudo) o nil si no es una jaula
function FlappyRun.cageGift(id, i)
    local e = entitiesOf(id)[i]
    if not (e and e.type == 'cage') then return nil end
    return (e.props and e.props.gift) or 'shield'
end

-- Flappies liberados en una etapa (guardados) y cuántas jaulas tiene → liberados, total
local cageCount = {}
function FlappyRun.rescuedCount(id)
    if cageCount[id] == nil then
        local n = 0
        for _, e in ipairs(entitiesOf(id)) do if e.type == 'cage' then n = n + 1 end end
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

-- COMPRAR en una tienda (src/flappy/Shops.lua): → 'ok' | 'poor' (no llega el monedero) | 'full' | 'type_full'
-- (addPowerup). Solo 'ok' gasta y se GUARDA ya; lo demás no toca nada. El récord de puntos no baja
function FlappyRun.buy(id, price)
    local d = FlappyRun.data
    if not d then return 'poor' end
    price = math.max(0, math.floor(price or 0))
    if (d.wallet or 0) < price then return 'poor' end
    local r = FlappyRun.addPowerup(id)
    if r ~= 'ok' then return r end
    d.wallet = (d.wallet or 0) - price
    FlappyRun.save()
    return 'ok'
end

-- El inventario para el nivel (AdventureState `args.powerups`, la rueda): los tipos que se tienen en el orden del
-- catálogo (los de Flappy) y gastar uno
function FlappyRun.powerupInventory()
    return {
        items = function()
            local out, inv = {}, (FlappyRun.data and FlappyRun.data.inventory) or {}
            for _, p in ipairs(require('src/world/powerups/Powerups').forMode('flappy')) do
                if (inv[p.id] or 0) > 0 then out[#out + 1] = { id = p.id, count = inv[p.id] } end
            end
            return out
        end,
        spend = function(id) return FlappyRun.spendPowerup(id) end,
    }
end

function FlappyRun.gameOver()
    return FlappyRun.restartWorld((FlappyRun.frontier()))
end

return FlappyRun
