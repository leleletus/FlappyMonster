-- tools/tests/edge_look — EL BORDE DE CONTRASTE (src/fx/Edge.lua, docs/design/entity-edge-shader.md): el modo (shader /
-- simple, por aparato y por ajuste), las reglas del modo simple (qué color, el fundido, lo que va sin borde) y, en modo
-- shader, la pasada que compara cada borde con lo que tiene detrás, píxel a píxel, en lienzos pequeños.
--   tools/tests/run.sh edge_look            (ONLY=a,b: solo esos casos; SHOT=1: capturas <save>/edge_*.png)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad = love.load

local fails = 0
local function check(name, ok, msg)
    print(('%-16s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function near(a, b, tol) return math.abs(a - b) <= tol end

local Edge, Settings, Shaders
local cases, ORDER = {}, {}
local function case(name, fn) cases[name] = fn; ORDER[#ORDER + 1] = name end

-- Un reloj a mano para el fundido
local clockT = 0
local function at(t) clockT = t end

-- ── El modo ──────────────────────────────────────────────────────────────────
case('modo', function()
    local d = Edge.defaultMode
    local okOs = d('Linux') == 'shader' and d('Windows') == 'shader' and d('OS X') == 'shader'
        and d('Android') == 'simple' and d('Horizon') == 'simple'
    local real, prev = Shaders.get, Settings.edge
    Settings.edge = 'shader'
    local withSh = Edge.mode()
    Shaders.get = function() return nil end
    local without = Edge.mode()
    Shaders.get = real
    Settings.edge = 'simple'
    local simple = Edge.mode()
    Settings.edge = prev
    check('modo', okOs and withSh == 'shader' and without == 'simple' and simple == 'simple',
        ('por SO=%s · ajuste shader=%s · sin shaders=%s · ajuste simple=%s'):format(tostring(okOs), withSh, without, simple))
end)

-- ── Modo simple: qué color ───────────────────────────────────────────────────
case('simple_tipo', function()
    local k = Edge.simpleKind
    local night = k({ light = 'night' }, 0, 0)
    local snow = k({ light = 'day', background = 'snow' }, 0, 0)
    local meadow = k({ light = 'day', background = 'meadow' }, 0, 0)
    local snowNight = k({ light = 'night', timeOfDay = 'night', background = 'snow' }, 0, 0)
    local deep = { depth = 'cave', surfaceRow = 6 }               -- (superficie en y = 320)
    local up, down = k(deep, 0, 150), k(deep, 0, 600)
    local far = k({ dark = true, players = { { x = 2000, y = 2000, facing = 1 } } }, 0, 0)
    local by = k({ dark = true, players = { { x = 10, y = 0, facing = 1 } } }, 0, 0)
    check('simple_tipo', night == 'light' and snow == 'dark' and meadow == nil and snowNight == 'light'
        and up == nil and down == 'light' and far == nil and by == 'light',
        ('noche=%s nieve=%s pradera=%s nieve de noche=%s · profundidad arriba=%s abajo=%s · a oscuras lejos=%s junto a un jugador=%s')
        :format(tostring(night), tostring(snow), tostring(meadow), tostring(snowNight), tostring(up), tostring(down), tostring(far), tostring(by)))
end)

-- ── Modo simple: el fundido ──────────────────────────────────────────────────
case('simple_fundido', function()
    local prev = Settings.edge
    Settings.edge = 'simple'
    local owner = {}
    local noop = function() end
    Edge.level = { light = 'night' }
    at(0);    Edge.draw(owner, 0, 0, noop)
    at(0.15); Edge.draw(owner, 0, 0, noop)
    local half = Edge.alphaOf(owner)
    at(0.4);  Edge.draw(owner, 0, 0, noop)
    local full = Edge.alphaOf(owner)
    Edge.level = { light = 'day' }
    at(0.45); Edge.draw(owner, 0, 0, noop)
    local leaving = Edge.alphaOf(owner)
    at(0.8);  Edge.draw(owner, 0, 0, noop)
    local gone = Edge.alphaOf(owner)
    Edge.level = nil
    Settings.edge = prev
    check('simple_fundido', near(half, 0.5, 0.1) and full == 1 and leaving > 0.5 and gone == 0,
        ('0,15 s=%.2f · 0,4 s=%.2f · al salir a la luz=%.2f · 0,35 s después=%.2f'):format(half, full, leaving, gone))
end)

-- ── Modo simple: lo que va sin borde ─────────────────────────────────────────
case('directo', function()
    local prev = Settings.edge
    Settings.edge = 'simple'
    local owner, n = {}, 0
    local fn = function() Edge.direct(function() n = n + 1 end) end
    Edge.level = { light = 'night' }
    for i = 0, 10 do at(i * 0.1); Edge.draw(owner, 0, 0, fn) end          -- (ya con el borde entero)
    n = 0
    at(1.2); Edge.draw(owner, 0, 0, fn)
    local a = Edge.alphaOf(owner)
    Edge.level = nil
    Settings.edge = prev
    check('directo', a == 1 and n == 1, ('borde=%.2f · lo de Edge.direct se dibujó %d vez/veces (quiero 1)'):format(a, n))
end)

case('sombreador', function()
    local prev = Settings.edge
    Settings.edge = 'simple'
    local owner = {}
    local other = Shaders.get('invert')
    local flat = Shaders.get('silhouette_flat')
    local seenInPass, kept = 0, true
    local fn = function()
        if Edge.inPass() then
            seenInPass = seenInPass + 1
            love.graphics.setShader(other)
            if love.graphics.getShader() ~= flat then kept = false end
            love.graphics.setShader()
        end
    end
    Edge.level = { light = 'night' }
    for i = 0, 5 do at(i * 0.1); Edge.draw(owner, 0, 0, fn) end
    local after = love.graphics.getShader()
    Edge.level = nil
    Settings.edge = prev
    check('sombreador', seenInPass > 0 and kept and after == nil and other ~= nil and flat ~= nil,
        ('copias=%d · el plano se mantiene=%s · después sin shader=%s'):format(seenInPass, tostring(kept), tostring(after == nil)))
end)

-- ── El ajuste ────────────────────────────────────────────────────────────────
case('ajuste', function()
    local Lang = require 'src/core/Lang'
    local prev = Settings.edge
    Settings.set('edge', 'simple')
    Settings.edge = nil
    Settings.load()
    local loaded = Settings.edge
    Settings.set('edge', prev)
    local row
    for _, t in ipairs(require('src/ui/menu/SettingsRows').TABS) do
        if t.id == 'access' then for _, r in ipairs(t.rows) do if r.id == 'edge' then row = r end end end
    end
    local missing = {}
    for _, lang in ipairs({ 'es', 'en' }) do
        Lang.set(lang)
        for _, key in ipairs({ 'settings.row_edge', 'settings.desc_edge', 'settings.val_edge_shader', 'settings.val_edge_simple' }) do
            if not Lang.has(key) or Lang.get(key) == key or Lang.get(key) == '' then missing[#missing + 1] = lang .. ':' .. key end
        end
    end
    Lang.set(Settings.language)
    check('ajuste', loaded == 'simple' and row ~= nil and #missing == 0,
        ('guardado y leído=%s · fila en AYUDAS=%s · textos que faltan: %s'):format(tostring(loaded), tostring(row ~= nil),
            #missing == 0 and 'ninguno' or table.concat(missing, ' ')))
end)

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    Edge = require 'src/fx/Edge'
    Settings = require 'src/core/Settings'
    Shaders = require 'src/fx/Shaders'
    Edge.clock = function() return clockT end
    local only = os.getenv('ONLY')
    local want
    if only and only ~= '' then want = {}; for n in only:gmatch('[^,]+') do want[n] = true end end
    for _, name in ipairs(ORDER) do
        if not want or want[name] then
            local ok, err = pcall(cases[name])
            if not ok then check(name, false, 'ERROR ' .. tostring(err)) end
        end
    end
    love.event.quit(fails == 0 and 0 or 1)
end
