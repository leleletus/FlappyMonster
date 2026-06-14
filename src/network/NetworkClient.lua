-- src/network/NetworkClient.lua
-- Singleton que gestiona la conexión con el servidor de FlappyMonster Online.
-- Los estados registran callbacks via NC:on(event, fn).
-- Cuando el estado cambia, simplemente sobreescribe los callbacks que necesita.

local sock   = require 'libs/sock'
local bitser = require 'libs/bitser'

local CONNECT_TIMEOUT = 5   -- segundos hasta considerar que el servidor no responde

local NC = {
    client         = nil,
    connected      = false,
    myId           = nil,
    myName         = nil,
    _handlers      = {},
    _connectTimer  = nil,   -- nil = no hay intento en curso; número = segundos transcurridos
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

-- Conecta al servidor y registra el nickname.
function NC:connect(host, port, name)
    if self.client then return end
    self.myName       = name
    self._connectTimer = 0   -- iniciar contador de timeout

    self.client = sock.newClient(host, port)
    self.client:setSerialization(bitser.dumps, bitser.loads)

    -- Al conectar a nivel TCP/ENet, mandar nickname
    self.client:on("connect", function()
        self.client:send("set_nickname", name)
    end)

    -- El servidor cerró la conexión (evento ENet DISCONNECT)
    self.client:on("disconnect", function()
        if not self.client then return end   -- ya fue procesado por disconnect() intencional
        self.connected     = false
        self.client        = nil
        self._connectTimer = nil
        NC:_fire("connection_lost", { msg = "El servidor cerro la conexion." })
    end)

    -- Login exitoso: ya estamos dentro
    self.client:on("login_success", function(data)
        self.myId          = data.id
        self.myName        = data.name
        self.connected     = true
        self._connectTimer = nil   -- conexión establecida, cancelar timeout
        NC:_fire("login_success", data)
    end)

    -- Dispatchers estáticos para el resto de eventos del juego
    local events = {
        "room_list", "room_update", "room_announce",
        "room_left", "kicked", "banned", "room_closed",
        "game_state", "room_error",
    }
    for _, evt in ipairs(events) do
        local e = evt
        self.client:on(e, function(data)
            NC:_fire(e, data)
        end)
    end

    self.client:connect()
end

-- Desconecta limpiando el estado (desconexión intencional — no dispara connection_lost).
function NC:disconnect()
    self.client        = nil   -- nil ANTES de que ENet pueda disparar disconnect
    self.connected     = false
    self.myId          = nil
    self._connectTimer = nil
end

-- Debe llamarse cada frame con dt. Gestiona timeout y errores de red.
function NC:update(dt)
    if not self.client then return end

    -- Timeout de conexión: si login_success no llega en CONNECT_TIMEOUT segundos
    if self._connectTimer ~= nil then
        self._connectTimer = self._connectTimer + (dt or 0.016)
        if self._connectTimer >= CONNECT_TIMEOUT then
            self._connectTimer = nil
            self.connected     = false
            self.client        = nil
            NC:_fire("connection_lost", {
                msg = "Tiempo de espera agotado. El servidor no responde.",
            })
            return
        end
    end

    local ok, err = pcall(function() self.client:update() end)
    if not ok then
        self._connectTimer = nil
        self.connected     = false
        self.client        = nil
        NC:_fire("connection_lost", { msg = tostring(err) })
    end
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
