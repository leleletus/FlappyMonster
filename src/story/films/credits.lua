-- src/story/films/credits.lua
-- LOS CRÉDITOS (docs/story/credits.md): después del final de la historia y desde Configuración. Tiempos y música:
-- assets/story/films.json, "credits" (cada escena = un trozo de una canción del juego: tools/music/credits_music.py).
-- El texto: assets/story/credits.lua (un bloque por escena).
--   logo       el logo cae, y a los 16 pulsos todo empieza a subir
-- Todo sobre el FONDO DE LADRILLOS del modo Flappy, que se mueve en las dos direcciones y cambia de color despacio.
--   pradera … bola   cada bloque de texto ENTRA por abajo justo cuando empieza su canción, con su ESCENARIO VIVO
--              debajo: un trocito de su isla que se JUEGA de verdad (src/story/LiveStage.lua: sus enemigos, bombas y
--              sonidos son los del juego); todo sube a la misma velocidad (la que hace que cada bloque quepa en su
--              canción y que el último haya salido por arriba cuando empieza la subida del Espejo)
--   mirror     sale lo último
--   rise       el espejo vacío; los siete fragmentos vuelan a él uno cada 2 pulsos (Xtra: las 14 mitades)
--   climax     el espejo entero brilla (rayos) y "¡GRACIAS POR JUGAR!"
--   bye        Claudio entra andando y baila al compás (pasos, brazos arriba, saltitos, una vuelta) mientras el
--              monstruo vuela a su alrededor, y se despide con la mano: "¡ADIÓS!"
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local PixelFont = require 'src/ui/PixelFont'
local TitleLogo = require 'src/ui/menu/TitleLogo'
local Anim = require 'src/fx/Anim'
local LiveStage = require 'src/story/LiveStage'
local L = require 'src/core/Lang'

local lerp, smooth, easeOut = K.lerp, K.smooth, K.easeOut
local F = {}
local stages                              -- los escenarios vivos de la película en curso (c.shared.stages)
local tickStages

local DATA = require 'assets/story/credits'
local ENTER_Y = 0.92                      -- (a esta altura de la pantalla entra cada bloque al empezar su canción)
local HEAD_S, NAME_S = 4, 6               -- escalas de la fuente pixel
local MARGIN = 40                         -- px entre el texto y los bichos que van debajo
local LINE = 1.6                          -- alto de línea del texto (× el de la fuente)
local SCROLL_FROM = 'logo'                -- escena y momento en que empieza a subir
local LAST_SCROLL = 'bola'                -- el último bloque: tiene que haber salido cuando empieza la subida del Espejo

-- ── Medidas ─────────────────────────────────────────────────────────────────
local function lineH(it)
    if it.gap then return it.gap end
    if it.head then return PixelFont.height(HEAD_S) end
    if it.name then return PixelFont.height(NAME_S) end
    local font = (it.small or it.smallk) and FONT_SMALL or FONT_MED
    local text = it.text and L(it.text) or it.smallk and L(it.smallk) or it.raw or it.small or it.line or ''
    local _, n = text:gsub('\n', '')
    return (n + 1) * math.floor(font:getHeight() * LINE + 0.5) + 4
end
local function blockH(list)
    local h = 0
    for _, it in ipairs(list) do h = h + lineH(it) end
    return h
end
-- lo que ocupa el escenario vivo de debajo (su nivel: 6 filas)
-- (las dos filas de arriba son aire — para los saltos —: se montan sobre el final del texto, son transparentes)
local STAGE_ROWS, STAGE_OVER = 6, 2 * 64
local FADE_TO, FADE_LEN = 0.5, 0.2         -- (se apaga del todo cuando su borde de abajo llega a media pantalla)
local function paradeH(list)
    return list.stage and (STAGE_ROWS * TILE_PX - STAGE_OVER + MARGIN) or 0
end

