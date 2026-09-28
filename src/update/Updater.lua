-- src/update/Updater.lua
-- Actualización automática del cliente (la usa UpdateState al arrancar).
--
-- 1. Conecta al servidor del juego (misma conexión ENet que el online) y pide
--    el manifiesto de la versión publicada: {version, {path, size, sha256}...}
--    (lo publica server/updates.lua cuando cambia version.txt en master).
-- 2. Si la versión es otra (más nueva o más vieja: manda el servidor),
--    compara hashes con lo que tiene y descarga SOLO lo que cambia, por trozos
--    y con varias peticiones en vuelo, comprobando el SHA-256 de cada archivo.
-- 3. Lo escribe en update/slots/<versión>/ (carpeta de guardado): lo que
--    cambia respecto al juego instalado, más lo de la versión anterior que
--    sigue igual (se copia). Nada toca la versión en uso hasta el final.
-- 4. Apunta la nueva como activa (update/state.lua, ver main.lua) y el juego
--    se reinicia: main.lua la monta encima del juego instalado.
-- Si algo falla (sin red, servidor antiguo, archivo corrupto) se sigue con la
-- versión actual. Solo funciona con el juego empaquetado (ver main.lua).
--
--   local u = Updater.new(host, port)
--   u:update(dt) -> 'connecting' | 'checking' | 'hashing' | 'downloading'
--                   | 'installing' | 'done' | 'uptodate' | 'failed'
--   u.version (la nueva), u.bytesDone/u.bytesTotal, u.filesDone/u.filesTotal, u.err

local sock     = require 'libs/sock'
local bitser   = require 'libs/bitser'
local Protocol = require 'src/network/Protocol'
local Resolver = require 'src/network/Resolver'

local Updater = {}
Updater.__index = Updater

local SLOTS       = 'update/slots/'
local CONNECT_MAX = 6        -- s para conectar y recibir el manifiesto
local IN_FLIGHT   = 4        -- peticiones de trozos a la vez
local REQ_TIMEOUT = 4        -- s sin respuesta → volver a pedir
local REQ_PER_SEC = 90       -- (el servidor limita a 120 mensajes/s)
local HASH_BUDGET = 0.012    -- s por frame hasheando archivos locales

local fs = love.filesystem

local function sha256(data)
    return love.data.encode('string', 'hex', love.data.hash('sha256', data))
end

local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end

function Updater.localVersion()
    local ok, v = pcall(fs.read, 'version.txt')
    return ok and trim(v) or '?'
end

local function state() return UPDATE_READ_STATE and UPDATE_READ_STATE() or {} end

-- Hashes de lo que hay ahora, si la versión activa guardó su manifiesto
local function knownHashes(active)
    if not active then return nil end
    local ok, src = pcall(fs.read, SLOTS .. active .. '/.manifest.lua')
    local chunk = ok and src and loadstring(src)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok2, t = pcall(chunk)
    return ok2 and type(t) == 'table' and t or nil
end

local function writeFile(path, data)
    local dir = path:match('^(.*)/[^/]*$')
    if dir then fs.createDirectory(dir) end
    return fs.write(path, data)
end

function Updater.new(host, port)
    local self = setmetatable({
        host = host, port = port, status = 'connecting', t = 0,
        bytesDone = 0, bytesTotal = 0, filesDone = 0, filesTotal = 0,
    }, Updater)
    self.job = Resolver.start(host)
    if not self.job then self:_open(host) end
    return self
end

function Updater:_open(ip)
    local ok, err = pcall(function()
        self.client = sock.newClient(ip, self.port, Protocol.CHANNELS)
        self.client:setSerialization(bitser.dumps, bitser.loads)
        self.client:on('connect', function() self.client:send('upd_manifest', {}) end)
        self.client:on('upd_manifest', function(m) self:_onManifest(m) end)
        self.client:on('upd_chunk', function(c) self:_onChunk(c) end)
        self.client:on('disconnect', function()
            if self.status ~= 'done' and self.status ~= 'uptodate' then self:_fail('desconectado') end
        end)
        self.client:connect()
    end)
    if not ok then self:_fail(tostring(err)) end
