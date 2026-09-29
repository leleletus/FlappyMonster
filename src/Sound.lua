-- src/Sound.lua
local Music = require 'src/Music'
local Sound = {}

local sources = {}
local music   = nil
local tracked = {}   -- fuentes rastreadas para stop/isPlaying individuales
local loops   = {}   -- name -> fuente del bucle de las pistas con intro (Sound.loadMusic)
local levelMusic = nil   -- pista que MANDA cuando se pide 'level' (p. ej. la del jefe)
local baseLevelMusic = nil   -- música del nivel actual (su campo "music"; nil = la de siempre)
local trackVol = {}          -- id -> volumen de la pista (assets/music/index.json)
local origin  = {}   -- name -> ruta del archivo de cada sonido
Sound._origin = origin

-- ── Mezcla ────────────────────────────────────────────────────────────────────
-- Ganancia por sonido para que todos se oigan parecido (medido: volumen del
-- tramo más fuerte de 100 ms ≈ -12 dBFS, como el salto o el punto). Se aplica
-- al cargar (se escalan las muestras), así se puede subir por encima de 1.
-- Los sonidos cortos de interfaz y pasos se dejan como están a propósito.
-- (Los efectos que antes se sintetizaban por código ya llevan su ganancia
-- dentro del archivo: no se ponen aquí o se aplicaría dos veces.)
local GAIN = {
    roundOver    = 2.8,  spikeHit   = 2.2,  dies2      = 0.65, glugluglu  = 0.8,
    airGasp      = 0.85, waterWarning = 1.4,
    -- Mega Crabby (archivos ya comprimidos: subir poco por encima de 1 satura)
    megaStep     = 0.9,  megaClack  = 1.0,  megaHurt   = 1.1,  megaSlam   = 1.1,
    megaWindup   = 0.85, megaShrink = 0.8,  megaFlee   = 0.9,
    -- tools/sounds/mechanics.py (medidos: → ≈ -12 dBFS)
    switchOn     = 0.77, switchOff  = 0.76, helmetBounce = 1.15, helmetBreak = 0.72,
    pufferWarn   = 1.0,  pufferInflate = 0.81, pufferDeflate = 0.77, pufferPrick = 0.67,
}
Sound.GAIN = GAIN

local function scaled(sd, g)
    if not g or g == 1 then return sd end
    local ch, n = sd:getChannelCount(), sd:getSampleCount()
    for i = 0, n - 1 do
        for c = 1, ch do
            local v = sd:getSample(i, c) * g
            sd:setSample(i, c, v > 1 and 1 or (v < -1 and -1 or v))
        end
    end
    return sd
end

local function load(name, path, stype)
    local g = GAIN[name]
    if g and g ~= 1 and stype == 'static' then
        -- Ganancia horneada en las muestras
        local ok, sd = pcall(love.sound.newSoundData, path)
        if ok then
            sources[name] = love.audio.newSource(scaled(sd, g), 'static')
            origin[name]  = path
            return
        end
    end
    local ok, result = pcall(love.audio.newSource, path, stype)
    if ok then
        sources[name] = result
        origin[name]  = path
    else
        sources[name] = nil
        print("[Sound] No se encontró: " .. path)
    end
end

