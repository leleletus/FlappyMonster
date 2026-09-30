-- src/states/OnlineAdventureState.lua
-- Modo aventura multijugador online — arquitectura autoritativa.
--
--  * Jugador propio: predicción local a paso fijo (60 Hz, igual que el
--    servidor) + reconciliación con el último input confirmado (Predictor).
--  * Otros jugadores, enemigos y burbujas: interpolación entre snapshots
--    reales con un pequeño retardo adaptativo (SnapshotBuffer).
--  * Eventos (puntos, sonidos, meta, fin de ronda): canal fiable,
--    sincronizados con el tick en que ocurrieron.
--  * El nivel y el modo de juego (objetivo) llegan en game_init: el cliente
--    no necesita tener el archivo del nivel.

local BaseState            = require 'src/BaseState'
local L = require 'src/Lang'
local Level                = require 'src/world/Level'
local Entities             = require 'src/world/Entities'
local PlayerAdventure      = require 'src/entities/PlayerAdventure'
local OnlinePlayer         = require 'src/entities/OnlinePlayer'
local NC                   = require 'src/network/NetworkClient'
local Protocol             = require 'src/network/Protocol'
local Predictor            = require 'src/network/Predictor'
local SnapshotBuffer       = require 'src/network/SnapshotBuffer'
local PixelIcons           = require 'src/ui/PixelIcons'
local Particles            = require 'src/fx/Particles'
local CornerButtons        = require 'src/ui/CornerButtons'
local Modes                = require 'src/world/Modes'
local BossZones            = require 'src/world/BossZones'
local BossHud              = require 'src/ui/BossHud'
local AutoScroll           = require 'src/world/AutoScroll'
local Floods               = require 'src/world/Floods'
local PointAreas           = require 'src/world/PointAreas'
local json                 = require 'libs/json'

local OnlineAdventureState = BaseState:new()

-- ── Constantes ────────────────────────────────────────────────────────────────
local TICK_DT        = Protocol.TICK_DT
local MAX_TICKS_FRAME = 5      -- ticks máximos simulados por frame (tras un tirón)
local TELEPORT_DIST  = 96      -- px: entre snapshots, más que esto = teletransporte
local EVENT_MAX_WAIT = 0.35    -- s máximos que un evento espera a su tick de render
local POPUP_LIFE  = 1.4
local POPUP_RISE  = 28
local POPUP_BOUNCE_T = 0.22

local PAUSE_RESUME = 1
local PAUSE_HUB    = 2
local PAUSE_STOP   = 3

local SPEC_WAIT  = 1
local SPEC_LEAVE = 2
local SPEC_OPTS  = { 'oadv.wait', 'oadv.leave_hub' }   -- claves de idioma

-- Assets
local imgIcon = nil
local imgBg   = nil
local BG_SCALE    = 15
local BG_PARALLAX = 0.3
local ICON_SCALE  = 4
local AIR_BAR_W   = 160
local AIR_BAR_H   = 12

local function loadAssets()
    if imgIcon then return end
    imgIcon = love.graphics.newImage('assets/images/player/icon.png')
    imgBg   = love.graphics.newImage('assets/images/level/Background.png')
end

local function lerp(a, b, f) return a + (b - a) * f end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function drawPixelButton(label, cx, y, w, h, selected, alpha)
    if selected then
        love.graphics.setColor(0.18, 0.18, 0.18, alpha)
        love.graphics.rectangle('fill', cx-w/2+4, y+4, w, h)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle('fill', cx-w/2, y, w, h)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.printf(label, cx-w/2, y+h/2-FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(1, 1, 1, alpha*0.45)
        love.graphics.rectangle('line', cx-w/2, y, w, h)
        love.graphics.setColor(1, 1, 1, alpha*0.5)
        love.graphics.printf(label, cx-w/2, y+h/2-FONT_MED:getHeight()/2, w, 'center')
    end
end

-- ── Enter ─────────────────────────────────────────────────────────────────────

function OnlineAdventureState:enter(args)
    require('src/ui/View').lockGameplay()      -- (todos ven la misma zona del nivel)
    loadAssets()
    args = args or {}
    self.currentRoom = args.room or {}

    -- Efectos del jugador propio (solo en los pasos "audibles" de la predicción)
    Particles.clear()
    PlayerAdventure.fx = function(kind, x, y)
        if kind ~= 'block_break' and kind ~= 'switch_hit' then Particles.emit(kind, x, y) end
    end
    -- Las entidades las simula el servidor: sus efectos llegan como eventos 'fx'
    require('src/world/entities/Entity').fx = nil

    -- Mundo provisional hasta que llegue game_init con el nivel real
    self:_buildWorld(nil)
    self.localPaInit   = false
    self.predictor     = nil
    self.simAccum      = 0
    self.audioDrowning = false

    -- Red
    self.myIdx       = nil
    self.roster      = {}        -- [idx] = { id, name, color }
    self.rosterById  = {}        -- [id]  = { id, name, color }
    self.snapBuf     = nil
    self.pendingEvents = {}      -- eventos de otros esperando su tick de render
    self.pendingJump   = false   -- "recién presionado" acumulado hasta el próximo tick
    self.pendingCrouch = false

    -- Modo de juego (objetivo de la ronda) y su estado para el HUD
    self.mode        = Modes.get(self.currentRoom.mode) or Modes.get(Modes.DEFAULT)
    self.modeHud     = nil       -- datos del modo en cada snapshot (snap.md)
    self.introT      = 0         -- cartel de presentación del modo
    self.banners     = {}        -- avisos grandes (llegadas a la meta...)

    -- Fin de ronda: breve cierre en la partida y luego pantalla de resultados
    self.showGameOver       = false
    self.roundEnd           = nil
    self.gameOverTimer      = 0
    self.gameOverMusicPitch = nil

    -- Jugadores remotos: [idx] = OnlinePlayer (excluye al propio)
    self.remotePlayers = {}

    -- Datos propios para el HUD (del snapshot más reciente)
    self.ownData = {
        lives=3, hp=3, hpMax=3, score=0, isSpectator=false, finished=false, place=0,
    }

    -- Cámara
    self.camX     = 0
    self.camY     = 0
    self.bgScrollX = 0
    self.bgScrollY = 0

    -- Canvas
    self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)

    -- Tiempo y popups
    self.levelTime = 0
    self.popups    = {}

    -- Overlay de pausa
    self.showPause  = false
    self.pauseSel   = PAUSE_RESUME
    self.pauseAlpha = 0

    -- Overlay espectador
    self.specOverlay = false
    self.specSel     = SPEC_WAIT

    -- Input continuo muestreado cada frame
    self.inputState = { left=false, right=false, jump=false, crouch=false }

    self:_setupHandlers()

    -- game_init pudo llegar en el mismo paquete que el room_update que nos trajo aquí
    if NC.pendingGameInit then self:_onGameInit(NC.pendingGameInit) end

    -- Peleas de jefe (el estado de las zonas llega en cada snapshot)
    self.bossBanner = nil
    self.bossFightT = 0
    Sound.setLevelMusic(nil)
    Sound.playMusic('level')
    self.musicSyncT = 0
end

