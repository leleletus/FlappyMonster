-- src/fx/NoiseMarks.lua
-- MARCAS DE RUIDO (niveles a oscuras): donde algo hace un ruido que los lúgubres oyen aparece un
-- "!" rojo un momento, con un aro que crece hasta donde se oye. Es la regla del nivel hecha
-- visible: hacer ruido → marca → ahí van a mirar. Solo dibujo; las suelta Noise.emit como fx
-- ('noise_s' salto · 'noise_m' golpe / enemigo muerto / bloque roto · 'noise_l' ground pound),
-- Particles.emit las trae aquí (un jugador y online) y Darkness.renderGlow las dibuja ENCIMA de la
-- oscuridad. Imagen: assets/images/fx/noise_mark.png (tools/ui/make_gloomy_sprites.py).
local NoiseMarks = {}

local T = TILE_PX
local LIFE, RING_T = 1.5, 0.45
local KIND = { noise_s = { r = 3.5, s = 3 }, noise_m = { r = 9, s = 4 }, noise_l = { r = 15, s = 5 } }
local list, img = {}, nil

function NoiseMarks.is(kind) return KIND[kind] ~= nil end
function NoiseMarks.clear() list = {} end

function NoiseMarks.add(kind, x, y)
    local k = KIND[kind]
    if not k then return end
    list[#list + 1] = { x = x, y = y, r = k.r * T, s = k.s, at = love.timer.getTime() }
    if #list > 16 then table.remove(list, 1) end
end

function NoiseMarks.render(camX, camY)
    if not list[1] then return end
    img = img or love.graphics.newImage('assets/images/fx/noise_mark.png')
    img:setFilter('nearest', 'nearest')
    local now = love.timer.getTime()
    for i = #list, 1, -1 do
        local m = list[i]
        local t = now - m.at
        if t >= LIFE then
            table.remove(list, i)
        else
            local a = math.min(1, (LIFE - t) / 0.4)
            local x, y = math.floor(m.x - camX), math.floor(m.y - camY)
            if t < RING_T then                                   -- el aro: hasta dónde se oye
                love.graphics.setColor(1, 0.25, 0.2, 0.55 * (1 - t / RING_T))
                love.graphics.setLineWidth(3)
                love.graphics.setLineStyle('rough')
                love.graphics.circle('line', x, y, 12 + (m.r - 12) * (t / RING_T), 40)
                love.graphics.setLineWidth(1)
            end
            local pop = 1 + 0.35 * math.max(0, 1 - t / 0.12)     -- (salta al aparecer)
            love.graphics.setColor(1, 0.22, 0.18, a)
            love.graphics.draw(img, x, y - 30 - math.floor(math.min(1, t / 0.2) * 10), 0, m.s * pop, m.s * pop,
                               img:getWidth() / 2, img:getHeight())
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return NoiseMarks
