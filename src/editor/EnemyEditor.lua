-- src/editor/EnemyEditor.lua
-- EDITOR DE ENEMIGOS:   love . --enemy [id]
-- Monta un enemigo SIN escribir código: sus datos (assets/enemies/<id>.json, ver
-- src/world/entities/base/DataEnemy.lua) y su conjunto de animación (assets/anim/<id>.json), con el editor de
-- animaciones dentro (la pieza src/editor/AnimPanel.lua). Pestañas:
--   General          nombre, categoría, tamaño, caja de golpe (se ve sobre el dibujo), vida, valores por defecto, rasgos
--   Animaciones      el editor de animaciones, con las secuencias que piden sus estados
--   Estados          qué secuencia se ve en cada estado (idle, walk, hurt, dead + los de sus comportamientos)
--   Comportamientos  piezas del catálogo (src/world/entities/behaviors/): perseguir, atacar, saltar, disparar…
--   Avisos           lo que le falta
-- "Probar" (F5) guarda y lo suelta en una sala de prueba dentro del juego (F10 vuelve).
-- Un enemigo guardado sale en el editor de niveles como cualquier otro tipo. OJO: un enemigo NUEVO es un tipo de
-- entidad nuevo → antes de publicarlo, subir Protocol.VERSION y version.txt (docs/entities/enemy-editor.md).
local ui          = require 'src/editor/ui'
local Shell       = require 'src/editor/ToolShell'
local Anim        = require 'src/fx/Anim'
local AnimPanel   = require 'src/editor/AnimPanel'
local AnimEditor  = require 'src/editor/AnimEditor'
local json        = require 'libs/json'
local th = ui.theme

local E = { ids = {}, id = nil, spec = nil, animDoc = nil, panel = AnimPanel.new(), tab = 'general', unsaved = false,
            newId = '', previewState = 'idle', pt = 0 }
E.ORDER = { 'id', 'label', 'category', 'description', 'anim', 'variant', 'scale', 'facesLeft', 'breathe', 'hitbox', 'hp', 'hurtTime',
            'defaults', 'traits', 'darkEdge', 'states', 'behaviors', 'sounds' }
local DataEnemy, Behaviors, EntityTypes       -- (se cargan en load: necesitan los globales del juego)

local TRAITS = {
    { 'needsPound', 'Duro: solo lo mata un ground pound' },
    { 'renderFront', 'Se dibuja por delante del jugador' },
    { 'freezeFloats', 'Congelado se queda en el sitio (no cae)' },
}
-- Props comunes que el editor deja fijar como valores por defecto del enemigo
local DEFAULT_KEYS = { movement = true, speed = true, onTouch = true, stompable = true, points = true, pauses = true,
                       turnAtEdges = true, respawn = true, bobAmp = true, flyMode = true }

local function touch() E.unsaved = true end

-- Cuadros a partir de las imágenes de assets/images/enemies/<id>/ (si el usuario ya las dibujó): las secuencias
-- salen del nombre de cada archivo (…idle… → idle, …dead… → dead, etc.; lo demás, andar).
local GUESS = { { 'idle', 'idle' }, { 'quieto', 'idle' }, { 'dead', 'dead' }, { 'muert', 'dead' }, { 'hurt', 'hurt' }, { 'dano', 'hurt' },
                { 'attack', 'attack' }, { 'ataque', 'attack' }, { 'atk', 'attack' }, { 'run', 'run' }, { 'corr', 'run' },
                { 'special', 'special' }, { 'shot', 'shot' }, { 'bala', 'shot' } }
