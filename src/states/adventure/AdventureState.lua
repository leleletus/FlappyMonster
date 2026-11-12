local TouchControls = require 'src/ui/TouchControls'
local Darkness      = require 'src/fx/Darkness'
local LightHud      = require 'src/ui/LightHud'
local Difficulty    = require 'src/core/Difficulty'
local Noise         = require 'src/world/systems/Noise'
local Scenes        = require 'src/world/level/Scenes'
local CornerButtons = require 'src/ui/CornerButtons'
local L = require 'src/core/Lang'
local MenuKit = require 'src/ui/menu/MenuKit'
-- src/states/adventure/AdventureState.lua
local BaseState       = require 'src/core/BaseState'
local Level           = require 'src/world/level/Level'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local PlayRecorder    = require 'src/core/PlayRecorder'
local Entities        = require 'src/world/entities/Entities'
local Carry           = require 'src/world/systems/Carry'
local Entity          = require 'src/world/entities/base/Entity'
local Particles       = require 'src/fx/Particles'
local BossZones       = require 'src/world/systems/BossZones'
local BossHud         = require 'src/ui/BossHud'
local RhythmDuel      = require 'src/ui/RhythmDuel'
local AutoScroll      = require 'src/world/systems/AutoScroll'
local Floods          = require 'src/world/systems/Floods'
local PointAreas      = require 'src/world/systems/PointAreas'
local StartCountdown  = require 'src/world/systems/StartCountdown'
local Sim             = require 'src/world/systems/Sim'
local SceneLayers     = require 'src/world/level/SceneLayers'
local CameraLook      = require 'src/ui/CameraLook'
local Rumble          = require 'src/core/Rumble'
local HitStop         = require 'src/ui/HitStop'

local AdventureState = BaseState:new()

local GAMEOVER_OPTIONS = { 'common.retry', 'common.menu' }   -- claves de idioma
local RESPAWN_DELAY    = 0

-- ── Assets del HUD ────────────────────────────────────────────────────────────
local imgIcon = nil
local function loadHudAssets()
    if imgIcon then return end
    imgIcon = love.graphics.newImage('assets/images/player/icon.png')
end

local ICON_SCALE = 4

-- (fondo: cielo y capas con paralaje del bioma del nivel, src/fx/Sky.lua;
-- Background.png es solo del modo Flappy)

-- ── Enter ─────────────────────────────────────────────────────────────────────
-- Al salir del nivel: cerrar la grabación (si la hay)
function AdventureState:exit()
    if Entity.onKill and Entity.onKill == self.onKill then Entity.onKill = nil end
    require('src/fx/Silhouette').level = nil
    require('src/ui/View').unlock()
    -- Música y sonidos de partida a cero (también la pista de jefe): al volver
    -- a entrar (reintentar tras perder todas las vidas, desde el editor...)
    -- todo empieza como la primera vez, la música desde el principio
    Sound.leaveMatch()
    Difficulty.bind(nil)
    -- NADA de lo conseguido en el nivel se guarda si no se TERMINA (vidas extra, puntos, fragmentos...): si no, se
    -- entraba, se cogía la vida, se salía y otra vez, sin fin. Saliendo a medias cuentan solo las vidas PERDIDAS:
    -- las de entrada menos las muertes (nunca menos de 1: quedarse sin ninguna es el Game Over, que va aparte).
    -- TERMINADO no se llama: las vidas ya las guardó `onFinish` con los premios (llamarlo aquí las pisaba).
    if not self.finished then self:_saveLostLives() end
    if self.rec then self.rec:finish(self); self.rec = nil end
end

-- Guarda las vidas PERDIDAS (las de entrada menos las muertes; las ganadas no, hasta terminar): al salir y en cada
-- muerte (si el juego se cierra de golpe, las perdidas ya están guardadas)
function AdventureState:_saveLostLives()
    if not (self.onLeave and not self.bonus and self.player and self.player.lives > 0) then return end
    local lives = self.player.lives
    if self.startLives then
        lives = math.max(1, math.min(lives, self.startLives - (self.stats and self.stats.deaths or 0)))
    end
    self.onLeave(lives)
end

