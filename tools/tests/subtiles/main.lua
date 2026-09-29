-- tools/tests/subtiles — mini bloques (subtiles, src/world/SubTiles.lua), los
-- bloques Tierra / Césped y las partículas físicas, con el jugador real
-- (PlayerAdventure + Input de prueba), entidades reales y Particles:
--   de_pie       de pie sobre dos subtiles (mitad de abajo): pies en la mitad de la celda
--   medio_pie    un solo cuarto de arriba (TL): se sostiene si lo pisa
--   pared        andando contra una subtile a la altura del pecho: se para en su cara
--   decorativa   la misma con solid=false: la atraviesa
--   cabeza       saltando bajo dos subtiles de arriba: la cabeza no pasa de su cara
--   crabby       un Crabby que anda hacia un escalón de subtiles se da la vuelta
--   caida        landingCross (lo que cae: pinchos, jefes...) aterriza en su cara
--   part_suelo   un trozo cae, rebota y se queda quieto justo encima del suelo
--   part_agua    en el agua cae mucho más despacio que en el aire
--   part_color   colores del material: césped, tierra, piedra, madera; y el de un
--                bloque roto (lo recuerda el nivel)
--   editor       guardar y cargar en el editor: se conservan (y solid=false)
--   dibujo       Level:render con tierra, césped y subtiles no da errores
-- SHOT=1: además guarda <save>/subtiles.png a tamaño real.
--
--   tools/tests/run.sh subtiles
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Particles = require 'src/fx/Particles'
local TileTypes = require 'src/world/tiles/TileTypes'
local TileCodec = require 'src/world/tiles/TileCodec'
local T = TILE_PX

