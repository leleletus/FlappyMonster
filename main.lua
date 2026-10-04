-- main.lua — ARRANQUE. Monta la última actualización descargada y arranca el
-- juego (game.lua). Este archivo NO se actualiza solo (ni conf.lua): cambiarlo
-- exige volver a instalar el juego, así que debe quedarse pequeño y estable.
--
-- Actualizaciones (ver src/update/Updater.lua): cada versión descargada vive en
-- la carpeta de guardado, en update/slots/<versión>/, solo con los archivos que
-- cambian respecto al juego instalado. Aquí se monta la activa POR ENCIMA del
-- juego instalado (LÖVE lee primero de ella). Estado en update/state.lua:
--   active    versión montada (nil = la instalada)
--   previous  la que había antes (se guarda hasta confirmar la nueva)
--   pending   true = recién instalada, aún sin confirmar
--   boots     arranques sin confirmar;  bad = versión que falló (no reinstalar)
--   trash     carpeta a borrar al arrancar
-- Una versión nueva se confirma tras CONFIRM_T s de juego sin errores. Si da
-- un error antes (o no llega a confirmarse en MAX_BOOTS arranques), se vuelve
-- a la anterior y no se vuelve a instalar esa versión.
--
-- Al ejecutar desde la carpeta del repo (`love .`) no se monta nada (así las
-- descargas de un .love probado en el mismo PC nunca tapan el código).
-- FM_UPDATE=1 lo fuerza (pruebas).
--
-- El montaje se COMPRUEBA (version.txt tiene que ser el de la versión activa).
-- En la SWITCH `fs.mount` no funciona (ni con la ruta relativa ni con la
-- absoluta): la 1ª versión entraba en bucle (descargar → reiniciar → sigue la
-- vieja → descargar...) y la 2ª, para cortarlo, dejaba ese aparato SIN
-- actualizaciones para siempre (`nomount`). Ahora, si no se puede montar, la
-- versión se usa por SUPERPOSICIÓN (`overlay`): sin montar nada, cada lectura
-- de un archivo del juego mira primero en la carpeta de la versión — se
-- envuelven love.filesystem (read, getInfo, getDirectoryItems...), los
-- cargadores de imágenes, sonidos y fuentes, y `require` —. Solo necesita poder
-- LEER la carpeta de guardado, que es donde se descargó. Si ni eso (no se lee
-- su version.txt), se vuelve a la instalada y se apunta `nomount` (sin bucle).
-- Cada arranque deja update/boot.log con lo que pasó (en Switch no hay consola).

local UPD       = 'update'
local STATE     = UPD .. '/state.lua'
local CONFIRM_T = 10
local MAX_BOOTS = 3

local fs = love.filesystem
local source = fs.getSource() or ''
UPDATE_ENABLED = fs.isFused() or source:match('%.love$') ~= nil or os.getenv('FM_UPDATE') == '1'

local function slotDir(v) return UPD .. '/slots/' .. v end

local function readState()
    local ok, src = pcall(fs.read, STATE)
    local chunk = ok and src and loadstring(src)
    if not chunk then return {} end
    setfenv(chunk, {})
    local ok2, t = pcall(chunk)
    return (ok2 and type(t) == 'table') and t or {}
end

