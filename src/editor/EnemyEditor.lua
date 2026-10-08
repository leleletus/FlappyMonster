-- src/editor/EnemyEditor.lua
-- EDITOR DE ENEMIGOS:   love . --enemy [id]
-- Monta un enemigo SIN escribir código: sus datos (assets/enemies/<id>.json, ver
-- src/world/entities/base/DataEnemy.lua) y su conjunto de animación (assets/anim/<id>.json), con el editor de
-- animaciones dentro (la pieza src/editor/AnimPanel.lua). Se hace en PASOS, de izquierda a derecha:
--   1 Dibujos        el editor de animaciones: sus cuadros y sus animaciones (quieto, andar, ataque…)
--   2 Cómo es        enemigo o JEFE, nombre, tamaño, caja de golpe (se ve sobre el dibujo), vida, cómo se mueve
--                    (anda, vuela, quieto, TREPA por paredes y techos), valores por defecto, rasgos
--   3 Qué hace       piezas del catálogo (src/world/entities/behaviors/): perseguir, atacar, saltar, disparar, esconderse…
--   4 Estados        qué animación se ve en cada estado
--   Avisos           lo que le falta
-- Deshacer (Ctrl+Z) y rehacer (Ctrl+Y) en todo; "Borrar" quita el enemigo (si ningún nivel lo usa).
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

local E = { ids = {}, id = nil, spec = nil, animDoc = nil, panel = AnimPanel.new(), tab = 'anim', unsaved = false,
            newId = '', previewState = 'idle', pt = 0 }
E.ORDER = { 'id', 'label', 'category', 'description', 'boss', 'anim', 'variant', 'scale', 'facesLeft', 'breathe', 'crawl', 'hitbox', 'hp', 'hurtTime',
            'defaults', 'traits', 'darkEdge', 'states', 'behaviors', 'sounds' }
local DataEnemy, DataBoss, Behaviors, EntityTypes       -- (se cargan en load: necesitan los globales del juego)

local TRAITS = {
    { 'needsPound', 'Duro: solo lo mata un ground pound' },
    { 'renderFront', 'Se dibuja por delante del jugador' },
    { 'freezeFloats', 'Congelado se queda en el sitio (no cae)' },
}
-- Props comunes que el editor deja fijar como valores por defecto del enemigo
local DEFAULT_KEYS = { movement = true, speed = true, onTouch = true, stompable = true, points = true, pauses = true,
                       turnAtEdges = true, respawn = true, bobAmp = true, flyMode = true }

