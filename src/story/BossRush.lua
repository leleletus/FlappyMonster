-- src/story/BossRush.lua
-- BOSS RUSH (Juego Libre, pestaña JEFES; el usuario, 2026-11-02: "para por fin separar los niveles de carrera de los de
-- jefes"): todas las peleas de jefe seguidas. Cada nivel empieza YA en la arena de su primer jefe (AdventureState
-- `atBoss`) y termina al vencer a sus jefes (`endOnBoss`: sin ir a la meta). Las vidas pasan de una pelea a la siguiente
-- (empieza con LIVES); quedarse sin ninguna acaba el Boss Rush. El tiempo es la suma de las peleas; el mejor con todas
-- vencidas se guarda (bossrush.dat, por dificultad). Al acabar se vuelve al Juego Libre con el resumen (`rush`).
-- Orden: los jefes de la historia mundo a mundo (y tras cada uno, sus jefes secretos), luego cualquier otro nivel con
-- zona de jefe. Fuera: los niveles de EVENTO (el Mega Mashup es su propia aventura).
local LevelCatalog = require 'src/world/level/LevelCatalog'
local Worlds       = require 'src/story/Worlds'

local BossRush = {}
BossRush.LIVES = 5
local SAVE = 'bossrush.dat'

-- Los niveles del Boss Rush, en orden (archivos)
function BossRush.levels()
    local have, out, seen = {}, {}, {}
    for _, f in ipairs(LevelCatalog.files()) do
        -- (las etapas Flappy son de su campaña: ahí no empieza la pelea sola)
        if LevelCatalog.hasBossZone(f) and not LevelCatalog.EVENTS[f] and not LevelCatalog.isFlappy(f) then have[f] = true end
    end
    local function add(id)
        local f = id .. '.json'
        if have[f] and not seen[f] then seen[f] = true; out[#out + 1] = f end
    end
    for _, W in ipairs(Worlds.LIST) do
        add(W.boss)
        for _, s in ipairs(W.secrets or {}) do add(s.level) end
    end
    local rest = {}
    for f in pairs(have) do if not seen[f] then rest[#rest + 1] = f end end
    table.sort(rest)
    for _, f in ipairs(rest) do out[#out + 1] = f end
    return out
end

local function loadBest()
    local ok, t = pcall(function() return love.filesystem.load(SAVE)() end)
    return (ok and type(t) == 'table') and t or {}
end
function BossRush.best(diff) return loadBest()[diff or 'none'] end
local function saveBest(diff, time)
    local t = loadBest()
    t[diff or 'none'] = time
    local lines = {}
    for k, v in pairs(t) do lines[#lines + 1] = string.format('[%q] = %.2f', k, v) end
    pcall(love.filesystem.write, SAVE, 'return { ' .. table.concat(lines, ', ') .. ' }\n')
end

-- Empieza (diff: la dificultad elegida en el Juego Libre)
function BossRush.start(diff)
    local run = { list = BossRush.levels(), i = 1, lives = BossRush.LIVES, time = 0, diff = diff }
    if #run.list == 0 then return false end
    BossRush._play(run)
    return true
end

function BossRush._finish(run, all)
    local best = BossRush.best(run.diff)
    local record = all and (not best or run.time < best)
    if record then saveBest(run.diff, run.time) end
    gStateMachine:change('free_play', { rush = { cleared = run.i - 1, total = #run.list, time = run.time, all = all,
                                                 record = record, best = record and run.time or best } })
end

function BossRush._play(run)
    gStateMachine:change('adventure', {
        level = LevelCatalog.DIR .. '/' .. run.list[run.i], returnTo = 'free_play', difficulty = run.diff,
        lives = run.lives, atBoss = true, endOnBoss = true, rush = { i = run.i, n = #run.list },
        onFinish = function(r)
            run.time, run.lives = run.time + (r.time or 0), math.max(1, r.lives or run.lives)
            run.i = run.i + 1
            if run.i > #run.list then BossRush._finish(run, true) else BossRush._play(run) end
        end,
        onGameOver = function() BossRush._finish(run, false) end,
    })
end

return BossRush
