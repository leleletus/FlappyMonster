-- src/network/Protocol.lua
-- Constantes y codificación compartidas entre cliente y servidor online.
-- Cualquier cambio aquí que rompa compatibilidad debe subir VERSION.

local P = {}

-- ── Versión / red ─────────────────────────────────────────────────────────────
P.VERSION        = 2        -- el servidor rechaza clientes con otra versión
P.CHANNELS       = 2
P.CH_RELIABLE    = 0        -- eventos de sala y de juego (ordenados, garantizados)
P.CH_STATE       = 1        -- snapshots e inputs (no fiables: el más nuevo gana)

-- ── Simulación ────────────────────────────────────────────────────────────────
-- Cliente y servidor simulan al jugador con el MISMO paso fijo; así la
-- predicción local coincide con el servidor y la reconciliación es exacta.
P.TICK_RATE      = 60
P.TICK_DT        = 1 / P.TICK_RATE
P.SNAPSHOT_EVERY = 2        -- ticks entre snapshots → 30 Hz
P.INPUT_REDUNDANCY = 12     -- inputs no confirmados reenviados en cada paquete

P.NAME_MAX       = 16

-- ── Input: bitmask por tick ───────────────────────────────────────────────────
P.IN_LEFT      = 1
P.IN_RIGHT     = 2
P.IN_JUMP      = 4
P.IN_CROUCH    = 8
P.IN_JUMP_P    = 16    -- salto recién presionado en este tick
P.IN_CROUCH_P  = 32    -- agacharse recién presionado en este tick
P.IN_MAX       = 63
P.IN_HELD_MASK = 15    -- sin flags de "recién presionado"

local band = bit and bit.band or function(a, b)
    local r, m = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + m end
        a = math.floor(a / 2); b = math.floor(b / 2); m = m * 2
    end
    return r
end
P.band = band

function P.bor(a, b)
    return a + b - band(a, b)
end

function P.encodeInput(left, right, jump, crouch, jumpPressed, crouchPressed)
    local b = 0
    if left          then b = b + P.IN_LEFT     end
    if right         then b = b + P.IN_RIGHT    end
    if jump          then b = b + P.IN_JUMP     end
    if crouch        then b = b + P.IN_CROUCH   end
    if jumpPressed   then b = b + P.IN_JUMP_P   end
    if crouchPressed then b = b + P.IN_CROUCH_P end
    return b
end

-- Rellena `out` (con los campos que usa el stub de Input) a partir del bitmask.
function P.decodeInput(bits, out)
    out.left           = band(bits, P.IN_LEFT)     ~= 0
    out.right          = band(bits, P.IN_RIGHT)    ~= 0
    out.jump           = band(bits, P.IN_JUMP)     ~= 0
    out.crouch         = band(bits, P.IN_CROUCH)   ~= 0
    out.jump_pressed   = band(bits, P.IN_JUMP_P)   ~= 0
    out.crouch_pressed = band(bits, P.IN_CROUCH_P) ~= 0
    return out
end

-- Stub de Input que PlayerAdventure consulta como global. Se instala durante
-- cada paso de simulación (cliente y servidor) para que el jugador lea el
-- input del tick en vez del teclado real.
function P.newInputStub()
    local inp = { left=false, right=false, jump=false, crouch=false,
                  jump_pressed=false, crouch_pressed=false }
    local stub = {}
    stub.state = inp
    function stub.pressed(action)
        if action == 'jump' then
            local v = inp.jump_pressed; inp.jump_pressed = false; return v
        end
        if action == 'crouch' then
            local v = inp.crouch_pressed; inp.crouch_pressed = false; return v
        end
        return false
    end
    function stub.down(action)
        if action == 'move_left'  then return inp.left   end
        if action == 'move_right' then return inp.right  end
        if action == 'jump'       then return inp.jump   end
        if action == 'crouch'     then return inp.crouch end
        return false
    end
    return stub
end

-- ── Códigos de enumeraciones ──────────────────────────────────────────────────
local DROWN   = { 'none', 'warning', 'drowning', 'dead' }
local DEATH   = { 'freeze', 'jump', 'fall' }
local function inverse(t) local r = {}; for i, v in ipairs(t) do r[v] = i end; return r end
local DROWN_I = inverse(DROWN)
local DEATH_I = inverse(DEATH)

