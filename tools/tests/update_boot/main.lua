-- tools/tests/update_boot — el arranque con actualizaciones (main.lua real) y
-- las protecciones contra el bucle de la Switch (descargar → reiniciar → no
-- se monta la versión nueva → descargar otra vez...). Cada "arranque" ejecuta
-- el main.lua de verdad (sin el juego) sobre una carpeta de guardado de
-- prueba con una versión 9.9.9 ya descargada y pendiente:
--   monta      el montaje funciona: version.txt = 9.9.9, sigue activa
--   no_monta   fs.mount falla: vuelve a la instalada, marca `nomount`, bloquea
--              las actualizaciones (UPDATE_BLOCKED) y deja update/boot.log;
--              el siguiente arranque sigue bloqueado (sin bucle)
--   no_tapa    fs.mount "funciona" pero no tapa al juego instalado (el caso
--              probable de la Switch): igual que no_monta
--   reinstala  con otra versión instalada se vuelve a intentar
--   updater    el Updater no reinstala la versión activa y, tras 2
--              instalaciones sin confirmar de la misma versión, para
--
--   tools/tests/run.sh update_boot
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fs = love.filesystem
local realMount, realUnmount = fs.mount, fs.unmount

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
    local out = { 'return {' }
    for k, v in pairs(state) do
        out[#out + 1] = type(v) == 'string' and ('  %s = %q,'):format(k, v) or ('  %s = %s,'):format(k, tostring(v))
    end
    out[#out + 1] = '}'
    fs.write('update/state.lua', table.concat(out, '\n'))
end

-- Un arranque: main.lua real, sin el juego (package.loaded.game)
local function boot(mountMode)
    fs.mount = realMount
    if mountMode == 'fail' then fs.mount = function() return false end
    elseif mountMode == 'nocover' then fs.mount = function() return true end end
    package.loaded.game = true
    UPDATE_BLOCKED = nil
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
        local ok1 = version() == installed and st.active == nil and st.nomount == installed and UPDATE_BLOCKED == true
        st = boot(mode)                                    -- el siguiente arranque
        check(name, ok1 and UPDATE_BLOCKED == true and st.active == nil and log:find('no se puede montar') ~= nil,
            ('usa %s, nomount=%s, bloqueado=%s; 2º arranque bloqueado=%s; boot.log %d líneas'):format(version(),
                tostring(st.nomount), tostring(UPDATE_BLOCKED), tostring(UPDATE_BLOCKED), select(2, log:gsub('\n', ''))))
    end

    prepare({ nomount = '0.0.1' })                         -- (se marcó con otra instalada)
    st = boot('ok')
    check('reinstala', st.nomount == nil and not UPDATE_BLOCKED, ('nomount=%s bloqueado=%s'):format(tostring(st.nomount), tostring(UPDATE_BLOCKED)))

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
    check('updater', a == 'uptodate' and b == 'failed' and c == 'hashing',
        ('servidor = activa → %s; 2 intentos sin confirmar → %s; 1 intento → %s'):format(a, b, c))

    pcall(realUnmount, SLOT)
    wipe('update')
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
