-- tools/tests/icecrabby_rules — reglas del CRABBY HELADO (types/crabby_ice.lua), caso a caso en
-- salas hechas a mano:
--   hundirse      al esconderse se hunde fila a fila (los 8 cuadros sink) y acaba escondido
--   tapa_pegada   púa / carámbano / trampolín bien pegados a la cabeza en TODO el esconderse y
--                 el salir: la base de su caja = la fila de arriba OPACA del cuadro actual (medida en
--                 el PNG) menos 2 px de arte (púa y carámbano encajados; el trampolín encima), ±1 px
--   pinzas        Crabby helado con pinzas pequeñas (dibujo): andando se ven a los dos lados
--                 por fuera del cuerpo; escondido, no; el Crabby normal no tiene
--   escombros     al esconderse suelta piedrecitas del bloque de debajo (Crabby normal y helado)
--   pua           escondido bajo la púa de hielo: tocarla mata (como el Crabby)
--   carambano     escondido bajo un carámbano: tocarlo = -2 de vida + empujón
--   nieve_toque   tocar el montón: se agrieta sin daño; al reventar, quien siga encima -1 + empujón
--   nieve_encima  caerle encima: revienta debajo y te lanza hacia arriba, sin daño
--   nieve_gp      ground pound encima del montón: el Crabby muere
--   nieve_techo   del techo con nieve: el pegote cae encima: -1 y aturdido; luego anda por el suelo
--   carambano_techo  del techo con carámbano: cae encima: -2
--   trampolin     escondido con el trampolín de hielo: caerle encima lanza
--   pared         trepador en una pared escondido bajo un carámbano: la caja sale de la pared
-- MEGA CRABBY HELADO (types/megacrabby_ice.lua):
--   mega_palmada  tras una embestida: palmada → 2 ondas que congelan a quien está en el suelo
--                 (no a quien salta por encima) → pinzas pegadas → recover → chase
--   mega_pinzas   pinzas pegadas: pisar el lomo rebota sin daño, pisotón en una pinza rebota sin
--                 daño, ground pound en una pinza = -2 y se suelta (un golpe por palmada)
--   mega_placa    al caer del salto desde la pared deja una placa que resbala; dura patchTime,
--                 ragePatchTime enfadado; se acaba al morir
--   mega_red      netPackExtra → netApplyExtra: ondas y placas iguales en el cliente (y en su nivel)
-- PINCHOS DE HIELO (src/world/SpikeSkins.lua, JSON "spikeSkin"):
--   pinchos_skin  el nivel guarda su aspecto (Level y el modelo del editor, ida y vuelta) y los
--                 niveles helados lo usan
--   LOOK=1        además guarda <save>/icecrabby_look.png: las 4 tapas andando y escondidas, en
--                 suelo, techo y pared, y un montón agrietándose
--
--   tools/tests/run.sh icecrabby_rules   (CASE=nombre: solo ese)
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
local T = TILE_PX

local fails = 0
local function check(case, ok, msg)
    print(('%-15s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H: suelo (fila H), techo (fila 1) y paredes; `blocks` = { {c, r}, ... } más bloques
local function room(W, H, ents, blocks)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = 1 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {} })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    for _, e in ipairs(es) do if e.tryAttach then e:tryAttach(level) end end
    return level, es, es[1]
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end

local function player(level, x, y)
    clearInput()
    local pa = PlayerAdventure:new(x, y)
    level.players = { pa }
    return pa
end

-- Simula `secs` s: jugadores, nivel, entidades, interacciones
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

-- Lo deja escondido (tapa fuera)
local function hide(e)
    e.state, e.spikeProgress, e.currentImg = 'hidden', 1, e.sk.hid
    e.hideTimer, e.hideDuration, e.peeking = 0, 99, false
end

local function ent(type, col, row, props)
    local p = { movement = 'walk', pauses = true, canHide = true, hideChance = 1 }
    for k, v in pairs(props or {}) do p[k] = v end
    return { type = type, col = col, row = row, props = p }
end

local cases = {}