-- (Re)construye el nivel, los renderers de entidades y el jugador local.
-- `data` = tabla del nivel (del servidor); nil = nivel por defecto local.
function OnlineAdventureState:_buildWorld(data)
    local level
    if data then
        local ok, lv = pcall(Level.fromData, data)
        if ok then level = lv else print('[online] nivel del servidor invalido: ' .. tostring(lv)) end
    end
    self.level = level or Level.new('assets/levels/nivel01.json')
    Particles.setLevel(self.level)                 -- (las partículas físicas chocan con él)
    if self.mode then self.level.hiddenTriggers = Modes.hiddenTriggers(self.mode) end
    -- Música del nivel (la misma para todos: viene en el nivel que manda el
    -- servidor). Si ya sonaba otra, se cambia.
    local before = Sound.resolveMusic('level')
    Sound.setBaseLevelMusic(self.level.music)
    if Sound.isMusicPlaying() and Sound.resolveMusic('level') ~= before then Sound.playMusic('level') end

    -- Burbujas de oxígeno controladas por el servidor (desactiva spawn local)
    self.level.disableOxySpawn = true
    -- Los bloques solo se rompen cuando lo dice el servidor (evento 'tile')
    self.level.canBreak = false

    -- Jugador local (predicho). Se posiciona al recibir game_init.
    local sx, sy   = self.level:getSpawnPx()
    self.localPa   = PlayerAdventure:new(sx, sy)
    self.localPa.lives = 3
    self.renderX, self.renderY = sx, sy

    -- Rebote local (predicción para sentir el bounce sin latencia)
    self.localBounceCooldown = {}   -- [enemyIdx] = timer restante

    -- Renderers de entidades: el servidor controla su estado, aquí solo se dibujan
    self.enemyRenderers = {}
    for i, placement in ipairs(self.level.entities) do
        local e = Entities.create(placement)
        if e then self.enemyRenderers[i] = e end
    end
    -- Cada zona de jefe sabe qué jefes (renderers) son suyos
    BossZones.link(self.level, self.enemyRenderers)
end

function OnlineAdventureState:exit()
    require('src/ui/View').unlock()
    NC:off("s"); NC:off("ev"); NC:off("game_init")
    NC.pendingGameInit = nil
    -- Fuera de la partida (sala, hub, resultados, error): nada de la partida
    -- sigue sonando — música del nivel/jefe, ahogamiento...
    Sound.leaveMatch()
end

function OnlineAdventureState:_setupHandlers()
    NC:on("game_init", function(data) self:_onGameInit(data) end)
    NC:on("s",  function(data) self:_onSnapshot(data) end)
    NC:on("ev", function(data) self:_onEvents(data) end)
    NC:on("room_update", function(data)
        self.currentRoom = data
        -- Tras el fin de ronda la sala vuelve a WAITING: eso lo gestiona el
        -- cierre (y la pantalla de resultados), no se salta directo al lobby.
        if data.state == "WAITING" and not self.showGameOver then
            gStateMachine:change('online_room', { room=data })
        end
    end)
    NC:on("room_announce", function(data)
        if type(data) == 'table' and data.kind ~= 'game' then Notify.toast(L.fromServer(data), data.kind) end
    end)
    NC:on("room_left",    function(data) gStateMachine:change('online_hub') end)
    NC:on("kicked",       function(data) Notify.roomExit('kicked', data) end)
    NC:on("banned",       function(data) Notify.roomExit('banned', data) end)
    NC:on("room_closed",  function(data) Notify.roomExit('room_closed', data) end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or L('err.lost'),
        })
    end)
end

-- ── Datos iniciales de la partida ─────────────────────────────────────────────

function OnlineAdventureState:_onGameInit(data)
    NC.pendingGameInit = nil
    if self.localPaInit or type(data) ~= 'table' then return end
    if not Protocol.isValidOwnState(data.own) then return end

    -- Nivel y modo enviados por el servidor
    if type(data.level) == 'string' then
        local ok, lv = pcall(json.decode, data.level)
        if ok and type(lv) == 'table' then self:_buildWorld(lv) end
    end
    self.mode   = Modes.get(data.mode) or self.mode
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

-- ── Cámara ────────────────────────────────────────────────────────────────────

function OnlineAdventureState:_updateCamera(dt)
    local targetX, targetY

    -- Muriendo: la cámara se queda donde está (no sigue al cuerpo que cae),
    -- igual que en un jugador. Así tampoco se sale de la zona de jefe.
    -- Con cámara automática, en cambio, la cámara es el nivel: sigue.
    local sc = self.level.autoScroll
    local scrolling = sc and sc.state ~= 'stop'
    if self.localPaInit and not self.ownData.isSpectator and self.localPa.dying and not scrolling then return end

    local followX, followY           -- a quién mira la cámara (posición real)
    if self.ownData.isSpectator then
        -- Seguir al primer jugador vivo
        local tx, ty = nil, nil
        for _, rp in pairs(self.remotePlayers) do
            if rp.visible and not rp.isSpectator then
                tx = rp.renderX; ty = rp.renderY; break
            end
        end
        if not tx then return end
        followX, followY = tx, ty
    else
        followX, followY = self.renderX, self.renderY
    end
    targetX = followX - WINDOW_W / 2
    targetY = followY - WINDOW_H / 2

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))
    -- Dentro de una zona de jefe (o cayendo por debajo de ella en plena
    -- pelea) la cámara se queda fija en ella; también para el espectador
    local zx, zy = BossZones.cameraTarget(self.level, followX, followY)
    if zx then targetX, targetY = zx, zy end
    if scrolling then targetX = AutoScroll.cameraX(self.level) end

    local prevX, prevY = self.camX, self.camY
    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt
    if scrolling then self.camX = targetX end      -- la ventana manda, sin suavizado

    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE
    self.bgScrollX = self.bgScrollX + (self.camX - prevX) * BG_PARALLAX
    self.bgScrollY = self.bgScrollY + (self.camY - prevY) * BG_PARALLAX
    if self.bgScrollX >= bgW then self.bgScrollX = self.bgScrollX - bgW end
    if self.bgScrollY >= bgH then self.bgScrollY = self.bgScrollY - bgH end
end

-- ── Popups de puntos ─────────────────────────────────────────────────────────

-- Aviso grande centrado (llegadas a la meta, etc.). `small` = versión discreta.
function OnlineAdventureState:_addBanner(title, sub, color, small)
    table.insert(self.banners, { title=title, sub=sub, color=color or {1,1,1}, small=small, t=0 })
    if #self.banners > 3 then table.remove(self.banners, 1) end
end

function OnlineAdventureState:_spawnPopup(text, wx, wy)
    table.insert(self.popups, { text=text, wx=wx, wy=wy, timer=0 })
end

function OnlineAdventureState:_updatePopups(dt)
    for i = #self.popups, 1, -1 do
        self.popups[i].timer = self.popups[i].timer + dt
        if self.popups[i].timer >= POPUP_LIFE then table.remove(self.popups, i) end
    end
end

