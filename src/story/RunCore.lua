-- src/story/RunCore.lua
-- Las reglas de PROGRESO que comparten las campañas (la historia: src/story/Run.lua; la campaña Flappy:
-- src/flappy/FlappyRun.lua). RunCore.install(R, saves, worlds) añade a la tabla `R` (con `R.slot`, `R.data`):
--   open(i[, difficulty]) · close() · active() · save() · isDone(id) · worldOpen(w) · state(w, k) · progress([w])
--   frontier() · setLives(n) · worldRating(w) · score(id, result) → resumen · giveReward(rw) · restartWorld(w)
-- `saves`: SLOTS, new(difficulty), load(i), write(i, d). `worlds`: count(), get(w) (con `.boss`, que puede faltar),
-- nodes(w) → { { id = nivel }, ... } en orden (el jefe, el último).
-- Reglas: en un mundo los niveles se abren en orden; el mundo siguiente, al superar el último nodo del anterior (su
-- jefe, si lo tiene).
local RunCore = {}

function RunCore.install(R, saves, worlds)
    R.slot, R.data = nil, nil

    function R.open(i, difficulty)
        R.slot = i
        R.data = saves.load(i)
        if not R.data then
            R.data = saves.new(difficulty)
            saves.write(i, R.data)
        end
        return R.data
    end

    function R.close() R.slot, R.data = nil, nil end
    function R.active() return R.data ~= nil end
    function R.save() if R.slot and R.data then saves.write(R.slot, R.data) end end
    function R.isDone(id) return R.data ~= nil and R.data.done[id] == true end

    -- (el último nodo del mundo: su jefe o, sin jefe, su último nivel)
    local function lastOf(w)
        local nodes = worlds.nodes(w)
        return nodes[#nodes] and nodes[#nodes].id
    end

    -- (o, en una partida de antes de que se metiera un mundo nuevo delante de él, el que ya tenía abierto: Save.migrate)
    function R.worldOpen(w)
        if w <= 1 then return true end
        local prev, W = worlds.get(w - 1), worlds.get(w)
        if not (prev and W) then return false end
        return R.isDone(prev.boss or lastOf(w - 1)) or (R.data ~= nil and R.data.open ~= nil and R.data.open[W.id] == true)
    end

    function R.state(w, k)
        local nodes = worlds.nodes(w)
        local n = nodes[k]
        if not n or not R.worldOpen(w) then return 'locked' end
        if R.isDone(n.id) then return 'done' end
        if k == 1 or R.isDone(nodes[k - 1].id) then return 'open' end
        return 'locked'
    end

    -- Superados / total (de un mundo, o de todo)
    function R.progress(w)
        local done, total = 0, 0
        for i = (w or 1), (w or worlds.count()) do
            for _, n in ipairs(worlds.nodes(i)) do
                total = total + 1
                if R.isDone(n.id) then done = done + 1 end
            end
        end
        return done, total
    end

    -- Dónde colocarse al abrir el mapa: el primer nodo sin superar del mundo más avanzado
    function R.frontier()
        for w = 1, worlds.count() do
            if R.worldOpen(w) then
                for k = 1, #worlds.nodes(w) do
                    if R.state(w, k) == 'open' then return w, k end
                end
            end
        end
        return worlds.count(), #worlds.nodes(worlds.count())      -- todo superado
    end

    -- Vidas con las que sigue la partida (al salir de un nivel sin acabarlo también cuentan las perdidas)
    function R.setLives(n)
        if not R.data then return end
        R.data.lives = math.max(1, math.floor(n))
        R.save()
    end

    -- Nota de un mundo: la media de la mejor valoración de cada nivel suyo (los no superados, 0)
    function R.worldRating(w)
        local Score = require 'src/story/Score'
        local list, nodes = {}, worlds.nodes(w)
        for _, n in ipairs(nodes) do
            local b = R.data and R.data.best[n.id]
            if b and b.rating and R.isDone(n.id) then list[#list + 1] = b.rating end
        end
        return Score.average(list, #nodes)
    end

    -- Nivel superado: se apunta, se guardan las vidas, se calcula su NOTA (src/story/Score.lua), su mejor marca y los
    -- puntos (solo lo que MEJORA el récord del nivel). NO guarda: quien llama añade lo suyo y guarda una vez.
    --   → { rating, grade, parts, points, record, par, reward (premio de la letra, la primera vez), gain, first }
    function R.score(id, result)
        local d = R.data
        if not d then return nil end
        local Score = require 'src/story/Score'
        local Difficulty = require 'src/core/Difficulty'
        result = result or {}
        local first = not d.done[id]
        d.done[id] = true
        if result.lives then d.lives = result.lives end      -- (las vidas se llevan al nivel siguiente)
        local sc = Score.level({ time = result.time, par = result.par or Score.par(result.width), deaths = result.deaths, hits = result.hits,
                                 kills = result.kills, killable = result.killable, stars = result.stars, starsTotal = result.starsTotal })
        local points = math.floor((result.score or 0) * Difficulty.of(d.difficulty, 'scoreMult', 1) + 0.5)
        local b = d.best[id] or {}
        -- (`record`: solo si MEJORA una nota que ya tenía en ESTA partida; la primera vez no hay récord que batir)
        local out = { rating = sc.rating, grade = sc.grade, parts = sc.parts, points = points, record = b.rating ~= nil and sc.rating > b.rating,
                      par = result.par or Score.par(result.width), first = first }
        -- premio del nivel: solo la primera vez que se llega a esa letra
        local order = { S = 4, A = 3, B = 2, C = 1, D = 0 }
        if (order[sc.grade] or 0) > (order[b.grade or ''] or -1) then out.reward = Score.LEVEL_REWARD[sc.grade] end
        out.gain = math.max(0, points - (b.score or 0))
        if points > (b.score or -1) then b.score = points end
        if result.time and (not b.time or result.time < b.time) then b.time = math.floor(result.time * 100) / 100 end
        if sc.rating > (b.rating or -1) then b.rating, b.grade = sc.rating, sc.grade end
        d.best[id] = b
        d.points = (d.points or 0) + out.gain
        d.playTime = (d.playTime or 0) + (result.time or 0)
        -- vidas extra cogidas: ya no vuelven a dar vidas en este nivel (AdventureState `taken`)
        if result.taken and #result.taken > 0 then
            d.taken = d.taken or {}
            local t = d.taken[id] or {}
            for _, i in ipairs(result.taken) do t[i] = true end
            d.taken[id] = t
        end
        return out
    end

    -- Da un PREMIO (Score.LEVEL_REWARD, WORLD_REWARD…): { lives = n } y/o { points = n } (vidas hasta 99). No guarda.
    function R.giveReward(rw)
        local d = R.data
        if not (d and rw) then return end
        if rw.lives then d.lives = math.min(99, d.lives + rw.lives) end
        if rw.points then d.points = (d.points or 0) + rw.points end
    end

    -- GAME OVER de mundo: sus niveles dejan de estar superados, las vidas vuelven a las del principio y se va a su
    -- primer nodo. Los récords (`best`) se conservan. Guarda.
    function R.restartWorld(w)
        local d = R.data
        if not d then return w end
        d.lives = require('src/core/Difficulty').of(d.difficulty, 'livesStart', 3)
        d.gameOvers = (d.gameOvers or 0) + 1
        for _, n in ipairs(worlds.nodes(w)) do d.done[n.id] = nil end
        d.world, d.node = w, 1
        R.save()
        return w
    end

    return R
end

return RunCore
