-- src/editor/ToolShell.lua
-- Lo que comparten las herramientas de edición que no son el editor de niveles (editor de animaciones, editor de
-- enemigos): tomar los callbacks de LÖVE, la entrada del toolkit (src/editor/ui.lua), guardar archivos del repo,
-- listar archivos, escribir JSON legible y PROBAR un nivel en el juego (F10 vuelve a la herramienta).
--
--   local Shell = require 'src/editor/ToolShell'
--   Shell.install({ title = '…', load = fn(args), update = fn(dt), draw = fn(), keypressed = fn(k), unsaved = fn() })
--   Shell.play(levelData)            -- juega esos datos de nivel (tabla) con AdventureState
local ui   = require 'src/editor/ui'
local json = require 'libs/json'

local Shell = { mode = 'edit', msg = '', msgT = 0, msgKind = 'info' }
local G = {}
local app

function Shell.message(text, kind) Shell.msg, Shell.msgT, Shell.msgKind = text, 4, kind or 'info' end

-- ── Archivos ──────────────────────────────────────────────────────────────────
-- Escribe un archivo DEL REPO (solo ejecutando el juego desde su carpeta)
function Shell.writeRepo(relPath, text)
    local src = love.filesystem.getSource()
    if not src or src:match('%.love$') or not love.filesystem.getInfo('main.lua') then
        return false, 'Solo se puede guardar ejecutando el juego desde su carpeta'
    end
    local f, err = io.open(src .. '/' .. relPath, 'wb')
    if not f then return false, tostring(err) end
    f:write(text); f:close()
    return true
end

