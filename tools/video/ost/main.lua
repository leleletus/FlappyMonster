-- tools/video/ost — VÍDEOS de presentación de la banda sonora (2ª versión, con la banda sonora definitiva): cada
-- tema de jefe sobre una MINIATURA VIVA de su pelea — la arena real del jefe, con su fondo, su luz y sus cosas, y el
-- jefe haciendo lo suyo (anda, trepa, carga, salta, rueda, se teletransporta...), sin sonido suyo —, el logo de
-- Flappy Monster botando en cada pulso, un rótulo con la pista y un VISUALIZADOR de barras que reacciona a la música
-- y marca por dónde va la canción.
--
--   love tools/video/ost <jefe> [segundos]   jefe: megagummy | megacrabby | miniboss1 | snowboss | megacrabby_ice |
--                                                  megagloomy | mirror
--   → $FM_PREVIEWS/videos/<pista>.mp4 (por defecto /home/mtvemo/FlappyMonster_pruebas/videos/)
--   tools/video/make_ost.sh                  todos
--
-- Cómo: no se graba la pantalla; se dibuja fotograma a fotograma (30 fps, reloj virtual: lo que anima con love.timer
-- va al tiempo del vídeo) en un lienzo de 1280x720 que se pasa en crudo a ffmpeg por una tubería.
--   · MÚSICA: la intro y el bucle de la pista (los archivos del juego), seguidos, UNA vez; el vídeo dura eso y se
--     acaba donde acaba la pista, sin fundido.
--   · EL JEFE corre con su IA DE VERDAD: un jugador de pega, INVISIBLE e inmortal (el "señuelo"), pasea por el centro
--     de la arena y el jefe le hace lo que le haría a un jugador. Va a un ritmo algo más lento que en el juego (PACE)
--     y no hay nadie que le pegue; para que enseñe lo que hace más adelante en la pelea, su vida BAJA SOLA con la
--     canción (fases de la Bola de Nieve, guardia del Rey Gummy, rabia de los Mega Crabbies, fases del Espejo).
--   · VISUALIZADOR: tools/video/spectrum.py saca el espectro de la pista por fotograma; las barras ya "sonadas" van
--     encendidas y las demás apagadas (la propia fila de barras es la barra de progreso), más el tiempo en cifras.
--   · Mega Crabby lúgubre (arena a oscuras): la BOMBILLA que cuelga del techo y se balancea al compás, con sus apagones.
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
love.graphics.setDefaultFilter('nearest', 'nearest')      -- (como game.lua: sin esto, los sprites que no fijan su filtro — el
                                                          -- Espejo, que dibuja un jugador — salían BORROSOS)
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })   -- (el jefe, mudo)
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Entity = require 'src/world/entities/Entity'
local BossZones = require 'src/world/BossZones'
local Floods = require 'src/world/Floods'
local Noise = require 'src/world/Noise'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Particles = require 'src/fx/Particles'
local Sky = require 'src/fx/Sky'
local IceDrips = require 'src/fx/IceDrips'
local LavaFx = require 'src/fx/LavaFx'
local Snowfall = require 'src/fx/Snowfall'
local Darkness = require 'src/fx/Darkness'
local PixelFont = require 'src/ui/PixelFont'

