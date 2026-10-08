-- src/editor/AnimEditor.lua
-- EDITOR DE ANIMACIONES:   love . --anim [id]
-- Crea y cambia los conjuntos de animación del juego (assets/anim/<id>.json; formato y uso en src/fx/Anim.lua):
-- de qué imágenes salen los cuadros, qué secuencias hay (quieto, andar, ataque…), su velocidad, sus variantes.
-- Todo lo que se ve en el centro es la pieza src/editor/AnimPanel.lua (la misma que lleva el editor de enemigos).
-- Sirve para cualquier cosa animada: sprites de enemigos, objetos, tiles, efectos.
local ui        = require 'src/editor/ui'
local Shell     = require 'src/editor/ToolShell'
local Anim      = require 'src/fx/Anim'
local AnimPanel = require 'src/editor/AnimPanel'
local th = ui.theme

local A = { id = nil, doc = nil, panel = AnimPanel.new(), unsaved = false, list = {}, newId = '', picking = false }
A.ORDER = { 'id', 'scale', 'origin', 'fallback', 'frames', 'anims', 'variants' }

local function refresh() A.list = Anim.list() end

function A.open(id)
    local data = Anim.read(id)
    if not data then return Shell.message('No se puede abrir ' .. id, 'error') end
    data.id = id
    A.id, A.doc, A.unsaved = id, data, false
    A.panel = AnimPanel.new()
end

function A.new(id)
    if not id:match('^[%l][%l%d_]*$') then return Shell.message('El nombre solo puede llevar minúsculas, números y _', 'error') end
    if love.filesystem.getInfo(Anim.path(id)) then return Shell.message('Ya existe un conjunto "' .. id .. '"', 'error') end
    A.id, A.doc, A.unsaved = id, { id = id, scale = 4, origin = { 0.5, 1 }, frames = {}, anims = {} }, true
    A.panel = AnimPanel.new()
end

-- Guarda un conjunto (también lo usa el editor de enemigos)
function A.write(doc)
    local ok, err = Shell.writeRepo(Anim.path(doc.id), Shell.encodeJson(doc, A.ORDER))
    if ok then Anim.reload(doc.id) end
    return ok, err
end

function A.save()
    if not A.doc then return end
    local ok, err = A.write(A.doc)
    if not ok then return Shell.message('No se pudo guardar: ' .. tostring(err), 'error') end
    A.unsaved = false
    refresh()
    Shell.message('Guardado ' .. Anim.path(A.id))
end

local function load(args)
    refresh()
    local want
    for i, a in ipairs(arg or {}) do if a == '--anim' then want = arg[i + 1] end end
    if want and not want:match('^%-') then
        if love.filesystem.getInfo(Anim.path(want)) then A.open(want) else A.new(want) end
    elseif A.list[1] then A.open(A.list[1]) end
end

local function draw()
    local W, H = love.graphics.getDimensions()
    ui.rect(0, 0, W, 46, th.panel, 0)
    ui.text('Animaciones', 14, 12, th.text, ui.fontLg)
    local x = 150
    if ui.button((A.id or '(ninguno)') .. '   v', x, 9, 220, 28, { align = 'left', tooltip = 'Abrir otro conjunto' }) then A.picking = not A.picking end
    x = x + 230
    if ui.button('Guardar', x, 9, 132, 28, { hint = 'Ctrl+S', color = A.unsaved and th.accentDk or nil, disabled = not A.doc }) then A.save() end
    x = x + 142
    A.newId = ui.textField('animeditnew', A.newId, x, 10, 170, 32, 'conjunto nuevo…')
    if ui.button('+ Nuevo', x + 176, 9, 80, 28, { disabled = A.newId == '' }) then A.new(A.newId); A.newId = '' end
    if A.unsaved then ui.text('* sin guardar', W - 130, 15, th.warn) end
    if A.doc then
        if A.panel:draw(A.doc, 8, 54, W - 16, H - 54 - 34) then A.unsaved = true end
    else
        ui.hint('No hay ningún conjunto abierto. Escribe un nombre arriba y pulsa "+ Nuevo".', 20, 70, 520)
    end
    if A.picking then
        local lh = math.min(#A.list * 26 + 12, H - 120)
        ui.rect(150, 40, 300, lh, th.panel2, 6); ui.rect(150, 40, 300, lh, th.border, 6, 'line')
        local y = ui.beginScroll('animeditlist', 150, 44, 300, lh - 8, #A.list * 26)
        for _, id in ipairs(A.list) do
            if ui.button(id, 156, y, 284, 24, { align = 'left', active = id == A.id }) then A.open(id); A.picking = false end
            y = y + 26
        end
        ui.endScroll()
    end
end

local function keypressed(k)
    if ui.hasFocus() then return end
    local ctrl = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    if ctrl and k == 's' then return A.save() end
    if k == 'escape' then A.picking = false end
    A.panel:keypressed(k)
end

function A.install()
    Shell.install({ title = 'Editor de animaciones', load = load, draw = draw, keypressed = keypressed,
                    unsaved = function() return A.unsaved end,
                    status = function() return 'Espacio: reproducir / pausa  ·  , .: cuadro anterior / siguiente  ·  rueda sobre la vista: zoom  ·  Ctrl+S: guardar' end })
end

return A
