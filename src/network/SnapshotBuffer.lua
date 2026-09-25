-- src/network/SnapshotBuffer.lua
-- Buffer de snapshots para interpolar entidades remotas (otros jugadores,
-- enemigos, burbujas). En vez de perseguir la última posición recibida, se
-- dibuja el mundo un poco en el pasado (`delay` ticks), interpolando entre
-- dos snapshots reales: el movimiento queda suave aunque la red tenga jitter.
-- El retardo se adapta al jitter y a la pérdida de paquetes medidos.

local SnapshotBuffer = {}
SnapshotBuffer.__index = SnapshotBuffer

local MAX_SNAPS     = 40
local RESYNC_TICKS  = 30     -- desfase de reloj que fuerza resincronizar
local MAX_DELAY     = 20     -- ticks (≈333 ms) como tope de retardo
local LOSS_HOLD     = 3      -- s que se mantiene el margen extra tras perder snapshots

function SnapshotBuffer.new(tickRate, snapEvery)
    local minDelay = snapEvery + 1
    return setmetatable({
        snaps     = {},
        tickRate  = tickRate,
        snapEvery = snapEvery,
        clock     = nil,         -- estimación del tick actual del servidor
        jitter    = 0,           -- desviación media de llegada (ticks)
        lossTimer = 0,
        minDelay  = minDelay,
        delay     = minDelay + 1,
    }, SnapshotBuffer)
end

-- Añade un snapshot (con campo `t` = tick del servidor). Ignora duplicados
-- y desordenados. Devuelve true si se aceptó.
function SnapshotBuffer:push(snap)
    local n = #self.snaps
    local last = self.snaps[n]
    if last and snap.t <= last.t then return false end
    if last and snap.t - last.t > self.snapEvery then self.lossTimer = LOSS_HOLD end

    table.insert(self.snaps, snap)
    if #self.snaps > MAX_SNAPS then table.remove(self.snaps, 1) end

    if not self.clock or math.abs(snap.t - self.clock) > RESYNC_TICKS then
        self.clock  = snap.t
        self.jitter = 0
    else
        local diff = snap.t - self.clock
        self.jitter = self.jitter + (math.abs(diff) - self.jitter) * 0.1
        self.clock  = self.clock + diff * 0.1
    end
    return true
end

function SnapshotBuffer:update(dt)
    if not self.clock then return end
    self.clock = self.clock + dt * self.tickRate
    if self.lossTimer > 0 then self.lossTimer = self.lossTimer - dt end

    local target = self.minDelay + self.jitter * 2.5
    if self.lossTimer > 0 then target = target + self.snapEvery end
    target = math.min(MAX_DELAY, target)
    -- Cambiar el retardo gradualmente para que no haya saltos
    self.delay = self.delay + (target - self.delay) * math.min(1, dt * 2)
end

function SnapshotBuffer:renderTick()
    return self.clock and (self.clock - self.delay) or nil
end

function SnapshotBuffer:newest()
    return self.snaps[#self.snaps]
end

-- Devuelve a, b, f: los snapshots que rodean al tick de render y la fracción
-- entre ambos (0..1). Si el tick de render supera al más nuevo, se mantiene
-- el último (a == b).
function SnapshotBuffer:sample()
    local s, n = self.snaps, #self.snaps
    if n == 0 or not self.clock then return nil end
    local rt = self.clock - self.delay
    if rt >= s[n].t then return s[n], s[n], 0 end
    if rt <= s[1].t then return s[1], s[1], 0 end
    for i = n - 1, 1, -1 do
        local a = s[i]
        if a.t <= rt then
            local b = s[i + 1]
            return a, b, (rt - a.t) / (b.t - a.t)
        end
    end
    return s[1], s[1], 0
end

return SnapshotBuffer
