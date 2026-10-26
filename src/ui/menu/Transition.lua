-- src/ui/menu/Transition.lua
-- TRANSICIÓN DE PANTALLA de los menús al juego (y entre pantallas que no comparten el fondo vivo): un IRIS de
-- píxeles (docs/architecture/menus.md) — un círculo que se cierra sobre un punto, un instante a oscuras, el cambio
-- de estado, y se vuelve a abrir. El borde va a escalones de IRIS_PX px (pixel art, sin bordes suaves). Mientras
-- tapa, el estado de debajo no se actualiza (no se puede pulsar nada dos veces); mientras abre, el nuevo ya va (sus
-- animaciones de entrada se ven debajo). (El fondo vivo usa el mismo iris al pasar de un nivel a otro: drawIris.)
--   Transition.go(estado, args[, x, y[, opts]])   en vez de gStateMachine:change(estado, args); x, y = dónde se cierra
--     opts.style = 'level' (entrar a un nivel desde el mapa del mundo): el iris se cierra más despacio sobre el
--     monstruo, la pantalla se funde a NEGRO y el nivel aparece con un fundido desde negro (sin iris que se abre)
--   Transition.update(dt) / Transition.render() / Transition.blocking()   (game.lua)
--   Transition.drawIris(k, x, y)          k = 0 cerrado del todo … 1 abierto del todo (nada que dibujar)
local Transition = {}

Transition.COVER = 0.42         -- s en cerrarse
Transition.HOLD = 0.08          -- s a oscuras
Transition.REVEAL = 0.46        -- s en abrirse
Transition.IRIS_PX = 8          -- px (lógicos) de cada escalón del borde
Transition.COLOR = { 0.05, 0.06, 0.13 }
Transition.LEVEL = { COVER = 0.6, HOLD = 0.4, REVEAL = 0.5 }     -- s de cada fase con el estilo 'level'

local phase, t, target = nil, 0, nil
local cx, cy, style

function Transition.go(name, args, x, y, opts)
    if phase == 'cover' or phase == 'hold' then return end
    phase, t, target = 'cover', 0, { name, args }
    cx, cy = x, y
    style = opts and opts.style or nil
end

-- Duración de una fase ('COVER' / 'HOLD' / 'REVEAL') con el estilo actual
local function dur(k) return (style == 'level' and Transition.LEVEL or Transition)[k] end

function Transition.active() return phase ~= nil end
function Transition.blocking() return phase == 'cover' or phase == 'hold' end

function Transition.update(dt)
    if not phase then return end
    t = t + dt
    if phase == 'cover' and t >= dur('COVER') then
        phase, t = 'hold', 0
    elseif phase == 'hold' and t >= dur('HOLD') then
        local tg = target
        phase, t, target = 'reveal', 0, nil
        cx, cy = nil, nil                          -- (se abre desde el centro de la pantalla nueva)
        gStateMachine:change(tg[1], tg[2])
    elseif phase == 'reveal' and t >= dur('REVEAL') then
        phase, style = nil, nil
    end
end

-- ── El iris ─────────────────────────────────────────────────────────────────
local irisShader
local function shader()
    if irisShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            extern vec2 center;     // en píxeles de pantalla
            extern number radius;
            extern number cell;
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
                vec2 p = (floor(sc / cell) + 0.5) * cell;           // a escalones: bloques de `cell` px
                if (distance(p, center) < radius) discard;
                return c;
            }
        ]])
        irisShader = ok and sh or false
    end
    return irisShader or nil
end

-- 0..1 → 0..1 suave al principio y al final
local function smooth(k) k = math.max(0, math.min(1, k)); return k * k * (3 - 2 * k) end

function Transition.drawIris(k, x, y)
    k = smooth(k)
    if k >= 1 then return end
    x, y = x or WINDOW_W / 2, y or WINDOW_H / 2
    local col = Transition.COLOR
    love.graphics.setColor(col[1], col[2], col[3], 1)
    local sh = shader()
    if not sh then
        -- (sin shaders: fundido)
        love.graphics.setColor(col[1], col[2], col[3], 1 - k)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    -- el radio que deja ver toda la pantalla desde (x, y): hasta la esquina más lejana
    local far = 0
    for _, p in ipairs({ { 0, 0 }, { WINDOW_W, 0 }, { 0, WINDOW_H }, { WINDOW_W, WINDOW_H } }) do
        far = math.max(far, math.sqrt((p[1] - x) ^ 2 + (p[2] - y) ^ 2))
    end
    -- (el shader trabaja en píxeles de la PANTALLA: se pasan el centro y los tamaños por la transformación actual)
    local sx, sy = love.graphics.transformPoint(x, y)
    local ox = love.graphics.transformPoint(0, 0)
    local scale = (love.graphics.transformPoint(1, 0)) - ox
    sh:send('center', { sx, sy })                     -- (LÖVE da `sc` con el origen arriba a la izquierda)
    sh:send('radius', far * k * scale)
    sh:send('cell', math.max(1, math.floor(Transition.IRIS_PX * scale + 0.5)))
    love.graphics.setShader(sh)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function Transition.render()
    if not phase then return end
    if style == 'level' then
        local col = Transition.COLOR
        if phase == 'cover' then Transition.drawIris(1 - t / dur('COVER'), cx, cy)
        elseif phase == 'hold' then                                   -- (del color del iris a negro)
            local k = 1 - math.min(1, t / (dur('HOLD') * 0.7))
            love.graphics.setColor(col[1] * k, col[2] * k, col[3] * k, 1)
            love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        else                                                          -- (el nivel sale del negro)
            love.graphics.setColor(0, 0, 0, 1 - math.min(1, t / dur('REVEAL')))
            love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    if phase == 'cover' then Transition.drawIris(1 - t / Transition.COVER, cx, cy)
    elseif phase == 'hold' then Transition.drawIris(0, cx, cy)
    else Transition.drawIris(t / Transition.REVEAL, cx, cy) end
end

return Transition
