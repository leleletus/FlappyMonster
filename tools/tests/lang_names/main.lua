-- tools/tests/lang_names — nombres traducidos (es / en):
--   jefes_tipo    cada tipo de jefe tiene su nombre en boss.<tipo> en TODOS los idiomas
--   jefe_propio   nombre propio en el nivel (props title / title_en, como name / name_en de los
--                 niveles): la barra (Boss:title) lo usa en cada idioma; sin title_en, el español;
--                 sin title, el del tipo traducido
--   ficha         Juego libre: la ficha del nivel (LevelCatalog bossNames) da el nombre del idioma
--   niveles       aviso (no falla): niveles sin "name_en"
--
--   tools/tests/run.sh lang_names
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fails = 0
local function check(case, ok, msg)
    print(('%-12s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

function love.load()
    require 'settings'
    Sound = setmetatable({}, { __index = function() return function() end end })
    -- (sin ventana: imágenes falsas con medidas, como el servidor headless)
    love.graphics.newImage = function() return { getWidth = function() return 16 end, getHeight = function() return 16 end,
        getDimensions = function() return 16, 16 end, setFilter = function() end, setWrap = function() end } end
    love.graphics.newQuad = function() return { setViewport = function() end } end
    local Lang = require 'src/Lang'
    local Entities = require 'src/world/Entities'
    local EntityTypes = require 'src/world/entities/EntityTypes'
    local LevelCatalog = require 'src/world/LevelCatalog'

    -- jefes_tipo
    local missing, n = {}, 0
    for name, def in pairs(EntityTypes.byName) do
        if def.boss then
            n = n + 1
            for _, l in ipairs(Lang.LANGUAGES) do
                Lang.set(l.id)
                local ok, e = pcall(Entities.create, { type = name, col = 5, row = 5, props = {} })
                local key = 'boss.' .. name
                -- (has() mira también el español: aquí se exige la clave en el archivo de ESE idioma)
                local file = love.filesystem.read('assets/lang/' .. l.id .. '.lua') or ''
                local inFile = file:find('%f[%w_]' .. name .. '%s*=') ~= nil
                if not ok or not inFile or e:title() ~= Lang.get(key) then missing[#missing + 1] = l.id .. ':' .. name end
            end
        end
    end
    table.sort(missing)
    check('jefes_tipo', n >= 5 and #missing == 0, ('%d jefes; sin nombre en su idioma: %s'):format(n, #missing > 0 and table.concat(missing, ', ') or 'ninguno'))

    -- jefe_propio
    local got = {}
    for _, case in ipairs({ { 'es', { title = 'REY HELADO', title_en = 'ICE KING' } }, { 'en', { title = 'REY HELADO', title_en = 'ICE KING' } },
                            { 'en', { title = 'REY HELADO' } }, { 'en', {} }, { 'es', {} } }) do
        Lang.set(case[1])
        local e = Entities.create({ type = 'megacrabby_ice', col = 5, row = 5, props = case[2] })
        got[#got + 1] = case[1] .. '=' .. e:title()
    end
    local want = 'es=REY HELADO | en=ICE KING | en=REY HELADO | en=ICY MEGA CRABBY | es=MEGA CRABBY HELADO'
    local s = table.concat(got, ' | ')
    check('jefe_propio', s == want, s)

    -- ficha (Juego libre / catálogo del servidor)
    local json = require 'libs/json'
    local d = json.decode(love.filesystem.read('assets/levels/glaciar_cangrejo.json'))
    for _, e in ipairs(d.entities) do
        if e.type == 'megacrabby_ice' then e.props = e.props or {}; e.props.title, e.props.title_en = 'REY HELADO', 'ICE KING' end
    end
    local info = LevelCatalog.info(require('src/world/Level').fromData(d), 'x.json')
    local names = {}
    for _, l in ipairs({ 'es', 'en' }) do
        Lang.set(l)
        for _, b in ipairs(info and info.bossNames or {}) do names[#names + 1] = l .. '=' .. tostring(Lang.bossName(b.type, b.props)) end
    end
    check('ficha', table.concat(names, ' | ') == 'es=REY HELADO | en=ICE KING', table.concat(names, ' | '))

    -- niveles sin traducción (solo aviso)
    local sin = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems('assets/levels')) do
        if f:match('%.json$') and not f:match('^_') and not f:match('^zz_') and f ~= 'editor_playtest.json' then
            local ok, lv = pcall(json.decode, love.filesystem.read('assets/levels/' .. f))
            if ok and lv and (not lv.name_en or lv.name_en == '') then sin[#sin + 1] = f end
        end
    end
    print(('niveles     AVISO  sin "name_en": %s'):format(#sin > 0 and table.concat(sin, ', ') or 'ninguno'))

    -- FILTRO DE NOMBRES de jugador (src/network/NameFilter.lua): largo, caracteres, palabras vetadas y sus disfraces
    local NF = require 'src/network/NameFilter'
    local bad = { 'puta', 'PuT4', 'P_U_T_4', 'puuuta', 'xXfuckXx', 'F-U-C-K', 'sh1t', 'n1gg3r', 'Admin', 'ADM1N', 'el_culo', 'ass', 'a55',
                  'server', 'mod', 'h1tler', 'B1TCH', 'cabr0n', 'xx_sex_xx', 'c0ck', 'ab', 'con espacio', 'ñandú', 'aaaaaaaaaaaaaaaaaaaa',
                  '1234', 'kys', 'm1erda', 'KKK', 'fuuuuck', 'p0rn', 'mi-erda', 'a\nb', 'x<y>z' }
    local good = { 'Mtvemo', 'Bot', 'Prueba', 'Player_1', 'Cassandra', 'Pollo', 'Apollo11', 'Dickens', 'Cumbia', 'Final_Boss', 'Animal',
                   'Tarzan', 'Conocido', 'Assassin', 'Bass', 'Class', 'Peacock', 'Torpedo', 'Mongolia', 'Hello', 'Anakin', 'Tetris',
                   'Modesto', 'Hostal', 'Luna-9', 'Analia', 'Kiko', 'Monika', 'Kakashi', 'Mario64', 'xX_Pro_Xx', 'Jugador1' }
    local wrong = {}
    for _, n in ipairs(bad) do if NF.check(n) then wrong[#wrong + 1] = n .. ' (aceptado)' end end
    for _, n in ipairs(good) do if not NF.check(n) then wrong[#wrong + 1] = n .. ' (rechazado)' end end
    check('nombres', #wrong == 0 and NF.typed('a b!c_d-é9') == 'abc_d-9',
        ('%d no permitidos y %d válidos; mal clasificados: %s'):format(#bad, #good, #wrong > 0 and table.concat(wrong, ', ') or 'ninguno'))

    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
