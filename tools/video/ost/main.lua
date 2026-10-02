-- tools/video/ost — VÍDEOS de presentación de la banda sonora: una escena del juego DE VERDAD
-- (la arena real del jefe, con su fondo, decoraciones y lo que se mueve) con el jefe en reposo y,
-- de vez en cuando, alguna de sus otras animaciones (rugido, pinzas...), SIN sonido suyo, y el
-- logo de Flappy Monster dando un botecito en cada pulso de la canción. La música se añade al
-- vídeo tal cual (el archivo del juego).
--
--   love tools/video/ost <jefe> [segundos]      jefe: megacrabby | megacrabby_ice | megagloomy
--   → $FM_PREVIEWS/videos/<pista>.mp4 (por defecto /home/mtvemo/FlappyMonster_pruebas/videos/)
--   tools/video/make_ost.sh                      los tres
--
-- Cómo: no se graba la pantalla; se dibuja fotograma a fotograma (30 fps, reloj virtual: lo que
-- anima con love.timer va al tiempo del vídeo) en un lienzo de 1280x720 y se le pasa en crudo a
-- ffmpeg por una tubería. El jefe hace su ENTRADA real al empezar (cae, ruge) y luego se queda en
-- reposo; cada 8 compases, un gesto; en el último cuarto de la canción se ENFADA. Para el Mega
-- Crabby lúgubre (arena a oscuras) cuelga del techo una BOMBILLA que se balancea al compás e
-- ilumina y oscurece la arena y al jefe; cada 16 compases FALLA y todo queda a oscuras 2 compases
-- (se ven solo los puntos luminosos del cangrejo).
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })   -- (el jefe, mudo)
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local Entity = require 'src/world/entities/Entity'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Particles = require 'src/fx/Particles'
local Sky = require 'src/fx/Sky'
local IceDrips = require 'src/fx/IceDrips'
local LavaFx = require 'src/fx/LavaFx'
local Snowfall = require 'src/fx/Snowfall'
local Darkness = require 'src/fx/Darkness'
local PixelFont = require 'src/ui/PixelFont'

local SHOWS = {
    megacrabby     = { level = 'assets/levels/guarida_cangrejo_rey.json', track = 'tentacle_nes', bpm = 185, title = 'CRAB TANTRUM (NES)', file = 'crab_tantrum_nes',
                       sub = 'MEGA CRABBY' },
    megacrabby_ice = { level = 'assets/levels/glaciar_cangrejo.json', track = 'tentacle_winter', bpm = 185, title = 'CRAB TANTRUM (WINTER)', file = 'crab_tantrum_winter',
                       sub = 'MEGA CRABBY HELADO' },
    megagloomy     = { level = 'assets/levels/gruta_lugubre.json', track = 'tentacle_gloomy', bpm = 150, title = 'CRAB TANTRUM (GLOOMY)', file = 'crab_tantrum_gloomy',
                       sub = 'MEGA CRABBY LÚGUBRE', bulb = true },
}
local FPS, W, H, T = 30, 1280, 720, TILE_PX
local vt = 0                                              -- reloj virtual (s de vídeo)
love.timer.getTime = function() return vt end
love.timer.getDelta = function() return 1 / FPS end

local show, level, es, boss, zone, player, ctl, canvas, scene, pipe, logo
local total, frameN, manual, emoteN, raged, lamp = 0, 0, false, 0, false, nil
local muxCmd

local function duration(path)
    local f = io.popen(('ffprobe -v error -show_entries format=duration -of csv=p=0 "%s"'):format(path))
    local d = tonumber(f:read('*a')); f:close()
    return d
end

