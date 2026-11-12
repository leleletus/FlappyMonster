-- src/world/entities/types/bosses/SnowbossRender.lua
-- El DIBUJO de la Gran Bola de Nieve (snowboss.lua): cuerpo por fase, bolas, olas, carámbanos, lago, muerte y editor.
-- La carga snowboss.lua con require(...)(Snow, P): añade sus funciones a la misma tabla. P = lo que antes eran locales del
-- archivo compartidos (docs/architecture/project-structure.md, «Split files»).
return function(Snow, P)
local CRACK_T, FROZEN_T, ICE_GROW, ICE_LEN, ICE_R, ICE_SHAKE = P.CRACK_T, P.FROZEN_T, P.ICE_GROW, P.ICE_LEN, P.ICE_R, P.ICE_SHAKE
local IC_FALL, IC_GROW, IC_READY, IC_SHAKE, ROLL_IN, S = P.IC_FALL, P.IC_GROW, P.IC_READY, P.IC_SHAKE, P.ROLL_IN, P.S
local SC, SHOCK_LIFE, SHOCK_SPD, SHOOT_GAP, SHOOT_WIND, SIDES = P.SC, P.SHOCK_LIFE, P.SHOCK_SPD, P.SHOOT_GAP, P.SHOOT_WIND, P.SIDES
local SPIT_AT, SPIT_WIND, SPLAT_AT, T, WINDUP_T = P.SPIT_AT, P.SPIT_WIND, P.SPLAT_AT, P.T, P.WINDUP_T

-- ── Dibujo ────────────────────────────────────────────────────────────────────
local Particles
local function emit(kind, x, y, o)
    Particles = Particles or require 'src/fx/Particles'
    Particles.emit(kind, x, y, o)
end

-- Fila de arriba (arte) de un cuadro del cuerpo: el sudor y las estrellas de mareo se
-- apoyan en la cabeza también cuando está aplastada (se mide de la imagen del cuadro: solo dibujo)
local tops, datas = {}, {}
local function topRow(f)
    local key = f.path .. ':' .. f.x .. ':' .. f.y
    if tops[key] == nil then
        tops[key] = 1
        if datas[f.path] == nil then
            local ok, data = pcall(love.image.newImageData, f.path)
            datas[f.path] = ok and data or false
        end
        local data = datas[f.path]
        if data then
            for y = 0, f.h - 1 do
                local found = false
                for x = f.x, f.x + f.w - 1 do
                    local _, _, _, a = data:getPixel(x, f.y + y)
                    if a > 0 then found = true; break end
                end
                if found then tops[key] = y; break end
            end
        end
    end
    return tops[key]
end

-- Cuadro del cuerpo (1-12) o, rodando, de la tira de rodar
-- QUÉ ANIMACIÓN toca y en qué paso: 'body' | 'roll', el clip y el paso
function Snow:pose()
    local st, t = self.state, self.deadTimer or 0
    local angry = (self.phase or 1) >= 2
    local C = self:art()
    if st == 'roll' or st == 'slide' or st == 'dying_flee' or (st == 'intro' and t < ROLL_IN) then
        -- (rodando: la vuelta entera de la animación repartida en un giro de la bola; huyendo, ya sin enfado)
        local r = 7 * self.sc
        local ang = -(self.x / r)
        local c = C((angry and st ~= 'dying_flee') and 'roll_angry' or 'roll_happy')
        return 'roll', c, c:atProgress((ang / (2 * math.pi)) % 1)
    end
    local function B(name, time, plain)
        local c = (not plain and angry and C('angry_' .. name)) or C(name)
        return 'body', c, c:at(time or t)
    end
    if st == 'dizzy' or st == 'soaked' or st == 'dying_dizzy' then return B('dizzy', t, true) end
    if st == 'dying_crack' then return B('dying', t, true) end
    if self.inv > 0 and not self.ghost and self.state == 'recover' then return B('hurt') end
    if st == 'land' or st == 'slam_land' or st == 'leap_land' then return B('land') end
    if st == 'windup' or st == 'leap_wind' then return B('windup') end
    if st == 'leap' then return B('leap') end
    if st == 'shoot' then
        local ph = self.phase or 1
        local u = t - SHOOT_WIND[ph]
        if u < 0 then return B('shoot_wind') end
        -- (una pasada de `shoot` por disparo: boca abierta y vuelta)
        local c = (angry and C('angry_shoot')) or C('shoot')
        return 'body', c, c:atFraction((u % SHOOT_GAP[ph]) / SHOOT_GAP[ph])
    end
    if st == 'phase_up' then return B('phase_up', t, true) end
    if st == 'slam_hold' then return B('slam_hold') end
    if st == 'rest' then return B('rest') end
    if st == 'intro' or st == 'ready' then
        if t >= 2.2 and t < 2.45 then return B('intro_flinch', t - 2.2, true) end
        if t >= 2.6 and t < SPIT_WIND then return B('intro_chatter', t - 2.6, true) end
        if t >= SPIT_WIND and t < SPIT_AT then return B('intro_inhale', t - SPIT_WIND, true) end      -- coge aire
        if t >= SPIT_AT and t < SPLAT_AT + 0.15 then return B('intro_spit', t - SPIT_AT, true) end   -- boca abierta
        return B('idle', t, true)
    end
    return B('idle')
