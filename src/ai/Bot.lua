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
-- PRIORIDADES (3.69.0; el usuario: a veces dejaba su zona para perseguirte y perdía sus puntos): lo PRIMERO es
-- PUNTUAR — estar en la zona que más da y quedarse —; atacar es un medio para eso, no el fin:
--   1. si está puntuando en una zona NO la deja para perseguirte: solo te ataca si estás en SU zona (o a su lado);
--   2. si no está en una zona, va a la mejor; si tú estás puntuando en una (y el descanso ha pasado) va a echarte de
--      ella; de camino solo te ataca si te tiene al alcance (no se desvía);
--   3. no hace ground pound sobre suelo ROMPIBLE (rompería el suelo de la zona y caería él también);
--   4. Activadores ON/OFF (ciudadela_alterna): si pulsarlo le deja una zona mejor, o te quita el suelo de la tuya
--      sin quitarle la suya, va y lo pulsa (cabezazo desde abajo o ground pound encima) — `_switchPlan`;
--   5. AGUA que sube (inundaciones): no planea por casillas que AHORA están bajo el agua; si el agua lo pilla, sale
--      nadando hacia lo seco más cercano y, si no avanza (un foso del que no se sale con el agua alta), ESPERA
--      quieto a que baje en vez de saltar sin parar — `_water`.
-- La ejecución de cada arista: andar = bucle cerrado hacia el centro de la casilla de al lado; un movimiento
-- grabado = se coloca quieto en el centro de su casilla y reproduce los inputs fotograma a fotograma (la física
-- es determinista: cae donde se grabó; si cae en otro sitio, vuelve a planear desde ahí).
local P = require 'src/network/Protocol'
local PointAreas = require 'src/world/PointAreas'
local BotNav = require 'src/ai/BotNav'
local Floods = require 'src/world/Floods'

local Bot = {}
Bot.__index = Bot

Bot.ATTACK_CD = 0.45         -- s entre ground pounds: MUY hostil (el usuario: casi siempre que te tenga cerca)
Bot.CHASE_R = 7              -- casillas: si estás a menos de esto, va a por ti aunque no estés en una zona
Bot.ATTACK_R = 3.2           -- casillas: a esta distancia (y casi a su altura) salta a por ti
Bot.REPLAN = 0.5             -- s: replanea aunque no haya cambiado de casilla
Bot.STUCK = 2.5              -- s sin avanzar → replanea desde donde esté
Bot.GIVE_UP = 2.5           -- s sin camino a su destino antes de irse a vagar a otra parte
Bot.PUSH_R = 1.8             -- casillas: radio del empujón de su ground pound
Bot.PUSH_VX, Bot.PUSH_VY = 1150, -700   -- el empujón: te lanza LEJOS (fuera de la zona), sin control un momento
Bot.SWITCH_CD = 6            -- s entre dos pulsaciones suyas de un Activador
Bot.WATER_TRY = 2.2          -- s nadando sin acercarse a lo seco antes de quedarse a esperar
Bot.WATER_WAIT = 15          -- s como mucho esperando a que baje el agua antes de volver a probar
Bot.WATER_DROP = 24          -- px que tiene que bajar el agua para volver a intentarlo

-- ¿Agua de una inundación SUBIDA ahí ahora? El grafo se grabó con cada inundación en su nivel MÍNIMO (así
-- empieza el nivel): mientras el agua está ahí, vale. Cuando ha subido, todo lo que cubre — también lo que ya
-- estaba mojado, porque ahora tiene más agua encima — deja de valer: otra física, y de un hoyo no se sale.
-- (El agua fija de los niveles ya está en el grafo.)
local function flooded(level, x, y)
    local fl = level.floods
    if not (fl and fl[1]) then return false end
    for _, f in ipairs(fl) do
        if x >= f.x0 and x < f.x1 and y >= f.surf and y < f.y1 and f.surf < (f.y1 - f.lo * TILE_PX) - 20 then return true end
    end
    return false
end
Bot.flooded = flooded

-- ¿El suelo bajo ese jugador es ROMPIBLE? (un ground pound lo rompería)
local function breakableUnder(level, pa)
    local ob = pa:getOuterBounds()
    local r = math.floor((ob.y + ob.h + 6) / TILE_PX) + 1
    for _, x in ipairs({ ob.x + 2, ob.x + ob.w - 2 }) do
        local d = level:getDef(math.floor(x / TILE_PX) + 1, r)
        if d and d.breakable then return true end
    end
    return false
