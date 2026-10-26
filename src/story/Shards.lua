-- src/story/Shards.lua
-- LOS FRAGMENTOS DEL ESPEJO (historia "El Espejo Roto", docs/historia/HISTORIA.md). Cada jefe guarda uno:
-- al vencerlo lo SUELTA, el jugador lo recoge y queda en su partida (Run.addShard). Con los siete, el final.
-- Con dos jefes por arena (`bossExtra`: Xtra extremo hasta 0.5.23; hoy ninguna dificultad) cada uno suelta MEDIO
-- fragmento ('3a' el original, '3b' la copia).
--   Shards.LEVEL[nivel] = nº de fragmento       Shards.ids(n, xtra) → { '3' } | { '3a', '3b' }
--   Shards.count(data) → tengo, total           Shards.pending(nivel, data) → los que faltan de ese nivel
--   Shards.drops(state, def) → el gestor dentro de un nivel (AdventureState: args.shards = def)
--     def = { ids = { ... }, onGet = function(id) end, final = bool }
-- Solo existe en el modo historia de un jugador (no es parte de la simulación compartida: no toca la física
-- de nadie; el fragmento flota y se recoge al tocarlo).
local Difficulty = require 'src/core/Difficulty'

local Shards = {}

Shards.TOTAL = 7
-- (el orden de la historia: assets/images/story/mirror/shard_<n>.png)
Shards.LEVEL = {
    reino_gummy = 1, cala_resaca = 2, fortaleza_malvada = 3, lago_helado = 4,     -- (2: el Pez Globo Gigante; antes el Mega Crabby)
    glaciar_cangrejo = 5, gruta_del_farol = 6, ruta_del_espejo = 7,                -- (6: el Saltarín Gigante; antes el Mega Crabby lúgubre)
}
Shards.FINAL = 7

function Shards.isXtra(difficulty) return Difficulty.of(difficulty, 'bossExtra', false) == true end

function Shards.ids(n, xtra)
    if xtra then return { n .. 'a', n .. 'b' } end
    return { tostring(n) }
end