end

function Snow:drawBody(camX, camY, alpha)
    local kind, clip, step = self:pose()
    local fr = clip:rec(step)                              -- (el cuadro que toca)
    local sc = self.sc
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    if st == 'intro' and t < ROLL_IN then sc = math.max(2, math.floor(self.sc * self:introScale(t) + 0.5)) end
    local fx = math.floor(self.x - camX)
    local fy = math.floor(self.y - camY + (self.outerH / 2))         -- pies
    if st == 'intro' and t < ROLL_IN then fy = math.floor(self.y - camY + 6.5 * SC[1] * self:introScale(t)) end
    -- temblor (carga, fase, grietas) y saltitos de risa
    local sh = 0
    if st == 'windup' then sh = 2 + math.floor(t / WINDUP_T[self.phase or 1] * 3) end
    if st == 'leap_wind' then sh = 1 + math.floor(math.min(1, t / self:leapWind()) * 2) end
    if st == 'phase_up' or st == 'dying_crack' then sh = 3 end
    if st == 'dying_dizzy' then                               -- vencida: se bambolea mareada y tiembla
        sh = 2
        fx = fx + math.floor(math.sin(now * 7) * sc * 0.6 + 0.5)
    end
    if (self.phase or 1) == 3 and st == 'idle' then sh = 1 end
    if st == 'intro' and t >= SPIT_WIND and t < SPIT_AT then                    -- coge aire: tiembla cada vez más
        sh = 1 + math.floor((t - SPIT_WIND) / (SPIT_AT - SPIT_WIND) * 2.99)
    end
    if st == 'intro' and t >= SPIT_AT and t < SPIT_AT + 0.1 then fy = fy - sc end  -- (retroceso al escupir)
    if st == 'soaked' then fy = fy + math.floor(math.sin(now * 5) * sc * 0.5) end  -- (flota en el agua)
    if sh > 0 then fx = fx + math.floor((math.random() * 2 - 1) * sh + 0.5); fy = fy + math.floor((math.random() * 2 - 1) * sh * 0.5 + 0.5) end
    local r, g, bl = 1, 1, 1
    if st == 'soaked' then                                   -- empapada: más oscura y azulada, gotea
        r, g, bl = 0.72, 0.8, 0.95
        if (self.lastDrip or 0) + 0.07 < now then
            self.lastDrip = now
            emit('snow_drip', self.x + (math.random() - 0.5) * self.outerW * 0.8, self.y - self.outerH * 0.2)
        end
    elseif (self.frostT or 0) > 0 and st ~= 'frozen' then    -- escarchada: azulada, latiendo
        local k = 0.5 + 0.5 * math.sin(now * 9)
        r, g = 0.62 + 0.15 * k, 0.82 + 0.1 * k
        if (self.lastFrost or 0) + 0.12 < now then
            self.lastFrost = now
            emit('cryo_mist', self.x + (math.random() - 0.5) * self.outerW, self.y + (math.random() - 0.5) * self.outerH)
        end
    end
    if self:flashRed() then r, g, bl = 1, 0.35, 0.35 end
    local dizzy = st == 'dizzy' or st == 'dying_dizzy'
    local starsAt = function(part)
        BossFx = BossFx or require 'src/fx/BossFx'
        BossFx.stars(fx, fy - (13 - topRow(fr)) * sc, 8 * sc, 2 * sc, math.max(3, math.floor(sc * 0.6)), alpha, part)
    end
    if dizzy then starsAt('back') end                                  -- (las estrellitas de detrás, antes del cuerpo)
    love.graphics.setColor(r, g, bl, alpha)
    love.graphics.draw(fr.image, fr.quad, fx, fy, 0, sc, sc, 8, 15)
    -- Grietas (fase 3; muriendo cada vez más)
    local ck = nil
    if st == 'dying_crack' then ck = math.min(3, 1 + math.floor(t / (CRACK_T / 3)))
    elseif (self.phase or 1) >= 3 then ck = 2 end
    if ck then
        -- (una tira por cuadro: siguen el aplastamiento y giran al rodar)
        local cr = S((kind == 'roll' and 'cracks_roll_' or 'cracks_body_') .. ck):rec(fr.data.ck or 1)
        love.graphics.setColor(r, g, bl, alpha)
        love.graphics.draw(cr.image, cr.quad, fx, fy, 0, sc, sc, 8, 15)
    end
    -- Sudor (fase 3 / mareada)
    if ((self.phase or 1) >= 3 or st == 'dizzy') and kind ~= 'roll' and st ~= 'frozen' and st ~= 'soaked' then
        local k = (now * 1.4) % 1
        love.graphics.setColor(1, 1, 1, alpha * (1 - k))
        S('sweat'):play(now, fx + 6 * sc, fy - (15 - topRow(fr)) * sc + k * 3 * sc, 0, sc * 0.5, sc * 0.5)
    end
    -- Mareada (también vencida, antes de huir): el corro de estrellitas de todos los jefes; aquí, las de delante
    if dizzy then starsAt('front') end
    -- Empapada: gotas azules girando
    if st == 'soaked' then
        for i = 0, 2 do
            local a = now * 5 + i * (math.pi * 2 / 3)
            local x = math.floor(fx + math.cos(a) * 7 * sc)
            local y = math.floor(fy - 15 * sc + math.sin(a) * 2 * sc)
            love.graphics.setColor(0.55, 0.8, 1, alpha)
            love.graphics.rectangle('fill', x - 6, y - 2, 12, 4)
            love.graphics.rectangle('fill', x - 2, y - 6, 4, 12)
        end
    end
    return fx, fy, sc