-- Fila de arriba opaca de cada imagen (medida en el PNG, no con lo que dice el código)
local topRows = {}
local function opaqueRows(img)
    if topRows[img] == nil then
        local Crabby = require('src/world/entities/types/crabby').class
        local name = Crabby.getImgName({ currentImg = img, sk = Crabby.SKINS.ice })
        local file = name:gsub('^ice_', '')
        file = ({ idle1 = 'crab1', idle2 = 'crab2', idle3 = 'crab3' })[file] or file
        file = file:match('^s(%d)$') and ('sink' .. file:sub(2)) or file
        local ok, d = pcall(love.image.newImageData, 'assets/images/crabby_ice/' .. file .. '.png')
        local rows = 0
        if ok then
            for y = 0, d:getHeight() - 1 do
                local any = false
                for x = 0, d:getWidth() - 1 do if select(4, d:getPixel(x, y)) > 0 then any = true; break end end
                if any then rows = d:getHeight() - y; break end
            end
        end
        topRows[img] = rows
    end
    return topRows[img]
end

function cases.tapa_pegada()
    local S = GUMMY_SCALE
    local worst, seen, info = 0, 0, {}
    for _, t in ipairs({ { 'crabby_ice', 2 }, { 'crabby_ice_icicle', 2 }, { 'crabbytramp_ice', 0 } }) do
        local level, es, e = room(20, 8, { ent(t[1], 10, 7) })
        step(level, es, 0.3)
        local feet = e.y + e.sprH / 2
        local maxd = 0
        local function measure()
            local box = e.trampBox and e:trampBox() or e:getSpikeHitbox()
            if not box or box.h < 2 then return end
            local want = feet - math.max(0, opaqueRows(e.currentImg) - t[2]) * S
            local d = math.abs((box.y + box.h) - want)
            if d > maxd then maxd = d end
            seen = seen + 1
        end
        e.state, e.hideTransTimer = 'hide_in', 0
        step(level, es, 1.2, function() measure(); return e.state == 'hidden' end)
        e.hideDuration = 0
        step(level, es, 1.2, function() measure(); return e.state == 'walk' end)
        info[#info + 1] = ('%s %.0f'):format(t[1], maxd)
        if maxd > worst then worst = maxd end
    end
    check('tapa_pegada', worst <= 1 and seen > 30,
        ('desfase máximo base de la tapa / cabeza (px): %s · %d pasos medidos'):format(table.concat(info, ', '), seen))
end

function cases.pinzas()
    local function sides(ty, hidden)
        local level, es, e = room(8, 4, { ent(ty, 4, 3) })
        step(level, es, 0.2)
        if hidden then hide(e) else e.state, e.currentImg = 'walk', e.sk.idle1 end
        local cv = love.graphics.newCanvas(8 * T, 4 * T)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 0)
        e:render(0, 0)
        love.graphics.setCanvas()
        local d = cv:newImageData()
        local n = { 0, 0 }
        local cx = math.floor(e.x)
        local half = e.sk.idle1:getWidth() * GUMMY_SCALE / 2
        for y = 0, d:getHeight() - 1 do
            for i, sd in ipairs({ -1, 1 }) do
                for k = half + 1, half + 12 do
                    local r, g, b, a = d:getPixel(cx + sd * k, y)
                    if a > 0 and r > 0.6 and g < 0.8 then n[i] = n[i] + 1 end   -- (naranja)
                end
            end
        end
        return n
    end
    local walk = sides('crabby_ice')
    local hid = sides('crabby_ice', true)
    local tramp = sides('crabbytramp_ice')
    local normal = sides('crabby')
    check('pinzas', walk[1] > 10 and walk[2] > 10 and hid[1] + hid[2] == 0 and tramp[1] > 10 and tramp[2] > 10
        and normal[1] + normal[2] == 0,
        ('píxeles de pinza fuera del cuerpo (izq/der): andando %d/%d · escondido %d/%d · trampolín %d/%d · Crabby normal %d/%d'):format(
            walk[1], walk[2], hid[1], hid[2], tramp[1], tramp[2], normal[1], normal[2]))
end