function OnlineAdventureState:_renderPopups()
    if #self.popups == 0 then return end
    love.graphics.setFont(FONT_MED)
    for _, pop in ipairs(self.popups) do
        local t       = pop.timer / POPUP_LIFE
        local offsetY = POPUP_RISE * (1 - (1-t)*(1-t))
        local alpha   = (t < POPUP_BOUNCE_T) and (t/POPUP_BOUNCE_T)
                        or (1 - (t - POPUP_BOUNCE_T) / (1 - POPUP_BOUNCE_T))
        local sx = math.floor(pop.wx - self.camX)
        local sy = math.floor(pop.wy - self.camY - offsetY)
        love.graphics.setColor(0, 0, 0, alpha*0.6)
        love.graphics.printf(pop.text, sx-119, sy+1, 240, 'center')
        love.graphics.setColor(1, 0.95, 0.15, alpha)
        love.graphics.printf(pop.text, sx-120, sy,   240, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Input ─────────────────────────────────────────────────────────────────────

-- Muestrea el input real una vez por frame. Los "recién presionado" se
-- acumulan hasta el próximo tick para no perderlos entre ticks.
function OnlineAdventureState:_collectInput()
    self.inputState.left   = Input.down('move_left')
    self.inputState.right  = Input.down('move_right')
    self.inputState.jump   = Input.down('jump')
    self.inputState.crouch = Input.down('crouch')
    if Input.pressed('jump')   then self.pendingJump   = true end
    if Input.pressed('crouch') then self.pendingCrouch = true end
end

function OnlineAdventureState:_clearInput()
    self.inputState = { left=false, right=false, jump=false, crouch=false }
    self.pendingJump, self.pendingCrouch = false, false
end

-- Envía los inputs no confirmados (redundancia contra pérdida de paquetes).
function OnlineAdventureState:_sendInputs()
    if not NC:isConnected() or not self.predictor then return end
    local first, list = self.predictor:unacked(Protocol.INPUT_REDUNDANCY)
    if #list == 0 then return end
    -- v = tick del mundo que estamos viendo: el servidor evalúa los choques
    -- con enemigos contra ESE estado (compensación de latencia)
    local rt = self.snapBuf and self.snapBuf:renderTick()
    NC:sendState("in", { s = first, b = list, v = rt and math.max(0, math.floor(rt + 0.5)) or nil })
end

-- ── Pause / Spectator helpers ─────────────────────────────────────────────────

function OnlineAdventureState:_getPauseOpts()
    local isAdmin = self.currentRoom and (self.currentRoom.adminId == NC.myId)
    if isAdmin then
        return { 'common.resume', 'oadv.leave_hub', 'room.stop' }   -- claves de idioma
    end
    return { 'common.resume', 'oadv.leave_hub' }
end

function OnlineAdventureState:_togglePause()
    self.showPause  = not self.showPause
    self.pauseSel   = PAUSE_RESUME
    self.pauseAlpha = 0
    -- Limpiar input al pausar para que el jugador no siga moviéndose
    if self.showPause then self:_clearInput() end
end

function OnlineAdventureState:_executePause(sel)
    local opts = self:_getPauseOpts()
    local chosen = opts[sel]
    if chosen == 'common.resume' then
        self.showPause = false
    elseif chosen == 'oadv.leave_hub' then
        NC:send("leave_room", {})
    elseif chosen == 'room.stop' then
        NC:send("stop_game", {})
        self.showPause = false
    end
end

function OnlineAdventureState:_executeSpec(sel)
    if sel == SPEC_LEAVE then
        NC:send("leave_room", {})
    else
        self.specOverlay = false
    end
end


-- ── Detección local de rebote sobre enemigos ──────────────────────────────────
-- Replica la lógica del servidor para dar feedback inmediato (sin latencia de
-- red). El rebote queda registrado en el predictor para re-aplicarlo en las
-- re-simulaciones hasta que el servidor lo confirme.
function OnlineAdventureState:_checkLocalBounce()
    local pa = self.localPa
    if pa.dying then return end
    for idx, er in pairs(self.enemyRenderers) do
        local cd = self.localBounceCooldown[idx] or 0
        if cd <= 0 then
            -- Mismas reglas que el servidor; aquí solo se predice el rebote
            local result, bvy, bdir, bdir2 = Entities.interactions.check(pa, er)
            if result == 'launch' then
                -- Trampolín: lanzado ya (bvy = vx, bdir = vy); lo confirma el servidor
                pa:launch(bvy, bdir, bdir2)
                self.localBounceCooldown[idx] = 0.3
                self.predictor:recordLaunch(bvy, bdir, bdir2)
                Sound.play(er.launchSound or 'trampoline')
                return
            elseif result == 'helmet' then
                -- Casco de Gummy: rebota (el servidor lo confirma); suena ya
                pa:bounce(bvy)
                self.localBounceCooldown[idx] = 0.3
                self.predictor:recordBounce(bvy)
                er.bonkT = 0.25
                Sound.play('helmetBounce')
                return
            elseif result == 'stomp' or result == 'pound' or result == 'bounce' then
                -- rebote con empujón lateral (jefe invulnerable; pisotón de lado a un trepador)
                local dir = (result == 'bounce') and bdir or (result == 'stomp' and bdir2) or nil
                local soft = (result == 'stomp') or nil
                pa:bounce(bvy, dir, soft)
                self.localBounceCooldown[idx] = 0.3
                self.predictor:recordBounce(bvy, dir, soft)
                -- Los jefes suenan con su propio golpe (lo manda el servidor)
                if not er.def.boss and result ~= 'bounce' then Sound.play('enemyExplode') end
                return
            end
        end
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

local GAME_OVER_DUR = 2.6  -- s de cierre en la partida antes de los resultados
local INTRO_DUR     = 4.0  -- s del cartel de presentación del modo
local BANNER_DUR    = 3.0

function OnlineAdventureState:update(dt)
    -- ── Game Over ─────────────────────────────────────────────────────────────
    if self.showGameOver then
        self.gameOverTimer = self.gameOverTimer + dt
        -- Ralentizar la música gradualmente hasta parar
        if self.gameOverMusicPitch and self.gameOverMusicPitch > 0 then
            self.gameOverMusicPitch = math.max(0, self.gameOverMusicPitch - dt * 0.55)
            Sound.setMusicPitch(self.gameOverMusicPitch)
            if self.gameOverMusicPitch <= 0 then
                Sound.stopMusic()
                self.gameOverMusicPitch = 0
            end
        end
        -- El mundo sigue animándose de fondo durante el cierre
        self.level:update(dt)
        self.level:updateFoliage(dt)
        if self.snapBuf then self.snapBuf:update(dt); self:_applyInterpolation() end
        if self.gameOverTimer >= GAME_OVER_DUR then
            Sound.setMusicPitch(1)
            Sound.stopMusic()
            gStateMachine:change('online_results', {
                results = self.roundEnd, room = self.currentRoom, mode = self.mode and self.mode.id,
            })
        end
        return
    end

    self.introT = self.introT + dt
    for i = #self.banners, 1, -1 do
        local b = self.banners[i]
        b.t = b.t + dt
        if b.t >= BANNER_DUR then table.remove(self.banners, i) end
    end

    -- ── Pausa: input del menú de pausa (el juego SIGUE corriendo) ───────────────
    if self.showPause then
        self.pauseAlpha = math.min(1, self.pauseAlpha + dt*5)
        local pauseOpts = self:_getPauseOpts()
        if Input.pressed('nav_up') then
            self.pauseSel = self.pauseSel - 1
            if self.pauseSel < 1 then self.pauseSel = #pauseOpts end
            Sound.play('select')
        end
        if Input.pressed('nav_down') then
            self.pauseSel = self.pauseSel + 1
            if self.pauseSel > #pauseOpts then self.pauseSel = 1 end
            Sound.play('select')
        end
        if Input.pressed('confirm') then
            Sound.play('select'); self:_executePause(self.pauseSel)
        end
        if Input.pressed('pause') or Input.pressed('back') then
            self:_togglePause()
        end
        -- NO hay return: todo lo demás sigue ejecutándose normalmente
    else
        -- ── Overlay espectador ────────────────────────────────────────────────
        if self.ownData.isSpectator and self.specOverlay then
            if Input.pressed('nav_up') then
                self.specSel = self.specSel - 1
                if self.specSel < 1 then self.specSel = #SPEC_OPTS end
            end
            if Input.pressed('nav_down') then
                self.specSel = self.specSel + 1
                if self.specSel > #SPEC_OPTS then self.specSel = 1 end
            end
            if Input.pressed('confirm') then self:_executeSpec(self.specSel) end
            if Input.pressed('pause') or Input.pressed('back') then
                self.specOverlay = false
            end
        end

        -- ── Activar pause / overlay espectador ────────────────────────────────
        if Input.pressed('pause') then
            if self.ownData.isSpectator then
                self.specOverlay = not self.specOverlay
                self.specSel = SPEC_WAIT
            else
                self:_togglePause()
            end
        end

        -- ── Controles táctiles ────────────────────────────────────────────────
        if Input.isMobile and not self.ownData.isSpectator then
            Input.VirtualPad.down['move_left']  = false
            Input.VirtualPad.down['move_right'] = false
            Input.VirtualPad.down['jump']       = false
            Input.VirtualPad.down['crouch']     = false
            local touches = love.touch.getTouches()
            for _, id in ipairs(touches) do
                local tx, ty = love.touch.getPosition(id)
                local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
                local scale  = math.min(sw/WINDOW_W, sh/WINDOW_H)
                local offX   = (sw - WINDOW_W*scale)/2
                local offY   = (sh - WINDOW_H*scale)/2
                local lx     = (tx-offX)/scale
                local ly     = (ty-offY)/scale
                if ly > WINDOW_H - 250 then
                    if lx >  20 and lx <  150 then Input.VirtualPad.down['move_left']  = true end
                    if lx > 170 and lx <  300 then Input.VirtualPad.down['move_right'] = true end
                    if lx > WINDOW_W-340 and lx <= WINDOW_W-200 then Input.VirtualPad.down['crouch'] = true end
                    if lx > WINDOW_W-200 and lx < WINDOW_W-20 then
                        Input.VirtualPad.down['jump'] = true
                    end
                end
            end
        end
    end  -- end if showPause / else

    -- ── Canvas ────────────────────────────────────────────────────────────────
    if self.sceneCanvas:getWidth() ~= WINDOW_W or self.sceneCanvas:getHeight() ~= WINDOW_H then
        self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end

    -- ── Tiempo: avanza localmente entre snapshots, el servidor lo corrige ─────
    self.levelTime = math.min(self.levelTime + dt, 600)

    -- ── Animaciones visuales del nivel (foliaje, burbujas) ────────────────────
    self.level:update(dt)
    self.level:updateFoliage(dt)

    -- ── Mundo remoto: interpolación entre snapshots + eventos sincronizados ──
    if self.snapBuf then
        self.snapBuf:update(dt)
        self:_applyInterpolation()
        self:_updatePendingEvents(dt)
    end
    for _, rp in pairs(self.remotePlayers) do rp:update(dt) end

    -- Bloques invisibles: se ven si los toca el jugador propio o uno remoto
    local boxes = {}
    if self.localPa and self.localPaInit and not self.localPa.dying and not self.ownData.isSpectator then
        boxes[1] = self.localPa:getOuterBounds()
    end
    for _, rp in pairs(self.remotePlayers) do
        if not rp.isSpectator and not rp.dying and not rp.firstSync then
            boxes[#boxes + 1] = PlayerAdventure.outerBoxAt(rp.x, rp.y)
        end
    end
    self.level:updateHiddenBlocks(dt, boxes)

    -- Decrementar cooldowns de rebote local
    for idx, cd in pairs(self.localBounceCooldown) do
        self.localBounceCooldown[idx] = cd - dt
    end

    -- ── Input (neutral en pausa: la física sigue corriendo) ───────────────────
    if not self.showPause and not self.ownData.isSpectator then
        self:_collectInput()
    end

    -- ── Cámara automática: la ventana avanza entre snapshots ──────────────────
    AutoScroll.clientUpdate(self.level, dt)

    -- ── Inundaciones: el agua depende solo del tiempo. Se usa el tick del
    -- servidor en el que se procesarán los inputs que predecimos ahora
    -- (reloj de snapshots + ping), así la predicción nada en la misma agua
    if self.snapBuf and self.snapBuf.clock and #(self.level.floods or {}) > 0 then
        local est = (self.snapBuf.clock + NC:getPing() / 1000 / TICK_DT) * TICK_DT
        local cur = (self.level.floodTime or 0) + dt
        if math.abs(est - cur) > 0.5 then cur = est
        else cur = cur + (est - cur) * math.min(1, dt * 2) end
        Floods.setTime(self.level, cur)
        Floods.updateFx(self.level, dt)
    end

    -- ── Zonas de puntos: quién está dentro (solo para el dibujo) ─────────────
    if #(self.level.pointAreas or {}) > 0 then
        local pos = {}
        if self.localPaInit and not self.ownData.isSpectator and not self.localPa.dying then
            pos[1] = { self.renderX, self.renderY, true }
        end
        for _, rp in pairs(self.remotePlayers) do
            if rp.visible and not rp.dying then pos[#pos+1] = { rp.x, rp.y, false } end
        end
        PointAreas.clientUpdate(self.level, dt, pos)
    end

    -- ── Jugador local: predicción a paso fijo ─────────────────────────────────
    -- (los jefes son sólidos: se choca con su posición interpolada)
    self.level.solidBodies = Entities.solidBodies(self.enemyRenderers)
    if self.predictor and not self.ownData.isSpectator then
        self.simAccum = self.simAccum + dt
        local ticks = 0
        while self.simAccum >= TICK_DT and ticks < MAX_TICKS_FRAME do
            self.simAccum = self.simAccum - TICK_DT
            ticks = ticks + 1
            local s = self.inputState
            local bits = Protocol.encodeInput(s.left, s.right, s.jump, s.crouch,
                                              self.pendingJump, self.pendingCrouch)
            self.pendingJump, self.pendingCrouch = false, false
            self.predictor:tick(bits)
            if not self.localPa.dying then self:_checkLocalBounce() end
        end
        -- Tras un tirón largo no intentar recuperar todo de golpe
        if ticks >= MAX_TICKS_FRAME then self.simAccum = 0 end
        if ticks > 0 then
            -- Los pasos "audibles" ya gestionaron el sonido del ahogamiento
            self.audioDrowning = (self.localPa.drownPhase == 'drowning') and not self.localPa.dying
            self:_sendInputs()
        end

        self.predictor:decay(dt)
        self.renderX, self.renderY = self.predictor:renderPos(self.simAccum / TICK_DT)
    end

    -- ── Música: el respawn ocurre en el servidor (aquí solo llega la posición
    -- corregida), así que tras morir ahogado nadie la reanudaba. Vuelve en
    -- cuanto no estamos ahogándonos ni en plena animación de muerte.
    if self.localPaInit and not self.audioDrowning and not Sound.isMusicPlaying()
       and (self.ownData.isSpectator or (not self.localPa.dying and self.localPa.drownPhase ~= 'drowning')) then
        Sound.playMusic('level')
    end

    -- ── Música del nivel sincronizada con el reloj del servidor: todos oyen
    -- el mismo punto de la canción (tick 0 = empieza la ronda). Solo la del
    -- nivel (la del jefe arranca con su evento).
    self.musicSyncT = (self.musicSyncT or 0) - dt
    if self.musicSyncT <= 0 and self.snapBuf and self.snapBuf.clock and not Sound.getLevelMusic() then
        self.musicSyncT = 1
        local serverNow = (self.snapBuf.clock + NC:getPing() / 2000 / TICK_DT) * TICK_DT
        Sound.syncMusic('level', serverNow)
    end

    -- ── Oyente de los sonidos del mundo: nosotros (o lo que miramos) ──────────
    if self.localPaInit and not self.ownData.isSpectator then
        Sound.setListener(self.renderX, self.renderY)
    else
        Sound.setListener(self.camX + WINDOW_W / 2, self.camY + WINDOW_H / 2)
    end

    -- ── Jefes: música de la pelea y carteles ─────────────────────────────────
    self:_updateBoss(dt)

    -- ── Cámara ────────────────────────────────────────────────────────────────
    self:_updateCamera(dt)
    self:_updatePopups(dt)
    Particles.update(dt)
end

function OnlineAdventureState:_updateBoss(dt)
    if self.bossBanner then self.bossBanner.t = self.bossBanner.t + dt end
    self.bossFightT = self.bossFightT + dt
    local want = BossZones.music(self.level)
    if want ~= Sound.getLevelMusic() then
        Sound.setLevelMusic(want)
        if want == BossZones.SILENCE then Sound.stopMusic()          -- (entrada del jefe: silencio)
        elseif not self.audioDrowning then Sound.playMusic('level') end
    end
end

-- Barras de vida (jefe y jugadores) durante la pelea y aviso de espera
function OnlineAdventureState:_renderBossHUD()
    local z = BossZones.fighting(self.level)
    if z and not self.showGameOver then
        local y = 48
        for _, b in ipairs(z.bosses) do
            if b.alive then BossHud.drawBoss(b, y, math.min(1, self.bossFightT / 0.8)); y = y + 72 end
        end
        -- Un jugador por fila, con su color de la sala
        local list = {}
        for idx = 1, 16 do
            local r = self.roster[idx]
            if r then
                local e
                if idx == self.myIdx then
                    local od = self.ownData
                    if not od.finished then
                        local pa = self.localPa
                        e = { name = r.name, color = r.color, hp = pa.hp, hpMax = pa.hpMax, key = r,
                              dead = od.isSpectator or pa.dying }
                    end
                else
                    local rp = self.remotePlayers[idx]
                    if rp and rp.visible and not rp.finished then
                        e = { name = r.name, color = r.color, hp = rp.hp, hpMax = 3, key = r,
                              dead = rp.isSpectator or rp.dying }
                    end
                end
                if e then list[#list+1] = e end
            end
        end
        BossHud.drawPlayers(list, 20, 110)
    elseif self.localPaInit and not self.ownData.isSpectator and not self.showGameOver then
        -- Fuera de una pelea: la vida propia solo si le falta algo
        local pa, r = self.localPa, self.roster[self.myIdx]
        if pa.hp < pa.hpMax and not pa.dying then
            BossHud.drawPlayers({ { name = r and r.name or L('hud.you'), color = r and r.color, hp = pa.hp,
                                    hpMax = pa.hpMax, key = r or pa } }, 20, 110)
        end
    end
    -- Esperando a que lleguen todos a la zona
    if self.localPaInit and not self.ownData.isSpectator then
        local wz = BossZones.arenaAt(self.level, self.renderX, self.renderY)
        if wz and wz.state == 'waiting' then BossHud.drawWaiting(wz.arrived, wz.needed) end
    end
    if self.bossBanner then
        BossHud.drawBanner(self.bossBanner.text, self.bossBanner.t, 2.2, self.bossBanner.col)
    end
    if not self.showGameOver then BossHud.drawScrollCountdown(self.level.autoScroll) end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineAdventureState:render()
    -- Temblor de pantalla (impactos, explosiones): solo al dibujar
    local shx, shy = Particles.shakeOffset()
    local realCamX, realCamY = self.camX, self.camY
    -- (cámara en píxeles enteros al dibujar: ver AdventureState:render)
    self.camX, self.camY = math.floor(self.camX + shx + 0.5), math.floor(self.camY + shy + 0.5)
    self:_renderScene()
    self.camX, self.camY = realCamX, realCamY
end

function OnlineAdventureState:_renderScene()
    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE

    love.graphics.push()
    love.graphics.origin()
    -- El recorte de lovesize (bandas negras) está en píxeles de la PANTALLA:
    -- dentro del canvas de la escena (tamaño lógico) recortaba otra zona y, con
    -- la ventana a otro tamaño que 1280x720, el juego salía cortado/descuadrado
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    love.graphics.setCanvas(self.sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- Fondo parallax
    love.graphics.setColor(1, 1, 1, 1)
    local startX = -(math.floor(self.bgScrollX) % bgW)
    local startY = -(math.floor(self.bgScrollY) % bgH)
    if startX > 0 then startX = startX - bgW end
    if startY > 0 then startY = startY - bgH end
    local bx = startX
    while bx < WINDOW_W do
        local by = startY
        while by < WINDOW_H do
            love.graphics.draw(imgBg, bx, by, 0, BG_SCALE, BG_SCALE)
            by = by + bgH
        end
        bx = bx + bgW
    end

    -- Nivel
    self.level:render(self.camX, self.camY)
    self.level:renderVents(self.camX, self.camY)
    self.level:renderFoliageBack(self.camX, self.camY)

    -- Enemigos (estado controlado por el servidor)
    for i, er in pairs(self.enemyRenderers) do
        if er.alive and not er.renderFront then
            er:render(self.camX, self.camY)
        end
    end

    -- Jugadores remotos via OnlinePlayer (excluye al propio)
    local adminId = self.currentRoom and self.currentRoom.adminId
    for _, rp in pairs(self.remotePlayers) do
        rp.isHost = (rp.id == adminId)
        if rp.visible then rp:render(self.camX, self.camY) end
    end

    -- Jugador propio ya en la meta
    if self.selfGhost and self.selfGhost.visible and self.ownData.finished then
        self.selfGhost.isHost = (self.selfGhost.id == adminId)
        self.selfGhost:render(self.camX, self.camY)
    end

    -- Jugador propio via simulación local (posición interpolada + corrección suave)
    if self.localPaInit and not self.ownData.isSpectator then
        local pa = self.localPa
        local sx, sy = pa.x, pa.y
        pa.x, pa.y = self.renderX, self.renderY
        pa:render(self.camX, self.camY)
        pa.isLocalView = true
        PointAreas.drawProgress(self.level, pa, self.renderX - self.camX, self.renderY - self.camY)
        Particles.render(self.camX, self.camY)
        if DEBUG_HITBOX then pa:renderDebug(self.camX, self.camY); self.level:renderDebug(self.camX, self.camY) end
        pa.x, pa.y = sx, sy
    end

    -- Entidades en un plano por delante de los jugadores (renderFront: pez globo)
    for _, er in pairs(self.enemyRenderers) do
        if er.alive and er.renderFront then er:render(self.camX, self.camY) end
    end

    -- Foliaje y burbujas
    self.level:renderFoliage(self.camX, self.camY)
    self.level:renderBubbles(self.camX, self.camY)

    love.graphics.setCanvas()
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()

    -- Efecto agua
    love.graphics.setColor(1, 1, 1, 1)
    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- HUD (antes, las franjas de cine de la entrada de un jefe: el HUD va encima)
    BossHud.drawCinema(self.level)
    self:_renderHUD()

    -- Controles táctiles
    if Input.isMobile and Input.lastDevice == 'touch' and not self.ownData.isSpectator then
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle('fill',  85, WINDOW_H-125, 65)
        love.graphics.circle('fill', 235, WINDOW_H-125, 65)
        love.graphics.circle('fill', WINDOW_W-110, WINDOW_H-125, 65)
        love.graphics.circle('fill', WINDOW_W-250, WINDOW_H-125, 65)
        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf('<', 20,  WINDOW_H-140, 130, 'center')
        love.graphics.printf('>', 170, WINDOW_H-140, 130, 'center')
        love.graphics.printf('A', WINDOW_W-175, WINDOW_H-140, 130, 'center')
        love.graphics.printf('v', WINDOW_W-315, WINDOW_H-132, 130, 'center')
    end
    if not self.showGameOver and not self.showPause and not self.specOverlay then
        CornerButtons.drawPause(self.pauseHover)
    end

    -- Overlays
    self:_renderBossHUD()
    if self.showPause then self:_renderPauseOverlay() end
    self:_renderModeHUD()
    if self.ownData.isSpectator and not self.showGameOver then self:_renderSpectatorOverlay() end

    -- ── Game Over overlay ─────────────────────────────────────────────────────
    if self.showGameOver then self:_renderGameOver() end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

function OnlineAdventureState:_renderGameOver()
    local t  = self.gameOverTimer
    local a  = math.min(1, t / 0.35)
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    -- Franja que entra desde los lados con el título
    local ease  = 1 - (1 - math.min(1, t / 0.45)) ^ 3
    local bandH = 150
    local by    = WINDOW_H / 2 - bandH / 2
    local col   = self.mode and self.mode.color or {1, 0.85, 0.2}
    love.graphics.setColor(0.04, 0.04, 0.07, 0.92)
    love.graphics.rectangle('fill', WINDOW_W * (1 - ease) / 2, by, WINDOW_W * ease, bandH)
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.rectangle('fill', WINDOW_W * (1 - ease) / 2, by, WINDOW_W * ease, 4)
    love.graphics.rectangle('fill', WINDOW_W * (1 - ease) / 2, by + bandH - 4, WINDOW_W * ease, 4)

    local s   = 1 + 0.25 * math.max(0, 1 - t / 0.3)
    local ta  = math.min(1, math.max(0, (t - 0.15) / 0.25))
    love.graphics.setFont(FONT_BIG)
    local title = L('oadv.round_over')
    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, by + 52)
    love.graphics.scale(s, s)
    love.graphics.setColor(0, 0, 0, ta)
    love.graphics.printf(title, -WINDOW_W / 2 + 3, -FONT_BIG:getHeight() / 2 + 3, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.2, ta)
    love.graphics.printf(title, -WINDOW_W / 2, -FONT_BIG:getHeight() / 2, WINDOW_W, 'center')
    love.graphics.pop()

    -- Motivo en el idioma de este jugador (reasonText del servidor = español)
    local re = self.roundEnd or {}
    local reason = re.reason and Modes.reasonText(Modes.get(re.mode), re.reason) or ''
    if reason == '' then reason = re.reasonText or '' end
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, ta * 0.85)
    love.graphics.printf(reason, 0, by + 96, WINDOW_W, 'center')
end

-- Presentación del modo, contador/objetivo y avisos grandes
function OnlineAdventureState:_renderModeHUD()
    local mode = self.mode
    if not mode then return end
    local col  = mode.color
    local cx   = WINDOW_W / 2

    -- Panel de objetivo, siempre visible arriba al centro: el objetivo del
    -- modo (grande, en su color) y la línea de estado (monstruos que quedan,
    -- tiempo...). Los textos los da el modo (objective, hudLine). Si no cabe
    -- entre el marcador y las vidas (pantallas estrechas), baja debajo.
    local md = self.modeHud or {}
    local objective = (mode.objective or mode.label):upper()
    local line, urgent, big
    if mode.hudLine then line, urgent, big = mode.hudLine(md) end
    line = line and line:upper() or nil
    -- Destello cuando cambia el estado (muere un monstruo, empieza la cuenta atrás...)
    if line ~= self.hudLinePrev then
        if self.hudLinePrev ~= nil then self.hudFlashT = 0.6 end
        self.hudLinePrev = line
    end
    self.hudFlashT = math.max(0, (self.hudFlashT or 0) - love.timer.getDelta())
    local flash = self.hudFlashT / 0.6

    -- Panel compacto (3 líneas: MODO / objetivo / estado) arriba, entre el
    -- marcador y las vidas. Si ahí no cabe (pantallas estrechas) se reduce a
    -- UNA línea fina debajo del marcador. Durante una pelea de jefe no se
    -- dibuja (la parte de arriba es de sus barras).
    local title = mode.label:upper()
    local iw, ih = PixelIcons.size(mode.icon or '')
    local iconW = iw > 0 and iw * 2 + 10 or 0
    local wT = FONT_MED:getWidth(title) + iconW
    local wO = FONT_SMALL:getWidth(objective)
    local wB = line and FONT_MED:getWidth(line) or 0
    local w  = math.max(wT, wO, wB) + 32
    -- Hueco libre centrado entre el marcador (PUNTOS/TIEMPO: su ancho cambia
    -- con el idioma) y las vidas/pausa de la derecha
    local labelW = math.max(FONT_BIG:getWidth(L('hud.score')), FONT_BIG:getWidth(L('hud.time')))
    local hudRight = 20 + labelW + 20 + FONT_BIG:getWidth("0'00''00")
    local topFree = WINDOW_W - 2 * math.max(hudRight + 12, 150 + 12)
    local boss = BossZones.fighting(self.level)
    local ph, pyBottom
    if boss then
        -- Pelea de jefe: la parte de arriba es de sus barras; el objetivo
        -- desaparece y vuelve al terminar (la cuenta atrás grande, si la hay,
        -- sí se ve, debajo de las barras)
        local n = 0
        for _, b in ipairs(boss.bosses) do if b.alive then n = n + 1 end end
        ph, pyBottom = 0, 48 + 72 * math.max(1, n)
    elseif w <= topFree then
        local py = 6
        ph = 8 + FONT_MED:getHeight() + 6 + FONT_SMALL:getHeight() + (line and (6 + FONT_MED:getHeight()) or 0) + 8
        local px = math.floor(cx - w / 2)
        love.graphics.setColor(0, 0, 0, 0.62)
        love.graphics.rectangle('fill', px, py, w, ph)
        love.graphics.setColor(col[1], col[2], col[3], 0.12 + 0.35 * flash)
        love.graphics.rectangle('fill', px, py, w, ph)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle('fill', px, py, w, 3)
        love.graphics.rectangle('line', px, py, w, ph)
        local function shadowed(font, text, x, y, c)
            love.graphics.setFont(font)
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.print(text, x + 2, y + 2)
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.print(text, x, y)
        end
        local ty = py + 9
        local tx = math.floor(cx - wT / 2)
        if iw > 0 then PixelIcons.draw(mode.icon, tx, ty + FONT_MED:getHeight() / 2 - ih, 2); tx = tx + iconW end
        shadowed(FONT_MED, title, tx, ty, col)
        local oy = ty + FONT_MED:getHeight() + 6
        shadowed(FONT_SMALL, objective, math.floor(cx - wO / 2), oy, { 1, 1, 1 })
        if line then
            local by = oy + FONT_SMALL:getHeight() + 6
            local bs = 1 + 0.15 * flash
            local lw = FONT_MED:getWidth(line)
            love.graphics.setFont(FONT_MED)
            love.graphics.push()
            love.graphics.translate(cx, by + FONT_MED:getHeight() / 2)
            love.graphics.scale(bs, bs)
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.print(line, -lw / 2 + 2, -FONT_MED:getHeight() / 2 + 2)
            local blink = urgent and math.floor(love.timer.getTime() * 4) % 2 == 0
            if blink then love.graphics.setColor(1, 0.3, 0.25, 1) else love.graphics.setColor(1, 0.92, 0.55, 1) end
            love.graphics.print(line, -lw / 2, -FONT_MED:getHeight() / 2)
            love.graphics.pop()
        end
        pyBottom = py + ph
    else
        -- Una sola línea: [icono] OBJETIVO · ESTADO
        local text = objective .. (line and ('  ·  ' .. line) or '')
        local font = FONT_SMALL
        local tw = font:getWidth(text) + iconW
        local lw = tw + 24
        local lh = 26
        -- Justo debajo del marcador
        local py = 100
        local px = math.floor(cx - lw / 2)
        love.graphics.setColor(0, 0, 0, 0.62)
        love.graphics.rectangle('fill', px, py, lw, lh)
        love.graphics.setColor(col[1], col[2], col[3], 0.12 + 0.35 * flash)
        love.graphics.rectangle('fill', px, py, lw, lh)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle('line', px, py, lw, lh)
        local tx = px + 12
        if iw > 0 then PixelIcons.draw(mode.icon, tx, py + lh / 2 - ih, 2); tx = tx + iconW end
        love.graphics.setFont(font)
        local blink = urgent and math.floor(love.timer.getTime() * 4) % 2 == 0
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.print(text, tx + 1, py + lh / 2 - font:getHeight() / 2 + 1)
        if blink then love.graphics.setColor(1, 0.3, 0.25, 1) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.print(text, tx, py + lh / 2 - font:getHeight() / 2)
        ph, pyBottom = lh, py + lh
    end
    local h, py = ph, pyBottom - ph
    if big then
        local pulse = urgent and (1 + 0.12 * math.abs(math.sin(love.timer.getTime() * 6))) or 1
        love.graphics.setFont(FONT_BIG)
        love.graphics.push()
        love.graphics.translate(cx, py + h + 34)
        love.graphics.scale(pulse * 1.4, pulse * 1.4)
        local bw = FONT_BIG:getWidth(big)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(big, -bw / 2 + 2, -FONT_BIG:getHeight() / 2 + 2)
        if urgent then love.graphics.setColor(1, 0.25, 0.2, 1) else love.graphics.setColor(1, 0.95, 0.3, 1) end
        love.graphics.print(big, -bw / 2, -FONT_BIG:getHeight() / 2)
        love.graphics.pop()
    end

    -- Cartel de presentación: nombre del modo + objetivo
    if self.introT < INTRO_DUR and not self.showGameOver then
        local t  = self.introT
        local a  = math.min(1, t / 0.3) * math.min(1, (INTRO_DUR - t) / 0.6)
        local slide = (1 - math.min(1, t / 0.35)) ^ 3 * 60
        local y  = WINDOW_H * 0.26 - slide
        love.graphics.setColor(0, 0, 0, 0.6 * a)
        love.graphics.rectangle('fill', 0, y - 14, WINDOW_W, 104)
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.rectangle('fill', 0, y - 14, WINDOW_W, 3)
        love.graphics.rectangle('fill', 0, y + 87, WINDOW_W, 3)
        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.printf(mode.label, 3, y + 3, WINDOW_W, 'center')
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.printf(mode.label, 0, y, WINDOW_W, 'center')
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, a * 0.9)
        -- (si ocupa dos líneas, con aire entre ellas: esta fuente no deja hueco)
        local lh = FONT_SMALL:getLineHeight()
        FONT_SMALL:setLineHeight(1.6)
        love.graphics.printf(mode.tagline, WINDOW_W * 0.15, y + 50, WINDOW_W * 0.7, 'center')
        FONT_SMALL:setLineHeight(lh)
    end

    -- Avisos grandes
    local y = WINDOW_H * 0.36
    for _, b in ipairs(self.banners) do
        local t = b.t
        local a = math.min(1, t / 0.2) * math.min(1, (BANNER_DUR - t) / 0.5)
        local s = 1 + 0.4 * math.max(0, 1 - t / 0.25)
        local c = b.color
        local font = b.small and FONT_MED or FONT_BIG
        love.graphics.setFont(font)
        love.graphics.push()
        love.graphics.translate(cx, y)
        love.graphics.scale(s, s)
        love.graphics.setColor(0, 0, 0, a * 0.85)
        love.graphics.printf(b.title, -WINDOW_W / 2 + 3, 3, WINDOW_W, 'center')
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.printf(b.title, -WINDOW_W / 2, 0, WINDOW_W, 'center')
        love.graphics.pop()
        if b.sub then
            love.graphics.setFont(FONT_SMALL)
            love.graphics.setColor(0, 0, 0, a * 0.8)
            love.graphics.printf(b.sub, 2, y + font:getHeight() + 10, WINDOW_W, 'center')
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.printf(b.sub, 0, y + font:getHeight() + 8, WINDOW_W, 'center')
        end
        y = y + font:getHeight() + 40
    end
end

-- ── HUD ───────────────────────────────────────────────────────────────────────

function OnlineAdventureState:_renderHUD()
    love.graphics.setFont(FONT_BIG)
    local fh     = FONT_BIG:getHeight()
    local labelX = 20
    local gap    = 20
    local row1Y  = 16
    local row2Y  = row1Y + fh + 10

    local od         = self.ownData
    -- Reloj: sube desde 0 o, en los modos con tiempo, baja hasta 0
    local shown      = self.roundEndAt and math.max(0, self.roundEndAt - self.levelTime) or self.levelTime
    local totalSecs  = math.floor(shown)
    local mins       = math.floor(totalSecs/60)
    local secs       = totalSecs % 60
    local centis     = math.floor((shown - math.floor(shown))*100)
    local timeStr    = mins .. string.format("'%02d''%02d", secs, centis)
    local scoreStr   = string.format('%06d', od.score or 0)

    local function printOut(text, x, y, r, g, b, a)
        love.graphics.setColor(0, 0, 0, (a or 1)*0.75)
        love.graphics.print(text, x+2, y+2)
        love.graphics.setColor(r, g, b, a or 1)
        love.graphics.print(text, x, y)
    end

    local scoreLabelW = FONT_BIG:getWidth(L('hud.score'))
    local timeLabelW  = FONT_BIG:getWidth(L('hud.time'))
    local maxLabelW   = math.max(scoreLabelW, timeLabelW)
    local valueStartX = labelX + maxLabelW + gap
    local maxValueW   = math.max(FONT_BIG:getWidth(scoreStr), FONT_BIG:getWidth(timeStr))
    local valueEndX   = valueStartX + maxValueW
    local sw = FONT_BIG:getWidth(scoreStr)
    local tw = FONT_BIG:getWidth(timeStr)

    printOut(L('hud.score'), labelX,          row1Y, 1, 0.95, 0.15)
    printOut(scoreStr, valueEndX - sw, row1Y, 1, 1, 1)

    -- TIME: parpadea rojo cuando se acaba (60 s del límite general; 10 s de un
    -- modo con tiempo, que ya avisa con su cuenta atrás grande)
    local timeLeft = self.roundEndAt and (shown + 50) or (600 - self.levelTime)
    local tr, tg, tb = 1, 0.95, 0.15
    local vr, vg, vb = 1, 1,    1
    if timeLeft < 60 then
        local red = math.floor(love.timer.getTime()) % 2 == 0
        if red then
            tr, tg, tb = 1, 0.10, 0.10
            vr, vg, vb = 1, 0.20, 0.20
        end
    end
    printOut(L('hud.time'),  labelX,          row2Y, tr, tg, tb)
    printOut(timeStr,  valueEndX - tw, row2Y, vr, vg, vb)

    -- Vidas e indicadores del jugador local
    if not od.isSpectator then
        local iconW = imgIcon:getWidth()  * ICON_SCALE
        local iconH = imgIcon:getHeight() * ICON_SCALE
        local label  = 'x' .. (od.lives or 0)
        local labelW = FONT_BIG:getWidth(label)
        local totalW = iconW + gap + labelW
        local sx     = WINDOW_W - totalW - 20
        local sy     = 14
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(imgIcon, sx, sy, 0, ICON_SCALE, ICON_SCALE)
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(label, sx+iconW+gap, sy+iconH/2-FONT_BIG:getHeight()/2)

        -- Barra de aire (ahogamiento) — delegada al jugador local
        if self.localPa and self.localPaInit then
            self.localPa:renderAirBar()
            self.localPa:renderDrownCountdown(self.renderX - self.camX, self.renderY - self.camY)
        end
    elseif od.finished then
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 0.85, 0.2, 0.95)
        love.graphics.printf(L('oadv.finish_place', { n = od.place or 0 }), WINDOW_W-240, 20, 220, 'right')
    else
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.printf(L('oadv.spectator'), WINDOW_W-180, 16, 160, 'right')
    end

    -- Indicador ONLINE
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0.3, 1, 0.5, 0.65)
    local roomName = (self.currentRoom and self.currentRoom.name) or "Online"
    love.graphics.printf(L('oadv.online', { room = roomName }), 0, WINDOW_H-22, WINDOW_W-14, 'right')

    -- Corona: tú eres el host (admin) de la sala
    if self.currentRoom and self.currentRoom.adminId == NC.myId then
        local tw = FONT_SMALL:getWidth(L('oadv.online', { room = roomName }))
        local px = 3
        -- Centrada con el texto según el cuerpo de la corona (filas 4-9 de
        -- la matriz), no con sus puntas: si no, a la vista queda baja.
        local textMidY = WINDOW_H - 22 + FONT_SMALL:getHeight() / 2
        PixelIcons.crown(WINDOW_W - 14 - tw - PixelIcons.CROWN_W * px - 6,
                         textMidY - 6.5 * px, px)
    end

    -- Estadísticas de red (F1): ping, retardo de interpolación, correcciones
    if DEBUG_HITBOX and self.snapBuf and self.predictor then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.format(
            'PING %dms  INTERP %.0fms  JITTER %.1f  CORR %d (ult %.1fpx)',
            NC:getPing(), self.snapBuf.delay * TICK_DT * 1000, self.snapBuf.jitter,
            self.predictor.corrections, self.predictor.lastError), 14, WINDOW_H-40)
    end

    self:_renderPopups()
