-- src/world/Explosions.lua
-- Explosiones (bombas; más adelante, las que lance un jefe). UNA función con
-- todo el efecto, autoritativa: la llaman el modo un jugador y el servidor
-- (los clientes online ven el resultado: jugadores corregidos por su estado,
-- tiles por eventos 'tile', entidades por snapshots, fx y sonidos por eventos).
--
-- Radios (en casillas, desde el centro de la explosión hasta lo más cercano de
-- cada cosa; la fuerza baja con la distancia):
--   kill  jugador: muere al instante · enemigos: fuera (salen despedidos girando)
--   hurt  jugador: -1 vida + empujón fuerte · enemigos: fuera ·
--         bloques rompibles: se rompen · activadores ON/OFF: cambian
--   push  jugador: solo un empujón (más flojo cuanto más lejos) ·
--         enemigos: empujados y aturdidos
--   más lejos: nada
-- Otras bombas dentro de `push`: se encienden (mecha corta) → reacción en cadena.
-- La invulnerabilidad del jugador (tras un golpe o al reaparecer) lo protege
-- como de todo lo demás.
--
--   Explosions.blast(level, x, y, radii, source)   radii = { kill, hurt, push } (casillas)

local Explosions = {}

Explosions.DEFAULT = { kill = 1.2, hurt = 2.3, push = 3.6 }

local PUSH_VX, PUSH_VY = { 300, 680 }, { 240, 560 }    -- empujón: de lejos / de cerca

-- Distancia del punto (x, y) a una caja
local function boxDist(x, y, b)
    local dx = math.max(b.x - x, 0, x - (b.x + b.w))
    local dy = math.max(b.y - y, 0, y - (b.y + b.h))
    return math.sqrt(dx * dx + dy * dy)
end
Explosions.boxDist = boxDist

-- Empuja al jugador lejos de la explosión (k = 0 lejos .. 1 cerca)
local function pushPlayer(pa, x, y, k)
    if pa.dying or pa:isPushProtected() then return end
    local dir = (pa.x >= x) and 1 or -1
    pa:launch(dir * (PUSH_VX[1] + (PUSH_VX[2] - PUSH_VX[1]) * k),
              -(PUSH_VY[1] + (PUSH_VY[2] - PUSH_VY[1]) * k))
end

function Explosions.blast(level, x, y, radii, source)
    local T = TILE_PX
    radii = radii or Explosions.DEFAULT
    local killR = (radii.kill or Explosions.DEFAULT.kill) * T
    local hurtR = (radii.hurt or Explosions.DEFAULT.hurt) * T
    local pushR = (radii.push or Explosions.DEFAULT.push) * T
    local PA = require 'src/entities/PlayerAdventure'

    -- Jugadores
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = boxDist(x, y, pa:getOuterBounds())
            local k = 1 - math.min(1, d / pushR)
            if d <= killR then
                PA.asOwner(pa, function() pa:die() end)
            elseif d <= hurtR then
                PA.asOwner(pa, function() pa:hurt(1) end)
                pushPlayer(pa, x, y, k)
            elseif d <= pushR then
                pushPlayer(pa, x, y, k)
            end
        end
    end

    -- Entidades: bombas (se encienden), enemigos (fuera / aturdidos)
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= source and e.alive and not (e.isGhost and e:isGhost()) then
            local d = boxDist(x, y, e:getOuterBounds())
            local dir = (e.x >= x) and 1 or -1
            if e.onBlast then
                if d <= pushR then e:onBlast(x, y, d, pushR) end
            elseif e.def and e.def.category == 'Enemigos' and not e.def.boss and e.state ~= 'dead' then
                if d <= hurtR and e.dieFling then
                    e:dieFling(dir)
                elseif d <= pushR and e:canBeKnocked() then
                    e:knockback(dir)
                end
            end
        end
    end

    -- Bloques: los rompibles se rompen y los activadores ON/OFF cambian (una vez)
    local c0, c1 = math.floor((x - hurtR) / T) + 1, math.floor((x + hurtR) / T) + 1
    local r0, r1 = math.floor((y - hurtR) / T) + 1, math.floor((y + hurtR) / T) + 1
    for r = r0, r1 do
        for c = c0, c1 do
            local cx, cy = (c - 0.5) * T, (r - 0.5) * T
            if math.sqrt((cx - x) ^ 2 + (cy - y) ^ 2) <= hurtR then
                local def = level:getDef(c, r)
                if def.thinIce then
                    level:crackIce(c, r, 4, 'blast')                 -- (el hielo fino se rompe)
                elseif def.breakable then
                    if level:breakTile(c, r) then
                        local Entity = require 'src/world/entities/Entity'
                        Entity.emitFx('block_break', (c - 1) * T, (r - 1) * T)
                    end
                elseif def.toggle then
                    if level:hitTile(c, r, 'pound') == 'toggle' then
                        local Entity = require 'src/world/entities/Entity'
                        Entity.emitFx('switch_hit', (c - 1) * T, (r - 1) * T)
                        Sound.play(level:getDef(c, r).name == 'switch_on' and 'switchOn' or 'switchOff')
                    end
                end
            end
        end
    end
end

return Explosions
