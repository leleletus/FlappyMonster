-- src/network/Resolver.lua
-- Resuelve un nombre de servidor (DNS) en un HILO aparte. ENet lo hace de
-- forma bloqueante al conectar: si la red acaba de caerse o el DNS va lento,
-- el juego entero se congelaba (sin dibujar ni leer mandos) justo al pulsar
-- CONECTAR; en Switch podía durar muchísimo. Así el hilo principal sigue vivo
-- y el tiempo de espera de NetworkClient funciona.
--
--   local job = Resolver.start(host)   -- nil si ya es una IP (no hace falta)
--   job:poll()  -> nil (aún no), ip, o false (no se pudo resolver)

local Resolver = {}

local THREAD_CODE = [[
local host, out = ...
local ok, socket = pcall(require, 'socket')
if not ok or not socket or not socket.dns then out:push('?'); return end
local ip = socket.dns.toip(host)
out:push(ip or false)
]]

local lastGood = {}   -- host -> última IP resuelta (por si luego falla el DNS)

local function isIP(host)
    return host:match('^%d+%.%d+%.%d+%.%d+$') ~= nil or host:find(':', 1, true) ~= nil
end

function Resolver.start(host)
    if isIP(host) then return nil end
    if host == 'localhost' then return { poll = function() return '127.0.0.1' end } end
    local ok, thread = pcall(love.thread.newThread, THREAD_CODE)
    if not ok or not thread then return nil end              -- sin hilos: como antes
    local ch = love.thread.newChannel()
    thread:start(host, ch)
    local job = { host = host }
    function job:poll()
        local r = ch:pop()
        if r == nil then
            local err = thread:getError()
            if err then r = '?' else return nil end
        end
        if r == '?' then return self.host end                 -- sin LuaSocket: que lo resuelva ENet
        if r then lastGood[self.host] = r; return r end
        return lastGood[self.host] or false                   -- DNS falló: la última IP buena
    end
    return job
end

return Resolver
