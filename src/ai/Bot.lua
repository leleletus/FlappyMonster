-- src/ai/Bot.lua
-- BOT RIVAL de las arenas de Rey de la Colina del modo historia (los bonus). Juega con un PlayerAdventure de
-- verdad (la misma física que tú) y lo maneja "pulsando botones": cada fotograma decide los bits de input
-- (src/network/Protocol.lua) y AdventureState se los da como Input. Es INMORTAL (pa.immortal: los golpes y los
-- empujones le llegan, pero no muere) y su trabajo es NO DEJARTE QUIETO EN LA ZONA:
--   * si tú estás en una zona de puntos, va a por ti (por el grafo de navegación, src/ai/BotNav.lua) y, al
--     tenerte cerca, salta hacia ti y hace un GROUND POUND encima: si cae cerca te empuja y te aturde
--     (AdventureState: knockback); entre ataque y ataque descansa `ATTACK_CD` s;
--   * si no, va a la zona que más puntos da y se queda dentro (también suma puntos: gana quien más tenga),
--     cambiando de casilla dentro de ella cada pocos segundos.
-- NO hace siempre lo mismo: el grafo es solo el MAPA de por dónde se puede ir; qué hace lo decide cada fotograma
-- según dónde estás tú y cómo está el nivel, y con algo de azar (descansos, a qué casilla de la zona va).
-- La ejecución de cada arista: andar = bucle cerrado hacia el centro de la casilla de al lado; un movimiento
-- grabado = se coloca quieto en el centro de su casilla y reproduce los inputs fotograma a fotograma (la física
-- es determinista: cae donde se grabó; si cae en otro sitio, vuelve a planear desde ahí).
local P = require 'src/network/Protocol'
local BotNav = require 'src/ai/BotNav'

local Bot = {}
Bot.__index = Bot

Bot.ATTACK_CD = 1.1          -- s entre ground pounds (experto)
Bot.ATTACK_R = 3.2           -- casillas: a esta distancia (y casi a su altura) salta a por ti
Bot.REPLAN = 0.5             -- s: replanea aunque no haya cambiado de casilla
Bot.STUCK = 2.5              -- s sin avanzar → replanea desde donde esté
Bot.PUSH_R = 1.8             -- casillas: radio del empujón de su ground pound
Bot.PUSH_VX, Bot.PUSH_VY = 1150, -700   -- el empujón: te lanza LEJOS (fuera de la zona), sin control un momento

local L, R, J, JP, C, CP = P.IN_LEFT, P.IN_RIGHT, P.IN_JUMP, P.IN_JUMP_P, P.IN_CROUCH, P.IN_CROUCH_P

function Bot.new(pa, nav, opts)
    opts = opts or {}
    pa.immortal = true
    return setmetatable({
        pa = pa, nav = nav, stub = P.newInputStub(),
        cd = opts.firstDelay or 1.5, attackCd = opts.attackCd or Bot.ATTACK_CD,
        path = nil, edgeF = 0, planT = 0, stuckT = 0, lastX = pa.x, mode = 'route',
        prevBits = 0, score = 0, name = opts.name, color = opts.color,
        fails = {}, banned = {}, clock = 0,
    }, Bot)
end

-- Las casillas de la zona donde quedarse AHORA (el suelo puede cambiar: bloques ON/OFF, hielo roto): las que
-- tienen suelo en este momento; mejor sobre suelo FIRME (el hielo fino se rompe bajo sus pies); si no hay
-- ninguna firme, todas las que tengan suelo. Devuelve el set (o nil) y si hay firmes.
local function zoneNodes(nav, area, level)
    local firm, all, anyF, anyA = {}, {}, false, false
    for id, n in pairs(nav.nodes) do
        local y = n.y or (n.r * TILE_PX - 40)
        if n.x >= area.x0 and n.x < area.x1 and y >= area.y0 and y < area.y1 and level:isStandable(n.c, n.r) then
            all[id], anyA = true, true
            if not level:getDef(n.c, n.r + 1).thinIce then firm[id], anyF = true, true end
        end
    end
    return anyF and firm or (anyA and all or nil), anyF
end

