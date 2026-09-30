-- src/ui/BossHud.lua
-- HUD de las peleas de jefe (pixel art): barra de vida del jefe arriba y
-- barras de vida de los jugadores (color de cada uno). Cada segmento es 1 HP:
-- rectángulos finos separados por un hueco, con borde negro, luz arriba y
-- sombra abajo como el resto de la interfaz.

local L = require 'src/Lang'
local utf8 = require 'utf8'

local BossHud = {}

local lost = setmetatable({}, { __mode = 'k' })   -- [clave] = { hp, t } para el destello al perder vida

local function shade(c, k) return math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k) end

-- Fila de segmentos. x, y: esquina; devuelve el ancho total.
local function segments(key, x, y, hp, hpMax, segW, segH, gap, col)
    x, y = math.floor(x), math.floor(y)
    local w = hpMax * segW + (hpMax - 1) * gap
    -- Marco: sombra, anillo claro (se ve sobre cualquier fondo) y fondo negro
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', x - 5 + 4, y - 5 + 4, w + 10, segH + 10)
    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.rectangle('fill', x - 5, y - 5, w + 10, segH + 10)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', x - 3, y - 3, w + 6, segH + 6)

    -- Destello blanco en los segmentos recién perdidos
    local st = key and lost[key]
    if key then
        if not st then st = { hp = hp, from = hp, t = 0 }; lost[key] = st end
        if hp < st.hp then st.from, st.t = st.hp, love.timer.getTime() end
        st.hp = hp
    end
    local flashing = st and (love.timer.getTime() - st.t) < 0.45
    local blink = math.floor(love.timer.getTime() * 16) % 2 == 0

    for i = 1, hpMax do
        local sx = x + (i - 1) * (segW + gap)
        if i <= hp then
            love.graphics.setColor(col[1], col[2], col[3], 1)
            love.graphics.rectangle('fill', sx, y, segW, segH)
            love.graphics.setColor(shade(col, 1.6)); love.graphics.rectangle('fill', sx, y, segW, 3)
            love.graphics.setColor(shade(col, 0.55)); love.graphics.rectangle('fill', sx, y + segH - 3, segW, 3)
        elseif flashing and i <= st.from and blink then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle('fill', sx, y, segW, segH)
        else
            love.graphics.setColor(0.16, 0.14, 0.18, 1)
            love.graphics.rectangle('fill', sx, y, segW, segH)
            love.graphics.setColor(0.24, 0.22, 0.27, 1)
            love.graphics.rectangle('fill', sx, y, segW, 2)
        end
    end
    return w
end

local function outlined(text, x, y, c, a)
    love.graphics.setColor(0, 0, 0, (a or 1) * 0.85)
    love.graphics.print(text, x + 2, y + 2)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
    love.graphics.print(text, x, y)
end

-- Barra del jefe centrada arriba. `boss` = entidad (hp, hpMax, title()).
-- appear: 0..1 animación de entrada (se llena de izquierda a derecha).
function BossHud.drawBoss(boss, y, appear)
    local hpMax = math.max(1, boss.hpMax or 1)
    local hp    = boss.hp or 0
    appear = appear or 1
    if appear < 1 then hp = math.min(hp, math.floor(hpMax * appear)) end
    local segW, gap, segH = 16, 4, 30
    local maxW = WINDOW_W * 0.7
    while hpMax * segW + (hpMax - 1) * gap > maxW and segW > 4 do
        segW = segW - 2; gap = math.max(2, gap - 1)
    end
    local w = hpMax * segW + (hpMax - 1) * gap
    local x = math.floor((WINDOW_W - w) / 2)
    love.graphics.setFont(FONT_MED)
    local title = boss.title and boss:title() or L('boss.default')
    outlined(title, math.floor(WINDOW_W / 2 - FONT_MED:getWidth(title) / 2), y, { 1, 0.35, 0.35 })
    segments(boss, x, y + 26, hp, hpMax, segW, segH, gap, { 0.92, 0.16, 0.22 })
    love.graphics.setColor(1, 1, 1, 1)
end

-- Barras de los jugadores: list = { {name, color, hp, hpMax, key, dead}, ... }
function BossHud.drawPlayers(list, x, y)
    love.graphics.setFont(FONT_MED)
    local nameW = 0
    for _, p in ipairs(list) do nameW = math.max(nameW, FONT_MED:getWidth(p.name or '')) end
    for i, p in ipairs(list) do
        local yy = y + (i - 1) * 38
        local c  = p.color or { 1, 1, 1 }
        local a  = p.dead and 0.45 or 1
        outlined(p.name or '', x, yy + 5, c, a)
        segments(p.key, x + nameW + 20, yy, p.dead and 0 or (p.hp or 0), math.max(1, p.hpMax or 3), 16, 24, 4, c)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- "Esperando a los demás jugadores" (los que llegaron a la zona antes)
