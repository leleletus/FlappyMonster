-- src/player/PlayerSprite.lua
-- El SPRITE DEL MONSTRUO, para todo lo que lo dibuja (el jugador, los jugadores online, el modo Flappy, el Espejo y
-- el Espejo perseguidor): sus animaciones salen del conjunto `player` (assets/anim/player.json, `love . --anim`) y se
-- piden POR NOMBRE. La simulación y la red llevan la POSE como un número (PlayerAdventure.frame), que aquí se traduce a
-- su animación:
--   1 `glide` (brazos arriba) · 2 `jump` (aleteo) · 3 `idle` · 4 `dead` · 5 `crouch`
--   (0.5.190, las POSES DE ACCIÓN — tools/art/player/make_monster_actions.py, assets/images/player/actions/ —)
--   6 aterrizar fuerte · 7 ground pound (encogido, al empezar; luego, el salto de siempre) · 8 lanzar · 9 empujar ·
--   10 mirar arriba · 11 agachado mirando abajo · 12 quieto mucho rato · 13 victoria
--   (el derrape y el dolor se quitaron: el usuario, «no terminan de quedar bien»)
-- y además `fall` (cayendo: brazos arriba / abajo), `flutter` (aleteo seguido), `dead_eyes` (los ojos en X) e `icon`.
--   local f = PlayerSprite.rec(pose o nombre [, t])   → el cuadro que toca (image, quad, w, h…)
--   local f = PlayerSprite.recOf(obj, pose)           → lo mismo, contando el tiempo desde que `obj` cambió de pose (las
--                                                       de una sola vez — aterrizar, dolor, victoria — empiezan por su
--                                                       primer cuadro; cada objeto lleva su cuenta: el jugador, los
--                                                       jugadores online, el Espejo, los actores)
--   PlayerSprite.draw(f, x, y, r, sx, sy, ox, oy)       como love.graphics.draw (ancla en píxeles del cuadro); si el cuadro
--                                                       lleva OJOS (`eye`, `ex`, `ey`, `esep` en su JSON: las poses de
--                                                       acción tienen la cara lisa), los pinta encima
local Anim = require 'src/fx/Anim'

local PS = { SET = 'player', POSES = { 'glide', 'jump', 'idle', 'dead', 'crouch',
    'act_land', 'act_gp_curl', 'act_throw', 'act_push', 'act_look_up', 'act_crouch_look_down',
    'act_idle_long', 'act_victory' } }
PS.LAND, PS.GP_CURL, PS.THROW, PS.PUSH = 6, 7, 8, 9
PS.LOOK_UP, PS.CROUCH_LOOK_DOWN, PS.IDLE_LONG, PS.VICTORY = 10, 11, 12, 13

function PS.clip(pose)
    return Anim.clip(PS.SET, PS.POSES[pose] or pose) or Anim.clip(PS.SET, 'idle')
end
function PS.rec(pose, t)
    local c = PS.clip(pose)
    return c:rec(c:at(t or love.timer.getTime()))
end
function PS.recOf(obj, pose)
    local now = love.timer.getTime()
    if obj._psPose ~= pose then obj._psPose, obj._psT0 = pose, now end
    local c = PS.clip(pose)
    if c.seq.loop then return c:rec(c:at(now)) end
    return c:rec(c:at(now - obj._psT0))
end

-- ── Los OJOS de quita y pon (como DeadEyes y los de risa del Espejo): imágenes de assets/images/player/actions/eyes/ a
-- medio píxel del sprite, SIMÉTRICOS por construcción — el derecho es el reflejo exacto del izquierdo alrededor del
-- centro del par, en píxeles de pantalla; `hurt` (> <) se voltea para el de la derecha —
local eyeImgs, MIRRORED = {}, { hurt = true }
local function eyeImg(name)
    local im = eyeImgs[name]
    if im == nil then
        local ok, res = pcall(love.graphics.newImage, 'assets/images/player/actions/eyes/' .. name .. '.png')
        im = ok and res or false
        if im then im:setFilter('nearest', 'nearest') end
        eyeImgs[name] = im
    end
    return im or nil
end
function PS.drawEyes(f, x, y, r, sx, sy, ox, oy)
    local d = f and f.data
    if not (d and d.eye) or (r or 0) ~= 0 then return end        -- (girado no lleva ojos: ninguna pose de acción gira)
    local img = eyeImg(d.eye)
    if not img then return end
    sx, sy = sx or 1, sy or sx or 1
    local cell = math.max(1, math.floor(math.abs(sy) / 2 + 0.5))
    local c = math.floor(x + (d.ex - (ox or 0)) * sx + 0.5)        -- (centro del par, px de pantalla)
    local cy = math.floor(y + (d.ey - (oy or 0)) * sy + 0.5)
    local off = math.floor((d.esep or 1) * math.abs(sx) + 0.5)
    local w, h = img:getWidth() * cell, img:getHeight() * cell
    local lx, ty = c - off - math.floor(w / 2), cy - math.floor(h / 2)
    local rx = 2 * c - lx - w
    love.graphics.draw(img, lx, ty, 0, cell, cell)
    if MIRRORED[d.eye] then love.graphics.draw(img, rx + w, ty, 0, -cell, cell)
    else love.graphics.draw(img, rx, ty, 0, cell, cell) end
end

function PS.draw(f, x, y, r, sx, sy, ox, oy)
    if not (f and f.image) then return end
    love.graphics.draw(f.image, f.quad, x, y, r or 0, sx or 1, sy or sx or 1, ox or 0, oy or 0)
    if f.data and f.data.eye then PS.drawEyes(f, x, y, r, sx, sy, ox, oy) end
end

return PS
