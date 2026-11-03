-- src/audio/Sound.lua
local Music = require 'src/audio/Music'
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

-- ── El catálogo: assets/sounds/index.json ─────────────────────────────────────
-- Cada sonido: su id (el de Sound.play), su archivo y, si los lleva, `gain` (ganancia horneada en las muestras al
-- cargar, para que todos se oigan parecido: ≈ -12 dBFS; puede pasar de 1), `range` (× el alcance) y `echo` (su peso en
-- el eco). Un sonido nuevo = su archivo + una línea en el índice.
local INDEX = 'assets/sounds/index.json'
local CATALOG, GAIN, RANGE, ECHO_W = {}, {}, {}, {}
do
    local ok, idx = pcall(function() return require('libs/json').decode(love.filesystem.read(INDEX)) end)
    if ok and type(idx) == 'table' then CATALOG = idx.sounds or {} else print('[Sound] no se pudo leer ' .. INDEX) end
    for _, e in ipairs(CATALOG) do
        GAIN[e.id], RANGE[e.id], ECHO_W[e.id] = e.gain, e.range, e.echo
    end
end
Sound.GAIN, Sound.CATALOG = GAIN, CATALOG

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

-- Volumen de las OPCIONES (0..1; src/core/Settings.lua): × todo lo que suena. Las muestras y las pistas se mezclan a 1.
local musicK, sfxK = 1, 1
function Sound.setVolumes(mus, sfx)
    if music and musicK > 0 then music:setVolume(music:getVolume() / musicK * mus)
    elseif music then music:setVolume(mus * 0.7) end        -- (estaba a 0: su volumen se perdió; el de casi todas)
    musicK, sfxK = mus, sfx
end

local voices = {}                     -- las voces de cada sonido (ver playClone): [name] = { n = siguiente a pisar, [i] }
local function load(name, path, stype)
    voices[name] = nil                -- (sus voces eran copias del sonido anterior)
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
    for _, e in ipairs(CATALOG) do load(e.id, e.file, e.stream and 'stream' or 'static') end
    if sources['drowning'] then sources['drowning']:setLooping(false) end
    -- Música: todas las pistas del índice (assets/music/index.json)
    for _, tr in ipairs(Music.list) do Sound.loadTrack(tr) end
end

-- Carga una pista del catálogo de música (src/audio/Music.lua)
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
-- Alcance por sonido (`range` en el índice: multiplica NEAR y FAR): lo que hace algo enorme se oye en toda la arena
-- (un jefe que la cruza no debe quedarse mudo)
Sound.RANGE = RANGE
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
-- "Fuerte" = su volumen ya atenuado por la distancia × su peso (`echo` en el índice: un golpe en la roca
-- retumba; un paso, casi nada). Repeticiones a mano (clones con retraso): funciona igual en PC,
-- Switch y Android (los efectos de OpenAL no están en todas partes). La música no tiene eco.
local ECHO_DELAY, ECHO_DECAY, ECHO_MIN, ECHO_MAX = 0.21, 0.5, 0.07, 3
local echoK, echoes = 0, {}
function Sound.setEcho(k)
    echoK = k or 0
    if echoK <= 0 then echoes = {} end
end

