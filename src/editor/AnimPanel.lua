-- src/editor/AnimPanel.lua
-- EL EDITOR DE ANIMACIONES, como PIEZA: dibuja y edita un conjunto de animación (los datos de assets/anim/<id>.json,
-- ver src/fx/Anim.lua) dentro del rectángulo que le den. Lo usan el editor de animaciones (pantalla entera) y el
-- editor de enemigos (su paso "Animaciones"): es el mismo código.
--
--   local panel = AnimPanel.new()
--   if panel:draw(doc, x, y, w, h) then  … doc cambió …  end          (doc = la tabla del JSON)
--   panel.wanted = { 'idle', 'walk', … }                               animaciones que se piden (se ofrecen para crear)
--
-- Se lee de izquierda a derecha, como se trabaja:
--   ANIMACIONES (izquierda)  la lista: Quieto, Andar, Ataque… — se elige una o se crea
--   VISTA + LÍNEA DE TIEMPO (centro)  la animación elegida moviéndose, y debajo sus cuadros en orden
--   BANCO DE CUADROS (derecha)  todos los dibujos disponibles (imágenes sueltas u hojas cortadas en rejilla);
--                               de aquí se añaden a la línea de tiempo
local ui    = require 'src/editor/ui'
local Anim  = require 'src/fx/Anim'
local Shell = require 'src/editor/ToolShell'
local th = ui.theme

local AnimPanel = {}
AnimPanel.__index = AnimPanel
-- Nombres habituales, con cómo se enseñan (el nombre interno es el que usa el juego: no se traduce)
AnimPanel.FRIENDLY = {
    idle = 'Quieto', walk = 'Andar', run = 'Correr', attack = 'Ataque', special = 'Acción especial', hurt = 'Daño', dead = 'Muerte',
    tired = 'Cansado', shot = 'Proyectil', hide = 'Esconderse', unhide = 'Salir del escondite', hidden = 'Escondido',
    peek = 'Asomado', meat = 'A medio esconder', air = 'En el aire', crouch = 'Agachado', all = 'Imágenes sueltas',
}
AnimPanel.PRESETS = { 'idle', 'walk', 'run', 'attack', 'special', 'hurt', 'dead', 'tired', 'hide', 'shot' }
local function nice(n) return AnimPanel.FRIENDLY[n] and (AnimPanel.FRIENDLY[n] .. '  (' .. n .. ')') or n end
AnimPanel.nice = nice

function AnimPanel.new()
    return setmetatable({ frame = 1, anim = nil, pos = 1, zoom = 8, playing = true, t = 0, speed = 1, variant = nil,
                          modal = nil, newName = '', filter = '', dirty = true, wanted = nil, lastClick = 0, lastFrame = 0 }, AnimPanel)
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

-- La animación que conviene enseñar al abrir: andar, o la que más cuadros tenga (una de un cuadro no se mueve)
local function bestAnim(doc)
    if doc.anims.walk and #doc.anims.walk.frames > 1 then return 'walk' end
    local best, n
    for _, name in ipairs(names(doc)) do
        local c = #doc.anims[name].frames
        if not n or c > n then best, n = name, c end
    end
    return best
end

local function thumb(set, i, x, y, w, h)
    local f = set.frames[i]
    if not (f and f.image) then
        ui.rect(x, y, w, h, th.bg, 3)
        ui.text('?', x, y + h / 2 - 7, th.danger, ui.font, w, 'center')
        return
    end
    local k = math.floor(math.min(w / f.w, h / f.h))
    if k < 1 then k = math.min(w / f.w, h / f.h) end
    love.graphics.setColor(1, 1, 1, 1)
    set:drawFrame(i, math.floor(x + w / 2), math.floor(y + h / 2), 0, k, k, 0.5, 0.5)
