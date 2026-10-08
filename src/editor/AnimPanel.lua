-- src/editor/AnimPanel.lua
-- EL EDITOR DE ANIMACIONES, como PIEZA: dibuja y edita un conjunto de animación (los datos de assets/anim/<id>.json,
-- ver src/fx/Anim.lua) dentro del rectángulo que le den. Lo usan el editor de animaciones (pantalla entera) y el
-- editor de enemigos (su pestaña "Animaciones"): es el mismo código.
--
--   local panel = AnimPanel.new()
--   if panel:draw(doc, x, y, w, h) then  … doc cambió …  end          (doc = la tabla del JSON)
--   panel.overlay = function(cx, cy, scale, set, frame) … end          dibujo extra sobre la vista (cajas del enemigo)
--   panel.wanted  = { 'idle', 'walk', … }                              secuencias que se piden (se ofrecen para crear)
--
-- Columnas: CUADROS (de qué imágenes salen: una imagen entera o una hoja cortada en rejilla) · VISTA (la secuencia
-- en movimiento, con su ancla) + TIRA (los cuadros de la secuencia, su orden y su duración) · SECUENCIAS y datos
-- del conjunto (escala, ancla, variantes).
local ui    = require 'src/editor/ui'
local Anim  = require 'src/fx/Anim'
local Shell = require 'src/editor/ToolShell'
local th = ui.theme

local AnimPanel = {}
AnimPanel.__index = AnimPanel
-- Nombres que se ofrecen al crear una secuencia (cualquier otro se escribe a mano)
AnimPanel.PRESETS = { 'idle', 'walk', 'run', 'attack', 'special', 'hurt', 'dead', 'shot', 'air', 'crouch' }

function AnimPanel.new()
    return setmetatable({ frame = 1, anim = nil, pos = 1, zoom = 8, playing = true, t = 0, speed = 1, variant = nil,
                          modal = nil, newName = '', filter = '', dirty = true, overlay = nil, wanted = nil }, AnimPanel)
end

function AnimPanel:touch() self.dirty = true end

-- El conjunto "vivo" de lo que se está editando (se rehace cuando cambian los datos)
function AnimPanel:set(doc)
    if self.dirty or self.doc ~= doc then
        self.doc, self.dirty = doc, false
        doc.frames, doc.anims = doc.frames or {}, doc.anims or {}
        self.live = Anim.fromData(doc, self.variant)
    end
    return self.live
end