-- VOCES: cada sonido tiene un grupo fijo de copias (como mucho VOICES) que se REUTILIZAN: se usa una que ya calló
-- y, si suenan todas, la que lleva más rato. Antes cada Sound.play hacía un clon nuevo que solo se liberaba al pasar
-- el recolector: en ráfagas (pasos, golpes, explosiones) se acumulaban fuentes de OpenAL, que en Switch / Android
-- son pocas (cuando se acaban, los sonidos dejan de oírse).
local VOICES = 6
local function playClone(name, pitch, vol)
    local src = sources[name]
    if not src then return end
    local pool = voices[name]
    if not pool then pool = { n = 1 }; voices[name] = pool end
    local v
    for i = 1, #pool do
        if not pool[i]:isPlaying() then v = pool[i]; break end
    end
    if not v then
        if #pool < VOICES then
            v = src:clone()
            pool[#pool + 1] = v
        else
            v = pool[pool.n]
            pool.n = pool.n % VOICES + 1
            v:stop()
        end
    end
    v:setPitch(pitch)
    v:setVolume(vol * sfxK)
    v:play()
end
-- (para los arneses: cuántas fuentes tiene cada sonido)
function Sound.voiceCount(name) return voices[name] and #voices[name] or 0 end

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
    src:setVolume((volume or 1.0) * sfxK)
    if not src:isPlaying() then src:play() end
    tracked[name] = src
end

-- Bucle mientras `on` (lo llama cada fotograma quien lo dibuja: solo dibujo, p. ej. la
-- Gran Bola de Nieve rodando); el volumen sigue a la distancia de (x, y) al oyente
-- (gain: × el volumen; los escenarios de los créditos lo bajan)
function Sound.loop(name, on, x, y, gain)
    local src = sources[name]
    if not src then return end
    if not on then
        if tracked[name] then src:stop(); tracked[name] = nil end
        return
    end
    local k = (x and Sound.falloff) and Sound.falloff(x, y, Sound.RANGE[name]) or 1
    src:setVolume(k * (gain or 1) * sfxK)
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

-- 'level' = lo que deba sonar en el nivel: la del jefe (si manda), la del
-- nivel o la de siempre
local function resolve(name)
    if name == 'level' then name = levelMusic or baseLevelMusic or Music.DEFAULT end
    return Music.playable(name)          -- (ids antiguos y huecos sin pista todavía: src/audio/Music.lua)
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
        lp:setPitch(1.0); lp:setVolume((volume or 0.7) * musicK)
        return
    end
    -- Siempre resetear pitch, aunque sea la misma pista
    if music == src and src:isPlaying() then
        src:setPitch(1.0)
        src:setVolume((volume or 0.7) * musicK)
        return
    end
    if music then
        music:setPitch(1.0)
        music:stop()
    end
    src:setPitch(1.0)
    src:setVolume((volume or 0.7) * musicK)
    -- Empieza SIEMPRE desde el principio: stop() rebobina (una pista que se
    -- quedó en pausa al salir de la partida seguía desde donde estaba)
    src:stop()
    if lp and lp ~= src then lp:stop() end
    src:play()
    music, musicName, adaptCur = src, name, nil
end

-- Cambio intro → bucle de las pistas con intro (llamar cada frame).
local paused = nil
local xf, xfadeStep                        -- (el fundido cruzado de Sound.switchMusic: abajo)
local INTRO_LEAD = 0.009
function Sound.update(dt)
    if xfadeStep then xfadeStep(dt or 0) end                -- (el fundido cruzado de switchMusic)
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

-- (lo que piden y leen los estados, sin el volumen de las opciones: ese lo pone Sound.setVolumes)
function Sound.setMusicVolume(v)
    if music then music:setVolume(v * musicK) end
end
function Sound.musicVolume() return (music and musicK > 0) and music:getVolume() / musicK or 0 end

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
-- mismo tempo y largo — tools/music/worldmap_nes.py): sigue el compás, solo cambian los instrumentos.
-- FUNDIDO CRUZADO (0.5.95, el usuario: el cambio de golpe se notaba): la de antes sigue sonando y BAJA mientras la
-- nueva, en el mismo punto, SUBE (`fade` s; curva de igual potencia: no se hunde a medio camino). Sound.update lo lleva.
Sound.XFADE = 1.2
-- xf = { src (la que se va), v0, target (volumen de la nueva), t, dur }
function Sound.switchMusic(name, fade)
    local cur, pos = Sound.musicPosition()
    if cur and resolve(name) == cur then return end
    fade = fade or Sound.XFADE
    local old = music
    if xf then xf.src:stop(); xf = nil end                  -- (otro cambio a medio fundido: la que ya se iba, fuera)
    if fade > 0 and old and old:isPlaying() then music = nil end    -- (que playMusic no pare la de antes)
    Sound.playMusic(name)
    if pos then Sound.syncMusic(name, pos, 0) end
    if old and music and music ~= old and fade > 0 and old:isPlaying() then
        local target = music:getVolume()
        music:setVolume(0)
        xf = { src = old, v0 = old:getVolume(), target = target, t = 0, dur = fade }
    elseif old and music ~= old and old:isPlaying() then
        old:stop()
    end
end
function xfadeStep(dt)
    if not xf or paused then return end
    xf.t = xf.t + dt
    local k = math.min(1, xf.t / xf.dur)
    xf.src:setVolume(xf.v0 * math.cos(k * math.pi / 2))
    if music then music:setVolume(xf.target * math.sin(k * math.pi / 2)) end
    if k >= 1 then
        xf.src:stop()
        xf = nil
    end
end

-- Pista que suena y su posición (s) dentro del archivo actual (intro o bucle)
function Sound.musicPosition()
    if not music or not music:isPlaying() then return nil end
    return musicName, music:tell(), (loops[musicName] == music and sources[musicName] ~= music) and 'bucle' or 'inicio'
end