function P.drownCode(s)   return DROWN_I[s] or 1 end
function P.drownName(c)   return DROWN[c] or 'none' end
function P.deathCode(s)   return s and DEATH_I[s] or 0 end
function P.deathName(c)   return DEATH[c] end

-- ── Estado completo del jugador propio (para reconciliación) ─────────────────
-- Solo se envía a su dueño. Incluye todo lo que afecta a la física futura;
-- lo puramente visual (frame, animT, puff) lo mantiene el cliente.
local F_ON_GROUND, F_IN_WATER, F_PREV_WATER, F_CROUCH = 1, 2, 4, 8
local F_DROP, F_DYING, F_ALIVE, F_DROWN_DEAD           = 16, 32, 64, 128

function P.packOwnState(pa)
    local f = 0
    if pa.onGround    then f = f + F_ON_GROUND  end
    if pa.inWater     then f = f + F_IN_WATER   end
    if pa.prevInWater then f = f + F_PREV_WATER end
    if pa.crouching   then f = f + F_CROUCH     end
    if pa.dropping    then f = f + F_DROP       end
    if pa.dying       then f = f + F_DYING      end
    if pa.alive       then f = f + F_ALIVE      end
    if pa.drownDead   then f = f + F_DROWN_DEAD end
    return {
        pa.x, pa.y, pa.vx, pa.vy, f, pa.jumpsLeft,
        P.deathCode(pa.deathPhase), pa.deathTimer, pa.deathY,
        P.drownCode(pa.drownPhase), pa.drownTimer, pa.drownChime, pa.drownAudT,
        pa.hp, pa.lives, pa.spawnX, pa.spawnY, pa.facing,
        pa.dropTop or 0, pa.dropHoldT or 0,
    }
end

function P.applyOwnState(s, pa)
    pa.x, pa.y, pa.vx, pa.vy = s[1], s[2], s[3], s[4]
    local f = s[5]
    pa.onGround    = band(f, F_ON_GROUND)  ~= 0
    pa.inWater     = band(f, F_IN_WATER)   ~= 0
    pa.prevInWater = band(f, F_PREV_WATER) ~= 0
    pa.crouching   = band(f, F_CROUCH)     ~= 0
    pa.dropping    = band(f, F_DROP)       ~= 0
    pa.dying       = band(f, F_DYING)      ~= 0
    pa.alive       = band(f, F_ALIVE)      ~= 0
    pa.drownDead   = band(f, F_DROWN_DEAD) ~= 0
    pa.jumpsLeft   = s[6]
    pa.deathPhase  = P.deathName(s[7])
    pa.deathTimer  = s[8]
    pa.deathY      = s[9]
    pa.drownPhase  = P.drownName(s[10])
    pa.drownTimer  = s[11]
    pa.drownChime  = s[12]
    pa.drownAudT   = s[13]
    pa.hp          = s[14]
    pa.lives       = s[15]
    pa.spawnX      = s[16]
    pa.spawnY      = s[17]
    pa.facing      = s[18]
    pa.dropTop     = s[19]
    pa.dropHoldT   = s[20]
end

-- Estructura mínima para validar un estado propio recibido del servidor.
function P.isValidOwnState(s)
    if type(s) ~= 'table' or #s < 20 then return false end
    for i = 1, 20 do if type(s[i]) ~= 'number' then return false end end
    return true
end

-- ── Estado visual de un jugador (lo ven todos) ────────────────────────────────
-- { idx, x, y, facing, frame, flags, lives, hp, score, drownCode, air% }
P.PF_DYING, P.PF_SPECTATOR = 1, 2

-- ── Utilidades ────────────────────────────────────────────────────────────────
function P.round(x) return math.floor(x + 0.5) end

-- Limpia un nombre: sin caracteres de control, espacios colapsados, longitud máx.
function P.sanitizeName(s, maxLen)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c]', ''):gsub('[^%w%s%-%_%.%!%?]', ''):gsub('%s+', ' ')
    s = s:match('^%s*(.-)%s*$')
    if #s == 0 then return nil end
    return s:sub(1, maxLen or P.NAME_MAX)
end

return P