function BossHud.drawWaiting(arrived, needed)
    local text = L('boss.waiting', { n = arrived or 0, max = needed or 0 })
    love.graphics.setFont(FONT_MED)
    local w = FONT_MED:getWidth(text) + 32
    local x, y = math.floor((WINDOW_W - w) / 2), math.floor(WINDOW_H * 0.22)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', x, y, w, 40)
    love.graphics.setColor(1, 0.35, 0.35, 0.9)
    love.graphics.rectangle('fill', x, y, w, 3)
    love.graphics.rectangle('fill', x, y + 37, w, 3)
    local a = 0.6 + 0.4 * math.abs(math.sin(love.timer.getTime() * 3))
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.print(text, x + 16, y + 12)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cámara automática: "esperando a todos" y cuenta atrás grande 3, 2, 1
function BossHud.drawScrollCountdown(a)
    if not a then return end
    if a.state == 'wait' and (a.needed or 0) > 1 then
        BossHud.drawWaiting(a.arrived, a.needed)
    elseif a.state == 'countdown' and a.cd > 0 then
        local n = math.ceil(a.cd)
        local f = n - a.cd                          -- 0..1 dentro de cada número
        local s = 1.6 + 1.2 * math.max(0, 1 - f / 0.2)
        love.graphics.setFont(FONT_BIG)
        love.graphics.push()
        love.graphics.translate(WINDOW_W / 2, WINDOW_H * 0.36)
        love.graphics.scale(s, s)
        local text = tostring(n)
        local w, h = FONT_BIG:getWidth(text), FONT_BIG:getHeight()
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(text, -w / 2 + 2, -h / 2 + 2)
        love.graphics.setColor(1, 0.95, 0.3, 1)
        love.graphics.print(text, -w / 2, -h / 2)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Entrada de un jefe (zona en 'intro'): franjas negras de cine que entran
-- desde arriba y abajo y, en la de abajo, el nombre del jefe letra a letra.
-- Solo dibujo: el avance lo lleva cada cliente con su reloj; se van solas al
-- empezar la pelea. `level` = el nivel (mira sus zonas de jefe).
local CINE_H, CINE_IN, CINE_OUT = 46, 0.45, 0.35
local cine = { k = 0, t = 0, title = nil }
function BossHud.drawCinema(level)
    local dt = math.min(0.05, love.timer.getDelta())
    local zone
    for _, z in ipairs(level.bossZones or {}) do if z.state == 'intro' then zone = z end end
    if zone then
        if cine.k == 0 then cine.t = 0 end
        cine.k = math.min(1, cine.k + dt / CINE_IN)
        cine.t = cine.t + dt
        local names = {}
        for _, b in ipairs(zone.bosses or {}) do if b.title then names[#names + 1] = b:title() end end
        cine.title = table.concat(names, ' & ')
    else
        cine.k = math.max(0, cine.k - dt / CINE_OUT)
    end
    if cine.k <= 0 then return end
    local e = 1 - (1 - cine.k) ^ 2
    local h = math.floor(CINE_H * e)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, h)
    love.graphics.rectangle('fill', 0, WINDOW_H - h, WINDOW_W, h)
    -- Nombre del jefe (aparece letra a letra tras entrar las franjas)
    local title = cine.title
    if title and title ~= '' and zone then
        local n = math.floor(math.max(0, cine.t - 0.6) * 18)
        local cut = utf8.offset(title, n + 1)                 -- (UTF-8: letras con tilde)
        local shown = cut and title:sub(1, cut - 1) or title
        if #shown > 0 then
            love.graphics.setFont(FONT_MED)
            local w = FONT_MED:getWidth(title)
            local x = math.floor(WINDOW_W / 2 - w / 2)
            local y = math.floor(WINDOW_H - h / 2 - FONT_MED:getHeight() / 2)
            outlined(shown, x, y, { 1, 0.3, 0.3 }, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Durante la entrada de un jefe el HUD entero (puntos, tiempo, vidas, barras,
-- pausa, ping, controles táctiles) se va y vuelve SUAVE, con las franjas:
-- solo quedan las franjas y el nombre del jefe.
function BossHud.hudAlpha()
    local k = cine.k
    return 1 - (1 - (1 - k) ^ 2)                      -- (misma curva que las franjas)
end

-- Dibuja `fn` (HUD) con la transparencia de hudAlpha: a través de un canvas,
-- así se desvanece todo junto (texto, sombras...) sin tocar el código del HUD
local hudCanvas
function BossHud.fadeHud(fn)
    local a = BossHud.hudAlpha()
    if a >= 0.999 then fn(); return end
    if a <= 0.001 then return end
    if not hudCanvas or hudCanvas:getWidth() ~= WINDOW_W or hudCanvas:getHeight() ~= WINDOW_H then
        hudCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end
    -- (canvas: sin la escala ni el recorte en píxeles de pantalla de lovesize)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.push('all')
    love.graphics.setCanvas(hudCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setScissor()
    fn()
    love.graphics.pop()
    if sx then love.graphics.setScissor(sx, sy, sw, sh) end
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.setColor(a, a, a, a)
    love.graphics.draw(hudCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cartel de inicio / fin de pelea (t = segundos desde que apareció)
function BossHud.drawBanner(title, t, dur, col)
    if t >= dur then return end
    local a = math.min(1, t / 0.2) * math.min(1, (dur - t) / 0.5)
    local s = 1 + 0.4 * math.max(0, 1 - t / 0.25)
    col = col or { 1, 0.3, 0.3 }
    love.graphics.setFont(FONT_BIG)
    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, WINDOW_H * 0.38)
    love.graphics.scale(s * 1.3, s * 1.3)
    love.graphics.setColor(0, 0, 0, a * 0.85)
    love.graphics.printf(title, -WINDOW_W / 2 + 3, 3, WINDOW_W, 'center')
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.printf(title, -WINDOW_W / 2, 0, WINDOW_W, 'center')
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return BossHud
