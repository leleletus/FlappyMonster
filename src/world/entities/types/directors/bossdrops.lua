-- AYUDA EN LAS PELEAS DE JEFE: director invisible que, mientras una zona de jefe está en pelea, deja CAER DEL CIELO
-- dentro de la zona comida (cura 1 PS) y vidas extra CUANDO HACEN FALTA ("director inteligente", 0.5.62; antes caían
-- al azar cada tantos segundos).
--
-- Dónde ayuda: en Extremo y Xtra extremo (modificadores `bossFood` / `bossLives` de src/core/Difficulty.lua: los s
-- MÍNIMOS entre una y otra; 0 = nada) y, en un nivel de EVENTO (el Mega Mashup: level.event), en TODAS las
-- dificultades, con su propio ritmo por dificultad (EVENT_FOOD / EVENT_LIVES).
--
-- Cuándo hace falta COMIDA (a cualquiera de los jugadores en la zona, pasado su tiempo mínimo y sin comida ya en el
-- suelo):
--   · vida BAJA: le queda ≤ un tercio (1 de 3, 1 de 4…);
--   · le cuesta: ≥ 2 golpes en los últimos STRUGGLE_T s, o murió hace poco, o lleva NO_DAMAGE_T s herido sin quitarle
--     vida al jefe;
--   · ANTES DE LO DIFÍCIL: herido justo cuando empieza otra parte (el director del evento lo avisa: level.helpHint —
--     una costura, el final —).
-- Una VIDA EXTRA: alguien en su última vida y además le cuesta (pasado su tiempo mínimo).
-- Dónde: de las casillas de la zona con suelo de verdad (sin agua, lava ni pinchos), la mejor: lejos del jefe (y de
-- donde va a caer su ataque si apunta), alcanzable (2-6 casillas del jugador que la necesita) y nunca encima de él.
--
-- No va en ningún nivel: Level.fromData lo añade solo, con su reserva de comidas y vidas (súbditos de reserva,
-- `summonKey` 'bossdrops': mismos índices en servidor y clientes). Lo simula el servidor online; lo que cae son
-- entidades normales (viajan en las instantáneas) que caen con el estado base 'skyfall' (Entity:dropFromSky) y se
-- cogen como siempre. Lo que da se guarda al acabar el nivel, como todo.
local Entity = require 'src/world/entities/base/Entity'
local Difficulty = require 'src/core/Difficulty'

