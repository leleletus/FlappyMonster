-- src/player/PlayerAir.lua
-- PARTE de src/player/PlayerAdventure.lua: el aire bajo el agua — ahogarse, la cuenta atrás, las salpicaduras y la barra de aire.
-- La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P): añade sus funciones a la tabla PlayerAdventure. P = lo que
-- antes eran locales del archivo y comparten las partes.
local Difficulty = require 'src/core/Difficulty'

return function(PlayerAdventure, P)
local DROWN_TOTAL, DROWN_CHIME_INT, DROWN_CHIMES, DROWN_AUDIO_DUR, AIR_BAR_W, AIR_BAR_H = P.DROWN_TOTAL, P.DROWN_CHIME_INT, P.DROWN_CHIMES, P.DROWN_AUDIO_DUR, P.AIR_BAR_W, P.AIR_BAR_H

-- ── Ahogamiento ───────────────────────────────────────────────────────────────
-- La "cabeza" es la franja superior del 25% de la outerBounds.
-- Mientras esté sumergida avanza el temporizador; al salir → reset total.
function PlayerAdventure:updateDrowning(dt, level)
    if self.dying or self.immortal then return end

    local headX, headY = self:getHeadPoint()
    local liq = level:liquidAt(headX, headY)
    local headUnder = liq ~= nil and liq.drown

    -- ── Salió del agua: reset total ──────────────────────────────────────────
    if not headUnder then
        if self.drownPhase ~= 'none' then
            self.drownTimer  = 0
            self.drownChime  = 0
            self.drownAudT   = 0
            self.drownDead   = false
            if self.drownPhase == 'drowning' then
                -- Solo suena al tomar aire si drowning.ogg estaba sonando
                Sound.play('airGasp')
                Sound.stopTracked('drowning')
                Sound.playMusic('level')
            end
            self.drownPhase = 'none'
        end
        return
    end

    -- ── Cabeza bajo el agua ───────────────────────────────────────────────────
    if self.drownPhase == 'none' then
        self.drownPhase  = 'warning'
        self.airBarBobT  = 0
        self.airBarBobOn = true
    end

    if self.drownPhase == 'warning' then
        self.drownTimer = self.drownTimer + dt

        -- Chimes cada DROWN_CHIME_INT segundos (máx DROWN_CHIMES)
        local air = Difficulty.k('airTime')                 -- (la dificultad da más o menos aire)
        local needed = math.floor(self.drownTimer / (DROWN_CHIME_INT * air))
        while self.drownChime < needed and self.drownChime < DROWN_CHIMES do
            self.drownChime = self.drownChime + 1
            Sound.play('waterWarning')
        end

        -- A los 20 s arrancar drowning.ogg
        if self.drownTimer >= DROWN_TOTAL * air then
            self.drownPhase = 'drowning'
            self.drownAudT  = 0
            self.drownTimer = 0
            Sound.stopMusic()
            Sound.playTracked('drowning')
        end
        return
    end

    if self.drownPhase == 'drowning' then
        self.drownAudT = self.drownAudT + dt
        -- Matar cuando termina el audio (~12 s)
        if self.drownAudT >= DROWN_AUDIO_DUR then
            Sound.stopTracked('drowning')
            Sound.play('glugluglu')
            self:die(true)   -- true = muerte por ahogamiento, sin dies2
        end
        return
    end
end

-- ── Splash al entrar / salir del agua ────────────────────────────────────────
-- splashSt: 'out'      fuera del líquido
--           'wading'   pies dentro, la cabeza aún no se ha hundido
--           'under'    cabeza sumergida
--           'surfaced' sacó la cabeza (para respirar) pero sigue en el agua
-- Suena al tocar el agua con los pies, al SACAR LA CABEZA (no hace falta
-- salir del todo) y al volver a hundirla. Margen de unos píxeles y un
-- intervalo mínimo para que flotar en la superficie no dispare repeticiones.
local SPLASH_HYST = 5       -- px por encima/debajo de la superficie
local SPLASH_MIN  = 0.25    -- s entre dos splashes

