-- src/world/level/Scenes.lua
-- ESCENAS: partes de un nivel con su propio cielo y su propia luz. Un nivel normal tiene UN fondo, una hora, una luz,
-- oscuridad, nieve, eco y pinchos para todo él; un nivel con `scenes` (JSON) los cambia según la escena activa — el
-- Mega Mashup de los Cangrejos (docs/bosses/crab-mashup.md) cose las arenas de cuatro jefes (costa, glaciar, cueva a
-- oscuras, playa de noche) y un escenario en un solo nivel y pasa de una a otra.
--   "scenes": [ { "col": 1, "w": 30, "background": "coast", "time": "night", "light": "...", "dark": true,
--                 "snow": true, "echo": false, "spikeSkin": "ice", "clouds": ..., "depth": ..., "surfaceRow": 12 }, … ]
-- Lo que una escena no dice, lo toma del nivel. Quién cambia de escena: el juego (Level:applyScene(i), lo llama el
-- director del evento en un jugador y en el servidor; el cliente online la aplica al llegarle en la instantánea).
-- Todo lo que lo dibuja (Sky, Darkness, Snowfall, pinchos…) lee los campos del nivel en cada fotograma: basta con
-- cambiarlos. El ECO lo pone el estado (Sound no se toca desde la simulación).
local Scenes = {}

Scenes.FIELDS = { 'background', 'timeOfDay', 'clouds', 'light', 'dark', 'snow', 'echo', 'spikeSkin', 'depth', 'surfaceRow' }
local JSON_KEY = { timeOfDay = 'time' }

-- Lo que el nivel cargó (lvl = su JSON) + sus escenas normalizadas
function Scenes.build(level, lvl)
    level.scenes = nil
    if type(lvl.scenes) ~= 'table' or #lvl.scenes == 0 then return end
    local Level = require 'src/world/level/Level'
    local base = {}
    for _, f in ipairs(Scenes.FIELDS) do base[f] = level[f] end
    level.baseScene = base
    level.scenes = {}
    for i, s in ipairs(lvl.scenes) do
        if type(s) == 'table' then
            local sc = { col = tonumber(s.col) or 1, w = tonumber(s.w) or level.tileW }
            for _, f in ipairs(Scenes.FIELDS) do
                local v = s[JSON_KEY[f] or f]
                if v == nil then v = base[f] end
                sc[f] = v
            end
            -- (la luz ambiente sale como la del nivel: de "light", si no de la hora y el fondo — Level.lightMood)
            sc.light = Level.lightMood({ light = s.light or lvl.light, time = s.time or lvl.time,
                                         background = s.background or lvl.background, dark = sc.dark })
            if s.echo == nil then sc.echo = sc.dark == true or sc.light == 'cave' end
            level.scenes[i] = sc
        end
    end
    level.sceneIdx = nil
end

-- Pone la escena i (nil = la del nivel)
function Scenes.apply(level, i)
    local sc = (i and level.scenes and level.scenes[i]) or level.baseScene
    if not sc or level.sceneIdx == i then return end
    for _, f in ipairs(Scenes.FIELDS) do level[f] = sc[f] end
    level.sceneIdx = i
    level.darkness = sc.dark and 1 or 0
end

-- Escena que contiene la columna `col` (o nil)
function Scenes.at(level, col)
    for i, sc in ipairs(level.scenes or {}) do
        if col >= sc.col and col < sc.col + sc.w then return i end
    end
    return nil
end

return Scenes
