-- src/states/online/OnlineAdventureRender.lua
-- PARTE de src/states/online/OnlineAdventureState.lua: el dibujo de la partida (escena, jugadores, entidades, oscuridad, hitboxes).
-- La carga OnlineAdventureState.lua con require(...)(OnlineAdventureState, P): añade sus funciones a la tabla OnlineAdventureState. P = lo que
-- antes eran locales del archivo y comparten las partes.
local IceDrips = require 'src/fx/IceDrips'
local LavaFx   = require 'src/fx/LavaFx'
local Sky      = require 'src/fx/Sky'
local Snowfall = require 'src/fx/Snowfall'
local L = require 'src/core/Lang'
local PlayerAdventure      = require 'src/player/PlayerAdventure'
local PixelIcons           = require 'src/ui/PixelIcons'
local Particles            = require 'src/fx/Particles'
local CornerButtons        = require 'src/ui/CornerButtons'
local Modes                = require 'src/world/modes/Modes'
local BossZones            = require 'src/world/systems/BossZones'
local BossHud              = require 'src/ui/BossHud'
local PointAreas           = require 'src/world/systems/PointAreas'
local Darkness             = require 'src/fx/Darkness'

return function(OnlineAdventureState, P)
local INTRO_DUR, BANNER_DUR = P.INTRO_DUR, P.BANNER_DUR

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

    love.graphics.push()
    love.graphics.origin()
    -- El recorte de lovesize (bandas negras) está en píxeles de la PANTALLA:
    -- dentro del canvas de la escena (tamaño lógico) recortaba otra zona y, con
    -- la ventana a otro tamaño que 1280x720, el juego salía cortado/descuadrado
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    love.graphics.setCanvas(self.sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- Cielo y fondo con paralaje (bioma del nivel; src/fx/Sky.lua)
    Sky.punch = Darkness.active(self.level) and not self.level.dark      -- (lo incandescente del fondo: ver Sky.lua)
    Sky.render(self.level, self.camX, self.camY)
    Sky.punch = false

    -- Nivel
    self.level:render(self.camX, self.camY)
    IceDrips.render(self.level, self.camX, self.camY)      -- (gotas del hielo: solo dibujo)
    require('src/fx/CaveAmbience').tick(self.level)        -- (cuevas: gotas lejanas, rumor... solo sonido)
    LavaFx.render(self.level, self.camX, self.camY)        -- (burbujas de la lava: solo dibujo)
    self.level:renderVents(self.camX, self.camY)
    self.level:renderFoliageBack(self.camX, self.camY)

    -- Enemigos (estado controlado por el servidor)
    require('src/fx/Silhouette').level = self.level      -- (filo de los enemigos oscuros en lo oscuro: `darkEdge`)
    for i, er in pairs(self.enemyRenderers) do
        if er.alive and not er.renderFront then
            er:render(self.camX, self.camY)
        end
    end

    -- (en lo oscuro —a oscuras, noche, cuevas— los monstruos llevan su fondo blanco: src/fx/Silhouette.lua)
    PlayerAdventure.lightLevel = self.level
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
        if DEBUG_HITBOX then
            -- (F1 online: también las ENTIDADES — con su estado del snapshot — y los demás jugadores; antes solo
            -- salían el jugador propio y el nivel)
            love.graphics.setLineWidth(2)
            pa:renderDebug(self.camX, self.camY)
            for _, er in pairs(self.enemyRenderers) do
                if er.alive and er.renderDebug then
                    -- (protegido: un tipo cuyas cajas pidan algo que solo existe al simular no tumba la partida)
                    local ok, err = pcall(er.renderDebug, er, self.camX, self.camY)
                    if not ok and not self._dbgErr then self._dbgErr = true; print('[hitbox] ' .. tostring(err)) end
                end
            end
            for _, rp in pairs(self.remotePlayers) do
                if rp.renderX and not rp.hidden then
                    local b = PlayerAdventure.outerBoxAt(rp.renderX, rp.renderY)
                    love.graphics.setColor(0, 1, 0, 0.4)
                    love.graphics.rectangle('line', b.x - self.camX, b.y - self.camY, b.w, b.h)
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
            self.level:renderDebug(self.camX, self.camY)
            love.graphics.setLineWidth(1)
        end
        pa.x, pa.y = sx, sy
    end
    PlayerAdventure.lightLevel = nil

    -- Entidades en un plano por delante de los jugadores (renderFront: pez globo)
    for _, er in pairs(self.enemyRenderers) do
        if er.alive and er.renderFront then er:render(self.camX, self.camY) end
    end

    -- Foliaje y burbujas
    self.level:renderFoliage(self.camX, self.camY)
    self.level:renderBubbles(self.camX, self.camY)
    Snowfall.render(self.level, self.camX, self.camY)      -- (nieve cayendo: solo dibujo)

    love.graphics.setCanvas()
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()

    -- Efecto agua
    love.graphics.setColor(1, 1, 1, 1)
    self.level:renderWaterEffect(self.camX, self.camY, self.sceneCanvas)

    -- A oscuras: las linternas de todos los jugadores; encima, los puntos luminosos
    -- (y la luz ambiente de cada nivel: atardecer, noche, cueva en penumbra — src/fx/Darkness.lua)
    if Darkness.active(self.level) then
        local src = {}
        for _, rp in pairs(self.remotePlayers) do
            if rp.visible and not rp.dying then src[#src + 1] = { x = rp.x, y = rp.y, facing = rp.facing, on = rp.lightOn } end
        end
        if self.localPaInit and not self.ownData.isSpectator then
            local pa = self.localPa
            src[#src + 1] = { x = self.renderX, y = self.renderY, facing = pa.facing, on = pa.lightOn and not pa.dying }
        end
        Darkness.render(self.level, self.camX, self.camY, src, self.enemyRenderers, self.sceneCanvas)
        Darkness.renderGlow(self.level, self.enemyRenderers, self.camX, self.camY)
    end

    -- HUD (antes, las franjas de cine de la entrada de un jefe: el HUD va encima)
    BossHud.drawCinema(self.level)
    -- (todo el HUD se desvanece durante la entrada de un jefe: BossHud.fadeHud)
    BossHud.fadeHud(function()
        self:_renderHUD()
        if not self.showGameOver and not self.showPause and not self.specOverlay then
            CornerButtons.drawPause(self.pauseHover)
        end
        self:_renderBossHUD()
    end)

    -- Overlays
    if self.showPause then self:_renderPauseOverlay() end
    BossHud.fadeHud(function() self:_renderModeHUD() end)
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
end