local function playSplash(self, liq, which)
    if not liq or self.splashCD > 0 then return end
    local name = (which == 'in') and liq.splashIn or liq.splashOut
    if name then Sound.play(name); self.splashCD = SPLASH_MIN end
end

function PlayerAdventure:updateSplash(dt, level)
    self.splashCD = math.max(0, (self.splashCD or 0) - dt)
    local st = self.splashSt or 'out'
    if not self.inWater then
        if st == 'under' or st == 'wading' then playSplash(self, self.prevLiquid, 'out') end
        self.splashSt = 'out'
        return
    end
    local hx, hy = self:getHeadPoint()
    local headUnder = level:liquidAt(hx, hy - SPLASH_HYST) ~= nil   -- claramente bajo el agua
    local headOut   = level:liquidAt(hx, hy + SPLASH_HYST) == nil   -- claramente fuera
    if st == 'out' then
        playSplash(self, self.liquid, 'in')
        st = headUnder and 'under' or 'wading'
    elseif st == 'wading' then
        if headUnder then st = 'under' end
    elseif st == 'under' then
        if headOut then playSplash(self, self.liquid, 'out'); st = 'surfaced' end
    elseif st == 'surfaced' then
        if headUnder then playSplash(self, self.liquid, 'in'); st = 'under' end
    end
    self.splashSt = st
end

-- ── Cuenta regresiva de ahogamiento (estilo Sonic) ──────────────────────────
-- Mientras suena drowning.ogg, su duración se reparte en 6 tramos: 5,4,3,2,1,0.
local COUNTDOWN_FROM = 5

function PlayerAdventure:drownCountdown()
    if self.drownPhase ~= 'drowning' or self.dying then return nil end
    local step = DROWN_AUDIO_DUR / (COUNTDOWN_FROM + 1)
    local k    = math.floor(self.drownAudT / step)
    return math.max(0, COUNTDOWN_FROM - k), (self.drownAudT - k * step) / step
end