-- Sala W x H con suelo y paredes de piedra; `put` = { {col,row,tile}, ... }
local function room(W, H, put, subs, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(put or {}) do tiles[p[2]][p[1]] = TileCodec.encode(TileTypes.byName[p[3]].id, p[4]) end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {}, subtiles = subs or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    return level, es
end
local function S(col, row, sub, kind, solid) return { col = col, row = row, sub = sub, kind = kind or 'solid', solid = solid } end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end
local function run(level, pa, secs, each)
    for _ = 1, math.floor(secs * 60) do
        if each then each() end
        pa:update(1 / 60, level)
    end
end
local function feet(pa) local b = pa:getOuterBounds(); return b.y + b.h end
local function head(pa) return pa:getOuterBounds().y end

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local cases = {}

function cases.de_pie()
    local level = room(10, 10, nil, { S(4, 8, 3), S(4, 8, 4), S(5, 8, 3), S(5, 8, 4) })
    local pa = PlayerAdventure:new(4 * T, 5 * T)
    clear(); run(level, pa, 1.5)
    local want = 7 * T + T / 2
    check('de_pie', pa.onGround and math.abs(feet(pa) - want) < 1.5,
        ('suelo=%s pies=%.1f (cara %d)'):format(tostring(pa.onGround), feet(pa), want))
end

function cases.medio_pie()
    -- Solo el cuarto de arriba a la izquierda de la celda (4,8); el jugador
    -- centrado en él (su caja lo pisa)
    local level = room(10, 10, nil, { S(4, 8, 1) })
    local pa = PlayerAdventure:new(3 * T + T / 4, 5 * T)
    clear(); run(level, pa, 1.5)
    check('medio_pie', pa.onGround and math.abs(feet(pa) - 7 * T) < 1.5,
        ('suelo=%s pies=%.1f (cara %d)'):format(tostring(pa.onGround), feet(pa), 7 * T))
end

local function wallCase(name, solid)
    -- Cuarto a la altura del pecho (fila 9, TL: y 512..544), jugador andando a la derecha
    local level = room(14, 10, nil, { S(8, 9, 1, 'dirt', solid), S(8, 9, 3, 'dirt', solid) })
    local pa = PlayerAdventure:new(3.5 * T, 9 * T - 60)
    clear(); run(level, pa, 0.5)
    stub.state.right = true
    run(level, pa, 3.0)
    clear()
    local b = pa:getOuterBounds()
    return b.x + b.w, level
end
function cases.pared()
    local right = wallCase('pared', true)
    check('pared', math.abs(right - 7 * T) < 1.5, ('borde derecho del jugador %.1f (cara %d)'):format(right, 7 * T))
end
function cases.decorativa()
    local right, level = wallCase('decorativa', false)
    check('decorativa', right > 8 * T + 40 and level.subSolid == nil,
        ('borde derecho del jugador %.1f (pasa de %d); físicas=%s'):format(right, 8 * T, tostring(level.subSolid)))
end

function cases.cabeza()
    local function top(subs)
        local level = room(10, 10, nil, subs)
        local pa = PlayerAdventure:new(4 * T, 9 * T - 60)
        clear(); run(level, pa, 0.5)
        local best = 1e9
        stub.state.jump_pressed, stub.state.jump = true, true
        run(level, pa, 1.2, function() best = math.min(best, head(pa)) end)
        clear()
        return best
    end
    local face = 7 * T + T / 2                      -- cara de abajo de los cuartos de arriba de la fila 8
    local with = top({ S(4, 8, 1), S(4, 8, 2), S(5, 8, 1), S(5, 8, 2) })
    local without = top({})
    check('cabeza', with >= face - 0.5 and without < face - 20,
        ('cabeza más alta %.1f con subtiles (cara %.0f); sin ellas %.1f'):format(with, face, without))
end

function cases.crabby()
    local level, es = room(14, 10, nil, { S(9, 9, 3), S(9, 9, 4) },
        { { type = 'crabby', col = 5, row = 9, props = { speed = 120 } } })
    local e = es[1]
    level.players = {}
    e.facing, e.vx = 1, math.abs(e.vx ~= 0 and e.vx or 120)
    local maxRight, turned = 0, false
    for _ = 1, 60 * 6 do
        e:update(1 / 60, level)
        maxRight = math.max(maxRight, e.x + e.outerW / 2)
        if e.vx < 0 then turned = true end
    end
    check('crabby', turned and maxRight <= 8 * T + 1,
        ('se dio la vuelta=%s, borde derecho máximo %.1f (cara %d)'):format(tostring(turned), maxRight, 8 * T))
end

function cases.caida()
    local level = room(10, 10, nil, { S(4, 6, 2), S(4, 7, 3) })
    local t1, top1 = level:landingCross(3 * T + 48, 100, 600)       -- TR de la fila 6 → cara 320
    local t2, top2 = level:landingCross(3 * T + 16, 100, 600)       -- BL de la fila 7 → cara 416
    check('caida', t1 and top1 == 5 * T and t2 and top2 == 6 * T + T / 2,
        ('TR fila 6 → %s, BL fila 7 → %s'):format(tostring(top1), tostring(top2)))
end

-- Partícula física suelta, paso a paso
local function particle(level, x, y)
    Particles.setLevel(level)
    local p = { x = x, y = y, vx = 0, vy = 0, g = 1400, size = 6, phys = true, t = 0, life = 99 }
    return p
end
function cases.part_suelo()
    local level = room(10, 10)
    local p = particle(level, 4 * T, 5 * T)
    p.vy = 300
    local bounced = false
    for _ = 1, 60 * 3 do
        Particles.physStep(p, 1 / 60)
        if p.vy < 0 then bounced = true end
    end
    local want = 9 * T - 3
    check('part_suelo', bounced and p.ground and math.abs(p.y - want) < 0.5,
        ('rebotó=%s, en el suelo=%s, y=%.2f (esperado %.1f)'):format(tostring(bounced), tostring(p.ground), p.y, want))
end
function cases.part_agua()
    local function fall(put)
        local level = room(10, 12, put)
        local p = particle(level, 4.5 * T, 2 * T)
        local n = 0
        while p.y < 8 * T and n < 60 * 20 do Particles.physStep(p, 1 / 60); n = n + 1 end
        return n / 60
    end
    local water = {}
    for r = 2, 11 do for c = 2, 9 do water[#water + 1] = { c, r, 'water' } end end
    local tAir, tWater = fall(nil), fall(water)
    check('part_agua', tWater > tAir * 3, ('6 casillas: aire %.2f s, agua %.2f s'):format(tAir, tWater))
end
function cases.part_color()
    local level = room(12, 10, { { 3, 9, 'grass' }, { 5, 9, 'dirt' }, { 9, 9, 'platform_drop' }, { 7, 5, 'breakable' } })
    Particles.setLevel(level)
    local function same(a, b) return a == b end
    local g = same(Particles.paletteAt(2.5 * T, 8 * T), TileTypes.debris(TileTypes.byName.grass))
    local d = same(Particles.paletteAt(4.5 * T, 8 * T), TileTypes.debris(TileTypes.byName.dirt))
    local s = same(Particles.paletteAt(6.5 * T, 9 * T), TileTypes.debris(TileTypes.byName.solid))
    local w = same(Particles.paletteAt(8.5 * T, 8 * T), TileTypes.debris(TileTypes.byName.platform_drop))
    level:setTileRaw(7, 5, 0)
    local prev = level:previousDef(7, 5)
    check('part_color', g and d and s and w and prev and prev.name == 'breakable',
        ('césped=%s tierra=%s piedra=%s madera=%s; roto=%s'):format(tostring(g), tostring(d), tostring(s), tostring(w),
            prev and prev.name or 'nil'))
end

function cases.editor()
    local Model = require 'src/editor/EditorModel'
    local m = Model.new(10, 8, 'sub')
    m:setSubtile(3, 5, 2, 'grass', true)
    m:setSubtile(4, 5, 3, 'dirt', false)
    m:setSubtile(3, 5, 2, 'solid', true)                  -- (reemplaza)
    local txt = m:encode()
    local m2 = Model.fromData(json.decode(txt))
    local a, b = m2:subtileAt(3, 5, 2), m2:subtileAt(4, 5, 3)
    local noSolidKey = not txt:find('"solid":true')
    check('editor', #m2.subtiles == 2 and a and a.kind == 'solid' and a.solid and b and b.kind == 'dirt' and b.solid == false
        and noSolidKey and m2:setSubtile(4, 5, 3, nil) and #m2.subtiles == 1,
        ('guardadas %d; (3,5,2)=%s; (4,5,3)=%s decoración=%s; solid=true no se escribe=%s'):format(#m2.subtiles,
            a and a.kind or '-', b and b.kind or '-', tostring(b and b.solid == false), tostring(noSolidKey)))
end

local function scene()
    local subs = {}
    -- escalera de piedra pequeña, repisa de tierra, matas de césped y una decorativa
    for i = 0, 3 do subs[#subs + 1] = S(4 + math.floor(i / 2), 9, 3 + i % 2) end
    subs[#subs + 1] = S(5, 9, 1); subs[#subs + 1] = S(5, 9, 2); subs[#subs + 1] = S(5, 8, 4)
    for c = 8, 10 do subs[#subs + 1] = S(c, 6, 3, 'dirt'); subs[#subs + 1] = S(c, 6, 4, 'dirt') end
    subs[#subs + 1] = S(9, 6, 1, 'grass'); subs[#subs + 1] = S(9, 6, 2, 'grass')
    subs[#subs + 1] = S(13, 9, 3, 'grass'); subs[#subs + 1] = S(13, 9, 4, 'grass', false)
    subs[#subs + 1] = S(16, 7, 1, 'solid', false)
    local put = {}
    for c = 2, 19 do put[#put + 1] = { c, 10, c < 7 and 'solid' or (c < 12 and 'dirt' or 'grass') } end
    for c = 15, 18 do put[#put + 1] = { c, 9, 'grass' } end
    put[#put + 1] = { 17, 8, 'dirt' }; put[#put + 1] = { 17, 7, 'grass' }
    return room(20, 11, put, subs)
end

function cases.dibujo()
    local level = scene()
    local ok, err = pcall(function()
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas)
        level:render(0, 0)
        EDITOR_VIEW = true; level:render(0, 0); EDITOR_VIEW = nil
        level:renderDebug(0, 0)
        love.graphics.setCanvas()
    end)
    check('dibujo', ok, ok and 'sin errores' or tostring(err))
end

local shot
function love.load()
    for _, n in ipairs({ 'de_pie', 'medio_pie', 'pared', 'decorativa', 'cabeza', 'crabby', 'caida',
                         'part_suelo', 'part_agua', 'part_color', 'editor', 'dibujo' }) do cases[n]() end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    if not os.getenv('SHOT') then love.event.quit(fails == 0 and 0 or 1); return end
    love.window.setMode(1280, 720)
    local level = scene()
    Particles.clear(); Particles.setLevel(level)
    -- trozos de un bloque roto sobre la piedra, pisadas sobre tierra y césped
    Particles.emit('block_break', 3 * T, 7 * T, { def = TileTypes.byName.breakable })
    Particles.emit('mega_step', 9 * T, 10 * T - 1)
    Particles.emit('spike_land', 14 * T, 9 * T - 1)
    for _ = 1, 50 do Particles.update(1 / 60) end
    shot = { level = level, n = 0 }
end

function love.draw()
    if not shot then return end
    love.graphics.clear(0.35, 0.6, 0.85)
    shot.level:render(0, 0)
    Particles.render(0, 0)
    shot.n = shot.n + 1
    if shot.n == 3 then love.graphics.captureScreenshot(function(img) img:encode('png', 'subtiles.png') end) end
    if shot.n > 5 then
        print('captura: ' .. love.filesystem.getSaveDirectory() .. '/subtiles.png')
        love.event.quit(fails == 0 and 0 or 1)
    end
end
