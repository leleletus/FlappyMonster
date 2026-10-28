-- MEGA MASHUP DE LOS CANGREJOS — el DIRECTOR del evento (docs/bosses/crab-mashup.md). Invisible; uno por nivel de
-- evento (assets/levels/mashup_cangrejos.json). Lleva a los cuatro cangrejos gigantes por turnos, cada uno en SU
-- arena (zonas de jefe `event`: las lleva él, no BossZones) y con SU música, que es ADAPTATIVA: piezas de
-- tools/music/crab_mashup.py PIECES=1 (assets/music/bosses/crab_mashup/cues.json: compases, tempo, cortes cada 4
-- compases y qué sigue).
--
--   intro (8 compases, en el ESCENARIO del final: los cuatro al fondo, un foco por compás; en el 5º, a la arena del
--   Tantrum y su entrada — el usuario, 0.5.62: "así queda mejor" —) → TANTRUM ⟲ → costura → ICY ⟲ → costura → GLOOMY ⟲ →
--   costura → GROOVE ⟲ → costura → FINAL ⟲ (por relevos, al azar, enfadados) → FIN (explosiones en cadena) → SALIDA ⟲
--
-- · Cada cangrejo pasa de turno al recibir su daño del turno (props.hp = 2, +1 por jugador extra: Boss). Al llegar a 0
--   no muere: queda CONGELADO aturdido (Boss: eventFrozen) y el director pide el CORTE siguiente de la música; en el
--   corte suena la costura: fundido a negro, los jugadores pasan a la arena siguiente (su escena: Level:applyScene),
--   el siguiente hace su entrada (jugadores congelados: la zona en 'intro') y la pelea empieza en el primer compás
--   de su bucle.
-- · EL FINAL (escenario grande: lo pinta el Groove del final, `bigStage`): pelea UNO, enfadado; los que esperan su
--   turno están AL FONDO (Boss: offstage 'wait') y cada uno lanza su peligro al compás (Tantrum: Crabbies del techo ·
--   Icy: carámbanos en las notas de la caja de música · Gloomy: un apagón · Groove: notas en los pops del slap); los
--   vencidos, al fondo noqueados ('ko') sin hacer nada. La música cambia de variante (el que pelea, delante) en el
--   corte, sin perder el compás.
-- · EL FIN: cada cangrejo revienta en un golpe de la subida de la coda y el último en el acorde; luego el escenario
--   vacío con la SALIDA, los resultados en la pantalla del escenario y la meta abierta.
-- · Puntos de control: perder todas las vidas → se vuelve a empezar en el cangrejo en que estabas (el final, entero):
--   AdventureState pasa `eventCheckpoint` al nivel.
--
-- Corre en un jugador y en el servidor (updateCustom); el cliente lo recibe todo en netPack (fase, pieza y punto de la
-- música, a quién le toca, quién está al fondo, peligros, estadísticas) y la música la sigue Sound.followAdaptive.
local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'

