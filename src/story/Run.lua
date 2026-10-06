-- src/story/Run.lua
-- La PARTIDA de historia en curso: el hueco abierto, qué está superado y qué se puede jugar.
--   Run.open(i[, difficulty])  abre el hueco i (lo crea si está vacío)
--   Run.state(w, k)            'done' | 'open' | 'locked' del nodo k del mundo w
--   Run.worldOpen(w)           ¿se puede entrar en ese mundo? (el jefe del anterior, superado)
--   Run.complete(id, result)   nivel superado: se apunta (y su mejor puntuación) y se guarda
-- Reglas: en un mundo los niveles se abren en orden; el jefe, con todos los anteriores superados;
-- el mundo siguiente, al vencer al jefe.
local Save = require 'src/story/Save'
local Worlds = require 'src/story/Worlds'

local Run = { slot = nil, data = nil }

function Run.open(i, difficulty)
    Run.slot = i
    Run.data = Save.load(i)
    if not Run.data then
        Run.data = Save.new(difficulty)
        Save.write(i, Run.data)
    end
    return Run.data
end

function Run.close() Run.slot, Run.data = nil, nil end
function Run.active() return Run.data ~= nil end
function Run.save() if Run.slot and Run.data then Save.write(Run.slot, Run.data) end end

function Run.isDone(id) return Run.data ~= nil and Run.data.done[id] == true end

function Run.worldOpen(w)
    if w <= 1 then return true end
    local prev = Worlds.get(w - 1)
    return prev ~= nil and Worlds.get(w) ~= nil and Run.isDone(prev.boss)
end

function Run.state(w, k)
    local nodes = Worlds.nodes(w)
    local n = nodes[k]
    if not n or not Run.worldOpen(w) then return 'locked' end
    if Run.isDone(n.id) then return 'done' end
    if k == 1 or Run.isDone(nodes[k - 1].id) then return 'open' end
    return 'locked'
end

-- Superados / total (de un mundo, o de todo el juego)
function Run.progress(w)
    local done, total = 0, 0
    for i = (w or 1), (w or Worlds.count()) do
        for _, n in ipairs(Worlds.nodes(i)) do
            total = total + 1
            if Run.isDone(n.id) then done = done + 1 end
        end
    end
    return done, total
end

-- Dónde colocarse al abrir el mapa: el primer nodo sin superar del mundo más avanzado
function Run.frontier()
    for w = 1, Worlds.count() do
        if Run.worldOpen(w) then
            for k = 1, #Worlds.nodes(w) do
                if Run.state(w, k) == 'open' then return w, k end
            end
        end
    end
    return Worlds.count(), #Worlds.nodes(Worlds.count())      -- todo superado
end

