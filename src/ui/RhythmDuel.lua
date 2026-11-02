-- src/ui/RhythmDuel.lua
-- EL DUELO DE RITMO del Cangrejo Groove (docs/bosses/groovecrab.md; la idea del usuario, estilo Friday Night Funkin'): las notas
-- EXACTAS del tema (assets/charts/groove.json: tools/music/groove_chart.py) suben hacia 4 flechas quietas y hay que pulsarlas a
-- tiempo. Lo juega cada CLIENTE contra SU música (una nota no puede esperar a una instantánea) y al acabar da el resultado: en un
-- jugador, al jefe (GC:duelReport); online, un mensaje al servidor. El jefe decide lo demás: congelar, noquear, quitar vida.
-- EN PANTALLA (0.5.150, el boceto del usuario): el fondo se oscurece y encima, las flechas algo a la izquierda del centro,
-- el medidor a su derecha y, a los lados, a media altura, el MONSTRUO (a la izquierda: todos los jugadores del duelo,
-- más pequeños si son varios) y el CANGREJO (a la derecha), los dos bailando: él canta su chart (GC:drawDuelCast) y cada
-- monstruo hace la pose de la flecha que acierta, la de fallo de la que se le escapa y, entre notas, su baile
-- (assets/anim/player.json: duel_*). En la arena no están mientras dura (R.hides). Online, cada acierto y fallo va
-- al servidor (`rhythm_pose`), que se lo pasa a los demás: R.remotePose.
-- Sin love.graphics fuera de draw.
local json = require 'libs/json'
local R = {}
local cur                                   -- el duelo en curso
local chartData
local sprites
local touchDown = {}
local NAMES = { 'rhythm_left', 'rhythm_down', 'rhythm_up', 'rhythm_right' }
local SPLASH_T = 0.16                       -- s del impacto al acertar
local SWING = 150                           -- % del medidor que se pierde fallándolas todas en una duración entera (por eso acaba a 1/3)

local function chart()
    if chartData == nil then
        local src = love.filesystem.read('assets/charts/groove.json')
        chartData = src and json.decode(src) or false
    end
    return chartData
end

-- La fila del chart `name` del compás `cb` de la partitura: { semicorchea, carril (0-3), … } o nil (el fondo del escenario
-- del Groove dibuja con esto sus flechas: groovecrab_stage.lua)
function R.row(name, cb)
    local c = chart()
    return c and c.charts[name] and c.charts[name][tostring(cb)] or nil
end

-- Las notas del duelo: los compases [bar, bar + bars) de la canción, con el bucle. { t, lane }
function R.build(boss, name, bar, bars)
    local c = chart()
    local out = {}
    if not c then return out end
    local list = c.charts[name] or {}
    for b = bar, bar + bars - 1 do
        local cb = (b < boss.INTRO_BARS) and b or boss.INTRO_BARS + (b - boss.INTRO_BARS) % boss.LOOP
        local row = list[tostring(cb)]
        if row then
            for i = 1, #row, 2 do
                out[#out + 1] = { t = (b * 16 + row[i]) * boss.S16, lane = row[i + 1] + 1 }
            end
        end
    end
    return out
end

function R.start(boss, info, diff, playing)
    local cfg = boss.DUEL[diff or 'normal'] or boss.DUEL.normal
    local notes = R.build(boss, cfg.chart, info.bar, info.bars)
    local n = math.max(1, #notes)
    local lose = SWING / n
    cur = { diff = diff, boss = boss, bar = info.bar, bars = info.bars, cfg = cfg, notes = notes, n = n, first = 1, meter = 50,
            lose = lose, gain = lose * (1 - cfg.failAt) / cfg.failAt, hits = 0, misses = 0, playing = playing, remote = {},
            clock = boss.songT or 0, endT = (info.bar + info.bars) * boss.BAR, lit = { 0, 0, 0, 0 }, hit = { 0, 0, 0, 0 }, text = nil, textT = 0 }
    return cur
end

-- Lo que pasó en cada duelo, en la carpeta de datos (rhythm_duel.log): lo que no se puede ver sin el aparato del jugador
local function logLine(c, what)
    local nm, pos, part = nil, nil, nil
    if Sound and Sound.musicPosition then nm, pos, part = Sound.musicPosition() end
    local v = love.filesystem.read('version.txt') or '?'
    pcall(love.filesystem.append, 'rhythm_duel.log', ('%s v%s dif=%s compas=%d x%d chart=%s notas=%d jugando=%s reloj=%.2f song=%.2f audio=%s/%s/%s aciertos=%d fallos=%d medidor=%.0f\n'):format(
        what, v:gsub('%s', ''), tostring(c.diff), c.bar, c.bars, tostring(chart() and true or false), #c.notes, tostring(c.playing), c.clock, c.boss.songT or -1,
        tostring(nm), tostring(pos), tostring(part), c.hits, c.misses, c.meter))
end

function R.current() return cur end

-- La pose del monstruo: acierto (ok) o fallo de la flecha `lane`; online, también se manda (c.onPose)
local function setPose(c, lane, ok)
    c.pose = { lane = lane, ok = ok, t = love.timer.getTime() }
    if c.onPose then c.onPose(lane, ok) end
end
-- La pose de OTRO jugador (online: lo que reenvía el servidor)
function R.remotePose(id, lane, ok)
    if cur and id ~= nil and type(lane) == 'number' then
        cur.remote[id] = { lane = math.max(1, math.min(4, math.floor(lane))), ok = ok == true, t = love.timer.getTime() }
    end
end
-- ¿No se dibuja en la arena quien está en (x, y)? (está en el duelo: sale en el minijuego)
function R.hides(level, x, y)
    return cur ~= nil and cur.boss.duelLive ~= nil and cur.boss:duelLive()
        and require('src/world/systems/BossZones').frozenAt(level, x, y) == true
end
function R.reset() cur = nil; touchDown = {} end

-- El reloj: la posición real de la música si suena (y cuadra con el del jefe); si no, el del jefe
local function audioTime(c)
    local boss = c.boss
    if not (Sound and Sound.musicPosition) then return nil end
    local name, pos, part = Sound.musicPosition()
    if name ~= 'groove' or type(pos) ~= 'number' then return nil end
    local introT, loopT = boss.INTRO_BARS * boss.BAR, boss.LOOP * boss.BAR
    local a = pos
    if part == 'bucle' then
        a = introT + pos
        a = a + math.floor(((boss.songT or 0) - a) / loopT + 0.5) * loopT
    end
    if math.abs(a - (boss.songT or 0)) > 0.6 then return nil end
    return a
end

-- Lo que se juzga: lo que SUENA ahora (con el ajuste de retardo de Configuración)
local function offset()
    local S = package.loaded['src/core/Settings']
    return ((S and S.rhythmOffset) or 0) / 1000
end

function R.press(lane)
    local c = cur
    if not (c and c.playing and not c.done) then return end
    c.lit[lane] = 0.12
    local W = c.cfg.window
    for i = c.first, #c.notes do
        local n = c.notes[i]
        if n.t > c.clock + W then break end
        if not n.judged and n.lane == lane and math.abs(n.t - c.clock) <= W then
            n.judged, n.hit = true, true
            c.hit[lane] = SPLASH_T
            Sound.play('scorpionClick', 1, 1)            -- (el usuario: cada nota acertada suena con un clic)
            c.hits = c.hits + 1
            c.meter = math.min(100, c.meter + c.gain)
            setPose(c, lane, true)
            c.text, c.textT = (math.abs(n.t - c.clock) <= W / 2) and 'rhythm.perfect' or 'rhythm.good', 0.5
            return true
        end
    end
    return false                                -- (pulsar sin nota no castiga)
end

local function readInput()
    for lane, a in ipairs(NAMES) do
        if Input.pressed(a) then R.press(lane) end
    end
    -- Táctil: la mitad de abajo de la pantalla, cuatro columnas
    if Input.isMobile and love.touch then
        local sw, sh = love.graphics.getDimensions()
        local seen = {}
        for _, id in ipairs(love.touch.getTouches()) do
            seen[id] = true
            if not touchDown[id] then
                local x, y = love.touch.getPosition(id)
                if y >= sh * 0.45 then R.press(math.max(1, math.min(4, math.floor(x / sw * 4) + 1))) end
            end
        end
        touchDown = seen
    end
end

-- Cada frame. `report(bar, acc, failed)` da el resultado una vez. `who` = el jugador local. `onPose(lane, ok)`: cada
-- acierto y fallo (online, para los demás)
function R.update(dt, level, who, report, press, onPose)
    local boss, info
    for _, z in ipairs(level and level.bossZones or {}) do
        for _, b in ipairs(z.bosses or {}) do
            if b.duelInfo then
                local i = b:duelInfo()
                if i then boss, info = b, i end
            end
        end
    end
    if not boss then cur = nil; return end
    if not cur or cur.bar ~= info.bar or cur.boss ~= boss then
        R.start(boss, info, level.difficulty, who ~= nil and not who.dying and who.alive ~= false)
        logLine(cur, 'empieza')
    end
    local c = cur
    c.onPose = onPose
    -- Sin notas (el chart no se pudo leer): acaba ya, sin castigo. Nunca dejar a nadie congelado esperando
    if #c.notes == 0 and not c.done then
        c.done, c.empty, c.acc = true, true, 0
        print('[RhythmDuel] duelo sin notas: el chart no se pudo leer o no tiene ese compás')
        logLine(c, 'sin_notas')
        if report then report(c.bar, 0, false) end
    end
    c.clock = c.clock + dt
    local a = audioTime(c)
    local target = (a or boss.songT or c.clock) - offset()
    if math.abs(target - c.clock) > 0.25 then c.clock = target
    else c.clock = c.clock + (target - c.clock) * math.min(1, dt * 8) end
    for l = 1, 4 do c.lit[l] = math.max(0, c.lit[l] - dt); c.hit[l] = math.max(0, c.hit[l] - dt) end
    if c.textT > 0 then c.textT = c.textT - dt end
    -- Si moría o reaparecía justo al empezar, entra ahora: lo que ya pasó no cuenta
    if not c.playing and not c.done and who and not who.dying and who.alive ~= false then
        c.playing = true
        for i = c.first, #c.notes do
            local n = c.notes[i]
            if n.t > c.clock + c.cfg.window then break end
            n.judged = true
            c.first = i + 1
        end
        local left = math.max(1, #c.notes - c.first + 1)
        c.n, c.lose = left, SWING / left
        c.gain = c.lose * (1 - c.cfg.failAt) / c.cfg.failAt
        logLine(c, 'entra_tarde')
    end
    if c.playing and not c.done then
        if press then press() else readInput() end
        -- Las que ya pasaron
        local W = c.cfg.window
        while c.first <= #c.notes do
            local n = c.notes[c.first]
            if n.judged then c.first = c.first + 1
            elseif c.clock > n.t + W then
                n.judged = true
                c.first = c.first + 1
                c.misses = c.misses + 1
                c.meter = c.meter - c.lose
                setPose(c, n.lane, false)
                c.text, c.textT = 'rhythm.miss', 0.5
            else break end
        end
        local endless = boss.duelOnly and boss:duelOnly()            -- (nivel de prueba: toda la canción, aunque se vacíe)
        if endless then c.meter = math.max(1, c.meter) end
        if (c.meter <= 0 and not endless) or c.clock >= c.endT then
            c.done, c.failed = true, c.meter <= 0
            c.acc = c.hits / c.n
            c.ko = not c.failed and c.acc >= c.cfg.koAt
            logLine(c, 'acaba')
            if report then report(c.bar, c.acc, c.failed) end
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function load()
    if sprites then return end
    sprites = { strums = love.graphics.newImage('assets/images/ui/rhythm/strums-Sheet.png'),
                hit = love.graphics.newImage('assets/images/ui/rhythm/strums_hit-Sheet.png'),
                notes = love.graphics.newImage('assets/images/ui/rhythm/notes-Sheet.png'),
                splash = love.graphics.newImage('assets/images/ui/rhythm/splash-Sheet.png'), q = {}, sq = {} }
    for l = 1, 4 do
        sprites.sq[l] = {}
        for f = 1, 3 do sprites.sq[l][f] = love.graphics.newQuad((f - 1) * 48, (l - 1) * 48, 48, 48, 144, 192) end
    end
    for _, k in ipairs({ 'strums', 'hit', 'notes', 'splash' }) do sprites[k]:setFilter('nearest', 'nearest') end
    for i = 1, 4 do sprites.q[i] = love.graphics.newQuad((i - 1) * 24, 0, 24, 24, 96, 24) end
end

local SCALE, GAP = 3, 84
local DIM_IN = 0.4                          -- s que tarda en oscurecerse el fondo
-- El fondo se OSCURECE (antes del marcador: el marcador queda a la vista). Lo llaman los estados antes de su HUD
function R.drawDim()
    local c = cur
    if not c then return end
    local u = math.min(1, math.max(0, (c.clock - (c.bar - 1) * c.boss.BAR) / DIM_IN))
    love.graphics.setColor(0.03, 0.01, 0.08, 0.55 * u)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Los MONSTRUOS del duelo, a la izquierda (cast: { {id, color, me}… }; nil = solo el propio, blanco)
local DIRS = { 'left', 'down', 'up', 'right' }
local HOLD_OK, HOLD_MISS = 0.34, 0.45
local function drawCast(c, cast, x, feet)
    local PS = require 'src/player/PlayerSprite'
    cast = cast or { { me = true } }
    local n = #cast
    if n == 0 then return end
    local k = (n == 1) and 9 or ((n == 2) and 7 or ((n <= 4) and 5 or 4))
    local step = (n == 1) and 0 or math.min(15 * k, math.floor(WINDOW_W * 0.24 / n))
    local now = love.timer.getTime()
    local beat = math.floor(c.clock / (c.boss.BAR / 4))
    for i, m in ipairs(cast) do
        local px = math.floor(x + (i - (n + 1) / 2) * step)
        local pose = m.me and c.pose or c.remote[m.id]
        local name, fr = 'duel_idle', beat % 2 + 1
        if pose and now - pose.t < (pose.ok and HOLD_OK or HOLD_MISS) then
            name, fr = (pose.ok and 'duel_' or 'duel_miss_') .. DIRS[pose.lane], 1
        end
        local clip = PS.clip(name)
        local rec = clip and clip.recs[math.min(#clip.recs, fr)]
        if rec and rec.image then
            local col = m.color
            if col then love.graphics.setColor(0.6 + col[1] * 0.4, 0.6 + col[2] * 0.4, 0.6 + col[3] * 0.4, 1)
            else love.graphics.setColor(1, 1, 1, 1) end
            love.graphics.draw(rec.image, rec.quad, px, feet, 0, k, k, math.floor(rec.w / 2), rec.h)
            if m.me and n > 1 then                              -- (cuál eres tú)
                local ty = feet - rec.h * k - 18
                love.graphics.setColor(1, 0.9, 0.3, 1)
                love.graphics.polygon('fill', px - 10, ty - 12, px + 10, ty - 12, px, ty)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function R.draw(cast)
    local c = cur
    if not c then return end
    load()
    local g = love.graphics
    local font = g.getFont()
    local cx, y0 = math.floor(WINDOW_W * 0.47), 150
    local x0 = cx - GAP * 2
    -- los dos que bailan, a media altura, a los lados (el boceto del usuario)
    local feet = math.floor(WINDOW_H * 0.6)
    -- (un foco y un suelo bajo cada lado: el monstruo es casi negro y de noche no se veía)
    for _, sp in ipairs({ { WINDOW_W * 0.17, 150, { 0.75, 0.85, 1 } }, { WINDOW_W * 0.85, 170, { 1, 0.6, 0.9 } } }) do
        local x, hw, col = math.floor(sp[1]), sp[2], sp[3]
        g.setBlendMode('add')
        g.setColor(col[1], col[2], col[3], 0.13)
        g.polygon('fill', x - 26, 0, x + 26, 0, x + hw, feet, x - hw, feet)
        g.setColor(col[1], col[2], col[3], 0.22)
        g.ellipse('fill', x, feet, hw, 18, 24)
        g.setBlendMode('alpha')
        g.setColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.6, 0.9)
        g.rectangle('fill', x - hw, feet, 2 * hw, 6)
    end
    drawCast(c, cast, WINDOW_W * 0.17, feet)
    if c.boss.drawDuelCast then c.boss:drawDuelCast(WINDOW_W * 0.85, feet, 0.8) end
    g.setColor(0, 0, 0, 0.35)
    g.rectangle('fill', x0 - 16, 0, GAP * 4 + 32, WINDOW_H)
    -- Quietas
    for l = 1, 4 do
        g.setColor(1, 1, 1, 1)
        -- (al pulsar se encoge; al acertar, además, salta: que se note)
        local k = (c.hit[l] > 0) and (SCALE + 1) or ((c.lit[l] > 0) and (SCALE - 0.5) or SCALE)
        local cxl = x0 + (l - 1) * GAP + 42
        g.draw(c.lit[l] > 0 and sprites.hit or sprites.strums, sprites.q[l], cxl, y0, 0, k, k, 12, 12)
    end
    -- Las que suben
    local speed = (WINDOW_H - y0 + 40) / c.cfg.scroll
    if c.playing and not c.done then
        for i = c.first, #c.notes do
            local n = c.notes[i]
            local y = y0 + (n.t - c.clock) * speed
            if y > WINDOW_H + 40 then break end
            if not n.judged then
                g.setColor(1, 1, 1, 1)
                g.draw(sprites.notes, sprites.q[n.lane], x0 + (n.lane - 1) * GAP + 6, math.floor(y) - 36, 0, SCALE, SCALE)
            end
        end
    end
    -- El impacto, encima de todo
    g.setColor(1, 1, 1, 1)
    for l = 1, 4 do
        if c.hit[l] > 0 then
            local f = math.min(3, math.floor((1 - c.hit[l] / SPLASH_T) * 3) + 1)
            g.draw(sprites.splash, sprites.sq[l][f], x0 + (l - 1) * GAP + 42, y0, 0, 3, 3, 24, 24)
        end
    end
    -- El medidor
    local mx, mh = x0 + GAP * 4 + 28, 320
    g.setColor(0, 0, 0, 0.8)
    g.rectangle('fill', mx - 4, y0 - 4, 24, mh + 8)
    local v = math.max(0, c.meter) / 100
    g.setColor(1 - v, 0.25 + v * 0.65, 0.3, 1)
    g.rectangle('fill', mx, math.floor(y0 + mh * (1 - v)), 16, math.ceil(mh * v))
    -- Textos
    local L = require 'src/core/Lang'
    g.setFont(FONT_MED)
    local msg
    if c.empty then msg = nil
    elseif c.done then msg = c.failed and 'rhythm.fail' or (c.ko and 'rhythm.ko' or 'rhythm.ok')
    elseif c.clock < c.bar * c.boss.BAR then msg = 'rhythm.ready'
    elseif not c.playing then msg = 'rhythm.watch'
    elseif c.textT > 0 then msg = c.text end
    if msg then
        g.setColor(0, 0, 0, 0.85)
        g.printf(L(msg), cx - 298, y0 + 72, 600, 'center')
        g.setColor(1, 0.95, 0.4, 1)
        g.printf(L(msg), cx - 300, y0 + 70, 600, 'center')
    end
    -- Táctil: las cuatro zonas
    if Input.isMobile then
        g.setColor(1, 1, 1, 0.08)
        for l = 0, 3 do g.rectangle('line', WINDOW_W * l / 4 + 4, WINDOW_H * 0.45, WINDOW_W / 4 - 8, WINDOW_H * 0.55 - 4) end
    end
    g.setColor(1, 1, 1, 1)
    g.setFont(font)
end

return R
