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
local Level                = require 'src/world/Level'
local Entities             = require 'src/world/Entities'
local PlayerAdventure      = require 'src/entities/PlayerAdventure'
local OnlinePlayer         = require 'src/entities/OnlinePlayer'
local NC                   = require 'src/network/NetworkClient'
local Protocol             = require 'src/network/Protocol'
local Predictor            = require 'src/network/Predictor'
local SnapshotBuffer       = require 'src/network/SnapshotBuffer'
local PixelIcons           = require 'src/ui/PixelIcons'
local Modes                = require 'src/world/Modes'
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
local SPEC_OPTS  = { 'ESPERAR', 'SALIR AL HUB' }

-- Assets
local imgIcon = nil
local imgBg   = nil
local BG_SCALE    = 15
local BG_PARALLAX = 0.3
local ICON_SCALE  = 4
local HP_BAR_W    = 80
local HP_BAR_H    = 14
local HP_BAR_GAP  = 8
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
    loadAssets()
    args = args or {}
    self.currentRoom = args.room or {}

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

    Sound.playMusic('level')
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

    -- Burbujas de oxígeno controladas por el servidor (desactiva spawn local)
    self.level.disableOxySpawn = true

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
end

function OnlineAdventureState:exit()
    NC:off("s"); NC:off("ev"); NC:off("game_init")
    NC.pendingGameInit = nil
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
    NC:on("room_announce", function(data) end)
    NC:on("room_left",    function(data) gStateMachine:change('online_hub') end)
    NC:on("room_closed",  function(data) gStateMachine:change('online_hub') end)
    NC:on("kicked",       function(data) gStateMachine:change('online_hub') end)
    NC:on("banned",       function(data) gStateMachine:change('online_hub') end)
    NC:on("connection_lost", function(data)
        gStateMachine:change('online_error', {
            code = "ERR_CONNECTION_LOST",
            msg  = data.msg or "Se perdio la conexion con el servidor.",
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
    self.modeHud = type(snap.md) == 'table' and snap.md or nil

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
        if db then
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
            -- Datos propios del tipo (desde el índice 9): los interpreta la entidad
            if db[9] ~= nil then
                local xa, xb = {}, {}
                for k = 9, #db do xb[#xb+1] = db[k]; xa[#xa+1] = da[k] end
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
        if (not ev.playerId or ev.playerId ~= NC.myId) and type(ev.sound) == 'string' then
            Sound.play(ev.sound)
        end
    elseif ev.type == 'score' and ev.playerId == NC.myId then
        self:_spawnPopup('+' .. tostring(ev.delta) .. '!', ev.x or 0, ev.y or 0)
    elseif ev.type == 'air_collected' and ev.playerId == NC.myId then
        -- El servidor confirmó que recogimos una burbuja de oxígeno.
        Sound.play('airGasp')
    elseif ev.type == 'finish' then
        -- Alguien cruzó la meta (modo carrera)
        local mine  = ev.playerId == NC.myId
        local who   = self.rosterById[ev.playerId]
        local place = tonumber(ev.place) or 0
        if mine then
            self:_addBanner('¡EN LA META!', place .. 'º lugar', {1, 0.85, 0.2})
            Sound.play('finish')
            Sound.stopTracked('drowning'); self.audioDrowning = false
        else
            self:_addBanner((who and who.name or '?') .. ' llegó a la meta',
                            place == 1 and '¡Cuenta atrás de 15 s!' or (place .. 'º lugar'),
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
        Sound.stopTracked('drowning')
        self.audioDrowning = false
    end
end

-- ── Cámara ────────────────────────────────────────────────────────────────────

function OnlineAdventureState:_updateCamera(dt)
    local targetX, targetY

    if self.ownData.isSpectator then
        -- Seguir al primer jugador vivo
        local tx, ty = nil, nil
        for _, rp in pairs(self.remotePlayers) do
            if rp.visible and not rp.isSpectator then
                tx = rp.renderX; ty = rp.renderY; break
            end
        end
        if not tx then return end
        targetX = tx - WINDOW_W / 2
        targetY = ty - WINDOW_H / 2
    else
        targetX = self.renderX - WINDOW_W / 2
        targetY = self.renderY - WINDOW_H / 2
    end

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))

    local prevX, prevY = self.camX, self.camY
    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt

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
        love.graphics.printf(pop.text, sx-39, sy+1, 80, 'center')
        love.graphics.setColor(1, 0.95, 0.15, alpha)
        love.graphics.printf(pop.text, sx-40, sy,   80, 'center')
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
    NC:sendState("in", { s = first, b = list })
end

-- ── Pause / Spectator helpers ─────────────────────────────────────────────────

function OnlineAdventureState:_getPauseOpts()
    local isAdmin = self.currentRoom and (self.currentRoom.adminId == NC.myId)
    if isAdmin then
        return { 'REANUDAR', 'SALIR AL HUB', 'DETENER PARTIDA' }
    end
    return { 'REANUDAR', 'SALIR AL HUB' }
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
    if chosen == 'REANUDAR' then
        self.showPause = false
    elseif chosen == 'SALIR AL HUB' then
        NC:send("leave_room", {})
    elseif chosen == 'DETENER PARTIDA' then
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
            local result, bvy = Entities.interactions.check(pa, er)
            if result == 'stomp' then
                pa.vy        = bvy
                pa.jumpsLeft = 2
                pa.onGround  = false
                self.localBounceCooldown[idx] = 0.3
                self.predictor:recordBounce(bvy)
                Sound.play('enemyExplode')
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

    -- Decrementar cooldowns de rebote local
    for idx, cd in pairs(self.localBounceCooldown) do
        self.localBounceCooldown[idx] = cd - dt
    end

    -- ── Input (neutral en pausa: la física sigue corriendo) ───────────────────
    if not self.showPause and not self.ownData.isSpectator then
        self:_collectInput()
    end

    -- ── Jugador local: predicción a paso fijo ─────────────────────────────────
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

    -- ── Cámara ────────────────────────────────────────────────────────────────
    self:_updateCamera(dt)
    self:_updatePopups(dt)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function OnlineAdventureState:render()
    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE

    love.graphics.push()
    love.graphics.origin()
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
        if er.alive then
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
        if DEBUG_HITBOX then pa:renderDebug(self.camX, self.camY); self.level:renderDebug(self.camX, self.camY) end
        pa.x, pa.y = sx, sy
    end

    -- Foliaje y burbujas
    self.level:renderFoliage(self.camX, self.camY)
    self.level:renderBubbles(self.camX, self.camY)

    love.graphics.setCanvas()
    love.graphics.pop()

    -- Efecto agua
    love.graphics.setColor(1, 1, 1, 1)
    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- HUD
    self:_renderHUD()

    -- Controles táctiles
    if Input.isMobile and Input.lastDevice == 'touch' and not self.ownData.isSpectator then
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle('fill',  85, WINDOW_H-125, 65)
        love.graphics.circle('fill', 235, WINDOW_H-125, 65)
        love.graphics.circle('fill', WINDOW_W-110, WINDOW_H-125, 65)
        love.graphics.circle('fill', WINDOW_W-50, 50, 30)
        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf('<', 20,  WINDOW_H-140, 130, 'center')
        love.graphics.printf('>', 170, WINDOW_H-140, 130, 'center')
        love.graphics.printf('A', WINDOW_W-175, WINDOW_H-140, 130, 'center')
        love.graphics.printf('||', WINDOW_W-80, 40, 60, 'center')
    end

    -- Overlays
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
    local title = '¡RONDA TERMINADA!'
    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, by + 52)
    love.graphics.scale(s, s)
    love.graphics.setColor(0, 0, 0, ta)
    love.graphics.printf(title, -WINDOW_W / 2 + 3, -FONT_BIG:getHeight() / 2 + 3, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.95, 0.2, ta)
    love.graphics.printf(title, -WINDOW_W / 2, -FONT_BIG:getHeight() / 2, WINDOW_W, 'center')
    love.graphics.pop()

    local reason = self.roundEnd and self.roundEnd.reasonText or ''
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

    -- Indicador permanente arriba al centro
    local md = self.modeHud or {}
    local label, big, urgent
    if mode.id == 'hunt' and md.left then
        label = 'MONSTRUOS: ' .. md.left
    elseif mode.id == 'race' then
        if md.cd then
            local secs = md.cd / 100
            big    = string.format('%d.%d', math.floor(secs), math.floor(secs * 10) % 10)
            urgent = secs <= 5
            label  = 'TIEMPO PARA LLEGAR'
        else
            label = '¡LLEGA A LA META!'
        end
    end
    if label then
        love.graphics.setFont(FONT_SMALL)
        local iw, ih = PixelIcons.size(mode.icon or '')
        local tw = FONT_SMALL:getWidth(label)
        local w  = tw + (iw > 0 and iw * 2 + 10 or 0) + 24
        local x  = math.floor(cx - w / 2)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle('fill', x, 12, w, 28)
        love.graphics.setColor(col[1], col[2], col[3], 0.8)
        love.graphics.rectangle('line', x, 12, w, 28)
        local tx = x + 12
        if iw > 0 then PixelIcons.draw(mode.icon, tx, 26 - ih, 2); tx = tx + iw * 2 + 10 end
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(label, tx, 26 - FONT_SMALL:getHeight() / 2)
    end
    if big then
        local pulse = urgent and (1 + 0.12 * math.abs(math.sin(love.timer.getTime() * 6))) or 1
        love.graphics.setFont(FONT_BIG)
        love.graphics.push()
        love.graphics.translate(cx, 66)
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
        love.graphics.printf(mode.tagline, WINDOW_W * 0.15, y + 50, WINDOW_W * 0.7, 'center')
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
    local totalSecs  = math.floor(self.levelTime)
    local mins       = math.floor(totalSecs/60)
    local secs       = totalSecs % 60
    local centis     = math.floor((self.levelTime - math.floor(self.levelTime))*100)
    local timeStr    = mins .. string.format("'%02d''%02d", secs, centis)
    local scoreStr   = string.format('%06d', od.score or 0)

    local function printOut(text, x, y, r, g, b, a)
        love.graphics.setColor(0, 0, 0, (a or 1)*0.75)
        love.graphics.print(text, x+2, y+2)
        love.graphics.setColor(r, g, b, a or 1)
        love.graphics.print(text, x, y)
    end

    local scoreLabelW = FONT_BIG:getWidth('SCORE')
    local timeLabelW  = FONT_BIG:getWidth('TIME')
    local maxLabelW   = math.max(scoreLabelW, timeLabelW)
    local valueStartX = labelX + maxLabelW + gap
    local maxValueW   = math.max(FONT_BIG:getWidth(scoreStr), FONT_BIG:getWidth(timeStr))
    local valueEndX   = valueStartX + maxValueW
    local sw = FONT_BIG:getWidth(scoreStr)
    local tw = FONT_BIG:getWidth(timeStr)

    printOut('SCORE', labelX,          row1Y, 1, 0.95, 0.15)
    printOut(scoreStr, valueEndX - sw, row1Y, 1, 1, 1)

    -- TIME: parpadea rojo cuando quedan menos de 60 s (igual que modo solo)
    local timeLeft = 600 - self.levelTime
    local tr, tg, tb = 1, 0.95, 0.15
    local vr, vg, vb = 1, 1,    1
    if timeLeft < 60 then
        local red = math.floor(love.timer.getTime()) % 2 == 0
        if red then
            tr, tg, tb = 1, 0.10, 0.10
            vr, vg, vb = 1, 0.20, 0.20
        end
    end
    printOut('TIME',  labelX,          row2Y, tr, tg, tb)
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

        -- Barra de HP (mostrar cuando hp < hpMax)
        local hp    = od.hp    or 3
        local hpMax = od.hpMax or 3
        if hp < hpMax then
            local totalHpW = hpMax * HP_BAR_W + (hpMax-1) * HP_BAR_GAP
            local barX     = math.floor((WINDOW_W - totalHpW) / 2)
            local barY     = WINDOW_H - HP_BAR_H - 20
            for i = 1, hpMax do
                local bx     = barX + (i-1)*(HP_BAR_W+HP_BAR_GAP)
                local filled = i <= hp
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle('fill', bx+3, barY+3, HP_BAR_W, HP_BAR_H)
                love.graphics.setColor(filled and 1 or 0.15, filled and 1 or 0.15, filled and 1 or 0.15, 0.85)
                love.graphics.rectangle('fill', bx, barY, HP_BAR_W, HP_BAR_H)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle('line', bx, barY, HP_BAR_W, HP_BAR_H)
            end
        end

        -- Barra de aire (ahogamiento) — delegada al jugador local
        if self.localPa and self.localPaInit then
            self.localPa:renderAirBar()
        end
    elseif od.finished then
        love.graphics.setFont(FONT_MED)
        love.graphics.setColor(1, 0.85, 0.2, 0.95)
        love.graphics.printf('META ' .. (od.place or 0) .. 'º', WINDOW_W-240, 20, 220, 'right')
    else
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.printf('ESPECTADOR', WINDOW_W-180, 16, 160, 'right')
    end

    -- Indicador ONLINE
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0.3, 1, 0.5, 0.65)
    local roomName = (self.currentRoom and self.currentRoom.name) or "Online"
    love.graphics.printf('ONLINE: ' .. roomName, 0, WINDOW_H-22, WINDOW_W-14, 'right')

    -- Corona: tú eres el host (admin) de la sala
    if self.currentRoom and self.currentRoom.adminId == NC.myId then
        local tw = FONT_SMALL:getWidth('ONLINE: ' .. roomName)
        local px = 3
        -- Centrada verticalmente con la línea de texto
        local textMidY = WINDOW_H - 22 + FONT_SMALL:getHeight() / 2
        PixelIcons.crown(WINDOW_W - 14 - tw - PixelIcons.CROWN_W * px - 6,
                         textMidY - PixelIcons.CROWN_H * px / 2, px)
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
    love.graphics.printf('PAUSA', 0, panelY + 16, WINDOW_W, 'center')

    love.graphics.setFont(FONT_MED)
    local startBY = panelY + 68
    for i, opt in ipairs(opts) do
        local by = startBY + (i - 1) * (btnH + btnGap)
        local col = (opt == 'DETENER PARTIDA') and {1,0.4,0.4} or nil
        if col and i == self.pauseSel then
            love.graphics.setColor(0.12, 0.12, 0.12, a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2 + 4, by + 4, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(0, 0, 0, a)
            love.graphics.printf(opt, WINDOW_W/2 - btnW/2, by + btnH/2 - FONT_MED:getHeight()/2, btnW, 'center')
        elseif col then
            love.graphics.setColor(col[1], col[2], col[3], 0.2 * a)
            love.graphics.rectangle('fill', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], 0.55 * a)
            love.graphics.rectangle('line', WINDOW_W/2 - btnW/2, by, btnW, btnH)
            love.graphics.setColor(col[1], col[2], col[3], 0.8 * a)
            love.graphics.printf(opt, WINDOW_W/2 - btnW/2, by + btnH/2 - FONT_MED:getHeight()/2, btnW, 'center')
        else
            drawPixelButton(opt, WINDOW_W/2, by, btnW, btnH, i == self.pauseSel, a)
        end
    end
