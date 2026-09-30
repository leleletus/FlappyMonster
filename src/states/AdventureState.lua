local TouchControls = require 'src/ui/TouchControls'
local CornerButtons = require 'src/ui/CornerButtons'
local L = require 'src/Lang'
-- src/states/AdventureState.lua
local BaseState       = require 'src/BaseState'
local Level           = require 'src/world/Level'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local PlayRecorder    = require 'src/PlayRecorder'
local Entities        = require 'src/world/Entities'
local Entity          = require 'src/world/entities/Entity'
local Particles       = require 'src/fx/Particles'
local BossZones       = require 'src/world/BossZones'
local BossHud         = require 'src/ui/BossHud'
local AutoScroll      = require 'src/world/AutoScroll'
local Floods          = require 'src/world/Floods'
local PointAreas      = require 'src/world/PointAreas'

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

-- ── Helper: botón cuadrado pixel art ─────────────────────────────────────────
local function drawPixelButton(label, cx, y, w, h, selected, alpha)
    if selected then
        love.graphics.setColor(0.18, 0.18, 0.18, alpha)
        love.graphics.rectangle('fill', cx - w/2 + 4, y + 4, w, h)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle('fill', cx - w/2, y, w, h)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    else
        love.graphics.setColor(1, 1, 1, alpha * 0.45)
        love.graphics.rectangle('line', cx - w/2, y, w, h)
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.printf(label, cx - w/2, y + h/2 - FONT_MED:getHeight()/2, w, 'center')
    end
end

local imgBg = nil
local BG_SCALE    = 15
local BG_PARALLAX = 0.3

local function loadBgAsset()
    if imgBg then return end
    imgBg = love.graphics.newImage('assets/images/level/Background.png')
end

-- ── Enter ─────────────────────────────────────────────────────────────────────
-- Al salir del nivel: cerrar la grabación (si la hay)
function AdventureState:exit()
    require('src/ui/View').unlock()
    -- Música y sonidos de partida a cero (también la pista de jefe): al volver
    -- a entrar (reintentar tras perder todas las vidas, desde el editor...)
    -- todo empieza como la primera vez, la música desde el principio
    Sound.leaveMatch()
    if self.rec then self.rec:finish(self); self.rec = nil end
end

function AdventureState:enter(args)
    require('src/ui/View').lockGameplay()      -- (todos ven la misma zona del nivel)
    loadHudAssets()
    loadBgAsset()
    args = args or {}
    self.levelPath = args.level or 'assets/levels/nivel01.json'
    self.returnTo  = args.returnTo or 'main_menu'   -- a dónde se sale (Juego libre → free_play)

    self.level  = Level.new(self.levelPath)
    local sx, sy = self.level:getSpawnPx()
    self.player = PlayerAdventure:new(sx, sy)
    self.level.players = { self.player }       -- para trampas/entidades que "ven" al jugador
    -- Grabación de la partida para analizarla (FM_RECORD=1; ver src/PlayRecorder.lua)
    if PlayRecorder.enabled() then self.rec = PlayRecorder.new(self.levelPath, self.level.name) end

    -- Efectos del jugador (ground pound, bloques rotos...)
    Particles.clear()
    Particles.setLevel(self.level)                 -- (las partículas físicas chocan con él)
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

    -- Instanciar entidades (enemigos, NPCs) desde el catálogo
    self.enemies = {}
    for _, placement in ipairs(self.level.entities) do
        local e = Entities.create(placement)
        if e then table.insert(self.enemies, e) end
    end

    -- Zonas de jefe: la pelea empieza al entrar (un solo jugador)
    self.bossCtl    = BossZones.newController(self.level, self.enemies)
    self.bossBanner = nil       -- { text, t, col }
    self.bossFightT = 0

    self.camX = 0
    self.camY = 0
    self.camFrozen = false
    self.bgScrollX = 0
    self.bgScrollY = 0

    self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)

    self.dead         = false
    self.deadTimer    = 0
    self.timeScale    = 1.0
    self.selectedOpt  = 1
    self.respawning   = false
    self.respawnTimer = 0

    Sound.setLevelMusic(nil)
    Sound.setBaseLevelMusic(self.level.music)          -- la música elegida en el editor
    Sound.playMusic('level')

    self.score      = 0
    self.levelTime  = 0   -- segundos transcurridos
    self.popups     = {}  -- lista de textos flotantes de puntos
