-- server/updates.lua
-- Actualizaciones automáticas del cliente: el servidor PUBLICA una versión del
-- juego y la sirve por la misma conexión ENet del juego (LÖVE 11 no tiene
-- HTTPS, así que no se puede descargar de GitHub directamente).
--
-- Publicar = "foto" de los archivos del juego (git ls-files, solo lo que
-- distribuye DIST) en server/published/current/ + manifest.lua con la versión
-- y el SHA-256 y tamaño de cada archivo. Solo se hace cuando cambia
-- version.txt (subir cosas a master sin cambiarlo no llega a los jugadores).
-- Se comprueba al arrancar y cada CHECK_EVERY s; el trabajo pesado (leer y
-- hashear ~40 MB) va en un hilo para no congelar las partidas.
--
-- Mensajes (contrato CONGELADO: los clientes ya instalados lo usarán siempre):
--   cliente → 'upd_manifest' {}            servidor → 'upd_manifest' {version, files={{path,size,hash}...}}
--   cliente → 'upd_get' {path, offset}     servidor → 'upd_chunk' {path, offset, data}   (≤ CHUNK bytes)
-- (version = nil si aún no hay nada publicado; data = nil si la petición no vale)

local Updates = {}

local CHUNK       = 48 * 1024
local CHECK_EVERY = 30

-- Qué se distribuye: el juego (NO main.lua ni conf.lua, que son el arranque,
-- ni el servidor, las herramientas o los recursos de compilación)
local DIST_FILES = { ['game.lua'] = true, ['input.lua'] = true, ['settings.lua'] = true, ['version.txt'] = true }
local DIST_DIRS  = { 'src/', 'libs/', 'assets/' }

local root, outDir, logf
local manifest, byPath = nil, {}
local thread, channel, checkT = nil, nil, 0
local cache = {}                -- path -> contenido (los últimos pedidos)
local cacheOrder = {}

local THREAD_CODE = [[
require 'love.data'
local root, outDir, CHUNKS, ch = ...
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function readFile(p) local f = io.open(p, 'rb'); if not f then return nil end; local d = f:read('*a'); f:close(); return d end
local function writeFile(p, d) local f = io.open(p, 'wb'); if not f then return false end; f:write(d); f:close(); return true end
local ok, err = pcall(function()
    local version = (readFile(root .. '/version.txt') or ''):match('^%s*(.-)%s*$')
    if version == '' then error('version.txt vacío o no encontrado') end
    local cur = readFile(outDir .. '/current/manifest.lua')
    if cur and cur:match('version = "([^"]*)"') == version then ch:push({ ok = true, text = cur, reused = true }); return end
    -- Lista de archivos del repo (solo los versionados) que se distribuyen
    local files = {}
    local p = io.popen('git -C ' .. sh(root) .. ' ls-files')
    for line in p:lines() do
        local keep = CHUNKS.files[line]
        for _, d in ipairs(CHUNKS.dirs) do if line:sub(1, #d) == d then keep = true end end
        if keep then files[#files + 1] = line end
    end
    p:close()
    if #files == 0 then error('git ls-files no devolvió archivos (¿está git instalado?)') end
    table.sort(files)
    local next = outDir .. '/next'
    os.execute('rm -rf ' .. sh(next) .. ' && mkdir -p ' .. sh(next))
    local dirs, lines, total = {}, {}, 0
    for _, f in ipairs(files) do
        local d = f:match('^(.*)/[^/]*$')
        if d and not dirs[d] then dirs[d] = true; os.execute('mkdir -p ' .. sh(next .. '/' .. d)) end
        local data = readFile(root .. '/' .. f)
        if data then
            if not writeFile(next .. '/' .. f, data) then error('no se pudo escribir ' .. f) end
            local h = love.data.encode('string', 'hex', love.data.hash('sha256', data))
            lines[#lines + 1] = string.format('  { %q, %d, %q },', f, #data, h)
            total = total + #data
        end
    end
    local text = string.format('return {\n version = %q,\n total = %d,\n files = {\n%s\n }\n}\n', version, total, table.concat(lines, '\n'))
    writeFile(next .. '/manifest.lua', text)
    os.execute('rm -rf ' .. sh(outDir .. '/current') .. ' && mv ' .. sh(next) .. ' ' .. sh(outDir .. '/current'))
    ch:push({ ok = true, text = text })
end)
if not ok then ch:push({ ok = false, err = tostring(err) }) end
]]

local function loadManifest(text)
    local chunk = loadstring(text)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, m = pcall(chunk)
    if not ok or type(m) ~= 'table' then return nil end
    local map, list = {}, {}
    for _, f in ipairs(m.files or {}) do
        local e = { path = f[1], size = f[2], hash = f[3] }
        map[e.path] = e
        list[#list + 1] = e
    end
    return { version = m.version, total = m.total or 0, files = list }, map
end

local function startPublish()
    if thread then return end
    channel = love.thread.newChannel()
    thread = love.thread.newThread(THREAD_CODE)
    thread:start(root, outDir, { files = DIST_FILES, dirs = DIST_DIRS }, channel)
end

function Updates.init(parentDir, log)
    root, outDir, logf = parentDir, parentDir .. '/server/published', log
    startPublish()
end

-- Llamar cada frame del servidor
function Updates.update(dt)
    if thread then
        local r = channel:pop()
        local terr = thread:getError()
        if r or terr then
            thread = nil
            if r and r.ok then
                local m, map = loadManifest(r.text)
                if m then
                    local changed = not manifest or manifest.version ~= m.version
                    manifest, byPath, cache, cacheOrder = m, map, {}, {}
                    if changed then
                        logf(string.format('Actualizaciones: versión %s %s (%d archivos, %.1f MB)', m.version,
                             r.reused and 'ya publicada' or 'PUBLICADA', #m.files, m.total / 1048576))
                    end
                end
            else
                logf('Actualizaciones: no se pudo publicar: ' .. tostring(r and r.err or terr))
            end
        end
    end
    checkT = checkT + dt
    if checkT >= CHECK_EVERY then
        checkT = 0
        local f = io.open(root .. '/version.txt', 'rb')
        local v = f and f:read('*a'):match('^%s*(.-)%s*$'); if f then f:close() end
        if v and v ~= '' and (not manifest or v ~= manifest.version) then startPublish() end
    end
end

local function fileData(path)
    local d = cache[path]
    if d then return d end
    local f = io.open(outDir .. '/current/' .. path, 'rb')
    if not f then return nil end
    d = f:read('*a'); f:close()
    cache[path] = d
    cacheOrder[#cacheOrder + 1] = path
    if #cacheOrder > 6 then cache[table.remove(cacheOrder, 1)] = nil end
    return d
end

-- Registra los mensajes (on = el `on` del servidor, con límite de mensajes)
function Updates.register(on)
    on('upd_manifest', function(_, client)
        if not manifest then client:send('upd_manifest', {}); return end
        local files = {}
        for i, e in ipairs(manifest.files) do files[i] = { e.path, e.size, e.hash } end
        client:send('upd_manifest', { version = manifest.version, files = files })
    end, true)
    on('upd_get', function(data, client)
        if type(data) ~= 'table' then return end
        local path, offset = data.path, tonumber(data.offset) or -1
        local e = type(path) == 'string' and byPath[path]
        local d = e and offset >= 0 and offset < math.max(1, e.size) and fileData(path)
        if not d then client:send('upd_chunk', { path = path, offset = offset }); return end
        client:send('upd_chunk', { path = path, offset = offset, data = d:sub(offset + 1, offset + CHUNK) })
    end, true)
end

Updates.CHUNK = CHUNK
return Updates
