-- src/states/online/OnlineAdventureNet.lua
-- PARTE de src/states/online/OnlineAdventureState.lua: lo que llega del servidor — datos iniciales de la partida, snapshots (interpolación de jugadores y entidades) y eventos.
-- La carga OnlineAdventureState.lua con require(...)(OnlineAdventureState, P): añade sus funciones a la tabla OnlineAdventureState. P = lo que
-- antes eran locales del archivo y comparten las partes.
local L = require 'src/core/Lang'
local OnlinePlayer         = require 'src/player/OnlinePlayer'
local NC                   = require 'src/network/NetworkClient'
local Protocol             = require 'src/network/Protocol'
local Predictor            = require 'src/network/Predictor'
local SnapshotBuffer       = require 'src/network/SnapshotBuffer'
local Particles            = require 'src/fx/Particles'
local Modes                = require 'src/world/modes/Modes'
local BossZones            = require 'src/world/systems/BossZones'
local AutoScroll           = require 'src/world/systems/AutoScroll'
local Floods               = require 'src/world/systems/Floods'
local PointAreas           = require 'src/world/systems/PointAreas'
local json                 = require 'libs/json'

return function(OnlineAdventureState, P)
local TICK_DT, TELEPORT_DIST, EVENT_MAX_WAIT, SPEC_WAIT, lerp = P.TICK_DT, P.TELEPORT_DIST, P.EVENT_MAX_WAIT, P.SPEC_WAIT, P.lerp

-- ── Datos iniciales de la partida ─────────────────────────────────────────────

function OnlineAdventureState:_onGameInit(data)
    NC.pendingGameInit = nil
    if self.localPaInit or type(data) ~= 'table' then return end
    if not Protocol.isValidOwnState(data.own) then return end

    -- Nivel y modo enviados por el servidor
    if type(data.level) == 'string' then
        local ok, lv = pcall(json.decode, data.level)
        if ok and type(lv) == 'table' then self:_buildWorld(lv, data.difficulty) end   -- (la dificultad cambia qué hay)
    end
    self.mode   = Modes.get(data.mode) or self.mode
    -- Dificultad de la sala (src/core/Difficulty.lua): la misma que simula el servidor
    local Difficulty = require 'src/core/Difficulty'
    self.level.difficulty = Difficulty.valid(data.difficulty) and data.difficulty or nil
    Difficulty.bind(self.level)
    self.localPa:applyDifficulty()
    self.level.hiddenTriggers = Modes.hiddenTriggers(self.mode)   -- (la meta, fuera de Carrera)
    self.introT = 0

    self.myIdx = data.idx
    for _, r in ipairs(data.roster or {}) do
        self.roster[r.idx] = r
        if r.id then self.rosterById[r.id] = r end
        if r.idx ~= self.myIdx then
            self.remotePlayers[r.idx] = OnlinePlayer:new(r.id, r.name, r.color)
        else
            -- Tras llegar a la meta el servidor deja de simularnos: nos
            -- dibujamos como "fantasma" en la meta con los datos del snapshot
            self.selfGhost = OnlinePlayer:new(r.id, r.name, r.color)
        end
    end

    Protocol.applyOwnState(data.own, self.localPa)
    self.predictor = Predictor.new(self.localPa, self.level)
    self.snapBuf   = SnapshotBuffer.new(data.tickRate or Protocol.TICK_RATE,
                                        data.snapEvery or Protocol.SNAPSHOT_EVERY)
    self.localPaInit = true
    self.renderX, self.renderY = self.localPa.x, self.localPa.y
    self.camX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, self.localPa.x - WINDOW_W/2))
    self.camY = math.max(0, math.min(self.level.heightPx - WINDOW_H, self.localPa.y - WINDOW_H/2))
end

-- ── Snapshots ─────────────────────────────────────────────────────────────────

