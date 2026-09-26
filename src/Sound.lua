-- src/Sound.lua
local Sound = {}

local sources = {}
local music   = nil
local tracked = {}   -- fuentes rastreadas para stop/isPlaying individuales

local function load(name, path, stype)
    local ok, result = pcall(love.audio.newSource, path, stype)
    if ok then
        sources[name] = result
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
                    v = ((t * f) % 1 < 0.5 and 1 or -1) * env * (vol or 0.25)
                end
                sd:setSample(i, v); i = i + 1
            end
        end
        return love.audio.newSource(sd, 'static')
    end)
    if ok then sources[name] = src end
end

function Sound.load()
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

function Sound.stopMusic()
    if music and music:isPlaying() then music:stop() end
    music = nil
end

function Sound.decimalPitch(score)
    local mult = score / 10
    return math.min(2.0, 0.9 + mult * 0.1)
end

return Sound