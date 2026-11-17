-- src/world/systems/StompChain.lua
-- LA RACHA DE PISOTONES (0.5.220; el usuario: como en los plataformas clásicos, encadenar pisotones sin tocar el suelo
-- da cada vez más puntos y, al final, vidas). Cada pisotón a un enemigo que da puntos sin tocar el suelo desde el
-- anterior multiplica SUS puntos por MULTS[n] (×1, ×2, ×4… ×64); del pisotón #MULTS + 1 en adelante da UNA VIDA en vez
-- de puntos. Los jefes (y lo que no da puntos) ni cuentan ni la cortan; tocar el suelo, el agua, morir o un golpe la
-- cortan. Sin dibujo: lo comparten un jugador y el servidor (cada uno pone sus puntos, su vida y su aviso).
--   StompChain.award(pa, e, pts) → puntos que da, el multiplicador, true si da una vida (puntos 0)
--   StompChain.update(pa)        cada paso del jugador (la corta en el suelo, en el agua o muriendo)
--   StompChain.reset(pa)         (un golpe)
--   StompChain.pitch(pa)         tono del sonido del pisotón que va a caer (0.5.235, el usuario: que se oiga la escalerita)
--   StompChain.step(n, pts)      la regla sola: el n.º `n` de una racha → puntos, multiplicador, true si da una vida
--   StompChain.pitchOf(n)        el tono del n.º `n` (la escalerita) — los usa también la racha de la META (WinCelebration) —
local StompChain = {}

StompChain.MULTS = { 1, 2, 4, 8, 16, 32, 64 }
-- LA ESCALERITA: cada pisotón de la racha sube un grado de la escala mayor (semitonos sobre el tono normal); el que da
-- la vida cae en la octava y los siguientes se quedan arriba
StompChain.SCALE = { 0, 2, 4, 5, 7, 9, 11, 12 }

function StompChain.award(pa, e, pts)
    pts = pts or 0
    if pts <= 0 or (e and e.def and e.def.boss) then return pts, 1, false end
    local n = (pa.stompChain or 0) + 1
    pa.stompChain = n
    return StompChain.step(n, pts)
end

function StompChain.step(n, pts)
    local m = StompChain.MULTS[n]
    if not m then return 0, nil, true end
    return (pts or 0) * m, m, false
end

function StompChain.update(pa)
    if pa.onGround or pa.inWater or pa.dying then pa.stompChain = 0 end
end

function StompChain.reset(pa) pa.stompChain = 0 end

-- (antes de award: el pisotón que suena es el n.º stompChain + 1; sin jugador, el tono normal)
function StompChain.pitch(pa) return StompChain.pitchOf(((pa and pa.stompChain) or 0) + 1) end

function StompChain.pitchOf(n)
    local sc = StompChain.SCALE
    return 2 ^ (sc[math.max(1, math.min(n, #sc))] / 12)
end

return StompChain
