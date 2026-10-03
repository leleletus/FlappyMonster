-- src/ai/BotNav.lua
-- NAVEGACIÓN de los bots (rivales del modo historia: las arenas de Rey de la Colina). Un GRAFO por nivel,
-- hecho con la física REAL del jugador (PlayerAdventure), sin aproximaciones:
--   nodos   = casillas donde se puede estar de pie (Level:isStandable): { c, r, x, y }
--   aristas = cómo ir de una a otra: 'walk' (a la de al lado, misma fila) o un MOVIMIENTO grabado (saltar, doble
--             salto, dejarse caer, bajar de una plataforma...): la lista de inputs por fotograma (bits del
--             Protocol, comprimidos en tramos) que, desde quieto en el centro de su casilla, lleva a otra
--   Se construye una vez por nivel, FUERA del juego (tools/tests/bot_nav BUILD=1 → assets/nav/<nivel>.json:
--   simular ~27 movimientos desde cada casilla es demasiado para hacerlo al cargar) y el juego solo lo lee.
--   Si el nivel cambia (otro `sig`), el harness lo avisa y hay que reconstruirlo.
--   BotNav.build(level)            → grafo (lento: segundos)
--   BotNav.load(name, level)       → grafo o nil (sin archivo o de otra versión del nivel)
--   BotNav.nodeAt(g, x, y)         → nodo donde está algo de pie en (x, y) (o el más cercano de esa fila)
--   BotNav.path(g, from, goals[, avoid, skip]) → lista de aristas (Dijkstra por fotogramas) hasta cualquiera de
--                                  `goals`; skip(u, e) = true descarta una arista (las que el bot vio fallar)
local P = require 'src/network/Protocol'
local json = require 'libs/json'

local BotNav = { VERSION = 2, DIR = 'assets/nav/' }

local T = function() return TILE_PX end
local DT = 1 / 60

-- ── Firma del nivel (para saber si el grafo está al día) ──────────────────────
function BotNav.signature(level)
    local h = 0
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            h = (h * 31 + (level:getRaw(c, r) or 0) % 1000003) % 2147483647
        end
    end
    return tostring(h) .. ':' .. level.tileW .. 'x' .. level.tileH
end

-- ── Movimientos (bits por fotograma) ──────────────────────────────────────────
local L, R, J, JP, C, CP = P.IN_LEFT, P.IN_RIGHT, P.IN_JUMP, P.IN_JUMP_P, P.IN_CROUCH, P.IN_CROUCH_P
local MAXF = 150

-- d = -1/0/1, hold = fotogramas con el salto pulsado, dirFrom/dirTo = cuándo se mantiene la dirección,
-- dbl = fotograma del 2º salto (nil = sin), dropThrough = agacharse para bajar de una plataforma
local function macro(d, hold, dirFrom, dirTo, dbl, kind)
    local bits = {}
    for f = 0, MAXF - 1 do
        local b = 0
        if kind == 'walkoff' then
            b = (d < 0) and L or R
        elseif kind == 'drop' then
            b = C + (f == 0 and CP or 0)
        else
            if f < hold then b = b + J + (f == 0 and JP or 0) end
            if dbl and f >= dbl and f < dbl + 24 then b = b + J + (f == dbl and JP or 0) end
            if d ~= 0 and f >= dirFrom and f < dirTo then b = b + ((d < 0) and L or R) end
        end
        bits[f + 1] = b
    end
    return bits
end