local function importFolder(id)
    local dir = 'assets/images/enemies/' .. id
    if not love.filesystem.getInfo(dir) then return nil end
    local doc = { id = id, scale = 4, origin = { 0.5, 1 }, frames = {}, anims = {} }
    for _, p in ipairs(Shell.listFiles(dir, '.png')) do
        doc.frames[#doc.frames + 1] = { image = p }
        local name, seq = p:match('([^/]+)%.png$'):lower(), 'walk'
        for _, g in ipairs(GUESS) do if name:find(g[1], 1, true) then seq = g[2]; break end end
        doc.anims[seq] = doc.anims[seq] or { frames = {}, fps = seq == 'idle' and 3 or 7, loop = seq ~= 'dead' }
        table.insert(doc.anims[seq].frames, #doc.frames)
    end
    if #doc.frames == 0 then return nil end
    return doc
end

local function refresh() E.ids = DataEnemy.ids() end

function E.open(id)
    local spec, err = DataEnemy.read(id)
    if not spec then return Shell.message('No se puede abrir ' .. id .. ': ' .. tostring(err), 'error') end
    local base = DataEnemy.blank(id)
    for k, v in pairs(base) do if spec[k] == nil then spec[k] = v end end
    E.id, E.spec, E.unsaved, E.tab = id, spec, false, E.tab or 'general'
    E.animDoc = Anim.read(spec.anim) or { id = spec.anim, scale = 4, origin = { 0.5, 1 }, frames = {}, anims = {} }
    E.animDoc.id = spec.anim
    E.panel = AnimPanel.new()
end

function E.new(id)
    if not id:match('^[%l][%l%d_]*$') then return Shell.message('El id solo puede llevar minúsculas, números y _', 'error') end
    if EntityTypes.byName[id] or love.filesystem.getInfo(DataEnemy.DIR .. id .. '.json') then
        return Shell.message('Ya existe un tipo de entidad "' .. id .. '"', 'error')
    end
    E.id, E.spec, E.unsaved = id, DataEnemy.blank(id), true
    E.spec.label = id:sub(1, 1):upper() .. id:sub(2)
    local found = Anim.read(id)
    local imported = not found and importFolder(id)
    E.animDoc = found or imported or { id = id, scale = 4, origin = { 0.5, 1 }, frames = {}, anims = {} }
    E.animDoc.id = id
    E.panel = AnimPanel.new()
    if imported then Shell.message(('Cuadros tomados de assets/images/enemies/%s/ (%d): revisa las secuencias en "Animaciones"'):format(id, #imported.frames)) end
end

function E.save(quiet)
    if not E.spec then return false end
    local ok, err = AnimEditor.write(E.animDoc)
    if ok then ok, err = Shell.writeRepo(DataEnemy.DIR .. E.id .. '.json', Shell.encodeJson(E.spec, E.ORDER)) end
    if ok then
        local ids, has = DataEnemy.ids(), false
        for _, i in ipairs(ids) do if i == E.id then has = true end end
        if not has then
            ids[#ids + 1] = E.id
            ok, err = Shell.writeRepo(DataEnemy.INDEX, Shell.encodeJson({ enemies = ids }))
        end
    end
    if not ok then Shell.message('No se pudo guardar: ' .. tostring(err), 'error'); return false end
    E.unsaved = false
    refresh()
    -- el tipo, al día en esta sesión (para "Probar")
    EntityTypes.unregister(E.id)
    local good, def = pcall(DataEnemy.typeDef, E.spec)
    if good then EntityTypes.register(def) end
    if not quiet then Shell.message('Guardado ' .. DataEnemy.DIR .. E.id .. '.json y ' .. Anim.path(E.animDoc.id)) end
    return good
end

-- Sala de prueba: suelo, dos alturas y un hueco; el enemigo en el suelo y en la repisa
function E.play()
    if #E.animDoc.frames == 0 then return Shell.message('Primero añade cuadros en "Animaciones"', 'error') end
    if not E.save(true) then return Shell.message('No se pudo preparar el enemigo: revisa "Avisos"', 'error') end
    local W, H, tiles = 44, 12, {}
    for r = 1, H do
        local row = {}
        for c = 1, W do row[c] = (r == H or c == 1 or c == W or r == 1) and 1 or 0 end
        tiles[r] = row
    end
    for c = 24, 32 do tiles[8][c] = 1 end                       -- una repisa
    for c = 36, 39 do tiles[5][c] = 1 end
    local fly = E.spec.defaults and E.spec.defaults.movement == 'fly'
    local ents = {
        { type = E.id, col = 14, row = fly and 8 or 11, props = { patrol = { left = 9, right = 21 } } },
        { type = E.id, col = 28, row = fly and 4 or 7, props = { patrol = { left = 24, right = 32 }, startDir = 'left' } },
        { type = 'checkpoint', col = 4, row = 11 },
    }
    Shell.play({ name = 'Prueba: ' .. (E.spec.label or E.id), width = W, height = H, playerStart = { 4, 11 }, tiles = tiles,
                 entities = ents, foliage = {}, vents = {}, background = 'meadow' })
end

-- ── Campos genéricos (de un esquema {key, kind, label, min, max, step, options, help}) ──
local function field(p, obj, x, y, w, idp)
    local v = obj[p.key]
    if v == nil then v = p.default end
    if type(v) == 'function' then return y end
    local nv, ch = v, false
    if p.kind == 'bool' then nv, ch = ui.toggle(p.label, v == true, x, y, w); y = y + 28
    elseif p.kind == 'number' or p.kind == 'int' then nv, ch = ui.number(p.label, tonumber(v) or 0, x, y, w, p); y = y + 28
    elseif p.kind == 'enum' then nv, ch = ui.enum(p.label, v, p.options, x, y, w); y = y + ui.ENUM_H + 4
    elseif p.kind == 'text' then
        ui.label(p.label, x, y, w, th.text); y = y + 22
        nv, ch = ui.textField((idp or '') .. p.key, tostring(v or ''), x, y, w, p.maxLen or 60, p.placeholder); y = y + 32
    else return y end
    if ch then obj[p.key] = nv; touch() end
    return y
end

-- Vista del enemigo con sus cajas (la de fuera = donde se le toca / pisa; la de dentro = donde hace daño)
local function drawPreview(x, y, w, h)
    ui.rect(x, y, w, h, th.canvas, 6)
    local set = E.panel:set(E.animDoc)
    if #E.animDoc.frames == 0 then
        ui.text('Sin cuadros todavía: pestaña "Animaciones"', x, y + h / 2 - 8, th.muted, ui.font, w, 'center')
        return
    end
    E.pt = E.pt + love.timer.getDelta()
    local name = (E.spec.states or {})[E.previewState] or E.previewState
    local S = E.spec.scale or 4
    local zoom = math.max(1, math.floor(math.min(w * 0.5 / (set:size(1) * S), h * 0.55 / (select(2, set:size(1)) * S))))
    local k = S * zoom
    local cx, fy = math.floor(x + w / 2), math.floor(y + h * 0.72)
    love.graphics.setScissor(x, y, w, h)
    ui.setColor(th.border, 0.8); love.graphics.line(x + 12, fy + 0.5, x + w - 12, fy + 0.5)          -- el suelo
    love.graphics.setColor(1, 1, 1, 1)
    set:draw(name, E.pt, cx, fy, 0, k * (E.spec.facesLeft and -1 or 1), k, 0.5, 1)
    local fw, fh = set:size(1)
    local sw, sh = fw * k, fh * k
    local hb = E.spec.hitbox
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 0.55, 0, 0.9)
    love.graphics.rectangle('line', cx - sw * hb.outerW / 2, fy - sh / 2 - sh * hb.outerH / 2, sw * hb.outerW, sh * hb.outerH)
    love.graphics.setColor(1, 0.9, 0.2, 0.9)
    love.graphics.rectangle('line', cx - sw * hb.innerW / 2, fy - sh / 2 - sh * hb.innerH / 2, sw * hb.innerW, sh * hb.innerH)
    love.graphics.setLineWidth(1)
    love.graphics.setScissor()
    ui.text(('"%s" · %dx%d px en el juego (una casilla = 64)'):format(name, fw * S, fh * S), x + 10, y + 8, th.muted, ui.fontSm)
    ui.text('naranja: donde se le toca / pisa · amarillo: donde hace daño', x + 10, y + h - 20, th.muted, ui.fontSm)
end

-- ── Pestañas ──────────────────────────────────────────────────────────────────
local function tabGeneral(x, y, w, h)
    local S = E.spec
    local fw = math.min(430, math.floor(w * 0.45))
    local px, pw = x + 10, fw - 24
    ui.rect(x, y, fw, h, th.panel, 6)
    local py = ui.beginScroll('enemygeneral', x, y + 6, fw, h - 12, 1320) + 4
    py = ui.caption('Identidad', px, py, pw)
    ui.label('Id (en niveles y red): ' .. E.id, px, py, pw, th.muted); py = py + 24
    py = field({ key = 'label', kind = 'text', label = 'Nombre en el editor de niveles' }, S, px, py, pw, 'en')
    py = field({ key = 'description', kind = 'text', label = 'Descripción (paleta)', maxLen = 120 }, S, px, py, pw, 'en')
    local cats = {}
    for _, c in ipairs(DataEnemy.CATEGORIES) do cats[#cats + 1] = { value = c, label = c } end
    py = field({ key = 'category', kind = 'enum', label = 'Categoría', options = cats }, S, px, py, pw)
    py = ui.caption('Dibujo', px, py, pw)
    py = field({ key = 'scale', kind = 'number', label = 'Escala (px por píxel de arte)', min = 1, max = 16, step = 0.5 }, S, px, py, pw)
    py = field({ key = 'facesLeft', kind = 'bool', label = 'El dibujo mira a la izquierda' }, S, px, py, pw)
    py = field({ key = 'breathe', kind = 'bool', label = '"Respira" cuando está quieto' }, S, px, py, pw)
    local edge = S.darkEdge ~= nil
    local nv, ch = ui.toggle('Filo claro en lo oscuro (sprite oscuro)', edge, px, py, pw); py = py + 28
    if ch then S.darkEdge = nv and { 1, 0.8, 0.55, 0.9 } or nil; touch() end
    py = ui.caption('Caja de golpe (× el tamaño del sprite)', px, py, pw)
    for _, f in ipairs({ { 'outerW', 'Fuera: ancho' }, { 'outerH', 'Fuera: alto' }, { 'innerW', 'Dentro: ancho' }, { 'innerH', 'Dentro: alto' } }) do
        py = field({ key = f[1], kind = 'number', label = f[2], min = 0.05, max = 1.5, step = 0.02 }, S.hitbox, px, py, pw)
    end
    py = ui.caption('Vida', px, py, pw)
    py = field({ key = 'hp', kind = 'int', label = 'Golpes que aguanta', min = 1, max = 20, step = 1 }, S, px, py, pw)
    if (S.hp or 1) > 1 then
        py = field({ key = 'hurtTime', kind = 'number', label = 'Dolido (s, intocable) tras cada golpe', min = 0.1, max = 3, step = 0.05 }, S, px, py, pw)
    end
    py = ui.caption('Valores por defecto (se pueden cambiar en cada nivel)', px, py, pw)
    for _, p in ipairs(EntityTypes.COMMON) do
        if DEFAULT_KEYS[p.key] and (not p.showIf or p.showIf(setmetatable({}, { __index = function(_, k2)
                local v = S.defaults[k2]
                if v ~= nil then return v end
                for _, q in ipairs(EntityTypes.COMMON) do if q.key == k2 then return q.default end end
            end }))) then
            py = field(p, S.defaults, px, py, pw)
        end
    end
    py = ui.caption('Rasgos', px, py, pw)
    for _, t in ipairs(TRAITS) do
        local v, c2 = ui.toggle(t[2], S.traits[t[1]] == true, px, py, pw); py = py + 28
        if c2 then S.traits[t[1]] = v or nil; touch() end
    end
    ui.endScroll()
    -- la vista
    local vx, vw = x + fw + 8, w - fw - 8
    drawPreview(vx, y, vw, h - 44)
    local states = DataEnemy.statesOf(S)
    local bx = vx
    for _, s in ipairs(states) do
        local bw = ui.font:getWidth(s) + 22
        if bx + bw > vx + vw then break end
        if ui.button(s, bx, y + h - 36, bw, 28, { active = s == E.previewState }) then E.previewState, E.pt = s, 0 end
        bx = bx + bw + 4
    end
end

local function tabStates(x, y, w, h)
    local S = E.spec
    ui.rect(x, y, w, h, th.panel, 6)
    local px, py, pw = x + 14, y + 12, math.min(760, w - 28)
    py = py + ui.hint('Cada ESTADO del enemigo enseña una secuencia de su conjunto de animación. Los de base los tiene siempre; los demás los traen sus comportamientos. '
        .. 'Si una secuencia no existe se ve la de reserva del conjunto.', px, py, pw) + 10
    local set = E.panel:set(E.animDoc)
    local opts = { { value = '', label = '(la del mismo nombre)' } }
    for _, n in ipairs(set.names) do opts[#opts + 1] = { value = n, label = n } end
    local WHY = { idle = 'quieto (pausas)', walk = 'andando / volando', hurt = 'recién golpeado (más de 1 de vida) y aturdido', dead = 'pisoteado',
                  run = 'persiguiendo', attack = 'atacando / disparando', special = 'acción especial (salto)' }
    for _, st in ipairs(DataEnemy.statesOf(S)) do
        local cur = (S.states or {})[st] or ''
        local shown = cur ~= '' and cur or st
        ui.rect(px, py, pw, 62, th.panel2, 5)
        -- miniatura animada
        if #E.animDoc.frames > 0 then
            local fw2, fh2 = set:size(1)
            local k = math.max(1, math.floor(math.min(50 / fw2, 50 / fh2)))
            love.graphics.setColor(1, 1, 1, 1)
            set:draw(shown, love.timer.getTime(), px + 34, py + 56, 0, k, k, 0.5, 1)
        end
        ui.text(st, px + 74, py + 8, th.text, ui.fontLg)
        ui.text(WHY[st] or 'estado propio', px + 74, py + 32, th.muted, ui.fontSm)
        if not set:has(shown) then ui.text('no existe "' .. shown .. '"', px + 74, py + 46, th.warn, ui.fontSm) end
        local v, c2 = ui.enum('', cur, opts, px + pw - 330, py - 6, 320)
        if c2 then
            S.states = S.states or {}
            S.states[st] = v ~= '' and v or nil
            touch()
        end
        py = py + 68
    end
end

local function tabBehaviors(x, y, w, h)
    local S = E.spec
    ui.rect(x, y, w, h, th.panel, 6)
    local px, pw = x + 14, math.min(620, w - 340)
    local n = 0
    for _, b in ipairs(S.behaviors) do n = n + 70 + #(Behaviors.byName[b.type] and Behaviors.byName[b.type].params or {}) * 28 end
    local py = ui.beginScroll('enemybeh', x, y + 6, pw + 28, h - 12, n + 120) + 6
    py = py + ui.hint('Sin comportamientos anda, vuela o se queda quieto como diga su movimiento. Cada pieza toma el mando cuando se cumple su condición; '
        .. 'si varias pueden, manda la de más arriba.', px, py, pw) + 10
    local remove, swap
    for i, b in ipairs(S.behaviors) do
        local def = Behaviors.byName[b.type]
        ui.rect(px, py, pw, 30, th.panel2, 5)
        ui.text(i .. '. ' .. (def and def.label or ('¿' .. tostring(b.type) .. '?')), px + 10, py + 6, th.text, ui.fontLg)
        if ui.button('^', px + pw - 150, py + 3, 28, 24, { disabled = i == 1 }) then swap = { i, i - 1 } end
        if ui.button('v', px + pw - 118, py + 3, 28, 24, { disabled = i == #S.behaviors }) then swap = { i, i + 1 } end
        if ui.button('Quitar', px + pw - 84, py + 3, 78, 24, { textColor = th.danger }) then remove = i end
        py = py + 34
        if def then
            ui.text(def.description or '', px + 10, py, th.muted, ui.fontSm, pw - 20); py = py + 20
            for _, p in ipairs(def.params) do py = field(p, b, px + 10, py, pw - 20) end
        end
        py = py + 12
    end
    ui.endScroll()
    if remove then table.remove(S.behaviors, remove); touch() end
    if swap then S.behaviors[swap[1]], S.behaviors[swap[2]] = S.behaviors[swap[2]], S.behaviors[swap[1]]; touch() end
    -- el catálogo
    local cx, cw = x + pw + 44, w - pw - 58
    local cy = ui.caption('Añadir', cx, y + 14, cw)
    for _, def in ipairs(Behaviors.list) do
        if ui.button('+ ' .. def.label, cx, cy, cw, 28, { align = 'left' }) then
            S.behaviors[#S.behaviors + 1] = { type = def.name }; touch()
        end
        cy = cy + 30
        cy = cy + ui.hint(def.description .. '  Estados: ' .. table.concat(def.states, ', '), cx, cy, cw) + 8
    end
    ui.hint('¿Falta una pieza? Es un archivo en src/world/entities/behaviors/ + su nombre en Behaviors.lua (la receta está arriba de ese archivo).', cx, cy + 4, cw, th.accentDk)
end

local function tabWarnings(x, y, w, h, warns)
    ui.rect(x, y, w, h, th.panel, 6)
    local py = y + 14
    if #warns == 0 then ui.text('Sin avisos: el enemigo está completo.', x + 16, py, th.ok); return end
    for _, t in ipairs(warns) do py = py + ui.hint(t, x + 14, py, math.min(800, w - 28), th.warn) + 6 end
end

-- ── Marco ─────────────────────────────────────────────────────────────────────
local function load()
    require 'settings'
    DataEnemy   = require 'src/world/entities/base/DataEnemy'
    Behaviors   = require 'src/world/entities/behaviors/Behaviors'
    EntityTypes = require('src/world/entities/Entities').types
    refresh()
    local want
    for i, a in ipairs(arg or {}) do if a == '--enemy' then want = arg[i + 1] end end
    if want and not want:match('^%-') then
        if love.filesystem.getInfo(DataEnemy.DIR .. want .. '.json') then E.open(want) else E.new(want) end
    elseif E.ids[1] then E.open(E.ids[1]) end
end

local function draw()
    local W, H = love.graphics.getDimensions()
    ui.rect(0, 0, W, 46, th.panel, 0)
    ui.text('Enemigos', 14, 12, th.text, ui.fontLg)
    local LW = 210
    -- la lista
    ui.rect(8, 54, LW, H - 54 - 34, th.panel, 6)
    local ly = ui.caption(('Hechos con datos (%d)'):format(#E.ids), 18, 64, LW - 20)
    for _, id in ipairs(E.ids) do
        if ui.button(id, 18, ly, LW - 20, 26, { align = 'left', active = id == E.id }) then E.open(id) end
        ly = ly + 30
    end
    if E.id and E.unsaved then
        local listed = false
        for _, id in ipairs(E.ids) do if id == E.id then listed = true end end
        if not listed then ui.button(E.id .. ' (nuevo)', 18, ly, LW - 20, 26, { align = 'left', active = true }); ly = ly + 30 end
    end
    ly = ly + 10
    E.newId = ui.textField('enemynew', E.newId, 18, ly, LW - 20, 24, 'id del nuevo…'); ly = ly + 32
    if ui.button('+ Nuevo enemigo', 18, ly, LW - 20, 28, { disabled = E.newId == '' }) then E.new(E.newId); E.newId = '' end
    ly = ly + 38
    ui.hint('Con dibujos en assets/images/enemies/<id>/ el enemigo nuevo los toma solo como cuadros.', 18, ly, LW - 20)

    if not E.spec then
        ui.hint('Escribe un id (minúsculas, sin espacios) y pulsa "+ Nuevo enemigo".', LW + 28, 70, 520)
        return
    end
    local warns = DataEnemy.validate(E.spec, E.panel:set(E.animDoc))
    local x, w = LW + 16, W - LW - 24
    if ui.button('Guardar', W - 392, 9, 132, 28, { hint = 'Ctrl+S', color = E.unsaved and th.accentDk or nil }) then E.save() end
    if ui.button('Probar', W - 252, 9, 110, 28, { hint = 'F5', tooltip = 'Guarda y lo suelta en una sala de prueba (F10 vuelve)' }) then E.play() end
    if E.unsaved then ui.text('* sin guardar', W - 108, 15, th.warn) end
    E.tab = ui.tabs({ { id = 'general', label = 'General' }, { id = 'anim', label = 'Animaciones' }, { id = 'states', label = 'Estados' },
                      { id = 'beh', label = 'Comportamientos', badge = #E.spec.behaviors > 0 and #E.spec.behaviors or nil },
                      { id = 'warn', label = 'Avisos', badge = #warns > 0 and #warns or nil, badgeColor = th.warn } }, E.tab, x, 8, math.min(720, w - 350), 34)
    local y, h = 54, H - 54 - 34
    if E.tab == 'general' then tabGeneral(x, y, w, h)
    elseif E.tab == 'anim' then
        E.panel.wanted = {}
        for _, st in ipairs(DataEnemy.statesOf(E.spec)) do E.panel.wanted[#E.panel.wanted + 1] = (E.spec.states or {})[st] or st end
        if E.panel:draw(E.animDoc, x, y, w, h) then touch() end
    elseif E.tab == 'states' then tabStates(x, y, w, h)
    elseif E.tab == 'beh' then tabBehaviors(x, y, w, h)
    else tabWarnings(x, y, w, h, warns) end
end

local function keypressed(k)
    if ui.hasFocus() then return end
    local ctrl = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    if ctrl and k == 's' then return E.save() end
    if k == 'f5' then return E.play() end
    if E.tab == 'anim' then E.panel:keypressed(k) end
end

function E.install()
    Shell.install({ title = 'Editor de enemigos', load = load, draw = draw, keypressed = keypressed,
                    unsaved = function() return E.unsaved end,
                    status = function() return 'Ctrl+S: guardar  ·  F5: probar en el juego (F10 vuelve)  ·  un enemigo guardado sale en el editor de niveles' end })
end

return E
