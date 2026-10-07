-- src/states/online/OnlineAdventureHud.lua
-- PARTE de src/states/online/OnlineAdventureState.lua: el HUD, los popups de puntos y las pantallas de pausa y de espectador.
-- La carga OnlineAdventureState.lua con require(...)(OnlineAdventureState, P): añade sus funciones a la tabla OnlineAdventureState. P = lo que
-- antes eran locales del archivo y comparten las partes.
local L = require 'src/core/Lang'
local NC                   = require 'src/network/NetworkClient'
local PixelIcons           = require 'src/ui/PixelIcons'
local CornerButtons        = require 'src/ui/CornerButtons'
local BossHud              = require 'src/ui/BossHud'
local TouchControls        = require 'src/ui/TouchControls'
local LightHud             = require 'src/ui/LightHud'

return function(OnlineAdventureState, P)
local TICK_DT, POPUP_LIFE, POPUP_RISE, POPUP_BOUNCE_T, SPEC_OPTS, drawPixelButton = P.TICK_DT, P.POPUP_LIFE, P.POPUP_RISE, P.POPUP_BOUNCE_T, P.SPEC_OPTS, P.drawPixelButton

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

-- ── HUD ───────────────────────────────────────────────────────────────────────
-- Assets
local imgIcon = nil
local ICON_SCALE  = 4
local AIR_BAR_W   = 160
local AIR_BAR_H   = 12

local function loadAssets()
    if imgIcon then return end
    imgIcon = love.graphics.newImage('assets/images/player/icon.png')
end


function OnlineAdventureState:_renderHUD()
    if self.level and self.level.dark and self.localPaInit and not self.ownData.isSpectator then
        LightHud.draw(self.localPa, WINDOW_W - 206, 76)             -- (bajo las vidas)
    end
    -- Antena de conexión: abajo a la izquierda; con los controles táctiles a la
    -- vista, abajo en el CENTRO (a los lados van la cruceta y el salto, y
    -- arriba el HUD)
    if self.pingIcon then
        if TouchControls.visible() then
            self.pingIcon:draw(math.floor(WINDOW_W / 2 - self.pingIcon:width() / 2), WINDOW_H - 14)
        else
            self.pingIcon:draw(16, WINDOW_H - 14)
        end
    end
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
        local lx, ly = sx+iconW+gap, sy+iconH/2-FONT_BIG:getHeight()/2
        -- SIEMPRE blanco con sombra negra, como el resto del HUD (en negro no se leía en niveles oscuros)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.print(label, lx + 3, ly + 3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, lx, ly)

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
            self.predictor.corrections, self.predictor.lastError), 14, WINDOW_H-64)   -- (encima de la antena)
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

-- En píxeles de pantalla, tras lovesize (game.lua): controles táctiles
function OnlineAdventureState:drawScreen()
    if TouchControls.visible() and not self.showPause and not self.showGameOver
       and not (self.ownData and self.ownData.isSpectator) then
        TouchControls.draw(nil, nil, BossHud.hudAlpha())
    end
end

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

P.loadAssets = loadAssets
end
