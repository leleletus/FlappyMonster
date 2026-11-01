-- src/ui/RhythmDuel.lua
-- EL DUELO DE RITMO del Cangrejo Groove (docs/bosses/groovecrab.md; la idea del usuario, estilo Friday Night Funkin'): las notas
-- EXACTAS del tema (assets/charts/groove.json: tools/music/groove_chart.py) suben hacia 4 flechas quietas y hay que pulsarlas a
-- tiempo. Lo juega cada CLIENTE contra SU música (una nota no puede esperar a una instantánea) y al acabar da el resultado: en un
-- jugador, al jefe (GC:duelReport); online, un mensaje al servidor. El jefe decide lo demás: congelar, noquear, quitar vida.
-- Sin love.graphics fuera de draw.
local json = require 'libs/json'
local R = {}
local cur                                   -- el duelo en curso
local chartData
local sprites
local touchDown = {}
local NAMES = { 'rhythm_left', 'rhythm_down', 'rhythm_up', 'rhythm_right' }
local SWING = 150                           -- % del medidor que se pierde fallándolas todas en una duración entera (por eso acaba a 1/3)

local function chart()
    if chartData == nil then
        local src = love.filesystem.read('assets/charts/groove.json')
        chartData = src and json.decode(src) or false
    end
    return chartData
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
    cur = { boss = boss, bar = info.bar, bars = info.bars, cfg = cfg, notes = notes, n = n, first = 1, meter = 50,
            lose = lose, gain = lose * (1 - cfg.failAt) / cfg.failAt, hits = 0, misses = 0, playing = playing,
            clock = boss.songT or 0, endT = (info.bar + info.bars) * boss.BAR, lit = { 0, 0, 0, 0 }, text = nil, textT = 0 }
    return cur
end

function R.current() return cur end
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
            c.hits = c.hits + 1
            c.meter = math.min(100, c.meter + c.gain)
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

-- Cada frame. `report(bar, acc, failed)` da el resultado una vez. `who` = el jugador local
function R.update(dt, level, who, report, press)
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
    end
    local c = cur
    c.clock = c.clock + dt
    local a = audioTime(c)
    local target = (a or boss.songT or c.clock) - offset()
    if math.abs(target - c.clock) > 0.25 then c.clock = target
    else c.clock = c.clock + (target - c.clock) * math.min(1, dt * 8) end
    for l = 1, 4 do c.lit[l] = math.max(0, c.lit[l] - dt) end
    if c.textT > 0 then c.textT = c.textT - dt end
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
                c.text, c.textT = 'rhythm.miss', 0.5
            else break end
        end
        if c.meter <= 0 or c.clock >= c.endT then
            c.done, c.failed = true, c.meter <= 0
            c.acc = c.hits / c.n
            c.ko = not c.failed and c.acc >= c.cfg.koAt
            if report then report(c.bar, c.acc, c.failed) end
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local function load()
    if sprites then return end
    sprites = { strums = love.graphics.newImage('assets/images/ui/rhythm/strums-Sheet.png'),
                hit = love.graphics.newImage('assets/images/ui/rhythm/strums_hit-Sheet.png'),
                notes = love.graphics.newImage('assets/images/ui/rhythm/notes-Sheet.png'), q = {} }
    for _, k in ipairs({ 'strums', 'hit', 'notes' }) do sprites[k]:setFilter('nearest', 'nearest') end
    for i = 1, 4 do sprites.q[i] = love.graphics.newQuad((i - 1) * 24, 0, 24, 24, 96, 24) end
end

local SCALE, GAP = 3, 84
function R.draw()
    local c = cur
    if not c then return end
    load()
    local g = love.graphics
    local font = g.getFont()
    local cx, y0 = math.floor(WINDOW_W / 2), 150
    local x0 = cx - GAP * 2
    g.setColor(0, 0, 0, 0.35)
    g.rectangle('fill', x0 - 16, 0, GAP * 4 + 32, WINDOW_H)
    -- Quietas
    for l = 1, 4 do
        g.setColor(1, 1, 1, 1)
        g.draw(c.lit[l] > 0 and sprites.hit or sprites.strums, sprites.q[l], x0 + (l - 1) * GAP + 6, y0 - 36, 0, SCALE, SCALE)
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
    if c.done then msg = c.failed and 'rhythm.fail' or (c.ko and 'rhythm.ko' or 'rhythm.ok')
    elseif c.clock < c.bar * c.boss.BAR then msg = 'rhythm.ready'
    elseif not c.playing then msg = 'rhythm.watch'
    elseif c.textT > 0 then msg = c.text end
    if msg then
        g.setColor(0, 0, 0, 0.85)
        g.printf(L(msg), 2, y0 + 72, WINDOW_W, 'center')
        g.setColor(1, 0.95, 0.4, 1)
        g.printf(L(msg), 0, y0 + 70, WINDOW_W, 'center')
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