end

-- ── Overlay de pausa ──────────────────────────────────────────────────────────

function OnlineAdventureState:_renderPauseOverlay()
    local a        = self.pauseAlpha
    local opts     = self:_getPauseOpts()
    local btnW     = 300
    local btnH     = 48
    local btnGap   = 14
    local totalBH  = #opts * btnH + (#opts - 1) * btnGap
    local panelW   = 440
    local panelH   = 72 + totalBH + 32
    local panelX   = math.floor((WINDOW_W - panelW) / 2)
    local panelY   = math.floor((WINDOW_H - panelH) / 2)

    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    love.graphics.setColor(0.08, 0.08, 0.12, 0.90 * a)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH)
    love.graphics.setColor(1, 0.85, 0, 0.6 * a)
    love.graphics.rectangle('line', panelX,   panelY,   panelW,   panelH)
    love.graphics.rectangle('line', panelX+2, panelY+2, panelW-4, panelH-4)

    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(1, 0.95, 0.15, a)
    love.graphics.printf(L('pause.title'), 0, panelY + 16, WINDOW_W, 'center')

    love.graphics.setFont(FONT_MED)
    local startBY = panelY + 68
    for i, opt in ipairs(opts) do
        local by = startBY + (i - 1) * (btnH + btnGap)
        local col = (opt == 'room.stop') and {1,0.4,0.4} or nil
        if col and i == self.pauseSel then
            love.graphics.setColor(0.12, 0.12, 0.12, a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2 + 4, by + 4, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(0, 0, 0, a)
            love.graphics.printf(L(opt):upper(), WINDOW_W/2 - btnW/2, by + btnH/2 - FONT_MED:getHeight()/2, btnW, 'center')
        elseif col then
            love.graphics.setColor(col[1], col[2], col[3], 0.2 * a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], 0.55 * a)
            love.graphics.rectangle('line', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], 0.8 * a)
            love.graphics.printf(L(opt):upper(), WINDOW_W/2 - btnW/2, by + btnH/2 - FONT_MED:getHeight()/2, btnW, 'center')
        else
            drawPixelButton(L(opt):upper(), WINDOW_W/2, by, btnW, btnH, i == self.pauseSel, a)
        end
    end
