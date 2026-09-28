-- src/network/NetworkClient.lua
-- Singleton que gestiona la conexión con el servidor de FlappyMonster Online.
-- Los estados registran callbacks via NC:on(event, fn).
-- Cuando el estado cambia, simplemente sobreescribe los callbacks que necesita.

local sock     = require 'libs/sock'
local bitser   = require 'libs/bitser'
local Protocol = require 'src/network/Protocol'
local Resolver = require 'src/network/Resolver'
local Lang = require 'src/Lang'

-- Nunca reconstruir metatablas desde datos de red.
bitser.includeMetatables(false)

local CONNECT_TIMEOUT = 5   -- segundos hasta considerar que el servidor no responde

local NC = {
    client         = nil,
    connected      = false,
    myId           = nil,
    myName         = nil,
    _handlers      = {},
    _connectTimer  = nil,   -- nil = no hay intento en curso; número = segundos transcurridos
    _resolving     = nil,   -- { job, port, name } mientras se resuelve el nombre del servidor
    pendingGameInit = nil,  -- último game_init recibido (por si llega antes del estado)
}

-- ── API pública ───────────────────────────────────────────────────────────────

function NC:on(event, fn)
    self._handlers[event] = fn
end

function NC:off(event)
    self._handlers[event] = nil
end

function NC:send(event, data)
    if self.client then
        self.client:send(event, data or {})
    end
end

-- Envío no fiable por el canal de estado (inputs): si se pierde, el siguiente
-- paquete ya lo repite, y no bloquea a los mensajes que vienen detrás.
function NC:sendState(event, data)
    if self.client then
        self.client:setSendChannel(Protocol.CH_STATE)
        self.client:setSendMode("unreliable")
        self.client:send(event, data or {})
    end
end

-- RTT en milisegundos (0 si no hay conexión).
function NC:getPing()
    if not self.client then return 0 end
    local ok, rtt = pcall(function() return self.client:getRoundTripTime() end)
    return (ok and type(rtt) == "number") and rtt or 0
end

-- Cierra de verdad un cliente (y su socket ENet). Sin esto, cada intento
-- fallido dejaba un socket abierto; en consola se acaban.
-- (El socket se destruye en el siguiente NC:update: puede que estemos dentro
-- del propio bucle de red de ese cliente, p. ej. al recibir login_error.)
local graveyard = {}
local function dropClient(c)
    if not c then return end
    pcall(function() if c.connection then c:disconnectNow() end end)
    graveyard[#graveyard + 1] = c
end
local function buryClients()
    for i = #graveyard, 1, -1 do
        local c = graveyard[i]
        graveyard[i] = nil
        pcall(function() if c.host then c.host:flush(); c.host:destroy() end end)
    end
end

-- Conecta al servidor y registra el nickname. El nombre del servidor se
-- resuelve en otro hilo (ver Resolver): nunca congela el juego.
function NC:connect(host, port, name)
    if self.client or self._resolving then return end
    self.myName       = name
    self._connectTimer = 0   -- iniciar contador de timeout (cuenta también el DNS)
    local job = Resolver.start(host)
    if job then
        self._resolving = { job = job, port = port, name = name }
    else
        self:_open(host, port, name)
    end
end

function NC:isBusy() return self.client ~= nil or self._resolving ~= nil end

function NC:_open(host, port, name)
    self.client = sock.newClient(host, port, Protocol.CHANNELS)
    self.client:setSerialization(bitser.dumps, bitser.loads)

    -- Al conectar a nivel ENet: handshake con versión de protocolo + nickname
    self.client:on("connect", function()
        self.client:send("hello", { v = Protocol.VERSION, name = name })
    end)

    -- El servidor cerró la conexión (evento ENet DISCONNECT)
    local me = self.client
    self.client:on("disconnect", function()
        if self.client ~= me then return end   -- ya fue procesado por disconnect() intencional
        self.connected     = false
        self.client        = nil
        dropClient(me)
        self._connectTimer = nil
        NC:_fire("connection_lost", { msg = Lang('err.server_closed') })
    end)

    -- Login exitoso: ya estamos dentro
    self.client:on("login_success", function(data)
        self.myId          = data.id
        self.myName        = data.name
        self.connected     = true
        self._connectTimer = nil   -- conexión establecida, cancelar timeout
        NC:_fire("login_success", data)
    end)

    -- Login rechazado (versión, nombre en uso...): cerrar y avisar
    self.client:on("login_error", function(data)
        NC:disconnect()
        NC:_fire("login_error", data)
    end)

    self.client:on("game_init", function(data)
        NC.pendingGameInit = data
        NC:_fire("game_init", data)
    end)

    -- Dispatchers estáticos para el resto de eventos del juego
    local events = {
        "room_list", "room_update", "room_announce",
        "room_left", "kicked", "banned", "room_closed",
        "room_error", "level_catalog", "s", "ev",
    }
    for _, evt in ipairs(events) do
        local e = evt
        self.client:on(e, function(data)
            NC:_fire(e, data)
        end)
    end

    self.client:connect()
    -- Si el servidor deja de responder (se cae, se va la red), darlo por
    -- perdido en ≤10 s en vez de los 30 s de ENet por defecto
    pcall(function() self.client:setTimeout(32, 3000, 10000) end)
end

-- Desconecta limpiando el estado (desconexión intencional — no dispara connection_lost).
function NC:disconnect()
    local c = self.client
    self.client        = nil   -- nil ANTES de que ENet pueda disparar disconnect
    self.connected     = false
    self.myId          = nil
    self._connectTimer = nil
    self._resolving    = nil   -- (si el DNS responde luego, se ignora)
    self.pendingGameInit = nil
    -- Avisar al servidor para que libere el slot al instante (no esperar timeout)
    -- y cerrar el socket
    dropClient(c)
end

-- Fallo de red: limpiar TODO (cliente, socket, DNS pendiente) y avisar
function NC:_fail(msg)
    local c = self.client
    self._connectTimer = nil
    self._resolving    = nil
    self.connected     = false
    self.client        = nil
    dropClient(c)
    NC:_fire("connection_lost", { msg = msg })
end

-- Debe llamarse cada frame con dt. Gestiona timeout y errores de red.
function NC:update(dt)
    if graveyard[1] then buryClients() end
    if not self.client and not self._resolving then return end

    -- Timeout de conexión: si login_success no llega en CONNECT_TIMEOUT segundos
    -- (incluye resolver el nombre del servidor)
    if self._connectTimer ~= nil then
        self._connectTimer = self._connectTimer + (dt or 0.016)
        if self._connectTimer >= CONNECT_TIMEOUT then
            return self:_fail(Lang('err.connect_timeout'))
        end
    end

    -- Nombre del servidor resuelto (en otro hilo): ahora sí, conectar
    local r = self._resolving
    if r then
        local ip = r.job:poll()
        if ip == nil then return end                       -- aún no
        self._resolving = nil
        if not ip then return self:_fail(Lang('err.not_found')) end
        local ok, err = pcall(function() self:_open(ip, r.port, r.name) end)
        if not ok then return self:_fail(tostring(err)) end
    end

    local ok, err = pcall(function() self.client:update() end)
    if not ok then self:_fail(tostring(err)) end
end

function NC:isConnected()
    return self.connected and self.client ~= nil
end

-- ── Dispatch interno ─────────────────────────────────────────────────────────

function NC:_fire(event, data)
    if self._handlers[event] then
        self._handlers[event](data)
    end
end

return NC