-- Los que tiene la partida, en orden, y cuántos son en total (7; Xtra extremo: 14 mitades)
function Shards.owned(data)
    local out, xtra = {}, Shards.isXtra(data.difficulty)
    for n = 1, Shards.TOTAL do
        for _, id in ipairs(Shards.ids(n, xtra)) do
            if data.shards and data.shards[id] then out[#out + 1] = id end
        end
    end
    return out, Shards.TOTAL * (xtra and 2 or 1)
end
function Shards.count(data)
    local list, total = Shards.owned(data)
    return #list, total
end

-- Los fragmentos de ese nivel que aún no tiene la partida
function Shards.pending(levelId, data)
    local n = Shards.LEVEL[levelId]
    local out = {}
    if not n then return out end
    for _, id in ipairs(Shards.ids(n, Shards.isXtra(data.difficulty))) do
        if not (data.shards and data.shards[id]) then out[#out + 1] = id end
    end
    return out
end

-- Partidas de antes de que existieran los fragmentos: los de los jefes ya vencidos se dan por recogidos
function Shards.migrate(data)
    if type(data.shards) == 'table' then
        -- (las MITADES de cuando Xtra extremo tenía dos jefes por arena — hasta 0.5.23 —: si su dificultad ya no
        --  los pone, cada mitad recogida cuenta como el fragmento entero: para acabar el nivel había que vencer a los dos)
        if not Shards.isXtra(data.difficulty) then
            for n = 1, Shards.TOTAL do
                local a, b = n .. 'a', n .. 'b'
                if data.shards[a] or data.shards[b] then data.shards[tostring(n)] = true end
                data.shards[a], data.shards[b] = nil, nil
            end
        end
        return
    end
    data.shards = {}
    local xtra = Shards.isXtra(data.difficulty)
    for level, n in pairs(Shards.LEVEL) do
        if data.done and data.done[level] then
            for _, id in ipairs(Shards.ids(n, xtra)) do data.shards[id] = true end
        end
    end
end

-- ── Dentro de un nivel ──────────────────────────────────────────────────────
local Drops = {}
Drops.__index = Drops

local RISE_T = 0.7          -- s que tarda en salir del jefe y quedarse flotando
local HOME_T = 5            -- s flotando antes de ir él solo hacia el jugador
local HOME_SPD = 300
local TOUCH = 46            -- px (medio lado de su caja)

function Shards.drops(state, def)
    return setmetatable({ state = state, ids = def.ids or {}, onGet = def.onGet, final = def.final, auto = def.auto,
                          next = 1, list = {}, seen = {}, got = 0 }, Drops)
end

function Drops:remaining() return #self.ids - self.got end
function Drops:allGot() return #self.ids > 0 and self.got >= #self.ids end
-- ¿Jefes vencidos y fragmentos recogidos? (todos los jefes del nivel han caído — o soltado su zona — y no queda
-- ningún fragmento suyo por recoger; si la partida ya los tenía, basta con vencerlos)
function Drops:cleared()
    if not self.bosses or #self.bosses == 0 then return false end
    for _, e in ipairs(self.bosses) do if self.seen[e] ~= 'dropped' then return false end end
    return #self.list == 0 and self.got >= #self.ids
end

-- Un fragmento sale de (x, y): sube en arco (hacia `dir`, lanzado) y se queda flotando
function Drops:spawn(x, y, dir)
    local id = self.ids[self.next]
    if not id then return end
    self.next = self.next + 1
    -- (lanzado: `dir` = hacia dónde, más lejos y más alto; si no, sube a un lado)
    local side = (dir and dir ~= 0) and dir or ((#self.list % 2 == 0) and -1 or 1)
    local far = (dir and dir ~= 0) and 200 or 60
    self.list[#self.list + 1] = { id = id, x0 = x, y0 = y, x = x, y = y, tx = x + side * far, ty = y - 110, t = 0 }
    Sound.playAt('shardDrop', x, y)
end

function Drops:update(dt)
    local st = self.state
    -- cada jefe que cae suelta el suyo (el original primero: en Xtra extremo, su mitad 'a')
    -- (los jefes se apuntan al empezar: el nivel quita de su lista a los que mueren)
    if not self.bosses then
        self.bosses = {}
        for _, e in ipairs(st.enemies or {}) do
            if e.def and e.def.category == 'Jefes' then self.bosses[#self.bosses + 1] = e end
        end
    end
    for _, e in ipairs(self.bosses) do
        do
            -- (cuándo lo suelta lo dice el jefe — Boss:shardDrop —: los que huyen, por el camino; sale LANZADO hacia
            --  el centro de su zona, de donde se va)
            local gone = (not e.alive) or (e.releasesZone and e:releasesZone())
            local drop = (e.shardDrop and e:shardDrop()) or (not e.shardDrop and gone)
            if not self.seen[e] then
                if not gone then self.seen[e] = 'alive' end
            elseif self.seen[e] == 'alive' and drop then
                self.seen[e] = 'dropped'
                local z = e.zone
                local dir = z and (((z.x0 + z.x1) / 2 < e.x) and -1 or 1) or 0
                self:spawn(e.x, e.y - (e.outerH or 0) * 0.3, dir)
            end
        end
    end
    local p = st.player
    for i = #self.list, 1, -1 do
        local s = self.list[i]
        s.t = s.t + dt
        if s.t < RISE_T then
            local u = s.t / RISE_T
            s.x = s.x0 + (s.tx - s.x0) * u
            s.y = s.y0 + (s.ty - s.y0) * u - math.sin(u * math.pi) * 80
        else
            if s.t > HOME_T and p and not p.dying then               -- nadie lo recoge: va él
                local dx, dy = p.x - s.tx, p.y - s.ty
                local d = math.sqrt(dx * dx + dy * dy)
                if d > 1 then
                    local step = math.min(d, HOME_SPD * dt)
                    s.tx, s.ty = s.tx + dx / d * step, s.ty + dy / d * step
                end
            end
            s.x, s.y = s.tx, s.ty + math.sin(s.t * 3) * 8
        end
        if p and not p.dying and s.t > 0.35 then
            local ob = p:getOuterBounds()
            if ob.x < s.x + TOUCH and ob.x + ob.w > s.x - TOUCH and ob.y < s.y + TOUCH and ob.y + ob.h > s.y - TOUCH then
                table.remove(self.list, i)
                self.got = self.got + 1
                Sound.play('shardGet')
                require('src/fx/Particles').emit('collect', s.x, s.y)
                require('src/fx/Particles').emit('oneup', s.x, s.y)
                if self.onGet then self.onGet(s.id, s.x, s.y) end
            end
        end
    end
end

-- Los que ya han salido y nadie ha recogido (al tocar la meta): se recogen solos
function Drops:collectAll()
    for i = #self.list, 1, -1 do
        local s = table.remove(self.list, i)
        self.got = self.got + 1
        if self.onGet then self.onGet(s.id, s.x, s.y) end
    end
end

-- (se dibuja ENCIMA de la oscuridad: brilla también en los niveles a oscuras)
function Drops:render(camX, camY)
    local Stage = require 'src/story/Stage'
    local now = love.timer.getTime()
    for _, s in ipairs(self.list) do
        local x, y = math.floor(s.x - camX), math.floor(s.y - camY)
        Stage.rays(x, y, now * 2, 6, 70 + 10 * math.sin(now * 4), 0.22, { 0.8, 0.95, 1 })
        Stage.shard(s.id, x, y, { s = 4, rot = math.sin(now * 2.2) * 0.2 })
    end
end

return Shards
