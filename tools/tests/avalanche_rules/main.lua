-- tools/tests/avalanche_rules — reglas del ALUD (types/traps/avalanche.lua), caso a caso en salas hechas a mano:
--   reloj        el ciclo: calma hasta `delay`, aviso (`warn` s, suena avalancheRumble), torrente (`pour` s, suena
--                avalanchePour), se vacía y calma; vuelve a avisar cada `period` s
--   dano         de pie dentro del canal: el torrente quita 1 de vida y lo aparta de lado; invulnerable no vuelve a doler
--   empuje       en el aire dentro del torrente cae más deprisa que fuera (empuja hacia abajo); sin daño (`damage` no)
--                no quita vida
--   cubierto     un saliente dentro del canal: debajo de él, ni daño ni empujón (la nieve se para en el bloque);
--                al lado, sí
--   escalonado   tres canales con `delay` 1, 2 y 3: avisan uno detrás de otro, con 1 s entre cada uno, y repiten
--   arrastra     una caja pequeña y un Gummy en el aire dentro del torrente caen más deprisa que fuera
--   red          el cliente (estado + tiempo de la instantánea) calcula el mismo torrente, empujón y daño que el servidor
--   dibujo       se dibuja en cada estado (y en el editor) sin errores
--
--   tools/tests/run.sh avalanche_rules   (CASE=nombre: solo ese; SHOT=1 guarda <save>/avalanche.png)
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
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local Interactions = require 'src/world/entities/base/Interactions'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Push = require 'src/world/systems/Push'
local T = TILE_PX
local DT = 1 / 60

local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
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

local function aval(col, row, props)
    local p = { width = 2, length = 10, period = 6, warn = 1.2, pour = 2.5, delay = 1 }
    for k, v in pairs(props or {}) do p[k] = v end
    return { type = 'avalanche', col = col, row = row, props = p }
end

local cases = {}

