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
    -- (el usuario: los pasos sonaban demasiado → 0.55 fue pasarse, "un poquito" más: 0.65; y el salto, algo menos)
    step         = 0.65, jump = 0.75,
    roundOver    = 2.8,  spikeHit   = 2.2,  dies2      = 0.65, glugluglu  = 0.8,
    airGasp      = 0.85, waterWarning = 1.4,
    -- Mega Crabby (archivos ya comprimidos: subir poco por encima de 1 satura)
    megaStep     = 0.7,  megaClack  = 1.0,  megaHurt   = 1.1,  megaSlam   = 1.1,
    megaWindup   = 0.78, megaShrink = 0.8,  megaFlee   = 0.9,  megaRoar = 0.67, megaFall = 0.8,
    -- Espejo (tools/sounds/mirror.py)
    bombIgnite = 0.72, bombFizz = 0.48, bombBlast = 0.87, iceBreak = 0.85,
    cryoWindup = 0.58, cryoBlast = 0.6, cryoFreeze = 0.51, cryoFree = 0.72, cryoDrop = 0.6,
    -- Gran Bola de Nieve (tools/sounds/snowboss.py)
    snowLaugh = 0.53, snowRoar = 0.55, snowSpit = 0.62, snowSplat = 0.51, snowRoll = 0.63,
    snowLand = 0.49, snowSlam = 0.59, snowCrash = 0.60, snowDizzy = 0.56, snowCrack = 0.92,
    snowBurst = 0.60, snowFlee = 0.46, snowIntroRoll = 0.59, snowBreath = 0.46,
    -- Rey Gummy (tools/sounds/megagummy.py)
    kingHop = 0.46, kingCharge = 0.34, kingJump = 0.37, kingFlop = 0.55, kingWave = 0.6, kingFanfare = 0.43,
    kingLaugh = 0.67, kingHurt = 0.55, kingSplit = 0.47, kingPop = 0.55, kingCrown = 0.66, kingLand = 0.55,
    mirrorAppear = 0.62, mirrorPortal = 0.37, glassWarn = 0.85, glassRise = 0.72, glassHit = 0.72,
    -- tools/sounds/mechanics.py (medidos: → ≈ -12 dBFS)
    switchOn     = 0.77, switchOff  = 0.76, helmetBounce = 1.15, helmetBreak = 0.72,
    pufferWarn   = 1.0,  pufferInflate = 0.81, pufferDeflate = 0.77, pufferPrick = 0.67,
    -- Linterna y Crabby lúgubre (tools/sounds/gloomy.py ya los deja a -12 dBFS; el tic, más flojo)
    lightOn = 1.0, lightOff = 1.0, lightOut = 1.0, lightDead = 1.0,
    mgloomyPing = 1.0, mgloomyListen = 1.0, mgloomyDrop = 1.0, mgloomySlam = 1.25, mgloomyDazzled = 1.0,
    mgloomyShriek = 1.0, mgloomyHurt = 1.0, mgloomyStep = 0.5, mgloomyRoar = 1.1,
    gloomyWind = 0.8, gloomyLeap = 0.8,
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
    load('helmetBreak', 'assets/sounds/enemies/gummy/helmet_break.wav',       'static')   -- ground pound: se rompe el casco de un Gummy
    load('helmetBounce','assets/sounds/enemies/gummy/helmet_bounce.wav',      'static')   -- rebote en el casco de un Gummy
    load('pufferWarn',  'assets/sounds/enemies/pufferfish/warn.wav',        'static')   -- pez globo: medio hinchado (aviso)
    load('pufferInflate','assets/sounds/enemies/pufferfish/inflate.wav',    'static')   -- pez globo: hinchado del todo
    load('pufferDeflate','assets/sounds/enemies/pufferfish/deflate.wav',    'static')   -- pez globo: se deshincha
    load('pufferPrick', 'assets/sounds/enemies/pufferfish/prick.wav',       'static')   -- pez globo: pincha al jugador
    load('spikeShake',  'assets/sounds/traps/spike_shake.wav',          'static')
    load('fireFizzle',  'assets/sounds/traps/fire_fizzle.wav',          'static')   -- bola del mortero que se apaga
    load('respawnFx',   'assets/sounds/enemies/common/respawn.wav',            'static')   -- una entidad reaparece
    load('crabPop',     'assets/sounds/enemies/crabby/pop.wav',           'static')   -- el Crabby arranca su pincho
    load('bombIgnite',  'assets/sounds/enemies/bomb/ignite.wav',        'static')   -- bomba: se enciende la mecha
    load('bombFizz',    'assets/sounds/enemies/bomb/fizz.wav',          'static')   -- bomba: la mecha chisporrotea
    load('bombBlast',   'assets/sounds/enemies/bomb/blast.wav',         'static')   -- bomba: explota
    load('bombKick',    'assets/sounds/enemies/bomb/kick.wav',          'static')   -- bomba: pisada / pateada
    load('iceCrack',    'assets/sounds/mechanics/ice_crack.wav',        'static')   -- hielo fino: se agrieta
    -- Ambiente (tools/sounds/ambience.py): gotas de las estalactitas y la cueva de fondo (src/fx/CaveAmbience.lua)
    load('dripFall',    'assets/sounds/ambience/drip_fall.wav',         'static')   -- la gota se suelta
    load('dripSplash',  'assets/sounds/ambience/drip_splash.wav',       'static')   -- la gota llega al suelo
    load('caveDrip',    'assets/sounds/ambience/cave_drip.wav',         'static')   -- gota lejana (ambiente)
    load('caveRumble',  'assets/sounds/ambience/cave_rumble.wav',       'static')   -- rumor de la roca (ambiente)
    load('cavePebble',  'assets/sounds/ambience/cave_pebble.wav',       'static')   -- piedrecita que rueda (ambiente)
    load('iceBreak',    'assets/sounds/mechanics/ice_break.wav',        'static')   -- hielo fino: se rompe
    load('cryoWindup',  'assets/sounds/traps/cryo_windup.wav',         'static')   -- congelador: carga
    load('cryoBlast',   'assets/sounds/traps/cryo_blast.wav',          'static')   -- congelador: chorro
    load('cryoFreeze',  'assets/sounds/traps/cryo_freeze.wav',         'static')   -- algo queda congelado
    load('cryoFree',    'assets/sounds/traps/cryo_free.wav',           'static')   -- se rompe el bloque de hielo
    load('cryoDrop',    'assets/sounds/traps/cryo_drop.wav',           'static')   -- congelador: baja del techo (fase del jefe)
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
    load('enemyExplode',  'assets/sounds/enemies/common/explode.ogg',  'static')
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
    load('mortarShoot',   'assets/sounds/enemies/mortar/shoot.wav',        'static')
    load('trampoline',    'assets/sounds/mechanics/trampoline.wav',         'static')
    load('miniAppear',    'assets/sounds/bosses/miniboss1/appear.wav', 'static')
    load('bossHurt',      'assets/sounds/bosses/boss_hurt.wav',    'static')
    load('bossExplode',   'assets/sounds/bosses/boss_explode.wav', 'static')
    load('mirrorLaugh',   'assets/sounds/bosses/mirror/laugh.wav', 'static')
    load('mirrorWarp',    'assets/sounds/bosses/mirror/warp.wav',   'static')   -- se rompe y desaparece
    load('mirrorAppear',  'assets/sounds/bosses/mirror/appear.wav', 'static')   -- reaparece en un espejo
    load('mirrorPortal',  'assets/sounds/bosses/mirror/portal.wav', 'static')   -- apunta desde el espejo
    load('glassWarn',     'assets/sounds/bosses/mirror/glass_warn.wav', 'static')  -- cristal roto: aviso
    load('glassRise',     'assets/sounds/bosses/mirror/glass_rise.wav', 'static')  -- cristal roto: salen
    load('glassHit',      'assets/sounds/bosses/mirror/glass_hit.wav',  'static')  -- cristal roto: tocarlos
    -- Mega Crabby (generados con tools/sounds/megacrabby.py)
    load('megaStep',      'assets/sounds/bosses/megacrabby/step.wav',   'static')   -- pisada pesada
    load('megaClack',     'assets/sounds/bosses/megacrabby/clack.wav',  'static')   -- chasquido de pinzas
    load('megaHurt',      'assets/sounds/bosses/megacrabby/hurt.wav',   'static')   -- recibe un golpe
    load('megaSlam',      'assets/sounds/bosses/megacrabby/slam.wav',   'static')   -- se clava al caer del techo
    load('megaWindup',    'assets/sounds/bosses/megacrabby/windup.wav', 'static')   -- aviso de embestida
    load('megaShrink',    'assets/sounds/bosses/megacrabby/shrink.wav', 'static')   -- muerte: se desinfla
    load('megaFlee',      'assets/sounds/bosses/megacrabby/flee.wav',   'static')   -- huye asustado
    load('megaRoar',      'assets/sounds/bosses/megacrabby/roar.wav',   'static')   -- rugido (entrada y descansos)
    load('megaFall',      'assets/sounds/bosses/megacrabby/fall.wav',   'static')   -- cae del cielo (entrada)
    -- Gran Bola de Nieve (tools/sounds/snowboss.py)
    for _, n in ipairs({ 'laugh', 'roar', 'spit', 'splat', 'roll', 'land', 'slam', 'crash', 'dizzy', 'crack',
                         'burst', 'flee', 'intro_roll', 'breath' }) do
        local id = 'snow' .. n:gsub('^%l', string.upper):gsub('_(%l)', string.upper)
        load(id, 'assets/sounds/bosses/snowboss/' .. n .. '.wav', 'static')
    end
    -- Rey Gummy (tools/sounds/megagummy.py): kingHop, kingFlop...
    for _, n in ipairs({ 'hop', 'charge', 'jump', 'flop', 'wave', 'fanfare', 'laugh', 'hurt', 'split', 'pop',
                         'crown', 'land' }) do
        load('king' .. n:gsub('^%l', string.upper), 'assets/sounds/bosses/megagummy/' .. n .. '.wav', 'static')
    end
    -- Saltarín (tools/sounds/hopper.py)
    for _, n in ipairs({ 'wind', 'jump', 'land' }) do
        load('hop' .. n:gsub('^%l', string.upper), 'assets/sounds/enemies/hopper/' .. n .. '.wav', 'static')
    end
    -- Linterna y Crabby lúgubre (tools/sounds/gloomy.py)
    for _, n in ipairs({ 'on', 'off', 'out', 'dead' }) do
        load('light' .. n:gsub('^%l', string.upper), 'assets/sounds/player/light_' .. n .. '.wav', 'static')
    end
    for _, n in ipairs({ 'wind', 'leap' }) do
        load('gloomy' .. n:gsub('^%l', string.upper), 'assets/sounds/enemies/gloomy/' .. n .. '.wav', 'static')
    end
    for _, n in ipairs({ 'ping', 'listen', 'drop', 'slam', 'dazzled', 'shriek', 'hurt', 'step', 'roar' }) do
        load('mgloomy' .. n:gsub('^%l', string.upper), 'assets/sounds/bosses/megagloomy/' .. n .. '.wav', 'static')
    end
    -- La historia (tools/sounds/story.py): cinemáticas y fragmentos del espejo
    for _, n in ipairs({ 'glint', 'crash', 'orb', 'blast', 'shard', 'grow', 'clink', 'restore', 'bell', 'shrink', 'wave' }) do
        load('story' .. n:gsub('^%l', string.upper), 'assets/sounds/story/' .. n .. '.wav', 'static')
    end
    load('shardDrop', 'assets/sounds/story/shard_drop.wav', 'static')      -- un jefe suelta su fragmento
    load('shardGet',  'assets/sounds/story/shard_get.wav',  'static')      -- el jugador lo recoge
    -- Música: todas las pistas del índice (assets/music/index.json)
    for _, tr in ipairs(Music.list) do Sound.loadTrack(tr) end
