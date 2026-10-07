-- src/editor/Editor.lua
-- Editor de niveles de FlappyMonster.  Uso:  love . --editor [assets/levels/x.json]
--
-- Corre dentro del propio juego: usa los mismos catálogos (src/world/tiles/Tiles.lua,
-- src/world/entities/Entities.lua), el mismo dibujo y los mismos assets, así que todo
-- tile, material o entidad nuevo aparece aquí solo. "Probar" (F5) juega el
-- nivel en el mismo proceso y F10 vuelve al editor.

local ui       = require 'src/editor/ui'
local Model    = require 'src/editor/EditorModel'
local Tiles    = require 'src/world/tiles/Tiles'
local Entities = require 'src/world/entities/Entities'
local Level    = require 'src/world/level/Level'
local DT       = require('src/world/decorations/Decorations').types
local Clip     = require 'src/ui/Clip'
local SpikeSkins = require 'src/world/level/SpikeSkins'
local Sky      = require 'src/fx/Sky'
local BossZones = require 'src/world/systems/BossZones'
local AutoScroll = require 'src/world/systems/AutoScroll'
local Modes     = require 'src/world/modes/Modes'
local Music     = require 'src/audio/Music'
local SubTiles  = require 'src/world/level/SubTiles'

local Codec, TT, ET, Props = Tiles.codec, Tiles.types, Entities.types, Entities.props
local th = ui.theme

local Editor = {}
local G = {}                 -- callbacks originales del juego (modo prueba)
local E = {}                 -- estado del editor
local P = {}        -- locales de archivo que comparten las partes (ver abajo "Partes")
local canvasPress, canvasDrag, canvasRelease, drawCanvas, drawTopBar, drawLeftPanel, drawRightPanel, drawStatus      -- (de las partes: se rellenan al cargarlas)
local drawModal      -- (de las partes: se rellenan al cargarlas)

local TOP, LEFT, RIGHT, STATUS = 46, 292, 330, 26
local LEVELS_DIR = 'assets/levels'
local PLAYTEST   = 'editor_playtest.json'
local T = function() return TILE_PX end

-- ── Capas y herramientas ──────────────────────────────────────────────────────
-- Una capa = qué se edita; cada una tiene sus herramientas (tecla entre
-- paréntesis) y una descripción que el panel enseña como ayuda.
local LAYERS = {
    { id='tiles',    label='Bloques',    tools={ 'brush', 'rect', 'line', 'fill', 'pick', 'link', 'erase' },
      help='Terreno, plataformas, líquidos, peligros y meta.' },
    { id='water',    label='Agua',       tools={ 'brush', 'rect', 'fill', 'erase' },
      help='Llena celdas de agua. Se combina con cualquier bloque (una plataforma sumergida, por ejemplo). El bloque "Agua" sin nada más está en la capa Bloques.' },
    { id='spikes',   label='Pinchos',    tools={ 'brush', 'erase' },
      help='Pinchos en cuartos de casilla: haz clic en el cuarto donde lo quieras. Matan al tocarlos por la punta.' },
    { id='entities', label='Entidades',  tools={ 'select', 'place', 'erase' },
      help='Enemigos, jefes, trampas, mecanismos y objetos.' },
    { id='deco',     label='Decoración', tools={ 'select', 'place', 'erase' },
      help='Plantas y adornos: solo se ven, no afectan al juego.' },
    { id='special',  label='Especial',   tools={ 'spawn', 'vent', 'boss', 'erase' },
      help='Estructura del nivel: inicio del jugador, vents de oxígeno y zonas de jefe.' },
    { id='mini',     label='Mini bloques', tools={ 'brush', 'pick', 'erase' },
      help='Bloques de un cuarto de casilla (piedra, tierra, césped) en cualquiera de las 4 subceldas: para detalles y adornos. Sólidos para todos por defecto; desmarca "Sólido" para que sean solo decoración.' },
}
local TOOLS = {
    brush  = { label='Pincel',      key='b', help='Pinta casilla a casilla (arrastra). Clic derecho borra.' },
    rect   = { label='Rectángulo',  key='r', help='Arrastra para rellenar un rectángulo.' },
    line   = { label='Línea',       key='l', help='Arrastra para trazar una línea recta.' },
    fill   = { label='Relleno',     key='f', help='Rellena la zona contigua del mismo tipo.' },
    erase  = { label='Borrar',      key='e', help='Borra lo de esta capa (también con clic derecho).' },
    pick   = { label='Cuentagotas', key='i', help='Copia a la paleta el bloque que hay bajo el cursor.' },
    link   = { label='Conectar',    key='k', help='Clic en un bloque ON/OFF para elegir (a la derecha) a qué objeto está conectado (inundaciones...). Las conexiones se ven como líneas amarillas; al borrar el bloque se borra la suya.' },
    select = { label='Seleccionar', key='v', help='Clic para seleccionar y editar sus propiedades; arrastra para moverlo. Las cajitas azules (rutas, puntos, esquinas) también se arrastran.' },
    place  = { label='Colocar',     key='b', help='Coloca lo elegido en la paleta. Algunos objetos se pintan arrastrando.' },
    spawn  = { label='Inicio',      key='s', help='Mueve el punto donde aparece el jugador (uno por nivel).' },
    vent   = { label='Vent',        key='o', help='Coloca un vent de oxígeno en un cuarto de casilla (sus burbujas recargan el aire bajo el agua). Clic en uno para editarlo.' },
    boss   = { label='Zona de jefe', key='z', help='Arrastra para crear una zona (clic = una pantalla, 20×11). Arrastra una zona para moverla o su esquina inferior derecha para cambiar su tamaño. La cámara se queda fija en ella y nadie sale hasta vencer al jefe.' },
}
local DIRS = { { 0, 'Arriba' }, { 1, 'Abajo' }, { 2, 'Izquierda' }, { 3, 'Derecha' } }
local DIR_ARROW = { [0] = '^', [1] = 'v', [2] = '<', [3] = '>' }