end

function AdventureState:pause()  end
-- Al volver de la pausa la música sigue donde estaba (no se reinicia)
function AdventureState:resume()
    if not Sound.resumeAll() then Sound.playMusic('level') end
end

function AdventureState:pauseGame()
    if not self.dead then gStateMachine:push('pause') end
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
    -- Con cámara automática la cámara ES el nivel: sigue moviéndose aunque se muera
    local scrolling = self.level.autoScroll and self.level.autoScroll.state ~= 'stop'
    if self.camFrozen and not scrolling then return end

    local targetX = self.player.x - WINDOW_W / 2
    local targetY = self.player.y - WINDOW_H / 2

    targetX = math.max(0, math.min(self.level.widthPx  - WINDOW_W, targetX))
    targetY = math.max(0, math.min(self.level.heightPx - WINDOW_H, targetY))
    -- Dentro de una zona de jefe la cámara se queda fija en ella
    local zx, zy = BossZones.cameraTarget(self.level, self.player.x, self.player.y)
    if zx then targetX, targetY = zx, zy end
    if scrolling then
        targetX = AutoScroll.cameraX(self.level)
    end

    local prevCamX = self.camX
    local prevCamY = self.camY
    self.camX = self.camX + (targetX - self.camX) * CAM_LERP * dt
    self.camY = self.camY + (targetY - self.camY) * CAM_LERP * dt
    -- Cámara automática: sin suavizado horizontal (la ventana manda)
    if scrolling then self.camX = targetX end

    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE
    self.bgScrollX = self.bgScrollX + (self.camX - prevCamX) * BG_PARALLAX
    self.bgScrollY = self.bgScrollY + (self.camY - prevCamY) * BG_PARALLAX
    if self.bgScrollX >= bgW then self.bgScrollX = self.bgScrollX - bgW end
    if self.bgScrollY >= bgH then self.bgScrollY = self.bgScrollY - bgH end
end

