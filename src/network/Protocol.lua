-- src/network/Protocol.lua
-- Constantes y codificación compartidas entre cliente y servidor online.
-- Cualquier cambio aquí que rompa compatibilidad debe subir VERSION.

local Tiles = require 'src/world/tiles/Tiles'

local P = {}

-- ── Versión / red ─────────────────────────────────────────────────────────────
P.VERSION = 92        -- el servidor rechaza clientes con otra versión (92: machacar cuenta todos los botones menos la linterna — izquierda/derecha en el estado propio, 39 —; 91: la Planta carnívora traga al jugador — tragado en el estado propio: bandera F_GULP e índices 35-38, PF_GULP —, se cuelga del techo y de las paredes (prop `mount`), se come de todo y revienta con una bomba lanzada (estado 'bomb'; la bomba, 'eaten'); la Piraña nada como el pez globo y en seco hace lo mismo que él (estados dry_* en vez de 'flop'); 90: el Topo, la Piraña y la Planta carnívora — tipos nuevos; la piraña manda en su netPack cuándo llega a lo más alto del salto —; 89: el trozo de platillo del Escarabajo Gigante lleva la isla del platillo en su netPack; 88: la Icy noqueada en un evento ya no se toca por sus pinzas; 87: el Escarabajo Gigante, estado 'hop' nuevo (se baja del platillo al levantarse); 86: el Escarabajo Gigante pesa en la Balanza y atraviesa los platillos de lado; 85: la isla de la JUNGLA — Gummy / Crabby / Crabby trampolín de la jungla (tipos nuevos), tiles nuevos 40-43, templo_escarabajo re-vestido —; 84: arena del templo con las plataformas una casilla más bajas; 83: Escarabajo Rinoceronte: estado 'brake' nuevo (frena derrapando), solo el impacto de la embestida empuja; 82: Escarabajo Rinoceronte con alas (prop `wings`: los súbditos del Escarabajo Gigante vuelan — otra lista de entidades —), empuja y arrolla embistiendo; arena del templo sin fosos; 81: Escarabajo Rinoceronte libre de su ruta al embestir y lanzado, sigue en las manos (whileCarried); el trozo de suelo del jefe lleva su tile en el netPack y el evento fx lleva `tile`; la zona de jefe rompe lo traído de fuera; 80: nivel nuevo templo_escarabajo (el Escarabajo Rinoceronte Gigante, en Juego Libre); 79: Escarabajo Rinoceronte (tipo nuevo, enemigo de la jungla) y Escarabajo Rinoceronte Gigante (tipo nuevo, jefe: bloques, cascotes y ondas en su netPack); la Balanza dispara con los golpes fuertes y lleva y dispara a los jefes (física predicha distinta); 78: Soplones en 27 niveles y la Ventisca en torre_viento — otras listas de entidades —; 77: el Géiser manda la cara de arriba de su agua (jetY, un estado) en vez del corte; la Caja manda su factor de empuje (fila + peso); 76: el Géiser manda en su netPack dónde se corta el chorro y lo que pesa lo que levanta; pushAt recibe a quién empuja; 75: el Géiser empuja de golpe — 3er valor de pushAt, la física predicha cambia —, los platillos de la Balanza se paran en bloques y se bajan agachado; 74: CARGAR — bit de input IN_GRAB_P 128, quien lleva cada cargable en el índice 10 de su entrada —, el aire (windVx en el estado propio, 34), Caja / Caja pequeña / Balanza (tipos nuevos), bomba objeto cargable que reaparece (otra lista en 3 niveles), familias de isla (Isles); 73: Mega Crabby lúgubre — medidor de luz en su netPack; 72: Mega Mashup — director `crabmashup` (tipo nuevo, netPack propio), nivel mashup_cangrejos, escenas, props de evento en los jefes, ayuda inteligente (bossdrops también en eventos); 71: Cangrejo Groove — ánimo del público en su netPack, revienta al morir (dying_burst); 70: El Groove con 2ª fase — platos de DJ, bajón; sin conga (netPack nuevo); 69: El Groove rehecho: nota dorada, aturdido, pista de baile, conga (netPack nuevo); 68: El Groove (tipo nuevo groovecrab, jefe secreto) y su nivel isla_del_groove; 67: Saltarín Gigante (tipo nuevo, jefe de las cuevas) y su nivel gruta_del_farol; 66: Saltarines en lugar de algunos lúgubres en las cuevas oscuras (otra lista de entidades); 65: Saltarín de cueva a oscuras = polilla (estado 'scared' nuevo); 64: cuenta atrás del principio de la ronda — StartCountdown, `cd` en game_init, mundo congelado —; 63: peces globo de reserva del Pez Globo Gigante (otra lista de entidades) y su huida de un salto; 62: peces globo en seco (estados dry_* nuevos) y el Pez Globo Gigante reequilibrado; 61: Pez Globo Gigante (tipo nuevo, jefe de la costa) y la resaca de las inundaciones (prop undertow: arrastra al jugador mientras baja el agua); 60: derrotas nuevas de los jefes — huyen gigantes: estados dying_* nuevos, trozo aturdido del Rey Gummy —; 59: Xtra extremo con UN jefe enfadado (bossFury) en vez de dos: otra lista de entidades; 58: ayuda en las peleas de jefe (director bossdrops y su reserva: entidades nuevas al final de la lista en Extremo y Xtra extremo); 57: Claudio (tipo nuevo, hecho con datos); 56: una sola zona de puntos activa que se mueve (reloj `zc` en la instantánea), dificultad de la sala (set_difficulty); 55: manzana (tipo nuevo, ya en niveles; cura en el estado propio); 54: el Espejo perseguidor, suelto y con ataques (red nueva); 53: el Espejo perseguidor (mirrorchase) y su nivel; 52: Crabby de cueva (tipo nuevo, ya en niveles); 51: Crabby de río y Crabby de lava (tipos nuevos, ya en niveles); 50: Gummy de cueva y Gummy de la fortaleza (tipos nuevos, ya en niveles); 49: Gummy de magma y Crabby de la fortaleza (tipos nuevos, ya en niveles); 48: Saltarín (entidad nueva); 47: Crabby lúgubre solo muere con ground pound (rebote), ruidos genéricos; 46: Mega Crabby lúgubre: techo, giro, aros con alcance; 45: Mega Crabby lúgubre terrestre (red nueva); 44: Mega Crabby lúgubre rehecho (red nueva), marcas de ruido; 43: niveles a oscuras, linterna (bit de input, estado propio 31-33, PF_LIGHT), Crabby lúgubre; 42: campo de carámbanos del Mega Crabby helado, guardia del Rey Gummy por todos lados (paracaídas), vuelo libre; 41: Rey Gummy, guardias Gummy de reserva; 40: Mega Crabby helado; 39: Crabby helado; 38: Gran Bola de Nieve rehecha, fases de zona, bloques de fase; 37: Gran Bola de Nieve; 36: congelador; 27: Bloques ON/OFF, vista fija en niveles; 28: entradas de jefe genéricas; 29: ataques de arena del Espejo; 30: cristal roto de jefe; 31: muertes especiales de enemigos; 32: bombas; 33: nieve, hielo y hielo fino; 34: arena; 35: roca abisal)
-- Entidades que el servidor manda a cada jugador: las que están a menos de esto (px) de donde MIRA (los jefes,
-- siempre). El cliente, a lo que no viene y está más lejos, no lo da por "en reposo" (sigue como estaba)
P.NEAR_X, P.NEAR_Y = 1400, 1000

