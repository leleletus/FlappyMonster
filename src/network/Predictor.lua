-- src/network/Predictor.lua
-- Predicción del jugador local con reconciliación contra el servidor.
--
-- Cada tick fijo el cliente simula su jugador con el input del tick (sin
-- esperar al servidor) y guarda ese input numerado. Cuando llega un snapshot
-- con "último input procesado = N" y el estado autoritativo tras N, el
-- predictor restaura ese estado y re-simula los inputs > N. Si predicción y
-- servidor coinciden no hay corrección visible; si difieren (colisión con
-- enemigos, burbujas de aire, pérdida de paquetes) el error resultante se
-- absorbe suavemente en unos frames en vez de teletransportar al jugador.

local Protocol = require 'src/network/Protocol'

local Predictor = {}
Predictor.__index = Predictor

local ERR_DECAY     = 12     -- 1/s: velocidad con la que se absorbe el error visual
local SNAP_DIST     = 128    -- px: por encima de esto se corrige sin suavizar
local HISTORY_MAX   = 240    -- ticks de inputs guardados (4 s)
local BOUNCE_WINDOW = 20     -- ticks: rebote local ≈ rebote del servidor

-- Campos puramente visuales de PlayerAdventure (no afectan a la física)
local VISUAL_FIELDS = { 'animT', 'frame', 'puff', 'airBarAlpha', 'airBarBobT', 'airBarBobOn', 'airBarShakeX' }

local function noop() end
local MUTED_SOUND = setmetatable({}, { __index = function() return noop end })

function Predictor.new(pa, level)
    return setmetatable({
        pa        = pa,
        level     = level,
        seq       = 0,        -- último input generado
        ackSeq    = 0,        -- último input confirmado por el servidor
        history   = {},       -- [seq] = { bits, bounceVy }
        inputStub = Protocol.newInputStub(),
        prevX     = pa.x, prevY = pa.y,   -- posición al inicio del tick (interpolación de render)
        errX      = 0,    errY  = 0,      -- error visual pendiente de absorber
        serverBounceSeq = 0,
        localBounces    = {},             -- seqs de rebotes predichos (para sonido)
        corrections     = 0,              -- estadística: correcciones con error > 1px
        lastError       = 0,
    }, Predictor)
end

-- Un paso fijo de física con `bits` como input. `silent` = re-simulación
-- (no debe volver a sonar nada).
function Predictor:_step(bits, silent)
    local realInput, realSound = Input, Sound
    Protocol.decodeInput(bits, self.inputStub.state)
    Input = self.inputStub
    if silent then Sound = MUTED_SOUND end
    local ok, err = pcall(self.pa.update, self.pa, Protocol.TICK_DT, self.level)
    Input, Sound = realInput, realSound
    if not ok then error(err, 0) end
end

-- Simula un tick nuevo con el input local. Devuelve su número de secuencia.
function Predictor:tick(bits)
    self.seq = self.seq + 1
    self.prevX, self.prevY = self.pa.x, self.pa.y
    self:_step(bits, false)
    self.history[self.seq] = { bits = bits }
    self.history[self.seq - HISTORY_MAX] = nil
    return self.seq
end

-- Registra que en el tick actual se aplicó un rebote predicho sobre un enemigo.
function Predictor:recordBounce(vy)
    local h = self.history[self.seq]
    if h then h.bounceVy = vy end
    table.insert(self.localBounces, self.seq)
    if #self.localBounces > 16 then table.remove(self.localBounces, 1) end
end

-- Inputs aún no confirmados (máx. `maxN`, los más recientes) para reenviar.
function Predictor:unacked(maxN)
    local first = math.max(self.ackSeq + 1, self.seq - maxN + 1)
    local list = {}
    for s = first, self.seq do
        local h = self.history[s]
        list[#list + 1] = h and h.bits or 0
    end
    return first, list
end

-- Aplica el estado autoritativo tras el input `ack` y re-simula lo pendiente.
-- Devuelve info para que el estado de juego reaccione (sonidos, etc.).
function Predictor:reconcile(ack, own, bounceSeq)
    if type(ack) ~= 'number' or ack < self.ackSeq or not Protocol.isValidOwnState(own) then
        return nil
    end
    if ack > self.seq then ack = self.seq end
    for s = self.ackSeq + 1, ack do self.history[s] = nil end
    self.ackSeq = ack

    -- ¿El servidor registró un rebote que no predijimos? (para su sonido)
    local missedBounce = false
    if type(bounceSeq) == 'number' and bounceSeq > self.serverBounceSeq then
        self.serverBounceSeq = bounceSeq
        missedBounce = true
        for _, s in ipairs(self.localBounces) do
            if math.abs(s - bounceSeq) <= BOUNCE_WINDOW then missedBounce = false; break end
        end
    end

    local pa = self.pa
    local oldX, oldY   = pa.x, pa.y
    local wasDying     = pa.dying

    -- El estado VISUAL (animación, "puff", barra de aire) no debe avanzar en
    -- la re-simulación: son ticks que ya se mostraron. Sin esto la animación
    -- corría 1,5-4 veces más rápido según el ping.
    local vis = {}
    for i, k in ipairs(VISUAL_FIELDS) do vis[i] = pa[k] end

    Protocol.applyOwnState(own, pa)
    for s = ack + 1, self.seq do
        local h = self.history[s]
        if h then
            self:_step(h.bits, true)
            -- Re-aplicar rebotes predichos que el servidor aún no ha simulado
            if h.bounceVy and not pa.dying
               and math.abs(s - self.serverBounceSeq) > BOUNCE_WINDOW then
                pa.vy = h.bounceVy; pa.jumpsLeft = 2; pa.onGround = false
            end
        end
    end

    for i, k in ipairs(VISUAL_FIELDS) do pa[k] = vis[i] end
    -- Si la corrección cambió la postura, el cuadro de agachado debe seguirla
    if pa.crouching and pa.frame ~= 5 then pa.frame = 5
    elseif not pa.crouching and pa.frame == 5 then pa.frame = 3 end

    -- Mantener la posición en pantalla continua: el salto se convierte en un
    -- error visual que decae, salvo teletransportes (respawn) o muerte.
    local dx, dy = oldX - pa.x, oldY - pa.y
    local dist2  = dx * dx + dy * dy
    self.lastError = math.sqrt(dist2)
    if dist2 > 1 then self.corrections = self.corrections + 1 end
    if dist2 > SNAP_DIST * SNAP_DIST or pa.dying ~= wasDying then
        self.errX, self.errY = 0, 0
        self.prevX, self.prevY = pa.x, pa.y
    else
        self.prevX, self.prevY = self.prevX - dx, self.prevY - dy
        self.errX,  self.errY  = self.errX + dx,  self.errY + dy
    end

    return { wasDying = wasDying, missedBounce = missedBounce }
end

-- Absorbe el error visual con decaimiento exponencial (independiente de FPS).
function Predictor:decay(dt)
    local k = math.exp(-ERR_DECAY * dt)
    self.errX, self.errY = self.errX * k, self.errY * k
    if math.abs(self.errX) < 0.05 then self.errX = 0 end
    if math.abs(self.errY) < 0.05 then self.errY = 0 end
end

-- Posición de render: interpolada dentro del tick (alpha 0..1) + error visual.
function Predictor:renderPos(alpha)
    local pa = self.pa
    return self.prevX + (pa.x - self.prevX) * alpha + self.errX,
           self.prevY + (pa.y - self.prevY) * alpha + self.errY
end

return Predictor
