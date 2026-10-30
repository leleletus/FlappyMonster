-- tools/tests/door_rules — reglas de la PUERTA activable (types/mechanisms/door.lua), caso a caso en salas hechas a mano:
--   bloquea      cerrada no la atraviesan un jugador andando, un Gummy (se da la vuelta) ni una caja empujada
--   su_activador el Activador de OTRA puerta no la abre; el suyo sí: cerrojo (doorClick en la puerta y en el
--                Activador), temblor, se abre subiendo (doorOpen) y deja pasar
--   se_queda     abierta (`stay`, por defecto) se queda así: volver a pulsar su Activador o esperar no la cierra
--   tres         tres puertas seguidas con sus tres Activadores: con dos pulsados no se pasa; con los tres, sí
--   cerrar       sin `stay`: con `closeAfter` se cierra sola (doorThud); con 0, se abre y se cierra con cada salto; con
--                un jugador o un Gummy en el hueco espera sin aplastarlo y se cierra cuando sale
--   baja         `dir` = 'down': se abre bajando al suelo; `trigger` = 'on': al pasar a OFF no salta
--   jefe         `source` = 'boss': se abre cuando la pelea de su zona acaba ganada, no antes
--   red          un cliente que solo recibe lo que viaja (estado + k del netPack, reposo = cerrada) tiene la MISMA caja
--                sólida y su jugador predicho choca y pasa igual que el del servidor
--   dibujo       se dibuja en cada isla, cerrada, a medio abrir y en el editor
--   templo       el Templo de los Pesos (assets/levels/templo_de_los_pesos.json): tres puertas, cada una con el
--                Activador de un ala; cada Activador abre SOLO la suya; con dos abiertas un jugador no pasa, con las
--                tres sí. SHOT=1 → <save>/templo_puertas.png (cerradas · dos abiertas · las tres)
--
--   tools/tests/run.sh door_rules   (CASE=nombre: solo ese; SHOT=1 guarda <save>/door_rules.png y templo_puertas.png)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
local played = {}
local function count(n) played[n] = (played[n] or 0) + 1 end
Sound = setmetatable({ play = count, playAt = count },
                     { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Push = require 'src/world/systems/Push'
local Isles = require 'src/world/level/Isles'
local T = TILE_PX
local DT = 1 / 60
local SW_OFF = 14

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

-- Sala W x H: suelo (fila H), techo (fila 1) y paredes; `blocks` = { {c, r[, tile]}, ... }; `links` del nivel
local function room(W, H, ents, blocks, links)
    local tiles = {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == 1 or r == H or c == 1 or c == W) and 1 or 0 end
        tiles[r] = row
    end
    for _, b in ipairs(blocks or {}) do tiles[b[2]][b[1]] = b[3] or 1 end
    local level = Level.fromData({ name = 't', width = W, height = H, playerStart = { 2, H - 1 },
                                   tiles = tiles, entities = ents or {}, links = links })
    local es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities, level.players = es, {}
    for _, e in ipairs(es) do if e.wantsLevel then e.levelRef = level end end
    return level, es
end

local function clearInput() for k in pairs(stub.state) do stub.state[k] = false end end
local function player(level, x, y)
    clearInput()
    local pa = PlayerAdventure:new(x, y)
    level.players[#level.players + 1] = pa
    return pa
end

-- Un paso como AdventureState: cuerpos y aire → jugadores → nivel → entidades → interacciones
local function step(level, es, secs, each)
    for _ = 1, math.max(1, math.floor(secs * 60 + 0.5)) do
        level.solidBodies = Entities.solidBodies(es)
        level.pushers = Push.collect(es)
        for _, pa in ipairs(level.players) do pa:update(DT, level) end
        level:update(DT)
        for _, e in ipairs(es) do if e.alive then e:update(DT, level) end end
        for _, pa in ipairs(level.players) do Interactions.run(pa, es, {}) end
        if each and each() then return true end
    end
end

local function door(col, row, props) return { type = 'door', col = col, row = row, props = props or { id = 1 } } end
local function hit(level, c, r) return level:hitTile(c, r, 'head') end
local function right(pa) local b = pa:getOuterBounds() return b.x + b.w end

local cases = {}

function cases.bloquea()
    -- el jugador andando hacia la derecha
    local level, es = room(20, 8, { door(12, 7) })
    local d = es[1]
    local pa = player(level, 4 * T, 7 * T - 60)
    stub.state.right = true
    step(level, es, 3)
    clearInput()
    local db = d:getOuterBounds({})
    check('bloquea', right(pa) <= db.x + 1 and d:isSolidBody(), ('el jugador se para en la puerta: borde %.0f, puerta en %.0f')
          :format(right(pa), db.x))
    -- un Gummy andando hacia ella se da la vuelta sin pasar
    local level2, es2 = room(20, 8, { door(12, 7), { type = 'gummy', col = 9, row = 7,
        props = { movement = 'walk', pauses = false, patrol = { left = 2, right = 19 } } } })
    local g, maxR = es2[2], 0
    step(level2, es2, 8, function()
        local b = g:getOuterBounds()
        maxR = math.max(maxR, b.x + b.w)
    end)
    local db2 = es2[1]:getOuterBounds({})
    check('bloquea', g.alive and maxR <= db2.x + 1, ('un Gummy no pasa: llega a %.0f, puerta en %.0f'):format(maxR, db2.x))
    -- una caja grande empujada por el jugador
    local level3, es3 = room(20, 8, { door(12, 7), { type = 'box', col = 9, row = 7 } })
    local box = es3[2]
    local pa3 = player(level3, 5 * T, 7 * T - 60)
    step(level3, es3, 0.3)
    stub.state.right = true
    local x0 = box.x
    step(level3, es3, 5)
    clearInput()
    local bb, db3 = box:getOuterBounds(), es3[1]:getOuterBounds({})
    check('bloquea', box.x > x0 + T and bb.x + bb.w <= db3.x + 1 and right(pa3) <= bb.x + 1,
          ('una caja empujada (%.0f px) se para en la puerta: borde %.0f, puerta en %.0f; el jugador detrás (%.0f)')
              :format(box.x - x0, bb.x + bb.w, db3.x, right(pa3)))
end

function cases.su_activador()
    played = {}
    -- Activador (5,4) → puerta 1; Activador (8,4) → puerta 2 (en otra parte de la sala)
    local level, es = room(24, 8, { door(12, 7, { id = 1 }), door(20, 7, { id = 2 }) }, { { 5, 4, SW_OFF }, { 8, 4, SW_OFF } },
                           { { col = 5, row = 4, to = 1 }, { col = 8, row = 4, to = 2 } })
    local d1, d2 = es[1], es[2]
    step(level, es, 0.2)
    hit(level, 8, 4)
    step(level, es, 2)
    local other = d1.state == 'closed' and d1.k == 0 and d2.state == 'open'
    played = {}
    hit(level, 5, 4)
    step(level, es, 0.05)
    local unlock = d1.state == 'unlock'
    step(level, es, d1.UNLOCK_T)
    local opening = d1.state == 'opening' and d1:isSolidBody()
    step(level, es, 1)
    check('su_activador', other and unlock and opening and d1.state == 'open' and not d1:isSolidBody(),
          ('el Activador de la otra puerta no la abre (%s); el suyo: cerrojo %s → abriéndose %s → abierta %s, ya no es sólida')
              :format(tostring(other), tostring(unlock), tostring(opening), d1.state))
    check('su_activador', (played.doorClick or 0) >= 2 and (played.doorOpen or 0) >= 1,
          ('sonidos: cerrojo %d (en la puerta y en su Activador), se abre %d'):format(played.doorClick or 0, played.doorOpen or 0))
    -- y ahora se pasa
    local pa = player(level, 9 * T, 7 * T - 60)
    stub.state.right = true
    step(level, es, 2)
    clearInput()
    check('su_activador', pa.x > 13 * T, ('abierta, el jugador pasa: x %.0f (> %d)'):format(pa.x, 13 * T))
end

function cases.se_queda()
    local level, es = room(20, 8, { door(12, 7) }, { { 5, 4, SW_OFF } }, { { col = 5, row = 4, to = 1 } })
    local d = es[1]
    step(level, es, 0.2)
    hit(level, 5, 4)
    step(level, es, 2)
    local opened = d.state == 'open'
    hit(level, 5, 4)                 -- (vuelve a OFF)
    step(level, es, 2)
    hit(level, 5, 4)                 -- (y a ON)
    step(level, es, 20)
    check('se_queda', opened and d.state == 'open' and d.k == 1 and not d:isSolidBody(),
          ('abierta (%s); tras volver a pulsar su Activador dos veces y 24 s: %s, k %.2f'):format(tostring(opened), d.state, d.k))
end

function cases.tres()
    local sw = { { 3, 4, SW_OFF }, { 5, 4, SW_OFF }, { 7, 4, SW_OFF } }
    local links = { { col = 3, row = 4, to = 1 }, { col = 5, row = 4, to = 2 }, { col = 7, row = 4, to = 3 } }
    -- pasillo de 3 de alto (techo en la fila 4 desde la columna 10) con las puertas en 12, 13 y 14
    local blocks = { sw[1], sw[2], sw[3] }
    for c = 10, 23 do blocks[#blocks + 1] = { c, 4 } end
    local res = {}
    for _, pressed in ipairs({ { 1, 2 }, { 1, 3 }, { 2, 3 }, { 1, 2, 3 } }) do
        local level, es = room(24, 8, { door(12, 7, { id = 1 }), door(13, 7, { id = 2 }), door(14, 7, { id = 3 }) }, blocks, links)
        step(level, es, 0.2)
        for _, i in ipairs(pressed) do hit(level, sw[i][1], sw[i][2]) end
        step(level, es, 2)
        local pa = player(level, 8 * T, 7 * T - 60)
        stub.state.right = true
        step(level, es, 3)
        clearInput()
        res[#res + 1] = { table.concat(pressed, '+'), pa.x > 16 * T, pa.x }
    end
    local ok = not res[1][2] and not res[2][2] and not res[3][2] and res[4][2]
    local s = {}
    for _, r in ipairs(res) do s[#s + 1] = ('%s → %s (x %.0f)'):format(r[1], r[2] and 'pasa' or 'no pasa', r[3]) end
    check('tres', ok, 'Activadores pulsados: ' .. table.concat(s, ' · '))
end

function cases.cerrar()
    played = {}
    -- closeAfter: se cierra sola
    local level, es = room(20, 8, { door(12, 7, { id = 1, stay = false, closeAfter = 1 }) }, { { 5, 4, SW_OFF } }, { { col = 5, row = 4, to = 1 } })
    local d = es[1]
    step(level, es, 0.2)
    hit(level, 5, 4)
    step(level, es, 1.5)
    local wasOpen = d.state == 'open'
    step(level, es, 2.5)
    check('cerrar', wasOpen and d.state == 'closed' and d.k == 0 and d:isSolidBody() and (played.doorThud or 0) >= 1,
          ('«se cierra a los 1 s»: abierta %s → %s (golpe %d)'):format(tostring(wasOpen), d.state, played.doorThud or 0))
    -- closeAfter 0: va y viene con cada salto
    local level2, es2 = room(20, 8, { door(12, 7, { id = 1, stay = false }) }, { { 5, 4, SW_OFF } }, { { col = 5, row = 4, to = 1 } })
    local d2 = es2[1]
    step(level2, es2, 0.2)
    local seq = {}
    for _ = 1, 3 do hit(level2, 5, 4); step(level2, es2, 2.5); seq[#seq + 1] = d2.state end
    check('cerrar', seq[1] == 'open' and seq[2] == 'closed' and seq[3] == 'open',
          ('sin «se queda abierta» y con 0 s, cada salto la cambia: %s'):format(table.concat(seq, ' → ')))
    -- con alguien en el hueco: espera y no lo aplasta; cuando sale, se cierra
    for _, who in ipairs({ 'jugador', 'gummy' }) do
        local ents = { door(12, 7, { id = 1, stay = false, closeAfter = 0.5 }) }
        if who == 'gummy' then ents[2] = { type = 'gummy', col = 12, row = 7, props = { movement = 'static' } } end
        local level3, es3 = room(20, 8, ents, { { 5, 4, SW_OFF } }, { { col = 5, row = 4, to = 1 } })
        local d3 = es3[1]
        step(level3, es3, 0.2)
        hit(level3, 5, 4)
        step(level3, es3, 1.5)
        local o = who == 'jugador' and player(level3, 12 * T - T / 2, 7 * T - 60) or es3[2]
        if who == 'gummy' then o.x, o.y = 12 * T - T / 2, 7 * T - o.outerH / 2 end
        local inside, overlapped = true, false
        step(level3, es3, 3, function()
            local a, b = o:getOuterBounds(), d3:getOuterBounds({})
            if d3:isSolidBody() and a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y then overlapped = true end
        end)
        local waited, wk = d3.state == 'closing' and d3.k > 0, d3.k
        -- sale
        if who == 'jugador' then level3.players = {} else o.alive = false end
        step(level3, es3, 2)
        check('cerrar', inside and not overlapped and waited and d3.state == 'closed',
              ('un %s en el hueco: la puerta espera (%s, k %.2f) sin taparlo nunca (%s); cuando sale se cierra: %s')
                  :format(who, tostring(waited), wk, tostring(not overlapped), d3.state))
    end
end

function cases.baja()
    local level, es = room(20, 8, { door(12, 7, { id = 1, dir = 'down', trigger = 'on' }) }, { { 5, 4, 13 } }, { { col = 5, row = 4, to = 1 } })
    local d = es[1]
    step(level, es, 0.2)
    hit(level, 5, 4)                 -- (ON → OFF: con «solo al pasar a ON» no salta)
    step(level, es, 2)
    local still = d.state == 'closed'
    hit(level, 5, 4)                 -- (OFF → ON)
    step(level, es, 0.05 + d.UNLOCK_T + 0.4)
    local b = d:getOuterBounds({})
    local mid = d.state == 'opening' and b.y > d.y0 + 4 and math.abs(b.y + b.h - d.y1) < 0.5
    step(level, es, 1)
    check('baja', still and mid and d.state == 'open',
          ('al pasar a OFF no salta (%s); al pasar a ON se abre BAJANDO: a medio abrir la parte sólida va de %.0f a %.0f (suelo %.0f) → %s')
              :format(tostring(still), b.y, b.y + b.h, d.y1, d.state))
end

function cases.jefe()
    local level, es = room(20, 8, { door(12, 7, { source = 'boss' }) })
    level.bossZones = { { id = 1, x0 = 2 * T, y0 = T, x1 = 10 * T, y1 = 7 * T, state = 'idle', bosses = {} } }
    local d = es[1]
    step(level, es, 0.5)
    level.bossZones[1].state = 'fight'
    step(level, es, 2)
    local closedInFight = d.state == 'closed'
    level.bossZones[1].state = 'cleared'
    step(level, es, 2)
    check('jefe', closedInFight and d.state == 'open', ('cerrada durante la pelea (%s); jefe vencido → %s'):format(tostring(closedInFight), d.state))
end

function cases.red()
    -- el SERVIDOR: puerta + Activador + un jugador que anda hacia ella; el CLIENTE: la misma sala sin Activador cuya
    -- puerta solo recibe lo que viaja, y su jugador (predicho) con las mismas teclas
    local links = { { col = 5, row = 4, to = 1 } }
    local srvL, srvE = room(20, 8, { door(12, 7) }, { { 5, 4, SW_OFF } }, links)
    local cliL, cliE = room(20, 8, { door(12, 7) }, { { 5, 4, SW_OFF } })
    local sd, cd = srvE[1], cliE[1]
    local ps = player(srvL, 8 * T, 7 * T - 60)
    local pc = player(cliL, 8 * T, 7 * T - 60)
    local worstBox, worstX, prev, t, sent = 0, 0, nil, 0, 0
    for i = 1, 60 * 5 do
        t = t + DT
        if i == 60 then hit(srvL, 5, 4) end
        stub.state.right = true
        -- (lo que manda el servidor de su puerta tal como la ven sus jugadores este paso: reposo = no viaja → netRest;
        -- si no, estado, tiempo y el netPack)
        if sd:netAtRest() then cd:netRest(); prev = nil
        else
            sent = sent + 1
            local pk = sd:netPack()
            cd.state, cd.deadTimer = sd.state, sd.deadTimer
            cd:netApply(prev or pk, pk, 1)
            prev = pk
        end
        local a, b = sd:getOuterBounds({}), cd:getOuterBounds({})
        worstBox = math.max(worstBox, math.abs(a.y - b.y), math.abs(a.h - b.h), math.abs(a.x - b.x),
                            (sd:isSolidBody() ~= cd:isSolidBody()) and 999 or 0)
        srvL.solidBodies = Entities.solidBodies(srvE)
        ps:update(DT, srvL)
        sd:update(DT, srvL)
        cliL.solidBodies = Entities.solidBodies(cliE)
        pc:update(DT, cliL)
        worstX = math.max(worstX, math.abs(ps.x - pc.x), math.abs(ps.y - pc.y))
    end
    clearInput()
    check('red', worstBox <= 0.5 and worstX <= 0.5 and ps.x > 13 * T and sent > 0,
          ('caja sólida del cliente = la del servidor (error %.2f px; %d fotos mandadas, cerrada en reposo); su jugador predicho '
           .. 'choca y pasa igual (error %.2f px, acaba en x %.0f)'):format(worstBox, sent, worstX, ps.x))
end

function cases.dibujo()
    local errs, shot = 0, nil
    local W, H = 4 + #Isles.IDS * 3, 7
    local cv = love.graphics.newCanvas(W * T, H * T)
    local ents = {}
    for i, isle in ipairs(Isles.IDS) do
        for j = 0, 1 do ents[#ents + 1] = door(2 + (i - 1) * 3 + j, 6, { id = i, isle = isle, height = 3 }) end
    end
    local level, es = room(W, H, ents)
    for i, e in ipairs(es) do if i % 2 == 0 then e.k, e.state = 0.5, 'opening' end end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.16, 0.18, 0.16, 1)
    pcall(level.render, level, 0, 0)
    for _, e in ipairs(es) do
        local ok, err = pcall(e.render, e, 0, 0)
        if not ok then errs = errs + 1; print('   ' .. tostring(err)) end
    end
    EDITOR_VIEW = true
    for _, e in ipairs(es) do
        e.k = 1
        local ok, err = pcall(e.render, e, 0, 0)
        if not ok then errs = errs + 1; print('   editor: ' .. tostring(err)) end
        e.k = 0
    end
    EDITOR_VIEW = nil
    -- (el icono de la paleta y la ayuda del editor encima de la puerta)
    local def = require('src/world/entities/base/EntityTypes').get('door')
    local ok1, e1 = pcall(def.editor.draw, 0, 0, 48)
    local ok2, e2 = pcall(def.class.drawEditorOverlay, { id = 2, height = 3 }, 96, 300, 1, { t = T, camX = 0, camY = 0 })
    local ok3, e3 = pcall(def.class.drawEditorOverlay, { source = 'boss', zone = 1 }, 96, 300, 0.5, { t = T, camX = 0, camY = 0 })
    for _, r in ipairs({ { ok1, e1 }, { ok2, e2 }, { ok3, e3 } }) do
        if not r[1] then errs = errs + 1; print('   editor (icono / ayuda): ' .. tostring(r[2])) end
    end
    love.graphics.setCanvas()
    if os.getenv('SHOT') then shot = cv:newImageData() end
    check('dibujo', errs == 0, ('se dibuja en las %d islas, cerrada, a medio abrir y en el editor: %d errores'):format(#Isles.IDS, errs))
    if shot then shot:encode('png', 'door_rules.png'); print('guardado ' .. love.filesystem.getSaveDirectory() .. '/door_rules.png') end
end

-- ── El Templo de los Pesos ──────────────────────────────────────────────────────
function cases.templo()
    local data = json.decode(love.filesystem.read('assets/levels/templo_de_los_pesos.json'))
    data.bossZones = nil
    local level = Level.fromData(data)
    local doors, all = {}, {}
    for _, pl in ipairs(level.entities) do
        local e = Entities.create(pl)
        if e and pl.type == 'door' then doors[#doors + 1] = e; e.levelRef = level end
        if e then all[#all + 1] = e end
    end
    level.liveEntities, level.players = doors, {}
    -- cada puerta, su Activador (uno, distinto, y de verdad un Activador)
    local sws, okLinks = {}, #doors == 3
    for _, d in ipairs(doors) do
        local cells = level:linkedCells(d.props.id or 1)
        if #cells ~= 1 or not level:getDef(cells[1][1], cells[1][2]).name:match('^switch_') then okLinks = false end
        sws[#sws + 1] = cells[1]
    end
    if okLinks and (sws[1][1] == sws[2][1] and sws[1][2] == sws[2][2]) then okLinks = false end
    local desc = {}
    for i, d in ipairs(doors) do desc[#desc + 1] = ('#%d col %d ← Activador (%d,%d)'):format(d.props.id, d.col, sws[i] and sws[i][1] or -1, sws[i] and sws[i][2] or -1) end
    check('templo', okLinks, ('%d puertas: %s'):format(#doors, table.concat(desc, ' · ')))
    if not okLinks then return end
    local shots = {}
    local function snap()
        if not os.getenv('SHOT') then return end
        local cv = love.graphics.newCanvas(16 * T, 10 * T)
        local cx, cy = 85 * T, 21 * T
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.1, 0.12, 0.1, 1)
        pcall(level.renderBackPlane, level, cx, cy)
        pcall(level.renderFoliageBack, level, cx, cy)
        pcall(level.render, level, cx, cy, true)
        for _, d in ipairs(doors) do d:render(cx, cy) end
        pcall(level.renderFoliage, level, cx, cy)
        love.graphics.setCanvas()
        shots[#shots + 1] = cv:newImageData()
    end
    local function run(secs) step(level, doors, secs) end
    local stuck
    run(0.2)
    snap()
    -- cada Activador abre solo la suya
    local only = true
    for i, s in ipairs(sws) do
        hit(level, s[1], s[2])
        run(2)
        for j, d in ipairs(doors) do
            if (j <= i) ~= (d.state == 'open') then only = false end
        end
        -- (con dos abiertas: un jugador desde el salón no pasa)
        if i == 2 then
            snap()
            local pa = player(level, 90 * T, 29 * T - 60)
            stub.state.right = true
            run(3)
            clearInput()
            stuck = pa.x
            level.players = {}
        end
    end
    snap()
    local pa = player(level, 90 * T, 29 * T - 60)
    stub.state.right = true
    run(3)
    clearInput()
    check('templo', only and stuck < 95 * T and pa.x > 97 * T,
          ('cada Activador abre solo la suya: %s; con dos abiertas el jugador se queda en x %.0f (< %d), con las tres pasa a x %.0f')
              :format(tostring(only), stuck, 95 * T, pa.x))
    if shots[1] then
        local W, H = shots[1]:getWidth(), shots[1]:getHeight()
        local out = love.image.newImageData(W, H * #shots)
        for i, d in ipairs(shots) do out:paste(d, 0, (i - 1) * H, 0, 0, W, H) end
        out:encode('png', 'templo_puertas.png')
        print('guardado ' .. love.filesystem.getSaveDirectory() .. '/templo_puertas.png')
    end
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'bloquea', 'su_activador', 'se_queda', 'tres', 'cerrar', 'baja', 'jefe', 'red', 'dibujo', 'templo' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