end

-- ── Overlay espectador ────────────────────────────────────────────────────────

function OnlineAdventureState:_renderSpectatorOverlay()
    local finished = self.ownData.finished
    love.graphics.setFont(FONT_SMALL)
    if finished then
        love.graphics.setColor(1, 0.85, 0.2, 0.9)
        love.graphics.printf(L('oadv.arrived_wait'), 0, WINDOW_H - 58, WINDOW_W, 'center')
    else
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.printf(L('oadv.spectator'), 0, WINDOW_H - 58, WINDOW_W, 'center')
    end

    if not self.specOverlay then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf(L(CornerButtons.pointerMode() and 'oadv.opts_touch' or 'oadv.opts_key'),
                             0, WINDOW_H - 36, WINDOW_W, 'center')
        return
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    local panelW, panelH = 380, 180
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)
    love.graphics.setColor(0.08, 0.08, 0.12, 0.90)
    love.graphics.rectangle('fill', panelX, panelY, panelW, panelH)
    love.graphics.setColor(0.7, 0.7, 1, 0.55)
    love.graphics.rectangle('line', panelX, panelY, panelW, panelH)
    love.graphics.rectangle('line', panelX+2, panelY+2, panelW-4, panelH-4)

    love.graphics.setFont(FONT_BIG)
    if finished then
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.printf(L('oadv.finished'), 0, panelY + 16, WINDOW_W, 'center')
    else
        love.graphics.setColor(0.7, 0.7, 1, 1)
        love.graphics.printf(L('oadv.eliminated'), 0, panelY + 16, WINDOW_W, 'center')
    end

    local btnW, btnH = 260, 44
    local btnGap = 12
    local totalBH = #SPEC_OPTS * btnH + (#SPEC_OPTS-1) * btnGap
    local startBY = panelY + panelH/2 - totalBH/2 + 16
    love.graphics.setFont(FONT_MED)
    for i, opt in ipairs(SPEC_OPTS) do
        local by = startBY + (i-1) * (btnH + btnGap)
        drawPixelButton(L(opt), WINDOW_W/2, by, btnW, btnH, i==self.specSel, 1)
    end
