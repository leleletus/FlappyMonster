-- src/states/StoryResultsState.lua
-- MODO HISTORIA: RESULTADOS de un nivel superado. Basada en la de la ronda online (mismo estilo
-- vivo: título que rebota, rayos de luz, confeti y fuegos, música de victoria, tics del conteo),
-- adaptada a UN jugador: un solo PEDESTAL, de la altura y el color de la NOTA, sobre el que cae el
-- monstruo; a la derecha las líneas entran deslizándose y sus puntos suben contando (tiempo, vidas
-- perdidas, golpes, enemigos, estrellas → total /100 y puntos); al final la NOTA se estampa en el
-- pedestal (src/story/Score.lua). S y A: fiesta completa; B: confeti; D: trombón triste.
-- Luego, si los hay: mejor nota, premio y la nota del MUNDO (al vencer a su jefe).
-- ENTER / toque: durante la animación la salta; después, vuelve al mapa.
--   args = { level = id, result = (AdventureState), summary = (Run.complete), map = args del mapa, color = {r,g,b} }
local BaseState   = require 'src/BaseState'
local PixelFont   = require 'src/ui/PixelFont'
local Celebration = require 'src/ui/Celebration'
local Score       = require 'src/story/Score'
local Worlds      = require 'src/story/Worlds'
local L = require 'src/Lang'

local StoryResultsState = BaseState:new()

local T_TITLE, T_PODIUM, T_FALL = 0.15, 0.6, 0.95
local T_ROWS, ROW_GAP, COUNT = 1.0, 0.28, 0.6
local GRADE = {
    S = { h = 210, col = { 1, 0.82, 0.2 }, dark = { 0.62, 0.45, 0.05 } },
    A = { h = 180, col = { 0.45, 0.95, 0.45 }, dark = { 0.2, 0.55, 0.2 } },
    B = { h = 150, col = { 0.45, 0.8, 1 }, dark = { 0.2, 0.45, 0.65 } },
    C = { h = 120, col = { 0.85, 0.85, 0.9 }, dark = { 0.45, 0.48, 0.58 } },
    D = { h = 90, col = { 0.8, 0.5, 0.45 }, dark = { 0.45, 0.25, 0.2 } },
}
local FLOOR_Y = 600

local sprites, imgCrouch, imgDead, silhouette
local DeadEyes = require 'src/entities/DeadEyes'
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function easeOutCubic(t) t = clamp01(t); return 1 - (1 - t) ^ 3 end
local function easeOutBack(t) t = clamp01(t); return 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2 end
local function easeOutBounce(t)
    t = clamp01(t)
    local n, d = 7.5625, 2.75
    if t < 1 / d then return n * t * t
    elseif t < 2 / d then t = t - 1.5 / d; return n * t * t + 0.75
    elseif t < 2.5 / d then t = t - 2.25 / d; return n * t * t + 0.9375
    else t = t - 2.625 / d; return n * t * t + 0.984375 end
end
local function shadowText(text, x, y, w, align, c, a)
    love.graphics.setColor(0, 0, 0, (a or 1) * 0.8)
    love.graphics.printf(text, x + 2, y + 2, w, align)
    love.graphics.setColor(c[1], c[2], c[3], a or 1)
    love.graphics.printf(text, x, y, w, align)
end
local function mmss(t) return string.format('%d:%02d', math.floor(t / 60), math.floor(t % 60)) end

