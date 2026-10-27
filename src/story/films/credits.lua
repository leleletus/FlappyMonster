-- src/story/films/credits.lua
-- LOS CRÉDITOS (docs/story/credits.md): después del final de la historia y desde Configuración. Tiempos y música:
-- assets/story/films.json, "credits" (cada escena = un trozo de una canción del juego: tools/music/credits_music.py).
-- El texto: assets/story/credits.lua (un bloque por escena).
--   logo       el logo cae, y a los 16 pulsos todo empieza a subir
-- Todo sobre el FONDO DE LADRILLOS del modo Flappy, que se mueve en las dos direcciones y cambia de color despacio.
--   pradera … bola   cada bloque de texto ENTRA por abajo justo cuando empieza su canción, con su ESCENARIO VIVO
--              debajo: un trocito de su isla que se JUEGA de verdad (src/story/LiveStage.lua: sus enemigos, bombas y
--              sonidos son los del juego); todo sube a la misma velocidad (la que hace que cada bloque quepa en su
--              canción y que el último haya salido por arriba cuando empieza la pelea)
--   mirror     sale lo último (en su último pulso se prepara la arena de la pelea)
--   fight, fight2   LA PELEA: el monstruo contra el Espejo en su arena, a pantalla completa, jugada de verdad (física del
--              juego, src/story/CreditsFight.lua lleva al monstruo); la misma cada vez: lo vence al final de la música
--   finale     el Espejo explota, sale volando hacia la cámara, se ESTRELLA contra la pantalla (cristal roto), resbala
--              y cae; "¡GRACIAS POR JUGAR!" y ahí termina
local Stage = require 'src/story/Stage'
local K = require 'src/story/films/common'
local PixelFont = require 'src/ui/PixelFont'
local TitleLogo = require 'src/ui/menu/TitleLogo'
local LiveStage = require 'src/story/LiveStage'
local Celebration = require 'src/ui/Celebration'
local L = require 'src/core/Lang'

local lerp, smooth, easeOut = K.lerp, K.smooth, K.easeOut
local F = {}
local stages                              -- los escenarios vivos de la película en curso (c.shared.stages)
local tickStages
local newFight, fightY, fightStage

local DATA = require 'assets/story/credits'
local ENTER_Y = 0.92                      -- (a esta altura de la pantalla entra cada bloque al empezar su canción)
local HEAD_S, NAME_S = 4, 6               -- escalas de la fuente pixel
local MARGIN = 40                         -- px entre el texto y los bichos que van debajo
local LINE = 1.6                          -- alto de línea del texto (× el de la fuente)
local SCROLL_FROM = 'logo'                -- escena y momento en que empieza a subir
local LAST_SCROLL = 'bola'                -- el último bloque: tiene que haber salido cuando empieza la pelea final

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
local FADE_TO, FADE_LEN = 0.4, 0.2         -- (se apaga del todo cuando su borde de abajo llega al 40 % de la pantalla)
-- Y APARECE igual, desde la nada, apagándose al revés al entrar por abajo: 0 con 3 filas a la vista, 1 con el suelo
-- entero (PLAY_FROM). Se juega desde que empieza a verse: antes, quieto y entero, cobraba vida de golpe al acercarse
local PLAY_FROM = 5 * 64 + 8              -- (lo de la franja, hasta el suelo, que tiene que verse para estar entera)
local IN_FROM = 3 * 64
local function stageIn(top)
    return math.max(0, math.min(1, (WINDOW_H - IN_FROM - top) / (PLAY_FROM - IN_FROM)))
end
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
            -- (desde que entra el último bloque hasta que empieza la pelea final le da tiempo a salir por arriba)
            if sc.id == LAST_SCROLL then
                local fight
                for _, s2 in ipairs(tl.scenes) do if s2.id == 'fight' then fight = s2 end end
                v = math.max(v, (WINDOW_H * ENTER_Y + blockH(list) + paradeH(list) + 20) / (fight.t0 - sc.t0))
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
        a = math.min(a, stageIn(top))
        if a > 0 then live:draw(top, a) end
    end
end

