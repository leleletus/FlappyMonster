-- src/world/BossZones.lua
-- Zonas de jefe: un rectángulo del nivel (en casillas) donde se pelea contra
-- uno o varios jefes. Lo usan el modo un jugador, el servidor, el cliente
-- online (predicción + dibujo) y el editor.
--
--  * Mientras la zona no esté superada, quien está DENTRO no puede salir
--    (paredes y techo invisibles: Level:arenaAt, que consulta PlayerAdventure).
--  * La cámara se queda fija enfocando la zona (BossZones.cameraTarget).
--  * La pelea empieza cuando TODOS los jugadores activos están dentro; hasta
--    entonces el jefe está dormido (y los que llegaron, esperando).
--  * Entrada del jefe (si tiene: b:hasIntro()): antes de la pelea la zona pasa
--    a 'intro'. Los jugadores de dentro se quedan CONGELADOS (sin control:
--    BossZones.frozenAt, que mira PlayerAdventure) y la música se calla
--    (BossZones.SILENCE) mientras el jefe hace su entrada; cuando todos sus
--    jefes dicen b:introDone(), empieza la pelea (y su música). La cámara se
--    centra en el jefe (cameraTarget) y el HUD pone franjas de cine con su
--    nombre (BossHud.drawCinema). La parte genérica de la entrada está en
--    Boss.lua (estados 'intro' → 'ready'); cada jefe solo anima la suya.
--  * La zona sabe qué jefes le pertenecen (zone.bosses): las entidades con
--    `boss` en su definición cuya propiedad `zone` es el id de la zona, o,
--    con zone = 0, las que están colocadas dentro de ella.
--  * Superada (todos sus jefes muertos) la zona desaparece y todo vuelve a
--    la normalidad.
--
-- En el JSON del nivel:  "bossZones": [ { "id":1, "col":40, "row":2, "w":20, "h":11, "music":"boss" } ]

local BossZones = {}

BossZones.DEFAULT_W, BossZones.DEFAULT_H = 20, 11      -- 1280x704 px: una pantalla
BossZones.STATES = { 'idle', 'waiting', 'fight', 'cleared', 'intro' }   -- (códigos de red: no reordenar)
local CODE = {}
for i, s in ipairs(BossZones.STATES) do CODE[s] = i end

