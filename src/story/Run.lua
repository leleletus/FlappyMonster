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

function Run.complete(id, result)
    local d = Run.data
    if not d then return end
    d.done[id] = true
    result = result or {}
    if result.lives then d.lives = result.lives end      -- (las vidas se llevan al nivel siguiente)
    local b = d.best[id] or {}
    if result.score and result.score > (b.score or -1) then b.score = result.score end
    if result.time and (not b.time or result.time < b.time) then b.time = math.floor(result.time * 100) / 100 end
    d.best[id] = b
    d.playTime = d.playTime + (result.time or 0)
    Run.save()
end

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
        d.done, w = {}, 1
    else
        for _, n in ipairs(Worlds.nodes(w)) do d.done[n.id] = nil end
    end
    d.world, d.node = w, 1
    Run.save()
    return w
end

return Run