-- ── Los escenarios vivos ────────────────────────────────────────────────────
-- Cada uno empieza un poco antes de que su bloque entre por abajo, se juega mientras se ve y se suelta al salir por
-- arriba. Van en c.shared (de toda la película): un bloque sigue a la vista en las escenas siguientes.
local START_BELOW = 160                   -- px bajo la pantalla a los que se crea (quieto, sin verse)
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
                -- (quieto e invisible hasta que empieza a aparecer: si no, las cosas explotaban y morían antes de verse)
                if stageIn(top) > 0 then stages[id]:update(dt) end
            elseif stages[id] and top + h <= -20 then
                stages[id] = false                                  -- (ya salió: no vuelve)
            end
        end
    end
end

-- ── Fuegos artificiales ─────────────────────────────────────────────────────
-- A ratos durante toda la película (los de las pantallas de resultados: src/ui/Celebration.lua, con su sonido): uno
-- cada FW_MIN..FW_MAX s; en el clímax y la despedida, el doble. Detrás del texto.
local FW_MIN, FW_MAX = 2.5, 6
local function fireworks(c, often)
    local gt = c.film.t
    c.shared.fx = c.shared.fx or Celebration.new()
    local fx = c.shared.fx
    local dt = math.max(0, math.min(0.1, gt - (c.shared.fxT or gt)))
    c.shared.fxT = gt
    c.shared.fwNext = c.shared.fwNext or (gt + 3)
    if gt >= c.shared.fwNext then
        fx:rocket()
        local k = often and 0.5 or 1
        c.shared.fwNext = gt + (FW_MIN + math.random() * (FW_MAX - FW_MIN)) * k
    end
    fx:update(dt)
end
local function drawFireworks(c)
    if c.shared.fx then c.shared.fx:drawBack() end
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
    F[id] = { update = function(c) tickStages(c); fireworks(c) end,
              draw = function(c) background(c); drawFireworks(c); drawScroll(c, c.film.t) end }
end
-- (en el último pulso de la escena del Espejo se prepara la arena de la pelea: F.fight)
local mirrorUpdate = F.mirror.update
F.mirror.update = function(c, t)
    mirrorUpdate(c, t)
    if t >= c.dur - c.beat then fightStage(c) end
end

-- ── LA PELEA: el monstruo contra el Espejo ──────────────────────────────────
-- (0.5.49, el usuario: en vez del espejo que se recompone y del baile de Claudio, "una pelea pregrabada —física real
-- del juego— donde el monstruo vence al Espejo y este explota, sale volando y se choca contra la pantalla; al caer,
-- aparece el gracias por jugar y termina ahí"). Un escenario vivo a pantalla completa (assets/story/sets/
-- credits_espejo.json) con el mando de src/story/CreditsFight.lua: la misma pelea cada vez. FIGHT_WINDOWS = cuándo
-- se abre cada ataque (s desde que empieza la pelea): el último golpe cae al final de la música de la pelea
local CreditsFight = require 'src/story/CreditsFight'
local FIGHT_SEED = 31
local FIGHT_WINDOWS = { 3.0, 12.5 }
-- (la arena, a pantalla completa: su suelo cerca del borde de abajo)
fightY = function(st) return WINDOW_H - st.h + 16 end
newFight = function()
    return LiveStage.new('credits_espejo', FIGHT_SEED, { immortal = true, pilot = function(st)
        local boss
        for _, e in ipairs(st.enemies) do if e.def.name == 'mirror' then boss = e end end
        boss.DEATH_HOLD = math.huge          -- (vencido, explota sin parar hasta que la película se lo lleva: F.finale)
        return CreditsFight.new(st.player, boss, { windows = FIGHT_WINDOWS })
    end })
end

-- La pelea en pantalla: la arena aparece en el primer pulso y se juega a la hora de la película (pasos fijos: la misma
-- cada vez). c.shared.fight = el escenario; .boss = el Espejo
-- (se crea en el último pulso de la escena de antes —cargar el nivel no da un tirón en el corte— y se juega desde el
-- primer instante de la pelea)
fightStage = function(c)
    if not c.shared.fight then
        local st = newFight()
        c.shared.fight = st
        for _, e in ipairs(st.st.enemies) do if e.def.name == 'mirror' then c.shared.boss = e end end
        st:draw(fightY(st), 0)                                    -- (su cámara, ya: ver LiveStage:draw)
    end
    return c.shared.fight
