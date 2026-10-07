-- src/story/Shards.lua
-- LOS FRAGMENTOS DEL ESPEJO (historia "El Espejo Roto", docs/historia/HISTORIA.md). Cada jefe guarda uno:
-- al vencerlo lo SUELTA, el jugador lo recoge y queda en su partida (Run.addShard). Con los siete, el final.
-- En Xtra extremo hay dos jefes por arena: cada uno suelta MEDIO fragmento ('3a' el original, '3b' la copia).
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
    reino_gummy = 1, guarida_cangrejo_rey = 2, fortaleza_malvada = 3, lago_helado = 4,
    glaciar_cangrejo = 5, gruta_lugubre = 6, ruta_del_espejo = 7,
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
    if type(data.shards) == 'table' then return end
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
    return setmetatable({ state = state, ids = def.ids or {}, onGet = def.onGet, final = def.final,
                          next = 1, list = {}, seen = {}, got = 0 }, Drops)
end

function Drops:remaining() return #self.ids - self.got end
function Drops:allGot() return #self.ids > 0 and self.got >= #self.ids end

-- Un fragmento sale de (x, y): sube en arco y se queda flotando
function Drops:spawn(x, y)
    local id = self.ids[self.next]
    if not id then return end
    self.next = self.next + 1
    local side = (#self.list % 2 == 0) and -1 or 1
    self.list[#self.list + 1] = { id = id, x0 = x, y0 = y, x = x, y = y, tx = x + side * 60, ty = y - 110, t = 0 }
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
            local gone = (not e.alive) or (e.releasesZone and e:releasesZone())
            if not self.seen[e] then
                if not gone then self.seen[e] = 'alive' end
            elseif self.seen[e] == 'alive' and gone then
                self.seen[e] = 'dropped'
                self:spawn(e.x, e.y)
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
