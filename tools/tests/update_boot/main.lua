-- tools/tests/update_boot — el arranque con actualizaciones (main.lua real) y
-- las protecciones contra el bucle de la Switch (descargar → reiniciar → no
-- se monta la versión nueva → descargar otra vez...). Cada "arranque" ejecuta
-- el main.lua de verdad (sin el juego) sobre una carpeta de guardado de
-- prueba con una versión 9.9.9 ya descargada y pendiente:
--   monta      el montaje funciona: version.txt = 9.9.9, sigue activa
--   no_monta   fs.mount falla (la SWITCH): la versión se usa por SUPERPOSICIÓN
--              — version.txt, un módulo y un archivo que solo están en la
--              versión se leen; las carpetas juntan lo instalado y lo nuevo —,
--              sigue activa, NO se bloquean las actualizaciones, y el
--              siguiente arranque igual (sin bucle); deja update/boot.log
--   no_tapa    fs.mount "funciona" pero no tapa al juego instalado: igual
--   ilegible   ni se monta ni se puede leer la versión: vuelve a la instalada,
--              marca `nomount` y bloquea (lo de antes: sin bucle)
--   viejo      un aparato que el arranque anterior dejó bloqueado (`nomount`
--              = la instalada) vuelve a buscar actualizaciones
--   reinstala  con otra versión instalada se vuelve a intentar
--   otra_base  la activa se descargó sobre OTRO juego instalado (`base`): no se monta (mezclaría dos versiones),
--              se usa la instalada; con `base` = la instalada sí se monta
--   updater    un manifiesto con una entrada sin sha256 válido no se instala; el Updater no reinstala la versión activa y, tras 2
--              instalaciones sin confirmar de la misma versión, para
--   copia      2ª actualización por superposición: lo que no cambia y solo está en la versión activa se copia a la
--              nueva, y lo que falta aunque su manifiesto lo apunte se vuelve a bajar
--   a_medias   game.lua de verdad: una versión recién instalada a la que le faltan archivos se deja y se reinicia
--              (una vez por versión); entera o ya confirmada sigue adelante
--
--   tools/tests/run.sh update_boot
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fs = love.filesystem
local realMount, realUnmount = fs.mount, fs.unmount
-- (el arranque por superposición envuelve funciones de love y añade un cargador a require: se guardan para
-- dejarlo todo como estaba entre un "arranque" y otro)
local SAVED = {}
for _, t in ipairs({ love.filesystem, love.graphics, love.image, love.audio, love.sound, love.thread }) do
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    SAVED[#SAVED + 1] = { t, c }
end
local NLOADERS = #package.loaders
local function restore()
    for _, e in ipairs(SAVED) do for k, v in pairs(e[2]) do e[1][k] = v end end
    while #package.loaders > NLOADERS do table.remove(package.loaders, 2) end
    UPDATE_RESOLVE, UPDATE_MODE = nil, nil
end

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local V = '9.9.9'
local SLOT = 'update/slots/' .. V

local function wipe(path)
    local info = fs.getInfo(path)
    if not info then return end
    if info.type == 'directory' then for _, it in ipairs(fs.getDirectoryItems(path)) do wipe(path .. '/' .. it) end end
    fs.remove(path)
end

-- Carpeta de guardado como la deja el Updater tras descargar 9.9.9
local function prepare(state)
    pcall(realUnmount, SLOT); pcall(realUnmount, fs.getSaveDirectory() .. '/' .. SLOT)
    wipe('update')
    fs.createDirectory(SLOT)
    fs.write(SLOT .. '/version.txt', V .. '\n')
    fs.createDirectory(SLOT .. '/assets/levels')
    fs.write(SLOT .. '/zz_solo_nueva.lua', 'return 42\n')                  -- (un módulo que solo trae la versión nueva)
    fs.write(SLOT .. '/assets/levels/zz_nuevo.json', '{}')                 -- (y un nivel)
    local out = { 'return {' }
    for k, v in pairs(state) do
        out[#out + 1] = type(v) == 'string' and ('  %s = %q,'):format(k, v) or ('  %s = %s,'):format(k, tostring(v))
    end
    out[#out + 1] = '}'
    fs.write('update/state.lua', table.concat(out, '\n'))
end

-- Un arranque: main.lua real, sin el juego (package.loaded.game)
local function boot(mountMode)
    restore()
    package.loaded.zz_solo_nueva = nil
    fs.mount = realMount
    if mountMode == 'fail' then fs.mount = function() return false end
    elseif mountMode == 'nocover' then fs.mount = function() return true end end
    package.loaded.game = true
    UPDATE_BLOCKED, UPDATE_MODE = nil, nil
    local chunk = assert(fs.load('boot_main.lua'))
    chunk()
    fs.mount = realMount
    return UPDATE_READ_STATE()
end

local function version()
    local ok, v = pcall(fs.read, 'version.txt')
    return ok and v:match('^%s*(.-)%s*$') or '?'
end

function love.load()
    local installed = version()

    prepare({ active = V, pending = true, boots = 0 })
    local st = boot('ok')
    check('monta', version() == V and st.active == V and not UPDATE_BLOCKED,
        ('version.txt=%s activa=%s bloqueado=%s'):format(version(), tostring(st.active), tostring(UPDATE_BLOCKED)))

    for _, mode in ipairs({ 'fail', 'nocover' }) do
        local name = mode == 'fail' and 'no_monta' or 'no_tapa'
        prepare({ active = V, pending = true, boots = 0 })
        st = boot(mode)
        local log = fs.read('update/boot.log') or ''
        local okm, mod = pcall(require, 'zz_solo_nueva')
        local items, hasNew, hasOld = fs.getDirectoryItems('assets/levels'), false, false
        for _, it in ipairs(items) do
            if it == 'zz_nuevo.json' then hasNew = true end
            if it == 'valle_soleado.json' then hasOld = true end
        end
        local ok1 = version() == V and st.active == V and st.nomount == nil and not UPDATE_BLOCKED and UPDATE_MODE == 'overlay'
            and okm and mod == 42 and fs.getInfo('assets/levels/zz_nuevo.json') ~= nil and hasNew and hasOld
            and fs.getInfo('assets/levels/valle_soleado.json') ~= nil and fs.read('update/state.lua') ~= nil
        st = boot(mode)                                    -- el siguiente arranque: igual, sin bucle
        check(name, ok1 and version() == V and st.active == V and not UPDATE_BLOCKED and log:find('superposici') ~= nil,
            ('usa %s (modo %s), activa=%s, bloqueado=%s; módulo nuevo=%s, nivel nuevo=%s, niveles de siempre=%s; 2º arranque %s'):format(version(),
                tostring(UPDATE_MODE), tostring(st.active), tostring(UPDATE_BLOCKED), tostring(okm and mod), tostring(hasNew), tostring(hasOld), version()))
    end
    restore()

    -- ni montar ni leer la versión (su carpeta, sin version.txt): bloquea como antes, sin bucle
    prepare({ active = V, pending = true, boots = 0 })
    fs.remove(SLOT .. '/version.txt')
    st = boot('fail')
    local okb = version() == installed and st.active == nil and st.nomount == installed and UPDATE_BLOCKED == true
    st = boot('fail')
    check('ilegible', okb and UPDATE_BLOCKED == true and st.active == nil,
        ('usa %s, nomount=%s, bloqueado=%s; 2º arranque bloqueado=%s'):format(version(), tostring(st.nomount), tostring(okb), tostring(UPDATE_BLOCKED)))
    restore()

    -- un aparato que el arranque ANTERIOR dejó bloqueado (nomount = la instalada, sin `boot`): se desbloquea
    prepare({ nomount = installed })
    st = boot('fail')
    check('viejo', st.nomount == nil and not UPDATE_BLOCKED, ('nomount=%s bloqueado=%s'):format(tostring(st.nomount), tostring(UPDATE_BLOCKED)))

    prepare({ nomount = '0.0.1' })                         -- (se marcó con otra instalada)
    st = boot('ok')
    check('reinstala', st.nomount == nil and not UPDATE_BLOCKED, ('nomount=%s bloqueado=%s'):format(tostring(st.nomount), tostring(UPDATE_BLOCKED)))

    -- la activa se hizo sobre otro juego instalado: fuera (y a la papelera); sobre el mismo: se monta
    prepare({ active = V, base = '0.0.1' })
    st = boot('ok')
    local gone = version() == installed and st.active == nil and st.trash == V
    restore()
    prepare({ active = V, base = installed })
    st = boot('ok')
    check('otra_base', gone and version() == V and st.active == V,
        ('base 0.0.1 → usa %s (activa %s, a la papelera %s); base = la instalada → usa %s'):format(gone and installed or '?',
         tostring(gone and 'nil' or 'sigue'), gone and V or '-', version()))
    restore()

    -- Updater (sin red: solo la decisión al recibir el manifiesto)
    local Updater = require 'src/update/Updater'
    local function decide(state, mver)
        prepare(state)
        local u = setmetatable({ status = 'connecting', t = 0, bytesDone = 0, bytesTotal = 0, filesDone = 0, filesTotal = 0 }, Updater)
        u:_onManifest({ version = mver, files = {} })
        return u.status
    end
    local a = decide({ active = V }, V)
    local b = decide({ tryVer = '9.9.10', tries = 2 }, '9.9.10')
    local c = decide({ tryVer = '9.9.10', tries = 1 }, '9.9.10')
    local function bad(files)
        prepare({})
        local u = setmetatable({ status = 'connecting', t = 0, bytesDone = 0, bytesTotal = 0, filesDone = 0, filesTotal = 0 }, Updater)
        u:_onManifest({ version = '9.9.11', files = files })
        return u.status
    end
    local H = string.rep('ab', 32)
    local d1 = bad({ { 'main.lua', 10 } })                         -- (sin hash)
    local d2 = bad({ { 'main.lua', 10, 'xyz' } })                  -- (hash que no es sha256)
    local d3 = bad({ { '../fuera.lua', 10, H } })                  -- (fuera de la carpeta)
    local d4 = bad({ { 'main.lua', 10, H } })                      -- (bien)
    check('updater', a == 'uptodate' and b == 'failed' and c == 'hashing' and d1 == 'failed' and d2 == 'failed'
        and d3 == 'failed' and d4 == 'hashing',
        ('servidor = activa → %s; 2 intentos sin confirmar → %s; 1 intento → %s; manifiesto sin hash → %s, hash raro → %s, ruta con .. → %s, bien → %s'):format(
         a, b, c, d1, d2, d3, d4))

    restore()

    -- 2ª actualización por SUPERPOSICIÓN (la Switch): lo que no cambia y solo está en la versión activa se copia a la
    -- nueva; lo que el manifiesto de la activa dice tener pero no está en ningún sitio se vuelve a bajar
    prepare({ active = V })
    local HSOLO = love.data.encode('string', 'hex', love.data.hash('sha256', fs.read(SLOT .. '/zz_solo_nueva.lua')))
    fs.write(SLOT .. '/.manifest.lua', ('return {\n  ["zz_solo_nueva.lua"] = %q,\n  ["zz_perdido.lua"] = %q,\n}\n'):format(HSOLO, H))
    boot('fail')
    local u = setmetatable({ status = 'connecting', t = 0, bytesDone = 0, bytesTotal = 0, filesDone = 0, filesTotal = 0 }, Updater)
    u:_onManifest({ version = '9.9.12', files = { { 'zz_solo_nueva.lua', 10, HSOLO }, { 'zz_perdido.lua', 10, H } } })
    while u.status == 'hashing' do u:_hashStep() end
    local perdido = #u.queue == 1 and u.queue[1].path == 'zz_perdido.lua'
    u.files = { u.files[1] }
    u:_install()
    check('copia', u.status == 'done' and perdido and fs.read('update/slots/9.9.12/zz_solo_nueva.lua') ~= nil,
        ('estado %s; se copia lo que solo está en la activa: %s; se vuelve a bajar lo perdido: %s'):format(u.status,
         tostring(fs.getInfo('update/slots/9.9.12/zz_solo_nueva.lua') ~= nil), tostring(perdido)))
    restore()

    -- game.lua de verdad (sin cargar el juego: su primer require corta) con la versión recién instalada a medias: la
    -- deja, olvida los fallos y reinicia (una sola vez por versión); entera sigue adelante
    local function runGame()
        local realRequire, realQuit, loadBefore = require, love.event.quit, love.load
        local reinicia = false
        require = function() error('SIGUE', 0) end
        love.event.quit = function(a) reinicia = a == 'restart' end
        local ok, err = pcall(assert(fs.load('boot_game.lua')))
        if ok and love.load ~= loadBefore then love.load() end
        require, love.event.quit, love.load = realRequire, realQuit, loadBefore
        return (not ok and err == 'SIGUE') and 'sigue' or (reinicia and 'reinicia' or tostring(err))
    end
    local INCOMPLETA = 'return {\n  ["zz_solo_nueva.lua"] = "x",\n  ["zz_no_esta.lua"] = "x",\n}\n'
    prepare({ active = V, previous = '9.9.8', pending = true, boots = 0, bad = '9.9.9', tryVer = V, tries = 2 })
    fs.createDirectory('update/slots/9.9.8')
    fs.write('update/slots/9.9.8/version.txt', '9.9.8\n')
    fs.write(SLOT .. '/.manifest.lua', INCOMPLETA)
    boot('fail')
    local r1 = runGame()
    local s1 = UPDATE_READ_STATE()
    local rep1 = r1 == 'reinicia' and s1.active == nil and s1.previous == nil and s1.pending == nil and s1.trash == V
        and s1.bad == nil and s1.tryVer == nil and s1.tries == nil and s1.repairVer == V and fs.getInfo('update/slots/9.9.8') == nil
    restore()
    prepare({ active = V, pending = true, boots = 0, repairVer = V })      -- (ya se intentó con esta versión: sin bucle)
    fs.write(SLOT .. '/.manifest.lua', INCOMPLETA)
    boot('fail')
    local r2 = runGame()
    restore()
    prepare({ active = V, pending = true, boots = 0 })                     -- (entera)
    fs.write(SLOT .. '/.manifest.lua', 'return {\n  ["zz_solo_nueva.lua"] = "x",\n  ["version.txt"] = "x",\n}\n')
    boot('fail')
    local r3 = runGame()
    restore()
    prepare({ active = V, boots = 0 })                                     -- (ya confirmada: no se comprueba)
    fs.write(SLOT .. '/.manifest.lua', INCOMPLETA)
    boot('fail')
    local r4 = runGame()
    check('a_medias', rep1 and r2 == 'sigue' and r3 == 'sigue' and r4 == 'sigue',
        ('a medias → %s (estado limpio: %s); 2ª vez → %s; entera → %s; confirmada → %s'):format(r1, tostring(rep1), r2, r3, r4))

    restore()
    pcall(realUnmount, SLOT)
    wipe('update')
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