-- Archivos con esa extensión bajo `dir` (recursivo), ordenados
function Shell.listFiles(dir, ext, out)
    out = out or {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = dir .. '/' .. f
        local info = love.filesystem.getInfo(p)
        if info and info.type == 'directory' then Shell.listFiles(p, ext, out)
        elseif f:sub(-#ext) == ext then out[#out + 1] = p end
    end
    table.sort(out)
    return out
end

-- JSON legible y estable (para que los diffs de git se lean): una clave por línea arriba; las listas de objetos,
-- un elemento por línea; lo de más adentro, en una línea. `order` = claves que van primero, en ese orden.
local function inline(v)
    local t = type(v)
    if t ~= 'table' then return json.encode(v) end
    if #v > 0 or next(v) == nil then
        if next(v) == nil then return '[]' end
        local parts = {}
        for i = 1, #v do parts[i] = inline(v[i]) end
        return '[' .. table.concat(parts, ', ') .. ']'
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        -- (OJO con `false`: «v[k] or …» lo perdía y "loop": false se guardaba como null → la animación volvía a repetirse)
        local val = v[k]
        if val == nil then val = v[tonumber(k)] end
        parts[#parts + 1] = json.encode(k) .. ': ' .. inline(val)
    end
    return '{' .. table.concat(parts, ', ') .. '}'
end
function Shell.encodeJson(data, order)
    local keys, seen = {}, {}
    for _, k in ipairs(order or {}) do if data[k] ~= nil then keys[#keys + 1] = k; seen[k] = true end end
    local rest = {}
    for k in pairs(data) do if not seen[k] and type(k) == 'string' and k:sub(1, 1) ~= '_' then rest[#rest + 1] = k end end
    table.sort(rest)
    for _, k in ipairs(rest) do keys[#keys + 1] = k end
    local out = { '{' }
    for i, k in ipairs(keys) do
        local v, comma = data[k], (i < #keys) and ',' or ''
        if type(v) == 'table' and #v > 0 and type(v[1]) == 'table' then
            out[#out + 1] = '  ' .. json.encode(k) .. ': ['
            for j = 1, #v do out[#out + 1] = '    ' .. inline(v[j]) .. (j < #v and ',' or '') end
            out[#out + 1] = '  ]' .. comma
        elseif type(v) == 'table' and #v == 0 and next(v) ~= nil then
            local sub = {}
            for sk in pairs(v) do sub[#sub + 1] = tostring(sk) end
            table.sort(sub)
            out[#out + 1] = '  ' .. json.encode(k) .. ': {'
            for j, sk in ipairs(sub) do out[#out + 1] = '    ' .. json.encode(sk) .. ': ' .. inline(v[sk]) .. (j < #sub and ',' or '') end
            out[#out + 1] = '  }' .. comma
        else
            out[#out + 1] = '  ' .. json.encode(k) .. ': ' .. inline(v) .. comma
        end
    end
    out[#out + 1] = '}'
    return table.concat(out, '\n') .. '\n'
end

-- ── Deshacer / rehacer ───────────────────────────────────────────────────────
-- local hist = Shell.history(function() return datos end, function(d) datos = d end)
-- hist:record() tras cada cambio (los cambios seguidos en menos de medio segundo cuentan como uno);
-- hist:undo() / hist:redo() → true si hizo algo; hist:reset() al abrir otra cosa.
function Shell.history(get, set)
    local H = { stack = {}, future = {}, cur = json.encode(get()), last = 0 }
    function H:reset() self.stack, self.future, self.cur, self.last = {}, {}, json.encode(get()), 0 end
    function H:record()
        local s = json.encode(get())
        if s == self.cur then return end
        local now = love.timer.getTime()
        if now - self.last > 0.5 or #self.stack == 0 then
            self.stack[#self.stack + 1] = self.cur
            if #self.stack > 200 then table.remove(self.stack, 1) end
        end
        self.cur, self.last, self.future = s, now, {}
    end
    function H:undo()
        if #self.stack == 0 then return false end
        self.future[#self.future + 1] = self.cur
        self.cur = table.remove(self.stack)
        self.last = 0
        set(json.decode(self.cur))
        return true
    end
    function H:redo()
        if #self.future == 0 then return false end
        self.stack[#self.stack + 1] = self.cur
        self.cur = table.remove(self.future)
        self.last = 0
        set(json.decode(self.cur))
        return true
    end
    return H
end

-- Borra un archivo DEL REPO
function Shell.removeRepo(relPath)
    local src = love.filesystem.getSource()
    if not src or src:match('%.love$') then return false end
    return os.remove(src .. '/' .. relPath) ~= nil
end

-- ── Probar en el juego ────────────────────────────────────────────────────────
local PLAYTEST = 'editor_playtest.json'
function Shell.play(levelData)
    love.filesystem.write(PLAYTEST, json.encode(levelData))
    if not Shell.gameReady then G.load(Shell.gameArgs or {}); Shell.gameReady = true end
    if G.resize then G.resize(love.graphics.getDimensions()) end
    gStateMachine:change('adventure', { level = PLAYTEST })
    Shell.mode = 'play'
end
function Shell.stopPlay()
    if Sound and Sound.stopMusic then Sound.stopTracked('drowning'); Sound.stopMusic() end
    Shell.mode = 'edit'
    Shell.message('De vuelta en el editor')
end

-- ── Instalación ───────────────────────────────────────────────────────────────
function Shell.install(a)
    app = a
    for _, name in ipairs({ 'load', 'update', 'draw', 'keypressed', 'keyreleased', 'textinput', 'mousepressed', 'mousereleased',
                            'mousemoved', 'wheelmoved', 'resize', 'focus', 'joystickadded', 'joystickpressed', 'touchpressed', 'quit' }) do
        G[name] = love[name]
    end
    local function route(name, fn)
        love[name] = function(...)
            if Shell.mode == 'play' then
                if G[name] then return G[name](...) end
            elseif fn then return fn(...) end
        end
    end
    love.load = function(args)
        ui.load()
        love.graphics.setDefaultFilter('nearest', 'nearest')
        love.keyboard.setKeyRepeat(true)
        love.window.setTitle('FlappyMonster — ' .. (app.title or 'Editor'))
        if not os.getenv('FM_TOOL_NOWINDOW') then
            local dw, dh = love.window.getDesktopDimensions()
            love.window.setMode(math.min(1600, dw - 80), math.min(920, dh - 80), { resizable = true, vsync = 1, minwidth = 1100, minheight = 640 })
        end
        Shell.gameArgs = args
        if app.load then app.load(args) end
    end
    route('update', function(dt)
        if Shell.msgT > 0 then Shell.msgT = Shell.msgT - dt end
        if app.update then app.update(dt) end
    end)
    route('draw', function()
        ui.beginFrame()
        love.graphics.clear(ui.theme.bg)
        app.draw()
        -- barra de estado
        local W, H = love.graphics.getDimensions()
        ui.rect(0, H - 26, W, 26, ui.theme.panel, 0)
        if Shell.msgT > 0 then
            local c = Shell.msgKind == 'error' and ui.theme.danger or (Shell.msgKind == 'warn' and ui.theme.warn or ui.theme.ok)
            ui.text(Shell.msg, 12, H - 20, c)
        elseif app.status then ui.text(app.status(), 12, H - 20, ui.theme.muted) end
        ui.drawTooltip()
        ui.endFrame()
    end)
    route('textinput', function(t) ui.textinput(t) end)
    route('mousepressed', function(x, y, b) ui.mousepressed(b); if app.mousepressed then app.mousepressed(x, y, b) end end)
    route('mousereleased', function(x, y, b) ui.mousereleased(b) end)
    route('wheelmoved', function(dx, dy) ui.wheelmoved(dy) end)
    for _, n in ipairs({ 'mousemoved', 'resize', 'focus', 'joystickadded', 'joystickpressed', 'touchpressed' }) do route(n, nil) end
    love.keypressed = function(k, ...)
        if Shell.mode == 'play' then
            if k == 'f10' then return Shell.stopPlay() end
            return G.keypressed and G.keypressed(k, ...)
        end
        ui.keypressed(k)
        if app.keypressed then app.keypressed(k) end
    end
    local toolDraw = love.draw
    love.draw = function()
        toolDraw()
        if Shell.mode == 'play' then
            love.graphics.origin()
            love.graphics.setFont(ui.font)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle('fill', 8, 8, 250, 26, 4, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print('PROBANDO — F10: volver al editor', 16, 14)
        end
    end
    love.quit = function()
        if Shell.mode == 'edit' and app.unsaved and app.unsaved() and not Shell.quitConfirmed then
            Shell.quitConfirmed = true
            Shell.message('Hay cambios sin guardar. Cierra otra vez para salir sin guardar.', 'warn')
            return true
        end
    end
end

return Shell
