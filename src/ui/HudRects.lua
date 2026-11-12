-- src/ui/HudRects.lua
-- DÓNDE ESTÁ CADA COSA DEL HUD en este fotograma (0.5.204, docs/design/ux-round-2026-11.md «HUD layout pass»: el
-- usuario vio la barra del jefe tapando los puntos y el aviso de la muerte pegado a ellos). Cada elemento del HUD apunta
-- aquí su rectángulo al dibujarse; los que van DEBAJO de otros (las barras de los jefes, las de vida, el HUD de Flappy,
-- el aviso de la muerte) se colocan con `below()`: justo bajo lo que ya hay, sin números fijos que se pisen al cambiar
-- el ancho de la pantalla o al juntarse varias cosas. El arnés tools/tests/hud_layout comprueba que nada se pisa.
--   HudRects.clear()                      al empezar el HUD de cada fotograma
--   HudRects.add(name, x, y, w, h)        lo que ocupa un elemento (devuelve y + h)
--   HudRects.below([gap])                 la primera y libre bajo todo lo apuntado (gap: el hueco, 10 por defecto)
--   HudRects.place(name, x, y, w, h)      lo apunta donde se pide o, si pisaría algo, más ABAJO (justo bajo lo que
--                                         pisaba); devuelve x, y donde quedó
--   HudRects.centerSpan([gap])            ancho libre centrado entre lo de la izquierda y lo de la derecha
--   HudRects.list()                       { { name, x, y, w, h }, ... } (las pruebas)
--   HudRects.overlaps()                   lo que se pisa o se sale en este fotograma (las pruebas)
local HudRects = {}

local list = {}

function HudRects.clear() for i = #list, 1, -1 do list[i] = nil end end

function HudRects.add(name, x, y, w, h)
    list[#list + 1] = { name = name, x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
    return y + h
end

-- (lo que va en la franja de ARRIBA y lo que se apila debajo: todo lo apuntado hasta ahora, salvo lo que va por la mitad
--  de la pantalla o abajo — carteles grandes, la cuenta atrás, el aire, la antena —)
local FLOATING = { banner = true, countdown = true, air = true, ping = true, intro = true,
                   notice = true, roomline = true, spectator = true }

function HudRects.below(gap)
    local y = 0
    for _, r in ipairs(list) do
        if not FLOATING[r.name] and r.y < WINDOW_H * 0.5 then y = math.max(y, r.y + r.h) end
    end
    return y + (gap or 10)
end

local function hits(x, y, w, h)
    local low
    for _, r in ipairs(list) do
        if not FLOATING[r.name] and x < r.x + r.w and r.x < x + w and y < r.y + r.h and r.y < y + h then
            low = math.max(low or 0, r.y + r.h)
        end
    end
    return low
end

function HudRects.place(name, x, y, w, h)
    for _ = 1, 20 do
        local low = hits(x, y, w, h)
        if not low then break end
        y = low + 10
    end
    HudRects.add(name, x, y, w, h)
    return x, y
end

-- El hueco libre CENTRADO de la franja de arriba: entre lo de la izquierda (puntos…) y lo de la derecha (vidas, pausa,
-- linterna) → ancho máximo de algo centrado que no los pise (la barra del jefe: se estrecha para caber)
function HudRects.centerSpan(gap)
    gap = gap or 16
    local half = WINDOW_W / 2
    for _, r in ipairs(list) do
        if not FLOATING[r.name] and r.y < WINDOW_H * 0.5 then
            if r.x + r.w / 2 < WINDOW_W / 2 then half = math.min(half, WINDOW_W / 2 - (r.x + r.w) - gap)
            else half = math.min(half, r.x - WINDOW_W / 2 - gap) end
        end
    end
    return math.max(0, 2 * half)
end

function HudRects.list() return list end

-- Lo que se pisa o se sale de la pantalla en este fotograma (las pruebas): { 'a pisa b', 'a fuera', ... }
function HudRects.overlaps()
    local out = {}
    for i = 1, #list do
        local a = list[i]
        if a.x < 0 or a.y < 0 or a.x + a.w > WINDOW_W or a.y + a.h > WINDOW_H then out[#out + 1] = a.name .. ' fuera' end
        for j = i + 1, #list do
            local b = list[j]
            if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
                out[#out + 1] = a.name .. ' pisa ' .. b.name
            end
        end
    end
    return out
end

return HudRects