end
local function tickFight(c)
    local st = fightStage(c)
    local gt = c.film.t
    c.shared.fightT0 = c.shared.fightT0 or gt
    local dt = math.max(0, math.min(0.1, gt - (c.shared.fightLast or gt)))
    c.shared.fightLast = gt
    st:update(dt)
end
local function drawFight(c, alpha)
    local st = c.shared.fight
    if not st then return end
    local a = smooth((c.film.t - (c.shared.fightT0 or 0)) / 0.6) * (alpha or 1)
    st:draw(fightY(st), a)
end

F.fight = {
    enter = function(c) fightStage(c); c.shared.fightT0, c.shared.fightLast = c.film.t, c.film.t end,
    update = function(c) tickFight(c) end,
    draw = function(c) background(c); drawFight(c) end,
}
F.fight2 = { update = F.fight.update, draw = F.fight.draw }

-- ── EL FINAL: el Espejo vencido explota, sale volando hacia la cámara y se ESTRELLA contra la pantalla ──────
-- Al empezar (con la música de la victoria): si por lo que sea no estaba vencido, se le da el último golpe (la pelea
-- es la misma cada vez, pero que el final no dependa de ello). Sigue explotando en la arena (sus explosiones de
-- verdad: 'dying_hold') hasta `fly`: entonces la película se lo lleva — sale de la arena hacia el centro de la
-- pantalla haciéndose enorme y dando vueltas (volteándose, sin girar: pixel art) —; en `crash` se estrella: cristal
-- roto (assets/images/fx/screen_crack.png), golpe, temblor; se queda pegado y en `slide` empieza a resbalar por el
-- cristal; en `fall` se despega y cae fuera; en `thanks`, ¡GRACIAS POR JUGAR! Y termina ahí.
local CRACK_S = 5                                  -- escala del cristal roto
local BIG = 4                                      -- lo grande que llega a la pantalla (× su tamaño en la arena)
local crackImg
local function crack()
    if crackImg == nil then
        local ok, im = pcall(love.graphics.newImage, 'assets/images/fx/screen_crack.png')
        if ok then im:setFilter('nearest', 'nearest') end
        crackImg = ok and im or false
    end
    return crackImg or nil
end
-- El Espejo dibujado a escala k con su centro en (x, y) de la pantalla (su dibujo de siempre, con los ojos en X)
local function drawMirror(m, x, y, k, flip)
    love.graphics.push()
    love.graphics.translate(math.floor(x), math.floor(y))
    love.graphics.scale(k * flip, k)
    m:render(m.x, m.y)
    love.graphics.pop()
end
-- Dónde está el Espejo en cada momento del final: → x, y, escala, volteado (±1); nil = ya no se ve
local function flight(c, t)
    local m = c.shared.boss
    local f0 = c.shared.flyFrom
    if not (m and f0) then return nil end
    local tf, tc, ts, tl = c.at('fly'), c.at('crash'), c.at('slide'), c.at('fall')
    local hx, hy = math.floor(WINDOW_W / 2), math.floor(WINDOW_H * 0.42)
    if t < tc then
        local u = (t - tf) / (tc - tf)
        local k = K.easeIn(u)                                          -- (acelerando hacia la cámara)
        local x = lerp(f0.x, hx, k)
        local y = lerp(f0.y, hy, k) - math.sin(u * math.pi) * 160      -- (en arco, saltando hacia arriba)
        local flip = (math.floor(u * 10) % 2 == 0) and 1 or -1          -- (da vueltas: se voltea)
        return x, y, 1 + (BIG - 1) * k, flip
    end
    -- pegado al cristal: aplastado contra él; luego resbala (cada vez más rápido) y se despega y cae
    local squash = 1 + 0.12 * math.exp(-(t - tc) * 10)
    if t < ts then return hx, hy, BIG * squash, 1 end
    if t < tl then
        local u = (t - ts) / (tl - ts)
        return hx, hy + K.easeIn(u) * 90, BIG, 1
    end
    local u = (t - tl) / c.b(2)
    if u > 1.2 then return nil end
    return hx, hy + 90 + u * u * (WINDOW_H + 200), BIG * (1 - 0.35 * K.clamp(u)), 1
