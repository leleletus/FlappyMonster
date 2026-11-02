-- src/world/level/CatalogWorker.lua
-- Las FICHAS de Juego Libre (LevelCatalog) en un HILO aparte: LÖVE corre el juego en un solo núcleo y cargar un nivel
-- entero por tarjeta, en un aparato sin compilador de Lua (Switch, móviles ARM), daba tirones de cientos de ms.
-- El hilo guarda las fichas en freeplay_cards.dat (carpeta de guardado; valen para esa versión del juego y ese archivo
-- de nivel), así que solo se calculan la primera vez. Si no hay hilo o falla, FreePlayState las carga como antes.
--   CatalogWorker.start(files)        lanza el hilo (si no está ya en marcha)
--   CatalogWorker.want(file)          que esa ficha vaya antes
--   CatalogWorker.poll(cache, budget) pasa las fichas listas a `cache`; devuelve si llegó alguna
--   CatalogWorker.running()           ¿sigue trabajando? (si no, lo que falte lo carga el hilo principal)
local CatalogWorker = {}

local thread, out, req
local asked = {}
local reported = false

-- Por turnos solo en la Switch: ahí un hilo nuevo puede caer en el núcleo del juego (ver CatalogWorkerThread)
local SLICE = 20000

function CatalogWorker.running()
    if not thread then return false end
    if thread:isRunning() or out:getCount() > 0 then return true end
    local err = thread:getError()
    if err and not reported then
        reported = true
        print('[CatalogWorker] ' .. tostring(err))
    end
    return false
end

function CatalogWorker.start(files)
    if CatalogWorker.running() or #files == 0 then return end
    local ok, th = pcall(love.thread.newThread, 'src/world/level/CatalogWorkerThread.lua')
    if not ok or not th then return end
    local fs = love.filesystem
    local version = (fs.read('version.txt') or '?'):match('^%s*(.-)%s*$')
    local overlayBase = (UPDATE_MODE == 'overlay') and ('update/slots/' .. version .. '/') or nil
    thread, out, req, asked = th, love.thread.newChannel(), love.thread.newChannel(), {}
    thread:start(files, out, req, overlayBase or false, version, Input.isSwitch and SLICE or false)
end

function CatalogWorker.want(file)
    if thread and not asked[file] and thread:isRunning() then
        asked[file] = true
        req:push(file)
    end
end

function CatalogWorker.poll(cache, budget)
    if not thread then return false end
    local t0, got = love.timer.getTime(), false
    while love.timer.getTime() - t0 < budget do
        local m = out:pop()
        if not m then break end
        if m.info then cache[m.file] = m.info; got = true
        elseif m.broken then cache[m.file] = { broken = m.broken, file = m.file }; got = true end
    end
    return got
end

return CatalogWorker