local function writeState(s)
    local out = { 'return {' }
    for k, v in pairs(s) do
        if type(v) == 'string' then out[#out + 1] = string.format('  %s = %q,', k, v)
        elseif type(v) == 'number' or type(v) == 'boolean' then out[#out + 1] = string.format('  %s = %s,', k, tostring(v)) end
    end
    out[#out + 1] = '}\n'
    fs.createDirectory(UPD)
    pcall(fs.write, STATE, table.concat(out, '\n'))
end
UPDATE_WRITE_STATE, UPDATE_READ_STATE = writeState, readState

-- Borra una carpeta de la carpeta de guardado (solo lo que está en ella)
local saveDir = fs.getSaveDirectory()
local function rmrf(path)
    local info = fs.getInfo(path)
    if not info then return end
    if info.type == 'directory' then
        for _, it in ipairs(fs.getDirectoryItems(path)) do rmrf(path .. '/' .. it) end
    end
    if fs.getRealDirectory(path) == saveDir then fs.remove(path) end
end
UPDATE_RMRF = rmrf

local function trim(v) return (v or ''):match('^%s*(.-)%s*$') end
local function fileVersion()
    local ok, v = pcall(fs.read, 'version.txt')
    return ok and trim(v) or '?'
end

local bootLog = {}
local function blog(msg) bootLog[#bootLog + 1] = msg end

-- Monta la versión v y comprueba que de verdad tapa al juego instalado
local function mountSlot(v)
    local rel = slotDir(v)
    for _, path in ipairs({ rel, saveDir .. '/' .. rel }) do
        local ok, res = pcall(fs.mount, path, '', false)
        local now = fileVersion()
        blog(string.format('mount %s -> %s (version.txt = %s)', path, tostring(ok and res), now))
        if ok and res then
            if now == v then return true end
            pcall(fs.unmount, path)                               -- montó, pero no tapa: fuera
        end
    end
    return false
end

-- SUPERPOSICIÓN: la versión v, sin montarla (ver arriba). Devuelve false si no se puede ni leer.
local function overlay(v)
    local base = slotDir(v) .. '/'
    local rawInfo, rawRead, rawItems = fs.getInfo, fs.read, fs.getDirectoryItems
    local okv, ver = pcall(rawRead, base .. 'version.txt')
    blog(string.format('overlay %s (version.txt = %s)', base, tostring(okv and trim(ver))))
    if not (okv and ver and trim(ver) == v) then return false end
    local function res(p)
        if type(p) ~= 'string' or p:sub(1, #UPD + 1) == UPD .. '/' then return p end
        local q = base .. (p:gsub('^/+', ''))
        if rawInfo(q) then return q end
        return p
    end
    UPDATE_RESOLVE = res
    local function wrap(t, names)
        for _, n in ipairs(names) do
            local f = t and t[n]
            if f then t[n] = function(p, ...) return f(res(p), ...) end end
        end
    end
    wrap(fs, { 'getInfo', 'lines', 'load', 'newFile', 'newFileData', 'getRealDirectory' })
    fs.read = function(a, b, ...)                              -- read(nombre[, n]) o read('string'|'data', nombre[, n])
        if (a == 'string' or a == 'data') and type(b) == 'string' then return rawRead(a, res(b), ...) end
        return rawRead(res(a), b, ...)
    end
    fs.getDirectoryItems = function(dir, ...)                  -- lo de la versión + lo instalado
        local out, seen = {}, {}
        local dirs = { dir }
        if type(dir) == 'string' and dir:sub(1, #UPD) ~= UPD and rawInfo(base .. dir) then dirs[2] = base .. dir end
        for _, d in ipairs(dirs) do
            for _, it in ipairs(rawItems(d)) do
                if not seen[it] then seen[it] = true; out[#out + 1] = it end
            end
        end
        return out
    end
    wrap(love.graphics, { 'newImage', 'newFont', 'newImageFont', 'newVideo' })
    wrap(love.image, { 'newImageData', 'newCompressedData' })
    wrap(love.audio, { 'newSource' })
    wrap(love.sound, { 'newSoundData', 'newDecoder' })
    wrap(love.thread, { 'newThread' })
    table.insert(package.loaders, 2, function(name)            -- require: primero la versión
        local n = name:gsub('%.', '/')
        for _, p in ipairs({ n .. '.lua', name .. '.lua', n .. '/init.lua' }) do
            if rawInfo(base .. p) then
                local chunk, err = loadstring(rawRead(base .. p), '@' .. p)
                return chunk or ('\n\t' .. tostring(err))
            end
        end
    end)
    return fileVersion() == v
end

local BOOT = 3                    -- versión de ESTE arranque (al cambiar se olvida `nomount`: hay otra forma de montar)
local st
if UPDATE_ENABLED then
    st = readState()
    local installed = fileVersion()                             -- (antes de montar nada)
    blog('instalada ' .. installed .. ', activa ' .. tostring(st.active) .. ', pendiente ' .. tostring(st.pending))
    if st.nomount and (st.nomount ~= installed or st.boot ~= BOOT) then st.nomount = nil end    -- (reinstalado, o arranque nuevo)
    if st.boot ~= BOOT then st.boot = BOOT; writeState(st) end
    if st.trash then rmrf(slotDir(st.trash)); st.trash = nil; writeState(st) end
    if st.pending then
        st.boots = (st.boots or 0) + 1
        if st.boots > MAX_BOOTS then
            -- No llega a confirmarse (¿se cierra solo?): volver a la anterior
            st.bad, st.trash, st.active = st.active, st.active, st.previous
            st.previous, st.pending, st.boots = nil, nil, nil
        end
        writeState(st)
    end
    if st.active and fs.getInfo(slotDir(st.active), 'directory') then
        if mountSlot(st.active) then UPDATE_MODE = 'mount'
        elseif overlay(st.active) then
            UPDATE_MODE = 'overlay'
            blog('no se puede montar ' .. st.active .. ': se usa por superposición')
        else
            -- Ni montar ni leer la versión: volver a la instalada y no volver
            -- a intentarlo hasta reinstalar (sin esto: bucle de descargas)
            blog('no se puede montar ni leer ' .. st.active .. ': se usa la instalada y no se buscan más actualizaciones')
            print('[update] no se pudo montar ' .. st.active)
            st.trash, st.active, st.previous, st.pending, st.boots = st.active, nil, nil, nil, nil
            st.nomount = installed
            writeState(st)
        end
    elseif st.active then
        st.active = nil; writeState(st)                       -- (carpeta perdida)
    end
    UPDATE_BLOCKED = st.nomount ~= nil                          -- (UpdateState no busca)
    pcall(fs.write, UPD .. '/boot.log', table.concat(bootLog, '\n') .. '\n')
end

require 'game'

-- ── Confirmar / deshacer una versión recién instalada ────────────────────────
if st and st.pending then
    local t, done = 0, false
    local gameUpdate = love.update
    love.update = function(dt)
        if gameUpdate then gameUpdate(dt) end
        if done then return end
        t = t + dt
        if t >= CONFIRM_T then
            done = true
            local s = readState()
            if s.previous then s.trash = s.previous end       -- (se borra al arrancar)
            s.previous, s.pending, s.boots = nil, nil, nil
            s.tryVer, s.tries = nil, nil                      -- (instalación confirmada)
            writeState(s)
        end
    end
    local handler = love.errorhandler or love.errhand
    love.errorhandler = function(msg)
        if not done then
            local s = readState()
            s.bad, s.trash, s.active = s.active, s.active, s.previous
            s.previous, s.pending, s.boots = nil, nil, nil
            writeState(s)
            msg = tostring(msg) .. '\n\n(La actualización falló: al reiniciar se usará la versión anterior.)'
        end
        return handler(msg)
    end
end