function StoryResultsState:enter(args)
    if not sprites then
        sprites = {}
        for i = 1, 3 do sprites[i] = love.graphics.newImage('assets/images/player/monstrito' .. i .. '.png') end
        imgCrouch = love.graphics.newImage('assets/images/player/monstrito5.png')
        imgDead = love.graphics.newImage('assets/images/player/monstrito4.png')
        -- (silueta de un color: el borde claro que lo separa del fondo oscuro)
        silhouette = love.graphics.newShader([[
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return vec4(c.rgb, Texel(t, uv).a * c.a); }
        ]])
    end
    self.args = args or {}
    local r = self.args.result or {}
    local s = self.args.summary or { rating = 0, grade = 'D', parts = {}, points = 0 }
    self.r, self.sum = r, s
    self.g = GRADE[s.grade] or GRADE.D
    self.color = self.args.color or { 1, 0.85, 0.2 }
    local W, P = Score.WEIGHTS, s.parts or {}
    -- { texto, valor mostrado (fn de k 0..1), puntos de la línea, máximo }
    local function count(n) return function(k) return tostring(math.floor((n or 0) * k + 0.5)) end end
    self.rows = {
        { L('story.results.time'), function(k) return mmss((r.time or 0) * k) end, P.time, W.time },
        { L('story.results.lives'), count(r.deaths), P.lives, W.lives },
        { L('story.results.hits'), count(r.hits), P.hits, W.hits },
        { L('story.results.kills'), function(k) return count(r.kills)(k) .. '/' .. (r.killable or 0) end, P.kills, W.kills },
        { L('story.results.stars'), function(k) return count(r.stars)(k) .. '/' .. (r.starsTotal or 0) end, P.stars, W.stars },
    }
    self.tTotal = T_ROWS + #self.rows * ROW_GAP + COUNT + 0.2           -- la fila del total
    self.tPoints = self.tTotal + 0.9                                    -- la de los puntos
    self.tStamp = self.tPoints + 1.0                                    -- la nota, al pedestal
    self.extra = {}
    local function add(text, col) self.extra[#self.extra + 1] = { text, col } end
    if s.record then add(L('story.results.record'), { 1, 0.95, 0.3 }) end
    local function reward(rw)
        if rw then add(rw.lives and L('story.results.reward_lives', { n = rw.lives }) or L('story.results.reward_points', { n = rw.points }), { 0.5, 1, 0.5 }) end
    end
    reward(s.reward)
    if s.world then
        add(L('story.results.world', { grade = s.world.grade }), (GRADE[s.world.grade] or GRADE.C).col)
        reward(s.world.reward)
    end
    -- juego acabado: dificultad nueva (para todas las partidas)
    if s.unlocked then add(L('story.results.unlocked', { name = L('difficulty.' .. s.unlocked) }), { 1, 0.45, 0.25 }) end
    self.tEnd = self.tStamp + 0.6 + #self.extra * 0.4
    self.celebrate = s.grade == 'S' or s.grade == 'A'
    -- Cómo se lo toma el monstruo: contento (S A B), sin más (C), triste (D) o… se muere del disgusto
    -- (D con menos de 25: un chiste visual, no pasa nada)
    self.mood = (s.grade == 'S' or s.grade == 'A' or s.grade == 'B') and 'happy' or (s.grade == 'C' and 'meh')
                or ((s.rating or 0) < 25 and 'dead' or 'sad')
    self.t, self.tick, self.fwTimer = 0, 0, 0.4
    self.landed, self.stamped = false, false
    self.fx = Celebration.new()
    Sound.stopMusic()
    -- (el volumen sale del CATÁLOGO — tools/music/levels.py —: antes iba fijo a 0.6 / 0.4, puesto para la pista prestada, y
    -- la nueva sonaba muy baja; mientras cuenta baja al 60 %, no al 45 %)
    local tv = (require('src/Music').get('victory') or {}).volume or 0.7
    self.musicVol = tv * (self.celebrate and 1 or 0.75)
    Sound.playMusic('victory', self.musicVol * 0.6)
end

function StoryResultsState:exit() Sound.stopMusic() end

function StoryResultsState:_podiumX() return math.floor(math.min(320, WINDOW_W * 0.25)) end

function StoryResultsState:_continue()
    if self.t < self.tEnd then self.t = self.tEnd; return end         -- (primero: saltar la animación)
    Sound.play('select')
    gStateMachine:change('story_map', self.args.map)
end

function StoryResultsState:update(dt)
    self.t = self.t + dt
    local t = self.t
    local cx = self:_podiumX()
    if not self.landed and t >= T_FALL + 0.6 then
        self.landed = true
        Sound.play('jump', 1.1, 0.6)
    end
    -- tics mientras cuentan las líneas, el total y los puntos
    if t > T_ROWS + 0.3 and t < self.tStamp then
        self.tick = self.tick - dt
        if self.tick <= 0 then
            self.tick = 0.07
            Sound.play('tick', 1 + (t - T_ROWS) * 0.18, 0.5)
        end
    end
    -- la NOTA se estampa en el pedestal
    if not self.stamped and t >= self.tStamp then
        self.stamped = true
        local top = FLOOR_Y - self.g.h
        if self.sum.grade == 'D' then
            Sound.play('sadtrombone')
            if self.mood == 'dead' then Sound.play('dies2') end
        else
            Sound.play('collect', 0.8)
            if self.celebrate or self.sum.grade == 'B' then
                self.fx:burst(cx, top - 60, self.celebrate and 90 or 40, 1.2)
            end
            if self.celebrate then
                self.fx:burst(40, WINDOW_H, 40, 0.5)
                self.fx:burst(WINDOW_W - 40, WINDOW_H, 40, 0.5)
            end
        end
    end
    if self.celebrate and self.stamped then
        self.fx:rain(dt)
        self.fwTimer = self.fwTimer - dt
        if self.fwTimer <= 0 then self.fwTimer = 1 + math.random(); self.fx:rocket() end
    end
    self.fx:update(dt)
    -- música: más baja mientras cuenta (para oír los tics), luego normal
    local duck = 0.6 + 0.4 * clamp01((t - self.tStamp) / 0.8)
    Sound.setMusicVolume(self.musicVol * duck)
    if Input.pressed('confirm') or Input.pressed('flap') or Input.pressed('back') then self:_continue() end
end

function StoryResultsState:touchpressed() self:_continue() end

-- El MONSTRUO y su reacción. Se ve sobre el fondo oscuro gracias a un foco de luz detrás y a un
-- borde claro (su silueta dibujada alrededor). Cae al pedestal; mientras se cuenta, NERVIOSO (da
-- golpecitos con el pie, mira a un lado y a otro, saltitos); con la nota: CONTENTO salta y gira,
-- SIN MÁS se queda quieto suspirando, TRISTE se agacha de espaldas y, si es un desastre, se MUERE
-- del disgusto (la animación de muerte del juego: ojos en X, salto y caída fuera; luego vuelve a
-- caer, triste). Solo dibujo.
local function drawSprite(img, x, y, sc, face, outline)
    local ox, oy = img:getWidth() / 2, img:getHeight() / 2
    love.graphics.setShader(silhouette)
    love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
    for _, d in ipairs({ { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 } }) do
        love.graphics.draw(img, x + d[1], y + d[2], 0, sc * face, sc, ox, oy)
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y, 0, sc * face, sc, ox, oy)
end

