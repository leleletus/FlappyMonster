-- tools/tests/level_solve — ¿se puede llegar a la meta (o a la zona de puntos)
-- con la física REAL del jugador? Búsqueda en anchura sobre estados del
-- jugador (packOwnState/applyOwnState) con acciones de 6 pasos. Ignora
-- enemigos y trampolines: solo terreno (pinchos, agua y aire sí cuentan).
--
--   xvfb-run -a love tools/tests/level_solve assets/levels/x.json [x.json ...]
-- Resultado por nivel: OK (con nº de pasos) o FALLA + la columna más lejana.
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
Input = stub
local json = require 'libs/json'
local Level = require 'src/world/Level'
local PlayerAdventure = require 'src/entities/PlayerAdventure'

local DT, K = 1 / 60, 6
local NODROWN = os.getenv('NODROWN')    -- (sin ahogarse: ¿el terreno se puede recorrer?)
local ACTIONS = {}
for _, d in ipairs({ -1, 0, 1 }) do
    for _, j in ipairs({ false, true }) do
        for _, c in ipairs(os.getenv('NOCROUCH') and { false } or { false, true }) do ACTIONS[#ACTIONS + 1] = { d = d, j = j, c = c } end
    end
end

local function targets(level, data)
    local T, list = TILE_PX, {}
    for r = 1, level.tileH do
        for c = 1, level.tileW do
            if level:getDef(c, r).trigger == 'finish' then list[#list + 1] = { (c - 0.5) * T, (r - 0.5) * T } end
        end
    end
    local kind = 'meta'
    if #list == 0 then
        kind = 'zona'
        for _, e in ipairs(data.entities or {}) do
            if e.type == 'pointarea' then
                local c2 = e.props and e.props.corner or { col = e.col, row = e.row }
                list[#list + 1] = { ((e.col + c2.col) / 2 - 0.5) * T, ((e.row + c2.row) / 2 - 0.5) * T }
            end
        end
    end
    return list, kind
end

local function solve(path)
    local data = json.decode(love.filesystem.read(path))
    data.bossZones = nil                        -- las arenas de jefe se ignoran (solo terreno)
    data.autoScroll = nil                       -- la cámara automática no cuenta: solo el terreno
    local level = Level.fromData(data)
    local tramps = {}
    for _, e in ipairs(data.entities or {}) do
        local d = e.type:match('^trampoline_?(%a*)$')
        if d then
            local T = TILE_PX
            tramps[#tramps + 1] = { dir = d == '' and 'up' or d, cx = (e.col - 0.5) * T, cy = (e.row - 0.5) * T,
                power = (e.props and e.props.power) or 1.75 }
        end
    end
    local pa = PlayerAdventure:new((data.playerStart[1] - 0.5) * TILE_PX, (data.playerStart[2] - 0.5) * TILE_PX)
    level.players = { pa }
    local goals, kind = targets(level, data)
    local explore = os.getenv('EXPLORE')
    if #goals == 0 and not explore then return false, 'sin meta ni zona', 0 end
    local function near(pa)
        if explore then return false end
        for _, g in ipairs(goals) do
            if math.abs(pa.x - g[1]) < TILE_PX * 0.9 and math.abs(pa.y - g[2]) < TILE_PX * 1.6 then return true end
        end
    end
    local function key(pa)
        return table.concat({ math.floor(pa.x / (explore and 24 or 14)), math.floor(pa.y / (explore and 24 or 14)), pa.onGround and 1 or 0,
            pa.jumpsLeft, math.floor(pa.vy / 260), math.floor(pa.vx / 120), pa.crouching and 1 or 0,
            math.floor((pa.drownTimer or 0) / 3),          -- (con más aire no es el mismo estado)
            pa.gpPhase == 'windup' and 1 or (pa.gpPhase == 'fall' and 2 or 0), math.floor((pa.dropHoldT or 0) * 8), pa.dropping and 1 or 0 }, ',')
    end
    local s0 = P.packOwnState(pa)
    -- Heurística: distancia POR LOS HUECOS hasta la meta (BFS de casillas no
    -- sólidas desde ella), no en línea recta: en un laberinto la recta apunta a
    -- las paredes. HDIST=0 vuelve a la línea recta.
    local T = TILE_PX
    local dist = {}
    if not explore and os.getenv('HDIST') ~= '0' then
        local q, head = {}, 1
        for _, g in ipairs(goals) do
            local c, r = math.floor(g[1] / T) + 1, math.floor(g[2] / T) + 1
            local k = r * 4096 + c
            if not dist[k] then dist[k] = 0; q[#q + 1] = { c, r } end
        end
        while head <= #q do
            local c, r = q[head][1], q[head][2]; head = head + 1
            local d = dist[r * 4096 + c]
            for _, n in ipairs({ { c + 1, r }, { c - 1, r }, { c, r + 1 }, { c, r - 1 } }) do
                local nc, nr = n[1], n[2]
                if nc >= 1 and nr >= 1 and nc <= level.tileW and nr <= level.tileH and not dist[nr * 4096 + nc]
                   and level:getDef(nc, nr).collision ~= 'solid' then
                    dist[nr * 4096 + nc] = d + 1; q[#q + 1] = { nc, nr }
                end
            end
        end
    end
    local function h(x, y)
        if explore then return 0 end
        local d = dist[(math.floor(y / T) + 1) * 4096 + math.floor(x / T) + 1]
        if d then return d * T end
        local m = 1e9
        for _, g in ipairs(goals) do m = math.min(m, math.abs(x - g[1]) * 0.5 + math.abs(y - g[2]) * (tonumber(os.getenv("HWY")) or 1.5)) end
        return m
    end
    -- montículo mínimo por prioridad
    local heap = {}
    local function push(item)
        heap[#heap + 1] = item
        local i = #heap
        while i > 1 do
            local p = math.floor(i / 2)
            if heap[p][3] <= heap[i][3] then break end
            heap[p], heap[i] = heap[i], heap[p]; i = p
        end
    end
    local function pop()
        local top = heap[1]
        local last = table.remove(heap)
        if #heap > 0 then
            heap[1] = last
            local i = 1
            while true do
                local l, r, m = i * 2, i * 2 + 1, i
                if l <= #heap and heap[l][3] < heap[m][3] then m = l end
                if r <= #heap and heap[r][3] < heap[m][3] then m = r end
                if m == i then break end
                heap[m], heap[i] = heap[i], heap[m]; i = m
            end
        end
        return top
    end
    local seen = { [key(pa)] = true }
    push({ s0, 0, h(pa.x, pa.y) })
    local bestInfo
    local visited, bestH, bestC, bestR = {}, nil, nil, nil
    local best, maxN, pops = 0, tonumber(os.getenv('MAXN')) or 60000, 0
    while #heap > 0 and pops < maxN do
        local node = pop(); pops = pops + 1
        for _, a in ipairs(ACTIONS) do
            P.applyOwnState(node[1], pa)
            pa.alive = true; pa.dying = false
            local st = Input.state
            local ok = true
            for f = 1, K do
                st.left, st.right, st.crouch = a.d < 0, a.d > 0, a.c
                st.jump = a.j
                st.jump_pressed = a.j and f == 1
                st.crouch_pressed = a.c and f == 1
                local before = pa.y + pa:getOuterBounds().h / 2
                if NODROWN then pa.drownTimer, pa.drownPhase, pa.drownAudT = 0, 'none', 0 end
                pa:update(DT, level)
                -- trampolines (emulación: solo terreno + lanzamiento)
                for _, t in ipairs(tramps) do
                    local ob = pa:getOuterBounds()
                    local T = TILE_PX
                    local bottom = ob.y + ob.h
                    local px = ob.x + ob.w / 2
                    if t.dir == 'up' then
                        if pa.vy > 120 and math.abs(px - t.cx) < T * 0.5 + ob.w / 2 - 6
                           and bottom >= t.cy - T / 2 - 6 and before <= t.cy - T / 2 + 10 and bottom <= t.cy + T / 2 then
                            pa.y = pa.y - (bottom - (t.cy - T / 2)); pa:launch(0, -math.abs(ADV_JUMP_VEL) * t.power)
                        end
                    else
                        local Pw = math.abs(ADV_JUMP_VEL) * t.power
                        local inY = ob.y < t.cy + T / 2 - 8 and ob.y + ob.h > t.cy - T / 2 + 8
                        if t.dir == 'right' and inY and ob.x <= t.cx + T / 2 and ob.x >= t.cx + T / 2 - 14 and a.d < 0 then
                            pa:launch(Pw * 0.85, -380)
                        elseif t.dir == 'left' and inY and ob.x + ob.w >= t.cx - T / 2 and ob.x + ob.w <= t.cx - T / 2 + 14 and a.d > 0 then
                            pa:launch(-Pw * 0.85, -380)
                        elseif t.dir == 'down' then
                        end
                    end
                end
                if pa.dying or not pa.alive or pa.drownPhase == 'dead' then ok = false; break end
            end
            if ok then
                if pa.x > best then best = pa.x end
                local hh = h(pa.x, pa.y); if hh < (bestH or 1e9) then bestH = hh; bestC, bestR = math.floor(pa.x / TILE_PX) + 1, math.floor(pa.y / TILE_PX) + 1; bestInfo = ('x=%.0f y=%.0f vx=%.0f vy=%.0f gnd=%s water=%s jl=%s'):format(pa.x, pa.y, pa.vx, pa.vy, tostring(pa.onGround), tostring(pa.inWater), tostring(pa.jumpsLeft)) end
                if near(pa) then return true, kind, node[2] + 1 end
                visited[(math.floor(pa.y / TILE_PX) + 1) * 1000 + math.floor(pa.x / TILE_PX) + 1] = true
                local k = key(pa)
                if not seen[k] then seen[k] = true; push({ P.packOwnState(pa), node[2] + 1, h(pa.x, pa.y) + (node[2] + 1) * 4 }) end
            end
        end
    end
    if os.getenv('DUMP') then
        for r = 1, level.tileH do
            local line = {}
            for c = 1, level.tileW do
                local d = level:getDef(c, r)
                line[#line + 1] = visited[r * 1000 + c] and 'o' or (d.collision == 'solid' and '#' or (level:isWaterAt((c - 0.5) * TILE_PX, (r - 0.5) * TILE_PX) and '~' or '.'))
            end
            print(table.concat(line))
        end
    end
    if explore then
        local miss, total = {}, 0
        for _, e in ipairs(data.entities or {}) do
            local d = e.type
            if d:match('^gummy') or d:match('^crabby') or d == 'gloomy' or d == 'bomb' or d == 'star' or d == 'extralife' or d == 'checkpoint' or d == 'mortar' then
                total = total + 1
                local ok = false
                for dr = -2, 2 do for dc = -1, 1 do
                    if visited[(e.row + dr) * 1000 + e.col + dc] then ok = true end
                end end
                if not ok then miss[#miss + 1] = ('%s(%d,%d)'):format(d, e.col, e.row) end
            end
        end
        print(('EXPLORE %s: %d/%d entidades alcanzables; %d estados. Fuera de alcance: %s'):format(path, total - #miss, total, pops, table.concat(miss, ' ')))
        return #miss == 0, 'explorar', 0
    end
    return false, kind, ('mas cerca en (%s,%s) [%s]'):format(bestC, bestR, bestInfo), pops
end

function love.load(arg)
    local files = {}
    for i = 1, #arg do if arg[i]:match('%.json$') then files[#files + 1] = arg[i] end end
    local bad = 0
    for _, f in ipairs(files) do
        local t0 = love.timer.getTime()
        local ok, kind, n, q = solve(f)
        if ok then print(('OK    %-40s → %s en %d acciones (%.1fs)'):format(f, kind, n, love.timer.getTime() - t0))
        else bad = bad + 1; print(('FALLA %-40s → %s; columna más lejana %s, %s estados'):format(f, kind, tostring(n), tostring(q))) end
    end
    love.event.quit(bad > 0 and 1 or 0)
end