-- ── Colisión jugador ↔ entidades ──────────────────────────────────────────────
-- Las reglas (pinchos, pisotón, coleccionables, checkpoints, ground pound)
-- viven en entities/Interactions.lua; aquí solo los efectos del modo solo.
function AdventureState:checkEnemyCollisions()
    local player = self.player
    Entities.interactions.run(player, self.enemies, {
        stomp = function(g, pts)
            self.score = self.score + (pts or 0)
            local popY = g.flipped and (g.y + g.outerH / 2) or (g.y - g.outerH / 2)
            self:spawnPopup('+' .. (pts or 0) .. '!', g.x, popY)
        end,
        pickup = function(e, pk)
            if pk.score then
                self.score = self.score + pk.score
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
                if self.selectedOpt == 1 then
                    gStateMachine:change('adventure', { level = self.levelPath, returnTo = self.returnTo })
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
    if self.sceneCanvas:getWidth() ~= WINDOW_W or self.sceneCanvas:getHeight() ~= WINDOW_H then
        self.sceneCanvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    end

    -- ── Controles táctiles (móvil): cruceta + salto, ver src/ui/TouchControls ──
    TouchControls.update(not self.dead)

    if Input.pressed('pause') then
        gStateMachine:push('pause')
        return
    end

    -- ── Lógica normal ─────────────────────────────────────────────────────────
    -- Cap del tiempo: congelar en 600 al morir por tiempo
    if not self.player.dying then
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
    PointAreas.update(self.level, dt, self.player.dying and {} or { self.player }, function(pa, pts)
        self.score = self.score + pts
        self:spawnPopup('+' .. pts, pa.x, pa.y - 60)
        Sound.play('pointGain'); Particles.emit('points', pa.x, pa.y)
    end)
    self.level.solidBodies = Entities.solidBodies(self.enemies)   -- jefes sólidos
    self.player:update(dt, self.level)

    -- Actualizar enemigos y limpiar los que ya murieron. Sus sonidos se
    -- atenúan según lo lejos que estén del jugador (Sound.setEmitter).
    Sound.setListener(self.player.x, self.player.y)
    self.level.liveEntities = self.enemies     -- obstáculos entre entidades
    for i = #self.enemies, 1, -1 do
        local g = self.enemies[i]
        Sound.setEmitter(g.x, g.y)
        g:update(dt, self.level)
        Sound.clearEmitter()
        -- (los súbditos de reserva de un jefe se quedan: el jefe los reutiliza)
        if not g.alive and not g.summonOf then
            table.remove(self.enemies, i)
        end
    end

    -- Colisiones jugador ↔ entidades
    self:checkEnemyCollisions()
    self:updateBoss(dt)
    for _, ev in ipairs(AutoScroll.update(self.level, dt)) do
        if ev.type == 'scroll_start' then self.bossBanner = { text = L('hud.go'), t = 0, col = { 0.4, 1, 0.5 } } end
    end
    Particles.update(dt)
    self:checkVentOxyCollisions()
    self:updatePopups(dt)

    self:updateCamera(dt)
    if self.rec then self.rec:step(dt, self) end

    -- ── Detectar muerte del jugador ───────────────────────────────────────────
    if self.player.dying and not self.player.alive then
        self.player.lives = self.player.lives - 1

        if self.player.lives <= 0 then
            self.dead        = true
            self.deadTimer   = 0
            self.selectedOpt = 1
            self.timeScale   = 1.0
        else
            self.respawning   = true
            self.respawnTimer = 0
            self.camFrozen    = true
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
        for _, b in ipairs(z.bosses) do
            if b.alive then
                BossHud.drawBoss(b, y, math.min(1, self.bossFightT / 0.8)); y = y + 72
            end
        end
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
end

-- ── HUD: vidas ────────────────────────────────────────────────────────────────
local function renderLivesHud(player)
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

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(label, sx + iconW + gap, sy + iconH/2 - FONT_BIG:getHeight()/2)
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
end

function AdventureState:_renderScene()
    local bgW = imgBg:getWidth()  * BG_SCALE
    local bgH = imgBg:getHeight() * BG_SCALE

    -- ── Aislar transformaciones para el Canvas (Evita zoom doble y cortes) ──
    love.graphics.push()
    love.graphics.origin()
    -- El recorte de lovesize (bandas negras) está en píxeles de la PANTALLA:
    -- dentro del canvas de la escena (tamaño lógico) recortaba otra zona y, con
    -- la ventana a otro tamaño que 1280x720, el juego salía cortado/descuadrado
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()

    -- ── Paso 1: renderizar toda la escena al canvas ───────────────────────────
    love.graphics.setCanvas(self.sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setColor(1, 1, 1, 1)
    local startX = -(math.floor(self.bgScrollX) % bgW)
    local startY = -(math.floor(self.bgScrollY) % bgH)
    if startX > 0 then startX = startX - bgW end
    if startY > 0 then startY = startY - bgH end
    local x = startX
    while x < WINDOW_W do
        local y = startY
        while y < WINDOW_H do
            love.graphics.draw(imgBg, x, y, 0, BG_SCALE, BG_SCALE)
            y = y + bgH
        end
        x = x + bgW
    end

    self.level:render(self.camX, self.camY)
    self.level:renderVents(self.camX, self.camY)
    self.level:renderFoliageBack(self.camX, self.camY)

    -- Renderizar enemigos (entre tiles y jugador)
    for _, g in ipairs(self.enemies) do
        if g.alive and not g.renderFront then g:render(self.camX, self.camY) end      -- (reservas: no)
    end

    self.player:render(self.camX, self.camY)
    PointAreas.drawProgress(self.level, self.player, self.player.x - self.camX, self.player.y - self.camY)
    Particles.render(self.camX, self.camY)

    -- Entidades en un plano por delante del jugador (renderFront: pez globo)
    for _, g in ipairs(self.enemies) do
        if g.alive and g.renderFront then g:render(self.camX, self.camY) end
    end

    -- Decoraciones (por encima de enemigos y player)
    self.level:renderFoliage(self.camX, self.camY)

    -- Burbujas de agua y vent (por encima de todo menos agua)
    self.level:renderBubbles(self.camX, self.camY)

    love.graphics.setCanvas()
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()

    -- ── Paso 2: volver a pantalla y aplicar efecto agua ───────────────────────
    love.graphics.setColor(1, 1, 1, 1)

    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- ── Debug hitboxes (F1) ───────────────────────────────────────────────────
    if DEBUG_HITBOX then
        self.player:renderDebug(self.camX, self.camY)

        -- Hitboxes de enemigos
        for _, g in ipairs(self.enemies) do
            if g.alive then g:renderDebug(self.camX, self.camY) end
        end

        -- Hitboxes reales del nivel (pinchos, contacto, formas de colisión)
        self.level:renderDebug(self.camX, self.camY)

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.print("DEBUG HITBOX [F1]", 20, WINDOW_H - 30)
    end

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

    renderLivesHud(self.player)
    self:renderBossHud()
    self.player:renderAirBar()
    self.player:renderDrownCountdown(self.player.x - self.camX, self.player.y - self.camY)
    self:renderPopups()
    end)

    -- ── Game over overlay ─────────────────────────────────────────────────────
    if self.dead and self.deadTimer > 0.4 then
        local oa = math.min(1, (self.deadTimer - 0.4) / 0.4)

        love.graphics.setColor(0, 0, 0, 0.60 * oa)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

        love.graphics.setFont(FONT_BIG)
        love.graphics.setColor(COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], oa)
        love.graphics.printf(L('hud.game_over'), 0, WINDOW_H/2 - 110, WINDOW_W, 'center')

        if self.deadTimer > 0.8 then
            local ba = math.min(1, (self.deadTimer - 0.8) / 0.3)
            love.graphics.setFont(FONT_MED)
            local btnW   = 260
            local btnH   = 48
            local gap    = 18
            local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
            local startY = WINDOW_H/2 - totalH/2 + 30
            local cx     = WINDOW_W / 2
            for i, opt in ipairs(GAMEOVER_OPTIONS) do
                local by = startY + (i - 1) * (btnH + gap)
                drawPixelButton(L(opt), cx, by, btnW, btnH, i == self.selectedOpt, ba)
            end
        end
    end

    if not self.dead then BossHud.fadeHud(function() CornerButtons.drawPause(self.pauseHover) end) end

    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(COLOR_WHITE)
end

-- Hover del mouse: mueve la selección real (solo en game over)
function AdventureState:mousemoved(tx, ty)
    self.pauseHover = not self.dead and CornerButtons.hitPause(tx, ty)
    if not self.dead or self.deadTimer <= 0.8 then return end
    local btnW   = 260
    local btnH   = 48
    local gap    = 18
    local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS - 1) * gap
    local startY = WINDOW_H/2 - totalH/2 + 30
    local cx     = WINDOW_W / 2
    for i = 1, #GAMEOVER_OPTIONS do
        local by = startY + (i-1) * (btnH + gap)
        local bx = cx - btnW/2
        if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
            if self.selectedOpt ~= i then self.selectedOpt = i; Sound.play('select') end
            return
        end
    end
end

-- En píxeles de pantalla, tras lovesize (game.lua): controles táctiles
function AdventureState:drawScreen()
    if TouchControls.visible() and not self.dead then TouchControls.draw(nil, nil, BossHud.hudAlpha()) end
end

-- Táctil Switch: tap en botón de game over
function AdventureState:touchpressed(id, tx, ty, dx, dy, pressure)
    if self.dead then
        if self.deadTimer <= 0.8 then return end
        local btnW   = 260
        local btnH   = 48
        local gap    = 18
        local totalH = #GAMEOVER_OPTIONS * btnH + (#GAMEOVER_OPTIONS-1) * gap
        local startY = WINDOW_H/2 - totalH/2 + 30
        local cx     = WINDOW_W / 2
        for i, _ in ipairs(GAMEOVER_OPTIONS) do
            local by = startY + (i-1) * (btnH + gap)
            local bx = cx - btnW/2
            if tx >= bx-10 and tx <= bx+btnW+10 and ty >= by-5 and ty <= by+btnH+5 then
                Sound.play('select')
                if i == 1 then
                    gStateMachine:change('adventure', { level = self.levelPath, returnTo = self.returnTo })
                else
                    gStateMachine:change(self.returnTo)
                end
                return
            end
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