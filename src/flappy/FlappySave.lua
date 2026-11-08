-- src/flappy/FlappySave.lua
-- PARTIDAS de la campaña Flappy: 3 huecos, SEPARADOS de los de Aventura (flappy1.sav, flappy2.sav, flappy3.sav; los de
-- la historia son story<n>.sav — src/story/Save.lua —). Cada una con su dificultad (Fácil, Normal o Difícil), sus vidas
-- y lo que lleva superado. Los campos `world` / `node` son los de RunCore (aquí: la zona y la etapa).
local SaveFile = require 'src/core/SaveFile'
local Difficulty = require 'src/core/Difficulty'

local FlappySave = { SLOTS = 3, VERSION = 1, DIFFICULTIES = { 'easy', 'normal', 'hard' } }

function FlappySave.file(i) return 'flappy' .. i .. '.sav' end

-- Una partida nueva (sin guardar todavía)
function FlappySave.new(difficulty)
    difficulty = difficulty or 'normal'
    return { version = FlappySave.VERSION, difficulty = difficulty, world = 1, node = 1,
             lives = Difficulty.of(difficulty, 'livesStart', 3),
             done = {}, best = {}, playTime = 0, points = 0, gameOvers = 0 }
end

function FlappySave.load(i)
    local d = SaveFile.read(FlappySave.file(i))
    if not d or type(d.done) ~= 'table' then return nil end
    d.best = type(d.best) == 'table' and d.best or {}
    d.difficulty = type(d.difficulty) == 'string' and d.difficulty or 'normal'
    d.lives = tonumber(d.lives) or 3
    d.world, d.node = tonumber(d.world) or 1, tonumber(d.node) or 1
    d.playTime = tonumber(d.playTime) or 0
    d.points = tonumber(d.points) or 0
    d.gameOvers = tonumber(d.gameOvers) or 0
    return d
end

function FlappySave.write(i, d) return SaveFile.write(FlappySave.file(i), d) end
function FlappySave.delete(i) SaveFile.remove(FlappySave.file(i)) end
function FlappySave.modtime(i) return SaveFile.modtime(FlappySave.file(i)) end

return FlappySave
