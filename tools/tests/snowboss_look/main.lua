-- tools/tests/snowboss_look — capturas para revisar a ojo (sin jugar) el aspecto de la
-- Gran Bola de Nieve y de los Congeladores. Guarda en <save>/:
--   snow_intro.png   la entrada a pantalla completa (3x3): coge aire, escupe, la bola vuela
--                    hacia la cámara y se estampa
--   snow_cracks.png  fase 3 (agrietada) en todas sus poses: quieta, aplastada, escupiendo,
--                    cargando, rodando (8 ángulos), mareada, congelada, agrietándose al morir
--   snow_cryo.png    Congeladores: la arena de lago_helado y una sala con todos los casos
--                    (en el suelo, en el techo, en una pared, flotando en cada dirección)
--
--   tools/tests/run.sh snowboss_look
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local TileCodec = require 'src/world/tiles/TileCodec'
local T = TILE_PX

local clock = 0
love.timer.getTime = function() return clock end           -- (el dibujo usa este reloj)

local function lago()
    local data = json.decode(love.filesystem.read('assets/levels/lago_helado.json'))
    local level = Level.fromData(data)
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    local boss
    for _, e in ipairs(es) do if e.def.name == 'snowboss' then boss = e end end
    return level, es, boss
end

local function save(canvas, name)
    canvas:newImageData():encode('png', name)
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
end

local function sky(w, h)
    love.graphics.setColor(0.42, 0.62, 0.85, 1)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Entrada ───────────────────────────────────────────────────────────────────
local function intro()
    local level, es, boss = lago()
    local z = boss.zone
    boss.state, boss.deadTimer = 'intro', 0
    boss:onIntroStart(level, {})
    local camX = math.floor((z.x0 + z.x1) / 2 - WINDOW_W / 2)
    local camY = math.floor((z.y0 + z.y1) / 2 - WINDOW_H / 2)
    local times = { 2.9, 3.25, 3.4, 3.48, 3.56, 3.64, 3.72, 3.8, 4.3 }
    local frame = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    local out = love.graphics.newCanvas(WINDOW_W * 3 / 2, WINDOW_H * 3 / 2)
    local t = 0
    for i, tt in ipairs(times) do
        while t < tt do t = t + 1 / 60; boss.deadTimer = t; boss:updateIntro(1 / 60, level, t) end
        clock = 100 + t
        love.graphics.setCanvas(frame)
        sky(WINDOW_W, WINDOW_H)
        level:render(camX, camY)
        for _, e in ipairs(es) do if e.alive and e ~= boss then e:render(camX, camY) end end
        boss:render(camX, camY)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(('t = %.2f'):format(tt), 12, 12, 0, 2, 2)
        love.graphics.setCanvas(out)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(frame, ((i - 1) % 3) * WINDOW_W / 2, math.floor((i - 1) / 3) * WINDOW_H / 2, 0, 0.5, 0.5)
        love.graphics.setCanvas()
    end
    save(out, 'snow_intro.png')
end

