-- src/story/Ghost.lua
-- CONTRARRELOJ CON FANTASMA (Juego Libre, pestaña CARRERAS; el usuario, 2026-11-02): mientras se juega un nivel de
-- carrera se graba al jugador (posición, cuadro y hacia dónde mira cada STEP s); al llegar a la meta, si es su mejor
-- tiempo, la grabación se guarda (ghosts/<nivel>.dat en la carpeta de guardado). La próxima vez su FANTASMA corre a la
-- vez: el mismo dibujo, medio transparente (OnlinePlayer como espectador), con el tiempo que hizo encima.
-- No es parte de la simulación: solo se dibuja (no choca ni cuenta para nada).
local Ghost = {}
Ghost.STEP = 1 / 20
local DIR = 'ghosts'

local function file(levelPath) return DIR .. '/' .. (levelPath:match('([^/]+)%.json$') or 'nivel') .. '.dat' end

local cache = {}            -- [levelPath] = datos | false (sin fantasma)
function Ghost.load(levelPath)
    if cache[levelPath] == nil then
        local ok, d = pcall(function() return love.filesystem.load(file(levelPath))() end)
        cache[levelPath] = (ok and type(d) == 'table' and type(d.d) == 'table' and type(d.time) == 'number') and d or false
    end
    return cache[levelPath] or nil
end
function Ghost.best(levelPath) local d = Ghost.load(levelPath); return d and d.time end

-- Grabar: una muestra cada STEP s
function Ghost.recorder() return { acc = Ghost.STEP, d = {} } end
function Ghost.record(rec, dt, pa)
    rec.acc = rec.acc + dt
    if rec.acc < Ghost.STEP then return end
    rec.acc = rec.acc - Ghost.STEP
    local d = rec.d
    d[#d + 1] = math.floor(pa.x + 0.5); d[#d + 1] = math.floor(pa.y + 0.5)
    d[#d + 1] = pa.frame or 3; d[#d + 1] = pa.facing or 1
end

-- Al llegar a la meta en `time` s: si mejora, se guarda. → true si es récord
function Ghost.finish(levelPath, time, rec)
    local best = Ghost.best(levelPath)
    if best and time >= best then return false end
    love.filesystem.createDirectory(DIR)
    local parts = {}
    for i, v in ipairs(rec.d) do parts[i] = tostring(v) end
    pcall(love.filesystem.write, file(levelPath), string.format('return { time = %.3f, step = %.4f, d = { %s } }\n',
        time, Ghost.STEP, table.concat(parts, ',')))
    cache[levelPath] = { time = time, step = Ghost.STEP, d = rec.d }
    return true
end

local function mmss(t) return string.format('%d:%05.2f', math.floor(t / 60), t % 60) end
Ghost.mmss = mmss

-- El fantasma para dibujar: drawer(t, camX, camY) lo pone donde iba a los `t` s
function Ghost.drawer(data)
    local OnlinePlayer = require 'src/player/OnlinePlayer'
    local L = require 'src/core/Lang'
    local op = OnlinePlayer:new('ghost', L('free.ghost', { t = mmss(data.time) }), { 0.75, 0.85, 1 })
    op.ghost = true
    local d, step = data.d, data.step or Ghost.STEP
    local n = math.floor(#d / 4)
    return function(t, camX, camY)
        if n == 0 then return end
        local k = math.min(n - 1, math.max(0, t / step))
        local i = math.floor(k)
        local f = k - i
        local a, b = i * 4, math.min(n - 1, i + 1) * 4
        op:applyData({ x = d[a + 1] + (d[b + 1] - d[a + 1]) * f, y = d[a + 2] + (d[b + 2] - d[a + 2]) * f,
                       frame = d[a + 3], facing = d[a + 4], isSpectator = true })
        op:render(camX, camY)
    end
end

return Ghost
