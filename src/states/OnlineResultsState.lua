-- src/states/OnlineResultsState.lua
-- Pantalla de resultados de una ronda online. Es GENÉRICA: sirve para
-- cualquier modo de juego. Solo usa la clasificación que envía el servidor
-- en el evento 'round_end':
--   { mode, reason, reasonText, entries = { {id, name, color, score,
--     finished, place, time, out, winner}, ... } }   (ya ordenadas)
-- Muestra podio (top 3), leaderboard completo, confeti y fuegos artificiales,
-- y al terminar vuelve al lobby de la sala.

local BaseState    = require 'src/BaseState'
local NC           = require 'src/network/NetworkClient'
local Modes        = require 'src/world/Modes'
local PixelIcons   = require 'src/ui/PixelIcons'

local OnlineResultsState = BaseState:new()

-- Dura lo MISMO para todos: no se puede saltar (antes el ganador, que llega
-- aún pulsando saltar = confirmar, la saltaba sin querer).
local DURATION   = 15     -- s hasta volver a la sala
local MUSIC_FADE = 1.5    -- s de fundido de la música al final

-- Tiempos de la animación (s desde que entra la pantalla)
local T_TITLE    = 0.15
local T_PODIUM   = 0.7    -- empiezan a subir los bloques (3º, 2º, 1º)
local T_STAGGER  = 0.45
local T_ROWS     = 1.2    -- entran las filas del leaderboard
local T_ROW_GAP  = 0.12
local COUNT_DUR  = 1.1    -- conteo de puntos de cada fila

local PODIUM = {          -- por puesto: altura, colores del bloque
    { h = 170, col = {1.00, 0.80, 0.20}, dark = {0.62, 0.45, 0.05} },
    { h = 120, col = {0.80, 0.84, 0.92}, dark = {0.45, 0.48, 0.58} },
    { h =  84, col = {0.85, 0.52, 0.28}, dark = {0.50, 0.28, 0.12} },
}
local CONFETTI_COLS = {
    {1,0.85,0.2}, {1,0.35,0.45}, {0.35,0.85,1}, {0.5,1,0.45}, {0.85,0.5,1}, {1,1,1},
}

local sprites
local function loadSprites()
    if sprites then return end
    sprites = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
end

local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function easeOutCubic(t) t = clamp01(t); return 1 - (1 - t) ^ 3 end
local function easeOutBack(t)
    t = clamp01(t)
    local c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
-- Caída con rebote (0 → 1)
local function easeOutBounce(t)
    t = clamp01(t)
    local n, d = 7.5625, 2.75
    if t < 1 / d then return n * t * t
    elseif t < 2 / d then t = t - 1.5 / d; return n * t * t + 0.75
    elseif t < 2.5 / d then t = t - 2.25 / d; return n * t * t + 0.9375
    else t = t - 2.625 / d; return n * t * t + 0.984375 end
end

local fitText = require('src/ui/TextUtil').fit

local function shadowText(text, x, y, w, align, r, g, b, a, off)
    off = off or 2
    love.graphics.setColor(0, 0, 0, (a or 1) * 0.8)
    love.graphics.printf(text, x + off, y + off, w, align)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.printf(text, x, y, w, align)