function StoryResultsState:drawHero(cx, top, t)
    local sc, ih = 5, 16
    local baseY = top - ih * sc / 2 + 4
    -- foco de luz detrás
    love.graphics.setBlendMode('add')
    for i, r in ipairs({ 120, 84, 52 }) do
        love.graphics.setColor(1, 0.95, 0.8, 0.07 * i)
        love.graphics.circle('fill', cx, baseY - 6, r)
    end
    love.graphics.setBlendMode('alpha')
    local outline = { 0.95, 0.95, 1, 0.9 }
    local img, face, x, y = sprites[3], 1, cx, baseY
    if t < T_FALL + 0.6 then                                          -- cayendo al pedestal
        y = -80 + (baseY + 80) * easeOutBounce((t - T_FALL) / 0.6)
    elseif t < self.tStamp then                                       -- NERVIOSO esperando la nota
        local w = t - T_FALL
        img = sprites[(math.floor(w * 7) % 2 == 0) and 1 or 3]          -- golpecitos con el pie
        face = (math.floor(w / 0.7) % 2 == 0) and 1 or -1               -- mira a un lado y a otro
        x = cx + math.floor(math.sin(w * 40) * 1.5 + 0.5)               -- tiembla
        y = baseY - math.abs(math.sin(w * math.pi * 2)) * ((math.floor(w / 0.5) % 3 == 0) and 10 or 0)
    else
        local a = t - self.tStamp
        if self.mood == 'happy' then
            local ph = (t * 2.2) % 1
            y = baseY - math.abs(math.sin(ph * math.pi)) * 26
            img = sprites[(math.floor(t * 8) % 3) + 1]
            face = (math.floor(t * 1.1) % 2 == 0) and 1 or -1
        elseif self.mood == 'meh' then
            img = sprites[1]
            y = baseY + math.floor(math.sin(t * 1.6) * 1.5 + 0.5)       -- suspira
        elseif self.mood == 'sad' or (self.mood == 'dead' and a > 2.6) then
            img, face = imgCrouch, -1                                    -- de espaldas, agachado
            if self.mood == 'dead' then y = -80 + (baseY + 80) * easeOutBounce((a - 2.6) / 0.6) end
            x = cx + math.floor(math.sin(t * 1.2) * 2 + 0.5)
        else                                                             -- se MUERE del disgusto
            img = imgDead
            if a < 0.5 then
                x = cx + math.floor(math.sin(t * 60) * 2 + 0.5)
            elseif a < 2.6 then
                local u = a - 0.5                                        -- salta y cae fuera, como al morir
                y = baseY - 420 * u + 0.5 * 1500 * u * u
            end
            if y > WINDOW_H + 60 then return end
            drawSprite(img, math.floor(x), math.floor(y), sc, face, outline)
            DeadEyes.draw(math.floor(x), math.floor(y), sc, face)
            return
        end
    end
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse('fill', cx, top + 2, 30, 6)
    drawSprite(img, math.floor(x), math.floor(y), sc, face, outline)