-- La zona que le conviene al bot ahora (se recalcula cada segundo)
function Bot.pickZone(nav, level, x, y, clock)
    local best, bs
    for _, a in ipairs(level.pointAreas or {}) do
        if not a._navAt or clock - a._navAt > 1 or clock < a._navAt then
            a._nodes, a._firm = zoneNodes(nav, a, level)
            a._navAt = clock
        end
        local cx, cy = (a.x0 + a.x1) / 2, (a.y0 + a.y1) / 2
        -- (más puntos, mejor; una zona sin suelo firme — todo hielo fino — vale menos; sin suelo, nada)
        local sc = (a.points or 1) * 1000 - (a._firm and 0 or 1500) - (a._nodes and 0 or 100000)
                   - math.abs(cx - x) * 0.2 - math.abs(cy - y) * 0.4
        if not bs or sc > bs then best, bs = a, sc end
    end
    return best
end

local function inArea(a, x, y) return x >= a.x0 and x < a.x1 and y >= a.y0 and y < a.y1 end

-- ¿En qué zona está ese jugador (o nil)?
local function areaOf(level, pa)
    for _, a in ipairs(level.pointAreas or {}) do
        if inArea(a, pa.x, pa.y) then return a end
    end
end

function Bot:_h() return self.pa:getOuterBounds().h end

-- Elige el destino: tú (si estás puntuando en una zona) o la mejor zona
function Bot:_goal(level, target)
    local pa = self.pa
    local area = target and not target.dying and areaOf(level, target)
    if area and self.cd <= 0 then
        local tn = BotNav.nodeAt(self.nav, target.x, target.y, target:getOuterBounds().h)
        if tn then
            local set = { [tn] = true }
            local n = self.nav.nodes[tn]
            for _, dc in ipairs({ -2, -1, 1, 2 }) do
                local id = (n.r) * 4096 + n.c + dc
                if self.nav.nodes[id] then set[id] = true end
            end
            return set, 'hunt'
        end
    end
    -- la zona que más da (a igualdad, la más cercana en línea recta)
    local best = Bot.pickZone(self.nav, level, pa.x, pa.y, self.clock)
    if best then
        if not best._nodes then return nil, 'hold' end
        local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
        if inArea(best, pa.x, pa.y) and pa.onGround and (not best._nodes or (here and best._nodes[here])) then return nil, 'hold' end
        return best._nodes, 'zone'
    end
    return nil, 'hold'
end