local function touch() E.unsaved = true; if E.hist then E.hist:record() end end
E.hist = Shell.history(function() return { spec = E.spec or {}, anim = E.animDoc or {} } end,
                       function(d) E.spec, E.animDoc = d.spec, d.anim; E.panel:touch(); E.unsaved = true end)

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
    E.hist:reset()
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
    E.tab = 'anim'
    E.hist:reset()
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
    if E.spec.boss then
        -- Jefe: una arena cerrada con su zona; la pelea empieza al entrar
        for c = 24, 32 do tiles[8][c] = 0 end
        for c = 36, 39 do tiles[5][c] = 0 end
        for c = 16, 20 do tiles[8][c] = 1 end
        for c = 30, 34 do tiles[8][c] = 1 end
        return Shell.play({ name = 'Prueba: ' .. (E.spec.label or E.id), width = W, height = H, playerStart = { 4, 11 }, tiles = tiles,
                            entities = { { type = E.id, col = 30, row = 11 }, { type = 'apple', col = 7, row = 11 } },
                            bossZones = { { id = 1, col = 10, row = 2, w = 33, h = 10 } }, foliage = {}, vents = {}, background = 'meadow' })
    end
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
    local py = ui.beginScroll('enemygeneral', x, y + 6, fw, h - 12, 1900) + 4
    py = ui.caption('Qué es', px, py, pw)
    local kind, kc = ui.enum('', S.boss and 'boss' or 'enemy', { { value = 'enemy', label = 'Enemigo normal' }, { value = 'boss', label = 'JEFE' } }, px, py - 20, pw)
    py = py + 34
    if kc then
        if kind == 'boss' then
            S.boss = {}
            for k, v in pairs(DataBoss.DEFAULTS) do S.boss[k] = v end
            S.boss.title = (S.label or E.id):upper(); S.boss.title_en = S.boss.title
            S.crawl = nil
        else S.boss = nil end
        touch()
    end
    if S.boss then
        py = py + ui.hint('Un JEFE vive en una ZONA DE JEFE del nivel (editor de niveles → capa Especial): tiene barra de vida, entrada, y solo se le puede golpear cuando lo dice "Se le puede golpear". Sus ataques son las piezas del paso 3.', px, py, pw, th.accent) + 6
        local B = S.boss
        py = field({ key = 'title', kind = 'text', label = 'Nombre en la barra (español, MAYÚSCULAS)', maxLen = 28 }, B, px, py, pw, 'eb')
        py = field({ key = 'title_en', kind = 'text', label = 'Nombre en la barra (inglés)', maxLen = 28 }, B, px, py, pw, 'eb')
        py = field({ key = 'hp', kind = 'int', label = 'Vida (1 jugador)', min = 1, max = 300, step = 1 }, B, px, py, pw)
        py = field({ key = 'hpPerPlayer', kind = 'int', label = 'Vida extra por jugador (online)', min = 0, max = 100, step = 1 }, B, px, py, pw)
        py = field({ key = 'vulnerable', kind = 'enum', label = 'Se le puede golpear', options = { { value = 'tired', label = 'Cansado, tras cada ataque' }, { value = 'always', label = 'Siempre' } } }, B, px, py, pw)
        if (B.vulnerable or 'tired') == 'tired' then
            py = field({ key = 'tiredTime', kind = 'number', label = 'Se queda cansado (s)', min = 0.3, max = 10, step = 0.1 }, B, px, py, pw)
        end
        py = field({ key = 'walkSpeed', kind = 'number', label = 'Velocidad persiguiendo (px/s; 0 = quieto)', min = 0, max = 600, step = 10 }, B, px, py, pw)
        py = field({ key = 'attackEvery', kind = 'number', label = 'Espera entre ataques (s)', min = 0, max = 10, step = 0.1 }, B, px, py, pw)
        py = field({ key = 'contact', kind = 'int', label = 'Vida que quita al tocarlo', min = 0, max = 3, step = 1 }, B, px, py, pw)
        py = field({ key = 'rageAt', kind = 'number', label = 'Fase 2 con esta fracción de vida', min = 0, max = 1, step = 0.05 }, B, px, py, pw)
        py = field({ key = 'ragePace', kind = 'number', label = 'En la fase 2 va (× de rápido)', min = 1, max = 3, step = 0.05 }, B, px, py, pw)
        py = field({ key = 'intro', kind = 'number', label = 'Entrada: cae del cielo en (s; 0 = sin entrada)', min = 0, max = 8, step = 0.5 }, B, px, py, pw)
    end
    py = ui.caption('Identidad', px, py, pw)
    ui.label('Id (en niveles y red): ' .. E.id, px, py, pw, th.muted); py = py + 24
    py = field({ key = 'label', kind = 'text', label = 'Nombre en el editor de niveles' }, S, px, py, pw, 'en')
    py = field({ key = 'description', kind = 'text', label = 'Descripción (paleta)', maxLen = 120 }, S, px, py, pw, 'en')
    local cats = {}
    for _, c in ipairs(DataEnemy.CATEGORIES) do cats[#cats + 1] = { value = c, label = c } end
    if not S.boss then py = field({ key = 'category', kind = 'enum', label = 'Categoría (en la paleta del editor de niveles)', options = cats }, S, px, py, pw) end
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
    if not S.boss then
    py = ui.caption('Vida', px, py, pw)
    py = field({ key = 'hp', kind = 'int', label = 'Golpes que aguanta', min = 1, max = 20, step = 1 }, S, px, py, pw)
    if (S.hp or 1) > 1 then
        py = field({ key = 'hurtTime', kind = 'number', label = 'Dolido (s, intocable) tras cada golpe', min = 0.1, max = 3, step = 0.05 }, S, px, py, pw)
    end
    py = ui.caption('Cómo se mueve', px, py, pw)
    local mv = (S.defaults.movement or 'walk')
    if mv == 'walk' then
        local cv, cc = ui.toggle('TREPA: anda también por paredes y techos', S.crawl == true, px, py, pw); py = py + 28
        if cc then S.crawl = cv or nil; touch() end
        if S.crawl then py = py + ui.hint('Trepando solo valen los comportamientos "Esconderse" (los demás necesitan andar por el suelo).', px, py, pw) + 6 end
    elseif S.crawl then S.crawl = nil end
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
                  run = 'persiguiendo', attack = 'atacando / disparando', special = 'acción especial (salto)', tired = 'cansado tras atacar (ahí se le golpea)', hide = 'escondiéndose / escondido / saliendo' }
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
    DataBoss    = require 'src/world/entities/base/DataBoss'
    Behaviors   = require 'src/world/entities/behaviors/Behaviors'
    EntityTypes = require('src/world/entities/Entities').types
    refresh()
    local want
    for i, a in ipairs(arg or {}) do if a == '--enemy' then want = arg[i + 1] end end
    if want and not want:match('^%-') then
        if love.filesystem.getInfo(DataEnemy.DIR .. want .. '.json') then E.open(want) else E.new(want) end
    elseif E.ids[1] then E.open(E.ids[1]) end
