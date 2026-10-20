-- src/ui/menu/Transition.lua
-- TRANSICIÓN DE PANTALLA de los menús al juego (y entre pantallas que no comparten el fondo vivo): una rejilla de
-- bloques de color que crecen en diagonal hasta tapar la pantalla, el cambio de estado, y los bloques que se
-- encogen para destapar la nueva (docs/architecture/menus.md). Mientras tapa, el estado de debajo no se actualiza (no se
-- puede pulsar nada dos veces); mientras destapa, el nuevo ya va (sus animaciones de entrada se ven debajo).
--   Transition.go(estado, args)       en vez de gStateMachine:change(estado, args)
--   Transition.update(dt) / Transition.render() / Transition.blocking()   (game.lua)
local Transition = {}

Transition.COVER = 0.32         -- s en tapar
Transition.REVEAL = 0.34        -- s en destapar
Transition.CELL = 48            -- px de cada bloque
Transition.COLOR = { 0.08, 0.09, 0.2 }

local phase, t, target = nil, 0, nil

function Transition.go(name, args)
    if phase == 'cover' then return end
    phase, t, target = 'cover', 0, { name, args }
end

function Transition.active() return phase ~= nil end
function Transition.blocking() return phase == 'cover' end

function Transition.update(dt)
    if not phase then return end
    t = t + dt
    if phase == 'cover' and t >= Transition.COVER then
        local tg = target
        phase, t, target = 'reveal', 0, nil
        gStateMachine:change(tg[1], tg[2])
    elseif phase == 'reveal' and t >= Transition.REVEAL then
        phase = nil
    end
end

-- Cuánto tapa (0..1) cada bloque: la onda va en diagonal desde arriba a la izquierda
local function amount(k, c, r, cols, rows)
    local d = (c + r) / (cols + rows)
    local v = (k * 1.7 - d * 0.7)
    return v < 0 and 0 or (v > 1 and 1 or v)
end

function Transition.render()
    if not phase then return end
    local k = phase == 'cover' and t / Transition.COVER or 1 - t / Transition.REVEAL
    k = math.max(0, math.min(1, k))
    local C = Transition.CELL
    local cols, rows = math.ceil(WINDOW_W / C), math.ceil(WINDOW_H / C)
    local col = Transition.COLOR
    love.graphics.setColor(col[1], col[2], col[3], 1)
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local a = amount(k, c, r, cols, rows)
            if a > 0 then
                -- (a saltos de 4 px: bloques de píxel, sin tamaños con decimales)
                local s = math.floor(C * a / 4 + 0.5) * 4
                if s > 0 then
                    local o = math.floor((C - s) / 2)
                    love.graphics.rectangle('fill', c * C + o, r * C + o, s, s)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Transition
