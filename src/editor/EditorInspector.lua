-- src/editor/EditorInspector.lua
-- PARTE de src/editor/Editor.lua: el panel derecho — campos generados desde un esquema de props, inspectores y las pestañas Selección / Nivel / Avisos.
-- La carga Editor.lua con require(...)(E, P): añade sus funciones a la tabla E. P = lo que
-- antes eran locales del archivo y comparten las partes.
local ui       = require 'src/editor/ui'
local DT       = require('src/world/decorations/Decorations').types
local SpikeSkins = require 'src/world/level/SpikeSkins'
local Sky      = require 'src/fx/Sky'
local BossZones = require 'src/world/systems/BossZones'
local AutoScroll = require 'src/world/systems/AutoScroll'
local Modes     = require 'src/world/modes/Modes'
local Music     = require 'src/audio/Music'

return function(E, P)
local TT, ET, Codec, th, Editor, STATUS = P.TT, P.ET, P.Codec, P.th, P.Editor, P.STATUS
local TOP, RIGHT, TOOLS, layerDef, msg, drawEntThumb = P.TOP, P.RIGHT, P.TOOLS, P.layerDef, P.msg, P.drawEntThumb
local drawTileThumb, drawDecoThumb, markDirty, pushUndo = P.drawTileThumb, P.drawDecoThumb, P.markDirty, P.pushUndo

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
-- Bloque ON/OFF (herramienta Conectar): a qué inundación está conectado
local function drawSwitchInspector(x, y, w)
    local sw, m = E.selSwitch, E.model
    local d = TT.get(Codec.id(m:get(sw.c, sw.r) or 0))
    if d.name ~= 'switch_on' and d.name ~= 'switch_off' then E.selSwitch = nil; return y end
    y = inspectorHeader(x, y, w, function(ix, iy, s) drawTileThumb(d, ix, iy, s) end, 'Bloque ON/OFF',
                        string.format('Mecanismo  ·  col %d, fila %d', sw.c, sw.r),
                        'Un cabezazo o un ground pound lo cambia. Enciende y apaga los objetos conectados (p. ej. una inundación: en ON sube al máximo, en OFF baja al mínimo). Al borrar el bloque, su conexión se va con él.')
    local l = m:linkAt(sw.c, sw.r)
    local cur = l and l.to or 0
    local opts = { { value = 0, label = 'Nada' } }
    local found = cur == 0
    for _, e in ipairs(m:activatables()) do
        local t, id = ET.get(e.type), tonumber(e.props.id) or 1
        if id == cur then found = true end
        opts[#opts + 1] = { value = id, label = string.format('%s #%d (col %d, fila %d)%s', t.label, id, e.col, e.row,
                            (e.type == 'flood' and e.props.control ~= 'switch') and ' — no usa ON/OFF' or '') }
    end
    if not found then opts[#opts + 1] = { value = cur, label = '#' .. cur .. ' (ya no existe)' } end
    local nb = 0
    for _, bl in ipairs(m.blockLinks or {}) do if bl.from[1] == sw.c and bl.from[2] == sw.r then nb = nb + 1 end end
    local hintTxt = string.format('Bloques ON/OFF conectados: %d. Con este activador elegido, haz clic (o arrastra) en Bloques ON/OFF para conectarlos o desconectarlos. Los que no tienen conexión siguen al activador más cercano.', nb)
    y = y + ui.hint(hintTxt, x, y, w) + 8
    ui.text('Objeto conectado', x, y, th.text); y = y + 20
    for _, o in ipairs(opts) do
        if ui.button(o.label, x, y, w, 26, { active = o.value == cur, align = 'left', font = ui.fontSm }) and o.value ~= cur then
            pushUndo()
            m:setLink(sw.c, sw.r, o.value > 0 and o.value or nil)
            -- (el objeto conectado se prepara para ello: la inundación pasa a moverse con bloques ON/OFF)
            local e = o.value > 0 and m:activatableById(o.value)
            local t = e and ET.get(e.type)
            if t and t.onLink then t.onLink(e.props) end
            markDirty()
        end
        y = y + 30
    end
    if l then
        if ui.button('Quitar conexión', x, y, w, 26, { font = ui.fontSm, textColor = th.danger }) then
            pushUndo(); m:setLink(sw.c, sw.r, nil); markDirty()
        end
        y = y + 32
    end
    y = y + 6
    local on, ch = ui.toggle('Empieza encendido (ON)', d.name == 'switch_on', x, y, w)
    if ch then
        pushUndo()
        m:setId(sw.c, sw.r, TT.byName[on and 'switch_on' or 'switch_off'].id)
        markDirty()
    end
    return y + 32
end

local function drawSelectionTab(x, y, w)
    if E.selSwitch and E.layer == 'tiles' then return drawSwitchInspector(x, y, w)
    elseif E.selVent and E.layer == 'special' then return drawVentInspector(x, y, w)
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
        y = y + 32
        ui.text('Inglés', x, y + 6, th.text)
        local ne, nech = ui.textField('lvl_name_en', m.name_en or '', x + 70, y, w - 70, 40, 'Nombre en inglés (si no, el de arriba)')
        if nech then m.name_en = (ne ~= '') and ne or nil; E.unsaved = true end
        y = y + 34
        -- TIEMPO OBJETIVO (la nota del modo historia): 0 = automático (0,75 s por casilla de ancho, mínimo 40 s)
        do
            local auto = math.max(40, math.floor(m.width * 0.75 + 0.5))
            local pv, pch = ui.number('Tiempo objetivo (s)', m.parTime or 0, x, y, w,
                { kind = 'int', min = 0, max = 3600, step = 10,
                  help = 'Hasta ese tiempo, la parte de tiempo de la nota va entera; baja hasta 0 al triple. 0 = automático (' .. auto .. ' s para este ancho)' })
            if pch then pushUndo(); m.parTime = (pv > 0) and pv or nil; markDirty() end
            y = y + 28
            y = y + ui.hint('Cuánto se tarda en pasarlo jugando bien. Los niveles largos (laberintos) necesitan el suyo. Ahora: '
                            .. ((m.parTime and (m.parTime .. ' s')) or ('automático, ' .. auto .. ' s')), x, y, w, th.border) + 6
        end
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
    -- Fondo y clima (solo visual): bioma del fondo con paralaje, hora del día, nubes, nieve
    local bg, tm = Sky.byId[m.background or Sky.DEFAULT], Sky.timeById[m.time or 'day']
    y, open = ui.section('lvl:weather', 'Fondo y clima', x, y, w, bg.label .. ' · ' .. tm.label)
    if open then
        local opts = {}
        for _, b in ipairs(Sky.BIOMES) do if not b.onlyDepth then opts[#opts + 1] = { value = b.id, label = b.label } end end
        local v, ch = ui.enum('Superficie', bg.id, opts, x, y, w)
        y = y + ui.ENUM_H
        if ch then pushUndo(); m.background = (v ~= Sky.DEFAULT) and v or nil; markDirty() end
        local topts = {}
        for _, t in ipairs(Sky.TIMES) do topts[#topts + 1] = { value = t.id, label = t.label } end
        v, ch = ui.enum('Hora', tm.id, topts, x, y, w)
        y = y + ui.ENUM_H
        if ch then pushUndo(); m.time = (v ~= 'day') and v or nil; markDirty() end
        if bg.sky then
            v, ch = ui.toggle('Nubes', m.clouds ~= false, x, y, w)
            y = y + 28
            if ch then pushUndo(); m.clouds = (not v) and false or nil; markDirty() end
        end
        local dopts = { { value = 'none', label = 'Ninguna' } }
        for _, b in ipairs(Sky.BIOMES) do if b.depth then dopts[#dopts + 1] = { value = b.id, label = b.label } end end
        v, ch = ui.enum('Profundidad', m.depth or 'none', dopts, x, y, w)
        y = y + ui.ENUM_H
        if ch then pushUndo(); m.depth = (v ~= 'none') and v or nil; markDirty() end
        do
            local auto = E.level and Sky.autoSurfaceRow(E.level) or 1
            v, ch = ui.number('Superficie: fila (0 = auto ' .. auto .. ')', m.surfaceRow or 0, x, y, w,
                              { kind = 'int', min = 0, max = m.height,
                                help = 'Fila donde se apoya el paisaje de la superficie (y donde empieza la profundidad). 0 = auto: 2 casillas por encima de la salida del jugador (sin profundidad, en auto el paisaje se apoya en el fondo del nivel). También: Alt + clic en el mapa.' })
            y = y + 30
            if ch then pushUndo(); m.surfaceRow = (v > 0) and v or nil; markDirty() end
        end
        y = y + ui.hint('Superficie: cielo y paisaje hasta la línea (azul en el mapa). Profundidad: el fondo de debajo (cuevas, fondo marino...). Capas con paralaje; de noche, luna y estrellas. Solo visual.', x, y, w, th.border) + 8
        local v, ch = ui.toggle('Nieve cayendo', m.snow == true, x, y, w)
        y = y + 28
        if ch then pushUndo(); m.snow = v or nil; markDirty() end
        y = y + ui.hint('Copos de nieve cayendo por todo el nivel. Solo es visual: no afecta al juego.', x, y, w, th.border) + 8
        v, ch = ui.toggle('A oscuras (linterna)', m.dark == true, x, y, w)
        y = y + 28
        if ch then pushUndo(); m.dark = v or nil; markDirty() end
        do
            local auto = require('src/world/level/Level').lightMood({ background = m.background, time = m.time })
            local names = { day = 'Día', dusk = 'Atardecer', night = 'Noche', cave = 'Cueva', none = 'Sin' }
            local lopts = { { value = 'auto', label = 'Auto (' .. names[auto] .. ')' } }
            for _, k in ipairs({ 'day', 'dusk', 'night', 'cave', 'none' }) do lopts[#lopts + 1] = { value = k, label = names[k] } end
            v, ch = ui.enum('Luz', m.light or 'auto', lopts, x, y, w)
            y = y + ui.ENUM_H
            if ch then pushUndo(); m.light = (v ~= 'auto') and v or nil; markDirty() end
            y = y + ui.hint('Luz ambiente (solo visual): atardecer cálido, noche fría y oscura con las antorchas brillando, cueva en penumbra con un halo alrededor del jugador. Lo que queda bajo la superficie (con profundidad) va en penumbra.', x, y, w, th.border) + 8
        end
        local autoEcho = m.dark == true or require('src/world/level/Level').lightMood({ background = m.background, time = m.time, light = m.light }) == 'cave'
        local echoOn = m.echo == true or (m.echo == nil and autoEcho)
        v, ch = ui.toggle('Eco (cueva profunda)', echoOn, x, y, w)
        y = y + 28
        if ch then pushUndo(); if v == autoEcho then m.echo = nil else m.echo = v end; markDirty() end
        y = y + ui.hint('Cueva sin luz: solo se ve lo que alumbra la linterna de cada jugador (se enciende y apaga; la batería se gasta y, si se agota, tarda en volver). AFECTA AL JUEGO: los Crabbies lúgubres huyen de la luz. En el editor el mapa se ve entero.', x, y, w, th.border) + 8
        local sopts = {}
        for _, sk in ipairs(SpikeSkins.LIST) do sopts[#sopts + 1] = { value = sk.id, label = sk.label } end
        v, ch = ui.enum('Pinchos', m.spikeSkin or 'normal', sopts, x, y, w)
        y = y + ui.ENUM_H
        if ch then pushUndo(); m.spikeSkin = (v ~= 'normal') and v or nil; markDirty() end
        y = y + ui.hint('Aspecto de todos los pinchos del nivel (los de las casillas y los que caen). Solo es visual.', x, y, w, th.border) + 8
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
        local pv, pch = ui.toggle('Enemigos inofensivos (prueba)', m.peaceful == true, x, y, w)
        y = y + 28
        if pch then pushUndo(); m.peaceful = pv or nil; markDirty() end
        y = y + ui.hint('Nivel de PRUEBA: tocar a los enemigos no hace daño (se les puede pisar igual). No sale en ningún modo online.', x, y, w, th.border) + 8
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
    return tostring(E.selected) .. tostring(E.selDeco) .. tostring(E.selZone) .. tostring(E.selVent) .. tostring(E.selSwitch)
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
        if E.selected or E.selDeco or E.selZone or E.selVent or E.selSwitch then E.rightTab = 'sel' end
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

P.drawRightPanel = drawRightPanel; P.drawStatus = drawStatus
end
