-- tools/tests/collection — LA COLECCIÓN del modo historia (src/states/story/StoryCollectionState.lua) con el juego real:
--  1. textos: cada entrada de assets/story/collectibles.json tiene name / desc / how / hint en TODOS los idiomas, y la
--     ayuda del mapa trae la tecla de la Colección ({alt}) del aparato que se usa (`textos`);
--  2. partida de prueba con 1 de los coleccionables: desde el MAPA, {alt} (la linterna: [F] / [Y]) abre la Colección
--     ENCIMA del mapa (`abrir`);
--  3. las fichas: una por entrada del catálogo; la que se tiene, con su icono y su "cómo"; las demás, "???" y pista;
--     la cuenta 1 / N (`fichas`);
--  4. navegar con las flechas por la rejilla (izquierda / derecha / abajo / arriba, sin salirse) y tocar una ficha
--     la elige (`navegar`, `tocar`);
--  5. ATRÁS vuelve al MISMO mapa (el mismo estado, mismo mundo, nodo y sitio del monstruo) (`volver`);
--  6. tocar la ficha de los fragmentos del mapa también la abre; a 960 de ancho, una columna y la elegida de abajo se
--     ve (desplaza); VOLVER (esquina) la cierra (`tactil`, `ancho960`);
--  6b. OTRO ESTADO de la partida (`data.collect[id] = 'stolen'`: el Groove robó las astillas): esas fichas enseñan el
--     icono de ese estado (collectibles.json `states.stolen.icon`: la corona / el amuleto vacíos), la etiqueta
--     ROBADA y su texto, y siguen contando como ganadas (`robada`, captura collection_robada.png);
--  7. lo que llevan PUESTO los jefes (Boss:drawWear): el Mega Crabby su corona y el Lúgubre su amuleto se dibujan;
--     con props.wear = false, no; el Mega Crabby helado no la lleva (`piezas`).
-- Capturas: <save>/collection_{1280,960,960_abajo,1600,mapa,jefes}.png, copiadas también a
-- /home/mtvemo/FlappyMonster_pruebas/coleccion/ (si existe la carpeta).
--   tools/tests/run.sh collection
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw

local press, realInput = {}, nil
local function pressNext(a) press[a] = true end
local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local step, t, T, shotQ = 'start', 0, 0, {}
local PREV = '/home/mtvemo/FlappyMonster_pruebas/coleccion/'
local Save, Run, Collect, L
local MAP, MAPPOS, NAV, N, STOLEN

function love.load(a)
    gameLoad(a)
    for _, cb in ipairs({ 'mousemoved', 'mousepressed', 'mousereleased', 'wheelmoved', 'touchpressed',
                          'touchmoved', 'touchreleased', 'focus' }) do love[cb] = function() end end
    love.audio.setVolume(0)
    realInput = Input
    Save, Run, Collect, L = require 'src/story/Save', require 'src/story/Run', require 'src/story/Collect', require 'src/core/Lang'
    for i = 1, Save.SLOTS do Save.delete(i) end
    -- partida de prueba: tiene SOLO el primero del catálogo
    local d = Save.new('normal')
    d.collect = { [Collect.LIST[1].id] = true }
    Save.write(1, d)
    Run.open(1)
    gStateMachine:change('story_map')
end