function Sound.load()
    -- Efectos chiptune (antes sintetizados por código; ahora archivos
    -- normales, organizados por tipo en assets/sounds/)
    load('gpStart',     'assets/sounds/player/ground_pound_start.wav',  'static')
    load('gpImpact',    'assets/sounds/player/ground_pound_impact.wav', 'static')
    load('headBump',    'assets/sounds/player/head_bump.wav',           'static')
    load('stunned',     'assets/sounds/player/stunned.wav',             'static')
    load('collect',     'assets/sounds/items/collect.wav',              'static')
    load('oneUp',       'assets/sounds/items/one_up.wav',               'static')
    load('checkpoint',  'assets/sounds/items/checkpoint.wav',           'static')
    load('blockBreak',  'assets/sounds/traps/block_break.wav',          'static')
    load('switchOn',    'assets/sounds/mechanics/switch_on.wav',        'static')   -- bloque ON/OFF → ON
    load('switchOff',   'assets/sounds/mechanics/switch_off.wav',       'static')   -- bloque ON/OFF → OFF
    load('helmetBreak', 'assets/sounds/enemies/helmet_break.wav',       'static')   -- ground pound: se rompe el casco de un Gummy
    load('helmetBounce','assets/sounds/enemies/helmet_bounce.wav',      'static')   -- rebote en el casco de un Gummy
    load('pufferWarn',  'assets/sounds/enemies/puffer_warn.wav',        'static')   -- pez globo: medio hinchado (aviso)
    load('pufferInflate','assets/sounds/enemies/puffer_inflate.wav',    'static')   -- pez globo: hinchado del todo
    load('pufferDeflate','assets/sounds/enemies/puffer_deflate.wav',    'static')   -- pez globo: se deshincha
    load('pufferPrick', 'assets/sounds/enemies/puffer_prick.wav',       'static')   -- pez globo: pincha al jugador
    load('spikeShake',  'assets/sounds/traps/spike_shake.wav',          'static')
    load('fireFizzle',  'assets/sounds/traps/fire_fizzle.wav',          'static')   -- bola del mortero que se apaga
    load('respawnFx',   'assets/sounds/enemies/respawn.wav',            'static')   -- una entidad reaparece
    load('crabPop',     'assets/sounds/enemies/crab_pop.wav',           'static')   -- el Crabby arranca su pincho
    load('slamStart',   'assets/sounds/bosses/miniboss1/slam_start.wav',       'static')   -- la Nave Malvada se lanza en picado
    load('spikesOut',   'assets/sounds/bosses/miniboss1/spikes_out.wav',       'static')   -- le salen los pinchos
    load('fanfare',     'assets/sounds/jingles/fanfare.wav',            'static')
    load('finish',      'assets/sounds/jingles/finish.wav',             'static')
    load('sadtrombone', 'assets/sounds/jingles/sad_trombone.wav',       'static')
    load('tick',        'assets/sounds/jingles/tick.wav',               'static')
    load('dies',          'assets/sounds/player/hurt.ogg',          'static')
    load('point',         'assets/sounds/flappy/point.ogg',         'static')
    load('decimal',       'assets/sounds/flappy/decimal.ogg',       'static')
    load('select',        'assets/sounds/ui/select.ogg',        'static')
    load('jump',          'assets/sounds/player/jump.ogg',          'static')
    load('step',          'assets/sounds/player/step.ogg',          'static')
    load('dies2',         'assets/sounds/player/death.ogg',         'static')
    load('enemyExplode',  'assets/sounds/enemies/enemy_explode.ogg',  'static')
    load('waterWarning',   'assets/sounds/water/warning.ogg',          'static')
    load('airGasp',        'assets/sounds/water/air_gasp.ogg',        'static')
    load('waterSplash',    'assets/sounds/water/splash_in.ogg',     'static')
    load('waterSplashOut', 'assets/sounds/water/splash_out.ogg',     'static')
    load('drowning',      'assets/sounds/water/drowning.ogg',      'stream')
    load('glugluglu',     'assets/sounds/water/glugluglu.ogg',     'static')
    load('pointGain',     'assets/sounds/mechanics/point_gain.wav',    'static')   -- zona de puntos
    load('floodRise',     'assets/sounds/water/flood_rise.wav',    'static')   -- inundación: sube
    load('floodFall',     'assets/sounds/water/flood_fall.wav',    'static')   -- inundación: baja
    if sources['drowning'] then sources['drowning']:setLooping(false) end
    load('fwLaunch',      'assets/sounds/fireworks/launch.ogg',      'static')
    load('fwBlast1',      'assets/sounds/fireworks/blast1.ogg',       'static')
    load('fwBlast2',      'assets/sounds/fireworks/blast2.ogg',      'static')
    load('fwBlastLarge',  'assets/sounds/fireworks/blast_large.ogg', 'static')
    load('roundOver',     'assets/sounds/flappy/round_over.ogg',    'static')
    load('spikeHit',      'assets/sounds/traps/spike_hit.wav',     'static')

    -- Jefes
    load('mortarShoot',   'assets/sounds/enemies/mortar_shoot.wav',        'static')
    load('trampoline',    'assets/sounds/mechanics/trampoline.wav',         'static')
    load('miniAppear',    'assets/sounds/bosses/miniboss1/appear.wav', 'static')
    load('bossHurt',      'assets/sounds/bosses/boss_hurt.wav',    'static')
    load('bossExplode',   'assets/sounds/bosses/boss_explode.wav', 'static')
    load('mirrorLaugh',   'assets/sounds/bosses/mirror/laugh.wav', 'static')
    -- Mega Crabby (generados con tools/sounds/megacrabby.py)
    load('megaStep',      'assets/sounds/bosses/megacrabby/step.wav',   'static')   -- pisada pesada
    load('megaClack',     'assets/sounds/bosses/megacrabby/clack.wav',  'static')   -- chasquido de pinzas
    load('megaHurt',      'assets/sounds/bosses/megacrabby/hurt.wav',   'static')   -- recibe un golpe
    load('megaSlam',      'assets/sounds/bosses/megacrabby/slam.wav',   'static')   -- se clava al caer del techo
    load('megaWindup',    'assets/sounds/bosses/megacrabby/windup.wav', 'static')   -- aviso de embestida
    load('megaShrink',    'assets/sounds/bosses/megacrabby/shrink.wav', 'static')   -- muerte: se desinfla
    load('megaFlee',      'assets/sounds/bosses/megacrabby/flee.wav',   'static')   -- huye asustado
    -- Música: todas las pistas del índice (assets/music/index.json)
    for _, tr in ipairs(Music.list) do Sound.loadTrack(tr) end