-- Los bits de este fotograma
function Bot:think(dt, level, target)
    local pa = self.pa
    self.cd = math.max(0, self.cd - dt)
    self.clock = self.clock + dt
    local bits = 0
    if pa.dying or (pa.stunT or 0) > 0 or (pa.ctrlLockT or 0) > 0 or (pa.iceT or 0) > 0 then
        self.mode, self.path = 'route', nil
        return self:_emit(0)
    end
    -- ── ATAQUE (bucle cerrado): salta hacia ti y, encima, ground pound ──
    if self.mode == 'attack' then
        self.atkT = self.atkT + dt
        local dx = target.x - pa.x
        if pa.onGround and self.atkT > 0.15 then
            self.mode, self.path, self.cd = 'route', nil, self:_rest()
            return self:_emit(0)
        end
        if pa.gpPhase then return self:_emit(0) end
        if math.abs(dx) > 8 then bits = bits + ((dx < 0) and L or R) end
        if self.atkT < 0.3 then bits = bits + J end
        -- encima (o pasándose) y ya bajando o cerca del vértice: ¡ground pound!
        if math.abs(dx) < 22 and pa.vy > -220 and pa.y < target.y - 20 then bits = bits + C + CP end
        -- (si estás más alto, el segundo salto)
        if self.atkT > 0.32 and self.atkT < 0.36 and target.y < pa.y - TILE_PX and pa.jumpsLeft > 0 then bits = bits + J + JP end
        if self.atkT > 1.6 then self.mode, self.cd = 'route', self:_rest() end
        return self:_emit(bits)
    end
    local goals, kind = self:_goal(level, target)
    -- cerca de ti y casi a tu altura: al ataque
    if kind == 'hunt' and pa.onGround and self.cd <= 0 then
        local dx, dy = target.x - pa.x, target.y - pa.y
        if math.abs(dx) < Bot.ATTACK_R * TILE_PX and dy > -1.6 * TILE_PX and dy < 0.8 * TILE_PX then
            self.mode, self.atkT = 'attack', 0
            pa.facing = (dx < 0) and -1 or 1
            return self:_emit(J + JP + ((dx < 0) and L or R))
        end
    end
    if not goals then
        -- en la zona: no se queda clavado — cada pocos segundos se cambia a otra casilla de la zona, al azar
        self.roamT = (self.roamT or (2 + math.random() * 3)) - dt
        local z = Bot.pickZone(self.nav, level, pa.x, pa.y, self.clock)
        if self.roamT <= 0 and z and z._nodes then
            local list = {}
            for id in pairs(z._nodes) do list[#list + 1] = id end
            table.sort(list)
            self.roamTo, self.roamT = list[math.random(#list)], 2.5 + math.random() * 4
        end
        local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
        if not self.roamTo or here == self.roamTo then self.roamTo = nil; return self:_emit(0) end
        goals = { [self.roamTo] = true }
    end
    -- ── RUTA por el grafo ──
    self.planT = self.planT - dt
    local cur = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h()) or nil
    if math.abs(pa.x - self.lastX) > 2 then self.stuckT, self.lastX = 0, pa.x else self.stuckT = self.stuckT + dt end
    if self.edge and self.edge.seq and self.edgeF > 0 then
        -- reproduciendo un movimiento grabado
        self.edgeF = self.edgeF + 1
        if not pa.onGround then self.edgeAir = true end
        -- (como al grabarla: termina al volver al suelo DESPUÉS de haber estado en el aire)
        if (pa.onGround and self.edgeAir and self.edgeF > 3) or self.edgeF > 160 then
            -- ¿cayó donde se grabó? Si una arista falla dos veces (el nivel cambió: hielo roto, un bloque
            -- roto…), se descarta un rato
            local landed = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
            if landed ~= self.edge.to then self:_fail(self.edgeFrom, self.edge) end
            self.edge, self.edgeF, self.path = nil, 0, nil
        else
            return self:_emit(BotNav.bitsAt(self.edge, self.edgeF))
        end
    end
    if not cur and pa.onGround then self.path = nil end
    if cur and (not self.path or self.planT <= 0 or self.pathFrom ~= cur or self.stuckT > Bot.STUCK) then
        if self.stuckT > Bot.STUCK and self.path and self.path[1] then self:_fail(cur, self.path[1]) end
        self.path = BotNav.path(self.nav, cur, goals, nil, function(u, e)
            local b = self.banned[u * 1048576 + e.to]
            if b ~= nil and b > self.clock then return true end
            -- (el grafo junta los dos estados de los bloques ON/OFF: fuera lo que AHORA no tiene suelo)
            local n = self.nav.nodes[e.to]
            return n == nil or not level:isStandable(n.c, n.r)
        end)
        self.pathFrom, self.planT, self.edge, self.edgeF = cur, Bot.REPLAN, nil, 0
        if self.stuckT > Bot.STUCK then self.stuckT = 0 end
    end
    local e = self.path and self.path[1]
    if not e then
        if not pa.onGround then return self:_emit(self.escBits or 0) end
        -- SIN CAMINO (fuera del grafo: un bloque roto, un foso, una casilla rara): hacia el destino a lo bruto,
        -- saltando (doble) cuando algo lo frena
        local gx
        for id in pairs(goals) do local n = self.nav.nodes[id]; if n then gx = n.x; break end end
        if not gx then return self:_emit(0) end
        local dir = (gx < pa.x) and L or R
        if math.abs(gx - pa.x) < 8 then dir = 0 end
        self.escT = (self.escT or 0) + dt
        if self.stuckT > 0.3 or self.escT > 1.2 then
            self.escT, self.stuckT = 0, 0
            self.escBits = dir + J
            return self:_emit(dir + J + JP)
        end
        self.escBits = dir
        return self:_emit(dir)
    end
    if not cur then return self:_emit(0) end            -- (en el aire: deja que caiga)
    local from = self.nav.nodes[cur]
    local to = self.nav.nodes[e.to]
    if e.walk then
        local dx = to.x - pa.x
        if math.abs(dx) < 6 then table.remove(self.path, 1); self.pathFrom = e.to; return self:_emit(0) end
        return self:_emit((dx < 0) and L or R)
    end
    -- movimiento grabado: primero quieto en el centro de su casilla
    local dx = from.x - pa.x
    if math.abs(dx) > 5 then return self:_emit((dx < 0) and L or R) end
    if math.abs(pa.vx) > 25 then return self:_emit(0) end
    self.edge, self.edgeF, self.edgeFrom, self.edgeAir = e, 1, cur, false
    return self:_emit(BotNav.bitsAt(e, 1))
end

-- Descanso entre ataques: no siempre igual (× 0,8-1,6), para que no sea un metrónomo
function Bot:_rest() return self.attackCd * (0.8 + math.random() * 0.8) end

function Bot:_fail(u, e)
    if not (u and e) then return end
    if os.getenv('BOT_DEBUG') then
        local a, b = self.nav.nodes[u], self.nav.nodes[e.to]
        print(('  falla %d,%d → %d,%d (%s) cae en %s'):format(a.c, a.r, b.c, b.r, e.walk and 'andar' or (#(e.seq or {}) .. ' tramos'),
            tostring(self.pa.onGround and BotNav.nodeAt(self.nav, self.pa.x, self.pa.y, self:_h()))))
    end
    local k = u * 1048576 + e.to
    self.fails[k] = (self.fails[k] or 0) + 1
    if self.fails[k] >= 2 then self.banned[k], self.fails[k] = self.clock + 15, 0 end
end

function Bot:_emit(bits)
    self.prevBits = bits
    P.decodeInput(bits, self.stub.state)
    return bits
end

-- Un paso de física del bot con su input (como el servidor: Input = su stub mientras se actualiza)
-- PASO FIJO de 1/60 s: los movimientos del grafo se grabaron fotograma a fotograma a 60 Hz; con el dt real del
-- juego (variable: 144 Hz, tirones...) los mismos inputs caían en otro sitio y el bot no llegaba a ninguna parte
-- (pasaba en el juego y no en el arnés, que iba a 1/60 clavado). El dt real se acumula y se dan los pasos que quepan.
Bot.DT = 1 / 60
function Bot:step(dt, level, target)
    self.acc = math.min((self.acc or 0) + dt, 0.1)
    self.landed = false
    while self.acc >= Bot.DT do
        self.acc = self.acc - Bot.DT
        self:_step(Bot.DT, level, target)
        if self.pa.gpLanded then self.landed = true end
    end
end

function Bot:_step(dt, level, target)
    self:think(dt, level, target)
    local real = Input
    Input = self.stub
    local ok, err = pcall(self.pa.update, self.pa, dt, level)
    Input = real
    if not ok then error(err, 0) end
    -- se cayó del nivel (inmortal: vuelve a su salida)
    if self.pa.y > (level.tileH + 2) * TILE_PX then
        self.pa.x, self.pa.y, self.pa.vx, self.pa.vy = self.pa.spawnX, self.pa.spawnY, 0, 0
        self.path, self.mode = nil, 'route'
    end
end

-- Aplica el empujón de su ground pound a `target` (si le alcanza): lanzado lejos y sin control un momento.
-- true si le dio.
function Bot:push(target)
    local hit, dir = self:poundHits(target)
    if not hit or target:isPushProtected() then return false end
    target:launch(dir * Bot.PUSH_VX, Bot.PUSH_VY)
    target.stunT = math.max(target.stunT or 0, 0.35)
    Sound.play('stunned')
    return true
end

-- Su ground pound acaba de caer: ¿a quién empuja? (lo aplica quien llama)
function Bot:poundHits(target)
    if not self.landed or not target or target.dying then return false end
    local dx, dy = target.x - self.pa.x, target.y - self.pa.y
    return math.abs(dx) < Bot.PUSH_R * TILE_PX and math.abs(dy) < 1.3 * TILE_PX, (dx < 0) and -1 or 1
end

return Bot