local Drops = Entity.extend(Entity, { debugColor = { 0.4, 1, 0.6 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

Drops.KEY = 'bossdrops'
Drops.POOL = { food = 2, lives = 1 }       -- cuántas puede haber a la vez por el escenario (se reutilizan al cogerlas)
local KIND_TYPE = { food = 'apple', lives = 'extralife' }
local MOD = { food = 'bossFood', lives = 'bossLives' }
local LIFT = { food = 10, lives = 0 }      -- (la comida se mece: posada un poco por encima del suelo)
-- En un nivel de EVENTO, en todas las dificultades: s mínimos entre comidas / vidas (Extremo y Xtra: los suyos)
Drops.EVENT_FOOD  = { easy = 8, normal = 11, hard = 14 }
Drops.EVENT_LIVES = { easy = 40, normal = 55, hard = 75 }
Drops.STRUGGLE_T, Drops.NO_DAMAGE_T, Drops.DEATH_T = 12, 25, 20

function Drops.loadAssets() end
function Drops.sizePx() return TILE_PX, TILE_PX end

function Drops:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
    self.cool = { food = 0, lives = 0 }
    self.t = 0
    self.hits = setmetatable({}, { __mode = 'k' })      -- [pa] = { instantes de golpes }
    self.lastHp = setmetatable({}, { __mode = 'k' })
    self.diedAt = setmetatable({}, { __mode = 'k' })
    self.wasDying = setmetatable({}, { __mode = 'k' })
    self.bossHitT = 0
end

function Drops:canBeStomped() return false end
function Drops:canBeKnocked() return false end
function Drops:isBodyDisabled() return true end
function Drops:isObstacle() return false end
function Drops:isGhost() return true end
function Drops:netAtRest() return true end  -- (el cliente no lo necesita: lo que cae ya viaja)
function Drops:netRest() end

-- s mínimos entre una y otra de `kind` en este nivel (0 = no ayuda con eso)
function Drops.every(level, kind)
    local v = Difficulty.of(level.difficulty, MOD[kind], 0)
    if v > 0 then return v end
    if level.event then
        local t = kind == 'food' and Drops.EVENT_FOOD or Drops.EVENT_LIVES
        return t[level.difficulty or 'normal'] or t.normal
    end
    return 0
end

-- Las colocaciones que Level.fromData añade (el director y su reserva), o nada si no hay ayuda
function Drops.placements(level)
    local z = level.bossZones and level.bossZones[1]
    if not z then return {} end
    local any = false
    for kind in pairs(MOD) do if Drops.every(level, kind) > 0 then any = true end end
    if not any then return {} end
    local col, row = z.col, math.max(1, z.row)
    local out = { { type = 'bossdrops', col = col, row = row } }
    for kind, n in pairs({ food = Drops.POOL.food, lives = Drops.POOL.lives }) do
        if Drops.every(level, kind) > 0 then
            for _ = 1, n do
                out[#out + 1] = { type = KIND_TYPE[kind], col = col, row = row, reserve = true, summonKey = Drops.KEY }
            end
        end
    end
    -- (orden fijo: pairs no lo es, y los índices tienen que coincidir en servidor y clientes)
    table.sort(out, function(a, b)
        if (a.reserve or false) ~= (b.reserve or false) then return not a.reserve end
        return a.type < b.type
    end)
    return out
end

-- Dónde cae, para el jugador `pa`: la mejor casilla con suelo de la zona (lejos del jefe y de donde va a caer su
-- ataque, a 2-6 casillas del jugador, nunca encima de él), desde arriba de la zona. nil si no encuentra
function Drops.spot(level, z, pa)
    local T = TILE_PX
    local c0, c1 = z.col + 1, z.col + z.w - 2
    local r0, r1 = math.max(1, z.row), math.min(level.tileH - 1, z.row + z.h - 1)
    if c1 < c0 then return nil end
    local danger = {}
    for _, b in ipairs(z.bosses or {}) do
        if b.alive and not b.offstage and not (b.isDying and b:isDying()) then
            danger[#danger + 1] = b.x
            local m = b.markerX or b.markX or b.markerx
            if m then danger[#danger + 1] = m end
        end
    end
    local best, bx, by
    for c = c0, c1 do
        local x = (c - 0.5) * T
        local ground
        for r = r0, r1 do
            local d = level:getDef(c, r)
            if level:liquidAt(x, (r - 0.5) * T) or d.mat.contact then break end
            if level:isStandable(c, r) then ground = r; break end
            if d.collision ~= 'none' then break end
        end
        if ground then
            local sc = 0
            for _, dx in ipairs(danger) do sc = sc + math.min(6, math.abs(dx - x) / T) * 2 end
            if pa then
                local dp = math.abs(pa.x - x) / T
                if dp < 1.5 then sc = sc - 30                               -- (nunca encima)
                elseif dp <= 6 then sc = sc + 6 - math.abs(dp - 3.5)       -- (alcanzable)
                else sc = sc - (dp - 6) end
            end
            sc = sc + ((c * 7919) % 13) * 0.01                              -- (desempate fijo, sin azar)
            if not best or sc > best then best, bx, by = sc, x, (r0 - 0.5) * T end
        end
    end
    return bx, by
end

-- ¿Qué necesita `pa` ahora? → 'lives', 'food' o nil
function Drops:needOf(level, pa)
    if pa.dying or pa.alive == false then return nil end
    local now = self.t
    local hits = self.hits[pa] or {}
    local recent = 0
    for _, h in ipairs(hits) do if now - h <= Drops.STRUGGLE_T then recent = recent + 1 end end
    local died = self.diedAt[pa] and now - self.diedAt[pa] <= Drops.DEATH_T
    local hurt = (pa.hp or 0) < (pa.hpMax or 0)
    local struggling = recent >= 2 or died or (hurt and now - self.bossHitT >= Drops.NO_DAMAGE_T)
    if (pa.lives or 9) <= 1 and struggling then return 'lives', true end
    local low = (pa.hp or 0) <= math.max(1, math.floor((pa.hpMax or 3) / 3))
    if hurt and (low or struggling or level.helpHint) then return 'food' end
    return nil
end

function Drops:updateCustom(dt, level)
    self.t = self.t + dt
    if not self.pool then
        self.pool = { food = {}, lives = {} }
        for _, e in ipairs(level.liveEntities or {}) do
            if e.summonOf == Drops.KEY then
                local kind = (e.def.pickup and e.def.pickup.lives) and 'lives' or 'food'
                table.insert(self.pool[kind], e)
            end
        end
    end
    -- lo que pasa: golpes y muertes de cada jugador, golpes al jefe
    for _, pa in ipairs(level.players or {}) do
        local hp0 = self.lastHp[pa]
        if hp0 and pa.hp and pa.hp < hp0 and not pa.dying then
            local h = self.hits[pa] or {}
            h[#h + 1] = self.t
            while #h > 6 do table.remove(h, 1) end
            self.hits[pa] = h
        end
        if pa.dying and not self.wasDying[pa] then self.diedAt[pa] = self.t end
        self.lastHp[pa], self.wasDying[pa] = pa.hp, pa.dying
    end
    for kind in pairs(self.cool) do self.cool[kind] = math.max(0, self.cool[kind] - dt) end
    for _, z in ipairs(level.bossZones or {}) do
        if z.state == 'fight' or (z.event and z.state == 'intro') then
            local bossHp = 0
            for _, b in ipairs(z.bosses or {}) do if b.alive then bossHp = bossHp + (b.hp or 0) end end
            if self.zoneHp and z == self.zoneOf and bossHp < self.zoneHp then self.bossHitT = self.t end
            self.zoneHp, self.zoneOf = bossHp, z
            for _, pa in ipairs(level.players or {}) do
                if require('src/world/systems/BossZones').contains(z, pa.x, pa.y) then
                    local need = self:needOf(level, pa)
                    if need and self.cool[need] <= 0 and #self.pool[need] > 0 and not self:lying(need) then
                        if self:drop(level, z, need, pa) then self.cool[need] = Drops.every(level, need) end
                    end
                end
            end
        end
    end
    level.helpHint = nil                                 -- (el aviso dura un paso: lo vuelve a poner quien lo da)
    return true
end

-- ¿Hay ya una de `kind` en el suelo sin coger? (no se amontonan)
function Drops:lying(kind)
    for _, e in ipairs(self.pool[kind]) do if e.alive and e.state ~= 'reserve' then return true end end
    return false
end

function Drops:drop(level, z, kind, pa)
    if Drops.every(level, kind) <= 0 then return false end
    local free
    for _, e in ipairs(self.pool[kind]) do
        if not e.alive then free = e; break end
    end
    if not free then return false end       -- (todas por ahí sin coger: no caen más)
    local x, y = Drops.spot(level, z, pa)
    if not x then return false end
    free:dropFromSky(x, y + TILE_PX / 2 - free.outerH / 2, LIFT[kind])
    Sound.playAt('respawnFx', x, y, 1.3, 0.6)
    return true
end

function Drops:render() end

return {
    name = 'bossdrops', label = 'Ayuda del jefe', category = 'Directores',
    description = 'Invisible y automático (no se coloca): en Extremo y Xtra extremo (y en los eventos, en todas) deja '
               .. 'caer comida y vidas extra durante las peleas de jefe cuando hacen falta.',
    class = Drops,
    hide = 'all',
    editorHide = true,
    defaults = { movement = 'static' },
    props = {},
}