local function names(doc)
    local out = {}
    for n in pairs(doc.anims or {}) do out[#out + 1] = n end
    table.sort(out)
    return out
end

-- Cuadro `i` encajado en una caja (miniaturas)
local function thumb(set, i, x, y, w, h)
    local f = set.frames[i]
    if not (f and f.image) then
        ui.rect(x, y, w, h, th.bg, 3)
        ui.text('?', x, y + h / 2 - 7, th.danger, ui.font, w, 'center')
        return
    end
    local k = math.max(1, math.floor(math.min(w / f.w, h / f.h)))
    if f.w * k > w or f.h * k > h then k = math.min(w / f.w, h / f.h) end
    love.graphics.setColor(1, 1, 1, 1)
    set:drawFrame(i, math.floor(x + w / 2), math.floor(y + h / 2), 0, k, k, 0.5, 0.5)
end

local function checker(x, y, w, h)
    ui.rect(x, y, w, h, th.canvas, 0)
    love.graphics.setScissor(x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.035)
    local s = 16
    for yy = 0, math.ceil(h / s) do
        for xx = (yy % 2), math.ceil(w / s), 2 do love.graphics.rectangle('fill', x + xx * s, y + yy * s, s, s) end
    end
    love.graphics.setScissor()
end

-- ── Operaciones sobre los datos ──────────────────────────────────────────────
local function removeFrame(doc, i)
    table.remove(doc.frames, i)
    for _, a in pairs(doc.anims) do
        local out, durs = {}, a.durations and {} or nil
        for k, idx in ipairs(a.frames) do
            if idx ~= i then
                out[#out + 1] = idx > i and idx - 1 or idx
                if durs then durs[#out] = a.durations[k] end
            end
        end
        a.frames, a.durations = out, durs
    end
end
local function swapFrames(doc, i, j)
    doc.frames[i], doc.frames[j] = doc.frames[j], doc.frames[i]
    for _, a in pairs(doc.anims) do
        for k, idx in ipairs(a.frames) do
            if idx == i then a.frames[k] = j elseif idx == j then a.frames[k] = i end
        end
    end
end

function AnimPanel:addAnim(doc, name)
    if name == '' or doc.anims[name] then return false end
    doc.anims[name] = { frames = { math.max(1, math.min(#doc.frames, self.frame)) }, fps = 8, loop = name ~= 'dead' }
    self.anim, self.pos = name, 1
    return true
end

-- ── Ventanas: elegir imagen / cortar hoja ────────────────────────────────────
local imageList
local function images()
    imageList = imageList or Shell.listFiles('assets/images', '.png')
    return imageList
end
function AnimPanel.forgetImages() imageList = nil end

function AnimPanel:drawModal(doc)
    local m = self.modal
    if not m then return false end
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.55); love.graphics.rectangle('fill', 0, 0, W, H)
    local w, h = 640, math.min(620, H - 80)
    local x, y = math.floor((W - w) / 2), math.floor((H - h) / 2)
    ui.rect(x, y, w, h, th.panel, 8); ui.rect(x, y, w, h, th.border, 8, 'line')
    local changed = false
    if m.kind == 'image' then
        ui.text(m.title or 'Elegir imagen', x + 16, y + 12, th.text, ui.fontLg)
        self.filter = ui.textField('animimgfilter', self.filter, x + 16, y + 44, w - 32, 60, 'Buscar (p. ej. enemies/gummy)…')
        local list = {}
        for _, p in ipairs(images()) do
            if self.filter == '' or p:lower():find(self.filter:lower(), 1, true) then list[#list + 1] = p end
        end
        local ly = ui.beginScroll('animimglist', x + 16, y + 80, w - 32, h - 130, #list * 26)
        for _, p in ipairs(list) do
            if ly > y + 50 and ly < y + h - 40 then
                if ui.button(p:gsub('^assets/images/', ''), x + 16, ly, w - 44, 24, { align = 'left', font = ui.fontSm }) then
                    self.modal = nil; ui.endScroll(); m.pick(p); return true
                end
            end
            ly = ly + 26
        end
        ui.endScroll()
        ui.text(#list .. ' imágenes en assets/images (una nueva: cópiala ahí y pulsa "Releer")', x + 16, y + h - 34, th.muted, ui.fontSm)
        if ui.button('Releer', x + w - 190, y + h - 40, 80, 28) then imageList = nil end
        if ui.button('Cancelar', x + w - 100, y + h - 40, 84, 28) then self.modal = nil end
    elseif m.kind == 'slice' then
        ui.text('Cortar una hoja en cuadros', x + 16, y + 12, th.text, ui.fontLg)
        ui.label(m.image:gsub('^assets/images/', ''), x + 16, y + 44, w - 32, th.muted)
        local ok, img = pcall(love.graphics.newImage, m.image)
        if ok then
            img:setFilter('nearest', 'nearest')
            local iw, ih = img:getDimensions()
            m.fw, m.fh = m.fw or ih, m.fh or ih
            local fy = y + 74
            m.fw = ui.number('Ancho del cuadro (px)', m.fw, x + 16, fy, 330, { min = 1, max = iw, step = 1, kind = 'int' }); fy = fy + 30
            m.fh = ui.number('Alto del cuadro (px)', m.fh, x + 16, fy, 330, { min = 1, max = ih, step = 1, kind = 'int' }); fy = fy + 30
            local cols, rows = math.floor(iw / m.fw), math.floor(ih / m.fh)
            ui.text(('Imagen %dx%d → %d columnas × %d filas = %d cuadros'):format(iw, ih, cols, rows, cols * rows), x + 16, fy + 4, th.text)
            -- la hoja con la rejilla encima
            local bx, by, bw, bh = x + 16, fy + 34, w - 32, h - (fy - y) - 100
            checker(bx, by, bw, bh)
            local k = math.max(1, math.floor(math.min(bw / iw, bh / ih)))
            if iw * k > bw or ih * k > bh then k = math.min(bw / iw, bh / ih) end
            local ox, oy = math.floor(bx + (bw - iw * k) / 2), math.floor(by + (bh - ih * k) / 2)
            love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(img, ox, oy, 0, k, k)
            ui.setColor(th.accent, 0.8)
            for c = 0, cols do love.graphics.line(ox + c * m.fw * k, oy, ox + c * m.fw * k, oy + rows * m.fh * k) end
            for r = 0, rows do love.graphics.line(ox, oy + r * m.fh * k, ox + cols * m.fw * k, oy + r * m.fh * k) end
            if ui.button(('Añadir %d cuadros'):format(cols * rows), x + w - 290, y + h - 40, 180, 28, { color = th.accentDk, disabled = cols * rows == 0 }) then
                for r = 0, rows - 1 do
                    for c = 0, cols - 1 do doc.frames[#doc.frames + 1] = { image = m.image, x = c * m.fw, y = r * m.fh, w = m.fw, h = m.fh } end
                end
                self.frame, self.modal, changed = #doc.frames - cols * rows + 1, nil, true
            end
        else
            ui.text('No se puede abrir esa imagen.', x + 16, y + 80, th.danger)
        end
        if ui.button('Cancelar', x + w - 100, y + h - 40, 84, 28) then self.modal = nil end
    end
    if ui.state.keys['escape'] then self.modal = nil end
    return changed
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
function AnimPanel:draw(doc, x, y, w, h)
    local set = self:set(doc)
    local changed = false
    local function touch() changed = true; self.dirty = true end
    local blocked = self.modal ~= nil                  -- (con una ventana abierta, lo de detrás no responde)
    if blocked then ui.state.pressed_saved = ui.state.pressed; ui.state.pressed = false end

    local LW, RW, TL = 256, 300, 168
    local cx, cw = x + LW + 8, w - LW - RW - 16
    local all = names(doc)
    if not self.anim or not doc.anims[self.anim] then self.anim = all[1] end
    local A = self.anim and doc.anims[self.anim]
    self.frame = math.max(1, math.min(math.max(1, #doc.frames), self.frame))

    -- ══ izquierda: CUADROS ══
    ui.rect(x, y, LW, h, th.panel, 6)
    local px, py, pw = x + 10, y + 10, LW - 20
    py = ui.caption(('Cuadros (%d)'):format(#doc.frames), px, py, pw)
    if ui.button('+ Imagen', px, py, pw / 2 - 3, 26, { tooltip = 'Añade una imagen entera como un cuadro' }) then
        self.modal = { kind = 'image', title = 'Añadir una imagen como cuadro', pick = function(p)
            doc.frames[#doc.frames + 1] = { image = p }; self.frame = #doc.frames; self.dirty = true; self.changedLater = true end }
    end
    if ui.button('+ Cortar hoja', px + pw / 2 + 3, py, pw / 2 - 3, 26, { tooltip = 'Elige una hoja de sprites y córtala en una rejilla de cuadros' }) then
        self.modal = { kind = 'image', title = 'Elegir la hoja que se va a cortar', pick = function(p) self.modal = { kind = 'slice', image = p } end }
    end
    py = py + 34
    local TH, per = 54, 4
    local gridH = h - (py - y) - 216
    local rowsN = math.ceil(#doc.frames / per)
    local gy = ui.beginScroll('animframes' .. tostring(doc), px, py, pw, gridH, rowsN * (TH + 6))
    for i = 1, #doc.frames do
        local tx = px + ((i - 1) % per) * (TH + 5)
        local ty = gy + math.floor((i - 1) / per) * (TH + 6)
        if ty > py - TH and ty < py + gridH then
            local sel = i == self.frame
            ui.rect(tx, ty, TH, TH, sel and th.accentDk or th.bg, 4)
            thumb(set, i, tx + 3, ty + 3, TH - 6, TH - 6)
            ui.text(tostring(i), tx + 3, ty + 1, sel and th.text or th.muted, ui.fontSm)
            if not blocked and ui.inside(tx, ty, TH, TH) and ui.state.pressed and ui.inside(px, py, pw, gridH) then self.frame = i; ui.state.consumed = true end
        end
    end
    ui.endScroll()
    py = py + gridH + 8
    local F = doc.frames[self.frame]
    if F then
        py = ui.caption('Cuadro ' .. self.frame, px, py, pw)
        ui.label((F.image or ''):gsub('^assets/images/', ''), px, py, pw, th.muted); py = py + 22
        local lf = set.frames[self.frame]
        local iw, ih = lf and lf.iw or 4096, lf and lf.ih or 4096
        local whole = F.w == nil
        local nv, ch = ui.toggle('Imagen entera', whole, px, py, pw); py = py + 26
        if ch then
            if nv then F.x, F.y, F.w, F.h = nil, nil, nil, nil else F.x, F.y, F.w, F.h = 0, 0, iw, ih end
            touch()
        end
        if not whole then
            for _, fld in ipairs({ { 'x', 'X', 0, iw - 1 }, { 'y', 'Y', 0, ih - 1 }, { 'w', 'Ancho', 1, iw }, { 'h', 'Alto', 1, ih } }) do
                local v, c2 = ui.number(fld[2], F[fld[1]] or 0, px, py, pw, { min = fld[3], max = fld[4], step = 1, kind = 'int' }); py = py + 26
                if c2 then F[fld[1]] = v; touch() end
            end
        else py = py + 0 end
        local bw3 = (pw - 8) / 3
        if ui.button('<', px, py, bw3, 24, { disabled = self.frame <= 1, tooltip = 'Mover el cuadro antes (las secuencias se ajustan solas)' }) then
            swapFrames(doc, self.frame, self.frame - 1); self.frame = self.frame - 1; touch() end
        if ui.button('>', px + bw3 + 4, py, bw3, 24, { disabled = self.frame >= #doc.frames }) then
            swapFrames(doc, self.frame, self.frame + 1); self.frame = self.frame + 1; touch() end
        if ui.button('Quitar', px + 2 * (bw3 + 4), py, bw3, 24, { textColor = th.danger, tooltip = 'Quita el cuadro (también de las secuencias)' }) then
            removeFrame(doc, self.frame); touch() end
    else
        ui.hint('Añade cuadros: una imagen entera por cuadro, o una hoja (varios cuadros en una imagen) cortada en rejilla.', px, py, pw)
    end

    -- ══ centro: VISTA ══
    local vh = h - TL - 8
    checker(cx, y, cw, vh)
    if self.playing then self.t = self.t + love.timer.getDelta() * self.speed end
    local shown, posK = self.frame, nil
    if A and #doc.frames > 0 then
        if self.playing then
            local fi, _, k = set:frameAt(self.anim, self.t)
            shown, posK = fi, k
        else
            self.pos = math.max(1, math.min(#A.frames, self.pos))
            shown, posK = A.frames[self.pos] or 1, self.pos
        end
    end
    if not blocked and ui.inside(cx, y, cw, vh) and ui.state.wheel ~= 0 then
        self.zoom = math.max(1, math.min(24, self.zoom + (ui.state.wheel > 0 and 1 or -1))); ui.state.wheel = 0
    end
    local mx, my = math.floor(cx + cw / 2), math.floor(y + vh * 0.62)
    if #doc.frames > 0 then
        love.graphics.setScissor(cx, y, cw, vh)
        love.graphics.setColor(1, 1, 1, 1)
        set:drawFrame(shown, mx, my, 0, self.zoom, self.zoom)
        -- el ancla (dónde se apoya: los pies) y el contorno del cuadro
        local f = set.frames[shown]
        if f then
            local ax, ay = (f.ox or set.ox) * f.w * self.zoom, (f.oy or set.oy) * f.h * self.zoom
            ui.setColor(th.border, 0.9); love.graphics.rectangle('line', mx - ax + 0.5, my - ay + 0.5, f.w * self.zoom, f.h * self.zoom)
            ui.setColor(th.warn, 0.9)
            love.graphics.line(mx - 10, my, mx + 10, my); love.graphics.line(mx, my - 10, mx, my + 10)
            if self.overlay then self.overlay(mx, my, self.zoom, set, f) end
        end
        love.graphics.setScissor()
    end
    -- controles de la vista
    if ui.button(self.playing and 'Pausa' or 'Reproducir', cx + 8, y + 8, 110, 26, { hint = 'espacio' }) then self.playing = not self.playing end
    local sp, sc = ui.enum('', self.speed, { { value = 0.25, label = '¼' }, { value = 0.5, label = '½' }, { value = 1, label = '1×' }, { value = 2, label = '2×' } }, cx + 126, y - 14, 150)
    if sc then self.speed = sp end
    ui.text(('zoom ×%d (rueda)   %s'):format(self.zoom, A and ('%s · %.2f s · cuadro %d'):format(self.anim, set:length(self.anim), shown) or 'sin secuencia'),
            cx + 290, y + 14, th.muted, ui.fontSm)

    -- ══ centro: TIRA de la secuencia ══
    local ty0 = y + vh + 8
    ui.rect(cx, ty0, cw, TL, th.panel, 6)
    if A then
        ui.text(('Secuencia "%s": %d cuadros'):format(self.anim, #A.frames), cx + 10, ty0 + 8, th.text)
        local S2 = 64
        local sx0 = ui.beginScroll('animstrip' .. tostring(doc), cx + 10, ty0 + 30, cw - 20, S2 + 30, 1)   -- (sin scroll vertical)
        local off = math.max(0, (self.pos - math.floor((cw - 20) / (S2 + 6))) * (S2 + 6))
        for k, idx in ipairs(A.frames) do
            local bx = cx + 10 + (k - 1) * (S2 + 6) - off
            if bx > cx - S2 and bx < cx + cw then
                local cur = k == (self.playing and posK or self.pos)
                ui.rect(bx, ty0 + 30, S2, S2, cur and th.accentDk or th.bg, 4)
                thumb(set, idx, bx + 3, ty0 + 33, S2 - 6, S2 - 6)
                ui.text(tostring(idx), bx + 3, ty0 + 31, th.muted, ui.fontSm)
                local d = A.durations and tonumber(A.durations[k])
                ui.text((d and d > 0) and ('%.2f s'):format(d) or '', bx, ty0 + 30 + S2 + 2, th.warn, ui.fontSm, S2, 'center')
                if not blocked and ui.inside(bx, ty0 + 30, S2, S2) and ui.state.pressed then self.pos, self.playing = k, false; ui.state.consumed = true end
            end
        end
        ui.endScroll()
        local by = ty0 + TL - 34
        local bx = cx + 10
        if ui.button('+ cuadro ' .. self.frame, bx, by, 110, 26, { disabled = #doc.frames == 0, tooltip = 'Añade a la secuencia el cuadro elegido a la izquierda (detrás del marcado)' }) then
            local at = math.min(#A.frames, self.pos) + 1
            table.insert(A.frames, at, self.frame)
            if A.durations then table.insert(A.durations, at, 0) end
            self.pos = at; touch()
        end
        bx = bx + 116
        if ui.button('<', bx, by, 30, 26, { disabled = self.pos <= 1 }) then
            A.frames[self.pos], A.frames[self.pos - 1] = A.frames[self.pos - 1], A.frames[self.pos]
            if A.durations then A.durations[self.pos], A.durations[self.pos - 1] = A.durations[self.pos - 1], A.durations[self.pos] end
            self.pos = self.pos - 1; touch()
        end
        if ui.button('>', bx + 34, by, 30, 26, { disabled = self.pos >= #A.frames }) then
            A.frames[self.pos], A.frames[self.pos + 1] = A.frames[self.pos + 1], A.frames[self.pos]
            if A.durations then A.durations[self.pos], A.durations[self.pos + 1] = A.durations[self.pos + 1], A.durations[self.pos] end
            self.pos = self.pos + 1; touch()
        end
        if ui.button('Quitar', bx + 68, by, 64, 26, { disabled = #A.frames <= 1, textColor = th.danger }) then
            table.remove(A.frames, self.pos)
            if A.durations then table.remove(A.durations, self.pos) end
            self.pos = math.max(1, self.pos - 1); touch()
        end
        bx = bx + 140
        if cw - (bx - cx) > 250 then
            local d = A.durations and tonumber(A.durations[self.pos]) or 0
            local nd, dc = ui.number('Dura (s; 0 = fps)', d, bx, by + 1, math.min(280, cw - (bx - cx) - 10), { min = 0, max = 10, step = 0.01 })
            if dc then
                A.durations = A.durations or {}
                for k = 1, #A.frames do A.durations[k] = tonumber(A.durations[k]) or 0 end
                A.durations[self.pos] = nd
                local any = false
                for k = 1, #A.frames do if A.durations[k] > 0 then any = true end end
                if not any then A.durations = nil end
                touch()
            end
        end
    else
        ui.hint('Crea una secuencia a la derecha (idle, walk…) y añádele cuadros.', cx + 10, ty0 + 12, cw - 20)
    end

    -- ══ derecha: SECUENCIAS y datos del conjunto ══
    local rx = x + w - RW
    ui.rect(rx, y, RW, h, th.panel, 6)
    px, pw = rx + 10, RW - 20
    local contentH = 760 + #all * 28 + (function() local n = 0; for _ in pairs(doc.variants or {}) do n = n + 1 end; return n * 86 end)()
    py = ui.beginScroll('animright' .. tostring(doc), rx, y + 6, RW, h - 12, contentH) + 4
    py = ui.caption(('Secuencias (%d)'):format(#all), px, py, pw)
    for _, n in ipairs(all) do
        local seq = doc.anims[n]
        if ui.button(n, px, py, pw, 24, { active = n == self.anim, align = 'left', hint = #seq.frames .. ' c · ' .. (seq.fps or 8) .. ' fps' }) then
            self.anim, self.pos, self.t = n, 1, 0
        end
        py = py + 28
    end
    -- las que se piden y aún no existen (el editor de enemigos: una por estado)
    local missing = {}
    for _, n in ipairs(self.wanted or {}) do if not doc.anims[n] then missing[#missing + 1] = n end end
    if #missing > 0 then
        py = py + 2 + ui.hint('Faltan: ' .. table.concat(missing, ', '), px, py, pw, th.warn) + 4
        if ui.button('Crear las que faltan', px, py, pw, 24, { disabled = #doc.frames == 0 }) then
            for _, n in ipairs(missing) do self:addAnim(doc, n) end
            touch()
        end
        py = py + 30
    end
    self.newName = ui.textField('animnew' .. tostring(doc), self.newName, px, py, pw - 78, 24, 'nombre nuevo…')
    if ui.button('+ Crear', px + pw - 72, py, 72, 26, { disabled = self.newName == '' or doc.anims[self.newName] ~= nil or #doc.frames == 0 }) then
        if self:addAnim(doc, self.newName) then self.newName = ''; touch() end
    end
    py = py + 32
    local qx = px
    for _, n in ipairs(AnimPanel.PRESETS) do
        if not doc.anims[n] then
            local bw = ui.fontSm:getWidth(n) + 14
            if qx + bw > px + pw then qx, py = px, py + 24 end
            if ui.button(n, qx, py, bw, 20, { font = ui.fontSm, disabled = #doc.frames == 0, tooltip = 'Crear la secuencia "' .. n .. '"' }) then self:addAnim(doc, n); touch() end
            qx = qx + bw + 4
        end
    end
    py = py + 30
    if A then
        py = ui.caption('Secuencia "' .. self.anim .. '"', px, py, pw)
        local v, c2 = ui.number('Cuadros por segundo', A.fps or 8, px, py, pw, { min = 0.5, max = 60, step = 0.5 }); py = py + 28
        if c2 then A.fps = v; touch() end
        v, c2 = ui.toggle('Se repite (bucle)', A.loop ~= false, px, py, pw); py = py + 28
        if c2 then A.loop = v; touch() end
        if A.loop == false then
            local opts = { { value = '', label = '(se queda en el último)' } }
            for _, n in ipairs(all) do if n ~= self.anim then opts[#opts + 1] = { value = n, label = n } end end
            v, c2 = ui.enum('Al acabar sigue', A.next or '', opts, px, py, pw); py = py + ui.ENUM_H + 4
            if c2 then A.next = v ~= '' and v or nil; touch() end
        end
        local ev = (A.events and A.events[tostring(self.pos)]) or ''
        ui.label('Aviso al llegar al cuadro ' .. self.pos .. ' de la secuencia', px, py, pw, th.text); py = py + 22
        v, c2 = ui.textField('animev' .. tostring(doc), ev, px, py, pw, 24, '(ninguno; p. ej. step)'); py = py + 32
        if c2 then
            A.events = A.events or {}
            A.events[tostring(self.pos)] = v ~= '' and v or nil
            if next(A.events) == nil then A.events = nil end
            touch()
        end
        local bw2 = (pw - 4) / 2
        if ui.button('Duplicar', px, py, bw2, 24) then
            local n2 = self.anim .. '2'
            while doc.anims[n2] do n2 = n2 .. '2' end
            local copy = { frames = {}, fps = A.fps, loop = A.loop, next = A.next }
            for k, i in ipairs(A.frames) do copy.frames[k] = i end
            if A.durations then copy.durations = {}; for k, d in ipairs(A.durations) do copy.durations[k] = d end end
            doc.anims[n2] = copy; self.anim = n2; touch()
        end
        if ui.button('Borrar secuencia', px + bw2 + 4, py, bw2, 24, { textColor = th.danger }) then
            doc.anims[self.anim] = nil
            for _, a in pairs(doc.anims) do if a.next == self.anim then a.next = nil end end
            if doc.fallback == self.anim then doc.fallback = nil end
            self.anim = nil; touch()
        end
        py = py + 34
    end
    py = ui.caption('Conjunto', px, py, pw)
    local v, c2 = ui.number('Escala en el juego (px por píxel)', doc.scale or 4, px, py, pw, { min = 1, max = 16, step = 0.5 }); py = py + 28
    if c2 then doc.scale = v; touch() end
    doc.origin = doc.origin or { 0.5, 1 }
    v, c2 = ui.number('Ancla X (0 izq · 1 der)', doc.origin[1], px, py, pw, { min = 0, max = 1, step = 0.05 }); py = py + 28
    if c2 then doc.origin[1] = v; touch() end
    v, c2 = ui.number('Ancla Y (0 arriba · 1 pies)', doc.origin[2], px, py, pw, { min = 0, max = 1, step = 0.05 }); py = py + 28
    if c2 then doc.origin[2] = v; touch() end
    if #all > 0 then
        local opts = {}
        for _, n in ipairs(all) do opts[#opts + 1] = { value = n, label = n } end
        v, c2 = ui.enum('Si piden una secuencia que no existe', doc.fallback or (doc.anims.idle and 'idle') or all[1], opts, px, py, pw); py = py + ui.ENUM_H + 4
        if c2 then doc.fallback = v; touch() end
    end
    py = ui.caption('Variantes (otras imágenes)', px, py, pw)
    local vnames = {}
    for n in pairs(doc.variants or {}) do vnames[#vnames + 1] = n end
    table.sort(vnames)
    if #vnames > 0 then
        local opts = { { value = '', label = '(la de base)' } }
        for _, n in ipairs(vnames) do opts[#opts + 1] = { value = n, label = n } end
        v, c2 = ui.enum('Ver', self.variant or '', opts, px, py, pw); py = py + ui.ENUM_H + 4
        if c2 then self.variant = v ~= '' and v or nil; self.dirty = true end
    end
    for _, n in ipairs(vnames) do
        local V = doc.variants[n]
        ui.text(n, px, py + 4, th.accent)
        if ui.button('Quitar', px + pw - 60, py, 60, 22, { font = ui.fontSm, textColor = th.danger }) then
            doc.variants[n] = nil
            if next(doc.variants) == nil then doc.variants = nil end
            if self.variant == n then self.variant = nil end
            touch()
        else
            py = py + 26
            v, c2 = ui.textField('animvf' .. n .. tostring(doc), V.from or '', px, py, pw, 120, 'de: ruta que se cambia'); py = py + 28
            if c2 then V.from = v; touch() end
            v, c2 = ui.textField('animvt' .. n .. tostring(doc), V.to or '', px, py, pw, 120, 'a: ruta por la que se cambia'); py = py + 32
            if c2 then V.to = v; touch() end
        end
    end
    self.newVar = ui.textField('animvnew' .. tostring(doc), self.newVar or '', px, py, pw - 78, 24, 'variante nueva…')
    if ui.button('+ Crear', px + pw - 72, py, 72, 26, { disabled = (self.newVar or '') == '' or (doc.variants and doc.variants[self.newVar] ~= nil) }) then
        doc.variants = doc.variants or {}
        -- (por defecto: la carpeta del primer cuadro → la misma con _<variante>)
        local dir = doc.frames[1] and doc.frames[1].image and doc.frames[1].image:match('^(.*)/[^/]*$') or 'assets/images'
        doc.variants[self.newVar] = { from = dir .. '/', to = dir .. '_' .. self.newVar .. '/' }
        self.newVar = ''; touch()
    end
    py = py + 34
    ui.endScroll()

    if blocked then ui.state.pressed = ui.state.pressed_saved end
    if self:drawModal(doc) then touch() end
    if self.changedLater then self.changedLater = nil; changed = true end
    return changed
end

-- Teclas del panel (true si la usó): espacio = reproducir / pausa; , . = cuadro anterior / siguiente de la secuencia
function AnimPanel:keypressed(k)
    if ui.hasFocus() or self.modal then return false end
    if k == 'space' then self.playing = not self.playing; return true end
    if k == ',' then self.playing = false; self.pos = math.max(1, self.pos - 1); return true end
    if k == '.' then self.playing = false; self.pos = self.pos + 1; return true end
    return false
end

return AnimPanel
