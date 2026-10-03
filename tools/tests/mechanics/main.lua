-- tools/tests/mechanics — bloques ON/OFF, bloque invisible y Gummy con casco,
-- con el jugador real (PlayerAdventure + Input de prueba) y las reglas de
-- Interactions. Salas pequeñas hechas a mano. Casos:
--   onoff_head   un cabezazo cambia ON→OFF, otro OFF→ON (y va a brokenQueue)
--   onoff_pound  un ground pound encima lo cambia UNA vez y el jugador se queda encima
--   hidden_up    se atraviesa subiendo y se queda de pie encima
--   hidden_drop  agachado encima no se baja (no traspasable)
--   hidden_side  se atraviesa andando de lado
--   hidden_vis   aparece al tocarlo, sigue mientras lo toca, luego desaparece
--   helmet_jump  con casco: caer encima (muchas velocidades y desplazamientos)
--                SIEMPRE rebota, casco intacto, sin daño
--   helmet_ride  rebotando 6 s sobre uno que anda: nunca daño
--   helmet_gp    ground pound: casco roto y muerto, sin daño al jugador
--   helmet_side  de lado sí hace daño (como un Gummy normal)
--   stomp_fast   Gummy normal: caer rapidísimo encima es pisotón, no muerte
--   puffer_through el pez globo explora su área (atraviesa bloques) sin salir de ella
--   puffer_concave área cóncava en L: la recorre entera y nunca sale
--   flyer_anim     un volador nunca pasa a idle; uno de suelo sí
--   boxed_in       Gummy/Crabby encerrados (entre bloques, en un pilar): quietos, sin girarse
--   puffer_cycle   jugador en el agua cerca: aviso → hinchado (pincha 1) → deshincha
--   puffer_dry     jugador fuera del agua: no se hincha
--   bloque_roto    Gummy/Crabby encima de un bloque rompible que se rompe: muere
--                  despedido girando (dead_fling: fantasma, sube y desaparece)
--   activador      Gummy/Crabby encima de un activador ON/OFF que cambia: saltito,
--                  sigue vivo y andando
--   tramp_avanza   Crabby trepador que pisa un trampolín: sale lanzado hacia
--                  delante y sigue andando (antes rebotaba en el sitio sin fin)
--   tramp_pinchos  lanzado por un trampolín y cae en pinchos: revienta (dead_burst)
--   bomba_activa   bomba viva: tener un jugador al lado NO la enciende; tocarla
--                  andando la patea hacia donde iba y la enciende, sin daño
--   bomba_pisada   pisar la bomba viva (con ruta): rebota, la bomba sale pateada
--                  (fuera de su ruta) y se enciende; la bomba objeto igual
--   bomba_radios   explosión con jugadores a 4 distancias: muere / -1 y empujón /
--                  solo empujón / nada (y los invulnerables, nada)
--   bomba_mundo    explosión: rompe bloques rompibles (solo cerca), cambia un
--                  activador, echa a un Gummy cercano, aturde a uno más lejos y
--                  enciende otra bomba (reacción en cadena)
--   bomba_objeto   quieta: tocarla no hace daño (se enciende); lanzada contra el
--                  jugador: -1 y aturdido
--   hielo_solido   hielo fino: se está de pie a media casilla; no se atraviesa
--                  saltando desde abajo ni agachándose encima
--   hielo_desgaste de pie encima: normal → dañado → muy dañado → a punto → roto
--                  (un estado cada THIN_ICE_WEAR s) y el jugador cae; efectos y
--                  eventos de red ('crack' / 'icebreak') en cada paso
--   hielo_gp       ground pound: 3 estados de golpe (normal → a punto); otro lo rompe
--   hielo_bomba    una explosión rompe el hielo fino
--   hielo_resbala  el hielo (y el hielo fino) resbala: corriendo y soltando, se frena
--                  en mucha más distancia que en piedra; también tarda más en arrancar
--   cryo_jugador   congelador (cada X s): carga → chorro → el jugador queda congelado
--                  (no se mueve aunque pulse), se descongela solo; pulsando sale antes
--   cryo_enemigo   congela a un Crabby (cae, inofensivo), se descongela y anda; congelado
--                  y pisado muere; un Gummy volador congelado cae al suelo
--   cryo_activador modo Activador: no dispara solo; al cambiar el Activador conectado, sí
--   cryo_corte     el chorro se corta en el primer bloque sólido
--   vuelo_libre    voladores en vuelo libre: salen de un hueco, de debajo de una plataforma y de dentro
--                  de un bloque, recorren toda la sala sin pararse y se acercan al jugador
--   encerrado      un Gummy sin sitio para andar (bloques a los dos lados) pasa a
--                  reposo (idle) y NO vuelve a andar (ni un cuadro); al quitar un
--                  bloque echa a andar
--   ping_icono     antena de conexión online: niveles (verde/amarillo/rojo/X) y que
--                  no parpadee (mejorar espera 0,6 s; perder la conexión, al momento)
-- SHOT_BOMB=1: <save>/mechanics_bombs.png (bombas andando, volando, encendidas
-- a distintos tiempos, objeto y explosión).
-- SHOT=1: además guarda <save>/mechanics.png (bloques, invisible visible,
-- Gummies con y sin casco) a tamaño real.
--
--   tools/tests/run.sh mechanics
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Interactions = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local T = TILE_PX

-- Sala W x H con suelo y paredes; `put` = { {col,row,tileName}, ... }
local function room(W, H, put, ents)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, p in ipairs(put or {}) do tiles[p[2]][p[1]] = require('src/world/tiles/TileCodec').encode(_G['TILE_' .. p[3]:upper()]) end
    local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    return level, es
end

-- Jugador de pie en la casilla (col, fila de apoyo = row)
local function playerAt(level, col, row)
    local pa = PlayerAdventure:new((col - 0.5) * T, row * T - 60)
    for _ = 1, 30 do pa:update(1 / 60, level) end            -- (que se asiente)
    level.players = { pa }
    return pa
end

local function clear() for k in pairs(stub.state) do stub.state[k] = false end end
local function run(level, pa, secs, each, es)
    for _ = 1, math.floor(secs * 60) do
        if each then each() end
        pa:update(1 / 60, level)
        for _, e in ipairs(es or {}) do if e.alive then e:update(1 / 60, level) end end
        if es then Interactions.run(pa, es, {}) end
    end
end
local function name(level, c, r) return level:getDef(c, r).name end

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local cases = {}

