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
    -- (en fondos claros de día NADA: los sprites ya llevan su contorno oscuro — el usuario, 2026-11-12 —)
    check('simple_tipo', night == 'light' and snow == nil and meadow == nil and snowNight == 'light'
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

-- Las copias del modo simple no tienen efectos: lo que el dibujo apunte en el dueño, las partículas y el azar
case('efectos', function()
    local prev = Settings.edge
    Settings.edge = 'simple'
    local Particles = require 'src/fx/Particles'
    local owner = { x = 0, y = 0 }
    local emits, realEmit = 0, Particles.emit
    local fn = function()
        owner._lx = (owner._lx or 0) + 1                    -- (un dibujo que lleva la cuenta de algo)
        owner._new = true
        Particles.emit('ember', 0, 0)
        math.random()
    end
    Edge.level = { light = 'night' }
    for i = 0, 5 do at(i * 0.1); Edge.draw(owner, 0, 0, function() end) end       -- (borde entero)
    Particles.emit = function(...) emits = emits + 1 end
    math.randomseed(7); local want = (function() math.random(); return math.random() end)()
    math.randomseed(7)
    owner._lx, owner._new = 10, nil
    at(1); Edge.draw(owner, 0, 0, function(...)
        local inPass = Edge.inPass()
        fn()
        if inPass then return end
    end)
    local got = math.random()
    Particles.emit = realEmit
    Edge.level = nil
    Settings.edge = prev
    check('efectos', owner._lx == 11 and owner._new == true and emits == 1 and got == want,
        ('cuenta del dibujo=%d (quiero 11) · partículas=%d (quiero 1) · el azar sigue igual=%s'):format(owner._lx, emits, tostring(got == want)))
end)

-- ── El rasgo `edge`: por categoría, y cada tipo puede cambiarlo ─────────────
case('rasgo', function()
    local EntityTypes = require 'src/world/entities/base/EntityTypes'
    local Entities = require 'src/world/entities/Entities'
    local DataEnemy = require 'src/world/entities/base/DataEnemy'
    local bad, n = {}, 0
    for name, t in pairs(EntityTypes.byName) do
        local cls = t.class
        local want = EntityTypes.EDGE_DEFAULT[t.category] == true
        if t.edgeOwn ~= nil then want = t.edgeOwn end          -- (el tipo lo cambia: `edge = true / false`)
        if (cls.edge == true) ~= want then bad[#bad + 1] = name .. '(' .. t.category .. ')' end
        n = n + 1
    end
    local g = Entities.create({ type = 'gummy', col = 5, row = 5, props = {} })
    local lava = Entities.create({ type = 'crabby_lava', col = 5, row = 5, props = {} })
    local spec = DataEnemy.read(DataEnemy.ids()[1])
    spec.darkEdge, spec.edge = { 1, 1, 1, 1 }, nil
    local fromDark = DataEnemy.typeDef(spec).class.edge
    spec.darkEdge, spec.edge = nil, false
    local off = DataEnemy.typeDef(spec).class.edge
    check('rasgo', #bad == 0 and n > 20 and g.edge == true and lava.edge == true and g.edgeThin == true
        and fromDark == true and off == false,
        ('%d tipos; distintos de su categoría: %s · gummy=%s lava=%s fino=%s · JSON darkEdge=%s edge:false=%s'):format(n,
            #bad == 0 and 'ninguno' or table.concat(bad, ' '), tostring(g.edge), tostring(lava.edge), tostring(g.edgeThin),
            tostring(fromDark), tostring(off)))
end)

-- ── Escenas del juego de verdad (AdventureState) ──────────────────────────────
-- Un nivel en marcha, sin tarjeta ni cuenta atrás, con el reloj y el azar fijos: la misma foto cada vez
local realGetTime = love.timer.getTime
local function scene(level, o)
    o = o or {}
    love.timer.getTime = function() return 100 end
    math.randomseed(7); love.math.setRandomSeed(7)
    gStateMachine:change('adventure', { level = 'assets/levels/' .. level .. '.json', returnTo = 'free_play' })
    local st = gStateMachine:_top()
    if st.introScene then st.introScene:finish(); st.introScene = nil end
    st.card, st.startCd, st.startGoT = nil, nil, nil
    st.player.invT = 0
    if o.prep then o.prep(st) end
    for _ = 1, (o.frames or 30) do st:update(1 / 60) end
    return st
end
local function photo(st, name)
    local cv = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(cv); love.graphics.clear(0, 0, 0, 1)
    math.randomseed(7); love.math.setRandomSeed(7)
    st:render()
    love.graphics.setCanvas()
    local data = cv:newImageData()
    data:encode('png', 'edge_' .. name .. '.png')
    return data
end
local function samePixels(a, b)
    if a:getWidth() ~= b:getWidth() or a:getHeight() ~= b:getHeight() then return false, -1 end
    local diff = 0
    for y = 0, a:getHeight() - 1, 2 do
        for x = 0, a:getWidth() - 1, 2 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.02 then diff = diff + 1 end
        end
    end
    return diff == 0, diff
end


-- ── Modo shader: la pasada, píxel a píxel, en lienzos pequeños ─────────────────
-- Fondo liso de 64x64; un "sprite" de 16x16 en (24, 24) por Edge.begin / finish; se lee el resultado
local function composite(bg, sprite, o)
    o = o or {}
    local W, H = o.w or 64, o.h or 64
    local scene = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(scene)
    if o.split then
        love.graphics.clear(bg[1], bg[2], bg[3], 1)
        love.graphics.setColor(o.split[1], o.split[2], o.split[3], 1)
        love.graphics.rectangle('fill', W / 2, 0, W / 2, H)
    else
        love.graphics.clear(bg[1], bg[2], bg[3], 1)
    end
    love.graphics.setCanvas()
    local light
    if o.light then
        light = love.graphics.newCanvas(math.ceil(W / 4), math.ceil(H / 4))
        love.graphics.setCanvas(light); love.graphics.clear(o.light, o.light, o.light, 1); love.graphics.setCanvas()
    end
    Edge.begin(scene)
    love.graphics.setColor(sprite[1], sprite[2], sprite[3], sprite[4] or 1)
    love.graphics.rectangle('fill', o.sx or 24, o.sy or 24, o.sw or 16, 16)
    if o.extra then o.extra() end
    love.graphics.setColor(1, 1, 1, 1)
    local out = Edge.finish(light)
    love.graphics.setCanvas()
    return out:newImageData(), out
end
local function px(img, x, y) local r, g, b, a = img:getPixel(x, y); return r, g, b, a end
local DARKBG, DARKSP = { 0.05, 0.05, 0.08 }, { 0.08, 0.08, 0.1 }

case('pixel_oscuro', function()
    local img = composite(DARKBG, DARKSP)
    local r1 = px(img, 23, 30)                     -- (1 px fuera del borde izquierdo)
    local r3 = px(img, 21, 30)                     -- (3 px fuera)
    local rin = px(img, 30, 30)                    -- (dentro: el sprite tal cual)
    check('pixel_oscuro', r1 > 0.7 and near(r3, 0.05, 0.02) and near(rin, 0.08, 0.02),
        ('a 1 px=%.2f (filo claro) · a 3 px=%.2f (fondo) · dentro=%.2f'):format(r1, r3, rin))
end)
case('pixel_claro', function()
    local img = composite({ 0.92, 0.95, 1 }, { 0.85, 0.9, 0.95 })
    local r1 = px(img, 23, 30)
    check('pixel_claro', r1 < 0.2, ('a 1 px=%.2f (filo oscuro)'):format(r1))
end)
case('pixel_contraste', function()
    local img = composite({ 0, 0, 0 }, { 1, 1, 1 })
    local r1 = px(img, 23, 30)
    check('pixel_contraste', r1 < 0.02, ('negro contra blanco, a 1 px=%.2f (sin filo)'):format(r1))
end)
case('pixel_mitad', function()
    -- fondo oscuro a la izquierda y blanco a la derecha; un sprite oscuro ancho que cruza la mitad
    local img = composite(DARKBG, DARKSP, { split = { 1, 1, 1 }, sx = 16, sw = 32 })
    local left = px(img, 15, 30)                   -- (fuera, por la izquierda: fondo oscuro → filo)
    local right = px(img, 48, 30)                  -- (fuera, por la derecha: fondo blanco → el sprite ya contrasta)
    check('pixel_mitad', left > 0.7 and right > 0.95, ('izquierda=%.2f (filo) · derecha=%.2f (fondo blanco, sin filo)'):format(left, right))
end)
case('oscuridad', function()
    local img = composite(DARKBG, DARKSP, { light = 0.055 })
    local r1 = px(img, 23, 30)
    check('oscuridad', near(r1, 0.05, 0.02), ('a oscuras fuera de la luz, a 1 px=%.2f (sin filo: no delata)'):format(r1))
end)
case('translucido', function()
    local img = composite(DARKBG, { DARKSP[1], DARKSP[2], DARKSP[3], 0.5 })
    local r1 = px(img, 23, 30)
    check('translucido', r1 > 0.3 and r1 < 0.6, ('sprite a media transparencia, a 1 px=%.2f (filo a medias)'):format(r1))
end)
case('directo_sombra', function()
    local img = composite(DARKBG, DARKSP, { extra = function()
        Edge.direct(function()
            love.graphics.setColor(0.06, 0.06, 0.09, 1)
            love.graphics.rectangle('fill', 4, 50, 20, 6)
        end)
    end })
    local r = px(img, 3, 52)
    check('directo_sombra', near(r, 0.05, 0.02), ('junto a la sombra (Edge.direct)=%.2f (sin filo)'):format(r))
end)
case('aditivo', function()
    local glow = function()
        love.graphics.setBlendMode('add')
        love.graphics.setColor(0.3, 0.2, 0.1, 1)
        love.graphics.rectangle('fill', 2, 2, 10, 10)
        love.graphics.setBlendMode('alpha')
    end
    local img = composite(DARKBG, DARKSP, { extra = function() Edge.direct(glow) end })
    local r, g = px(img, 6, 6)
    local r0 = px(img, 13, 6)
    check('aditivo', near(r, 0.35, 0.02) and near(g, 0.25, 0.02) and near(r0, 0.05, 0.02),
        ('brillo aditivo por Edge.direct=%.2f,%.2f (quiero 0.35,0.25) · al lado=%.2f (sin filo)'):format(r, g, r0))
end)
case('borde_pantalla', function()
    local img = composite(DARKBG, DARKSP, { sx = 0 })
    local r = px(img, 63, 30)
    check('borde_pantalla', near(r, 0.05, 0.02), ('sprite pegado a la izquierda: la última columna=%.2f (fondo)'):format(r))
end)
case('tamano', function()
    local a = select(2, composite(DARKBG, DARKSP))
    local b = select(2, composite(DARKBG, DARKSP, { w = 96, h = 80 }))
    check('tamano', a:getWidth() == 64 and b:getWidth() == 96 and b:getHeight() == 80,
        ('lienzos: %dx%d y %dx%d'):format(a:getWidth(), a:getHeight(), b:getWidth(), b:getHeight()))
end)
case('reuse', function()
    local prev = Settings.edge
    Settings.edge = 'shader'
    local st = scene('fortaleza_malvada')
    local SceneLayers = require 'src/world/level/SceneLayers'
    local target = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(target)
    local out = SceneLayers.draw(st.level, st.camX, st.camY, st.sceneCanvas, st.enemies, st._actorsFn)
    love.graphics.setCanvas()
    local want = out:newImageData()
    love.graphics.setCanvas(st.sceneCanvas); love.graphics.clear(1, 0, 1, 1); love.graphics.setCanvas()   -- (lo de antes de juntar, ensuciado)
    local frozen = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(frozen)
    SceneLayers.draw(st.level, st.camX, st.camY, st.sceneCanvas, st.enemies, st._actorsFn, nil, true)
    love.graphics.setCanvas()
    local got = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(got); love.graphics.clear(0, 0, 0, 1)
    st.level:renderWaterEffect(st.camX, st.camY, out)
    love.graphics.setCanvas()
    local ok, d = samePixels(frozen:newImageData(), got:newImageData())
    love.timer.getTime = realGetTime
    Settings.edge = prev
    check('reuse', out ~= st.sceneCanvas and ok, ('el golpe congelado vuelve a poner la escena YA juntada: %s'):format(ok and 'sí' or (d .. ' píxeles distintos')))
end)

-- Capturas de escenas de verdad en modo shader (SHOT=1): para mirarlas
case('capturas', function()
    if os.getenv('SHOT') ~= '1' then return end
    local prev = Settings.edge
    for _, mode in ipairs({ 'shader', 'simple' }) do
        Settings.edge = mode
        for _, lv in ipairs({ 'gruta_del_farol', 'bajo_el_hielo', 'fortaleza_malvada', 'cumbres_escarcha', 'cripta_del_silencio' }) do
            local st = scene(lv, { frames = 40 })
            photo(st, lv .. '_' .. mode)
        end
    end
    love.timer.getTime = realGetTime
    Settings.edge = prev
    check('capturas', true, 'edge_<nivel>_<modo>.png en la carpeta de guardado')
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