end

-- Carga una pista del catálogo de música (src/Music.lua)
function Sound.loadTrack(tr)
    trackVol[tr.id] = tr.volume
    if tr.pending then return end                    -- (hueco: su archivo aún no existe)
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
    bombBlast = 4,
    mirrorWarp = 2.5, mirrorAppear = 2.5, mirrorPortal = 2.5, glassWarn = 3, glassRise = 3,
    mgloomyPing = 3, mgloomyListen = 3, mgloomyDrop = 3, mgloomySlam = 3, mgloomyDazzled = 3, mgloomyShriek = 3,
    mgloomyHurt = 3, mgloomyStep = 2, mgloomyRoar = 3,
    megaStep = 1.8, megaClack = 2.2, megaRoar = 3, megaFall = 3, megaHurt = 3, megaSlam = 3, megaWindup = 2.5,
    megaShrink = 3, megaFlee = 2.2, bossHurt = 3, bossExplode = 3,
    snowLaugh = 3, snowRoar = 3, snowSlam = 3, snowCrash = 3, snowBurst = 3, snowIntroRoll = 3, snowRoll = 2.5,
    snowLand = 2.5, snowSpit = 2.2, snowDizzy = 2.5, snowCrack = 2.5, snowBreath = 2.5,
    kingFlop = 3, kingLand = 3, kingFanfare = 3, kingLaugh = 3, kingSplit = 3, kingWave = 2.5, kingCharge = 2.5,
    kingJump = 2.5, kingHurt = 2.5, kingPop = 2.5, kingCrown = 2.5, kingHop = 2,
}
local listenerX, listenerY = nil, nil
local emitterX, emitterY   = nil, nil

