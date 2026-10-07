-- src/editor/EditorPalette.lua
-- PARTE de src/editor/Editor.lua: la barra de arriba y el panel izquierdo (capa, herramienta, paleta con buscador).
-- La carga Editor.lua con require(...)(E, P): añade sus funciones a la tabla E. P = lo que
-- antes eran locales del archivo y comparten las partes.
local ui       = require 'src/editor/ui'
local DT       = require('src/world/decorations/Decorations').types
local SubTiles  = require 'src/world/level/SubTiles'

return function(E, P)
local TT, ET, th, LEFT, STATUS, TOP = P.TT, P.ET, P.th, P.LEFT, P.STATUS, P.TOP
local LAYERS, TOOLS, DIRS, layerDef, drawEntThumb, drawTileThumb = P.LAYERS, P.TOOLS, P.DIRS, P.layerDef, P.drawEntThumb, P.drawTileThumb
local drawDecoThumb, undo, redo, listLevels, guardUnsaved, save = P.drawDecoThumb, P.undo, P.redo, P.listLevels, P.guardUnsaved, P.save
local startPlay = P.startPlay

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
            if not t.editorHide then items[#items+1] = { key = t.id, label = t.label, cat = t.category, ord = TT.categoryOrder(t.category), def = t,
                                tip = string.format('%s\nColisión: %s%s · Material: %s', t.label,
                                      ({ solid = 'sólida', oneway = 'solo desde arriba', none = 'ninguna' })[t.collision] or t.collision,
                                      t.dropThrough and ' (se baja agachado)' or '', t.mat.label) } end
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
    elseif L == 'mini' then
        for _, k in ipairs(SubTiles.KINDS) do
            local t = TT.byName[k]
            if t then items[#items+1] = { key = k, label = t.label, cat = 'Mini bloques', ord = 1, def = t,
                                         tip = t.label .. ' (un cuarto de casilla)' } end
        end
    elseif L == 'deco' then
        for _, t in ipairs(DT.list) do
            items[#items+1] = { key = t.name, label = t.label, cat = t.category, ord = DT.categoryOrder(t.category), deco = t,
                                 tip = t.label .. (t.placement == 'sub' and ' (subcelda)' or ' (casilla)') }
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
    if L == 'mini' then E.tool.mini = 'brush' end
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
    y = y + math.ceil(#LAYERS / 3) * 34 + 4
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
    elseif L == 'mini' then
        local v, ch = ui.toggle('Sólido (choca con todo)', E.miniSolid, x, y, w)
        if ch then E.miniSolid = v end
        y = y + 30
        y = sectionTitle('Paleta', x, y, w)
        drawPalette(L, x, y, w, bottom)
    elseif L == 'water' or L == 'special' then
        y = sectionTitle('Capa ' .. layerDef(L).label, x, y, w)
        ui.hint(layerDef(L).help, x, y, w, th.border)
    else
        y = sectionTitle('Paleta', x, y, w)
        drawPalette(L, x, y, w, bottom)
    end
end

P.drawTopBar = drawTopBar; P.drawLeftPanel = drawLeftPanel
end
