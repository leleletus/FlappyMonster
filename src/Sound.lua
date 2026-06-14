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

function Sound.load()
    load('dies',          'assets/sounds/dies.ogg',          'static')
    load('point',         'assets/sounds/point.ogg',         'static')
    load('decimal',       'assets/sounds/decimal.ogg',       'static')
    load('select',        'assets/sounds/select.ogg',        'static')
    load('jump',          'assets/sounds/jump.ogg',          'static')
    load('step',          'assets/sounds/step.ogg',          'static')
    load('dies2',         'assets/sounds/dies2.ogg',         'static')
    load('enemyExplode',  'assets/sounds/enemyExplode.ogg',  'static')
    load('waterWarning',   'assets/sounds/S1_C2.ogg',          'static')
    load('airGasp',        'assets/sounds/airGasp.ogg',        'static')
    load('waterSplash',    'assets/sounds/S1_AA.ogg',     'static')
    load('waterSplashOut', 'assets/sounds/WaterSplash.ogg',     'static')
    load('drowning',      'assets/sounds/drowning.ogg',      'stream')
    load('glugluglu',     'assets/sounds/glugluglu.ogg',     'static')
    if sources['drowning'] then sources['drowning']:setLooping(false) end
    load('menus',         'assets/sounds/menus.ogg',         'stream')
    load('level',         'assets/sounds/level.ogg',         'stream')
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