function love.load(arg)
    show = assert(SHOWS[arg[1] or ''], 'jefe: megacrabby | megacrabby_ice | megagloomy')
    local audio = love.filesystem.getRealDirectory(show.level) and ('assets/music/' .. show.track .. '.ogg')
    local base = love.filesystem.getSource()
    local audioPath = base .. '/' .. audio
    total = tonumber(arg[2]) or duration(audioPath)
    WINDOW_W, WINDOW_H = W, H

    local data = json.decode(love.filesystem.read(show.level))
    level = Level.fromData(data)
    es = {}
    for _, pl in ipairs(level.entities) do es[#es + 1] = Entities.create(pl) end
    level.liveEntities = es
    BossZones.link(level, es)
    Particles.setLevel(level); Particles.clear()
    Entity.fx = function(kind, x, y, opts) Particles.emit(kind, x, y, opts) end
    for _, e in ipairs(es) do if e.def.boss then boss = e end end
    zone = level.bossZones[1]
    -- un jugador de pega, invisible, entra en la zona para que el jefe haga su ENTRADA de verdad
    player = PlayerAdventure:new(zone.x0 + 2.5 * T, zone.y1 - 60)
    level.players = { player }
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

    local out = (os.getenv('FM_PREVIEWS') or '/home/mtvemo/FlappyMonster_pruebas') .. '/videos'
    os.execute('mkdir -p "' .. out .. '"')
    local file = out .. '/' .. show.file .. '.mp4'
    -- En DOS pasos: primero solo la imagen (por la tubería) y, al acabar, se le pone la música. (En
    -- uno solo, con -shortest, ffmpeg terminaba el audio mucho antes de que llegaran los fotogramas
    -- y cortaba el vídeo a los pocos segundos.)
    local fade = math.max(0, total - 2)
    local silent = file .. '.video.mp4'
    pipe = assert(io.popen(('ffmpeg -v error -y -f rawvideo -pix_fmt rgba -s %dx%d -r %d -i - '
        .. '-vf "fade=t=in:st=0:d=0.6,fade=t=out:st=%.2f:d=2" -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p "%s"')
        :format(W, H, FPS, fade, silent), 'w'))
    muxCmd = ('ffmpeg -v error -y -i "%s" -t %.3f -i "%s" -af "afade=t=out:st=%.2f:d=2" -c:v copy -c:a aac -b:a 256k '
        .. '-movflags +faststart "%s" && rm -f "%s"'):format(silent, total, audioPath, fade, file, silent)
    print(('%s: %.1f s, %d fotogramas → %s'):format(show.track, total, math.floor(total * FPS), file))
end

-- ── Simulación (pasos de 1/60) ───────────────────────────────────────────────
local function beat() return 60 / show.bpm end
-- (los Megas, en 'recover': misma pose de reposo que 'ready', pero 'ready' es de la ENTRADA y ahí no se
-- dibuja el enfado — las esquirlas de hielo y los símbolos solo salían durante los gestos)
local IDLE = { megacrabby = 'recover', megacrabby_ice = 'recover', megagloomy = 'ready' }

local function emote()
    emoteN = emoteN + 1
    local name = boss.def.name
    if name == 'megagloomy' then
        local k = ({ 'ping', 'taunt', 'ping', 'roar' })[(emoteN - 1) % 4 + 1]
        boss.pinged = nil
        boss:enter(k)
        if k == 'roar' then Entity.emitFx('shake_roar', boss.x, boss.y) end
    else
        boss.restKind = ({ 2, 3, 1, 2, 1, 3 })[(emoteN - 1) % 6 + 1]      -- (pinzas, pincho, rugido...)
        boss.restFor = 1.8
        boss.state, boss.deadTimer = 'rest', 0
    end
end

local function enrage()
    raged = true
    if boss.def.name == 'megagloomy' then
        boss.rage, boss.phase = true, 3
        boss:enter('roar'); Entity.emitFx('shake_roar', boss.x, boss.y)
    else
        boss.hp = math.max(1, math.floor(boss.hpMax * 0.3))               -- (enfadado: símbolos, temblor, esquirlas)
        boss.restKind, boss.restFor = 1, 1.8
        boss.state, boss.deadTimer = 'rest', 0
    end
end

local lastBar = -1
local function step(dt)
    for k in pairs(Input.state) do Input.state[k] = false end
    level.solidBodies = Entities.solidBodies(es)
    if not manual then
        player:update(dt, level)
        ctl:update(dt)
        -- la entrada ha terminado y empieza la pelea: a partir de aquí lo llevamos nosotros
        if zone.state == 'fight' and boss.state ~= 'intro' and boss.state ~= 'ready' and boss.state ~= 'fall_in'
           and boss.state ~= 'land_in' and boss.state ~= 'roar_in' and boss.state ~= 'dormant' then
            manual = true
            level.players = {}
            if boss.def.name == 'megagloomy' then boss:stand(level, boss.x) end
            boss.state, boss.deadTimer = IDLE[boss.def.name], 10
        end
    end
    level:update(dt); level:updateFoliage(dt)
    for _, e in ipairs(es) do
        if e ~= boss and (e.alive or e.summonOf) then e:update(dt, level) end
    end
    if not manual then
        boss:update(dt, level)
    else
        local st = boss.state
        if st == IDLE[boss.def.name] then
            if boss.updatePings then boss:updatePings(nil, dt) end
        else
            boss:update(dt, level)                               -- (el gesto, con sus efectos de verdad)
            st = boss.state
            if st == 'chase' or st == 'prowl' or st == 'fight' or (st == 'recover' and IDLE[boss.def.name] ~= 'recover') then
                boss.state, boss.deadTimer = IDLE[boss.def.name], 10
                boss.vx = 0
            end
        end
        -- gestos: uno cada 8 compases; en el último cuarto, se enfada
        local bar = math.floor(vt / (beat() * 4))
        if bar ~= lastBar and boss.state == IDLE[boss.def.name] then
            lastBar = bar
            if not raged and vt >= total * 0.74 then enrage()
            elseif bar % 8 == 4 then emote() end
        end
    end
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

local function drawLogo()
    -- botecito en cada pulso: crece de golpe y vuelve; en el primero de cada compás, un poco más
    local b = vt / beat()
    local ph = b - math.floor(b)
    local strong = math.floor(b) % 4 == 0
    local k = math.exp(-ph * 7)
    local s = 5 * (1 + (strong and 0.16 or 0.09) * k)
    local rot = (strong and 0.035 or 0.02) * k * ((math.floor(b) % 2 == 0) and 1 or -1)
    local cx, cy = W / 2, 74 - 6 * k
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.draw(logo, cx + 4, cy + 4, rot, s, s, logo:getWidth() / 2, logo:getHeight() / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(logo, cx, cy, rot, s, s, logo:getWidth() / 2, logo:getHeight() / 2)
    -- la pista
    local a = math.min(1, math.max(0, (vt - 0.8) / 0.8))
    PixelFont.shadow(show.title, 28, H - 62, 3, a)
    PixelFont.shadow(show.sub .. '  ·  FLAPPY MONSTER OST', 28, H - 34, 2, 0.8 * a)
end

local function render()
    local shx, shy = Particles.shakeOffset()
    local camX = math.floor((zone.x0 + zone.x1) / 2 - W / 2 + shx + 0.5)
    local camY = math.floor(math.min(level.tileH * T - H, zone.y1 + 1.5 * T - H) + shy + 0.5)
    local bulbBody, bulbGlow
    if lamp then bulbBody, bulbGlow = drawBulb(camX, camY) end
    love.graphics.setCanvas(scene)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    Sky.render(level, camX, camY)
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
    if level.dark then
        Darkness.render(level, camX, camY, {})
        Darkness.renderGlow(level, es, camX, camY)
    end
    if bulbGlow then bulbGlow() end
    drawLogo()
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
    frameN = frameN + 1
    if frameN % 300 == 0 then print(('  %d s / %d s'):format(frameN / FPS, total)) end
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, 0.25, 0.25)
end