-- Sonidos PRIVADOS: solo los oye el jugador que los causa (su cliente ya los
-- genera con la predicción), así que el servidor no los manda a nadie. P. ej.
-- la alarma de ahogo: cada uno debe oír solo la suya.
P.PRIVATE_SOUNDS = { waterWarning = true }
-- Sonidos COMPARTIDOS: los oyen todos, también quien los causa (su cliente NO
-- los predice): lo que decide solo el servidor, p. ej. el casco que se rompe
-- con un ground pound o el pinchazo del pez globo.
P.SHARED_SOUNDS  = { helmetBreak = true, pufferPrick = true, cryoFreeze = true }
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
P.IN_LIGHT_P   = 64    -- linterna recién pulsada en este tick (niveles a oscuras)
P.IN_GRAB_P    = 128   -- ARRIBA recién pulsado: coger / lanzar lo que se carga (systems/Carry)
P.IN_MAX       = 255
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

function P.encodeInput(left, right, jump, crouch, jumpPressed, crouchPressed, lightPressed, grabPressed)
    local b = 0
    if left          then b = b + P.IN_LEFT     end
    if right         then b = b + P.IN_RIGHT    end
    if jump          then b = b + P.IN_JUMP     end
    if crouch        then b = b + P.IN_CROUCH   end
    if jumpPressed   then b = b + P.IN_JUMP_P   end
    if crouchPressed then b = b + P.IN_CROUCH_P end
    if lightPressed  then b = b + P.IN_LIGHT_P  end
    if grabPressed   then b = b + P.IN_GRAB_P   end
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
    out.light_pressed  = band(bits, P.IN_LIGHT_P)  ~= 0
    out.grab_pressed   = band(bits, P.IN_GRAB_P)   ~= 0
    return out
end