function AdventureState:enter(args)
    HitStop.reset()                                -- (sin un hit-stop a medias de otra partida)
    args = args or {}
    self.enterArgs = args                         -- (REINTENTAR desde la pausa: el mismo nivel con lo mismo — retryNow —)
    -- DEMO (el fondo de los menús, src/ui/menu/MenuScene.lua): el nivel de verdad, jugado por un bot
    -- (args.demo.step(dt, level) mueve al jugador en vez del mando; demo.camera(st) → camX, camY: cámara propia;
    -- demo.noSky: sin cielo, transparente; demo.noBossCtl: sin el control de las zonas de jefe — entradas, música —), sin HUD, sin pausa, sin música, vidas sin fin y
    -- con la vista adaptable del menú (no se fija a 16:9). camX / camY = dónde va el jugador en la pantalla.
    self.demo = args.demo
    if not self.demo then require('src/ui/View').lockGameplay() end      -- (todos ven la misma zona del nivel)
    loadHudAssets()
    self.levelPath = args.level or 'assets/levels/nivel01.json'
    self.returnTo  = args.returnTo or 'main_menu'   -- a dónde se sale (Juego libre → free_play)
    -- Al llegar a la META el nivel termina: `onFinish(result)` decide qué pasa (el modo historia
    -- apunta el nivel y vuelve a su mapa); sin él se vuelve a `returnTo`.
    self.onFinish  = args.onFinish
    -- Modo historia: las vidas vienen de la aventura (`lives`) y vuelven a ella al salir del nivel
    -- (`onLeave(vidas)`); quedarse sin ninguna es el GAME OVER de la aventura (`onGameOver()`: sin
    -- "reintentar": se vuelve al principio del mundo). `gameOverNote` = la frase que lo explica.
    self.startLives = args.lives
    self.onLeave, self.onGameOver, self.gameOverNote = args.onLeave, args.onGameOver, args.gameOverNote
    -- POWER-UPS (docs/design/powerups.md): `args.powerups` = el inventario de la partida { items(), spend(id) } (la
    -- campaña Flappy: FlappyMapState); con él, la RUEDA RÁPIDA (WheelState) y los atajos 1–6
    self.powerups = args.powerups
    self.won, self.wonT = false, 0
    self.finished = false

    self.level  = Level.new(self.levelPath, args.difficulty)
    -- (modo historia, nivel de jefe: sin META — acaba al vencer al jefe y recoger su fragmento, src/story/Shards —;
    --  sus casillas de meta se quitan)
    -- (un nivel de EVENTO — el Mega Mashup — sí acaba en su salida: tiene su propio guion)
    if args.shards and #(self.level.bossZones or {}) > 0 and not self.level.event then
        for r = 1, self.level.tileH do
            for c = 1, self.level.tileW do
                if self.level:getDef(c, r).trigger == 'finish' then self.level.tiles[r][c] = 0 end
            end
        end
    end
    -- Dificultad (src/core/Difficulty.lua): la del modo historia; sin ella, el juego de siempre
    self.level.difficulty = Difficulty.valid(args.difficulty) and args.difficulty or nil
    Difficulty.bind(self.level)
    self.level.eventCheckpoint = args.eventCheckpoint              -- (Mega Mashup: el punto de control del evento)
    -- Hielo fino que se agrieta / rompe (lo decide el nivel): partículas y sonido
    self.level.tileFx = function(kind, c, r)
        local x, y = (c - 0.5) * TILE_PX, (r - 1) * TILE_PX + TILE_PX / 4
        Particles.emit(kind == 'icebreak' and 'ice_break' or 'ice_crack', x, y)
        Sound.playAt(kind == 'icebreak' and 'iceBreak' or 'iceCrack', x, y, 0.9 + math.random() * 0.2)
    end
    local sx, sy = self.level:getSpawnPx()
    self.player = PlayerAdventure:new(sx, sy)
    if self.demo then self.player.moveK = 1 end      -- (el bot del fondo de los menús: a su velocidad de siempre)
    self.player:settle(self.level)             -- (de pie sobre el suelo desde el primer fotograma: la cuenta atrás)
    self.player:applyDifficulty()
    if self.startLives then self.player.lives = self.startLives end
    -- BOSS RUSH (src/story/BossRush.lua): se empieza ya dentro de la arena del primer jefe y el nivel acaba al vencerlos
    self.endOnBoss, self.rush = args.endOnBoss, args.rush
    -- CONTRARRELOJ (Juego Libre, carreras): se graba la partida y corre el fantasma del mejor tiempo (src/story/Ghost.lua)
    if args.ghost then
        local Ghost = require 'src/story/Ghost'
        local best = Ghost.load(self.levelPath)
        self.ghost = { rec = Ghost.recorder(), draw = best and Ghost.drawer(best) }
    end
    local z = args.atBoss and (self.level.bossZones or {})[1]
    if z then
        local gx, gy = self.level:findGround(z.col + 2, z.col, z.col + z.w - 1, z.row, z.row + z.h - 1)
        if gx then
            self.player.x, self.player.y = gx, gy
            self.player:settle(self.level)
            self.player.spawnX, self.player.spawnY = self.player.x, self.player.y
        end
    end
    self.level.players = { self.player }       -- para trampas/entidades que "ven" al jugador
    -- Grabación de la partida para analizarla (FM_RECORD=1; ver src/core/PlayRecorder.lua)
    if PlayRecorder.enabled() and not self.demo then self.rec = PlayRecorder.new(self.levelPath, self.level.name) end

    -- Efectos del jugador (ground pound, bloques rotos...)
    Particles.clear()
    Particles.setLevel(self.level)                 -- (las partículas físicas chocan con él)
    require('src/fx/NoiseMarks').clear()
    require('src/world/systems/Noise').bind(self.level)         -- (ruidos que oyen los enemigos)
    PlayerAdventure.fx = function(kind, x, y, pa)
        Particles.emit(kind, x, y)
        if pa == self.player and not self.demo then
            Rumble.onPlayerFx(kind)                                     -- (vibración: src/core/Rumble.lua)
        end
        if kind == 'block_break' then Sound.play('blockBreak') end
        if kind == 'switch_hit' then               -- (el bloque ya cambió: suena su estado nuevo)
            local on = self.level:getDefAt(x + 1, y + 1).name == 'switch_on'
            Sound.play(on and 'switchOn' or 'switchOff')
        end
    end
    -- Impactos de pinchos que caen, bloques que rompe un jefe...
    Entity.fx = function(kind, x, y, opts)
        Particles.emit(kind, x, y, opts)
        if kind == 'block_break' then Sound.play('blockBreak') end
    end
    self._pfx, self._efx = PlayerAdventure.fx, Entity.fx

    -- Instanciar entidades (enemigos, NPCs) desde el catálogo
    -- (`args.taken` = { [nº de la colocación] = true }: vidas extra ya cogidas en este nivel en partidas TERMINADAS:
    -- salen transparentes y solo dan puntos. Las que se cogen ahora se apuntan en `self.takenNow` y la historia las
    -- guarda al terminar el nivel — Run.complete —, como todo lo demás)
    -- (`args.rescued` = { [colocación] = true }: FLAPPIES ENJAULADOS ya liberados en partidas terminadas — campaña Flappy,
    -- types/items/cage.lua —: salen vacíos; los liberados ahora van en `result.rescued` al terminar)
    self.enemies, self.takenNow, self.takenArg, self.rescuedArg = {}, {}, args.taken, args.rescued
    for i, placement in ipairs(self.level.entities) do
        local e = Entities.create(placement)
        if e then
            e.placeIdx = i
            if args.taken and args.taken[i] then e.taken = true end
            if args.rescued and args.rescued[i] then e.freed = true end
            table.insert(self.enemies, e)
        end
    end

    -- BONUS del modo historia: Rey de la Colina contra el bot (src/story/BonusMatch.lua)
    self.bonus = args.bonus and require('src/story/BonusMatch').new(self, args.bonus) or nil

    -- FRAGMENTOS DEL ESPEJO (modo historia, src/story/Shards.lua): los jefes de este nivel sueltan los suyos
    -- al caer. `shards.final` = es el último (el del jefe Espejo): al recogerlo el nivel acaba SIN tocar la meta.
    -- (también sin fragmentos por ganar si el nivel termina solo al vencer al jefe: `auto`, repetir un jefe ya vencido)
    self.shards = (args.shards and (#(args.shards.ids or {}) > 0 or #(args.shards.collect or {}) > 0 or args.shards.auto)) and require('src/story/Shards').drops(self, args.shards) or nil
    if self.shards and self.level.event then self.shards.auto = false end
    self.endingT, self.shardArgs = nil, args.shards
    -- Modo historia: el final de una carrera como escena dentro del nivel, que enlaza con el siguiente (src/story/RunOut.lua)
    self.outroArgs = args.outro
    self.runOut = args.outro and require('src/story/RunOut').new(self, args.outro) or nil

    -- Zonas de jefe: la pelea empieza al entrar (un solo jugador)
    self.bossCtl    = BossZones.newController(self.level, self.enemies)
    self.bossBanner = nil       -- { text, t, col }
    self.bossFightT = 0

    self.camX = 0
    self.camY = 0
    self.camFrozen = false
    self.camSnap = true             -- (el primer encuadre, sin barrido desde la esquina: se ve quieto en la cuenta atrás)
    -- CUENTA ATRÁS del principio (src/world/systems/StartCountdown.lua): todo congelado mientras dura (la demo, no)
    self.startCd   = (not self.demo) and StartCountdown.TIME or nil
    -- (la TARJETA del nivel: nombre, isla, tiempo objetivo — src/ui/LevelCard.lua —; no en la demo ni en el editor)
    self.card = (not self.demo and not args.fromEditor) and require('src/ui/LevelCard').new(self.level,
                    self.levelPath:match('([^/]+)%.json$'), { par = not self.bonus }) or nil
    self.cardT = 0
    self.startPrev = nil            -- (lo que faltaba el frame anterior: para el sonido de cada número)
    self.startGoT  = nil            -- (s desde el ¡YA!: el cartel)

    self.sceneCanvas = require('src/fx/SceneCanvas').get()      -- (compartido: src/fx/SceneCanvas.lua)

    self.dead         = false
    self.deadTimer    = 0
    self.timeScale    = 1.0
    self.selectedOpt  = 1
    self.respawning   = false
    self.respawnTimer = 0

    if self.demo then
        self.player.lives = 99
    else
        Sound.setLevelMusic(nil)
        Sound.setBaseLevelMusic(self.level.music)          -- la música elegida en el editor
        Sound.setEcho(self.level.echo and 1 or 0)          -- (cuevas: eco)
        Sound.playMusic('level')
    end

    self.score      = 0
    -- Estadísticas del nivel (para la nota del modo historia: src/story/Score.lua)
    local stars = 0
    for _, e in ipairs(self.level.entities) do if e.type == 'star' then stars = stars + 1 end end
    self.stats = { kills = 0, killable = require('src/world/modes/Modes').entityInfo(self.level.entities).killable or 0,
                   stars = 0, starsTotal = stars, deaths = 0, hits = 0, items = 0, itemsTotal = 0, zoneT = 0 }
    -- (los vencidos SIN pisotón —bomba, bloque roto, pinchos, lava— también cuentan: antes usar bombas bajaba la nota)
    if not self.demo then
        self.onKill = function(e)
            if e.props and e.props.stompable and not (e.def and e.def.boss) then self.stats.kills = self.stats.kills + 1 end
        end
        Entity.onKill = self.onKill
    end
    for _, e in ipairs(self.level.entities) do
        local def = require('src/world/entities/base/EntityTypes').get(e.type)
        if def and def.pickup then self.stats.itemsTotal = self.stats.itemsTotal + 1 end
    end
    self.prevHp = self.player.hp
    self.levelTime  = 0   -- segundos transcurridos
    self.popups     = {}  -- lista de textos flotantes de puntos
    -- (args.onReady(st): el nivel ya montado — el FILM TEST lo usa para llevar al jugador a la escena que quiere ver)
    if args.onReady then args.onReady(self) end
end

-- Vuelve a apuntar a ESTE nivel lo que es global (dificultad, partículas, ruidos, efectos): lo usa la demo del
-- fondo de los menús, que sigue viva mientras otros niveles entran y salen
function AdventureState:rebindGlobals()
    Difficulty.bind(self.level)
    Particles.setLevel(self.level)
    require('src/world/systems/Noise').bind(self.level)
    PlayerAdventure.fx, Entity.fx = self._pfx, self._efx
end

function AdventureState:pause()  end
-- Al volver de la pausa la música sigue donde estaba (no se reinicia)
function AdventureState:resume()
    if not Sound.resumeAll() then Sound.playMusic('level') end
end

-- ¿Se pueden usar power-ups ahora? (vivo, en marcha: ni muriendo, ni ganado, ni en la cuenta atrás, ni en una escena)
function AdventureState:canUsePowerups()
    local pa = self.player
    return pa and not pa.dying and pa.alive ~= false and not self.dead and not self.won and not self.endingT
           and not self.startCd and not (self.runOut and self.runOut.active)
end

function AdventureState:openWheel(mode, touchId)
    gStateMachine:push('powerup_wheel', { pa = self.player, inv = self.powerups, mode = mode, touchId = touchId })
end

-- Atajo n (teclas 1–6): el n-ésimo tipo que se tiene (el orden de la rueda); si no se puede usar ahora, nada se gasta
function AdventureState:usePowerupAt(n)
    local it = self.powerups.items()[n]
    if not it then return end
    if self.player:canUse(it.id) and self.powerups.spend(it.id) then self.player:usePowerup(it.id) else Sound.play('headBump') end
end

function AdventureState:pauseGame()
    if not self.dead and not self.won and not self.endingT then gStateMachine:push('pause') end
end

-- ── Cámara ────────────────────────────────────────────────────────────────────
-- ── Colisión jugador ↔ burbujas de oxígeno de vents ─────────────────────────
function AdventureState:checkVentOxyCollisions()
    local player = self.player
    if player.dying or not player.alive then return end
    local ob  = player:getOuterBounds()
    local hit = self.level:checkVentOxyCollision(ob.x, ob.y, ob.w, ob.h)
    if hit then
        if player.drownPhase == 'warning' or player.drownPhase == 'drowning' then
            if player.drownPhase == 'drowning' then
                Sound.stopTracked('drowning')
                Sound.playMusic('level')
            end
            player.drownTimer  = 0
            player.drownChime  = 0
            player.drownAudT   = 0
            player.drownDead   = false
            player.drownPhase  = 'none'
            player.airBarBobT  = 0
            player.airBarBobOn = true
        end
        Sound.play('airGasp')
    end
end

-- ── Popups de puntos ─────────────────────────────────────────────────────────
-- Animación: aparece desde abajo invisible → sube con rebote → desvanece
local POPUP_LIFE     = 1.4    -- duración total en segundos
local POPUP_RISE     = 28     -- px que sube en total
local POPUP_BOUNCE_T = 0.22   -- fracción del tiempo dedicada al bounce inicial

function AdventureState:spawnPopup(text, wx, wy)
    table.insert(self.popups, {
        text  = text,
        wx    = wx,    -- posición mundo X
        wy    = wy,    -- posición mundo Y (tope del gummy)
        timer = 0,
    })
end

function AdventureState:updatePopups(dt)
    for i = #self.popups, 1, -1 do
        local pop = self.popups[i]
        pop.timer = pop.timer + dt
        if pop.timer >= POPUP_LIFE then
            table.remove(self.popups, i)
        end
    end
end

function AdventureState:renderPopups()
    if #self.popups == 0 then return end
    love.graphics.setFont(FONT_MED)
    for _, pop in ipairs(self.popups) do
        local t        = pop.timer / POPUP_LIFE   -- 0→1
        local alpha, offsetY

        -- Curva continua: offsetY sube suavemente de 0 → POPUP_RISE con ease-out
        offsetY = POPUP_RISE * (1 - (1 - t) * (1 - t))

        if t < POPUP_BOUNCE_T then
            -- Fade in rápido
            alpha = t / POPUP_BOUNCE_T
        else
            -- Fade out
            local ft = (t - POPUP_BOUNCE_T) / (1 - POPUP_BOUNCE_T)
            alpha    = 1 - ft
        end

        local sx = math.floor(pop.wx - self.camX)
        local sy = math.floor(pop.wy - self.camY - offsetY)

        -- Sombra pixel-art
        love.graphics.setColor(0, 0, 0, alpha * 0.6)
        love.graphics.printf(pop.text, sx - 119, sy + 1, 240, 'center')
        -- Texto amarillo brillante
        love.graphics.setColor(1, 0.95, 0.15, alpha)
        love.graphics.printf(pop.text, sx - 120, sy, 240, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function AdventureState:updateCamera(dt)
    -- (demo con cámara propia: los escenarios de los créditos, src/story/LiveStage.lua)
    if self.demo and self.demo.camera then self.camX, self.camY = self.demo.camera(self); return end
    -- (la escena final de una carrera en la historia — src/story/RunOut.lua —: la cámara se queda donde la dejó la
    -- cámara automática y ellos salen de cuadro; si siguiera al jugador, acabarían contra la pared del final del nivel)
    if self.runOut and self.runOut.active then return end
    -- Con cámara automática la cámara ES el nivel: sigue moviéndose aunque se muera
    local scrolling = self.level.autoScroll and self.level.autoScroll.state ~= 'stop'
    if self.camFrozen and not scrolling then return end

    local targetX = self.player.x - WINDOW_W * (self.demo and self.demo.camX or 0.5)
    local targetY = self.player.y - WINDOW_H * (self.demo and self.demo.camY or 0.5)
    -- (MIRAR arriba / abajo manteniendo ARRIBA o AGACHARSE quieto: src/ui/CameraLook.lua; no en la demo, ni volando
    -- en un nivel Flappy, ni en una zona de jefe — la cámara es la zona —)
    self._look = self._look or {}
    local zoneCam = BossZones.cameraTarget(self.level, self.player.x, self.player.y)
    targetY = targetY + CameraLook.offset(self._look, self.player, dt, not self.demo and not self.level.flappy and not zoneCam)
    targetX = targetX + CameraLook.lead(self._look, self.player, dt, not self.demo and not self.level.flappy and not zoneCam)

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))
    -- Dentro de una zona de jefe la cámara se queda fija en ella
    local zx, zy = BossZones.cameraTarget(self.level, self.player.x, self.player.y)
    if zx then targetX, targetY = zx, zy end
    if scrolling then
        targetX = AutoScroll.cameraX(self.level)
    end

    -- (un director movió a los jugadores a otra parte del nivel — el Mega Mashup —: la cámara salta, no se desliza)
    if (self.level.cameraCut or 0) ~= (self._camCut or 0) then self._camCut, self.camSnap = self.level.cameraCut, true end
    if self.camSnap then self.camX, self.camY, self.camSnap = targetX, targetY, false; return end
    local k = CAM_LERP * BossZones.cameraEase(self, zx ~= nil, dt)      -- (sin tirón al entrar / salir de una zona)
    self.camX = self.camX + (targetX - self.camX) * k * dt
    self.camY = self.camY + (targetY - self.camY) * k * dt
    -- Cámara automática: sin suavizado horizontal (la ventana manda)
    if scrolling then self.camX = targetX end
end

-- ── Colisión jugador ↔ entidades ──────────────────────────────────────────────
-- Las reglas (pinchos, pisotón, coleccionables, checkpoints, ground pound)
-- viven en entities/Interactions.lua; aquí solo los efectos del modo solo.
function AdventureState:checkEnemyCollisions()
    local player = self.player
    Entities.interactions.run(player, self.enemies, {
        stomp = function(g, pts)
            self.score = self.score + (pts or 0)
            if not g.def.boss and g.state == 'dead' then self.stats.kills = self.stats.kills + 1 end
            local popY = g.flipped and (g.y + g.outerH / 2) or (g.y - g.outerH / 2)
            self:spawnPopup('+' .. (pts or 0) .. '!', g.x, popY)
        end,
        pickup = function(e, pk)
            if pk.lives and not e.taken and e.placeIdx then self.takenNow[e.placeIdx] = true end
            pk = Entities.interactions.pickupEffect(player, pk, e)
            self.stats.items = self.stats.items + 1
            if pk.heal then
                player.hp = player.hp + pk.heal
                self.prevHp = player.hp
                self:spawnPopup(L('hud.plus_hp'), e.x, e.y - e.outerH / 2)
                Sound.play('appleHeal'); Particles.emit('collect', e.x, e.y)
            end
            if pk.score then
                self.score = self.score + pk.score
                if e.def.name == 'star' then self.stats.stars = self.stats.stars + 1 end
                self:spawnPopup('+' .. pk.score .. '!', e.x, e.y - e.outerH / 2)
                Sound.play('collect'); Particles.emit('collect', e.x, e.y)
            end
            if pk.lives then
                player.lives = math.min(99, player.lives + pk.lives)
                self:spawnPopup(L('hud.plus_life'), e.x, e.y - e.outerH / 2)
                Sound.play('oneUp'); Particles.emit('oneup', e.x, e.y)
            end
        end,
        checkpoint = function(e)
            if self.checkpoint == e then return end
            if self.checkpoint then self.checkpoint.activeLocal = false end
            self.checkpoint = e
            e:activate()
            player.spawnX, player.spawnY = e:respawnPoint()
            Sound.play('checkpoint'); Particles.emit('checkpoint', e.x, e.y - e.outerH / 2)
            self:spawnPopup(L('hud.checkpoint'), e.x, e.y - e.outerH / 2 - 10)
        end,
    })
end

-- Reintentar (tras perder todas las vidas): el mismo nivel con lo mismo que traía
function AdventureState:retryArgs()
    return { level = self.levelPath, returnTo = self.returnTo, onFinish = self.onFinish, difficulty = self.level.difficulty,
             shards = self.shardArgs, outro = self.outroArgs, taken = self.takenArg, rescued = self.rescuedArg,
             eventCheckpoint = self.level.eventCheckpointNow }      -- (Mega Mashup: se reintenta en el cangrejo en que estabas)
end

-- REINTENTAR desde la pausa (el usuario, 2026-11-02): el nivel otra vez desde el principio, con los mismos argumentos.
-- Lo conseguido en este intento no se guarda (no ha terminado: regla 7). Con VIDAS (historia, Flappy, Boss Rush)
-- cuesta UNA, como morir, para que no se abuse (el usuario, 0.5.200; la pausa avisa antes): se cuenta como una muerte y
-- se guarda al momento. Con la última vida no se puede.
function AdventureState:retryCostsLife() return (self.enterArgs or {}).lives ~= nil and not self.bonus end
function AdventureState:canRetry()
    if self.demo or self.won or self.endingT then return false end
    return not self:retryCostsLife() or self.player.lives > 1
end
function AdventureState:retryNow()
    local a = {}
    for k, v in pairs(self.enterArgs or {}) do a[k] = v end
    if self:retryCostsLife() then
        self.player.lives = self.player.lives - 1
        self.stats.deaths = (self.stats.deaths or 0) + 1
        self:_saveLostLives()
    end
    if a.lives then a.lives = math.max(1, self.player.lives) end
    if self.level.eventCheckpointNow then a.eventCheckpoint = self.level.eventCheckpointNow end   -- (Mega Mashup)
    gStateMachine:change('adventure', a)
end

-- Lo que se lleva del nivel (para la nota del modo historia: src/story/Score.lua)
function AdventureState:result()
    local st = self.stats
    local taken = {}
    for i in pairs(self.takenNow or {}) do taken[#taken + 1] = i end
    local rescued = {}
    for _, e in ipairs(self.enemies or {}) do if e.rescuedNow and e.placeIdx then rescued[#rescued + 1] = e.placeIdx end end
    return { score = self.score, time = self.levelTime, lives = self.player.lives, width = self.level.tileW, par = self.level.parTime, taken = taken, rescued = rescued,
             kills = st.kills, killable = st.killable, stars = st.stars, starsTotal = st.starsTotal,
             deaths = st.deaths, hits = st.hits, secretExit = self.secretExit or nil }
end

-- Fragmentos del espejo: cada jefe vencido suelta el suyo; al recogerlo se apunta en la partida (onGet). Con el
-- último del juego (shards.final), el jugador se queda quieto y a salvo y la pantalla se funde a blanco.
-- `shards.auto` (la historia, en los niveles con jefe): vencido el jefe y recogido su fragmento, el nivel TERMINA solo
-- (sin ir a la meta; en el juego libre y online sigue habiendo que llegar a ella)
AdventureState.ENDING_TIME = 2.2
AdventureState.AUTO_WIN_T = 0.8          -- s tras recoger el fragmento (que se vea el cartel) hasta "nivel superado"
function AdventureState:updateShards(dt)
    local sh = self.shards
    if not sh then return end
    local before, cbefore = sh.got, sh.cgot
    sh:update(dt)
    if sh.cgot > cbefore then self:spawnPopup(L('hud.collect'), self.player.x, self.player.y - 70) end   -- (un coleccionable)
    if sh.got > before then
        self:spawnPopup(L('hud.shard'), self.player.x, self.player.y - 70)
        if sh.final and sh:allGot() and not self.endingT and not self.won then
            self.endingT = 0
            self.player.forceFrozen = true
            self.player:grantInvulnerability(AdventureState.ENDING_TIME + 2)
            Sound.stopMusic()
        end
    end
    if sh.auto and not sh.final and not self.won and not self.endingT and not self.player.dying and sh:cleared() then
        self.autoWinT = (self.autoWinT or 0) + dt
        if self.autoWinT >= AdventureState.AUTO_WIN_T then self:win() end
    end
end

-- Ha llegado a la meta: ya no le pasa nada, suena la fanfarria y sale el cartel
AdventureState.WIN_TIME = 2.6
function AdventureState:win()
    self.won, self.wonT = true, 0
    self.player.victory = true                               -- (su pose de victoria: PlayerAdventure.actionPose)
    -- (contrarreloj: ¿su mejor tiempo? se guarda el fantasma nuevo y se dice)
    if self.ghost and require('src/story/Ghost').finish(self.levelPath, self.levelTime, self.ghost.rec) then
        self:spawnPopup(L('free.ghost_record'), self.player.x, self.player.y - 90)
    end
    if self.shards then self.shards:collectAll() end       -- (un fragmento suelto sin recoger no se pierde)
    self.player:grantInvulnerability(AdventureState.WIN_TIME + 2)
    Sound.stopMusic()
    Sound.play('fanfare')
    self.bossBanner = { text = L('hud.level_clear'), t = 0, col = { 1, 0.9, 0.25 } }
end

-- ── Update ────────────────────────────────────────────────────────────────────
function AdventureState:update(dt)
    -- HIT-STOP: unos fotogramas congelado tras un golpe fuerte (src/ui/HitStop.lua); la música sigue
    if HitStop.step(dt) and not self.demo then return end
    -- El duelo de ritmo del Cangrejo Groove (lo juega el jugador; el jefe decide el resto)
    RhythmDuel.update(dt, self.level, self.player, function(bar, acc, failed)
        for _, e in ipairs(self.level.liveEntities or {}) do
            if e.duelReport then e:duelReport(self.player, bar, acc, failed) end
        end
    end)
    -- ── Game over ─────────────────────────────────────────────────────────────
    if self.dead then
        self.timeScale = self.timeScale + (0.7 - self.timeScale) * 2 * dt
        Sound.setMusicPitch(self.timeScale)
        self.deadTimer = self.deadTimer + dt

        local sdt = dt * self.timeScale
        self.player:update(sdt, self.level)

        if self.deadTimer > 0.8 then
            if Input.pressed('nav_up') then
                self.selectedOpt = self.selectedOpt - 1
                if self.selectedOpt < 1 then self.selectedOpt = #GAMEOVER_OPTIONS end
                Sound.play('select')
            end
            if Input.pressed('nav_down') then
                self.selectedOpt = self.selectedOpt + 1
                if self.selectedOpt > #GAMEOVER_OPTIONS then self.selectedOpt = 1 end
                Sound.play('select')
            end
            if Input.pressed('confirm') then
                Sound.play('select')
                if self.onGameOver then self.onGameOver(); return end
                if self.selectedOpt == 1 then
                    gStateMachine:change('adventure', self:retryArgs())
                else
                    gStateMachine:change(self.returnTo)
                end
                return
            end
        end
        return
    end

    -- ── Respawn ───────────────────────────────────────────────────────────────
    if self.respawning then
        if self.bonus then self.bonus:update(dt); if self.bonus.sent then return end end   -- (el reloj y el bot siguen)
        self.player:update(dt, self.level)
        self.respawnTimer = self.respawnTimer + dt
        if self.respawnTimer >= RESPAWN_DELAY then
            -- Cámara automática: se reaparece en el centro de lo que se ve
            Sim.respawnPoint(self.level, self.player)
            self.player:respawn()
            self.deathShowT   = 0                                -- (la causa de la muerte, unos segundos)
            self.camFrozen    = false
            self.respawning   = false
            self.respawnTimer = 0
        end
        return
    end

    -- ── Forzar recálculo del Canvas si la pantalla rota / cambia proporción ──
    self.sceneCanvas = require('src/fx/SceneCanvas').get()   -- (el mismo; otro si la pantalla cambió)

    -- ── Controles táctiles (móvil): cruceta + salto, ver src/ui/TouchControls ──
    -- (el botón extra: el ATAQUE ESPECIAL en los niveles Flappy; la linterna en los niveles a oscuras)
    if not self.demo then TouchControls.update(not self.dead, self.level.flappy and 'special' or self.level.dark, not self.level.flappy) end

    -- (en la escena final no hay pausa, ni ya ganado: salir en la celebración perdía el nivel)
    if not self.demo and Input.pressed('pause') and not (self.runOut and self.runOut.active) and not self.won and not self.endingT then
        gStateMachine:push('pause')
        return
    end
    -- La RUEDA de los power-ups (mantener) y los atajos 1–6 (el tipo de esa posición, directamente)
    if self.powerups and self:canUsePowerups() then
        if Input.pressed('wheel') then return self:openWheel() end          -- (mantener o pulsar: la opción)
        for n = 1, 6 do
            if Input.pressed('wheel_' .. n) then self:usePowerupAt(n); break end
        end
    end

    -- ── Cuenta atrás del principio: el mundo congelado y sin control ──────────
    if self.card then self.cardT = self.cardT + dt end
    if self.deathShowT then self.deathShowT = self.deathShowT + dt end
    if self.startCd then
        StartCountdown.beeps(self.startPrev, self.startCd - dt)
        self.startPrev = self.startCd - dt
        self.startCd = self.startCd - dt
        if self.startCd > 0 then self:updateCamera(dt); return end
        self.startCd, self.startGoT = nil, 0
    end
    if self.startGoT then
        self.startGoT = self.startGoT + dt
        if self.startGoT >= StartCountdown.GO_TIME then self.startGoT = nil end
    end

    -- ── Nivel superado: un momento de celebración y se sale ───────────────────
    if self.won then
        self.wonT = self.wonT + dt
        if self.wonT >= AdventureState.WIN_TIME then
            self.finished = true                              -- (terminado: lo conseguido SÍ se guarda; ver exit)
            if self.onFinish then self.onFinish(self:result()) else gStateMachine:change(self.returnTo) end
            return
        end
    end
    -- ── El ÚLTIMO fragmento, recogido: la pantalla se va a blanco y empieza el final de la historia ──
    if self.endingT then
        self.endingT = self.endingT + dt
        if self.endingT >= AdventureState.ENDING_TIME then
            local r = self:result()
            r.ending = true
            self.finished = true
            if self.onFinish then self.onFinish(r) else gStateMachine:change(self.returnTo) end
            return
        end
    end

    -- ── Lógica normal ─────────────────────────────────────────────────────────
    -- Cap del tiempo: congelar en 600 al morir por tiempo
    if not self.player.dying and not self.won then
        self.levelTime = math.min(self.levelTime + dt, Sim.TIME_LIMIT)
        if self.ghost then require('src/story/Ghost').record(self.ghost.rec, dt, self.player) end
    end

    -- Límite de 10 minutos: muerte instantánea con todas las vidas
    if self.levelTime >= Sim.TIME_LIMIT and not self.player.dying then
        self.player.lives = 1   -- die() restará 1, quedando en 0 → game over
        self.player:die(nil, true)
    end

    -- (solo dibujo / solo de este jugador: decoraciones, bloques escondidos que ve, la espuma de las inundaciones)
    self.level:updateFoliage(dt)
    self.level:updateHiddenBlocks(dt, self.player.dying and {} or { self.player:getOuterBounds() })
    Floods.updateFx(self.level, dt)
    -- (la escena final de una carrera en la historia: al acabar, el nivel termina sin meta y enlaza con el siguiente)
    if self.runOut and self.runOut:update(dt) then
        local r = self:result()
        r.outro = true
        self.finished = true
        if self.onFinish then self.onFinish(r) else gStateMachine:change(self.returnTo) end
        return
    end

    -- ── EL PASO de la simulación: el mismo orden que el servidor (src/world/systems/Sim.lua, Sim.step) ──
    self._simHooks = self._simHooks or self:_makeSimHooks()
    self._simDt = dt
    if not Sim.step(self.level, self.enemies, dt, self._simHooks) then return end      -- (el bonus terminó)

    -- (Boss Rush: vencidos todos sus jefes, el nivel termina — sin ir a la meta —)
    if self.endOnBoss and not self.won and not self.player.dying and #(self.level.bossZones or {}) > 0 then
        local all = true
        for _, bz in ipairs(self.level.bossZones) do if bz.state ~= 'cleared' then all = false end end
        if all then self:win() end
    end
    Particles.update(dt)
    self:updatePopups(dt)

    self:updateShards(dt)
    self:updateCamera(dt)
    if self.rec then self.rec:step(dt, self) end

    -- (golpes recibidos: cada vez que baja la vida sin morir)
    if self.player.hp < self.prevHp and not self.player.dying then
        self.stats.hits = self.stats.hits + (self.prevHp - self.player.hp)
        if not self.demo then Rumble.hurt() end
    end
    self.prevHp = self.player.hp

    if self.player.dying and not self._hsDying and not self.demo then
        HitStop.trigger(HitStop.DEATH)                                        -- (al morir)
        -- (de qué: se dice al reaparecer — src/player/DeathCause.lua, src/ui/DeathBanner.lua —)
        self.deathCause = require('src/player/DeathCause').of(self.player, self.level, self.enemies, self.player.deathFlags)
    end
    self._hsDying = self.player.dying
    -- ── Detectar muerte del jugador ───────────────────────────────────────────
    if self.player.dying and not self.player.alive then
        self.player.lives = self.demo and 99 or (self.player.lives - 1)      -- (la demo: vidas sin fin)
        self.stats.deaths = self.stats.deaths + 1

        if self.player.lives <= 0 then
            self.dead        = true
            self.deadTimer   = 0
            self.selectedOpt = 1
            self.timeScale   = 1.0
        else
            self.respawning   = true
            self.respawnTimer = 0
            self.camFrozen    = true
            if not self.demo then self:_saveLostLives() end
        end
    elseif self.player.dying then
        self.camFrozen = true
    end
end

-- Los GANCHOS del paso compartido (Sim.step: el orden está allí, igual que en el servidor). Uno por estado: sin cierres
-- nuevos por fotograma; el dt del fotograma, en self._simDt.
function AdventureState:_makeSimHooks()
    local h = {}
    h.floods = function() Floods.advance(self.level, self._simDt) end           -- inundaciones: el agua sube y baja
    h.players = function()
        local dt = self._simDt
        local scripted = self.runOut and self.runOut:input()
        if self.demo then
            self.demo.step(dt, self.level)                                -- (el bot del fondo de los menús)
        elseif scripted then                                              -- (sin control: corre y salta solo)
            local real = Input
            Input = scripted
            self.player.moveK = 1                                         -- (a la velocidad fija: el guion no pulsa correr)
            local ok, err = pcall(self.player.update, self.player, dt, self.level)
            Input = real
            if not ok then error(err, 0) end
        else
            self.player:update(dt, self.level)
        end
        Scenes.follow(self.level, self.player, dt)                        -- (niveles con `followScenes`: el tutorial)
        -- al moverse, como cada jugador en el servidor: el oxígeno, la 1ª pasada de choques y las metas
        self:checkVentOxyCollisions()
        self:checkEnemyCollisions()
        self:_checkGoals()
        if self.bonus then
            self.level.players = { self.player }                          -- (los enemigos ven a todos)
            for _, b in ipairs(self.bonus.bots) do self.level.players[#self.level.players + 1] = b.pa end
            self.bonus:update(dt)
            if self.bonus.sent then return 'stop' end
        end
        -- (los sonidos de las entidades se atenúan según lo lejos que estén del jugador: Sound.setEmitter)
        Sound.setListener(self.player.x, self.player.y)
    end
    h.emit, h.prune = Sound.setEmitter, true
    h.zonePlayers = function()
        -- Zonas de puntos: estar dentro da puntos cada cierto tiempo
        local inZones = self.bonus and self.bonus:players() or (self.player.dying and {} or { self.player })
        if self.bonus and self.bonus.over then inZones = {} end
        -- (cuánto tiempo pasa el jugador DENTRO de una zona: los resultados del bonus)
        if #inZones > 0 and not self.player.dying then
            for _, a in ipairs(self.level.pointAreas or {}) do
                if PointAreas.isActive(self.level, a) and PointAreas.inside(a, self.player.x, self.player.y) then
                    self.stats.zoneT = self.stats.zoneT + self._simDt; break
                end
            end
        end
        return inZones
    end
    h.zonePoints = function(pa, pts)
        if self.bonus and not self.bonus:award(pa, pts) then
            Particles.emit('points', pa.x, pa.y)
            return
        end
        self.score = self.score + pts
        self:spawnPopup('+' .. pts, pa.x, pa.y - 60)
        Sound.play('pointGain'); Particles.emit('points', pa.x, pa.y)
    end
    h.bosses = function()
        if not (self.demo and self.demo.noBossCtl) then self:updateBoss(self._simDt) end   -- (los créditos: sin pelea de verdad)
    end
    h.autoScroll = function()
        for _, ev in ipairs(AutoScroll.update(self.level, self._simDt)) do
            if ev.type == 'scroll_start' and not ev.quiet then self.bossBanner = { text = L('hud.go'), t = 0, col = { 0.4, 1, 0.5 } } end
        end
    end
    h.interactions = function() self:checkEnemyCollisions() end         -- (2ª pasada: lo que se movió alcanza al jugador)
    return h
end

-- ── META: tocarla termina el nivel (al moverse el jugador, como en el servidor: Sim.step) ──
function AdventureState:_checkGoals()
    if self.won or self.endingT or self.player.dying then return end
    local ob = self.player:getOuterBounds()
    if self.level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'finish') then self:win() end
    -- (la SALIDA SECRETA, tile `secret_exit`: termina el nivel como la meta y el resultado lo dice — `secretExit` —; en
    --  la historia abre además el camino secreto: Worlds `secrets`, StoryMapState. Fuera de la historia es una meta más)
    if not self.won and self.level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'secret_exit') then
        self.secretExit = true
        self:win()
    end
end

-- ── Jefes ─────────────────────────────────────────────────────────────────────
function AdventureState:updateBoss(dt)
    for _, ev in ipairs(self.bossCtl:update(dt)) do
        if ev.type == 'boss_start' then
            self.bossBanner = { text = L('hud.boss'), t = 0, col = { 1, 0.3, 0.3 } }
            self.bossFightT = 0
        elseif ev.type == 'boss_clear' then
            self.bossBanner = { text = L('hud.boss_defeated'), t = 0, col = { 1, 0.9, 0.25 } }
            Sound.play('fanfare')
        end
    end
    if self.bossBanner then self.bossBanner.t = self.bossBanner.t + dt end
    self.bossFightT = self.bossFightT + dt
    -- (escena nueva con otro eco: src/world/level/Scenes.lua)
    if self.level.echo ~= self._echo then self._echo = self.level.echo; Sound.setEcho(self.level.echo and 1 or 0) end
    -- Música ADAPTATIVA (un director: el Mega Mashup): manda él
    local path, pid, pos, nxt = BossZones.adaptive(self.level)
    if path then
        Sound.setLevelMusic(Sound.ADAPTIVE)
        if self.player.drownPhase ~= 'drowning' then Sound.followAdaptive(path, pid, pos, nxt) end
        -- (en un jugador MANDA EL AUDIO: el reloj del director se ajusta a lo que suena — si no, a la mínima pausa del
        -- juego se separaban, la música se recolocaba y se oía un salto: el usuario, 0.5.65, en el bucle del Groove)
        local apid, at = Sound.adaptiveTell()
        local md = self.level.musicDirector
        if apid and md and apid == md.piece and math.abs(at - md.pos) < 0.5 and md.syncAudio then md:syncAudio(at) end
        return
    end
    -- Música de la pelea (intro + bucle); al terminar vuelve la del nivel
    local want = BossZones.music(self.level)
    if want ~= Sound.getLevelMusic() then
        Sound.setLevelMusic(want)
        if want == BossZones.SILENCE then Sound.stopMusic()          -- (entrada del jefe: silencio)
        elseif self.player.drownPhase ~= 'drowning' then Sound.playMusic('level') end
    end
end

function AdventureState:renderBossHud()
    local z = BossZones.fighting(self.level)
    -- (nivel FLAPPY: su HUD propio — vida siempre a la vista y la carga del ataque especial: src/ui/FlappyHud.lua —)
    if self.level.flappy then
        local FlappyHud = require 'src/ui/FlappyHud'
        FlappyHud.draw(self.player)
        if self.powerups then                                       -- (la bolsa: cuántos power-ups quedan; tocarla, la rueda)
            local n = 0
            for _, it in ipairs(self.powerups.items()) do n = n + it.count end
            FlappyHud.drawBag(n)
        end
    end
    if z and self.level.flappy then
        BossHud.drawZone(z, 18, math.min(1, self.bossFightT / 0.8))
    elseif z then
        local y = 18
        y = BossHud.drawZone(z, y, math.min(1, self.bossFightT / 0.8))
        local p = self.player
        BossHud.drawPlayers({ { name = L('hud.you'), color = { 1, 0.95, 0.2 }, hp = p.hp, hpMax = p.hpMax,
                                key = p, dead = p.dying } }, 20, 110)
    elseif self.player.hp < self.player.hpMax and not self.player.dying and not self.level.flappy then
        -- Fuera de una pelea: la vida solo si le falta algo
        local p = self.player
        BossHud.drawPlayers({ { name = L('hud.you'), color = { 1, 0.95, 0.2 }, hp = p.hp, hpMax = p.hpMax, key = p } }, 20, 110)
    end
    if self.bossBanner then
        BossHud.drawBanner(self.bossBanner.text, self.bossBanner.t, 2.2, self.bossBanner.col)
    end
    BossHud.drawScrollCountdown(self.level.autoScroll)
    if self.startCd or self.startGoT then BossHud.drawStartCountdown(self.startCd or -self.startGoT) end
    if self.card then require('src/ui/LevelCard').draw(self.card, self.cardT) end
    if self.deathShowT then require('src/ui/DeathBanner').draw(self.deathCause, self.deathShowT) end
    BossHud.drawRun(self.level, self.enemies)                     -- (la persecución del Espejo: ¡CORRE!)
    BossHud.drawUndertow(self.level)                              -- (la resaca: ¡RESACA! y hacia dónde)
end

-- ── HUD: vidas ────────────────────────────────────────────────────────────────
local function renderLivesHud(player, dark)
    local iconW = imgIcon:getWidth()  * ICON_SCALE
    local iconH = imgIcon:getHeight() * ICON_SCALE

    love.graphics.setFont(FONT_BIG)
    local label  = 'x' .. player.lives
    local labelW = FONT_BIG:getWidth(label)
    local gap    = 10

    local totalW = iconW + gap + labelW
    local sx     = WINDOW_W - totalW - 20
    local sy     = 14

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgIcon, sx, sy, 0, ICON_SCALE, ICON_SCALE)

    local lx, ly = sx + iconW + gap, sy + iconH/2 - FONT_BIG:getHeight()/2
    -- SIEMPRE blanco con sombra negra, como el resto del HUD: en negro no se leía de noche, al atardecer, en cuevas
    -- ni sobre fondos oscuros (antes solo se cambiaba en los niveles a oscuras)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(label, lx + 3, ly + 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(label, lx, ly)
end

-- ── Render ────────────────────────────────────────────────────────────────────
function AdventureState:render()
    -- Temblor de pantalla (impactos, explosiones): solo al dibujar
    local shx, shy = Particles.shakeOffset()
    local realCamX, realCamY = self.camX, self.camY
    -- Cámara en píxeles ENTEROS al dibujar (pixel art): con decimales, los
    -- tiles caían a medio píxel y lo que redondea su posición (bloques de jefe,
    -- entidades) no: quedaban rendijas de 1 px que, con la ventana grande
    -- (canvas escalado), se veían como líneas entre bloques que deben unirse
    self.camX, self.camY = math.floor(self.camX + shx + 0.5), math.floor(self.camY + shy + 0.5)
    self:_renderScene()
    self.camX, self.camY = realCamX, realCamY
    if self.runOut then self.runOut:render() end                  -- (el fundido a negro de la escena final)
    -- (el último fragmento: a blanco, y de ahí al final de la historia)
    if self.endingT then
        love.graphics.setColor(1, 1, 1, math.max(0, math.min(1, (self.endingT - 0.9) / (AdventureState.ENDING_TIME - 1.0))))
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Lo que va entre las entidades de atrás y las de delante (SceneLayers: el orden de las capas, compartido con online)
function AdventureState:_drawActors(camX, camY)
    if self.bonus then self.bonus:render(camX, camY) end
    -- (en el duelo de ritmo no está en la arena: sale bailando en el minijuego — src/ui/RhythmDuel.lua —)
    if self.ghost and self.ghost.draw then self.ghost.draw(self.levelTime, camX, camY) end   -- (el fantasma, detrás)
    if not RhythmDuel.hides(self.level, self.player.x, self.player.y) then self.player:render(camX, camY) end
    PointAreas.drawProgress(self.level, self.player, self.player.x - camX, self.player.y - camY)
end

function AdventureState:_renderScene()
    -- ── La escena entera al lienzo, y al volver, el efecto del agua (src/world/level/SceneLayers.lua) ──
    self._actorsFn = self._actorsFn or function(cx, cy) self:_drawActors(cx, cy) end     -- (uno por estado: sin basura)
    SceneLayers.draw(self.level, self.camX, self.camY, self.sceneCanvas, self.enemies, self._actorsFn,
                     self.demo and self.demo.noSky)

    -- A oscuras: solo se ve lo que alumbra la linterna; encima, los puntos luminosos
    -- (y la luz ambiente de cada nivel: atardecer, noche, cueva en penumbra — src/fx/Darkness.lua)
    if Darkness.active(self.level) then
        local p, src = self.player, self._lightSrc        -- (la linterna del jugador: tabla del estado, rellenada aquí)
        if not src then src = { {} }; self._lightSrc = src end
        local L1 = src[1]
        L1.x, L1.y, L1.facing, L1.on = p.x, p.y, p.facing, p.lightOn and not p.dying
        Darkness.render(self.level, self.camX, self.camY, src, self.enemies, self.sceneCanvas)
        Darkness.renderGlow(self.level, self.enemies, self.camX, self.camY)
    end

    -- Fragmentos del espejo que han soltado los jefes (brillan: encima de la oscuridad)
    if self.shards then self.shards:render(self.camX, self.camY) end
    Carry.drawPrompt(self.player, self.enemies, self.camX, self.camY)      -- (la ayuda de "coger": systems/Carry)
    if not self.demo then Entities.renderOverlays(self.enemies, self.camX, self.camY, self.player, love.timer.getDelta()) end   -- (carteles)
    self.player.drawMashPrompt(self.player, self.camX, self.camY)          -- (machacar: tragado por una planta / en hielo)

    -- ── Debug hitboxes (F1) ───────────────────────────────────────────────────
    if DEBUG_HITBOX then
        love.graphics.setLineWidth(2)                    -- (a 1 px y medio transparentes casi no se veían)
        self.player:renderDebug(self.camX, self.camY)
        if self.bonus then for _, b in ipairs(self.bonus.bots or {}) do b.pa:renderDebug(self.camX, self.camY) end end      -- (los bots)

        -- Hitboxes de enemigos
        for _, g in ipairs(self.enemies) do
            if g.alive then g:renderDebug(self.camX, self.camY) end
        end

        -- Hitboxes reales del nivel (pinchos, contacto, formas de colisión)
        self.level:renderDebug(self.camX, self.camY)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("DEBUG HITBOX [F1]", 20, WINDOW_H - 30)
    end

    if self.demo then return end          -- (la demo del fondo de los menús: sin HUD)
    -- (un director de evento: siluetas de su intro y el fundido a negro de sus costuras — el Mega Mashup —)
    local md = self.level.musicDirector
    if md and md.drawOverlay then md:drawOverlay() end
    RhythmDuel.drawDim()                  -- (el duelo de ritmo: el fondo se oscurece, bajo el HUD)
    BossHud.drawCinema(self.level)        -- (entrada de un jefe: franjas de cine, bajo el HUD)

    -- (todo el HUD se desvanece durante la entrada de un jefe: BossHud.fadeHud)
    self._hudFn = self._hudFn or function() self:_drawHud() end           -- (uno por estado: sin basura)
    BossHud.fadeHud(self._hudFn)

    -- ── Game over overlay (la ventana de opciones de los menús: src/ui/menu/MenuKit) ──
    if self.dead and self.deadTimer > 0.4 then
        local oa = math.min(1, (self.deadTimer - 0.4) / 0.4)
        local labels, colors, o = self:_gameOverOptions()
        o.titleColor = { 1, 0.42, 0.38 }
        MenuKit.optionsWindow(L('hud.game_over'), labels, colors, self.onGameOver and 1 or self.selectedOpt, oa, o)
    end

    if not self.dead then BossHud.fadeHud(function() CornerButtons.drawPause(self.pauseHover) end) end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

-- Imprime texto con borde negro (sombra de 2 px)
local function printOutlined(text, x, y, r, g, b, a)
    love.graphics.setColor(0, 0, 0, (a or 1) * 0.75)
    love.graphics.print(text, x + 2, y + 2)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.print(text, x, y)
end

-- El HUD de la partida: puntos, tiempo, vidas, luz, jefe, aire... (dentro de BossHud.fadeHud: se desvanece en la entrada
-- de un jefe)
function AdventureState:_drawHud()
    -- HUD: SCORE y TIME  (sin fondo, valores alineados a la derecha)
    love.graphics.setFont(FONT_BIG)
    local fh = FONT_BIG:getHeight()

    local labelX  = 20
    local gap     = 20
    local row1Y   = 16
    local row2Y   = row1Y + fh + 10

    -- Calcular strings
    local totalSecs = math.floor(self.levelTime)
    local mins      = math.floor(totalSecs / 60)
    local secs      = totalSecs % 60
    local centis    = math.floor((self.levelTime - math.floor(self.levelTime)) * 100)
    local timeStr   = mins .. string.format("'%02d''%02d", secs, centis)
    local scoreStr  = string.format('%06d', self.score)

    -- Columna de etiquetas y columna de valores alineados a la derecha
    local scoreLabelW = FONT_BIG:getWidth(L('hud.score'))
    local timeLabelW  = FONT_BIG:getWidth(L('hud.time'))
    local maxLabelW   = math.max(scoreLabelW, timeLabelW)
    local valueStartX = labelX + maxLabelW + gap
    -- El ancho del área de valor se fija al más ancho de los dos valores
    local maxValueW   = math.max(FONT_BIG:getWidth(scoreStr), FONT_BIG:getWidth(timeStr))
    local valueEndX   = valueStartX + maxValueW  -- borde derecho común

    local sw = FONT_BIG:getWidth(scoreStr)
    local tw = FONT_BIG:getWidth(timeStr)

    -- SCORE
    printOutlined(L('hud.score'),  labelX,          row1Y, 1, 0.95, 0.15)
    printOutlined(scoreStr, valueEndX - sw,  row1Y, 1, 1,    1   )

    -- TIME (parpadea rojo cuando quedan menos de 60 s)
    local timeLeft = 600 - self.levelTime
    local tr, tg, tb, ta = 1, 0.95, 0.15, 1
    local vr, vg, vb, va = 1, 1,    1,    1
    if timeLeft < 60 then
        -- Parpadeo binario: 1s amarillo, 1s rojo
        local red = math.floor(love.timer.getTime()) % 2 == 0
        if red then
            tr, tg, tb = 1, 0.10, 0.10
            vr, vg, vb = 1, 0.20, 0.20
        end
    end
    printOutlined(L('hud.time'),   labelX,          row2Y, tr, tg, tb, ta)
    printOutlined(timeStr,  valueEndX - tw,  row2Y, vr, vg, vb, va)

    if not self.bonus then renderLivesHud(self.player, self.level.dark) end     -- (en el bonus no hay vidas: ver BonusMatch)
    if not self.bonus then self:_drawCollected() end                            -- (estrellas y jaulas: src/ui/CollectHud.lua)
    if self.level.dark then LightHud.draw(self.player, WINDOW_W - 206, 76) end      -- (bajo las vidas)
    self:renderBossHud()
    RhythmDuel.draw()
    if self.bonus then self.bonus:renderHud() end
    self.player:renderAirBar()
    self.player:renderDrownCountdown(self.player.x - self.camX, self.player.y - self.camY)
    self:renderPopups()
end

-- Estrellas cogidas y flappies liberados del nivel (lo de antes cuenta: las jaulas vacías ya liberadas)
function AdventureState:collectedCounts()
    local st = self.stats or {}
    local cages, freed = 0, 0
    for _, e in ipairs(self.enemies or {}) do
        if e.def and e.def.name == 'cage' then
            cages = cages + 1
            if e.rescuedNow or e.freed or e.state == 'open' or e.state == 'empty' then freed = freed + 1 end
        end
    end
    return st.stars or 0, st.starsTotal or 0, freed, cages
end
function AdventureState:_drawCollected()
    require('src/ui/CollectHud').draw(self:collectedCounts())
end

-- Las opciones del fin de partida: textos, colores y opciones de la ventana (historia: solo seguir, con su nota)
function AdventureState:_gameOverOptions()
    if self.onGameOver then return { L('story.go_continue') }, { 'green' }, { note = self.gameOverNote or '' } end
    local l = {}
    for i, k in ipairs(GAMEOVER_OPTIONS) do l[i] = L(k):upper() end
    return l, { 'green', 'red' }, {}
end

-- Hover del mouse: mueve la selección real (solo en game over)
function AdventureState:mousemoved(tx, ty)
    self.pauseHover = not self.dead and CornerButtons.hitPause(tx, ty)
    if not self.dead or self.deadTimer <= 0.8 or self.onGameOver then return end
    local i = MenuKit.optionAt(#GAMEOVER_OPTIONS, tx, ty)
    if i and self.selectedOpt ~= i then self.selectedOpt = i; Sound.play('select') end
end

-- En píxeles de pantalla, tras lovesize (game.lua): controles táctiles
function AdventureState:drawScreen()
    if TouchControls.visible() and not self.dead then TouchControls.draw(nil, nil, BossHud.hudAlpha()) end
end

-- Táctil Switch: tap en botón de game over
function AdventureState:touchpressed(id, tx, ty, dx, dy, pressure)
    if self.dead then
        if self.deadTimer <= 0.8 then return end
        if self.onGameOver then Sound.play('select'); self.onGameOver(); return end      -- (historia: cualquier toque sigue)
        local i = MenuKit.optionAt(#GAMEOVER_OPTIONS, tx, ty)
        if i then
            Sound.play('select')
            if i == 1 then
                gStateMachine:change('adventure', self:retryArgs())
            else
                gStateMachine:change(self.returnTo)
            end
            return
        end
        return
    end

    -- La BOLSA de los power-ups (HUD de Flappy): abre la rueda para tocar
    if self.powerups and self.level.flappy and self:canUsePowerups() then
        local b = require('src/ui/FlappyHud').bagRect()
        if tx >= b.x and tx <= b.x + b.w and ty >= b.y and ty <= b.y + b.h then return self:openWheel('tap', id) end
    end
    -- Botón de pausa (ratón y táctil)
    if CornerButtons.hitPause(tx, ty) then
        Input.VirtualPad._pressedThisFrame['pause'] = true
        return
    end
end

return AdventureState