end

-- Sombra en (x, gy) de ancho w: más oscura cuanto más cerca (k 0..1)
local Edge = require 'src/fx/Edge'
local function shadow(x, gy, w, k, camX, camY)
    love.graphics.setColor(0, 0, 0, 0.18 + 0.22 * k)
    love.graphics.rectangle('fill', math.floor(x - camX - w / 2), math.floor(gy - camY - 6), math.floor(w), 6)
end

function Snow:render(camX, camY)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    -- Retumbo rodando (bucle solo de dibujo; cada cliente lo oye a su distancia)
    if not EDITOR_VIEW and Sound.loop then
        Sound.loop('snowRoll', st == 'roll' or st == 'slide', self.x, self.y)
    end
    local alpha = self:ghostAlpha()
    if st == 'dormant' then self:renderSplat(camX, camY, now); return end

    -- Sombra donde va a caer (saltando / gran golpe): sobre la superficie real de debajo
    if st == 'hop' or st == 'slam_up' or st == 'slam_hold' or st == 'slam_fall' then
        local gy = self:groundBelow(self.x, self:feetY())
        local k = math.max(0.2, 1 - (gy - self:feetY()) / (6 * T))
        Edge.direct(shadow, self.x, gy, self.outerW * (0.5 + 0.35 * k), k, camX, camY)      -- (sin borde: src/fx/Edge.lua)
    end
    -- Salto a plataforma: MARCA donde va a caer (parpadea, se cierra al acercarse)
    if st == 'leap_wind' or st == 'leap' then
        local k = (st == 'leap') and 1 or math.min(1, t / self:leapWind())
        local w = math.floor(self.outerW * (1.3 - 0.4 * k))
        local x0 = math.floor(self.landX - camX - w / 2)
        local y0 = math.floor(self.landY - camY - 8)
        local blink = (math.floor(now * 10) % 2 == 0) and 1 or 0.6
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle('fill', x0 + 2, y0 + 2, w, 6)
        love.graphics.setColor(0.55, 0.85, 1, 0.8 * blink)
        love.graphics.rectangle('fill', x0, y0, w, 6)
        love.graphics.rectangle('fill', x0, y0 - 14, 6, 14)
        love.graphics.rectangle('fill', x0 + w - 6, y0 - 14, 6, 14)
    end

    if st == 'dying_flee' then alpha = (alpha or 1) * self:fleeAlpha(t) end   -- (solo si se atasca a la vista: Boss.fleeOver)
    do
        local _, _, sc = self:drawBody(camX, camY, alpha)
        if st == 'frozen' then
            IceEncase = IceEncase or require 'src/fx/IceEncase'
            local b = self:getOuterBounds()
            IceEncase.draw(b.x - camX, b.y - camY - sc, b.w, b.h + sc, now, (self.frozenFor or FROZEN_T) - t)
        end
        -- Polvo de nieve rodando / deslizando
        if (st == 'roll' or st == 'slide' or st == 'dying_flee') and (self.lastTrail or 0) + 0.04 < now then
            self.lastTrail = now
            emit('snow_trail', self.x - (self.dir or 1) * self.outerW * 0.3, self:feetY() - 4)
        end
        -- Aliento helado al cambiar de fase
        if st == 'phase_up' and (self.lastBreath or 0) + 0.05 < now then
            self.lastBreath = now
            emit('cryo_puff', self.x, self.y + self.outerH * 0.1, { nx = (self.facing or 1), ny = 0 })
        end
    end

    -- Bolas
    for _, b in ipairs(self.proj or {}) do
        love.graphics.setColor(1, 1, 1, 1)
        self:art()('ball'):play(now, math.floor(b.x - camX), math.floor(b.y - camY), 0, 4, 4)
    end
    -- Carámbanos del techo: crecen, tiemblan (sombra donde caerán) y caen
    for _, c in ipairs(self.icicles or {}) do
        local cx = math.floor(c.x - camX)
        if c.st == IC_GROW or c.st == IC_READY or c.st == IC_SHAKE then
            local k = (c.st == IC_GROW) and math.min(1, c.t / ICE_GROW) or 1
            if c.st == IC_SHAKE then
                cx = cx + math.floor(math.sin(now * 70) * 3)
                c.gy = c.gy or self:groundBelow(c.x, c.top + ICE_LEN + 8)
                local u = math.min(1, c.t / ICE_SHAKE)
                Edge.direct(shadow, c.x, c.gy, 14 + 30 * u, u, camX, camY)
            else
                c.gy = nil
            end
            love.graphics.setColor(1, 1, 1, 1)
            -- (crece hacia abajo desde el techo)
            S('icicle'):playPx(now, cx, math.floor(c.top - camY), 0, 4, 4 * k, 4, 0)
        elseif c.st == IC_FALL then
            love.graphics.setColor(1, 1, 1, 1)
            S('icicle'):playPx(now, cx, math.floor(c.y - camY), 0, 4, 4, 4, 0)
        end
    end
    -- Olas de nieve del gran golpe
    if (self.shockT or 99) < SHOCK_LIFE then
        local d = self.shockT * SHOCK_SPD
        local a = math.min(1, (SHOCK_LIFE - self.shockT) / 0.3)
        love.graphics.setColor(1, 1, 1, a)
        for _, s in ipairs(SIDES) do
            S('shock'):play(now, math.floor(self.shockX + s * d - camX), math.floor(self.shockY - camY - 16), 0, 4 * s, 4)
        end
    end
    self:renderSplat(camX, camY, now)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Primera superficie (bloque o plataforma) bajo (x, y) dentro de la zona (solo dibujo)