-- La disposición entera (se calcula una vez por película y por idioma): dónde empieza cada bloque en "papel"
-- (coordenadas que suben con el tiempo) y la velocidad
local layout
local function getLayout(c)
    if layout and layout.lang == L.current() then return layout end
    local tl = c.film.tl
    local lay = { lang = L.current(), blocks = {} }
    local t0
    for _, sc in ipairs(tl.scenes) do
        if sc.id == SCROLL_FROM then t0 = sc.t0 + (sc.cues.roll or 0) end
    end
    -- velocidad: que cada bloque quepa en su canción y que el último salga por arriba a tiempo
    local v = 30
    for _, sc in ipairs(tl.scenes) do
        local list = DATA[sc.id]
        if list then
            local h = blockH(list) + paradeH(list) + 40
            v = math.max(v, h / sc.dur)
            -- (desde que entra el último bloque hasta que empieza la subida del Espejo le da tiempo a salir por arriba)
            if sc.id == LAST_SCROLL then
                local rise
                for _, s2 in ipairs(tl.scenes) do if s2.id == 'rise' then rise = s2 end end
                v = math.max(v, (WINDOW_H * ENTER_Y + blockH(list) + paradeH(list) + 20) / (rise.t0 - sc.t0))
            end
        end
    end
    lay.v, lay.t0 = v, t0
    for _, sc in ipairs(tl.scenes) do
        local list = DATA[sc.id]
        if list then
            -- (el bloque entra por abajo al empezar su escena: su posición en el papel es la que tendrá en pantalla
            -- entonces más lo que ya ha subido todo)
            lay.blocks[#lay.blocks + 1] = { sc = sc, list = list, y = WINDOW_H * ENTER_Y + v * (sc.t0 - t0), h = blockH(list) + paradeH(list) }
        end
    end
    layout = lay
    return lay
end

-- Cuánto ha subido el papel a los `gt` s de la película
local function scrollAt(lay, gt) return math.max(0, gt - lay.t0) * lay.v end

-- ── Dibujo de un bloque ─────────────────────────────────────────────────────
local function drawText(text, font, y, a, col)
    love.graphics.setFont(font)
    local lh = font:getLineHeight()
    font:setLineHeight(LINE)
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    love.graphics.printf(text, 2, y + 2, WINDOW_W, 'center')
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.printf(text, 0, y, WINDOW_W, 'center')
    font:setLineHeight(lh)
end

local function drawBlock(b, y, gt)
    local yy = y
    for _, it in ipairs(b.list) do
        local h = lineH(it)
        if yy + h > -40 and yy < WINDOW_H + 40 then
            if it.head then
                local t = L(it.head)
                PixelFont.shadow(t, math.floor((WINDOW_W - PixelFont.width(t, HEAD_S)) / 2), math.floor(yy), HEAD_S, 1, { 1, 0.86, 0.3 })
            elseif it.name then
                local s = NAME_S
                while s > 3 and PixelFont.width(it.name, s) > WINDOW_W - 80 do s = s - 1 end
                PixelFont.shadow(it.name, math.floor((WINDOW_W - PixelFont.width(it.name, s)) / 2), math.floor(yy), s, 1)
            elseif it.text or it.raw then
                drawText(it.text and L(it.text) or it.raw, FONT_MED, math.floor(yy), 1, { 1, 1, 1 })
            elseif it.line then
                drawText(it.line, FONT_MED, math.floor(yy), 0.9, { 0.82, 0.86, 1 })
            elseif it.small or it.smallk then
                drawText(it.smallk and L(it.smallk) or it.small, FONT_SMALL, math.floor(yy), 0.85, { 0.82, 0.86, 1 })
            end
        end
        yy = yy + h
    end
    -- su escenario vivo, debajo del texto
    local live = b.list.stage and stages and stages[b.list.stage]
    if live then
        -- (se apaga al subir: cuando entra el escenario de la sección siguiente, el de esta ya no se ve)
        local top = math.floor(yy + MARGIN - STAGE_OVER)
        local bottom = top + live.h
        local a = math.max(0, math.min(1, (bottom - WINDOW_H * FADE_TO) / (WINDOW_H * FADE_LEN)))
        live:draw(top, a)
    end
end

-- ── Los escenarios vivos ────────────────────────────────────────────────────
-- Cada uno empieza un poco antes de que su bloque entre por abajo, se juega mientras se ve y se suelta al salir por
-- arriba. Van en c.shared (de toda la película): un bloque sigue a la vista en las escenas siguientes.
local START_BELOW = 160                   -- px bajo la pantalla a los que empieza a jugarse
tickStages = function(c)
    local lay = getLayout(c)
    local gt = c.film.t
    c.shared.stages = c.shared.stages or {}
    stages = c.shared.stages
    local dt = math.max(0, math.min(0.1, gt - (c.shared.stageT or gt)))
    c.shared.stageT = gt
    local s = scrollAt(lay, gt)
    for i, b in ipairs(lay.blocks) do
        local id = b.list.stage
        if id then
            local top = b.y - s + blockH(b.list) + MARGIN - STAGE_OVER     -- (el borde de arriba de la franja en pantalla)
            local h = STAGE_ROWS * TILE_PX
            if top < WINDOW_H + START_BELOW and top + h > -20 then
                if not stages[id] then stages[id] = LiveStage.new(id, 100 + i) end
                stages[id]:update(dt)
            elseif stages[id] and top + h <= -20 then
                stages[id] = false                                  -- (ya salió: no vuelve)
            end
        end
    end
end

-- ── El fondo: los ladrillos del modo Flappy ────────────────────────────────
-- Se repiten en las dos direcciones; van de lado despacio y suben con los créditos (a menos velocidad: paralaje), y su
-- color pasa poco a poco por los del modo Flappy (oscurecidos: el texto blanco se tiene que leer encima).
local BG_COLORS = { { 0.50, 0.80, 1.00 }, { 0.55, 1.00, 0.55 }, { 0.60, 0.90, 1.00 }, { 1.00, 0.60, 0.40 },
                    { 0.70, 1.00, 0.40 }, { 0.40, 0.65, 1.00 }, { 1.00, 0.45, 0.55 }, { 0.45, 1.00, 0.75 } }
local BG_DARK, BG_SECS = 0.5, 6           -- oscurecido; segundos por color
local function background(c)
    local gt = c.film.t
    local k = gt / BG_SECS
    local i = math.floor(k) % #BG_COLORS + 1
    local a, b = BG_COLORS[i], BG_COLORS[i % #BG_COLORS + 1]
    local u = smooth(k - math.floor(k))
    local col = { (a[1] + (b[1] - a[1]) * u) * BG_DARK, (a[2] + (b[2] - a[2]) * u) * BG_DARK, (a[3] + (b[3] - a[3]) * u) * BG_DARK }
    local lay = getLayout(c)
    Stage.flappyBg(gt * 18, col, 1, scrollAt(lay, gt) * 0.35)
end

-- Todo lo que sube (logo incluido) a los `gt` s
local function drawScroll(c, gt)
    local lay = getLayout(c)
    local s = scrollAt(lay, gt)
    -- el logo: cae al empezar y sube con el resto
    local ls = 6
    local lw, lh = TitleLogo.size(ls)
    local ly = math.floor(WINDOW_H * 0.5 - lh / 2 - s)
    if ly + lh > -20 then
        TitleLogo.draw(math.floor((WINDOW_W - lw) / 2), ly, ls, { t = gt, intro = true, wave = true, shadow = 6 })
    end
    for _, b in ipairs(lay.blocks) do
        local y = b.y - s
        if y < WINDOW_H + 40 and y + b.h > -60 then drawBlock(b, y, gt) end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Escenas que suben ───────────────────────────────────────────────────────
local SCROLL = { 'logo', 'pradera', 'costa', 'fortaleza', 'nieve', 'cuevas', 'volcan', 'crab', 'bola', 'mirror' }
for _, id in ipairs(SCROLL) do
    F[id] = { update = function(c) tickStages(c) end,
              draw = function(c) background(c); drawScroll(c, c.film.t) end }
end

-- ── El espejo se recompone ──────────────────────────────────────────────────
local MX = function() return math.floor(WINDOW_W / 2) end
local MF = function() return math.floor(WINDOW_H * 0.66) end

F.rise = {
    enter = function(c) c.shared.ids = c.shared.ids or Stage.shardIds(c.xtra) end,
    update = function(c, t)
        local ids = c.shared.ids
        local each = c.b(2) * 7 / #ids
        c.v.got = c.v.got or 0
        for i = c.v.got + 1, #ids do
            if t >= c.at('shards') + (i - 1) * each + each * 0.8 then
                c.v.got = i
                if not c.xtra or i % 2 == 0 then c.sfx('storyClink', 1 + i / #ids * 0.5, 0.7) end
                local sx, sy = Stage.shardSlot(ids[i], MX(), MF())
                Stage.spark(sx, sy, 6, 16, 120, { life = 0.5, s = 3 })
            end
        end
    end,
    draw = function(c, t)
        background(c)
        local ids = c.shared.ids
        local each = c.b(2) * 7 / #ids
        local placed = {}
        for i = 1, c.v.got or 0 do placed[#placed + 1] = ids[i] end
        local a = smooth(c.k(0, c.b(1)))
        Stage.mirror(MX(), MF(), { shards = placed, alpha = a })
        -- los que vuelan: desde fuera de la pantalla, en arco, girando
        for i, id in ipairs(ids) do
            local u = (t - (c.at('shards') + (i - 1) * each)) / (each * 0.8)
            if u > 0 and u < 1 then
                local sx, sy = Stage.shardSlot(id, MX(), MF())
                local ang = i / #ids * math.pi * 2
                local ox, oy = MX() + math.cos(ang) * WINDOW_W * 0.6, MF() - 200 + math.sin(ang) * WINDOW_H * 0.7
                local k = easeOut(u)
                Stage.shard(id, lerp(ox, sx, k), lerp(oy, sy, k) - math.sin(k * math.pi) * 80, { rot = (1 - k) * 3 })
            end
        end
        Stage.drawSparks()
    end,
}

-- ── El espejo entero y GRACIAS ──────────────────────────────────────────────
F.climax = {
    events = {
        { cue = 'whole', fn = function(c)
            c.sfx('storyRestore')
            local gx, gy = Stage.glassCenter(MX(), MF())
            Stage.spark(gx, gy, 30, 40, 340, { life = 1.1, s = 4 })
        end },
    },
    draw = function(c, t)
        background(c)
        local gx, gy = Stage.glassCenter(MX(), MF())
        Stage.rays(gx, gy, t * 1.6, 12, WINDOW_W, 0.12 + 0.06 * math.sin(t * 4))
        Stage.mirror(MX(), MF(), { whole = true })
        Stage.drawSparks()
        if t >= c.at('thanks') then
            local u = c.k(c.at('thanks'), c.at('thanks') + c.b(2))
            local msg = L('credits.thanks')
            local s = 7
            while s > 3 and PixelFont.width(msg, s) > WINDOW_W - 80 do s = s - 1 end
            local y = math.floor(lerp(-80, 60, K.elastic(u)))
            PixelFont.shadow(msg, math.floor((WINDOW_W - PixelFont.width(msg, s)) / 2), y, s, 1, { 1, 0.9, 0.35 })
        end
    end,
}

-- ── Claudio baila y se despide ──────────────────────────────────────────────
-- Al compás (un pulso = una figura): entra andando (pulsos 0-4); PASOS con saltito en cada pulso (hasta `spin`); en
-- `spin` una VUELTA (se gira cada medio pulso) con salto; brazos ARRIBA alternando con quieto y saltando (hasta
-- `wave`); desde `wave`, el saludo; desde `end`, quieto saludando mientras se funde a negro.
-- Mientras, el monstruo VUELA a su alrededor (un ocho, aleteando por arte de magia) y al final saluda a su lado.
local CS = 8                                    -- escala de Claudio (16 px → 128)
local function claudio(c, t)
    local set = Anim.load('claudio')
    local beat = c.beat
    local b = t / beat                          -- pulsos (con decimales)
    local cx, floor = WINDOW_W / 2, WINDOW_H * 0.82
    local x, y, seq, st, fl = cx, floor, 'idle', t, 1
    local spin = c.at('spin') / beat               -- (la vuelta: 4 pulsos desde `spin`)
    if b < 4 then
        x, seq = lerp(-80, cx, smooth(b / 4)), 'walk'
    elseif b < spin then
        local k = b - math.floor(b)
        y = floor - math.sin(math.min(1, k * 2) * math.pi) * 18 * (k < 0.5 and 1 or 0)
        seq, st = 'walk', math.floor(b) / 4      -- (un paso por pulso)
        if math.floor(b) % 4 == 3 then seq = 'cheer' end
    elseif b < spin + 4 then
        fl = (math.floor(b * 2) % 2 == 0) and 1 or -1
        y = floor - math.sin(((b - spin) / 4) * math.pi) * 60
        seq = 'cheer'
    elseif b < c.at('wave') / beat then
        local k = b - math.floor(b)
        seq = (math.floor(b) % 2 == 0) and 'cheer' or 'idle'
        if math.floor(b) % 2 == 0 then y = floor - math.sin(k * math.pi) * 34 end
    else
        seq = 'wave'
    end
    -- sombrita
    love.graphics.setColor(0, 0, 0, 0.35)
    local sw = math.floor(10 * CS * (1 - (floor - y) / 200))
    love.graphics.rectangle('fill', math.floor(cx + (x - cx) - sw / 2), math.floor(floor + 2), sw, CS)
    love.graphics.setColor(1, 1, 1, 1)
    set:draw(seq, st, math.floor(x), math.floor(y), 0, CS * fl, CS)
    return x, y
end

F.bye = {
    -- (chispas al compás: en cada pulso del baile, y una lluvia en la vuelta)
    update = function(c, t)
        local b = math.floor(t / c.beat)
        if b ~= c.v.lastBeat then
            c.v.lastBeat = b
            local cx, fy = WINDOW_W / 2, WINDOW_H * 0.82
            local spin = c.at('spin') / c.beat
            if b >= 4 and b < c.at('end') / c.beat then
                local n = (b >= spin and b < spin + 4) and 10 or 3
                Stage.spark(cx + math.random(-260, 260), fy - math.random(60, 300), n, 20, 140, { life = 0.6, s = 3 })
            end
        end
    end,
    draw = function(c, t)
        background(c)
        -- "gracias" sigue arriba, y se va con el final
        local msg = L('credits.thanks')
        local s = 7
        while s > 3 and PixelFont.width(msg, s) > WINDOW_W - 80 do s = s - 1 end
        PixelFont.shadow(msg, math.floor((WINDOW_W - PixelFont.width(msg, s)) / 2), 60, s, 1, { 1, 0.9, 0.35 })
        Stage.drawSparks()
        -- el espejo se va apagando arriba
        local a = 1 - smooth(c.k(0, c.b(4)))
        if a > 0 then Stage.mirror(MX(), MF(), { whole = true, alpha = a }) end
        -- el monstruo vuela alrededor de Claudio (un ocho) y, al despedirse, se queda flotando a su lado
        do
            local set = Anim.load('player')
            local cx, fy = WINDOW_W / 2, WINDOW_H * 0.82
            local w = c.at('wave')
            local ox, oy = cx + math.cos(t * 1.3) * 380, fy - 250 + math.sin(t * 2.6) * 70
            local vx = -math.sin(t * 1.3)
            if t >= w then
                local u = smooth(c.k(w, w + c.b(2)))
                ox, oy = lerp(ox, cx + 210, u), lerp(oy, fy - 150 + math.sin(t * 5) * 8, u)
                vx = (u < 1) and vx or -1
            end
            love.graphics.setColor(1, 1, 1, 1)
            set:draw('flutter', t, math.floor(ox), math.floor(oy), 0, PLAYER_SCALE * (vx >= 0 and 1 or -1), PLAYER_SCALE)
        end
        local x, y = claudio(c, t)
        if t >= c.at('wave') then
            local u = c.k(c.at('wave'), c.at('wave') + c.b(1))
            local msg = L('credits.bye')
            local s = 5
            local w = PixelFont.width(msg, s)
            local by = math.floor(y - 16 * CS - 40 - (1 - easeOut(u)) * 20)
            PixelFont.shadow(msg, math.floor(x - w / 2), by, s, u, { 1, 1, 1 })
        end
    end,
}

-- (para las pruebas: la disposición de los bloques — dónde está cada uno y a qué velocidad sube —)
function F._layout(c) return getLayout(c) end
function F._scrollAt(c, gt) return scrollAt(getLayout(c), gt) end
F._DATA = DATA

return F
