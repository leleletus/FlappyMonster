-- tools/tests/editor_open — el editor de niveles real con el diálogo "Abrir
-- nivel" (Ctrl+O): captura la lista arriba y tras bajar con las flechas
-- (<save>/editor_open_1.png, _2.png), cierra el diálogo y captura la capa
-- Mini bloques (tecla 7, _3.png) y la pestaña Nivel con "Fondo y clima" abierto
-- (_4.png); "Guardar como" con el nombre de un nivel existente avisa y solo guarda al segundo Guardar
-- (_saveas.png; la escritura se intercepta); la PALETA de la capa Entidades con la categoría Enemigos (_entidades.png
-- arriba, _entidades_2.png abajo:
-- las miniaturas con dibujo propio — pez globo, piraña, topo, planta… — salían oscuras, 0.5.97); comprueba que no hay
-- errores.
-- LINKS=1: abre links.json (un bloque ON/OFF conectado a una inundación),
-- elige Bloques → Conectar (K), hace clic en el bloque y captura el
-- inspector y la línea de la conexión (_links.png).
--
-- PLAY=assets/levels/x.json: abre ese nivel en el editor, pulsa F5 (probar, como
-- el usuario), mete al jugador en la zona de jefe y captura 1.5 s después de
-- empezar la pelea (_play.png): lo que se ve jugando desde el editor.
-- Si el nivel no tiene zona de jefe: captura el editor en la capa Decoración (_play_ed.png) y el juego
-- quieto a los 0.5 / 1.2 / 2.0 / 2.8 / 3.8 s (_play_1.._5.png), p. ej. el hielo
-- fino agrietándose bajo el jugador (tools/levelgen/arenas/hielo.json). AT=col,fila:
-- pone ahí al jugador (ver cualquier parte de un nivel).
--
-- PLANE=1 (LEVEL=tools/levelgen/arenas/fondo.json): el PLANO DE FONDO en el editor (src/world/level/BackPlane.lua):
-- captura Delante (_plano_delante.png) y con zoom (_plano_zoom.png), P pasa a Fondo, pinta un bloque (solo en bgTiles),
-- uno que no puede ir allí no se pinta, el cuentagotas lee el fondo, coloca una decoración (plane = 'bg'), las capas de
-- delante no se eligen, borrar no toca lo de delante, captura con lo de delante translúcido (_plano_fondo.png) y la
-- paleta con lo que no puede ir apagado (_plano_paleta.png), deshacer / rehacer, guarda (bgTiles fila a fila, plane),
-- relee, cambia el tamaño, alejado al 25 % (_plano_lejos.png) y F5 lo prueba (_plano_play.png).
--
--   tools/tests/run.sh editor_open
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
arg = arg or {}
arg[#arg + 1] = '--editor'
local LINKS = os.getenv('LINKS')
if LINKS then arg[#arg + 1] = 'links.json' end
local PLAY = os.getenv('PLAY')
if PLAY then arg[#arg + 1] = PLAY end
local PLANE = os.getenv('PLANE')
if PLANE and not PLAY then arg[#arg + 1] = os.getenv('LEVEL') or 'assets/levels/nivel01.json' end
-- (filtros) sin preferencias de otra pasada: el diálogo "Abrir" empieza sin filtros; y un nivel FUERA de la historia y
-- de Worlds.MEMBERS, con fondo de fortaleza, en la carpeta de guardado (se borra al acabar): su isla se adivina por el fondo
local GUESS_LEVEL = 'assets/levels/zz_fondo_prueba.json'
love.filesystem.remove('editor_prefs.json')
if not (PLAY or LINKS or PLANE) then
    local json = require 'libs/json'
    local d = json.decode(love.filesystem.read('assets/levels/jardin_gummies.json'))
    d.name, d.name_en, d.background = 'Prueba por el fondo', 'Background guess test', 'fortress'
    love.filesystem.createDirectory('assets/levels')
    love.filesystem.write(GUESS_LEVEL, json.encode(d))
end
love.filesystem.load('game_main.lua')()
local frame, realDown = 0, love.keyboard.isDown
local function key(k, ctrl)
    if ctrl then love.keyboard.isDown = function(...) return true end end
    love.keypressed(k)
    love.keyboard.isDown = realDown
end
local function shot(n)
    love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_' .. n .. '.png') end)
end
-- ── PLANE=1: el plano de fondo en el editor ──
local PL = { ok = true }
local function check(name, ok, detail)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', detail))
    if not ok then PL.ok = false end
end
-- Ctrl + tecla (solo Ctrl: key(k, true) también "pulsa" Mayús, y Ctrl+Mayús+Z es rehacer)
local function ctrlKey(k)
    local real = love.keyboard.isDown
    love.keyboard.isDown = function(...)
        for _, x in ipairs({ ... }) do if x == 'lctrl' then return true end end
        return false
    end
    love.keypressed(k)
    love.keyboard.isDown = real
end
-- clic (botón b) en el centro de la casilla (c, r), con la cámara del editor
local function clickCell(c, r, b)
    local E = require('src/editor/Editor').state()
    local mx = 292 + ((c - 0.5) * TILE_PX - E.camX) * E.zoom
    local my = 46 + ((r - 0.5) * TILE_PX - E.camY) * E.zoom
    local realPos = love.mouse.getPosition
    love.mouse.getPosition = function() return mx, my end
    love.mousepressed(mx, my, b or 1); love.mousereleased(mx, my, b or 1)
    love.mouse.getPosition = realPos
end
function planeCase()
    local E = require('src/editor/Editor').state()
    local Model = require 'src/editor/EditorModel'
    local Tiles = require 'src/world/tiles/Tiles'
    local BackPlane = require 'src/world/level/BackPlane'
    local DT = require('src/world/decorations/Decorations').types
    local json = require 'libs/json'
    local m = E.model
    if frame == 4 then shot('plano_delante') end
    if frame == 6 then PL.zoom0 = E.zoom; E.zoom = 1.5 end
    if frame == 9 then shot('plano_zoom') end
    if frame == 11 then
        E.zoom = PL.zoom0
        key('p')
        check('plano', E.plane == 'bg' and E.layer == 'tiles', 'P → plano ' .. tostring(E.plane) .. ', capa ' .. E.layer)
        -- una casilla vacía en los dos planos, a la vista
        for r = 2, 8 do for c = 3, 16 do
            if not PL.c and m.bgTiles[r][c] == 0 and m.tiles[r][c] == TILE_EMPTY and m.bgTiles[r][c + 1] == 0 then PL.c, PL.r = c, r end
        end end
        E.palette.tiles = TILE_SOLID; E.tool.tiles = 'brush'
        PL.undo0 = #E.undo
        clickCell(PL.c, PL.r)
        check('pintar', m.bgTiles[PL.r][PL.c] == Tiles.codec.encode(TILE_SOLID, false, nil) and m.tiles[PL.r][PL.c] == TILE_EMPTY,
              ('(%d,%d): fondo %d, delante %d'):format(PL.c, PL.r, m.bgTiles[PL.r][PL.c], m.tiles[PL.r][PL.c]))
        -- uno que no puede ir al plano (líquido, peligro, activador...): no se pinta
        local bad
        for _, t in ipairs(Tiles.types.list) do if not bad and t.id ~= 0 and not t.editorHide and not BackPlane.allows(t) then bad = t end end
        E.palette.tiles = bad.id
        clickCell(PL.c + 1, PL.r)
        check('prohibido', m.bgTiles[PL.r][PL.c + 1] == 0 and m.tiles[PL.r][PL.c + 1] == TILE_EMPTY and tostring(E.msg):find('no puede') ~= nil,
              bad.label .. ' en el fondo: ' .. m.bgTiles[PL.r][PL.c + 1] .. ' · aviso: ' .. tostring(E.msg))
        E.tool.tiles = 'pick'
        clickCell(PL.c, PL.r)
        check('gotero', E.palette.tiles == TILE_SOLID, 'el cuentagotas copia el bloque del fondo: ' .. tostring(E.palette.tiles))
    end
    if frame == 12 then shot('plano_paleta') end       -- (la paleta de Bloques en el fondo: lo que no puede ir, apagado)
    if frame == 14 then
        key('5')
        local ft
        for _, t in ipairs(DT.list) do if not ft and t.plane ~= 'bg' and t.placement ~= 'sub' then ft = t end end
        E.palette.deco, E.tool.deco = ft.name, 'place'
        PL.nDeco = #m.foliage
        clickCell(PL.c + 2, PL.r)
        local n = m.foliage[#m.foliage]
        PL.deco = n
        check('deco', #m.foliage == PL.nDeco + 1 and n.plane == 'bg' and E.layer == 'deco',
              ft.label .. ' colocada en el fondo: plane = ' .. tostring(n and n.plane))
        key('4')
        check('capas', E.layer == 'deco', 'en el fondo, la tecla 4 (Entidades) no cambia de capa: ' .. E.layer)
        -- borrar en el fondo no toca las decoraciones de delante
        local front
        for _, d in ipairs(m.foliage) do if not front and d.plane ~= 'bg' and not m:decoAt(d.col, d.row, nil, 'bg') then front = d end end
        if front then
            local before = #m.foliage
            E.tool.deco = 'erase'
            clickCell(front.col, front.row)
            check('borrar', #m.foliage == before, 'borrar en el fondo sobre una decoración de delante: ' .. before .. ' → ' .. #m.foliage)
            E.tool.deco = 'select'
        end
        E.selDeco = PL.deco; E.rightTab = 'sel'
    end
    -- (el usuario: en el Fondo, al mover la cámara lo de delante translúcido dejaba ESTELA fuera del nivel — se borraba
    -- con el recorte de la ventana puesto —): se aparta la cámara para que a la izquierda del nivel no haya nada, se
    -- mueve, y a la izquierda del nivel todo debe ser el fondo liso del lienzo
    if frame == 15 then PL.cam0 = { E.camX, E.camY }; E.camX = -420 / E.zoom end
    if frame == 16 then
        E.camX = -210 / E.zoom
        love.graphics.captureScreenshot(function(img) PL.cap = img end)
    end
    if frame == 17 and PL.cap then
        local lx = 292 + (0 - E.camX) * E.zoom                    -- (borde izquierdo del nivel en la ventana)
        local r0, g0, b0 = PL.cap:getPixel(300, 300)
        local same = true
        for x = 300, math.floor(lx) - 6, 12 do
            for y = 120, 700, 40 do
                local r, g, b = PL.cap:getPixel(x, y)
                if math.abs(r - r0) + math.abs(g - g0) + math.abs(b - b0) > 0.02 then same = false end
            end
        end
        check('estela', lx > 360 and same, ('fuera del nivel (x 300..%d), tras mover la cámara: todo el fondo liso=%s'):format(math.floor(lx), tostring(same)))
        E.camX, E.camY = PL.cam0[1], PL.cam0[2]
    end
    if frame == 18 then shot('plano_fondo') end
    if frame == 20 then
        local u = #E.undo
        ctrlKey('z')
        local gone = #m.foliage == PL.nDeco
        ctrlKey('y')
        check('deshacer', gone and #m.foliage == PL.nDeco + 1 and m.bgTiles[PL.r][PL.c] ~= 0 and u - PL.undo0 >= 2,
              ('deshacer quita la decoración (%s), rehacer la devuelve; %d pasos en el historial'):format(tostring(gone), u - PL.undo0))
        ctrlKey('z'); ctrlKey('z')
        local noBlock = E.model.bgTiles[PL.r][PL.c] == 0
        ctrlKey('y'); ctrlKey('y')
        m = E.model
        check('deshacer2', noBlock and m.bgTiles[PL.r][PL.c] ~= 0, 'deshacer también quita el bloque del fondo; rehacer lo pone')
        -- guardar (el texto que se escribiría) y releer
        local txt = m:encode()
        local d = json.decode(txt)
        local hasDeco = false
        for _, f in ipairs(d.foliage) do if f.col == PL.c + 2 and f.row == PL.r and f.plane == 'bg' then hasDeco = true end end
        check('guardar', d.bgTiles and d.bgTiles[PL.r][PL.c] ~= 0 and hasDeco and txt:find('"bgTiles": %[\n    %[') ~= nil and #d.bgTiles == d.height,
              'bgTiles fila a fila (' .. (d.bgTiles and #d.bgTiles or 0) .. ' filas) y la decoración con "plane": "bg"')
        local m2 = Model.fromData(d, 'x.json')
        local lv = require('src/world/level/Level').fromData(json.decode(txt))
        check('releer', m2.bgTiles[PL.r][PL.c] == d.bgTiles[PL.r][PL.c] and lv.bg ~= nil and #lv.bgDecorations >= 1,
              'el editor y el juego lo leen: Level.bg y ' .. #lv.bgDecorations .. ' decoraciones en el plano')
        check('vacio', not Model.new(10, 8, 'x'):encode():find('bgTiles'), 'un nivel sin plano no guarda "bgTiles"')
        m2:resize(m2.width + 3, m2.height + 2)
        check('tamano', #m2.bgTiles == m2.height and #m2.bgTiles[1] == m2.width and m2.bgTiles[PL.r][PL.c] == d.bgTiles[PL.r][PL.c],
              ('cambiar el tamaño cambia bgTiles: %dx%d'):format(#m2.bgTiles[1], #m2.bgTiles))
        key('p')
        check('delante', E.plane == 'front', 'P vuelve a Delante')
    end
    if frame == 21 then E.zoom = 0.25 end
    if frame == 23 then shot('plano_lejos') end        -- (alejado del todo: el plano sigue en su sitio)
    if frame == 24 then E.zoom = PL.zoom0; key('f5') end
    local st = gStateMachine and gStateMachine:_top()
    if frame > 26 and st and st.level and st.player and not PL.played then
        PL.played = frame
        check('probar', st.level.bg ~= nil, 'F5: el nivel de prueba tiene el plano de fondo (Level.bg)')
    end
    if PL.played and frame == PL.played + 60 then shot('plano_play') end
    if PL.played and frame == PL.played + 64 then
        print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_plano_{delante,zoom,paleta,fondo,lejos,play}.png')
        E.unsaved = false                  -- (si no, el editor pide confirmar el cierre)
        if PL.ok then print('TODO OK'); love.event.quit(0) else love.event.quit(1) end
    end
    if frame > 600 and not PL.played then print('FALLA: la prueba del nivel no arrancó'); E.unsaved = false; love.event.quit(1) end
end
local gameUpdate = love.update
function love.update(dt)
    frame = frame + 1
    gameUpdate(dt)
    if PLAY then
        -- (WIN=1813x1014: tamaño de ventana, p. ej. el del usuario)
        if frame == 2 and os.getenv('WIN') == 'full' then
            love.window.setFullscreen(true, 'desktop')
            if love.resize then love.resize(love.graphics.getDimensions()) end
            print('ventana: ' .. table.concat({ love.graphics.getDimensions() }, 'x') .. ' dpi ' .. love.window.getDPIScale())
        elseif frame == 2 and os.getenv('WIN') then
            local w, h = os.getenv('WIN'):match('(%d+)x(%d+)')
            love.window.updateMode(tonumber(w), tonumber(h), { resizable = true })
            print('ventana: ' .. table.concat({ love.graphics.getDimensions() }, 'x'))
            if love.resize then love.resize(tonumber(w), tonumber(h)) end
        end
        if frame == 2 then key('5') end            -- (capa Decoración: la paleta sale en la captura)
        if frame == 4 then love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play_ed.png') end) end
        if frame == 6 then key('f5') end
        local st = gStateMachine and gStateMachine:_top()
        if frame > 8 and st and st.player and st.level then
            local z = (st.level.bossZones or {})[1]
            if z and not PLAY_placed then
                PLAY_placed = true
                st.player.x, st.player.y = z.x0 + 2 * TILE_PX, z.y1 - 2 * TILE_PX
            end
            if not z then
                if not PLAY_t0 and os.getenv('AT') then
                    -- AT=col,fila: pone al jugador ahí (capturas de cualquier parte del nivel)
                    local c, r = os.getenv('AT'):match('(%d+),(%d+)')
                    st.player.x, st.player.y = (tonumber(c) - 0.5) * TILE_PX, (tonumber(r) - 0.5) * TILE_PX
                    st.player.spawnX, st.player.spawnY = st.player.x, st.player.y
                end
                PLAY_t0 = PLAY_t0 or frame
                for i, sec in ipairs({ 0.5, 1.2, 2.0, 2.8, 3.8 }) do
                    PLAY_shot = PLAY_shot or {}
                    if frame >= PLAY_t0 + math.floor(sec * 60) and not PLAY_shot[i] then
                        PLAY_shot[i] = true
                        love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play_' .. i .. '.png') end)
                    end
                end
                if frame >= PLAY_t0 + 240 then
                    print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_play_*.png')
                    print('TODO OK'); love.event.quit(0)
                end
            end
            if z and z.state == 'fight' then
                PLAY_fight = PLAY_fight or frame
                if frame == PLAY_fight + 90 then
                    love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_play.png') end)
                end
                if frame == PLAY_fight + 96 then
                    print('captura en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_play.png')
                    print('TODO OK'); love.event.quit(0)
                end
            end
        end
        if PLAY_t0 and not (st and st.player) and frame >= PLAY_t0 + 240 then
            print('TODO OK'); love.event.quit(0)           -- (p. ej. el jugador estaba muriendo)
        end
        if frame > 3000 then print('FALLA: la pelea no empezó'); love.event.quit(1) end
        return
    end
    if PLANE then return planeCase() end
    if LINKS then
        if frame == 5 then key('1') end
        if frame == 8 then key('k') end
        if frame == 12 then
            -- clic en la casilla (3,3): cámara inicial (-40,-40) al 75 %
            local mx, my = 292 + (2.5 * 64 + 40) * 0.75, 46 + (2.5 * 64 + 40) * 0.75
            local realPos = love.mouse.getPosition
            love.mouse.getPosition = function() return mx, my end
            love.mousepressed(mx, my, 1); love.mousereleased(mx, my, 1)
            love.mouse.getPosition = realPos
        end
        if frame == 20 then love.graphics.captureScreenshot(function(img) img:encode('png', 'editor_open_links.png') end) end
        if frame == 26 then
            print('captura en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_links.png')
            print('TODO OK'); love.event.quit(0)
        end
        return
    end
    if frame == 5 then key('o', true) end
    if frame == 10 then shot(1) end
    if frame >= 12 and frame < 42 then key('down') end
    if frame == 50 then shot(2) end
    if frame == 55 then key('escape') end
    if frame == 60 then key('7') end                    -- capa Mini bloques
    if frame == 66 then shot(3) end
    -- Pestaña Nivel con todas sus secciones abiertas (Fondo y clima, Música...)
    if frame == 68 then
        local E = require('src/editor/Editor').state()
        E.rightTab = 'level'
        local ui = require 'src/editor/ui'
        for _, k in ipairs({ 'lvl:weather' }) do ui.state.sections[k] = true end
    end
    if frame == 74 then shot(4) end
    -- "Guardar como" con el nombre de un nivel que YA existe (de la historia): el primer Guardar solo avisa; el
    -- segundo lo guarda (la escritura se intercepta: nunca toca el repo)
    if frame == 76 then
        local E = require('src/editor/Editor').state()
        E.rightTab = nil
        E.model.save = function(_, p) SAVEAS_PATH = p; return true end
        E.modal = { kind = 'saveas', name = 'valle_soleado' }
    end
    if frame == 79 then key('return') end
    if frame == 82 then
        local E = require('src/editor/Editor').state()
        SAVEAS_1 = { saved = SAVEAS_PATH, confirm = E.modal and E.modal.confirm }
        shot('saveas')
        key('return')
    end
    if frame == 86 then
        local ok = SAVEAS_1.saved == nil and SAVEAS_1.confirm == 'valle_soleado' and SAVEAS_PATH == 'assets/levels/valle_soleado.json'
        print(('%-10s %s  1er Guardar: guarda=%s, avisa=%s; 2º: guarda en %s'):format('guardar', ok and 'OK   ' or 'FALLA',
            tostring(SAVEAS_1.saved), tostring(SAVEAS_1.confirm), tostring(SAVEAS_PATH)))
        if not ok then print('Error: "Guardar como" pisa un nivel existente sin preguntar') end
    end
    -- "Abrir" con el BUSCADOR (el usuario no encontraba el nivel del jefe): tiene el foco al abrir; escribir filtra (sin
    -- tildes ni mayúsculas, por archivo y nombre) e Intro abre el primero que coincide
    if frame == 88 then
        local E = require('src/editor/Editor').state()
        local t0 = love.timer.getTime()
        E.modal = { kind = 'open', files = E.listLevels() }
        local t1 = love.timer.getTime()
        local again = E.listLevels()                                -- (la 2ª vez, de la caché)
        local t2 = love.timer.getTime()
        OPEN_N = #E.modal.files
        -- FILTROS (el usuario: aislar por isla, por modo y los de jefe): la Costa Helada = sus 6 niveles de la historia;
        -- Rey de la Colina = solo niveles con zona de puntos; solo jefes = con jefe (sí el templo del escarabajo, no el
        -- valle soleado); los tres a la vez se combinan
        local files = E.modal.files
        local set = function(v) local t = {} for _, p in ipairs(v) do t[p:match('([^/]+)%.json$')] = true end return t end
        local ch = set(E.filterLevels(files, '', { world = 'costa_helada' }))
        local nch = 0 for _ in pairs(ch) do nch = nch + 1 end
        local koth = E.filterLevels(files, '', { mode = 'koth' })
        local kothOk = #koth > 5
        for _, p in ipairs(koth) do if not files.meta[p].modes.koth then kothOk = false end end
        local boss = set(E.filterLevels(files, '', { boss = true }))
        local both = E.filterLevels(files, '', { world = 'nieve', boss = true })
        local ok = nch == 6 and ch.fabrica_criogenica and ch.bajo_el_hielo and ch.glaciar_cangrejo and ch.lago_de_cristal
            and kothOk and boss.templo_escarabajo and boss.lago_helado and not boss.valle_soleado
            and #both == 1 and both[1]:match('lago_helado') ~= nil
        print(('%-10s %s  Costa Helada %d niveles · Rey de la Colina %d · con jefe %d · Montañas + jefe = %s · lista %.2f s (2ª vez %.2f s)'):format(
            'filtros', ok and 'OK   ' or 'FALLA', nch, #koth, #E.filterLevels(files, '', { boss = true }), tostring(both[1]), t1 - t0, t2 - t1))
        if not ok then print('Error: los filtros del diálogo "Abrir" no aíslan bien') end
        -- ISLA = la isla a la que PERTENECE (el usuario: "no por el fondo que usan"): los secretos con su mundo; fuera de
        -- la historia, la tabla Worlds.MEMBERS (la mina inundada, con fondo de montaña, en las Cuevas); solo sin tabla se
        -- adivina por el fondo, avisado; sin isla, "Otros"
        local Worlds = require 'src/story/Worlds'
        local function inW(w) return set(E.filterLevels(files, '', { world = w })) end
        local costa, cuevas, final, nieve, fort, otros = inW('costa'), inW('cuevas'), inW('final'), inW('nieve'), inW('fortaleza'), inW(E.NO_WORLD)
        local tableOk, bad = true, {}
        local wset = {} for _, W in ipairs(Worlds.LIST) do wset[W.id] = true end
        for id, w in pairs(Worlds.MEMBERS) do
            local m = files.meta['assets/levels/' .. id .. '.json']
            if not love.filesystem.getInfo('assets/levels/' .. id .. '.json') or (w and not wset[w]) or (m and (m.guess or m.world ~= (w or nil))) then
                tableOk = false; bad[#bad + 1] = id
            end
        end
        local gm = files.meta[GUESS_LEVEL]
        local ok2 = costa.guarida_cangrejo_rey and cuevas.gruta_lugubre and final.isla_del_groove and final.mashup_cangrejos
            and cuevas.mina_inundada and not nieve.mina_inundada and costa.rebote_real and otros.EnemyTest and not otros.valle_soleado
            and tableOk and fort.zz_fondo_prueba and gm and gm.guess and not files.meta['assets/levels/mina_inundada.json'].guess
        print(('%-10s %s  secretos en su isla (guarida → Costa, gruta lúgubre → Cuevas, Groove y Mashup → Final) · fuera de la historia por la tabla (%d; mina inundada → Cuevas, no Montañas)%s · adivinado por el fondo: zz_fondo_prueba → %s · Otros %d'):format(
            'isla', ok2 and 'OK   ' or 'FALLA', (function() local n = 0 for _ in pairs(Worlds.MEMBERS) do n = n + 1 end return n end)(),
            #bad > 0 and (' MAL: ' .. table.concat(bad, ', ')) or '', tostring(gm and gm.guess and gm.world), (function() local n = 0 for _ in pairs(otros) do n = n + 1 end return n end)()))
        if not ok2 then print('Error: el filtro Isla no usa la isla a la que pertenece el nivel') end
    end
    if frame == 90 then for ch in ('TEMPLO escarabajo'):gmatch('.') do love.textinput(ch) end end
    if frame == 93 then shot('abrir') end
    if frame == 95 then key('return') end
    if frame == 98 then
        local E = require('src/editor/Editor').state()
        local path = E.model and E.model.path
        local ok = path == 'assets/levels/templo_escarabajo.json' and E.modal == nil and (OPEN_N or 0) > 20
        print(('%-10s %s  %d niveles · «TEMPLO escarabajo» + Intro abre %s'):format('buscar', ok and 'OK   ' or 'FALLA', OPEN_N or 0, tostring(path)))
        if not ok then print('Error: el buscador de "Abrir" no encuentra el nivel') end
    end
    -- NADA SE PIERDE al guardar o probar desde el editor (el usuario: probando el Mega Mashup desde el editor, la arena
    -- de la Gloomy no se ponía a oscuras — el editor tiraba `scenes` —): cada nivel del juego, cargado en el editor y
    -- escrito como lo guarda, conserva todas sus claves de primer nivel; las que el editor no conoce, idénticas
    if frame == 99 then
        local Model = require 'src/editor/EditorModel'
        local json = require 'libs/json'
        local n, lost = 0, {}
        for _, f in ipairs(love.filesystem.getDirectoryItems('assets/levels')) do
            if f:match('%.json$') then
                local path = 'assets/levels/' .. f
                local okA, a = pcall(json.decode, love.filesystem.read(path))
                local m = okA and Model.load(path)
                if m then
                    n = n + 1
                    local okB, b = pcall(json.decode, m:encode())
                    for k, v in pairs(a) do
                        local miss = not okB or b[k] == nil
                        if not miss and not (Model.KNOWN or {})[k] then miss = json.encode(v) ~= json.encode(b[k]) end
                        if miss and not (type(v) == 'table' and next(v) == nil) and v ~= false then lost[#lost + 1] = f .. ':' .. k end
                    end
                end
            end
        end
        local m = Model.load('assets/levels/mashup_cangrejos.json')
        local back = json.decode(m:encode())
        local dark3 = back.scenes and back.scenes[3] and back.scenes[3].dark == true
        local ok = n > 40 and #lost == 0 and dark3 and back.event ~= nil
        print(('%-10s %s  %d niveles cargados y escritos por el editor: claves perdidas %d%s · Mashup: escenas %d (la 3ª a oscuras %s), evento %s'):format(
            'conserva', ok and 'OK   ' or 'FALLA', n, #lost, #lost > 0 and (' (' .. table.concat(lost, ', ', 1, math.min(#lost, 6)) .. ')') or '',
            back.scenes and #back.scenes or 0, tostring(dark3), tostring(back.event ~= nil)))
        if not ok then print('Error: el editor pierde datos del nivel al guardar o probar') end
    end
    -- La paleta de Entidades, solo los Enemigos (buscar "enemigos": la categoría)
    if frame == 99 then
        local Ed = require('src/editor/Editor')
        Ed.setLayer('entities')
        local E = Ed.state()
        E.search = E.search or {}
        E.search.entities = 'enemigos'
    end
    if frame == 102 then shot('entidades') end
    if frame == 103 then require('src/editor/ui').state.scroll.pal_entities = 9999 end      -- (y el final de la lista)
    if frame == 105 then shot('entidades_2') end
    -- LOS FILTROS SE RECUERDAN (el usuario: "es incómodo colocar el filtro a cada rato"): al cerrar y volver a abrir
    -- "Abrir" siguen los tres filtros y el texto (el de «buscar»), también en otra sesión del editor (editor_prefs.json);
    -- "Quitar filtros" los quita todos de un clic (y también para la siguiente vez)
    local function openDlg() local E = require('src/editor/Editor').state(); E.modal = { kind = 'open', files = E.listLevels() } end
    local function dlgClick(which)
        local E = require('src/editor/Editor').state()
        local sw, sh = love.graphics.getDimensions()
        local w, h = math.min(sw - 80, 660), math.min(sh - 80, 180 + #E.modal.files * 34)
        local x, y = (sw - w) / 2, (sh - h) / 2
        local mx, my
        if which == 'isla' then mx, my = x + 145, y + 80 else mx, my = x + 95, y + h - 31 end
        CLICK_UNTIL = frame + 3
        REAL_POS = REAL_POS or love.mouse.getPosition
        love.mouse.getPosition = function() return mx, my end
        love.mousepressed(mx, my, 1); love.mousereleased(mx, my, 1)
    end
    if CLICK_UNTIL and frame >= CLICK_UNTIL then love.mouse.getPosition = REAL_POS; CLICK_UNTIL = nil end
    local function md() return require('src/editor/Editor').state().modal end
    if frame == 108 then openDlg() end
    if frame == 110 then REM = { q1 = md().query }; dlgClick('isla') end
    if frame == 114 then REM.w1 = md().filters.world; shot('abrir_filtros') end
    if frame == 115 then require('src/editor/Editor').state().modal = nil end
    if frame == 116 then openDlg() end
    if frame == 118 then REM.w2, REM.q2 = md().filters.world, md().query
        require('src/editor/Editor').state().modal = nil
        require('src/editor/Editor').state().forgetOpenPrefs()             -- (otra sesión: lo relee del archivo)
        openDlg() end
    if frame == 120 then REM.w3, REM.q3 = md().filters.world, md().query; dlgClick('quitar') end
    if frame == 124 then
        local E = require('src/editor/Editor').state()
        REM.reset = md().filters.world == nil and md().filters.mode == nil and md().filters.boss == nil and md().query == ''
            and #E.filterLevels(md().files, md().query, md().filters) == #md().files
        md().query = 'prueba por el fondo'                -- (sin guardarlo: la captura del aviso "(por el fondo)")
        shot('abrir_fondo')
    end
    if frame == 125 then local E = require('src/editor/Editor').state(); E.modal = nil; E.forgetOpenPrefs(); openDlg() end
    if frame == 127 then
        local f = md().filters
        local again = f.world == nil and f.mode == nil and f.boss == nil and md().query == ''
        local q = 'TEMPLO escarabajo'
        local ok = REM.q1 == q and REM.w1 == 'pradera' and REM.w2 == 'pradera' and REM.q2 == q and REM.w3 == 'pradera'
            and REM.q3 == q and REM.reset and again and love.filesystem.getInfo('editor_prefs.json') ~= nil
        print(('%-10s %s  al reabrir: texto «%s», Isla %s → cerrar y abrir: %s «%s» · otra sesión (archivo): %s «%s» · Quitar filtros: %s, y al reabrir %s'):format(
            'recuerda', ok and 'OK   ' or 'FALLA', tostring(REM.q1), tostring(REM.w1), tostring(REM.w2), tostring(REM.q2),
            tostring(REM.w3), tostring(REM.q3), tostring(REM.reset), again and 'sin filtros' or 'CON filtros'))
        if not ok then print('Error: el diálogo "Abrir" no recuerda (o no quita) los filtros') end
        require('src/editor/Editor').state().modal = nil
        love.filesystem.remove(GUESS_LEVEL)
    end
    if frame == 129 then
        print('capturas en ' .. love.filesystem.getSaveDirectory() .. '/editor_open_{1,2,3,4,saveas,abrir,abrir_filtros,abrir_fondo,entidades,entidades_2}.png')
        print('TODO OK'); love.event.quit(0)
    end
end
