-- src/world/entities/types/bosses/groovecrab_stage.lua
-- PARTE de types/bosses/groovecrab.lua (EL GROOVE): el DIBUJO — él (postura y vaivén de las pinzas; noqueado, sin
-- gafas y con ojos en X), sus notas y la dorada, las ondas, la pista de baile, los platos de DJ y el bajón de los
-- bafles, y el ESCENARIO de detrás (renderBack: el público de cangrejos y
-- Gummies en silueta con barras de luz, los bafles que bombean, el ecualizador, la bola de discoteca y sus láseres;
-- delante, los focos de colores y el destello al empezar cada frase). Pedido del usuario (0.5.47): "una mezcla de
-- rave nocturna y concierto en la playa, de atardecer" — que se vea que es un jefe MUSICAL.
-- Todo sale de state + deadTimer + songT + lo que llega por red: igual online. Solo dibujo (sin efectos).
-- La carga groovecrab.lua con require(...)(GC, P): añade sus funciones a la tabla GC.
local BossFx = require 'src/fx/BossFx'
local BossWaves = require 'src/world/entities/base/BossWaves'
local SpriteStrip = require 'src/fx/SpriteStrip'

return function(GC, P)
local T, MS, FW, FH, S16, BAR, BEAT = P.T, P.MS, P.FW, P.FH, P.S16, P.BAR, P.BEAT
local REGROW_T, BOOM_LEN, FLOOR_WARN = P.REGROW_T, P.BOOM_LEN, P.FLOOR_WARN
local DECK_T, DECK_W, DECK_H, DECK_IN, DROP_FX = P.DECK_T, P.DECK_W, P.DECK_H, P.DECK_IN, P.DROP_FX

-- ── Arte ──
local DIR = 'assets/images/bosses/groovecrab/'
local art
local imgs = {}
local function img(path)                                -- (sprites sueltos del juego: el público)
    if not imgs[path] then
        local ok, im = pcall(love.graphics.newImage, path)
        if ok and im.setFilter then im:setFilter('nearest', 'nearest') end
        imgs[path] = ok and im or false
    end
    return imgs[path] or nil
end
local SPECIES = { 'crabby', 'crabby_river', 'crabby_cave', 'crabby_fortress', 'crabby_ice', 'crabby_lava' }
local function crabImg(sp, f) return img('assets/images/enemies/' .. SPECIES[sp] .. '/crab' .. f .. '.png') end
local function gummyImg(f) return img('assets/images/enemies/gummy/gummy' .. f .. '.png') end
-- (el público VARIADO del escenario grande: los Gummies de cada isla)
local MIX = { 'gummy', 'gummy_cave', 'gummy_fortress', 'gummy_ice', 'gummy_magma' }
local function mixImg(i, f) return img('assets/images/enemies/' .. MIX[i] .. '/' .. 'gummy' .. f .. '.png') end

function GC.loadAssets()
    if art or not (love and love.graphics) then return end
    art = { body = SpriteStrip.load(DIR .. 'body-Sheet.png', FW), big = SpriteStrip.load(DIR .. 'bigclaw-Sheet.png', 12),
            small = SpriteStrip.load(DIR .. 'claw-Sheet.png', 7), tramp = SpriteStrip.load(DIR .. 'tramp.png', 16),
            note = SpriteStrip.load(DIR .. 'note-Sheet.png', 9), gold = SpriteStrip.load(DIR .. 'gold-Sheet.png', 9),
            wave = SpriteStrip.load(DIR .. 'wave-Sheet.png', 12), speaker = SpriteStrip.load(DIR .. 'speaker-Sheet.png', 18),
            ball = SpriteStrip.load(DIR .. 'discoball-Sheet.png', 12), stick = SpriteStrip.load(DIR .. 'glowstick-Sheet.png', 3),
            panel = SpriteStrip.load(DIR .. 'panel-Sheet.png', 32), ko = SpriteStrip.load(DIR .. 'ko-Sheet.png', FW),
            glasses = SpriteStrip.load(DIR .. 'glasses.png', 14), deck = SpriteStrip.load(DIR .. 'deck-Sheet.png', 24),
            led = SpriteStrip.load(DIR .. 'led-Sheet.png', 3), arrow = SpriteStrip.load(DIR .. 'arrow.png', 7) }
end
local function quad(s, i) return s.images and s.images[i] or s.image, s.quads[i] end

local BEAT_COLS = { { 1, 0.31, 0.64 }, { 0.25, 0.85, 1 }, { 1, 0.82, 0.25 }, { 0.36, 0.94, 0.48 } }
-- (los colores de las NOTAS normales —note-Sheet.png—: sin amarillo, que es el de la dorada; el usuario, 0.5.52)
local NOTE_COLS = { { 1, 0.31, 0.64 }, { 0.25, 0.85, 1 }, { 0.71, 0.42, 1 }, { 0.36, 0.94, 0.48 } }
local function beatOf(self)
    if self.eventRef and self.eventRef.beatPos then return self.eventRef:beatPos() end   -- (el evento: su música)
    local s = self.songT or 0; return math.floor(s / BEAT), (s / BEAT) % 1
end
-- (`props.bigStage`: el ESCENARIO GRANDE del final del Mega Mashup — lo pone este Groove, esté peleando o al fondo —)
local function bigUp(self) return self.props.bigStage and self.zone ~= nil and (self.zone.state == 'fight' or self.zone.state == 'intro') end
local function live(self)
    if bigUp(self) then return not EDITOR_VIEW end
    return self:isActive() and not EDITOR_VIEW and self.zone ~= nil and self.zone.state == 'fight'