-- Número junto al jugador, en pantalla (sx, sy = centro del jugador en pantalla).
-- Solo lo ve el propio jugador (lo dibuja el HUD local).
function PlayerAdventure:renderDrownCountdown(sx, sy)
    local n, f = self:drownCountdown()
    if not n then return end
    local text = tostring(n)
    local pop  = 1 + 0.6 * math.max(0, 1 - f / 0.15)      -- salta al cambiar
    local x, y = math.floor(sx + 46), math.floor(sy - 70)
    love.graphics.setFont(FONT_BIG)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(pop * 1.5, pop * 1.5)
    local w, h = FONT_BIG:getWidth(text), FONT_BIG:getHeight()
    love.graphics.setColor(0, 0, 0, 1)
    for _, o in ipairs({ {-2,0},{2,0},{0,-2},{0,2},{-2,-2},{2,2},{-2,2},{2,-2} }) do
        love.graphics.print(text, -w / 2 + o[1], -h / 2 + o[2])
    end
    if n <= 1 then love.graphics.setColor(1, 0.3, 0.3, 1) else love.graphics.setColor(1, 1, 1, 1) end
    love.graphics.print(text, -w / 2, -h / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Animación barra de aire ──────────────────────────────────────────────────
function PlayerAdventure:updateAirBarAnim(dt)
    local targetAlpha = (self.drownPhase ~= 'none') and 1 or 0
    local lerpSpeed   = (targetAlpha > self.airBarAlpha) and 6 or 3
    self.airBarAlpha  = self.airBarAlpha + (targetAlpha - self.airBarAlpha) * lerpSpeed * dt
    if self.airBarAlpha < 0.005 then self.airBarAlpha = 0 end

    -- Bob de entrada
    if self.airBarBobOn then
        self.airBarBobT = self.airBarBobT + dt
        if self.airBarBobT > 0.5 then
            self.airBarBobOn = false
            self.airBarBobT  = 0
        end
    end

    -- Agitación durante drowning: crece con drownAudT
    if self.drownPhase == 'drowning' then
        local t         = self.drownAudT / DROWN_AUDIO_DUR  -- 0→1
        local intensity = 1 + t * 6     -- 1→7 px
        local freq      = 18 + t * 34   -- 18→52 rad/s
        self.airBarShakeX = math.sin(love.timer.getTime() * freq) * intensity
    else
        self.airBarShakeX = 0
    end
end

-- ── HUD: barra de aire pixel-art ─────────────────────────────────────────────
function PlayerAdventure:renderAirBar()
    if self.airBarAlpha <= 0 then return end

    local a = self.airBarAlpha

    local progress
    if self.drownPhase == 'warning' then
        progress = 1 - (self.drownTimer / DROWN_TOTAL)
    else
        progress = 0
    end

    -- Bob de entrada: offset Y amortiguado
    local bobY = 0
    if self.airBarBobOn then
        local t   = self.airBarBobT
        local env = 1 - (t / 0.5)
        bobY = math.sin(t * math.pi * 3.5) * 12 * env
    end

    local bx = math.floor((WINDOW_W - AIR_BAR_W) / 2) + math.floor(self.airBarShakeX)
    local by = math.floor(WINDOW_H - 60 + bobY)

    -- Sombra pixel-art
    love.graphics.setColor(0, 0, 0, 0.75 * a)
    love.graphics.rectangle('fill', bx + 2, by + 2, AIR_BAR_W, AIR_BAR_H)

    -- Fondo
    love.graphics.setColor(0.10, 0.10, 0.15, a)
    love.graphics.rectangle('fill', bx, by, AIR_BAR_W, AIR_BAR_H)

    -- Fill de aire
    local fillW = math.floor(AIR_BAR_W * progress)
    if fillW > 0 then
        local pulse = 1.0
        if progress < 0.25 then
            pulse = 0.4 + math.abs(math.sin(love.timer.getTime() * 7)) * 0.6
        end
        local r = math.min(1, 2 - progress * 2)
        local g = math.min(1, progress * 2) * 0.55
        local b = math.max(0, progress)
        love.graphics.setColor(r * pulse, g * pulse, b * pulse, a)
        love.graphics.rectangle('fill', bx, by, fillW, AIR_BAR_H)
        love.graphics.setColor(1, 1, 1, 0.20 * a)
        love.graphics.rectangle('fill', bx, by, fillW, 2)
    end

    -- Parpadeo rojo durante drowning
    if self.drownPhase == 'drowning' then
        local pulse = 0.35 + math.abs(math.sin(love.timer.getTime() * 7)) * 0.65
        love.graphics.setColor(0.9, 0.05, 0.05, pulse * a)
        love.graphics.rectangle('fill', bx, by, AIR_BAR_W, AIR_BAR_H)
    end

    -- Borde
    love.graphics.setColor(0.55, 0.55, 0.65, a)
    love.graphics.rectangle('line', bx, by, AIR_BAR_W, AIR_BAR_H)

    -- Icono "~"
    love.graphics.setFont(FONT_SMALL)
    love.graphics.setColor(0.4, 0.7, 1, a * 0.9)
    love.graphics.print('~', bx - 14, by + 1)

    love.graphics.setColor(1, 1, 1, 1)
end
function PlayerAdventure:renderDebug(camX, camY)
    local ob=self:getOuterBounds()
    love.graphics.setColor(0,1,0,0.4)
    love.graphics.rectangle('line',ob.x-camX,ob.y-camY,ob.w,ob.h)
    local ib=self:getInnerBounds()
    love.graphics.setColor(1,0,0,0.4)
    love.graphics.rectangle('line',ib.x-camX,ib.y-camY,ib.w,ib.h)
    -- Punto de boca (hitbox de ahogamiento) — círculo cyan
    local hx, hy = self:getHeadPoint()
    love.graphics.setColor(0.2, 0.8, 1, 0.9)
    love.graphics.circle('fill', hx-camX, hy-camY, 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle('line', hx-camX, hy-camY, 3)
end
end
