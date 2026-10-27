-- Jefe secreto CANGREJO GROOVE (types/groovecrab.lua; "El Groove" hasta la 0.5.54): un Crabby trampolín gigante — un CANGREJO VIOLINISTA (pinza grande y
-- pinza pequeña) con gafas de sol y el trampolín del juego en la espalda — que PELEA AL RITMO DE SU TEMA (`groove`,
-- tools/music/slap_boss.py: el slap bass de protagonista), en un ESCENARIO de playa al atardecer con público. Se abre
-- en el mapa tras vencer al Espejo (docs/bosses/groovecrab.md). Arte propio: tools/art/bosses/make_groove_crab.py.
-- Este archivo: el reglamento, la pelea y la red. El dibujo (él, el escenario, el público, la pista, los platos):
-- groovecrab_stage.lua (una PARTE: añade métodos a la misma tabla; docs/architecture/project-structure.md).
--
-- EL RELOJ ES LA CANCIÓN: `songT` = el tiempo desde que empezó la pelea (la música de la zona empieza en ese mismo
-- instante y sigue sonando al reaparecer). De él sale en qué SECCIÓN, compás y semicorchea está (tabla SONG: la
-- partitura del tema, 150 BPM: intro 8 compases + bucle A 16 · B 16 · SOLO 8 · SUBIDA 8 · CLÍMAX 16 · VUELTA 4), y de
-- eso, qué hace (GC.plan). No le afecta el ritmo de la dificultad (def.pace = false): todo cae en el compás.
--   · SALTO (A, compases impares de la 1ª mitad del clímax, la vuelta): se AGACHA con una diana en el suelo que te
--     sigue (fija en la semicorchea 6), SALTA en el tercer tiempo y CAE en el compás siguiente justo en el bombo: dos
--     ONDAS DE ARENA por el suelo (base/BossWaves.lua). Pura función del tiempo. En el SOLO, saltitos sin ondas.
--   · NOTAS (B y compases pares del clímax): alza la pinza grande y, en los POPS del bajo, dispara una NOTA de colores
--     hacia ti (recta). Entre chasquido y chasquido se te acerca andando.
--   · PISTA DE BAILE (la subida y la 2ª mitad del clímax): el suelo está hecho de baldosas (2 casillas): unas se
--     ENCIENDEN un tiempo (aviso) y en el siguiente LANZAN una columna de luz que quita 1. Dos dibujos por compás. En
--     las plataformas de los lados no llega.
--   · 1ª FASE — LA NOTA DORADA: en el golpe de banda que cierra cada 8 compases (y en el 5º del solo) dispara una
--     nota DORADA alta (pasa por encima de un jugador en el suelo: hay que SALTAR contra ella). Tocarla la DEVUELVE:
--     vuelve hacia él y al darle le REVIENTA EL TRAMPOLÍN → NOQUEADO 2 compases ('stunned': le vuelan las gafas, ojos
--     en X): pisotón 1, ground pound 2, hasta 2 golpes. Luego le CRECE otro trampolín de la cabeza ('regrow') y sigue.
--     La dorada no hace daño.
--   · 2ª FASE (por debajo de `rageAt`) — LOS PLATOS DE DJ: ya no hay doradas; en cada plataforma de los lados sale un
--     plato. Se sube con SU trampolín; pisar un plato (o ground pound) lo hace girar DECK_T s (cuenta atrás en sus
--     LED). Con los DOS girando a la vez, los bafles sueltan el BAJÓN contra él → noqueado igual que con la dorada.
--   · Su TRAMPOLÍN te lanza muy alto si le caes encima (también con ground pound). Tocar su CUERPO = 1 de vida y
--     empujón; las PINZAS no hacen daño (la caja es solo caparazón y patas).
--   · ENFADADO (en la 2ª fase; en Xtra extremo desde el principio, aunque siga en la 1ª): salta en todos los compases
--     que puede y dispara más notas. Vida 11 (+4 por jugador; la dificultad la escala).
-- Entrada: cae del cielo en su sitio, chasquea dos veces las pinzas y rebota en su trampolín. Derrota: aturdido
-- (estrellitas) y se va de un BOTE enorme en su trampolín hacia el cielo (pura función del tiempo). Sin fragmento.
-- Todo lo que se dibuja sale de state + deadTimer + x, y + netPackExtra (songT, fase, diana, ondas, notas, platos):
-- igual online. La pista de baile es función de songT.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local BossWaves = require 'src/world/entities/base/BossWaves'

local GC = Entity.extend(Boss, {
    ATTACKS  = { crouch = true, hop = true, snap = true },
    OPENINGS = { stunned = true },
    debugColor = { 0.3, 0.9, 0.85 },
    -- (la caja: SOLO el caparazón y las patas — 14 de los 18 px de ancho, sin las pinzas, que no hacen daño —; de
    -- alto, todo el cuerpo)
    hitbox = { outerW = 0.78, outerH = 1.0, innerW = 0.66, innerH = 0.7 },
})
GC.hurtSound   = 'megaHurt'
-- (su 'stunned' lo dibuja él: el bamboleo genérico GIRA todo su render alrededor de su centro, y su render también
-- pinta la pista de baile: las baldosas se mecían con él — el usuario, 0.5.48)
GC.ownStunLook = true
GC.introLength = 3.6
GC.wantsLevel  = true
local strike, overlap = Boss.strike, Boss.overlap

local P = {}                                    -- (lo que comparte con su parte de dibujo)
local T  = TILE_PX
local MS = 10                                   -- escala del pixel art (los Crabbies: 4)
local FW, FH = 18, 10                           -- el cuerpo: 18x10 (caparazón 7 filas + patas)
GC.MS = MS

-- ── LA CANCIÓN (tools/music/slap_boss.py; si cambia la partitura, cambia esto) ──
local S16 = 0.1                                 -- 150 BPM: semicorchea
local BAR = 16 * S16
local BEAT = 4 * S16
local INTRO_BARS = 8
local SONG = { { 'A', 16 }, { 'B', 16 }, { 'K', 8 }, { 'S', 8 }, { 'C', 16 }, { 'O', 4 } }
local LOOP = 0
for _, s in ipairs(SONG) do LOOP = LOOP + s[2] end
GC.S16, GC.BAR, GC.INTRO_BARS, GC.LOOP = S16, BAR, INTRO_BARS, LOOP
-- Las notas: en los POPS del bajo de cada compás de la B (y de la 2ª mitad del clímax, que es la B)
local B_NOTES = { { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 10 }, { 4, 8 }, {},
                  { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 10 }, { 4, 8 }, { 6 } }
