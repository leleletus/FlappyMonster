-- src/player/PlayerSprite.lua
-- El SPRITE DEL MONSTRUO, para todo lo que lo dibuja (el jugador, los jugadores online, el modo Flappy, el Espejo y
-- el Espejo perseguidor): sus animaciones salen del conjunto `player` (assets/anim/player.json, `love . --anim`) y se
-- piden POR NOMBRE. La simulación y la red llevan la POSE como un número (PlayerAdventure.frame: 1, 2, 3, 5), que
-- aquí se traduce a su animación:
--   1 `glide` (brazos arriba) · 2 `jump` (aleteo) · 3 `idle` · 4 `dead` · 5 `crouch`
-- y además `fall` (cayendo: brazos arriba / abajo), `flutter` (aleteo seguido), `dead_eyes` (los ojos en X) e `icon`.
--   local f = PlayerSprite.rec(pose o nombre [, t])   → el cuadro que toca (image, quad, w, h…)
--   PlayerSprite.draw(f, x, y, r, sx, sy, ox, oy)       como love.graphics.draw (ancla en píxeles del cuadro)
local Anim = require 'src/fx/Anim'

local PS = { SET = 'player', POSES = { 'glide', 'jump', 'idle', 'dead', 'crouch' } }

function PS.clip(pose)
    return Anim.clip(PS.SET, PS.POSES[pose] or pose) or Anim.clip(PS.SET, 'idle')
end
function PS.rec(pose, t)
    local c = PS.clip(pose)
    return c:rec(c:at(t or love.timer.getTime()))
end
function PS.draw(f, x, y, r, sx, sy, ox, oy)
    if not (f and f.image) then return end
    love.graphics.draw(f.image, f.quad, x, y, r or 0, sx or 1, sy or sx or 1, ox or 0, oy or 0)
end

return PS
