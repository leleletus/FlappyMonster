-- src/editor/Editor.lua
-- Editor de niveles de FlappyMonster.  Uso:  love . --editor [assets/levels/x.json]
--
-- Corre dentro del propio juego: usa los mismos catálogos (src/world/Tiles.lua,
-- src/world/Entities.lua), el mismo dibujo y los mismos assets, así que todo
-- tile, material o entidad nuevo aparece aquí solo. "Probar" (F5) juega el
-- nivel en el mismo proceso y F10 vuelve al editor.

local ui       = require 'src/editor/ui'
local Model    = require 'src/editor/EditorModel'
local Tiles    = require 'src/world/Tiles'
local Entities = require 'src/world/Entities'
local Level    = require 'src/world/Level'
local DT       = require('src/world/Decorations').types
local BossZones = require 'src/world/BossZones'
local AutoScroll = require 'src/world/AutoScroll'
local Modes     = require 'src/world/Modes'
local Music     = require 'src/Music'

local Codec, TT, ET, Props = Tiles.codec, Tiles.types, Entities.types, Entities.props
local th = ui.theme

local Editor = {}
local G = {}                 -- callbacks originales del juego (modo prueba)
local E = {}                 -- estado del editor

local TOP, LEFT, RIGHT, STATUS = 46, 292, 330, 26
local LEVELS_DIR = 'assets/levels'
local PLAYTEST   = 'editor_playtest.json'
local T = function() return TILE_PX end

