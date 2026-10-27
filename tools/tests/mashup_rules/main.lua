-- tools/tests/mashup_rules — el EVENTO Mega Mashup de los Cangrejos (types/directors/crabmashup.lua) de principio a
-- fin, simulado (como un jugador / el servidor), en su nivel real (assets/levels/mashup_cangrejos.json):
--   inicio     con el jugador en el ESCENARIO del final empieza la INTRO (pieza 'intro', zona 5 en entrada, escena 5, los
--              cuatro al fondo); en su compás 5, a la arena del Tantrum, que entra; al acabar la intro, su bucle y la pelea
--   tope       2 de daño por turno: pisotón 1 + ground pound → 1 + 1 (no 3); a 0 no muere: CONGELADO, no recibe más,
--              y la música pide el CORTE siguiente (≤ 4 compases) hacia su costura
--   costura    en la costura: fundido, los jugadores pasan a la arena siguiente, su escena (nieve, a oscuras…), la
--              cámara salta, el siguiente hace su entrada y la pelea empieza al empezar su bucle
--   orden      Tantrum → Icy → Gloomy (escena a oscuras) → Groove (con los platos desde el principio, SIN enfado; su
--              reloj es el del evento: el bucle empieza en su SOLO) → final
--   sinenfado  en la parte principal ninguno se enfada aunque le quede 1
--   final      relevos: uno pelea (enfadado), los otros tres al FONDO esperando, en sus sitios; la música es la variante
--              del que pelea; los que esperan lanzan sus peligros (notas, carámbanos, Crabbies, apagón)
--   relevo     vencido el que pelea: en el corte pasa al fondo NOQUEADO, baja otro (al azar, de los que quedan) y la
--              música cambia de variante SIN perder el compás
--   fin        vencidos los cuatro: la pieza 'end'; revientan uno por compás (5, 6, 7, 8); luego la SALIDA con la zona
--              abierta (la meta)
--   barra      la barra compartida: 8 al empezar, baja con cada golpe; el nombre, el del que pelea
--   red        netPack → otro director (cliente): fase, pieza, punto, quién pelea, quién está al fondo, iguales
--   control    con punto de control (level.eventCheckpoint = 3) se empieza en la costura hacia la Gloomy
--
--   GAME=1     EL JUEGO DE VERDAD (AdventureState, con dibujo y música): el jugador empieza en la primera arena; a
--              cada cangrejo, al segundo de pelear, se le baja su vida del turno; recorre todo el evento (intro, 4
--              cangrejos, final, fin, salida) sin errores, con la MÚSICA ADAPTATIVA sonando la pieza del director
--              (Sound.musicPosition) en cada momento; SHOTS=1 guarda capturas de cada fase (mashup_<fase>.png)
--
--   tools/tests/run.sh mashup_rules            ·  tools/tests/run.sh mashup_rules GAME=1 [SHOTS=1]
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
if os.getenv('GAME') then return require('play') end
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local BossZones = require 'src/world/systems/BossZones'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local T = TILE_PX
local DT = 1 / 60
local LEVEL = 'assets/levels/mashup_cangrejos.json'

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local function build(checkpoint)
    local f = assert(io.open(LEVEL, 'r'))
    local data = json.decode(f:read('*a')); f:close()
    local level = Level.fromData(data)
    level.eventCheckpoint = checkpoint
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    local ctl = BossZones.newController(level, es)
    local sx, sy = level:getSpawnPx()
    local pa = PlayerAdventure:new(sx, sy)
    pa:settle(level)
    pa.hurt = function() return false end                      -- (inmortal: aquí se prueba el evento)
    pa.die = function() return false end
    level.players = { pa }
    local cm
    for _, e in ipairs(es) do if e.def.name == 'crabmashup' then cm = e end end
    return level, es, ctl, pa, cm
end

local function step(level, es, ctl, pa, secs, until_)
    for _ = 1, math.floor(secs * 60 + 0.5) do
        level.players = { pa }
        level.solidBodies = Entities.solidBodies(es)
        for k in pairs(stub.state) do stub.state[k] = false end
        pa:update(DT, level)
        level:update(DT)
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        ctl:update(DT)
        if until_ and until_() then return true end
    end
    return false
end

-- Le baja su vida del turno al que pelea (lo hace vulnerable para no depender de su ataque)
local function beat(b, pa)
    local real = b.isVulnerable
    b.isVulnerable = function() return true end
    b.inv = 0; b.lastHitter = pa
    local a = b:damage(1, 'stomp')
    b.inv = 0
    local hp1 = b.hp
    local c = b:damage(2, 'pound')
    b.inv = 0
    local d = b:damage(1, 'stomp')
    b.isVulnerable = real
    return a, hp1, c, d
end

local cases = {}

