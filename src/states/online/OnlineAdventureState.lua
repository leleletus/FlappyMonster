local IceDrips = require 'src/fx/IceDrips'
local LavaFx   = require 'src/fx/LavaFx'
local Sky      = require 'src/fx/Sky'
local Snowfall = require 'src/fx/Snowfall'
-- src/states/online/OnlineAdventureState.lua
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

local BaseState            = require 'src/core/BaseState'
local L = require 'src/core/Lang'
local Level                = require 'src/world/level/Level'
local Entities             = require 'src/world/entities/Entities'
local PlayerAdventure      = require 'src/player/PlayerAdventure'
local OnlinePlayer         = require 'src/player/OnlinePlayer'
local NC                   = require 'src/network/NetworkClient'
local Protocol             = require 'src/network/Protocol'
local Predictor            = require 'src/network/Predictor'
local SnapshotBuffer       = require 'src/network/SnapshotBuffer'
local PixelIcons           = require 'src/ui/PixelIcons'
local Particles            = require 'src/fx/Particles'
local CornerButtons        = require 'src/ui/CornerButtons'
local Modes                = require 'src/world/modes/Modes'
local BossZones            = require 'src/world/systems/BossZones'
local BossHud              = require 'src/ui/BossHud'
local AutoScroll           = require 'src/world/systems/AutoScroll'
local Floods               = require 'src/world/systems/Floods'
local PointAreas           = require 'src/world/systems/PointAreas'
local json                 = require 'libs/json'
local PingIcon             = require 'src/ui/PingIcon'
local TouchControls        = require 'src/ui/TouchControls'
local Darkness             = require 'src/fx/Darkness'
local LightHud             = require 'src/ui/LightHud'

local OnlineAdventureState = BaseState:new()
local P = {}        -- locales de archivo que comparten las partes (ver abajo "Partes")
local loadAssets      -- (de las partes: se rellenan al cargarlas)

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
    require('src/world/entities/base/Entity').fx = nil

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
function OnlineAdventureState:_buildWorld(data, difficulty)
    local level
    if data then
        local ok, lv = pcall(Level.fromData, data, difficulty)
        if ok then level = lv else print('[online] nivel del servidor invalido: ' .. tostring(lv)) end
    end
    self.level = level or Level.new('assets/levels/nivel01.json')
    Particles.setLevel(self.level)                 -- (las partículas físicas chocan con él)
    require('src/fx/NoiseMarks').clear()
    require('src/world/systems/Noise').bind(nil)                -- (online: los ruidos son cosa del servidor)
    if self.mode then self.level.hiddenTriggers = Modes.hiddenTriggers(self.mode) end
    -- Música del nivel (la misma para todos: viene en el nivel que manda el
    -- servidor). Si ya sonaba otra, se cambia.
    local before = Sound.resolveMusic('level')
    Sound.setBaseLevelMusic(self.level.music)
    Sound.setEcho(self.level.echo and 1 or 0)          -- (cuevas: eco)
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
    require('src/fx/Silhouette').level = nil
    require('src/ui/View').unlock()
    NC:off("s"); NC:off("ev"); NC:off("game_init")
    NC.pendingGameInit = nil
    require('src/core/Difficulty').bind(nil)
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

    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt
    if scrolling then self.camX = targetX end      -- la ventana manda, sin suavizado
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
    if Input.pressed('light')  then self.pendingLight  = true end
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
            elseif result == 'shatter' then
                -- Enemigo congelado que no muere: rebota y le rompe el hielo
                pa:bounce(bvy)
                self.localBounceCooldown[idx] = 0.3
                self.predictor:recordBounce(bvy)
                Sound.play('cryoFree')
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
                if er.state == 'frozen' then Sound.play('cryoFree') end       -- (le rompió el hielo)
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
    -- Indicador de conexión: ping + cuánto hace del último snapshot
    self.pingIcon = self.pingIcon or PingIcon.new()
    local age = self.lastSnapAt and (love.timer.getTime() - self.lastSnapAt) or 0
    self.pingIcon:update(dt, NC:getPing(), age, NC.connected ~= false)
    -- Controles táctiles (móvil): cruceta + salto en píxeles de pantalla
    TouchControls.update(not self.showPause and not self.showGameOver and not (self.ownData and self.ownData.isSpectator),
                         self.level and self.level.dark)
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
                                              self.pendingJump, self.pendingCrouch, self.pendingLight)
            self.pendingJump, self.pendingCrouch, self.pendingLight = false, false, false
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
        y = BossHud.drawZone(z, y, math.min(1, self.bossFightT / 0.8))
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
    if not self.showGameOver then BossHud.drawRun(self.level, self.enemyRenderers) end
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
end

-- ── Partes (el resto de OnlineAdventureState.lua, por sistemas) ────────────────────
P.TICK_DT = TICK_DT; P.TELEPORT_DIST = TELEPORT_DIST; P.EVENT_MAX_WAIT = EVENT_MAX_WAIT; P.POPUP_LIFE = POPUP_LIFE; P.POPUP_RISE = POPUP_RISE
P.POPUP_BOUNCE_T = POPUP_BOUNCE_T; P.SPEC_WAIT = SPEC_WAIT; P.SPEC_OPTS = SPEC_OPTS; P.lerp = lerp; P.drawPixelButton = drawPixelButton
P.INTRO_DUR = INTRO_DUR; P.BANNER_DUR = BANNER_DUR
require('src/states/online/OnlineAdventureNet')(OnlineAdventureState, P)
require('src/states/online/OnlineAdventureRender')(OnlineAdventureState, P)
require('src/states/online/OnlineAdventureHud')(OnlineAdventureState, P)
loadAssets = P.loadAssets

return OnlineAdventureState