end

-- ── Ratón / táctil ────────────────────────────────────────────────────────────
-- Misma geometría que _renderPauseOverlay / _renderSpectatorOverlay.

function OnlineAdventureState:_pauseRects()
    local n      = #self:_getPauseOpts()
    local btnW, btnH, gap = 300, 48, 14
    local totalBH = n * btnH + (n - 1) * gap
    local panelW, panelH = 440, 72 + totalBH + 32
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)
    local rects  = {}
    for i = 1, n do
        rects[i] = { x = WINDOW_W / 2 - btnW / 2, y = panelY + 68 + (i - 1) * (btnH + gap), w = btnW, h = btnH }
    end
    return rects, { x = panelX, y = panelY, w = panelW, h = panelH }
end

function OnlineAdventureState:_specRects()
    local n = #SPEC_OPTS
    local btnW, btnH, gap = 260, 44, 12
    local panelW, panelH = 380, 180
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)
    local totalBH = n * btnH + (n - 1) * gap
    local startBY = panelY + panelH / 2 - totalBH / 2 + 16
    local rects = {}
    for i = 1, n do
        rects[i] = { x = WINDOW_W / 2 - btnW / 2, y = startBY + (i - 1) * (btnH + gap), w = btnW, h = btnH }
    end
    return rects, { x = panelX, y = panelY, w = panelW, h = panelH }