local CM = Entity.extend(Entity, { debugColor = { 1, 0.5, 0.9 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

local T = TILE_PX
CM.wantsLevel = true                        -- (BossZones.link le da levelRef: también en el cliente)
CM.CUES   = 'assets/music/bosses/crab_mashup/cues.json'
CM.ROLES  = { 'tantrum', 'icy', 'gloomy', 'groove' }
local LOOP = { tantrum = 'tantrum', icy = 'icy', gloomy = 'gloomy', groove = 'groove' }
local SEAM = { tantrum = 'seam_icy', icy = 'seam_gloomy', gloomy = 'seam_groove', groove = 'seam_final' }
local PHASES = { 'wait', 'intro', 'crab', 'seam', 'final', 'end', 'outro' }
local PCODE = {}
for i, p in ipairs(PHASES) do PCODE[p] = i end
local PIECE_IDS = { 'intro', 'tantrum', 'seam_icy', 'icy', 'seam_gloomy', 'gloomy', 'seam_groove', 'groove',
                    'seam_final', 'final_tantrum', 'final_icy', 'final_gloomy', 'final_groove', 'end', 'outro' }
local PIDX = {}
for i, p in ipairs(PIECE_IDS) do PIDX[p] = i end
local RIDX = { tantrum = 1, icy = 2, gloomy = 3, groove = 4 }

-- Los que ESPERAN su turno en el final andan por el ESCENARIO (0.5.64, el usuario: "flotando chiquitos en el centro
-- no queda bien"): a su tamaño, más oscuros, sin hacer daño al tocarlos, con sus animaciones y sonidos; tiran su peligro
-- con un gesto (throw: uno de sus estados, `kind` = su emote). Cada uno con uno de sus propios estados
local LOOK = {
    megacrabby      = { wait = 'chase',  throw = 'rest', kind = 1, sound = 'megaRoar',  ko = 'stuck' },
    megacrabby_ice  = { wait = 'chase',  throw = 'rest', kind = 2, sound = 'megaClack', ko = 'clap_stuck' },
    megagloomy      = { wait = 'prowl',  throw = 'shriek', ko = 'dazzled' },
    groovecrab      = { wait = 'groove', throw = 'snap',   ko = 'stunned' },
}
local FADE_OUT, TELEPORT_AT, FADE_IN = 0.45, 0.5, 0.55          -- s de la costura: a negro, cambio, vuelve
local WANDER = 75                                                 -- px/s paseando por el escenario
local DIM = { wait = { 0.55, 0.55, 0.66 }, ko = { 0.45, 0.42, 0.52 } }   -- (más oscuros que el que pelea)
CM.ICICLE_WARN, CM.ICICLE_FALL = 0.55, 900                        -- s de aviso, px/s
CM.NOTE_SPEED = 300
CM.BLACKOUT = { 0.3, 0.8, 0.45 }                                  -- s: se apaga, apagado, vuelve

-- ── El mapa de la música (lo leen el director y Sound) ───────────────────────────
local cues
function CM.cues()
    if cues == nil then
        local json = require 'libs/json'
        local ok, m = pcall(json.decode, love.filesystem.read(CM.CUES) or '')
        cues = (ok and type(m) == 'table' and type(m.pieces) == 'table') and m or false
        if not cues then print('[crabmashup] no se pudo leer ' .. CM.CUES) end
    end
    return cues or nil
end
local function piece(pid) local c = CM.cues(); return c and pid and c.pieces[pid] or nil end
-- Compás (1…) y semicorchea (con decimales) en el punto `t` de la pieza
local function barAt(pc, t)
    local bars = pc.bars
    local i = 1
    while i < #bars and bars[i + 1][1] <= t do i = i + 1 end
    local s16 = 60 / bars[i][2] / 4
    return i, (t - bars[i][1]) / s16
end
CM.barAt = barAt
-- El primer corte de una pieza en bucle después de `t` (con un margen: que dé tiempo a oírse)
local function nextCut(pc, t)
    for _, c in ipairs(pc.cuts or {}) do if c > t + 0.05 then return c end end
    return pc.music_end
end

function CM.loadAssets() end
function CM.sizePx() return TILE_PX, TILE_PX end

function CM:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
    self.phase = 'wait'
    self.piece, self.pos, self.lap = nil, 0, 0
    self.fade = 0
    self.ci = 0                                -- (parte principal: cangrejo 1..4)
    self.active = nil                          -- (final: el rol que pelea)
    self.ko = {}                               -- (final: rol → true, vencido)
    self.notes, self.icicles, self.noteId = {}, {}, 0
    self.blackT = nil
    self.stats = {}                            -- [idx] = { dmg, deaths, hits }
    self.t = 0
end

function CM:canBeStomped() return false end
function CM:canBeKnocked() return false end
function CM:isBodyDisabled() return true end
function CM:isObstacle() return false end
function CM:isGhost() return true end
function CM:collect() return false end
function CM:interact() return nil end

-- ── Preparación (la primera vez que ve el nivel; también en el cliente) ──────────
function CM:setup(level)
    if self.level == level then return end
    self.level = level
    level.musicDirector = self
    local zones = {}
    for _, z in ipairs(level.bossZones or {}) do if z.event then zones[#zones + 1] = z end end
    table.sort(zones, function(a, b) return a.col < b.col end)
    self.zones = zones                          -- 1..4 las arenas, 5 el escenario del final
    self.main, self.fin = {}, {}
    for i, z in ipairs(zones) do
        z.barOf = self
        for _, b in ipairs(z.bosses or {}) do
            local role = b.props and b.props.mashupRole
            if role then
                b.eventRef = self
                if i <= 4 then self.main[role] = b else self.fin[role] = b end
            end
        end
    end
    self.finalZone = zones[5]
    -- (en sus entradas — la intro y la del final — la cámara mira al centro del escenario: BossZones.cameraTarget)
    if self.finalZone then self.finalZone.focus = { (self.finalZone.x0 + self.finalZone.x1) / 2, self.finalZone.y1 - WINDOW_H * 0.45 } end
    -- (se empieza en el escenario: su escena desde el primer fotograma, sin esperar a la intro)
    if self.phase == 'wait' and self.finalZone then level:applyScene(self:sceneOf(self.finalZone)) end
end

function CM:sceneOf(z) return require('src/world/level/Scenes').at(self.level, z.col) end

-- ── El RELOJ de la música ────────────────────────────────────────────────────────
function CM:startPiece(pid, pos)
    local old = self.piece
    self.piece, self.pos, self.pend, self.lap = pid, pos or 0, nil, 0
    self:onPiece(pid, old)
end

function CM:advance(dt)
    local pc = piece(self.piece)
    if not pc then return end
    self.pos = self.pos + dt
    if self.pend and self.pos >= self.pend.at then
        local nx, over = self.pend, self.pos - self.pend.at
        return self:startPiece(nx.piece, (nx.pos or 0) + over)
    end
    if pc.loop then
        if self.pos >= pc.music_end then self.pos = self.pos - pc.music_end; self.lap = self.lap + 1 end
    elseif self.pos >= pc.length and pc.next then
        return self:startPiece(pc.next, self.pos - pc.length)
    end
end

-- (un jugador: el audio manda — AdventureState le pasa el punto que suena; sin cruzar el corte pedido ni la vuelta)
function CM:syncAudio(t)
    if self.pend and t >= self.pend.at then return end
    if t < self.pos - 0.25 then return end                        -- (el audio dio la vuelta antes: lo hará el reloj)
    self.pos = t
end

-- Para Sound.followAdaptive: mapa, pieza, punto, próximo cambio
function CM:musicState()
    local pc = piece(self.piece)
    if not pc then return nil end
    local nxt = self.pend
    if not nxt and not pc.loop and pc.next then nxt = { piece = pc.next, at = pc.length, pos = 0 } end
    return CM.CUES, self.piece, self.pos, nxt
end

-- Compás y semicorchea AHORA (+ `off` s), traducidos a las secciones del tema del Groove (GC:whereAt)
function CM:grooveWhere(off)
    local pc = piece(self.piece)
    if not pc then return 0, 'I', 1, 0 end
    local t, lap, len = self.pos + (off or 0), self.lap, pc.music_end
    if pc.loop then
        while t < 0 do t, lap = t + len, lap - 1 end
        while t >= len do t, lap = t - len, lap + 1 end
    end
    t = math.max(0, t)
    local bi, step = barAt(pc, t)
    local sec, k
    if self.piece == 'groove' then
        -- (su bucle: solo 8 · riff A 16 · B 16 · clímax 16 · vuelta 4)
        if bi <= 8 then sec, k = 'K', bi elseif bi <= 24 then sec, k = 'A', bi - 8 elseif bi <= 40 then sec, k = 'B', bi - 24
        elseif bi <= 56 then sec, k = 'C', bi - 40 else sec, k = 'O', bi - 56 end
    else
        sec, k = 'C', bi                                            -- (el final: como su clímax)
    end
    return 8 + math.max(0, lap) * #pc.bars + bi - 1, sec, k, step
end

-- Tiempo (negras) y su fracción: para lo que baila al compás (el público, los bafles)
function CM:beatPos()
    local pc = piece(self.piece)
    if not pc then return 0, 0 end
    local bi, step = barAt(pc, math.max(0, self.pos))
    local nb = (self.lap * #pc.bars + bi - 1) * 4 + math.floor(step / 4)
    return nb, (step % 4) / 4
end

-- ── La barra compartida (BossHud: z.barOf) ─────────────────────────────────────
-- Toda la vida que queda del evento: la parte principal (los que faltan) o el final; el nombre, el que pelea
function CM:barTotals()
    local list = (self.phase == 'final' or self.phase == 'end' or self.phase == 'outro'
                  or (self.phase == 'seam' and self.piece == 'seam_final' and self.seamTo == 5)) and self.fin or self.main
    local hp, max = 0, 0
    for _, role in ipairs(CM.ROLES) do
        local b = list[role]
        if b then
            local need = self:need(b)
            max = max + need
            local mine = (b.hpMax and b.hpMax > 0 and b.state ~= 'dormant') and b.hp or need
            if b.eventFrozen or self.ko[role] and list == self.fin then mine = 0 end
            if list == self.main and self.doneMain and self.doneMain[role] then mine = 0 end
            hp = hp + math.max(0, mine)
        end
    end
    return hp, max
end
function CM:need(b)
    local p = b.props or {}
    return math.max(1, (p.hp or 4) + (p.hpPerPlayer or 2) * math.max(0, #(self.level and self.level.players or {}) - 1))
end
function CM:title()
    local b
    if self.phase == 'final' and self.active then b = self.fin[self.active]
    elseif self.ci >= 1 and self.ci <= 4 then b = self.main[CM.ROLES[self.ci]] end
    return b and b:title() or require('src/core/Lang')('mashup.title')
end

-- ── Simulación (un jugador y servidor) ───────────────────────────────────────────
function CM:updateCustom(dt, level)
    self:setup(level)
    self.t = self.t + dt
    self:watchPlayers(level)
    if self.phase == 'wait' then
        local z = self.finalZone                                    -- (se empieza en el escenario del final)
        if z and (z.needed or 0) > 0 and z.arrived == z.needed then self:begin(level) end
        return true
    end
    self:advance(dt)
    self:tick(dt, level)
    self.hp, self.hpMax = self:barTotals()
    return true
end

function CM:players()
    local out = {}
    for _, pa in ipairs(self.level.players or {}) do if pa.alive ~= false then out[#out + 1] = pa end end
    return out
end

-- Empieza: la intro (siluetas + la entrada del Tantrum) o, con punto de control, la costura hacia ese cangrejo
function CM:begin(level)
    local cp = math.floor(tonumber(level.eventCheckpoint) or 1)
    if cp >= 2 and cp <= 5 then
        self.doneMain = {}
        for i = 1, cp - 1 do if i <= 4 then self.doneMain[CM.ROLES[i]] = true; self.main[CM.ROLES[i]].eventFrozen = true end end
        self.ci = cp - 1
        return self:startPiece(SEAM[CM.ROLES[cp - 1]], 0)
    end
    self:startPiece('intro', 0)
end

function CM:onPiece(pid, old)
    local level = self.level
    if pid == 'intro' then
        -- en el ESCENARIO del final, los cuatro al fondo; los focos los van mostrando (renderBack)
        self.phase, self.ci, self.introMoved, self.seamT = 'intro', 0, false, nil
        local z = self.finalZone
        level:applyScene(self:sceneOf(z))
        z.state, z.cineKey = 'intro', 'mashup.title'
        for _, r in ipairs(CM.ROLES) do if self.fin[r] then self:toStage(self.fin[r], r) end end
    elseif LOOP[pid] then
        self:fightMain(RIDX[pid])
    elseif pid:sub(1, 5) == 'seam_' then
        self.phase, self.seamT, self.teleported = 'seam', 0, false
        self.seamTo = (pid == 'seam_final') and 5 or (self.ci + 1)
        if pid == 'seam_final' then
            -- (quién abre el final: al azar; la música de la costura sigue con SU variante)
            local roles = {}
            for _, r in ipairs(CM.ROLES) do roles[#roles + 1] = r end
            self.active = roles[math.random(#roles)]
            local pc = piece(pid)
            self.pend = { piece = 'final_' .. self.active, at = pc.length, pos = 0 }
        end
    elseif pid:sub(1, 6) == 'final_' then
        if old and old:sub(1, 6) == 'final_' then self:swap(pid:sub(7))
        else self:fightFinal() end
    elseif pid == 'end' then
        self.phase, self.boomN = 'end', 0
        self.notes, self.icicles = {}, {}
        level.dark, level.darkness = false, 0
    elseif pid == 'outro' then
        self.phase = 'outro'
        local z = self.finalZone
        if z then z.state = 'cleared' end                       -- (las paredes se abren: la meta)
    end
end

function CM:fightMain(i)
    local role = CM.ROLES[i]
    local z, b = self.zones[i], self.main[role]
    self.phase, self.ci = 'crab', i
    self.level.eventCheckpointNow = i
    if not z or not b then return end
    z.state, z.fought, z.cineKey = 'fight', true, nil
    if b.state ~= 'fight' then b:startFight(#self:players()) end
    for _, pa in ipairs(self:players()) do pa.spawnX, pa.spawnY = pa.x, pa.y end
end

function CM:fightFinal()
    local z = self.finalZone
    self.phase = 'final'
    self.level.eventCheckpointNow = 5
    if not z then return end
    z.state, z.fought, z.cineKey = 'fight', true, nil
    local b = self.fin[self.active]
    if b then b:startFight(#self:players()); b.started = true end
    for _, pa in ipairs(self:players()) do pa.spawnX, pa.spawnY = pa.x, pa.y end
    self.hazT = {}
end

-- Un cangrejo llegó a 0 (Boss:damage): aturdido hasta el próximo corte
function CM:crabDown(b)
    if b.eventFrozen then return end
    b.eventFrozen, b.inv, b.ghost = true, 0, false
    Entity.emitFx('shake_big', b.x, b.y)
    Sound.play('fanfare')
    local pc = piece(self.piece)
    if not pc then return end
    local cut = nextCut(pc, self.pos)
    if self.phase == 'crab' and b == self.main[CM.ROLES[self.ci]] then
        self.doneMain = self.doneMain or {}
        self.doneMain[CM.ROLES[self.ci]] = true
        self.pend = { piece = SEAM[CM.ROLES[self.ci]], at = cut, pos = 0 }
    elseif self.phase == 'final' and b == self.fin[self.active] then
        self.ko[self.active] = true
        local left = {}
        for _, r in ipairs(CM.ROLES) do if not self.ko[r] then left[#left + 1] = r end end
        if #left == 0 then
            self.pend = { piece = 'end', at = cut, pos = 0 }
        else
            local nx = left[math.random(#left)]
            self.pend = { piece = 'final_' .. nx, at = cut, pos = (cut >= pc.music_end - 1e-3) and 0 or cut }
        end
    end
end

-- Daño a un cangrejo: para el ranking (quién le dio)
function CM:onCrabHit(b, n, pa)
    if n <= 0 then return end
    local st = self:statOf(pa)
    if st then st.dmg = st.dmg + n end
end

function CM:statOf(pa)
    if not pa then return nil end
    local k = pa.ownerIdx or 1
    self.stats[k] = self.stats[k] or { dmg = 0, deaths = 0, hits = 0 }
    return self.stats[k]
end

-- Muertes y golpes recibidos de cada jugador (para los resultados)
function CM:watchPlayers(level)
    self._hp = self._hp or setmetatable({}, { __mode = 'k' })
    self._dy = self._dy or setmetatable({}, { __mode = 'k' })
    for _, pa in ipairs(level.players or {}) do
        local st = self:statOf(pa)
        if self.phase ~= 'wait' and self.phase ~= 'outro' then
            if pa.dying and not self._dy[pa] then st.deaths = st.deaths + 1 end
            if self._hp[pa] and pa.hp < self._hp[pa] and not pa.dying then st.hits = st.hits + 1 end
        end
        self._dy[pa], self._hp[pa] = pa.dying, pa.hp
    end
end

-- ── Cada paso, según la fase ─────────────────────────────────────────────────────
function CM:tick(dt, level)
    local players = self:players()
    if self.phase == 'intro' then
        -- compás 5 de la intro: fundido, a la arena del Tantrum y su entrada (como en una costura)
        local pc = piece('intro')
        if pc and self.pos >= pc.bars[5][1] then
            self.seamT = (self.seamT or 0) + dt
            local s = self.seamT
            self.fade = (s < FADE_OUT) and s / FADE_OUT or math.max(0, 1 - (s - TELEPORT_AT - 0.1) / FADE_IN)
            if not self.introMoved and s >= TELEPORT_AT then
                self.introMoved = true
                self:moveTo(1, players)
                self.ci = 1
            end
        end
    elseif self.phase == 'seam' then
        self.seamT = self.seamT + dt
        local s = self.seamT
        self.fade = (s < FADE_OUT) and s / FADE_OUT or math.max(0, 1 - (s - TELEPORT_AT - 0.1) / FADE_IN)
        if not self.teleported and s >= TELEPORT_AT then
            self.teleported = true
            self:moveTo(self.seamTo, players)
        end
    elseif self.phase == 'final' then
        self:tickFinal(dt, level, players)
    elseif self.phase == 'end' then
        self:tickEnd(level)
    end
    if self.phase ~= 'seam' and not (self.phase == 'intro' and self.seamT) then self.fade = math.max(0, self.fade - dt / FADE_IN) end
    level.screenFade = self.fade > 0 and self.fade or nil
    self:tickHazards(dt, level, players)
end

-- Llevar a los jugadores a la arena `i` (5 = el final) y que entre su cangrejo
function CM:moveTo(i, players)
    local level = self.level
    local from = (self.ci or 0) >= 1 and self.zones[self.ci] or self.finalZone
    if from and from ~= self.zones[i] then
        from.state = (from == self.finalZone) and 'idle' or 'cleared'   -- (el escenario sigue: el final será allí)
        from.cineKey = nil
    end
    local z = self.zones[i]
    if not z then return end
    level:applyScene(self:sceneOf(z))
    level.cameraCut = (level.cameraCut or 0) + 1                    -- (la cámara salta, no se desliza)
    local gx, gy = level:findGround(z.col + 2, z.col, z.col + z.w - 1, z.row, z.row + z.h - 1)
    gx, gy = gx or (z.x0 + 2 * T), gy or (z.y1 - T)
    for k, pa in ipairs(players) do
        pa.x, pa.y = gx + (k - 1) * T * 0.7, gy
        pa.vx, pa.vy = 0, 0
        pa.prevX, pa.prevY = pa.x, pa.y
        pa.spawnX, pa.spawnY = pa.x, pa.y
        pa.gpPhase = nil
    end
    z.state = 'intro'
    level.helpHint = true                                           -- (antes de lo difícil: la ayuda, si estás herido)
    if i <= 4 then
        local b = self.main[CM.ROLES[i]]
        if b then b.eventFrozen = false; b:startIntro(level, players, z) end
    else
        -- el FINAL: el que abre entra; los demás, al fondo esperando su turno
        for _, r in ipairs(CM.ROLES) do
            local b = self.fin[r]
            if b then
                if r == self.active then b.offstage = nil; b:startIntro(level, players, z)
                else self:toStage(b, r) end
            end
        end
    end
end

-- Su sitio en el ESCENARIO (de pie en el suelo, repartidos alrededor del centro)
function CM:slot(role)
    local z = self.finalZone
    return (z.x0 + z.x1) / 2 + (RIDX[role] - 2.5) * 5 * T
end
-- De pie en el suelo del escenario en x (cada tipo a su manera: su caja va distinta)
function CM:standAt(b, x)
    local z = self.finalZone
    b.x, b.vx, b.vy = x, 0, 0
    if b.stand and b.def.name == 'megagloomy' then b:stand(self.level, x)
    elseif b.floorY and b.def.name == 'groovecrab' then b.y = b.floorY - b.outerH / 2
    else b.y, b.onGround = z.y1 - b.outerH / 2, true end
end
-- Esperando su turno: a su sitio, de pie, andando por ahí (sin daño, sin pensar: lo lleva stageWalk)
function CM:toStage(b, role)
    b.offstage, b.eventFrozen, b.throwT = 'wait', false, nil
    b.inv, b.ghost, b.flipped = 0, false, false
    if b.crawl ~= nil then b.crawl = false end
    if b.ang then b.ang = 0 end
    self:standAt(b, self:slot(role))
    local L = LOOK[b.def.name]
    if L then b.state, b.deadTimer = L.wait, 0 end
    b.wanderDir = (RIDX[role] % 2 == 0) and 1 or -1
end
-- Vencido en el final: se queda NOQUEADO donde cayó (como estaba al congelarse), sin hacer nada hasta el fin
function CM:toKO(b)
    b.offstage, b.eventFrozen = 'ko', false
    b.inv, b.ghost = 0, false
    -- (en el suelo y en su pose de noqueado: si lo vencieron en el aire o en la pared, no se queda flotando)
    if b.crawl ~= nil then b.crawl = false end
    if b.ang then b.ang = 0 end
    b.hop = nil
    local L = LOOK[b.def.name]
    if L and L.ko and b.state ~= L.ko then b.state, b.deadTimer = L.ko, 0 end
    b.flipped = (b.state == 'stuck')
    self:standAt(b, math.max(self.finalZone.x0 + 2 * T, math.min(self.finalZone.x1 - 2 * T, b.x)))
end

-- Un paso de los que esperan: pasean de un lado a otro (dan la vuelta en los bordes y, a ratos, porque sí)
function CM:stageWalk(b, dt)
    local L = LOOK[b.def.name]
    if not L then return end
    b.deadTimer = (b.deadTimer or 0) + dt
    if b.throwT then                                              -- (el gesto de tirar su peligro)
        b.throwT = b.throwT - dt
        if b.throwT > 0 then return end
        b.throwT, b.state, b.deadTimer = nil, L.wait, 0
    end
    local z = self.finalZone
    local d = b.wanderDir or 1
    b.wanderT = (b.wanderT or (2 + math.random() * 3)) - dt
    if b.wanderT <= 0 then b.wanderT, d = 2.5 + math.random() * 3.5, -d end
    local nx = b.x + d * WANDER * dt
    if nx < z.x0 + 2 * T then nx, d = z.x0 + 2 * T, 1 elseif nx > z.x1 - 2 * T then nx, d = z.x1 - 2 * T, -1 end
    b.wanderDir = d
    local name = b.def.name
    if name == 'megagloomy' then
        b.face, b.dir = d, d
        b:stand(self.level, nx)
        b:walkAnim(dt)
    elseif name == 'groovecrab' then
        b.facing, b.x = d, nx
    else
        b.facing = d
        b:walk(self.level, dt, d * WANDER)
        b:animWalk(dt, (b.tuning and b.tuning.walkFps) or 8)
    end
end
-- El gesto al tirar su peligro (y su sonido)
function CM:throwAnim(b, dur)
    local L = b and LOOK[b.def.name]
    if not L or b.offstage ~= 'wait' then return end
    b.state, b.deadTimer, b.throwT = L.throw, 0, dur
    if L.kind then b.restKind = L.kind end
    if L.sound then Sound.play(L.sound, 1.1, 0.5) end
end

-- El relevo del final (en el corte): el vencido se queda noqueado donde cayó; el siguiente — que ya está en el
-- escenario — se pone a pelear (ruge, sin entrada desde el cielo)
function CM:swap(role)
    local level = self.level
    local old = self.active and self.fin[self.active]
    if old then self:toKO(old) end
    self.active = role
    local b = self.fin[role]
    if not b then return end
    b.offstage, b.eventFrozen, b.throwT = nil, false, nil
    self:standAt(b, b.x)
    b.started = true
    b.introPlayed = true                                          -- (los Mega: ya en escena, a perseguir directamente)
    b:startFight(#self:players())
    Entity.emitFx('shake_roar', b.x, b.y)
    Sound.play('megaRoar', 0.9)
    level.helpHint = true
    Sound.play('crowdCheer', 1.0)
end

function CM:tickFinal(dt, level, players)
    local b = self.active and self.fin[self.active]
    -- el que acaba de bajar: cuando termina su entrada, a pelear
    if b and not b.started and b.introDone and b:introDone() then
        b.started = true
        b:startFight(#players)
    end
    -- el apagón de la Gloomy: luz que se va y vuelve
    if self.active == 'gloomy' and b and not b.eventFrozen then
        level.dark = true
        level.darkness = math.min(1, (level.darkness or 0) + dt / 0.8)
    elseif self.blackT then
        local t = self.t - self.blackT
        local a, h, o = CM.BLACKOUT[1], CM.BLACKOUT[2], CM.BLACKOUT[3]
        level.dark = t < a + h + o
        level.darkness = (t < a) and t / a or (t < a + h and 1 or math.max(0, 1 - (t - a - h) / o))
        if t >= a + h + o then self.blackT, level.dark, level.darkness = nil, false, 0 end
    elseif level.dark then
        level.darkness = math.max(0, (level.darkness or 0) - dt / 0.8)
        if level.darkness <= 0 then level.dark = false end
    end
    for _, r in ipairs(CM.ROLES) do
        local x = self.fin[r]
        if x and x.alive and x.offstage == 'wait' then self:stageWalk(x, dt) end
    end
    -- LOS QUE ESPERAN tiran su peligro, al compás de la música
    local pc = piece(self.piece)
    if not pc then return end
    local p0, p1 = self.prevPos or self.pos, self.pos
    self.prevPos = self.pos
    -- (dio la VUELTA solo si salta mucho hacia atrás; un poco hacia atrás es el audio recolocando el reloj — CM:syncAudio
    -- lo deja retroceder hasta 0,25 s —: no cruza nada. Antes cualquier retroceso contaba como vuelta y cruzaba la pieza
    -- ENTERA: todos sus carámbanos, notas y Crabbies a la vez — el usuario, en Xtra extremo: "cientos por segundo")
    if p1 < p0 then
        if p0 - p1 > pc.music_end / 2 then p0 = p0 - pc.music_end else p0 = p1 end
    end
    local function crossed(t) return t > p0 and t <= p1 end
    local waiting = function(r) local x = self.fin[r]; return x and x.offstage == 'wait' end
    local bar, step = barAt(pc, math.max(0, p1))
    local pbar = barAt(pc, math.max(0, p0))
    if waiting('groove') then                                       -- notas en los pops (una por compás par)
        for _, t in ipairs(pc.events and pc.events.pops or {}) do
            if crossed(t) then
                local bi = barAt(pc, t)
                if bi % 2 == 0 and self.noteBar ~= bi then self.noteBar = bi; self:fireNote(level, players) end
            end
        end
    end
    if waiting('icy') then                                          -- un carámbano en la 1ª nota de la caja de cada compás
        for _, t in ipairs(pc.events and pc.events.box or {}) do
            if crossed(t) then
                local bi = barAt(pc, t)
                if self.iceBar ~= bi then self.iceBar = bi; self:dropIcicle(level, players) end
            end
        end
    end
    if bar ~= pbar then
        if waiting('gloomy') and bar % 8 == 5 and not self.blackT and self.active ~= 'gloomy' then
            self.blackT = self.t
            self:throwAnim(self.fin.gloomy, 1.0)
            Sound.playAt('mgloomyShriek', self.fin.gloomy.x, self.fin.gloomy.y, 0.9)
        end
        if waiting('tantrum') and bar % 8 == 1 then self:dropCrabby(level, players) end
    end
end

-- ── Los peligros del final ───────────────────────────────────────────────────────
function CM:fireNote(level, players)
    local src = self.fin.groove
    local tgt = players[math.random(math.max(1, #players))]
    if not src or not tgt then return end
    local dx, dy = tgt.x - src.x, tgt.y - src.y
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    self.noteId = self.noteId + 1
    self.notes[#self.notes + 1] = { id = self.noteId, x = src.x, y = src.y, vx = dx / d * CM.NOTE_SPEED,
                                    vy = dy / d * CM.NOTE_SPEED, c = self.noteId % 4 + 1, t = 0 }
    self:throwAnim(src, 0.35)
    Sound.playAt('megaClack', src.x, src.y, 1.3, 0.6)      -- (donde está: el director queda lejos del escenario)
end

function CM:dropIcicle(level, players)
    local z, tgt = self.finalZone, players[math.random(math.max(1, #players))]
    if not z or not tgt then return end
    local x = math.max(z.x0 + T / 2, math.min(z.x1 - T / 2, tgt.x))
    local floor = select(2, level:landingCross(x, tgt.y - T, z.y1 + T)) or (tgt.y + T)
    self.noteId = self.noteId + 1
    self.icicles[#self.icicles + 1] = { id = self.noteId, x = x, y = z.y0, floor = floor, t = 0 }
    self:throwAnim(self.fin.icy, 0.8)
    Sound.playAt('iceCrack', x, floor, 1.3, 0.7)           -- (el aviso: la grieta en el suelo)
end

function CM:dropCrabby(level, players)
    local mega = self.fin.tantrum
    if not mega or not mega.summonable then return end
    local n, free = mega:summonable(level)
    local e = free and free[1]
    if not e or n <= 0 then return end
    local z, tgt = self.finalZone, players[math.random(math.max(1, #players))]
    local x = math.max(z.x0 + T, math.min(z.x1 - T, (tgt and tgt.x or (z.x0 + z.x1) / 2) + (math.random() - 0.5) * 4 * T))
    local h = e.home
    h.x, h.y, h.facing, h.flipped, h.state = x, z.y0 + e.outerH / 2 + 2, 1, true, 'walk'
    h.vx = e.speed
    e:resetToHome()
    e.state, e.deadTimer = 'spawning', 0
    e.leashZone = z
    Entity.emitFx('spawn', x, h.y)
    self:throwAnim(mega, 1.2)
    self.crabDrops = (self.crabDrops or 0) + 1         -- (cuántos ha soltado: lo cuenta tools/tests/mashup_rules)
    Sound.playAt('respawnFx', x, h.y, 0.8)
end

function CM:tickHazards(dt, level, players)
    for i = #self.notes, 1, -1 do
        local n = self.notes[i]
        n.t = n.t + dt
        n.x, n.y = n.x + n.vx * dt, n.y + n.vy * dt
        local hit = false
        for _, pa in ipairs(players) do
            if math.abs(pa.x - n.x) < 34 and math.abs(pa.y - n.y) < 46 then
                Boss.strike(pa, { 1, 260, -380, 0.25, 0 }, n.vx >= 0 and 1 or -1); hit = true
            end
        end
        if hit or n.t > 4 or level:collisionAt(n.x, n.y) and level:collisionAt(n.x, n.y).collision == 'solid' then
            table.remove(self.notes, i)
        end
    end
    for i = #self.icicles, 1, -1 do
        local c = self.icicles[i]
        local was = c.t
        c.t = c.t + dt
        if was < CM.ICICLE_WARN and c.t >= CM.ICICLE_WARN then Sound.playAt('megaFall', c.x, c.floor, 1.8, 0.6) end   -- (se suelta)
        if c.t >= CM.ICICLE_WARN then c.y = c.y + CM.ICICLE_FALL * dt end
        local hit = false
        for _, pa in ipairs(players) do
            if c.t >= CM.ICICLE_WARN and math.abs(pa.x - c.x) < 30 and c.y > pa.y - 48 and c.y < pa.y + 48 then
                Boss.strike(pa, { 1, 200, -300, 0.2, 0 }, (pa.x >= c.x) and 1 or -1); hit = true
            end
        end
        if hit or c.y >= c.floor then
            if not hit then Entity.emitFx('ice_shatter', c.x, c.floor) end
            Sound.playAt('iceBreak', c.x, c.floor, 1.2, 0.9)       -- (el impacto, donde cae)
            table.remove(self.icicles, i)
        end
    end
end

-- ── El fin: explosiones en cadena (compases 5, 6, 7 y el acorde del 8) ─────────────
function CM:tickEnd(level)
    local pc = piece('end')
    if not pc then return end
    local bi = barAt(pc, self.pos)
    while self.boomN < 4 and bi >= 5 + self.boomN do
        self.boomN = self.boomN + 1
        local role = CM.ROLES[self.boomN]
        local b = self.fin[role]
        if b and b.alive then
            Entity.emitFx('boss_big_blast', b.x, b.y)
            for k = 0, 5 do
                local a = k / 6 * math.pi * 2
                Entity.emitFx('enemy_burst', b.x + math.cos(a) * 40, b.y + math.sin(a) * 30)
            end
            Entity.emitFx('king_confetti_big', b.x, b.y)
            Entity.emitFx('shake_big', b.x, b.y)
            Sound.play('bossExplode', 1.0)
            Sound.play('enemyExplode', 0.8)
            Sound.play('crowdCheer', 1.0)
            b.state, b.alive = 'dead', false
            for _, m in ipairs(b.summonKey and b:minions(level) or {}) do if m.alive then m.alive, m.state = false, 'dead' end end
        end
    end
end

-- ── Red ───────────────────────────────────────────────────────────────────────────
-- { fase, pieza, punto·1000, vuelta, ci, activo, fundido·100, seamTo, fondo×4 (0 nada, 1 espera, 2 ko), congelado×4
--   (principal), congelado×4 (final), stats (n, {idx, dmg, deaths, hits}…), notas (n, {id,x,y,c}…), carámbanos (n,
--   {id,x,y,t·100}…), oscuridad·100, hp, hpMax, boomN }
function CM:netPack()
    local out = { PCODE[self.phase] or 1, PIDX[self.piece] or 0, math.floor(self.pos * 1000 + 0.5), self.lap, self.ci,
                  RIDX[self.active] or 0, math.floor(self.fade * 100 + 0.5), self.seamTo or 0 }
    for _, r in ipairs(CM.ROLES) do
        local b = self.fin and self.fin[r]
        out[#out + 1] = b and (b.offstage == 'wait' and 1 or (b.offstage == 'ko' and 2 or 0)) or 0
    end
    for _, r in ipairs(CM.ROLES) do out[#out + 1] = (self.main and self.main[r] and self.main[r].eventFrozen) and 1 or 0 end
    for _, r in ipairs(CM.ROLES) do out[#out + 1] = (self.fin and self.fin[r] and self.fin[r].eventFrozen) and 1 or 0 end
    local keys = {}
    for k in pairs(self.stats) do keys[#keys + 1] = k end
    table.sort(keys)
    out[#out + 1] = #keys
    for _, k in ipairs(keys) do
        local s = self.stats[k]
        out[#out + 1] = k; out[#out + 1] = s.dmg; out[#out + 1] = s.deaths; out[#out + 1] = s.hits
    end
    out[#out + 1] = #self.notes
    for _, n in ipairs(self.notes) do
        out[#out + 1] = n.id; out[#out + 1] = math.floor(n.x); out[#out + 1] = math.floor(n.y); out[#out + 1] = n.c
    end
    out[#out + 1] = #self.icicles
    for _, c in ipairs(self.icicles) do
        out[#out + 1] = c.id; out[#out + 1] = math.floor(c.x); out[#out + 1] = math.floor(c.y); out[#out + 1] = math.floor(c.t * 100)
    end
    out[#out + 1] = math.floor(((self.level and self.level.dark) and (self.level.darkness or 1) or 0) * 100)
    out[#out + 1] = self.hp or 0
    out[#out + 1] = self.hpMax or 0
    out[#out + 1] = self.boomN or 0
    out[#out + 1] = self.level and self.level.sceneIdx or 0
    return out
end

function CM:netApply(a, b, f)
    local level = self.levelRef
    if level then self:setup(level) end
    if type(b[1]) ~= 'number' then return end
    self.phase = PHASES[b[1]] or self.phase
    local pid = PIECE_IDS[b[2]]
    -- el punto de la música: interpolado si es la misma pieza y avanza
    local pa_, pb_ = (a[3] or b[3]) / 1000, b[3] / 1000
    if pid ~= self.piece then self.lap = 0 end
    self.piece = pid
    self.pos = (a[2] == b[2] and pb_ >= pa_) and (pa_ + (pb_ - pa_) * f) or pb_
    self.lap, self.ci = b[4] or 0, b[5] or 0
    self.active = CM.ROLES[b[6]]
    self.fade, self.seamTo = (b[7] or 0) / 100, b[8]
    local i = 9
    for _, r in ipairs(CM.ROLES) do
        local x = self.fin and self.fin[r]
        if x then x.offstage = (b[i] == 1 and 'wait') or (b[i] == 2 and 'ko') or nil end
        i = i + 1
    end
    for _, r in ipairs(CM.ROLES) do local x = self.main and self.main[r]; if x then x.eventFrozen = b[i] == 1 end; i = i + 1 end
    for _, r in ipairs(CM.ROLES) do local x = self.fin and self.fin[r]; if x then x.eventFrozen = b[i] == 1 end; i = i + 1 end
    self.stats = {}
    local n = b[i] or 0; i = i + 1
    for _ = 1, n do
        self.stats[b[i]] = { dmg = b[i + 1], deaths = b[i + 2], hits = b[i + 3] }; i = i + 4
    end
    self.notes = {}
    n = b[i] or 0; i = i + 1
    for _ = 1, n do self.notes[#self.notes + 1] = { id = b[i], x = b[i + 1], y = b[i + 2], c = b[i + 3] }; i = i + 4 end
    self.icicles = {}
    n = b[i] or 0; i = i + 1
    for _ = 1, n do self.icicles[#self.icicles + 1] = { id = b[i], x = b[i + 1], y = b[i + 2], t = b[i + 3] / 100 }; i = i + 4 end
    local dk = (b[i] or 0) / 100; i = i + 1
    self.hp, self.hpMax, self.boomN = b[i], b[i + 1], b[i + 2]; i = i + 3
    local sc = b[i]
    if level then
        if sc and sc > 0 then level:applyScene(sc) end
        level.dark, level.darkness = dk > 0, dk                     -- (la escena a oscuras, o el apagón del final)
        level.screenFade = self.fade > 0 and self.fade or nil
        if self.finalZone and self.phase == 'outro' then self.finalZone.state = 'cleared' end
    end
end

function CM:netAtRest() return false end

-- ── Dibujo ────────────────────────────────────────────────────────────────────────
local canvas
local function scaled(e, sx, sy, sc, tint, look)
    if not (canvas and canvas:getWidth() == WINDOW_W and canvas:getHeight() == WINDOW_H) then
        canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
        canvas:setFilter('nearest', 'nearest')
    end
    local real = e.state
    if look then e.state = look end
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.translate(sx, sy); love.graphics.scale(sc); love.graphics.translate(-sx, -sy)
    e._bodyOnly = true
    e:render(e.x - sx, e.y - sy)
    e._bodyOnly = nil
    love.graphics.pop()
    e.state = real
    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
end
CM.drawScaled = scaled

-- Detrás de los bloques: los focos de la intro y, al final, los resultados en la pantalla del escenario
function CM:introLit()
    if self.phase ~= 'intro' then return 4 end
    local pc = piece('intro')
    return pc and math.min(4, barAt(pc, math.max(0, self.pos))) or 0
end
function CM:renderBack(camX, camY)
    if EDITOR_VIEW or not self.fin then return end
    if self.phase == 'intro' then                                -- (un foco por compás sobre cada uno)
        local lit = self:introLit()
        for k, r in ipairs(CM.ROLES) do
            local b = self.fin[r]
            if b and b.alive and k <= lit then
                local sx, fy = math.floor(b.x - camX), math.floor(self.finalZone.y1 - camY)
                love.graphics.setBlendMode('add')
                love.graphics.setColor(1, 0.95, 0.7, 0.16)
                love.graphics.polygon('fill', sx - 20, 0, sx + 20, 0, sx + 3 * T, fy, sx - 3 * T, fy)
                love.graphics.setBlendMode('alpha')
            end
        end
    end
    if self.phase == 'outro' then self:drawResults(camX, camY) end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Los que no pelean (esperando / noqueados), en el escenario: a su tamaño, más oscuros (en la intro, en negro hasta
-- que les llega su foco)
function CM:drawStaged(camX, camY)
    local lit = self:introLit()
    for k, r in ipairs(CM.ROLES) do
        local b = self.fin and self.fin[r]
        if b and b.alive and b.offstage then
            local tint = DIM[b.offstage] or DIM.wait
            if self.phase == 'intro' then tint = (k <= lit) and { 1, 1, 1 } or { 0.07, 0.06, 0.11 } end
            scaled(b, math.floor(b.x - camX), math.floor(b.y - camY), 1, tint)
            if b.offstage == 'ko' then
                require('src/fx/BossFx').stars(math.floor(b.x - camX), math.floor(b.y - camY - b.sprH * 0.45), b.sprW * 0.35, 14, 7, 0.8, 'front')
            end
        end
    end
end

-- Encima: siluetas de la intro, peligros, estrellas de los aturdidos, el fundido de las costuras
local noteArt, iceArt
function CM:render(camX, camY)
    if EDITOR_VIEW then return end
    local now = love.timer.getTime()
    self:drawStaged(camX, camY)
    -- estrellitas sobre los congelados (aturdidos hasta el corte)
    for _, list in ipairs({ self.main or {}, self.fin or {} }) do
        for _, b in pairs(list) do
            if b.alive and b.eventFrozen and not b.offstage then
                require('src/fx/BossFx').stars(math.floor(b.x - camX), math.floor(b.y - camY - b.sprH * 0.45), b.sprW * 0.35, 14, 7, 1, 'front')
            end
        end
    end
    -- notas (Groove al fondo)
    if #self.notes > 0 then
        noteArt = noteArt or require('src/fx/SpriteStrip').load('assets/images/bosses/groovecrab/note-Sheet.png', 9)
        for _, n in ipairs(self.notes) do
            love.graphics.setColor(1, 1, 1, 1)
            if noteArt then noteArt:draw(((n.c or 1) - 1) % 4 + 1, math.floor(n.x - camX), math.floor(n.y - camY), 0, 5, 5) end
        end
    end
    -- carámbanos (Icy al fondo): primero la grieta de aviso en el suelo, luego cae
    if #self.icicles > 0 then
        iceArt = iceArt or require('src/fx/SpriteStrip').load('assets/images/bosses/megacrabby_ice/ice_field-Sheet.png', 8)
        for _, c in ipairs(self.icicles) do
            local x = math.floor(c.x - camX)
            if c.t < CM.ICICLE_WARN then
                local blink = math.floor(now * 12) % 2 == 0
                love.graphics.setColor(0.7, 0.9, 1, blink and 0.9 or 0.4)
                love.graphics.rectangle('fill', x - 18, math.floor((c.floor or c.y) - camY) - 6, 36, 6)
            end
            love.graphics.setColor(1, 1, 1, 1)
            if iceArt then iceArt:draw(2, x, math.floor(c.y - camY), math.pi, 5, 5) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Por encima de todo (pantalla): las siluetas de la intro y el fundido de las costuras
function CM:drawOverlay()
    if (self.fade or 0) > 0 then
        love.graphics.setColor(0, 0, 0, self.fade)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Los resultados en la pantalla del escenario (un jugador: tiempo, golpes, muertes; online: ranking)
function CM:drawResults(camX, camY)
    local L = require 'src/core/Lang'
    local z = self.finalZone
    if not z then return end
    local w, h = math.floor(math.min(9 * T, (z.x1 - z.x0) * 0.6)), math.floor(3.4 * T)
    local x, y = math.floor((z.x0 + z.x1) / 2 - w / 2 - camX), math.floor(z.y0 + 0.6 * T - camY)
    love.graphics.setColor(0.06, 0.04, 0.12, 0.92)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(1, 0.31, 0.64, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', x, y, w, h)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 0.86, 0.36, 1)
    love.graphics.printf(L('mashup.victory'), x, y + 10, w, 'center')
    love.graphics.setFont(FONT_SMALL)
    local rows, keys = {}, {}
    for k in pairs(self.stats) do keys[#keys + 1] = k end
    table.sort(keys, function(p, q)
        local a, b = self.stats[p], self.stats[q]
        if a.dmg ~= b.dmg then return a.dmg > b.dmg end
        return a.deaths < b.deaths
    end)
    local names = self.levelRef and self.levelRef.playerNames or {}
    for r, k in ipairs(keys) do
        local s = self.stats[k]
        local name = names[k] or (#keys == 1 and L('hud.you')) or ('P' .. k)
        rows[#rows + 1] = L('mashup.result_row', { n = r, name = name, dmg = s.dmg, deaths = s.deaths, hits = s.hits })
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(rows) do
        if i > 4 then break end
        love.graphics.printf(line, x + 12, y + 46 + (i - 1) * 24, w - 24, 'center')
    end
    love.graphics.setColor(0.6, 1, 0.7, 1)
    love.graphics.printf(L('mashup.exit'), x, y + h - 30, w, 'center')
    love.graphics.setColor(1, 1, 1, 1)
end

return {
    name = 'crabmashup', label = 'Mega Mashup (director)', category = 'Directores',
    description = 'Director del evento Mega Mashup de los Cangrejos: los cuatro cangrejos por turnos con música '
               .. 'adaptativa (docs/bosses/crab-mashup.md). Uno por nivel de evento.',
    class = CM,
    hide = 'all',
    pace = false,
    defaults = { movement = 'static' },
    props = {},
}