end

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineResultsState:enter(args)
    loadSprites()
    args = args or {}
    self.room    = args.room or {}
    local res    = type(args.results) == 'table' and args.results or {}
    self.mode    = Modes.get(res.mode or args.mode) or Modes.get(Modes.DEFAULT)
    self.reason  = res.reasonText or ''
    self.note    = type(res.note) == 'string' and res.note or nil   -- desempate
    self.tie     = res.tie == true
    self.entries = {}
    for _, e in ipairs(type(res.entries) == 'table' and res.entries or {}) do
        if type(e) == 'table' then
            e.name  = tostring(e.name or '?')
            e.score = tonumber(e.score) or 0
            e.color = type(e.color) == 'table' and e.color or {1, 1, 1}
            table.insert(self.entries, e)
        end
    end

    self.winners, self.meWinner = {}, false
    for _, e in ipairs(self.entries) do
        if e.winner then
            table.insert(self.winners, e)
            if e.id == NC.myId then self.meWinner = true end
        end
    end
    local nw = #self.winners
    if self.tie then
        self.title, self.titleCol = '¡EMPATE!', {1, 0.9, 0.2}
    elseif self.meWinner and nw == 1 then
        self.title, self.titleCol = '¡VICTORIA!', {1, 0.9, 0.2}
    elseif self.meWinner then
        self.title, self.titleCol = '¡GANASTE!', {1, 0.9, 0.2}
    elseif nw == 1 then
        self.title, self.titleCol = '¡GANA ' .. self.winners[1].name .. '!', self.winners[1].color
    elseif nw > 1 then
        self.title, self.titleCol = '¡GANAN ' .. nw .. ' JUGADORES!', {1, 0.9, 0.2}
    else
        self.title, self.titleCol = 'NADIE GANA', {0.65, 0.65, 0.75}
    end
    self.celebrate = nw > 0

    self.t          = 0
    self.confetti   = {}
    self.sparks     = {}
    self.fwTimer    = 0.6
    self.rockets    = {}
    self.landed     = {}      -- [puesto] = true cuando el jugador cayó en el podio
    self.countTick  = 0
    self.leaving    = false

    self:_setupHandlers()
    Sound.stopMusic()
    -- La música de victoria arranca YA; más baja mientras suben los puntos
    -- (para oír el conteo) y luego a volumen normal
    self.musicVol = self.celebrate and 0.6 or 0.35
    Sound.playMusic('youWin', self.musicVol * 0.45)
end

function OnlineResultsState:exit()
    NC:off("room_update")
    Sound.stopMusic()
end

function OnlineResultsState:_setupHandlers()
    NC:on("room_update", function(data)
        self.room = data
        -- El host ya inició otra ronda: entrar directo
        if data.state == "IN_GAME" then
            gStateMachine:change('online_adventure', { room = data })
        end
    end)
    NC:on("room_announce", function(data)
        if type(data) == 'table' then Notify.toast(data.msg, data.kind) end
    end)
    NC:on("room_error",   function() end)
    NC:on("room_left",    function() gStateMachine:change('online_hub') end)
    NC:on("kicked",       function(data) Notify.roomExit('kicked', data) end)
    NC:on("banned",       function(data) Notify.roomExit('banned', data) end)
    NC:on("room_closed",  function(data) Notify.roomExit('room_closed', data) end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or "Se perdio la conexion con el servidor.",
        })
    end)
end

function OnlineResultsState:_leave()
    if self.leaving then return end
    self.leaving = true
    gStateMachine:change('online_room', { room = self.room })
end

-- ── Efectos ───────────────────────────────────────────────────────────────────

