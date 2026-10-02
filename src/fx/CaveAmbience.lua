-- src/fx/CaveAmbience.lua
-- AMBIENTE de las cuevas (niveles con eco: level.echo, por defecto los que están a oscuras): aunque
-- el jugador esté quieto y no pase nada, la cueva suena viva — gotas lejanas, alguna piedrecita
-- que rueda, un rumor grave de la roca. Flojo y espaciado (el silencio sigue mandando), cada vez
-- con otro tono y volumen, y con el eco de la cueva (Sound.setEcho). Solo sonido, en cada cliente
-- (no es simulación ni ruido que oigan los enemigos). Las gotas de las estalactitas que se ven
-- suenan aparte, donde caen (DecoFx.drip: 'dripFall' / 'dripSplash').
--   CaveAmbience.tick(level)   una vez por fotograma, desde el dibujo de los estados de nivel
-- Sonidos: assets/sounds/ambience/ (tools/sounds/ambience.py).
local CaveAmbience = {}

-- { sonido, cada [a, b] s, volumen [a, b], tono [a, b] }
local LAYERS = {
    { 'caveDrip',   2.5, 7,  0.10, 0.32, 0.8, 1.3 },
    { 'cavePebble', 14,  32, 0.10, 0.22, 0.8, 1.2 },
    { 'caveRumble', 24,  50, 0.18, 0.3,  0.85, 1.1 },
}
local timers, forLevel = {}, nil

local function rnd(a, b) return a + (b - a) * math.random() end

function CaveAmbience.tick(level)
    if not level or not level.echo or not Sound or not Sound.playAt then return end
    if forLevel ~= level then
        forLevel = level
        for i, l in ipairs(LAYERS) do timers[i] = rnd(l[2], l[3]) * 0.6 end
    end
    local dt = math.min(0.1, love.timer.getDelta())
    for i, l in ipairs(LAYERS) do
        timers[i] = timers[i] - dt
        if timers[i] <= 0 then
            timers[i] = rnd(l[2], l[3])
            Sound.playAt(l[1], nil, nil, rnd(l[6], l[7]), rnd(l[4], l[5]))
        end
    end
end

return CaveAmbience