-- ── MÚSICA ADAPTATIVA (piezas que siguen un reloj: el Mega Mashup, docs/bosses/crab-mashup.md) ────────────────
-- Un MAPA (json: `pieces` = { id = { file, loop, length, music_end, bars, cuts, next } }, `volume`) y un reloj que
-- lleva OTRO (el director del evento: un jugador o el servidor, que no tiene audio): cada frame dice qué pieza suena,
-- en qué punto y el próximo cambio { piece, at = s de la pieza actual, pos = s de la siguiente }. Aquí solo se SIGUE:
-- la pieza que toca, recolocada si se desvía más de `ADAPT_TOL`, y el cambio a la siguiente medio frame ANTES (como
-- la intro → el bucle) para que no haya hueco. Las fuentes son de la música normal (`music`): pausa, tono y parar
-- funcionan igual.
local adaptMaps, adaptSrc = {}, {}
local adaptCur = nil                      -- id de la pieza que suena (con su mapa)
local ADAPT_TOL = 0.2                      -- (online: recolocar suena a salto; solo si se va más de esto)
Sound.ADAPTIVE = '_adaptativa'            -- (lo que vale getLevelMusic mientras manda una música adaptativa)

function Sound.adaptiveMap(path)
    if adaptMaps[path] == nil then
        local json = require 'libs/json'
        local ok, m = pcall(json.decode, love.filesystem.read(path) or '')
        adaptMaps[path] = (ok and type(m) == 'table' and type(m.pieces) == 'table') and m or false
        if not adaptMaps[path] then print('[Sound] mapa de música adaptativa ilegible: ' .. tostring(path)) end
    end
    return adaptMaps[path] or nil
end

local function adaptSource(map, path, pid)
    local key = path .. '#' .. pid
    if adaptSrc[key] == nil then
        local pc = map.pieces[pid]
        local ok, src = pcall(love.audio.newSource, Music.DIR .. (pc and pc.file or '?'), 'stream')
        adaptSrc[key] = ok and src or false
        if ok then src:setLooping(pc.loop == true) else print('[Sound] no se encontró la pieza ' .. pid) end
    end
    return adaptSrc[key] or nil
end

-- Sigue el reloj de `path` (mapa): pieza `pid` en `pos` s; `nxt` = { piece, at, pos } o nil. pid nil = callada.
function Sound.followAdaptive(path, pid, pos, nxt)
    if paused then return end
    local map = Sound.adaptiveMap(path)
    if not map or not pid or not map.pieces[pid] then
        if adaptCur then Sound.stopMusic() end
        return
    end
    local vol = tonumber(map.volume) or 1
    local function start(id, at)
        local src = adaptSource(map, path, id)
        if not src then return end
        if music and music ~= src then music:stop() end
        src:setPitch(1.0); src:setVolume(vol * musicK)
        src:seek(math.max(0, at)); src:play()
        music, musicName, adaptCur = src, Sound.ADAPTIVE, id
    end
    -- ¿Ya se adelantó al cambio (medio frame antes) y el reloj aún no ha llegado? sigue
    if nxt and adaptCur == nxt.piece and adaptCur ~= pid and music and music:isPlaying() then return end
    if adaptCur ~= pid or not music or musicName ~= Sound.ADAPTIVE or not music:isPlaying() then
        start(pid, pos); return
    end
    local t = music:tell()
    local len = map.pieces[pid].music_end or music:getDuration()
    -- el cambio, a menos de medio frame
    if nxt and map.pieces[nxt.piece] then
        local left = nxt.at - t
        if map.pieces[pid].loop and left < -len / 2 then left = left + len end       -- (el corte es al dar la vuelta)
        if left <= INTRO_LEAD + 0.008 and left > -0.25 then start(nxt.piece, (nxt.pos or 0) - left); return end
    end
    local d = t - pos
    if map.pieces[pid].loop and len > 0 then d = (d + len / 2) % len - len / 2 end
    if math.abs(d) > ADAPT_TOL and music:getPitch() == 1 then
        music:seek(math.max(0, pos))
        Sound.adaptiveSeeks = (Sound.adaptiveSeeks or 0) + 1       -- (recolocaciones: se oyen; el arnés las cuenta)
    end
end

-- ¿Está sonando una música adaptativa?
function Sound.adaptivePlaying() return musicName == Sound.ADAPTIVE and music ~= nil and music:isPlaying() end
-- La pieza adaptativa que suena y su punto (s), o nil (en UN JUGADOR el reloj del director lo sigue: el audio manda)
function Sound.adaptiveTell()
    if not Sound.adaptivePlaying() or paused then return nil end
    return adaptCur, music:tell()
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
    if xf and xf.src:isPlaying() then xf.src:pause(); table.insert(paused, xf.src) end
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
    if xf then xf.src:stop(); xf = nil end
    local lp = musicName and loops[musicName]
    if lp then lp:stop() end
    if paused then
        for _, src in ipairs(paused) do src:stop() end
        paused = nil
    end
    music, musicName, adaptCur = nil, nil, nil
end

function Sound.decimalPitch(score)
    local mult = score / 10
    return math.min(2.0, 0.9 + mult * 0.1)
end

return Sound