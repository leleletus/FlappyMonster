-- tools/tests/tool_editors — los editores de ANIMACIONES y de ENEMIGOS de verdad (love . --anim / --enemy), sin
-- escribir nada en el repo (lo que guardarían se captura y se comprueba que es JSON válido):
--   TOOL=anim   (por defecto) abre el conjunto `gummy`, cambia de secuencia, crea una, cambia su velocidad, abre la
--               ventana de cortar una hoja y añade sus cuadros; "guarda"; capturas tool_anim_1..3.png
--   TOOL=anim FLOW=runtime   DEL EDITOR AL JUEGO: con el ratón de verdad (clics en los botones y rueda sobre los campos
--               del editor) cambia animaciones de tres cosas — Gloomy `walk` (quita un cuadro, cambia el orden, baja la
--               velocidad), bomba `walk` (de 4 cuadros a 2, más lenta) y trampolín `idle` (le añade un cuadro y
--               velocidad) —, guarda con Ctrl+S y ARRANCA EL JUEGO con esas entidades: sin tocar su código, andan con
--               los cuadros, el orden y el ritmo nuevos. (Lo guardado va a la carpeta de guardado del arnés, que el
--               juego lee antes que el repo; se borra al acabar.) Captura tool_anim_runtime.png
--   TOOL=enemy KIND=boss  lo mismo con un JEFE de datos (su sala de prueba lleva zona de jefe)
--   TOOL=enemy  crea un enemigo nuevo sobre el conjunto del Gummy, recorre sus pestañas (General, Animaciones,
--               Estados, Comportamientos, Avisos), le añade dos comportamientos, "guarda" y lo PRUEBA en el juego
--               (F5): el enemigo existe en el nivel de prueba y el juego corre; F10 vuelve. tool_enemy_1..6.png
-- Capturas en <save> (~/.local/share/love/fm_test_tools/).
--
--   tools/tests/run.sh tool_editors            tools/tests/run.sh tool_editors TOOL=enemy
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local TOOL = os.getenv('TOOL') or 'anim'
arg = arg or {}
arg[#arg + 1] = '--' .. TOOL
local FLOW = os.getenv('FLOW')
if TOOL == 'anim' then arg[#arg + 1] = (FLOW == 'runtime') and 'enemies/gloomy' or 'enemies/gummy' end
-- El conf.lua DE VERDAD debe encender el ratón para esta herramienta (el de este arnés lo lleva siempre: sin esta
-- comprobación el editor se abría bien aquí y fallaba al abrirlo el usuario)
do
    local real = love.conf
    love.filesystem.load('game_conf.lua')()
    local t = { window = {}, modules = {} }
    love.conf(t)
    love.conf = real
    if not t.modules.mouse then print('conf         FALLA  conf.lua no enciende el ratón con --' .. TOOL); love.event.quit(1); return end
    print('conf         OK     conf.lua enciende el ratón con --' .. TOOL)
end
love.filesystem.load('game_main.lua')()

local json  = require 'libs/json'
local ui    = require 'src/editor/ui'
local Shell = require 'src/editor/ToolShell'
local Anim  = require 'src/fx/Anim'
local fails, writes = 0, {}
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
-- (nada se escribe en el repo: se guarda aquí)
local installed = {}
Shell.writeRepo = function(path, text)
    writes[#writes + 1] = { path = path, text = text }
    if FLOW == 'runtime' then
        -- (a la carpeta de guardado: LÖVE la lee ANTES que el repo, así el juego ve lo que guardó el editor)
        love.filesystem.createDirectory(path:match('^(.*)/[^/]+$'))
        love.filesystem.write(path, text)
        installed[#installed + 1] = path
    end
    return true
end
for _, pth in ipairs({ 'assets/anim/enemies/gloomy.json', 'assets/anim/enemies/bomb.json', 'assets/anim/mechanisms/trampoline.json' }) do
    if love.filesystem.getRealDirectory(pth) == love.filesystem.getSaveDirectory() then love.filesystem.remove(pth) end   -- (restos de otra ejecución)
end
-- RATÓN DE VERDAD sobre el editor: dónde se dibujó cada botón / campo numérico en el último fotograma
local rects = {}
local rawButton, rawNumber, rawGetPos = ui.button, ui.number, love.mouse.getPosition
local fakeMouse
ui.button = function(label, x, y, w, h, opts)
    if label then rects[#rects + 1] = { kind = 'b', label = label, tip = opts and opts.tooltip or '', x = x, y = y, w = w, h = h, off = opts and opts.disabled } end
    return rawButton(label, x, y, w, h, opts)
end
ui.number = function(label, value, x, y, w, p2)
    rects[#rects + 1] = { kind = 'n', label = label, tip = '', x = x + w - 124 + 26, y = y, w = 70, h = 24 }
    return rawNumber(label, value, x, y, w, p2)
end
love.mouse.getPosition = function() if fakeMouse then return fakeMouse[1], fakeMouse[2] end return rawGetPos() end
local function find(kind, label, tip)
    for i = #rects, 1, -1 do
        local r = rects[i]
        if r.kind == kind and r.label == label and (not tip or r.tip:find(tip, 1, true)) then return r end
    end
end
local function click(label, tip)
    local r = find('b', label, tip)
    if not r or r.off then return false end
    fakeMouse = { math.floor(r.x + r.w / 2), math.floor(r.y + r.h / 2) }
    love.mousepressed(fakeMouse[1], fakeMouse[2], 1)
    return true
end
local function wheelOn(label, n)
    local r = find('n', label)
    if not r then return false end
    fakeMouse = { math.floor(r.x + r.w / 2), math.floor(r.y + r.h / 2) }
    love.wheelmoved(0, n)
    return true
end
local function shot(n) love.graphics.captureScreenshot(function(img) img:encode('png', 'tool_' .. TOOL .. '_' .. n .. '.png') end) end
local realDown = love.keyboard.isDown
local function key(k, ctrl)
    if ctrl then love.keyboard.isDown = function() return true end end
    love.keypressed(k)
    love.keyboard.isDown = realDown
end
local function validJson()
    local bad = {}
    for _, w in ipairs(writes) do
        local ok, t = pcall(json.decode, w.text)
        if not ok or type(t) ~= 'table' then bad[#bad + 1] = w.path end
    end
    return #bad == 0, table.concat(bad, ', ')
end

local runtimeFlow
local frame = 0
local frames0 = 0            -- cuadros del conjunto al abrirlo
local realMouse, zoom0, scroll0, scroll1

-- ── DEL EDITOR AL JUEGO (FLOW=runtime) ──
local RT = { okClicks = true, t = 0, seen = {} }
local function saved(path)
    for i = #writes, 1, -1 do if writes[i].path == path then return json.decode(writes[i].text) end end
end
local function copy(t) local o = {}; for i, v in ipairs(t) do o[i] = v end; return o end
local function act(ok) if not ok then RT.okClicks = false end end
runtimeFlow = function(dt)
    local A = require 'src/editor/AnimEditor'
    local P = A.panel
    -- 1. Gloomy · andar: quitar un cuadro, cambiar el orden, bajar la velocidad
    if frame == 4 then P.anim, P.pos, P.playing = 'walk', 2, false; RT.g0 = copy(A.doc.anims.walk.frames); RT.gfps0 = A.doc.anims.walk.fps
    elseif frame == 6 then act(click('Quitar', 'Quita este cuadro de la animación'))
    elseif frame == 8 then P.pos = 1
    elseif frame == 10 then act(click('>', 'Mover este cuadro después'))
    elseif frame >= 12 and frame <= 21 then act(wheelOn('Velocidad (fps)', -1))
    elseif frame == 23 then
        fakeMouse = nil
        local w = A.doc.anims.walk
        local g0 = RT.g0
        check('edita_gloomy', RT.okClicks and #w.frames == 3 and w.frames[1] == g0[3] and w.frames[2] == g0[1] and w.frames[3] == g0[4] and w.fps == RT.gfps0 - 5,
              ('walk: cuadros %s → %s; velocidad %s → %s (con clics y rueda de verdad: %s)'):format(table.concat(g0, ' '), table.concat(w.frames, ' '), tostring(RT.gfps0), tostring(w.fps), tostring(RT.okClicks)))
        key('s', true)
    -- 2. Bomba · andar: de 4 cuadros a 2, más lenta
    elseif frame == 25 then A.open('enemies/bomb')
    elseif frame == 27 then P.anim, P.pos, P.playing = 'walk', 4, false; RT.b0 = copy(A.doc.anims.walk.frames); RT.bfps0 = A.doc.anims.walk.fps
    elseif frame == 29 then act(click('Quitar', 'Quita este cuadro de la animación'))
    elseif frame == 31 then P.pos = 3
    elseif frame == 33 then act(click('Quitar', 'Quita este cuadro de la animación'))
    elseif frame >= 35 and frame <= 44 then act(wheelOn('Velocidad (fps)', -1))
    elseif frame == 46 then
        fakeMouse = nil
        local w = A.doc.anims.walk
        check('edita_bomba', RT.okClicks and #RT.b0 == 4 and #w.frames == 2 and w.fps == RT.bfps0 - 5,
              ('walk: %d cuadros → %d; velocidad %s → %s'):format(#RT.b0, #w.frames, tostring(RT.bfps0), tostring(w.fps)))
        key('s', true)
    -- 3. Trampolín · reposo: añadirle un cuadro del banco (el estirado) y darle velocidad
    elseif frame == 48 then A.open('mechanisms/trampoline')
    elseif frame == 50 then P.anim, P.playing = 'idle', false; P.frame = A.doc.anims.bounce.frames[1]; RT.t0 = copy(A.doc.anims.idle.frames)
    elseif frame == 52 then act(click('+ Añadir el cuadro ' .. P.frame .. ' del banco'))
    elseif frame >= 54 and frame <= 61 then act(wheelOn('Velocidad (fps)', 1))
    elseif frame == 63 then
        fakeMouse = nil
        local w = A.doc.anims.idle
        check('edita_tramp', RT.okClicks and #RT.t0 == 1 and #w.frames == 2 and w.frames[2] == A.doc.anims.bounce.frames[1] and w.fps == 8,
              ('idle: %d cuadro → %d; velocidad %s'):format(#RT.t0, #w.frames, tostring(w.fps)))
        key('s', true)
    -- 4. EL JUEGO, con lo guardado
    elseif frame == 66 then
        local g, b, tr = saved('assets/anim/enemies/gloomy.json'), saved('assets/anim/enemies/bomb.json'), saved('assets/anim/mechanisms/trampoline.json')
        RT.g, RT.b, RT.tr = g, b, tr
        check('guarda', g and b and tr and #writes == 3 and validJson(), ('%d archivos guardados por el editor: %s'):format(#writes, table.concat(installed, ' · ')))
        local W, H, tiles = 44, 12, {}
        for r = 1, H do
            local row = {}
            for c = 1, W do row[c] = (r == H or c == 1 or c == W or r == 1) and 1 or 0 end
            tiles[r] = row
        end
        Shell.play({ name = 'Del editor al juego', width = W, height = H, playerStart = { 3, 11 }, tiles = tiles, foliage = {}, vents = {}, background = 'meadow',
                     entities = { { type = 'gloomy', col = 30, row = 11, props = { patrol = { left = 24, right = 40 }, senseRange = 0 } },
                                  { type = 'bomb', col = 16, row = 11, props = { patrol = { left = 11, right = 21 }, trigger = 0 } },
                                  { type = 'trampoline', col = 7, row = 11 } } })
        RT.start = frame
    elseif RT.start and frame > RT.start + 2 then
        RT.t = RT.t + dt
        local st = gStateMachine and gStateMachine:_top()
        for _, e in ipairs(st and st.enemies or {}) do
            local n = e.def and e.def.name
            if n == 'gloomy' or n == 'bomb' then
                local S = RT.seen[n] or { frames = {}, changes = 0, time = 0, shown = {} }
                RT.seen[n] = S
                local walking = (n == 'bomb' and e.state == 'walk') or (n == 'gloomy' and select(3, e:animNow()) ~= nil)
                if walking then
                    S.time = S.time + dt
                    S.frames[e.frame] = true
                    if S.last and S.last ~= e.frame then S.changes = S.changes + 1 end
                    S.last = e.frame
                    if n == 'gloomy' then S.shown[e.frame] = e:frameNow() end       -- (el cuadro del conjunto que DIBUJA en ese paso)
                else S.last = nil end
            end
        end
        if frame == RT.start + 30 then love.graphics.captureScreenshot(function(img) img:encode('png', 'tool_anim_runtime.png') end) end
        if RT.t >= 4 then
            local function count(tb) local c = 0; for _ in pairs(tb) do c = c + 1 end; return c end
            local G, B = RT.seen.gloomy or { frames = {}, changes = 0, time = 0, shown = {} }, RT.seen.bomb or { frames = {}, changes = 0, time = 0 }
            local gw, bw = RT.g.anims.walk, RT.b.anims.walk
            local gRate, bRate = G.changes / math.max(0.01, G.time), B.changes / math.max(0.01, B.time)
            local order = true
            for k = 1, #gw.frames do if G.shown[k] ~= gw.frames[k] then order = false end end
            check('juego_gloomy', Shell.mode == 'play' and count(G.frames) == 3 and not G.frames[4] and order and math.abs(gRate - gw.fps) < 1.2 and G.time > 1,
                  ('en el juego anda con %d pasos (antes 4), dibuja los cuadros %s (guardado: %s), a %.1f pasos/s (guardado %s; antes %s)'):format(
                      count(G.frames), table.concat({ tostring(G.shown[1]), tostring(G.shown[2]), tostring(G.shown[3]) }, ' '), table.concat(gw.frames, ' '), gRate, tostring(gw.fps), tostring(RT.gfps0)))
            check('juego_bomba', count(B.frames) == 2 and not B.frames[3] and math.abs(bRate - bw.fps) < 1 and B.time > 1,
                  ('en el juego anda con %d pasos (antes 4), a %.1f pasos/s (guardado %s; antes %s)'):format(count(B.frames), bRate, tostring(bw.fps), tostring(RT.bfps0)))
            -- el trampolín en reposo: su animación ahora tiene 2 cuadros y pasa de uno a otro a 8/s (lo que dibuja Tramp:render)
            local c = Anim.clip('mechanisms/trampoline', 'idle')
            local stepsSeen, flips, last = {}, 0, nil
            for i = 0, 79 do
                local k = c:at(i / 80)
                stepsSeen[k] = true
                if last and last ~= k then flips = flips + 1 end
                last = k
            end
            check('juego_tramp', c.count == 2 and stepsSeen[1] and stepsSeen[2] and math.abs(flips - 8) <= 1 and c:rec(2).path:find('extended', 1, true) ~= nil,
                  ('el trampolín en reposo tiene %d cuadros en el juego y cambia %d veces por segundo (guardado: 8); el 2.º es %s'):format(c.count, flips, c:rec(2).path:match('[^/]+$')))
            for _, pth in ipairs(installed) do love.filesystem.remove(pth) end
            print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails)); love.event.quit(fails == 0 and 0 or 1)
        end
    end
end
local toolUpdate = love.update
function love.update(dt)
    frame = frame + 1
    toolUpdate(dt)
    if TOOL == 'anim' and FLOW == 'runtime' then
        runtimeFlow(dt)
        rects = {}
    elseif TOOL == 'anim' then
        local A = require 'src/editor/AnimEditor'
        if frame == 3 then
            -- las TIRAS del juego salen de la animación con su "sheet" en el conjunto de su carpeta, y su velocidad manda
            do
                local AnimM, SpriteStrip = require 'src/fx/Anim', require 'src/fx/SpriteStrip'
                local n, via, timed, split = 0, 0, nil, 0
                for _, id in ipairs(AnimM.list()) do
                    for _, a in pairs((AnimM.read(id) or {}).anims or {}) do
                        if a.sheet then
                            n = n + 1
                            local st = SpriteStrip.load('assets/images/' .. id .. '/' .. a.sheet, a.frameW)
                            -- (una hoja repartida por estados: cada animación responde a sus números "at")
                            local okPart = st.set ~= nil
                            for k = 1, a.at and #a.at or #a.frames do if not st.quads[a.at and a.at[k] or k] then okPart = false end end
                            if not a.at and st.count ~= #a.frames then okPart = false end
                            if a.at then split = split + 1 end
                            if okPart then via = via + 1 end
                            if a.codeFps and st.count > 2 then timed = timed or { st, a.codeFps } end
                        end
                    end
                end
                local same, scaled = false, false
                if timed then
                    local st, fps = timed[1], timed[2]
                    same = true
                    for i = 0, 40 do local t = i * 0.037; if st:frameAt(t, fps) ~= math.floor(t * fps) % st.count + 1 then same = false end end
                    st.nominal = fps / 2                 -- (como si el conjunto pidiera el doble de velocidad que el código)
                    scaled = true
                    for i = 0, 40 do local t = i * 0.037; if st:frameAt(t, fps / 2) ~= math.floor(t * fps + 1e-9) % st.count + 1 then scaled = false end end
                    st.nominal = fps
                end
                check('tiras', via == n and (not timed or (same and scaled)), ('%d animaciones de hoja (%d son estados de una hoja repartida), %d leídas de su conjunto; al ritmo del código igual=%s; el conjunto cambia el ritmo=%s'):format(n, split, via, tostring(same), tostring(scaled)))
            end
            frames0 = A.doc and #A.doc.frames or 0
            check('abre', A.id == 'enemies/gummy' and A.doc and frames0 >= 4, ('conjunto %s con %d cuadros'):format(tostring(A.id), A.doc and #A.doc.frames or 0))
            A.panel.anim = 'walk'
        elseif frame == 6 then shot(1)
        elseif frame == 8 then
            A.panel.frame = 4
            local ok = A.panel:addAnim(A.doc, 'attack'); A.panel:touch()
            A.doc.anims.attack.fps = 12
            table.insert(A.doc.anims.attack.frames, 2)
            A.doc.anims.attack.durations = { 0.2, 0.05 }
            A.panel:touch()
            local set = A.panel:set(A.doc)
            check('secuencia', ok and set:has('attack') and math.abs(set:length('attack') - 0.25) < 1e-6, ('attack creada: %s, dura %.2f s'):format(tostring(ok), set:length('attack')))
            A.panel.modal = { kind = 'slice', image = 'assets/images/enemies/hopper/pradera-Sheet.png', fw = 16, fh = 21 }
            A.hist:record()
        elseif frame == 11 then shot(2)
        elseif frame == 12 then
            -- deshacer / rehacer
            A.panel.modal = nil
            local u = A.hist:undo()
            local gone = A.doc.anims.attack == nil
            local r = A.hist:redo()
            check('deshacer', u and gone and r and A.doc.anims.attack ~= nil, ('deshacer quita la secuencia nueva (%s) y rehacer la devuelve (%s)'):format(tostring(gone), tostring(A.doc.anims.attack ~= nil)))
            A.browse = true
        elseif frame == 24 then
            shot(4)
            -- RUEDA con el explorador abierto SOBRE un conjunto ya abierto (antes la rueda se la quedaba el editor de
            -- detrás: hacía zoom en la vista y la lista del explorador no se movía)
            realMouse = love.mouse.getPosition
            local W, H = love.graphics.getDimensions()
            love.mouse.getPosition = function() return math.floor(W * 0.6), math.floor(H * 0.5) end
            zoom0, scroll0 = A.panel.zoom, ui.state.scroll.animbrowsegrid or 0
            love.wheelmoved(0, -3)
        elseif frame == 25 then
            check('explorador', #A.list >= 40, #A.list .. ' conjuntos en el explorador')
            scroll1 = ui.state.scroll.animbrowsegrid or 0
            love.wheelmoved(0, -2)
        elseif frame == 26 then
            local scroll2 = ui.state.scroll.animbrowsegrid or 0
            check('rueda', scroll1 > scroll0 and scroll2 > scroll1 and A.panel.zoom == zoom0,
                  ('la lista del explorador baja %d → %d → %d px; el zoom del editor de detrás %s → %s'):format(scroll0, scroll1, scroll2, tostring(zoom0), tostring(A.panel.zoom)))
            love.mouse.getPosition = realMouse
            A.browse = false
        elseif frame == 27 then
            -- (lo que hace el botón "Añadir 4 cuadros")
            for c = 0, 3 do A.doc.frames[#A.doc.frames + 1] = { image = 'assets/images/enemies/hopper/pradera-Sheet.png', x = c * 16, y = 0, w = 16, h = 21 } end
            A.panel.modal = nil; A.panel:touch(); A.panel.frame = 7
            check('cortar', #A.panel:set(A.doc).frames == frames0 + 4 and A.panel:set(A.doc).frames[frames0 + 3].w == 16, #A.doc.frames .. ' cuadros tras cortar la hoja')
            A.unsaved = true
        elseif frame == 30 then shot(3); key('s', true)
        elseif frame == 32 then
            local ok, bad = validJson()
            local w = writes[1]
            local back = w and json.decode(w.text)
            check('guarda', #writes == 1 and ok and w.path == 'assets/anim/enemies/gummy.json' and back.anims.attack and #back.frames == frames0 + 4 and not A.unsaved,
                  ('%d archivo(s): %s%s'):format(#writes, w and w.path or '-', ok and '' or (' JSON mal: ' .. bad)))
            -- lo guardado se vuelve a leer igual
            local s2 = Anim.fromData(back)
            check('ida_vuelta', s2:has('walk') and s2:frameAt('walk', 0) == 2 and s2.frames[frames0 + 1].x == 0 and s2.frames[frames0 + 2].x == 16, 'el JSON guardado da el mismo conjunto')
            print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails)); love.event.quit(fails == 0 and 0 or 1)
        end
    else
        local E = require 'src/editor/EnemyEditor'
        local ET = require('src/world/entities/Entities').types
        if frame == 3 then
            E.new('zz_prueba')
            E.spec.anim = 'enemies/gummy'; E.animDoc = Anim.read('enemies/gummy'); E.animDoc.id = 'enemies/gummy'
            check('nuevo', E.id == 'zz_prueba' and E.spec.hp == 1 and E.unsaved, 'enemigo nuevo con valores por defecto')
        elseif frame == 6 then shot(1)
        elseif frame == 7 then E.tab = 'general'
        elseif frame == 9 then shot(2)
        elseif frame == 10 then E.tab = 'states'
        elseif frame == 12 then shot(3)
        elseif frame == 13 then E.tab = 'beh'
            E.spec.behaviors = { { type = 'chase', range = 6 }, { type = 'melee' } }
            E.spec.hp = 2
            if os.getenv('KIND') == 'boss' then        -- (un JEFE de datos: su sala de prueba lleva zona de jefe)
                E.spec.boss = {}
                for k, v in pairs(require('src/world/entities/base/DataBoss').DEFAULTS) do E.spec.boss[k] = v end
                E.spec.behaviors = { { type = 'melee', range = 3 } }
            end
            E.hist:record()
            local u = E.hist:undo()
            local back = #E.spec.behaviors == 0
            E.hist:redo()
            check('deshacer', u and back and #E.spec.behaviors >= 1, 'deshacer quita los comportamientos y rehacer los devuelve')
        elseif frame == 15 then shot(4)
        elseif frame == 16 then E.tab = 'warn'
        elseif frame == 18 then shot(5)
        elseif frame == 19 then key('f5')
        elseif frame == 22 then
            local ok, bad = validJson()
            local paths = {}
            for _, w in ipairs(writes) do paths[#paths + 1] = w.path end
            local spec
            for _, w in ipairs(writes) do if w.path == 'assets/enemies/zz_prueba.json' then spec = json.decode(w.text) end end
            check('guarda', ok and spec and spec.hp == 2 and #spec.behaviors >= 1 and ET.byName.zz_prueba ~= nil,
                  table.concat(paths, ' · ') .. (ok and '' or (' JSON mal: ' .. bad)))
        elseif frame == 70 then
            local st = gStateMachine and gStateMachine:_top()
            local n, states = 0, {}
            for _, e in ipairs(st and st.enemies or {}) do if e.def and e.def.name == 'zz_prueba' then n = n + 1; states[#states + 1] = e.state end end
            local want = os.getenv('KIND') == 'boss' and 1 or 2
            if want == 1 then
                local z = st and st.level and st.level.bossZones and st.level.bossZones[1]
                check('jefe', ET.byName.zz_prueba.category == 'Jefes' and z ~= nil and states[1] == 'dormant', ('tipo de categoría %s; zona de jefe en la sala: %s (%s); el jefe espera dormido: %s'):format(tostring(ET.byName.zz_prueba.category), tostring(z ~= nil), z and z.state or '-', tostring(states[1])))
            end
            check('probar', Shell.mode == 'play' and st and st.player and n == want, ('en el juego: %s; enemigos zz_prueba: %d (%s)'):format(tostring(Shell.mode), n, table.concat(states, ', ')))
            shot(6)
        elseif frame == 74 then
            key('f10')
            check('volver', Shell.mode == 'edit', 'F10 vuelve al editor')
            print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails)); love.event.quit(fails == 0 and 0 or 1)
        end
    end
end