-- ── Grietas (fase 3) ──────────────────────────────────────────────────────────
local function cracks()
    local level, es, boss = lago()
    boss.phase = 3
    boss:setScale(10)
    local fy = boss:feetY()
    local poses = {
        { 'idle', 0 }, { 'land', 0.05 }, { 'land', 0.2 }, { 'windup', 0.2 }, { 'shoot', 0.46 },
        { 'dizzy', 0.1 }, { 'frozen', 0.5 }, { 'dying_crack', 0.3 }, { 'dying_crack', 1.5 },
    }
    for k = 0, 7 do poses[#poses + 1] = { 'roll', 0, k } end
    local CW, CH, COLS = 220, 220, 6
    local out = love.graphics.newCanvas(CW * COLS, CH * math.ceil(#poses / COLS))
    love.graphics.setCanvas(out)
    sky(out:getWidth(), out:getHeight())
    love.graphics.setCanvas()
    for i, ps in ipairs(poses) do
        boss.state, boss.deadTimer, boss.inv = ps[1], ps[2], 0
        boss.frozenFor = 4
        local x0 = boss.home.x
        if ps[3] then
            -- ángulo k de rodar: x tal que floor(-(x / r) / (pi/4)) % 8 = k
            local r = 7 * boss.sc
            boss.x = -((ps[3] + 0.5) * math.pi / 4) * r + 8 * math.pi * 2 * r
        else
            boss.x = x0
        end
        boss.y = fy - boss.outerH / 2
        local cx, cy = ((i - 1) % COLS) * CW, math.floor((i - 1) / COLS) * CH
        local camX = math.floor(boss.x - cx - CW / 2)
        local camY = math.floor(fy - cy - CH + 30)
        clock = 50
        love.graphics.setCanvas(out)
        love.graphics.setScissor(cx, cy, CW, CH)
        boss:render(camX, camY)
        love.graphics.setScissor()
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print(ps[1] .. (ps[3] and (' ' .. ps[3]) or (' ' .. ps[2])), cx + 6, cy + 6)
        love.graphics.setCanvas()
    end
    save(out, 'snow_cracks.png')
end

-- ── Congeladores ──────────────────────────────────────────────────────────────
local function room()
    -- techo (fila 2) y suelo (fila 14); paredes; un bloque suelto
    local W, H = 30, 15
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r <= 2 or r >= 14 or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    tiles[8][15] = 1
    local ents = {
        { type = 'cryo', col = 3, row = 13, props = { dir = 'right' } },   -- en el suelo
        { type = 'cryo', col = 6, row = 3, props = { dir = 'right' } },    -- pegado al techo
        { type = 'cryo', col = 2, row = 7, props = { dir = 'down' } },     -- en la pared izquierda
        { type = 'cryo', col = 29, row = 7, props = { dir = 'down' } },    -- en la pared derecha
        { type = 'cryo', col = 10, row = 6, props = { dir = 'down' } },    -- flotando, abajo
        { type = 'cryo', col = 20, row = 6, props = { dir = 'down' } },    -- flotando (cerca de la derecha)
        { type = 'cryo', col = 13, row = 9, props = { dir = 'left' } },    -- flotando, de lado
        { type = 'cryo', col = 24, row = 10, props = { dir = 'up' } },     -- flotando, hacia arriba
        { type = 'cryo', col = 27, row = 13, props = { dir = 'up' } },     -- en el suelo, hacia arriba
        { type = 'cryo', col = 15, row = 9, props = { dir = 'down' } },    -- bajo un bloque suelto
        { type = 'cryo', col = 9, row = 3, props = { dir = 'down' } },     -- justo bajo el techo
    }
    local level = Level.fromData({ name = 'cryo', width = W, height = H, playerStart = { 2, 13 },
                                   tiles = tiles, entities = ents })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    return level, es
end

local function cryo()
    local out = love.graphics.newCanvas(1920, 1000)
    love.graphics.setCanvas(out)
    sky(1920, 1000)
    -- la sala de casos (30x15 casillas a escala 1)
    local level, es = room()
    level:render(0, 0)
    clock = 10
    for _, e in ipairs(es) do e:render(0, 0) end
    love.graphics.setCanvas()
    -- la arena de lago_helado (esquinas)
    local lv, les, boss = lago()
    local z = boss.zone
    local frame = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(frame)
    sky(WINDOW_W, WINDOW_H)
    local camX = math.floor((z.x0 + z.x1) / 2 - WINDOW_W / 2)
    local camY = math.floor(z.y0 - 2 * T)
    lv:render(camX, camY)
    for _, e in ipairs(les) do if e.def.name == 'cryo' then e:render(camX, camY) end end
    love.graphics.setCanvas(out)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(frame, 0, 960 - 0, 0, 0, 0)       -- (sitio reservado)
    love.graphics.setCanvas()
    save(out, 'snow_cryo.png')
    local out2 = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(out2)
    love.graphics.draw(frame)
    love.graphics.setCanvas()
    save(out2, 'snow_cryo_lago.png')
end

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    local only = os.getenv('ONLY')
    if not only or only == 'intro' then intro() end
    if not only or only == 'cracks' then cracks() end
    if not only or only == 'cryo' then cryo() end
    love.event.quit(0)
end
