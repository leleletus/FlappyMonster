-- src/editor/AnimEditor.lua
-- EDITOR DE ANIMACIONES:   love . --anim [id]
-- Crea y cambia los conjuntos de animación del juego (assets/anim/<id>.json; formato y uso en src/fx/Anim.lua).
-- Están TODOS los dibujos del juego: enemigos, jefes, jugador, objetos, trampas, decoraciones, tiles, efectos,
-- interfaz. "Abrir…" los enseña por grupos, con su miniatura y un buscador. El trabajo se hace en la pieza
-- src/editor/AnimPanel.lua (la misma que lleva el editor de enemigos).
local ui        = require 'src/editor/ui'
local Shell     = require 'src/editor/ToolShell'
local Anim      = require 'src/fx/Anim'
local AnimPanel = require 'src/editor/AnimPanel'
local th = ui.theme

local A = { id = nil, doc = nil, panel = AnimPanel.new(), unsaved = false, list = {}, newId = '', browse = false,
            group = nil, search = '', thumbs = {} }
A.ORDER = { 'id', 'label', 'strip', 'timing', 'scale', 'origin', 'fallback', 'meta', 'frames', 'anims', 'variants' }
-- Grupos del explorador: { prefijo del id, nombre }. El primero que casa manda.
A.GROUPS = {
    { 'enemies/', 'Enemigos' }, { 'bosses/', 'Jefes' }, { 'player', 'Jugador' }, { 'items', 'Objetos' },
    { 'traps', 'Trampas' }, { 'mechanisms', 'Mecanismos' }, { 'world/decorations', 'Decoraciones' },
    { 'world/tiles', 'Tiles (bloques)' }, { 'world', 'Mundo (cielo, agua…)' }, { 'fx', 'Efectos' }, { 'ui', 'Interfaz' },
    { 'story', 'Historia y mapa' }, { 'flappy', 'Modo Flappy' }, { '', 'Otros (enemigos del editor…)' },
}
local function groupOf(id)
    for i, g in ipairs(A.GROUPS) do
        if g[1] == '' or id:sub(1, #g[1]) == g[1] then return i end
    end
    return #A.GROUPS
end

local function refresh() A.list = Anim.list() end

A.hist = Shell.history(function() return A.doc or {} end, function(d) A.doc = d; A.panel:touch(); A.unsaved = true end)

function A.open(id)
    local data = Anim.read(id)
    if not data then return Shell.message('No se puede abrir ' .. id, 'error') end
    data.id = id
    A.id, A.doc, A.unsaved, A.browse = id, data, false, false
    A.panel = AnimPanel.new()
    A.hist:reset()
end

function A.new(id)
    if not id:match('^[%l][%l%d_/]*$') then return Shell.message('El nombre solo puede llevar minúsculas, números, _ y / (carpetas)', 'error') end
    if love.filesystem.getInfo(Anim.path(id)) then return Shell.message('Ya existe un conjunto "' .. id .. '"', 'error') end
    A.id, A.doc, A.unsaved, A.browse = id, { id = id, scale = 4, origin = { 0.5, 1 }, frames = {}, anims = {} }, true, false
    A.panel = AnimPanel.new()
    A.hist:reset()
end

-- Guarda un conjunto (también lo usa el editor de enemigos)
function A.write(doc)
    local ok, err = Shell.writeRepo(Anim.path(doc.id), Shell.encodeJson(doc, A.ORDER))
    if ok then
        Anim.reload(doc.id)
        require('src/fx/SpriteStrip').forget()
    end
    return ok, err
end

function A.save()
    if not A.doc then return end
    -- (las carpetas del id tienen que existir)
    local dir = Anim.path(A.id):match('^(.*)/[^/]+$')
    local src = love.filesystem.getSource()
    if src and not src:match('%.love$') then os.execute('mkdir -p "' .. src .. '/' .. dir .. '"') end
    local ok, err = A.write(A.doc)
    if not ok then return Shell.message('No se pudo guardar: ' .. tostring(err), 'error') end
    A.unsaved = false
    A.thumbs[A.id] = nil
    refresh()
    Shell.message('Guardado ' .. Anim.path(A.id) .. ' — el juego lo usará la próxima vez que se abra')
end

local function load(args)
    refresh()
    local want
    for i, a in ipairs(arg or {}) do if a == '--anim' then want = arg[i + 1] end end
    if want and not want:match('^%-') then
        if love.filesystem.getInfo(Anim.path(want)) then A.open(want) else A.new(want) end
    else
        A.browse = true
    end
end

-- Miniatura de un conjunto (se cargan unas pocas por fotograma)
local loadedThisFrame = 0
local function thumbOf(id)
    local t = A.thumbs[id]
    if t == nil and loadedThisFrame < 4 then
        loadedThisFrame = loadedThisFrame + 1
        local data = Anim.read(id)
        t = data and Anim.fromData(data) or false
        A.thumbs[id] = t
    end
    return t or nil
end

-- El explorador: grupos a la izquierda, tarjetas con miniatura a la derecha, buscador arriba
local function drawBrowser(W, H)
    loadedThisFrame = 0
    local x, y, w, h = 40, 60, W - 80, H - 110
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle('fill', 0, 0, W, H)
    ui.rect(x, y, w, h, th.panel, 8); ui.rect(x, y, w, h, th.border, 8, 'line')
    ui.text('Abrir un conjunto de animación', x + 18, y + 14, th.text, ui.fontLg)
    A.search = ui.textField('animbrowse', A.search, x + 340, y + 12, 320, 40, 'Buscar por nombre…')
    if A.doc and ui.button('Cerrar', x + w - 100, y + 12, 84, 28) then A.browse = false end
    -- grupos
    local counts = {}
    for _, id in ipairs(A.list) do local g = groupOf(id); counts[g] = (counts[g] or 0) + 1 end
    local gx, gy, gw = x + 14, y + 56, 230
    if ui.button('Todos', gx, gy, gw, 28, { align = 'left', active = A.group == nil, hint = tostring(#A.list) }) then A.group = nil end
    gy = gy + 32
    for i, g in ipairs(A.GROUPS) do
        if counts[i] then
            if ui.button(g[2], gx, gy, gw, 28, { align = 'left', active = A.group == i, hint = tostring(counts[i]) }) then A.group = i end
            gy = gy + 32
        end
    end
    ui.hint('"Lo usa el juego": puedes cambiar sus dibujos y verlo moverse; el orden de los cuadros lo fija el código.\n"Completo": todo se decide aquí (orden, velocidad, animaciones).', gx, gy + 10, gw)
    -- tarjetas
    local shown = {}
    local q = A.search:lower()
    for _, id in ipairs(A.list) do
        if (A.group == nil or groupOf(id) == A.group) and (q == '' or id:lower():find(q, 1, true)) then shown[#shown + 1] = id end
    end
    local cx0, cy0, cwid, chh = x + gw + 30, y + 56, w - gw - 44, h - 70
    local CW, CH = 168, 150
    local per = math.max(1, math.floor(cwid / (CW + 8)))
    local sy = ui.beginScroll('animbrowsegrid', cx0, cy0, cwid, chh, math.ceil(#shown / per) * (CH + 8))
    for i, id in ipairs(shown) do
        local tx = cx0 + ((i - 1) % per) * (CW + 8)
        local ty = sy + math.floor((i - 1) / per) * (CH + 8)
        if ty > cy0 - CH and ty < cy0 + chh then
            local hov = ui.inside(tx, ty, CW, CH) and ui.inside(cx0, cy0, cwid, chh)
            ui.rect(tx, ty, CW, CH, (id == A.id) and th.accentDk or (hov and th.hover or th.panel2), 6)
            ui.rect(tx + 6, ty + 6, CW - 12, 86, th.canvas, 4)
            local set = thumbOf(id)
            local code = false
            if set and #set.frames > 0 then
                local fi = set:frameAt(set.fallback, love.timer.getTime())
                AnimPanel.thumb(set, fi, tx + 10, ty + 10, CW - 20, 78)
                code = set.data.meta and set.data.meta.code
            end
            local name = id:match('([^/]+)$')
            ui.label(name, tx + 8, ty + 96, CW - 16, th.text)
            ui.label(id:match('^(.*)/[^/]+$') or '', tx + 8, ty + 114, CW - 16, th.muted)
            if set then ui.text(code and 'lo usa el juego' or 'completo', tx + 8, ty + 131, code and th.warn or th.ok, ui.fontSm) end
            if hov and ui.state.pressed then ui.state.consumed = true; A.open(id); ui.endScroll(); return end
        end
    end
    ui.endScroll()
    if #shown == 0 then ui.text('Nada con ese nombre.', cx0 + 10, cy0 + 20, th.muted) end
end

local function draw()
    local W, H = love.graphics.getDimensions()
    ui.rect(0, 0, W, 46, th.panel, 0)
    ui.text('Animaciones', 14, 12, th.text, ui.fontLg)
    local x = 150
    if ui.button('Abrir', x, 9, 120, 28, { hint = 'Ctrl+O', tooltip = 'Todos los dibujos del juego, por grupos' }) then A.browse = true end
    x = x + 128
    ui.label(A.id and ('editando:  ' .. A.id) or 'nada abierto', x, 12, 300, A.id and th.text or th.muted)
    x = x + 310
    if ui.button('Guardar', x, 9, 132, 28, { hint = 'Ctrl+S', color = A.unsaved and th.accentDk or nil, disabled = not A.doc }) then A.save() end
    x = x + 140
    if ui.button('Deshacer', x, 9, 120, 28, { hint = 'Ctrl+Z', disabled = #A.hist.stack == 0 }) then A.hist:undo() end
    x = x + 128
    A.newId = ui.textField('animeditnew', A.newId, x, 10, 190, 40, 'nombre de uno nuevo…')
    if ui.button('+ Nuevo', x + 196, 9, 80, 28, { disabled = A.newId == '' }) then A.new(A.newId); A.newId = '' end
    if A.unsaved then ui.text('* sin guardar', W - 110, 15, th.warn) end
    if A.doc then
        local blocked = A.browse
        local sp = ui.state.pressed
        if blocked then ui.state.pressed = false end
        if A.panel:draw(A.doc, 8, 54, W - 16, H - 54 - 34) then A.unsaved = true; A.hist:record() end
        if blocked then ui.state.pressed = sp end
    end
    if A.browse then drawBrowser(W, H) end
end

local function keypressed(k)
    if ui.hasFocus() then return end
    local ctrl = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    local shift = love.keyboard.isDown('lshift', 'rshift')
    if ctrl and k == 's' then return A.save() end
    if ctrl and k == 'o' then A.browse = true; return end
    if ctrl and k == 'z' then if shift then A.hist:redo() else A.hist:undo() end; return end
    if ctrl and k == 'y' then A.hist:redo(); return end
    if k == 'escape' and A.doc then A.browse = false end
    if not A.browse then A.panel:keypressed(k) end
end

function A.install()
    Shell.install({ title = 'Editor de animaciones', load = load, draw = draw, keypressed = keypressed,
                    unsaved = function() return A.unsaved end,
                    status = function() return 'Ctrl+O: abrir  ·  Ctrl+S: guardar  ·  Ctrl+Z / Ctrl+Y: deshacer / rehacer  ·  Espacio: reproducir / pausa  ·  , .: cuadro anterior / siguiente' end })
end

return A