function Snow:groundBelow(x, y)
    local zy1 = select(4, self:zoneBounds())
    local level = self.levelRef
    if not level then return zy1 end
    for yy = math.floor(y), math.min(zy1 + 2 * T, level.tileH * T), 8 do
        if level:collisionAt(x, yy, true) then return math.floor(yy / 8) * 8 end
    end
    return zy1
end

-- Escupitajo de la entrada (solo dibujo, del reloj de la entrada: igual online):
-- la bola sale de la boca, vuela hacia la cámara creciendo y girando (con estela) y al
-- llegar se estampa en la pantalla (destello + mancha que chorrea y cae, 1.6 s)
function Snow:renderSplat(camX, camY, now)
    local t = self.deadTimer or 0
    if self.state == 'dormant' then self.splatAt = nil end
    if self.state == 'intro' and t >= SPIT_AT and t < SPLAT_AT then
        local mx, my = self:mouthPos()
        local x0, y0 = mx - camX, my - camY
        local x1, y1 = WINDOW_W / 2, WINDOW_H * 0.46
        for i = 3, 0, -1 do                                        -- (estela: copias de antes)
            local u = math.max(0, (t - i * 0.025 - SPIT_AT) / (SPLAT_AT - SPIT_AT))
            local e = u * u                                        -- (acelera hacia la cámara)
            local x = x0 + (x1 - x0) * e
            local y = y0 + (y1 - y0) * e - math.sin(u * math.pi) * 70
            local k = math.floor(4 + 26 * e * e + 0.5)            -- 8 px → ~240 px
            love.graphics.setColor(1, 1, 1, (i == 0) and 1 or (0.35 - i * 0.08))
            self:art()('ball'):play(love.timer.getTime(), math.floor(x), math.floor(y), u * 7, k, k)
        end
    end
    if self.state == 'intro' and t >= SPLAT_AT and not self.splatAt then self.splatAt = now end
    local s = self.splatAt
    if not s then return end
    local u = now - s
    if u > 1.6 then return end
    if u < 0.09 then                                               -- destello del golpe
        love.graphics.setColor(1, 1, 1, require('src/fx/Flash').alpha(0.45 * (1 - u / 0.09)))   -- (sin destellos: suave)
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    local slide = math.max(0, u - 0.55) * 180
    local sc = (u < 0.06) and 14 or 12                             -- (aplasta un instante al chocar)
    love.graphics.setColor(1, 1, 1, math.min(1, (1.6 - u) / 0.4))
    S('splat'):play(u, math.floor(WINDOW_W / 2), math.floor(WINDOW_H * 0.46 + slide), 0, sc, sc)
end

-- Editor: cada carámbano (línea) y lo que alcanza la sacudida de un aterrizaje
function Snow.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx or type(props.icicles) ~= 'table' then return end
    love.graphics.setColor(0.6, 0.9, 1, 0.5)
    for _, p in ipairs(props.icicles) do
        local x = (p.col - 0.5) * ctx.t - ctx.camX
        local y = (p.row - 1) * ctx.t - ctx.camY
        love.graphics.rectangle('fill', math.floor(x - 2), math.floor(y), 4, ctx.t)
        love.graphics.rectangle('line', math.floor(x - ICE_R * ctx.t), math.floor(y), math.floor(2 * ICE_R * ctx.t), ctx.t)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

end