-- Nivel superado: se apunta, se guardan las vidas, se calcula su NOTA (src/story/Score.lua) y se dan
-- los premios. Devuelve el resumen para la pantalla de resultados:
--   { rating, grade, parts, points (del nivel, ya con el × de la dificultad), record (mejor nota que antes),
--     reward = { lives | points } | nil, world = { rating, grade, reward } | nil (si con él se completa el mundo) }
function Run.complete(id, result)
    local d = Run.data
    if not d then return nil end
    local Score = require 'src/story/Score'
    local Difficulty = require 'src/Difficulty'
    result = result or {}
    local first = not d.done[id]
    d.done[id] = true
    if result.lives then d.lives = result.lives end      -- (las vidas se llevan al nivel siguiente)
    local sc = Score.level({ time = result.time, par = Score.par(result.width), deaths = result.deaths, hits = result.hits,
                             kills = result.kills, killable = result.killable, stars = result.stars, starsTotal = result.starsTotal })
    local points = math.floor((result.score or 0) * Difficulty.of(d.difficulty, 'scoreMult', 1) + 0.5)
    local b = d.best[id] or {}
    local out = { rating = sc.rating, grade = sc.grade, parts = sc.parts, points = points, record = sc.rating > (b.rating or -1) }
    -- premio del nivel: solo la primera vez que se llega a esa letra
    local had = b.grade
    local order = { S = 4, A = 3, B = 2, C = 1, D = 0 }
    if (order[sc.grade] or 0) > (order[had or ''] or -1) then out.reward = Score.LEVEL_REWARD[sc.grade] end
    if points > (b.score or -1) then b.score = points end
    if result.time and (not b.time or result.time < b.time) then b.time = math.floor(result.time * 100) / 100 end
    if sc.rating > (b.rating or -1) then b.rating, b.grade = sc.rating, sc.grade end
    d.best[id] = b
    d.points = (d.points or 0) + points
    d.playTime = d.playTime + (result.time or 0)
    -- ¿con este se completa su mundo? → nota del mundo y su premio (una vez)
    for w = 1, Worlds.count() do
        local nodes = Worlds.nodes(w)
        if nodes[#nodes] and nodes[#nodes].id == id then
            local rating, grade = Run.worldRating(w)
            out.world = { index = w, rating = rating, grade = grade }
            if first and not d.worldReward[w] then
                d.worldReward[w] = grade
                out.world.reward = Score.WORLD_REWARD[grade]
            end
        end
    end
    -- (los dos premios, cada uno si lo hay: con ipairs un nil delante se saltaba el del mundo)
    for _, rw in pairs({ a = out.reward, b = out.world and out.world.reward or nil }) do
        if rw.lives then d.lives = math.min(99, d.lives + rw.lives) end
        if rw.points then d.points = d.points + rw.points end
    end
    -- ¿JUEGO ACABADO (el jefe del último mundo)? → desbloquea la dificultad siguiente (global, para las 3
    -- partidas: Difícil → Extremo, Extremo → Xtra extremo; src/Difficulty.lua UNLOCKS)
    local lastNodes = Worlds.nodes(Worlds.count())
    if lastNodes[#lastNodes] and lastNodes[#lastNodes].id == id then
        out.unlocked = Run.unlockAfter(d.difficulty)
    end
    Run.save()
    return out
end

-- BONUS (arena contra el bot): 'done' ganado · 'open' con el jefe del mundo vencido · 'locked'
Run.BONUS_REWARD = { lives = 1, points = 1000 }
function Run.bonusState(w)
    local W, b = Worlds.get(w), Worlds.bonus(w)
    if not (b and Run.data) then return 'locked' end
    if Run.data.bonus[b.id] and Run.data.bonus[b.id].won then return 'done' end
    return Run.isDone(W.boss) and 'open' or 'locked'
end

-- Fin de una partida bonus: apunta la mejor puntuación; la PRIMERA victoria da el premio. Devuelve el premio o nil.
function Run.bonusResult(id, result)
    local d = Run.data
    if not d then return nil end
    local b = d.bonus[id] or {}
    local reward
    if result.won and not b.won then
        b.won, reward = true, Run.BONUS_REWARD
        d.lives = math.min(99, d.lives + reward.lives)
        d.points = (d.points or 0) + reward.points
    end
    b.best = math.max(b.best or 0, result.score or 0)
    b.played = (b.played or 0) + 1
    d.bonus[id] = b
    Run.save()
    return reward
end

-- Desbloqueo por acabar el juego en `difficulty`: devuelve el id NUEVO desbloqueado (nil si ya lo estaba)
function Run.unlockAfter(difficulty)
    local Save = require 'src/story/Save'
    local nxt = require('src/Difficulty').UNLOCKS[difficulty or '']
    if not nxt then return nil end
    local g = Save.global()
    if g.unlocked[nxt] then return nil end
    g.unlocked[nxt] = true
    g.cleared = type(g.cleared) == 'table' and g.cleared or {}
    g.cleared[difficulty] = true
    Save.writeGlobal(g)
    return nxt
end

-- Nota de un mundo: la media de la mejor valoración de cada nivel suyo (los no superados, 0)
function Run.worldRating(w)
    local Score = require 'src/story/Score'
    local list, nodes = {}, Worlds.nodes(w)
    for _, n in ipairs(nodes) do
        local b = Run.data and Run.data.best[n.id]
        if b and b.rating and Run.isDone(n.id) then list[#list + 1] = b.rating end
    end
    return Score.average(list, #nodes)
end

-- FRAGMENTOS DEL ESPEJO (src/story/Shards.lua): quedan en la partida al TERMINAR el nivel en que se recogieron
-- (StoryMapState: salir a medias no guarda nada de lo conseguido)
function Run.addShard(id)
    local d = Run.data
    if not d then return end
    d.shards = d.shards or {}
    d.shards[id] = true
    Run.save()
end
function Run.shards() return require('src/story/Shards').count(Run.data or { shards = {} }) end

-- Vidas con las que sigue la aventura (al salir de un nivel sin acabarlo también cuentan las perdidas)
function Run.setLives(n)
    if not Run.data then return end
    Run.data.lives = math.max(1, math.floor(n))
    Run.save()
end

-- GAME OVER (sin vidas): se vuelve al PRINCIPIO DEL MUNDO `w` — sus niveles dejan de estar superados
-- y las vidas vuelven a las del principio. En las dificultades con `restartGame` (Xtra extremo) se
-- pierde TODO: de vuelta al mundo 1. Los récords (`best`) se conservan. Devuelve el mundo al que se va.
function Run.gameOver(w)
    local d = Run.data
    if not d then return 1 end
    local Difficulty = require 'src/Difficulty'
    d.lives = Difficulty.of(d.difficulty, 'livesStart', 3)
    d.gameOvers = (d.gameOvers or 0) + 1
    if Difficulty.of(d.difficulty, 'restartGame', false) then
        d.done, d.shards, w = {}, {}, 1          -- (todo el juego otra vez: también los fragmentos)
    else
        for _, n in ipairs(Worlds.nodes(w)) do d.done[n.id] = nil end
    end
    d.world, d.node = w, 1
    Run.save()
    return w
end

return Run