end

-- Carga una pista del catálogo de música (src/Music.lua)
function Sound.loadTrack(tr)
    trackVol[tr.id] = tr.volume
    if tr.intro then
        Sound.loadMusic(tr.id, tr.intro, tr.loopFile)
    elseif tr.loopFile then
        Sound.loadMusic(tr.id, nil, tr.loopFile)
    else
        load(tr.id, tr.file, 'stream')
        if sources[tr.id] then sources[tr.id]:setLooping(tr.loops) end
    end
end

-- Pista con INTRO + BUCLE: suena la intro una vez y después el bucle para
-- siempre (el cambio lo hace Sound.update). Se reproduce con playMusic(name).
function Sound.loadMusic(name, introPath, loopPath)
    if introPath then load(name, introPath, 'stream') end
    local ok, src = pcall(love.audio.newSource, loopPath, 'stream')
    if ok then
        src:setLooping(true)
        loops[name] = src
        if not sources[name] then sources[name] = src end   -- sin intro: solo el bucle
    else
        print("[Sound] No se encontró: " .. loopPath)
    end
end

-- ── Sonido en el mundo: atenuación por distancia ────────────────────────────
-- El juego pone el OYENTE (el jugador local, o el centro de la cámara si no
-- juega) y, mientras simula algo que está en el mundo, el EMISOR (la entidad,
-- el jugador...). Todo Sound.play con un emisor activo se atenúa según la
-- distancia al oyente: volumen completo hasta NEAR px, nada a partir de FAR.
-- Los sonidos sin emisor (menús, avisos, los del propio jugador) suenan igual.
-- Online cada cliente calcula SU volumen: los eventos de sonido traen x, y.
Sound.NEAR = 480
Sound.FAR  = 1400
-- Alcance por sonido (multiplica NEAR y FAR): lo que hace algo enorme se oye
-- en toda la arena (un jefe que la cruza no debe quedarse mudo)
Sound.RANGE = {
    megaStep = 1.8, megaClack = 2.2, megaHurt = 3, megaSlam = 3, megaWindup = 2.5,
    megaShrink = 3, megaFlee = 2.2, bossHurt = 3, bossExplode = 3,
}
local listenerX, listenerY = nil, nil
local emitterX, emitterY   = nil, nil

function Sound.setListener(x, y) listenerX, listenerY = x, y end
function Sound.getListener() return listenerX, listenerY end
function Sound.setEmitter(x, y) emitterX, emitterY = x, y end
function Sound.clearEmitter() emitterX, emitterY = nil, nil end
function Sound.getEmitter() return emitterX, emitterY end

