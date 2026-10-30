-- src/states/story/StoryMapScenes.lua
-- PARTE de src/states/story/StoryMapState.lua: las ESCENAS DEL MAPA de los secretos (docs/story/story.md, "Los
-- secretos"; decisiones del usuario del 2026-10-29). Sin texto, como toda la historia: sprites del mapa y del juego,
-- chispas, rayos y sonidos de las películas. Se ven UNA vez (la partida las apunta en `films[id]`, como las películas)
-- y se pueden saltar (ENTER / atrás: su efecto se aplica igual).
--   groove  EL ROBO. Con el Espejo vencido y TODAS las astillas (Collect, tipo 'splinter'): en el islote del Groove,
--           su bola de discoteca saca las astillas de la corona y del amuleto (el jugador se queda las monturas:
--           estado 'stolen'), la bola se completa y el aleteo del monstruo chisporrotea y se apaga — en su isla y en el
--           Mashup la bola no deja aletear —. Al acabar se abre la isla del Groove (Worlds `secrets`: scene = 'groove')
--   regrow  Vencido el Groove: los rayos de la bola hacen crecer otra vez a los tres cangrejos pequeños (el helado,
--           el Mega Crabby y el lúgubre: la onda del espejo los había encogido) → se abre el Mega Mashup
--           (scene = 'regrow')
--   disco   EL FINAL DE VERDAD, tras el Mega Mashup (Worlds `epilogue`): la bola se rompe, las astillas vuelven a sus
--           monturas (estado true otra vez), todos pequeños bailando, el monstruo aletea libre y el trofeo: la bola
--   La onda de luz del final (src/story/films/ending.lua) encoge también a los cangrejos secretos descubiertos y
--   rebota en la bola del Groove: StoryMapState.secretCrabs / grooveSpot (abajo).
-- Cuándo empieza una: al entrar en el mapa (y al acabar otra), cuando ya no queda nada abriéndose ni el monstruo
-- anda; la cámara va al sitio de la escena y vuelve.
-- La carga StoryMapState.lua con require(...)(StoryMapState, P).
local Worlds = require 'src/story/Worlds'
local Run = require 'src/story/Run'
local Collect = require 'src/story/Collect'

return function(SM, P)
local img, frameQ, nodeXY, mapNodes, stopIndex = P.img, P.frameQ, P.nodeXY, P.mapNodes, P.stopIndex

local floor, sin, cos = math.floor, math.sin, math.cos
local Stage = function() return require 'src/story/Stage' end

-- Cómo se ve cada cangrejo secreto en el mapa (por su tipo de jefe: collectibles.json `source.boss`): en grande y su
-- enemigo normal (en pequeño, tras la onda del espejo). El helado no es secreto pero vuelve en el Mashup.
local CRAB_ART = {
    megacrabby     = { big = { img = 'assets/images/bosses/megacrabby/crab1.png' },
                       small = { img = 'assets/images/enemies/crabby/crab1.png' } },
    megagloomy     = { big = { img = 'assets/images/bosses/megagloomy/body-Sheet.png', fw = 38, glow = 'assets/images/bosses/megagloomy/glow-Sheet.png' },
                       small = { img = 'assets/images/enemies/gloomy/gloomy-Sheet.png', fw = 26, glow = 'assets/images/enemies/gloomy/glow-Sheet.png' } },
    megacrabby_ice = { big = { img = 'assets/images/bosses/megacrabby_ice/crab1.png' },
                       small = { img = 'assets/images/enemies/crabby_ice/crab1.png' } },
}
SM.CRAB_ART = CRAB_ART
-- (los del Mega Mashup, en su orden: el Tantrum, el helado, el lúgubre; el Groove aparte)
local MASHUP_CRABS = { 'megacrabby', 'megacrabby_ice', 'megagloomy' }

-- ── Dónde: los nodos de los secretos ─────────────────────────────────────────────────────────────────────────────
local function secretNode(level)
    for w = 1, Worlds.count() do
        for k, nd in ipairs(mapNodes(w)) do if nd.secret and nd.id == level then return w, k end end
    end
end
-- (en píxeles del mapa; nil si ese secreto no existe)
local function secretXY(level)
    local w, k = secretNode(level)
    if not w then return nil end
    return nodeXY(w, k)
end
SM.secretXY = secretXY

-- Los cangrejos SECRETOS que la partida ha descubierto (su nodo se ve): { { x, y, art, small } } — los encoge la onda del
-- final (ending.lua). Uno por coleccionable con jefe (genérico: un secreto nuevo con su jefe sale solo si tiene arte)
function SM.secretCrabs()
    local out = {}
    for _, c in ipairs(Collect.LIST) do
        local s = c.source
        local e = s.level and Worlds.secretOf(s.level)
        local art = s.boss and CRAB_ART[s.boss]
        if e and art and Run.data and Run.secretState(e) ~= 'locked' then
            local x, y = secretXY(s.level)
            if x then out[#out + 1] = { x = x + 40, y = y + 12, art = art.big, small = art.small, boss = s.boss } end
        end
    end
    return out
end

-- El GROOVE en su islote, cuando cuenta en el final: la partida tiene todas las astillas (si no, el juego acaba en el
-- Espejo, sin nada más). → x, y de sus pies o nil
function SM.grooveSpot()
    if not (Run.data and Collect.hasAll(Run.data, 'splinter') and #Collect.ofKind('splinter') > 0) then return nil end
    local x, y = secretXY('isla_del_groove')
    if not x then return nil end
    return x + 4, y + 10
end

-- ── Piezas de dibujo (en píxeles del mapa; la cámara ya está aplicada) ───────────────────────────────────────────
local GFW = 18                                -- (groovecrab/body-Sheet: 3 cuadros de 18x10)
-- El Groove entero, como en el juego (groovecrab_stage.lua GC:render) y con la vida de los otros cangrejos gigantes del
-- mapa (StoryMapState:_drawBossArt / BOSS_CLAWS): respira (un aplastado suave), las pinzas se mecen y chasquean de vez en
-- cuando; el trampolín de la espalda, el cuerpo y sus dos pinzas — la grande delante, la pequeña detrás — (el usuario:
-- en el mapa le faltaban las pinzas y el trampolín). Mira a la izquierda, como su dibujo; (x, y) = sus pies
local function drawGroove(x, y, t, s, dance)
    local D = 'assets/images/bosses/groovecrab/'
    local body, big, small, tramp = img(D .. 'body-Sheet.png'), img(D .. 'bigclaw-Sheet.png'), img(D .. 'claw-Sheet.png'), img(D .. 'tramp.png')
    local fr = dance and ((floor(t * 4) % 3) + 1) or 1
    local squash = 1 + 0.06 * sin(t * 4)
    local hop = dance and floor(-math.abs(sin(t * 6)) * 8) or 0
    local function snap(k)                                                   -- (un chasquido de vez en cuando; bailando, al ritmo)
        local q = t * (dance and 3 or 1.1) + k * 0.5
        return (floor(q) % (dance and 2 or 3) == 0 and q % 1 < 0.22) and 2 or 1
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(floor(x), floor(y + hop))
    love.graphics.draw(tramp, 0, floor(-9 * s * squash), 0, s, s * (2 - squash), 8, 9)     -- (el muelle: se encoge al respirar)
    love.graphics.draw(body, frameQ(body, GFW, fr), 0, 0, 0, s, s * squash, GFW / 2, 10)
    local dyB, dxB = sin(t * 5) * 0.5, 0.15 + 0.15 * sin(t * 2.5)
    local dyS, dxS = sin(t * 5 + 1.9) * 0.5, 0.15 + 0.15 * sin(t * 2.5 + 1.9)
    love.graphics.draw(big, frameQ(big, 12, snap(1)), floor((-13 - dxB) * s), floor((-4.5 + dyB) * s * squash), 0, s, s, 6, 4.5)
    love.graphics.draw(small, frameQ(small, 7, snap(2)), floor((11.5 + dxS) * s), floor((-4 + dyS) * s * squash), 0, -s, s, 3.5, 3)
    love.graphics.pop()
end
local function drawBall(x, y, t, s, bright)
    local im = img('assets/images/bosses/groovecrab/discoball-Sheet.png')
    local fr = (floor(t * (bright and 10 or 4)) % 4) + 1
    if bright then Stage().rays(x, y, t * 3, 8, 26 * s, 0.25, { 1, 0.9, 1 }) end
    love.graphics.setColor(bright and 1 or 0.6, bright and 1 or 0.6, bright and 1 or 0.7, 1)
    love.graphics.draw(im, frameQ(im, 12, fr), floor(x - 6 * s), floor(y - 6 * s), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end
local function drawIcon(id, x, y, s, a)
    local im = Collect.image(id)
    if not im then return end
    love.graphics.setColor(1, 1, 1, a or 1)
    love.graphics.draw(im, floor(x - im:getWidth() * s / 2), floor(y - im:getHeight() * s / 2), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end
-- el monstruo (de pie, o volando con su aleteo: `fly` = altura)
local function drawMonster(x, y, face, fly, t)
    local fi = fly and ((floor(t * 10) % 2 == 0) and 4 or 5) or 1
    local im = img('assets/images/player/monstrito' .. fi .. '.png')
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle('fill', floor(x - 12), floor(y + 6), 24, 6)
    love.graphics.setColor(1, 1, 1, 1)
    local s = 3
    love.graphics.draw(im, floor(x - (face < 0 and -1 or 1) * 9 * s / 2), floor(y + 8 - 16 * s - (fly or 0)), 0, face < 0 and -s or s, s)
end
local function beam(x0, y0, x1, y1, a)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 0.85, 1, a)
    love.graphics.setLineWidth(6)
    love.graphics.line(floor(x0), floor(y0), floor(x1), floor(y1))
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.setLineWidth(2)
    love.graphics.line(floor(x0), floor(y0), floor(x1), floor(y1))
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode('alpha')
    love.graphics.setColor(1, 1, 1, 1)
end
SM.drawGrooveArt, SM.drawDiscoBall = drawGroove, drawBall          -- (también para la película del final)
local function k01(t, a, b) return math.max(0, math.min(1, (t - a) / (b - a))) end
local function lerp(a, b, u) return a + (b - a) * u end

-- Las astillas de la partida, por su id (las monturas: corona, amuleto…)
local function splinters()
    local out = {}
    for _, c in ipairs(Collect.ofKind('splinter')) do out[#out + 1] = c.id end
    return out
end

-- ── Las escenas ───────────────────────────────────────────────────────────────────────────────────────────────────
local SCENES = {}

-- EL ROBO (en el islote del Groove)
SCENES.groove = {
    dur = 7.0, focus = 'isla_del_groove',
    enter = function(sc)
        sc.gx, sc.gy = secretXY('isla_del_groove')
        sc.gx, sc.gy = sc.gx + 30, sc.gy + 6
        sc.mx, sc.my = sc.gx - 120, sc.gy + 4
        sc.ids = splinters()
    end,
    cues = {
        { 0.6, function(sc) Sound.play('storyGlint', 0.9) end },
        { 1.0, function(sc) Sound.play('storyOrb') end },
        { 2.9, function(sc) Sound.play('storyRestore'); Stage().spark(sc.gx, sc.gy - 70, 16, 10, 220, { life = 0.6, s = 3 }) end },
        { 3.8, function(sc) Sound.play('jump', 0.75, 0.8) end },
        { 4.4, function(sc) Sound.play('jump', 0.65, 0.6) end },
        { 4.9, function(sc) Sound.play('jump', 0.55, 0.4); Sound.play('storyShrink', 0.7, 0.6) end },
        { 5.6, function(sc) Sound.play('storyLaughFar', 1.5, 0.6) end },
    },
    draw = function(sc, t)
        local bx, by = sc.gx, sc.gy - 74
        local whole = t >= 2.9
        drawGroove(sc.gx, sc.gy, t, 3, t >= 5.2)
        drawBall(bx, by, t, 3, whole)
        if not whole and t >= 0.6 and t < 1.2 then Stage().rays(bx, by, t * 3, 6, 40 * k01(t, 0.6, 0.9), 0.3, { 1, 0.9, 1 }) end
        -- el monstruo, que llega; las monturas suben de él y la bola les saca las astillas
        local face = 1
        local hop = 0
        for _, h in ipairs({ { 3.8, 26 }, { 4.4, 16 }, { 4.9, 8 } }) do      -- (intenta aletear: cada vez menos)
            if t >= h[1] and t < h[1] + 0.45 then hop = sin((t - h[1]) / 0.45 * math.pi) * h[2] end
        end
        drawMonster(sc.mx, sc.my, face, hop > 0 and hop or nil, t)
        if hop > 0 and floor(t * 20) % 3 == 0 then
            Stage().spark(sc.mx, sc.my - hop - 10, 1, 8, 40, { life = 0.4, s = 2, vy = 30 })    -- (el aleteo chisporrotea)
        end
        local n = #sc.ids
        for i, id in ipairs(sc.ids) do
            local ox = (i - (n + 1) / 2) * 44
            local up = k01(t, 1.0, 1.5)
            local back = k01(t, 3.1, 3.6)
            local ix = lerp(sc.mx, sc.mx + 40 + ox, up)
            local iy = lerp(sc.my - 30, sc.my - 90, up) + back * 60
            if t >= 1.0 and back < 1 then drawIcon(id, ix, iy, 2, 1 - back) end
            -- la astilla sale de su montura y vuela a la bola
            local t0 = 1.7 + (i - 1) * 0.35
            local u = k01(t, t0, t0 + 0.8)
            if u > 0 and u < 1 then
                Stage().orb(lerp(ix, bx, u), lerp(iy, by, u) - sin(u * math.pi) * 40, t, 2)
                if floor(t * 30) % 2 == 0 then Stage().spark(lerp(ix, bx, u), lerp(iy, by, u), 1, 4, 20, { life = 0.3, s = 2 }) end
            end
        end
        -- los rayos de la bola, completa, sobre el monstruo: el aleteo se apaga
        if t >= 3.4 and t < 5.3 then beam(bx, by, sc.mx, sc.my - 24, 0.35 + 0.15 * sin(t * 20)) end
        if t >= 5.2 then                                             -- (y el Groove baila: sus notas)
            local note = img('assets/images/bosses/groovecrab/note-Sheet.png')
            for j = 0, 2 do
                local q = (t * 0.8 + j / 3) % 1
                love.graphics.setColor(1, 1, 1, 1 - q)
                love.graphics.draw(note, frameQ(note, 9, (j * 2) % 8 + 1), floor(sc.gx - 40 + j * 36), floor(sc.gy - 40 - q * 60), 0, 3, 3)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
        if whole and t < 3.1 then Stage().flash(0.5 * (1 - (t - 2.9) / 0.2), 1, 0.95, 1) end
    end,
    -- las astillas, robadas: la partida se queda con las monturas vacías
    done = function(d)
        for _, id in ipairs(splinters()) do if d.collect[id] == true then d.collect[id] = 'stolen' end end
    end,
}

-- LOS TRES CRECEN OTRA VEZ (vencido el Groove)
SCENES.regrow = {
    dur = 5.4, focus = 'mashup_cangrejos',
    enter = function(sc)
        sc.gx, sc.gy = secretXY('isla_del_groove')
        sc.gx, sc.gy = sc.gx + 30, sc.gy + 6
        local mx, my = secretXY('mashup_cangrejos')
        sc.crabs = {}
        for i, b in ipairs(MASHUP_CRABS) do sc.crabs[i] = { x = mx - 70 + (i - 1) * 70, y = my + 26 + ((i == 2) and 10 or 0), b = b } end
    end,
    cues = {
        { 0.5, function(sc) Sound.play('storyGlint', 1.1) end },
        { 1.1, function(sc) Sound.play('storyGrow', 0.9) end },
        { 2.3, function(sc) Sound.play('storyGrow', 1.0) end },
        { 3.5, function(sc) Sound.play('storyGrow', 1.1) end },
        { 4.6, function(sc) Sound.play('storyLaughFar', 1.5, 0.6) end },
    },
    draw = function(sc, t)
        local bx, by = sc.gx, sc.gy - 74
        drawGroove(sc.gx, sc.gy, t, 3, true)
        drawBall(bx, by, t, 3, true)
        for i, c in ipairs(sc.crabs) do
            local t0 = 1.1 + (i - 1) * 1.2
            local u = k01(t, t0, t0 + 0.7)
            if t >= t0 - 0.3 and t < t0 + 0.4 then beam(bx, by, c.x, c.y - 20, 0.6) end
            local art = CRAB_ART[c.b]
            if u < 0.5 then SM._drawBossArt(sc.map, art.small, c.x, c.y, 0, 1 + u * 0.6)
            else SM._drawBossArt(sc.map, art.big, c.x, c.y, 0, lerp(0.6, 1, (u - 0.5) * 2)) end
            if u > 0.45 and u < 0.55 then Stage().spark(c.x, c.y - 20, 6, 12, 160, { life = 0.5, s = 3 }) end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end,
}

-- EL FINAL DE VERDAD (tras el Mega Mashup)
SCENES.disco = {
    dur = 8.0, focus = 'mashup_cangrejos',
    enter = function(sc)
        sc.gx, sc.gy = secretXY('isla_del_groove')
        sc.gx, sc.gy = sc.gx + 30, sc.gy + 6
        sc.cx, sc.cy = secretXY('mashup_cangrejos')
        sc.crabs = {}
        for i, b in ipairs(MASHUP_CRABS) do sc.crabs[i] = { x = sc.cx - 70 + (i - 1) * 70, y = sc.cy + 26 + ((i == 2) and 10 or 0), b = b } end
        sc.ids = splinters()
    end,
    cues = {
        { 0.9, function(sc) Sound.play('storyCrash'); Stage().spark(sc.gx, sc.gy - 74, 30, 10, 320, { life = 0.8, s = 3, g = 200 }) end },
        { 1.4, function(sc) Sound.play('storyRestore') end },
        { 2.0, function(sc) Sound.play('storyShrink', 1.0) end },
        { 3.2, function(sc) Sound.play('jump', 1.2, 0.5) end },
        { 3.7, function(sc) Sound.play('jump', 1.3, 0.5) end },
        { 4.2, function(sc) Sound.play('jump', 1.4, 0.5) end },
        { 5.2, function(sc) Sound.play('storyBell', 1.5) end },
    },
    draw = function(sc, t)
        local bx, by = sc.gx, sc.gy - 74
        local broken = t >= 0.9
        local shrunk = k01(t, 2.0, 2.6)
        -- el Groove (encoge también) y los tres; luego bailan todos, pequeños
        local dance = t >= 2.6
        drawGroove(sc.gx, sc.gy, t, lerp(3, 1.5, shrunk), dance)
        if not broken then
            local j = floor(sin(t * 60) * 3 * k01(t, 0.2, 0.9))
            drawBall(bx + j, by, t, 3, true)
        end
        for i, c in ipairs(sc.crabs) do
            local art = CRAB_ART[c.b]
            local hop = dance and floor(-math.abs(sin(t * 6 + i)) * 10) or 0
            if shrunk < 0.5 then SM._drawBossArt(sc.map, art.big, c.x, c.y, 0, lerp(1, 0.6, shrunk * 2))
            else SM._drawBossArt(sc.map, art.small, c.x, c.y + hop, 0, lerp(1.4, 1, (shrunk - 0.5) * 2)) end
        end
        -- las astillas vuelven a sus monturas (hacia el monstruo)
        for i = 1, #sc.ids do
            local u = k01(t, 1.0 + i * 0.12, 1.8 + i * 0.12)
            if u > 0 and u < 1 then Stage().orb(lerp(bx, sc.cx - 150, u), lerp(by, sc.cy - 140, u) - sin(u * math.pi) * 50, t, 2) end
        end
        -- el monstruo aletea LIBRE, por encima de todos
        local fly = (t >= 3.0) and (60 + sin(t * 5) * 14) * k01(t, 3.0, 3.6) or nil
        drawMonster(sc.cx - 120, sc.cy + 10, 1, fly, t)
        if dance then
            local note = img('assets/images/bosses/groovecrab/note-Sheet.png')
            for j = 0, 3 do
                local q = (t * 0.7 + j / 4) % 1
                love.graphics.setColor(1, 1, 1, 1 - q)
                love.graphics.draw(note, frameQ(note, 9, (j * 2) % 8 + 1), floor(sc.cx - 80 + j * 52), floor(sc.cy - 30 - q * 70), 0, 3, 3)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
        if broken and t < 1.1 then Stage().flash(0.6 * (1 - (t - 0.9) / 0.2), 1, 0.95, 1) end
    end,
    -- (en pantalla, encima: el TROFEO, la bola de discoteca)
    overlay = function(sc, t)
        local u = k01(t, 5.2, 5.7)
        if u <= 0 then return end
        local x, y = floor(WINDOW_W / 2), floor(WINDOW_H / 2)
        Stage().rays(x, y, t * 2, 10, 160 * u, 0.3, { 1, 0.9, 1 })
        drawIcon('bola_disco', x, y + floor(sin(t * 3) * 4), 6 * u, 1)
    end,
    -- las astillas, de vuelta en sus monturas
    done = function(d)
        for _, id in ipairs(splinters()) do if d.collect[id] == 'stolen' then d.collect[id] = true end end
    end,
}
SM.SCENES = SCENES

-- ── Cuándo, y su vida ─────────────────────────────────────────────────────────────────────────────────────────────
-- La escena que toca ahora (o nil): la de un secreto con todo lo demás cumplido (Worlds `secrets` `scene`) o el
-- epílogo de un nivel ya superado (Worlds `epilogue`). → id, mundo y nodo del secreto que abre (si abre uno)
function SM._sceneDue()
    local d = Run.data
    if not d then return nil end
    d.films = d.films or {}
    for w = 1, Worlds.count() do
        for k, nd in ipairs(mapNodes(w)) do
            local sid = nd.secret and nd.def.scene
            if sid and SCENES[sid] and not d.films[sid] and not Run.isDone(nd.id) and Run.secretState(nd.def, true) == 'open' then
                return sid, w, k
            end
        end
        local ep = Worlds.get(w).epilogue
        if ep and SCENES[ep.scene] and not d.films[ep.scene] and Run.isDone(ep.after) then return ep.scene end
    end
    return nil
end

function SM:_sceneStart(id, w, k)
    local def = SCENES[id]
    local sc = { id = id, def = def, t = 0, fired = {}, w = w, k = k, map = self }
    def.enter(sc)
    local fx, fy = secretXY(def.focus)
    sc.fx, sc.fy = fx or self.heroX, fy or self.heroY
    self.scene = sc
end

-- Termina (o se salta): su efecto en la partida, apuntada como vista, guardada; si abre un secreto, se abre a la vista
function SM:_sceneEnd()
    local sc = self.scene
    if not sc then return end
    self.scene = nil
    -- (vista desde el FILM TEST: sin efectos en la partida — es de mentira — y vuelta a él)
    if self.sceneDone then local f = self.sceneDone; self.sceneDone = nil; f(); return end
    local d = Run.data
    if sc.def.done then sc.def.done(d) end
    d.films = d.films or {}
    d.films[sc.id] = true
    Run.save()
    if sc.w then
        self.opening = { [stopIndex(sc.w, sc.k)] = true }
        self.t, self.openSound, self.openAt = 0, true, P.SECRET_OPEN_AT
    end
end

-- (update: true = la escena manda en este fotograma — sin andar ni flechas —)
function SM:_sceneTick(dt)
    if not self.scene and self.forceScene then          -- (el FILM TEST: esa escena, ya)
        local id = self.forceScene
        self.forceScene = nil
        if SCENES[id] then self:_sceneStart(id) end
    end
    if not self.scene then
        local busy = #self.queue > 0 or self.flight or (next(self.opening or {}) ~= nil and self.t < (self.openAt or P.OPEN_AT) + 1.3)
        if busy or self.t < 0.5 then return false end
        local id, w, k = SM._sceneDue()
        if not id then return false end
        self:_sceneStart(id, w, k)
    end
    local sc = self.scene
    sc.t = sc.t + dt
    for i, c in ipairs(sc.def.cues or {}) do
        if not sc.fired[i] and sc.t >= c[1] then sc.fired[i] = true; c[2](sc) end
    end
    Stage().update(dt)
    -- la cámara, al sitio de la escena (como la del monstruo: centrada entre la cabecera y la ficha)
    local hx, hy = self.heroX, self.heroY
    self.heroX, self.heroY = sc.fx, sc.fy
    local tx, ty = self:_camTarget()
    self.heroX, self.heroY = hx, hy
    if not self.camX then self.camX, self.camY = tx, ty end
    local kk = math.min(1, dt * 4)
    self.camX, self.camY = self.camX + (tx - self.camX) * kk, self.camY + (ty - self.camY) * kk
    if sc.t >= sc.def.dur or Input.pressed('confirm') or Input.pressed('back') then self:_sceneEnd() end
    return true
end

-- (render: encima de todo lo del mapa, debajo de la cabecera; las franjas de cine tapan la cabecera y la ficha)
function SM:_drawScene(cx, cy)
    local sc = self.scene
    if not sc then return end
    love.graphics.push()
    love.graphics.translate(-cx, -cy)
    sc.def.draw(sc, sc.t)
    Stage().drawSparks()
    love.graphics.pop()
end
function SM:_drawSceneOver()
    local sc = self.scene
    if not sc then return end
    local a = math.min(1, sc.t / 0.4, (sc.def.dur - sc.t) / 0.4)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, 112)
    love.graphics.rectangle('fill', 0, WINDOW_H - 104, WINDOW_W, 104)
    love.graphics.setColor(1, 1, 1, 1)
    if sc.def.overlay then sc.def.overlay(sc, sc.t) end
end

-- (para las pruebas: la escena en curso)
function SM:_sceneNow() return self.scene and self.scene.id or nil, self.scene and self.scene.t or 0 end
end
