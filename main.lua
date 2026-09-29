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
-- Si en este aparato no funciona (pasó en Switch: la carpeta de guardado no se
-- monta con la ruta relativa), se prueba con la ruta absoluta y, si tampoco,
-- se vuelve a la versión instalada y se apunta `nomount` = versión instalada:
-- con eso UpdateState no vuelve a buscar actualizaciones en este aparato (si no,
-- descargaría → reiniciaría → no montaría → descargaría... sin fin). Se vuelve a
-- intentar cuando cambia la versión instalada (reinstalar). Cada arranque deja
-- update/boot.log con lo que pasó (en Switch no hay consola).

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

local st
if UPDATE_ENABLED then
    st = readState()
    local installed = fileVersion()                             -- (antes de montar nada)
    blog('instalada ' .. installed .. ', activa ' .. tostring(st.active) .. ', pendiente ' .. tostring(st.pending))
    if st.nomount and st.nomount ~= installed then st.nomount = nil; writeState(st) end   -- (reinstalado)
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
        if not mountSlot(st.active) then
            -- Este aparato no puede usar las actualizaciones: volver a la
            -- instalada y no volver a intentarlo hasta reinstalar
            blog('no se puede montar ' .. st.active .. ': se usa la instalada y no se buscan más actualizaciones')
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