end

-- ¿Algún nivel coloca este enemigo? → lista de niveles
local function usedIn(id)
    local out = {}
    for _, p in ipairs(Shell.listFiles('assets/levels', '.json')) do
        local text = love.filesystem.read(p) or ''
        if text:find('"type"%s*:%s*"' .. id:gsub('%p', '%%%0') .. '"') then out[#out + 1] = p:match('([^/]+)%.json$') end
    end
    return out
end

function E.delete()
    local id = E.id
    local levels = usedIn(id)
    if #levels > 0 then return Shell.message('No se puede borrar: lo usan los niveles ' .. table.concat(levels, ', '), 'error') end
    local ids = {}
    for _, i in ipairs(DataEnemy.ids()) do if i ~= id then ids[#ids + 1] = i end end
    Shell.writeRepo(DataEnemy.INDEX, Shell.encodeJson({ enemies = ids }))
    Shell.removeRepo(DataEnemy.DIR .. id .. '.json')
    if E.animDoc and E.animDoc.id == id then Shell.removeRepo(Anim.path(id)); Anim.reload(id) end
    EntityTypes.unregister(id)
    E.id, E.spec, E.animDoc, E.unsaved, E.confirm = nil, nil, nil, false, nil
    refresh()
    Shell.message('Borrado el enemigo "' .. id .. '" (sus dibujos en assets/images no se tocan)')
end

-- Los pasos, y qué se hace en cada uno
local STEPS = {
    { id = 'anim',    label = '1 · Dibujos',   help = 'Sus CUADROS (los dibujos) y sus ANIMACIONES: quieto, andar… Empieza aquí.' },
    { id = 'general', label = '2 · Cómo es',   help = 'Enemigo o jefe, tamaño, caja de golpe, vida y cómo se mueve.' },
    { id = 'beh',     label = '3 · Qué hace',  help = 'Lo que hace además de moverse: perseguir, atacar, saltar, disparar, esconderse.' },
    { id = 'states',  label = '4 · Estados',   help = 'Qué animación se ve en cada momento (normalmente no hay que tocar nada).' },
    { id = 'warn',    label = 'Avisos',        help = 'Lo que le falta para estar completo.' },
}

local function draw()
    local W, H = love.graphics.getDimensions()
    ui.rect(0, 0, W, 46, th.panel, 0)
    ui.text('Enemigos', 14, 12, th.text, ui.fontLg)
    local LW = 210
    local blocked = E.confirm ~= nil
    local sp = ui.state.pressed
    if blocked then ui.block() end
    -- la lista
    ui.rect(8, 54, LW, H - 54 - 34, th.panel, 6)
    local ly = ui.caption(('Tus enemigos (%d)'):format(#E.ids), 18, 64, LW - 20)
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
    ly = ui.caption('Crear uno', 18, ly, LW - 20)
    E.newId = ui.textField('enemynew', E.newId, 18, ly, LW - 20, 24, 'nombre (p. ej. claudio)'); ly = ly + 32
    if ui.button('+ Nuevo enemigo', 18, ly, LW - 20, 28, { disabled = E.newId == '', color = th.accentDk }) then E.new(E.newId); E.newId = '' end
    ly = ly + 38
    ui.hint('El nombre va en minúsculas y sin espacios. Si ya hay dibujos en assets/images/enemies/<nombre>/, se cogen solos como cuadros.', 18, ly, LW - 20)

    if not E.spec then
        ui.hint('Escribe un nombre a la izquierda y pulsa "+ Nuevo enemigo", o elige uno de la lista.', LW + 28, 70, 560, th.accent)
        if blocked then ui.unblock() end
        return
    end
    local warns = DataEnemy.validate(E.spec, E.panel:set(E.animDoc))
    local x, w = LW + 16, W - LW - 24
    -- arriba a la derecha: deshacer, guardar, probar, borrar
    local bx = W - 12
    bx = bx - 78;  if ui.button('Borrar', bx, 9, 78, 28, { textColor = th.danger, tooltip = 'Quita este enemigo del juego' }) then E.confirm = 'delete' end
    bx = bx - 118; if ui.button('Probar', bx, 9, 110, 28, { hint = 'F5', color = th.accentDk, tooltip = 'Guarda y lo suelta en una sala de prueba dentro del juego (F10 vuelve)' }) then E.play() end
    bx = bx - 140; if ui.button('Guardar', bx, 9, 132, 28, { hint = 'Ctrl+S', color = E.unsaved and th.accentDk or nil }) then E.save() end
    bx = bx - 128; if ui.button('Deshacer', bx, 9, 120, 28, { hint = 'Ctrl+Z', disabled = #E.hist.stack == 0 }) then E.hist:undo() end
    if E.unsaved then ui.text('*', bx - 14, 14, th.warn, ui.fontLg) end
    local tabs = {}
    for _, st in ipairs(STEPS) do
        local t = { id = st.id, label = st.label }
        if st.id == 'beh' and #E.spec.behaviors > 0 then t.badge = #E.spec.behaviors end
        if st.id == 'warn' and #warns > 0 then t.badge, t.badgeColor = #warns, th.warn end
        tabs[#tabs + 1] = t
    end
    E.tab = ui.tabs(tabs, E.tab, x, 8, math.min(640, bx - x - 30), 34)
    local help = ''
    for _, st in ipairs(STEPS) do if st.id == E.tab then help = st.help end end
    ui.text((E.spec.boss and 'JEFE  ' or '') .. '«' .. (E.spec.label or E.id) .. '»  —  ' .. help, x + 4, 52, th.muted, ui.fontSm)
    local y, h = 72, H - 72 - 34
    if E.tab == 'general' then tabGeneral(x, y, w, h)
    elseif E.tab == 'anim' then
        E.panel.wanted = {}
        for _, st in ipairs(DataEnemy.statesOf(E.spec)) do E.panel.wanted[#E.panel.wanted + 1] = (E.spec.states or {})[st] or st end
        for _, b in ipairs(E.spec.behaviors) do
            for _, a2 in ipairs(Behaviors.byName[b.type] and Behaviors.byName[b.type].anims or {}) do E.panel.wanted[#E.panel.wanted + 1] = a2 end
        end
        if E.panel:draw(E.animDoc, x, y, w, h) then touch() end
    elseif E.tab == 'states' then tabStates(x, y, w, h)
    elseif E.tab == 'beh' then tabBehaviors(x, y, w, h)
    else tabWarnings(x, y, w, h, warns) end
    if blocked then ui.unblock() end
    -- confirmar el borrado
    if E.confirm == 'delete' then
        love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle('fill', 0, 0, W, H)
        local mw, mh = 520, 190
        local mx, my = math.floor((W - mw) / 2), math.floor((H - mh) / 2)
        ui.rect(mx, my, mw, mh, th.panel, 8); ui.rect(mx, my, mw, mh, th.border, 8, 'line')
        ui.text('¿Borrar el enemigo "' .. E.id .. '"?', mx + 18, my + 16, th.text, ui.fontLg)
        ui.text('Se quita de la lista y se borran sus datos y su conjunto de animación. Sus dibujos (assets/images) se quedan. No se puede deshacer.', mx + 18, my + 52, th.muted, ui.font, mw - 36)
        if ui.button('Borrar', mx + mw - 230, my + mh - 46, 100, 30, { textColor = th.danger }) then E.delete() end
        if ui.button('Cancelar', mx + mw - 120, my + mh - 46, 100, 30) then E.confirm = nil end
    end
end

local function keypressed(k)
    if ui.hasFocus() then return end
    local ctrl = love.keyboard.isDown('lctrl', 'rctrl', 'lgui', 'rgui')
    local shift = love.keyboard.isDown('lshift', 'rshift')
    if k == 'escape' then E.confirm = nil end
    if not E.spec or E.confirm then return end
    if ctrl and k == 's' then return E.save() end
    if ctrl and k == 'z' then if shift then E.hist:redo() else E.hist:undo() end; return end
    if ctrl and k == 'y' then E.hist:redo(); return end
    if k == 'f5' then return E.play() end
    if E.tab == 'anim' then E.panel:keypressed(k) end
end

function E.install()
    Shell.install({ title = 'Editor de enemigos', load = load, draw = draw, keypressed = keypressed,
                    unsaved = function() return E.unsaved end,
                    status = function() return 'Ctrl+S: guardar  ·  Ctrl+Z / Ctrl+Y: deshacer / rehacer  ·  F5: probar en el juego (F10 vuelve)  ·  un enemigo guardado sale en el editor de niveles' end })
end

return E