local MACROS
local PENALTY = {}             -- movimiento → coste extra (los arriesgados: último recurso)
local function macros()
    if MACROS then return MACROS end
    MACROS = {}
    local function add(m) MACROS[#MACROS + 1] = m end
    for _, d in ipairs({ -1, 1 }) do
        add(macro(d, 0, 0, MAXF, nil, 'walkoff'))
        for _, hold in ipairs({ 6, 30 }) do
            for _, dirTo in ipairs({ MAXF, 14 }) do
                add(macro(d, hold, 0, dirTo))
                add(macro(d, hold, 0, dirTo, 18))
            end
        end
        add(macro(d, 30, 12, MAXF))                   -- sube recto y luego se mete (borde de arriba)
        add(macro(d, 30, 12, MAXF, 18))
        add(macro(d, 30, 26, MAXF, 20))               -- doble salto alto y luego de lado
        add(macro(d, 30, 30, MAXF, 28))               -- el 2º salto en lo más alto: lo máximo que sube (3 casillas)
        add(macro(d, 30, 36, MAXF, 34))
        add(macro(d, 30, 0, MAXF, 28))
        -- (v2) el 2º salto EXACTO en lo más alto (cuadro 21): los 3 bloques justos — con el de antes (28) se quedaba
        -- a 2 px y en cumbre_cangrejo el bot no subía nunca a las plataformas: saltaba sin parar en el sitio
        add(macro(d, 30, 24, MAXF, 21))
        add(macro(d, 30, 32, MAXF, 21))
        -- (v2) saltos LARGOS: el 2º salto tarde, casi al volver a la altura de salida (huecos de 5 casillas: en
        -- cumbre_cangrejo es la única forma de pasar de los salientes a las plataformas). Son JUSTOS — en
        -- isla_flotante el bot falló uno y cayó fuera del grafo —, así que cuestan mucho: solo se usan si no hay otra ruta
        for _, at in ipairs({ 36, 41 }) do
            local m = macro(d, 30, 0, MAXF, at)
            PENALTY[m] = 400
            add(m)
        end
    end
    for _, hold in ipairs({ 6, 30 }) do
        add(macro(0, hold, 0, 0))
        add(macro(0, hold, 0, 0, 18))
    end
    add(macro(0, 30, 0, 0, 21))                       -- (v2) recto hacia arriba, lo máximo
    add(macro(0, 0, 0, 0, nil, 'drop'))
    return MACROS
end

local function rle(bits, n)
    local out, last, cnt = {}, nil, 0
    for i = 1, n do
        if bits[i] == last then cnt = cnt + 1
        else
            if last then out[#out + 1] = { last, cnt } end
            last, cnt = bits[i], 1
        end
    end
    if last then out[#out + 1] = { last, cnt } end
    return out
end

-- bits del fotograma f (1..) de una arista grabada
function BotNav.bitsAt(edge, f)
    local k = 0
    for _, run in ipairs(edge.seq) do
        k = k + run[2]
        if f <= k then return run[1] end
    end
    return 0
end

-- ── Nodos ─────────────────────────────────────────────────────────────────────
local function nodeId(c, r) return r * 4096 + c end

local function feetRow(pa)
    local ob = pa:getOuterBounds()
    return math.floor((ob.y + ob.h - 2) / TILE_PX) + 1
end

function BotNav.nodeAt(g, x, y, h)
    local c = math.floor(x / TILE_PX) + 1
    local r = math.floor((y + (h or 0) / 2 - 2) / TILE_PX) + 1
    if g.nodes[nodeId(c, r)] then return nodeId(c, r) end
    for _, dc in ipairs({ -1, 1 }) do
        if g.nodes[nodeId(c + dc, r)] then return nodeId(c + dc, r) end
    end
    return nil
end

-- ── Construcción (física real) ────────────────────────────────────────────────
-- Bloques ON/OFF (switchBlock): el grafo se hace con todos ACTIVOS y con todos INACTIVOS y se juntan (el
-- bot no sabe en qué estado estarán; si una arista no vale ahora, se atasca, la penaliza y replanea)
local function switchCells(level)
    local TileTypes = require 'src/world/tiles/TileTypes'
    local TileCodec = require 'src/world/tiles/TileCodec'
    local out = {}
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            local raw = level:getRaw(c, r)
            local def = TileTypes.get(TileCodec.id(raw))
            if def and def.switchBlock then out[#out + 1] = { c, r, raw, def } end
        end
    end
    return out
end

local function setSwitches(level, cells, active)
    local TileTypes = require 'src/world/tiles/TileTypes'
    local TileCodec = require 'src/world/tiles/TileCodec'
    for _, k in ipairs(cells) do
        local c, r, raw, def = k[1], k[2], k[3], k[4]
        local want = (def.switchBlock.active == active) and def or TileTypes.byName[def.switchBlock.other]
        local _, wet, spikes = TileCodec.decode(raw)
        level.tiles[r][c] = TileCodec.encode(want.id, wet, spikes)
    end
end

BotNav._switchCells, BotNav._setSwitches = switchCells, setSwitches

function BotNav.build(level, opts)
    local cells = switchCells(level)
    if #cells == 0 then return BotNav.buildOne(level, opts) end
    setSwitches(level, cells, true)
    local a = BotNav.buildOne(level, opts)
    setSwitches(level, cells, false)
    local b = BotNav.buildOne(level, opts)
    for _, k in ipairs(cells) do level.tiles[k[2]][k[1]] = k[3] end
    a.sig = BotNav.signature(level)
    for id, n in pairs(b.nodes) do a.nodes[id] = a.nodes[id] or n end
    for id, list in pairs(b.edges) do
        local mine = a.edges[id] or {}
        a.edges[id] = mine
        for _, e in ipairs(list) do
            local found
            for _, f in ipairs(mine) do if f.to == e.to then found = f end end
            if not found then mine[#mine + 1] = e elseif e.cost < found.cost then found.cost, found.seq, found.walk = e.cost, e.seq, e.walk end
        end
    end
    a.stats.nodes, a.stats.steps = a.stats.nodes + b.stats.nodes, a.stats.steps + b.stats.steps
    return a
end

function BotNav.buildOne(level, opts)
    opts = opts or {}
    local PlayerAdventure = require 'src/entities/PlayerAdventure'
    local stub = P.newInputStub()
    local realInput, realSound = Input, Sound
    Sound = setmetatable({}, { __index = function() return function() end end })
    Input = stub
    local g = { version = BotNav.VERSION, sig = BotNav.signature(level), nodes = {}, edges = {} }
    -- (el nivel NO cambia mientras se simula: ni bloques rotos ni Activadores pulsados por los saltos de prueba)
    local canBreak = level.canBreak
    level.canBreak = false
    for r = 2, level.tileH - 1 do
        for c = 2, level.tileW - 1 do
            if level:isStandable(c, r) then
                g.nodes[nodeId(c, r)] = { c = c, r = r, x = (c - 0.5) * TILE_PX }
            end
        end
    end
    local pa = PlayerAdventure:new(0, 0)
    level.players = { pa }
    -- objetos SÓLIDOS del nivel (trampolines, morteros): con sus caras de rebote. Un trampolín siempre "listo"
    -- (se pregunta su interact, sin gastarlo); en la partida, si está recargando, la arista falla y se descarta
    local Entities = require 'src/world/Entities'
    local bodies = {}
    for _, pl in ipairs(level.entities or {}) do
        local ok, e = pcall(Entities.create, pl)
        if ok and e and e.solidFull then bodies[#bodies + 1] = e end
    end
    level.solidBodies = bodies
    local function step()
        pa:update(DT, level)
        for _, e in ipairs(bodies) do
            if e.interact then
                local res, vx, vy, jumps = e:interact(pa)
                if res == 'launch' then pa:launch(vx, vy, jumps) end
            end
        end
    end
    local h = pa:getOuterBounds().h
    local count, steps = 0, 0
    for id, n in pairs(g.nodes) do
        -- estado de partida: quieto en el centro de su casilla, ya asentado
        -- (se deja caer desde un poco más arriba: empezar con la caja metida en el suelo lo atravesaba)
        pa.x, pa.y, pa.vx, pa.vy = n.x, (n.r - 1) * TILE_PX - 12, 0, 0
        pa.onGround, pa.jumpsLeft, pa.dying, pa.alive = false, 2, false, true
        P.decodeInput(0, stub.state)
        for _ = 1, 40 do step() end
        if pa.onGround and feetRow(pa) == n.r then
            n.y = pa.y
            local s0 = P.packOwnState(pa)
            local out = {}
            g.edges[id] = out
            -- caminar a la de al lado (sin simular: la ejecución lo corrige en bucle cerrado)
            for _, dc in ipairs({ -1, 1 }) do
                local to = nodeId(n.c + dc, n.r)
                if g.nodes[to] then out[#out + 1] = { to = to, cost = math.ceil(TILE_PX / ADV_MOVE_SPD * 60), walk = dc } end
            end
            -- movimientos grabados
            local best = {}
            -- un movimiento desde `dx` px del centro de la casilla → fotograma en que aterriza y dónde
            local function try(bits, dx)
                P.applyOwnState(s0, pa)
                pa.x = pa.x + dx
                pa.dying, pa.alive = false, true
                local air = false
                for f = 1, MAXF do
                    P.decodeInput(bits[f], stub.state)
                    step()
                    steps = steps + 1
                    if pa.dying or pa.alive == false or (pa.hurtT or 0) > 0 then return nil end
                    if not pa.onGround then air = true
                    elseif air and f > 3 then
                        return f, BotNav.nodeAt(g, pa.x, pa.y, h)
                    end
                end
            end
            for _, bits in ipairs(macros()) do
                local landed, to = try(bits, 0)
                if landed then
                    if to and to ~= id then
                        local cost = landed + 6 + (PENALTY[bits] or 0)
                        if not best[to] or cost < best[to].cost then
                            best[to] = { to = to, cost = cost, seq = rle(bits, landed) }
                        end
                    end
                end
            end
            for _, e in pairs(best) do out[#out + 1] = e end
            count = count + 1
        else
            g.nodes[id] = nil
        end
    end
    for id, list in pairs(g.edges) do
        for i = #list, 1, -1 do if not g.nodes[list[i].to] then table.remove(list, i) end end
    end
    Input, Sound = realInput, realSound
    level.canBreak = canBreak
    level.solidBodies = nil
    g.stats = { nodes = count, steps = steps }
    return g
end

-- ── Archivo ───────────────────────────────────────────────────────────────────
function BotNav.encode(g)
    local nodes, edges = {}, {}
    for id, n in pairs(g.nodes) do nodes[#nodes + 1] = { id, n.c, n.r, math.floor(n.x), math.floor(n.y or 0) } end
    for id, list in pairs(g.edges) do
        for _, e in ipairs(list) do edges[#edges + 1] = { id, e.to, e.cost, e.walk or 0, e.seq or 0 } end
    end
    table.sort(nodes, function(a, b) return a[1] < b[1] end)
    table.sort(edges, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    return json.encode({ version = g.version, sig = g.sig, nodes = nodes, edges = edges })
end

function BotNav.decode(text)
    local ok, d = pcall(json.decode, text)
    if not ok or type(d) ~= 'table' or d.version ~= BotNav.VERSION then return nil end
    local g = { version = d.version, sig = d.sig, nodes = {}, edges = {} }
    for _, n in ipairs(d.nodes) do g.nodes[n[1]] = { c = n[2], r = n[3], x = n[4], y = n[5] } end
    for _, e in ipairs(d.edges) do
        local list = g.edges[e[1]] or {}
        g.edges[e[1]] = list
        list[#list + 1] = { to = e[2], cost = e[3], walk = (e[4] ~= 0) and e[4] or nil, seq = (type(e[5]) == 'table') and e[5] or nil }
    end
    return g
end

function BotNav.load(name, level)
    local ok, text = pcall(love.filesystem.read, BotNav.DIR .. name .. '.json')
    if not ok or not text then return nil end
    local g = BotNav.decode(text)
    if g and level and g.sig ~= BotNav.signature(level) then g.stale = true end
    return g
end

-- ── Camino más corto (en fotogramas) a cualquiera de `goals` (set de ids) ────
function BotNav.path(g, from, goals, avoid, skip)
    if not from or not g.nodes[from] then return nil end
    if goals[from] then return {} end
    local dist, prev, prevE = { [from] = 0 }, {}, {}
    local open = { from }
    while #open > 0 do
        -- (pocos cientos de nodos: búsqueda lineal del mínimo, sin montículo)
        local bi, bd = 1, dist[open[1]]
        for i = 2, #open do if dist[open[i]] < bd then bi, bd = i, dist[open[i]] end end
        local u = table.remove(open, bi)
        if goals[u] then
            local list, v = {}, u
            while v ~= from do table.insert(list, 1, prevE[v]); v = prev[v] end
            return list, bd
        end
        for _, e in ipairs(g.edges[u] or {}) do
          if not (skip and skip(u, e)) then
            local nd = bd + e.cost + ((avoid and avoid[e.to]) or 0)
            if not dist[e.to] or nd < dist[e.to] then
                if not dist[e.to] then open[#open + 1] = e.to end
                dist[e.to], prev[e.to], prevE[e.to] = nd, u, e
            end
          end
        end
    end
    return nil
end

return BotNav