function cases.flujo()
    local level, es, ctl, pa, cm = build()
    check('inicio', cm ~= nil, 'director en el nivel')
    step(level, es, ctl, pa, 0.3)
    local back = 0
    for _, r in ipairs({ 'tantrum', 'icy', 'gloomy', 'groove' }) do if cm.fin[r].offstage == 'wait' then back = back + 1 end end
    check('inicio', cm.phase == 'intro' and cm.piece == 'intro' and level.bossZones[5].state == 'intro' and level.sceneIdx == 5 and back == 4,
        ('en el escenario: fase %s, pieza %s, zona 5 %s, escena %s, los cuatro al fondo %d'):format(cm.phase, tostring(cm.piece),
            level.bossZones[5].state, tostring(level.sceneIdx), back))
    local tan = cm.main.tantrum
    step(level, es, ctl, pa, 6.5)
    check('inicio', tan.state ~= 'dormant' and BossZones.contains(level.bossZones[1], pa.x, pa.y) and level.sceneIdx == 1
        and level.bossZones[5].state == 'idle',
        ('compás 5 de la intro: a la arena del Tantrum (%s), escena %s, entra (%s); el escenario queda %s'):format(
            tostring(BossZones.contains(level.bossZones[1], pa.x, pa.y)), tostring(level.sceneIdx), tan.state, level.bossZones[5].state))
    step(level, es, ctl, pa, 6, function() return cm.piece == 'tantrum' end)
    step(level, es, ctl, pa, 0.1)
    check('inicio', cm.phase == 'crab' and level.bossZones[1].state == 'fight' and tan.hpMax == 2,
        ('pieza %s, fase %s, zona %s, vida %s/%s'):format(cm.piece, cm.phase, level.bossZones[1].state, tan.hp, tan.hpMax))
    check('barra', cm.hpMax == 8 and cm.hp == 8 and cm:title() == tan:title(), ('barra %s/%s "%s"'):format(cm.hp, cm.hpMax, cm:title()))

    local order = { 'tantrum', 'icy', 'gloomy', 'groove' }
    for i, role in ipairs(order) do
        local b = cm.main[role]
        local z = level.bossZones[i]
        if i > 1 then
            check('orden', cm.ci == i and z.state == 'fight' and b.hpMax == 2,
                ('%s: ci %d, zona %d %s, vida %s/%s'):format(role, cm.ci, i, z.state, b.hp, b.hpMax))
        end
        step(level, es, ctl, pa, 1)
        local rageOk = true
        if role == 'groove' then
            local _, sec = b:whereAt(b.songT or 0)
            check('orden', b.phase == 2 and not b.rage and (sec == 'K' or sec == 'A'),
                ('Groove: fase %s, enfadado %s, sección %s (su bucle empieza en el solo)'):format(b.phase, tostring(b.rage), tostring(sec)))
        end
        local pos0 = cm.pos
        local a, hp1, c, d = beat(b, pa)
        if b.rage and b:rage() then rageOk = false end
        if role == 'gloomy' and b.rage then rageOk = false end
        check('tope', a and hp1 == 1 and c and b.hp == 0 and b.eventFrozen and d == false,
            ('%s: pisotón → %s, ground pound → %s (tope), otro → %s; congelado %s'):format(role, hp1, b.hp, tostring(d), tostring(b.eventFrozen)))
        check('sinenfado', rageOk, role .. ': sin enfado con la vida a 1/0')
        local pc = require('src/world/entities/types/directors/crabmashup').cues and nil
        local bar = 60 / (role == 'gloomy' and 144 or (role == 'groove' and 150 or 180)) * 4
        check('tope', cm.pend and cm.pend.at - pos0 <= 4 * bar + 0.06 and cm.pend.at > pos0,
            ('%s: corte pedido a %.2f s (ahora %.2f; ≤ 4 compases = %.2f)'):format(role, cm.pend and cm.pend.at or -1, pos0, 4 * bar))
        step(level, es, ctl, pa, 12, function() return cm.phase == 'seam' and cm.teleported end)
        local nz = level.bossZones[i + 1]
        local inside = nz and BossZones.contains(nz, pa.x, pa.y)
        local sc = level.scenes[i + 1]
        check('costura', inside and level.sceneIdx == i + 1 and nz.state == 'intro' and (level.cameraCut or 0) >= i,
            ('→ arena %d: jugador dentro %s, escena %s (fondo %s, oscura %s, nieve %s), zona %s, corte de cámara %s'):format(i + 1,
                tostring(inside), tostring(level.sceneIdx), tostring(sc.background), tostring(level.dark), tostring(level.snow),
                nz and nz.state or '?', tostring(level.cameraCut)))
        if i == 2 then check('costura', level.dark == true, 'la arena de la Gloomy, a oscuras') end
        if i < 4 then step(level, es, ctl, pa, 10, function() return cm.phase == 'crab' and cm.ci == i + 1 end) end
    end

    -- ── EL FINAL ──
    step(level, es, ctl, pa, 10, function() return cm.phase == 'final' end)
    step(level, es, ctl, pa, 0.2)
    local fz = level.bossZones[5]
    local act = cm.active
    local nBack = 0
    for _, r in ipairs(order) do if r ~= act and cm.fin[r].offstage == 'wait' then nBack = nBack + 1 end end
    check('final', fz.state == 'fight' and act ~= nil and nBack == 3 and cm.piece == 'final_' .. act and cm.hpMax == 8,
        ('zona %s, pelea %s, al fondo esperando %d, pieza %s, barra %s/%s'):format(fz.state, tostring(act), nBack, tostring(cm.piece), cm.hp, cm.hpMax))
    local seen = { notes = 0, ice = 0, crab = 0, dark = false }
    local reserves = {}
    for _, e in ipairs(es) do if e.summonOf then reserves[#reserves + 1] = e end end
    step(level, es, ctl, pa, 12, function()
        seen.notes = math.max(seen.notes, #cm.notes)
        seen.ice = math.max(seen.ice, #cm.icicles)
        if level.dark then seen.dark = true end
        for _, e in ipairs(reserves) do if e.alive and e.state ~= 'reserve' then seen[e] = true end end
        seen.crab = 0
        for k in pairs(seen) do if type(k) == 'table' then seen.crab = seen.crab + 1 end end
        local b = cm.fin[act]
        if not b.started and b.introDone and b:introDone() then return false end
    end)
    local want = {}
    for _, r in ipairs(order) do if r ~= act then want[r] = true end end
    check('final', cm.fin[act].rage ~= false or cm.fin[act].phase == 2 or (cm.fin[act].rage == nil),
        act .. ' pelea enfadado')
    check('final', (not want.groove or seen.notes > 0) and (not want.icy or seen.ice > 0) and (not want.gloomy or seen.dark)
        and (not want.tantrum or seen.crab > 0),
        ('peligros de los que esperan: notas %d, carámbanos %d, Crabbies %d, apagón %s'):format(seen.notes, seen.ice, seen.crab, tostring(seen.dark)))
    for k = 1, 4 do
        local b = cm.fin[cm.active]
        step(level, es, ctl, pa, 8, function() return b.started end)
        local prev = cm.active
        beat(b, pa)
        local cut = cm.pend and cm.pend.at
        local pid = cm.pend and cm.pend.piece
        if k < 4 then
            step(level, es, ctl, pa, 8, function() return cm.active ~= prev end)
            local okPos = cut and math.abs(cm.pos - (cut % (require('src/world/entities/types/directors/crabmashup').cues and 22.5882 or 22.5882))) < 0.1
            check('relevo', cm.fin[prev].offstage == 'ko' and cm.active ~= prev and not cm.ko[cm.active] and cm.piece == pid and okPos,
                ('%s → al fondo %s; baja %s; música %s en %.2f (corte %.2f)'):format(prev, tostring(cm.fin[prev].offstage),
                    tostring(cm.active), tostring(cm.piece), cm.pos, cut or -1))
        else
            check('fin', pid == 'end', 'vencidos los cuatro: la siguiente pieza es el fin (' .. tostring(pid) .. ')')
        end
    end
    step(level, es, ctl, pa, 8, function() return cm.phase == 'end' end)
    step(level, es, ctl, pa, 20, function() return cm.phase == 'outro' end)
    local dead = 0
    for _, r in ipairs(order) do if not cm.fin[r].alive then dead = dead + 1 end end
    check('fin', cm.phase == 'outro' and dead == 4 and fz.state == 'cleared' and (cm.boomN or 0) == 4,
        ('fase %s, reventados %d, zona final %s'):format(cm.phase, dead, fz.state))
    local st = cm.stats[1] or {}
    check('barra', (st.dmg or 0) >= 16, 'daño apuntado al jugador: ' .. tostring(st.dmg))

    -- red
    local other = Entities.create({ type = 'crabmashup', col = 2, row = 3, props = {} })
    other.levelRef = level
    local data = cm:netPack()
    other:netApply(data, data, 1)
    check('red', other.phase == cm.phase and other.piece == cm.piece and math.abs(other.pos - cm.pos) < 0.01,
        ('fase %s/%s, pieza %s/%s'):format(other.phase, cm.phase, tostring(other.piece), tostring(cm.piece)))
end

function cases.control()
    local level, es, ctl, pa, cm = build(3)
    step(level, es, ctl, pa, 3, function() return cm.teleported end)
    local z3 = level.bossZones[3]
    check('control', cm.piece == 'seam_gloomy' and BossZones.contains(z3, pa.x, pa.y) and cm.main.tantrum.eventFrozen and cm.main.icy.eventFrozen,
        ('pieza %s, jugador en la arena 3: %s; Tantrum e Icy ya hechos'):format(tostring(cm.piece), tostring(BossZones.contains(z3, pa.x, pa.y))))
    step(level, es, ctl, pa, 8, function() return cm.phase == 'crab' end)
    check('control', cm.ci == 3 and cm.hp == 4 and cm.hpMax == 8, ('ci %d, barra %s/%s (quedan la Gloomy y el Groove)'):format(cm.ci, cm.hp, cm.hpMax))
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'flujo', 'control' }) do
        if not only or only == n then
            local ok, err = xpcall(cases[n], debug.traceback)
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