-- Stub de Input que PlayerAdventure consulta como global. Se instala durante
-- cada paso de simulación (cliente y servidor) para que el jugador lea el
-- input del tick en vez del teclado real.
function P.newInputStub()
    local inp = { left=false, right=false, jump=false, crouch=false,
                  jump_pressed=false, crouch_pressed=false, light_pressed=false, grab_pressed=false }
    local stub = {}
    stub.state = inp
    function stub.pressed(action)
        if action == 'jump' then
            local v = inp.jump_pressed; inp.jump_pressed = false; return v
        end
        if action == 'crouch' then
            local v = inp.crouch_pressed; inp.crouch_pressed = false; return v
        end
        if action == 'light' then
            local v = inp.light_pressed; inp.light_pressed = false; return v
        end
        if action == 'grab' then
            local v = inp.grab_pressed; inp.grab_pressed = false; return v
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

-- Índice de un material en el registro (mismo orden en cliente y servidor).
function P.materialIndex(m)
    for i, x in ipairs(Tiles.materials.list) do if x == m then return i end end
    return 0
end

-- ── Estado completo del jugador propio (para reconciliación) ─────────────────
-- Solo se envía a su dueño. Incluye todo lo que afecta a la física futura;
-- lo puramente visual (frame, animT, puff) lo mantiene el cliente.
local F_ON_GROUND, F_IN_WATER, F_PREV_WATER, F_CROUCH = 1, 2, 4, 8
local F_DROP, F_DYING, F_ALIVE, F_DROWN_DEAD           = 16, 32, 64, 128
local F_GULP                                           = 256   -- tragado por una Planta carnívora (PlayerGulp.lua)

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
    if pa.gulped      then f = f + F_GULP       end
    return {
        pa.x, pa.y, pa.vx, pa.vy, f, pa.jumpsLeft,
        P.deathCode(pa.deathPhase), pa.deathTimer, pa.deathY,
        P.drownCode(pa.drownPhase), pa.drownTimer, pa.drownChime, pa.drownAudT,
        pa.hp, pa.lives, pa.spawnX, pa.spawnY, pa.facing,
        pa.dropTop or 0, pa.dropHoldT or 0,
        pa.liquid and P.materialIndex(pa.liquid) or 0,
        pa.groundDef and pa.groundDef.id or -1,
        pa.hurtT or 0,
        (pa.gpPhase == 'windup' and 1) or (pa.gpPhase == 'fall' and 2) or 0,
        pa.gpT or 0, pa.stunT or 0, pa.invT or 0, pa.squashT or 0, pa.ctrlLockT or 0,
        pa.iceT or 0,
        pa.lightOn and 1 or 0, pa.lightBat or 1, pa.lightCd or 0,
        pa.windVx or 0,                                   -- (el arrastre del aire: systems/Push)
        pa.gulpMash or 0, pa.gulpBiteT or 0, pa.gulpNx or 0, pa.gulpNy or -1,   -- (tragado: PlayerGulp.lua)
        (pa.mashL and 1 or 0) + (pa.mashR and 2 or 0),   -- (machacar: izquierda / derecha ya pulsadas; mashPresses)
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
    pa.gulped      = band(f, F_GULP)       ~= 0
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
    pa.liquid      = Tiles.materials.list[s[21]]
    pa.groundDef   = s[22] >= 0 and Tiles.types.byId[s[22]] or nil
    pa.hurtT       = s[23]
    pa.gpPhase     = (s[24] == 1 and 'windup') or (s[24] == 2 and 'fall') or nil
    pa.gpT         = s[25]
    pa.stunT       = s[26]
    pa.invT        = s[27]
    pa.squashT     = s[28]
    pa.ctrlLockT   = s[29]
    pa.iceT        = s[30]
    pa.lightOn     = s[31] == 1
    pa.lightBat    = s[32]
    pa.lightCd     = s[33]
    pa.windVx      = s[34]
    pa.gulpMash    = s[35]
    pa.gulpBiteT   = s[36]
    pa.gulpNx      = s[37]
    pa.gulpNy      = s[38]
    local m = s[39] or 0
    pa.mashL, pa.mashR = m % 2 == 1, m >= 2
end

-- Estructura mínima para validar un estado propio recibido del servidor.
function P.isValidOwnState(s)
    if type(s) ~= 'table' or #s < 38 then return false end
    for i = 1, 38 do if type(s[i]) ~= 'number' then return false end end
    return true
end

-- ── Estado visual de un jugador (lo ven todos) ────────────────────────────────
-- { idx, x, y, facing, frame, flags, lives, hp, score, drownCode, air% }
P.PF_DYING, P.PF_SPECTATOR, P.PF_FINISHED, P.PF_STUNNED = 1, 2, 4, 8
P.PF_HURT = 16      -- acaba de recibir daño (parpadea en rojo)
P.PF_INVULN = 32    -- recién reaparecido: invulnerable (parpadea)
P.PF_SQUASH = 64    -- aplastado (sprite achatado)
P.PF_ICE = 128      -- congelado en un bloque de hielo (congelador)
P.PF_LIGHT = 256    -- linterna encendida (niveles a oscuras)
P.PF_GULP = 512     -- tragado por una Planta carnívora (no se dibuja: está dentro)

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