-- TEXTOS EN INGLÉS (los vídeos se comparten en inglés): título de la pista y nombre del jefe como en assets/lang/en.lua.
-- bpm = pulsos por minuto del logo; hp = { fracción de la canción, fracción de vida } (la vida baja sola)
local SHOWS = {
    megagummy      = { level = 'assets/levels/reino_gummy.json', track = 'gummy_king_boss', bpm = 148, title = 'HIS MAJESTY GUMMY',
                       sub = 'GUMMY KING', color = { 1, 0.82, 0.3 }, phase2 = 0.45 },
    megacrabby     = { level = 'assets/levels/guarida_cangrejo_rey.json', track = 'crab_tantrum_normal', bpm = 186, title = 'CRAB TANTRUM',
                       sub = 'MEGA CRABBY', color = { 1, 0.55, 0.3 }, hp = { { 0.68, 0.3 } } },
    miniboss1      = { level = 'assets/levels/fortaleza_malvada.json', track = 'evil_ship_boss', bpm = 160, title = 'PURSUIT',
                       sub = 'EVIL MONSTER', color = { 0.75, 0.5, 1 }, noBreak = true, flooded = true },
    snowboss       = { level = 'assets/levels/lago_helado.json', track = 'snowball_boss', bpm = 168, title = 'THE BIG SNOWBALL',
                       sub = 'BIG SNOWBALL', color = { 0.6, 0.85, 1 }, hp = { { 0.34, 0.6 }, { 0.67, 0.3 } } },
    megacrabby_ice = { level = 'assets/levels/glaciar_cangrejo.json', track = 'crab_tantrum_icy', bpm = 186, title = 'CRAB TANTRUM (ICY)',
                       sub = 'ICY MEGA CRABBY', color = { 0.55, 0.85, 1 }, hp = { { 0.68, 0.3 } } },
    megagloomy     = { level = 'assets/levels/gruta_lugubre.json', track = 'crab_tantrum_gloomy', bpm = 144, title = 'CRAB TANTRUM (GLOOMY)',
                       sub = 'MEGA GLOOMY CRABBY', color = { 0.7, 0.6, 1 }, bulb = true, rage = 0.7 },
    mirror         = { level = 'assets/levels/ruta_del_espejo.json', track = 'mirror_boss', bpm = 158, title = 'THE MIRROR',
                       sub = 'MIRROR  ·  FINAL BOSS', color = { 1, 0.35, 0.4 }, hp = { { 0.34, 0.6 }, { 0.67, 0.3 } }, laugh = 22, lively = true },
}
local FPS, W, H, T = 30, 1280, 720, TILE_PX
local PACE = 0.85                                         -- el jefe, un poco más despacio que en el juego
local NB = 64                                             -- barras del visualizador
local vt = 0                                              -- reloj virtual (s de vídeo)
love.timer.getTime = function() return vt end
love.timer.getDelta = function() return 1 / FPS end

local show, level, es, boss, zone, lure, ctl, canvas, scene, pipe, logo
local total, frameN, lamp, spectrum = 0, 0, nil, {}
local SAFE = {}
local muxCmd

local function sh(cmd) local f = io.popen(cmd); local s = f:read('*a'); f:close(); return s end