local function layerDef(id) for _, l in ipairs(LAYERS) do if l.id == id then return l end end end

-- ── Utilidades ────────────────────────────────────────────────────────────────
local function msg(s, kind) E.msg, E.msgKind, E.msgT = s, kind or 'ok', 4 end

local function canvasRect()
    local w, h = love.graphics.getDimensions()
    return LEFT, TOP, w - LEFT - RIGHT, h - TOP - STATUS
end

local function screenToWorld(mx, my)
    local cx, cy = canvasRect()
    return E.camX + (mx - cx) / E.zoom, E.camY + (my - cy) / E.zoom
end

local function worldToCell(wx, wy)
    local t = T()
    local c, r = math.floor(wx / t) + 1, math.floor(wy / t) + 1
    local sx = math.floor((wx % t) / (t / 2))
    local sy = math.floor((wy % t) / (t / 2))
    return c, r, sy * 2 + sx + 1          -- subcelda: 1 TL, 2 TR, 3 BL, 4 BR
end

local function lineCells(c0, r0, c1, r1)
    local cells = {}
    local dc, dr = math.abs(c1 - c0), -math.abs(r1 - r0)
    local sc, sr = c0 < c1 and 1 or -1, r0 < r1 and 1 or -1
    local err = dc + dr
    while true do
        cells[#cells+1] = { c0, r0 }
        if c0 == c1 and r0 == r1 then break end
        local e2 = 2 * err
        if e2 >= dr then err = err + dr; c0 = c0 + sc end
        if e2 <= dc then err = err + dc; r0 = r0 + sr end
    end
    return cells
end

-- Imágenes para miniaturas (cache)
local imgCache = {}
local function img(path)
    if imgCache[path] == nil then
        local ok, i = pcall(love.graphics.newImage, path)
        imgCache[path] = ok and i or false
    end
    return imgCache[path] or nil
end

-- Versión con colores invertidos (miniatura del jefe espejo)
local invCache = {}
local function imgInv(path)
    if invCache[path] == nil then
        local ok, d = pcall(love.image.newImageData, path)
        if ok then
            d:mapPixel(function(_, _, r, g, b, a) return 1 - r, 1 - g, 1 - b, a end)
            invCache[path] = love.graphics.newImage(d)
            invCache[path]:setFilter('nearest', 'nearest')
        else
            invCache[path] = false
        end
    end
    return invCache[path] or nil
end
local function entThumb(t)
    local path = t.editor and t.editor.sprite or ''
    return (t.editor and t.editor.invert) and imgInv(path) or img(path)
end


local function drawImageFit(i, x, y, w, h, flipY)
    if not i then return end
    local s = math.min(w / i:getWidth(), h / i:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(i, x + w / 2, y + h / 2, 0, s, flipY and -s or s, i:getWidth() / 2, i:getHeight() / 2)
end

-- Miniatura de una entidad: su dibujo propio (editor.draw) o su sprite
local function drawEntThumb(t, x, y, w, h, flipY)
    if t.editor and t.editor.draw then
        local s = math.min(w, h)
        t.editor.draw(x + (w - s) / 2, y + (h - s) / 2, s)
    elseif t.editor and t.editor.frameW then
        -- Hoja de animación (editor.frameW): solo el primer cuadro
        local i = entThumb(t)
        if not i then return end
        local fw, fh = t.editor.frameW, i:getHeight()
        t._thumbQuad = t._thumbQuad or love.graphics.newQuad(0, 0, fw, fh, i:getWidth(), fh)
        local sc = math.min(w / fw, h / fh)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(i, t._thumbQuad, x + w / 2, y + h / 2, 0, sc, flipY and -sc or sc, fw / 2, fh / 2)
    else
        drawImageFit(entThumb(t), x, y, w, h, flipY)
    end
end

local function drawTileThumb(def, x, y, s)
    if def.draw or def.texture or def.color then
        TT.drawTile(def, { x = x, y = y, size = s, time = love.timer.getTime() })
    elseif def.name == 'empty' then
        ui.rect(x, y, s, s, th.bg, 0)
        love.graphics.setColor(th.danger[1], th.danger[2], th.danger[3], 0.6)
        love.graphics.line(x + 6, y + 6, x + s - 6, y + s - 6)
    else
        local c = def.editorColor or { 0.5, 0.5, 0.5 }
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
        love.graphics.rectangle('fill', x, y, s, s)
    end
end

-- Miniatura de una decoración usando su propio draw (anclada abajo-centro)
local decoThumbs = {}
local function drawDecoThumb(t, x, y, s)
    local d = decoThumbs[t.name]
    if not d then
        d = DT.instantiate(DT.normalize({ type = t.name, col = 1, row = 1, sub = 3 }))
        decoThumbs[t.name] = d
    end
    d.animT = d.animT + love.timer.getDelta()
    if t.update then t.update(d, love.timer.getDelta()) end
    local k = (t.editor and t.editor.previewScale) or (t.placement == 'sub' and 1.0 or 0.4)
    k = k * s / 64
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(x, y, s, s)
    love.graphics.push()
    love.graphics.translate(x + s / 2, y + s)
    love.graphics.scale(k)
    t.draw(d, 0, 0)
    love.graphics.pop()
    love.graphics.setScissor(sx, sy, sw, sh)
end

-- ── Modelo / historial ────────────────────────────────────────────────────────
local function markDirty() E.levelDirty = true; E.unsaved = true end

local function pushUndo()
    table.insert(E.undo, E.model:snapshot())
    if #E.undo > 200 then table.remove(E.undo, 1) end
    E.redo = {}
end

local function undo()
    if #E.undo == 0 then return msg('Nada que deshacer', 'warn') end
    table.insert(E.redo, E.model:snapshot())
    E.model:restore(table.remove(E.undo))
    E.selected, E.selDeco, E.selZone = nil, nil, nil; markDirty(); msg('Deshecho')
end

local function redo()
    if #E.redo == 0 then return msg('Nada que rehacer', 'warn') end
    table.insert(E.undo, E.model:snapshot())
    E.model:restore(table.remove(E.redo))
    E.selected, E.selDeco, E.selZone = nil, nil, nil; markDirty(); msg('Rehecho')
end

local function rebuild()
    local ok, lvl = pcall(E.model.buildLevel, E.model)
    if not ok then msg('Error al construir el nivel: ' .. tostring(lvl), 'error'); E.levelDirty = false; return end
    E.level = lvl
    -- Instancias de entidades para dibujarlas tal cual en el juego (asentadas)
    E.instances = {}
    for i, e in ipairs(E.model.entities) do
        local inst = Entities.create(Model.deepcopy(e))
        if inst then
            inst._spawnY = inst.y
            if inst.wantsLevel then inst.levelRef = lvl end           -- (p. ej. el Congelador: dónde se apoya)
            if inst.tryAttach then inst:tryAttach(lvl) end        -- trepadores: pegados a su pared/techo
            if not inst.flying then
                for _ = 1, 240 do inst:fall(lvl, 1 / 60); if inst.onGround then break end end
            end
            E.instances[i] = inst
        end
    end
    E.warnings = E.model:validate()
    E.levelDirty = false
end

local function setModel(m, path)
    E.model = m
    E.undo, E.redo = {}, {}
    E.selected, E.selDeco, E.selZone = nil, nil, nil
    E.unsaved = false
    E.levelDirty = true
    E.camX, E.camY, E.zoom = -40, -40, 0.75
    E.newW, E.newH = m.width, m.height
    rebuild()
    msg(path and ('Abierto ' .. path) or 'Nivel nuevo')
end

-- Niveles de la carpeta (con su nombre, para la lista de "Abrir"). Los que
-- empiezan por _ (p. ej. el de "Probar") no se ofrecen.
local function listLevels()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(LEVELS_DIR)) do
        if f:match('%.json$') and not f:match('^_') and f ~= 'editor_playtest.json' then
            out[#out+1] = LEVELS_DIR .. '/' .. f
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    local names = {}
    for _, path in ipairs(out) do
        local ok, d = pcall(function() return require('libs/json').decode(love.filesystem.read(path)) end)
        names[path] = ok and type(d) == 'table' and d.name or nil
    end
    out.names = names
    return out
end

local function guardUnsaved(action)
    if E.unsaved then
        E.modal = { kind = 'confirm', text = 'Hay cambios sin guardar. ¿Descartarlos?', onYes = action }
    else action() end
end

local function save(path)
    path = path or E.model.path
    if not path then E.modal = { kind = 'saveas', name = E.model.name or 'nivel' }; return end
    local ok, err = E.model:save(path)
    if ok then E.unsaved = false; msg('Guardado en ' .. path) else msg('No se pudo guardar: ' .. tostring(err), 'error') end
end

-- ── Modo prueba ───────────────────────────────────────────────────────────────
local function startPlay()
    local errs = 0
    for _, w in ipairs(E.warnings or {}) do if w[1] == 'error' then errs = errs + 1 end end
    if errs > 0 then E.rightTab = 'warn'; return msg('Corrige los errores (pestaña Avisos) antes de probar', 'error') end
    Editor.previewMusic(nil)
    love.filesystem.write(PLAYTEST, E.model:encode())
    if not E.gameReady then G.load(E.gameArgs or {}); E.gameReady = true end
    if G.resize then G.resize(love.graphics.getDimensions()) end
    gStateMachine:change('adventure', { level = PLAYTEST })
    E.mode = 'play'
end

local function stopPlay()
    if Sound then Sound.stopTracked('drowning'); Sound.stopMusic() end
    E.mode = 'edit'
    msg('De vuelta en el editor')
end

-- ── API usada por paneles ─────────────────────────────────────────────────────
function Editor.centerOn(c, r)
    local _, _, cw, ch = canvasRect()
    E.camX = (c - 0.5) * T() - cw / 2 / E.zoom
    E.camY = (r - 0.5) * T() - ch / 2 / E.zoom
end

function Editor.deleteSelected()
    if E.layer == 'deco' and E.selDeco then
        for i, x in ipairs(E.model.foliage) do
            if x == E.selDeco then pushUndo(); table.remove(E.model.foliage, i); break end
        end
        E.selDeco = nil; markDirty()
        return
    end
    local e = E.selected
    if not e then return end
    for i, x in ipairs(E.model.entities) do
        if x == e then pushUndo(); table.remove(E.model.entities, i); break end
    end
    E.selected = nil; markDirty()
end

function Editor.duplicate()
    local e = E.selected
    if not e then return end
    pushUndo()
    local d = Model.deepcopy(e)
    d.col = math.min(E.model.width, d.col + 1)
    if d.props.patrol then d.props.patrol.left = d.props.patrol.left + 1; d.props.patrol.right = d.props.patrol.right + 1 end
    table.insert(E.model.entities, d)
    E.selected = d; markDirty()
end

-- Escuchar una música del catálogo en el editor (nil = parar). Los sonidos
-- se cargan la primera vez (el editor no los necesita hasta entonces).
function Editor.previewMusic(id)
    if not Sound or (not id and not E.soundReady) then E.preview = nil; return end
    if not E.soundReady then Sound.load(); E.soundReady = true end
    if id then Sound.playMusic(id) else Sound.stopMusic() end
    E.preview = id
end

-- Siguiente versión (dirección...) de la entidad seleccionada o, si no hay,
-- de lo elegido en la paleta
function Editor.cycleVariant()
    local e = E.selected
    local vs = e and ET.variantsOf(e.type)
    if vs then
        for i, n in ipairs(vs) do
            if n == e.type then pushUndo(); e.type = vs[i % #vs + 1]; markDirty(); break end
        end
        return
    end
    vs = ET.variantsOf(E.palette.entities)
    if vs then
        for i, n in ipairs(vs) do
            if n == E.palette.entities then
                E.palette.entities = vs[i % #vs + 1]
                E.variantPick = E.variantPick or {}
                E.variantPick[ET.get(E.palette.entities).variant.group] = E.palette.entities
                break
            end
        end
    end
end

-- ── Bucle del editor ──────────────────────────────────────────────────────────
function Editor.load(args, levelArg)
    ui.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    love.keyboard.setKeyRepeat(true)
    love.window.setTitle('FlappyMonster — Editor de niveles')
    local dw, dh = love.window.getDesktopDimensions()
    love.window.setMode(math.min(1600, dw - 80), math.min(920, dh - 80),
                        { resizable = true, vsync = 1, minwidth = 1100, minheight = 640 })
    E.gameArgs = args
    E.mode = 'edit'
    E.layer = 'tiles'
    E.tool = { tiles='brush', water='brush', spikes='brush', entities='select', deco='place', special='spawn', mini='brush' }
    E.selZone = nil
    E.selDeco = nil
    E.palette = { tiles = TILE_SOLID, entities = ET.list[1] and ET.list[1].name, deco = DT.list[1] and DT.list[1].name,
                  mini = SubTiles.KINDS[1] }
    E.miniSolid = true
    E.spikeDir = 0
    E.search, E.variantPick, E.rightTab = {}, {}, 'sel'
    E.grid, E.showRoutes = true, true
    E.msgT = 0
    local path = levelArg or 'assets/levels/nivel01.json'
    local m, err = Model.load(path)
    if m then setModel(m, path) else setModel(Model.new(30, 15, 'nuevo'), nil); msg(err, 'error') end
end

function Editor.update(dt)
    if E.levelDirty then rebuild() end
    if E.soundReady and Sound then Sound.update(dt) end       -- (música de prueba: intro → bucle)
    if E.level then E.level:update(dt); E.level:updateFoliage(dt) end
    if E.msgT > 0 then E.msgT = E.msgT - dt end

    -- Desplazamiento con teclado
    if not ui.hasFocus() and not E.modal then
        local sp = 700 * dt / E.zoom
        if love.keyboard.isDown('left')  then E.camX = E.camX - sp end
        if love.keyboard.isDown('right') then E.camX = E.camX + sp end
        if love.keyboard.isDown('up')    then E.camY = E.camY - sp end
        if love.keyboard.isDown('down')  then E.camY = E.camY + sp end
    end
    -- Arrastre del lienzo / pintura
    if E.pan then
        local mx, my = love.mouse.getPosition()
        E.camX = E.pan.camX - (mx - E.pan.mx) / E.zoom
        E.camY = E.pan.camY - (my - E.pan.my) / E.zoom
    elseif E.stroke then
        canvasDrag()
    end
end

function Editor.draw()
    ui.beginFrame()
    love.graphics.clear(th.bg)
    drawCanvas()
    drawTopBar()
    drawLeftPanel()
    drawRightPanel()
    drawStatus()
    drawModal()
    ui.drawTooltip()
    E.uiConsumed = ui.state.consumed
    ui.endFrame()
end

local function overCanvas(x, y)
    local cx, cy, cw, ch = canvasRect()
    return x >= cx and y >= cy and x < cx + cw and y < cy + ch and not E.modal
end

function Editor.mousepressed(x, y, b)
    ui.mousepressed(b)
    if not overCanvas(x, y) then return end
    if b == 3 or (b == 1 and love.keyboard.isDown('space')) then
        E.pan = { mx = x, my = y, camX = E.camX, camY = E.camY }
    elseif b == 1 and E.rightTab == 'level' and love.keyboard.isDown('lalt', 'ralt') then
        -- Alt + clic (pestaña Nivel): la línea de superficie del fondo pasa a esa fila
        local _, wy = screenToWorld(x, y)
        local row = math.max(1, math.min(E.model.height, math.floor(wy / TILE_PX + 0.5) + 1))
        pushUndo(); E.model.surfaceRow = row; markDirty()
        msg('Línea de superficie en la fila ' .. row)
    elseif b == 1 or b == 2 then
        canvasPress(b)
    end
end

function Editor.mousereleased(x, y, b)
    ui.mousereleased(b)
    if E.pan and (b == 3 or b == 1) then E.pan = nil end
    if E.stroke and b == E.stroke.button then canvasRelease() end
end

function Editor.wheelmoved(dx, dy)
    local mx, my = love.mouse.getPosition()
    if overCanvas(mx, my) then
        local wx, wy = screenToWorld(mx, my)
        E.zoom = math.max(0.25, math.min(3, E.zoom * (dy > 0 and 1.15 or 1 / 1.15)))
        local cx, cy = canvasRect()
        E.camX = wx - (mx - cx) / E.zoom
        E.camY = wy - (my - cy) / E.zoom
    else
        ui.wheelmoved(dy)
    end
end

function Editor.textinput(t) ui.textinput(t) end

function Editor.keypressed(k)
    ui.keypressed(k)
    if E.modal then
        if k == 'escape' then E.modal = nil; ui.state.focus = nil end
        return
    end
    if ui.hasFocus() then return end
    local ctrl  = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    local shift = love.keyboard.isDown('lshift', 'rshift')
    if ctrl then
        if k == 'z' then if shift then redo() else undo() end
        elseif k == 'y' then redo()
        elseif k == 's' then if shift then E.modal = { kind = 'saveas', name = E.model.name } else save() end
        elseif k == 'o' then guardUnsaved(function() E.modal = { kind = 'open', files = listLevels() } end)
        elseif k == 'n' then guardUnsaved(function() E.modal = { kind = 'new', w = 30, h = 15 } end)
        elseif k == 'd' then Editor.duplicate() end
        return
    end
    local n = tonumber(k)
    if n and LAYERS[n] then E.layer = LAYERS[n].id; return end
    for _, tn in ipairs(layerDef(E.layer).tools) do
        if TOOLS[tn].key == k then E.tool[E.layer] = tn; return end
    end
    if k == 'g' then E.grid = not E.grid
    elseif k == 'h' then E.showRoutes = not E.showRoutes
    elseif k == 'x' then
        if E.layer == 'entities' then Editor.cycleVariant() else E.spikeDir = (E.spikeDir + 1) % 4 end
    elseif k == 'f1' then E.modal = { kind = 'help' }
    elseif k == 'delete' or k == 'backspace' then Editor.deleteSelected()
    elseif k == 'escape' then E.selected = nil; E.selDeco = nil
    elseif k == 'f5' then startPlay()
    elseif k == '=' or k == 'kp+' then E.zoom = math.min(3, E.zoom * 1.25)
    elseif k == '-' or k == 'kp-' then E.zoom = math.max(0.25, E.zoom / 1.25)
    elseif k == '0' then E.zoom = 1 end
end

-- Estado interno (para pruebas automatizadas y depuración)
function Editor.state() return E end

-- ── Instalación: toma los callbacks de LÖVE (el juego queda para "Probar") ──
function Editor.install(levelArg)
    for _, name in ipairs({ 'load', 'update', 'draw', 'keypressed', 'keyreleased', 'textinput',
                            'mousepressed', 'mousereleased', 'mousemoved', 'wheelmoved', 'resize',
                            'focus', 'joystickadded', 'joystickpressed', 'touchpressed', 'quit' }) do
        G[name] = love[name]
    end
    local function route(name, editorFn)
        love[name] = function(...)
            if E.mode == 'play' then
                if G[name] then return G[name](...) end
            elseif editorFn then
                return editorFn(...)
            end
        end
    end
    love.load = function(args) Editor.load(args, levelArg) end
    route('update', Editor.update)
    route('draw', Editor.draw)
    route('textinput', Editor.textinput)
    route('mousepressed', Editor.mousepressed)
    route('mousereleased', Editor.mousereleased)
    route('wheelmoved', Editor.wheelmoved)
    route('mousemoved', nil)
    route('resize', nil)
    route('focus', nil)
    route('joystickadded', nil)
    route('joystickpressed', nil)
    route('touchpressed', nil)
    love.keypressed = function(k, ...)
        if E.mode == 'play' then
            if k == 'f10' then return stopPlay() end
            return G.keypressed and G.keypressed(k, ...)
        end
        return Editor.keypressed(k)
    end
    -- En modo prueba: aviso para volver
    local playDraw = love.draw
    love.draw = function()
        playDraw()
        if E.mode == 'play' then
            love.graphics.origin()
            love.graphics.setFont(ui.font)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle('fill', 8, 8, 250, 26, 4, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print('PROBANDO — F10: volver al editor', 16, 14)
        end
    end
    love.quit = function()
        if E.mode == 'edit' and E.unsaved and not E.quitConfirmed then
            E.quitConfirmed = true
            msg('Hay cambios sin guardar. Cierra otra vez para salir sin guardar.', 'warn')
            return true
        end
    end
end

-- ── Partes (el resto de Editor.lua, por sistemas) ────────────────────
P.TT = TT; P.ET = ET; P.Codec = Codec; P.th = th; P.Editor = Editor
P.LEFT = LEFT; P.STATUS = STATUS; P.RIGHT = RIGHT; P.TOP = TOP; P.LEVELS_DIR = LEVELS_DIR
P.T = T; P.LAYERS = LAYERS; P.TOOLS = TOOLS; P.DIRS = DIRS; P.DIR_ARROW = DIR_ARROW
P.layerDef = layerDef; P.msg = msg; P.canvasRect = canvasRect; P.screenToWorld = screenToWorld; P.worldToCell = worldToCell
P.lineCells = lineCells; P.img = img; P.drawEntThumb = drawEntThumb; P.drawTileThumb = drawTileThumb; P.drawDecoThumb = drawDecoThumb
P.markDirty = markDirty; P.pushUndo = pushUndo; P.undo = undo; P.redo = redo; P.setModel = setModel
P.listLevels = listLevels; P.guardUnsaved = guardUnsaved; P.save = save; P.startPlay = startPlay
require('src/editor/EditorCanvas')(E, P)
require('src/editor/EditorPalette')(E, P)
require('src/editor/EditorInspector')(E, P)
require('src/editor/EditorDialogs')(E, P)
canvasPress, canvasDrag, canvasRelease, drawCanvas, drawTopBar = P.canvasPress, P.canvasDrag, P.canvasRelease, P.drawCanvas, P.drawTopBar
drawLeftPanel, drawRightPanel, drawStatus, drawModal = P.drawLeftPanel, P.drawRightPanel, P.drawStatus, P.drawModal

return Editor