function OnlineResultsState:_burstConfetti(x, y, n, spread)
    for _ = 1, n do
        local ang = -math.pi / 2 + (math.random() * 2 - 1) * (spread or 1.1)
        local sp  = 250 + math.random() * 420
        table.insert(self.confetti, {
            x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
            rot = math.random() * 6.28, vr = (math.random() * 2 - 1) * 12,
            w = 5 + math.random() * 6, h = 3 + math.random() * 4,
            col = CONFETTI_COLS[math.random(#CONFETTI_COLS)], life = 3.5 + math.random() * 2,
            sway = math.random() * 6.28,
        })
    end
end

-- Cohete: sube desde abajo dejando estela y explota en (tx, ty)
function OnlineResultsState:_launchRocket()
    local x  = 80 + math.random() * (WINDOW_W - 160)
    local ty = 90 + math.random() * 200
    table.insert(self.rockets, { x = x, y = WINDOW_H + 10, tx = x + (math.random() * 2 - 1) * 60, ty = ty,
                                 sx = x, sy = WINDOW_H + 10, t = 0, dur = 0.9 + math.random() * 0.3,
                                 large = math.random() < 0.3, trail = {} })
    Sound.play('fwLaunch', 0.9 + math.random() * 0.2, 0.55)
end

function OnlineResultsState:_firework(x, y, large)
    local col  = CONFETTI_COLS[math.random(#CONFETTI_COLS)]
    local col2 = CONFETTI_COLS[math.random(#CONFETTI_COLS)]
    local n    = large and 60 or 34
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + math.random() * 0.2
        local sp  = (large and 200 or 140) + math.random() * 90
        table.insert(self.sparks, { x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
                                    col = (i % 3 == 0) and col2 or col, life = 1.1 + math.random() * 0.5, t = 0 })
    end
    if large then
        Sound.play('fwBlastLarge', 0.95 + math.random() * 0.1, 0.8)
    else
        Sound.play(math.random() < 0.5 and 'fwBlast1' or 'fwBlast2', 0.9 + math.random() * 0.2, 0.7)
    end
end

-- ── Geometría ─────────────────────────────────────────────────────────────────

local PODIUM_CX = { 320, 170, 470 }   -- centro X de cada puesto (1º al centro)
local PODIUM_W  = 138
local FLOOR_Y   = 600

function OnlineResultsState:_podiumTime(place)
    -- Suben en orden 3º, 2º, 1º para crear suspense
    return T_PODIUM + (3 - place) * T_STAGGER
end

-- ── Update ────────────────────────────────────────────────────────────────────

function OnlineResultsState:update(dt)
    local prevT = self.t
    self.t = self.t + dt
    local t = self.t

    -- Jugadores que caen sobre su bloque: sonido + confeti al campeón
    for place = 1, math.min(3, #self.entries) do
        local land = self:_podiumTime(place) + 0.55 + 0.5
        if not self.landed[place] and t >= land then
            self.landed[place] = true
            local e = self.entries[place]
            if place == 1 then
                if self.celebrate then
                    self:_burstConfetti(PODIUM_CX[1], FLOOR_Y - PODIUM[1].h - 60, 90, 1.2)
                    self:_burstConfetti(40, WINDOW_H, 40, 0.5)
                    self:_burstConfetti(WINDOW_W - 40, WINDOW_H, 40, 0.5)
                else
                    Sound.play('sadtrombone')
                end
            else
                Sound.play('jump', 1 + (3 - place) * 0.1, 0.6)
            end
            if e and e.winner and place > 1 then
                self:_burstConfetti(PODIUM_CX[place], FLOOR_Y - PODIUM[place].h - 50, 25, 0.9)
            end
        end
    end

    -- Tic del conteo de puntos mientras suben los números
    local rowsEnd = T_ROWS + #self.entries * T_ROW_GAP + COUNT_DUR
    if t > T_ROWS + 0.3 and t < rowsEnd then
        self.countTick = self.countTick - dt
        if self.countTick <= 0 then
            self.countTick = 0.07
            Sound.play('tick', 1 + (t - T_ROWS) * 0.25, 0.5)
        end
    end

    -- Confeti continuo suave y fuegos artificiales si hay ganador
    if self.celebrate and self.landed[1] then
        if math.random() < dt * 14 then
            table.insert(self.confetti, {
                x = math.random() * WINDOW_W, y = -10, vx = (math.random() * 2 - 1) * 30, vy = 60 + math.random() * 60,
                rot = math.random() * 6.28, vr = (math.random() * 2 - 1) * 8,
                w = 5 + math.random() * 5, h = 3 + math.random() * 3,
                col = CONFETTI_COLS[math.random(#CONFETTI_COLS)], life = 12, sway = math.random() * 6.28,
            })
        end
        self.fwTimer = self.fwTimer - dt
        if self.fwTimer <= 0 and t < DURATION - 1.5 then
            self.fwTimer = 1.0 + math.random() * 1.0
            self:_launchRocket()
        end
    end

    -- Cohetes en vuelo
    for i = #self.rockets, 1, -1 do
        local r = self.rockets[i]
        r.t = r.t + dt
        local k = 1 - (1 - math.min(1, r.t / r.dur)) ^ 2      -- frena al subir
        r.x = r.sx + (r.tx - r.sx) * k
        r.y = r.sy + (r.ty - r.sy) * k
        table.insert(r.trail, 1, { x = r.x, y = r.y })
        if #r.trail > 10 then table.remove(r.trail) end
        if r.t >= r.dur then
            table.remove(self.rockets, i)
            self:_firework(r.x, r.y, r.large)
        end
    end

    -- Música de victoria: baja durante el conteo de puntos, fundido al final
    local countEnd = T_ROWS + #self.entries * T_ROW_GAP + COUNT_DUR + 0.3
    local duck = 0.45 + 0.55 * math.max(0, math.min(1, (t - countEnd) / 0.8))
    local fade = math.max(0, math.min(1, (DURATION - t) / MUSIC_FADE))
    Sound.setMusicVolume(self.musicVol * duck * fade)

    for i = #self.confetti, 1, -1 do
        local c = self.confetti[i]
        c.vy   = c.vy + 520 * dt
        if c.vy > 150 then c.vy = 150 end            -- resistencia del aire
        c.vx   = c.vx * (1 - 1.8 * dt)
        c.sway = c.sway + dt * 3
        c.x    = c.x + (c.vx + math.sin(c.sway) * 40) * dt
        c.y    = c.y + c.vy * dt
        c.rot  = c.rot + c.vr * dt
        c.life = c.life - dt
        if c.life <= 0 or c.y > WINDOW_H + 20 then table.remove(self.confetti, i) end
    end
    for i = #self.sparks, 1, -1 do
        local p = self.sparks[i]
        p.t  = p.t + dt
        p.vy = p.vy + 120 * dt
        p.vx, p.vy = p.vx * (1 - 1.5 * dt), p.vy * (1 - 1.5 * dt)
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.t >= p.life then table.remove(self.sparks, i) end
    end

    -- Volver a la sala (mismo tiempo para todos; sin atajo para saltarla)
    if t >= DURATION then self:_leave() end
end

-- Sin atajos: evita que main.lua convierta el clic en CONFIRMAR/navegación
function OnlineResultsState:touchpressed() end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineResultsState:_renderBackground()
    local t   = self.t
    local col = self.mode and self.mode.color or {1, 0.85, 0.2}
    -- Degradado vertical
    for i = 0, 17 do
        local f = i / 17
        love.graphics.setColor(0.03 + col[1] * 0.10 * (1 - f), 0.03 + col[2] * 0.10 * (1 - f),
                               0.07 + col[3] * 0.12 * (1 - f), 1)
        love.graphics.rectangle('fill', 0, i * WINDOW_H / 18, WINDOW_W, WINDOW_H / 18 + 1)
    end

    -- Rayos de luz girando detrás del podio
    local a  = easeOutCubic((t - T_PODIUM) / 1.2)
    if a > 0 then
        local cx, cy = PODIUM_CX[1], FLOOR_Y - PODIUM[1].h - 40
        local rays   = 14
        local c      = self.celebrate and {1, 0.9, 0.45} or {0.6, 0.6, 0.7}
        for i = 0, rays - 1 do
            local ang = t * 0.25 + i * (math.pi * 2 / rays)
            local w   = 0.09
            love.graphics.setColor(c[1], c[2], c[3], 0.07 * a)
            love.graphics.polygon('fill', cx, cy,
                cx + math.cos(ang - w) * 900, cy + math.sin(ang - w) * 900,
                cx + math.cos(ang + w) * 900, cy + math.sin(ang + w) * 900)
        end
        love.graphics.setColor(c[1], c[2], c[3], 0.10 * a)
        love.graphics.circle('fill', cx, cy, 120 + math.sin(t * 2) * 8)
    end

    -- Suelo
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', 0, FLOOR_Y, WINDOW_W * 0.52, WINDOW_H - FLOOR_Y)
    love.graphics.setColor(col[1], col[2], col[3], 0.5)
    love.graphics.rectangle('fill', 0, FLOOR_Y, WINDOW_W * 0.52, 3)
end

function OnlineResultsState:_renderPodium()
    local t = self.t
    for place = 3, 1, -1 do
        local e  = self.entries[place]
        local pd = PODIUM[place]
        local cx = PODIUM_CX[place]
        local t0 = self:_podiumTime(place)
        local rise = easeOutBack((t - t0) / 0.55)
        if t >= t0 then
            local h  = pd.h * rise
            local x  = cx - PODIUM_W / 2
            local y  = FLOOR_Y - h
            local dim = e and 1 or 0.35
            -- Bloque con volumen
            love.graphics.setColor(pd.dark[1] * dim, pd.dark[2] * dim, pd.dark[3] * dim, 1)
            love.graphics.rectangle('fill', x, y, PODIUM_W, h)
            love.graphics.setColor(pd.col[1] * dim, pd.col[2] * dim, pd.col[3] * dim, 1)
            love.graphics.rectangle('fill', x + 6, y, PODIUM_W - 12, h)
            love.graphics.setColor(1, 1, 1, 0.35 * dim)
            love.graphics.rectangle('fill', x + 6, y, PODIUM_W - 12, 6)
            -- Brillo que recorre el bloque del 1º
            if place == 1 and e and self.celebrate then
                local sx = x + ((t * 120) % (PODIUM_W + 80)) - 40
                love.graphics.setScissor(math.floor(x), math.floor(y), PODIUM_W, math.ceil(h))
                love.graphics.setColor(1, 1, 1, 0.25)
                love.graphics.polygon('fill', sx, y, sx + 18, y, sx - 12, y + h, sx - 30, y + h)
                love.graphics.setScissor()
            end
            -- Número del puesto
            love.graphics.setFont(FONT_BIG)
            local numA = clamp01((t - t0 - 0.3) / 0.3)
            love.graphics.setColor(0, 0, 0, 0.35 * numA)
            love.graphics.printf(tostring(place), x + 3, y + 24 + 3, PODIUM_W, 'center')
            love.graphics.setColor(1, 1, 1, 0.95 * numA)
            love.graphics.printf(tostring(place), x, y + 24, PODIUM_W, 'center')
        end

        -- Jugador: cae sobre el bloque con rebote
        if e and t >= t0 + 0.5 then
            local top  = FLOOR_Y - pd.h
            local fall = easeOutBounce((t - t0 - 0.5) / 0.6)
            local img  = sprites[3]
            local sc   = 5
            local ih   = img:getHeight()
            local baseY = top - ih * sc / 2 + 4
            local y    = -80 + (baseY + 80) * fall
            local hop  = 0
            if self.landed[place] and e.winner then
                -- Los ganadores saltan de alegría (animando el sprite)
                local ph = (t * 2.2 + place * 0.3) % 1
                hop = -math.abs(math.sin(ph * math.pi)) * 26
                img = sprites[(math.floor(t * 8) % 3) + 1]
            end
            local c   = e.color
            local lum = e.winner and 1 or 0.55
            -- Sombra en el bloque
            love.graphics.setColor(0, 0, 0, 0.3 * fall)
            love.graphics.ellipse('fill', cx, top + 2, 30 + hop * 0.3, 6)
            love.graphics.setColor((0.6 + c[1] * 0.4) * lum, (0.6 + c[2] * 0.4) * lum, (0.6 + c[3] * 0.4) * lum, 1)
            local face = (place == 2) and 1 or ((place == 3) and -1 or 1)
            love.graphics.draw(img, cx, y + hop, 0, sc * face, sc, img:getWidth() / 2, ih / 2)

            -- Nombre y corona
            if fall >= 1 then
                local nameY = y + hop - ih * sc / 2 - 22
                love.graphics.setFont(FONT_SMALL)
                shadowText(fitText(FONT_SMALL, e.name, PODIUM_W + 20), cx - 100, nameY, 200, 'center',
                           c[1], c[2], c[3], 1)
                if e.winner then
                    local px = 3
                    local cw, ch = PixelIcons.CROWN_W * px, PixelIcons.CROWN_H * px
                    local bob = math.sin(t * 4) * 3
                    PixelIcons.crown(cx - cw / 2, nameY - ch - 10 + bob, px)
                end
            end
        end
    end
end

-- Texto de la columna "resultado" según lo que traiga la entrada
local function detailText(e)
    if e.finished then
        local s = e.place and (e.place .. 'º') or 'META'
        if e.time then s = s .. string.format(' %.1fs', e.time) end
        return s, {1, 0.85, 0.2}
    elseif e.out then
        return 'FUERA', {0.9, 0.4, 0.4}
    end
    return '', {1, 1, 1}
end

function OnlineResultsState:_renderBoard()
    local t   = self.t
    local x   = 660
    local w   = WINDOW_W - x - 40
    local DETAIL_R = 110           -- borde derecho de la columna RESULTADO (desde la derecha)
    local y0  = 208
    local rowH = 50
    local showDetail = false
    for _, e in ipairs(self.entries) do if e.finished or e.out then showDetail = true end end

    local ha = clamp01((t - T_ROWS + 0.3) / 0.3)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 0.85, 0.2, 0.8 * ha)
    love.graphics.print('#', x + 14, y0 - 22)
    love.graphics.print('JUGADOR', x + 56, y0 - 22)
    love.graphics.printf('PUNTOS', x, y0 - 22, w - 14, 'right')
    if showDetail then love.graphics.printf('RESULTADO', x, y0 - 22, w - DETAIL_R, 'right') end
    love.graphics.setColor(1, 0.85, 0.2, 0.3 * ha)
    love.graphics.rectangle('fill', x, y0 - 6, w, 2)

    local maxRows = math.floor((FLOOR_Y + 60 - y0) / rowH)
    for i, e in ipairs(self.entries) do
        if i > maxRows then break end
        local rt = T_ROWS + (i - 1) * T_ROW_GAP
        if t >= rt then
            local k  = easeOutCubic((t - rt) / 0.4)
            local rx = x + (1 - k) * 420
            local ry = y0 + (i - 1) * rowH
            local c  = e.color
            local mine = e.id == NC.myId

            -- Fondo de la fila
            if e.winner then
                local pulse = 0.18 + 0.08 * math.sin(t * 4 + i)
                love.graphics.setColor(1, 0.8, 0.2, pulse * k)
            else
                love.graphics.setColor(1, 1, 1, 0.06 * k)
            end
            love.graphics.rectangle('fill', rx, ry, w, rowH - 6)
            if e.winner then
                love.graphics.setColor(1, 0.85, 0.2, 0.9 * k)
                love.graphics.rectangle('line', rx, ry, w, rowH - 6)
            end
            if mine then
                love.graphics.setColor(1, 1, 1, 0.85 * k)
                love.graphics.rectangle('line', rx - 3, ry - 3, w + 6, rowH)
            end
            -- Barra de color del jugador
            love.graphics.setColor(c[1], c[2], c[3], k)
            love.graphics.rectangle('fill', rx, ry, 6, rowH - 6)

            local ty = ry + (rowH - 6) / 2 - FONT_MED:getHeight() / 2
            love.graphics.setFont(FONT_MED)
            shadowText(tostring(i), rx + 14, ty, 40, 'left', 1, 1, 1, k)
            local nx = rx + 56
            if e.winner then
                PixelIcons.crown(nx, ry + (rowH - 6) / 2 - PixelIcons.CROWN_H, 2, k)
                nx = nx + PixelIcons.CROWN_W * 2 + 10
            end
            local nameMax = w - (nx - rx) - 90
            if showDetail then
                nameMax = w - DETAIL_R - FONT_SMALL:getWidth((detailText(e))) - 16 - (nx - rx)
            end
            local name = fitText(FONT_MED, e.name .. (mine and ' (tú)' or ''), nameMax)
            shadowText(name, nx, ty, nameMax + 20, 'left', c[1] * 0.7 + 0.3, c[2] * 0.7 + 0.3, c[3] * 0.7 + 0.3, k)

            -- Puntos con conteo
            local cf    = easeOutCubic((t - rt - 0.3) / COUNT_DUR)
            local shown = math.floor(e.score * cf + 0.5)
            shadowText(string.format('%d', shown), rx, ty, w - 14, 'right', 1, 1, 1, k)

            if showDetail then
                local d, dc = detailText(e)
                love.graphics.setFont(FONT_SMALL)
                shadowText(d, rx, ry + (rowH - 6) / 2 - FONT_SMALL:getHeight() / 2, w - DETAIL_R, 'right',
                           dc[1], dc[2], dc[3], k, 1)
            end
        end
    end
end

function OnlineResultsState:render()
    local t = self.t
    self:_renderBackground()

    -- Cohetes subiendo (estela)
    for _, r in ipairs(self.rockets) do
        for k, tp in ipairs(r.trail) do
            local a = 1 - k / (#r.trail + 1)
            love.graphics.setColor(1, 0.8, 0.4, a * 0.8)
            love.graphics.rectangle('fill', tp.x - 2, tp.y - 2, 4, 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', r.x - 3, r.y - 3, 6, 6)
    end

    -- Chispas de fuegos artificiales (detrás del contenido)
    for _, p in ipairs(self.sparks) do
        local a = 1 - p.t / p.life
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], a)
        love.graphics.rectangle('fill', p.x - 2, p.y - 2, 4, 4)
        love.graphics.setColor(1, 1, 1, a * 0.6)
        love.graphics.rectangle('fill', p.x - 1, p.y - 1, 2, 2)
    end

    -- Título con rebote de escala
    local ta = clamp01((t - T_TITLE) / 0.25)
    local sc = 0.4 + 0.6 * easeOutBack((t - T_TITLE) / 0.5)
    love.graphics.setFont(FONT_BIG)
    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, 64)
    love.graphics.scale(sc * 1.5, sc * 1.5)
    local wig = self.celebrate and math.sin(t * 3) * 0.03 or 0
    love.graphics.rotate(wig)
    local tc = self.titleCol
    love.graphics.setColor(0, 0, 0, ta * 0.8)
    love.graphics.printf(self.title, -WINDOW_W / 2 + 3, -FONT_BIG:getHeight() / 2 + 3, WINDOW_W, 'center')
    love.graphics.setColor(tc[1] * 0.6 + 0.4, tc[2] * 0.6 + 0.4, tc[3] * 0.6 + 0.4, ta)
    love.graphics.printf(self.title, -WINDOW_W / 2, -FONT_BIG:getHeight() / 2, WINDOW_W, 'center')
    love.graphics.pop()

    -- Subtítulo: modo + motivo
    local sa = clamp01((t - T_TITLE - 0.35) / 0.3)
    local mode = self.mode
    if mode then
        local label = mode.label
        love.graphics.setFont(FONT_MED)
        local iw = select(1, PixelIcons.size(mode.icon or ''))
        local lw = FONT_MED:getWidth(label) + (iw > 0 and iw * 2 + 12 or 0)
        local lx = WINDOW_W / 2 - lw / 2
        if iw > 0 then
            PixelIcons.draw(mode.icon, lx, 112, 2, sa)
            lx = lx + iw * 2 + 12
        end
        love.graphics.setColor(mode.color[1], mode.color[2], mode.color[3], sa)
        love.graphics.print(label, lx, 114)
    end
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.7 * sa)
    love.graphics.printf(self.reason, 0, 142, WINDOW_W, 'center')
    if self.note then
        love.graphics.setColor(1, 0.85, 0.2, 0.9 * sa)
        love.graphics.printf(self.note, 0, 160, WINDOW_W, 'center')
    end

    self:_renderPodium()
    self:_renderBoard()

    -- Confeti (delante de todo)
    for _, c in ipairs(self.confetti) do
        local a = math.min(1, c.life)
        love.graphics.push()
        love.graphics.translate(c.x, c.y)
        love.graphics.rotate(c.rot)
        love.graphics.setColor(c.col[1], c.col[2], c.col[3], a)
        love.graphics.rectangle('fill', -c.w / 2, -c.h / 2 * math.abs(math.cos(c.rot * 1.7)), c.w, c.h * math.abs(math.cos(c.rot * 1.7)) + 1)
        love.graphics.pop()
    end

    -- Pie: cuenta atrás hasta volver a la sala
    local remaining = math.max(0, DURATION - t)
    local fx, fw, fy = WINDOW_W - 450, 400, WINDOW_H - 46
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle('fill', fx, fy + 22, fw, 4)
    love.graphics.setColor(1, 0.85, 0.2, 0.8)
    love.graphics.rectangle('fill', fx, fy + 22, fw * (1 - remaining / DURATION), 4)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, 0.6)
    local hint = 'Volviendo a la sala en ' .. math.ceil(remaining) .. '...'
    love.graphics.printf(hint, fx - 300, fy, fw + 300, 'right')

    love.graphics.setColor(1, 1, 1, 1)
end

return OnlineResultsState
