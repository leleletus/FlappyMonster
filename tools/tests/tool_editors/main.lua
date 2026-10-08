-- tools/tests/tool_editors — los editores de ANIMACIONES y de ENEMIGOS de verdad (love . --anim / --enemy), sin
-- escribir nada en el repo (lo que guardarían se captura y se comprueba que es JSON válido):
--   TOOL=anim   (por defecto) abre el conjunto `gummy`, cambia de secuencia, crea una, cambia su velocidad, abre la
--               ventana de cortar una hoja y añade sus cuadros; "guarda"; capturas tool_anim_1..3.png
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
if TOOL == 'anim' then arg[#arg + 1] = 'enemies/gummy' end
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
Shell.writeRepo = function(path, text)
    writes[#writes + 1] = { path = path, text = text }
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

local frame = 0
local toolUpdate = love.update
function love.update(dt)
    frame = frame + 1
    toolUpdate(dt)
    if TOOL == 'anim' then
        local A = require 'src/editor/AnimEditor'
        if frame == 3 then
            check('abre', A.id == 'enemies/gummy' and A.doc and #A.doc.frames == 4, ('conjunto %s con %d cuadros'):format(tostring(A.id), A.doc and #A.doc.frames or 0))
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
        elseif frame == 24 then shot(4)
        elseif frame == 25 then
            check('explorador', #A.list >= 100, #A.list .. ' conjuntos en el explorador')
            A.browse = false
        elseif frame == 27 then
            -- (lo que hace el botón "Añadir 4 cuadros")
            for c = 0, 3 do A.doc.frames[#A.doc.frames + 1] = { image = 'assets/images/enemies/hopper/pradera-Sheet.png', x = c * 16, y = 0, w = 16, h = 21 } end
            A.panel.modal = nil; A.panel:touch(); A.panel.frame = 7
            check('cortar', #A.panel:set(A.doc).frames == 8 and A.panel:set(A.doc).frames[7].w == 16, #A.doc.frames .. ' cuadros tras cortar la hoja')
            A.unsaved = true
        elseif frame == 30 then shot(3); key('s', true)
        elseif frame == 32 then
            local ok, bad = validJson()
            local w = writes[1]
            local back = w and json.decode(w.text)
            check('guarda', #writes == 1 and ok and w.path == 'assets/anim/enemies/gummy.json' and back.anims.attack and #back.frames == 8 and not A.unsaved,
                  ('%d archivo(s): %s%s'):format(#writes, w and w.path or '-', ok and '' or (' JSON mal: ' .. bad)))
            -- lo guardado se vuelve a leer igual
            local s2 = Anim.fromData(back)
            check('ida_vuelta', s2:has('walk') and s2:frameAt('walk', 0) == 2 and s2.frames[5].x == 0 and s2.frames[6].x == 16, 'el JSON guardado da el mismo conjunto')
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