local C_NOTES = { [2] = { 11 }, [6] = { 11 } }  -- (1ª mitad del clímax: el pop del final del riff)
local GOLD_AT = 12                              -- semicorchea de la nota dorada: el golpe de banda que cierra la frase
local CROUCH_LOCK = 6                           -- la diana se fija aquí; salta en la 8 y cae en la 0 siguiente
local MIN_WARN = 0.3                            -- s mínimos agachado (con la diana a la vista) para saltar

-- Saltos, notas, trampolín
local HOP_H, LICK_H = 3.2 * T, 1.4 * T          -- altura de un salto y de un saltito del solo
local HOP_DUR = 8 * S16                         -- de la semicorchea 8 a la 0 del compás siguiente
local WALK_SPD = 70                             -- px/s acercándose entre notas
local NOTE_SPD = { 300, 345 }                   -- { normal, enfadado } (0.5.55: 330 / 390, "se pasa un poco" — el usuario)
local NOTE_R = 16                               -- media caja de una nota
local NOTE_LIFE = 4.0
-- Los DIBUJOS de las notas (0.5.51, el usuario: "en diferentes patrones y más visibles"): cambian cada 2 compases
--   aim  recta hacia ti · fan  tres en abanico (la del centro, hacia ti) · lob  en arco, cae donde estás. Enfadado
--   (más notas por compás) no hay abanico: sería una lluvia. (Hubo una que ondulaba: "confunde bastante", 0.5.52)
local NOTE_KINDS = { 'aim', 'fan', 'lob' }
local FAN_A = 0.32                              -- rad entre las notas del abanico
local LOB_G, LOB_T = 1100, 1.05                 -- gravedad y s de vuelo de la nota en arco
-- El BAILE (0.5.51: "que sea más móvil"): entre ataques cruza el escenario a pasitos en cada tiempo, mirándote,
-- y nunca hacia ti si estás cerca
local DANCE_STEP = 0.5 * T                      -- px por tiempo (se mueve en la 2ª mitad de cada tiempo)
local DANCE_KEEP = 2.6 * T                      -- no se acerca andando a un jugador a menos de esto
local LAUNCH = 1.85                             -- × la velocidad de salto: lo que lanza el trampolín
local GRACE  = 0.8                              -- s sin volver a dar a nadie tras un toque
-- La nota dorada
local GOLD_SPD, GOLD_BACK = 240, 640            -- px/s: hacia ti / de vuelta hacia él
local GOLD_R = 24
local GOLD_UP = 2.2 * T                         -- apunta por ENCIMA de ti: hay que saltar contra ella
local GOLD_LIFE = 4.5
local STUN_T = 2 * BAR                          -- aturdido: dos compases
local STUN_HITS = 2                             -- golpes que admite aturdido
local REGROW_T = 0.9                            -- s que tarda en crecerle el trampolín nuevo
-- La pista de baile: baldosas de 2 casillas por todo el suelo de la zona; en cada compás dos dibujos: aviso en el
-- tiempo 1 → columna en el 2; aviso en el 3 → columna en el 4
local PANEL = 2 * T
local BOOM_H = 3.5 * T                          -- alto de la columna de luz (las plataformas de los lados, a 5, se salvan)
local BOOM_LEN = 3                              -- semicorcheas que dura la columna
local FLOOR_WARN = 12                           -- semicorcheas de AVISO antes de la columna (3 tiempos: 1,2 s; antes 0,4)
-- Los platos de DJ (2ª fase)
local DECK_T = 10 * BAR                         -- s que gira un plato tras pisarlo (16 s; el usuario, 0.5.56: tú lo atraes de un
                                                -- lado a otro, "con los platos un poquito más") — da para bajar, volver a su
                                                -- trampolín y subir a la otra plataforma)
local DECK_W, DECK_H = 24 * 4, 10 * 4           -- (el arte: 24x10 a ×4)
local DECK_IN = 1.0                             -- s que tardan en salir al empezar la 2ª fase
local DROP_FX = 0.8                             -- s que se ve el BAJÓN de los bafles
GC.PANEL, GC.BOOM_H, GC.DECK_T = PANEL, BOOM_H, DECK_T
P.T, P.MS, P.FW, P.FH, P.S16, P.BAR, P.BEAT = T, MS, FW, FH, S16, BAR, BEAT
P.REGROW_T, P.STUN_T, P.BOOM_LEN, P.FLOOR_WARN = REGROW_T, STUN_T, BOOM_LEN, FLOOR_WARN
P.NOTE_R, P.GOLD_R = NOTE_R, GOLD_R
P.DECK_T, P.DECK_W, P.DECK_H, P.DECK_IN, P.DROP_FX = DECK_T, DECK_W, DECK_H, DECK_IN, DROP_FX

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_TOUCH = { 1, 480, -420, 0.2, 0 }
local HIT_NOTE  = { 1, 300, -340, 0.15, 0 }
local HIT_BOOM  = { 1, 0, -620, 0.2, 0 }
local WAVES = { spd = 420, life = 2.0, w = 44, h = 34, hit = { 1, 300, -440, 0.15, 0 } }
P.WAVES = WAVES

-- Muerte
-- Muerte (0.5.56, el usuario: "se iba hacia arriba" → que EXPLOTE salvajemente, como los cangrejos en pinchos o lava):
-- noqueado DAZE_T s con explosioncitas cada vez más seguidas, y REVIENTA; luego el escenario se recoge (STAGE_OUT s)
local DAZE_T = 1.8
local STAGE_OUT = 2.4
local DEATH = { dying_daze = true, dying_burst = true }
P.DAZE_T, P.STAGE_OUT = DAZE_T, STAGE_OUT
-- El ÁNIMO del público (0.5.56): le VITOREA cuando te da o caes, le ABUCHEA cuando le das o lo vences
local CHEER, BOO = 1, 2
local MOOD_T = 2.0                                  -- s que dura una reacción
GC.CHEER, GC.BOO, GC.MOOD_T = CHEER, BOO, MOOD_T

function GC.sizePx() return FW * MS, FH * MS end
function GC:feetY() return self.y + self.outerH / 2 end
function GC:bossPhase() return self.phase or 1 end
-- (su "fase enfadada" es la del ritmo: el enfado genérico de Xtra extremo, que acelera, rompería el compás)
function GC:angryPhase() return true end

