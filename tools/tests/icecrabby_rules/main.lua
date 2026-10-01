-- tools/tests/icecrabby_rules — reglas del CRABBY HELADO (types/crabby_ice.lua), caso a caso en
-- salas hechas a mano:
--   hundirse      al esconderse se hunde fila a fila (los 8 cuadros sink) y acaba escondido
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

function love.load()
    if os.getenv('LOOK') then look() end
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'hundirse', 'escombros', 'pua', 'carambano', 'nieve_toque', 'nieve_encima', 'nieve_gp',
                         'nieve_techo', 'carambano_techo', 'trampolin', 'pared' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