function love.load(arg)
    show = assert(SHOWS[arg[1] or ''], 'jefe: megagummy | megacrabby | miniboss1 | snowboss | megacrabby_ice | megagloomy | mirror')
    show.id = arg[1]
    local base = love.filesystem.getSource() .. '/'
    local out = (os.getenv('FM_PREVIEWS') or '/home/mtvemo/FlappyMonster_pruebas') .. '/videos'
    os.execute('mkdir -p "' .. out .. '"')
    -- LA PISTA: intro + bucle, seguidos (del catálogo de música del juego)
    local idx = json.decode(love.filesystem.read('assets/music/index.json'))
    local tr
    for _, t in ipairs(idx.tracks) do if t.id == show.track then tr = t end end
    assert(tr, 'pista ' .. show.track)
    local wav = out .. '/' .. show.track .. '.tmp.wav'
    local M = base .. 'assets/music/'
    if tr.intro then
        os.execute(('ffmpeg -v error -y -i "%s" -i "%s" -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" "%s"'):format(M .. tr.intro, M .. tr.loop, wav))
    else
        os.execute(('ffmpeg -v error -y -i "%s" "%s"'):format(M .. (tr.file or tr.loop), wav))
    end
    local full = tonumber(sh(('ffprobe -v error -show_entries format=duration -of csv=p=0 "%s"'):format(wav)))
    total = tonumber(arg[2]) or full
    -- el espectro, por fotograma
    local spec = out .. '/' .. show.track .. '.tmp.txt'
    local py = os.getenv('FM_PYTHON') or (os.getenv('HOME') .. '/.venvs/fm-music/bin/python')
    os.execute(('"%s" "%s" "%s" %d %d "%s"'):format(py, base .. '../spectrum.py', wav, FPS, NB, spec))
    local f = io.open(spec, 'r')
    if f then
        for line in f:lines() do
            local row = {}
            for n in line:gmatch('%d+') do row[#row + 1] = tonumber(n) / 99 end
            spectrum[#spectrum + 1] = row
        end
        f:close(); os.remove(spec)
    end
    WINDOW_W, WINDOW_H = W, H
    love.math.setRandomSeed(7); math.randomseed(7)

    local data = json.decode(love.filesystem.read(show.level))
    level = Level.fromData(data)
    if show.noBreak then level.canBreak = false end           -- (la Nave no se come el suelo de la arena)
    es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    Noise.bind(level)
    Particles.setLevel(level); Particles.clear()
    Entity.fx = function(kind, x, y, opts) Particles.emit(kind, x, y, opts) end
    for _, e in ipairs(es) do if e.def.boss and not e.summonOf then boss = boss or e end end
    zone = boss.zone or level.bossZones[1]
    for _, z in ipairs(level.bossZones) do
        if boss.x >= z.x0 and boss.x <= z.x1 and boss.y >= z.y0 and boss.y <= z.y1 then zone = z end
    end
    -- el SEÑUELO: un jugador de pega, invisible e inmortal; entra en la zona y el jefe hace su entrada de verdad
    -- CASILLAS SEGURAS para el señuelo: las del SUELO principal de la arena (la fila con más casillas donde se puede
    -- estar de pie), sin hielo fino ni agua, y dentro de lo que se ve. Solo pasea por ellas; si se queda atascado (metido
    -- en un escalón, en una poza, empujado contra una pared), vuelve a una de golpe — es invisible —. Antes entraba por
    -- una esquina y a veces se quedaba dentro del escenario: el jefe se pasaba el vídeo atacando una pared.
    local cxz = (zone.x0 + zone.x1) / 2
    local halfV = math.min((zone.x1 - zone.x0) / 2 - 2.5 * T, W / 2 - 4 * T)
    local rows = {}
    for r = math.floor(zone.y0 / T) + 1, math.floor(zone.y1 / T) + 1 do
        for c = math.floor(zone.x0 / T) + 2, math.floor(zone.x1 / T) do
            local x, y = (c - 0.5) * T, (r - 0.5) * T
            if math.abs(x - cxz) <= halfV and level:isStandable(c, r) and not level:liquidAt(x, y) then
                local under = level:getDefAt(x, y + T)
                if not tostring(under.name):find('thin_ice') then
                    rows[r] = rows[r] or {}
                    table.insert(rows[r], { x = x, y = y })
                end
            end
        end
    end
    local best
    for r, list in pairs(rows) do if not best or #list > #rows[best] or (#list == #rows[best] and r > best) then best = r end end
    SAFE = rows[best] or { { x = cxz, y = zone.y1 - 60 } }
    table.sort(SAFE, function(a, b) return math.abs(a.x - cxz) < math.abs(b.x - cxz) end)
    -- (durante la ENTRADA del jefe el señuelo espera en la casilla segura más a la IZQUIERDA, no en el centro: los Mega
    -- Crabbies caen en su sitio — el centro — solo si no hay un jugador cerca; con el señuelo en medio caían en una esquina)
    local first = SAFE[1]
    for _, c in ipairs(SAFE) do if c.x < first.x then first = c end end
    lure = PlayerAdventure:new(first.x, first.y)
    lure.immortal = true
    lure.brain = { wait = 1.5, tx = first.x, stuck = 0, lastX = 0, bad = 0 }
    level.players = { lure }
    ctl = BossZones.newController(level, es)

    canvas = love.graphics.newCanvas(W, H)
    scene = love.graphics.newCanvas(W, H)
    logo = love.graphics.newImage('assets/images/menus/logo.png'); logo:setFilter('nearest', 'nearest')
    if show.bulb then
        lamp = { px = (zone.x0 + zone.x1) / 2, py = zone.y0 + 8, len = 4.6 * T, lights = {} }
        for _, l in ipairs({ { 620, 0.4 }, { 440, 0.7 }, { 260, 1.0 } }) do    -- (tres luces a la vez: una bombilla con caída suave)
            local d = { x = 0, y = 0, animT = 0, flip = 1, layer = 'none',
                        def = { cullMargin = 0, draw = function() end, light = { r = l[1], a = l[2], color = { 1, 0.9, 0.7 }, dy = 0, pulse = 0 } } }
            lamp.lights[#lamp.lights + 1] = d
            level.decorations[#level.decorations + 1] = d
        end
    end

    local file = out .. '/' .. show.track .. '.mp4'
    -- En DOS pasos: primero solo la imagen (por la tubería) y, al acabar, se le pone la música. SIN fundido de salida:
    -- el vídeo y la música se acaban donde se acaba la pista.
    local silent = file .. '.video.mp4'
    pipe = assert(io.popen(('ffmpeg -v error -y -f rawvideo -pix_fmt rgba -s %dx%d -r %d -i - '
        .. '-vf "fade=t=in:st=0:d=0.5" -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p "%s"')
        :format(W, H, FPS, silent), 'w'))
    muxCmd = ('ffmpeg -v error -y -i "%s" -t %.3f -i "%s" -c:v copy -c:a aac -b:a 256k -movflags +faststart "%s" && rm -f "%s" "%s"')
        :format(silent, total, wav, file, silent, wav)
    print(('%s: %.1f s, %d fotogramas → %s'):format(show.track, total, math.floor(total * FPS), file))
end

-- ── El señuelo: pasea por el centro de la arena, se para, salta de vez en cuando ─────────────────────────────
local function lureBits(dt)
    local b = lure.brain
    if zone.state ~= 'fight' then return 0 end                -- (quieto hasta que acaba la entrada del jefe)
    -- ¿atascado o fuera de sitio? (dentro de un bloque, en el agua, lejos de su suelo, sin poder avanzar): a una casilla segura
    local home = SAFE[1]
    local off = math.abs(lure.y - home.y) > 2.2 * T and lure.onGround
    local wet = level:liquidAt(lure.x, lure.y) and not show.flooded
    local inside = level:collisionAt(lure.x, lure.y)
    if off or wet or inside or b.stuck > 1.0 then b.bad = b.bad + dt else b.bad = math.max(0, b.bad - dt) end
    if inside or b.bad > 0.8 then
        local c = SAFE[love.math.random(math.min(#SAFE, 6))]
        lure.x, lure.y, lure.vx, lure.vy = c.x, c.y, 0, 0
        b.bad, b.stuck, b.wait, b.tx = 0, 0, 0.8, c.x
        RESCUES = (RESCUES or 0) + 1
        return 0
    end
    if b.wait > 0 then
        b.wait = b.wait - dt
        if b.wait <= 0 then
            b.tx = SAFE[love.math.random(#SAFE)].x
            b.jump = love.math.random() < (show.lively and 0.6 or 0.25)
        end
        return 0
    end
    local dx = b.tx - lure.x
    if math.abs(dx) < 14 then
        b.wait = show.lively and (0.6 + love.math.random() * 1.6) or (1.5 + love.math.random() * 3)
        b.stuck = 0
        return 0
    end
    local bits = (dx < 0) and P.IN_LEFT or P.IN_RIGHT
    if math.abs(lure.x - b.lastX) < 0.5 then b.stuck = b.stuck + dt else b.stuck = 0 end
    b.lastX = lure.x
    if lure.onGround and (b.jump or (b.stuck > 0.3 and (b.hold or 0) <= 0)) then
        bits = bits + P.IN_JUMP + P.IN_JUMP_P
        b.jump, b.hold = false, 0.25
    elseif (b.hold or 0) > 0 then
        b.hold = b.hold - dt; bits = bits + P.IN_JUMP
    end
    return bits
end

-- ── Simulación (pasos de 1/60): la pelea de verdad, con el señuelo ───────────────────────────────────────────
local function beat() return 60 / show.bpm end
local hpStep, raged, laughAt = 0, false, nil

local function progress(k)
    -- la vida del jefe baja sola con la canción (sin golpes): así enseña sus fases
    for i, s in ipairs(show.hp or {}) do
        if i > hpStep and k >= s[1] and boss.hpMax then
            hpStep = i
            boss.hp = math.max(1, math.floor(boss.hpMax * s[2]))
        end
    end
    if show.phase2 and not raged and k >= show.phase2 and boss.phase2Hp then
        raged = true
        boss.hp = math.min(boss.hp, math.floor(boss:phase2Hp()))
    end
    if show.rage and not raged and k >= show.rage and (boss.state == 'prowl' or boss.state == 'walk' or boss.state == 'tired') then
        raged = true
        boss.rage, boss.phase = true, 3
        boss:enter('roar'); Entity.emitFx('shake_roar', boss.x, boss.y)
    end
    if show.laugh and zone.state == 'fight' then
        laughAt = laughAt or (vt + show.laugh * 0.6)
        if vt >= laughAt then laughAt = vt + show.laugh; if boss.onPlayerDeath then boss:onPlayerDeath(lure) end end
    end
end

local function step(dt)
    P.decodeInput(lureBits(dt), Input.state)
    level.players = { lure }
    level.solidBodies = Entities.solidBodies(es)
    lure:update(dt, level)
    if lure.dying or lure.alive == false then                 -- (por si acaso: vuelve al centro)
        lure:respawn(); lure.x, lure.y = (zone.x0 + zone.x1) / 2, zone.y1 - 60
    end
    lure.hp = lure.hpMax
    for k in pairs(Input.state) do Input.state[k] = false end
    Floods.advance(level, dt)
    level:update(dt); level:updateFoliage(dt)
    for _, e in ipairs(es) do
        if e.alive or e.summonOf then
            e:update((e.def.category == 'Jefes') and dt * PACE or dt, level)
        end
    end
    ctl:update(dt)
    if zone.state == 'fight' then progress(vt / total) end
    Particles.update(dt)
end

-- ── Dibujo ───────────────────────────────────────────────────────────────────
local function drawBulb(camX, camY)
    -- péndulo: un vaivén completo cada 8 pulsos
    local a = 0.62 * math.sin(vt * 2 * math.pi / (beat() * 8))
    local bx, by = lamp.px + math.sin(a) * lamp.len, lamp.py + math.cos(a) * lamp.len
    -- APAGONES: cada 16 compases la bombilla falla — parpadea, se queda a oscuras 2 compases (solo se ven
    -- los puntos luminosos del cangrejo) y vuelve parpadeando
    local barLen = beat() * 4
    local pos = (vt / barLen) % 16
    local on = 1
    if pos >= 12 and pos < 14 then on = 0
    elseif pos >= 11.6 and pos < 12 then on = (math.floor(vt * 22) % 3 == 0) and 0.15 or 1        -- parpadeo antes de irse
    elseif pos >= 14 and pos < 14.3 then on = (math.floor(vt * 22) % 2 == 0) and 1 or 0.1 end     -- … y al volver
    -- … y de vez en cuando, sin patrón, TITILA: un rato corto en el que la luz baja a saltos
    local function rnd(n) local x = math.sin(n * 127.1 + 311.7) * 43758.5453; return x - math.floor(x) end
    local ep = math.floor(vt / 0.8)
    if on == 1 and rnd(ep) < 0.16 then
        on = 0.5 + 0.5 * rnd(math.floor(vt * 18) + ep * 7.3)
    end
    for _, d in ipairs(lamp.lights) do
        d.x, d.y = bx, by + 14
        d.def.light.a0 = d.def.light.a0 or d.def.light.a
        d.def.light.a = d.def.light.a0 * on
    end
    -- Dos partes: el cable y la bombilla se dibujan ANTES de la oscuridad (les afecta la luz como a todo:
    -- apagada, casi no se ven); después, solo lo que BRILLA (el filamento y su halo), según lo encendida que esté
    local sx, sy = math.floor(lamp.px - camX), math.floor(lamp.py - camY)
    local ex, ey = math.floor(bx - camX), math.floor(by - camY)
    local function body()
        love.graphics.setColor(0.5, 0.5, 0.56, 1)
        for i = 0, 24 do                                         -- el cable, a trocitos (píxel)
            local k = i / 24
            love.graphics.rectangle('fill', math.floor(sx + (ex - sx) * k) - 1, math.floor(sy + (ey - sy) * k) - 1, 4, 4)
        end
        love.graphics.setColor(0.42, 0.42, 0.48, 1); love.graphics.rectangle('fill', ex - 8, ey - 4, 16, 12)      -- casquillo
        love.graphics.setColor(0.25, 0.25, 0.3, 1); love.graphics.rectangle('fill', ex - 8, ey + 4, 16, 4)
        love.graphics.setColor(0.75, 0.72, 0.6, 1); love.graphics.rectangle('fill', ex - 10, ey + 8, 20, 20)     -- el cristal
        love.graphics.rectangle('fill', ex - 6, ey + 28, 12, 4)
        love.graphics.setColor(1, 1, 1, 1)
    end
    local function glow()
        if on <= 0.02 then return end
        love.graphics.setColor(1, 0.93, 0.6, on); love.graphics.rectangle('fill', ex - 10, ey + 8, 20, 20)
        love.graphics.rectangle('fill', ex - 6, ey + 28, 12, 4)
        love.graphics.setColor(1, 1, 0.92, on); love.graphics.rectangle('fill', ex - 6, ey + 12, 8, 8)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(1, 0.85, 0.5, 0.18 * on); love.graphics.rectangle('fill', ex - 18, ey, 36, 36)
        love.graphics.setBlendMode('alpha')
        love.graphics.setColor(1, 1, 1, 1)
    end
    return body, glow
end

local function clock(s)
    s = math.max(0, math.floor(s))
    return ('%d:%02d'):format(math.floor(s / 60), s % 60)
end

local camF, logoA = nil, 1
local BAND_H = 124                                            -- el rótulo: una franja abajo
local overlayCam
local function drawOverlay()
    -- LOGO: arriba a la IZQUIERDA (en el centro tapaba al jefe cuando subía a las plataformas, y a la Nave siempre), con su
    -- botecito en cada pulso; si aun así el jefe pasa por detrás, se transparenta mientras tanto
    local b = vt / beat()
    local ph = b - math.floor(b)
    local strong = math.floor(b) % 4 == 0
    local k = math.exp(-ph * 7)
    local s = 6 * (1 + (strong and 0.15 or 0.08) * k)
    local rot = (strong and 0.035 or 0.02) * k * ((math.floor(b) % 2 == 0) and 1 or -1)
    local lw, lh = logo:getWidth() * 6, logo:getHeight() * 6
    local cx, cy = 34 + lw / 2, 30 + lh / 2 - 6 * k
    local hidden = false
    if boss and boss.alive and overlayCam then
        local bb = boss:getOuterBounds()
        local x0, y0 = bb.x - overlayCam[1], bb.y - overlayCam[2]
        hidden = x0 < cx + lw / 2 + 30 and x0 + bb.w > cx - lw / 2 - 30 and y0 < cy + lh / 2 + 30 and y0 + bb.h > cy - lh / 2 - 30
    end
    logoA = logoA + ((hidden and 0.16 or 1) - logoA) * 0.18
    love.graphics.setColor(0, 0, 0, 0.55 * logoA)
    love.graphics.draw(logo, cx + 5, cy + 5, rot, s, s, logo:getWidth() / 2, logo:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, logoA)
    love.graphics.draw(logo, cx, cy, rot, s, s, logo:getWidth() / 2, logo:getHeight() / 2)
    -- RÓTULO: franja oscura con su filo, la pista, el jefe y el tiempo
    local a = math.min(1, math.max(0, (vt - 0.4) / 0.6))
    local y0 = H - BAND_H
    local col = show.color
    love.graphics.setColor(0, 0, 0, 0.72 * a); love.graphics.rectangle('fill', 0, y0, W, BAND_H)
    love.graphics.setColor(col[1], col[2], col[3], 0.9 * a); love.graphics.rectangle('fill', 0, y0, W, 4)
    love.graphics.setColor(0, 0, 0, 0.5 * a); love.graphics.rectangle('fill', 0, y0 + 4, W, 2)
    PixelFont.draw(show.title, 28, y0 + 16, 4, a)
    PixelFont.draw(show.sub .. '  ·  FLAPPY MONSTER OST', 28, y0 + 46, 2, 0.75 * a, col)
    local tx = clock(vt) .. ' / ' .. clock(total)
    PixelFont.draw(tx, W - 28 - PixelFont.width(tx, 3), y0 + 18, 3, 0.9 * a)
    -- VISUALIZADOR: barras del espectro; las ya sonadas, encendidas (es también la barra de progreso)
    local row = spectrum[math.min(#spectrum, frameN + 1)] or {}
    local x0, x1, yb, hmax = 28, W - 28, H - 14, 46
    local bw = (x1 - x0) / NB
    local done = vt / total
    love.graphics.setColor(1, 1, 1, 0.12 * a); love.graphics.rectangle('fill', x0, yb, x1 - x0, 3)
    love.graphics.setColor(col[1], col[2], col[3], a); love.graphics.rectangle('fill', x0, yb, math.floor((x1 - x0) * done), 3)
    for i = 1, NB do
        local v = row[i] or 0
        local hgt = math.max(2, math.floor(v * hmax / 2) * 2)
        local bx = math.floor(x0 + (i - 1) * bw)
        local played = (i - 0.5) / NB <= done
        if played then love.graphics.setColor(col[1], col[2], col[3], (0.55 + 0.45 * v) * a)
        else love.graphics.setColor(1, 1, 1, (0.16 + 0.3 * v) * a) end
        love.graphics.rectangle('fill', bx + 1, yb - 3 - hgt, math.floor(bw) - 2, hgt)
    end
    -- el cursor de la canción
    local mx = math.floor(x0 + (x1 - x0) * done)
    love.graphics.setColor(1, 1, 1, a); love.graphics.rectangle('fill', mx - 2, yb - 3, 4, 9)
    love.graphics.setColor(1, 1, 1, 1)
end

local function render()
    local shx, shy = Particles.shakeOffset()
    -- (arena más ANCHA que la pantalla — la de la Bola de Nieve —: la cámara sigue al jefe, suave, sin salirse de la zona)
    local fx = (zone.x0 + zone.x1) / 2 - W / 2
    if zone.x1 - zone.x0 > W then
        local want = math.max(zone.x0 - T, math.min(zone.x1 + T - W, boss.x - W / 2))
        camF = camF and (camF + (want - camF) * 0.06) or want
        fx = camF
    end
    local camX = math.floor(fx + shx + 0.5)
    -- (la franja del rótulo tapa lo de abajo: la arena se sube para que su suelo quede a la vista)
    local camY = math.floor(math.min(level.tileH * T - H, zone.y1 + 1.5 * T - H) + (BAND_H - 1.2 * T) + shy + 0.5)
    local bulbBody, bulbGlow
    if lamp then bulbBody, bulbGlow = drawBulb(camX, camY) end
    love.graphics.setCanvas(scene)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    Sky.punch = Darkness.active(level) and not level.dark
    Sky.render(level, camX, camY)
    Sky.punch = false
    level:render(camX, camY)
    IceDrips.render(level, camX, camY)
    LavaFx.render(level, camX, camY)
    level:renderVents(camX, camY)
    level:renderFoliageBack(camX, camY)
    for _, e in ipairs(es) do if e.alive and not e.renderFront then e:render(camX, camY) end end
    Particles.render(camX, camY)
    for _, e in ipairs(es) do if e.alive and e.renderFront then e:render(camX, camY) end end
    level:renderFoliage(camX, camY)
    level:renderBubbles(camX, camY)
    Snowfall.render(level, camX, camY)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    level:renderWaterEffect(camX, camY, scene)
    if bulbBody then bulbBody() end
    if Darkness.active(level) then
        Darkness.render(level, camX, camY, {}, es, scene)
        Darkness.renderGlow(level, es, camX, camY)
    end
    if bulbGlow then bulbGlow() end
    overlayCam = { camX, camY }
    drawOverlay()
    love.graphics.setCanvas()
end

function love.update()
    if frameN >= math.floor(total * FPS) then
        pipe:close()
        os.execute(muxCmd)
        print('hecho')
        love.event.quit(0)
        return
    end
    step(1 / 60); vt = vt + 1 / 60
    step(1 / 60); vt = vt + 1 / 60
    love.graphics.origin()
    render()
    pipe:write(canvas:newImageData():getString())
    if os.getenv('SHOT') and frameN == tonumber(os.getenv('SHOT')) then
        canvas:newImageData():encode('png', 'ost_' .. show.id .. '.png')
    end
    frameN = frameN + 1
    if frameN % 300 == 0 then print(('  %d s / %d s · jefe: %s (x %d) · señuelo x %d, rescates %d'):format(frameN / FPS, total, tostring(boss.state), boss.x - zone.x0, lure.x - zone.x0, RESCUES or 0)) end
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, 0.25, 0.25)
end