end

function StoryResultsState:render()
    local t, c, g = self.t, self.color, self.g
    local cx = self:_podiumX()
    -- Fondo: degradado con el color del mundo
    for i = 0, 17 do
        local f = i / 17
        love.graphics.setColor(0.03 + c[1] * 0.12 * (1 - f), 0.03 + c[2] * 0.12 * (1 - f), 0.07 + c[3] * 0.14 * (1 - f), 1)
        love.graphics.rectangle('fill', 0, i * WINDOW_H / 18, WINDOW_W, WINDOW_H / 18 + 1)
    end
    -- Rayos de luz detrás del pedestal
    local ra = easeOutCubic((t - T_PODIUM) / 1.2)
    if ra > 0 then
        local px, py = cx, FLOOR_Y - g.h - 40
        local rc = self.celebrate and { 1, 0.9, 0.45 } or { 0.6, 0.6, 0.7 }
        for i = 0, 13 do
            local ang = t * 0.25 + i * (math.pi * 2 / 14)
            love.graphics.setColor(rc[1], rc[2], rc[3], 0.07 * ra)
            love.graphics.polygon('fill', px, py, px + math.cos(ang - 0.09) * 900, py + math.sin(ang - 0.09) * 900,
                                  px + math.cos(ang + 0.09) * 900, py + math.sin(ang + 0.09) * 900)
        end
    end
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 0, FLOOR_Y, WINDOW_W, WINDOW_H - FLOOR_Y)
    love.graphics.setColor(c[1], c[2], c[3], 0.5)
    love.graphics.rectangle('fill', 0, FLOOR_Y, WINDOW_W, 3)
    self.fx:drawBack()

    -- Título (rebota y se balancea) y el nivel
    local ta = clamp01((t - T_TITLE) / 0.25)
    local sc = 0.4 + 0.6 * easeOutBack((t - T_TITLE) / 0.5)
    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, 60)
    love.graphics.scale(sc * 1.5, sc * 1.5)
    love.graphics.rotate(self.celebrate and math.sin(t * 3) * 0.03 or 0)
    love.graphics.setFont(FONT_BIG)
    shadowText(L('hud.level_clear'), -WINDOW_W / 2, -FONT_BIG:getHeight() / 2, WINDOW_W, 'center', { 1, 0.95, 0.4 }, ta)
    love.graphics.pop()
    love.graphics.setFont(FONT_MED)
    local sa = clamp01((t - T_TITLE - 0.35) / 0.3)
    shadowText(Worlds.levelName(self.args.level or ''), 0, 104, WINDOW_W, 'center', c, sa)

    -- El PEDESTAL (uno: modo de un jugador) y el monstruo encima
    local rise = easeOutBack((t - T_PODIUM) / 0.55)
    local w = 150
    if t >= T_PODIUM then
        local h = g.h * rise
        local x, y = cx - w / 2, FLOOR_Y - h
        love.graphics.setColor(g.dark); love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setColor(g.col); love.graphics.rectangle('fill', x + 6, y, w - 12, h)
        love.graphics.setColor(1, 1, 1, 0.35); love.graphics.rectangle('fill', x + 6, y, w - 12, 6)
        -- la NOTA estampada en su cara
        if t >= self.tStamp then
            local k = clamp01((t - self.tStamp) / 0.25)
            local s = math.floor(14 * (1 + 1.6 * (1 - k)) + 0.5)
            local letter = self.sum.grade
            PixelFont.shadow(letter, math.floor(cx - PixelFont.width(letter, s) / 2), math.floor(y + h / 2 - PixelFont.height(s) / 2), s, 1)
        end
    end
    if t >= T_FALL then self:drawHero(cx, FLOOR_Y - g.h, t) end

    -- Las líneas: entran deslizándose y cuentan
    local bx = math.max(cx + w / 2 + 50, WINDOW_W - 680)
    local bw = WINDOW_W - bx - 40
    local y0, rowH = 170, 50
    love.graphics.setFont(FONT_MED)
    for i, row in ipairs(self.rows) do
        local rt = T_ROWS + (i - 1) * ROW_GAP
        if t >= rt then
            local k = easeOutCubic((t - rt) / 0.4)
            local rx, ry = bx + (1 - k) * 420, y0 + (i - 1) * rowH
            love.graphics.setColor(1, 1, 1, 0.07 * k)
            love.graphics.rectangle('fill', rx, ry, bw, rowH - 8)
            love.graphics.setColor(c[1], c[2], c[3], k)
            love.graphics.rectangle('fill', rx, ry, 6, rowH - 8)
            local ty = ry + (rowH - 8) / 2 - FONT_MED:getHeight() / 2
            local cf = easeOutCubic((t - rt - 0.3) / COUNT)
            shadowText(row[1], rx + 16, ty, bw, 'left', { 1, 1, 1 }, k)
            shadowText(row[2](cf), rx, ty, bw - 150, 'right', { 1, 1, 1 }, k)
            local got = (row[3] or 0) * cf
            shadowText(('%d/%d'):format(math.floor(got + 0.5), row[4]), rx, ty, bw - 14, 'right', { 1, 0.85, 0.3 }, k)
        end
    end
    -- TOTAL /100 y PUNTOS
    local function bigRow(rt, label, value, col, i)
        if t < rt then return end
        local k = easeOutCubic((t - rt) / 0.4)
        local rx, ry = bx + (1 - k) * 420, y0 + i * rowH + 6
        love.graphics.setColor(col[1], col[2], col[3], 0.18 * k)
        love.graphics.rectangle('fill', rx, ry, bw, rowH - 4)
        love.graphics.setColor(col[1], col[2], col[3], 0.9 * k)
        love.graphics.rectangle('line', rx, ry, bw, rowH - 4)
        local ty = ry + (rowH - 4) / 2 - FONT_MED:getHeight() / 2
        shadowText(label, rx + 16, ty, bw, 'left', col, k)
        shadowText(value(easeOutCubic((t - rt - 0.2) / 0.8)), rx, ty, bw - 14, 'right', { 1, 1, 1 }, k)
    end
    bigRow(self.tTotal, L('story.results.grade'), function(k) return ('%d/100'):format(math.floor(self.sum.rating * k + 0.5)) end, g.col, #self.rows)
    bigRow(self.tPoints, L('story.results.points'), function(k) return tostring(math.floor((self.sum.points or 0) * k + 0.5)) end, { 1, 0.85, 0.3 }, #self.rows + 1)

    -- Mejor nota, premios, mundo
    for i, e in ipairs(self.extra) do
        local et = self.tStamp + 0.4 + (i - 1) * 0.4
        if t >= et then
            local k = easeOutBack((t - et) / 0.4)
            local blink = (i == 1 and self.sum.record) and (0.75 + 0.25 * math.sin(t * 9)) or 1
            local s = 3
            local tw = PixelFont.width(e[1], s)
            love.graphics.push()
            love.graphics.translate(bx + bw / 2, FLOOR_Y + 30 + (i - 1) * 30)
            love.graphics.scale(k, k)
            PixelFont.shadow(e[1], math.floor(-tw / 2), 0, s, blink, e[2])
            love.graphics.pop()
        end
    end

    self.fx:drawFront()
    if t >= self.tEnd then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.55 + 0.25 * math.sin(t * 4))
        love.graphics.printf(L('story.results.hint'), 0, WINDOW_H - 28, WINDOW_W, 'center')
    end
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, 1)
end

return StoryResultsState
