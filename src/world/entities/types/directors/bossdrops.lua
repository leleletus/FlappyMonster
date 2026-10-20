-- AYUDA EN LAS PELEAS DE JEFE (Extremo y Xtra extremo): director invisible que, mientras una zona de jefe está en
-- pelea, deja CAER DEL CIELO, dentro de la zona y a ratos al azar, comida (cura 1 PS) y, en Xtra extremo, vidas
-- extra. Lo dicen dos modificadores de src/core/Difficulty.lua: `bossFood` y `bossLives` = segundos (de media)
-- entre una y otra; 0 = nada. Sin ellos la pelea era casi imposible (el usuario).
--
-- No va en ningún nivel: Level.fromData lo añade solo, con su reserva de comidas y vidas (súbditos de reserva,
-- `summonKey` 'bossdrops': mismos índices en servidor y clientes), cuando la dificultad trae alguno de los dos. Lo
-- simula el servidor online; lo que cae son entidades normales (viajan en las instantáneas) que caen con el estado
-- base 'skyfall' (Entity:dropFromSky) y se cogen como siempre. Lo que da se guarda al acabar el nivel, como todo.
local Entity = require 'src/world/entities/base/Entity'
local Difficulty = require 'src/core/Difficulty'

local Drops = Entity.extend(Entity, { debugColor = { 0.4, 1, 0.6 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })

Drops.KEY = 'bossdrops'
Drops.POOL = { food = 2, lives = 1 }       -- cuántas puede haber a la vez por el escenario (se reutilizan al cogerlas)
local KIND_TYPE = { food = 'apple', lives = 'extralife' }
local MOD = { food = 'bossFood', lives = 'bossLives' }
local LIFT = { food = 10, lives = 0 }      -- (la comida se mece: posada un poco por encima del suelo)

function Drops.loadAssets() end
function Drops.sizePx() return TILE_PX, TILE_PX end

function Drops:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.state = 'idle'
    self.timers = {}                        -- [zona] = { food = s, lives = s } hasta la siguiente
end

function Drops:canBeStomped() return false end
function Drops:canBeKnocked() return false end
function Drops:isBodyDisabled() return true end
function Drops:isObstacle() return false end
function Drops:isGhost() return true end
function Drops:netAtRest() return true end  -- (el cliente no lo necesita: lo que cae ya viaja)
function Drops:netRest() end

-- Las colocaciones que Level.fromData añade (el director y su reserva), o nada si la dificultad no da ayuda
function Drops.placements(level)
    local z = level.bossZones and level.bossZones[1]
    if not z then return {} end
    local any = false
    for _, m in pairs(MOD) do if Difficulty.of(level.difficulty, m, 0) > 0 then any = true end end
    if not any then return {} end
    local col, row = z.col, math.max(1, z.row)
    local out = { { type = 'bossdrops', col = col, row = row } }
    for kind, n in pairs({ food = Drops.POOL.food, lives = Drops.POOL.lives }) do
        if Difficulty.of(level.difficulty, MOD[kind], 0) > 0 then
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

-- Dónde cae: una columna al azar de la zona con suelo de verdad debajo (sin agua, lava ni pinchos por medio) y
-- nada sólido encima, desde arriba de la zona. nil si no encuentra
local function spot(level, z)
    local T = TILE_PX
    local c0, c1 = z.col + 1, z.col + z.w - 2
    local r0, r1 = math.max(1, z.row), math.min(level.tileH - 1, z.row + z.h - 1)
    if c1 < c0 then return nil end
    for _ = 1, 12 do
        local c = math.random(c0, c1)
        local x = (c - 0.5) * T
        for r = r0, r1 do
            local d = level:getDef(c, r)
            if level:liquidAt(x, (r - 0.5) * T) or d.mat.contact then break end
            if level:isStandable(c, r) then return x, (r0 - 0.5) * T end
            if d.collision ~= 'none' then break end
        end
    end
    return nil
end

function Drops:updateCustom(dt, level)
    if not self.pool then
        self.pool = { food = {}, lives = {} }
        for _, e in ipairs(level.liveEntities or {}) do
            if e.summonOf == Drops.KEY then
                local kind = (e.def.pickup and e.def.pickup.lives) and 'lives' or 'food'
                table.insert(self.pool[kind], e)
            end
        end
    end
    for _, z in ipairs(level.bossZones or {}) do
        if z.state == 'fight' then
            local tm = self.timers[z]
            for kind, mod in pairs(MOD) do
                local every = Difficulty.k(mod, 0)
                if every > 0 and #self.pool[kind] > 0 then
                    if not tm then tm = {}; self.timers[z] = tm end
                    -- (la primera llega antes: a media espera)
                    tm[kind] = (tm[kind] or every * (0.4 + math.random() * 0.4)) - dt
                    if tm[kind] <= 0 then
                        tm[kind] = every * (0.7 + math.random() * 0.6)
                        self:drop(level, z, kind)
                    end
                end
            end
        else
            self.timers[z] = nil
        end
    end
    return true
end

function Drops:drop(level, z, kind)
    local free
    for _, e in ipairs(self.pool[kind]) do
        if not e.alive then free = e; break end
    end
    if not free then return false end       -- (todas por ahí sin coger: no caen más)
    local x, y = spot(level, z)
    if not x then return false end
    free:dropFromSky(x, y + TILE_PX / 2 - free.outerH / 2, LIFT[kind])
    Sound.playAt('respawnFx', x, y, 1.3, 0.6)
    return true
end

function Drops:render() end

return {
    name = 'bossdrops', label = 'Ayuda del jefe', category = 'Directores',
    description = 'Invisible y automático (no se coloca): en Extremo y Xtra extremo deja caer comida y vidas extra '
               .. 'durante las peleas de jefe.',
    class = Drops,
    hide = 'all',
    editorHide = true,
    defaults = { movement = 'static' },
    props = {},
}