end
AnimPanel.thumb = thumb

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
        if #out == 0 then out[1] = 1 end
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
    if name == '' or doc.anims[name] or #doc.frames == 0 then return false end
    doc.anims[name] = { frames = { math.max(1, math.min(#doc.frames, self.frame)) }, fps = 8, loop = name ~= 'dead' }
    self.anim, self.pos, self.t = name, 1, 0
    return true
end
-- Añade el cuadro `i` del banco a la animación elegida (detrás del marcado)
function AnimPanel:addToTimeline(doc, i)
    local A = self.anim and doc.anims[self.anim]
    if not A then return false end
    local at = math.min(#A.frames, self.pos) + 1
    table.insert(A.frames, at, i)
    if A.durations then table.insert(A.durations, at, 0) end
    self.pos = at
    return true
end

-- ── Ventanas ──────────────────────────────────────────────────────────────────
local imageList
local function images()
    imageList = imageList or Shell.listFiles('assets/images', '.png')
    return imageList
end

function AnimPanel:drawModal(doc)
    local m = self.modal
    if not m then return false end
    local W, H = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle('fill', 0, 0, W, H)
    local w, h = 700, math.min(640, H - 80)
    if m.kind == 'newanim' then w, h = 520, 330 end
    local x, y = math.floor((W - w) / 2), math.floor((H - h) / 2)
    ui.rect(x, y, w, h, th.panel, 8); ui.rect(x, y, w, h, th.border, 8, 'line')
    local changed = false
    if m.kind == 'newanim' then
        ui.text('Nueva animación', x + 16, y + 12, th.text, ui.fontLg)
        ui.text('Elige cuál (el nombre entre paréntesis es el que usa el juego):', x + 16, y + 44, th.muted)
        local bx, by = x + 16, y + 72
        for _, n in ipairs(AnimPanel.PRESETS) do
            if not doc.anims[n] then
                local bw = ui.font:getWidth(nice(n)) + 24
                if bx + bw > x + w - 16 then bx, by = x + 16, by + 34 end
                if ui.button(nice(n), bx, by, bw, 28) then
                    self:addAnim(doc, n); self.modal, changed = nil, true
                end
                bx = bx + bw + 6
            end
        end
        by = by + 50
        ui.text('…u otro nombre (minúsculas, sin espacios):', x + 16, by, th.muted); by = by + 24
        self.newName = ui.textField('animnewname', self.newName, x + 16, by, w - 150, 24, 'p. ej. girar')
        local ok = self.newName:match('^[%l][%l%d_]*$') and not doc.anims[self.newName]
        if ui.button('Crear', x + w - 124, by, 108, 26, { disabled = not ok, color = th.accentDk }) then
            self:addAnim(doc, self.newName); self.newName, self.modal, changed = '', nil, true
        end
        if ui.button('Cancelar', x + w - 110, y + h - 40, 94, 28) then self.modal = nil end
    elseif m.kind == 'image' then
        ui.text(m.title or 'Elegir imagen', x + 16, y + 12, th.text, ui.fontLg)
        ui.text(m.multi and 'Pulsa cada imagen que quieras añadir como cuadro; luego "Hecho".' or 'Pulsa la imagen.', x + 16, y + 40, th.muted, ui.fontSm)
        self.filter = ui.textField('animimgfilter', self.filter, x + 16, y + 60, w - 32, 60, 'Buscar (p. ej. enemies/gummy)…')
        local list = {}
        for _, p in ipairs(images()) do
            if self.filter == '' or p:lower():find(self.filter:lower(), 1, true) then list[#list + 1] = p end
        end
        local ly = ui.beginScroll('animimglist', x + 16, y + 96, w - 32, h - 150, #list * 26)
        local picked
        for _, p in ipairs(list) do
            if ly > y + 70 and ly < y + h - 50 then
                local added = m.added and m.added[p]
                if ui.button((added and '+ ' or '') .. p:gsub('^assets/images/', ''), x + 16, ly, w - 44, 24, { align = 'left', font = ui.fontSm, active = added }) then picked = p end
            end
            ly = ly + 26
        end
        ui.endScroll()
        if picked then
            if m.multi then m.added = m.added or {}; m.added[picked] = true end
            m.pick(picked)
            if not m.multi then self.modal = nil end
            changed = true
        end
        ui.text(#list .. ' imágenes en assets/images (una nueva: cópiala ahí y pulsa "Releer")', x + 16, y + h - 34, th.muted, ui.fontSm)
        if ui.button('Releer', x + w - 200, y + h - 40, 80, 28) then imageList = nil end
        if ui.button(m.multi and 'Hecho' or 'Cancelar', x + w - 110, y + h - 40, 94, 28, { color = m.multi and th.accentDk or nil }) then self.modal = nil end
    elseif m.kind == 'slice' then
        ui.text('Cortar una hoja en cuadros', x + 16, y + 12, th.text, ui.fontLg)
        ui.label(m.image:gsub('^assets/images/', ''), x + 16, y + 44, w - 32, th.muted)
        local ok, img = pcall(love.graphics.newImage, m.image)
        if ok then
            img:setFilter('nearest', 'nearest')
            local iw, ih = img:getDimensions()
            m.fw, m.fh = m.fw or ih, m.fh or ih
            local fy = y + 74
            m.fw = ui.number('Ancho de cada cuadro (px)', m.fw, x + 16, fy, 360, { min = 1, max = iw, step = 1, kind = 'int' }); fy = fy + 30
            m.fh = ui.number('Alto de cada cuadro (px)', m.fh, x + 16, fy, 360, { min = 1, max = ih, step = 1, kind = 'int' }); fy = fy + 30
            local cols, rows = math.floor(iw / m.fw), math.floor(ih / m.fh)
            ui.text(('La imagen mide %dx%d → %d columnas × %d filas = %d cuadros'):format(iw, ih, cols, rows, cols * rows), x + 16, fy + 4, th.text)
            local bx, by, bw, bh = x + 16, fy + 34, w - 32, h - (fy - y) - 100
            checker(bx, by, bw, bh)
            local k = math.floor(math.min(bw / iw, bh / ih))
            if k < 1 then k = math.min(bw / iw, bh / ih) end
            local ox, oy = math.floor(bx + (bw - iw * k) / 2), math.floor(by + (bh - ih * k) / 2)
            love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(img, ox, oy, 0, k, k)
            ui.setColor(th.accent, 0.8)
            for c = 0, cols do love.graphics.line(ox + c * m.fw * k, oy, ox + c * m.fw * k, oy + rows * m.fh * k) end
            for r = 0, rows do love.graphics.line(ox, oy + r * m.fh * k, ox + cols * m.fw * k, oy + r * m.fh * k) end
            if ui.button(('Añadir %d cuadros'):format(cols * rows), x + w - 300, y + h - 40, 180, 28, { color = th.accentDk, disabled = cols * rows == 0 }) then
                for r = 0, rows - 1 do
                    for c = 0, cols - 1 do doc.frames[#doc.frames + 1] = { image = m.image, x = c * m.fw, y = r * m.fh, w = m.fw, h = m.fh } end
                end
                self.frame, self.modal, changed = #doc.frames - cols * rows + 1, nil, true
            end
        else
            ui.text('No se puede abrir esa imagen.', x + 16, y + 80, th.danger)
        end
        if ui.button('Cancelar', x + w - 110, y + h - 40, 94, 28) then self.modal = nil end
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
    local savedPressed, savedWheel = ui.state.pressed, ui.state.wheel
    if blocked then ui.state.pressed, ui.state.wheel = false, 0 end

    local all = names(doc)
    if not self.anim or not doc.anims[self.anim] then self.anim, self.pos, self.t = bestAnim(doc), 1, 0 end
    local A = self.anim and doc.anims[self.anim]
    self.frame = math.max(1, math.min(math.max(1, #doc.frames), self.frame))
    local code = false        -- (ya no hay conjuntos "del juego" aparte: todos se editan igual)

    -- aviso de arriba: por dónde empezar
    local top = y
    if false then
    elseif #doc.frames == 0 then
        top = top + ui.hint('Empieza por la derecha: añade CUADROS (los dibujos). Después crea una ANIMACIÓN a la izquierda y ve metiéndole cuadros.', x, top, w, th.accent) + 6
    elseif #all == 0 then
        top = top + ui.hint('Ya hay cuadros. Ahora crea una ANIMACIÓN a la izquierda ("+ Nueva animación").', x, top, w, th.accent) + 6
    end
    h = h - (top - y); y = top

    local LW, RW, TL = 250, 290, 190
    local cx, cw = x + LW + 8, w - LW - RW - 16

    -- ══ 1 · ANIMACIONES ══
    ui.rect(x, y, LW, h, th.panel, 6)
    local px, pw = x + 10, LW - 20
    local py = ui.caption('1 · Animaciones', px, y + 10, pw)
    local listH = math.min(#all * 50 + 4, math.max(100, h - 330))
    local ly = ui.beginScroll('animlist' .. tostring(doc), px, py, pw, listH, #all * 50)
    for _, n in ipairs(all) do
        local seq = doc.anims[n]
        if ly > py - 50 and ly < py + listH then
            local sel = n == self.anim
            local hov = ui.inside(px, ly, pw - 6, 46) and ui.inside(px, py, pw, listH)
            ui.rect(px, ly, pw - 6, 46, sel and th.accentDk or (hov and th.hover or th.panel2), 5)
            if #doc.frames > 0 then
                local fi = set:frameAt(n, love.timer.getTime())
                thumb(set, fi, px + 4, ly + 4, 38, 38)
            end
            ui.label(AnimPanel.FRIENDLY[n] or n, px + 50, ly + 3, pw - 62, th.text)
            ui.text(('%s · %d cuadro%s · %s fps'):format(n, #seq.frames, #seq.frames == 1 and '' or 's', tostring(seq.fps or 8)), px + 50, ly + 26, sel and th.text or th.muted, ui.fontSm)
            if hov and ui.state.pressed then self.anim, self.pos, self.t, self.playing = n, 1, 0, true; ui.state.consumed = true end
        end
        ly = ly + 50
    end
    ui.endScroll()
    py = py + listH + 6
    if ui.button('+ Nueva animación', px, py, pw, 28, { color = th.accentDk, disabled = #doc.frames == 0 or code and doc.strip ~= nil,
                 tooltip = #doc.frames == 0 and 'Primero añade cuadros (a la derecha)' or 'Quieto, andar, ataque…' }) then
        self.modal = { kind = 'newanim' }
    end
    py = py + 34
    local missing = {}
    for _, n in ipairs(self.wanted or {}) do if not doc.anims[n] then missing[#missing + 1] = n end end
    if #missing > 0 then
        py = py + ui.hint('Este enemigo necesita además: ' .. table.concat(missing, ', '), px, py, pw, th.warn) + 4
        if ui.button('Crearlas (con el cuadro elegido)', px, py, pw, 24, { disabled = #doc.frames == 0 }) then
            for _, n in ipairs(missing) do self:addAnim(doc, n) end
            touch()
        end
        py = py + 30
    end
    if A then
        py = ui.caption('«' .. (AnimPanel.FRIENDLY[self.anim] or self.anim) .. '»', px, py + 4, pw)
        local v, c2 = ui.number('Velocidad (fps)', A.fps or 8, px, py, pw, { min = 0.5, max = 60, step = 0.5 }); py = py + 28
        if c2 then A.fps = v; touch() end
        v, c2 = ui.toggle('Se repite sin parar', A.loop ~= false, px, py, pw); py = py + 28
        if c2 then A.loop = v; touch() end
        if A.sheet then
            -- (animación que el juego lee de una hoja: qué llega al juego de lo que se cambie aquí)
            local txt
            if A.at then
                txt = ('El juego enseña esta animación cuando toca este estado y usa %d cuadro%s de ella (con menos, los repite; los de más no salen). El ritmo lo lleva el juego.'):format(#A.at, #A.at == 1 and '' or 's')
            elseif A.codeFps then
                txt = 'El juego la reproduce tal como está aquí: cuadros, orden y velocidad.'
            else
                txt = 'El juego usa sus cuadros en este orden; cuándo pasa de uno a otro depende de lo que ocurre en la partida, así que la velocidad de aquí solo vale para verla.'
            end
            py = py + ui.hint(txt, px, py, pw) + 6
        end
        if A.loop == false then
            local opts = { { value = '', label = '(se queda en el último)' } }
            for _, n in ipairs(all) do if n ~= self.anim then opts[#opts + 1] = { value = n, label = n } end end
            v, c2 = ui.enum('Al acabar pasa a', A.next or '', opts, px, py, pw); py = py + ui.ENUM_H + 4
            if c2 then A.next = v ~= '' and v or nil; touch() end
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
        if ui.button('Borrar', px + bw2 + 4, py, bw2, 24, { textColor = th.danger, tooltip = 'Borra esta animación (los cuadros siguen en el banco)' }) then
            doc.anims[self.anim] = nil
            for _, a in pairs(doc.anims) do if a.next == self.anim then a.next = nil end end
            if doc.fallback == self.anim then doc.fallback = nil end
            self.anim = nil; touch()
        end
    end

    -- ══ 2 · VISTA ══
    local vh = h - TL - 8
    checker(cx, y, cw, vh)
    ui.text('2 · Vista', cx + 10, y + 8, th.muted, ui.fontSm)
    if self.playing then self.t = self.t + love.timer.getDelta() * self.speed end
    local shown, posK, len = self.frame, nil, 0
    if A and #doc.frames > 0 then
        len = set:length(self.anim)
        if self.playing then
            if A.loop == false and self.t > len + 0.6 then self.t = 0 end          -- (las que no se repiten: vuelve a empezar para verla)
            local fi, _, k = set:frameAt(self.anim, self.t)
            shown, posK = fi, k
            self.pos = k
        else
            self.pos = math.max(1, math.min(#A.frames, self.pos))
            shown, posK = A.frames[self.pos] or 1, self.pos
        end
    end
    local barH = 44
    if ui.inside(cx, y, cw, vh - barH) and ui.state.wheel ~= 0 then
        self.zoom = math.max(1, math.min(24, self.zoom + (ui.state.wheel > 0 and 1 or -1))); ui.state.wheel = 0
    end
    local mx, my = math.floor(cx + cw / 2), math.floor(y + (vh - barH) * 0.66)
    if #doc.frames > 0 then
        love.graphics.setScissor(cx, y, cw, vh - barH)
        love.graphics.setColor(1, 1, 1, 1)
        set:drawFrame(shown, mx, my, 0, self.zoom, self.zoom)
        local f = set.frames[shown]
        if f then
            local ax, ay = (f.ox or set.ox) * f.w * self.zoom, (f.oy or set.oy) * f.h * self.zoom
            ui.setColor(th.border, 0.7); love.graphics.rectangle('line', mx - ax + 0.5, my - ay + 0.5, f.w * self.zoom, f.h * self.zoom)
            ui.setColor(th.warn, 0.9)
            love.graphics.line(mx - 10, my, mx + 10, my); love.graphics.line(mx, my - 10, mx, my + 10)
        end
        love.graphics.setScissor()
    else
        ui.text('Aquí se verá la animación', cx, y + vh / 2 - 20, th.muted, ui.fontLg, cw, 'center')
    end
    ui.text(('zoom ×%d (rueda del ratón)'):format(self.zoom), cx + cw - 200, y + 8, th.muted, ui.fontSm, 190, 'right')
    -- reproductor
    local by0 = y + vh - barH
    ui.rect(cx, by0, cw, barH, th.panel, 0)
    local bx = cx + 8
    if ui.button('<', bx, by0 + 8, 30, 28, { tooltip = 'Cuadro anterior (,)' }) then self.playing = false; self.pos = math.max(1, self.pos - 1) end
    if ui.button(self.playing and 'Pausa' or 'Reproducir', bx + 34, by0 + 8, 104, 28, { color = th.accentDk, hint = 'espacio' }) then
        self.playing = not self.playing
        if self.playing and A then self.t = set.anims[self.anim] and set.anims[self.anim].starts[self.pos] or 0 end
    end
    if ui.button('>', bx + 142, by0 + 8, 30, 28, { tooltip = 'Cuadro siguiente (.)' }) then self.playing = false; self.pos = self.pos + 1 end
    bx = bx + 182
    -- barra de avance (se puede pulsar)
    local sw = math.max(60, cw - 182 - 300)
    ui.rect(bx, by0 + 18, sw, 8, th.bg, 4)
    if A and len > 0 then
        local tt = self.playing and (A.loop ~= false and self.t % len or math.min(self.t, len)) or (set.anims[self.anim] and set.anims[self.anim].starts[self.pos] or 0)
        ui.rect(bx, by0 + 18, math.max(4, sw * tt / len), 8, th.accent, 4)
        local seq = set.anims[self.anim]
        for k = 2, #seq.starts do ui.rect(bx + sw * seq.starts[k] / len - 1, by0 + 15, 2, 14, th.border, 0) end
        if not blocked and ui.inside(bx, by0 + 8, sw, 28) and ui.state.down then
            local tsel = (ui.state.mx - bx) / sw * len
            for k = #seq.starts, 1, -1 do if tsel >= seq.starts[k] then self.pos = k; break end end
            self.playing = false
        end
        ui.text(('cuadro %d de %d · %.2f s'):format(posK or 1, #A.frames, len), bx + sw + 10, by0 + 15, th.text, ui.fontSm)
    end
    local sx0 = cx + cw - 124
    for i, s in ipairs({ { 0.25, '¼' }, { 0.5, '½' }, { 1, '1×' }, { 2, '2×' } }) do
        if ui.button(s[2], sx0 + (i - 1) * 30, by0 + 10, 28, 24, { active = self.speed == s[1], font = ui.fontSm, tooltip = 'Velocidad de la vista (no cambia la animación)' }) then self.speed = s[1] end
    end

    -- ══ 3 · LÍNEA DE TIEMPO ══
    local ty0 = y + vh + 8
    ui.rect(cx, ty0, cw, TL, th.panel, 6)
    if A then
        ui.text(('3 · Línea de tiempo de «%s»: sus cuadros, en orden'):format(AnimPanel.FRIENDLY[self.anim] or self.anim), cx + 10, ty0 + 8, th.text)
        local S2 = 72
        local visible = math.floor((cw - 20) / (S2 + 6))
        local off = math.max(0, (self.pos - visible + 1)) * (S2 + 6)
        love.graphics.setScissor(cx + 6, ty0 + 30, cw - 12, S2 + 26)
        for k, idx in ipairs(A.frames) do
            local fx = cx + 10 + (k - 1) * (S2 + 6) - off
            if fx > cx - S2 and fx < cx + cw then
                local cur = k == self.pos
                ui.rect(fx, ty0 + 32, S2, S2, cur and th.accentDk or th.bg, 5)
                if cur then ui.rect(fx, ty0 + 32, S2, S2, th.accent, 5, 'line') end
                thumb(set, idx, fx + 4, ty0 + 36, S2 - 8, S2 - 8)
                ui.text(tostring(k), fx + 4, ty0 + 33, th.muted, ui.fontSm)
                local d = A.durations and tonumber(A.durations[k])
                ui.text((d and d > 0) and ('%.2f s'):format(d) or '', fx, ty0 + 34 + S2, th.warn, ui.fontSm, S2, 'center')
                if not blocked and ui.inside(fx, ty0 + 32, S2, S2) and ui.inside(cx, ty0 + 30, cw, S2 + 4) and ui.state.pressed then
                    self.pos, self.playing = k, false; ui.state.consumed = true
                end
            end
        end
        love.graphics.setScissor()
        local byb = ty0 + TL - 36
        local bx2 = cx + 10
        local lock = code and doc.strip ~= nil
        if ui.button('+ Añadir el cuadro ' .. self.frame .. ' del banco', bx2, byb, 220, 28, { color = th.accentDk, disabled = #doc.frames == 0,
                     tooltip = 'Mete en esta animación el cuadro elegido a la derecha (también: doble clic en el banco)' }) then
            self:addToTimeline(doc, self.frame); touch()
        end
        bx2 = bx2 + 228
        if ui.button('<', bx2, byb, 30, 28, { disabled = self.pos <= 1, tooltip = 'Mover este cuadro antes' }) then
            A.frames[self.pos], A.frames[self.pos - 1] = A.frames[self.pos - 1], A.frames[self.pos]
            if A.durations then A.durations[self.pos], A.durations[self.pos - 1] = A.durations[self.pos - 1], A.durations[self.pos] end
            self.pos = self.pos - 1; self.playing = false; touch()
        end
        if ui.button('>', bx2 + 34, byb, 30, 28, { disabled = self.pos >= #A.frames, tooltip = 'Mover este cuadro después' }) then
            A.frames[self.pos], A.frames[self.pos + 1] = A.frames[self.pos + 1], A.frames[self.pos]
            if A.durations then A.durations[self.pos], A.durations[self.pos + 1] = A.durations[self.pos + 1], A.durations[self.pos] end
            self.pos = self.pos + 1; self.playing = false; touch()
        end
        if ui.button('Quitar', bx2 + 68, byb, 70, 28, { disabled = #A.frames <= 1, textColor = th.danger, tooltip = 'Quita este cuadro de la animación (sigue en el banco)' }) then
            table.remove(A.frames, self.pos)
            if A.durations then table.remove(A.durations, self.pos) end
            self.pos = math.max(1, self.pos - 1); touch()
        end
        bx2 = bx2 + 148
        if cw - (bx2 - cx) > 290 then
            local d = A.durations and tonumber(A.durations[self.pos]) or 0
            local nd, dc = ui.number('Este cuadro dura (s; 0 = normal)', d, bx2, byb + 2, math.min(340, cw - (bx2 - cx) - 10), { min = 0, max = 10, step = 0.01 })
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
        if #A.frames == 1 then ui.text('Solo tiene un cuadro: no se mueve. Añádele más desde el banco.', cx + 10 + S2 + 16, ty0 + 60, th.warn, ui.fontSm) end
    else
        ui.text('3 · Línea de tiempo', cx + 10, ty0 + 8, th.muted)
        ui.text('Crea o elige una animación a la izquierda.', cx + 10, ty0 + 40, th.muted)
    end

    -- ══ BANCO DE CUADROS ══
    local rx = x + w - RW
    ui.rect(rx, y, RW, h, th.panel, 6)
    px, pw = rx + 10, RW - 20
    py = ui.caption(('Banco de cuadros (%d)'):format(#doc.frames), px, y + 10, pw)
    local lockFrames = code and doc.strip ~= nil
    if ui.button('+ Imágenes…', px, py, pw / 2 - 3, 28, { disabled = lockFrames, tooltip = 'Añade imágenes sueltas: cada una es un cuadro' }) then
        self.modal = { kind = 'image', multi = true, title = 'Añadir imágenes como cuadros', pick = function(p)
            doc.frames[#doc.frames + 1] = { image = p }; self.frame = #doc.frames; self.dirty = true end }
    end
    if ui.button('+ Cortar una hoja…', px + pw / 2 + 3, py, pw / 2 - 3, 28, { disabled = lockFrames, tooltip = 'Una imagen con varios cuadros en rejilla: se corta en cuadros' }) then
        self.modal = { kind = 'image', title = 'Elegir la hoja que se va a cortar', pick = function(p) self.modal = { kind = 'slice', image = p } end }
    end
    py = py + 36
    local TH, per = 60, 4
    local detailsH = 250
    local gridH = math.max(80, h - (py - y) - detailsH)
    local gy = ui.beginScroll('animbank' .. tostring(doc), px, py, pw, gridH, math.ceil(#doc.frames / per) * (TH + 6))
    local now = love.timer.getTime()
    for i = 1, #doc.frames do
        local tx = px + ((i - 1) % per) * (TH + 6)
        local tyy = gy + math.floor((i - 1) / per) * (TH + 6)
        if tyy > py - TH and tyy < py + gridH then
            local sel = i == self.frame
            ui.rect(tx, tyy, TH, TH, sel and th.accentDk or th.bg, 4)
            thumb(set, i, tx + 3, tyy + 3, TH - 6, TH - 6)
            ui.text(tostring(i), tx + 3, tyy + 1, sel and th.text or th.muted, ui.fontSm)
            if not blocked and ui.inside(tx, tyy, TH, TH) and ui.inside(px, py, pw, gridH) and ui.state.pressed then
                if self.lastFrame == i and now - self.lastClick < 0.4 and A and not lockFrames then       -- doble clic: a la línea de tiempo
                    self:addToTimeline(doc, i); touch()
                end
                self.frame, self.lastFrame, self.lastClick = i, i, now
                ui.state.consumed = true
            end
        end
    end
    ui.endScroll()
    py = py + gridH + 6
    local F = doc.frames[self.frame]
    local dy = ui.beginScroll('animdetail' .. tostring(doc), rx, py, RW, h - (py - y) - 6, 760) + 2
    if F then
        local open
        dy, open = ui.section('animsecframe', 'Cuadro ' .. self.frame .. ' (el elegido)', px, dy, pw, nil, true)
        if open then
            ui.label((F.image or ''):gsub('^assets/images/', ''), px, dy, pw, th.muted); dy = dy + 22
            if ui.button('Cambiar su imagen…', px, dy, pw, 24, { tooltip = 'Este cuadro pasa a usar otra imagen' }) then
                self.modal = { kind = 'image', title = 'Imagen para el cuadro ' .. self.frame, pick = function(p)
                    F.image = p; if not F.w then F.x, F.y = nil, nil end; self.dirty = true end }
            end
            dy = dy + 30
            local lf = set.frames[self.frame]
            local iw, ih = lf and lf.iw or 4096, lf and lf.ih or 4096
            local whole = F.w == nil
            local wholeOnly = (doc.meta and doc.meta.wholeImages) or F.key ~= nil     -- (imagen suelta que el juego carga por su nombre: entera)
            if not wholeOnly then
                local nv, ch = ui.toggle('Usa la imagen entera', whole, px, dy, pw); dy = dy + 26
                if ch then
                    if nv then F.x, F.y, F.w, F.h = nil, nil, nil, nil else F.x, F.y, F.w, F.h = 0, 0, iw, ih end
                    touch()
                end
                if not whole then
                    for _, fld in ipairs({ { 'x', 'Recorte: X', 0, iw - 1 }, { 'y', 'Recorte: Y', 0, ih - 1 }, { 'w', 'Recorte: ancho', 1, iw }, { 'h', 'Recorte: alto', 1, ih } }) do
                        local v, c2 = ui.number(fld[2], F[fld[1]] or 0, px, dy, pw, { min = fld[3], max = fld[4], step = 1, kind = 'int' }); dy = dy + 26
                        if c2 then F[fld[1]] = v; touch() end
                    end
                end
            end
            if not code then
                local bw3 = (pw - 8) / 3
                if ui.button('<', px, dy, bw3, 24, { disabled = self.frame <= 1, tooltip = 'Mover antes en el banco (las animaciones se ajustan solas)' }) then
                    swapFrames(doc, self.frame, self.frame - 1); self.frame = self.frame - 1; touch() end
                if ui.button('>', px + bw3 + 4, dy, bw3, 24, { disabled = self.frame >= #doc.frames }) then
                    swapFrames(doc, self.frame, self.frame + 1); self.frame = self.frame + 1; touch() end
                if ui.button('Eliminar', px + 2 * (bw3 + 4), dy, bw3, 24, { textColor = th.danger, tooltip = 'Lo quita del banco y de todas las animaciones' }) then
                    removeFrame(doc, self.frame); touch() end
                dy = dy + 32
            end
        end
    end
    local open
    dy, open = ui.section('animsecset', 'Ajustes del conjunto', px, dy, pw, nil, false)
    if open then
        local v, c2 = ui.number('Escala en el juego', doc.scale or 4, px, dy, pw, { min = 1, max = 16, step = 0.5 }); dy = dy + 28
        if c2 then doc.scale = v; touch() end
        doc.origin = doc.origin or { 0.5, 1 }
        v, c2 = ui.number('Ancla X (0 izq · 1 der)', doc.origin[1], px, dy, pw, { min = 0, max = 1, step = 0.05 }); dy = dy + 28
        if c2 then doc.origin[1] = v; touch() end
        v, c2 = ui.number('Ancla Y (0 arriba · 1 pies)', doc.origin[2], px, dy, pw, { min = 0, max = 1, step = 0.05 }); dy = dy + 28
        if c2 then doc.origin[2] = v; touch() end
        dy = dy + ui.hint('El ancla (la cruz amarilla de la vista) es el punto del dibujo que se apoya en el suelo.', px, dy, pw) + 6
    end
    dy, open = ui.section('animsecvar', 'Variantes', px, dy, pw, nil, false)
    if open then
        dy = dy + ui.hint('Una variante usa las MISMAS animaciones cambiando la carpeta (o el archivo) de las imágenes: así un conjunto sirve para el Gummy de cada isla.', px, dy, pw) + 6
        local vnames = {}
        for n in pairs(doc.variants or {}) do vnames[#vnames + 1] = n end
        table.sort(vnames)
        if #vnames > 0 then
            local opts = { { value = '', label = '(la de base)' } }
            for _, n in ipairs(vnames) do opts[#opts + 1] = { value = n, label = n } end
            local v, c2 = ui.enum('Ver en la vista', self.variant or '', opts, px, dy, pw); dy = dy + ui.ENUM_H + 4
            if c2 then self.variant = v ~= '' and v or nil; self.dirty = true end
        end
        for _, n in ipairs(vnames) do
            local V = doc.variants[n]
            ui.text(n, px, dy + 4, th.accent)
            if ui.button('Quitar', px + pw - 60, dy, 60, 22, { font = ui.fontSm, textColor = th.danger }) then
                doc.variants[n] = nil
                if next(doc.variants) == nil then doc.variants = nil end
                if self.variant == n then self.variant = nil end
                touch()
            else
                dy = dy + 26
                local v, c2 = ui.textField('animvf' .. n .. tostring(doc), V.from or '', px, dy, pw, 120, 'cambia esta ruta…'); dy = dy + 28
                if c2 then V.from = v; touch() end
                v, c2 = ui.textField('animvt' .. n .. tostring(doc), V.to or '', px, dy, pw, 120, '…por esta'); dy = dy + 32
                if c2 then V.to = v; touch() end
            end
        end
        self.newVar = ui.textField('animvnew' .. tostring(doc), self.newVar or '', px, dy, pw - 78, 24, 'variante nueva…')
        if ui.button('+ Crear', px + pw - 72, dy, 72, 26, { disabled = (self.newVar or '') == '' or (doc.variants and doc.variants[self.newVar] ~= nil) }) then
            doc.variants = doc.variants or {}
            local dir = doc.frames[1] and doc.frames[1].image and doc.frames[1].image:match('^(.*)/[^/]*$') or 'assets/images'
            doc.variants[self.newVar] = { from = dir .. '/', to = dir .. '_' .. self.newVar .. '/' }
            self.newVar = ''; touch()
        end
        dy = dy + 34
    end
    ui.endScroll()

    if blocked then ui.state.pressed, ui.state.wheel = savedPressed, savedWheel end
    if self:drawModal(doc) then touch() end
    return changed
end

-- Teclas del panel (true si la usó): espacio = reproducir / pausa; , . = cuadro anterior / siguiente
function AnimPanel:keypressed(k)
    if ui.hasFocus() or self.modal then return false end
    if k == 'space' then self.playing = not self.playing; return true end
    if k == ',' then self.playing = false; self.pos = math.max(1, self.pos - 1); return true end
    if k == '.' then self.playing = false; self.pos = self.pos + 1; return true end
    return false
end

return AnimPanel
