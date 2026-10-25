-- src/fx/StunRing.lua
-- El corro de estrellitas de "aturdido / noqueado", COMÚN a todo lo que lo dibuja (jefes: BossFx.stars; jugador,
-- jugadores remotos y el Espejo: PlayerAdventure.drawStunStars; entidades aturdidas: EntityTypes).
--
-- El corro da la vuelta a la cabeza en 3D: las estrellas que pasan por DETRÁS (la mitad de arriba de la elipse) se
-- dibujan ANTES del cuerpo, y las de DELANTE después. Dibujarlas todas encima del cuerpo, en una pasada, parecía un
-- halo plano (el usuario, 0.5.28). Quien dibuja hace dos llamadas: part = 'back' antes del cuerpo y 'front' después.
--
-- Las dos llamadas de un mismo cuadro usan el MISMO instante (`StunRing.now`): una estrella que cruza el borde entre
-- detrás y delante nunca sale dos veces ni se pierde. Solo dibujo (nada de esto viaja por la red).
local StunRing = {}

local _now, _real = 0, -1
function StunRing.now()
    local t = love.timer.getTime()
    if math.abs(t - _real) > 0.006 then _now = t end               -- (dentro del mismo cuadro: el mismo instante)
    _real = t
    return _now
end

-- ¿Pasa por detrás? (y < 0 = la mitad de arriba de la elipse, la lejana)
function StunRing.isBack(y) return y < 0 end

-- ¿Se dibuja en esta pasada? (part nil = todas)
function StunRing.wants(part, back)
    return part == nil or (part == 'back') == back
end

-- n estrellas repartidas que giran a `speed` rad/s: lista de { x = cos, y = sin (unitarios), back, i }, las de
-- detrás primero; solo las de la pasada `part`
function StunRing.points(n, speed, part)
    local now, out = StunRing.now(), {}
    for i = 0, n - 1 do
        local a = now * speed + i * (math.pi * 2 / n)
        local x, y = math.cos(a), math.sin(a)
        local back = StunRing.isBack(y)
        if StunRing.wants(part, back) then out[#out + 1] = { x = x, y = y, back = back, i = i } end
    end
    table.sort(out, function(p, q) return p.y < q.y end)
    return out
end

return StunRing