end

F.finale = {
    enter = function(c)
        fightStage(c)
        local m = c.shared.boss
        -- (seguro: si no está vencido, el último golpe ahora)
        if m and not m:isDying() then
            c.shared.fight:_wrap(function()
                m.hp, m.inv, m.ghost = 1, 0, false
                m:damage(1, 'stomp')
            end)
        end
    end,
    update = function(c, t) tickFight(c) end,
    events = {
        { cue = 'fly', fn = function(c)
            -- se lo lleva la película: desde donde está en la arena (en la pantalla)
            local st, m = c.shared.fight, c.shared.boss
            if not (st and m) then return end
            c.shared.flyFrom = { x = m.x - (st.cx or 0), y = m.y - (st.cy or 0) }
            m.state, m.deadTimer, m.alive = 'dying_fall', 0, false         -- (la arena ya no lo dibuja: ahora es de la película)
            c.sfx('bossExplode', 0.8)
            c.sfx('mirrorWarp', 0.7)
            Stage.spark(c.shared.flyFrom.x, c.shared.flyFrom.y, 24, 30, 320, { life = 0.7, s = 4 })
        end },
        { cue = 'crash', fn = function(c)
            c.sfx('iceBreak', 0.8)
            c.sfx('bossExplode', 0.6)
            c.sfx('gpImpact', 0.7)
            Stage.spark(math.floor(WINDOW_W / 2), math.floor(WINDOW_H * 0.42), 30, 60, 420, { life = 0.9, s = 4 })
        end },
        { cue = 'fall', fn = function(c) c.sfx('mirrorWarp', 0.6) end },
        { cue = 'thanks', fn = function(c) c.sfx('storyRestore') end },
    },
    draw = function(c, t)
        -- (el golpe contra la pantalla: tiembla todo un momento)
        local sh = 0
        if t >= c.at('crash') then sh = 14 * math.exp(-(t - c.at('crash')) * 6) end
        love.graphics.push()
        if sh > 0.5 then love.graphics.translate(math.floor((math.random() * 2 - 1) * sh), math.floor((math.random() * 2 - 1) * sh)) end
        background(c)
        -- la arena se apaga un poco cuando llega el gracias
        drawFight(c, 1 - 0.55 * smooth(c.k(c.at('thanks'), c.at('thanks') + c.b(2))))
        love.graphics.pop()
        local m = c.shared.boss
        local x, y, k, flip = flight(c, t)
        if m and x then drawMirror(m, x, y, k, flip) end
        -- el cristal roto, desde el golpe hasta el final (está EN la pantalla: no tiembla)
        if t >= c.at('crash') then
            local im = crack()
            if im then
                local a = math.min(1, (t - c.at('crash')) / 0.06)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.draw(im, math.floor(WINDOW_W / 2), math.floor(WINDOW_H * 0.42), 0, CRACK_S, CRACK_S,
                                   im:getWidth() / 2, im:getHeight() / 2)
                love.graphics.setColor(1, 1, 1, 1)
            end
            Stage.flash(0.7 * (1 - c.k(c.at('crash'), c.at('crash') + 0.25)))
        end
        Stage.drawSparks()
        if t >= c.at('thanks') then
            local u = c.k(c.at('thanks'), c.at('thanks') + c.b(2))
            local msg = L('credits.thanks')
            local s = 8
            while s > 3 and PixelFont.width(msg, s) > WINDOW_W - 80 do s = s - 1 end
            local y = math.floor(lerp(-100, WINDOW_H * 0.64 - PixelFont.height(s) / 2, K.elastic(u)))      -- (bajo el golpe: que se lea)
            PixelFont.shadow(msg, math.floor((WINDOW_W - PixelFont.width(msg, s)) / 2), y, s, 1, { 1, 0.9, 0.35 })
        end
    end,
}

-- (para las pruebas: la disposición de los bloques — dónde está cada uno y a qué velocidad sube —)
function F._newFight() return newFight() end
function F._fightY(st) return fightY(st) end
function F._layout(c) return getLayout(c) end
function F._scrollAt(c, gt) return scrollAt(getLayout(c), gt) end
F._DATA = DATA

return F