function cases.reloj()
    played = {}
    local level, es = room(12, 14, { aval(5, 2) })
    local a = es[1]
    local seen = {}
    local t = 0
    step(level, es, 13, function()
        t = t + DT
        seen[#seen + 1] = { t, a.state }
    end)
    local function at(s) for _, q in ipairs(seen) do if q[1] >= s then return q[2] end end end
    check('reloj', at(0.5) == 'idle' and at(1.5) == 'warn' and at(2.5) == 'pour' and at(4.6) == 'pour'
          and (at(4.9) == 'drain' or at(4.9) == 'idle') and at(6.5) == 'idle' and at(7.5) == 'warn' and at(8.5) == 'pour',
          ('0,5 s %s · 1,5 %s · 2,5 %s · 4,6 %s · 4,9 %s · 6,5 %s · 7,5 %s · 8,5 %s'):format(at(0.5), at(1.5), at(2.5), at(4.6),
          at(4.9), at(6.5), at(7.5), at(8.5)))
    -- (los cambios de estado, exactos al paso)
    local first = {}
    for i = 2, #seen do
        if seen[i][2] ~= seen[i - 1][2] and not first[seen[i][2]] then first[seen[i][2]] = seen[i][1] end
    end
    check('reloj', math.abs((first.warn or 0) - 1) < 0.03 and math.abs((first.pour or 0) - 2.2) < 0.03
          and math.abs((first.drain or 0) - 4.7) < 0.03,
          ('aviso a %.2f s (1), torrente a %.2f (2,2), se vacía a %.2f (4,7)'):format(first.warn or -1, first.pour or -1, first.drain or -1))
    check('reloj', (played.avalancheRumble or 0) == 3 and (played.avalanchePour or 0) >= 3,
          ('sonidos en 13 s: aviso %d (3), torrente %d (≥ 3)'):format(played.avalancheRumble or 0, played.avalanchePour or 0))
    -- el frente baja a SPEED px/s y se para en el suelo (fila 14: la nieve llega a 12 casillas desde arriba como mucho)
    local level2, es2 = room(12, 14, { aval(5, 2, { length = 20 }) })
    local b = es2[1]
    step(level2, es2, 2.2 + 0.3)
    local tail, front = b:span()
    local bots = b:bottoms()
    check('reloj', tail == 0 and math.abs(front - 0.3 * b.SPEED) < b.SPEED / 30 + 1 and bots[1] == 12 * T and bots[2] == 12 * T,
          ('a 0,3 s del torrente el frente baja %.0f px (≈ %.0f); en cada columna se para en el suelo: %d, %d (%d)')
              :format(front or -1, 0.3 * b.SPEED, bots[1], bots[2], 12 * T))
end

function cases.dano()
    local level, es = room(12, 10, { aval(5, 2, { length = 8 }) })
    local a = es[1]
    local pa = player(level, 5 * T, 8.5 * T)               -- (de pie en la columna derecha del canal)
    step(level, es, 0.3)
    local hp0, x0 = pa.hp, pa.x
    local hit
    step(level, es, 3, function() if pa.hp < hp0 and not hit then hit = { x = pa.x, vx = pa.vx } end end)
    check('dano', hit ~= nil and pa.hp == hp0 - 1, ('el torrente le quita 1 de vida: %d → %d'):format(hp0, pa.hp))
    check('dano', hit ~= nil and (hit.vx or 0) > 100, ('lo aparta de lado hacia fuera del canal: vx %.0f'):format(hit and hit.vx or 0))
    -- invulnerable (recién golpeado) no vuelve a doler aunque siga dentro
    local level2, es2 = room(12, 10, { aval(5, 2, { length = 8, width = 4 }) })
    local pb = player(level2, 6 * T, 8.5 * T)
    pb:grantInvulnerability(10)
    local h0 = pb.hp
    step(level2, es2, 4)
    check('dano', pb.hp == h0, ('invulnerable dentro del torrente: vida %d → %d'):format(h0, pb.hp))
end

function cases.empuje()
    local function fall(inside, props)
        local level, es = room(14, 20, { aval(5, 2, props) })
        local pa = player(level, (inside and 5 or 10) * T, 4 * T)
        -- (sujeto en el aire hasta que el torrente ya cae entero; luego se suelta)
        step(level, es, 2.9, function() pa.x, pa.y, pa.vy = (inside and 5 or 10) * T, 4 * T, 0 end)
        local y0, hp0 = pa.y, pa.hp
        step(level, es, 0.35)
        return pa.y - y0, pa.hp - hp0
    end
    local din, hin = fall(true, { length = 18, damage = false })
    local dout = fall(false, { length = 18, damage = false })
    check('empuje', din > dout * 1.25, ('en 0,35 s dentro del torrente cae %.0f px, fuera %.0f'):format(din, dout))
    check('empuje', hin == 0, ('sin daño (`damage` = no): vida %+d'):format(hin))
end

function cases.cubierto()
    -- canal de 2 columnas (5 y 6); saliente en la columna 5, fila 6. Debajo de él (fila 8) a cubierto; en la 6, no
    local level, es = room(12, 10, { aval(5, 2, { length = 8, width = 2 }) }, { { 5, 6 } })
    local a = es[1]
    local bots = a:bottoms()
    check('cubierto', bots[1] == 4 * T and bots[2] == 8 * T,
          ('la nieve se para en el saliente (columna 5: %d px, %d) y en el suelo (columna 6: %d, %d)'):format(bots[1], 4 * T, bots[2], 8 * T))
    local under = player(level, 4.5 * T, 8.5 * T)
    local hp0 = under.hp
    local pushed = 0
    step(level, es, 4, function()
        local _, wy = Push.at(level, under.x, under.y, under)
        if wy > 0 then pushed = pushed + 1 end
    end)
    check('cubierto', under.hp == hp0 and pushed == 0, ('bajo el saliente: vida %d → %d, pasos empujado %d'):format(hp0, under.hp, pushed))
    local level2, es2 = room(12, 10, { aval(5, 2, { length = 8, width = 2 }) }, { { 5, 6 } })
    local open = player(level2, 5.5 * T, 8.5 * T)
    local h1 = open.hp
    step(level2, es2, 4)
    check('cubierto', open.hp < h1, ('al lado, sin saliente encima: vida %d → %d'):format(h1, open.hp))
end

function cases.escalonado()
    local level, es = room(20, 14, { aval(3, 2, { delay = 1, period = 6 }), aval(7, 2, { delay = 2, period = 6 }),
                                     aval(11, 2, { delay = 3, period = 6 }) })
    local starts = { {}, {}, {} }
    local prev = { 'idle', 'idle', 'idle' }
    local t = 0
    step(level, es, 14, function()
        t = t + DT
        for i = 1, 3 do
            if es[i].state == 'warn' and prev[i] ~= 'warn' then starts[i][#starts[i] + 1] = t end
            prev[i] = es[i].state
        end
    end)
    local ok, txt = true, {}
    for i = 1, 3 do
        local s = starts[i]
        txt[#txt + 1] = ('canal %d: %s'):format(i, table.concat((function() local o = {} for _, v in ipairs(s) do o[#o + 1] = ('%.2f'):format(v) end return o end)(), ', '))
        if not (s[1] and math.abs(s[1] - i) < 0.03 and s[2] and math.abs(s[2] - (i + 6)) < 0.03) then ok = false end
    end
    check('escalonado', ok, 'avisos a 1/2/3 s y otra vez a 7/8/9 · ' .. table.concat(txt, ' · '))
end

function cases.arrastra()
    local function drop(inside, kind)
        local level, es = room(14, 20, { aval(5, 2, { length = 18, damage = false }),
                                         { type = kind, col = inside and 5 or 10, row = 4, props = {} } })
        local e = es[2]
        local function pin() e.x, e.y, e.vy, e.onGround = (inside and 5 or 10) * T - T / 2, 4 * T, 0, false end
        step(level, es, 2.9, pin)
        local y0 = e.y
        step(level, es, 0.35)
        return e.y - y0
    end
    for _, kind in ipairs({ 'smallbox', 'gummy' }) do
        local din, dout = drop(true, kind), drop(false, kind)
        check('arrastra', din > dout * 1.15, ('%s: en 0,35 s dentro cae %.0f px, fuera %.0f'):format(kind, din, dout))
    end
end

function cases.red()
    local level, es = room(12, 14, { aval(5, 2, { length = 12, width = 3 }) }, { { 6, 8 } })
    local srv = es[1]
    local cli = Entities.create({ type = 'avalanche', col = 5, row = 2, props = srv.props })
    cli.levelRef = level
    local diffs, samples = 0, 0
    local probe = player(level, 0, 0)
    level.players = {}
    step(level, es, 8, function()
        -- (lo que viaja: el estado y su tiempo; en reposo no se manda → netRest)
        if srv:netAtRest() then cli:netRest() else cli.state, cli.deadTimer = srv.state, srv.deadTimer end
        cli:measure(level)
        for x = 4 * T, 8 * T, 24 do
            for y = 2 * T, 13 * T, 40 do
                local a1, b1 = srv:pushAt(x, y)
                local a2, b2 = cli:pushAt(x, y)
                samples = samples + 1
                if (b1 or 0) ~= (b2 or 0) then diffs = diffs + 1 end
            end
        end
        probe.x, probe.y = 6.5 * T, 10 * T
        local h1 = srv:getHazardBoxes() and Interactions.defaultCheck(probe, srv)
        local h2 = cli:getHazardBoxes() and Interactions.defaultCheck(probe, cli)
        if h1 ~= h2 then diffs = diffs + 1 end
    end)
    check('red', diffs == 0 and samples > 1000, ('empujón y daño iguales en el cliente: %d diferencias en %d muestras'):format(diffs, samples))
end

function cases.dibujo()
    local level, es = room(12, 14, { aval(5, 2, { length = 12, width = 3 }) }, { { 6, 8 } })
    local a = es[1]
    local cv = love.graphics.newCanvas(12 * T, 14 * T)
    local errs, shots = 0, {}
    local function draw()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0.23, 0.29, 0.42, 1)
        level:render(0, 0)
        local ok, err = pcall(a.render, a, 0, 0)
        love.graphics.setCanvas()
        if not ok then errs = errs + 1; print('   ' .. tostring(err)) end
    end
    for _, s in ipairs({ { 'idle', 0 }, { 'warn', 0.6 }, { 'pour', 0.2 }, { 'pour', 1.5 }, { 'drain', 0.3 } }) do
        a.state, a.deadTimer = s[1], s[2]
        draw()
        if os.getenv('SHOT') then shots[#shots + 1] = cv:newImageData() end
    end
    EDITOR_VIEW = true; a.state = 'idle'; draw(); EDITOR_VIEW = nil
    check('dibujo', errs == 0, ('se dibuja en calma, aviso, torrente, vaciándose y en el editor: %d errores'):format(errs))
    if os.getenv('SHOT') and shots[1] then
        local W, H = shots[1]:getWidth(), shots[1]:getHeight()
        local out = love.image.newImageData(W * #shots, H)
        for i, d in ipairs(shots) do out:paste(d, (i - 1) * W, 0, 0, 0, W, H) end
        out:encode('png', 'avalanche.png')
        print('guardado ' .. love.filesystem.getSaveDirectory() .. '/avalanche.png')
    end
end

function love.load()
    local only = os.getenv('CASE')
    for _, n in ipairs({ 'reloj', 'dano', 'empuje', 'cubierto', 'escalonado', 'arrastra', 'red', 'dibujo' }) do
        if not only or only == n then
            local ok, err = pcall(cases[n])
            if not ok then check(n, false, 'error: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
