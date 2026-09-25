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
local LAYERS = {
    { id='tiles',    label='Bloques',    tools={ 'brush', 'rect', 'line', 'fill', 'erase', 'pick' } },
    { id='water',    label='Agua',       tools={ 'brush', 'rect', 'fill', 'erase' } },
    { id='spikes',   label='Pinchos',    tools={ 'brush', 'erase' } },
    { id='entities', label='Entidades',  tools={ 'select', 'place', 'erase' } },
    { id='deco',     label='Decoracion', tools={ 'place', 'erase' } },
    { id='special',  label='Especial',   tools={ 'spawn', 'vent', 'erase' } },
}
local TOOLS = {
    brush  = { label='Pincel',      key='b', help='Pinta celda a celda (arrastra). Clic derecho borra.' },
    rect   = { label='Rectangulo',  key='r', help='Arrastra para rellenar un rectangulo.' },
    line   = { label='Linea',       key='l', help='Arrastra para trazar una linea recta.' },
    fill   = { label='Relleno',     key='f', help='Rellena la zona contigua del mismo tipo.' },
    erase  = { label='Borrar',      key='e', help='Borra lo de esta capa (tambien clic derecho).' },
    pick   = { label='Cuentagotas', key='i', help='Copia el bloque bajo el cursor a la paleta.' },
    select = { label='Seleccionar', key='v', help='Selecciona, mueve y edita entidades. Arrastra las cajitas de la ruta.' },
    place  = { label='Colocar',     key='b', help='Coloca lo elegido en la paleta.' },
    spawn  = { label='Inicio',      key='s', help='Mueve el punto de inicio del jugador.' },
    vent   = { label='Vent',        key='o', help='Coloca/quita un vent de oxigeno (subcelda).' },
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

local function drawImageFit(i, x, y, w, h, flipY)
    if not i then return end
    local s = math.min(w / i:getWidth(), h / i:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(i, x + w / 2, y + h / 2, 0, s, flipY and -s or s, i:getWidth() / 2, i:getHeight() / 2)
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
    E.selected = nil; markDirty(); msg('Deshecho')
end

local function redo()
    if #E.redo == 0 then return msg('Nada que rehacer', 'warn') end
    table.insert(E.undo, E.model:snapshot())
    E.model:restore(table.remove(E.redo))
    E.selected = nil; markDirty(); msg('Rehecho')
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
    E.selected = nil
    E.unsaved = false
    E.levelDirty = true
    E.camX, E.camY, E.zoom = -40, -40, 0.75
    E.newW, E.newH = m.width, m.height
    rebuild()
    msg(path and ('Abierto ' .. path) or 'Nivel nuevo')
end

local function listLevels()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(LEVELS_DIR)) do
        if f:match('%.json$') then out[#out+1] = LEVELS_DIR .. '/' .. f end
    end
    table.sort(out)
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
    if errs > 0 then return msg('Corrige los errores (panel Avisos) antes de probar', 'error') end
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
        local e, idx = m:entityAt(c, r)
        if erase then
            if e then table.remove(m.entities, idx); if E.selected == e then E.selected = nil end; s.changed = true end
        elseif e then
            E.selected = e; s.move = { e = e, dc = 0 }
        elseif tool == 'place' then
            if m:inBounds(c, r) then
                E.selected = m:addEntity(E.palette.entities, c, r); s.changed = true
                s.move = { e = E.selected }
            end
        else
            E.selected = nil
        end
    elseif L == 'deco' then
        local ft
        for _, f in ipairs(Level.FOLIAGE_TYPES) do if f.name == E.palette.deco then ft = f end end
        local o, idx = m:findObject(m.foliage, c, r, (not erase and ft and ft.sub) and sub or nil)
        if erase then
            if o then table.remove(m.foliage, idx); s.changed = true end
        elseif not o and m:inBounds(c, r) and ft then
            m.foliage[#m.foliage+1] = { type = ft.name, col = c, row = r, sub = ft.sub and sub or nil }
            s.changed = true
        end
    elseif L == 'special' then
        if tool == 'spawn' and not erase then
            if m:inBounds(c, r) then m.playerStart = { c, r }; s.changed = true end
        elseif tool == 'vent' and not erase then
            local o, idx = m:findObject(m.vents, c, r, sub)
            if o then table.remove(m.vents, idx) elseif m:inBounds(c, r) then m.vents[#m.vents+1] = { col = c, row = r, sub = sub } end
            s.changed = true
        else
            local o, idx = m:findObject(m.vents, c, r)
            if o then table.remove(m.vents, idx); s.changed = true end
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
        h.col = (h.side == 'left' and p.left) or (h.side == 'right' and p.right) or c
    elseif s.move and E.model:inBounds(c, r) then
        local e = s.move.e
        if c ~= e.col or r ~= e.row then
            -- La ruta se desplaza con la entidad
            local dc = c - e.col
            if e.props.patrol then e.props.patrol.left = e.props.patrol.left + dc; e.props.patrol.right = e.props.patrol.right + dc end
            e.col, e.row = c, r
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
    end
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
                local hx, hy = (h.col - 1) * t - camX + t * 0.2, (h.row - 1) * t - camY + t * 0.2
                love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35 * a)
                love.graphics.rectangle('fill', hx, hy, t * 0.6, t * 0.6, 6, 6)
                love.graphics.setColor(1, 1, 1, 0.9 * a)
                love.graphics.rectangle('line', hx, hy, t * 0.6, t * 0.6, 6, 6)
            end
        end
        if sel then
            love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
            love.graphics.rectangle('line', (e.col-1)*t - camX + 2, (e.row-1)*t - camY + 2, t - 4, t - 4, 6, 6)
        end
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
        if E.layer == 'deco' then
            for _, f in ipairs(Level.FOLIAGE_TYPES) do if f.name == E.palette.deco and f.sub then subLayer = true end end
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
end

-- ── Paneles ───────────────────────────────────────────────────────────────────
local function sectionTitle(s, x, y, w)
    ui.text(s:upper(), x, y, th.muted, ui.fontSm)
    ui.rect(x, y + 16, w, 1, th.border, 0)
    return y + 24
end

local function drawTopBar()
    local w = love.graphics.getWidth()
    ui.rect(0, 0, w, TOP, th.panel, 0)
    ui.rect(0, TOP - 1, w, 1, th.border, 0)
    local x = 8
    local function btn(label, bw, fn, opts)
        if ui.button(label, x, 8, bw, 30, opts) then fn() end
        x = x + bw + 6
    end
    btn('Nuevo', 64, function() guardUnsaved(function() E.modal = { kind = 'new', w = 30, h = 15 } end) end, { tooltip = 'Ctrl+N' })
    btn('Abrir', 64, function() guardUnsaved(function() E.modal = { kind = 'open', files = listLevels() } end) end, { tooltip = 'Ctrl+O' })
    btn('Guardar', 74, function() save() end, { tooltip = 'Ctrl+S' })
    btn('Guardar como', 110, function() E.modal = { kind = 'saveas', name = E.model.name } end, { tooltip = 'Ctrl+Shift+S' })
    x = x + 8
    btn('Deshacer', 80, undo, { disabled = #E.undo == 0, tooltip = 'Ctrl+Z' })
    btn('Rehacer', 76, redo, { disabled = #E.redo == 0, tooltip = 'Ctrl+Y' })
    x = x + 8
    btn('Rejilla', 70, function() E.grid = not E.grid end, { active = E.grid, tooltip = 'G' })
    btn('Rutas', 64, function() E.showRoutes = not E.showRoutes end, { active = E.showRoutes, tooltip = 'H: mostrar rutas de todas las entidades' })
    x = x + 8
    btn('-', 30, function() E.zoom = math.max(0.25, E.zoom / 1.25) end)
    ui.text(string.format('%d%%', math.floor(E.zoom * 100 + 0.5)), x, 15, th.text, ui.font, 50, 'center'); x = x + 56
    btn('+', 30, function() E.zoom = math.min(3, E.zoom * 1.25) end)

    local title = (E.model.path or '(sin guardar)') .. (E.unsaved and '  •' or '')
    ui.text(title, x + 12, 15, E.unsaved and th.warn or th.muted)
    if ui.button('Probar  (F5)', w - 132, 8, 124, 30, { color = th.accentDk, tooltip = 'Juega este nivel. F10 vuelve al editor.' }) then startPlay() end
end

local function drawLeftPanel()
    local h = love.graphics.getHeight()
    ui.rect(0, TOP, LEFT, h - TOP - STATUS, th.panel, 0)
    ui.rect(LEFT - 1, TOP, 1, h - TOP - STATUS, th.border, 0)
    local x, w = 10, LEFT - 20
    local y = sectionTitle('Capas (1-6)', x, TOP + 10, w)
    local bw = (w - 8) / 3
    for i, l in ipairs(LAYERS) do
        local bx = x + ((i - 1) % 3) * (bw + 4)
        local by = y + math.floor((i - 1) / 3) * 34
        if ui.button(l.label, bx, by, bw, 30, { active = E.layer == l.id, font = ui.fontSm }) then
            E.layer = l.id
        end
    end
    y = y + 76
    y = sectionTitle('Herramientas', x, y, w)
    local tools = layerDef(E.layer).tools
    local tw = (w - 8) / 3
    for i, tn in ipairs(tools) do
        local td = TOOLS[tn]
        local bx = x + ((i - 1) % 3) * (tw + 4)
        local by = y + math.floor((i - 1) / 3) * 34
        if ui.button(td.label .. ' (' .. td.key:upper() .. ')', bx, by, tw, 30,
                     { active = E.tool[E.layer] == tn, font = ui.fontSm, tooltip = td.help }) then
            E.tool[E.layer] = tn
        end
    end
    y = y + math.ceil(#tools / 3) * 34 + 8

    -- Opciones / paleta por capa
    local L = E.layer
    if L == 'spikes' then
        y = sectionTitle('Direccion del pincho (X gira)', x, y, w)
        local dw = (w - 12) / 4
        for i, d in ipairs(DIRS) do
            if ui.button(DIR_ARROW[d[1]] .. ' ' .. d[2], x + (i - 1) * (dw + 4), y, dw, 30,
                         { active = E.spikeDir == d[1], font = ui.fontSm }) then E.spikeDir = d[1] end
        end
        y = y + 40
        ui.text('Los pinchos ocupan subceldas (cuartos de bloque): haz clic en el cuarto donde lo quieras. Matan al tocarlos desde su punta.',
                x, y, th.muted, ui.fontSm, w)
        return
    elseif L == 'water' then
        ui.text('Marca celdas llenas de agua. Se puede combinar con cualquier bloque (p. ej. una plataforma sumergida). El bloque "Agua" puro esta en la capa Bloques.',
                x, y, th.muted, ui.fontSm, w)
        return
    elseif L == 'special' then
        ui.text('Inicio: donde aparece el jugador (uno por nivel).\nVent: burbujas de oxigeno que recargan el aire bajo el agua (en subceldas).',
                x, y, th.muted, ui.fontSm, w)
        return
    end

    -- Paleta con miniaturas agrupada por categoría
    local items = {}
    if L == 'tiles' then
        for _, t in ipairs(TT.list) do items[#items+1] = { key = t.id, label = t.label, cat = t.category, def = t } end
    elseif L == 'entities' then
        for _, t in ipairs(ET.list) do items[#items+1] = { key = t.name, label = t.label, cat = t.category, ent = t } end
    elseif L == 'deco' then
        for _, f in ipairs(Level.FOLIAGE_TYPES) do items[#items+1] = { key = f.name, label = f.label, cat = f.sub and 'Pequenas (subcelda)' or 'Grandes', icon = f.icon } end
    end
    local cats, order = {}, {}
    for _, it in ipairs(items) do
        if not cats[it.cat] then cats[it.cat] = {}; order[#order+1] = it.cat end
        table.insert(cats[it.cat], it)
    end
    local cell, gap = 80, 6
    local cols = math.floor((w + gap) / (cell + gap))
    local contentH = 0
    for _, c in ipairs(order) do contentH = contentH + 24 + math.ceil(#cats[c] / cols) * (cell + 18 + gap) end
    local areaH = h - STATUS - y - 8
    local yy = ui.beginScroll('pal_' .. L, x, y, w, areaH, contentH)
    for _, c in ipairs(order) do
        ui.text(c, x, yy + 4, th.muted, ui.fontSm); yy = yy + 24
        for i, it in ipairs(cats[c]) do
            local bx = x + ((i - 1) % cols) * (cell + gap)
            local by = yy + math.floor((i - 1) / cols) * (cell + 18 + gap)
            local sel = E.palette[L] == it.key
            local hov = ui.inside(bx, by, cell, cell + 18)
            ui.rect(bx, by, cell, cell + 18, sel and th.accentDk or (hov and th.hover or th.panel2), 6)
            if sel then ui.rect(bx, by, cell, cell + 18, th.accent, 6, 'line') end
            local ix, iy, is = bx + 12, by + 8, cell - 24
            if it.def then
                drawTileThumb(it.def, ix, iy, is)
            elseif it.ent then
                drawImageFit(img(it.ent.editor and it.ent.editor.sprite or ''), ix, iy, is, is)
            elseif it.icon then
                drawImageFit(img(it.icon), ix, iy, is, is)
            end
            ui.text(it.label, bx + 2, by + cell - 6, th.text, ui.fontSm, cell - 4, 'center')
            if hov then
                local tip = it.label
                if it.def then
                    local d = it.def
                    tip = string.format('%s  (id %d)\nColision: %s%s\nMaterial: %s', d.label, d.id, d.collision,
                        d.dropThrough and ' (se baja agachado)' or '', d.mat.label)
                elseif it.ent then
                    tip = it.ent.label .. ' — ' .. it.ent.category
                end
                ui.tooltip(tip)
                if ui.state.pressed then
                    E.palette[L] = it.key; ui.state.consumed = true
                    if L == 'entities' then E.tool.entities = 'place' end
                    if L == 'tiles' and (E.tool.tiles == 'erase' or E.tool.tiles == 'pick') then E.tool.tiles = 'brush' end
                end
            end
        end
        yy = yy + math.ceil(#cats[c] / cols) * (cell + 18 + gap)
    end
    ui.endScroll()
end

-- Inspector de entidad: generado a partir de su esquema de propiedades
local function drawInspector(x, y, w)
    local e = E.selected
    local t = ET.get(e.type)
    y = sectionTitle('Entidad seleccionada', x, y, w)
    ui.rect(x, y, 48, 48, th.panel2, 6)
    drawImageFit(img(t.editor and t.editor.sprite or ''), x + 6, y + 6, 36, 36, e.props.attach == 'ceiling')
    ui.text(t.label, x + 58, y + 4, th.text, ui.fontLg)
    ui.text(string.format('%s · col %d, fila %d', t.category, e.col, e.row), x + 58, y + 28, th.muted, ui.fontSm)
    y = y + 58
    if ui.button('Duplicar (Ctrl+D)', x, y, (w - 6) / 2, 26, { font = ui.fontSm }) then Editor.duplicate() end
    if ui.button('Eliminar (Supr)', x + (w + 6) / 2, y, (w - 6) / 2, 26, { font = ui.fontSm, textColor = th.danger }) then Editor.deleteSelected() end
    y = y + 36

    local lastGroup
    for _, p in ipairs(t.schema) do
        if not p.showIf or p.showIf(e.props) then
            if p.group ~= lastGroup then
                lastGroup = p.group
                ui.text(p.group or 'General', x, y + 2, th.accent, ui.fontSm); y = y + 20
            end
            local v = e.props[p.key]
            local nv, ch
            if p.kind == 'bool' then
                nv, ch = ui.toggle(p.label, v, x, y, w); y = y + 28
            elseif p.kind == 'int' or p.kind == 'number' then
                nv, ch = ui.number(p.label, v, x, y, w, p); y = y + 28
            elseif p.kind == 'enum' then
                nv, ch = ui.enum(p.label, v, p.options, x, y, w); y = y + ui.ENUM_H + 4
            elseif p.kind == 'text' then
                ui.text(p.label, x, y + 2, th.text); y = y + 20
                nv, ch = ui.textField('prop_' .. p.key, v or '', x, y, w, p.maxLen); y = y + 32
            elseif p.kind == 'patrol' then
                local on, tch = ui.toggle(p.label, v ~= false, x, y, w); y = y + 28
                if tch then
                    nv, ch = on and { left = e.col - 3, right = e.col + 3 } or false, true
                elseif v then
                    local l, lch = ui.number('   Limite izq. (col)', v.left, x, y, w, { kind = 'int', min = 1, max = v.right }); y = y + 28
                    local r, rch = ui.number('   Limite der. (col)', v.right, x, y, w, { kind = 'int', min = v.left, max = E.model.width }); y = y + 28
                    if lch or rch then nv, ch = { left = l, right = r }, true end
                    ui.text('Arrastra las cajitas azules en el mapa.', x, y, th.muted, ui.fontSm, w); y = y + 18
                end
            elseif p.kind == 'point' then
                ui.text(p.label .. string.format(': (%d, %d)', v.col, v.row), x, y + 4, th.text); y = y + 26
            end
            if ch then pushUndo(); e.props[p.key] = nv; markDirty() end
            if p.help and ui.inside(x, y - 28, w, 28) then ui.tooltip(p.help) end
        end
    end
    return y + 8
end

local function drawRightPanel()
    local sw, sh = love.graphics.getDimensions()
    local x0 = sw - RIGHT
    ui.rect(x0, TOP, RIGHT, sh - TOP - STATUS, th.panel, 0)
    ui.rect(x0, TOP, 1, sh - TOP - STATUS, th.border, 0)
    local x, w = x0 + 12, RIGHT - 24
    local areaH = sh - TOP - STATUS
    local yy = ui.beginScroll('right', x0, TOP, RIGHT, areaH, E.rightH or areaH)
    local y = yy + 10

    if E.selected and E.layer == 'entities' then
        y = drawInspector(x, y, w)
    else
        y = sectionTitle('Celda', x, y, w)
        local hv = E.hover
        if hv and E.model:inBounds(hv.c, hv.r) then
            local raw = E.model:get(hv.c, hv.r)
            local id, wl, sp = Codec.decode(raw)
            local d = TT.get(id)
            ui.rect(x, y, 48, 48, th.panel2, 6); drawTileThumb(d, x + 4, y + 4, 40)
            ui.text(string.format('%s  (id %d)', d.label, id), x + 58, y + 2, th.text)
            ui.text(string.format('col %d, fila %d', hv.c, hv.r), x + 58, y + 22, th.muted, ui.fontSm)
            y = y + 56
            ui.text('Colision: ' .. d.collision .. (d.dropThrough and ' (traspasable)' or ''), x, y, th.muted, ui.fontSm); y = y + 16
            ui.text('Material: ' .. d.mat.label .. (wl and '  ·  con agua' or ''), x, y, th.muted, ui.fontSm); y = y + 16
            local ns = 0; for i = 1, 4 do if sp[i].present then ns = ns + 1 end end
            if ns > 0 then ui.text('Pinchos: ' .. ns, x, y, th.muted, ui.fontSm); y = y + 16 end
        else
            ui.text('Pasa el cursor por el mapa.', x, y, th.muted, ui.fontSm); y = y + 20
        end
        if E.layer == 'entities' then
            ui.text('Usa Seleccionar (V) y haz clic en una entidad para editar sus propiedades.', x, y + 6, th.muted, ui.fontSm, w)
            y = y + 40
        end
        y = y + 8
    end

    -- Nivel
    y = sectionTitle('Nivel', x, y, w)
    ui.text('Nombre', x, y + 4, th.text)
    local nm, nch = ui.textField('lvl_name', E.model.name or '', x + 70, y, w - 70, 40)
    if nch then E.model.name = nm; E.unsaved = true end
    y = y + 34
    E.newW = E.newW or E.model.width
    E.newH = E.newH or E.model.height
    E.newW = ui.number('Ancho (tiles)', E.newW, x, y, w, { kind = 'int', min = 8, max = 400 }); y = y + 28
    E.newH = ui.number('Alto (tiles)', E.newH, x, y, w, { kind = 'int', min = 6, max = 200 }); y = y + 30
    local changedSize = E.newW ~= E.model.width or E.newH ~= E.model.height
    if ui.button('Aplicar tamano', x, y, (w - 6) / 2, 26, { disabled = not changedSize, font = ui.fontSm }) and changedSize then
        pushUndo(); E.model:resize(E.newW, E.newH); markDirty(); msg('Tamano cambiado a ' .. E.newW .. 'x' .. E.newH)
    end
    if ui.button('Enmarcar con borde', x + (w + 6) / 2, y, (w - 6) / 2, 26, { font = ui.fontSm, tooltip = 'Rodea el mapa con el bloque Borde' }) then
        pushUndo(); E.model:frame(TILE_BORDER); markDirty()
    end
    y = y + 38

    -- Avisos
    y = sectionTitle('Avisos', x, y, w)
    local ws = E.warnings or {}
    if #ws == 0 then ui.text('Todo correcto.', x, y, th.ok, ui.fontSm); y = y + 20 end
    for _, wn in ipairs(ws) do
        local col = (wn[1] == 'error' and th.danger) or (wn[1] == 'warn' and th.warn) or th.muted
        local _, lines = ui.fontSm:getWrap(wn[2], w - 14)
        local hgt = #lines * ui.fontSm:getHeight() + 6
        if ui.inside(x, y, w, hgt) then
            ui.rect(x - 4, y - 2, w + 8, hgt, th.hover, 4)
            if wn[3] and ui.state.pressed then
                E.layer, E.tool.entities, E.selected = 'entities', 'select', wn[3]
                Editor.centerOn(wn[3].col, wn[3].row)
            end
        end
        ui.rect(x, y + 4, 6, 6, col, 3)
        ui.text(wn[2], x + 14, y, col, ui.fontSm, w - 14)
        y = y + hgt
    end
    y = y + 10

    -- Ayuda
    y = sectionTitle('Atajos', x, y, w)
    local help = 'Rueda: zoom · Clic central / Espacio+arrastrar: mover vista\nFlechas: mover vista · 1-6: capas\nB R L F E I V: herramientas\nClic derecho: borrar · Ctrl+Z / Ctrl+Y\nCtrl+S guardar · F5 probar · F10 volver'
    ui.text(help, x, y, th.muted, ui.fontSm, w)
    local _, hl = ui.fontSm:getWrap(help, w)
    y = y + #hl * ui.fontSm:getHeight() + 16

    E.rightH = y - yy
    ui.endScroll()
end

local function drawStatus()
    local sw, sh = love.graphics.getDimensions()
    ui.rect(0, sh - STATUS, sw, STATUS, th.panel, 0)
    ui.rect(0, sh - STATUS, sw, 1, th.border, 0)
    local parts = { layerDef(E.layer).label .. ' · ' .. TOOLS[E.tool[E.layer]].label }
    if E.hover then
        parts[#parts+1] = string.format('col %d  fila %d', E.hover.c, E.hover.r)
        local raw = E.model:get(E.hover.c, E.hover.r)
        if raw then parts[#parts+1] = TT.get(Codec.id(raw)).label end
    end
    parts[#parts+1] = string.format('%dx%d', E.model.width, E.model.height)
    parts[#parts+1] = #E.model.entities .. ' entidades'
    ui.text(table.concat(parts, '    '), 10, sh - STATUS + 6, th.muted, ui.fontSm)
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
    if md.kind == 'open' then h = math.min(sh - 120, 120 + #md.files * 34) end
    local x, y = (sw - w) / 2, (sh - h) / 2
    ui.rect(x, y, w, h, th.panel, 8)
    ui.rect(x, y, w, h, th.border, 8, 'line')
    local close = function() E.modal = nil end

    if md.kind == 'confirm' then
        ui.text('Atencion', x + 20, y + 16, th.warn, ui.fontLg)
        ui.text(md.text, x + 20, y + 52, th.text, ui.font, w - 40)
        if ui.button('Descartar cambios', x + w - 290, y + h - 50, 160, 32, { textColor = th.danger }) then E.modal = nil; md.onYes() end
        if ui.button('Cancelar', x + w - 120, y + h - 50, 100, 32) then close() end
    elseif md.kind == 'open' then
        ui.text('Abrir nivel', x + 20, y + 16, th.text, ui.fontLg)
        local yy = y + 56
        for _, f in ipairs(md.files) do
            if ui.button(f, x + 20, yy, w - 40, 28, { align = 'left' }) then
                local m, err = Model.load(f)
                if m then E.modal = nil; setModel(m, f) else msg(err, 'error') end
            end
            yy = yy + 34
        end
        if #md.files == 0 then ui.text('No hay niveles en ' .. LEVELS_DIR, x + 20, yy, th.muted) end
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
    elseif md.kind == 'new' then
        ui.text('Nivel nuevo', x + 20, y + 16, th.text, ui.fontLg)
        md.w = ui.number('Ancho (tiles)', md.w, x + 20, y + 60, w - 40, { kind = 'int', min = 8, max = 400 })
        md.h = ui.number('Alto (tiles)', md.h, x + 20, y + 92, w - 40, { kind = 'int', min = 6, max = 200 })
        if ui.button('Crear', x + w - 230, y + h - 50, 100, 32) then
            E.modal = nil; setModel(Model.new(md.w, md.h, 'nuevo'), nil)
            E.newW, E.newH = md.w, md.h
        end
        if ui.button('Cancelar', x + w - 120, y + h - 50, 100, 32) then close() end
    end
    ui.state.consumed = true
end

-- ── API usada por paneles ─────────────────────────────────────────────────────
function Editor.centerOn(c, r)
    local _, _, cw, ch = canvasRect()
    E.camX = (c - 0.5) * T() - cw / 2 / E.zoom
    E.camY = (r - 0.5) * T() - ch / 2 / E.zoom
end

function Editor.deleteSelected()
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
    E.palette = { tiles = TILE_SOLID, entities = ET.list[1] and ET.list[1].name, deco = Level.FOLIAGE_TYPES[1].name }
    E.spikeDir = 0
    E.grid, E.showRoutes = true, true
    E.msgT = 0
    local path = levelArg or 'assets/levels/nivel01.json'
    local m, err = Model.load(path)
    if m then setModel(m, path) else setModel(Model.new(30, 15, 'nuevo'), nil); msg(err, 'error') end
end

function Editor.update(dt)
    if E.levelDirty then rebuild() end
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
    elseif k == 'x' then E.spikeDir = (E.spikeDir + 1) % 4
    elseif k == 'delete' or k == 'backspace' then Editor.deleteSelected()
    elseif k == 'escape' then E.selected = nil
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
