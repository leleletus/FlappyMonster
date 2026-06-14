-- src/states/OnlineAdventureState.lua
-- Modo aventura multijugador online — arquitectura autoritativa.
-- El cliente solo envía inputs y renderiza el estado que manda el servidor.
-- No corre física propia ni simula enemigos localmente.

local BaseState            = require 'src/BaseState'
local Level                = require 'src/world/Level'
local Gummy                = require 'src/entities/Gummy'
local Crabby               = require 'src/entities/Crabby'
local PlayerAdventure      = require 'src/entities/PlayerAdventure'
local OnlinePlayer         = require 'src/entities/OnlinePlayer'
local NC                   = require 'src/network/NetworkClient'

local OnlineAdventureState = BaseState:new()

-- ── Constantes ────────────────────────────────────────────────────────────────
local INPUT_RATE  = 1 / 30  -- 30 Hz envío de inputs
local POPUP_LIFE  = 1.4
local POPUP_RISE  = 28
local POPUP_BOUNCE_T = 0.22

-- Deben coincidir con los valores en PlayerAdventure.lua / server
local DROWN_TOTAL     = 20
local DROWN_AUDIO_DUR = 12

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

    -- Cargar nivel solo para renderizado
    self.levelPath = 'assets/levels/nivel01.json'
    self.level     = Level.new(self.levelPath)

    -- Burbujas de oxígeno controladas por el servidor (desactiva spawn local)
    self.level.disableOxySpawn = true

    -- Jugador local para movimiento responsivo (sin latencia de red)
    local sx, sy   = self.level:getSpawnPx()
    self.localPa   = PlayerAdventure:new(sx, sy)
    self.localPa.lives = 3
    self.localPaInit   = false

    -- Game over
    self.showGameOver       = false
    self.gameOverTimer      = 0
    self.gameOverMusicPitch = nil

    -- Rebote local (predicción cliente para sentir el bounce sin latencia)
    self.localBounceCooldown = {}   -- [enemyIdx] = timer restante
    self.recentLocalBounce   = 0   -- si > 0, ignora bounceVy del servidor (evita doble rebote)

    -- Crear renderers de enemigos desde los datos del nivel
    -- El servidor controla su estado; el cliente solo los dibuja
    self.enemyRenderers = {}
    for i, edata in ipairs(self.level.enemies) do
        local e
        if edata.type == 'gummy' then
            e = Gummy:new(edata)
        elseif edata.type == 'crabby' then
            e = Crabby:new(edata)
        end
        if e then self.enemyRenderers[i] = e end
    end

    -- Jugadores remotos (incluye al jugador propio para render del cuerpo)
    self.remotePlayers = {}

    -- Datos propios del jugador local (actualizados desde game_state)
    self.ownData = {
        x=0, y=0, lives=3, hp=3, hpMax=3, score=0,
        drownPhase='none', airFraction=1, drownAudT=0,
        dying=false, isSpectator=false,
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

    -- Input state enviado al servidor
    self.inputState = { left=false, right=false, jump=false, crouch=false }
    self.inputJustPressed = { jump=false, crouch=false }
    self.inputTimer = 0

    -- Air bar animación local (basada en datos del servidor)
    self.airBarAlpha = 0

    self:_setupHandlers()
    Sound.playMusic('level')
end

function OnlineAdventureState:_setupHandlers()
    NC:on("game_state", function(data)
        self:_onGameState(data)
    end)
    NC:on("room_update", function(data)
        self.currentRoom = data
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

-- ── Recepción de estado del servidor ─────────────────────────────────────────

function OnlineAdventureState:_onGameState(data)
    -- Procesar jugadores
    local activeIds = {}
    for _, pdata in ipairs(data.players or {}) do
        activeIds[pdata.id] = true

        -- Actualizar / crear renderer
        local rp = self.remotePlayers[pdata.id]
        if not rp then
            rp = OnlinePlayer:new(pdata.id, pdata.name, pdata.color)
            self.remotePlayers[pdata.id] = rp
        end
        rp:applyData(pdata)

        -- Datos propios
        if pdata.id == NC.myId then
            local prev = self.ownData
            self.ownData = {
                x           = pdata.x,
                y           = pdata.y,
                facing      = pdata.facing,
                frame       = pdata.frame,
                lives       = pdata.lives,
                hp          = pdata.hp,
                hpMax       = pdata.hpMax,
                score       = pdata.score,
                drownPhase  = pdata.drownPhase,
                airFraction = pdata.airFraction,
                drownAudT   = pdata.drownAudT,
                dying       = pdata.dying,
                deathPhase  = pdata.deathPhase,
                isSpectator = pdata.isSpectator,
            }
            -- Pasar a espectador si lo indica el servidor (no mostrar overlay si ya hay game over)
            if pdata.isSpectator and not prev.isSpectator and not self.showGameOver then
                self.specOverlay = true
                self.specSel     = SPEC_WAIT
            end
            -- Sincronizar jugador local con estado autoritativo del servidor
            if self.localPa then
                if not self.localPaInit then
                    self.localPa.x = pdata.x; self.localPa.y = pdata.y
                    self.localPa.vx = 0;       self.localPa.vy = 0
                    self.localPaInit = true
                else
                    if pdata.dying and not prev.dying and not self.localPa.dying then
                        self.localPa:die()
                    end
                    if not pdata.dying and prev.dying then
                        self.localPa.spawnX = pdata.x; self.localPa.spawnY = pdata.y
                        self.localPa:respawn()
                    end
                    -- Muerte falsa local: cliente murió pero el servidor nunca lo confirmó
                    -- (p.ej.: drownPhase llegó a muerte localmente pero el servidor recogió aire)
                    if not pdata.dying and self.localPa.dying and not prev.dying then
                        self.localPa.spawnX = pdata.x; self.localPa.spawnY = pdata.y
                        self.localPa:respawn()
                    end
                    -- Sincronizar drownPhase: si el servidor reseteó el oxígeno (burbuja) y el
                    -- cliente aún no lo sabe, corregir antes de que progrese a muerte falsa.
                    if pdata.drownPhase == 'none' and self.localPa.drownPhase ~= 'none' then
                        self.localPa.drownTimer  = 0; self.localPa.drownChime = 0
                        self.localPa.drownAudT   = 0; self.localPa.drownDead  = false
                        self.localPa.airBarAlpha  = 0; self.localPa.airBarBobOn = false
                        self.localPa.drownPhase   = 'none'
                    end
                    if not pdata.dying and not self.localPa.dying then
                        local ddx = math.abs(self.localPa.x - pdata.x)
                        local ddy = math.abs(self.localPa.y - pdata.y)
                        if ddx > 96 or ddy > 96 then
                            self.localPa.x = pdata.x; self.localPa.y = pdata.y
                            self.localPa.vx = 0; self.localPa.vy = 0
                        end
                    end
                end
            end
        end
    end

    -- Limpiar jugadores que ya no están
    for id in pairs(self.remotePlayers) do
        if not activeIds[id] then self.remotePlayers[id] = nil end
    end

    -- Actualizar renderers de enemigos
    self:_updateEnemyRenderers(data.enemies)

    -- Sincronizar burbujas de oxígeno desde el servidor
    self.level:syncOxyBubbles(data.ventBubbles)

    -- Sincronizar reloj autoritativo del servidor
    if data.levelTime then
        self.levelTime = data.levelTime
    end

    -- Procesar eventos (sonidos, popups de puntuación)
    self:_processEvents(data.events)
end

local ENEMY_LERP = 18  -- velocidad de suavizado de posición (px/s)

function OnlineAdventureState:_updateEnemyRenderers(enemyList)
    for _, edata in ipairs(enemyList or {}) do
        local er = self.enemyRenderers[edata.idx]
        if er then
            -- Suavizar posición hacia el valor del servidor para reducir desync visual
            if er._renderX == nil then er._renderX = edata.x; er._renderY = edata.y end
            local dx = edata.x - er._renderX
            local dy = edata.y - er._renderY
            -- Snap si la diferencia es muy grande (teletransporte / respawn)
            if math.abs(dx) > 64 or math.abs(dy) > 64 then
                er._renderX = edata.x; er._renderY = edata.y
            else
                -- El lerp se aplica en update; aquí solo guardamos el target
                er._targetX = edata.x; er._targetY = edata.y
            end
            er.x        = er._renderX
            er.y        = er._renderY
            er.facing   = edata.facing
            er.state    = edata.state
            er.frame    = edata.frame
            er.alive    = edata.alive
            er.deadTimer = edata.deadTimer or 0
            er.breatheT = edata.breatheT  or 0
            if edata.eType == 'crabby' then
                er.spikeProgress = edata.spikeProgress or 0
                er.flipped       = edata.flipped or false
                if edata.currentImgName then
                    er:setImgFromName(edata.currentImgName)
                end
            end
        end
    end
end

function OnlineAdventureState:_processEvents(events)
    for _, ev in ipairs(events or {}) do
        if ev.type == 'sound' then
            -- Sonidos globales (enemigos) o de otros jugadores.
            -- Los sonidos propios los genera directamente localPa para evitar dobles.
            if not ev.playerId or ev.playerId ~= NC.myId then
                Sound.play(ev.sound)
            end
        elseif ev.type == 'score' and ev.playerId == NC.myId then
            self:_spawnPopup('+' .. ev.delta .. '!', ev.x, ev.y)
            -- Solo aplicar rebote del servidor si la detección local no lo hizo ya
            if ev.bounceVy and self.localPa and self.localPaInit and not self.localPa.dying
               and (not self.recentLocalBounce or self.recentLocalBounce <= 0) then
                self.localPa.vy        = ev.bounceVy
                self.localPa.jumpsLeft = 2
                self.localPa.onGround  = false
            end
        elseif ev.type == 'air_collected' and ev.playerId == NC.myId then
            -- El servidor confirmó que recogimos una burbuja de oxígeno.
            -- Resetear el estado de ahogamiento local inmediatamente, incluso si
            -- la detección local divergió (hitbox pequeño + posición desincronizada).
            if self.localPa and self.localPaInit then
                local wasPhase = self.localPa.drownPhase
                self.localPa.drownTimer  = 0; self.localPa.drownChime = 0
                self.localPa.drownAudT   = 0; self.localPa.drownDead  = false
                self.localPa.airBarAlpha  = 0; self.localPa.airBarBobOn = false
                self.localPa.drownPhase   = 'none'
                if self.localPa.dying then
                    -- Muerte falsa por ahogamiento: el servidor dice que seguimos vivos
                    local od = self.ownData
                    self.localPa.spawnX = od and od.x or self.localPa.x
                    self.localPa.spawnY = od and od.y or self.localPa.y
                    self.localPa:respawn()
                end
                -- El evento 'sound'/'airGasp' del servidor se filtra para el jugador propio,
                -- así que reproducirlo aquí.
                if wasPhase == 'drowning' then
                    Sound.play('airGasp')
                    Sound.stopTracked('drowning')
                    Sound.playMusic('level')
                elseif wasPhase == 'warning' then
                    Sound.play('airGasp')
                end
            end
        elseif ev.type == 'game_over' then
            self.showGameOver        = true
            self.gameOverTimer       = 0
            self.specOverlay         = false
            self.gameOverMusicPitch  = 1.0
            Sound.stopTracked('drowning')
        end
    end
end

-- ── Cámara ────────────────────────────────────────────────────────────────────

function OnlineAdventureState:_updateCamera(dt)
    local targetX, targetY

    if self.ownData.isSpectator then
        -- Seguir al primer jugador vivo
        local tx, ty = nil, nil
        for id, rp in pairs(self.remotePlayers) do
            if id ~= NC.myId and not rp.isSpectator then
                tx = rp.renderX; ty = rp.renderY; break
            end
        end
        if not tx then return end
        targetX = tx - WINDOW_W / 2
        targetY = ty - WINDOW_H / 2
    else
        local px = (self.localPa and self.localPaInit) and self.localPa.x or self.ownData.x
        local py = (self.localPa and self.localPaInit) and self.localPa.y or self.ownData.y
        targetX = px - WINDOW_W / 2
        targetY = py - WINDOW_H / 2
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

-- ── Envío de input al servidor ────────────────────────────────────────────────

function OnlineAdventureState:_collectInput()
    -- Estado continuo
    self.inputState.left   = Input.down('move_left')
    self.inputState.right  = Input.down('move_right')
    self.inputState.jump   = Input.down('jump')
    self.inputState.crouch = Input.down('crouch')

    -- Flags de "recién presionado" (se acumulan hasta el envío)
    if Input.pressed('jump')   then self.inputJustPressed.jump   = true end
    if Input.pressed('crouch') then self.inputJustPressed.crouch = true end
end

function OnlineAdventureState:_sendInput(dt)
    self.inputTimer = self.inputTimer + dt
    if self.inputTimer >= INPUT_RATE then
        self.inputTimer = 0
        if not NC:isConnected() then return end
        NC:send("player_input", {
            left           = self.inputState.left,
            right          = self.inputState.right,
            jump           = self.inputState.jump,
            crouch         = self.inputState.crouch,
            jump_pressed   = self.inputJustPressed.jump,
            crouch_pressed = self.inputJustPressed.crouch,
        })
        self.inputJustPressed.jump   = false
        self.inputJustPressed.crouch = false
    end
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
    if self.showPause then
        self.inputState       = { left=false, right=false, jump=false, crouch=false }
        self.inputJustPressed = { jump=false, crouch=false }
    end
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
-- Replica la lógica del servidor para dar feedback inmediato (sin latencia de red).
function OnlineAdventureState:_checkLocalBounce()
    if not self.localPa or not self.localPaInit or self.localPa.dying then return end
    if not self.localBounceCooldown then self.localBounceCooldown = {} end
    local pob = self.localPa:getOuterBounds()

    for idx, er in pairs(self.enemyRenderers) do
        local cd = self.localBounceCooldown[idx] or 0
        if cd <= 0 and er.alive and er.state ~= 'dead' then
            -- Saltarse si el cuerpo del Crabby está desactivado (escondido)
            if not (er.isBodyDisabled and er:isBodyDisabled()) then
                local gib = er:getInnerBounds()
                local gob = er:getOuterBounds()
                local overlap = pob.x < gib.x+gib.w and pob.x+pob.w > gib.x and
                                pob.y < gib.y+gib.h and pob.y+pob.h > gib.y
                if overlap then
                    if er.flipped then
                        -- Crabby volteado: pisotón desde abajo (jugador sube)
                        local enemyBotZone = gob.y + gob.h * 0.65
                        if self.localPa.vy < 0 and pob.y > enemyBotZone - 10 then
                            self.localPa.vy       =  math.abs(ADV_JUMP_VEL) * 0.40
                            self.localPa.jumpsLeft = 2
                            self.localPa.onGround  = false
                            self.localBounceCooldown[idx] = 0.3
                            self.recentLocalBounce        = 0.3
                        end
                    else
                        -- Gummy / Crabby normal: pisotón desde arriba (jugador cae)
                        local gummyTopZone = gob.y + gob.h * 0.35
                        if self.localPa.vy > 0 and pob.y+pob.h < gummyTopZone + 10 then
                            self.localPa.vy       = -math.abs(ADV_JUMP_VEL) * 0.40
                            self.localPa.jumpsLeft = 2
                            self.localPa.onGround  = false
                            self.localBounceCooldown[idx] = 0.3
                            self.recentLocalBounce        = 0.3
                        end
                    end
                end
            end
        end
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

local GAME_OVER_DUR = 3.5  -- segundos mostrando la pantalla de game over

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
        if self.gameOverTimer >= GAME_OVER_DUR and self.currentRoom then
            Sound.playMusic('menus')
            gStateMachine:change('online_room', { room=self.currentRoom })
        end
        return
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

    -- ── Tiempo: interpolado localmente para suavizar el display, corregido por el server ────
    -- El servidor envía levelTime en cada game_state (_onGameState lo sobreescribe).
    -- El incremento local solo sirve para que el contador no se congele entre paquetes.
    self.levelTime = math.min(self.levelTime + dt, 600)

    -- ── Animaciones visuales del nivel (foliaje, burbujas) ────────────────────
    self.level:update(dt)
    self.level:updateFoliage(dt)

    -- ── Actualizar renderers de jugadores remotos (no el propio) ─────────────
    for id, rp in pairs(self.remotePlayers) do
        if id ~= NC.myId then rp:update(dt) end
    end

    -- ── Suavizar posición de enemigos hacia el target del servidor ────────────
    local lerpF = math.min(1, ENEMY_LERP * dt)
    for _, er in pairs(self.enemyRenderers) do
        if er._renderX ~= nil and er._targetX ~= nil then
            er._renderX = er._renderX + (er._targetX - er._renderX) * lerpF
            er._renderY = er._renderY + (er._targetY - er._renderY) * lerpF
            er.x = er._renderX
            er.y = er._renderY
        end
    end
    -- Decrementar cooldowns de rebote local
    if self.localBounceCooldown then
        for idx, cd in pairs(self.localBounceCooldown) do
            self.localBounceCooldown[idx] = cd - dt
        end
    end
    if self.recentLocalBounce and self.recentLocalBounce > 0 then
        self.recentLocalBounce = self.recentLocalBounce - dt
    end

    -- ── Recoger input solo cuando no pausado ─────────────────────────────────
    if not self.showPause and not self.ownData.isSpectator then
        self:_collectInput()
    end

    -- ── Actualizar jugador local (siempre, pausado o no — física continúa) ───
    if self.localPa and self.localPaInit and not self.ownData.isSpectator then
        self.localPa:update(dt, self.level)
        -- La recolección de burbujas de oxígeno la confirma el servidor vía
        -- el evento 'air_collected' (ver _processEvents). No se detecta localmente
        -- para evitar falsos positivos/negativos por desincronización de posición.
        if not self.localPa.dying then
            self:_checkLocalBounce()
        end
    end

    -- ── Cámara ────────────────────────────────────────────────────────────────
    self:_updateCamera(dt)
    self:_updatePopups(dt)

    self:_sendInput(dt)
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

    -- Enemigos (estado controlado por el servidor)
    for i, er in pairs(self.enemyRenderers) do
        if er.alive then
            er:render(self.camX, self.camY)
        end
    end

    -- Jugadores remotos via OnlinePlayer (excluye al propio)
    for id, rp in pairs(self.remotePlayers) do
        if id ~= NC.myId then
            rp:render(self.camX, self.camY)
        end
    end

    -- Jugador propio via simulación local
    if self.localPa and self.localPaInit and not self.ownData.isSpectator then
        self.localPa:render(self.camX, self.camY)
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
    if self.ownData.isSpectator and not self.showGameOver then self:_renderSpectatorOverlay() end

    -- ── Game Over overlay ─────────────────────────────────────────────────────
    if self.showGameOver then self:_renderGameOver() end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

function OnlineAdventureState:_renderGameOver()
    local t = math.min(1, self.gameOverTimer / 0.4)  -- fade in
    local a = t

    love.graphics.setColor(0, 0, 0, 0.75 * a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    love.graphics.setFont(FONT_BIG)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.printf('GAME OVER', 3, WINDOW_H/2 - 44, WINDOW_W, 'center')
    love.graphics.setColor(1, 0.2, 0.2, a)
    love.graphics.printf('GAME OVER', 0, WINDOW_H/2 - 46, WINDOW_W, 'center')

    local remaining = math.max(0, GAME_OVER_DUR - self.gameOverTimer)
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(1, 1, 1, a * 0.75)
    love.graphics.printf(
        'Volviendo a la sala en ' .. math.ceil(remaining) .. '...',
        0, WINDOW_H/2 + 10, WINDOW_W, 'center')
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
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0.7, 0.7, 1, 0.8)
    love.graphics.printf('ESPECTADOR', 0, WINDOW_H - 58, WINDOW_W, 'center')

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
    love.graphics.setColor(0.7, 0.7, 1, 1)
    love.graphics.printf('ELIMINADO', 0, panelY + 16, WINDOW_W, 'center')

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
