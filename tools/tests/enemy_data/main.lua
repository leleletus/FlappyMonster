-- tools/tests/enemy_data — animaciones como datos (src/fx/Anim.lua) y enemigos hechos con datos
-- (src/world/entities/base/DataEnemy.lua + src/world/entities/behaviors/), sin ventana:
--   anim_tiempos   cuadro por tiempo: bucle, duraciones por cuadro, secuencia que no se repite, reserva
--   anim_avisos    los avisos (`events`) de una secuencia salen una vez por pasada
--   anim_variante  una variante cambia las imágenes y no las secuencias
--   anim_juego     todos los conjuntos de assets/anim cargan y sus secuencias apuntan a cuadros que existen
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