end
-- EL ESCENARIO APARECE EN LA ENTRADA (el usuario: que no salga de la nada al empezar la pelea): s de entrada (nil =
-- no se ve: antes de la entrada; 99 = ya está todo, en la pelea y mientras cae vencido). Y AL REVENTAR SE RECOGE igual
-- que salió, al revés (el usuario, 0.5.56: "desaparecía de golpe"): la entrada hacia atrás en P.STAGE_OUT s
local STAGE_IN = 3.3                                    -- (lo que tarda en salir todo: los láseres, a 3.2)
local function stageT(self)
    if EDITOR_VIEW then return nil end
    if bigUp(self) then return 99 end
    local st = self.state
    if st == 'intro' then return self.deadTimer or 0 end
    if st == 'ready' then return self:introTime() + (self.deadTimer or 0) end
    if st == 'dying_burst' then return math.max(0, STAGE_IN * (1 - (self.deadTimer or 0) / P.STAGE_OUT)) end
    if live(self) or self:isDying() then return 99 end
    return nil
end
-- (0..1 de lo que ya salió de algo que aparece entre a y b s de la entrada; suave)
local function appear(t, a, b)
    local u = math.max(0, math.min(1, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)
end
-- (¿baila ya? con la música: en la pelea y vencido; en la entrada, quieto)
local function dancing(self) return live(self) or self:isDying() end

-- ── La postura según el estado y el compás ──
-- { pata (cuadro), sx, sy, trampolín (0..1.3), pinza grande (cuadro, dx, dy), pinza pequeña (cuadro, dy), temblor x }
function GC:pose()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local nb, beat = beatOf(self)
    local on = beat < 0.25
    local p = { leg = 1, sx = 1, sy = 1, tk = 1, bf = 1, bdx = 0, bdy = 0, sf = 1, sdy = 0, jx = 0, flip = 1 }
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it < P.LAND_AT then p.sy, p.sx, p.tk = 1.1, 0.92, 1.2
        elseif it < P.LAND_AT + 0.25 then local k = 1 - (it - P.LAND_AT) / 0.25; p.sy, p.sx = 1 - 0.2 * k, 1 + 0.15 * k
        else
            local snap = (it >= P.SNAP1 and it < P.SNAP1 + 0.1) or (it >= P.SNAP2 and it < P.SNAP2 + 0.1)
            p.bf, p.bdy = snap and 2 or 1, (it >= P.SNAP1 and it < P.BOING) and -5 or 0
            if it >= P.BOING then p.tk = 1 + 0.35 * math.max(0, math.sin((it - P.BOING) * 18) * (1 - (it - P.BOING) / 0.8)) end
        end
    elseif st == 'groove' then
        p.leg = (nb % 2) * 2 + 1
        p.sy, p.sx, p.tk = on and 0.9 or 1, on and 1.06 or 1, on and 0.85 or 1
        p.bf, p.bdy, p.sdy = on and 2 or 1, (nb % 2 == 1) and -2 or 0, (nb % 2 == 1) and 0 or -1
        if self._walking then p.leg = math.floor(now * 8) % 3 + 1 end
        -- PASOS DE BAILE (0.5.51, el usuario: más variedad visual), cada 2 compases uno: el meneo de siempre; las
        -- pinzas arriba por turnos; MEDIA VUELTA en cada tiempo (se voltea: sin girar, pixel art); y sentadilla con
        -- vaivén. Solo dibujo, del reloj de la canción: igual online
        local move = math.floor((self.songT or 0) / (2 * BAR)) % 4
        if move == 1 then
            p.bdy, p.sdy = (nb % 2 == 0) and -6 or 1, (nb % 2 == 1) and -5 or 1
            p.bf, p.sf = (nb % 2 == 0) and 1 or 2, (nb % 2 == 1) and 1 or 2
        elseif move == 2 then
            p.flip = (nb % 2 == 0) and 1 or -1
        elseif move == 3 then
            p.sy, p.sx = on and 0.8 or 0.95, on and 1.12 or 1.02
            p.jx = ((math.floor((self.songT or 0) / (BEAT / 2)) % 2 == 0) and -1 or 1) * MS
            p.bdy, p.sdy = on and 1 or -3, on and 1 or -3
        end
    elseif st == 'snap' then
        p.bdy, p.bdx = -5, -2
        local step = ((self.songT or 0) % BAR) / S16
        p.bf = (step % 1 < 0.8 and math.floor(step) % 2 == 0 and on) and 2 or 1
        p.leg = (nb % 2) * 2 + 1
    elseif st == 'crouch' then
        local k = math.min(1, t / 0.25)
        p.sy, p.sx, p.tk = 1 - 0.15 * k, 1 + 0.1 * k, 0.7
        p.jx = (math.floor(now * 30) % 2 == 0) and 1 or 0
    elseif st == 'hop' then
        p.sy, p.sx, p.tk, p.leg, p.bdy, p.sdy = 1.1, 0.92, 1.2, 2, 2, 2
    elseif st == 'stunned' or st == 'dying_daze' then
        -- NOQUEADO (el usuario, 0.5.48: que se note MUY atontado): sin trampolín (le reventó), le vuelan las gafas
        -- (drawGlasses), ojos en X que giran, la lengua fuera, despatarrado; el golpe lo APLASTA y se recupera
        -- muelleando, y luego se tambalea de lado a lado (desplazado, nunca girado: pixel art), las pinzas por el suelo
        local w = math.sin(now * 4.5)
        local hit = math.max(0, 1 - t / 0.45)
        local bump = hit * hit * math.cos(t * 22)
        p.ko, p.tk = true, (st == 'dying_daze') and 0.6 or 0
        p.sy, p.sx = 1 - 0.28 * bump + 0.04 * math.abs(w), 1 + 0.22 * bump - 0.03 * math.abs(w)
        p.bdy, p.sdy, p.bdx = 0, 1, -1.5 + w * 0.6                       -- (las pinzas en el suelo, sin meterse)
        p.jx = math.floor(w * 7 + 0.5) + ((t < 0.3) and ((math.floor(now * 40) % 2 == 0) and 3 or -3) or 0)
    elseif st == 'regrow' then
        -- le CRECE otro trampolín de la cabeza: sale encogido y se estira con un muelleo
        local u = math.min(1, t / REGROW_T)
        p.tk = u * (1 + 0.35 * math.sin(u * 14) * (1 - u))
        p.ko = t < 0.35                                                 -- (hasta que le vuelven las gafas: drawGlasses)
        p.sy, p.sx = 1 + 0.05 * math.sin(u * 20) * (1 - u), 1
        p.bdy, p.sdy = -3 * math.sin(u * math.pi), -2 * math.sin(u * math.pi)
    end
    if st == 'dying_daze' then
        -- (a punto de reventar: se va HINCHANDO y tiembla cada vez más)
        local u = math.min(1, t / P.DAZE_T)
        p.sx, p.sy = p.sx * (1 + 0.16 * u * u), p.sy * (1 + 0.12 * u * u)
        p.jx = p.jx + ((math.floor(now * 50) % 2 == 0) and 1 or -1) * math.floor(1 + u * 5)
    end
    -- EL VAIVÉN de las pinzas (como los Mega Crabbies, nunca tiesas): desvío en px de arte que se suma a la postura
    -- (sin girarlas: el pixel art no se rota). Andando se mecen a contrapié; agachado, recogidas y temblando; en el
    -- aire, agitándose; con el trampolín creciendo, se estiran; aturdido, cuelgan
    local sw = function(amp, speed, ph) return math.sin(now * speed + (ph or 0)) * amp end
    local it = (st == 'ready') and (self:introTime() + t) or t
    if st == 'groove' and self._walking then
        p.bdy, p.bdx, p.sdy = p.bdy + sw(1.5, 12), p.bdx + sw(1, 12, 1.5), p.sdy + sw(1.5, 12, math.pi)
    elseif st == 'groove' then
        p.bdy, p.sdy = p.bdy + sw(0.5, 4), p.sdy + sw(0.5, 4, 2)
    elseif st == 'snap' then
        p.bdx = p.bdx + ((p.bf == 2) and -1.2 or 0)
        p.sdy = p.sdy + sw(1, 10)
    elseif st == 'crouch' then
        p.bdx, p.bdy, p.sdy = p.bdx + 1.5 + sw(0.4, 40), p.bdy + 1, p.sdy + 1 + sw(0.4, 40, 1)
    elseif st == 'hop' or ((st == 'intro' or st == 'ready') and it < P.LAND_AT) then
        p.bdy, p.sdy, p.bdx = -3 + sw(1.5, 20), -2 + sw(1, 20, 1.3), p.bdx + sw(0.8, 20, 0.7)
    elseif st == 'stunned' or st == 'dying_daze' then
        p.bdx, p.sdy = p.bdx + sw(0.5, 6), p.sdy + sw(0.3, 6, 2)
    end
    if self.boingAt and now - self.boingAt < 0.5 and self:trampOut() then
        p.tk = p.tk + 0.3 * math.sin((now - self.boingAt) * 30) * (1 - (now - self.boingAt) / 0.5)
    end
    return p
end

-- ── EL ESCENARIO de detrás (Entities.renderBack: después del cielo, antes de los bloques) ──
-- Público en silueta por todo el ancho de la zona (y algo más) saltando a contratiempo, con barras de luz; detrás, el
-- ecualizador; a los lados de la zona, los bafles; arriba en el centro, la bola de discoteca y sus láseres
local CROWD_DARK = { 0.16, 0.10, 0.24 }
function GC:renderBack(camX, camY)
    if not art or self.state == 'dead' then return end
    if self.offstage and not self.props.bigStage then return end      -- (al fondo del evento: sin su escenario)
    local et = stageT(self)
    if not et then return end
    local zx0, zx1, zy0 = self:zoneBounds()
    local fy = self.floorY
    local nb, beat = beatOf(self)
    local dance = dancing(self)
    if not dance then beat = 0.5 end                                    -- (en la entrada no salta nadie: sin música)
    local now = love.timer.getTime()
    -- en la ENTRADA va saliendo todo: los bafles suben del suelo, la bola baja, el público se asoma uno a uno y,
    -- con el rebote del trampolín, se encienden el ecualizador y los láseres
    local kSpk, kBall, kLight = appear(et, 0.3, 1.1), appear(et, 0.6, 1.6), appear(et, 2.6, 3.2)
    -- ecualizador gigante (barras de colores que siguen el compás)
    local nbar = 26
    local span = (zx1 - zx0) + 8 * T
    local bw = math.floor(span / nbar)
    for i = 0, nbar - 1 do
        local seed = math.sin((nb + 1) * 12.9898 + i * 78.233) * 43758.5453
        local r = seed - math.floor(seed)
        local h = math.floor((1.2 + r * 3.2) * (1 - 0.45 * beat) * kLight) * (T / 2)
        local x = math.floor(zx0 - 4 * T + i * bw - camX)
        for seg = 0, math.floor(h / (T / 2)) - 1 do
            local c = BEAT_COLS[math.min(4, math.floor(seg / 2) + 1)]
            love.graphics.setColor(c[1], c[2], c[3], 0.28)
            love.graphics.rectangle('fill', x + 4, math.floor(fy - camY - (seg + 1) * (T / 2) + 4), bw - 8, T / 2 - 6)
        end
    end
    -- láseres desde la bola de discoteca (se mueven solos y cambian de color en cada tiempo)
    local bx, by = (zx0 + zx1) / 2, zy0 - 0.4 * T
    love.graphics.setBlendMode('add')
    for k = 0, 3 do
        local a = math.sin(now * 1.3 + k * 1.6) * 1.0
        local c = BEAT_COLS[(nb + k) % 4 + 1]
        love.graphics.setColor(c[1], c[2], c[3], 0.22 * kLight)
        love.graphics.setLineWidth(4)
        love.graphics.line(math.floor(bx - camX), math.floor(by - camY), math.floor(bx + math.tan(a) * (fy - by) - camX), math.floor(fy - camY))
    end
    -- motas de la bola por las paredes y el suelo
    for k = 0, 13 do
        local a = now * 0.9 + k * 0.45
        love.graphics.setColor(1, 1, 1, 0.35 * kLight)
        love.graphics.rectangle('fill', math.floor(bx + math.cos(a) * (zx1 - zx0) * 0.5 - camX), math.floor(by + 2 * T + math.abs(math.sin(a * 1.3)) * 6 * T - camY), 6, 6)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
    local bi, bq = quad(art.ball, math.floor(now * 8) % 4 + 1)
    local bdrop = math.floor((1 - kBall) * 5 * T)                       -- (baja colgada de su cadena)
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.rectangle('fill', math.floor(bx - camX) - 2, math.floor(by - camY) - 4 * T - bdrop, 4, 4 * T - 30)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bi, bq, math.floor(bx - camX), math.floor(by - camY) - bdrop, 0, 6, 6, 6, 6)
    -- el PÚBLICO: cangrejos de todas las especies y Gummies, en silueta, saltando a contratiempo, con barras de luz.
    -- DOS filas (0.5.55, el usuario: "más audiencia, detrás y entre los que ya están"): la de atrás más pequeña, más
    -- oscura y más alta; la de delante, más apretada
    if self.props.bigStage then
        -- (el ESCENARIO GRANDE del final del evento: el usuario, "la audiencia del Groove pero mucho más amplia y
        -- variada" → tres filas, más gente y también Gummies de todas las islas y saltarines)
        self:drawCrowd(camX, camY, et, nb, beat, { n = 52, scale = 2, dark = 0.45, lift = 1.15 * T, seed = 41.9, gap = 1.0, mix = true })
        self:drawCrowd(camX, camY, et, nb, beat, { n = 44, scale = 3, dark = 0.66, lift = 0.6 * T, seed = 17.3, gap = 0.9, mix = true })
        self:drawCrowd(camX, camY, et, nb, beat, { n = 38, scale = 4, dark = 1, lift = 0, seed = 3.1, gap = 0.6, mix = true })
    else
        self:drawCrowd(camX, camY, et, nb, beat, { n = 34, scale = 3, dark = 0.62, lift = 0.55 * T, seed = 17.3, gap = 0.9 })
        self:drawCrowd(camX, camY, et, nb, beat, { n = 30, scale = 4, dark = 1, lift = 0, seed = 3.1, gap = 0.6 })
    end
    -- los BAFLES a los lados de la zona: la membrana sale en cada bombo (tiempos 1 y 3)
    local kick = dance and beat < 0.2 and nb % 2 == 0
    local rise = math.floor((1 - kSpk) * 26 * 6)                       -- (salen del suelo: los tapan los bloques)
    local spk = { zx0 + 0.9 * T, zx1 - 0.9 * T }
    if self.props.bigStage then                                         -- (escenario grande: más bafles, en torres)
        spk = { zx0 + 0.9 * T, zx0 + 3.2 * T, zx0 + (zx1 - zx0) * 0.33, zx0 + (zx1 - zx0) * 0.67, zx1 - 3.2 * T, zx1 - 0.9 * T }
    end
    for _, sx0 in ipairs(spk) do
        local si, sq = quad(art.speaker, kick and 2 or 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(si, sq, math.floor(sx0 - camX), math.floor(fy - camY) + rise, 0, 6, 6, 9, 26)
        if dance and beat < 0.5 then                                     -- (aros de sonido)
            local c = BEAT_COLS[nb % 4 + 1]
            love.graphics.setColor(c[1], c[2], c[3], 0.6 * (1 - beat * 2))
            love.graphics.setLineWidth(4)
            local rr = 60 + beat * 160
            love.graphics.circle('line', math.floor(sx0 - camX), math.floor(fy - 8.5 * 6 - camY), rr, 24)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Una fila del público. Los cangrejos que tienen PINZAS en el juego (el de río —la pradera—, el helado y el de lava:
-- `claw` de su piel en types/enemies/crabby.lua) las llevan también aquí, en silueta, y agarran la barra de luz con
-- una, alzándola al compás (el usuario, 0.5.55); los que no tienen, la llevan pegada al cuerpo como antes
local clawCfg = {}
local function clawOf(sp)
    if clawCfg[sp] == nil then
        local skin = SPECIES[sp]:match('^crabby_(%a+)$')
        local Crabby = require('src/world/entities/base/EntityTypes').get('crabby')
        local cfg = skin and Crabby and Crabby.class and Crabby.class.SKINS and Crabby.class.SKINS[skin] and Crabby.class.SKINS[skin].claw
        clawCfg[sp] = cfg and { cfg = cfg, strip = SpriteStrip.load(cfg.file, cfg.w) } or false
    end
    return clawCfg[sp] or nil
end
function GC:drawCrowd(camX, camY, et, nb, beat, row)
    local zx0, zx1 = self:zoneBounds()
    local fy = self.floorY
    local S, n = row.scale, row.n
    local dk = { CROWD_DARK[1] * row.dark, CROWD_DARK[2] * row.dark, CROWD_DARK[3] * row.dark }
    -- su ÁNIMO (0.5.56): VITOREANDO saltan todos en cada tiempo, más alto, agitando las barras; ABUCHEANDO se quedan
    -- quietos, algo hundidos, con las barras bajadas (k: la fuerza, que se va al acabar la reacción)
    local mood, age = self:crowdMood()
    local k = mood and math.min(1, math.max(0, (GC.MOOD_T - (age or 0)) / 0.4)) or 0
    local cheer, boo = mood == GC.CHEER and k > 0.5, mood == GC.BOO and k > 0.5
    for i = 0, n - 1 do
        local seed = math.sin(i * 91.7 + row.seed) * 43758.5453
        local r = seed - math.floor(seed)
        local x = zx0 - 3 * T + (i + 0.5) * ((zx1 - zx0) + 6 * T) / n + (r - 0.5) * T * row.gap
        local off = (i + (row.scale == 3 and 1 or 0)) % 2
        local up = ((nb + off) % 2 == 0 and beat < 0.3) and math.floor(10 * S / 4) or 0
        if cheer then up = math.floor(math.abs(math.sin((beat + off * 0.5) * math.pi)) * 18 * S / 4)
        elseif boo then up = -math.floor(4 * S / 4) end
        local kIn = appear(et, 0.7 + i * 0.05, 1.0 + i * 0.05)          -- (se asoma de debajo de la arena)
        up = up - math.floor((1 - kIn) * 3 * T) + math.floor(math.sin(kIn * math.pi) * 14) + math.floor(row.lift)
        local im, sp
        if row.mix and r < 0.38 then im = mixImg(math.floor(r * 113) % #MIX + 1, (nb + off) % 2 + 1)
        elseif r < 0.2 then im = gummyImg((nb + off) % 2 + 1)
        else sp = math.floor(r * 97) % #SPECIES + 1; im = crabImg(sp, (nb + off) % 3 + 1) end
        if im then
            local w, h = im:getWidth() * S, im:getHeight() * S
            local cxs = math.floor(x - camX)
            local feet = math.floor(fy - 0.15 * T - up - camY)
            local sx, sy = cxs - math.floor(w / 2), feet - h
            local lean = ((nb + i) % 2 == 0) and -1 or 1
            if cheer then lean = ((math.floor(beat * 4) + i) % 2 == 0) and -1 or 1 end     -- (agitándolas)
            local si, sq = quad(art.stick, (i + nb) % 4 + 1)
            local cl = sp and clawOf(sp)
            -- (sin filo aunque sea de noche: el público es fondo y no debe confundirse con lo que hace daño — el usuario)
            love.graphics.setColor(dk[1], dk[2], dk[3], 0.92)
            love.graphics.draw(im, sx, sy, 0, S, S)
            if cl then
                -- sus PINZAS: la del lado `lean`, ALZADA con la barra de luz (sube un poco más en el pulso); la otra, abajo
                local c, st = cl.cfg, cl.strip
                local fw, fh = c.w, st.h or st.image:getHeight()
                for _, side in ipairs({ -1, 1 }) do
                    local raised = side == lean and not boo
                    -- (alzada BIEN por encima del caparazón y un poco hacia fuera, y de un tono algo más claro que el
                    -- cuerpo: en silueta, si no, la pinza se fundía con él y no se veía)
                    local dy = raised and (-6 - ((beat < 0.3) and 1 or 0)) or 0
                    local px = cxs + side * math.floor(c.x * S + fw * S / 2 - c.inset * S + (raised and S or 0))
                    local top = feet + math.floor(c.y * S - fh * S + dy * S)
                    love.graphics.setColor(dk[1] * 1.6 + 0.04, dk[2] * 1.6 + 0.04, dk[3] * 1.6 + 0.06, 0.95)
                    st:draw(raised and 2 or 1, px, top + math.floor(fh * S / 2), 0, -side * S, S)
                    if raised then
                        love.graphics.setColor(1, 1, 1, 0.95)
                        love.graphics.draw(si, sq, px, top + 2, lean * 0.25, S, S, 1.5, 8)
                    elseif boo and side == lean then                    -- (abucheando: la barra cuelga de la pinza)
                        love.graphics.setColor(1, 1, 1, 0.95)
                        love.graphics.draw(si, sq, px, top + math.floor(fh * S), lean * 2.6, S, S, 1.5, 8)
                    end
                end
            else
                -- la barra de luz, AGARRADA al cuerpo (su base en el borde de arriba, a un lado), inclinándose al ritmo
                love.graphics.setColor(1, 1, 1, 0.95)
                if boo then                                             -- (bajada, colgando por delante)
                    love.graphics.draw(si, sq, sx + w / 2 + lean * (w / 2 - 6 * S / 4), sy + h - 2 * S, lean * 2.6, S, S, 1.5, 8)
                else
                    love.graphics.draw(si, sq, sx + w / 2 + lean * (w / 2 - 10 * S / 4), sy + 2 * S, lean * 0.3, S, S, 1.5, 8)
                end
            end
        end
    end
end

-- Los focos del escenario: dos conos desde arriba hacia él, que cambian de color en cada tiempo
function GC:drawSpotlights(camX, camY)
    local zx0, zx1, zy0 = self:zoneBounds()
    local nb = beatOf(self)
    local fx, fy = math.floor(self.x - camX), math.floor(self.floorY - camY)
    love.graphics.setBlendMode('add')
    for i, sx0 in ipairs({ zx0 + T, zx1 - T }) do
        local c = BEAT_COLS[(nb + (i - 1) * 2) % 4 + 1]
        love.graphics.setColor(c[1], c[2], c[3], 0.10)
        local x0, y0 = math.floor(sx0 - camX), math.floor(zy0 - 2 * T - camY)
        love.graphics.polygon('fill', x0 - 16, y0, x0 + 16, y0, fx + 1.4 * T, fy, fx - 1.4 * T, fy)
    end
    love.graphics.setBlendMode('alpha')
end

-- La PISTA DE BAILE: las baldosas encima del suelo (encendidas avisan; luego la columna de luz)
function GC:drawFloor(camX, camY)
    local n, x0 = self:panels()
    local f = self:floorNow()
    local nb = beatOf(self)
    for i = 0, n - 1 do
        -- (SOLO se encienden las del ataque — aviso parpadeando y columna —; si no, todas apagadas: el usuario, para
        -- no confundirlas con la diana del salto)
        local lit = f and f.lit[i]
        local fr = 1
        -- (cada baldosa, SU color —el usuario, 0.5.52: en rosa todas ya no se veían de colores—; el aviso parpadea
        -- cada vez más deprisa según se acerca la columna)
        local col = i % 4 + 1
        if lit and f.warn then fr = ((math.floor(f.u * f.u * 14) % 2 == 0) and col + 1 or 1)
        elseif lit and f.boom then fr = col + 1 end
        local pi, pq = quad(art.panel, fr)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pi, pq, math.floor(x0 + i * P.T * 2 - camX), math.floor(self.floorY - camY) - 6, 0, 4, 4)
        local box = self:boomBox(i)
        local bx, by = math.floor(box.x - camX), math.floor(box.y - camY)
        if lit and f.warn then
            -- el FANTASMA de la columna que va a salir, de su color: dónde exactamente, cada vez más fuerte
            local c = BEAT_COLS[col]
            love.graphics.setBlendMode('add')
            love.graphics.setColor(c[1], c[2], c[3], 0.06 + 0.14 * f.u)
            love.graphics.rectangle('fill', bx, by, box.w, box.h)
            love.graphics.setBlendMode('alpha')
            love.graphics.setColor(c[1], c[2], c[3], 0.4 + 0.5 * f.u)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', bx + 2, by + 2, box.w - 4, box.h - 4)
            love.graphics.setLineWidth(1)
            -- y una flecha de "¡ojo!" que sube desde la baldosa
            local ay = math.floor(self.floorY - camY - 20 - f.u * 30)
            love.graphics.setColor(1, 0.85, 0.3, 0.5 + 0.5 * f.u)
            love.graphics.polygon('fill', bx + box.w / 2 - 14, ay, bx + box.w / 2 + 14, ay, bx + box.w / 2, ay - 18)
        elseif lit and f.boom then
            local c = BEAT_COLS[col]
            love.graphics.setBlendMode('add')
            love.graphics.setColor(c[1], c[2], c[3], 0.75)
            love.graphics.rectangle('fill', bx, by, box.w, box.h)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.rectangle('fill', math.floor(bx + box.w / 2 - 10), by, 20, box.h)
            love.graphics.setBlendMode('alpha')
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Los PLATOS DE DJ (2ª fase), sobre sus plataformas: salen al empezar la fase (suben desde la plataforma); apagados,
-- una flecha que bota encima dice "písame"; girando, la etiqueta da vueltas y los LED cuentan lo que le queda
local N_LED = 5
function GC:drawDecks(camX, camY)
    if not (self.decks and self.phase == 2) then return end
    local now = love.timer.getTime()
    local kIn = self.p2T and math.max(0, math.min(1, ((self.songT or 0) - self.p2T) / DECK_IN)) or 1
    if self:isDying() then kIn = 1 end
    -- con la PISTA encendida se van con sus plataformas (el usuario, 0.5.56: que el ataque se vea solo) y, al acabar,
    -- vuelven a salir de ellas (el momento de volver se recuerda al dibujar)
    if self:decksAway() or self.state == 'dying_burst' then self._deckAway = true; return end
    if self._deckAway then self._deckAway, self._deckBack = false, now end
    if self._deckBack then kIn = math.min(kIn, math.min(1, (now - self._deckBack) / DECK_IN)) end
    local live = self:decksLive()
    for i, d in ipairs(self.decks) do
        local on = (d.on or 0) > 0
        local fr = on and (math.floor(now * 12) % 3 + 2) or 1
        local x, y = math.floor(d.x - DECK_W / 2 - camX), math.floor(d.y - camY) - math.floor(DECK_H * kIn)
        local h = math.floor(DECK_H * kIn)
        if h > 0 then
            -- (sale de la plataforma: se recorta lo que aún está "dentro")
            local Clip = require 'src/ui/Clip'
            if on then                                                  -- (el halo de encendido)
                love.graphics.setBlendMode('add')
                love.graphics.setColor(0.25, 0.85, 1, 0.25 + 0.1 * math.sin(now * 10))
                love.graphics.rectangle('fill', x - 6, y - 6, DECK_W + 12, DECK_H + 6)
                love.graphics.setBlendMode('alpha')
            elseif live then                                            -- (apagado: late, para que se vea de noche)
                love.graphics.setBlendMode('add')
                love.graphics.setColor(1, 0.9, 0.5, 0.18 + 0.14 * math.sin(now * 6))
                love.graphics.rectangle('fill', x - 10, y - 10, DECK_W + 20, DECK_H + 10)
                love.graphics.setBlendMode('alpha')
            end
            Clip.push(x, y, DECK_W, h)                                  -- (los halos, fuera del recorte)
            love.graphics.setColor(1, 1, 1, 1)
            local di, dq = quad(art.deck, fr)
            love.graphics.draw(di, dq, x, y, 0, 4, 4)
            -- la cuenta atrás: N_LED en la tira de delante (rojos y parpadeando al final)
            local lit = on and math.ceil(d.on / DECK_T * N_LED) or 0
            for k = 0, N_LED - 1 do
                local lf = 1
                if k < lit then lf = (lit <= 2) and ((math.floor(now * 8) % 2 == 0) and 3 or 1) or 2 end
                local li, lq = quad(art.led, lf)
                love.graphics.draw(li, lq, x + 8 + k * 16, y + 7 * 4, 0, 4, 4)
            end
            Clip.pop()
        end
        if live and not on and kIn >= 1 then                            -- (¡písame!)
            local bob = math.floor(math.abs(math.sin(now * 5)) * 14)
            local ai, aq = quad(art.arrow, 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(ai, aq, math.floor(d.x - camX) - 14, y - 40 - bob, 0, 4, 4)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- El BAJÓN: los dos bafles disparan aros y un chorro de luz contra él (DROP_FX s desde dropT)
function GC:drawDrop(camX, camY)
    if not self.dropT then return end
    local u = ((self.songT or 0) - self.dropT) / DROP_FX
    if u < 0 or u >= 1 then return end
    local zx0, zx1 = self:zoneBounds()
    local sy = math.floor(self.floorY - 8.5 * 6 - camY)
    local tx = math.floor(self.x - camX)
    love.graphics.setBlendMode('add')
    for i, sx0 in ipairs({ zx0 + 0.9 * T, zx1 - 0.9 * T }) do
        local sx = math.floor(sx0 - camX)
        local c = BEAT_COLS[(i - 1) * 2 + 1]
        love.graphics.setColor(c[1], c[2], c[3], 0.3 * (1 - u))
        local x0, x1 = math.min(sx, tx), math.max(sx, tx)
        local hh = math.floor(40 * (1 - u)) + 8
        love.graphics.rectangle('fill', x0, sy - hh, x1 - x0, 2 * hh)
        love.graphics.setLineWidth(6)
        for k = 0, 2 do
            local r = (u * 3 - k * 0.3) * 260
            if r > 0 then love.graphics.circle('line', sx, sy, r, 32) end
        end
        love.graphics.setLineWidth(1)
    end
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- Las GAFAS que le volaron al quedar noqueado: salen de la cara hacia atrás en arco, botan en el suelo y se quedan;
-- al recomponerse ('regrow') vuelven de un salto a su cara. Pura función de state + deadTimer (el sitio donde caen se
-- recuerda al dibujar, para que se queden ahí mientras se recoge el escenario después de reventar)
local GL_FLY, GL_BACK = 0.55, 0.35
function GC:drawGlasses(camX, camY, alpha)
    local st, t = self.state, self.deadTimer or 0
    local f = self.facing or 1
    local hx, hy = self.x + f * 0.5 * MS, self:feetY() - 6 * MS            -- (la cara)
    local rx, ry = self.x - f * 2.6 * T, self.floorY                      -- (en el suelo, detrás de él)
    local x, y
    if st == 'stunned' or st == 'dying_daze' then
        self._glass = { rx, ry }
        if t < GL_FLY then
            local u = t / GL_FLY
            x, y = hx + (rx - hx) * u, hy + (ry - hy) * u - 2.2 * T * 4 * u * (1 - u)
        else
            local b = math.max(0, 1 - (t - GL_FLY) / 0.3)
            x, y = rx, ry - math.abs(math.sin((t - GL_FLY) * 14)) * 18 * b
        end
    elseif st == 'regrow' and t < GL_BACK then
        local u = t / GL_BACK
        x, y = rx + (hx - rx) * u, ry + (hy - ry) * u - 1.5 * T * 4 * u * (1 - u)
    elseif st == 'dying_burst' and self._glass then
        x, y = self._glass[1], self._glass[2]
        alpha = alpha * math.max(0, 1 - (t - P.STAGE_OUT + 0.6) / 0.6)
    else return end
    local gi, gq = quad(art.glasses, 1)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(gi, gq, math.floor(x - camX), math.floor(y - camY), 0, MS * f * -1, MS, 7, 4)
    love.graphics.setColor(1, 1, 1, 1)
end

function GC:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' or not art then return end
    local st = self.state
    local now = love.timer.getTime()
    -- (`_bodyOnly`: solo él — el director del Mega Mashup lo dibuja pequeño al fondo —, sin pista, platos ni focos)
    local extras = not self._bodyOnly
    if extras and stageT(self) then self:drawFloor(camX, camY) end
    if extras and (live(self) or self:isDying()) then self:drawDecks(camX, camY) end
    if extras and live(self) then self:drawSpotlights(camX, camY) end
    -- (¿anda? lo que avanzó desde el dibujo anterior)
    self._walking = self._lx ~= nil and math.abs(self.x - self._lx) > 0.05 and st == 'groove'
    self._lx = self.x
    if st == 'dying_burst' then                                       -- (reventó: solo quedan sus gafas)
        if not EDITOR_VIEW then self:drawGlasses(camX, camY, 1) end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local p = self:pose()
    local alpha = self:ghostAlpha()
    local f = (self.facing or 1) * p.flip
    local fx, fy = math.floor(self.x - camX + 0.5) + p.jx, math.floor(self:feetY() - camY + 0.5)
    local dizzy = (st == 'dying_daze' or st == 'stunned') and not EDITOR_VIEW
    if dizzy then BossFx.stars(fx, fy - 9 * MS, 9 * MS, 1.8 * MS, 7, alpha, 'back') end
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, alpha)
    elseif self.rage and self:isActive() then
        local q = 0.86 + 0.08 * math.sin(now * 8)
        love.graphics.setColor(1, q, q, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    love.graphics.push()
    love.graphics.translate(fx, fy)
    love.graphics.scale(p.sx, p.sy)
    -- (el dibujo mira a la IZQUIERDA: mirando a la derecha va espejado; la pinza grande va por delante)
    local A = art
    if p.tk > 0.02 then
        local ti, tq = quad(A.tramp, 1)
        love.graphics.draw(ti, tq, 0, -(FH - 1) * MS, 0, MS, MS * p.tk, 8, 9)       -- (el muelle, metido un píxel en el caparazón)
    end
    local bi, bq
    if p.ko then bi, bq = quad(A.ko, math.floor(now * 7) % 2 + 1)        -- (los ojos en X giran)
    else bi, bq = quad(A.body, p.leg) end
    love.graphics.draw(bi, bq, 0, 0, 0, -MS * f, MS, FW / 2, FH)
    local bx = f * (13 - math.floor(p.bdx + 0.5)) * MS        -- (bdx: hacia el cuerpo; en px de arte enteros)
    local bdy, sdy = math.floor(p.bdy + 0.5), math.floor(p.sdy + 0.5)
    local gi, gq = quad(A.big, p.bf)
    love.graphics.draw(gi, gq, bx, (-4.5 + bdy) * MS, 0, -MS * f, MS, 6, 4.5)
    local si, sq = quad(A.small, p.sf)
    love.graphics.draw(si, sq, -f * 11.5 * MS, (-4 + sdy) * MS, 0, MS * f, MS, 3.5, 3)
    love.graphics.pop()
    if dizzy then BossFx.stars(fx, fy - 9 * MS, 9 * MS, 1.8 * MS, 7, alpha, 'front') end
    if not EDITOR_VIEW then self:drawGlasses(camX, camY, alpha) end
    if not extras then love.graphics.setColor(1, 1, 1, 1); return end
    self:drawOver(camX, camY)
    if live(self) then self:drawDrop(camX, camY) end
    -- el destello al empezar cada frase (el primer tiempo de cada 4 compases)
    if live(self) then
        local b, sec, k, step = self:whereAt(self.songT or 0)
        if sec ~= 'I' and k % 4 == 1 and step < 1.2 then
            local zx0, zx1, zy0, zy1 = self:zoneBounds()
            love.graphics.setBlendMode('add')
            love.graphics.setColor(1, 1, 1, 0.16 * (1 - step / 1.2))
            love.graphics.rectangle('fill', math.floor(zx0 - camX), math.floor(zy0 - 3 * T - camY), zx1 - zx0, zy1 - zy0 + 4 * T)
            love.graphics.setBlendMode('alpha')
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- La diana, las ondas, las notas (y la dorada) y el enfado
function GC:drawOver(camX, camY)
    local now = love.timer.getTime()
    if self.state == 'crouch' and not EDITOR_VIEW then
        local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
        love.graphics.setColor(1, 0.3, 0.3, blink)
        BossFx.target(now * 1.2, math.floor(self.markX - camX), math.floor(self.floorY - camY - 16), 8, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    for _, w in ipairs(self.waves or {}) do
        local fr = math.floor((w.t or 0) * 12) % 3 + 1
        art.wave:draw(fr, math.floor(w.x - camX), math.floor(w.y - camY) - 18, 0, 4 * w.dir, 4)
    end
    for _, n in ipairs(self.notes or {}) do
        if (n.c or 0) >= 4 then
            -- la DORADA: mucho más grande, con RAYOS que giran, un aro blanco que late y un halo dorado (devuelta,
            -- deja estela). Que no se confunda con ninguna nota normal (ya ninguna es amarilla: el usuario, 0.5.52)
            local x, y = math.floor(n.x - camX), math.floor(n.y - camY)
            love.graphics.setBlendMode('add')
            love.graphics.setColor(1, 0.85, 0.3, 0.4 + 0.15 * math.sin(now * 12))
            love.graphics.circle('fill', x, y, 46 + 5 * math.sin(now * 12), 20)
            love.graphics.setColor(1, 0.92, 0.5, 0.35)
            for r = 0, 5 do
                local a = now * 2.2 + r * math.pi / 3
                local ca, sa = math.cos(a), math.sin(a)
                love.graphics.polygon('fill', x + ca * 20 - sa * 7, y + sa * 20 + ca * 7, x + ca * 20 + sa * 7, y + sa * 20 - ca * 7,
                                      x + ca * 78, y + sa * 78)
            end
            love.graphics.setBlendMode('alpha')
            love.graphics.setColor(1, 1, 1, 0.6 + 0.4 * math.sin(now * 10))
            love.graphics.setLineWidth(4)
            love.graphics.circle('line', x, y, 40, 20)
            love.graphics.setLineWidth(1)
            if n.c == 5 then
                for k = 1, 3 do
                    love.graphics.setColor(1, 0.9, 0.4, 0.3 / k)
                    art.gold:draw(1, x - math.floor(n.vx * 0.03 * k), y - math.floor(n.vy * 0.03 * k), 0, 6, 6)
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
            art.gold:draw(math.floor(now * 6) % 2 + 1, x, y, 0, 7, 7)
        else
            -- (más visibles: más grandes, con un halo de su color y una estela detrás)
            local fr = (n.c or 0) * 2 + (math.floor(now * 6 + (n.id or 0)) % 2) + 1
            local c = NOTE_COLS[(n.c or 0) % 4 + 1]
            local x, y = math.floor(n.x - camX), math.floor(n.y - camY)
            local sp = math.max(1, math.sqrt((n.vx or 0) ^ 2 + (n.vy or 0) ^ 2))
            love.graphics.setBlendMode('add')
            love.graphics.setColor(c[1], c[2], c[3], 0.3 + 0.1 * math.sin(now * 14 + (n.id or 0)))
            love.graphics.circle('fill', x, y, 30, 16)
            for k = 1, 3 do
                love.graphics.setColor(c[1], c[2], c[3], 0.35 / k)
                love.graphics.circle('fill', math.floor(x - (n.vx or 0) / sp * 14 * k), math.floor(y - (n.vy or 0) / sp * 14 * k), 14 - 3 * k, 10)
            end
            love.graphics.setBlendMode('alpha')
            love.graphics.setColor(1, 1, 1, 1)
            art.note:draw(fr, x, y, 0, 5, 5)
        end
    end
    self:drawCue(camX, camY, now)
    BossFx.anger(self, self.rage and self:isActive(), self.x - camX, self:feetY() - camY - 16 * MS)
    love.graphics.setColor(1, 1, 1, 1)
end

-- AVISO DE NOTA: un pulso de luz en la punta de la pinza justo antes de cada nota (del reloj de la canción y su plan:
-- igual online) — se ve venir el disparo
function GC:drawCue(camX, camY, now)
    if not (self:isActive() and self.state == 'snap') or EDITOR_VIEW then return end
    local _, sec, k, step = self:whereAt(self.songT or 0)
    local plan = GC.plan(sec, k, self.rage, self:goldOff())
    local nextS
    for _, s in ipairs(plan.notes) do if s > step and (not nextS or s < nextS) then nextS = s end end
    if not nextS then return end
    local left = (nextS - step) * S16
    if left > 0.22 then return end
    local u = 1 - left / 0.22
    local x, y = self:clawTip()
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 0.25 + 0.55 * u)
    love.graphics.setLineWidth(4)
    love.graphics.circle('line', math.floor(x - camX), math.floor(y - camY), math.floor(44 - 30 * u), 16)
    love.graphics.circle('fill', math.floor(x - camX), math.floor(y - camY), math.floor(6 + 10 * u), 12)
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cajas de depuración (F1): ondas, notas, columnas de la pista, los platos y el cojín del trampolín
function GC:debugBoxes()
    local out = {}
    for _, w in ipairs(self.waves or {}) do local b = BossWaves.box(w, P.WAVES); b.kind = 'hazard'; out[#out + 1] = b end
    for _, n in ipairs(self.notes or {}) do local b = self:noteBox(n); b.kind = (n.c >= 4) and 'area' or 'hazard'; out[#out + 1] = b end
    local f = self.zone and self:floorNow()
    if f and f.boom then for i, on in pairs(f.lit) do if on then local b = self:boomBox(i); b.kind = 'hazard'; out[#out + 1] = b end end end
    if self.decks and self.phase == 2 then
        for _, d in ipairs(self.decks) do local b = self:deckBox(d); b.kind = 'area'; out[#out + 1] = b end
    end
    if self:trampOut() then local b = self:trampBox(); b.kind = 'area'; out[#out + 1] = b end
    return out
end
end