-- Ejecuta fn con el emisor en (x, y) y deja el anterior como estaba
function Sound.withEmitter(x, y, fn, ...)
    local ox, oy = emitterX, emitterY
    emitterX, emitterY = x, y
    local ok, err = pcall(fn, ...)
    emitterX, emitterY = ox, oy
    if not ok then error(err, 0) end
end

-- Factor 0..1 de un sonido en (x, y) para el oyente actual (`range`
-- multiplica las distancias, ver Sound.RANGE)
function Sound.falloff(x, y, range)
    if not x or not y or not listenerX then return 1 end
    local dx, dy = x - listenerX, y - listenerY
    local d = math.sqrt(dx * dx + dy * dy)
    local near, far = Sound.NEAR * (range or 1), Sound.FAR * (range or 1)
    if d <= near then return 1 end
    if d >= far then return 0 end
    local k = 1 - (d - near) / (far - near)
    return k * k                        -- cae suave al principio y rápido al final
end

-- Sonido en un punto del mundo (x, y) sin tocar el emisor actual
function Sound.playAt(name, x, y, pitch, volume)
    local ox, oy = emitterX, emitterY
    emitterX, emitterY = x, y
    Sound.play(name, pitch, volume)
    emitterX, emitterY = ox, oy
end

-- Fuente cargada de un sonido (nil si no existe) y su archivo: para pruebas
function Sound.source(name) return sources[name], origin[name] end

function Sound.play(name, pitch, volume)
    local src = sources[name]
    if not src then return end
    local k = Sound.falloff(emitterX, emitterY, Sound.RANGE[name])
    if k <= 0.01 then return end
    local clone = src:clone()
    clone:setPitch(pitch   or 1.0)
    clone:setVolume((volume or 1.0) * k)
    clone:play()
end

-- Reproduce rastreado (sin clonar) → permite stop/isPlaying precisos
function Sound.playTracked(name, pitch, volume)
    local src = sources[name]
    if not src then return end
    src:setPitch(pitch or 1.0)
    src:setVolume(volume or 1.0)
    if not src:isPlaying() then src:play() end
    tracked[name] = src
end

function Sound.stopTracked(name)
    local src = tracked[name]
    if src then src:stop(); tracked[name] = nil end
end

function Sound.isPlaying(name)
    local src = tracked[name] or sources[name]
    if not src then return false end
    return src:isPlaying()
end

-- Pista que suena cuando el juego pide la música 'level' (nil = la normal).
-- Así, durante un jefe, respawns y demás siguen con la música del jefe.
function Sound.setLevelMusic(name) levelMusic = name end
function Sound.getLevelMusic() return levelMusic end

-- Música del nivel en juego (id del índice; nil o desconocido = la de siempre)
function Sound.setBaseLevelMusic(id) baseLevelMusic = id and Music.levelTrack(id) or nil end
function Sound.getBaseLevelMusic() return baseLevelMusic or Music.DEFAULT end

-- 'level' = lo que deba sonar en el nivel: la del jefe (si manda), la del
-- nivel o la de siempre
local function resolve(name)
    if name == 'level' then return levelMusic or baseLevelMusic or Music.DEFAULT end
    return name
end
Sound.resolveMusic = resolve

local musicName = nil
function Sound.playMusic(name, volume)
    name = resolve(name)
    volume = volume or trackVol[name]
    local src = sources[name]
    if not src then return end
    -- Pista con intro que ya está en su bucle: sigue sonando
    local lp = loops[name]
    if lp and music == lp and lp:isPlaying() then
        lp:setPitch(1.0); lp:setVolume(volume or 0.7)
        return
    end
    -- Siempre resetear pitch, aunque sea la misma pista
    if music == src and src:isPlaying() then
        src:setPitch(1.0)
        src:setVolume(volume or 0.7)
        return
    end
    if music and music:isPlaying() then
        music:setPitch(1.0)
        music:stop()
    end
    src:setPitch(1.0)
    src:setVolume(volume or 0.7)
    if lp and src ~= lp then src:seek(0) end
    src:play()
    music, musicName = src, name
