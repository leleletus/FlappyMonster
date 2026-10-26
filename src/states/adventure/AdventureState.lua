local IceDrips = require 'src/fx/IceDrips'
local LavaFx   = require 'src/fx/LavaFx'
local Sky      = require 'src/fx/Sky'
local Snowfall = require 'src/fx/Snowfall'
local TouchControls = require 'src/ui/TouchControls'
local Darkness      = require 'src/fx/Darkness'
local LightHud      = require 'src/ui/LightHud'
local Difficulty    = require 'src/core/Difficulty'
local Noise         = require 'src/world/systems/Noise'
local CornerButtons = require 'src/ui/CornerButtons'
local L = require 'src/core/Lang'
local MenuKit = require 'src/ui/menu/MenuKit'
-- src/states/adventure/AdventureState.lua
local BaseState       = require 'src/core/BaseState'
local Level           = require 'src/world/level/Level'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local PlayRecorder    = require 'src/core/PlayRecorder'
local Entities        = require 'src/world/entities/Entities'
local Entity          = require 'src/world/entities/base/Entity'
local Particles       = require 'src/fx/Particles'
local BossZones       = require 'src/world/systems/BossZones'
local BossHud         = require 'src/ui/BossHud'
local AutoScroll      = require 'src/world/systems/AutoScroll'
local Floods          = require 'src/world/systems/Floods'
local PointAreas      = require 'src/world/systems/PointAreas'
local StartCountdown  = require 'src/world/systems/StartCountdown'

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
    args = args or {}
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
    self.won, self.wonT = false, 0
    self.finished = false

    self.level  = Level.new(self.levelPath, args.difficulty)
    -- (modo historia, nivel de jefe: sin META — acaba al vencer al jefe y recoger su fragmento, src/story/Shards —;
    --  sus casillas de meta se quitan)
    if args.shards and #(self.level.bossZones or {}) > 0 then
        for r = 1, self.level.tileH do
            for c = 1, self.level.tileW do
                if self.level:getDef(c, r).trigger == 'finish' then self.level.tiles[r][c] = 0 end
            end
        end
    end
    -- Dificultad (src/core/Difficulty.lua): la del modo historia; sin ella, el juego de siempre
    self.level.difficulty = Difficulty.valid(args.difficulty) and args.difficulty or nil
    Difficulty.bind(self.level)
    -- Hielo fino que se agrieta / rompe (lo decide el nivel): partículas y sonido
    self.level.tileFx = function(kind, c, r)
        local x, y = (c - 0.5) * TILE_PX, (r - 1) * TILE_PX + TILE_PX / 4
        Particles.emit(kind == 'icebreak' and 'ice_break' or 'ice_crack', x, y)
        Sound.playAt(kind == 'icebreak' and 'iceBreak' or 'iceCrack', x, y, 0.9 + math.random() * 0.2)
    end
    local sx, sy = self.level:getSpawnPx()
    self.player = PlayerAdventure:new(sx, sy)
    self.player:settle(self.level)             -- (de pie sobre el suelo desde el primer fotograma: la cuenta atrás)
    self.player:applyDifficulty()
    if self.startLives then self.player.lives = self.startLives end
    self.level.players = { self.player }       -- para trampas/entidades que "ven" al jugador
    -- Grabación de la partida para analizarla (FM_RECORD=1; ver src/core/PlayRecorder.lua)
    if PlayRecorder.enabled() and not self.demo then self.rec = PlayRecorder.new(self.levelPath, self.level.name) end

    -- Efectos del jugador (ground pound, bloques rotos...)
    Particles.clear()
    Particles.setLevel(self.level)                 -- (las partículas físicas chocan con él)
    require('src/fx/NoiseMarks').clear()
    require('src/world/systems/Noise').bind(self.level)         -- (ruidos que oyen los enemigos)
    PlayerAdventure.fx = function(kind, x, y)
        Particles.emit(kind, x, y)
        if kind == 'block_break' then Sound.play('blockBreak') end
        if kind == 'switch_hit' then               -- (el bloque ya cambió: suena su estado nuevo)
            local on = self.level:getDefAt(x + 1, y + 1).name == 'switch_on'
            Sound.play(on and 'switchOn' or 'switchOff')
        end
    end
    -- Impactos de pinchos que caen, bloques que rompe un jefe...
    Entity.fx = function(kind, x, y)
        Particles.emit(kind, x, y)
        if kind == 'block_break' then Sound.play('blockBreak') end
    end
    self._pfx, self._efx = PlayerAdventure.fx, Entity.fx

    -- Instanciar entidades (enemigos, NPCs) desde el catálogo
    -- (`args.taken` = { [nº de la colocación] = true }: vidas extra ya cogidas en este nivel en partidas TERMINADAS:
    -- salen transparentes y solo dan puntos. Las que se cogen ahora se apuntan en `self.takenNow` y la historia las
    -- guarda al terminar el nivel — Run.complete —, como todo lo demás)
    self.enemies, self.takenNow, self.takenArg = {}, {}, args.taken
    for i, placement in ipairs(self.level.entities) do
        local e = Entities.create(placement)
        if e then
            e.placeIdx = i
            if args.taken and args.taken[i] then e.taken = true end
            table.insert(self.enemies, e)
        end
    end

    -- BONUS del modo historia: Rey de la Colina contra el bot (src/story/BonusMatch.lua)
    self.bonus = args.bonus and require('src/story/BonusMatch').new(self, args.bonus) or nil

    -- FRAGMENTOS DEL ESPEJO (modo historia, src/story/Shards.lua): los jefes de este nivel sueltan los suyos
    -- al caer. `shards.final` = es el último (el del jefe Espejo): al recogerlo el nivel acaba SIN tocar la meta.
    -- (también sin fragmentos por ganar si el nivel termina solo al vencer al jefe: `auto`, repetir un jefe ya vencido)
    self.shards = (args.shards and (#(args.shards.ids or {}) > 0 or args.shards.auto)) and require('src/story/Shards').drops(self, args.shards) or nil
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

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))
    -- Dentro de una zona de jefe la cámara se queda fija en ella
    local zx, zy = BossZones.cameraTarget(self.level, self.player.x, self.player.y)
    if zx then targetX, targetY = zx, zy end
    if scrolling then
        targetX = AutoScroll.cameraX(self.level)
    end

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
             shards = self.shardArgs, outro = self.outroArgs, taken = self.takenArg }