-- ── Capas y herramientas ──────────────────────────────────────────────────────
-- Una capa = qué se edita; cada una tiene sus herramientas (tecla entre
-- paréntesis) y una descripción que el panel enseña como ayuda.
local LAYERS = {
    { id='tiles',    label='Bloques',    tools={ 'brush', 'rect', 'line', 'fill', 'pick', 'erase' },
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
}
local TOOLS = {
    brush  = { label='Pincel',      key='b', help='Pinta casilla a casilla (arrastra). Clic derecho borra.' },
    rect   = { label='Rectángulo',  key='r', help='Arrastra para rellenar un rectángulo.' },
    line   = { label='Línea',       key='l', help='Arrastra para trazar una línea recta.' },
    fill   = { label='Relleno',     key='f', help='Rellena la zona contigua del mismo tipo.' },
    erase  = { label='Borrar',      key='e', help='Borra lo de esta capa (también con clic derecho).' },
    pick   = { label='Cuentagotas', key='i', help='Copia a la paleta el bloque que hay bajo el cursor.' },
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

-- ── Acciones sobre el lienzo ──────────────────────────────────────────────────
local function pal() return E.palette[E.layer] end

local function applyCell(c, r, erase)
    local m = E.model
    if not m:inBounds(c, r) then return false end
    local L = E.layer
    if L == 'tiles' then
        return m:setId(c, r, erase and TILE_EMPTY or pal())
    elseif L == 'water' then
        return m:setWater(c, r, not erase)
    end
    return false
end

local function applySpike(c, r, sub, erase)
    if not E.model:inBounds(c, r) then return false end
    return E.model:setSpike(c, r, sub, not erase, E.spikeDir)
end

local function applyFill(c, r, erase)
    local m = E.model
    if E.layer == 'tiles' then
        local id = erase and TILE_EMPTY or pal()
        return m:flood(c, r, function(raw) return Codec.id(raw) end,
                       function(cc, rr) return m:setId(cc, rr, id) end) > 0
    elseif E.layer == 'water' then
        return m:flood(c, r, function(raw) return Codec.id(raw) * 2 + (Codec.isWaterlogged(raw) and 1 or 0) end,
                       function(cc, rr) return m:setWater(cc, rr, not erase) end) > 0
    end
end

local function rectCells(a, b)
    local out = {}
    for r = math.min(a[2], b[2]), math.max(a[2], b[2]) do
        for c = math.min(a[1], b[1]), math.max(a[1], b[1]) do out[#out+1] = { c, r } end
    end
    return out
end

-- Asas editables (rutas, puntos) de una entidad según su esquema
local function handlesOf(e)
    local hs = {}
    local t = ET.get(e.type)
    if not t then return hs end
    for _, p in ipairs(t.schema) do
        local v = e.props[p.key]
        if p.kind == 'patrol' and v and (not p.showIf or p.showIf(e.props)) then
            hs[#hs+1] = { key = p.key, side = 'left',  col = v.left,  row = e.row }
            hs[#hs+1] = { key = p.key, side = 'right', col = v.right, row = e.row }
        elseif p.kind == 'point' and v then
            hs[#hs+1] = { key = p.key, side = 'point', col = v.col, row = v.row }
        elseif p.kind == 'points' and v then
            for i, q in ipairs(v) do
                hs[#hs+1] = { key = p.key, side = 'pts', idx = i, col = q.col, row = q.row, list = v }
            end
        end
    end
    return hs
end

local function canvasPress(button)
    local mx, my = love.mouse.getPosition()
    local wx, wy = screenToWorld(mx, my)
    local c, r, sub = worldToCell(wx, wy)
    local m, L, tool = E.model, E.layer, E.tool[E.layer]
    local erase = (button == 2) or tool == 'erase'
    E.stroke = { button = button, start = { c, r }, last = { c, r }, changed = false }
    pushUndo()
    local s = E.stroke

    if L == 'tiles' or L == 'water' then
        if tool == 'pick' and button == 1 then
            local raw = m:get(c, r)
            if raw then E.palette.tiles = Codec.id(raw); E.tool.tiles = 'brush'; msg('Bloque copiado: ' .. TT.get(Codec.id(raw)).label) end
        elseif tool == 'fill' then
            s.changed = applyFill(c, r, erase)
        elseif tool == 'rect' or tool == 'line' then
            s.shape = tool; s.erase = erase
        else
            s.paint = true; s.erase = erase
            s.changed = applyCell(c, r, erase)
        end
    elseif L == 'spikes' then
        s.spikes = true; s.erase = erase; s.lastSub = sub
        s.changed = applySpike(c, r, sub, erase)
    elseif L == 'entities' then
        -- ¿Asa de la entidad seleccionada?
        if E.selected and tool ~= 'erase' then
            for _, h in ipairs(handlesOf(E.selected)) do
                if h.col == c and h.row == r then s.handle = h; return end
            end
        end
        local pdef = ET.get(E.palette.entities)
        local e, idx = m:entityAt(c, r, sub)
        if erase then
            if e then table.remove(m.entities, idx); if E.selected == e then E.selected = nil end; s.changed = true end
        elseif e then
            E.selected = e; s.move = { e = e, dc = 0 }
        elseif tool == 'place' then
            if m:inBounds(c, r) then
                local n, why = m:addEntity(E.palette.entities, c, r, pdef and pdef.placement == 'sub' and sub or nil)
                if n then
                    E.selected = n; s.changed = true
                    if pdef and pdef.paint then
                        s.paintEntity = pdef          -- se siguen colocando al arrastrar
                    else
                        s.move = { e = E.selected }
                    end
                else
                    msg(why or 'No se puede colocar ahí', 'warn')
                end
            end
        else
            E.selected = nil
        end
    elseif L == 'deco' then
        local ft = DT.get(E.palette.deco)
        local useSub = ft and ft.placement == 'sub'
        if erase then
            local o, idx = m:findObject(m.foliage, c, r)
            if o then table.remove(m.foliage, idx); if E.selDeco == o then E.selDeco = nil end; s.changed = true end
        elseif tool == 'select' then
            local o = m:findObject(m.foliage, c, r, sub) or m:findObject(m.foliage, c, r)
            E.selDeco = o
            if o then s.moveDeco = o end
        elseif ft and m:inBounds(c, r) and not m:findObject(m.foliage, c, r, useSub and sub or nil) then
            local n = DT.normalize({ type = ft.name, col = c, row = r, sub = useSub and sub or nil })
            m.foliage[#m.foliage+1] = n
            E.selDeco = n
            s.changed = true
        end
    elseif L == 'special' then
        if tool == 'spawn' and not erase then
            if m:inBounds(c, r) then m.playerStart = { c, r }; s.changed = true end
        elseif tool == 'boss' and not erase then
            -- Esquina inferior derecha de la zona elegida: cambiar tamaño.
            -- Dentro de una zona: seleccionar y moverla. Fuera: crear una.
            local sz = E.selZone
            if sz and c == sz.col + sz.w - 1 and r == sz.row + sz.h - 1 then
                s.zoneResize = sz
            else
                local z = m:zoneAt(c, r)
                if z then
                    E.selZone = z
                    s.zoneMove = { z = z, dc = c - z.col, dr = r - z.row }
                elseif m:inBounds(c, r) then
                    s.zoneNew = true
                    E.selZone = nil
                end
            end
        elseif tool == 'vent' and not erase then
            -- Clic en un vent: seleccionarlo (para su límite de altura); en una
            -- subcelda libre: colocar uno ahí (en el centro de esa subcelda)
            local o = m:findObject(m.vents, c, r, sub)
            if o then
                E.selVent = o
            elseif m:inBounds(c, r) then
                local v = { col = c, row = r, sub = sub }
                m.vents[#m.vents+1] = v
                E.selVent = v
                s.changed = true
            end
        elseif tool == 'boss' and erase then
            local z, idx = m:zoneAt(c, r)
            if z then
                table.remove(m.bossZones, idx); s.changed = true
                if E.selZone == z then E.selZone = nil end
            end
        else
            local o, idx = m:findObject(m.vents, c, r, sub)
            if not o then o, idx = m:findObject(m.vents, c, r) end
            if o then
                table.remove(m.vents, idx); s.changed = true
                if E.selVent == o then E.selVent = nil end
            else
                local z, zi = m:zoneAt(c, r)
                if z and tool == 'erase' then
                    table.remove(m.bossZones, zi); s.changed = true
                    if E.selZone == z then E.selZone = nil end
                end
            end
        end
    end
    if s.changed then markDirty() end
end

local function canvasDrag()
    local s = E.stroke
    if not s then return end
    local wx, wy = screenToWorld(love.mouse.getPosition())
    local c, r, sub = worldToCell(wx, wy)
    if s.paint then
        for _, cell in ipairs(lineCells(s.last[1], s.last[2], c, r)) do
            if applyCell(cell[1], cell[2], s.erase) then s.changed = true; markDirty() end
        end
    elseif s.spikes then
        if c ~= s.last[1] or r ~= s.last[2] or sub ~= s.lastSub then
            if applySpike(c, r, sub, s.erase) then s.changed = true; markDirty() end
            s.lastSub = sub
        end
    elseif s.handle and E.selected then
        local h, p = s.handle, E.selected.props[s.handle.key]
        if h.side == 'left'  and c ~= p.left  then p.left  = math.min(c, p.right); s.changed = true; markDirty() end
        if h.side == 'right' and c ~= p.right then p.right = math.max(c, p.left);  s.changed = true; markDirty() end
        if h.side == 'point' and (c ~= p.col or r ~= p.row) then p.col, p.row = c, r; s.changed = true; markDirty() end
        if h.side == 'pts' then
            local q = p[h.idx]
            if q and (c ~= q.col or r ~= q.row) then q.col, q.row = c, r; h.row = r; s.changed = true; markDirty() end
        end
        h.col = (h.side == 'left' and p.left) or (h.side == 'right' and p.right) or c
    elseif s.paintEntity and E.model:inBounds(c, r) then
        -- Pintar entidades (p. ej. pinchos de lluvia a lo largo de un techo)
        local pd = s.paintEntity
        local psub = pd.placement == 'sub' and sub or nil
        if not E.model:entityAt(c, r, psub) then
            local n = E.model:addEntity(pd.name, c, r, psub)
            if n then s.changed = true; markDirty() end
        end
    elseif s.zoneMove then
        local z, m = s.zoneMove.z, E.model
        local nc = math.max(1, math.min(m.width - z.w + 1, c - s.zoneMove.dc))
        local nr = math.max(1, math.min(m.height - z.h + 1, r - s.zoneMove.dr))
        if nc ~= z.col or nr ~= z.row then z.col, z.row = nc, nr; s.changed = true; markDirty() end
    elseif s.zoneResize then
        local z, m = s.zoneResize, E.model
        local nw = math.max(4, math.min(m.width - z.col + 1, c - z.col + 1))
        local nh = math.max(3, math.min(m.height - z.row + 1, r - z.row + 1))
        if nw ~= z.w or nh ~= z.h then z.w, z.h = nw, nh; s.changed = true; markDirty() end
    elseif s.moveDeco and E.model:inBounds(c, r) then
        local d = s.moveDeco
        local nsub = d.sub and sub or nil
        if c ~= d.col or r ~= d.row or nsub ~= d.sub then
            d.col, d.row, d.sub = c, r, nsub
            s.changed = true; markDirty()
        end
    elseif s.move and E.model:inBounds(c, r) then
        local e = s.move.e
        local nsub = e.sub and sub or nil
        local edef = ET.get(e.type)
        local okPos = not (edef and edef.ceilingOnly) or E.model:ceilingAbove(c, r, nsub)
        if okPos and (c ~= e.col or r ~= e.row or nsub ~= e.sub) then
            -- La ruta se desplaza con la entidad
            local dc = c - e.col
            if e.props.patrol then e.props.patrol.left = e.props.patrol.left + dc; e.props.patrol.right = e.props.patrol.right + dc end
            -- ...y también sus rutas por puntos (waypoints)
            local dr = r - e.row
            local et = ET.get(e.type)
            for _, pp in ipairs(et and et.schema or {}) do
                if pp.kind == 'points' and type(e.props[pp.key]) == 'table' then
                    for _, q in ipairs(e.props[pp.key]) do q.col, q.row = q.col + dc, q.row + dr end
                end
                if pp.kind == 'point' and type(e.props[pp.key]) == 'table' then
                    local q = e.props[pp.key]
                    q.col, q.row = q.col + dc, q.row + dr
                end
            end
            e.col, e.row, e.sub = c, r, nsub
            s.changed = true; markDirty()
        end
    end
    s.last = { c, r }
end

local function canvasRelease()
    local s = E.stroke
    if not s then return end
    if s.shape then
        local wx, wy = screenToWorld(love.mouse.getPosition())
        local c, r = worldToCell(wx, wy)
        local cells = (s.shape == 'rect') and rectCells(s.start, { c, r })
                      or lineCells(s.start[1], s.start[2], c, r)
        for _, cell in ipairs(cells) do
            if applyCell(cell[1], cell[2], s.erase) then s.changed = true end
        end
        if s.changed then markDirty() end
    end
    if s.zoneNew then
        local wx, wy = screenToWorld(love.mouse.getPosition())
        local c, r = worldToCell(wx, wy)
        local m = E.model
        c = math.max(1, math.min(m.width, c)); r = math.max(1, math.min(m.height, r))
        local z
        if math.abs(c - s.start[1]) < 3 and math.abs(r - s.start[2]) < 2 then
            -- Clic: una pantalla de tamaño, empezando en la celda
            z = m:addZone(s.start[1], s.start[2], s.start[1] + BossZones.DEFAULT_W - 1, s.start[2] + BossZones.DEFAULT_H - 1)
        else
            z = m:addZone(s.start[1], s.start[2], c, r)
        end
        E.selZone = z
        s.changed = true; markDirty()
        msg('Zona de jefe #' .. z.id .. ' creada. Coloca un jefe dentro (capa Entidades).')
    end
    if not s.changed then table.remove(E.undo) end    -- el clic no cambió nada
    E.stroke = nil
end

-- ── Dibujo del lienzo ─────────────────────────────────────────────────────────
local function drawCanvas()
    local cx, cy, cw, ch = canvasRect()
    local m, lv, t, z = E.model, E.level, T(), E.zoom
    ui.rect(cx, cy, cw, ch, th.canvas, 0)
    love.graphics.setScissor(cx, cy, cw, ch)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(z)

    local camX, camY = E.camX, E.camY
    local vw, vh = cw / z, ch / z
    EDITOR_VIEW = true         -- las entidades invisibles en la partida se dibujan aquí

    -- Fondo del mapa
    love.graphics.setColor(0.36, 0.48, 0.62, 1)
    love.graphics.rectangle('fill', -camX, -camY, m.width * t, m.height * t)

    -- Nivel (los culls de Level usan WINDOW_W/H: se ajustan a la vista)
    local ww, wh = WINDOW_W, WINDOW_H
    WINDOW_W, WINDOW_H = vw, vh
    if lv then
        lv:render(camX, camY)
        -- Líquidos: tinte por material
        local c0, c1 = math.max(1, math.floor(camX / t) + 1), math.min(m.width, math.floor((camX + vw) / t) + 1)
        local r0, r1 = math.max(1, math.floor(camY / t) + 1), math.min(m.height, math.floor((camY + vh) / t) + 1)
        for r = r0, r1 do for c = c0, c1 do
            local liq = lv:liquidOfCell(c, r)
            if liq and liq.tint then
                love.graphics.setColor(liq.tint)
                love.graphics.rectangle('fill', (c-1)*t - camX, (r-1)*t - camY, t, t)
            end
        end end
        lv:renderVents(camX, camY)
        lv:renderFoliageBack(camX, camY)
        -- Bloques trampa: en el editor se marcan (en el juego son idénticos al original)
        love.graphics.setFont(ui.fontSm)
        for r = r0, r1 do for c = c0, c1 do
            local d = TT.get(Codec.id(m:get(c, r)))
            if d.fake then
                local x, y = (c-1)*t - camX, (r-1)*t - camY
                love.graphics.setColor(1, 0.3, 0.8, 0.9)
                love.graphics.setLineWidth(2 / z)
                for k = 0, 3 do   -- borde discontinuo
                    love.graphics.line(x + k*t/4, y + 1, x + k*t/4 + t/8, y + 1)
                    love.graphics.line(x + k*t/4, y + t - 1, x + k*t/4 + t/8, y + t - 1)
                end
                love.graphics.print('?', x + t/2 - 4, y + t/2 - 8)
            end
        end end
        -- Límite de altura de las burbujas de cada vent
        for vi, vd in ipairs(m.vents) do
            local v = lv.vents[vi]
            if v and (tonumber(vd.limit) or 0) > 0 then
                local y = v.ceilingY - camY
                love.graphics.setColor(0.4, 0.9, 1, 0.9)
                love.graphics.setLineWidth(2 / z)
                for xx = v.x - camX - 30, v.x - camX + 24, 12 do love.graphics.line(xx, y, xx + 6, y) end
                love.graphics.print('límite', v.x - camX + 30, y - 8)
            end
            if vd == E.selVent then
                love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 1)
                love.graphics.circle('line', v and (v.x - camX) or 0, v and (v.y - camY) or 0, t * 0.4)
            end
        end
    end
    Editor.drawZones(camX, camY, t, z)
    Editor.drawAutoScroll(camX, camY, t, z)
    for _, inst in pairs(E.instances or {}) do
        -- Si cae desde donde se colocó, se marca el recorrido hasta donde aterriza
        if inst._spawnY and math.abs(inst.y - inst._spawnY) > t * 0.5 then
            love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.7)
            love.graphics.setLineWidth(2 / z)
            local x = inst.x - camX
            local y0, y1 = inst._spawnY - camY, inst.y - camY
            local dir = y1 > y0 and 1 or -1
            for yy = y0, y1 - dir * 10, dir * 12 do love.graphics.line(x, yy, x, yy + dir * 6) end
            love.graphics.circle('line', x, y0, 6)
        end
        inst:render(camX, camY)
    end
    if lv then lv:renderFoliage(camX, camY) end
    WINDOW_W, WINDOW_H = ww, wh

    -- Punto de inicio
    local ps = m.playerStart
    local pimg = img('assets/images/player/monstrito3.png')
    if pimg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pimg, (ps[1]-0.5)*t - camX, (ps[2]-0.5)*t - camY, 0, PLAYER_SCALE, PLAYER_SCALE,
                           pimg:getWidth()/2, pimg:getHeight()/2)
    end
    love.graphics.setColor(th.ok[1], th.ok[2], th.ok[3], 0.9)
    love.graphics.setLineWidth(2 / z)
    love.graphics.rectangle('line', (ps[1]-1)*t - camX, (ps[2]-1)*t - camY, t, t)

    -- Rejilla
    if E.grid then
        local c0 = math.max(0, math.floor(camX / t)); local c1 = math.min(m.width, math.ceil((camX + vw) / t))
        local r0 = math.max(0, math.floor(camY / t)); local r1 = math.min(m.height, math.ceil((camY + vh) / t))
        love.graphics.setLineWidth(1 / z)
        for c = c0, c1 do
            love.graphics.setColor(1, 1, 1, c % 5 == 0 and 0.16 or 0.07)
            love.graphics.line(c*t - camX, r0*t - camY, c*t - camX, r1*t - camY)
        end
        for r = r0, r1 do
            love.graphics.setColor(1, 1, 1, r % 5 == 0 and 0.16 or 0.07)
            love.graphics.line(c0*t - camX, r*t - camY, c1*t - camX, r*t - camY)
        end
    end

    -- Rutas de entidades (todas tenues; la seleccionada destacada y editable)
    love.graphics.setLineWidth(3 / z)
    for i, e in ipairs(m.entities) do
        local sel = (e == E.selected)
        if E.showRoutes or sel then
            for _, h in ipairs(handlesOf(e)) do
                local a = sel and 1 or 0.35
                if h.side == 'left' then
                    local p = e.props[h.key]
                    local y = (e.row - 0.5) * t - camY
                    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.8 * a)
                    love.graphics.line((p.left - 0.5) * t - camX, y, (p.right - 0.5) * t - camX, y)
                end
                if h.side == 'pts' then
                    -- Ruta por puntos: línea hacia el siguiente (y cierre al primero)
                    local nq = h.list[h.idx % #h.list + 1]
                    love.graphics.setColor(1, 0.55, 0.2, 0.8 * a)
                    love.graphics.line((h.col - 0.5) * t - camX, (h.row - 0.5) * t - camY,
                                       (nq.col - 0.5) * t - camX, (nq.row - 0.5) * t - camY)
                end
                local hx, hy = (h.col - 1) * t - camX + t * 0.2, (h.row - 1) * t - camY + t * 0.2
                love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35 * a)
                love.graphics.rectangle('fill', hx, hy, t * 0.6, t * 0.6, 6, 6)
                love.graphics.setColor(1, 1, 1, 0.9 * a)
                love.graphics.rectangle('line', hx, hy, t * 0.6, t * 0.6, 6, 6)
                if h.idx then
                    love.graphics.setFont(ui.fontSm)
                    love.graphics.print(tostring(h.idx), hx + t * 0.22, hy + t * 0.18)
                end
            end
        end
        if sel then
            -- Ayuda visual propia del tipo (p. ej. el alcance del mortero)
            local et = ET.get(e.type)
            if et and et.class.drawEditorOverlay then
                et.class.drawEditorOverlay(e.props, (e.col - 0.5) * t - camX, (e.row - 0.5) * t - camY, z,
                                           { entities = m.entities, t = t, camX = camX, camY = camY })
            end
            love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
            if e.sub then
                local h = t / 2
                love.graphics.rectangle('line', (e.col-1)*t + ((e.sub-1) % 2) * h - camX + 1,
                                        (e.row-1)*t + math.floor((e.sub-1) / 2) * h - camY + 1, h - 2, h - 2, 3, 3)
            else
                love.graphics.rectangle('line', (e.col-1)*t - camX + 2, (e.row-1)*t - camY + 2, t - 4, t - 4, 6, 6)
            end
        end
    end

    -- Decoración seleccionada
    local sd = E.selDeco
    if sd and E.layer == 'deco' then
        local h = sd.sub and t / 2 or t
        local ox = sd.sub and ((sd.sub - 1) % 2) * h or 0
        local oy = sd.sub and math.floor((sd.sub - 1) / 2) * h or 0
        love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
        love.graphics.setLineWidth(2 / z)
        love.graphics.rectangle('line', (sd.col-1)*t + ox - camX + 1, (sd.row-1)*t + oy - camY + 1, h - 2, h - 2, 4, 4)
    end

    -- Borde del mapa
    love.graphics.setLineWidth(2 / z)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.6)
    love.graphics.rectangle('line', -camX, -camY, m.width * t, m.height * t)

    -- Vista previa bajo el cursor
    local mx, my = love.mouse.getPosition()
    if ui.inside(cx, cy, cw, ch) and not E.modal then
        local wx, wy = screenToWorld(mx, my)
        local c, r, sub = worldToCell(wx, wy)
        local tool = E.tool[E.layer]
        local s = E.stroke
        love.graphics.setLineWidth(2 / z)
        if s and s.shape then
            local cells = (s.shape == 'rect') and rectCells(s.start, { c, r }) or lineCells(s.start[1], s.start[2], c, r)
            love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
            for _, cell in ipairs(cells) do love.graphics.rectangle('fill', (cell[1]-1)*t - camX, (cell[2]-1)*t - camY, t, t) end
        elseif E.layer == 'tiles' and (tool == 'brush' or tool == 'rect' or tool == 'line' or tool == 'fill') then
            drawTileThumb(TT.get(E.palette.tiles), (c-1)*t - camX, (r-1)*t - camY, t)
        end
        local subLayer = E.layer == 'spikes' or (E.layer == 'special' and tool == 'vent')
        if E.layer == 'entities' and tool == 'place' then
            local et = ET.get(E.palette.entities)
            if et and et.placement == 'sub' then subLayer = true end
        end
        if E.layer == 'deco' then
            local ft = DT.get(E.palette.deco)
            if E.tool.deco ~= 'erase' and ft and ft.placement == 'sub' then subLayer = true end
        end
        love.graphics.setColor(1, 1, 1, 0.9)
        if subLayer then
            local h = t / 2
            local sx, sy = (c-1)*t + ((sub-1) % 2) * h - camX, (r-1)*t + math.floor((sub-1) / 2) * h - camY
            love.graphics.rectangle('line', sx, sy, h, h)
            if E.layer == 'spikes' then ui.text(DIR_ARROW[E.spikeDir], sx, sy + h/2 - 8, th.warn, ui.fontLg, h, 'center') end
        else
            love.graphics.rectangle('line', (c-1)*t - camX, (r-1)*t - camY, t, t)
        end
        E.hover = { c = c, r = r, sub = sub }
    else
        E.hover = nil
    end

    love.graphics.setLineWidth(1)
    love.graphics.pop()
    love.graphics.setScissor()
    EDITOR_VIEW = false
end

-- ── Paneles ───────────────────────────────────────────────────────────────────
local sectionTitle = ui.caption

-- Separador vertical entre grupos de botones de la barra superior
local function barSep(x)
    ui.rect(x, 12, 1, 22, th.border, 0)
    return x + 9
end

local function drawTopBar()
    local w = love.graphics.getWidth()
    ui.rect(0, 0, w, TOP, th.panel, 0)
    ui.rect(0, TOP - 1, w, 1, th.border, 0)
    local x = 8
    local function btn(label, bw, fn, opts)
        if ui.button(label, x, 8, bw, 30, opts) then fn() end
        x = x + bw + 4
    end
    -- Archivo
    btn('Nuevo', 62, function() guardUnsaved(function() E.modal = { kind = 'new', w = 30, h = 15 } end) end, { tooltip = 'Nivel nuevo (Ctrl+N)' })
    btn('Abrir', 62, function() guardUnsaved(function() E.modal = { kind = 'open', files = listLevels() } end) end, { tooltip = 'Abrir un nivel (Ctrl+O)' })
    btn('Guardar', 74, function() save() end, { tooltip = 'Guardar (Ctrl+S)' })
    btn('Guardar como…', 116, function() E.modal = { kind = 'saveas', name = E.model.name } end, { tooltip = 'Guardar con otro nombre (Ctrl+Mayús+S)' })
    x = barSep(x + 4)
    -- Edición
    btn('Deshacer', 80, undo, { disabled = #E.undo == 0, tooltip = 'Ctrl+Z' })
    btn('Rehacer', 76, redo, { disabled = #E.redo == 0, tooltip = 'Ctrl+Y' })
    x = barSep(x + 4)
    -- Vista
    btn('Rejilla', 70, function() E.grid = not E.grid end, { active = E.grid, tooltip = 'Mostrar la rejilla (G)' })
    btn('Rutas', 62, function() E.showRoutes = not E.showRoutes end, { active = E.showRoutes, tooltip = 'Mostrar las rutas de todas las entidades (H)' })
    btn('−', 30, function() E.zoom = math.max(0.25, E.zoom / 1.25) end, { tooltip = 'Alejar (−)' })
    if ui.button(string.format('%d%%', math.floor(E.zoom * 100 + 0.5)), x, 8, 56, 30, { tooltip = 'Zoom al 100% (0)' }) then E.zoom = 1 end
    x = x + 60
    btn('+', 30, function() E.zoom = math.min(3, E.zoom * 1.25) end, { tooltip = 'Acercar (+)' })

    -- Nivel abierto (centro) y acciones de la derecha
    local right = w - 132 - 4 - 84
    local name = (E.model.name and E.model.name ~= '') and E.model.name or 'Sin nombre'
    local file = E.model.path and E.model.path:match('[^/]+$') or 'sin guardar'
    local title = name .. '  ·  ' .. file .. (E.unsaved and '  •' or '')
    ui.text(title, x + 14, 15, E.unsaved and th.warn or th.muted, ui.font, math.max(0, right - x - 24), 'center')
    if ui.button('Ayuda', right, 8, 80, 30, { tooltip = 'Atajos de teclado (F1)', hint = 'F1' }) then E.modal = { kind = 'help' } end
    if ui.button('Probar', w - 132, 8, 124, 30, { color = th.accentDk, hint = 'F5', tooltip = 'Juega este nivel. F10 vuelve al editor.' }) then startPlay() end
end

-- ── Paleta ────────────────────────────────────────────────────────────────────
-- Fichas de la capa actual, agrupadas por categoría (en el orden de cada
-- catálogo). Las variantes de un mismo objeto (direcciones...) son una ficha.
local function paletteItems(L)
    local items = {}
    if L == 'tiles' then
        for _, t in ipairs(TT.list) do
            items[#items+1] = { key = t.id, label = t.label, cat = t.category, ord = TT.categoryOrder(t.category), def = t,
                                tip = string.format('%s\nColisión: %s%s · Material: %s', t.label,
                                      ({ solid = 'sólida', oneway = 'solo desde arriba', none = 'ninguna' })[t.collision] or t.collision,
                                      t.dropThrough and ' (se baja agachado)' or '', t.mat.label) }
        end
    elseif L == 'entities' then
        local seen = {}
        for _, t in ipairs(ET.list) do
            local v = t.variant
            if not (v and seen[v.group]) then
                local it = { key = t.name, label = t.label, cat = t.category, ord = ET.categoryOrder(t.category), ent = t,
                             tip = t.label .. (t.description and ('\n' .. t.description) or '') }
                if v then
                    seen[v.group] = true
                    it.key, it.label, it.variants = 'variant:' .. v.group, v.groupLabel or t.label, ET.variants[v.group]
                    it.tip = it.label .. (t.description and ('\n' .. t.description) or '') .. '\n' .. (v.prop or 'Versión') .. ': elige debajo (X gira)'
                end
                items[#items+1] = it
            end
        end
    elseif L == 'deco' then
        for _, t in ipairs(DT.list) do
            items[#items+1] = { key = t.name, label = t.label, cat = t.category, ord = t.placement == 'sub' and 2 or 1, deco = t, tip = t.label }
        end
    end
    -- Búsqueda
    local q = (E.search[L] or ''):lower()
    if q ~= '' then
        local out = {}
        for _, it in ipairs(items) do
            if (it.label .. ' ' .. (it.cat or '')):lower():find(q, 1, true) then out[#out+1] = it end
        end
        items = out
    end
    -- Agrupar por categoría, en orden
    local cats, order = {}, {}
    for _, it in ipairs(items) do
        if not cats[it.cat] then cats[it.cat] = {}; order[#order+1] = it.cat end
        table.insert(cats[it.cat], it)
    end
    table.sort(order, function(a, b)
        local oa, ob = cats[a][1].ord or 99, cats[b][1].ord or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return cats, order
end

local function paletteSelected(L, it)
    if it.variants then
        for _, n in ipairs(it.variants) do if E.palette.entities == n then return true end end
        return false
    end
    return E.palette[L] == it.key
end

local function pickPalette(L, it)
    if it.variants then
        E.variantPick = E.variantPick or {}
        local g = ET.get(it.variants[1]).variant.group
        E.palette.entities = E.variantPick[g] or it.variants[1]
    else
        E.palette[L] = it.key
    end
    if L == 'entities' then E.tool.entities = 'place' end
    if L == 'deco' then E.tool.deco = 'place' end
    if L == 'tiles' and (E.tool.tiles == 'erase' or E.tool.tiles == 'pick') then E.tool.tiles = 'brush' end
end

-- Selector de variante del objeto elegido en la paleta (p. ej. dirección
-- del trampolín). Devuelve el nuevo y.
local function drawVariantPicker(x, y, w)
    local vs = ET.variantsOf(E.palette.entities)
    if not vs then return y end
    local cur = ET.get(E.palette.entities)
    ui.text((cur.variant.prop or 'Versión') .. '  (X gira)', x, y, th.muted, ui.fontSm); y = y + 16
    local bw = (w - (#vs - 1) * 4) / #vs
    for i, n in ipairs(vs) do
        local vt = ET.get(n)
        if ui.button(vt.variant.label, x + (i - 1) * (bw + 4), y, bw, 26, { active = n == E.palette.entities, font = ui.fontSm }) then
            E.palette.entities = n
            E.variantPick = E.variantPick or {}; E.variantPick[vt.variant.group] = n
            E.tool.entities = 'place'
        end
    end
    return y + 34
end

local function drawPalette(L, x, y, w, bottom)
    -- Buscador
    E.search = E.search or {}
    local q, qch = ui.textField('search_' .. L, E.search[L] or '', x, y, w, 30, 'Buscar…')
    if qch then E.search[L] = q end
    y = y + 34
    if L == 'entities' then y = drawVariantPicker(x, y, w) end

    local cats, order = paletteItems(L)
    local cell, gap, labelH = 80, 6, 26
    local cols = math.floor((w + gap) / (cell + gap))
    -- Alto del contenido (con las categorías plegadas o no)
    local contentH = 0
    for _, c in ipairs(order) do
        contentH = contentH + ui.SECTION_H + 6
        if ui.state.sections['pal_' .. L .. c] ~= false then
            contentH = contentH + math.ceil(#cats[c] / cols) * (cell + labelH + gap) + 4
        end
    end
    local areaH = bottom - y
    local yy = ui.beginScroll('pal_' .. L, x - 4, y, w + 8, areaH, contentH)
    if #order == 0 then ui.text('Nada coincide con la búsqueda.', x, yy + 4, th.muted, ui.fontSm) end
    for _, c in ipairs(order) do
        local catDef = (L == 'entities') and select(2, ET.categoryOrder(c)) or nil
        local hy = yy
        local open
        yy, open = ui.section('pal_' .. L .. c, c, x, yy, w, tostring(#cats[c]))
        if catDef and ui.inside(x, hy, w, ui.SECTION_H) then ui.tooltip(catDef.description) end
        if open then
            for i, it in ipairs(cats[c]) do
                local bx = x + ((i - 1) % cols) * (cell + gap)
                local by = yy + math.floor((i - 1) / cols) * (cell + labelH + gap)
                local sel = paletteSelected(L, it)
                local hov = ui.inside(bx, by, cell, cell + labelH)
                ui.rect(bx, by, cell, cell + labelH, sel and th.accentDk or (hov and th.hover or th.panel2), 6)
                if sel then ui.rect(bx, by, cell, cell + labelH, th.accent, 6, 'line') end
                local ix, iy, is = bx + 14, by + 6, cell - 28
                if it.def then
                    drawTileThumb(it.def, ix, iy, is)
                elseif it.ent then
                    local shown = it.ent
                    if it.variants and sel then shown = ET.get(E.palette.entities) end
                    drawEntThumb(shown, ix, iy, is, is)
                elseif it.deco then
                    drawDecoThumb(it.deco, ix, iy, is)
                end
                -- (nombre en hasta dos líneas, centrado en la franja de abajo)
                local nl = math.min(2, math.floor(ui.textHeight(it.label, cell - 6, ui.fontSm) / ui.fontSm:getHeight() + 0.5))
                ui.text(it.label, bx + 3, by + cell - 22 + (2 - nl) * ui.fontSm:getHeight() / 2 + 6, th.text, ui.fontSm, cell - 6, 'center')
                if hov then
                    ui.tooltip(it.tip or it.label)
                    if ui.state.pressed then pickPalette(L, it); ui.state.consumed = true end
                end
            end
            yy = yy + math.ceil(#cats[c] / cols) * (cell + labelH + gap) + 4
        end
    end
    ui.endScroll()
end

local function drawLeftPanel()
    local h = love.graphics.getHeight()
    ui.rect(0, TOP, LEFT, h - TOP - STATUS, th.panel, 0)
    ui.rect(LEFT - 1, TOP, 1, h - TOP - STATUS, th.border, 0)
    local x, w = 10, LEFT - 20
    local y = sectionTitle('Capa', x, TOP + 10, w)
    local bw = (w - 8) / 3
    for i, l in ipairs(LAYERS) do
        local bx = x + ((i - 1) % 3) * (bw + 4)
        local by = y + math.floor((i - 1) / 3) * 34
        if ui.button(l.label, bx, by, bw, 30, { active = E.layer == l.id, font = ui.fontSm,
                                                  tooltip = l.label .. ' (tecla ' .. i .. ')\n' .. l.help }) then
            E.layer = l.id
        end
    end
    y = y + 72
    y = sectionTitle('Herramienta', x, y, w)
    local tools = layerDef(E.layer).tools
    local tw = (w - 4) / 2
    for i, tn in ipairs(tools) do
        local td = TOOLS[tn]
        local bx = x + ((i - 1) % 2) * (tw + 4)
        local by = y + math.floor((i - 1) / 2) * 32
        if ui.button(td.label, bx, by, tw, 28, { active = E.tool[E.layer] == tn, font = ui.fontSm,
                                                 hint = td.key:upper(), tooltip = td.help }) then
            E.tool[E.layer] = tn
        end
    end
    y = y + math.ceil(#tools / 2) * 32 + 4
    -- Ayuda de la herramienta elegida
    local td = TOOLS[E.tool[E.layer]]
    y = y + ui.hint(td.help, x, y, w) + 10

    local L = E.layer
    local bottom = h - STATUS - 8
    if L == 'spikes' then
        y = sectionTitle('Dirección del pincho', x, y, w)
        local dw = (w - 12) / 4
        for i, d in ipairs(DIRS) do
            if ui.button(d[2], x + (i - 1) * (dw + 4), y, dw, 28, { active = E.spikeDir == d[1], font = ui.fontSm }) then E.spikeDir = d[1] end
        end
        y = y + 34
        ui.text('X gira la dirección.', x, y, th.muted, ui.fontSm, w)
    elseif L == 'water' or L == 'special' then
        y = sectionTitle('Capa ' .. layerDef(L).label, x, y, w)
        ui.hint(layerDef(L).help, x, y, w, th.border)
    else
        y = sectionTitle('Paleta', x, y, w)
        drawPalette(L, x, y, w, bottom)
    end
end

-- ── Propiedades (generadas a partir de un esquema) ───────────────────────────
-- Sirve para entidades, decoraciones, zonas de jefe, vents, la cámara
-- automática y cualquier cosa futura con esquema (ver entities/Props.lua).
-- Cada `group` es una sección plegable. min/max pueden ser funciones(owner).
-- `onChange(key, value)` opcional: en vez de escribir props[key] directamente.
local function propLimit(v, owner) if type(v) == 'function' then return v(owner) end return v end

local function drawPropFields(schema, props, x, y, w, owner, idPrefix, onChange)
    idPrefix = idPrefix or 'props'
    -- Propiedades visibles por grupo (para el contador de la cabecera)
    local counts = {}
    for _, p in ipairs(schema) do
        if not p.showIf or p.showIf(props) then
            local g = p.group or 'General'
            counts[g] = (counts[g] or 0) + 1
        end
    end
    local lastGroup, open = nil, true
    for _, p in ipairs(schema) do
        local g = p.group or 'General'
        if (not p.showIf or p.showIf(props)) then
            if g ~= lastGroup then
                lastGroup = g
                y = y + 2
                y, open = ui.section(idPrefix .. ':' .. g, g, x, y, w, tostring(counts[g]))
            end
            if open then
                local v = props[p.key]
                if v == nil then v = (type(p.default) == 'function') and p.default(owner or {}) or p.default end
                local y0 = y
                local nv, ch
                if p.kind == 'bool' then
                    nv, ch = ui.toggle(p.label, v, x, y, w); y = y + 28
                elseif p.kind == 'int' or p.kind == 'number' then
                    local lim = { kind = p.kind, step = p.step, help = p.help,
                                  min = propLimit(p.min, owner), max = propLimit(p.max, owner) }
                    nv, ch = ui.number(p.label, v, x, y, w, lim); y = y + 28
                elseif p.kind == 'enum' then
                    nv, ch = ui.enum(p.label, v, p.options, x, y, w); y = y + ui.ENUM_H + 4
                elseif p.kind == 'text' then
                    ui.text(p.label, x, y + 2, th.text); y = y + 20
                    nv, ch = ui.textField('prop_' .. p.key, v or '', x, y, w, p.maxLen); y = y + 32
                elseif p.kind == 'patrol' then
                    local on, tch = ui.toggle(p.label, v ~= false, x, y, w); y = y + 28
                    if tch then
                        nv, ch = on and { left = owner.col - 3, right = owner.col + 3 } or false, true
                    elseif v then
                        local l, lch = ui.number('   Límite izquierdo (col.)', v.left, x, y, w, { kind = 'int', min = 1, max = v.right }); y = y + 28
                        local r, rch = ui.number('   Límite derecho (col.)', v.right, x, y, w, { kind = 'int', min = v.left, max = E.model.width }); y = y + 28
                        if lch or rch then nv, ch = { left = l, right = r }, true end
                        ui.text('También se arrastran las cajitas azules del mapa.', x, y, th.muted, ui.fontSm, w); y = y + 18
                    end
                elseif p.kind == 'point' then
                    ui.text(p.label, x, y + 5, th.text, ui.font, w - 90)
                    ui.text(string.format('col %d, fila %d', v.col, v.row), x, y + 6, th.muted, ui.fontSm, w, 'right')
                    y = y + 26
                    ui.text('Arrastra su cajita azul en el mapa.', x, y, th.muted, ui.fontSm, w); y = y + 18
                elseif p.kind == 'points' then
                    ui.text(p.label, x, y + 5, th.text, ui.font, w - 90)
                    ui.text(#v .. ' puntos', x, y + 6, th.muted, ui.fontSm, w, 'right'); y = y + 26
                    local bw = (w - 6) / 2
                    if ui.button('Añadir punto', x, y, bw, 24, { font = ui.fontSm, disabled = #v >= (p.max or 32) }) then
                        local last = v[#v]
                        local nv2 = {}
                        for i, q in ipairs(v) do nv2[i] = { col = q.col, row = q.row } end
                        nv2[#nv2+1] = { col = math.min(E.model.width, last.col + 2), row = last.row }
                        nv, ch = nv2, true
                    end
                    if ui.button('Quitar el último', x + bw + 6, y, bw, 24, { font = ui.fontSm, disabled = #v <= (p.min or 1) }) then
                        local nv2 = {}
                        for i = 1, #v - 1 do nv2[i] = { col = v[i].col, row = v[i].row } end
                        nv, ch = nv2, true
                    end
                    y = y + 30
                    ui.text('Arrastra las cajitas numeradas en el mapa.', x, y, th.muted, ui.fontSm, w); y = y + 18
                end
                if ch then
                    pushUndo()
                    if onChange then onChange(p.key, nv) else props[p.key] = nv end
                    markDirty()
                end
                if p.help and ui.inside(x, y0, w, y - y0) then ui.tooltip(p.help) end
            end
        end
    end
    return y
end

-- ── Inspectores ───────────────────────────────────────────────────────────────
-- Cabecera común: miniatura, nombre, subtítulo, descripción y acciones
local function inspectorHeader(x, y, w, thumb, title, subtitle, description)
    ui.rect(x, y, 52, 52, th.panel2, 6)
    if thumb then thumb(x + 6, y + 6, 40) end
    ui.text(title, x + 62, y + 6, th.text, ui.fontLg, w - 62)
    ui.text(subtitle, x + 62, y + 30, th.muted, ui.fontSm, w - 62)
    y = y + 60
    if description then
        ui.text(description, x, y, th.muted, ui.fontSm, w)
        y = y + ui.textHeight(description, w, ui.fontSm) + 8
    end
    return y
end

local function actionButtons(x, y, w, actions)
    local n = #actions
    local bw = (w - (n - 1) * 6) / n
    for i, a in ipairs(actions) do
        if ui.button(a[1], x + (i - 1) * (bw + 6), y, bw, 26,
                     { font = ui.fontSm, hint = a[3], textColor = a[4] and th.danger or nil }) then a[2]() end
    end
    return y + 34
end

local function drawEntityInspector(x, y, w)
    local e = E.selected
    local t = ET.get(e.type)
    y = inspectorHeader(x, y, w, function(ix, iy, s) drawEntThumb(t, ix, iy, s, s, e.props.attach == 'ceiling') end,
                        t.variant and (t.variant.groupLabel or t.label) or t.label,
                        string.format('%s  ·  col %d, fila %d%s', t.category, e.col, e.row, e.sub and (' · cuarto ' .. e.sub) or ''),
                        t.description)
    y = actionButtons(x, y, w, { { 'Duplicar', Editor.duplicate, 'Ctrl+D' }, { 'Eliminar', Editor.deleteSelected, 'Supr', true } })
    -- Variante (dirección del trampolín...): cambia el tipo manteniendo sus propiedades
    local vs = ET.variantsOf(e.type)
    if vs then
        local opts = {}
        for _, n in ipairs(vs) do opts[#opts+1] = { value = n, label = ET.get(n).variant.label } end
        local nv, ch = ui.enum(t.variant.prop or 'Versión', e.type, opts, x, y, w); y = y + ui.ENUM_H + 8
        if ch then pushUndo(); e.type = nv; markDirty() end
    end
    return drawPropFields(t.schema, e.props, x, y, w, e, 'ent:' .. e.type) + 8
end

local function drawDecoInspector(x, y, w)
    local d = E.selDeco
    local t = DT.get(d.type)
    y = inspectorHeader(x, y, w, function(ix, iy, s) drawDecoThumb(t, ix, iy, s) end, t.label,
                        string.format('%s  ·  col %d, fila %d%s', t.category, d.col, d.row, d.sub and (' · cuarto ' .. d.sub) or ''))
    y = actionButtons(x, y, w, { { 'Eliminar', Editor.deleteSelected, 'Supr', true } })
    return drawPropFields(t.schema, d.props, x, y, w, d, 'deco:' .. d.type) + 8
end

-- Esquemas de lo que no es una entidad (se editan con los mismos campos)
local VENT_SCHEMA = {
    { key='limit', kind='int', label='Altura máxima (casillas)', group='Burbujas', default=0, min=0, max=200, step=1,
      help='Casillas que sube la burbuja de aire antes de explotar. 0 = hasta la superficie.' },
}
local function zoneSchema()
    local m = E.model
    return {
        { key='id', kind='int', label='Número (id)', group='Zona', min=1, max=99, step=1,
          help='Los jefes con la propiedad "Zona de jefe (id)" igual a este número le pertenecen (0 = la zona en la que están colocados).' },
        { key='music', kind='enum', label='Música de la pelea', group='Zona', options=BossZones.MUSIC },
        { key='col', kind='int', label='Columna', group='Posición y tamaño', min=1, max=m.width, step=1 },
        { key='row', kind='int', label='Fila', group='Posición y tamaño', min=1, max=m.height, step=1 },
        { key='w', kind='int', label='Ancho (casillas)', group='Posición y tamaño', min=4,
          max=function(z) return m.width - z.col + 1 end, step=1, help='20 = una pantalla' },
        { key='h', kind='int', label='Alto (casillas)', group='Posición y tamaño', min=3,
          max=function(z) return m.height - z.row + 1 end, step=1, help='11 = una pantalla' },
    }
end
local AUTOSCROLL_SCHEMA = {
    { key='startCol', kind='int', label='Columna inicial', group='Recorrido', min=1, max=function() return E.model.width end, step=1,
      help='Borde izquierdo de la ventana al empezar (el inicio del jugador debe quedar dentro)' },
    { key='endCol', kind='int', label='Columna final (0 = fin)', group='Recorrido', min=0, max=function() return E.model.width end, step=1,
      help='Donde se para (borde derecho de la ventana). 0 = al final del nivel' },
    { key='speed', kind='number', label='Velocidad (px/s)', group='Recorrido', min=5, max=2000, step=5,
      help='El jugador anda a 240 px/s' },
    { key='width', kind='int', label='Ancho de la ventana (casillas)', group='Ventana', min=6, max=200, step=1,
      help='20 = una pantalla de 1280 px' },
    { key='margin', kind='number', label='Margen por detrás (casillas)', group='Ventana', min=0, max=20, step=0.1,
      help='Cuánto puede quedarse fuera por la izquierda antes de morir' },
    { key='countdown', kind='number', label='Cuenta atrás (s)', group='Ventana', min=0, max=10, step=0.5 },
}

local function drawVentInspector(x, y, w)
    local v = E.selVent
    y = inspectorHeader(x, y, w, function(ix, iy, s)
            love.graphics.setColor(0.4, 0.9, 1, 1); love.graphics.circle('line', ix + s / 2, iy + s / 2, s * 0.35)
            love.graphics.circle('fill', ix + s / 2, iy + s / 2, s * 0.12)
        end, 'Vent de oxígeno', string.format('Especial  ·  col %d, fila %d · cuarto %d', v.col, v.row, v.sub or 1),
        'Suelta burbujas; las grandes recargan el aire de quien las toca bajo el agua.')
    y = actionButtons(x, y, w, { { 'Eliminar', function()
        pushUndo()
        for i, o in ipairs(E.model.vents) do if o == v then table.remove(E.model.vents, i) break end end
        E.selVent = nil; markDirty()
    end, nil, true } })
    return drawPropFields(VENT_SCHEMA, v, x, y, w, v, 'vent', function(k, val)
        v[k] = (val and val > 0) and val or nil
    end) + 8
end

function Editor.drawZoneInspector(x, y, w)
    local z, m = E.selZone, E.model
    y = inspectorHeader(x, y, w, function(ix, iy, s)
            love.graphics.setColor(1, 0.3, 0.3, 1); love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', ix + 4, iy + 8, s - 8, s - 16); love.graphics.setLineWidth(1)
        end, 'Zona de jefe #' .. z.id, string.format('Especial  ·  col %d, fila %d · %d×%d casillas', z.col, z.row, z.w, z.h),
        'La cámara se queda fija en ella y nadie puede salir hasta vencer a sus jefes. La pelea empieza cuando han entrado todos los jugadores.')
    y = actionButtons(x, y, w, {
        { 'Una pantalla (20×11)', function()
            pushUndo(); z.w = math.min(BossZones.DEFAULT_W, m.width - z.col + 1)
            z.h = math.min(BossZones.DEFAULT_H, m.height - z.row + 1); markDirty()
        end },
        { 'Eliminar', function()
            pushUndo()
            for i, o in ipairs(m.bossZones) do if o == z then table.remove(m.bossZones, i) break end end
            E.selZone = nil; markDirty()
        end, nil, true } })
    y = drawPropFields(zoneSchema(), z, x, y, w, z, 'zone')
    -- Jefes que le pertenecen
    local bosses = m:bossesOf(z)
    local open
    y = y + 2
    y, open = ui.section('zone:bosses', 'Jefes', x, y, w, tostring(#bosses))
    if open then
        if #bosses == 0 then
            y = y + ui.hint('Ninguno. Coloca un jefe dentro (capa Entidades, categoría Jefes) o pon su "Zona de jefe (id)" a ' .. z.id .. '.',
                            x, y, w, th.warn) + 6
        end
        for _, e in ipairs(bosses) do
            local t = ET.get(e.type)
            if ui.button(string.format('%s  (col %d, fila %d)', t.label, e.col, e.row), x, y, w, 26,
                         { font = ui.fontSm, align = 'left', tooltip = 'Seleccionarlo' }) then
                E.layer, E.tool.entities, E.selected = 'entities', 'select', e
            end
            y = y + 30
        end
    end
    return y + 8
end

-- Nada seleccionado: la casilla bajo el cursor y cómo seleccionar
local function drawNothingSelected(x, y, w)
    local hv = E.hover
    if hv and E.model:inBounds(hv.c, hv.r) then
        local raw = E.model:get(hv.c, hv.r)
        local id, wl, sp = Codec.decode(raw)
        local d = TT.get(id)
        local ns = 0; for i = 1, 4 do if sp[i].present then ns = ns + 1 end end
        local info = string.format('Material: %s%s%s', d.mat.label, wl and '  ·  con agua' or '',
                                   ns > 0 and ('  ·  ' .. ns .. ' pincho' .. (ns > 1 and 's' or '')) or '')
        y = inspectorHeader(x, y, w, function(ix, iy, s) drawTileThumb(d, ix, iy, s) end, d.label,
                            string.format('Casilla  ·  col %d, fila %d', hv.c, hv.r), info)
    else
        ui.text('Pasa el cursor por el mapa para ver una casilla.', x, y, th.muted, ui.fontSm, w); y = y + 24
    end
    local tip = ({
        entities = 'Con Seleccionar (V), haz clic en una entidad para editar sus propiedades.',
        deco     = 'Con Seleccionar (V), haz clic en una decoración para editarla.',
        special  = 'Haz clic en un vent (herramienta Vent) o en una zona de jefe (herramienta Zona de jefe) para editarla.',
    })[E.layer]
    if tip then y = y + ui.hint(tip, x, y, w) + 8 end
    return y
end

-- ── Panel de la derecha: Selección / Nivel / Avisos ──────────────────────────
local function drawSelectionTab(x, y, w)
    if E.selVent and E.layer == 'special' then return drawVentInspector(x, y, w)
    elseif E.selZone and E.layer == 'special' then return Editor.drawZoneInspector(x, y, w)
    elseif E.selected and E.layer == 'entities' then return drawEntityInspector(x, y, w)
    elseif E.selDeco and E.layer == 'deco' then return drawDecoInspector(x, y, w) end
    return drawNothingSelected(x, y, w)
end

local function drawLevelTab(x, y, w)
    local m = E.model
    local open
    y, open = ui.section('lvl:general', 'General', x, y, w)
    if open then
        ui.text('Nombre', x, y + 6, th.text)
        local nm, nch = ui.textField('lvl_name', m.name or '', x + 70, y, w - 70, 40, 'Nombre del nivel')
        if nch then m.name = nm; E.unsaved = true end
        y = y + 34
        E.newW = E.newW or m.width
        E.newH = E.newH or m.height
        E.newW = ui.number('Ancho (casillas)', E.newW, x, y, w, { kind = 'int', min = 8, max = 400 }); y = y + 28
        E.newH = ui.number('Alto (casillas)', E.newH, x, y, w, { kind = 'int', min = 6, max = 200 }); y = y + 30
        local changedSize = E.newW ~= m.width or E.newH ~= m.height
        if ui.button('Aplicar tamaño', x, y, (w - 6) / 2, 26, { disabled = not changedSize, font = ui.fontSm }) and changedSize then
            pushUndo(); m:resize(E.newW, E.newH); markDirty(); msg('Tamaño cambiado a ' .. E.newW .. '×' .. E.newH)
        end
        if ui.button('Enmarcar con borde', x + (w + 6) / 2, y, (w - 6) / 2, 26, { font = ui.fontSm, tooltip = 'Rodea el mapa con el bloque Borde' }) then
            pushUndo(); m:frame(TILE_BORDER); markDirty()
        end
        y = y + 36
    end
    y = y + 2
    y, open = ui.section('lvl:scroll', 'Cámara automática', x, y, w, m.autoScroll and 'activada' or 'no')
    if open then
        local on, ch = ui.toggle('Activada', m.autoScroll ~= nil, x, y, w)
        if ui.inside(x, y, w, 26) then
            ui.tooltip('El nivel avanza solo hacia la derecha. Empieza cuando todos los jugadores están en la ventana inicial; quien se queda atrás muere y reaparece en el centro. Solo modo Carrera.')
        end
        y = y + 30
        if ch then
            pushUndo()
            m.autoScroll = on and AutoScroll.normalize({ startCol = 1, endCol = 0 }) or nil
            markDirty()
        end
        if m.autoScroll then y = drawPropFields(AUTOSCROLL_SCHEMA, m.autoScroll, x, y, w, m.autoScroll, 'scroll') end
        y = y + 4
    end
    y = y + 2
    -- Música del nivel (catálogo: assets/music/index.json)
    local cur = Music.levelTrack(m.music)
    local curTrack = Music.get(cur)
    y, open = ui.section('lvl:music', 'Música', x, y, w, curTrack and curTrack.name or cur)
    if open then
        for _, tr in ipairs(Music.levelList) do
            local sel = tr.id == cur
            local playing = E.preview == tr.id
            local kind = tr.intro and 'intro + bucle' or 'bucle'
            if ui.button(tr.name, x, y, w - 36, 26, { active = sel, align = 'left', font = ui.fontSm, hint = kind,
                                                      tooltip = 'Usar "' .. tr.name .. '" como música de este nivel' }) and not sel then
                pushUndo()
                m.music = (tr.id ~= Music.DEFAULT) and tr.id or nil
                markDirty()
            end
            -- Botón escuchar / parar (icono dibujado: la fuente no tiene ▶ ■)
            local bx = x + w - 32
            local pressed = ui.button('', bx, y, 32, 26, { tooltip = playing and 'Parar' or 'Escuchar', active = playing })
            love.graphics.setColor(th.text)
            if playing then love.graphics.rectangle('fill', bx + 11, y + 8, 10, 10)
            else love.graphics.polygon('fill', bx + 12, y + 7, bx + 12, y + 19, bx + 22, y + 13) end
            if pressed then
                Editor.previewMusic(playing and nil or tr.id)
            end
            y = y + 30
        end
        y = y + ui.hint('Para añadir canciones: copia el archivo en assets/music/ y añade una entrada en assets/music/index.json.',
                        x, y, w, th.border) + 8
    end
    y = y + 2
    -- Modos de juego online: en cuáles se ofrece este nivel
    y, open = ui.section('lvl:modes', 'Modos de juego', x, y, w, m.modes and 'limitados' or 'todos')
    if open then
        -- Lo que el servidor mira para decidir (mismo cálculo que server/main.lua)
        local info = Modes.entityInfo(m.entities)
        info.finish, info.autoScroll = 0, m.autoScroll ~= nil
        if E.level then info.finish = E.level:countTrigger('finish') end
        local allowed = {}
        if m.modes then for _, id in ipairs(m.modes) do allowed[id] = true end end
        for _, md in ipairs(Modes.list) do
            local on = (m.modes == nil) or allowed[md.id] == true
            local ok, why = md.requires(info)
            local nv, ch = ui.toggle(md.label, on, x, y, w)
            local tip = md.tagline .. (ok and '' or ('\nAhora no sale: ' .. (why or 'el nivel no cumple sus requisitos')))
            if ui.inside(x, y, w, 26) then ui.tooltip(tip) end
            y = y + 26
            ui.text(on and (ok and 'Disponible' or ('No disponible: ' .. (why or '?'))) or 'Desactivado para este nivel',
                    x + 10, y - 2, (on and ok) and th.ok or th.muted, ui.fontSm, w - 10)
            y = y + 18
            if ch then
                pushUndo()
                allowed = {}
                for _, o in ipairs(Modes.list) do
                    local cur = (m.modes == nil) or (function() for _, id in ipairs(m.modes) do if id == o.id then return true end end end)()
                    if o.id == md.id then cur = nv end
                    if cur then allowed[#allowed+1] = o.id end
                end
                m.modes = (#allowed < #Modes.list) and allowed or nil
                markDirty()
            end
        end
        local koth = Modes.get('koth')
        local mt = m.matchTime or (koth and koth.DEFAULT_TIME) or 150
        local nv, ch = ui.number('Duración de la partida (s)', mt, x, y + 4, w,
                                 { kind = 'int', min = 30, max = 590, step = 10,
                                   help = 'Partidas con tiempo (Rey de la Colina). Por defecto ' .. ((koth and koth.DEFAULT_TIME) or 150) .. ' s' })
        if ch then pushUndo(); m.matchTime = nv; markDirty() end
        y = y + 38
    end
    y = y + 2
    y, open = ui.section('lvl:summary', 'Resumen', x, y, w)
    if open then
        local byCat = {}
        for _, e in ipairs(m.entities) do
            local t = ET.get(e.type); local c = t and t.category or '?'
            byCat[c] = (byCat[c] or 0) + 1
        end
        local lines = { string.format('Tamaño: %d×%d casillas', m.width, m.height),
                        string.format('Inicio: col %d, fila %d', m.playerStart[1], m.playerStart[2]) }
        for _, c in ipairs(ET.CATEGORIES) do
            if byCat[c.id] then lines[#lines+1] = string.format('%s: %d', c.id, byCat[c.id]) end
        end
        lines[#lines+1] = string.format('Decoraciones: %d  ·  Vents: %d  ·  Zonas de jefe: %d', #m.foliage, #m.vents, #m.bossZones)
        for _, l in ipairs(lines) do ui.text(l, x, y, th.muted, ui.fontSm, w); y = y + 17 end
        y = y + 6
    end
    return y
end

local function drawWarningsTab(x, y, w)
    local ws = E.warnings or {}
    if #ws == 0 then
        return y + ui.hint('Todo correcto: el nivel no tiene problemas.', x, y, w, th.ok) + 8
    end
    ui.text('Haz clic en un aviso para ir a lo que lo causa.', x, y, th.muted, ui.fontSm, w); y = y + 22
    for _, wn in ipairs(ws) do
        local col = (wn[1] == 'error' and th.danger) or (wn[1] == 'warn' and th.warn) or th.muted
        local hgt = ui.textHeight(wn[2], w - 18, ui.fontSm) + 10
        local hov = ui.inside(x, y, w, hgt)
        ui.rect(x, y, w, hgt, hov and wn[3] and th.hover or th.panel2, 4)
        ui.rect(x, y, 3, hgt, col, 1)
        ui.text(wn[2], x + 12, y + 5, th.text, ui.fontSm, w - 18)
        if hov and wn[3] and ui.state.pressed then
            E.layer, E.tool.entities, E.selected = 'entities', 'select', wn[3]
            E.rightTab = 'sel'
            Editor.centerOn(wn[3].col, wn[3].row)
            ui.state.consumed = true
        end
        y = y + hgt + 6
    end
    return y
end

local function selectionKey()
    return tostring(E.selected) .. tostring(E.selDeco) .. tostring(E.selZone) .. tostring(E.selVent)
end

local function drawRightPanel()
    local sw, sh = love.graphics.getDimensions()
    local x0 = sw - RIGHT
    ui.rect(x0, TOP, RIGHT, sh - TOP - STATUS, th.panel, 0)
    ui.rect(x0, TOP, 1, sh - TOP - STATUS, th.border, 0)
    local x, w = x0 + 14, RIGHT - 28

    -- Al seleccionar algo nuevo, se enseña su pestaña
    local key = selectionKey()
    if key ~= E.lastSelKey then
        E.lastSelKey = key
        if E.selected or E.selDeco or E.selZone or E.selVent then E.rightTab = 'sel' end
    end
    E.rightTab = E.rightTab or 'sel'
    local ws = E.warnings or {}
    local nErr, nWarn = 0, 0
    for _, wn in ipairs(ws) do if wn[1] == 'error' then nErr = nErr + 1 elseif wn[1] == 'warn' then nWarn = nWarn + 1 end end
    local badge = (nErr + nWarn > 0) and (nErr + nWarn) or nil
    E.rightTab = ui.tabs({
        { id = 'sel',   label = 'Selección' },
        { id = 'level', label = 'Nivel' },
        { id = 'warn',  label = 'Avisos', badge = badge, badgeColor = nErr > 0 and th.danger or th.warn },
    }, E.rightTab, x0 + 6, TOP + 8, RIGHT - 12, 32)

    local top = TOP + 46
    local areaH = sh - STATUS - top
    local yy = ui.beginScroll('right_' .. E.rightTab, x0, top, RIGHT, areaH, E.rightH and E.rightH[E.rightTab] or areaH)
    local y = yy + 8
    if E.rightTab == 'sel' then y = drawSelectionTab(x, y, w)
    elseif E.rightTab == 'level' then y = drawLevelTab(x, y, w)
    else y = drawWarningsTab(x, y, w) end
    E.rightH = E.rightH or {}
    E.rightH[E.rightTab] = y - yy + 12
    ui.endScroll()
end

local function drawStatus()
    local sw, sh = love.graphics.getDimensions()
    ui.rect(0, sh - STATUS, sw, STATUS, th.panel, 0)
    ui.rect(0, sh - STATUS, sw, 1, th.border, 0)
    local parts = { layerDef(E.layer).label .. ' › ' .. TOOLS[E.tool[E.layer]].label }
    if E.hover then
        parts[#parts+1] = string.format('col %d, fila %d', E.hover.c, E.hover.r)
        local raw = E.model:get(E.hover.c, E.hover.r)
        if raw then parts[#parts+1] = TT.get(Codec.id(raw)).label end
    end
    parts[#parts+1] = string.format('%d×%d', E.model.width, E.model.height)
    parts[#parts+1] = #E.model.entities .. ' entidades'
    ui.text(table.concat(parts, '     '), 10, sh - STATUS + 6, th.muted, ui.fontSm)
    if E.msg and E.msgT > 0 then
        local c = (E.msgKind == 'error' and th.danger) or (E.msgKind == 'warn' and th.warn) or th.ok
        ui.text(E.msg, sw - 610, sh - STATUS + 6, c, ui.fontSm, 600, 'right')
    end
end

-- ── Diálogos ──────────────────────────────────────────────────────────────────
local function drawModal()
    local md = E.modal
    if not md then return end
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    local w, h = 460, 200
    if md.kind == 'open' then w, h = math.min(sw - 80, 620), math.min(sh - 80, 130 + #md.files * 34) end
    if md.kind == 'help' then w, h = 720, 470 end
    local x, y = (sw - w) / 2, (sh - h) / 2
    ui.rect(x, y, w, h, th.panel, 8)
    ui.rect(x, y, w, h, th.border, 8, 'line')
    local close = function() E.modal = nil end

    if md.kind == 'confirm' then
        ui.text('Atención', x + 20, y + 16, th.warn, ui.fontLg)
        ui.text(md.text, x + 20, y + 52, th.text, ui.font, w - 40)
        if ui.button('Descartar cambios', x + w - 290, y + h - 50, 160, 32, { textColor = th.danger }) then E.modal = nil; md.onYes() end
        if ui.button('Cancelar', x + w - 120, y + h - 50, 100, 32) then close() end
    elseif md.kind == 'open' then
        ui.text('Abrir nivel', x + 20, y + 16, th.text, ui.fontLg)
        ui.text(#md.files .. ' niveles  ·  rueda del ratón o flechas para moverse', x + 170, y + 22, th.muted, ui.fontSm)
        -- Lista con scroll (caben muchos niveles)
        local top, areaH = y + 56, h - 56 - 60
        local contentH = #md.files * 34
        md.sel = math.max(1, math.min(#md.files, md.sel or 1))
        local keys = ui.state.keys
        if keys['down'] then md.sel = math.min(#md.files, md.sel + 1) end
        if keys['up'] then md.sel = math.max(1, md.sel - 1) end
        if keys['down'] or keys['up'] then          -- (que la seleccionada se vea)
            local off = ui.state.scroll['open'] or 0
            local sy = (md.sel - 1) * 34
            if sy < off then off = sy elseif sy + 28 > off + areaH then off = sy + 28 - areaH end
            ui.state.scroll['open'] = off
        end
        local open = function(f)
            local m, err = Model.load(f)
            if m then E.modal = nil; setModel(m, f) else msg(err, 'error') end
        end
        local yy = ui.beginScroll('open', x + 16, top, w - 32, areaH, contentH)
        for i, f in ipairs(md.files) do
            local file = f:match('[^/]+$')
            local name = md.files.names and md.files.names[f]
            local label = (name and name ~= '' and name ~= file:gsub('%.json$', '')) and (file .. '   —   ' .. name) or file
            if ui.button(label, x + 20, yy, w - 48, 28, { align = 'left', active = (i == md.sel) }) then open(f) end
            yy = yy + 34
        end
        ui.endScroll()
        if #md.files == 0 then ui.text('No hay niveles en ' .. LEVELS_DIR, x + 20, top, th.muted) end
        if keys['return'] and md.files[md.sel] then open(md.files[md.sel]) end
        if ui.button('Cancelar', x + w - 120, y + h - 46, 100, 30) then close() end
    elseif md.kind == 'saveas' then
        ui.text('Guardar como', x + 20, y + 16, th.text, ui.fontLg)
        ui.text(LEVELS_DIR .. '/', x + 20, y + 66, th.muted)
        ui.state.focus = ui.state.focus or 'saveas'
        md.name = ui.textField('saveas', md.name or '', x + 120, y + 60, w - 200, 40)
        md.name = md.name:gsub('[^%w%-_]', '')
        ui.text('.json', x + w - 72, y + 66, th.muted)
        local go = ui.button('Guardar', x + w - 230, y + h - 50, 100, 32) or ui.state.keys['return']
        if go and #md.name > 0 then
            E.modal = nil; ui.state.focus = nil
            if E.model.name == nil or E.model.name == '' or E.model.name == 'nuevo' then E.model.name = md.name end
            save(LEVELS_DIR .. '/' .. md.name .. '.json')
        end
        if ui.button('Cancelar', x + w - 120, y + h - 50, 100, 32) then close(); ui.state.focus = nil end
    elseif md.kind == 'help' then
        ui.text('Atajos de teclado', x + 20, y + 16, th.text, ui.fontLg)
        local cols = {
            { 'Archivo', { { 'Ctrl+N', 'Nivel nuevo' }, { 'Ctrl+O', 'Abrir' }, { 'Ctrl+S', 'Guardar' },
                           { 'Ctrl+Mayús+S', 'Guardar como' }, { 'F5', 'Probar el nivel' }, { 'F10', 'Volver al editor (probando)' } } },
            { 'Edición', { { 'Ctrl+Z / Ctrl+Y', 'Deshacer / rehacer' }, { 'Ctrl+D', 'Duplicar la entidad' },
                           { 'Supr', 'Eliminar la selección' }, { 'Esc', 'Quitar la selección' },
                           { 'X', 'Girar pincho / cambiar versión' }, { 'Clic derecho', 'Borrar' } } },
            { 'Capas y herramientas', { { '1 … 6', 'Cambiar de capa' }, { 'B R L F I E', 'Pincel, rect., línea, relleno…' },
                           { 'V', 'Seleccionar' }, { 'S O Z', 'Inicio, vent, zona de jefe' } } },
            { 'Vista', { { 'Rueda', 'Zoom' }, { '+ / − / 0', 'Acercar / alejar / 100%' },
                         { 'Clic central', 'Mover la vista' }, { 'Espacio + arrastrar', 'Mover la vista' },
                         { 'Flechas', 'Mover la vista' }, { 'G / H', 'Rejilla / rutas' } } },
        }
        local cw = (w - 60) / 2
        for i, c in ipairs(cols) do
            local cx = x + 20 + ((i - 1) % 2) * (cw + 20)
            local cy = y + 56 + math.floor((i - 1) / 2) * 190
            ui.text(c[1]:upper(), cx, cy, th.accent, ui.fontSm); cy = cy + 20
            for _, k in ipairs(c[2]) do
                ui.rect(cx, cy, 130, 22, th.bg, 4)
                ui.text(k[1], cx, cy + 4, th.text, ui.fontSm, 130, 'center')
                ui.text(k[2], cx + 140, cy + 4, th.muted, ui.fontSm, cw - 140)
                cy = cy + 26
            end
        end
        if ui.button('Cerrar', x + w - 120, y + h - 46, 100, 30) then close() end
    elseif md.kind == 'new' then
        ui.text('Nivel nuevo', x + 20, y + 16, th.text, ui.fontLg)
        md.w = ui.number('Ancho (casillas)', md.w, x + 20, y + 60, w - 40, { kind = 'int', min = 8, max = 400 })
        md.h = ui.number('Alto (casillas)', md.h, x + 20, y + 92, w - 40, { kind = 'int', min = 6, max = 200 })
        if ui.button('Crear', x + w - 230, y + h - 50, 100, 32) then
            E.modal = nil; setModel(Model.new(md.w, md.h, 'nuevo'), nil)
            E.newW, E.newH = md.w, md.h
        end
        if ui.button('Cancelar', x + w - 120, y + h - 50, 100, 32) then close() end
    end
    ui.state.consumed = true
end

-- ── Zonas de jefe ─────────────────────────────────────────────────────────────
-- Dibujo en el lienzo: área (roja), encuadre de la cámara (una pantalla
-- centrada, como en el juego), asa de tamaño y enlace con sus jefes.
local function dashedRect(x, y, w, h, dash)
    for xx = x, x + w - dash, dash * 2 do
        love.graphics.line(xx, y, math.min(xx + dash, x + w), y)
        love.graphics.line(xx, y + h, math.min(xx + dash, x + w), y + h)
    end
    for yy = y, y + h - dash, dash * 2 do
        love.graphics.line(x, yy, x, math.min(yy + dash, y + h))
        love.graphics.line(x + w, yy, x + w, math.min(yy + dash, y + h))
    end
end

function Editor.drawZones(camX, camY, t, zoom)
    local m = E.model
    love.graphics.setFont(ui.fontSm)
    for _, z in ipairs(m.bossZones) do
        local sel = (z == E.selZone)
        local x, y, w, h = (z.col - 1) * t - camX, (z.row - 1) * t - camY, z.w * t, z.h * t
        love.graphics.setColor(1, 0.2, 0.25, sel and 0.16 or 0.09)
        love.graphics.rectangle('fill', x, y, w, h)
        love.graphics.setLineWidth((sel and 4 or 3) / zoom)
        love.graphics.setColor(1, 0.3, 0.3, sel and 1 or 0.75)
        love.graphics.rectangle('line', x, y, w, h)
        -- Lo que enseñará la cámara (1280x720 centrado)
        local cw, ch = 1280, 720
        love.graphics.setLineWidth(2 / zoom)
        love.graphics.setColor(1, 1, 1, 0.35)
        dashedRect(x + (w - cw) / 2, y + (h - ch) / 2, cw, ch, 16)
        -- Etiqueta
        local bosses = m:bossesOf(z)
        local label = 'ZONA DE JEFE #' .. z.id .. (#bosses == 0 and '  (sin jefe)' or '')
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', x + 4, y + 4, ui.fontSm:getWidth(label) / 1 + 12, 20)
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.print(label, x + 10, y + 7)
        -- Asa de tamaño
        if sel then
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
            love.graphics.rectangle('fill', x + w - t + t * 0.2, y + h - t + t * 0.2, t * 0.6, t * 0.6)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.rectangle('line', x + w - t + t * 0.2, y + h - t + t * 0.2, t * 0.6, t * 0.6)
        end
        -- Enlace zona → jefes
        love.graphics.setColor(1, 0.4, 0.4, sel and 0.9 or 0.5)
        for _, e in ipairs(bosses) do
            love.graphics.line(x + 10, y + 24, (e.col - 0.5) * t - camX, (e.row - 0.5) * t - camY)
            love.graphics.circle('line', (e.col - 0.5) * t - camX, (e.row - 0.5) * t - camY, t * 0.55)
        end
    end
    love.graphics.setLineWidth(1)
end

-- ── Cámara automática ─────────────────────────────────────────────────────────
function Editor.drawAutoScroll(camX, camY, t, zoom)
    local a = E.model.autoScroll
    if not a then return end
    local m = E.model
    local H = m.height * t
    local sx = (a.startCol - 1) * t - camX
    local endCol = (a.endCol > 0) and math.min(a.endCol, m.width) or m.width
    local ex = endCol * t - camX
    love.graphics.setLineWidth(3 / zoom)
    -- Ventana inicial (verde) y final (amarilla)
    love.graphics.setColor(0.3, 1, 0.5, 0.12)
    love.graphics.rectangle('fill', sx, -camY, a.width * t, H)
    love.graphics.setColor(0.3, 1, 0.5, 0.9)
    love.graphics.rectangle('line', sx, -camY, a.width * t, H)
    love.graphics.setColor(1, 0.85, 0.2, 0.9)
    love.graphics.rectangle('line', ex - a.width * t, -camY, a.width * t, H)
    love.graphics.line(ex, -camY, ex, -camY + H)
    -- Flechas del recorrido
    love.graphics.setColor(0.3, 1, 0.5, 0.5)
    for xx = sx + a.width * t + t, ex - t, t * 4 do
        love.graphics.line(xx, -camY + H / 2, xx + t, -camY + H / 2)
        love.graphics.line(xx + t, -camY + H / 2, xx + t * 0.6, -camY + H / 2 - t * 0.35)
        love.graphics.line(xx + t, -camY + H / 2, xx + t * 0.6, -camY + H / 2 + t * 0.35)
    end
    love.graphics.setFont(ui.fontSm)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', sx + 4, -camY + 4, 260, 20)
    love.graphics.setColor(0.3, 1, 0.5, 1)
    love.graphics.print(string.format('CÁMARA AUTOMÁTICA  ·  %d px/s', a.speed), sx + 10, -camY + 7)
    love.graphics.setLineWidth(1)
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
    E.tool = { tiles='brush', water='brush', spikes='brush', entities='select', deco='place', special='spawn' }
    E.selZone = nil
    E.selDeco = nil
    E.palette = { tiles = TILE_SOLID, entities = ET.list[1] and ET.list[1].name, deco = DT.list[1] and DT.list[1].name }
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

return Editor
