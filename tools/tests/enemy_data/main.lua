-- tools/tests/enemy_data — animaciones como datos (src/fx/Anim.lua) y enemigos hechos con datos
-- (src/world/entities/base/DataEnemy.lua + src/world/entities/behaviors/), sin ventana:
--   anim_tiempos   cuadro por tiempo: bucle, duraciones por cuadro, secuencia que no se repite, reserva
--   anim_avisos    los avisos (`events`) de una secuencia salen una vez por pasada
--   anim_variante  una variante cambia las imágenes y no las secuencias
--   anim_juego     todos los conjuntos de assets/anim cargan y sus secuencias apuntan a cuadros que existen
--   por_nombre     Gloomy, Mega Gloomy, bombas y pez globo piden sus animaciones por nombre y se ve el MISMO cuadro
--                  que con las fórmulas de antes (cuadro por número de la hoja), estado a estado
--   registro       un enemigo de datos se registra como tipo (props comunes, miniatura) y se crea en un nivel
--   anda           sin comportamientos anda y se gira como cualquiera; el ciclo de andar sale de su secuencia
--   persigue       'chase': ve al jugador, corre hacia él (estado run) y lo deja cuando se va
--   ataca          'melee': aviso → golpe (quita vida solo durante el golpe) → descanso → espera
--   salta          'leap': se agacha y salta hacia el jugador; cae y sigue andando
--   dispara        'shoot': su proyectil viaja, quita vida y se para en un bloque
--   vida           con 3 de vida aguanta 2 pisotones (estado hurt, intocable) y muere al tercero
--   trepa          `crawl`: anda pegado al suelo, sube por la pared y sigue por el techo sin soltarse
--   esconde        'hide': entra, se queda escondido (no se le puede pisar; su tapa quita vida) y sale
--   jefe           un JEFE de datos: zona, entrada, persigue, ataca (el golpe quita vida), se cansa (ahí se le
--                  golpea: un golpe por ocasión), fase 2 con poca vida, muere y la zona queda libre
--   red            netPack → netApply en otra instancia: misma vida y proyectiles; el dibujo sale de estado + reloj
--   avisos         validate: dice qué secuencias faltan
--   indice         los enemigos de assets/enemies/index.json existen, son válidos y están registrados
--
--   tools/tests/run.sh enemy_data
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fails = 0
local function check(case, ok, msg)
    print(('%-14s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

function love.load()
    require 'settings'
    local played = {}
    Sound = setmetatable({ play = function(n) played[#played + 1] = n end }, { __index = function() return function() end end })
    love.graphics.newImage = function(p)
        local w, h = 16, 16
        return { path = p, getWidth = function() return w end, getHeight = function() return h end,
                 getDimensions = function() return w, h end, setFilter = function() end, setWrap = function() end }
    end
    love.graphics.newQuad = function() return { setViewport = function() end } end
    local P = require 'src/network/Protocol'
    local stub = P.newInputStub(); Input = stub
    local Anim = require 'src/fx/Anim'
    local Level = require 'src/world/level/Level'
    local Entities = require 'src/world/entities/Entities'
    local Interactions = require 'src/world/entities/base/Interactions'
    local DataEnemy = require 'src/world/entities/base/DataEnemy'
    local PlayerAdventure = require 'src/player/PlayerAdventure'
    local T = TILE_PX

    -- ── animaciones ──
    local set = Anim.fromData({ id = 't', frames = { { image = 'a/x1.png' }, { image = 'a/x2.png' }, { image = 'a/x3.png' } },
        anims = { idle = { frames = { 1 }, fps = 4 },
                  walk = { frames = { 2, 3 }, fps = 10, durations = { 0.1, 0.3 }, events = { ['2'] = 'step' } },
                  dead = { frames = { 3, 1 }, fps = 5, loop = false } },
        variants = { ice = { from = 'a/', to = 'b/' } } })
    local a, _, k1 = set:frameAt('walk', 0.05)
    local b = set:frameAt('walk', 0.25)
    local c = set:frameAt('walk', 0.45)                      -- (dura 0.4: da la vuelta)
    local d, done = set:frameAt('dead', 9)
    local e0, notDone = set:frameAt('dead', 0.1)
    local fb = set:frameAt('no_existe', 0)
    check('anim_tiempos', a == 2 and b == 3 and c == 2 and d == 1 and done and e0 == 3 and not notDone and fb == 1
          and math.abs(set:length('walk') - 0.4) < 1e-6 and set:frameN('walk', 3) == 2,
          ('walk 0.05/0.25/0.45 → %d %d %d; dead acabada → %d (%s); reserva → %d; largo walk %.2f'):format(a, b, c, d, tostring(done), fb, set:length('walk')))
    local ev1 = set:eventsBetween('walk', 0, 0.39)
    local ev2 = set:eventsBetween('walk', 0, 1.2)             -- tres pasadas
    check('anim_avisos', #ev1 == 1 and ev1[1] == 'step' and #ev2 == 3, ('una pasada: %d; tres pasadas: %d'):format(#ev1, #ev2))
    local ice = Anim.fromData(set.data, 'ice')
    check('anim_variante', ice.frames[2].path == 'b/x2.png' and set.frames[2].path == 'a/x2.png' and ice:length('walk') == set:length('walk'),
          ice.frames[2].path .. ' / ' .. set.frames[2].path)
    local bad, n = {}, 0
    for _, id in ipairs(Anim.list()) do
        n = n + 1
        local data = Anim.read(id)
        local s = data and Anim.fromData(data)
        if not s or #s.frames == 0 or #s.names == 0 then bad[#bad + 1] = id .. ' (vacío)'
        else
            for _, f in ipairs(s.frames) do
                if not love.filesystem.getInfo(f.path) then bad[#bad + 1] = id .. ': falta ' .. f.path end
            end
            for name, a2 in pairs(data.anims) do
                for _, i in ipairs(a2.frames) do if i < 1 or i > #s.frames then bad[#bad + 1] = id .. '.' .. name .. ': cuadro ' .. i end end
            end
            for vn, v in pairs(data.variants or {}) do
                for _, f in ipairs(Anim.fromData(data, vn).frames) do
                    if not love.filesystem.getInfo(f.path) then bad[#bad + 1] = id .. '#' .. vn .. ': falta ' .. f.path end
                end
            end
        end
    end
    check('anim_juego', #bad == 0 and n >= 2, ('%d conjuntos; mal: %s'):format(n, #bad > 0 and table.concat(bad, ', ') or 'ninguno'))

    -- ── por_nombre: lo que ya pide sus animaciones POR NOMBRE se ve IGUAL que cuando el código elegía el cuadro por
    -- su número en la hoja (las fórmulas de antes, aquí escritas): mismo trozo de la misma imagen en cada estado
    do
        local diffs, n2 = {}, 0
        local function same(what, set, fi, sheet, idx, fw)
            n2 = n2 + 1
            local f = set.frames[fi]
            if not f or not f.path:find(sheet, 1, true) or f.x ~= (idx - 1) * fw then
                diffs[#diffs + 1] = ('%s: cuadro %s de %s, esperado el %d'):format(what, f and (f.x / fw + 1) or '?', f and f.path:match('[^/]+$') or '?', idx)
            end
        end
        -- Gloomy y Mega Gloomy (constantes de antes: andar 1-4, quieto 5, agachado 6, salto 7, susto 8, muerto 9)
        local Gloomy = require('src/world/entities/types/enemies/gloomy').class
        local gset = Anim.load('enemies/gloomy')
        local function old(st, modeT, frame)
            if st == 'dead' then return 9 end
            if st == 'leap' then return 7 end
            if st == 'crouch' then return 6 end
            if st == 'idle' or st == 'rest' then return 5 end
            if st == 'taunt' then return (math.floor(modeT * 9) % 2 == 0) and 6 or 5 end
            if st == 'flee' and modeT < 0.12 then return 8 end
            if st == 'stunned' or st == 'frozen' then return 8 end
            return math.max(1, math.min(4, frame))
        end
        for _, st in ipairs({ 'dead', 'leap', 'crouch', 'idle', 'rest', 'taunt', 'flee', 'stunned', 'frozen', 'walk', 'hunt' }) do
            for i = 0, 30 do
                local me = setmetatable({ state = st, modeT = i * 0.031 + 0.004, frame = i % 4 + 1, deadTimer = i * 0.05 }, { __index = Gloomy })
                same('gloomy ' .. st, gset, me:frameNow(), 'gloomy-Sheet', old(st, me.modeT, me.frame), 26)
                same('gloomy brillo ' .. st, gset, me:frameNow('glow_'), 'glow-Sheet', old(st, me.modeT, me.frame), 26)
            end
        end
        local MG = require('src/world/entities/types/bosses/megagloomy').class
        local mset = Anim.load('bosses/megagloomy')
        local function oldMG(st, t, frame)
            if st == 'dying_out' or st == 'dead' then return 9 end
            if st == 'dying_curl' then return 8 end
            if st == 'pounce' or st == 'dive' then return 7 end
            if st == 'taunt' then return (math.floor(t * 8) % 2 == 0) and 6 or 5 end
            if st == 'aim' or st == 'dazzled' or st == 'recover' or st == 'tired' or st == 'flinch' then return 6 end
            if st == 'roar' or st == 'shriek' then return 8 end
            if st == 'intro' or st == 'ready' then return (t >= 1.5 and t < 2.9) and 8 or 5 end
            if st == 'ping' or st == 'claw' or st == 'dormant' or st == 'ceil_ping' or st == 'ceil_wait' then return 5 end
            return math.max(1, math.min(4, frame))
        end
        for _, st in ipairs({ 'dying_out', 'dead', 'dying_curl', 'pounce', 'dive', 'taunt', 'aim', 'dazzled', 'tired', 'roar', 'intro', 'ready', 'ping', 'dormant', 'stalk', 'charge' }) do
            for i = 0, 40 do
                local me = setmetatable({ state = st, deadTimer = i * 0.083 + 0.004, frame = i % 4 + 1 }, { __index = MG })
                same('megagloomy ' .. st, mset, me:frameNow(), 'body-Sheet', oldMG(st, me.deadTimer, me.frame), 38)
                same('megagloomy brillo ' .. st, mset, me:frameNow('glow_'), 'glow-Sheet', oldMG(st, me.deadTimer, me.frame), 38)
            end
        end
        local w = mset.anims.walk
        if math.abs(1 / w.fps - 0.11) > 1e-9 or mset:fps('run') ~= 20 or #w.frames ~= 4 or gset:fps('walk') ~= 11 then diffs[#diffs + 1] = 'ritmo de andar' end
        -- Bomba (rehecha el 2026-10-08: ya no se compara con el dibujo viejo): tiene sus animaciones, la chispa de cada
        -- cuerpo, la punta de la mecha en cada cuadro del cuerpo, y la explosión dura los 0,6 s de la simulación
        local bset = Anim.load('enemies/bomb')
        for _, n in ipairs({ 'idle', 'walk', 'lit', 'object_idle', 'object_lit', 'fuse_idle', 'fuse_lit', 'object_fuse_idle', 'object_fuse_lit', 'explosion' }) do
            n2 = n2 + 1
            if not bset:has(n) then diffs[#diffs + 1] = 'bomba: falta la animación ' .. n end
        end
        for _, n in ipairs({ 'idle', 'walk', 'lit', 'object_idle', 'object_lit' }) do
            for k = 1, bset:count(n) do
                n2 = n2 + 1
                if type(bset:frame(bset:frameN(n, k)).data.tip) ~= 'table' then diffs[#diffs + 1] = 'bomba: ' .. n .. ' sin punta de mecha' end
            end
        end
        if math.abs(bset:length('explosion') - 0.6) > 0.01 or bset.anims.explosion.loop then diffs[#diffs + 1] = 'bomba: la explosión no dura 0,6 s' end
        -- Pez globo: nadar 1-2 a 2,5/s; aviso: tiembla 1 ↔ 3 cada 0,06 s y a los 0,3 s se queda en el 3; hinchado 4; deshinchar 3 → 1
        local pset = Anim.load('enemies/pufferfish')
        for i = 0, 60 do
            local t = i * 0.0113 + 0.001
            same('pez nadar', pset, (pset:frameAt('swim', t * 7)), 'puffer_fish', math.floor(t * 7 * 2.5) % 2 + 1, 16)
            same('pez aviso', pset, (pset:frameAt('warn', t)), 'puffer_fish', (t < 0.3 and math.floor(t / 0.06) % 2 == 0) and 1 or 3, 16)
            same('pez deshincha', pset, (pset:frameAt('deflate', t)), 'puffer_fish', (t < 0.4 * 0.6) and 3 or 1, 16)
            same('pez hinchado', pset, (pset:frameAt('puffed', t)), 'puffer_fish', 4, 16)
        end
        -- Gran Bola de Nieve (y Verity): el cuadro del cuerpo de antes (1-12; +4 enfadada) y el de rodar (1-8 por giro)
        local Snow = require('src/world/entities/types/bosses/snowboss').class
        local SW, SG = { 0.4, 0.32, 0.24 }, { 0.18, 0.15, 0.11 }
        local function oldSnow(me)
            local st, t = me.state, me.deadTimer
            local b = (me.phase >= 2) and 4 or 0
            if st == 'roll' or st == 'slide' or (st == 'intro' and t < 2.2) then
                return 'roll', math.floor(-(me.x / (7 * me.sc)) / (math.pi / 4)) % 8 + 1
            end
            if st == 'dizzy' or st == 'soaked' then return 'body', 11 + math.floor(t * 6) % 2 end
            if st == 'dying_crack' then return 'body', 10 end
            if me.inv > 0 and not me.ghost and st == 'recover' then return 'body', (me.phase >= 2) and 10 or 9 end
            if st == 'land' or st == 'slam_land' or st == 'leap_land' then return 'body', b + ((t < 0.12) and 3 or 2) end
            if st == 'windup' or st == 'leap_wind' then return 'body', b + 3 end
            if st == 'leap' then return 'body', b + 4 end
            if st == 'shoot' then
                local u = t - SW[me.phase]
                if u < 0 then return 'body', b + 2 end
                return 'body', b + ((u % SG[me.phase]) < SG[me.phase] * 0.6 and 4 or 1)
            end
            if st == 'phase_up' then return 'body', 8 end
            if st == 'slam_hold' then return 'body', b + 4 end
            if st == 'rest' then return 'body', b + ((math.floor(t * 3) % 2 == 0) and 1 or 2) end
            if st == 'intro' or st == 'ready' then
                if t >= 2.2 and t < 2.45 then return 'body', 3 end
                if t >= 2.6 and t < 3.2 then return 'body', (math.floor((t - 2.6) * 8) % 2 == 0) and 4 or 2 end
                if t >= 3.2 and t < 3.45 then return 'body', (t < 3.3) and 2 or 3 end
                if t >= 3.45 and t < 3.78 + 0.15 then return 'body', 4 end
                return 'body', 1
            end
            return 'body', b + 1
        end
        for _, verity in ipairs({ false, true }) do
            for _, st in ipairs({ 'roll', 'slide', 'intro', 'ready', 'dizzy', 'soaked', 'dying_crack', 'recover', 'land', 'slam_land', 'windup',
                                  'leap_wind', 'leap', 'shoot', 'phase_up', 'slam_hold', 'rest', 'idle', 'chase' }) do
                for ph = 1, 3 do
                    for i = 0, 45 do
                        local me = setmetatable({ state = st, deadTimer = i * 0.0937 + 0.003, phase = ph, x = i * 37.3, sc = 6, inv = (i % 2), ghost = false,
                                                  verity = verity }, { __index = Snow })
                        local kind, idx = oldSnow(me)
                        local k2, clip, step = me:pose()
                        local sheet = (kind == 'roll') and ((ph >= 2) and 'roll_angry' or 'roll_happy') or 'body-Sheet'
                        n2 = n2 + 1
                        local f = clip:rec(step)
                        if k2 ~= kind or not f.path:find(sheet, 1, true) or f.x ~= (idx - 1) * 16 or (f.path:find('verity', 1, true) ~= nil) ~= verity or f.data.ck ~= idx then
                            diffs[#diffs + 1] = ('bola %s fase %d t=%.2f: cuadro %d de %s, esperado el %d de %s'):format(st, ph, me.deadTimer, f.x / 16 + 1, f.path:match('[^/]+$'), idx, sheet)
                        end
                    end
                end
            end
        end
        -- Rey Gummy: andar = cuadros 2 y 3 a 6/s; el resto, un cuadro por estado
        local gset = Anim.load('bosses/megagummy')
        for i, n in ipairs({ 'idle', false, false, 'jump', 'dazed', 'hurt', 'laugh', 'shout' }) do
            if n then same('rey ' .. n, gset, (gset:frameAt(n, 0.37)), 'megagummy/body-Sheet', i, 16) end
        end
        for i = 0, 40 do
            local now = i * 0.0531 + 0.002
            same('rey andar', gset, (gset:frameAt('walk', now)), 'megagummy/body-Sheet', (math.floor(now * 6) % 2 == 0) and 2 or 3, 16)
            same('rey ola', gset, (gset:frameAt('wave', now)), 'wave-Sheet', math.floor(now * 10) % 2 + 1, 12)
        end
        -- Congelador: quieto 1; cargando 2 → 3 a mitad de la carga; disparando 4. Mega Crabby: patalear / escarbar
        local cb, cc = Anim.clip('traps/cryo', 'charge'), Anim.clip('traps/cryo', 'cannon_charge')
        for i = 0, 20 do
            local k = i / 20
            n2 = n2 + 2
            if cb:rec(cb:atProgress(k)).x ~= (((k < 0.5) and 2 or 3) - 1) * 16 or cc:rec(cc:atProgress(k)).x ~= (((k < 0.5) and 2 or 3) - 1) * 16 then diffs[#diffs + 1] = 'congelador cargando' end
        end
        same('congelador quieto', Anim.load('traps/cryo'), (Anim.load('traps/cryo'):frameAt('idle', 1)), 'cryo_body', 1, 16)
        same('congelador dispara', Anim.load('traps/cryo'), (Anim.load('traps/cryo'):frameAt('fire', 1)), 'cryo_body', 4, 16)
        for _, sid in ipairs({ 'bosses/megacrabby', 'bosses/megacrabby_ice' }) do
            for name, fps in pairs({ wiggle = 12, kick = 24, dig = 14, windup = 18 }) do
                local c = Anim.clip(sid, name)
                for i = 0, 30 do
                    local t = i * 0.0213 + 0.001
                    n2 = n2 + 1
                    if not c:rec(c:at(t)).path:find('crab' .. (math.floor(t * fps) % 3 + 1) .. '.png', 1, true) then diffs[#diffs + 1] = sid .. ' ' .. name end
                end
            end
            n2 = n2 + 1
            if not Anim.clip(sid, 'idle'):rec(1).path:find('crab2.png', 1, true) or Anim.clip(sid, 'walk').count ~= 3 then diffs[#diffs + 1] = sid .. ' idle' end
        end
        check('por_nombre', #diffs == 0, ('%d comparaciones con el dibujo de antes; distintas: %s'):format(n2, #diffs > 0 and (#diffs .. ' — ' .. diffs[1]) or 'ninguna'))
    end

    -- ── enemigos de datos ── (un enemigo de prueba sobre el conjunto del Gummy; no entra en el juego)
    local function spec(id, extra)
        local s = DataEnemy.blank(id)
        s.anim, s.label = 'enemies/gummy', 'Prueba ' .. id
        s.defaults = { movement = 'walk', speed = 60, points = 10, onTouch = 'hurt', stompable = true, pauses = false }
        for k, v in pairs(extra or {}) do s[k] = v end
        Entities.types.register(DataEnemy.typeDef(s))
        return s
    end
    spec('zz_plain')
    spec('zz_chase', { behaviors = { { type = 'chase', range = 5, giveUp = 0.5 } } })
    spec('zz_melee', { behaviors = { { type = 'melee', range = 2, windup = 0.3, active = 0.2, rest = 0.2, reach = 1.5, cooldown = 1 } } })
    spec('zz_leap', { behaviors = { { type = 'leap', range = 6, every = 2, windup = 0.2, height = 2, dist = 4 } } })
    spec('zz_shoot', { behaviors = { { type = 'shoot', range = 8, windup = 0.2, rest = 0.2, speed = 400, cooldown = 3 } } })
    spec('zz_tank', { hp = 3, hurtTime = 0.3 })

    local function room(W, ents)
        local H, tiles = 8, {}
        for r = 1, H do
            local row = {}
            for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
            tiles[r] = row
        end
        local level = Level.fromData({ name = 'test', width = W, height = H, playerStart = { 2, H - 1 }, tiles = tiles, entities = ents })
        local es = {}
        for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
        level.liveEntities = es
        return level, es
    end
    local function playerAt(level, col)
        local pa = PlayerAdventure:new((col - 0.5) * T, 7 * T - 60)
        level.players = {}
        for _ = 1, 30 do pa:update(1 / 60, level) end
        level.players = { pa }
        return pa
    end
    local function run(level, es, secs, pa, each)
        for i = 1, math.floor(secs * 60) do
            if pa then pa:update(1 / 60, level) end
            for _, e in ipairs(es) do if e.alive then e:update(1 / 60, level) end end
            if pa then Interactions.run(pa, es, {}) end
            if each then each(i / 60) end
        end
    end
    local function far(pa) pa.x = -9999 end

    -- registro
    local def = Entities.types.byName.zz_plain
    local hasSpeed = false
    for _, p in ipairs(def.schema) do if p.key == 'speed' and p.default == 60 then hasSpeed = true end end
    local level, es = room(20, { { type = 'zz_plain', col = 10, row = 7 } })
    check('registro', def and def.dataEnemy and hasSpeed and def.editor and def.editor.sprite and #es == 1 and es[1].sprW == 64,
          ('tipo %s, speed por defecto %s, miniatura %s, sprite %s px'):format(tostring(def and def.name), tostring(hasSpeed), tostring(def.editor and def.editor.sprite), tostring(es[1] and es[1].sprW)))

    -- anda
    local e = es[1]
    level.players = {}
    local x0, turned, frames = e.x, false, {}
    run(level, es, 8, nil, function() if e.facing < 0 then turned = true end; frames[e.frame] = true end)
    check('anda', math.abs(e.x - x0) > 0 or turned, ('se movió %.0f px, se giró %s, cuadros de andar %s'):format(e.x - x0, tostring(turned), (frames[1] and frames[2]) and '1 y 2' or '?'))

    -- persigue
    level, es = room(30, { { type = 'zz_chase', col = 20, row = 7, props = { startDir = 'right', patrol = false } } })
    e = es[1]
    local pa = playerAt(level, 16)
    pa.invT = 99
    local ran, minD = false, 1e9
    run(level, es, 1.5, nil, function() if e.state == 'run' then ran = true end; minD = math.min(minD, math.abs(e.x - pa.x)) end)
    far(pa)
    run(level, es, 1.5)
    check('persigue', ran and minD < 2 * T and e.state ~= 'run', ('corrió %s, se acercó a %.0f px, al irse el jugador: %s'):format(tostring(ran), minD, e.state))

    -- ataca
    level, es = room(30, { { type = 'zz_melee', col = 20, row = 7, props = { movement = 'static', onTouch = 'none' } } })
    e = es[1]
    pa = playerAt(level, 19)
    pa.x = e.x - 1.2 * T
    local hpAt, seen = {}, {}
    run(level, es, 1.2, pa, function(t) seen[e.state] = true; hpAt[#hpAt + 1] = { t, pa.hp, e.state, e.deadTimer } end)
    local firstHit
    for _, h in ipairs(hpAt) do if h[2] < 3 and not firstHit then firstHit = h end end
    check('ataca', seen.attack and firstHit and firstHit[4] >= 0.3 and firstHit[4] < 0.55 and pa.hp == 2 and (e.cd_melee or 0) > 0,
          ('estado attack %s; primer golpe a los %.2f s del ataque (aviso 0.30); vida %d; en espera %s'):format(tostring(seen.attack), firstHit and firstHit[4] or -1, pa.hp, tostring((e.cd_melee or 0) > 0)))

    -- salta
    level, es = room(30, { { type = 'zz_leap', col = 20, row = 7, props = { movement = 'static', onTouch = 'none' } } })
    e = es[1]
    pa = playerAt(level, 16); pa.invT = 99
    local xs, top, sp = e.x, e.y, false
    run(level, es, 2.0, nil, function() if e.state == 'special' then sp = true end; top = math.min(top, e.y) end)
    check('salta', sp and (xs - e.x) > 1.5 * T and (es[1].home.y - top) > 1.2 * T and e.onGround and e.state ~= 'special',
          ('estado special %s; avanzó %.1f casillas hacia el jugador; subió %.1f; acabó en %s'):format(tostring(sp), (xs - e.x) / T, (e.home.y - top) / T, e.state))

    -- dispara
    level, es = room(30, { { type = 'zz_shoot', col = 22, row = 7, props = { movement = 'static', onTouch = 'none' } } })
    e = es[1]
    pa = playerAt(level, 17)
    local maxShots, hpMin = 0, 3
    run(level, es, 2.5, pa, function() maxShots = math.max(maxShots, #e.shots); hpMin = math.min(hpMin, pa.hp) end)
    check('dispara', maxShots == 1 and hpMin == 2 and #e.shots == 0, ('proyectiles a la vez %d, vida mínima %d, al final quedan %d'):format(maxShots, hpMin, #e.shots))

    -- vida
    level, es = room(20, { { type = 'zz_tank', col = 10, row = 7, props = { movement = 'static' } } })
    e = es[1]
    level.players = {}
    local log = {}
    for i = 1, 3 do
        e:stomp(); log[#log + 1] = e.state .. '/' .. tostring(e.hp)
        local disabled = e:isBodyDisabled()
        run(level, es, 0.5)
        log[#log] = log[#log] .. (disabled and '*' or '')
    end
    check('vida', log[1] == 'hurt/2*' and log[2] == 'hurt/1*' and log[3]:match('^dead'), table.concat(log, ' → '))

    -- trepa
    spec('zz_crawl', { crawl = true })
    level, es = room(12, { { type = 'zz_crawl', col = 6, row = 7, props = { patrol = false, speed = 120 } } })
    e = es[1]
    level.players = {}
    local wall, ceil, fell = false, false, false
    run(level, es, 16, nil, function()
        if e.cattached and e.cnx ~= 0 then wall = true end
        if e.cattached and e.cny == 1 then ceil = true end
        if e.y > 8 * T then fell = true end
    end)
    check('trepa', e.crawl and wall and ceil and not fell, ('trepador %s; pared %s, techo %s, se cayó %s'):format(tostring(e.crawl), tostring(wall), tostring(ceil), tostring(fell)))

    -- esconde
    spec('zz_hide', { behaviors = { { type = 'hide', every = 0.3, inTime = 0.2, stay = 1.0, outTime = 0.2, cover = 'hurt' } } })
    level, es = room(20, { { type = 'zz_hide', col = 10, row = 7, props = { movement = 'static', onTouch = 'none' } } })
    e = es[1]
    pa = playerAt(level, 10); pa.x = e.x; pa.invT = 0
    local sawHide, disabledSeen, an = false, false, {}
    run(level, es, 2.2, pa, function()
        if e.state == 'hide' then sawHide = true; an[(e:animNow())] = true end
        if e:isBodyDisabled() then disabledSeen = true end
    end)
    local hpAfter = pa.hp
    e.state, e.deadTimer, e.owner = 'hide', 0.6, e.beh[1]; e.hp = 1
    e:stomp()
    check('esconde', sawHide and disabledSeen and hpAfter < 3 and e.state == 'hide' and an.hide,
          ('se escondió %s; intocable escondido %s; la tapa quitó vida (%d de 3); pisarlo escondido no lo mata (%s)'):format(tostring(sawHide), tostring(disabledSeen), hpAfter, e.state))

    -- jefe
    local BossZones = require 'src/world/systems/BossZones'
    local bs = spec('zz_boss', { behaviors = { { type = 'melee', range = 2.5, windup = 0.3, active = 0.3, rest = 0.2, reach = 2, cooldown = 0.5 } },
                                 boss = { title = 'PRUEBA', hp = 4, hpPerPlayer = 0, walkSpeed = 120, contact = 0, tiredTime = 1.5, attackEvery = 0.5, intro = 1 } })
    do
        local W, H, tiles = 24, 10, {}
        for r = 1, H do
            local row = {}
            for c = 1, W do row[c] = (r == H or c == 1 or c == W) and 1 or 0 end
            tiles[r] = row
        end
        level = Level.fromData({ name = 'jefe', width = W, height = H, playerStart = { 4, H - 1 }, tiles = tiles,
                                 entities = { { type = 'zz_boss', col = 16, row = H - 1 } },
                                 bossZones = { { id = 1, col = 2, row = 2, w = W - 2, h = H - 2 } } })
        es = {}
        for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
        level.liveEntities = es
        BossZones.link(level, es)
        local ctl = BossZones.newController(level, es)
        local boss = es[1]
        pa = PlayerAdventure:new(6.5 * T, (H - 1) * T - 60)
        level.players = { pa }
        local seen, hpMin, hits, tiredHit = {}, 3, 0, false
        for i = 1, 60 * 40 do
            level.solidBodies = Entities.solidBodies(es)
            pa.invT = 0
            pa:update(1 / 60, level)
            if boss.alive then boss:update(1 / 60, level) end
            ctl:update(1 / 60)
            seen[boss.state] = true
            hpMin = math.min(hpMin, pa.hp)
            if pa.hp < 3 then pa.hp = 3 end
            pa.dying, pa.alive = false, true
            -- en cuanto se cansa: un pisotón (como haría el jugador)
            if boss.state == 'tired' and boss.inv <= 0 then
                local before = boss.hp
                boss:stomp(); hits = hits + 1
                if boss.hp < before then tiredHit = true end
            end
            if not boss.alive then break end
        end
        local z = level.bossZones[1]
        local title = boss:title()
        check('jefe', seen.intro and seen.fight and seen.attack and seen.tired and hpMin < 3 and tiredHit and not boss.alive and z.state == 'cleared' and title == 'PRUEBA'
              and Entities.types.byName.zz_boss.category == 'Jefes',
              ('estados: %s%s%s%s; el golpe quitó vida %s; golpes dados cansado %d; muerto %s; zona %s; nombre %s'):format(seen.intro and 'intro ' or '', seen.fight and 'fight ' or '',
               seen.attack and 'attack ' or '', seen.tired and 'tired' or '', tostring(hpMin < 3), hits, tostring(not boss.alive), tostring(z.state), tostring(title)))
    end

    -- red
    level, es = room(30, { { type = 'zz_shoot', col = 22, row = 7, props = { movement = 'static' } }, { type = 'zz_shoot', col = 5, row = 3, props = { movement = 'static' } } })
    local srv, cli = es[1], es[2]
    srv.hp = 1; srv:addShot(100, 200, 50, 0, 2, 20, 1); srv:addShot(300, 220, 50, 0, 2, 24, 1)
    local pk = srv:netPack()
    cli:netApply(pk, pk, 1)
    srv.state, srv.deadTimer = 'attack', 0.1; cli.state, cli.deadTimer = 'attack', 0.1
    local n1, t1 = srv:animNow(); local n2, t2 = cli:animNow()
    check('red', cli.hp == 1 and #cli.shots == 2 and cli.shots[2].x == 300 and cli.shots[2].size == 24 and n1 == n2 and t1 == t2,
          ('vida %d, proyectiles %d (x=%s), animación %s@%.2f = %s@%.2f'):format(cli.hp, #cli.shots, tostring(cli.shots[2] and cli.shots[2].x), n1, t1, n2, t2))

    -- avisos
    local w = DataEnemy.validate({ id = 'zz_melee', anim = 'enemies/gummy', behaviors = { { type = 'melee' }, { type = 'shoot' }, { type = 'no' } }, states = {} })
    local txt = table.concat(w, ' | ')
    check('avisos', txt:find('"attack"', 1, true) and txt:find('"hurt"', 1, true) and txt:find('shot', 1, true) and txt:find('no existe', 1, true) and #DataEnemy.validate({ id = 'Mal Id', anim = 'enemies/gummy' }) >= 1,
          #w .. ' avisos: ' .. txt:sub(1, 150))

    -- indice
    local ib = {}
    local ids = DataEnemy.ids()
    for _, id in ipairs(ids) do
        local s, err = DataEnemy.read(id)
        if not s then ib[#ib + 1] = id .. ': ' .. tostring(err)
        elseif not Entities.types.byName[id] or not Entities.types.byName[id].dataEnemy then ib[#ib + 1] = id .. ': sin registrar'
        else
            local ok = pcall(Entities.create, { type = id, col = 3, row = 3, props = {} })
            if not ok then ib[#ib + 1] = id .. ': no se crea' end
            if not Anim.read(s.anim) then ib[#ib + 1] = id .. ': sin conjunto ' .. tostring(s.anim) end
        end
    end
    check('indice', #ib == 0, ('%d enemigos de datos; mal: %s'):format(#ids, #ib > 0 and table.concat(ib, ', ') or 'ninguno'))

    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