end

local L, R, J, JP, C, CP = P.IN_LEFT, P.IN_RIGHT, P.IN_JUMP, P.IN_JUMP_P, P.IN_CROUCH, P.IN_CROUCH_P

function Bot.new(pa, nav, opts)
    opts = opts or {}
    pa.immortal = true
    return setmetatable({
        pa = pa, nav = nav, stub = P.newInputStub(),
        cd = opts.firstDelay or 1.5, attackCd = opts.attackCd or Bot.ATTACK_CD,
        path = nil, edgeF = 0, planT = 0, stuckT = 0, lastX = pa.x, mode = 'route',
        prevBits = 0, score = 0, name = opts.name, color = opts.color,
        fails = {}, banned = {}, clock = 0, chaseR = opts.chase or Bot.CHASE_R,
    }, Bot)
end

-- Las casillas de la zona donde quedarse AHORA (el suelo puede cambiar: bloques ON/OFF, hielo roto): las que
-- tienen suelo en este momento; mejor sobre suelo FIRME (el hielo fino se rompe bajo sus pies); si no hay
-- ninguna firme, todas las que tengan suelo. Devuelve el set (o nil) y si hay firmes.
local function zoneNodes(nav, area, level)
    local firm, all, anyF, anyA = {}, {}, false, false
    local rect, anyR = {}, false
    for id, n in pairs(nav.nodes) do
        local y = n.y or (n.r * TILE_PX - 40)
        if n.x >= area.x0 and n.x < area.x1 and y >= area.y0 and y < area.y1 and not flooded(level, n.x, y) then   -- (ni lo que ahora está bajo el agua)
            rect[id], anyR = true, true
            if level:isStandable(n.c, n.r) then
                all[id], anyA = true, true
                if not level:getDef(n.c, n.r + 1).thinIce then firm[id], anyF = true, true end
            end
        end
    end
    -- (con UNA sola zona activa no hay otra a la que irse: si ahora no le queda suelo — el hielo se rompió —, entra
    -- igual, a donde lo había: dentro de la zona se puntúa también nadando)
    -- (no si el suelo depende de un Activador ON/OFF: ahí lo suyo es ir a pulsarlo)
    if not anyA and anyR and #BotNav._switchCells(level) > 0 then anyR = false end
    return anyF and firm or (anyA and all) or (anyR and rect or nil), anyF
end

-- Las zonas a las que tiene sentido ir: con la zona ÚNICA que se mueve (PointAreas), la activa — o ya la
-- siguiente parada si está a punto de irse o va de camino: el bot se adelanta —; es su objetivo principal
local function goalZones(level)
    local a = PointAreas.target(level)
    return a and { a } or {}
end

-- La zona que le conviene al bot ahora (se recalcula cada segundo)
function Bot.pickZone(nav, level, x, y, clock)
    local best, bs
    for _, a in ipairs(goalZones(level)) do
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
    for _, a in ipairs(PointAreas.live(level)) do                -- (solo cuenta la zona ACTIVA)
        if inArea(a, pa.x, pa.y) then return a end
    end
end

function Bot:_h() return self.pa:getOuterBounds().h end

-- ¿Puede atacarte ahí con su ground pound? (no sobre suelo rompible: lo rompería)
function Bot:_canPound(level, target)
    return target ~= nil and not target.dying and not breakableUnder(level, target)
end

-- Elige el destino. PUNTUAR primero: si ya está en una zona, se queda (y solo va a por ti si estás en ella);
-- si no, a la mejor zona — o a echarte de la tuya si estás puntuando.
function Bot:_goal(level, target)
    local pa = self.pa
    local alive = target and not target.dying
    -- (en el aire: la última en que estuvo, si SIGUE siendo la activa — la zona se mueve: PointAreas —)
    local mine
    if pa.onGround then mine = areaOf(level, pa); self.myArea = mine
    else mine = self.myArea end
    if mine and not PointAreas.isActive(level, mine) then mine, self.myArea = nil, nil end
    local theirs = alive and areaOf(level, target)
    local ready = alive and self.cd <= 0 and self.clock >= (self.noHuntT or 0) and self:_canPound(level, target)
    -- ¿a por ti? Solo si estás en SU zona, o si él no está puntuando y tú sí (o te tiene muy cerca)
    local hunt = false
    if ready then
        if mine then hunt = theirs == mine
        else
            local close = math.abs(target.x - pa.x) < self.chaseR * TILE_PX and math.abs(target.y - pa.y) < 4 * TILE_PX
            hunt = theirs ~= nil and close
        end
    end
    if hunt then
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
        -- (ya puntúa en otra zona que da lo mismo: no la deja por ir a la "mejor")
        if mine and mine ~= best and mine._nodes and here and mine._nodes[here] and (mine.points or 1) >= (best.points or 1) then
            return nil, 'hold'
        end
        return best._nodes, 'zone'
    end
    return nil, 'hold'