end

local function inRect(r, x, y, pad)
    pad = pad or 0
    return x >= r.x - pad and x <= r.x + r.w + pad and y >= r.y - pad and y <= r.y + r.h + pad
end

function OnlineAdventureState:mousemoved(tx, ty)
    self.pauseHover = CornerButtons.hitPause(tx, ty)
    if self.showPause then
        for i, r in ipairs((self:_pauseRects())) do
            if inRect(r, tx, ty, 4) and self.pauseSel ~= i then self.pauseSel = i; Sound.play('select') end
        end
    elseif self.ownData.isSpectator and self.specOverlay then
        for i, r in ipairs((self:_specRects())) do
            if inRect(r, tx, ty, 4) and self.specSel ~= i then self.specSel = i; Sound.play('select') end
        end
    end
end

function OnlineAdventureState:touchpressed(id, tx, ty)
    if self.showGameOver then return end
    if self.showPause then
        local rects, panel = self:_pauseRects()
        for i, r in ipairs(rects) do
            if inRect(r, tx, ty, 4) then
                self.pauseSel = i; Sound.play('select'); self:_executePause(i); return
            end
        end
        if not inRect(panel, tx, ty) then self:_togglePause() end    -- fuera = reanudar
        return
    end
    if self.ownData.isSpectator then
        if self.specOverlay then
            local rects, panel = self:_specRects()
            for i, r in ipairs(rects) do
                if inRect(r, tx, ty, 4) then
                    self.specSel = i; Sound.play('select'); self:_executeSpec(i); return
                end
            end
            if not inRect(panel, tx, ty) then self.specOverlay = false end
        elseif CornerButtons.hitPause(tx, ty) then
            self.specOverlay, self.specSel = true, SPEC_WAIT
        end
        return
    end
    if CornerButtons.hitPause(tx, ty) then
        Sound.play('select'); self:_togglePause(); return
    end
    -- Móvil: toque de un solo cuadro en los botones de acción
    if Input.isMobile and ty > WINDOW_H - 250 then
        if tx > WINDOW_W - 200 and tx < WINDOW_W - 20 then
            Input.VirtualPad._pressedThisFrame['jump'] = true
        elseif tx > WINDOW_W - 340 and tx <= WINDOW_W - 200 then
            Input.VirtualPad._pressedThisFrame['crouch'] = true
        end
    end
end

return OnlineAdventureState