function OnlineAdventureState:_onSnapshot(snap)
    if not self.snapBuf or type(snap) ~= 'table' or type(snap.t) ~= 'number' then return end
    self.lastSnapAt = love.timer.getTime()          -- (indicador de conexión)

    -- Indexar jugadores por idx una sola vez
    snap.byIdx = {}
    for _, p in ipairs(snap.p or {}) do
        if type(p) == 'table' and type(p[1]) == 'number' then snap.byIdx[p[1]] = p end
    end
    -- Burbujas: id → {x, y}
    snap.bub = {}
    for vi, flat in ipairs(snap.vb or {}) do
        for i = 1, #flat - 2, 3 do
            snap.bub[flat[i]] = { vi, flat[i+1], flat[i+2] }
        end
    end
    if not self.snapBuf:push(snap) then return end   -- viejo/duplicado

    -- HUD propio: siempre del snapshot más reciente
    local mine = snap.byIdx[self.myIdx]
    if mine then
        local wasSpec = self.ownData.isSpectator
        self.ownData.lives       = mine[7]
        self.ownData.hp          = mine[8]
        self.ownData.score       = mine[9]
        self.ownData.isSpectator = Protocol.band(mine[6], Protocol.PF_SPECTATOR) ~= 0
        self.ownData.finished    = Protocol.band(mine[6], Protocol.PF_FINISHED) ~= 0
        self.ownData.place       = mine[12] or 0
        -- Quien llega a la meta también deja de jugar, pero no está "eliminado"
        if self.ownData.isSpectator and not wasSpec and not self.showGameOver
           and not self.ownData.finished then
            self.specOverlay = true
            self.specSel     = SPEC_WAIT
            Sound.stopTracked('drowning')
            self.audioDrowning = false
        end
    end
    if type(snap.lt) == 'number' then self.levelTime = snap.lt / 100 end
    -- Zonas de jefe: el más reciente (la predicción usa sus paredes)
    BossZones.netApply(self.level, snap.bz)
    AutoScroll.netApply(self.level, snap.sc)     -- cámara automática (paredes de la predicción)
    Floods.netApply(self.level, snap.fc, TICK_DT) -- inundaciones controladas (el agua: en su tiempo predicho)
    PointAreas.netApply(self.level, snap.zc)      -- la zona de puntos que se mueve: su reloj
    self.modeHud = type(snap.md) == 'table' and snap.md or nil
    -- Modo con tiempo (hud `tl` = centésimas que quedan, p. ej. Rey de la
    -- Colina): el reloj del HUD cuenta hacia atrás hasta este instante
    local tl = self.modeHud and tonumber(self.modeHud.tl)
    self.roundEndAt = tl and (self.levelTime + tl / 100) or nil

    -- Reconciliar la predicción local
    if snap.a and snap.o and self.predictor and not self.ownData.isSpectator then
        local r = self.predictor:reconcile(snap.a, snap.o, snap.bs)
        if r then
            local pa = self.localPa
            -- Muerte que no predijimos (p. ej. enemigo): su sonido
            if pa.dying and not r.wasDying and pa.drownPhase == 'none' then
                Sound.play('dies2')
            end
            -- Pisotón que solo detectó el servidor: su sonido
            if r.missedBounce then Sound.play('enemyExplode') end
            -- Golpe que solo vio el servidor (un jefe nos cayó encima)
            if r.hpDrop then Sound.play('dies') end
            self:_syncDrownAudio()
        end
    end
end

-- La música/sonido de ahogamiento sigue al estado predicho aunque una
-- corrección del servidor lo cambie sin pasar por la física "audible".
function OnlineAdventureState:_syncDrownAudio()
    local pa = self.localPa
    local drowning = (pa.drownPhase == 'drowning') and not pa.dying
    if self.audioDrowning and not drowning then
        Sound.stopTracked('drowning')
        if not pa.dying then Sound.playMusic('level') end
    elseif drowning and not self.audioDrowning then
        Sound.stopMusic()
        Sound.playTracked('drowning')
    end
    self.audioDrowning = drowning
end

