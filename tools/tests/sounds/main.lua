-- tools/tests/sounds — los sonidos del juego, de verdad (src/Sound.lua):
--  1. todo nombre usado en el código con Sound.play / playAt / playTracked
--     ('literal') está cargado (un nombre mal escrito no sonaría nunca);
--  2. los sonidos de NAMES (por defecto, los nuevos) se reproducen: la fuente
--     arranca y suena;
--  3. volumen tras la ganancia de Sound.GAIN (tramo más fuerte de 100 ms, como
--     se midió la mezcla): debe quedar en [-15, -8] dBFS (los de LOUD, grandes
--     explosiones, hasta -4 dBFS).
--
--   tools/tests/run.sh sounds                       (NAMES=a,b,c para otros)
io.stdout:setvbuf('no')
-- Sonidos que PUEDEN ir más fuertes que el resto (explosiones grandes)
LOUD = { bombBlast = true }
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = require 'src/Sound'

local NAMES = os.getenv('NAMES') or
    'switchOn,switchOff,helmetBounce,helmetBreak,pufferWarn,pufferInflate,pufferDeflate,pufferPrick,cryoWindup,cryoBlast,cryoFreeze,cryoFree,snowLaugh,snowRoar,snowSpit,snowSplat,snowRoll,snowLand,snowSlam,snowCrash,snowDizzy,snowCrack,snowBurst,snowFlee,snowIntroRoll,snowBreath'

local fails = 0
local function check(ok, msg)
    print((ok and 'OK     ' or 'FALLA  ') .. msg)
    if not ok then fails = fails + 1 end
end

-- Nombres usados en el código (se lee el repo: run.sh lanza desde la raíz)
local function usedNames()
    local names, files = {}, {}
    local p = io.popen('{ git ls-files; git ls-files -o --exclude-standard; } | grep "\\.lua$" | grep -v "^resources/\\|^tools/"')
    for f in p:lines() do files[#files + 1] = f end
    p:close()
    for _, f in ipairs(files) do
        local fh = io.open(f)
        if fh then
            local src = fh:read('*a'); fh:close()
            for _, fn in ipairs({ 'play', 'playAt', 'playTracked' }) do     -- (playMusic = música, no efectos)
                for name in src:gmatch('Sound%.' .. fn .. "%(%s*'([%w_]+)'") do names[name] = names[name] or f end
                for name in src:gmatch('Sound%.' .. fn .. '%(%s*"([%w_]+)"') do names[name] = names[name] or f end
            end
        end
    end
    return names
end

-- dBFS del tramo más fuerte de 100 ms, con la ganancia aplicada
local function loudness(path, gain)
    local sd = love.sound.newSoundData(path)
    local n, ch, sr = sd:getSampleCount(), sd:getChannelCount(), sd:getSampleRate()
    local win, best = math.floor(sr * 0.1), 0
    local sq = {}
    for i = 0, n - 1 do
        local v = 0
        for c = 1, ch do v = v + sd:getSample(i, c) end
        v = math.max(-1, math.min(1, v / ch * gain))
        sq[i + 1] = v * v
    end
    local acc = 0
    for i = 1, n do
        acc = acc + sq[i]
        if i > win then acc = acc - sq[i - win] end
        if i >= math.min(win, n) then best = math.max(best, acc / math.min(win, i)) end
    end
    return 10 * math.log10(best + 1e-12)
end

local introTracks, cur, started, switched, clock, left = {}, 1, false, nil, 0, 0

function love.load()
    Sound.load()
    love.audio.setVolume(0)            -- (se reproducen de verdad, pero en silencio)
    -- 1. nombres usados en el código
    local missing = {}
    for name, f in pairs(usedNames()) do
        if not Sound.source(name) then missing[#missing + 1] = name .. ' (' .. f .. ')' end
    end
    table.sort(missing)
    check(#missing == 0, 'nombres usados en el código y cargados' ..
        (#missing > 0 and (': FALTAN ' .. table.concat(missing, ', ')) or ''))
    -- 2 y 3. los sonidos pedidos
    for name in NAMES:gmatch('[^,]+') do
        local src, path = Sound.source(name)
        if not src then
            check(false, name .. ': no está cargado')
        else
            local c = src:clone(); c:play()
            local playing = c:isPlaying(); c:stop()
            local g = Sound.GAIN[name] or 1
            local db = loudness(path, g)
            local top = LOUD[name] and -4 or -8
            check(playing and db >= -15 and db <= top,
                ('%-14s suena=%s  GAIN=%.2f  %.1f dBFS  (%s)'):format(name, tostring(playing), g, db, path))
        end
    end
    -- 4. pistas con INTRO + BUCLE: la intro suena una vez y el bucle entra pegado a su final (love.update)
    local Music = require 'src/Music'
    for _, tr in ipairs(Music.list) do
        if tr.intro and not tr.pending then table.insert(introTracks, tr.id) end
    end
end

-- Cada pista: se coloca la intro a 0.3 s de su final y se mira, frame a frame, cuándo entra el bucle
function love.update(dt)
    local id = introTracks[cur]
    if not id then
        print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
        return love.event.quit(fails == 0 and 0 or 1)
    end
    if not started then
        Sound.playMusic(id)
        local src = Sound.source(id)
        src:seek(src:getDuration() - 0.3)
        started, clock, left = true, 0, 0.3
        return
    end
    clock = clock + dt
    local src = Sound.source(id)
    local before = src:isPlaying() and (src:getDuration() - src:tell()) or -1     -- lo que le quedaba a la intro
    Sound.update(dt)
    local _, pos, part = Sound.musicPosition()
    if part == 'bucle' and not switched then
        switched = { left = before, pos = pos }
    end
    if switched and clock > 0.9 then
        local _, p2, part2 = Sound.musicPosition()
        check(switched.left <= 0.03 and switched.pos <= 0.03 and part2 == 'bucle' and not src:isPlaying(),
            ('%-22s intro → bucle: a la intro le quedaban %.0f ms, el bucle sigue (%.2f s) y la intro paró=%s')
                :format(id, switched.left * 1000, p2 or -1, tostring(not src:isPlaying())))
        Sound.stopMusic()
        cur, started, switched = cur + 1, false, nil
    elseif clock > 3 then
        check(false, id .. ': el bucle no llegó a entrar')
        Sound.stopMusic()
        cur, started, switched = cur + 1, false, nil
    end
end