function GC:initBoss()
    self.floorY = self.row * T                         -- (los pies: de pie en el suelo de su celda; la arena es llana)
    self.y = self.floorY - self.outerH / 2
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.rage, self.phase = false, 1
    self.songT, self.prevT = 0, 0
    self.waves, self.nextId = {}, 0
    self.notes, self.noteId = {}, 0
    self.decks = nil                                   -- (nil: sin buscar aún; false: la arena no tiene plataformas)
    self.dropT, self.p2T = nil, nil                    -- (songT del último bajón y del paso a la 2ª fase: el dibujo)
    self.graceT, self.stunHits = 0, 0
    self.markX = math.floor(self.x)
end

function GC:onFightStart(n)
    self.songT, self.prevT = 0, -1e-6
    self.rage = require('src/core/Difficulty').flag('bossFury') == true
    self.phase = 1
    self:enter('groove')
end

-- ── Dónde va la canción ───────────────────────────────────────────────────────
-- → compás absoluto (0…), sección, compás dentro de ella (1…), semicorchea (0…16, con decimales)
function GC.where(st)
    local b = math.floor(st / BAR)
    local step = (st - b * BAR) / S16
    if b < INTRO_BARS then return b, 'I', b + 1, step end
    local lb = (b - INTRO_BARS) % LOOP
    for _, s in ipairs(SONG) do
        if lb < s[2] then return b, s[1], lb + 1, step end
        lb = lb - s[2]
    end
end
-- (la vuelta del bucle en que está el compás b: 0 en la intro y la primera)
function GC.loopOf(b) return b < INTRO_BARS and 0 or math.floor((b - INTRO_BARS) / LOOP) end

-- ¿Dispara la nota dorada en el compás (sec, k)? → su semicorchea, o nil. En el golpe de banda que cierra cada 8
-- compases (el usuario, 0.5.48: antes cada 4 eran demasiadas); en el SOLO, en el golpe del 5º compás. Solo en la 1ª
-- fase (ver GC:goldOn)
local PHRASE = { A = true, B = true, S = true, C = true }
function GC.goldAt(sec, k)
    if PHRASE[sec] and k % 8 == 0 then return GOLD_AT end
    if sec == 'K' and k == 5 then return 0 end
    return nil
end

-- ¿Pista de baile en el compás (sec, k)? (la subida entera y la 2ª mitad del clímax)
function GC.floorOn(sec, k) return sec == 'S' or (sec == 'C' and k >= 9) end