-- Aplica el estado interpolado del mundo remoto para este frame.
function OnlineAdventureState:_applyInterpolation()
    local a, b, f = self.snapBuf:sample()
    if not a then return end

    -- Jugadores remotos
    for idx, rp in pairs(self.remotePlayers) do
        local pb = b.byIdx[idx]
        local pa = a.byIdx[idx] or pb
        if not pb then pb = pa end
        if pb then
            local x, y = pb[2], pb[3]
            if pa ~= pb and math.abs(pb[2]-pa[2]) < TELEPORT_DIST and math.abs(pb[3]-pa[3]) < TELEPORT_DIST then
                x, y = lerp(pa[2], pb[2], f), lerp(pa[3], pb[3], f)
            end
            local d = (f < 0.5) and pa or pb   -- datos discretos del más cercano
            rp.visible = true
            rp:applyData({
                x=x, y=y, facing=d[4], frame=d[5],
                dying       = Protocol.band(d[6], Protocol.PF_DYING) ~= 0,
                isSpectator = Protocol.band(d[6], Protocol.PF_SPECTATOR) ~= 0,
                lives=d[7], hp=d[8], score=d[9], drownPhase=Protocol.drownName(d[10]),
                finished    = Protocol.band(d[6], Protocol.PF_FINISHED) ~= 0,
                stunned     = Protocol.band(d[6], Protocol.PF_STUNNED) ~= 0,
                hurt        = Protocol.band(d[6], Protocol.PF_HURT) ~= 0,
                invuln      = Protocol.band(d[6], Protocol.PF_INVULN) ~= 0,
                squashed    = Protocol.band(d[6], Protocol.PF_SQUASH) ~= 0,
                iced        = Protocol.band(d[6], Protocol.PF_ICE) ~= 0,
                lightOn     = Protocol.band(d[6], Protocol.PF_LIGHT) ~= 0,
                place       = d[12],
            })
        else
            rp.visible = false   -- salió de la partida
        end
    end

    -- Nosotros mismos, ya en la meta
    local g, mine = self.selfGhost, b.byIdx[self.myIdx]
    if g and mine and self.ownData.finished then
        g.visible = true
        g:applyData({ x=mine[2], y=mine[3], facing=mine[4], frame=mine[5], isSpectator=true,
                      finished=true, place=mine[12], dying=false })
    end

    -- Enemigos
    local ea, eb = a.e or {}, b.e or {}
    for i, er in pairs(self.enemyRenderers) do
        local db = eb[i]
        local da = ea[i] or db
        if not db then
            er:netRest()              -- no vino: está en reposo (ver Entity:netAtRest)
        else
            local x, y = db[1], db[2]
            if math.abs(db[1]-da[1]) < TELEPORT_DIST and math.abs(db[2]-da[2]) < TELEPORT_DIST then
                x, y = lerp(da[1], db[1], f), lerp(da[2], db[2], f)
            end
            local d = (f < 0.5) and da or db
            er.x, er.y  = x, y
            er.facing   = d[3]
            er.state    = d[4]
            er.frame    = d[5]
            er.alive    = d[6]
            -- Temporizadores: interpolar solo si avanzan (se reinician a 0)
            er.deadTimer = ((db[7] >= da[7]) and lerp(da[7], db[7], f) or db[7]) / 100
            er.breatheT  = ((db[8] >= da[8]) and lerp(da[8], db[8], f) or db[8]) / 100
            er.flipped   = d[9] == 1
            -- Datos propios del tipo (desde el índice 10): los interpreta la entidad
            if db[10] ~= nil then
                local xa, xb = {}, {}
                for k = 10, #db do xb[#xb+1] = db[k]; xa[#xa+1] = da[k] end
                er:netApply(xa, xb, f)
            end
        end
    end

    -- Burbujas de oxígeno (interpoladas por ID)
    local vents = {}
    for id, bb in pairs(b.bub) do
        local ba = a.bub[id]
        local x, y = bb[2], bb[3]
        if ba then x, y = lerp(ba[2], bb[2], f), lerp(ba[3], bb[3], f) end
        local list = vents[bb[1]]
        if not list then list = {}; vents[bb[1]] = list end
        list[#list+1] = { x=x, y=y }
    end
    local out = {}
    for vi = 1, #self.level.vents do out[vi] = vents[vi] or {} end
    self.level:syncOxyBubbles(out)
end

-- ── Eventos ───────────────────────────────────────────────────────────────────

function OnlineAdventureState:_onEvents(data)
    if type(data) ~= 'table' or type(data.list) ~= 'table' then return end
    for _, ev in ipairs(data.list) do
        if type(ev) == 'table' then
            -- Lo que le pasa al jugador propio o el fin de partida: ya.
            -- Lo del resto del mundo: cuando se dibuje ese tick.
            if ev.type == 'round_end' or ev.playerId == NC.myId then
                self:_processEvent(ev)
            else
                ev._wait = 0
                table.insert(self.pendingEvents, ev)
            end
        end
    end
end

function OnlineAdventureState:_updatePendingEvents(dt)
    local rt = self.snapBuf and self.snapBuf:renderTick()
    local i = 1
    while i <= #self.pendingEvents do
        local ev = self.pendingEvents[i]
        ev._wait = ev._wait + dt
        if (rt and type(ev.t) == 'number' and ev.t <= rt) or ev._wait >= EVENT_MAX_WAIT then
            table.remove(self.pendingEvents, i)
            self:_processEvent(ev)
        else
            i = i + 1
        end
    end
end

function OnlineAdventureState:_processEvent(ev)
    if ev.type == 'sound' then
        -- Los sonidos propios los genera la predicción local (evita dobles).
        if (not ev.playerId or ev.playerId ~= NC.myId) and type(ev.sound) == 'string'
           and not (ev.playerId and Protocol.PRIVATE_SOUNDS[ev.sound]) then   -- (alarma de otro)
            local pitch = tonumber(ev.pitch)
            pitch = pitch and math.max(0.25, math.min(3, pitch)) or nil
            -- Con posición: se atenúa según NUESTRA distancia a donde sonó
            local x, y = tonumber(ev.x), tonumber(ev.y)
            if x and y then Sound.playAt(ev.sound, x, y, pitch) else Sound.play(ev.sound, pitch) end
        end
    elseif ev.type == 'boss_start' then
        self.bossBanner = { text = L('hud.boss'), t = 0, col = { 1, 0.3, 0.3 } }
        self.bossFightT = 0
    elseif ev.type == 'scroll_start' then
        self.bossBanner = { text = L('hud.go'), t = 0, col = { 0.4, 1, 0.5 } }
    elseif ev.type == 'boss_clear' then
        self.bossBanner = { text = L('hud.boss_defeated'), t = 0, col = { 1, 0.9, 0.25 } }
        Sound.play('fanfare')
    elseif ev.type == 'score' then
        -- Zona de puntos: destello para todos; el "+N", solo para quien los gana
        if ev.kind == 'zone' then PointAreas.flashAt(self.level, tonumber(ev.x) or 0, (tonumber(ev.y) or 0) + 40) end
        if ev.playerId == NC.myId then
            self:_spawnPopup('+' .. tostring(ev.delta) .. (ev.kind == 'zone' and '' or '!'), ev.x or 0, ev.y or 0)
        end
    elseif ev.type == 'tile' then
        -- Bloque roto / ON-OFF cambiado (lo decide el servidor): aplicar,
        -- partículas y sonido para todos
        local c, r, v = tonumber(ev.c), tonumber(ev.r), tonumber(ev.v)
        if c and r and v then
            self.level:setTileRaw(c, r, v)
            if ev.k == 'set' then
                -- (Bloque ON/OFF que cambia con su activador: sin efectos)
            elseif ev.k == 'crack' or ev.k == 'icebreak' then
                -- Hielo fino que se agrieta / se rompe
                local x, y = (c - 0.5) * TILE_PX, (r - 1) * TILE_PX + TILE_PX / 4
                if ev.k == 'crack' then self.level:tileBump(c, r, 'crack') end
                Particles.emit(ev.k == 'icebreak' and 'ice_break' or 'ice_crack', x, y)
                Sound.playAt(ev.k == 'icebreak' and 'iceBreak' or 'iceCrack', x, y)
            elseif ev.k == 'toggle' then
                self.level:tileBump(c, r, ev.from)
                Particles.emit('switch_hit', (c - 1) * TILE_PX, (r - 1) * TILE_PX)
                Sound.play(self.level:getDef(c, r).name == 'switch_on' and 'switchOn' or 'switchOff')
            else
                Particles.emit('block_break', (c - 1) * TILE_PX, (r - 1) * TILE_PX)
                Sound.play('blockBreak')
            end
        end
    elseif ev.type == 'fx' then
        -- Efectos de OTROS jugadores (los propios ya los generó la predicción)
        if ev.playerId ~= NC.myId and ev.kind ~= 'block_break' and ev.kind ~= 'switch_hit' and type(ev.kind) == 'string' then
            Particles.emit(ev.kind, tonumber(ev.x) or 0, tonumber(ev.y) or 0)
        end
    elseif ev.type == 'pickup' then
        local x, y = tonumber(ev.x) or 0, tonumber(ev.y) or 0
        if ev.kind == 'life' then
            Sound.play('oneUp'); Particles.emit('oneup', x, y)
            if ev.playerId == NC.myId then self:_spawnPopup(L('hud.plus_life'), x, y - 30) end
        elseif ev.kind == 'heal' then
            Sound.play('appleHeal'); Particles.emit('collect', x, y)
            if ev.playerId == NC.myId then self:_spawnPopup(L('hud.plus_hp'), x, y - 30) end
        else
            Sound.play('collect'); Particles.emit('collect', x, y)
            if ev.playerId == NC.myId and ev.delta then self:_spawnPopup('+' .. ev.delta .. '!', x, y - 30) end
        end
    elseif ev.type == 'checkpoint' and ev.playerId == NC.myId then
        -- Nuestra bandera se levanta (cada jugador tiene su propio checkpoint)
        for i, er in pairs(self.enemyRenderers) do
            if er.def and er.def.checkpoint then
                if i == ev.idx then er:activate() else er.activeLocal = false end
            end
        end
        Sound.play('checkpoint')
        Particles.emit('checkpoint', tonumber(ev.x) or 0, (tonumber(ev.y) or 0) - 40)
        self:_spawnPopup(L('hud.checkpoint'), tonumber(ev.x) or 0, (tonumber(ev.y) or 0) - 60)
    elseif ev.type == 'air_collected' and ev.playerId == NC.myId then
        -- El servidor confirmó que recogimos una burbuja de oxígeno.
        Sound.play('airGasp')
    elseif ev.type == 'finish' then
        -- Alguien cruzó la meta (modo carrera)
        local mine  = ev.playerId == NC.myId
        local who   = self.rosterById[ev.playerId]
        local place = tonumber(ev.place) or 0
        if mine then
            self:_addBanner(L('oadv.at_finish'), L('oadv.place', { n = place }), {1, 0.85, 0.2})
            Sound.play('finish')
            Sound.stopTracked('drowning'); self.audioDrowning = false
        else
            self:_addBanner(L('oadv.reached_finish', { name = who and who.name or '?' }),
                            place == 1 and L('oadv.countdown') or L('oadv.place', { n = place }),
                            who and who.color or {1, 1, 1}, true)
            Sound.play('point')
        end
    elseif ev.type == 'round_end' then
        if self.showGameOver then return end
        self.showGameOver        = true
        self.roundEnd            = ev
        self.gameOverTimer       = 0
        self.specOverlay         = false
        self.showPause           = false
        self.gameOverMusicPitch  = 1.0
        Sound.play('roundOver')           -- mientras la música del nivel se ralentiza
        Sound.stopTracked('drowning')
        self.audioDrowning = false
    end
end
end