end

-- ── ACTIVADORES ON/OFF ────────────────────────────────────────────────────────
-- Los Activadores del nivel y desde qué casilla se pulsan: de pie debajo (cabezazo) o encima (ground pound)
local function activators(nav, level)
    if nav.switches then return nav.switches end
    local TileTypes = require 'src/world/tiles/TileTypes'
    local TileCodec = require 'src/world/tiles/TileCodec'
    local list = {}
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            local def = TileTypes.get(TileCodec.id(level:getRaw(c, r)))
            if def and def.toggle and not def.switchBlock then
                local a = { c = c, r = r, press = {} }
                for k = 2, 3 do                              -- debajo: los pies 2 o 3 filas más abajo, con hueco entre medias
                    local id = (r + k) * 4096 + c
                    local free = true
                    for rr = r + 1, r + k - 1 do if level:getDef(c, rr).collision == 'solid' then free = false end end
                    if nav.nodes[id] and free then a.press[id] = 'bump' end
                end
                local top = (r - 1) * 4096 + c
                if nav.nodes[top] then a.press[top] = 'pound' end
                if next(a.press) then list[#list + 1] = a end
            end
        end
    end
    nav.switches = list
    return list
end

-- Qué zonas tendrían suelo si se pulsara el Activador (los Bloques ON/OFF cambiados): { [zona] = true }, y
-- cuánto da la mejor. Se recalcula solo cuando cambia el estado de los bloques.
local function flippedZones(nav, level)
    local cells = BotNav._switchCells(level)
    if #cells == 0 then return nil end
    local key = 0
    for _, k in ipairs(cells) do key = (key * 31 + level:getRaw(k[1], k[2])) % 2147483647 end
    -- (… y de CUÁL es la zona a la que ir ahora: se mueve de parada en parada)
    for _, a in ipairs(goalZones(level)) do key = (key * 31 + a.col0 * 131 + a.row0) % 2147483647 end
    if nav._flipKey == key then return nav._flip, nav._flipBest end
    local TileTypes = require 'src/world/tiles/TileTypes'
    local TileCodec = require 'src/world/tiles/TileCodec'
    for _, k in ipairs(cells) do
        local other = TileTypes.byName[k[4].switchBlock.other]
        local _, wet, spikes = TileCodec.decode(k[3])
        level.tiles[k[2]][k[1]] = TileCodec.encode(other.id, wet, spikes)
    end
    local set, best = {}, 0
    for _, a in ipairs(goalZones(level)) do
        if zoneNodes(nav, a, level) then set[a] = true; best = math.max(best, a.points or 1) end
    end
    for _, k in ipairs(cells) do level.tiles[k[2]][k[1]] = k[3] end
    nav._flipKey, nav._flip, nav._flipBest = key, set, best
    return set, best
end

-- ¿Le conviene pulsar un Activador ahora? → set de casillas desde las que pulsarlo (o nil)
function Bot:_switchPlan(level, target)
    if self.clock < (self.switchCd or 0) then return nil end
    local acts = activators(self.nav, level)
    if #acts == 0 then return nil end
    local flip, flipBest = flippedZones(self.nav, level)
    if not flip then return nil end
    local nowBest = 0
    for _, a in ipairs(goalZones(level)) do
        if a._nodes then nowBest = math.max(nowBest, a.points or 1) end
    end
    local pa = self.pa
    local mine = pa.onGround and areaOf(level, pa) or nil
    local theirs = target and not target.dying and areaOf(level, target)
    -- (a) pulsándolo habría una zona mejor que cualquiera de ahora (o ahora no hay ninguna con suelo)
    local want = flipBest > nowBest
    -- (b) tú puntúas en una zona que se quedaría sin suelo, él no está en ella y a él le queda otra igual o mejor
    if not want and theirs and theirs._nodes and not flip[theirs] and theirs ~= mine and flipBest >= nowBest and flipBest > 0 then want = true end
    if not want then return nil end
    local set = {}
    for _, a in ipairs(acts) do for id, how in pairs(a.press) do set[id] = how end end
    return set
end

-- ── AGUA QUE SUBE ─────────────────────────────────────────────────────────────
-- La altura (y) de la superficie del agua sobre ese punto
local function surfaceAt(level, x, y)
    for _, f in ipairs(level.floods or {}) do
        if x >= f.x0 and x < f.x1 and y >= f.surf and y < f.y1 then return f.surf end
    end
    return y
end

-- Dentro del agua de una inundación: los movimientos grabados no valen (otra física). Nada hacia la casilla SECA
-- más cercana (de su destino, si hay; si no, cualquiera): de lado y saltando; y si en `WATER_TRY` s no se acerca
-- — un foso del que no se sale con el agua alta —, se queda QUIETO esperando a que baje.
function Bot:_water(dt, level, goals)
    local pa = self.pa
    local w = self.wt
    if not w then w = { t = 0, best = math.huge, scan = 0, hold = 0 }; self.wt = w end
    self.path, self.edge, self.edgeF = nil, nil, 0
    local surf = surfaceAt(level, pa.x, pa.y)
    if w.wait then
        self.kind = 'wait'
        if surf > w.waitSurf + Bot.WATER_DROP or self.clock > w.waitUntil then w.wait, w.t, w.best = nil, 0, math.huge end
        return self:_emit(0)
    end
    self.kind = 'water'
    w.scan = w.scan - dt
    if w.scan <= 0 or not w.gx then
        w.scan = 0.5
        local bd
        w.gx, w.gy = nil, nil
        for pass = 1, 2 do                               -- primero lo seco de su destino; si no hay, cualquier casilla seca
            for id, n in pairs(self.nav.nodes) do
                if (pass == 2 or (goals and goals[id])) and n.y and not flooded(level, n.x, n.y) and level:isStandable(n.c, n.r) then
                    local d = math.abs(n.x - pa.x) + 2.5 * math.abs(n.y - pa.y)
                    if not bd or d < bd then bd, w.gx, w.gy = d, n.x, n.y end
                end
            end
            if w.gx then break end
        end
    end
    if not w.gx then return self:_emit(0) end
    local d = math.abs(w.gx - pa.x) + math.abs(w.gy - pa.y)
    if d < w.best - 12 then w.best, w.t = d, 0 else w.t = w.t + dt end
    if w.t > Bot.WATER_TRY then
        w.wait, w.waitSurf, w.waitUntil = true, surf, self.clock + Bot.WATER_WAIT
        self.kind = 'wait'
        return self:_emit(0)
    end
    local bits = 0
    local dx = w.gx - pa.x
    if math.abs(dx) > 10 then bits = (dx < 0) and L or R end
    w.still = (math.abs(pa.x - (w.lastX or pa.x)) < 0.3) and ((w.still or 0) + dt) or 0
    w.lastX = pa.x
    if pa.onGround then w.dbl = false end
    if pa.onGround and (w.gy < pa.y - 20 or w.still > 0.25) then
        bits, w.hold = bits + J + JP, 0.4                 -- salta (para subir o porque algo lo frena)
    elseif w.hold > 0 then
        bits, w.hold = bits + J, w.hold - dt
    elseif not pa.onGround and pa.vy > -40 and (pa.jumpsLeft or 0) > 0 and w.gy < pa.y - 30 and not w.dbl then
        bits, w.hold, w.dbl = bits + J + JP, 0.4, true     -- y el segundo salto en lo alto
    end
    return self:_emit(bits)
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
    -- ── PULSANDO un Activador: cabezazo desde abajo (salto, y el segundo en lo alto) o ground pound encima ──
    if self.mode == 'press' then
        self.pressT = self.pressT + dt
        if (pa.onGround and self.pressT > 0.2) or self.pressT > 1.6 then
            self.mode, self.path, self.switchCd = 'route', nil, self.clock + Bot.SWITCH_CD
            return self:_emit(0)
        end
        if self.pressHow == 'pound' then
            if self.pressT < 0.2 then bits = J elseif not pa.gpPhase then bits = C + CP end
        else
            bits = J
            if not pa.onGround and pa.vy > -60 and (pa.jumpsLeft or 0) > 0 and not self.pressDbl then
                bits, self.pressDbl = J + JP, true
            end
        end
        return self:_emit(bits)
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
    -- un movimiento grabado A MEDIAS se termina siempre, decida lo que decida después (si no, quedaba colgado al
    -- llegar a la zona y se reanudaba más tarde, fuera de sitio: se tiraba de la plataforma)
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
    local goals, kind = self:_goal(level, target)
    -- ACTIVADOR ON/OFF: si pulsarlo le conviene (y no está persiguiéndote), va a por él
    local press = (kind ~= 'hunt') and self:_switchPlan(level, target) or nil
    if press then
        local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
        if here and press[here] then
            local n = self.nav.nodes[here]
            if math.abs(n.x - pa.x) > 5 then return self:_emit((n.x < pa.x) and L or R) end
            if math.abs(pa.vx) > 25 then return self:_emit(0) end
            self.mode, self.pressT, self.pressHow, self.pressDbl = 'press', 0, press[here], false
            self.edge, self.edgeF, self.path = nil, 0, nil
            return self:_emit(J + JP)
        end
        goals, kind = press, 'switch'
    end
    -- AGUA de una inundación: nada hacia lo seco o espera a que baje (los movimientos grabados no valen ahí)
    if pa.inWater and flooded(level, pa.x, pa.y) then return self:_water(dt, level, goals) end
    self.wt = nil
    -- REBOTANDO sin tocar suelo (cayó sobre un Crabby trampolín, un trampolín...): en el aire no daba ninguna orden y
    -- se quedaba botando hasta que el Crabby se iba. Pasado un momento en el aire, tira hacia su destino para salirse.
    self.airT = pa.onGround and 0 or ((self.airT or 0) + dt)
    if self.airT > 0.9 then
        local gx
        for id in pairs(goals or {}) do local n = self.nav.nodes[id]; if n then gx = n.x; break end end
        if not gx then
            local z = Bot.pickZone(self.nav, level, pa.x, pa.y, self.clock)
            gx = z and (z.x0 + z.x1) / 2 or pa.x
        end
        if math.abs(gx - pa.x) < 40 then gx = pa.x + (self.airSide or 1) * 200 end       -- (justo debajo: a un lado)
        self.airSide = (gx < pa.x) and -1 or 1
        self.path = nil
        return self:_emit((gx < pa.x) and L or R)
    end
    -- cerca de ti y casi a tu altura: al ataque (estés o no en una zona, vaya adonde vaya)
    -- (puntuando en una zona solo ataca si tú estás en ELLA: no la deja por ti; y nunca sobre suelo rompible)
    local myZone = pa.onGround and areaOf(level, pa)
    if target and not target.dying and not target:isPushProtected() and pa.onGround and self.cd <= 0
       and (not myZone or areaOf(level, target) == myZone) and self:_canPound(level, target) and not breakableUnder(level, pa) then
        local dx, dy = target.x - pa.x, target.y - pa.y
        if math.abs(dx) < Bot.ATTACK_R * TILE_PX and dy > -1.6 * TILE_PX and dy < 0.8 * TILE_PX then
            self.mode, self.atkT = 'attack', 0
            self.edge, self.edgeF = nil, 0
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
            -- (solo casillas de SU misma fila: ir a otra altura lo sacaba de la zona por el camino)
            local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
            local row = here and self.nav.nodes[here].r
            for id in pairs(z._nodes) do if self.nav.nodes[id].r == row then list[#list + 1] = id end end
            if #list == 0 then list[1] = here end
            table.sort(list)
            self.roamTo, self.roamT = list[math.random(#list)], 2.5 + math.random() * 4
        end
        local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
        if not self.roamTo or here == self.roamTo then self.roamTo = nil; return self:_emit(0) end
        goals = { [self.roamTo] = true }
        kind = 'roam'
    end
    -- VAGAR: si su destino resultó inalcanzable (ver "SIN CAMINO" más abajo), anda un rato hacia otra casilla a la
    -- que SÍ sabe llegar, en vez de quedarse saltando en el sitio; perseguirte sigue teniendo prioridad
    if self.wander then
        local here = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h())
        if self.clock > self.wanderUntil or here == self.wander then self.wander = nil
        elseif kind ~= 'hunt' then goals, kind = { [self.wander] = true }, 'wander' end
    end
    self.kind = kind
    -- ── RUTA por el grafo ──
    self.planT = self.planT - dt
    local cur = pa.onGround and BotNav.nodeAt(self.nav, pa.x, pa.y, self:_h()) or nil
    if math.abs(pa.x - self.lastX) > 2 then self.stuckT, self.lastX = 0, pa.x else self.stuckT = self.stuckT + dt end
    if not cur and pa.onGround then self.path = nil end
    if cur and (not self.path or self.planT <= 0 or self.pathFrom ~= cur or self.stuckT > Bot.STUCK) then
        if self.stuckT > Bot.STUCK and self.path and self.path[1] then self:_fail(cur, self.path[1]) end
        self.path = BotNav.path(self.nav, cur, goals, nil, function(u, e)
            local b = self.banned[u * 1048576 + e.to]
            if b ~= nil and b > self.clock then return true end
            if kind == 'roam' and not e.walk then return true end      -- (paseando por la zona: solo andando)
            -- (el grafo junta los dos estados de los bloques ON/OFF: fuera lo que AHORA no tiene suelo)
            local n = self.nav.nodes[e.to]
            if n == nil or not level:isStandable(n.c, n.r) then return true end
            -- (ni lo que AHORA está bajo el agua de una inundación: ahí la física es otra y no se sale igual)
            return n.y ~= nil and flooded(level, n.x, n.y)
        end)
        self.pathFrom, self.planT, self.edge, self.edgeF = cur, Bot.REPLAN, nil, 0
        if self.stuckT > Bot.STUCK then self.stuckT = 0 end
    end
    local e = self.path and self.path[1]
    if e then self.noPathT = 0
    elseif kind ~= 'roam' and kind ~= 'hunt' then self.noPathT = (self.noPathT or 0) + dt end      -- (también en el aire: a lo bruto se pasa el rato saltando)
    if not e then
        if not pa.onGround then return self:_emit(self.escBits or 0) end
        -- (paseando por su zona y sin camino a esa casilla: se queda donde está; a lo bruto se salía de la zona)
        if kind == 'roam' then self.roamTo = nil; return self:_emit(0) end
        -- (no hay cómo llegar hasta ti — un hoyo, un bloque roto —: deja de perseguirte un rato y vuelve a su zona)
        if kind == 'hunt' then self.noHuntT = self.clock + 2.5; return self:_emit(0) end
        if kind == 'wander' then self.wander = nil; return self:_emit(0) end
        if kind == 'switch' then self.switchCd = self.clock + 3; return self:_emit(0) end      -- (no llega al Activador: lo deja)
        -- NUNCA se queda intentándolo sin fin (en cumbre_cangrejo se pasó la partida saltando en el sitio): tras
        -- `GIVE_UP` s sin camino, se va a VAGAR a una casilla alcanzable al azar y vuelve a probar después
        if self.noPathT > Bot.GIVE_UP and cur then
            self.noPathT = 0
            if not self.nav.ids then
                self.nav.ids = {}
                for id in pairs(self.nav.nodes) do self.nav.ids[#self.nav.ids + 1] = id end
                table.sort(self.nav.ids)
            end
            for _ = 1, 16 do
                local id = self.nav.ids[math.random(#self.nav.ids)]
                if id ~= cur and BotNav.path(self.nav, cur, { [id] = true }) then
                    self.wander, self.wanderUntil = id, self.clock + 4 + math.random() * 3
                    self.path = nil
                    return self:_emit(0)
                end
            end
        end
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
    -- (el movimiento se grabó desde el CENTRO exacto de la casilla: se coloca ahí — como mucho 5 px — y parado. Los
    -- saltos justos — 3 bloques de alto, huecos de 5 — fallaban por esos píxeles y lo dejaban fuera del grafo)
    pa.x, pa.vx = from.x, 0
    self.edge, self.edgeF, self.edgeFrom, self.edgeAir = e, 1, cur, false
    return self:_emit(BotNav.bitsAt(e, 1))
end

-- Descanso entre ataques: no siempre igual (× 0,8-1,6), para que no sea un metrónomo
function Bot:_rest() return self.attackCd * (0.7 + math.random() * 0.8) end

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