-- Lo que hace él en un compás: { hop = true | lick = true, notes = { semicorcheas } }. noGold: ya no suelta doradas
-- (2ª fase): sus compases son como los demás
function GC.plan(sec, k, rage, noGold)
    local p = { notes = {} }
    local gold = not noGold and GC.goldAt(sec, k) ~= nil
    if sec == 'I' then
        p.hop = k == 5 or k == 7
    elseif sec == 'A' then
        p.hop = not gold and (k % 2 == 1 or (rage and k % 4 == 0))     -- (enfadado, uno más cada 4; antes en todos)
    elseif sec == 'B' then
        p.notes = B_NOTES[k] or {}
        if rage and not gold and k % 4 == 1 then p.notes = { 4, 8, 12 } end   -- (enfadado: la tercera, cada 4 compases)
    elseif sec == 'C' then
        if k <= 8 then
            if k % 2 == 1 then p.hop = true
            else
                p.notes = C_NOTES[k] or {}
                if rage and not gold then p.notes = { 6, 11 } end
            end
        else p.notes = B_NOTES[k] or {} end
    elseif sec == 'K' then
        p.lick = k % 2 == 0
    elseif sec == 'O' then
        p.hop = k % 2 == 1
    end
    if gold then                                                        -- (nada después del golpe de la dorada)
        local keep = {}
        for _, s in ipairs(p.notes) do if s < GOLD_AT then keep[#keep + 1] = s end end
        p.notes = keep
    end
    return p
end

-- El dibujo de las notas del compás (sec, k): cambia cada 2 compases; enfadado, sin abanico
function GC.noteKind(sec, k, rage)
    local kind = NOTE_KINDS[math.floor((k - 1) / 2) % #NOTE_KINDS + 1]
    if rage and kind == 'fan' then kind = 'aim' end
    return kind
end

-- ── La pista de baile ─────────────────────────────────────────────────────────
-- Dibujos (uno por compás, en este orden): baldosas pares, impares, los lados, el centro. n = baldosas de la zona
local function pattern(which, n)
    local out = {}
    for i = 0, n - 1 do
        local on
        if which == 1 then on = i % 2 == 0
        elseif which == 2 then on = i % 2 == 1
        elseif which == 3 then on = i < math.floor(n / 4) or i >= n - math.floor(n / 4)
        else on = i >= math.floor(n / 4) + 1 and i < n - math.floor(n / 4) - 1 end
        out[i] = on
    end
    return out
end
function GC:panels()
    local zx0, zx1 = self:zoneBounds()
    local n = math.max(1, math.floor((zx1 - zx0) / PANEL))
    local x0 = zx0 + ((zx1 - zx0) - n * PANEL) / 2
    return n, x0
end
-- Lo que pasa en la pista AHORA: → nil o { lit = {i = true}, warn, boom, u (0..1 del aviso), beat (0..1 del tiempo) }
-- UN dibujo por compás (0.5.51, el usuario: "más visibles y evitables"; antes dos, con 0,4 s de aviso): AVISO los 3
-- primeros tiempos (FLOOR_WARN), la COLUMNA en el 4º (BOOM_LEN semicorcheas)
function GC:floorNow()
    local b, sec, k, step = GC.where(self.songT or 0)
    if not GC.floorOn(sec, k) then return nil end
    local n = self:panels()
    local which = (k - 1) % 4 + 1
    return { lit = pattern(which, n), warn = step < FLOOR_WARN, boom = step >= FLOOR_WARN and step < FLOOR_WARN + BOOM_LEN,
             u = math.min(1, step / FLOOR_WARN), beat = (step % 4) / 4 }
end
function GC:boomBox(i)
    local _, x0 = self:panels()
    return { x = x0 + i * PANEL + 6, y = self.floorY - BOOM_H, w = PANEL - 12, h = BOOM_H }
end
function GC:updateFloor(level)
    local f = self:floorNow()
    if not (f and f.boom) then return end
    for i, on in pairs(f.lit) do
        if on then
            local box = self:boomBox(i)
            for _, pa in ipairs(level.players or {}) do
                if overlap(pa:getOuterBounds(), box) then strike(pa, HIT_BOOM, (pa.x >= box.x + box.w / 2) and 1 or -1) end
            end
        end
    end
end

-- ── Los PLATOS DE DJ (2ª fase) ─────────────────────────────────────────────
-- Uno en cada plataforma de los lados (las más a la izquierda y a la derecha de la zona, por encima del suelo: se
-- buscan en los tiles, igual en un jugador y en el servidor). Un plato: { x, y (la cara de arriba de su plataforma),
-- on (s que le quedan girando) }. El usuario (0.5.48): "usando al propio Groove (trampolín) el jugador se trepa a las
-- plataformas y tiene que hacer algo en ambas con cierto tiempo"
function GC:findDecks(level)
    if not (level and level.getDef) then return false end
    local zx0, zx1, zy0 = self:zoneBounds()
    local c0, c1 = math.floor(zx0 / T) + 1, math.ceil(zx1 / T)
    local r0, r1 = math.max(1, math.floor(zy0 / T) + 1), math.floor(self.floorY / T) - 2     -- (2 casillas sobre el suelo)
    local mid = (zx0 + zx1) / 2
    local left, right
    -- (las plataformas de los platos son BLOQUES DE FASE: escondidas hasta la 2ª fase; cuentan con su casilla de verdad)
    local hidden = {}
    for _, pb in ipairs(level.phaseBlocks or {}) do
        for _, cell in ipairs(pb.cells) do hidden[cell.r * 65536 + cell.c] = cell.raw end
    end
    local TileTypes, TileCodec = require 'src/world/tiles/TileTypes', require 'src/world/tiles/TileCodec'
    local function stands(c, r)
        local raw = hidden[r * 65536 + c]
        local d = raw and TileTypes.get(TileCodec.id(raw)) or level:getDef(c, r)
        return d and (d.collision == 'oneway' or d.collision == 'solid')
    end
    for r = r0, r1 do
        local c = c0
        while c <= c1 do
            if stands(c, r) and not stands(c, r - 1) then
                local ca = c
                while c + 1 <= c1 and stands(c + 1, r) and not stands(c + 1, r - 1) do c = c + 1 end
                local raw0 = hidden[r * 65536 + ca]
            local d = raw0 and TileTypes.get(TileCodec.id(raw0)) or level:getDef(ca, r)
                local run = { x = ((ca - 1) + c) * T / 2, y = (r - 1) * T + math.floor((d.hitbox and d.hitbox.y or 0) * T), on = 0 }
                if (c - ca + 1) * T >= DECK_W then
                    if run.x < mid and (not left or run.x < left.x) then left = run end
                    if run.x > mid and (not right or run.x > right.x) then right = run end
                end
            end
            c = c + 1
        end
    end
    if not (left and right) then return false end
    return { left, right }
end
function GC:deckBox(d) return { x = d.x - DECK_W / 2, y = d.y - DECK_H, w = DECK_W, h = DECK_H } end
-- ¿Ya no suelta doradas? (2ª fase, si la arena tiene sus platos; si no, sigue con la dorada: si no, no habría forma
-- de dañarlo)
function GC:goldOff() return self.phase == 2 and self.decks ~= nil and self.decks ~= false end
-- ¿Se pueden poner a girar? (no con él noqueado o recomponiéndose: el bajón ya le dio; ni durante la pista de baile)
function GC:decksLive()
    return self:goldOff() and self:isActive() and self.state ~= 'stunned' and self.state ~= 'regrow' and not self:decksAway()
end
-- (0.5.53-0.5.55 se iba solo a ponerse bajo el otro plato al encender uno: "queda forzado y raro" — el usuario, 0.5.56;
-- ahora se porta como siempre y eres TÚ quien lo atrae: te sigue andando y sus saltos caen donde estás)

-- DURANTE LA PISTA DE BAILE (2ª fase) los platos y sus plataformas DESAPARECEN —céntrate en el ataque— y vuelven al
-- acabar (el usuario, 0.5.56). Del reloj de la canción: igual online (las casillas, como cambios de tile)
function GC:decksAway()
    if not self:goldOff() then return false end
    local _, sec, k = GC.where(self.songT or 0)
    return GC.floorOn(sec, k)
end
-- Pone o quita las casillas de las plataformas (las de los bloques de fase de su zona); una ocupada espera
function GC:setPlatforms(level, on)
    local TileTypes, TileCodec = require 'src/world/tiles/TileTypes', require 'src/world/tiles/TileCodec'
    local done, changed = true, false
    for _, pb in ipairs(level.phaseBlocks or {}) do
        if pb.shown then
            local hid = TileCodec.encode((TileTypes.byName[pb.hiddenAs] or TileTypes.byName.empty).id)
            for _, cell in ipairs(pb.cells) do
                local want = on and cell.raw or hid
                if level:getRaw(cell.c, cell.r) ~= want then
                    if on and level:cellOccupied(cell.c, cell.r) then done = false
                    else
                        level:setTileRaw(cell.c, cell.r, want)
                        changed = true
                        level.brokenQueue = level.brokenQueue or {}
                        table.insert(level.brokenQueue, { cell.c, cell.r, want, 'set' })
                        Entity.emitFx('spawn', (cell.c - 0.5) * T, (cell.r - 0.5) * T)
                    end
                end
            end
        end
    end
    return done, changed
end
function GC:updatePlatforms(level)
    if not self:goldOff() then return end
    local want = not self:decksAway()
    if self.platOn ~= want then
        local done, changed = self:setPlatforms(level, want)
        if done then self.platOn = want end
        if changed then Sound.play(want and 'switchOn' or 'switchOff', 0.8) end
    end
end

function GC:updateDecks(level, dt)
    if not self:goldOff() then return end
    local live = self:decksLive()
    local away = self:decksAway()
    for _, d in ipairs(self.decks) do
        if d.on > 0 and not away then                                       -- (escondidos, su cuenta se para)
            d.on = math.max(0, d.on - dt)
            if d.on == 0 then Sound.play('switchOff', 0.9) end                -- (se acabó el tiempo: hay que volver)
        end
        if live then
            local box = self:deckBox(d)
            for _, pa in ipairs(level.players or {}) do
                if not pa.dying and pa.alive ~= false then
                    local pb = pa:getOuterBounds()
                    local down = pa.prevY and math.max(0, pa.y - pa.prevY) or 0
                    if overlap(pb, box) and ((pa.vy or 0) > 0 or down > 0) and pb.y + pb.h <= box.y + 18 then
                        if d.on == 0 then
                            Sound.play('switchOn', 1)
                            Sound.play('megaClack', 0.7, 0.7)
                            Entity.emitFx('king_sparkle', d.x, box.y)
                        end
                        d.on = DECK_T                                          -- (pisarlo otra vez: vuelve a empezar)
                        pa:bounce(-math.abs(ADV_JUMP_VEL) * Boss.BOUNCE)
                        break
                    end
                end
            end
        end
    end
    if live and self.decks[1].on > 0 and self.decks[2].on > 0 then self:bassDrop() end
end
-- Los DOS platos girando: los bafles sueltan el BAJÓN contra él
function GC:bassDrop()
    for _, d in ipairs(self.decks) do d.on = 0 end
    self.dropT = self.songT
    local zx0, zx1 = self:zoneBounds()
    for _, sx in ipairs({ zx0 + 0.9 * T, zx1 - 0.9 * T }) do Entity.emitFx('king_confetti_big', sx, self.floorY - 3 * T) end
    Sound.play('megaSlam', 1, 0.6)
    self:knockOut()
end

-- ── Golpes a los jugadores ───────────────────────────────────────────────────
-- Tocar su CUERPO (caparazón y patas) quita 1 y empuja; las PINZAS no hacen daño (el usuario: "es injusto, ningún Mega
-- funciona así"): la caja es solo el cuerpo (hitbox outerW) y no se agranda. Encima, no (es pisarlo o el trampolín)
function GC:touch(level)
    if self.graceT > 0 or self.state == 'stunned' then return end
    local b = self:getOuterBounds()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pb = pa:getOuterBounds()
            local onTop = pb.y + pb.h <= b.y + 14 and (pa.vy or 0) >= -50
            if not onTop and overlap(pb, b) and strike(pa, HIT_TOUCH, (pa.x >= self.x) and 1 or -1) then
                self.graceT = GRACE
            end
        end
    end
end

-- ── El trampolín de la espalda ───────────────────────────────────────────────
-- (aturdido no tiene: le reventó; le crece en 'regrow' y lanza otra vez cuando ya ha salido medio)
function GC:trampOut()
    if not self:isActive() then return false end
    if self.state == 'stunned' then return false end
    if self.state == 'regrow' then return (self.deadTimer or 0) >= REGROW_T * 0.6 end
    return true
end
function GC:trampBox()
    local b = self:getOuterBounds()
    local w = 14 * MS
    return { x = self.x - w / 2, y = b.y - 9 * MS, w = w, h = 9 * MS + 8 }
end

-- (sin efectos: el cliente online lo usa para predecir)
function GC:interact(pa)
    if not self:isActive() then return nil end
    if self:trampOut() and (pa.vy or 0) > 0 then
        local tb, pob = self:trampBox(), pa:getOuterBounds()
        if overlap(pob, tb) and pob.y + pob.h <= tb.y + tb.h then
            return 'launch', 0, -math.abs(ADV_JUMP_VEL) * LAUNCH
        end
    end
    return Boss.interact(self, pa)
end
function GC:onLaunch(pa)
    Sound.play('trampoline', 0.9, 0.8)
    self.boingAt = love and love.timer and love.timer.getTime() or 0      -- (solo el dibujo: el muelle se mece)
end

-- ── Notas (y la dorada) ───────────────────────────────────────────────────────
-- (de la punta de la pinza grande, que va por delante). c: 0-3 = colores · 4 = dorada · 5 = dorada devuelta
function GC:clawTip()
    local f = self.facing or 1
    return self.x + f * 15 * MS, self:feetY() - 9 * MS
end
function GC:shoot(level, gold, kind)
    local pa = self:nearestPlayer(level)
    if not pa then return end
    local x, y = self:clawTip()
    local dx, dy = pa.x - x, (pa.y - 6 - (gold and GOLD_UP or 0)) - y
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    local spd = gold and GOLD_SPD or NOTE_SPD[self.rage and 2 or 1]
    local function add(vx, vy, extra)
        self.noteId = self.noteId % 999 + 1
        local n = { id = self.noteId, x = x, y = y, vx = vx, vy = vy, t = 0, c = gold and 4 or self.noteId % 4 }
        for key, v in pairs(extra or {}) do n[key] = v end
        self.notes[#self.notes + 1] = n
    end
    kind = (not gold) and kind or 'aim'
    if kind == 'fan' then
        local a = math.atan2(dy, dx)
        for _, da in ipairs({ -FAN_A, 0, FAN_A }) do add(math.cos(a + da) * spd, math.sin(a + da) * spd) end
    elseif kind == 'lob' then
        -- (en arco: sube y cae donde estás —a tus pies— en LOB_T s)
        local fy = pa.y + 20
        add(dx / LOB_T, ((fy - y) - 0.5 * LOB_G * LOB_T * LOB_T) / LOB_T, { g = LOB_G })
    else
        add(dx / d * spd, dy / d * spd)
    end
    if gold then
        Sound.play('megaClack', 0.9, 0.9)
        Sound.play('checkpoint', 0.5, 1.4)
    else Sound.play('megaClack', 0.8, 1.25) end
end
function GC:goldAlive()
    for _, n in ipairs(self.notes) do if n.c >= 4 then return true end end
    return false
end
function GC:noteBox(n)
    local r = (n.c >= 4) and GOLD_R or NOTE_R
    return { x = n.x - r, y = n.y - r, w = 2 * r, h = 2 * r }
end
function GC:updateNotes(level, dt)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    for i = #self.notes, 1, -1 do
        local n = self.notes[i]
        n.t = n.t + dt
        if n.c == 5 then                                                -- (devuelta: va derecha a su trampolín)
            local tx, ty = self.x, self:feetY() - 11 * MS
            local dx, dy = tx - n.x, ty - n.y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            n.vx, n.vy = dx / d * GOLD_BACK, dy / d * GOLD_BACK
        end
        if n.g then n.vy = n.vy + n.g * dt end                           -- (en arco)
        n.x, n.y = n.x + n.vx * dt, n.y + n.vy * dt
        local gone = n.t >= ((n.c >= 4) and GOLD_LIFE or NOTE_LIFE) or n.x < zx0 - T or n.x > zx1 + T
                     or n.y < zy0 - 3 * T or n.y > zy1 + T
        if n.g and n.y >= self.floorY - NOTE_R and n.vy > 0 then          -- (la del arco, al caer al suelo: revienta)
            gone = true
            Entity.emitFx('king_sparkle', n.x, self.floorY - NOTE_R)
        end
        if not gone then
            local box = self:noteBox(n)
            if n.c == 5 then
                local b = self:getOuterBounds()
                local hit = { x = b.x - 20, y = b.y - 9 * MS, w = b.w + 40, h = b.h + 9 * MS }
                if overlap(hit, box) then
                    gone = true
                    self:goldHit()
                end
            else
                for _, pa in ipairs(level.players or {}) do
                    if not pa.dying and pa.alive ~= false and overlap(pa:getOuterBounds(), box) then
                        if n.c == 4 then                                -- (¡la dorada! tocarla la devuelve)
                            n.c, n.t = 5, 0
                            Sound.play('helmetBounce', 0.9, 1.3)
                            Entity.emitFx('king_sparkle', n.x, n.y)
                            break
                        elseif strike(pa, HIT_NOTE, n.vx >= 0 and 1 or -1) then gone = true end
                    end
                end
            end
        end
        if gone then table.remove(self.notes, i) end
    end
end

-- La dorada le da: le REVIENTA el trampolín y queda NOQUEADO
function GC:goldHit() self:knockOut() end
-- NOQUEADO (la dorada o el bajón): sin trampolín, le vuelan las gafas; 2 compases vulnerable
function GC:knockOut()
    if not self:isActive() or self.state == 'stunned' or self.state == 'regrow' then return end
    if self.hop then                                                    -- (en el aire: cae donde está)
        self.hop = nil
        self.y = self.floorY - self.outerH / 2
    end
    local b = self:getOuterBounds()
    Entity.emitFx('groove_tramp', self.x, b.y - 4 * MS)
    Entity.emitFx('king_confetti_big', self.x, b.y - 6 * MS)
    Entity.emitFx('shake_big', self.x, self.y)
    Sound.play('bossExplode', 0.9)
    Sound.play('stunned')
    self.stunHits = 0
    self:enter('stunned')
end

-- ── Estados que sabe hacer el cuerpo ─────────────────────────────────────────
function GC:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GC:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function GC:isVulnerable() return self:isActive() and self.state == 'stunned' and (self.stunHits or 0) < STUN_HITS end
function GC:releasesZone() return self.state == 'dying_burst' or self.state == 'dead' end
function GC:shardDrop() return false end                                -- (jefe secreto: no guarda fragmento)
function GC:isSolidBody() return Boss.isSolidBody(self) and not DEATH[self.state] end
function GC:canBeKnocked() return false end

-- Un golpe aturdido (hasta STUN_HITS por aturdimiento; con el último, se recompone y le crece el trampolín)
-- A media vida (`rageAt`), la 2ª FASE: enfadado, sin doradas (las que queden, fuera) y salen los platos
function GC:onDamaged(n, kind)
    if self:isDying() then return end
    self:mood(BOO)                                                      -- (el público, triste: le abuchea a quien le pega)
    Entity.emitFx('shake_big', self.x, self.y)                          -- (cada golpe tiembla la pantalla: el usuario, 0.5.51)
    self.stunHits = (self.stunHits or 0) + 1
    if self.phase ~= 2 and self.hp <= self.hpMax * (self.props.rageAt or 0.5) then
        self.phase, self.rage, self.p2T = 2, true, self.songT
        for i = #self.notes, 1, -1 do if self.notes[i].c >= 4 then table.remove(self.notes, i) end end
        Entity.emitFx('shake_roar', self.x, self.y)
        Sound.play('megaRoar', 0.6)
    end
    if self.stunHits >= STUN_HITS then self:enter('regrow'); Sound.play('trampoline', 0.8, 0.5) end
end

function GC:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.waves, self.notes, self.hop = {}, {}, nil
    if self.decks then for _, d in ipairs(self.decks) do d.on = 0 end end
    self.y = self.floorY - self.outerH / 2
    self:enter('dying_daze')
    self.blastT = 0
    Sound.play('megaHurt', 0.9)
    Sound.play('stunned')
    self:mood(BOO)
    self:onDefeat()
end

-- El público reacciona (con su sonido; no repite la misma reacción seguida)
function GC:mood(kind)
    local now = self.songT or 0
    if self.moodKind == kind and now - (self.moodAt or -99) < 0.6 then return end
    self.moodKind, self.moodAt = kind, now
    Sound.play(kind == CHEER and 'crowdCheer' or 'crowdBoo', 0.95 + math.random() * 0.1)
end
-- → kind (CHEER / BOO / nil) y s desde que empezó (vencido: abuchea hasta el final)
function GC:crowdMood()
    if self:isDying() then return BOO, 0 end
    if not self.moodKind or self.moodKind == 0 then return nil end
    local age = (self.songT or 0) - (self.moodAt or -99)
    if age < 0 or age > MOOD_T then return nil end
    return self.moodKind, age
end
-- ¿Le dio a un jugador (o cayó)? → vítores. (Por su vida: lo mismo le dé lo que le dé)
function GC:watchPlayers(level)
    self._php = self._php or setmetatable({}, { __mode = 'k' })
    for _, pa in ipairs(level.players or {}) do
        local h = (pa.dying or pa.alive == false) and -1 or (pa.hp or 0)
        local prev = self._php[pa]
        if prev and h < prev then self:mood(CHEER) end
        self._php[pa] = h
    end
end

-- REVIENTA: explosión grande, pedazos, su trampolín hecho trizas y confeti; el escenario se recoge
function GC:burst()
    local b = self:getOuterBounds()
    self:enter('dying_burst')
    Entity.emitFx('boss_big_blast', self.x, self.y)
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2
        Entity.emitFx('enemy_burst', self.x + math.cos(a) * b.w * 0.4, self.y + math.sin(a) * b.h * 0.4)
    end
    Entity.emitFx('groove_tramp', self.x, b.y - 4 * MS)
    Entity.emitFx('king_confetti_big', self.x, b.y)
    Entity.emitFx('shake_big', self.x, self.y)
    Sound.play('bossExplode', 1.0)
    Sound.play('enemyExplode', 0.8)
    Sound.play('megaSlam', 0.9, 0.7)
    Sound.play('crowdBoo', 0.9)
end

-- ── Update ────────────────────────────────────────────────────────────────────
function GC:faceTo(x) if math.abs(x - self.x) > 8 then self.facing = (x > self.x) and 1 or -1 end end
function GC:set(st) if self.state ~= st then self:enter(st) end end

-- BAILA ANDANDO: un pasito en la 2ª mitad de cada tiempo hacia un lado del escenario (cambia cada 2 compases),
-- mirándote (de espaldas, a lo moonwalk, cuando se aleja); nunca hacia un jugador que tenga cerca
function GC:danceWalk(b, dt, pa, x0, x1)
    local dir = (math.floor(b / 2) % 2 == 0) and -1 or 1
    if (dir < 0 and self.x <= x0) or (dir > 0 and self.x >= x1) then return end
    if pa and (pa.x - self.x) * dir > 0 and math.abs(pa.x - self.x) < DANCE_KEEP then return end
    local u = ((self.songT or 0) % BEAT) / BEAT
    if u < 0.5 then return end
    self.x = math.max(x0, math.min(x1, self.x + dir * DANCE_STEP / (BEAT / 2) * dt))
end

function GC:aimMark(level)
    local zx0, zx1 = self:zoneBounds()
    local hw = self.outerW / 2 + 8
    local pa = self:nearestPlayer(level)
    local x = pa and pa.x or self.x
    self.markX = math.floor(math.max(zx0 + hw, math.min(zx1 - hw, x)))
end

function GC:land(lick)
    self.x, self.y = self.hop.x1, self.floorY - self.outerH / 2
    self.hop = nil
    Entity.emitFx('gp_land', self.x, self.floorY)
    if lick then
        Sound.play('megaStep', 0.8)
        Entity.emitFx('shake_small', self.x, self.y)
    else
        BossWaves.spawn(self, self.floorY, self.outerW / 2)
        Sound.play('megaSlam', 0.7)
        Sound.play('gpImpact', 0.6)
        Entity.emitFx('shake_big', self.x, self.y)
    end
    self:set('groove')
end

function GC:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    if self.decks == nil then self.decks = self:findDecks(level) end
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    BossWaves.update(self, level, dt, WAVES)
    self:updateNotes(level, dt)
    local st, t = self.state, self.deadTimer

    if st == 'dying_daze' then
        -- explosioncitas por el cuerpo, cada vez más seguidas, y REVIENTA
        self.blastT = (self.blastT or 0) - dt
        if self.blastT <= 0 then
            self.blastT = math.max(0.1, 0.38 - t * 0.16)
            local b = self:getOuterBounds()
            Entity.emitFx('boss_blast', self.x + (math.random() - 0.5) * b.w, self.y + (math.random() - 0.5) * b.h)
            Sound.play('bossExplode', 0.8 + t * 0.25, 0.55)
        end
        if t >= DAZE_T then self:burst() end
        return
    elseif st == 'dying_burst' then
        if t >= STAGE_OUT then self.state, self.alive = 'dead', false end
        return
    end
    self.prevT, self.songT = self.songT, self.songT + dt
    local b, sec, k, step = GC.where(self.songT)
    local pb, _, _, pstep = GC.where(math.max(0, self.prevT))
    -- (¿acaba de pasar la semicorchea s? la 0 es el cambio de compás)
    local crossed = function(s) if s == 0 then return pb ~= b end; return pb == b and pstep < s and step >= s end
    local plan = GC.plan(sec, k, self.rage, self:goldOff())

    -- El escenario va a lo suyo (también con él aturdido): la pista de baile y los platos
    self:updateFloor(level)
    self:watchPlayers(level)
    self:updatePlatforms(level)
    self:updateDecks(level, dt)

    -- En el aire: el salto sigue hasta caer en su compás
    if self.hop then
        local u = (self.songT - self.hop.t0) / HOP_DUR
        if u >= 1 then self:land(self.hop.lick)
        else
            self.x = self.hop.x0 + (self.hop.x1 - self.hop.x0) * u
            self.y = self.floorY - self.outerH / 2 - self.hop.h * 4 * u * (1 - u)
            self:set('hop')
            self:touch(level)
            return
        end
    end

    -- ATURDIDO (le reventó el trampolín) y luego le CRECE otro
    if self.state == 'stunned' then
        if t >= STUN_T then self:enter('regrow'); Sound.play('trampoline', 0.8, 0.5) end
        return
    elseif self.state == 'regrow' then
        if t < REGROW_T then return end
        Sound.play('trampoline', 0.9, 1.0)
        self:set('groove')
    end

    -- La NOTA DORADA, en el golpe de banda que cierra la frase (una a la vez; solo en la 1ª fase)
    local g = not self:goldOff() and GC.goldAt(sec, k) or nil
    if g and crossed(g) and not self:goldAlive() then self:shoot(level, true) end

    -- El SALTO: agachado (la diana te sigue hasta la semicorchea 6), salta en la 8
    if plan.hop or plan.lick then
        if step < 8 then
            if self.state ~= 'crouch' then Sound.play('megaWindup', plan.lick and 0.3 or 0.5) end
            if step < CROUCH_LOCK then self:aimMark(level) end
            self:faceTo(self.markX)
            self:set('crouch')
            self:touch(level)
            return
        end
        -- (sin al menos MIN_WARN s agachado —venía de aturdido— no salta: la diana tiene que verse)
        if crossed(8) and self.state == 'crouch' and self.deadTimer >= MIN_WARN then
            self.hop = { t0 = b * BAR + 8 * S16, x0 = self.x, x1 = self.markX, h = plan.lick and LICK_H or HOP_H,
                         lick = plan.lick == true }
            Sound.play('trampoline', 0.7, plan.lick and 0.9 or 0.7)
            self:set('hop')
            return
        end
    end

    -- Las NOTAS, en los pops del bajo; entre una y otra se acerca andando
    local last = plan.notes[#plan.notes]
    for _, s in ipairs(plan.notes) do if crossed(s) then self:shoot(level, false, GC.noteKind(sec, k, self.rage)) end end
    local pa = self:nearestPlayer(level)
    if pa then self:faceTo(pa.x) end
    if (last and step < last + 2) or (g and step >= g and step < g + 2) then
        self:set('snap')
    else
        self:set('groove')
        local zx0, zx1 = self:zoneBounds()
        local hw = self.outerW / 2 + 8
        if pa and (sec == 'B' or sec == 'C') and math.abs(pa.x - self.x) > 2.5 * T then
            self.x = math.max(zx0 + hw, math.min(zx1 - hw, self.x + self.facing * WALK_SPD * dt))
        else
            self:danceWalk(b, dt, pa, zx0 + hw + T, zx1 - hw - T)
        end
    end
    self:touch(level)
end

-- ── Entrada: cae del cielo, chasquea dos veces y rebota en su trampolín ──
local FALL_AT, LAND_AT, SNAP1, SNAP2, BOING = 0.3, 1.0, 1.7, 2.1, 2.8
GC.LAND_AT = LAND_AT
P.LAND_AT, P.SNAP1, P.SNAP2, P.BOING = LAND_AT, SNAP1, SNAP2, BOING
function GC:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GC:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GC:updateIntro(dt, level, t)
    local hy = self.floorY - self.outerH / 2
    local _, _, zy0 = self:zoneBounds()
    self.x = self.home.x
    if t < LAND_AT then
        local y0 = zy0 - 3 * self.outerH
        local u = math.max(0, (t - FALL_AT) / (LAND_AT - FALL_AT))
        self.y = (t < FALL_AT) and y0 or (y0 + (hy - y0) * u * u)
        return
    end
    self.y = hy
    if self.introStep < 1 then
        self.introStep = 1
        Sound.play('megaSlam', 0.7)
        Entity.emitFx('gp_land', self.x, self.floorY)
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= SNAP1 and self.introStep < 2 then self.introStep = 2; Sound.play('megaClack', 0.8, 1.2) end
    if t >= SNAP2 and self.introStep < 3 then self.introStep = 3; Sound.play('megaClack', 0.8, 1.35) end
    if t >= BOING and self.introStep < 4 then self.introStep = 4; Sound.play('trampoline', 0.8, 0.7) end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { songT·100, enfadado 0/1, diana x, golpes aturdido, fase, bajón songT·100 (-1), 2ª fase songT·100 (-1), ánimo del
--   público (0/1/2), su songT·100 (-1), nOndas, {ondas…}, nNotas, {id, x, y, vx, vy, color}…, nPlatos, {x, y, girando s·10}… }
local NOTE_STRIDE, DECK_STRIDE = 6, 3
local HEAD = 10                                 -- (donde empiezan las ondas)
local function readList(b, k, stride)
    local n = type(b[k]) == 'number' and b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, stride do e[j] = b[k + 1 + i * stride + j - 1] end
        list[#list + 1] = e
    end
    return list, k + 1 + n * stride
end

function GC:netPackExtra()
    local out = { math.floor(self.songT * 100), self.rage and 1 or 0, self.markX or 0, self.stunHits or 0, self.phase or 1,
                  self.dropT and math.floor(self.dropT * 100) or -1, self.p2T and math.floor(self.p2T * 100) or -1,
                  self.moodKind or 0, self.moodAt and math.floor(self.moodAt * 100) or -1 }
    BossWaves.pack(self.waves, out)
    out[#out + 1] = #self.notes
    for _, n in ipairs(self.notes) do
        out[#out + 1] = n.id; out[#out + 1] = math.floor(n.x); out[#out + 1] = math.floor(n.y)
        out[#out + 1] = math.floor(n.vx); out[#out + 1] = math.floor(n.vy); out[#out + 1] = n.c
    end
    local decks = self.decks or {}
    out[#out + 1] = #decks
    for _, d in ipairs(decks) do
        out[#out + 1] = math.floor(d.x); out[#out + 1] = math.floor(d.y); out[#out + 1] = math.ceil(d.on * 10)
    end
    return out
end

function GC:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    local s0 = type(a[1]) == 'number' and a[1] or b[1]
    self.songT = (s0 + (b[1] - s0) * f) / 100
    self.rage, self.markX, self.stunHits, self.phase = b[2] == 1, b[3], b[4] or 0, b[5] or 1
    self.dropT = (type(b[6]) == 'number' and b[6] >= 0) and b[6] / 100 or nil
    self.p2T = (type(b[7]) == 'number' and b[7] >= 0) and b[7] / 100 or nil
    self.moodKind = b[8] or 0
    self.moodAt = (type(b[9]) == 'number' and b[9] >= 0) and b[9] / 100 or nil
    local waves, k = BossWaves.unpack(a, b, HEAD, f)
    self.waves = waves
    local prev = {}
    if type(a[1]) == 'number' then
        local _, ka = BossWaves.unpack(a, a, HEAD, 1)
        for _, e in ipairs((readList(a, ka, NOTE_STRIDE))) do if e[1] then prev[e[1]] = e end end
    end
    local notes, kc = readList(b, k, NOTE_STRIDE)
    self.notes = {}
    for _, e in ipairs(notes) do
        local x, y = e[2], e[3]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(x) == 'number' then x, y = o[2] + (x - o[2]) * f, o[3] + (y - o[3]) * f end
        self.notes[#self.notes + 1] = { id = e[1], x = x, y = y, vx = e[4], vy = e[5], c = e[6] or 0, t = 0 }
    end
    local decks = readList(b, kc, DECK_STRIDE)
    if #decks > 0 then
        self.decks = {}
        for _, e in ipairs(decks) do self.decks[#self.decks + 1] = { x = e[1], y = e[2], on = (e[3] or 0) / 10 } end
    end
end

-- El dibujo: groovecrab_stage.lua
require('src/world/entities/types/bosses/groovecrab_stage')(GC, P)

local G = 'Cangrejo Groove'
return {
    name = 'groovecrab', label = 'Cangrejo Groove', category = 'Jefes',
    description = 'Jefe SECRETO: un Crabby trampolín gigante que pelea al ritmo de su tema (salta y cae en el bombo, '
               .. 'notas en los pops del bajo, pista de baile). 1ª fase: devuélvele la NOTA DORADA; 2ª fase: sube con '
               .. 'su trampolín a las plataformas y pon a girar los DOS platos de DJ a la vez. Las dos cosas le '
               .. 'revientan el trampolín y lo dejan noqueado.',
    class = GC,
    pace = false,                                -- (va al compás de su música: la dificultad no le cambia el ritmo)
    boss = { title = 'CANGREJO GROOVE' },
    hide = Boss.HIDE,
    defaults = { points = 40 },
    props = Boss.props({ hp = 11, hpPerPlayer = 4 }, {
        { key = 'rageAt', kind = 'number', label = '2ª fase con (fracción de vida)', group = G, default = 0.5,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = 'assets/images/bosses/groovecrab/body-Sheet.png', frameW = FW },
}