end

function Updater:_fail(err)
    if self.status == 'failed' then return end
    self.status, self.err = 'failed', err
    print('[update] ' .. tostring(err))
    self:_close()
end

function Updater:_close()
    local c = self.client
    self.client = nil
    if c then pcall(function() c:disconnectNow() end) end
end

function Updater:cancel() self:_fail('cancelado') end

-- ── Manifiesto: qué hay que bajar ────────────────────────────────────────────
function Updater:_onManifest(m)
    if self.status ~= 'connecting' then return end
    if type(m) ~= 'table' or type(m.version) ~= 'string' or type(m.files) ~= 'table' then
        return self:_fail('el servidor no tiene ninguna versión publicada')
    end
    local st = state()
    self.version = m.version
    self.current = Updater.localVersion()
    if m.version == self.current or m.version == st.bad then
        self.status = 'uptodate'
        self:_close()
        return
    end
    self.files = {}
    for _, f in ipairs(m.files) do
        if type(f) == 'table' and type(f[1]) == 'string' and not f[1]:find('%.%.') then
            self.files[#self.files + 1] = { path = f[1], size = tonumber(f[2]) or 0, hash = f[3] }
        end
    end
    self.active = st.active
    self.known = knownHashes(st.active) or {}
    self.hashQueue = {}
    for _, f in ipairs(self.files) do self.hashQueue[#self.hashQueue + 1] = f end
    self.status = 'hashing'
end

-- Compara (poco a poco, sin congelar la pantalla) con lo que hay ahora
function Updater:_hashStep()
    local t0 = love.timer.getTime()
    local activeDir = self.active and (SLOTS .. self.active)
    while #self.hashQueue > 0 and love.timer.getTime() - t0 < HASH_BUDGET do
        local f = table.remove(self.hashQueue)
        local have = self.known[f.path]
        if not have and fs.getInfo(f.path, 'file') then
            local ok, data = pcall(fs.read, f.path)
            have = ok and data and sha256(data)
        end
        if have == f.hash then
            -- Igual que lo que hay: si viene de la versión activa, se copia
            local real = fs.getRealDirectory(f.path) or ''
            if activeDir and real:sub(-#activeDir) == activeDir then f.copy = true end
        else
            f.download = true
        end
    end
    if #self.hashQueue == 0 then
        self.slot = SLOTS .. self.version .. '/'
        if UPDATE_RMRF then UPDATE_RMRF(SLOTS .. self.version) end      -- (restos de un intento anterior)
        fs.createDirectory(self.slot)
        self.queue = {}
        for _, f in ipairs(self.files) do
            if f.download then
                self.queue[#self.queue + 1] = f
                self.bytesTotal = self.bytesTotal + f.size
                self.filesTotal = self.filesTotal + 1
            end
        end
        self.pending, self.reqT = {}, 0
        self.status = 'downloading'
    end
end

-- ── Descarga ─────────────────────────────────────────────────────────────────
local function key(path, offset) return path .. '@' .. offset end

function Updater:_request(f, offset)
    self.pending[key(f.path, offset)] = { f = f, offset = offset, t = love.timer.getTime() }
    self.client:send('upd_get', { path = f.path, offset = offset })
    self.reqT = self.reqT + 1 / REQ_PER_SEC
end

-- Siguiente trozo que pedir: el archivo en curso y, si ya está todo pedido, el siguiente
function Updater:_nextRequest()
    local f = self.cur
    if not f or f.nextOffset >= math.max(1, f.size) then
        f = table.remove(self.queue, 1)
        if not f then return false end
        f.nextOffset, f.parts, f.got = 0, {}, 0
        self.cur = f
    end
    local off = f.nextOffset
    f.nextOffset = off + Updater.CHUNK
    self:_request(f, off)
    return true
end

function Updater:_onChunk(c)
    if self.status ~= 'downloading' or type(c) ~= 'table' then return end
    local p = self.pending[key(tostring(c.path), tonumber(c.offset) or -1)]
    if not p then return end
    self.pending[key(p.f.path, p.offset)] = nil
    if type(c.data) ~= 'string' then return self:_fail('el servidor rechazó ' .. p.f.path) end
    local f = p.f
    f.parts[p.offset] = c.data
    f.got = f.got + #c.data
    self.bytesDone = self.bytesDone + #c.data
    if f.got >= f.size then
        -- Completo: unir por orden y comprobar
        local offs = {}
        for o in pairs(f.parts) do offs[#offs + 1] = o end
        table.sort(offs)
        local out = {}
        for i, o in ipairs(offs) do out[i] = f.parts[o] end
        local data = table.concat(out)
        f.parts = nil
        if #data ~= f.size or sha256(data) ~= f.hash then
            return self:_fail('archivo dañado: ' .. f.path)
        end
        if not writeFile(self.slot .. f.path, data) then return self:_fail('no se pudo escribir ' .. f.path) end
        self.filesDone = self.filesDone + 1
    end
end

function Updater:_downloadStep(dt)
    local now = love.timer.getTime()
    -- Peticiones sin respuesta: volver a pedir
    for k, p in pairs(self.pending) do
        if now - p.t > REQ_TIMEOUT then
            p.retries = (p.retries or 0) + 1
            if p.retries > 4 then return self:_fail('el servidor no responde') end
            p.t = now
            self.client:send('upd_get', { path = p.f.path, offset = p.offset })
        end
    end
    self.reqT = math.max(0, self.reqT - dt)
    local inFlight = 0
    for _ in pairs(self.pending) do inFlight = inFlight + 1 end
    while inFlight < IN_FLIGHT and self.reqT < 0.05 do
        if not self:_nextRequest() then break end
        inFlight = inFlight + 1
    end
    if inFlight == 0 and #self.queue == 0 and (not self.cur or self.cur.nextOffset >= math.max(1, self.cur.size)) then
        self.status = 'installing'
    end
end

-- ── Instalar: copiar lo que sigue igual y activar ────────────────────────────
function Updater:_install()
    self:_close()
    local manifest = { 'return {' }
    for _, f in ipairs(self.files) do
        manifest[#manifest + 1] = string.format('  [%q] = %q,', f.path, f.hash)
        if f.copy then
            local ok, data = pcall(fs.read, f.path)
            if not (ok and data and writeFile(self.slot .. f.path, data)) then
                return self:_fail('no se pudo copiar ' .. f.path)
            end
        end
    end
    manifest[#manifest + 1] = '}\n'
    writeFile(self.slot .. '.manifest.lua', table.concat(manifest, '\n'))
    local st = state()
    st.previous = st.active                 -- (nil = el juego instalado)
    st.active, st.pending, st.boots = self.version, true, 0
    if UPDATE_WRITE_STATE then UPDATE_WRITE_STATE(st) end
    self.status = 'done'
end

function Updater:update(dt)
    self.t = self.t + dt
    if self.job then
        local ip = self.job:poll()
        if ip ~= nil then
            self.job = nil
            if not ip then return self:_fail('no se encontró el servidor') end
            self:_open(ip)
        end
    end
    if self.client then pcall(function() self.client:update() end) end
    local s = self.status
    if s == 'connecting' and self.t > CONNECT_MAX then self:_fail('sin respuesta del servidor')
    elseif s == 'hashing' then self:_hashStep()
    elseif s == 'downloading' then self:_downloadStep(dt)
    elseif s == 'installing' then self:_install() end
    return self.status
end

Updater.CHUNK = 48 * 1024        -- (igual que server/updates.lua)
return Updater