function Sound.setListener(x, y) listenerX, listenerY = x, y end
function Sound.getListener() return listenerX, listenerY end
function Sound.setEmitter(x, y) emitterX, emitterY = x, y end
function Sound.getEmitter() return emitterX, emitterY end
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

-- ECO (cuevas profundas: nivel con `echo`, Sound.setEcho): cada sonido se repite más flojo y
-- un poco más grave, y cuanto MÁS FUERTE llega, más eco deja (más repeticiones y más altas).
-- "Fuerte" = su volumen ya atenuado por la distancia × su peso (ECHO_W: un golpe en la roca
-- retumba; un paso, casi nada). Repeticiones a mano (clones con retraso): funciona igual en PC,
-- Switch y Android (los efectos de OpenAL no están en todas partes). La música no tiene eco.
local ECHO_DELAY, ECHO_DECAY, ECHO_MIN, ECHO_MAX = 0.21, 0.5, 0.07, 3
local ECHO_W = {
    step = 0.3, jump = 0.4, lightOn = 0.35, lightOff = 0.35, lightDead = 0.35, lightOut = 0.6, headBump = 0.6,
    gpImpact = 1.0, gpStart = 0.5, enemyExplode = 0.9, blockBreak = 1.0, spikeHit = 0.9, dies = 0.8, dies2 = 0.9,
    bossHurt = 1.0, bossExplode = 1.0, mgloomySlam = 1.0, mgloomyShriek = 1.0, mgloomyRoar = 1.0, mgloomyPing = 0.9,
    mgloomyDazzled = 0.9, mgloomyHurt = 0.9, mgloomyListen = 0.7, mgloomyStep = 0.5, gloomyWind = 0.5, gloomyLeap = 0.6,
    megaSlam = 1.0, megaRoar = 1.0, megaStep = 0.7, bombBlast = 1.0, stunned = 0.6, collect = 0.5,
    dripFall = 0.5, dripSplash = 0.9, caveDrip = 0.3, cavePebble = 0.3, caveRumble = 0,   -- (los de ambiente ya traen su cola)
}
local echoK, echoes = 0, {}
function Sound.setEcho(k)
    echoK = k or 0
    if echoK <= 0 then echoes = {} end
