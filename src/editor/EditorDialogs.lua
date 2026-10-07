-- src/editor/EditorDialogs.lua
-- PARTE de src/editor/Editor.lua: los diálogos (abrir, guardar, confirmar) y las herramientas de zonas de jefe y cámara automática.
-- La carga Editor.lua con require(...)(E, P): añade sus funciones a la tabla E. P = lo que
-- antes eran locales del archivo y comparten las partes.
local ui       = require 'src/editor/ui'
local Model    = require 'src/editor/EditorModel'

return function(E, P)
local th, Editor, LEVELS_DIR, msg, setModel, save = P.th, P.Editor, P.LEVELS_DIR, P.msg, P.setModel, P.save

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

-- Conexiones bloque ON/OFF → objeto activable: línea de puntos amarilla del
-- bloque al objeto (al centro de su área si la tiene; roja si no existe)
function Editor.drawLinks(camX, camY, t, zoom)
    local m = E.model
    local byId = {}
    for _, f in ipairs(m:activatables()) do byId[tonumber(f.props.id) or 1] = f end
    love.graphics.setLineWidth(2 / zoom)
    for _, l in ipairs(m.links or {}) do
        local x0, y0 = (l.col - 0.5) * t - camX, (l.row - 0.5) * t - camY
        local f = byId[l.to]
        local sel = E.selSwitch and E.selSwitch.c == l.col and E.selSwitch.r == l.row
        if f then
            local cr = type(f.props.corner) == 'table' and f.props.corner or { col = f.col, row = f.row }
            local x1 = ((f.col - 1) + cr.col) / 2 * t - camX
            local y1 = ((f.row - 1) + cr.row) / 2 * t - camY
            love.graphics.setColor(1, 0.85, 0.2, sel and 1 or 0.6)
            local dx, dy = x1 - x0, y1 - y0
            local len = math.sqrt(dx * dx + dy * dy)
            for k = 0, len - 1, 14 / zoom do
                local a, b = k / len, math.min(1, (k + 7 / zoom) / len)
                love.graphics.line(x0 + dx * a, y0 + dy * a, x0 + dx * b, y0 + dy * b)
            end
            love.graphics.circle('fill', x1, y1, 4 / zoom)
        else
            love.graphics.setColor(1, 0.3, 0.3, 0.9)
        end
        love.graphics.rectangle('line', x0 - t / 2 + 2, y0 - t / 2 + 2, t - 4, t - 4)
        love.graphics.print('#' .. l.to, x0 - t / 2 + 4, y0 - t / 2 + 2, 0, 1 / zoom, 1 / zoom)
    end
    -- Bloques ON/OFF → su activador (cian: conectado; tenue: el más cercano)
    if E.layer == 'tiles' and E.tool.tiles == 'link' then
        for rr = 1, m.height do
            for cc = 1, m.width do
                if m:isSwitchBlock(cc, rr) then
                    local src, implicit = m:blockSource(cc, rr)
                    if src then
                        local sel = E.selSwitch and E.selSwitch.c == src[1] and E.selSwitch.r == src[2]
                        love.graphics.setColor(0.3, 0.9, 1, implicit and 0.25 or (sel and 0.95 or 0.6))
                        love.graphics.line((cc - 0.5) * t - camX, (rr - 0.5) * t - camY, (src[1] - 0.5) * t - camX, (src[2] - 0.5) * t - camY)
                    end
                end
            end
        end
    end
    if E.selSwitch and E.layer == 'tiles' then
        love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 1)
        love.graphics.rectangle('line', (E.selSwitch.c - 1) * t - camX, (E.selSwitch.r - 1) * t - camY, t, t)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
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

P.drawModal = drawModal
end
