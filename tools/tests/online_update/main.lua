-- tools/tests/online_update — la DESCARGA de una actualización de verdad contra el servidor LOCAL (run.sh lo arranca;
-- él publica la versión del repo en server/published): el Updater del juego pide el manifiesto, compara, baja por
-- trozos lo que cambia, comprueba el SHA-256 de cada archivo y lo instala en update/slots/<versión>/.
--  · los archivos que este arnés no tiene (game.lua, version.txt) se bajan;
--  · además se fuerza a bajar los BIG archivos más grandes (como si hubieran cambiado), para pasar por el límite de
--    ancho de banda del servidor (2 MB/s por cliente): tiene que acabar, y no más rápido que el límite;
--  · cada archivo bajado tiene el hash del manifiesto; lo que no cambia se copia.
--
--   tools/tests/run.sh online_update            (BIG=6 por defecto)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local fs = love.filesystem
local Updater = require 'src/update/Updater'

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end

local function wipe(path)
    local info = fs.getInfo(path)
    if not info then return end
    if info.type == 'directory' then for _, it in ipairs(fs.getDirectoryItems(path)) do wipe(path .. '/' .. it) end end
    fs.remove(path)
end

local BIG = tonumber(os.getenv('BIG')) or 6
local u, t, tries, forced, dlStart, dlEnd = nil, 0, 0, {}, nil, nil

function love.load()
    wipe('update')
end

local function finish()
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    wipe('update')
    love.event.quit(fails == 0 and 0 or 1)
end

function love.update(dt)
    t = t + dt
    if t > 240 then check('descarga', false, 'no acabó en 240 s (estado ' .. tostring(u and u.status) .. ')'); return finish() end
    -- El servidor tarda en publicar (hashea el repo en un hilo): se reintenta hasta que tenga versión
    if not u or (u.status == 'failed' and not u.files) then
        if u and tries > 0 and u.err and not u.err:find('publicada') and not u.err:find('respuesta') then
            check('descarga', false, 'falló: ' .. tostring(u.err)); return finish()
        end
        if t < (nextTry or 0) then return end
        nextTry = t + 1
        u, tries = Updater.new('localhost', 22122), tries + 1
        return
    end
    local s = u:update(dt)
    -- Recién llegado el manifiesto: los BIG más grandes cuentan como cambiados (se bajarán)
    if s == 'hashing' and not u._forced then
        u._forced = true
        local list = {}
        for _, f in ipairs(u.files) do list[#list + 1] = f end
        table.sort(list, function(a, b) return a.size > b.size end)
        for i = 1, math.min(BIG, #list) do u.known[list[i].path] = 'cambiado'; forced[list[i].path] = list[i] end
    end
    if s == 'downloading' and not dlStart then dlStart = t end
    if (s == 'installing' or s == 'done') and dlStart and not dlEnd then dlEnd = t end
    if s == 'failed' then check('descarga', false, 'falló: ' .. tostring(u.err)); return finish() end
    if s == 'done' then
        dlEnd = dlEnd or t
        local slot = 'update/slots/' .. u.version .. '/'
        local bad, got, nForced, copied = {}, 0, 0, 0
        for _, f in ipairs(u.files) do
            if f.download then
                local ok, data = pcall(fs.read, slot .. f.path)
                local h = ok and data and love.data.encode('string', 'hex', love.data.hash('sha256', data))
                if h ~= f.hash then bad[#bad + 1] = f.path else got = got + 1 end
                if forced[f.path] then nForced = nForced + 1 end
            elseif f.copy then copied = copied + 1 end
        end
        local mb, secs = u.bytesTotal / 1048576, math.max(0.01, dlEnd - dlStart)
        check('descarga', #bad == 0 and got > 0 and nForced == math.min(BIG, #u.files) and fs.getInfo(slot .. '.manifest.lua') ~= nil,
            ('versión %s: %d archivos bajados (%d forzados) y comprobados, %d mal%s; manifiesto guardado=%s'):format(
             u.version, got, nForced, #bad, #bad > 0 and (' (' .. bad[1] .. ')') or '', tostring(fs.getInfo(slot .. '.manifest.lua') ~= nil)))
        check('limite', mb / secs <= 2.6 and mb > 2,
            ('%.1f MB en %.1f s = %.2f MB/s (límite del servidor 2 MB/s por cliente)'):format(mb, secs, mb / secs))
        return finish()
    end
end

function love.draw()
    love.graphics.print(('%s  %.1f / %.1f MB'):format(tostring(u and u.status), (u and u.bytesDone or 0) / 1048576,
        (u and u.bytesTotal or 0) / 1048576), 20, 20)
end