end
function Sound.getEcho() return echoK end

local function playClone(name, pitch, vol)
    local src = sources[name]
    if not src then return end
    local clone = src:clone()
    clone:setPitch(pitch)
    clone:setVolume(vol)
    clone:play()
end

function Sound.play(name, pitch, volume)
    local src = sources[name]
    if not src then return end
    local k = Sound.falloff(emitterX, emitterY, Sound.RANGE[name])
    if k <= 0.01 then return end
    local vol = (volume or 1.0) * k
    playClone(name, pitch or 1.0, vol)
    if echoK > 0 then
        local e = math.min(1, vol) * (ECHO_W[name] or 0.6) * echoK
        local now = love.timer.getTime()
        for i = 1, ECHO_MAX do
            e = e * ECHO_DECAY
            if e < ECHO_MIN then break end
            echoes[#echoes + 1] = { name = name, at = now + ECHO_DELAY * i, pitch = (pitch or 1.0) * (0.985 ^ i), vol = e }
        end
    end
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

-- Bucle mientras `on` (lo llama cada fotograma quien lo dibuja: solo dibujo, p. ej. la
-- Gran Bola de Nieve rodando); el volumen sigue a la distancia de (x, y) al oyente
function Sound.loop(name, on, x, y)
    local src = sources[name]
    if not src then return end
    if not on then
        if tracked[name] then src:stop(); tracked[name] = nil end
        return
    end
    local k = (x and Sound.falloff) and Sound.falloff(x, y, Sound.RANGE[name]) or 1
    src:setVolume(k)
    if not src:isPlaying() then src:setLooping(true); src:play() end
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
    if name == 'level' then name = levelMusic or baseLevelMusic or Music.DEFAULT end
    return Music.playable(name)          -- (ids antiguos y huecos sin pista todavía: src/Music.lua)
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
    if music then
        music:setPitch(1.0)
        music:stop()
    end
    src:setPitch(1.0)
    src:setVolume(volume or 0.7)
    -- Empieza SIEMPRE desde el principio: stop() rebobina (una pista que se
    -- quedó en pausa al salir de la partida seguía desde donde estaba)
    src:stop()
    if lp and lp ~= src then lp:stop() end
    src:play()
    music, musicName = src, name
end

-- Cambio intro → bucle de las pistas con intro (llamar cada frame).
local paused = nil
local INTRO_LEAD = 0.009
function Sound.update(dt)
    if echoes[1] then                                      -- ecos pendientes
        local now = love.timer.getTime()
        for i = #echoes, 1, -1 do
            local e = echoes[i]
            if now >= e.at then
                if not paused then playClone(e.name, e.pitch, e.vol) end
                table.remove(echoes, i)
            end
        end
    end
    -- El bucle arranca cuando a la intro le queda menos de medio frame (su final va apagado: tools/music
    -- `export`), no un frame DESPUÉS de que se pare: así no hay hueco de silencio ni llega tarde al compás
    local lp = musicName and loops[musicName]
    if lp and music ~= lp and not paused then
        local left = 0
        if music:isPlaying() then
            local d = music:getDuration()
            left = d > 0 and (d - music:tell()) / math.max(0.1, music:getPitch()) or 1
        end
        if left <= math.max(INTRO_LEAD, math.min(0.03, (dt or 0) * 0.6)) then      -- (a ≤ medio frame de su final)
            lp:setPitch(music:getPitch()); lp:setVolume(music:getVolume())
            lp:seek(0); lp:play()
            music = lp
        end
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

-- Cambia a OTRA versión de la misma canción en el mismo punto (el mapa del mundo: cada isla su arreglo,
-- mismo tempo y largo — tools/music/worldmap_nes.py): sigue el compás, solo cambian los instrumentos
function Sound.switchMusic(name)
    local cur, pos = Sound.musicPosition()
    if cur and resolve(name) == cur then return end
    Sound.playMusic(name)
    if pos then Sound.syncMusic(name, pos, 0) end
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
    for _, src in pairs(tracked) do src:stop() end
    if paused then
        for _, src in ipairs(paused) do src:stop() end
        paused = nil
    end
end

-- Deja la música "de partida" como al empezar: sin pista de jefe ni del nivel,
-- tono normal y nada sonando (la pantalla siguiente pone la suya)
function Sound.leaveMatch()
    Sound.stopAllTracked()
    Sound.setEcho(0)
    levelMusic, baseLevelMusic = nil, nil
    if music then music:setPitch(1.0) end
    Sound.stopMusic()
end

-- Para la música (también si estaba en PAUSA: si no, al volver a pedirla
-- seguía desde donde se quedó) y olvida lo pausado
function Sound.stopMusic()
    if music then music:stop() end
    local lp = musicName and loops[musicName]
    if lp then lp:stop() end
    if paused then
        for _, src in ipairs(paused) do src:stop() end
        paused = nil
    end
    music, musicName = nil, nil
end

function Sound.decimalPitch(score)
    local mult = score / 10
    return math.min(2.0, 0.9 + mult * 0.1)
end

return Sound