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

local Run = {}
-- (open, close, active, save, isDone, worldOpen, state, progress, frontier, setLives, worldRating, score, restartWorld:
--  las reglas compartidas con la campaña Flappy, src/story/RunCore.lua)
require('src/story/RunCore').install(Run, Save, Worlds)

-- Nivel superado: se apunta, se guardan las vidas, se calcula su NOTA (src/story/Score.lua) y se dan
-- los premios. Devuelve el resumen para la pantalla de resultados:
--   { rating, grade, parts, points (del nivel, ya con el × de la dificultad), record (mejor nota que la que ya tenía),
--     reward = { lives | points } | nil, world = { rating, grade, reward } | nil (si con él se completa el mundo) }
function Run.complete(id, result)
    local d = Run.data
    if not d then return nil end
    local Score = require 'src/story/Score'
    local out = Run.score(id, result)
    local first = out.first
    out.first = nil
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
    -- partidas: Difícil → Extremo, Extremo → Xtra extremo; src/core/Difficulty.lua UNLOCKS)
    local lastNodes = Worlds.nodes(Worlds.count())
    if lastNodes[#lastNodes] and lastNodes[#lastNodes].id == id then
        out.unlocked = Run.unlockAfter(d.difficulty)
    end
    Run.save()
    return out
end

-- BONUS (arena contra el bot): 'done' ganado · 'open' con el jefe del mundo vencido · 'locked'
function Run.bonusState(w)
    local W, b = Worlds.get(w), Worlds.bonus(w)
    if not (b and Run.data) then return 'locked' end
    if Run.data.bonus[b.id] and Run.data.bonus[b.id].won then return 'done' end
    return Run.isDone(W.boss) and 'open' or 'locked'
end

-- NIVEL SECRETO (Worlds `secrets`; `e` = su entrada o el id de su nivel): 'done' superado · 'open' con todo lo que
-- pide su entrada (la salida secreta usada — `found` —, los niveles de `after` superados, todos los coleccionables de su
-- tipo `collect`, la ESCENA del mapa que lo abre ya vista — `scene`: StoryMapScenes —) · 'locked' (y, cerrado, ni se ve
-- en el mapa). Superado una vez, ya no se cierra. `noScene`: sin contar la escena (¿le toca ya su escena?)
function Run.secretState(e, noScene)
    if type(e) == 'string' then e = Worlds.secretOf(e) end
    if not (e and Run.data) then return 'locked' end
    if Run.isDone(e.level) then return 'done' end
    if e.exit and not (Run.data.found and Run.data.found[e.level]) then return 'locked' end
    for _, id in ipairs(e.after or {}) do if not Run.isDone(id) then return 'locked' end end
    if e.collect and not require('src/story/Collect').hasAll(Run.data, e.collect) then return 'locked' end
    if e.scene and not noScene and not (Run.data.films and Run.data.films[e.scene]) then return 'locked' end
    return 'open'
end

-- SALIDA SECRETA usada (terminado el nivel `from` por ella): se apunta el secreto al que lleva (`found[nivel]`)
-- (noSave: el nivel terminado lo guarda todo junto en Run.complete)
function Run.findSecret(level, noSave)
    local d = Run.data
    if not d then return end
    d.found = d.found or {}
    d.found[level] = true
    if not noSave then Run.save() end
end

-- COLECCIONABLE ganado (src/story/Collect.lua): como los fragmentos, solo al TERMINAR el nivel. Un estado que ya
-- tuviera (p. ej. 'stolen') no se pisa
function Run.addCollect(id, noSave)
    local d = Run.data
    if not d then return end
    d.collect = d.collect or {}
    if d.collect[id] == nil or d.collect[id] == false then d.collect[id] = true end
    if not noSave then Run.save() end
end

-- Fin de una partida bonus: su NOTA (Score.bonus), sus puntos (solo si se gana, × la dificultad) y sus premios — la
-- PRIMERA victoria, y la primera vez que se gana con cada letra —. Devuelve el resumen para la pantalla de resultados:
--   { rating, grade, parts, points, record, won, rewards = { {lives|points}, ... } }
function Run.bonusResult(id, result)
    local d = Run.data
    if not d then return nil end
    local Score = require 'src/story/Score'
    local Difficulty = require 'src/core/Difficulty'
    local b = d.bonus[id] or {}
    local sc = Score.bonus(result)
    local out = { rating = sc.rating, grade = sc.grade, parts = sc.parts, won = result.won == true, rewards = {},
                  points = 0, record = b.rating ~= nil and sc.rating > b.rating }
    if result.won then
        out.points = math.floor((result.score or 0) * Difficulty.of(d.difficulty, 'scoreMult', 1) + 0.5)
        out.gain = math.max(0, out.points - (b.bestPts or 0))             -- (solo lo que mejora el récord)
        b.bestPts = math.max(b.bestPts or 0, out.points)
        d.points = (d.points or 0) + out.gain
        if not b.won then b.won = true; out.rewards[#out.rewards + 1] = Score.BONUS_WIN end
        local order = { S = 4, A = 3, B = 2, C = 1, D = 0 }
        if (order[sc.grade] or 0) > (order[b.wonGrade or ''] or -1) then
            b.wonGrade = sc.grade
            if Score.BONUS_GRADE_REWARD[sc.grade] then out.rewards[#out.rewards + 1] = Score.BONUS_GRADE_REWARD[sc.grade] end
        end
        for _, rw in ipairs(out.rewards) do
            if rw.lives then d.lives = math.min(99, d.lives + rw.lives) end
            if rw.points then d.points = d.points + rw.points end
        end
    end
    if sc.rating > (b.rating or -1) then b.rating, b.grade = sc.rating, sc.grade end
    b.best = math.max(b.best or 0, result.score or 0)
    b.played = (b.played or 0) + 1
    d.bonus[id] = b
    Run.save()
    return out
end

-- Desbloqueo por acabar el juego en `difficulty`: devuelve el id NUEVO desbloqueado (nil si ya lo estaba)
function Run.unlockAfter(difficulty)
    local Save = require 'src/story/Save'
    local nxt = require('src/core/Difficulty').UNLOCKS[difficulty or '']
    if not nxt then return nil end
    local g = Save.global()
    if g.unlocked[nxt] then return nil end
    g.unlocked[nxt] = true
    g.cleared = type(g.cleared) == 'table' and g.cleared or {}
    g.cleared[difficulty] = true
    Save.writeGlobal(g)
    return nxt
end

-- FRAGMENTOS DEL ESPEJO (src/story/Shards.lua): quedan en la partida al TERMINAR el nivel en que se recogieron
-- (StoryMapState: salir a medias no guarda nada de lo conseguido)
-- (noSave: el nivel terminado lo guarda todo junto en Run.complete — fragmento y nivel en UNA escritura)
function Run.addShard(id, noSave)
    local d = Run.data
    if not d then return end
    d.shards = d.shards or {}
    d.shards[id] = true
    if not noSave then Run.save() end
end
function Run.shards() return require('src/story/Shards').count(Run.data or { shards = {} }) end

-- GAME OVER (sin vidas): se vuelve al PRINCIPIO DEL MUNDO `w` — sus niveles dejan de estar superados
-- y las vidas vuelven a las del principio. En las dificultades con `restartGame` (Xtra extremo) se
-- pierde TODO: de vuelta al mundo 1. Los récords (`best`) se conservan. Devuelve el mundo al que se va.
function Run.gameOver(w)
    local d = Run.data
    if not d then return 1 end
    local Difficulty = require 'src/core/Difficulty'
    if not Difficulty.of(d.difficulty, 'restartGame', false) then return Run.restartWorld(w) end
    d.lives = Difficulty.of(d.difficulty, 'livesStart', 3)
    d.gameOvers = (d.gameOvers or 0) + 1
    d.done, d.shards, d.open = {}, {}, {}            -- (todo el juego otra vez: también los fragmentos,
    d.collect, d.found = {}, {}                       --  los coleccionables y las salidas secretas encontradas)
    d.world, d.node = 1, 1
    Run.save()
    return 1
end

return Run