-- Música de la pelea: las pistas marcadas "boss": true en assets/music/index.json
-- (una canción nueva de jefe sale sola aquí y en el editor) o 'level' = la
-- del nivel. Por defecto la primera de jefe ('boss').
local Music = require 'src/Music'
BossZones.MUSIC = {}
for _, tr in ipairs(Music.bossList) do BossZones.MUSIC[#BossZones.MUSIC + 1] = { value = tr.id, label = tr.name } end
BossZones.MUSIC[#BossZones.MUSIC + 1] = { value = 'level', label = 'La del nivel' }
BossZones.DEFAULT_MUSIC = Music.byId.boss and 'boss' or (BossZones.MUSIC[1] and BossZones.MUSIC[1].value) or 'level'

local function int(v, d) v = tonumber(v); return v and math.floor(v) or d end

-- ── Datos ─────────────────────────────────────────────────────────────────────
function BossZones.normalize(z, i)
    if type(z) ~= 'table' then return nil end
    local music = BossZones.DEFAULT_MUSIC
    for _, m in ipairs(BossZones.MUSIC) do if z.music == m.value then music = m.value end end
    return {
        id    = math.max(1, int(z.id, i or 1)),
        col   = math.max(1, int(z.col, 1)),
        row   = math.max(1, int(z.row, 1)),
        w     = math.max(4, int(z.w, BossZones.DEFAULT_W)),
        h     = math.max(3, int(z.h, BossZones.DEFAULT_H)),
        music = music,
    }
end

function BossZones.serialize(z)
    return { id = z.id, col = z.col, row = z.row, w = z.w, h = z.h,
             music = (z.music ~= BossZones.DEFAULT_MUSIC) and z.music or nil }
end

-- Rectángulo en px de mundo
function BossZones.rect(z)
    local T = TILE_PX
    return (z.col - 1) * T, (z.row - 1) * T, (z.col - 1 + z.w) * T, (z.row - 1 + z.h) * T
end

function BossZones.containsCell(z, c, r)
    return c >= z.col and c < z.col + z.w and r >= z.row and r < z.row + z.h
end

-- Zonas de juego (Level.fromData): datos + rectángulo + estado
function BossZones.build(list)
    local out = {}
    for i, raw in ipairs(list or {}) do
        local z = BossZones.normalize(raw, i)
        if z then
            z.x0, z.y0, z.x1, z.y1 = BossZones.rect(z)
            z.state, z.arrived, z.needed = 'idle', 0, 0
            z.bosses = {}
            out[#out+1] = z
        end
    end
    return out
end

local function contains(z, x, y)
    return x >= z.x0 and x <= z.x1 and y >= z.y0 and y <= z.y1
end
BossZones.contains = contains

-- Zona sin superar que contiene el punto (paredes invisibles), o nil
function BossZones.arenaAt(level, x, y)
    for _, z in ipairs(level.bossZones or {}) do
        if z.state ~= 'cleared' and contains(z, x, y) then return z end
    end
    return nil
end

-- ── Enlace zona ↔ jefes ───────────────────────────────────────────────────────
-- `entities` = instancias (lista o tabla dispersa por índice, como los
-- renderers del cliente online). Cada jefe queda con e.zone = su zona.
function BossZones.link(level, entities)
    local zones = level.bossZones or {}
    for _, z in ipairs(zones) do z.bosses = {} end
    for _, e in pairs(entities) do
        if e.wantsLevel then e.levelRef = level end
        -- Cuerpos que se dibujan como bloques (bloques de jefe): los bloques de
        -- al lado se unen con ellos (TileTypes.joinsCell)
        if e.joinsCell then
            level.joinOverlay = level.joinOverlay or setmetatable({}, { __mode = 'k' })
            level.joinOverlay[e] = true
        end
        if e.def and e.def.boss then
            local want, zone = e.props.zone or 0, nil
            for _, z in ipairs(zones) do
                if (want > 0 and z.id == want) or (want == 0 and contains(z, e.x, e.y)) then zone = z; break end
            end
            e.zone = zone
            if zone then table.insert(zone.bosses, e) end
        end
    end
end

-- ── Controlador de la pelea (autoritativo: un jugador y servidor) ────────────
-- Cada paso: quién está dentro, cuándo empieza, avisar de muertes (risa del
-- jefe) y cuándo queda superada. Devuelve eventos { {type=..., zone=id}, ... }.
local Controller = {}
Controller.__index = Controller

function BossZones.newController(level, entities)
    BossZones.link(level, entities)
    return setmetatable({
        level = level,
        safe  = setmetatable({}, { __mode = 'k' }),   -- [pa] = {x, y} último suelo dentro
        wasDying = setmetatable({}, { __mode = 'k' }),
    }, Controller)
end

-- ¿Sigue "ocupando" su zona? (un jefe puede soltarla antes de desaparecer:
-- b:releasesZone(), p. ej. el Mega Crabby cuando huye ya derrotado)
local function bossAlive(b)
    if b.releasesZone and b:releasesZone() then return false end
    return b.alive and b.state ~= 'dead'
end

function Controller:update(dt)
    local events = {}
    local players = {}
    for _, pa in ipairs(self.level.players or {}) do
        if pa.alive ~= false then players[#players+1] = pa end
    end
    for _, z in ipairs(self.level.bossZones or {}) do
        if z.state ~= 'cleared' then
            local inside = 0
            for _, pa in ipairs(players) do
                local inZ = contains(z, pa.x, pa.y)
                if inZ and not pa.dying then
                    inside = inside + 1
                    if pa.onGround then self.safe[pa] = { pa.x, pa.y } end
                end
                -- Un jugador cae en plena pelea: el jefe se ríe
                if z.state == 'fight' and pa.dying and not self.wasDying[pa] and inZ then
                    for _, b in ipairs(z.bosses) do
                        if bossAlive(b) and b.onPlayerDeath then b:onPlayerDeath(pa) end
                    end
                end
            end
            z.arrived, z.needed = inside, #players

            if z.state == 'idle' or z.state == 'waiting' then
                if #z.bosses == 0 then
                    z.state = 'cleared'                       -- zona sin jefe: no bloquea
                elseif #players > 0 and inside == #players then
                    local intro = false
                    for _, b in ipairs(z.bosses) do if b.hasIntro and b:hasIntro() then intro = true end end
                    if intro then
                        -- Entrada del jefe: congelados, sin música, hasta que acabe
                        z.state = 'intro'
                        for _, b in ipairs(z.bosses) do
                            if b.startIntro then b:startIntro(self.level, players, z) end
                        end
                        events[#events+1] = { type = 'boss_intro', zone = z.id }
                    else
                        self:beginFight(z, players, events)
                    end
                else
                    z.state = inside > 0 and 'waiting' or 'idle'
                end
            elseif z.state == 'intro' then
                local done = true
                for _, b in ipairs(z.bosses) do
                    if b.introDone and not b:introDone() then done = false end
                end
                if done then self:beginFight(z, players, events) end
            elseif z.state == 'fight' then
                local any = false
                for _, b in ipairs(z.bosses) do if bossAlive(b) then any = true end end
                if not any then
                    z.state = 'cleared'
                    events[#events+1] = { type = 'boss_clear', zone = z.id }
                end
            end
        end
    end
    for _, pa in ipairs(players) do self.wasDying[pa] = pa.dying end
    return events
end

function Controller:beginFight(z, players, events)
    z.state = 'fight'
    for _, b in ipairs(z.bosses) do b:startFight(#players) end
    -- Durante la pelea se reaparece dentro de la zona
    for _, pa in ipairs(players) do
        local s = self.safe[pa]
        pa.spawnX, pa.spawnY = s and s[1] or pa.x, s and s[2] or pa.y
    end
    events[#events+1] = { type = 'boss_start', zone = z.id }
end

-- ¿Está congelado quien está en (x, y)? (entrada del jefe de su zona)
function BossZones.frozenAt(level, x, y)
    for _, z in ipairs(level.bossZones or {}) do
        if z.state == 'intro' and contains(z, x, y) then return true end
    end
    return false
end

-- ── Reaparecer dentro de una zona en plena pelea ─────────────────────────────
-- Quien muere en plena pelea reaparece en el sitio MÁS SEGURO de la zona en
-- ese momento (no donde estaba al empezar): de todas las casillas donde se
-- cabe de pie (Level:isStandable: sin pinchos ni peligros, con suelo), la
-- mejor puntuada:
--   · lejos del jefe (su x: si apunta desde el techo, es donde caerá),
--     hasta SAFE_BOSS casillas (más allá ya da igual);
--   · sin otros enemigos cerca (súbditos, peces...);
--   · fuera del agua y lejos de una inundación que sube;
--   · no dentro de un bloque de jefe (cuerpos sólidos).
-- Lo usan un jugador y el servidor (misma función, mismo resultado).
-- nil = no está en una zona en pelea (o no queda suelo).
local SAFE_BOSS  = 7        -- casillas: a partir de aquí, más lejos no puntúa más
local ENEMY_NEAR = 2.5      -- casillas: un enemigo más cerca penaliza
local STAND_DY   = 16 * PLAYER_SCALE / 2 + 2   -- del suelo al centro del jugador de pie

local function spawnScore(level, z, bosses, c, r)
    local T = TILE_PX
    local x, y = (c - 0.5) * T, r * T - STAND_DY
    -- Dentro de un bloque de jefe u otro cuerpo sólido: no
    if level:bodyAt(x, y) or level:bodyAt(x, (r - 1) * T + 4) then return nil end
    -- Sobre algo que ahora es peligroso (p. ej. el cristal roto de jefe): no
    for _, e in ipairs(level.liveEntities or {}) do
        if e.unsafeAt and e.alive and e:unsafeAt(x, y) then return nil end
    end
    local score = 0
    local dBoss = SAFE_BOSS * T
    for _, b in ipairs(bosses) do
        -- (su cuerpo y, si apunta, también donde va a caer: los dos cuentan;
        -- en horizontal pesa más: debajo de un jefe en la pared no es seguro)
        local pts = { { b.x, b.y } }
        if b.markerX and (b.state == 'aim' or b.state == 'wallaim') then pts[2] = { b.markerX, b.landY or b.y } end
        for _, q in ipairs(pts) do
            local d = math.max(math.abs(q[1] - x) - (b.outerW or 0) / 2, 0) + math.max(math.abs(q[2] - y) - (b.outerH or 0) / 2, 0) * 0.25
            dBoss = math.min(dBoss, d)
        end
    end
    score = score + dBoss / T * 10
    -- (pegado al jefe es lo peor: pesa más que tener súbditos cerca)
    if dBoss < 3 * T then score = score - (3 - dBoss / T) * 45 end
    for _, e in ipairs(level.liveEntities or {}) do
        if e.alive and not e.def.boss and not e.def.pickup and not e.def.checkpoint and e.isObstacle and e:isObstacle()
           and e.state ~= 'reserve' then
            local d = math.sqrt((e.x - x) ^ 2 + (e.y - y) ^ 2) / T
            if d < ENEMY_NEAR then score = score - (ENEMY_NEAR - d) * 12 end
        end
    end
    -- Agua: la cabeza dentro es malo; los pies dentro, un poco
    if level:liquidAt(x, y - 30) then score = score - 40
    elseif level:liquidAt(x, y + 30) then score = score - 8 end
    -- Inundación: por debajo de donde llegará el agua (su nivel máximo), peor
    -- cuanto más hondo; y ya cubierto ahora, mucho peor
    for _, f in ipairs(level.floods or {}) do
        if x >= f.x0 and x < f.x1 and y < f.y1 then
            local top = f.y1 - (f.hi or f.hTiles) * T              -- superficie en lo más alto
            local under = (y - STAND_DY + 8 - top) / T             -- cabeza por debajo de ella
            if under > 0 then score = score - math.min(under, 4) * 6 end
            if f.surf and y - 30 >= f.surf then score = score - 30 end
        end
    end
    return score, x, y
end

function BossZones.safeSpawn(level, z)
    local bosses = {}
    for _, b in ipairs(z.bosses or {}) do
        if b.alive and not (b.isDying and b:isDying()) then bosses[#bosses + 1] = b end
    end
    local best, bx, by
    for c = z.col, z.col + z.w - 1 do
        for r = z.row, z.row + z.h - 1 do
            if level:isStandable(c, r) then
                local sc, x, y = spawnScore(level, z, bosses, c, r)
                if sc and (not best or sc > best + 1e-6) then best, bx, by = sc, x, y end
            end
        end
    end
    return bx, by, best
end

function BossZones.respawnPoint(level, pa)
    for _, z in ipairs(level.bossZones or {}) do
        if z.state == 'fight' and (contains(z, pa.spawnX, pa.spawnY) or contains(z, pa.x, pa.y)) then
            local x, y = BossZones.safeSpawn(level, z)
            if x then return x, y end
            -- (sin sitio bueno: el de siempre si aún tiene suelo)
            local T = TILE_PX
            local c = math.floor(pa.spawnX / T) + 1
            local r = math.floor((pa.spawnY + STAND_DY) / T) + 1
            if level:isStandable(c, r) then return nil end
            return level:findGround(c, z.col, z.col + z.w - 1, z.row, z.row + z.h - 1)
        end
    end
    return nil
end

-- ── Red: estado de las zonas en cada snapshot ────────────────────────────────
function BossZones.netPack(level)
    local zones = level.bossZones or {}
    if #zones == 0 then return nil end
    local out = {}
    for i, z in ipairs(zones) do out[i] = { CODE[z.state] or 1, z.arrived or 0, z.needed or 0 } end
    return out
end

function BossZones.netApply(level, list)
    if type(list) ~= 'table' then return end
    for i, z in ipairs(level.bossZones or {}) do
        local d = list[i]
        if type(d) == 'table' then
            z.state   = BossZones.STATES[d[1]] or z.state
            z.arrived = tonumber(d[2]) or 0
            z.needed  = tonumber(d[3]) or 0
        end
    end
end

-- ── Cliente: cámara, música, HUD ──────────────────────────────────────────────
-- Cámara fija sobre la zona que contiene (x, y). Si la zona es más grande que
-- la pantalla, sigue al jugador sin salirse de ella. nil = cámara normal.
-- Zona cuya cámara manda para alguien en (x, y): la que lo contiene o, en
-- plena pelea, aquella por DEBAJO de la cual está (se cayó por un agujero
-- del suelo: las paredes ya no lo retienen, pero la cámara sigue fija)
function BossZones.cameraZone(level, x, y)
    local z = BossZones.arenaAt(level, x, y)
    if z then return z end
    for _, zz in ipairs(level.bossZones or {}) do
        if zz.state == 'fight' and x >= zz.x0 and x <= zz.x1 and y > zz.y1 then return zz end
    end
    return nil
end

function BossZones.cameraTarget(level, x, y)
    local z = BossZones.cameraZone(level, x, y)
    if not z then return nil end
    -- Entrada del jefe: la cámara no sigue a nadie, se centra en el jefe (su
    -- sitio del editor, o b:introFocus(): igual en todos los clientes)
    if z.state == 'intro' and z.bosses and z.bosses[1] then
        local b = z.bosses[1]
        if b.introFocus then x, y = b:introFocus()
        elseif b.home then x, y = b.home.x, b.home.y end
    end
    -- (fuera de la zona por abajo: se enfoca como si estuviera en su borde)
    x = math.max(z.x0, math.min(z.x1, x))
    y = math.max(z.y0, math.min(z.y1, y))
    local function axis(a0, a1, p, view, maxWorld)
        local t
        if a1 - a0 <= view then t = (a0 + a1) / 2 - view / 2
        else t = math.max(a0, math.min(a1 - view, p - view / 2)) end
        return math.max(0, math.min(maxWorld - view, t))
    end
    return axis(z.x0, z.x1, x, WINDOW_W, level.widthPx), axis(z.y0, z.y1, y, WINDOW_H, level.heightPx), z
end

-- Zona en plena pelea (para música y HUD), o nil
function BossZones.fighting(level)
    for _, z in ipairs(level.bossZones or {}) do
        if z.state == 'fight' then return z end
    end
    return nil
end

-- Pista de música que debe sonar como 'level' ahora mismo (nil = la normal;
-- SILENCE = callada, durante la entrada de un jefe: no es ninguna pista, así
-- que Sound.playMusic('level') no suena y los estados paran la que hubiera)
BossZones.SILENCE = '_silencio'
function BossZones.music(level)
    for _, zz in ipairs(level.bossZones or {}) do
        if zz.state == 'intro' then return BossZones.SILENCE end
    end
    local z = BossZones.fighting(level)
    if z and z.music ~= 'level' then return z.music end
    return nil
end

return BossZones
