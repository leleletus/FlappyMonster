-- src/world/systems/StompChain.lua
-- LA RACHA DE PISOTONES (0.5.220; el usuario: como en los plataformas clásicos, encadenar pisotones sin tocar el suelo
-- da cada vez más puntos y, al final, vidas). Cada pisotón a un enemigo que da puntos sin tocar el suelo desde el
-- anterior multiplica SUS puntos por MULTS[n] (×1, ×2, ×4… ×64); del pisotón #MULTS + 1 en adelante da UNA VIDA en vez
-- de puntos. Los jefes (y lo que no da puntos) ni cuentan ni la cortan; tocar el suelo, el agua, morir o un golpe la
-- cortan. Sin dibujo: lo comparten un jugador y el servidor (cada uno pone sus puntos, su vida y su aviso).
--   StompChain.award(pa, e, pts) → puntos que da, el multiplicador, true si da una vida (puntos 0)
--   StompChain.update(pa)        cada paso del jugador (la corta en el suelo, en el agua o muriendo)
--   StompChain.reset(pa)         (un golpe)
local StompChain = {}

StompChain.MULTS = { 1, 2, 4, 8, 16, 32, 64 }

function StompChain.award(pa, e, pts)
    pts = pts or 0
    if pts <= 0 or (e and e.def and e.def.boss) then return pts, 1, false end
    local n = (pa.stompChain or 0) + 1
    pa.stompChain = n
    local m = StompChain.MULTS[n]
    if not m then return 0, nil, true end
    return pts * m, m, false
end

function StompChain.update(pa)
    if pa.onGround or pa.inWater or pa.dying then pa.stompChain = 0 end
end

function StompChain.reset(pa) pa.stompChain = 0 end

return StompChain
