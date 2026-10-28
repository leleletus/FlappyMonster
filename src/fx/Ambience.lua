-- src/fx/Ambience.lua
-- AMBIENTE de fondo por ISLA (0.5.83: antes solo las cuevas, CaveAmbience): aunque el jugador esté quieto y no pase
-- nada, el sitio suena vivo. Flojo y espaciado (el silencio sigue mandando), cada vez con otro tono y volumen. Solo
-- sonido, en cada cliente (no es simulación ni ruido que oigan los enemigos).
--   · cueva (niveles con eco: level.echo, por defecto los que están a oscuras): gotas lejanas, alguna piedrecita que
--     rueda, un rumor grave de la roca — con el eco de la cueva (Sound.setEcho). Las gotas de las estalactitas que se
--     ven suenan aparte, donde caen (DecoFx.drip: 'dripFall' / 'dripSplash').
--   · jungla (la isla del nivel: src/world/level/Isles.lua): cigarras, pájaros, una rana, un mono aullador lejano,
--     hojas que se agitan.
--   Ambience.tick(level)   una vez por fotograma, desde el dibujo de los estados de nivel
-- Un ambiente nuevo = una entrada en SETS (cuándo suena + sus capas). Sonidos: assets/sounds/ambience/
-- (tools/sounds/ambience.py, tools/sounds/jungle.py).
local Isles = require 'src/world/level/Isles'

local Ambience = {}

local function rnd(a, b) return a + (b - a) * math.random() end

-- { sonido, cada [a, b] s, volumen [a, b], tono [a, b] }
Ambience.SETS = {
    {
        id = 'cave', when = function(level) return level.echo end,
        -- (flojos: es el FONDO, no algo que llame la atención; el usuario los pidió más bajos)
        layers = {
            { 'caveDrip',   2.5, 7,  0.04, 0.14, 0.8, 1.3 },
            { 'cavePebble', 14,  32, 0.04, 0.10, 0.8, 1.2 },
            { 'caveRumble', 24,  50, 0.08, 0.14, 0.85, 1.1 },
        },
    },
    {
        id = 'jungle', when = function(level) return Isles.of(level) == 'jungla' end,
        layers = {
            { 'jungleCicada',  5,  11, 0.08, 0.14, 0.9, 1.1 },
            { 'jungleWhistle', 6,  14, 0.06, 0.12, 0.9, 1.15 },
            { 'jungleTrill',   9,  18, 0.05, 0.10, 0.9, 1.1 },
            { 'jungleToucan',  12, 25, 0.06, 0.11, 0.9, 1.1 },
            { 'jungleFrog',    8,  16, 0.06, 0.11, 0.85, 1.15 },
            { 'jungleHowler',  25, 45, 0.08, 0.13, 0.9, 1.05 },
            { 'jungleRustle',  10, 20, 0.04, 0.08, 0.9, 1.2 },
        },
    },
}

local timers, forLevel, active = {}, nil, nil

function Ambience.tick(level)
    if not level or not Sound or not Sound.playAt then return end
    if forLevel ~= level then
        forLevel, active = level, nil
        for _, set in ipairs(Ambience.SETS) do
            if set.when(level) then active = set; break end                 -- (el primero que toca)
        end
        timers = {}
        for i, l in ipairs(active and active.layers or {}) do timers[i] = rnd(l[2], l[3]) * 0.6 end
    end
    if not active then return end
    local dt = math.min(0.1, love.timer.getDelta())
    for i, l in ipairs(active.layers) do
        timers[i] = timers[i] - dt
        if timers[i] <= 0 then
            timers[i] = rnd(l[2], l[3])
            Sound.playAt(l[1], nil, nil, rnd(l[6], l[7]), rnd(l[4], l[5]))
        end
    end
end

return Ambience