end

-- ── Overlay espectador ────────────────────────────────────────────────────────

function OnlineAdventureState:_renderSpectatorOverlay()
    local finished = self.ownData.finished
    love.graphics.setFont(FONT_SMALL)
    if finished then
        love.graphics.setColor(1, 0.85, 0.2, 0.9)
        love.graphics.printf('¡LLEGASTE! Esperando al resto...', 0, WINDOW_H - 58, WINDOW_W, 'center')
    else
        love.graphics.setColor(0.7, 0.7, 1, 0.8)
        love.graphics.printf('ESPECTADOR', 0, WINDOW_H - 58, WINDOW_W, 'center')
    end

    if not self.specOverlay then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf('[PAUSA] para opciones', 0, WINDOW_H - 36, WINDOW_W, 'center')
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
        love.graphics.printf('EN LA META', 0, panelY + 16, WINDOW_W, 'center')
    else
        love.graphics.setColor(0.7, 0.7, 1, 1)
        love.graphics.printf('ELIMINADO', 0, panelY + 16, WINDOW_W, 'center')
    end

    local btnW, btnH = 260, 44
    local btnGap = 12
    local totalBH = #SPEC_OPTS * btnH + (#SPEC_OPTS-1) * btnGap
    local startBY = panelY + panelH/2 - totalBH/2 + 16
    love.graphics.setFont(FONT_MED)
    for i, opt in ipairs(SPEC_OPTS) do
        local by = startBY + (i-1) * (btnH + btnGap)
        drawPixelButton(opt, WINDOW_W/2, by, btnW, btnH, i==self.specSel, 1)
    end
end

return OnlineAdventureState