end

-- Lo que se lleva del nivel (para la nota del modo historia: src/story/Score.lua)
function AdventureState:result()
    local st = self.stats
    local taken = {}
    for i in pairs(self.takenNow or {}) do taken[#taken + 1] = i end
    return { score = self.score, time = self.levelTime, lives = self.player.lives, width = self.level.tileW, par = self.level.parTime, taken = taken,
             kills = st.kills, killable = st.killable, stars = st.stars, starsTotal = st.starsTotal,
             deaths = st.deaths, hits = st.hits }
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
    local before = sh.got
    sh:update(dt)
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
    if self.shards then self.shards:collectAll() end       -- (un fragmento suelto sin recoger no se pierde)
    self.player:grantInvulnerability(AdventureState.WIN_TIME + 2)
    Sound.stopMusic()
    Sound.play('fanfare')
    self.bossBanner = { text = L('hud.level_clear'), t = 0, col = { 1, 0.9, 0.25 } }
end

-- ── Update ────────────────────────────────────────────────────────────────────
function AdventureState:update(dt)
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
            local rx, ry = AutoScroll.respawnPoint(self.level)
            if not rx then rx, ry = BossZones.respawnPoint(self.level, self.player) end   -- suelo roto en la zona
            if rx then self.player.spawnX, self.player.spawnY = rx, ry end
            self.player:respawn()
            self.camFrozen    = false
            self.respawning   = false
            self.respawnTimer = 0
        end
        return
    end

    -- ── Forzar recálculo del Canvas si la pantalla rota / cambia proporción ──
    self.sceneCanvas = require('src/fx/SceneCanvas').get()   -- (el mismo; otro si la pantalla cambió)

    -- ── Controles táctiles (móvil): cruceta + salto, ver src/ui/TouchControls ──
    if not self.demo then TouchControls.update(not self.dead, self.level.dark) end

    -- (en la escena final no hay pausa, ni ya ganado: salir en la celebración perdía el nivel)
    if not self.demo and Input.pressed('pause') and not (self.runOut and self.runOut.active) and not self.won and not self.endingT then
        gStateMachine:push('pause')
        return
    end

    -- ── Cuenta atrás del principio: el mundo congelado y sin control ──────────
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
        self.levelTime = math.min(self.levelTime + dt, 600)
    end

    -- Límite de 10 minutos: muerte instantánea con todas las vidas
    if self.levelTime >= 600 and not self.player.dying then
        self.player.lives = 1   -- die() restará 1, quedando en 0 → game over
        self.player:die(nil, true)
    end

    self.level:update(dt)
    self.level:updateFoliage(dt)
    self.level:updateHiddenBlocks(dt, self.player.dying and {} or { self.player:getOuterBounds() })
    Floods.advance(self.level, dt)                 -- inundaciones: el agua sube y baja
    Floods.updateFx(self.level, dt)
    -- Zonas de puntos: estar dentro da puntos cada cierto tiempo
    local inZones = self.bonus and self.bonus:players() or (self.player.dying and {} or { self.player })
    if self.bonus and self.bonus.over then inZones = {} end
    -- (cuánto tiempo pasa el jugador DENTRO de una zona: los resultados del bonus)
    if #inZones > 0 and not self.player.dying then
        for _, a in ipairs(self.level.pointAreas or {}) do
            if PointAreas.isActive(self.level, a) and PointAreas.inside(a, self.player.x, self.player.y) then
                self.stats.zoneT = self.stats.zoneT + dt; break
            end
        end
    end
    PointAreas.update(self.level, dt, inZones, function(pa, pts)
        if self.bonus and not self.bonus:award(pa, pts) then
            Particles.emit('points', pa.x, pa.y)
            return
        end
        self.score = self.score + pts
        self:spawnPopup('+' .. pts, pa.x, pa.y - 60)
        Sound.play('pointGain'); Particles.emit('points', pa.x, pa.y)
    end)
    self.level.solidBodies = Entities.solidBodies(self.enemies)   -- jefes sólidos
    -- (la escena final de una carrera en la historia: al acabar, el nivel termina sin meta y enlaza con el siguiente)
    if self.runOut and self.runOut:update(dt) then
        local r = self:result()
        r.outro = true
        self.finished = true
        if self.onFinish then self.onFinish(r) else gStateMachine:change(self.returnTo) end
        return
    end
    local scripted = self.runOut and self.runOut:input()
    if self.demo then
        self.demo.step(dt, self.level)                                -- (el bot del fondo de los menús)
    elseif scripted then                                                  -- (sin control: corre y salta solo)
        local real = Input
        Input = scripted
        local ok, err = pcall(self.player.update, self.player, dt, self.level)
        Input = real
        if not ok then error(err, 0) end
    else
        self.player:update(dt, self.level)
    end
    if self.bonus then
        self.level.players = { self.player }                          -- (los enemigos ven a todos)
        for _, b in ipairs(self.bonus.bots) do self.level.players[#self.level.players + 1] = b.pa end
        self.bonus:update(dt)
        if self.bonus.sent then return end
    end

    -- Actualizar enemigos y limpiar los que ya murieron. Sus sonidos se
    -- atenúan según lo lejos que estén del jugador (Sound.setEmitter).
    Sound.setListener(self.player.x, self.player.y)
    self.level.liveEntities = self.enemies     -- obstáculos entre entidades
    for i = #self.enemies, 1, -1 do
        local g = self.enemies[i]
        Sound.setEmitter(g.x, g.y)
        g:update(Difficulty.dt(g, dt), self.level)          -- (su ritmo: la dificultad)
        Sound.clearEmitter()
        -- (los súbditos de reserva de un jefe se quedan: el jefe los reutiliza)
        if not g.alive and not g.summonOf then
            table.remove(self.enemies, i)
        end
    end

    -- Colisiones jugador ↔ entidades
    self:checkEnemyCollisions()
    if not (self.demo and self.demo.noBossCtl) then self:updateBoss(dt) end      -- (los créditos: jefes sin pelea de verdad)
    for _, ev in ipairs(AutoScroll.update(self.level, dt)) do
        if ev.type == 'scroll_start' and not ev.quiet then self.bossBanner = { text = L('hud.go'), t = 0, col = { 0.4, 1, 0.5 } } end
    end
    Particles.update(dt)
    self:checkVentOxyCollisions()
    self:updatePopups(dt)

    self:updateShards(dt)
    self:updateCamera(dt)
    if self.rec then self.rec:step(dt, self) end

    -- (golpes recibidos: cada vez que baja la vida sin morir)
    if self.player.hp < self.prevHp and not self.player.dying then self.stats.hits = self.stats.hits + (self.prevHp - self.player.hp) end
    self.prevHp = self.player.hp

    -- ── META: tocarla termina el nivel ────────────────────────────────────────
    if not self.won and not self.endingT and not self.player.dying then
        local ob = self.player:getOuterBounds()
        if self.level:triggerInBox(ob.x, ob.y, ob.w, ob.h, 'finish') then self:win() end
    end

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
    if z then
        local y = 18
        y = BossHud.drawZone(z, y, math.min(1, self.bossFightT / 0.8))
        local p = self.player
        BossHud.drawPlayers({ { name = L('hud.you'), color = { 1, 0.95, 0.2 }, hp = p.hp, hpMax = p.hpMax,
                                key = p, dead = p.dying } }, 20, 110)
    elseif self.player.hp < self.player.hpMax and not self.player.dying then
        -- Fuera de una pelea: la vida solo si le falta algo
        local p = self.player
        BossHud.drawPlayers({ { name = L('hud.you'), color = { 1, 0.95, 0.2 }, hp = p.hp, hpMax = p.hpMax, key = p } }, 20, 110)
    end
    if self.bossBanner then
        BossHud.drawBanner(self.bossBanner.text, self.bossBanner.t, 2.2, self.bossBanner.col)
    end
    BossHud.drawScrollCountdown(self.level.autoScroll)
    if self.startCd or self.startGoT then BossHud.drawStartCountdown(self.startCd or -self.startGoT) end
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

function AdventureState:_renderScene()

    -- ── Aislar transformaciones para el Canvas (Evita zoom doble y cortes) ──
    love.graphics.push()
    love.graphics.origin()
    -- El recorte de lovesize (bandas negras) está en píxeles de la PANTALLA:
    -- dentro del canvas de la escena (tamaño lógico) recortaba otra zona y, con
    -- la ventana a otro tamaño que 1280x720, el juego salía cortado/descuadrado
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()

    -- ── Paso 1: renderizar toda la escena al canvas ───────────────────────────
    local outCanvas = love.graphics.getCanvas()          -- (a dónde va luego: la pantalla, o el lienzo de quien la dibuja)
    love.graphics.setCanvas(self.sceneCanvas)
    if self.demo and self.demo.noSky then
        love.graphics.clear(0, 0, 0, 0)                    -- (sin cielo: se ve lo que haya detrás; los créditos)
    else
        love.graphics.clear(0, 0, 0, 1)
        Sky.punch = Darkness.active(self.level) and not self.level.dark      -- (lo incandescente del fondo: ver Sky.lua)
        Sky.render(self.level, self.camX, self.camY)          -- (cielo y fondo con paralaje)
        Sky.punch = false
    end

    Entities.renderBack(self.enemies, self.camX, self.camY)  -- (lo que las entidades dibujan detrás de los bloques)
    self.level:render(self.camX, self.camY)
    IceDrips.render(self.level, self.camX, self.camY)      -- (gotas del hielo: solo dibujo)
    require('src/fx/CaveAmbience').tick(self.level)        -- (cuevas: gotas lejanas, rumor... solo sonido)
    LavaFx.render(self.level, self.camX, self.camY)        -- (burbujas de la lava: solo dibujo)
    self.level:renderVents(self.camX, self.camY)
    self.level:renderFoliageBack(self.camX, self.camY)

    require('src/fx/Silhouette').level = self.level      -- (filo de los enemigos oscuros en lo oscuro: `darkEdge`)
    -- Renderizar enemigos (entre tiles y jugador)
    for _, g in ipairs(self.enemies) do
        if g.alive and not g.renderFront then (g.renderLive or g.render)(g, self.camX, self.camY) end      -- (reservas: no)
    end

    PlayerAdventure.lightLevel = self.level          -- (en lo oscuro, filo blanco: cada monstruo según SU sitio)
    if self.bonus then self.bonus:render(self.camX, self.camY) end
    self.player:render(self.camX, self.camY)
    PlayerAdventure.lightLevel = nil
    PointAreas.drawProgress(self.level, self.player, self.player.x - self.camX, self.player.y - self.camY)
    Particles.render(self.camX, self.camY)

    -- Entidades en un plano por delante del jugador (renderFront: pez globo)
    for _, g in ipairs(self.enemies) do
        if g.alive and g.renderFront then (g.renderLive or g.render)(g, self.camX, self.camY) end
    end

    -- Decoraciones (por encima de enemigos y player)
    self.level:renderFoliage(self.camX, self.camY)

    -- Burbujas de agua y vent (por encima de todo menos agua)
    self.level:renderBubbles(self.camX, self.camY)
    Snowfall.render(self.level, self.camX, self.camY)      -- (nieve cayendo: solo dibujo)

    love.graphics.setCanvas(outCanvas)
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()

    -- ── Paso 2: volver a pantalla y aplicar efecto agua ───────────────────────
    love.graphics.setColor(1, 1, 1, 1)

    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- A oscuras: solo se ve lo que alumbra la linterna; encima, los puntos luminosos
    -- (y la luz ambiente de cada nivel: atardecer, noche, cueva en penumbra — src/fx/Darkness.lua)
    if Darkness.active(self.level) then
        local p = self.player
        Darkness.render(self.level, self.camX, self.camY,
                        { { x = p.x, y = p.y, facing = p.facing, on = p.lightOn and not p.dying } }, self.enemies, self.sceneCanvas)
        Darkness.renderGlow(self.level, self.enemies, self.camX, self.camY)
    end

    -- Fragmentos del espejo que han soltado los jefes (brillan: encima de la oscuridad)
    if self.shards then self.shards:render(self.camX, self.camY) end

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
    BossHud.drawCinema(self.level)        -- (entrada de un jefe: franjas de cine, bajo el HUD)

    -- (todo el HUD se desvanece durante la entrada de un jefe: BossHud.fadeHud)
    BossHud.fadeHud(function()
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

    -- Helper: imprime texto con borde negro de 1px
    local function printOutlined(text, x, y, r, g, b, a)
        love.graphics.setColor(0, 0, 0, (a or 1) * 0.75)
        love.graphics.print(text, x + 2, y + 2)
        love.graphics.setColor(r, g, b, a or 1)
        love.graphics.print(text, x, y)
    end

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
    if self.level.dark then LightHud.draw(self.player, WINDOW_W - 206, 76) end      -- (bajo las vidas)
    self:renderBossHud()
    if self.bonus then self.bonus:renderHud() end
    self.player:renderAirBar()
    self.player:renderDrownCountdown(self.player.x - self.camX, self.player.y - self.camY)
    self:renderPopups()
    end)

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

    -- Botón de pausa (ratón y táctil)
    if CornerButtons.hitPause(tx, ty) then
        Input.VirtualPad._pressedThisFrame['pause'] = true
        return
    end
end

return AdventureState