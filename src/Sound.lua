-- src/Sound.lua
local Sound = {}

local sources = {}
local music   = nil
local tracked = {}   -- fuentes rastreadas para stop/isPlaying individuales
local origin  = {}   -- name -> ruta del archivo o SoundData (herramientas de mezcla)
Sound._origin = origin

-- ── Mezcla ────────────────────────────────────────────────────────────────────
-- Ganancia por sonido para que todos se oigan parecido (medido: volumen del
-- tramo más fuerte de 100 ms ≈ -12 dBFS, como el salto o el punto). Se aplica
-- al cargar (se escalan las muestras), así se puede subir por encima de 1.
-- Los sonidos cortos de interfaz y pasos se dejan como están a propósito.
local GAIN = {
    -- archivos
    roundOver    = 2.8,  spikeHit   = 2.2,  dies2      = 0.65, glugluglu  = 0.8,
    airGasp      = 0.85, waterWarning = 1.4,
    -- sintetizados
    blockBreak   = 1.8,  checkpoint = 1.9,  collect    = 2.5,  gpImpact   = 1.6,
    gpStart      = 2.4,  headBump   = 2.0,  oneUp      = 2.0,  respawnFx  = 2.2,
    spikeShake   = 2.8,  stunned    = 2.5,  tick       = 1.8,  finish     = 1.2,
    sadtrombone  = 1.2,
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

-- Jingles chiptune sintetizados por código (onda cuadrada): no necesitan
-- archivos. notes = { {frecuencia Hz (0 = silencio), duración s}, ... }
local function synth(name, notes, vol)
    local ok, src = pcall(function()
        local rate, total = 22050, 0
        for _, n in ipairs(notes) do total = total + n[2] end
        local sd = love.sound.newSoundData(math.floor(total * rate) + 1, rate, 16, 1)
        local i = 0
        for _, n in ipairs(notes) do
            local len = math.floor(n[2] * rate)
            for k = 0, len - 1 do
                local v = 0
                if n[1] > 0 then
                    local t   = k / rate
                    local f   = n[1] * (1 + 0.012 * math.sin(t * 38) * math.min(1, t * 4))  -- vibrato
                    local env = math.min(1, k / 80) * math.min(1, (len - k) / 400)
                    if len > rate * 0.3 then env = env * (1 - 0.6 * k / len) end
                    v = ((t * f) % 1 < 0.5 and 1 or -1) * env * (vol or 0.25) * (GAIN[name] or 1)
                end
                sd:setSample(i, v); i = i + 1
            end
        end
        origin[name] = sd
        return love.audio.newSource(sd, 'static')
    end)
    if ok then sources[name] = src end
end

-- Efectos sintetizados con barrido de tono y/o ruido (8 bits).
-- parts = { {dur, f0, f1, wave='square'|'noise'|'tri', vol}, ... }
local function sfx(name, parts)
    local ok, src = pcall(function()
        local rate, total = 22050, 0
        for _, p in ipairs(parts) do total = total + p[1] end
        local sd = love.sound.newSoundData(math.floor(total * rate) + 1, rate, 16, 1)
        local i, phase, noiseV, noiseC = 0, 0, 0, 0
        for _, p in ipairs(parts) do
            local len = math.floor(p[1] * rate)
            for k = 0, len - 1 do
                local u   = k / math.max(1, len - 1)
                local f   = p[2] + (p[3] - p[2]) * u
                local env = math.min(1, k / 60) * (1 - u) ^ 1.3
                local v
                phase = phase + f / rate
                if p.wave == 'noise' then
                    noiseC = noiseC + f / rate
                    if noiseC >= 1 then noiseC = noiseC - 1; noiseV = math.random() * 2 - 1 end
                    v = noiseV
                elseif p.wave == 'tri' then
                    v = 1 - 4 * math.abs((phase % 1) - 0.5)
                else
                    v = (phase % 1 < 0.5) and 1 or -1
                end
                sd:setSample(i, math.max(-1, math.min(1, v * env * (p.vol or 0.25) * (GAIN[name] or 1)))); i = i + 1
            end
        end
        origin[name] = sd
        return love.audio.newSource(sd, 'static')
    end)
    if ok then sources[name] = src end
end

function Sound.load()
    -- Ground pound, bloques, coleccionables...
    sfx('gpStart',    { {0.16, 300, 900, wave='square', vol=0.16} })
    sfx('gpImpact',   { {0.05, 180, 60, wave='square', vol=0.3}, {0.28, 900, 200, wave='noise', vol=0.35} })
    sfx('blockBreak', { {0.22, 2600, 500, wave='noise', vol=0.32} })
    sfx('headBump',   { {0.06, 220, 140, wave='square', vol=0.2} })
    sfx('collect',    { {0.05, 1318, 1318, vol=0.16}, {0.05, 1760, 1760, vol=0.16}, {0.14, 2093, 2093, vol=0.14} })
    sfx('oneUp',      { {0.08, 659, 659, vol=0.18}, {0.08, 784, 784, vol=0.18}, {0.08, 1319, 1319, vol=0.18},
                        {0.08, 1047, 1047, vol=0.18}, {0.08, 1175, 1175, vol=0.18}, {0.2, 1568, 1568, vol=0.16} })
    sfx('checkpoint', { {0.1, 523, 523, wave='tri', vol=0.35}, {0.1, 784, 784, wave='tri', vol=0.35},
                        {0.25, 1047, 1047, wave='tri', vol=0.3} })
    sfx('spikeShake', { {0.35, 3000, 2000, wave='noise', vol=0.12} })
    sfx('respawnFx',  { {0.25, 400, 1400, wave='tri', vol=0.25} })
    sfx('stunned',    { {0.3, 1200, 800, wave='square', vol=0.1} })
    local G4, C5, E5, G5, C6 = 392, 523.25, 659.25, 783.99, 1046.5
    synth('fanfare', { {G4,.09},{C5,.09},{E5,.09},{G5,.09},{0,.05},{E5,.08},{G5,.08},{C6,.55} }, 0.22)
    synth('finish',  { {C5,.07},{E5,.07},{G5,.07},{C6,.22} }, 0.2)
    synth('sadtrombone', { {392,.28},{370,.28},{349,.28},{330,.7} }, 0.2)
    synth('tick', { {1318.5,.035} }, 0.12)
    load('dies',          'assets/sounds/dies.ogg',          'static')
    load('point',         'assets/sounds/point.ogg',         'static')
    load('decimal',       'assets/sounds/decimal.ogg',       'static')
    load('select',        'assets/sounds/select.ogg',        'static')
    load('jump',          'assets/sounds/jump.ogg',          'static')
    load('step',          'assets/sounds/step.ogg',          'static')
    load('dies2',         'assets/sounds/dies2.ogg',         'static')
    load('enemyExplode',  'assets/sounds/enemyExplode.ogg',  'static')
    load('waterWarning',   'assets/sounds/water/warning.ogg',          'static')
    load('airGasp',        'assets/sounds/water/air_gasp.ogg',        'static')
    load('waterSplash',    'assets/sounds/water/splash_in.ogg',     'static')
    load('waterSplashOut', 'assets/sounds/water/splash_out.ogg',     'static')
    load('drowning',      'assets/sounds/water/drowning.ogg',      'stream')
    load('glugluglu',     'assets/sounds/water/glugluglu.ogg',     'static')
    if sources['drowning'] then sources['drowning']:setLooping(false) end
    load('fwLaunch',      'assets/sounds/fireworks/launch.ogg',      'static')
    load('fwBlast1',      'assets/sounds/fireworks/blast1.ogg',       'static')
    load('fwBlast2',      'assets/sounds/fireworks/blast2.ogg',      'static')
    load('fwBlastLarge',  'assets/sounds/fireworks/blast_large.ogg', 'static')
    load('roundOver',     'assets/sounds/round_over.ogg',    'static')
    load('spikeHit',      'assets/sounds/spike_hit.wav',     'static')
    load('youWin',        'assets/music/victory.ogg',       'stream')
    load('menus',         'assets/music/menus.ogg',         'stream')
    load('level',         'assets/music/level.ogg',         'stream')
    if sources['menus'] then sources['menus']:setLooping(true) end
    if sources['level'] then sources['level']:setLooping(true) end
end

function Sound.play(name, pitch, volume)
    local src = sources[name]
    if not src then return end
    local clone = src:clone()
    clone:setPitch(pitch   or 1.0)
    clone:setVolume(volume or 1.0)
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

function Sound.playMusic(name, volume)
    local src = sources[name]
    if not src then return end
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
    src:play()
    music = src
end

function Sound.setMusicVolume(v)
    if music then music:setVolume(v) end
end

-- ¿Está sonando la pista `name` (o cualquier música si name es nil)?
function Sound.isMusicPlaying(name)
    if not music or not music:isPlaying() then return false end
    return name == nil or sources[name] == music
end

-- Lerp del pitch de la música (usado para el slowdown al morir)
function Sound.setMusicPitch(pitch)
    if music and music:isPlaying() then
        music:setPitch(math.max(0.1, pitch))
    end
end

-- Pausa: congela la música y los sonidos largos (ahogamiento) donde van,
-- para continuar EXACTAMENTE desde ahí al despausar.
local paused = nil
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

function Sound.stopMusic()
    if music and music:isPlaying() then music:stop() end
    music = nil
end

function Sound.decimalPitch(score)
    local mult = score / 10
    return math.min(2.0, 0.9 + mult * 0.1)
end

return Sound