local function top() return gStateMachine:_top() end
local function shot(name) shotQ[#shotQ + 1] = name end
local function resize(w, h) love.window.setMode(w, h, { resizable = true }); love.resize(w, h) end
local go = function(s) step, T = s, t end

-- Los textos de cada coleccionable, en todos los idiomas
local function checkTexts()
    local missing = {}
    local langs = {}
    for _, lg in ipairs(L.LANGUAGES) do langs[#langs + 1] = type(lg) == 'table' and (lg.id or lg[1]) or lg end
    for _, lg in ipairs(langs) do
        local k = L.keys(lg)
        for _, c in ipairs(Collect.LIST) do
            for _, f in ipairs({ 'name', 'desc', 'how', 'hint' }) do
                local key = (c.keys or ('story.collect.' .. c.id)) .. '.' .. f
                if not k[key] then missing[#missing + 1] = lg .. ':' .. key end
            end
            if not k['story.collect.kind.' .. tostring(c.kind)] then missing[#missing + 1] = lg .. ':kind.' .. tostring(c.kind) end
        end
    end
    local dev = realInput.lastDevice
    realInput.lastDevice = 'keyboard'; local hk = L('story.map_hint')
    realInput.lastDevice = 'gamepad'; local hp = L('story.map_hint')
    realInput.lastDevice = dev
    check('textos', #missing == 0 and hk:find('[F]', 1, true) and hp:find('[Y]', 1, true)
        and not hk:find('{', 1, true) and not hp:find('{', 1, true),
        ('%d coleccionables × %d idiomas, faltan: %s · ayuda del mapa: "%s" / "%s"'):format(#Collect.LIST, #langs,
            #missing > 0 and table.concat(missing, ' ') or 'ninguno', hk, hp))
end

-- Lo que llevan puestos los jefes: se dibujan (y se cuentan las piezas dibujadas)
local function checkWear()
    local Entities = require 'src/world/entities/Entities'
    local Boss = require 'src/world/entities/base/Boss'
    local drawn = {}
    local real = love.graphics.draw
    local canvas = love.graphics.newCanvas(900, 330)
    love.graphics.push('all')
    love.graphics.origin(); love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.32, 0.42, 0.56, 1)
    love.graphics.draw = function(im, ...)
        if type(im) == 'userdata' and im.typeOf and im:typeOf('Image') then
            for path, img in pairs(Boss._wearImages or {}) do if img == im then drawn[path] = (drawn[path] or 0) + 1 end end
        end
        return real(im, ...)
    end
    local EV = EDITOR_VIEW
    EDITOR_VIEW = true                                -- (sin entrada: se dibujan quietos)
    local function draw(tp, x, props, st)
        local e = Entities.create({ type = tp, col = 1, row = 1, props = props or {} })
        e.x, e.y = x, 220
        if st then e.state = st end
        e:render(0, 0)
        return e
    end
    draw('megacrabby', 150)
    draw('megagloomy', 450, nil, 'prowl')
    draw('megacrabby_ice', 760)
    local before = {}
    for k, v in pairs(drawn) do before[k] = v end
    draw('megacrabby', -400, { wear = false })
    draw('megagloomy', -400, { wear = false }, 'prowl')
    EDITOR_VIEW = EV
    love.graphics.draw = real
    love.graphics.setCanvas()
    love.graphics.pop()
    local crown, amulet = 'assets/images/bosses/megacrabby/wear_crown.png', 'assets/images/bosses/megagloomy/wear_amulet.png'
    local same = (drawn[crown] == before[crown]) and (drawn[amulet] == before[amulet])
    check('piezas', (before[crown] or 0) == 1 and (before[amulet] or 0) == 1 and same,
        ('corona dibujada %s vez (el Mega y no el helado), amuleto %s; con wear=false no se dibujan=%s'):format(
            tostring(before[crown] or 0), tostring(before[amulet] or 0), tostring(same)))
    canvas:newImageData():encode('png', 'collection_jefes.png')
end

local function copyPreview(name)
    if not love.filesystem.getInfo(name) then return end
    local f = io.open(PREV .. name, 'wb')
    if f then f:write((love.filesystem.read(name))); f:close() end
end

function love.update(dt)
    t = t + dt
    local cur = press; press = {}
    Input = setmetatable({ pressed = function(x) return cur[x] == true end, down = function() return false end },
                         { __index = realInput })
    gameUpdate(dt)
    Input = realInput
    local st = top()
    if require('src/ui/menu/Transition').active() then return end

    if step == 'start' and t > 0.6 then
        checkTexts()
        checkWear()
        MAP = st
        MAPPOS = { world = st.world, node = st.node, x = st.heroX, y = st.heroY }
        shot('mapa')
        go('open')
    elseif step == 'open' and t - T > 0.3 then
        pressNext('light'); go('open2')
    elseif step == 'open2' and t - T > 0.7 then
        local stack = gStateMachine.stack
        check('abrir', st.list ~= nil and stack[#stack - 1] == MAP,
            ('{alt} en el mapa → %s, encima del mapa=%s'):format(st.list and 'Colección' or tostring(st),
                tostring(stack[#stack - 1] == MAP)))
        if not st.list then go('end'); return end
        N = #st.list
        local owned = {}
        for i = 1, N do owned[i] = st:owned(i) end
        local have, total = Collect.count(Run.data)
        local Ly = st.layout(N)
        check('fichas', N == #Collect.LIST and N >= 3 and owned[1] and not owned[2] and not owned[3]
            and have == 1 and total == N and #Ly.cards == N,
            ('%d fichas (catálogo %d), la 1 suya=%s, 2 y 3 "???"=%s/%s, cuenta %d / %d, %d columnas a %d de ancho'):format(
                N, #Collect.LIST, tostring(owned[1]), tostring(not owned[2]), tostring(not owned[3]), have, total,
                Ly.cols, WINDOW_W))
        shot('1280')
        NAV = { cols = Ly.cols, seq = {} }
        go('nav')
    elseif step == 'nav' and t - T > 0.4 then
        -- por la rejilla: ← → siguen el orden (al final de una fila pasan a la siguiente), ↑ ↓ cambian de fila en la
        -- misma columna; nada se sale de la lista
        local moves = { 'nav_left', 'nav_right', 'nav_right', 'nav_left', 'nav_left', 'nav_down', 'nav_up', 'nav_up' }
        local k = #NAV.seq + 1
        if k > 1 then NAV.seq[k - 1] = st.sel end
        if k <= #moves then pressNext(moves[k]); NAV.seq[k] = false; T = t - 0.25
        else
            local c = NAV.cols
            local want, sel = {}, 1
            local d = { nav_left = -1, nav_right = 1, nav_up = -c, nav_down = c }
            for i, m in ipairs(moves) do
                if sel + d[m] >= 1 and sel + d[m] <= N then sel = sel + d[m] end
                want[i] = sel
            end
            local ok = true
            for i = 1, #want do if NAV.seq[i] ~= want[i] then ok = false end end
            check('navegar', ok, ('← → → ← ← ↓ ↑ ↑: %s (esperado %s, %d columnas)'):format(
                table.concat(NAV.seq, ' '), table.concat(want, ' '), c))
            go('touch')
        end
    elseif step == 'touch' and t - T > 0.3 then
        local Ly = st.layout(N)
        local r = Ly.cards[2]
        st:touchpressed('mouse', r.x + r.w / 2, r.y + r.h / 2 - st.scroll)
        st:touchreleased('mouse', r.x + r.w / 2, r.y + r.h / 2 - st.scroll)
        check('tocar', st.sel == 2, ('tocar la ficha 2 → elegida %d'):format(st.sel))
        pressNext('back'); go('back')
    elseif step == 'back' and t - T > 0.8 then
        check('volver', st == MAP and st.world == MAPPOS.world and st.node == MAPPOS.node
            and st.heroX == MAPPOS.x and st.heroY == MAPPOS.y,
            ('ATRÁS → el mismo mapa=%s, mundo %s nodo %s, monstruo en (%d, %d)'):format(tostring(st == MAP),
                tostring(st.world), tostring(st.node), st.heroX or -1, st.heroY or -1))
        resize(960, 720); go('r960')
    elseif step == 'r960' and t - T > 0.5 then
        -- con el dedo: tocar la ficha de los fragmentos del mapa abre la Colección
        realInput.lastDevice = 'touch'
        st:touchpressed('t', WINDOW_W - 316 + 150, 112 + 16 + 56)
        go('r960b')
    elseif step == 'r960b' and t - T > 0.7 then
        check('tactil', st.list ~= nil, ('tocar la ficha de los fragmentos (960 de ancho) → %s'):format(
            st.list and 'Colección' or tostring(st)))
        if not st.list then go('end'); return end
        realInput.lastDevice = 'keyboard'
        shot('960')
        pressNext('nav_down'); go('r960c')
    elseif step == 'r960c' and t - T > 0.15 then
        pressNext('nav_down'); go('r960d')
    elseif step == 'r960d' and t - T > 0.8 then
        local Ly = st.layout(N)
        local r = Ly.cards[st.sel]
        local y = r.y - st.scroll
        check('ancho960', Ly.cols == 1 and st.sel == 3 and y >= Ly.view.y - 1 and y + r.h <= Ly.view.y + Ly.view.h + 1,
            ('%d columna(s); ↓ ↓ → ficha %d en y=%d (vista %d..%d, desplazado %d)'):format(Ly.cols, st.sel, y,
                Ly.view.y, Ly.view.y + Ly.view.h, st.scroll))
        shot('960_abajo')
        go('r960e')
    elseif step == 'r960e' and t - T > 0.3 then
        resize(1600, 720); go('r1600')
    elseif step == 'r1600' and t - T > 0.6 then
        shot('1600'); go('r1600b')
    elseif step == 'r1600b' and t - T > 0.3 then
        realInput.lastDevice = 'touch'
        st:touchpressed('t', 40, 40)                          -- (VOLVER, arriba a la izquierda)
        go('r1600c')
    elseif step == 'r1600c' and t - T > 0.8 then
        realInput.lastDevice = 'keyboard'
        check('esquina', st == MAP, ('VOLVER (esquina, con el dedo) → %s'):format(st == MAP and 'el mapa' or tostring(st)))
        -- OTRO ESTADO de la partida: las que tienen `states.stolen` en el catálogo, robadas por el Groove
        STOLEN = {}
        Run.data.collect = {}
        for i, c in ipairs(Collect.LIST) do
            if type(c.states) == 'table' and c.states.stolen then STOLEN[#STOLEN + 1] = i; Run.data.collect[c.id] = 'stolen' end
        end
        resize(1280, 720)
        go('robo')
    elseif step == 'robo' and t - T > 0.5 then
        pressNext('light'); go('robo2')
    elseif step == 'robo2' and t - T > 0.8 then
        local ok, info = st.list ~= nil and #STOLEN > 0, {}
        for _, i in ipairs(STOLEN) do
            local c = st.list and st.list[i]
            local tag, line
            if st.stateTexts then tag, line = st:stateTexts(i) end
            local good = c and st:owned(i) and st:state(i) == 'stolen' and st:iconPath(i) == c.states.stolen.icon
                and love.filesystem.getInfo(c.states.stolen.icon) ~= nil and tag ~= nil and line ~= nil
            ok = ok and good
            info[#info + 1] = ('%s: icono %s, etiqueta "%s", texto "%s"'):format(c and c.id or '?',
                tostring(st.iconPath and st:iconPath(i)), tostring(tag), tostring(line))
        end
        local have = Collect.count(Run.data)
        check('robada', ok and have == #STOLEN, ('%d robadas (cuentan como ganadas: %d): %s'):format(#STOLEN, have,
            table.concat(info, ' · ')))
        shot('robada')
        go('robo3')
    elseif step == 'robo3' and t - T > 0.4 then
        pressNext('back'); go('end')
    elseif step == 'end' and t - T > 0.4 then
        for _, n in ipairs({ 'mapa', '1280', '960', '960_abajo', '1600', 'jefes', 'robada' }) do copyPreview('collection_' .. n .. '.png') end
        print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
        print('capturas: ' .. love.filesystem.getSaveDirectory() .. '/collection_*.png  (y ' .. PREV .. ')')
        for i = 1, Save.SLOTS do Save.delete(i) end
        love.event.quit(fails == 0 and 0 or 1)
    end
end

function love.draw()
    gameDraw()
    local name = table.remove(shotQ, 1)
    if name then love.graphics.captureScreenshot(function(img) img:encode('png', 'collection_' .. name .. '.png') end) end
end