end

-- Cambio intro → bucle de las pistas con intro (llamar cada frame).
local paused = nil
function Sound.update(dt)
    local lp = musicName and loops[musicName]
    if lp and music ~= lp and not paused and not music:isPlaying() then
        lp:setPitch(music:getPitch()); lp:setVolume(music:getVolume())
        lp:seek(0); lp:play()
        music = lp
    end
end

function Sound.setMusicVolume(v)
    if music then music:setVolume(v) end
end

-- ¿Está sonando la pista `name` (o cualquier música si name es nil)?
function Sound.isMusicPlaying(name)
    if not music or not music:isPlaying() then return false end
    name = name and resolve(name)
    return name == nil or sources[name] == music or loops[name] == music
end

-- Online: coloca la pista `name` (resuelta) en el punto que le toca a los
-- `t` segundos de haber empezado (intro una vez y luego el bucle), para que
-- todos los jugadores oigan lo mismo a la vez. Solo corrige si ya está
-- sonando esa pista y se ha desviado más de `tol` segundos.
function Sound.syncMusic(name, t, tol)
    name, tol = resolve(name), tol or 0.35
    if paused or name ~= musicName or not music or not music:isPlaying() or t < 0 then return false end
    local intro, lp = sources[name], loops[name]
    local src, pos
    if lp and intro and intro ~= lp then
        local d = intro:getDuration()
        if d <= 0 then return false end
        if t < d then src, pos = intro, t
        else
            local ld = lp:getDuration()
            if ld <= 0 then return false end
            src, pos = lp, (t - d) % ld
        end
    else
        src = lp or intro
        local d = src and src:getDuration() or -1
        if d <= 0 then return false end
        if src:isLooping() then pos = t % d elseif t < d then pos = t else return false end
    end
    if src == music and math.abs(src:tell() - pos) <= tol then return false end
    local pitch, vol = music:getPitch(), music:getVolume()
    if src ~= music then music:stop() end
    src:setPitch(pitch); src:setVolume(vol)
    src:seek(pos)
    if not src:isPlaying() then src:play() end
    music = src
    return true
end

-- Pista que suena y su posición (s) dentro del archivo actual (intro o bucle)
function Sound.musicPosition()
    if not music or not music:isPlaying() then return nil end
    return musicName, music:tell(), (loops[musicName] == music and sources[musicName] ~= music) and 'bucle' or 'inicio'
end

-- Lerp del pitch de la música (usado para el slowdown al morir)
function Sound.setMusicPitch(pitch)
    if music and music:isPlaying() then
        music:setPitch(math.max(0.1, pitch))
    end
end

-- Pausa: congela la música y los sonidos largos (ahogamiento) donde van,
-- para continuar EXACTAMENTE desde ahí al despausar.
function Sound.pauseAll()
    paused = {}
    if music and music:isPlaying() then music:pause(); table.insert(paused, music) end
    for _, src in pairs(tracked) do
        if src:isPlaying() then src:pause(); table.insert(paused, src) end
    end
end

-- Devuelve true si había algo pausado que se reanudó.
function Sound.resumeAll()
    local list = paused
    paused = nil
    if not list or #list == 0 then return false end
    for _, src in ipairs(list) do src:play() end
    return true
end

-- Para todos los sonidos rastreados (ahogamiento...): al salir de una partida
function Sound.stopAllTracked()
    for _, src in pairs(tracked) do
        if src:isPlaying() then src:stop() end
    end
    paused = nil
end

-- Deja la música "de partida" como al empezar: sin pista de jefe ni del nivel,
-- tono normal y nada sonando (la pantalla siguiente pone la suya)
function Sound.leaveMatch()
    Sound.stopAllTracked()
    levelMusic, baseLevelMusic = nil, nil
    if music then music:setPitch(1.0) end
    Sound.stopMusic()
end

function Sound.stopMusic()
    if music and music:isPlaying() then music:stop() end
    music, musicName = nil, nil
end

function Sound.decimalPitch(score)
    local mult = score / 10
    return math.min(2.0, 0.9 + mult * 0.1)
end

return Sound