function cases.onoff_head()
    local level = room(8, 8, { { 4, 5, 'switch_on' } })
    local pa = playerAt(level, 4, 7)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    run(level, pa, 1.0, function() end)
    local a = name(level, 4, 5)
    clear(); run(level, pa, 0.5)
    stub.state.jump_pressed = true; stub.state.jump = true
    run(level, pa, 1.0)
    local b = name(level, 4, 5)
    local q = level.brokenQueue or {}
    check('onoff_head', a == 'switch_off' and b == 'switch_on' and #q == 2 and q[1][4] == 'toggle',
        ('1º cabezazo → %s, 2º → %s, cola=%d'):format(a, b, #q))
end

function cases.onoff_pound()
    -- Bloque ON en el suelo; el jugador salta encima y hace ground pound
    local level = room(8, 8, { { 4, 7, 'switch_on' } })
    local pa = playerAt(level, 4, 6)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    local t = 0
    run(level, pa, 1.4, function()
        t = t + 1
        if t == 16 then stub.state.jump = false; stub.state.crouch_pressed = true end
    end)
    local q = level.brokenQueue or {}
    check('onoff_pound', name(level, 4, 7) == 'switch_off' and #q == 1 and pa.onGround and pa.y < 6 * T,
        ('→ %s, cambios=%d, de pie encima=%s'):format(name(level, 4, 7), #q, tostring(pa.onGround and pa.y < 6 * T)))
end

function cases.hidden_up()
    local level = room(8, 9, { { 4, 6, 'hidden_block' } })          -- (a 2 casillas sobre la cabeza)
    local pa = playerAt(level, 4, 8)
    clear(); stub.state.jump_pressed = true; stub.state.jump = true
    local t = 0
    run(level, pa, 2.0, function()
        t = t + 1
        if t == 26 then stub.state.jump_pressed = true end        -- doble salto en lo alto: pasa del todo
        if os.getenv('TRACE') and t % 4 == 0 then
            local b = pa:getOuterBounds()
            print(('    t=%2d pies=%d vy=%d suelo=%s saltos=%s'):format(t, b.y + b.h, pa.vy, tostring(pa.onGround), tostring(pa.jumpsLeft)))
        end
    end)
    local top = 5 * T
    check('hidden_up', pa.onGround and math.abs((pa:getOuterBounds().y + pa:getOuterBounds().h) - top) < 2,
        ('en el suelo=%s, pies=%d (cara de arriba %d)'):format(tostring(pa.onGround),
            pa:getOuterBounds().y + pa:getOuterBounds().h, top))
end

function cases.hidden_drop()
    local level = room(8, 9, { { 4, 5, 'hidden_block' } })
    local pa = PlayerAdventure:new(3.5 * T, 4 * T - 60)
    level.players = { pa }
    clear(); run(level, pa, 0.6)
    local y0 = pa.y
    stub.state.crouch = true
    run(level, pa, 1.2)
    check('hidden_drop', pa.onGround and math.abs(pa.y - y0) < 30,
        ('agachado 1,2 s: y %d → %d'):format(y0, pa.y))
end

function cases.hidden_side()
    local level = room(10, 8, { { 5, 7, 'hidden_block' }, { 5, 6, 'hidden_block' } })
    -- (suelo bajo la columna invisible: la fila 7 es la de apoyo → se usa la 8 como suelo)
    level, _ = room(10, 9, { { 5, 8, 'hidden_block' }, { 5, 7, 'hidden_block' } })
    local pa = playerAt(level, 3, 8)
    local x0 = pa.x
    clear(); stub.state.right = true
    run(level, pa, 1.5)
    check('hidden_side', pa.x > 6 * T, ('x %d → %d (la columna invisible está en %d..%d)'):format(x0, pa.x, 4 * T, 5 * T))
end

function cases.hidden_vis()
    local level = room(8, 9, { { 4, 5, 'hidden_block' } })
    local pa = PlayerAdventure:new(3.5 * T, 4 * T - 60)
    level.players = { pa }
    clear()
    local function step(s)
        for _ = 1, math.floor(s * 60) do pa:update(1 / 60, level); level:updateHiddenBlocks(1 / 60, { pa:getOuterBounds() }) end
    end
    step(0.5)
    local key = 5 * 65536 + 4
    local seen = level.hiddenVis and level.hiddenVis[key] ~= nil
    step(3)
    local still = level.hiddenVis[key] ~= nil
    pa.x = 7 * T                                     -- se va
    step(0.5)
    local blinking = level.hiddenVis[key] ~= nil
    step(1.0)
    local gone = level.hiddenVis[key] == nil
    check('hidden_vis', seen and still and blinking and gone,
        ('al tocar=%s, 3 s encima=%s, al irse (0,5 s)=%s, luego=%s'):format(tostring(seen), tostring(still),
            tostring(blinking), gone and 'invisible' or 'visible'))
end

local function gummyRoom(helmet, movement)
    return room(12, 8, {}, { { type = 'gummy', col = 6, row = 7,
        props = { helmet = helmet, movement = movement or 'static', points = 10, patrol = { left = 3, right = 10 } } } })
end

-- Suelta al jugador encima del Gummy (dx px de lado, velocidad vy, ground
-- pound si gp) y simula como el juego (jugador, entidad, Interactions.run)
-- hasta `secs`. Devuelve lo que pasó.
local function dropOn(g, level, dx, vy, gp, secs)
    local pa = PlayerAdventure:new(g.x + dx, g.y - 170)
    level.players = { pa }
    pa.vy, pa.onGround = vy, false
    if gp then pa.gpPhase, pa.gpT = 'fall', 0 end
    local out = { bounces = 0, hp0 = pa.hp, results = {} }
    clear()
    for _ = 1, math.floor((secs or 1) * 60) do
        pa:update(1 / 60, level)
        if g.alive then g:update(1 / 60, level) end
        local r = Interactions.check(pa, g)
        if r then out.results[r] = (out.results[r] or 0) + 1 end
        Interactions.run(pa, { g }, {})
        if r == 'helmet' then out.bounces = out.bounces + 1 end
        if pa.dying then break end
    end
    out.pa = pa
    return out
end

-- Saltar encima: SIEMPRE rebota, casco intacto, jugador sin daño (muchas
-- caídas: de lado a lado del casco y de lentas a muy rápidas)
function cases.helmet_jump()
    local bad, n = {}, 0
    for _, vy in ipairs({ 60, 300, 700, 1100, 1500, 2000 }) do
        for dx = -40, 40, 8 do
            local level, es = gummyRoom(true)
            local g = es[1]
            local o = dropOn(g, level, dx, vy, false, 0.6)
            n = n + 1
            if o.pa.dying or o.pa.hp < o.hp0 or not g.helmet or g.state == 'dead' or o.bounces < 1 then
                bad[#bad + 1] = ('vy=%d dx=%d: rebotes=%d vida %d→%d %s casco=%s gummy=%s'):format(vy, dx, o.bounces,
                    o.hp0, o.pa.hp, o.pa.dying and 'MUERTO' or '', tostring(g.helmet), g.state)
            end
        end
    end
    check('helmet_jump', #bad == 0, ('%d caídas, %d mal%s'):format(n, #bad, #bad > 0 and (': ' .. bad[1]) or ''))
end

-- Rebotando encima de un Gummy con casco que anda (sin tocar nada) 6 s
function cases.helmet_ride()
    local level, es = gummyRoom(true, 'walk')
    local g = es[1]
    local o = dropOn(g, level, 0, 300, false, 6)
    check('helmet_ride', not o.pa.dying and o.pa.hp == o.hp0 and g.helmet and g.state ~= 'dead',
        ('rebotes=%d, jugador %s vida %d, casco=%s'):format(o.bounces, o.pa.dying and 'MUERTO' or 'vivo', o.pa.hp,
            tostring(g.helmet)))
end

-- Ground pound encima: casco roto y Gummy muerto; jugador sin daño
function cases.helmet_gp()
    local bad, n = {}, 0
    for dx = -36, 36, 12 do
        local level, es = gummyRoom(true)
        local g = es[1]
        local o = dropOn(g, level, dx, 900, true, 0.8)
        n = n + 1
        if g.state ~= 'dead' or g.helmet or o.pa.dying or o.pa.hp < o.hp0 then
            bad[#bad + 1] = ('dx=%d: gummy=%s casco=%s jugador %s vida %d'):format(dx, g.state, tostring(g.helmet),
                o.pa.dying and 'MUERTO' or 'vivo', o.pa.hp)
        end
    end
    check('helmet_gp', #bad == 0, ('%d ground pounds, %d mal%s'):format(n, #bad, #bad > 0 and (': ' .. bad[1]) or ''))
end

-- De lado: le hace daño (como un Gummy normal)
function cases.helmet_side()
    local level, es = gummyRoom(true)
    local g = es[1]
    local pa = playerAt(level, 3, 7)
    clear(); stub.state.right = true
    local hurt = false
    for _ = 1, 120 do
        pa:update(1 / 60, level); Interactions.run(pa, { g }, {})
        if pa.dying or pa.hp < 3 then hurt = true; break end
    end
    check('helmet_side', hurt and g.helmet, ('andar contra él: daño=%s, casco=%s'):format(tostring(hurt), tostring(g.helmet)))
end

-- Gummy normal: caer muy rápido encima es pisotón, no muerte (antes podía
-- saltarse la franja de pisotón en un paso)
function cases.stomp_fast()
    local bad = {}
    for _, vy in ipairs({ 300, 900, 1500, 2000 }) do
        for dx = -30, 30, 10 do
            local level, es = gummyRoom(false)
            local g = es[1]
            local o = dropOn(g, level, dx, vy, false, 0.6)
            if g.state ~= 'dead' or o.pa.dying then
                bad[#bad + 1] = ('vy=%d dx=%d: gummy=%s jugador %s'):format(vy, dx, g.state, o.pa.dying and 'MUERTO' or 'vivo')
            end
        end
    end
    check('stomp_fast', #bad == 0, (#bad == 0 and 'todas las caídas lo pisotean' or (#bad .. ' mal: ' .. bad[1])))
end

-- ── Pez globo ────────────────────────────────────────────────────────────────
-- Estanque de agua con una columna de bloques en medio de su ruta
local function pond(area)
    local W, H = 16, 9
    local put = {}
    for r = 3, 8 do for c = 2, W - 1 do put[#put + 1] = { c, r, 'water' } end end
    for r = 4, 6 do put[#put + 1] = { 9, r, 'solid' } end
    return room(W, H, put, { { type = 'pufferfish', col = 5, row = 5,
        props = { area = area or { { col = 3, row = 4 }, { col = 14, row = 4 }, { col = 14, row = 7 }, { col = 3, row = 7 } },
                  speed = 60, range = 2.5, warnTime = 0.6, inflateTime = 2.5 } } })
end

-- Punto dentro del polígono de casillas (centros), con margen `m` px
local function inPoly(area, x, y, m)
    local poly = {}
    for _, q in ipairs(area) do poly[#poly + 1] = { (q.col - 0.5) * T, (q.row - 0.5) * T } end
    local function ins(px, py)
        local c, j = false, #poly
        for i = 1, #poly do
            local a, b = poly[i], poly[j]
            if (a[2] > py) ~= (b[2] > py) and px < (b[1] - a[1]) * (py - a[2]) / (b[2] - a[2]) + a[1] then c = not c end
            j = i
        end
        return c
    end
    return ins(x, y) or ins(x - m, y) or ins(x + m, y) or ins(x, y - m) or ins(x, y + m)
end

-- Explora su área (rectángulo con una columna de bloques en medio): la
-- atraviesa y pasa por muchas casillas distintas sin salir nunca
function cases.puffer_through()
    local level, es = pond()
    local f = es[1]
    level.players = {}
    local cells, n, out = {}, 0, 0
    local minX, maxX = f.x, f.x
    for _ = 1, 60 * 40 do
        f:update(1 / 60, level)
        minX, maxX = math.min(minX, f.x), math.max(maxX, f.x)
        local k = math.floor(f.px / T) .. ',' .. math.floor(f.py / T)
        if not cells[k] then cells[k] = true; n = n + 1 end
        if not inPoly(f.props.area, f.px, f.py, 3) then out = out + 1 end
    end
    check('puffer_through', maxX > 10 * T and minX < 5 * T and n >= 12 and out == 0 and f.state == 'walk',
        ('x %d..%d (columna en %d..%d), %d casillas visitadas, fuera del área %d veces'):format(minX, maxX, 8 * T, 9 * T, n, out))
end

-- Área cóncava en L: nunca sale de ella (no corta por la esquina de fuera)
function cases.puffer_concave()
    local L = { { col = 3, row = 4 }, { col = 14, row = 4 }, { col = 14, row = 5 }, { col = 5, row = 5 },
                { col = 5, row = 8 }, { col = 3, row = 8 } }
    local level, es = pond(L)
    local f = es[1]
    f.x, f.y = 4 * T, 4 * T; f.home.x, f.home.y = f.x, f.y; f.px, f.py = f.x, f.y
    level.players = {}
    local out, legs = 0, { top = false, left = false }
    for _ = 1, 60 * 60 do
        f:update(1 / 60, level)
        if not inPoly(L, f.px, f.py, 3) then out = out + 1 end
        if f.px > 9 * T then legs.top = true end
        if f.py > 6.5 * T then legs.left = true end
    end
    check('puffer_concave', out == 0 and legs.top and legs.left,
        ('fuera del área %d veces; recorre el brazo de arriba=%s y el de abajo=%s'):format(out, tostring(legs.top), tostring(legs.left)))
end

-- Encerrados: entre dos bloques (o en un pilar de una casilla, con bordes a
-- los dos lados) se quedan quietos, sin girarse; con sitio, vuelven a andar
cases.boxed_in = function()
    local res = {}
    for _, kind in ipairs({ 'gummy', 'crabby' }) do
        local level, es = room(12, 8, { { 5, 7, 'solid' }, { 7, 7, 'solid' } },
            { { type = kind, col = 6, row = 7, props = { pauses = false, speed = 60 } } })
        level.players = {}
        local e = es[1]
        for _ = 1, 30 do e:update(1 / 60, level) end      -- (cae y se asienta)
        local flips, x0, facing = 0, nil, e.facing
        for _ = 1, 60 * 4 do
            e:update(1 / 60, level)
            if e.facing ~= facing then flips = flips + 1; facing = e.facing end
            x0 = x0 or e.x
        end
        local still = math.abs(e.x - x0) < 1
        level.tiles[7][7] = TILE_EMPTY                  -- se abre la derecha
        local xa = e.x
        for _ = 1, 60 * 3 do e:update(1 / 60, level) end
        res[#res + 1] = { kind = kind, flips = flips, still = still, moved = math.abs(e.x - xa) }
    end
    -- pilar de una casilla con bordes a los dos lados
    local level, es = room(12, 8, { { 6, 6, 'solid' } }, { { type = 'gummy', col = 6, row = 5, props = { pauses = false } } })
    level.players = {}
    local g = es[1]
    for _ = 1, 30 do g:update(1 / 60, level) end
    local gx, gflips, gf = g.x, 0, g.facing
    for _ = 1, 60 * 3 do g:update(1 / 60, level); if g.facing ~= gf then gflips = gflips + 1; gf = g.facing end end
    local ok = res[1].flips == 0 and res[1].still and res[1].moved > 40 and res[2].flips == 0 and res[2].still
               and res[2].moved > 40 and gflips == 0 and math.abs(g.x - gx) < 1
    check('boxed_in', ok, ('gummy: giros %d quieto=%s, luego anda %d px · crabby: giros %d quieto=%s, anda %d px · pilar: giros %d'):format(
        res[1].flips, tostring(res[1].still), res[1].moved, res[2].flips, tostring(res[2].still), res[2].moved, gflips))
end

-- Enemigo de pie sobre una fila de 3 bloques `tile` (cols 5-7, fila 6)
local function onBlocks(kind, tile)
    local level, es = room(12, 8, { { 5, 6, tile }, { 6, 6, tile }, { 7, 6, tile } },
        { { type = kind, col = 6, row = 5, props = { pauses = false, speed = 20 } } })
    level.players = {}
    local e = es[1]
    for _ = 1, 40 do e:update(1 / 60, level) end        -- (cae y se asienta)
    return level, es, e
end

function cases.bloque_roto()
    local parts, ok = {}, true
    for _, kind in ipairs({ 'gummy', 'crabby' }) do
        local level, es, e = onBlocks(kind, 'breakable')
        local y0, stood = e.y, e.onGround
        level:hitTile(6, 6, 'head')
        local st, ghost = e.state, e:isGhost()
        local maxUp = 0
        for _ = 1, 60 * 2.5 do
            if e.alive then e:update(1 / 60, level) end
            maxUp = math.max(maxUp, y0 - e.y)
        end
        local good = stood and st == 'dead_fling' and ghost and maxUp > 60 and not e.alive
        ok = ok and good
        parts[#parts + 1] = ('%s: de pie=%s → %s fantasma=%s sube %d px, desaparece=%s'):format(kind, tostring(stood), st,
            tostring(ghost), maxUp, tostring(not e.alive))
    end
    check('bloque_roto', ok, table.concat(parts, ' · '))
end

function cases.activador()
    local parts, ok = {}, true
    for _, kind in ipairs({ 'gummy', 'crabby' }) do
        local level, es, e = onBlocks(kind, 'switch_on')
        level:hitTile(6, 6, 'head')
        local vy = e.vy
        for _ = 1, 60 * 2 do e:update(1 / 60, level) end
        local good = vy < -100 and e.alive and (e.state == 'walk' or e.state == 'idle') and e.onGround ~= nil
        ok = ok and good
        parts[#parts + 1] = ('%s: vy %d, luego %s vivo=%s'):format(kind, vy, e.state, tostring(e.alive))
    end
    check('activador', ok, table.concat(parts, ' · '))
end

-- Sala con un trampolín hacia arriba en (7, 7) y un Crabby trepador que va hacia él
local function trampRoom(extra)
    local level, es = room(18, 8, {}, { { type = 'trampoline', col = 7, row = 7 },
        { type = 'crabby', col = 4, row = 7, props = { pauses = false, speed = 110, wallWalk = true, startDir = 'right' } } })
    level.players = {}
    if extra then extra(level) end
    return level, es
end
local function stepAll(level, es, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.solidBodies = Entities.solidBodies(es)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
        if each then each() end
    end
end

function cases.tramp_avanza()
    local level, es = trampRoom()
    local c = es[2]
    local launches, wasL, firstLand = 0, false, nil
    local tx = 6.5 * T
    stepAll(level, es, 5, function()
        local l = c.state == 'launched'
        if l and not wasL then launches = launches + 1 end
        if wasL and not l and not firstLand then firstLand = c.x end
        wasL = l
    end)
    check('tramp_avanza', launches >= 1 and launches <= 2 and firstLand and firstLand - tx > 0.8 * T,   -- (hacia DELANTE)
        ('lanzamientos en 5 s: %d; aterrizó a %.1f casillas del trampolín'):format(launches,
            firstLand and math.abs(firstLand - tx) / T or -1))
end

function cases.tramp_pinchos()
    local TileCodec = require 'src/world/tiles/TileCodec'
    local level, es = trampRoom(function(level)
        -- pinchos en el suelo, a la derecha del trampolín (cols 8-13)
        local up = { present = true, dir = TileCodec.DIR_UP }
        for c = 8, 13 do level.tiles[7][c] = TileCodec.encode(0, false, { nil, nil, up, up }) end
    end)
    local c = es[2]
    local burst, ghost = false, false
    stepAll(level, es, 4, function()
        if c.state == 'dead_burst' and not burst then burst, ghost = true, c:isGhost() end
        if os.getenv('TRACE_CRAB') and c.state ~= lastSt then print(('    %s x=%d y=%d vx=%d'):format(c.state, c.x, c.y, c.vx or 0)); lastSt = c.state end
    end)
    check('tramp_pinchos', burst and ghost and not c.alive,
        ('revienta=%s fantasma=%s desaparece=%s'):format(tostring(burst), tostring(ghost), tostring(not c.alive)))
end

-- ── Bombas ────────────────────────────────────────────────────────────────────
local function bombRoom(ents, put)
    local level, es = room(24, 9, put or {}, ents)
    level.players = {}
    return level, es
end
local function stepEnts(level, es, secs, each)
    for _ = 1, math.floor(secs * 60) do
        level.solidBodies = Entities.solidBodies(es)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each then each() end
    end
end

function cases.bomba_activa()
    local level, es = bombRoom({ { type = 'bomb', col = 8, row = 8, props = { pauses = false, speed = 0 } } })
    local b = es[1]
    stepEnts(level, es, 0.5)
    -- un jugador parado justo al lado: NO la enciende (nunca por cercanía)
    local pn = PlayerAdventure:new(b.x - 0.9 * T, b.y)
    level.players = { pn }
    stepEnts(level, es, 1.0)
    local near = b.state
    -- otro que anda hacia ella: la patea hacia donde iba (derecha), sin daño
    local pa = playerAt(level, 5, 8)
    level.players = { pa }
    local hp0, x0 = pa.hp, b.x
    clear(); stub.state.right = true
    local kickedAt
    for i = 1, 60 * 1.2 do
        pa:update(1 / 60, level)
        stepEnts(level, es, 1 / 60)
        if b.state == 'lit' and not kickedAt then kickedAt = true end
    end
    clear()
    check('bomba_activa', near ~= 'lit' and kickedAt and b.x - x0 > T and pa.hp == hp0,
        ('jugador al lado: %s (no se enciende) · al tocarla: %s, pateada %.1f casillas hacia donde iba; vida %d → %d'):format(
            near, b.state, (b.x - x0) / T, hp0, pa.hp))
end

function cases.bomba_pisada()
    local parts, ok = {}, true
    for _, kind in ipairs({ 'bomb', 'bombobject' }) do
        local level, es = bombRoom({ { type = kind, col = 8, row = 8,
            props = { pauses = false, speed = 0, patrol = { left = 7, right = 9 }, fuseTime = 5 } } })
        local b = es[1]
        stepEnts(level, es, 0.4)
        local pa = PlayerAdventure:new(b.x - 30, b.y - 90)
        level.players = { pa }
        pa.vy = 300
        local bounced, x0 = false, b.x
        for i = 1, 60 do
            pa:update(1 / 60, level)
            stepEnts(level, es, 1 / 60)
            if os.getenv('TRACE_BOMB') and i % 4 == 0 then print(('    %s t=%d x=%d y=%d vx=%d vy=%d suelo=%s %s'):format(kind, i, b.x, b.y, b.vx, b.vy, tostring(b.onGround), b.state)) end
            if pa.vy < -100 and not bounced then bounced = true end
        end
        local moved = math.abs(b.x - x0) / T
        local good = bounced and b.state == 'lit' and moved > 1 and pa.hp == pa.hpMax
        ok = ok and good
        parts[#parts + 1] = ('%s: rebota=%s %s, pateada %.1f casillas'):format(kind, tostring(bounced), b.state, moved)
    end
    check('bomba_pisada', ok, table.concat(parts, ' · '))
end

-- Enciende la bomba `b` con mecha corta y avanza hasta que explote
local function detonate(level, es, b, secs)
    require('src/world/entities/BombCore').light(b, 0.1)
    local exploded = false
    stepEnts(level, es, secs or 0.5, function() if b.state == 'exploding' then exploded = true end end)
    return exploded
end

function cases.bomba_radios()
    local level, es = bombRoom({ { type = 'bombobject', col = 12, row = 8 } })
    local b = es[1]
    stepEnts(level, es, 0.3)
    -- jugadores a 0.6, 1.8, 3.0 y 5 casillas (borde de su caja), y uno invulnerable a 0.6
    local function at(d, side)
        local pa = PlayerAdventure:new(0, 0)
        local ob = pa:getOuterBounds()
        pa.x = b.x + side * (d * T + (pa.x - ob.x))
        pa.y = b.y
        return pa
    end
    local p1, p2, p3, p4, p5 = at(0.6, -1), at(1.8, 1), at(3.0, -1), at(5, 1), at(0.6, 1)
    p5.invT = 3
    level.players = { p1, p2, p3, p4, p5 }
    local ex = detonate(level, es, b, 0.3)
    local r = ('muy cerca: muere=%s · medio: vida %d/%d vx %d · lejos: vida %d vx %d · fuera: vx %d · invulnerable cerca: muere=%s'):format(
        tostring(p1.dying), p2.hp, p2.hpMax, p2.vx, p3.hp, p3.vx, p4.vx, tostring(p5.dying))
    check('bomba_radios', ex and p1.dying and p2.hp == p2.hpMax - 1 and p2.vx > 200 and p3.hp == p3.hpMax
          and p3.vx < -100 and math.abs(p4.vx) < 1 and not p5.dying and p5.hp == p5.hpMax, r)
end

function cases.bomba_mundo()
    local level, es = bombRoom({
        { type = 'bombobject', col = 12, row = 8 },
        { type = 'gummy', col = 10, row = 8, props = { pauses = false, speed = 0 } },
        { type = 'crabby', col = 15, row = 8, props = { pauses = false, speed = 0 } },
        { type = 'bombobject', col = 14, row = 8, props = { fuseTime = 3 } },
    }, { { 12, 6, 'breakable' }, { 11, 7, 'breakable' }, { 20, 7, 'breakable' }, { 13, 7, 'switch_on' } })
    local b, g, c, b2 = es[1], es[2], es[3], es[4]
    stepEnts(level, es, 0.3)
    detonate(level, es, b, 0.25)
    local near, nearB, far = name(level, 12, 6), name(level, 11, 7), name(level, 20, 7)
    local sw = name(level, 13, 7)
    local gs, cs = g.state, c.state
    local chain = false
    stepEnts(level, es, 1.5, function() if b2.state == 'exploding' then chain = true end end)
    check('bomba_mundo', near ~= 'breakable' and nearB ~= 'breakable' and far == 'breakable' and sw == 'switch_off'
          and gs == 'dead_fling' and cs == 'stunned' and chain,
        ('bloques cerca: %s,%s lejos: %s · activador: %s · gummy: %s · crabby: %s · cadena: %s'):format(
            near, nearB, far, sw, gs, cs, tostring(chain)))
end

function cases.bomba_objeto()
    local level, es = bombRoom({ { type = 'bombobject', col = 10, row = 8, props = { fuseTime = 5 } } })
    local b = es[1]
    stepEnts(level, es, 0.3)
    local pa = playerAt(level, 8, 8)
    level.players = { pa }
    clear(); stub.state.right = true
    for _ = 1, 50 do pa:update(1 / 60, level); stepEnts(level, es, 1 / 60) end
    clear()
    local stillOk = pa.hp == pa.hpMax and b.state == 'lit'
    -- otra, lanzada contra un jugador
    local level2, es2 = bombRoom({ { type = 'bombobject', col = 4, row = 4, props = { fuseTime = 5 } } })
    local b2 = es2[1]
    local pb = playerAt(level2, 8, 8)
    level2.players = { pb }
    local tt = 0.6                                 -- (tiro parabólico que le cae encima en 0,6 s)
    b2:throw((pb.x - b2.x) / tt, (pb.y - b2.y - 0.5 * ADV_GRAVITY * tt * tt) / tt, false)
    local hit, stunned = false, false
    for _ = 1, 60 do
        pb:update(1 / 60, level2)
        stepEnts(level2, es2, 1 / 60)
        if pb.hp < pb.hpMax and not hit then hit = true; stunned = (pb.stunT or 0) > 0 end
    end
    check('bomba_objeto', stillOk and hit and stunned and b2.state == 'lit',
        ('quieta: vida %d/%d, %s · lanzada: golpea=%s aturde=%s, %s'):format(pa.hp, pa.hpMax, b.state,
            tostring(hit), tostring(stunned), b2.state))
end

-- ── Hielo fino ───────────────────────────────────────────────────────────────
local function iceRoom()
    -- losa de hielo fino de 5 casillas (cols 6-10) en la fila 5, con aire debajo
    local level, es = room(16, 9, { { 6, 5, 'thin_ice' }, { 7, 5, 'thin_ice' }, { 8, 5, 'thin_ice' },
                                    { 9, 5, 'thin_ice' }, { 10, 5, 'thin_ice' } })
    level.players = {}
    local fx = {}
    level.tileFx = function(kind, c, r) fx[#fx + 1] = kind end
    return level, fx
end

function cases.hielo_solido()
    local level = iceRoom()
    -- de pie encima (cae desde arriba): pies a media casilla
    local pa = PlayerAdventure:new(8 * T - 32, 2 * T)
    level.players = { pa }
    clear()
    for _ = 1, 60 do pa:update(1 / 60, level) end
    local feetY = pa:getOuterBounds().y + pa:getOuterBounds().h
    local onTop = pa.onGround and math.abs(feetY - 4 * T) < 2
    -- agachado encima: no baja
    stub.state.crouch = true
    for _ = 1, 40 do pa:update(1 / 60, level) end
    stub.state.crouch = false
    local stayed = pa:getOuterBounds().y + pa:getOuterBounds().h <= 4 * T + 2
    -- desde abajo saltando: choca con la cara de abajo (media casilla)
    local pb = PlayerAdventure:new(8 * T - 32, 8 * T - 60)
    level.players = { pb }
    for _ = 1, 20 do pb:update(1 / 60, level) end
    stub.state.jump_pressed = true; pb:update(1 / 60, level); stub.state.jump_pressed = false
    local minHead = math.huge
    for i = 1, 50 do
        stub.state.jump_pressed = (i == 14)            -- doble salto: sin el hielo llegaría más arriba
        pb:update(1 / 60, level); minHead = math.min(minHead, pb:getOuterBounds().y)
    end
    clear()
    local blocked = minHead >= 4.5 * T - 1
    check('hielo_solido', onTop and stayed and blocked,
        ('de pie a media casilla=%s (pies %d, cara %d) · agachado no baja=%s · desde abajo la cabeza para en %d (cara de abajo %d)'):format(
            tostring(onTop), feetY, 4 * T, tostring(stayed), minHead, 4.5 * T))
end

function cases.hielo_desgaste()
    local level, fx = iceRoom()
    local pa = PlayerAdventure:new(8 * T - 32, 2 * T)
    level.players = { pa }
    clear()
    local seen, t, brokeAt, fellBy = {}, 0, nil, nil
    for i = 1, 60 * 5 do
        pa:update(1 / 60, level)
        level:update(1 / 60)
        t = t + 1 / 60
        local n = name(level, 8, 5)
        if seen[#seen] ~= n then seen[#seen + 1] = n end
        if n == 'empty' and not brokeAt then brokeAt = t end
    end
    local fell = pa.y > 5 * T
    local q = level.brokenQueue or {}
    local kinds = {}
    for _, b in ipairs(q) do kinds[#kinds + 1] = b[4] end
    local want = { 'thin_ice', 'thin_ice_1', 'thin_ice_2', 'thin_ice_3', 'empty' }
    local ok = #seen == 5 and fell and brokeAt and brokeAt > 3 and brokeAt < 3.6
    for i = 1, 5 do ok = ok and seen[i] == want[i] end
    check('hielo_desgaste', ok and #fx >= 4,
        ('estados: %s · roto a los %.1f s · el jugador cae=%s · efectos %s'):format(table.concat(seen, ' → '),
            brokeAt or -1, tostring(fell), table.concat(fx, ',')))
end

function cases.hielo_gp()
    local level, fx = iceRoom()
    local function gp(col)
        local pa = PlayerAdventure:new(col * T - 32, 2 * T)
        level.players = { pa }
        pa.vy, pa.gpPhase, pa.gpT = 0, 'fall', 0
        for _ = 1, 50 do pa:update(1 / 60, level) end
        return pa
    end
    gp(8)
    local a = name(level, 8, 5)
    gp(8)
    local b = name(level, 8, 5)
    check('hielo_gp', a == 'thin_ice_3' and b == 'empty',
        ('primer ground pound: %s (3 estados) · segundo: %s'):format(a, b))
end

function cases.hielo_bomba()
    local level, es = room(16, 9, { { 7, 7, 'thin_ice' }, { 8, 7, 'thin_ice' } },
        { { type = 'bombobject', col = 8, row = 8 } })
    level.players = {}
    stepEnts(level, es, 0.3)
    require('src/world/entities/BombCore').light(es[1], 0.1)
    stepEnts(level, es, 0.3)
    check('hielo_bomba', name(level, 7, 7) == 'empty' and name(level, 8, 7) == 'empty',
        ('hielo fino tras la explosión: %s, %s'):format(name(level, 7, 7), name(level, 8, 7)))
end

function cases.hielo_resbala()
    local function run(kind)
        -- suelo de 24 casillas del material en la fila 8
        local put = {}
        for c = 2, 23 do put[#put + 1] = { c, 8, kind } end
        local level = room(25, 9, put)
        local pa = PlayerAdventure:new(4 * T, 7 * T - 50)
        level.players = { pa }
        clear()
        for _ = 1, 40 do pa:update(1 / 60, level) end           -- (se posa)
        local x0 = pa.x
        stub.state.right = true
        local tAccel
        for i = 1, 120 do
            pa:update(1 / 60, level)
            if not tAccel and pa.vx >= ADV_MOVE_SPD * 0.9 then tAccel = i / 60 end
        end
        stub.state.right = false
        local xs = pa.x
        for _ = 1, 180 do pa:update(1 / 60, level) end
        clear()
        return pa.x - xs, tAccel or 9
    end
    local dStone, aStone = run('solid')
    local dIce, aIce = run('ice')
    local dThin, aThin = run('thin_ice')
    check('hielo_resbala', dIce > dStone * 3 and dThin > dStone * 3 and aIce > aStone * 2,
        ('frenada: piedra %d px, hielo %d px, hielo fino %d px · arrancar: piedra %.2f s, hielo %.2f s'):format(
            dStone, dIce, dThin, aStone, aIce))
end

-- Sala del congelador: suelo en la fila 9, congelador en (3, 8) mirando a la derecha
local function cryoRoom(props, put, ents)
    local list = { { type = 'cryo', col = 3, row = 8, props = props } }
    for _, e in ipairs(ents or {}) do list[#list + 1] = e end
    local level, es = room(20, 9, put, list)
    level.players = {}
    return level, es, es[1]
end

function cases.cryo_jugador()
    local function trial(mashEvery)
        local level, es, cryo = cryoRoom({ firstDelay = 0.3, interval = 60, windup = 0.5, freezeTime = 3 })
        local pa = playerAt(level, 8, 8)
        clear()
        local seen, frozenFor, moved, x0 = {}, 0, 0, nil
        local n = 0
        stepEnts(level, es, 6, function()
            n = n + 1
            seen[cryo.state] = true
            stub.state.right = (pa.iceT or 0) > 0                 -- (intenta andar congelado)
            if (pa.iceT or 0) > 0 then
                frozenFor = frozenFor + 1 / 60
                x0 = x0 or pa.x
                moved = math.max(moved, math.abs(pa.x - x0))
                if mashEvery and n % mashEvery == 0 then stub.state.jump_pressed = true end
            end
            pa:update(1 / 60, level)
        end)
        clear()
        return seen, frozenFor, moved
    end
    local seen, tFree, moved = trial(nil)
    local _, tMash = trial(8)
    check('cryo_jugador', seen.windup and seen.fire and tFree > 2.7 and tFree < 3.3 and moved < 8 and tMash < tFree * 0.5,
        ('estados carga=%s chorro=%s · congelado %.2f s (se mueve %d px pulsando →) · pulsando saltar %.2f s'):format(
            tostring(seen.windup), tostring(seen.fire), tFree, moved, tMash))
end

function cases.cryo_enemigo()
    -- Crabby andando delante del congelador
    local level, es, cryo = cryoRoom({ firstDelay = 0.2, interval = 60, windup = 0.3, freezeTime = 2 }, nil,
        { { type = 'crabby', col = 8, row = 8, props = { pauses = false, speed = 40 } } })
    local c = es[2]
    local froze, thawed
    stepEnts(level, es, 4, function()
        if c.state == 'frozen' then froze = true end
        if froze and c.state == 'walk' then thawed = true end
    end)
    -- Otra vez congelado y pisado desde arriba: muere
    c.alive, c.state = true, 'walk'
    c:freeze(3)
    local pa = PlayerAdventure:new(c.x, c.y - 140)
    level.players = { pa }
    clear()
    local res
    for _ = 1, 60 do
        pa:update(1 / 60, level)
        local r = Interactions.check(pa, c)
        if r then res = r end
        Interactions.run(pa, { c }, {})
        if c.state == 'dead' then break end
    end
    -- Gummy volador congelado: cae al suelo
    local level2, es2 = cryoRoom({ firstDelay = 0.2, interval = 60, windup = 0.3, freezeTime = 3 }, nil,
        { { type = 'gummy', col = 8, row = 5, props = { movement = 'fly', pauses = false, speed = 40 } } })
    local g = es2[2]
    g:freeze(3)
    stepEnts(level2, es2, 1.5)
    check('cryo_enemigo', froze and thawed and c.state == 'dead' and res == 'stomp' and g.state == 'frozen' and g.onGround,
        ('Crabby congelado=%s descongelado=%s · pisado: %s → %s · Gummy volador congelado en el suelo=%s'):format(
            tostring(froze), tostring(thawed), tostring(res), c.state, tostring(g.onGround)))
end

function cases.cryo_activador()
    local level, es, cryo = cryoRoom({ mode = 'switch', id = 1, windup = 0.3 }, { { 12, 4, 'switch_on' } })
    level.links = { { col = 12, row = 4, to = 1 } }
    local before = {}
    stepEnts(level, es, 3, function() before[cryo.state] = true end)
    level:hitTile(12, 4, 'head')
    local after = {}
    stepEnts(level, es, 1.5, function() after[cryo.state] = true end)
    check('cryo_activador', not before.windup and not before.fire and after.windup and after.fire,
        ('sin cambiar: carga=%s · tras el Activador: carga=%s chorro=%s'):format(
            tostring(before.windup or false), tostring(after.windup), tostring(after.fire)))
end

function cases.cryo_corte()
    local level, es, cryo = cryoRoom({ firstDelay = 0.1, windup = 0.2, range = 12 }, { { 9, 8, 'solid' } })
    local maxHead = 0
    stepEnts(level, es, 1.5, function()
        local _, head = cryo:streamSpan()
        if head then maxHead = math.max(maxHead, head) end
    end)
    local want = 8 * T - 3 * T                 -- (de la boca, borde derecho de la casilla 3, al bloque de la 9)
    check('cryo_corte', math.abs(maxHead - want) <= 8,
        ('punta del chorro %d px (bloque a %d px)'):format(maxHead, want))
end

function cases.encerrado()
    -- Gummy en la casilla 8, bloques en la 7 y la 9 (fila 8, suelo en la 9)
    local level, es = room(16, 10, { { 7, 9, 'solid' }, { 9, 9, 'solid' } },
        { { type = 'gummy', col = 8, row = 9, props = { pauses = false } } })
    level.players = {}
    local g = es[1]
    local walked, idleT = 0, 0
    stepEnts(level, es, 3, function()
        if g.state == 'walk' then walked = walked + 1 else idleT = idleT + 1 end
    end)
    -- (los primeros fotogramas aún anda hasta darse cuenta)
    local stuckOk = g.state == 'idle' and idleT > 150
    level:setTileRaw(9, 9, 0)                   -- se abre sitio a la derecha
    local walkedAfter = false
    stepEnts(level, es, 1.5, function() if g.state == 'walk' and math.abs(g.vx or 0) > 0 then walkedAfter = true end end)
    check('encerrado', stuckOk and walked < 10 and walkedAfter,
        ('encerrado: estado %s, %d fotogramas andando de 180 · con sitio vuelve a andar=%s'):format(
            g.state, walked, tostring(walkedAfter)))
end

-- Un Crabby TREPADOR empujado al canto de una plataforma (su centro, fuera): antes no encontraba superficie bajo el
-- centro, no se agarraba y se quedaba parado para siempre; ahora se arrima, se agarra y sigue andando
function cases.trepador_canto()
    -- plataforma de 3 bloques (casillas 6-8, fila 7) en el aire; el Crabby, suelto y con el centro 10 px más allá
    local level, es = room(16, 10, { { 6, 7, 'solid' }, { 7, 7, 'solid' }, { 8, 7, 'solid' } },
        { { type = 'crabby', col = 8, row = 6, props = { pauses = false, wallWalk = true, canHide = false } } })
    level.players = {}
    local c = es[1]
    stepEnts(level, es, 0.5)
    local Crawler = require 'src/world/entities/Crawler'
    Crawler.detach(c)
    c.x, c.vx, c.vy = 8 * T + 10, 0, 0                -- (el borde derecho de la plataforma está en 8*T)
    local x0, got, moved = c.x, false, 0
    stepEnts(level, es, 3, function()
        if c.cattached then got = true end
        moved = math.max(moved, math.abs(c.x - x0))
    end)
    check('trepador_canto', got and moved > T,
        ('se agarra=%s · se movió %.1f casillas en 3 s'):format(tostring(got), moved / T))
end

function cases.ping_icono()
    local PingIcon = require 'src/ui/PingIcon'
    local L = PingIcon.level
    local lv = { L(40, 0.03, true), L(120, 0.03, true), L(200, 0.03, true), L(400, 0.03, true),
                 L(40, 0.8, true), L(40, 2, true), L(40, 0.03, false) }
    local want = { 4, 3, 2, 1, 1, 0, 0 }
    local ok = true
    for i = 1, #want do ok = ok and lv[i] == want[i] end
    local ind = PingIcon.new()
    ind:update(1 / 60, 200, 0.03, true)          -- 4 → 2: empeora 2, al momento
    local a = ind.shown
    ind:update(0.3, 40, 0.03, true)              -- mejora: aún no
    local b = ind.shown
    ind:update(0.4, 40, 0.03, true)              -- 0,7 s después: sí
    local c = ind.shown
    ind:update(1 / 60, 40, 3, true)              -- sin snapshots: X al momento
    local d = ind.shown
    ok = ok and a == 2 and b == 2 and c == 4 and d == 0
    check('ping_icono', ok, ('niveles %s; parpadeo: %d %d %d %d'):format(table.concat(lv, ','), a, b, c, d))
end

-- Vuelo libre (flyMode = 'free'): sale de un hueco en U, de debajo de una plataforma y de DENTRO de
-- un bloque; recorre toda la sala (todos sus sectores), nunca se queda parado, nunca acaba dentro
-- de algo y, con un jugador, se le acerca
function cases.vuelo_libre()
    local put = {}
    for _, c in ipairs({ 5, 9 }) do for r = 9, 12 do put[#put + 1] = { c, r, 'solid' } end end   -- hueco en U (cols 6-8)
    for c = 5, 9 do put[#put + 1] = { c, 13, 'solid' } end
    for c = 14, 20 do put[#put + 1] = { c, 8, 'platform' } end                                    -- plataforma
    for c = 22, 25 do put[#put + 1] = { c, 5, 'solid' } end                                       -- repisa
    put[#put + 1] = { 25, 6, 'solid' }; put[#put + 1] = { 25, 7, 'solid' }                        -- esquina
    put[#put + 1] = { 12, 4, 'solid' }                                                            -- (uno nace DENTRO de este)
    local fp = { movement = 'fly', flyMode = 'free', flyRange = 40, speed = 110 }
    local level, es = room(28, 15, put, {
        { type = 'gummy', col = 7, row = 12, props = fp },             -- en el fondo del hueco
        { type = 'gummy', col = 17, row = 9, props = fp },             -- pegado bajo la plataforma
        { type = 'gummy', col = 12, row = 4, props = fp },             -- dentro de un bloque
        { type = 'gummy', col = 24, row = 6, props = fp } })           -- en la esquina
    level.players = {}
    local W, H = 27 * T, 14 * T
    local stuck, inSolid, sect = 0, 0, {}
    local last = {}
    for i = 1, #es do sect[i], last[i] = {}, { x = es[i].x, y = es[i].y, t = 0 } end
    local out = {}
    for f = 1, 60 * 70 do
        for i, e in ipairs(es) do
            e:update(1 / 60, level)
            sect[i][math.floor(e.x / (W / 5)) .. ',' .. math.floor(e.y / (H / 3))] = true
            local l = last[i]
            if (e.x - l.x) ^ 2 + (e.y - l.y) ^ 2 > 24 ^ 2 then l.x, l.y, l.t = e.x, e.y, 0 else l.t = l.t + 1 / 60 end
            stuck = math.max(stuck, l.t)
            if f > 180 and level:isEnemySolidAt(e.x, e.y) then inSolid = inSolid + 1 end
            if i == 1 and not out[1] and e.y < 8 * T then out[1] = f / 60 end
            if i == 3 and not out[3] and not level:isEnemySolidAt(e.x, e.y) then out[3] = f / 60 end
        end
    end
    local minSect = 99
    for i = 1, #es do
        local n = 0
        for _ in pairs(sect[i]) do n = n + 1 end
        minSect = math.min(minSect, n)
    end
    -- con un jugador quieto en una esquina: se le acerca
    local pa = playerAt(level, 3, 14)
    local near = 1e9
    for _ = 1, 60 * 40 do
        for _, e in ipairs(es) do
            e:update(1 / 60, level)
            near = math.min(near, math.sqrt((e.x - pa.x) ^ 2 + (e.y - pa.y) ^ 2) / T)
        end
    end
    check('vuelo_libre', out[1] and out[3] and out[3] < 3 and minSect >= 11 and stuck < 2.5 and inSolid == 0 and near < 2.5,
        ('sale del hueco a los %.1f s y del bloque a los %.1f s; sectores visitados (de 15) mín. %d; parado como mucho %.1f s; '
         .. 'pasos dentro de un bloque %d; al jugador se acerca a %.1f casillas'):format(
            out[1] or -1, out[3] or -1, minSect, stuck, inSolid, near))
end

-- Voladores: nunca en idle (patitas siempre moviéndose); uno de suelo sí para
function cases.flyer_anim()
    local level, es = room(14, 8, {}, {
        { type = 'gummy', col = 7, row = 4, props = { movement = 'fly', pauses = true, patrol = { left = 3, right = 12 } } },
        { type = 'gummy', col = 7, row = 7, props = { pauses = true, patrol = { left = 3, right = 12 } } } })
    level.players = {}
    local flyIdle, groundIdle, frames = false, false, {}
    for _ = 1, 60 * 20 do
        for _, e in ipairs(es) do e:update(1 / 60, level) end
        if es[1].state == 'idle' then flyIdle = true end
        if es[2].state == 'idle' then groundIdle = true end
        frames[es[1].frame] = true
    end
    check('flyer_anim', not flyIdle and groundIdle and frames[1] and frames[2],
        ('volador en idle=%s (patitas: cuadros 1 y 2=%s), el de suelo para=%s'):format(tostring(flyIdle),
            tostring(frames[1] and frames[2]), tostring(groundIdle)))
end

function cases.puffer_cycle()
    local level, es = pond()
    local f = es[1]
    local pa = PlayerAdventure:new(f.x + 60, f.y)
    level.players = { pa }
    clear()
    local seen, hurtAt, hp0, hpFirst, hurt2 = {}, nil, pa.hp, nil, nil
    local t = 0
    for _ = 1, 60 * 6 do
        t = t + 1 / 60
        -- Cerca (lo ve) y, ya hinchado, pegado a él (en el agua)
        pa.x, pa.y, pa.vx, pa.vy = f.x + (f.state == 'inflated' and 30 or 60), f.y, 0, 0
        pa:update(1 / 60, level)
        f:update(1 / 60, level)
        seen[f.state] = seen[f.state] or t
        local hp = pa.hp
        Interactions.run(pa, { f }, {})
        if pa.hp ~= hp and os.getenv('TRACE') then print(('    %.2fs vida %d→%d muriendo=%s pez=%s'):format(t, hp, pa.hp, tostring(pa.dying), f.state)) end
        if pa.hp < hp then
            if not hurtAt then hurtAt, hpFirst = t, pa.hp elseif not hurt2 then hurt2 = t end
        end
        if seen.deflate then break end
    end
    -- 1º pinchazo al hincharse (-1), el 2º no antes de que acabe la protección (1,6 s)
    local ok = pa.inWater and seen.warn and seen.inflated and seen.deflate and hurtAt
               and hurtAt >= seen.inflated - 0.001 and hpFirst == hp0 - 1
               and (not hurt2 or hurt2 - hurtAt >= 1.6) or false
    check('puffer_cycle', ok, ('aviso %.2fs → hinchado %.2fs → deshincha %.2fs; pinchazos %.2fs (vida %d→%s) y %s'):format(
        seen.warn or -1, seen.inflated or -1, seen.deflate or -1, hurtAt or -1, hp0, tostring(hpFirst),
        hurt2 and ('%.2fs'):format(hurt2) or 'ninguno más'))
end

function cases.puffer_dry()
    -- Un jugador FUERA del agua junto a él: no se hincha
    local level, es = pond()
    local f = es[1]
    for r = 3, 8 do for c = 2, 15 do level.tiles[r][c] = (c == 9 and r >= 4 and r <= 6) and TILE_SOLID or TILE_EMPTY end end
    local pa = PlayerAdventure:new(f.x + 60, f.y)
    level.players = { pa }
    clear()
    for _ = 1, 60 * 3 do pa.x, pa.y = f.x + 60, f.y; pa:update(1 / 60, level); f:update(1 / 60, level) end
    check('puffer_dry', not pa.inWater and f.state == 'walk', ('jugador en el agua=%s, pez=%s'):format(tostring(pa.inWater), f.state))
end

-- SHOT_BOMB=1: bombas en todos sus estados → <save>/mechanics_bombs.png
local function bombShot()
    local Core = require 'src/world/entities/BombCore'
    local level, es = bombRoom({
        { type = 'bomb', col = 3, row = 8, props = { pauses = false, speed = 40 } },
        { type = 'bomb', col = 6, row = 8, props = { speed = 0, fuseTime = 2 } },
        { type = 'bomb', col = 9, row = 8, props = { speed = 0, fuseTime = 2 } },
        { type = 'bomb', col = 12, row = 8, props = { speed = 0, fuseTime = 2 } },
        { type = 'bombobject', col = 15, row = 8, props = { fuseTime = 2 } },
        { type = 'bomb', col = 3, row = 4, props = { movement = 'fly', speed = 40 } },
        { type = 'bombobject', col = 20, row = 8, props = { fuseTime = 2 } },
    })
    stepEnts(level, es, 0.4)
    local times = { [2] = 0.2, [3] = 1.2, [4] = 1.85, [5] = 1.0 }
    for i, t in pairs(times) do Core.light(es[i], 2); es[i].deadTimer = t end
    es[7].state, es[7].deadTimer = 'exploding', 0.15
    local canvas = love.graphics.newCanvas(24 * T, 9 * T)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.45, 0.62, 0.8, 1)
    level:render(0, 0)
    for _, e in ipairs(es) do if e.alive then e:render(0, 0) end end
    love.graphics.setCanvas()
    canvas:newImageData():encode('png', 'mechanics_bombs.png')
    print('captura bombas: ' .. love.filesystem.getSaveDirectory() .. '/mechanics_bombs.png')
end

local shot
function love.load()
    for _, n in ipairs({ 'onoff_head', 'onoff_pound', 'hidden_up', 'hidden_drop', 'hidden_side', 'hidden_vis',
                         'helmet_jump', 'helmet_ride', 'helmet_gp', 'helmet_side', 'stomp_fast',
                         'puffer_through', 'puffer_concave', 'puffer_cycle', 'puffer_dry', 'flyer_anim', 'vuelo_libre', 'boxed_in',
                         'bloque_roto', 'activador', 'tramp_avanza', 'tramp_pinchos', 'ping_icono',
                         'bomba_activa', 'bomba_pisada', 'bomba_radios', 'bomba_mundo', 'bomba_objeto',
                         'hielo_solido', 'hielo_desgaste', 'hielo_gp', 'hielo_bomba', 'encerrado', 'trepador_canto', 'hielo_resbala',
                         'cryo_jugador', 'cryo_enemigo', 'cryo_activador', 'cryo_corte' }) do cases[n]() end
    if os.getenv('SHOT_BOMB') then bombShot() end
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    if not os.getenv('SHOT') then love.event.quit(fails == 0 and 0 or 1); return end
    -- Escena para la captura
    love.window.setMode(1280, 720)
    local level, es = room(20, 11, { { 4, 7, 'switch_on' }, { 6, 7, 'switch_off' }, { 9, 7, 'hidden_block' },
        { 10, 7, 'hidden_block' }, { 12, 7, 'hidden_block' } }, {
        { type = 'gummy', col = 14, row = 10, props = { helmet = true } },
        { type = 'gummy', col = 16, row = 10, props = {} },
        { type = 'gummy', col = 18, row = 10, props = { helmet = true, movement = 'fly' } },
        { type = 'pufferfish', col = 3, row = 3, props = {} },
        { type = 'pufferfish', col = 6, row = 3, props = {} },
        { type = 'pufferfish', col = 9, row = 3, props = {} } })
    for _, e in ipairs(es) do e.vx = 0 end
    -- Bloques ON/OFF golpeados, congelados a media animación: el ON en lo alto
    -- del saltito (cabezazo) y el OFF lo más aplastado (ground pound)
    level:tileBump(4, 7, 'head'); level.tileAnim[7 * 65536 + 4].t = 0.11
    level:tileBump(6, 7, 'pound'); level.tileAnim[7 * 65536 + 6].t = 0.11
    level.update = function() end
    -- Peces: nadando, avisando (medio) e hinchado
    es[4].state = 'walk'; es[5].state, es[5].deadTimer = 'warn', 0.45; es[6].state, es[6].deadTimer = 'inflated', 1
    local pa = PlayerAdventure:new(9.5 * T, 6 * T - 60)
    level.players = { pa }
    clear(); for _ = 1, 40 do pa:update(1 / 60, level) end     -- (de pie encima del 9 y el 10)
    -- el 9 y 10 tocados; el 12 de hace un momento (parpadeando)
    level:updateHiddenBlocks(1, { pa:getOuterBounds() })
    level:updateHiddenBlocks(1, { pa:getOuterBounds(), { x = 11 * T, y = 5 * T, w = 40, h = 64 } })
    level:updateHiddenBlocks(0.3, { pa:getOuterBounds() })
    shot = { level = level, es = es, pa = pa, n = 0 }
end

function love.draw()
    if not shot then return end
    love.graphics.clear(0.35, 0.6, 0.85)
    shot.level:render(0, 0)
    for _, e in ipairs(shot.es) do e:render(0, 0) end
    shot.pa:render(0, 0)
    shot.n = shot.n + 1
    if shot.n == 3 then
        love.graphics.captureScreenshot(function(img) img:encode('png', 'mechanics.png') end)
    end
    if shot.n > 5 then
        print('captura: ' .. love.filesystem.getSaveDirectory() .. '/mechanics.png')
        love.event.quit(fails == 0 and 0 or 1)
    end
end
