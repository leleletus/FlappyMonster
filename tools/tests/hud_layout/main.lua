-- tools/tests/hud_layout — EL HUD SIN PISARSE (0.5.204, docs/design/ux-round-2026-11.md «HUD layout pass»; el usuario:
-- la barra del jefe tapaba los puntos y el aviso de la muerte iba pegado a ellos). Con el juego real, escenas con TODO
-- el HUD a la vez — pelea de jefe (barra del jefe y la del jugador), vidas, linterna (nivel a oscuras), estrellas,
-- botón de pausa (ratón), el aviso de la muerte, ¡CORRE! de la persecución, ¡RESACA!, el HUD de Flappy y su bolsa —
-- se dibujan a 960, 1280 y 1600 de ancho; cada elemento apunta su rectángulo (src/ui/HudRects.lua) y ninguno puede
-- pisar a otro ni salirse de la pantalla. Capturas <save>/hud_<escena>_<ancho>.png.
--   tools/tests/run.sh hud_layout
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad = love.load

local fails = 0
local function check(name, ok, msg)
    print(('%-14s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local WIDTHS = { 960, 1280, 1600 }

-- Un nivel en marcha, ya en la pelea del jefe (si tiene), sin tarjeta ni cuenta atrás
local function scene(level, o)
    o = o or {}
    gStateMachine:change('adventure', { level = 'assets/levels/' .. level .. '.json', returnTo = 'free_play',
                                         atBoss = o.boss, powerups = o.powerups })
    local st = gStateMachine:_top()
    if st.introScene then st.introScene:finish(); st.introScene = nil end
    st.card, st.startCd, st.startGoT = nil, nil, nil
    st.player.invT = 999
    if o.boss then
        for _ = 1, 1200 do
            st:update(1 / 60)
            local z = st.level.bossZones and st.level.bossZones[1]
            if z and z.state == 'fight' then break end
        end
        st.bossFightT = 5
    end
    st.player.hp = math.max(1, st.player.hpMax - 1)                  -- (le falta vida: se ve su barra)
    st.stats.starsTotal, st.stats.stars = 3, 1                      -- (las estrellas del nivel, arriba)
    st.deathCause, st.deathShowT = { kind = 'spikes' }, 0.5         -- (el aviso de la muerte, a la vista)
    if o.prep then o.prep(st) end
    return st
end

-- Dibuja la escena a cada ancho y mira los rectángulos
local function measure(name, st)
    local HudRects = require 'src/ui/HudRects'
    local W0 = WINDOW_W
    local bad, seen = {}, {}
    for _, w in ipairs(WIDTHS) do
        WINDOW_W = w
        local cv = love.graphics.newCanvas(w, WINDOW_H)
        love.graphics.setCanvas(cv); love.graphics.clear(0, 0, 0, 1)
        st:render()
        love.graphics.setCanvas()
        cv:newImageData():encode('png', ('hud_%s_%d.png'):format(name, w))
        local L = HudRects.list()
        for _, r in ipairs(L) do seen[r.name] = true end
        for i = 1, #L do
            local a = L[i]
            if a.x < 0 or a.y < 0 or a.x + a.w > w or a.y + a.h > WINDOW_H then
                bad[#bad + 1] = ('%d: %s fuera (%d,%d %dx%d)'):format(w, a.name, a.x, a.y, a.w, a.h)
            end
            for j = i + 1, #L do
                local b = L[j]
                if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
                    bad[#bad + 1] = ('%d: %s pisa %s'):format(w, a.name, b.name)
                end
            end
        end
    end
    WINDOW_W = W0
    local names = {}
    for k in pairs(seen) do names[#names + 1] = k end
    table.sort(names)
    return bad, table.concat(names, ',')
end

local function case(name, level, o, want)
    local st = scene(level, o)
    local bad, names = measure(name, st)
    local missing = {}
    for _, n in ipairs(want or {}) do if not names:find(n, 1, true) then missing[#missing + 1] = n end end
    check(name, #bad == 0 and #missing == 0, ('[%s]%s: %s'):format(names, #missing > 0 and (' faltan ' .. table.concat(missing, ',')) or '',
        #bad == 0 and 'nada se pisa' or table.concat(bad, ' · ')))
end

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    Input.lastDevice = 'mouse'                                      -- (el botón de pausa a la vista)
    -- 1. pelea a oscuras: jefe, vida, vidas, linterna, estrellas, pausa, aviso de la muerte
    case('jefe_oscuro', 'gruta_del_farol', { boss = true }, { 'score', 'lives', 'light', 'collect', 'pause', 'boss', 'players', 'death' })
    -- 2. pelea normal (otra isla, otro jefe)
    case('jefe', 'reino_gummy', { boss = true }, { 'score', 'lives', 'collect', 'pause', 'boss', 'players', 'death' })
    -- 3. la persecución del Espejo: ¡CORRE! arriba
    case('corre', 'huida_del_espejo', { prep = function(st)
        local au = st.level.autoScroll
        if au then au.state = 'run' end
        st.level._chase, st.level._runAt = true, love.timer.getTime() - 2
    end }, { 'score', 'lives', 'collect', 'run', 'death' })
    -- 4. la resaca: ¡RESACA! bajo las barras de la pelea
    case('resaca', 'cala_resaca', { boss = true, prep = function(st)
        local f = (st.level.floods or {})[1]
        if f then f.alertAt, f.undertow = love.timer.getTime() - 1, 1 end
    end }, { 'score', 'boss', 'undertow' })
    -- 5. un nivel Flappy con su jefe: corazones, cargas y la bolsa de los power-ups
    case('flappy', 'valle_redcoptero', { boss = true, prep = function(st)
        st.powerups = st.powerups or { items = function() return { { id = 'shield', count = 2 } } end }
    end }, { 'score', 'flappy', 'bag', 'death' })
    -- 6. ACCESIBILIDAD: los símbolos para daltónicos sobre los bloques y activadores ON / OFF (captura hud_simbolos_*)
    require('src/core/Settings').cbSymbols = true
    case('simbolos', 'valle_soleado', { prep = function(st)
        local c0 = math.floor(st.player.x / TILE_PX) + 2
        local r0 = math.floor(st.player.y / TILE_PX) - 1
        local TT = require 'src/world/tiles/TileTypes'
        for i, n in ipairs({ 'switchblock_on', 'switchblock_on_x', 'switchblock_off', 'switchblock_off_x', 'switch_on', 'switch_off' }) do
            st.level:setTileRaw(c0 + i, r0, require('src/world/tiles/TileCodec').encode(TT.byName[n].id))
        end
        st.camX = math.max(0, (c0 + 3) * TILE_PX - WINDOW_W / 2)
        st.camY = math.max(0, (r0 - 1) * TILE_PX - WINDOW_H / 2)
        st.camFrozen = true
    end }, { 'score' })
    require('src/core/Settings').cbSymbols = false
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
