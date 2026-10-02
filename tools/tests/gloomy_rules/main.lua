-- Arnés: NIVELES A OSCURAS, LINTERNA y CRABBY LÚGUBRE, caso a caso (salas pequeñas, sin red).
--   linterna      se enciende y apaga; encendida gasta la batería en LIGHT_TIME s, se agota sola y
--                 no vuelve a encender hasta LIGHT_COOL s; apagada se recarga; fuera de un nivel a
--                 oscuras no hace nada
--   luz_pared     Lights.lit: dentro del cono sí; detrás del jugador, fuera de alcance o con una
--                 pared en medio, no
--   estado_propio la linterna viaja en el estado propio (pack → apply) y en el bit de input
--   oye           un ground pound lejos (10 casillas) lo atrae; un salto a esa distancia, no; un salto
--                 cerca, sí; ANDAR no hace ruido
--   marca         cada ruido deja su "!" (fx noise_s/m/l); en niveles con luz no hay ruidos
--   navega        planea el camino: baja de una plataforma al ruido de debajo, rodea una columna, va del
--                 techo a una repisa; sin ir y venir (≤ 3 cambios de sentido)
--   burla         tras darle a un jugador, se para a burlarse
--   busca         llega donde sonó, ronda por allí y, sin más ruidos, lo deja: sin sonidos, con sus iconos (! ? …)
--   salta         de cerca se agacha (aviso) y salta: 1 de vida + empujón; nunca mata
--   contacto      tocarlo quita 1 de vida, no mata
--   huye          con la linterna encima huye de la luz y se aleja; a oscuras se calma
--   pisoton       un pisotón normal solo rebota; un ground pound lo mata
--   bloque        muere si se rompe el bloque al que se agarra (suelo o techo)
--   choque        dos lúgubres no se atraviesan: se dan la vuelta
--   distraer      estrella, bloque, trampolín, mortero, bomba... suenan con su fuerza y va a mirar ahí
--   techo         desde el techo salta sobre el jugador y NO se queda clavado: se agarra y sigue
--   explora       sin ruta: en 40 s recorre suelo, paredes y techo de la sala
--   red           netPack → netApply: superficie y estado iguales en el cliente
--   LOOK=1        <save>/gloomy_look.png: la sala a oscuras con la linterna (lo que ve el jugador)
--
--   tools/tests/run.sh gloomy_rules   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
Sound = setmetatable({ play = function(n) played[n] = (played[n] or 0) + 1 end },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Interactions = require 'src/world/entities/Interactions'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Lights = require 'src/world/Lights'
local Noise = require 'src/world/Noise'
local T = TILE_PX
local BREAK = require('src/world/tiles/TileTypes').byName.breakable.id

local fails = 0
local function check(case, ok, msg)
    print(('%-14s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local function room(W, H, ents, blocks, dark)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = 1 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 }, dark = dark ~= false,
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    Noise.bind(level)
    return level, es, es[1]
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end
local function player(level, col, H)
    clearInput()
    local pa = PlayerAdventure:new((col - 0.5) * T, (H - 1) * T - 60)
    level.players = { pa }
    for _ = 1, 40 do pa:update(1 / 60, level) end
    pa.invT = 0
    return pa
end

local function step(level, es, secs, each)
    for _ = 1, math.floor(secs * 60) do
        for _, pa in ipairs(level.players) do pa:update(1 / 60, level) end
        level.solidBodies = Entities.solidBodies(es)
        level:update(1 / 60)
        for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end
local function gl(col, row, props) return { type = 'gloomy', col = col, row = row, props = props or {} } end
local function press(a) stub.state[a .. '_pressed'] = true end

local cases = {}

function cases.linterna()
    local level = room(12, 8, {})
    local pa = player(level, 4, 8)
    press('light'); step(level, {}, 0.05)
    local on = pa.lightOn
    step(level, {}, PlayerAdventure.LIGHT_TIME * 0.5)
    local half = pa.lightBat
    local out = step(level, {}, PlayerAdventure.LIGHT_TIME, function() return not pa.lightOn end)
    local cd = pa.lightCd
    press('light'); step(level, {}, 0.05)
    local refused = not pa.lightOn
    step(level, {}, PlayerAdventure.LIGHT_COOL + 2)
    local bat = pa.lightBat
    press('light'); step(level, {}, 0.05)
    local again = pa.lightOn
    press('light'); step(level, {}, 0.05)
    local off = not pa.lightOn
    -- nivel con luz: no hay linterna
    local l2 = room(12, 8, {}, nil, false)
    local p2 = player(l2, 4, 8)
    press('light'); step(l2, {}, 0.05)
    check('linterna', on and half > 0.4 and half < 0.6 and out and cd > 0 and refused and bat > 0.12 and again and off
        and not p2.lightOn,
        ('enciende=%s; a media batería %.2f; se agota=%s (enfría %.1f s, no enciende=%s); recarga a %.2f y enciende=%s; apaga=%s; '
         .. 'en un nivel con luz=%s'):format(tostring(on), half, tostring(out), cd, tostring(refused), bat, tostring(again),
         tostring(off), tostring(p2.lightOn)))
end

function cases.luz_pared()
    local level = room(20, 8, {}, { { 12, 7 }, { 12, 6 }, { 12, 5 } })
    local pa = player(level, 6, 8)
    pa.facing, pa.lightOn = 1, true
    local y = pa.y - 20
    local front = Lights.lit(level, pa.x + 3 * T, y)
    local back = Lights.lit(level, pa.x - 2 * T, y)
    local far = Lights.lit(level, pa.x + 12 * T, y)
    local wall = Lights.lit(level, 13.5 * T, 6 * T)
    local above = Lights.lit(level, pa.x + 1 * T, pa.y - 3 * T)
    pa.lightOn = false
    local offL = Lights.lit(level, pa.x + 3 * T, y)
    check('luz_pared', front and not back and not far and not wall and not above and not offL,
        ('delante=%s detrás=%s lejos=%s tras la pared=%s encima=%s apagada=%s'):format(tostring(front), tostring(back),
         tostring(far), tostring(wall), tostring(above), tostring(offL)))
end

function cases.estado_propio()
    local level = room(12, 8, {})
    local pa = player(level, 4, 8)
    pa.lightOn, pa.lightBat, pa.lightCd = true, 0.37, 1.25
    local s = P.packOwnState(pa)
    local pb = PlayerAdventure:new(0, 0)
    P.applyOwnState(s, pb)
    local bits = P.encodeInput(false, false, false, false, false, false, true)
    local out = P.decodeInput(bits, {})
    check('estado_propio', P.isValidOwnState(s) and pb.lightOn and math.abs(pb.lightBat - 0.37) < 1e-6 and pb.lightCd == 1.25
        and out.light_pressed and bits <= P.IN_MAX,
        ('válido=%s; encendida=%s batería %.2f enfría %.2f; bit de input=%d'):format(tostring(P.isValidOwnState(s)),
         tostring(pb.lightOn), pb.lightBat, pb.lightCd, bits))
end

function cases.oye()
    local function try(dist, r)
        local level, es, e = room(34, 8, { gl(4, 7, { pauses = false }) })
        step(level, es, 0.3)
        e.cdir, e.state = -1, 'walk'
        local x0 = e.x
        Noise.emit(e.x + dist * T, e.y, r)
        step(level, es, 2.0)
        return e.x - x0, e.state
    end
    local farPound, st1 = try(10, Noise.R.pound)
    local farJump, st2 = try(10, Noise.R.faint)
    local nearJump, st3 = try(2.5, Noise.R.faint)
    -- ni andar ni saltar hacen ruido
    local level = room(20, 8, {})
    local pa = player(level, 6, 8)
    local n0 = level.noises and level.noises.seq or 0
    stub.state.right = true; step(level, {}, 1.0); stub.state.right = false
    local walkN = (level.noises and level.noises.seq or 0) - n0
    stub.state.jump_pressed = true; step(level, {}, 0.1)
    local jumpN = (level.noises and level.noises.seq or 0) - n0 - walkN
    check('oye', farPound > 2 * T and st2 ~= 'hunt' and farJump < T and nearJump > 0.5 * T and walkN == 0 and jumpN == 0
        and Noise.R.hit < Noise.R.hurt and Noise.R.hurt < Noise.R.kill and Noise.R.kill < Noise.R.pound,
        ('ground pound a 10 casillas: se acerca %.1f (%s); ruido flojo a 10: %.1f (%s); a 2,5: %.1f (%s); ruidos andando 1 s: %d; al saltar: %d'):format(
         farPound / T, st1, farJump / T, st2, nearJump / T, st3, walkN, jumpN))
end

-- Cada ruido deja su marca "!" (fx) del tamaño de lo que se oye; en un nivel CON luz, nada
function cases.marca()
    local Entity = require 'src/world/entities/Entity'
    local got = {}
    Entity.fx = function(kind) got[#got + 1] = kind end
    local level = room(20, 8, {})
    Noise.emit(100, 100, Noise.R.faint); Noise.emit(100, 100, Noise.R.hurt); Noise.emit(100, 100, Noise.R.pound)
    local l2 = room(20, 8, {}, nil, false)
    Noise.emit(100, 100, Noise.R.pound)
    Entity.fx = nil
    check('marca', #got == 3 and got[1] == 'noise_s' and got[2] == 'noise_m' and got[3] == 'noise_l' and not l2.noises,
        ('marcas: %s; en un nivel con luz se apunta=%s'):format(table.concat(got, ', '), tostring(l2.noises ~= nil)))
end

-- NAVEGAR sin titubeos: (1) en lo alto de una plataforma y el ruido en el suelo, DEBAJO de ella;
-- (2) el ruido al otro lado de una columna. Llega cerca y cambia de sentido muy pocas veces
function cases.navega()
    local msg, ok = {}, true
    local function try(name, ents, blocks, gx, gy, W)
        local level, es, e = room(W or 22, 10, ents, blocks)
        step(level, es, 0.4)
        Noise.emit(gx, gy, Noise.R.pound)
        local flips, last, best, tBest, t = 0, e.cdir, 1e9, 0, 0
        step(level, es, 9, function()
            t = t + 1 / 60
            if e.cattached and e.cdir ~= last then flips = flips + 1; last = e.cdir end
            local d = math.sqrt((e.x - gx) ^ 2 + (e.y - gy) ^ 2)
            if d < best then best, tBest = d, t end
            return e.state == 'search' and d < 1.5 * T
        end)
        local good = best < 1.5 * T and flips <= 3
        ok = ok and good
        msg[#msg + 1] = ('%s: llega a %.1f casillas en %.1f s, cambios de sentido %d'):format(name, best / T, tBest, flips)
    end
    -- (1) plataforma de 5 a 2 casillas del suelo; él arriba; el ruido justo debajo
    try('bajar', { gl(10, 6, { pauses = false }) }, { { 8, 7 }, { 9, 7 }, { 10, 7 }, { 11, 7 }, { 12, 7 } }, 9.5 * T, 9 * T - 20)
    -- (2) columna de 3 de alto en medio; el ruido al otro lado, en el suelo
    try('columna', { gl(6, 9, { pauses = false }) }, { { 10, 9 }, { 10, 8 }, { 10, 7 } }, 14.5 * T, 9 * T - 20)
    -- (3) en el techo, el ruido en una repisa de la pared contraria
    try('techo→repisa', { gl(9, 2, { pauses = false }) }, { { 18, 6 }, { 19, 6 }, { 20, 6 }, { 21, 6 } }, 19.5 * T, 5 * T - 20)
    check('navega', ok, table.concat(msg, ' · '))
end

-- Burla: tras darle a un jugador se queda quieto haciendo flexiones (da tiempo a apartarse)
function cases.burla()
    local level, es, e = room(20, 8, { gl(8, 7, { pauses = false, senseRange = 0.01, hearing = 0 }) })
    step(level, es, 0.3)
    local pa = player(level, 8, 8)
    pa.x = e.x
    local x0
    local seen, frames = false, {}
    step(level, es, 0.8, function()
        pa.x = pa.x + 6                                   -- (el jugador sale empujado: se aparta)
        if e.state == 'taunt' then
            seen = true
            x0 = x0 or e.x
            frames[e:frameNow()] = true
        end
    end)
    local n = 0
    for _ in pairs(frames) do n = n + 1 end
    step(level, es, 2)
    check('burla', seen and n == 2 and math.abs(e.x - (x0 or 0)) > 1 and e.state ~= 'taunt',
        ('se burla=%s (cuadros distintos %d, quieto mientras); después %s'):format(tostring(seen), n, e.state))
end

function cases.busca()
    local level, es, e = room(30, 8, { gl(4, 7, { pauses = false, searchTime = 2 }) })
    step(level, es, 0.3)
    local gx = e.x + 8 * T
    Noise.emit(gx, e.y, Noise.R.pound)
    local seen, reach = {}, nil
    local icons = {}
    played = {}
    step(level, es, 12, function()
        seen[e.state] = true
        icons[e.icon or 0] = true
        if e.state == 'search' and not reach then reach = math.abs(e.x - gx) / T end
    end)
    check('busca', seen.hunt and seen.search and reach and reach < 1.5 and e.state ~= 'search' and e.state ~= 'hunt'
        and icons[1] and icons[2] and icons[3] and not next(played),
        ('va=%s, ronda=%s (llegó a %.1f casillas del sitio), al final %s; iconos ! ? …: %s %s %s; sonidos: %s'):format(
         tostring(seen.hunt), tostring(seen.search), reach or -1, e.state, tostring(icons[1]), tostring(icons[2]),
         tostring(icons[3]), next(played) or 'ninguno'))
end

function cases.salta()
    local level, es, e = room(24, 9, { gl(6, 8, { pauses = false }) })
    step(level, es, 0.3)
    local pa = player(level, 9, 9)
    local hp0 = pa.hp
    local seen, tWind, tLeap, t = {}, nil, nil, 0
    played = {}
    local x0
    step(level, es, 4, function()
        t = t + 1 / 60
        stub.state.right = (math.floor(t * 4) % 2 == 0); stub.state.left = not stub.state.right     -- (se mueve: lo nota)
        seen[e.state] = true
        if e.state == 'crouch' and not tWind then tWind = t end
        if e.state == 'leap' and not tLeap then tLeap = t end
        if pa.hp < hp0 and not x0 then x0 = pa.vx; return true end
    end)
    clearInput()
    check('salta', seen.crouch and seen.leap and tLeap and tWind and tLeap - tWind >= 0.4 and pa.hp == hp0 - 1 and not pa.dying
        and math.abs(x0 or 0) > 200 and (played.gloomyWind or 0) >= 1,
        ('se agacha=%s (aviso %.2f s, siseo %d) y salta=%s; vida %d→%d, empujón vx %.0f, muerto=%s'):format(tostring(seen.crouch),
         (tLeap or 0) - (tWind or 0), played.gloomyWind or 0, tostring(seen.leap), hp0, pa.hp, x0 or 0, tostring(pa.dying)))
end

function cases.contacto()
    local level, es, e = room(20, 8, { gl(8, 7, { pauses = false, senseRange = 0.01, hearing = 0 }) })
    step(level, es, 0.3)
    local pa = player(level, 8, 8)
    pa.x = e.x
    local hp0 = pa.hp
    step(level, es, 0.2)
    check('contacto', pa.hp == hp0 - 1 and not pa.dying, ('vida %d→%d, muerto=%s'):format(hp0, pa.hp, tostring(pa.dying)))
end

function cases.huye()
    local level, es, e = room(34, 8, { gl(12, 7, { pauses = false, senseRange = 0.01, hearing = 0 }) })
    step(level, es, 0.3)
    local pa = player(level, 9, 8)
    pa.facing = 1
    local d0 = e.x - pa.x
    e.cdir = -1                                            -- (iba hacia el jugador)
    played = {}
    press('light')
    local fled
    step(level, es, 1.5, function() if e.state == 'flee' then fled = true end end)
    local d1 = e.x - pa.x
    local lit = Lights.lit(level, e.x, e.y)
    press('light')                                         -- apaga
    step(level, es, 3)
    check('huye', fled and d1 > d0 + 2 * T and e.state ~= 'flee',
        ('huye=%s: de %.1f a %.1f casillas del jugador en 1,5 s (aún alumbrado=%s); a oscuras: %s'):format(tostring(fled),
         d0 / T, d1 / T, tostring(lit), e.state))
end

-- DURO: un pisotón normal solo REBOTA (no lo mata, no hace daño); un GROUND POUND sí lo mata
function cases.pisoton()
    local function try(gp)
        local level, es, e = room(20, 9, { gl(8, 8, { pauses = false, senseRange = 0.01, hearing = 0 }) })
        step(level, es, 0.3)
        local pa = player(level, 8, 9)
        pa.x, pa.y, pa.vy, pa.onGround = e.x, e.y - 150, 300, false
        local hp0, up = pa.hp, false
        if gp then pa.gpPhase, pa.vy = 'fall', 900 end
        step(level, es, 0.6, function() if pa.vy < -200 then up = true end; return e.state == 'dead' or up end)
        if not gp then step(level, es, 1.2, function() e.state = 'idle'; e.idleTimer, e.idleDuration = 0, 99; pa.x = e.x end) end   -- (sigue rebotando encima)
        return e.state, hp0 - pa.hp, up
    end
    local st1, d1, up1 = try(false)
    local st2, d2 = try(true)
    check('pisoton', st1 ~= 'dead' and d1 == 0 and up1 and st2 == 'dead' and d2 == 0,
        ('pisotón normal (y 1,2 s más rebotando encima): %s, rebota=%s, vida -%d; ground pound: %s, vida -%d'):format(st1, tostring(up1), d1, st2, d2))
end

-- BLOQUE: si se rompe el bloque al que está agarrado (suelo o techo), muere despedido
function cases.bloque()
    local function try(col, row, bc, br, attach)
        local level, es, e = room(20, 9, { gl(col, row, { pauses = false, senseRange = 0.01, hearing = 0 }) }, nil)
        level.tiles[br][bc] = BREAK
        if attach then e.cnx, e.cny, e.cattached = attach[1], attach[2], nil end
        step(level, es, 0.3, function() e.state = 'idle'; e.idleTimer, e.idleDuration = 0, 99 end)
        local was = e.cattached and true or false
        level:breakTile(bc, br)
        return e.state, was
    end
    local floor, a1 = try(8, 8, 8, 9)                       -- de pie sobre el bloque del suelo
    local ceil, a2 = try(8, 2, 8, 1, { 0, 1 })              -- colgado del techo
    local other = try(8, 8, 12, 9)                          -- otro bloque: no le pasa nada
    check('bloque', floor == 'dead_fling' and a1 and ceil == 'dead_fling' and a2 and other ~= 'dead_fling',
        ('se rompe el de debajo: %s; el del techo del que cuelga: %s; otro bloque: %s'):format(floor, ceil, other))
end

-- CHOQUE: dos lúgubres no se atraviesan (ni a otros enemigos): se dan la vuelta
function cases.choque()
    local level, es = room(24, 8, { gl(6, 7, { pauses = false, senseRange = 0.01, hearing = 0 }),
                                    gl(12, 7, { pauses = false, senseRange = 0.01, hearing = 0 }) })
    local a, b = es[1], es[2]
    step(level, es, 0.3)
    local minGap, turns, last = 1e9, 0, nil
    step(level, es, 14, function()
        a.wanderT, b.wanderT = 9, 9                         -- (sin medias vueltas al azar)
        a.state, b.state = 'walk', 'walk'
        if (b.x - a.x) > 3 * T then a.cdir, b.cdir = 1, -1 end          -- (siempre el uno hacia el otro)
        local ba, bb = a:getOuterBounds(), b:getOuterBounds()
        minGap = math.min(minGap, math.max(bb.x - (ba.x + ba.w), ba.x - (bb.x + bb.w)))
        local k = a.cdir * 10 + b.cdir
        if last and k ~= last then turns = turns + 1 end
        last = k
    end)
    check('choque', minGap >= 0 and turns >= 2 and a.x < b.x,
        ('hueco mínimo entre sus cajas %.0f px (nunca se solapan); cambios de sentido %d; siguen en su lado=%s'):format(minGap, turns,
         tostring(a.x < b.x)))
end

-- RUIDOS para DISTRAER: coger una estrella, romper un bloque, un trampolín, un mortero, una bomba...
-- suenan (cada uno con su fuerza: Noise.R / Noise.SOUNDS) y el lúgubre va a mirar AHÍ, no al jugador
function cases.distraer()
    -- (1) cada cosa apunta su ruido, del tamaño que toca
    local level, es = room(30, 9, { { type = 'star', col = 6, row = 8, props = {} } })
    local got = {}
    local function last() local n = level.noises; return n and n.list[#n.list] end
    local pa = player(level, 6, 9)
    step(level, es, 0.4)
    got.star = last() and last().r / T
    level.tiles[6][10] = BREAK; level:breakTile(10, 6); got.tile = last().r / T
    for _, n in ipairs({ 'trampoline', 'mortarShoot', 'bombBlast', 'pufferInflate' }) do
        local n0 = level.noises.seq
        Noise.src(500, 300); Sound.play(n); Noise.src(nil)
        got[n] = (level.noises.seq > n0) and last().r / T or 0
    end
    local n0 = level.noises.seq
    Sound.play('bombBlast')                                 -- (sin sitio: no es de nadie → nada)
    local nowhere = level.noises.seq - n0
    Noise.src(500, 300); Sound.play('jump'); Noise.src(nil)
    local silent = level.noises.seq - n0
    local order = (got.star or 99) < got.tile and got.tile < Noise.R.pound and Noise.R.pound < got.bombBlast
    -- (2) distracción: el jugador a la izquierda, callado; una bomba estalla a la derecha → va a la derecha
    local l2, es2, e = room(34, 8, { gl(16, 7, { pauses = false, senseRange = 0.01 }) })
    local p2 = player(l2, 6, 8)
    step(l2, es2, 0.3)
    local x0 = e.x
    Noise.src(28 * T, 7 * T); Sound.play('bombBlast'); Noise.src(nil)
    step(l2, es2, 2.5)
    check('distraer', got.star == Noise.R.pickup and got.tile == Noise.R.tile and got.trampoline == 8 and got.mortarShoot == 10
        and got.bombBlast == 26 and got.pufferInflate == 7 and nowhere == 0 and silent == 0 and order and e.x - x0 > 2 * T,
        ('casillas: estrella %s, bloque %s, trampolín %s, mortero %s, bomba %s, pez globo %s; sin sitio %d, salto %d; '
         .. 'estrella < bloque < ground pound < bomba=%s; bomba a la derecha: va %.1f casillas hacia ella (%s)'):format(
         tostring(got.star), tostring(got.tile), tostring(got.trampoline), tostring(got.mortarShoot), tostring(got.bombBlast),
         tostring(got.pufferInflate), nowhere, silent, tostring(order), (e.x - x0) / T, e.state))
end

function cases.techo()
    local level, es, e = room(24, 7, { gl(8, 2, { pauses = false, attach = 'ceiling' }) })
    e.flipped = true; e:init()
    step(level, es, 0.4)
    local onCeil = e.cattached and e.cny == 1
    local pa = player(level, 8, 7)
    pa.x = e.x + 20
    Noise.emit(pa.x, pa.y, Noise.R.faint * 2)               -- (un ruido justo debajo: baja a por él)
    local seen = {}
    step(level, es, 5, function()
        pa.invT = 3
        seen[e.state] = true
    end)
    step(level, es, 3)
    check('techo', onCeil and seen.leap and e.cattached and e.state ~= 'leap' and not tostring(e.state):find('drop'),
        ('en el techo=%s; oye algo debajo y salta=%s; después: agarrado=%s (normal %d,%d), estado %s'):format(tostring(onCeil),
         tostring(seen.leap), tostring(e.cattached), e.cnx, e.cny, e.state))
end

function cases.explora()
    local level, es, e = room(14, 8, { gl(4, 7, { pauses = false, hearing = 0 }) }, { { 7, 5 }, { 8, 5 } })
    local surf = {}
    step(level, es, 60, function()
        if e.cattached then surf[e.cnx .. ',' .. e.cny] = true end
    end)
    local n = 0
    for _ in pairs(surf) do n = n + 1 end
    check('explora', n >= 3 and e.alive, ('superficies distintas recorridas en 60 s: %d (suelo, paredes, techo)'):format(n))
end

function cases.red()
    local level, es, e = room(14, 8, { gl(4, 7, { pauses = false, hearing = 0 }) })
    step(level, es, 6)
    local pk = e:netPack()
    local l2 = room(14, 8, { gl(4, 7) })
    local r = Entities.create({ type = 'gloomy', col = 4, row = 7, props = {} })
    r.x, r.y, r.state = e.x, e.y, e.state
    r:netApply(pk, pk, 1)
    check('red', r.cnx == e.cnx and r.cny == e.cny and r.cattached == e.cattached,
        ('superficie servidor %d,%d / cliente %d,%d'):format(e.cnx, e.cny, r.cnx or 9, r.cny or 9))
end

local function look()
    local Darkness = require 'src/fx/Darkness'
    WINDOW_W, WINDOW_H = 1280, 720
    local level, es = room(20, 12, { gl(11, 11, { pauses = false }), gl(16, 11), gl(5, 2, { attach = 'ceiling' }), gl(14, 7) },
                           { { 13, 8 }, { 14, 8 }, { 15, 8 }, { 8, 9 } })
    es[3].flipped = true; es[3]:init()
    step(level, es, 0.5)
    local pa = player(level, 6, 12)
    pa.facing, pa.lightOn = 1, true
    es[1].state = 'flee'; es[1].modeT = 0.05
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.12, 0.13, 0.18, 1)
    level:render(0, 48)
    for _, e in ipairs(es) do e:render(0, 48) end
    pa:render(0, 48)
    Darkness.render(level, 0, 48, { { x = pa.x, y = pa.y, facing = 1, on = true } })
    Darkness.renderGlow(level, es, 0, 48)
    require('src/ui/LightHud').draw(pa, 20, 118)
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'gloomy_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/gloomy_look.png')
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'linterna', 'luz_pared', 'estado_propio', 'oye', 'marca', 'navega', 'burla', 'busca', 'salta', 'contacto', 'huye', 'pisoton',
                         'bloque', 'choque', 'distraer', 'techo', 'explora', 'red' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'ERROR ' .. tostring(err)) end
        end
    end
    if os.getenv('LOOK') then look() end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