function cases.hundirse()
    local level, es, e = room(20, 8, { ent('crabby_ice_snow', 10, 7) })
    step(level, es, 0.5)
    e.state, e.hideTransTimer = 'hide_in', 0
    local seen, n = {}, 0
    step(level, es, 1.5, function()
        local name = e:getImgName()
        if name:match('^ice_s%d') and not seen[name] then seen[name] = true; n = n + 1 end
        return e.state == 'hidden'
    end)
    check('hundirse', n >= 7 and e.state == 'hidden',
        ('cuadros de hundirse vistos: %d; estado %s (tapa %.2f)'):format(n, e.state, e.spikeProgress))
end

function cases.escombros()
    local Particles = require 'src/fx/Particles'
    local got = {}
    local orig = Particles.emit
    Particles.emit = function(k, ...) if k == 'crab_dig' then got[#got + 1] = k end return orig(k, ...) end
    local level, es = room(20, 8, { ent('crabby', 6, 7), ent('crabby_ice', 14, 7) })
    step(level, es, 0.3)
    local ok = {}
    for i, e in ipairs(es) do
        got = {}
        e.state, e.hideTransTimer = 'hide_in', 0
        local clock = 0
        love.timer.getTime = function() return clock end
        for _ = 1, 60 do
            clock = clock + 1 / 60
            e:update(1 / 60, level)
            e:render(0, 0)
        end
        ok[i] = #got
    end
    Particles.emit = orig
    check('escombros', ok[1] > 0 and ok[2] > 0, ('emisiones al esconderse: Crabby %d, Crabby helado %d'):format(ok[1], ok[2]))
end

function cases.pua()
    local level, es, e = room(20, 8, { ent('crabby_ice', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local hb = e:getHazardBoxes()[1]
    local pa = player(level, hb.x + hb.w / 2, hb.y + 4)
    local r = Interactions.check(pa, e)
    check('pua', r == 'kill', ('tocar la púa de hielo: %s'):format(tostring(r)))
end

function cases.carambano()
    local level, es, e = room(20, 8, { ent('crabby_ice_icicle', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local hb = e:getHazardBoxes()[1]
    local pa = player(level, hb.x + hb.w / 2 + 20, hb.y + hb.h / 2)
    local hp0 = pa.hp
    Interactions.run(pa, es, {})
    check('carambano', pa.hp == hp0 - 2 and math.abs(pa.vx) > 100,
        ('vida %d→%d, empujón vx %d (efecto %s, daño %s)'):format(hp0, pa.hp, pa.vx, tostring(hb.effect), tostring(hb.dmg)))
end

function cases.nieve_toque()
    local level, es, e = room(20, 8, { ent('crabby_ice_snow', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local mb = e:moundBox()
    local pa = player(level, mb.x - 70, 7 * T - 60)                -- cerca del montón
    step(level, es, 0.4)
    pa.x = mb.x + 10                                               -- lo toca
    local hp0 = pa.hp
    local crackHp, cracked
    step(level, es, 0.2, function()
        if e.state == 'snow_crack' and not cracked then cracked = true; crackHp = pa.hp end
    end)
    local stCrack = e.state
    pa.x = e.x                                                     -- sigue encima al reventar
    step(level, es, 0.4)
    check('nieve_toque', cracked and crackHp == hp0 and pa.hp == hp0 - 1 and e.state ~= 'hidden',
        ('al tocar: %s, vida %s (sin daño); al reventar vida %d→%d, cangrejo %s'):format(
            stCrack, tostring(crackHp), hp0, pa.hp, e.state))
end

function cases.nieve_encima()
    local level, es, e = room(20, 8, { ent('crabby_ice_snow', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local mb = e:moundBox()
    local pa = player(level, e.x, mb.y - 200)
    pa.vy = 300
    local hp0 = pa.hp
    local launched = false
    step(level, es, 0.8, function() if pa.vy < -300 then launched = true end end)
    check('nieve_encima', launched and pa.hp == hp0 and e.state ~= 'hidden',
        ('lanzado=%s, vida %d→%d, cangrejo %s'):format(tostring(launched), hp0, pa.hp, e.state))
end

function cases.nieve_gp()
    local level, es, e = room(20, 8, { ent('crabby_ice_snow', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local mb = e:moundBox()
    local pa = player(level, e.x, mb.y - 120)
    pa.gpPhase, pa.vy = 'fall', 900
    step(level, es, 0.5)
    check('nieve_gp', e.state == 'dead' or not e.alive, ('ground pound sobre el montón: cangrejo %s'):format(e.state))
end

local function ceilingDrop(type, wantDmg, name)
    local level, es, e = room(20, 9, { ent(type, 10, 2, { attach = 'ceiling', dropOnSight = true, detectRange = 8 }) })
    step(level, es, 0.3)
    hide(e)
    local pa = player(level, e.x, 8 * T - 60)
    step(level, es, 0.3)
    local hp0 = pa.hp
    local maxStun = 0
    step(level, es, 4, function() maxStun = math.max(maxStun, pa.stunT or 0) end)
    return level, es, e, pa, hp0, maxStun
end

function cases.nieve_techo()
    local _, _, e, pa, hp0, stun = ceilingDrop('crabby_ice_snow')
    check('nieve_techo', pa.hp == hp0 - 1 and stun > 0.3 and not e.flipped and (e.state == 'walk' or e.state == 'idle' or e:isHiding()),
        ('vida %d→%d, aturdido %.2f s, cangrejo %s en el suelo=%s'):format(hp0, pa.hp, stun, e.state, tostring(not e.flipped)))
end

function cases.carambano_techo()
    local _, _, e, pa, hp0 = ceilingDrop('crabby_ice_icicle')
    check('carambano_techo', pa.hp == hp0 - 2, ('vida %d→%d (cangrejo %s)'):format(hp0, pa.hp, e.state))
end

function cases.trampolin()
    local level, es, e = room(20, 8, { ent('crabbytramp_ice', 10, 7) })
    step(level, es, 0.3)
    hide(e)
    local tb = e:trampBox()
    local pa = player(level, e.x, tb.y - 40)
    pa.vy = 400
    local launched = false
    step(level, es, 0.5, function() if pa.vy < -700 then launched = true end end)
    check('trampolin', launched, ('lanzado por el trampolín de hielo=%s'):format(tostring(launched)))
end

function cases.pared()
    -- un trepador en la pared izquierda (columna 1 = pared): escondido, el carámbano sale hacia la derecha
    local level, es, e = room(12, 12, { ent('crabby_ice_icicle', 2, 6, { wallWalk = true }) })
    step(level, es, 0.1)
    e.cnx, e.cny, e.cattached = 1, 0, true
    e.x = T + e.sprH / 2
    hide(e)
    local hb = e:getHazardBoxes()[1]
    local cx = hb.x + hb.w / 2
    -- (escondido, el carámbano sale de la cara de la pared, x = T, hacia dentro de la sala)
    check('pared', hb and hb.x >= T - 2 and cx > T + 20 and hb.w > hb.h,
        ('caja del carámbano: x %.0f..%.0f (pared en %d), %dx%d'):format(hb.x, hb.x + hb.w, T, hb.w, hb.h))
end

-- Captura: las 4 tapas en suelo (andando / escondido), techo y pared
-- ── Mega Crabby helado ───────────────────────────────────────────────────────
local function mega(W)
    local level, es, e = room(W or 34, 10, { { type = 'megacrabby_ice', col = 17, row = 9, props = {} } })
    level.players = {}
    e:startFight(1)
    e.state, e.deadTimer = 'chase', 0
    step(level, es, 0.3)
    return level, es, e
end

function cases.mega_palmada()
    local level, es, e = mega(40)
    local pa = player(level, e.x + 520, 9 * T - 40)
    local jumper = PlayerAdventure:new(e.x - 520, 9 * T - 40)
    level.players = { pa, jumper }
    step(level, es, 0.4)
    e.chargeDir, e.facing, e.travel, e.state, e.deadTimer = 1, 1, 1e9, 'charge', 0
    e.graceT = 0
    local seq, frozenA, frozenB, last = {}, false, false, nil
    step(level, es, 4, function()
        if e.state ~= last then seq[#seq + 1] = e.state; last = e.state end
        -- el saltador salta justo cuando la onda le llega
        for _, w in ipairs(e.waves) do
            if w.dir < 0 and math.abs(w.x - jumper.x) < 140 and jumper.onGround then jumper.vy = -900; jumper.onGround = false end
        end
        if (pa.iceT or 0) > 0 then frozenA = true end
        if (jumper.iceT or 0) > 0 then frozenB = true end
        return last == 'chase' and #seq > 3
    end)
    local s = table.concat(seq, '>')
    check('mega_palmada', s:match('clap>clap_stuck>recover>chase') ~= nil and frozenA and not frozenB,
        ('estados %s; congelado en el suelo %s, el que salta %s'):format(s, tostring(frozenA), tostring(frozenB)))
end

function cases.mega_pinzas()
    local level, es, e = mega()
    local function stuck()
        e.state, e.deadTimer, e.hitDrop, e.inv = 'clap_stuck', 0, false, 0
        e.props.clapStuck = 30
    end
    local function drop(x, gp)
        local pa = player(level, x, e.y - e.outerH / 2 - 80)
        pa.vy = 600
        if gp then pa.gpPhase = 'fall' end
        local hp0 = e.hp
        step(level, es, 0.6, function() return e.hp ~= hp0 or e.state ~= 'clap_stuck' end)
        return hp0 - e.hp, pa
    end
    stuck()
    local d1 = drop(e.x, true)                                   -- lomo (ground pound)
    stuck()
    local cb = e:clawBoxes()[2]
    local d2 = drop(cb.x + cb.w - 30, false)                     -- pinza, pisotón
    stuck()
    local cl = e:clawBoxes()[1]
    local d3 = drop(cl.x + 30, true)                             -- pinza, ground pound
    local st = e.state
    check('mega_pinzas', d1 == 0 and d2 == 0 and d3 == 2 and st == 'recover',
        ('daño: lomo %d, pisotón en pinza %d, GP en pinza %d; luego %s'):format(d1, d2, d3, st))
end

function cases.mega_placa()
    local level, es, e = mega()
    e.state, e.deadTimer = 'pounce', 0
    e.vy, e.onGround = 0, true
    e.props.patchTime = 2
    e:addPatch(level)
    local fp = e.patches[1]
    e.state, e.recoverFor = 'recover', 99
    e.x = 30 * T                                                 -- (fuera de la placa)
    step(level, es, 0.05)
    local function slide(x)
        local pa = player(level, x, 9 * T - 40)
        step(level, es, 0.4)
        pa.vx = ADV_MOVE_SPD
        local x0 = pa.x
        step(level, es, 0.35)
        return pa.x - x0
    end
    local onP = slide((fp.x0 + fp.x1) / 2 - 60)
    local offP = slide(4 * T)
    step(level, es, 2)
    local gone = level.frostPatches == nil or #level.frostPatches == 0
    e.hp = 1
    e:addPatch(level)
    local rageLife = e.patches[#e.patches].left
    e:defeat()
    step(level, es, 0.05)
    check('mega_placa', onP > offP * 1.8 and gone and math.abs(rageLife - (e.props.ragePatchTime or 8)) < 0.01
        and level.frostPatches == nil,
        ('resbala %.0f px en la placa / %.0f fuera; caduca %s; enfadado dura %.1f s; al morir %s'):format(
        onP, offP, tostring(gone), rageLife, tostring(level.frostPatches)))
end

function cases.mega_red()
    local level, es, e = mega()
    e:spawnWaves()
    e:addPatch(level)
    local pk = e:netPackExtra()
    local level2 = room(34, 10, {})
    local r = Entities.create({ type = 'megacrabby_ice', col = 17, row = 9, props = {} })
    r.levelRef = level2
    r.state = 'clap'
    r:netApplyExtra(pk, pk, 1)
    local ok = #r.waves == 2 and #r.patches == 1 and level2.frostPatches == r.patches
        and math.abs(r.waves[2].x - math.floor(e.waves[2].x)) < 1 and r.patches[1].x0 == e.patches[1].x0
    check('mega_red', ok, ('ondas %d, placas %d, en el nivel del cliente %s'):format(
        #r.waves, #r.patches, tostring(level2.frostPatches ~= nil)))
end

local function look()
    local types = { 'crabby_ice', 'crabby_ice_icicle', 'crabby_ice_snow', 'crabbytramp_ice' }
    local ents = {}
    for i, t in ipairs(types) do
        local c = 3 + (i - 1) * 4
        ents[#ents + 1] = ent(t, c, 11)                                       -- suelo, andando
        ents[#ents + 1] = ent(t, c + 2, 11)                                   -- suelo, escondido
        ents[#ents + 1] = ent(t, c + 1, 2, { attach = 'ceiling' })            -- techo, escondido
    end
    ents[#ents + 1] = ent('crabby_ice_icicle', 2, 6, { wallWalk = true })     -- pared
    ents[#ents + 1] = ent('crabby_ice_snow', 2, 9, { wallWalk = true })
    local level, es = room(20, 12, ents)
    step(level, es, 0.2)
    for i, e in ipairs(es) do
        if i % 3 ~= 1 or i > 12 then hide(e) end
        if i > 12 then e.cnx, e.cny, e.cattached, e.x = 1, 0, true, T + e.sprH / 2 end
    end
    es[9].state = 'snow_crack'                                                -- un montón agrietándose
    local cv = love.graphics.newCanvas(20 * T, 12 * T)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.35, 0.42, 0.62, 1)
    level:render(0, 0)
    for _, e in ipairs(es) do e:render(0, 0) end
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'icecrabby_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/icecrabby_look.png')
end

-- LOOK=1: el Mega Crabby helado en 4 momentos (palmada, pinzas pegadas con ondas y placa, enfadado)
function cases.pinchos_skin()
    local SpikeSkins = require 'src/world/SpikeSkins'
    local Model = require 'src/editor/EditorModel'
    local json = require 'libs/json'
    local d = json.decode(love.filesystem.read('assets/levels/lago_helado.json'))
    local lvl = Level.fromData(d)
    local m = Model.fromData(d, 'x.json')
    local back = m:toData()
    local m2 = Model.new(10, 6, 'n')
    local plain = Level.fromData(m2:toData())
    local okImg = SpikeSkins.image('ice') ~= SpikeSkins.image('normal') and SpikeSkins.image('nada') == SpikeSkins.image('normal')
    local icy = {}
    for _, f in ipairs({ 'lago_helado', 'torre_viento' }) do
        local t = json.decode(love.filesystem.read('assets/levels/' .. f .. '.json'))
        icy[#icy + 1] = f .. '=' .. tostring(t.spikeSkin)
    end
    local ok = lvl.spikeSkin == 'ice' and SpikeSkins.of(lvl) == 'ice' and back.spikeSkin == 'ice'
               and SpikeSkins.of(plain) == nil and okImg and table.concat(icy, ' '):match('nil') == nil
    check('pinchos_skin', ok, ('nivel %s · editor ida y vuelta %s · nivel nuevo %s · imágenes ok %s · %s'):format(
        tostring(lvl.spikeSkin), tostring(back.spikeSkin), tostring(SpikeSkins.of(plain)), tostring(okImg),
        table.concat(icy, ' ')))
end

-- LOOK=1: pinchos normales y de hielo (casilla en las 4 direcciones + pincho que cae)
local function lookSpikes()
    local TC = require 'src/world/tiles/TileCodec'
    local cv = love.graphics.newCanvas(2 * 8 * T, 5 * T)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.35, 0.42, 0.62, 1)
    for i, skin in ipairs({ 'normal', 'ice' }) do
        local tiles = {}
        for r = 1, 5 do
            local row = {}
            for c = 1, 8 do row[c] = (r == 1 or r == 5) and 1 or 0 end
            tiles[r] = row
        end
        local sp = function(dir) local t = {}; for k = 1, 4 do t[k] = { present = true, dir = dir } end; return t end
        tiles[4][3] = TC.encode(0, false, sp(TC.DIR_UP))
        tiles[2][4] = TC.encode(0, false, sp(TC.DIR_DOWN))
        tiles[3][6] = TC.encode(0, false, sp(TC.DIR_LEFT))
        tiles[3][7] = TC.encode(0, false, sp(TC.DIR_RIGHT))
        local level = Level.fromData({ name = 't', width = 8, height = 5, playerStart = { 2, 4 }, tiles = tiles,
                                       entities = { { type = 'spikefall', col = 2, row = 2, props = {} } },
                                       spikeSkin = (skin ~= 'normal') and skin or nil })
        local e = Entities.create(level.entities[1])
        e.levelRef = level
        love.graphics.push()
        love.graphics.translate((i - 1) * 8 * T, 0)
        level:render(0, 0)
        e:render(0, 0)
        love.graphics.pop()
    end
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'pinchos_hielo.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/pinchos_hielo.png')
end

-- LOOK=1: esconderse y salir, cuadro a cuadro, de cada tapa de objeto (icecrabby_esconderse.png)
local function lookHide()
    local covers = { 'crabby_ice', 'crabby_ice_icicle', 'crabbytramp_ice' }
    local N = 12
    local W, H = 2 * T, 2 * T
    local cv = love.graphics.newCanvas(N * W, #covers * H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.35, 0.42, 0.62, 1)
    for row, ty in ipairs(covers) do
        local level, es, e = room(6, 4, { ent(ty, 3, 3) })
        step(level, es, 0.3)
        e.pauses = false
        for i = 1, N do
            -- 6 momentos escondiéndose y 6 saliendo
            local k = (i - 1) % 6
            if i <= 6 then e.state, e.hideTransTimer = 'hide_in', k * 0.2
            else e.state, e.hideTransTimer = 'hide_out', k * 0.2 end
            e:updateCustom(0, level)
            love.graphics.setScissor((i - 1) * W, (row - 1) * H, W, H)
            love.graphics.clear(0.35, 0.42, 0.62, 1)
            level:render(e.x - W / 2 - (i - 1) * W, e.y - H * 0.75 - (row - 1) * H)
            e:render(e.x - W / 2 - (i - 1) * W, e.y - H * 0.75 - (row - 1) * H)
            love.graphics.setScissor()
        end
    end
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'icecrabby_esconderse.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/icecrabby_esconderse.png')
end

local function lookMega()
    local CW, CH = 9 * T, 5 * T
    local moments = { { 'clap', 0.15 }, { 'clap_stuck', 0.3 }, { 'chase', 0, true }, { 'rest', 0.5, true } }
    local cv = love.graphics.newCanvas(CW * #moments, CH)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.35, 0.42, 0.62, 1)
    for i, m in ipairs(moments) do
        local level, es, e = mega(40)
        if i == 2 then e:spawnWaves(); for _, w in ipairs(e.waves) do w.x = w.x + w.dir * 150 end; e:addPatch(level) end
        e.state, e.deadTimer = m[1], m[2]
        if m[3] then e.hp = 1 end
        love.timer.getTime = function() return 10 + i end
        if m[3] then e:render(0, 0); love.timer.getTime = function() return 11 + i end end
        local camX, camY = math.floor(e.x - CW / 2 - (i - 1) * CW), math.floor(9 * T - CH + T)
        love.graphics.setScissor((i - 1) * CW, 0, CW - 4, CH)
        love.graphics.clear(0.35, 0.42, 0.62, 1)
        level:render(camX, camY)
        e:render(camX, camY)
        love.graphics.setScissor()
    end
    love.graphics.setCanvas()
    cv:newImageData():encode('png', 'icemega_look.png')
    print('guardado ' .. love.filesystem.getSaveDirectory() .. '/icemega_look.png')
end

function love.load()
    if os.getenv('LOOK') then look(); lookMega(); lookSpikes(); lookHide() end
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'tapa_pegada', 'pinzas', 'hundirse', 'escombros', 'pua', 'carambano', 'nieve_toque', 'nieve_encima', 'nieve_gp',
                         'nieve_techo', 'carambano_techo', 'trampolin', 'pared',
                         'mega_palmada', 'mega_pinzas', 'mega_placa', 'mega_red', 'pinchos_skin' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
