-- tools/tests/flappy_campaign — la CAMPAÑA FLAPPY a nivel de módulos (docs/design/flappy-plan-3-campaign-frame.md):
--   archivo    SaveFile: escribir y leer una tabla; un archivo roto se lee como nil + dañado y NO se sobrescribe
--   progreso   RunCore con un catálogo de mentira (2 mundos x 2 nodos): orden de los nodos, el mundo siguiente tras el
--              jefe, frontier, score (mejor nota, puntos), restartWorld (borra lo superado del mundo y guarda los récords)
--   zonas      cada etapa de src/flappy/Zones.lua existe, es un nivel Flappy con meta y sin errores del editor, con al
--              menos 1 jaula, 3 cargas y 1 comida (la de su zona); cada muro agrietado TAPA algo (lo de detrás no se
--              alcanza desde delante sin romperlo); la etapa del JEFE, sin jaula pero con su zona de jefe y un jefe dentro;
--              SIN SUELO (Plan 5d): ni césped ni tierra, ningún pilar flota (cuelga del techo o sube desde el borde de
--              abajo), cada lanzarredes sobre su soporte hasta el borde y todas las etapas de la zona con su fondo;
--              el MAPA de cada zona: su arte existe, cada nodo (y la tienda, si vende algo) tiene su sitio y no se pisan
--   premio     el premio de la nota (S: +1 vida; A: +500 puntos) se DA y se guarda, no solo sale en los resultados
--   partida    FlappyRun: abrir un hueco escribe flappy<n>.sav (no story<n>.sav), las etapas se abren en orden, vidas de
--              Fácil al empezar, gameOver vuelve al principio de la zona
--   monedero   el MONEDERO sube con los puntos de cada etapa TERMINADA; salir a medias y el game over no lo tocan;
--              comprar no baja el récord de puntos
--   tienda     FlappyRun.buy: ok / poor / full / type_full (solo ok gasta y guarda); los datos de src/flappy/Shops.lua
--   migrar     una partida v3 carga con el monedero a 0 y lo demás igual
--   (los casos de pantallas — mapa, partidas, CONTINUAR — van en menu_flow, que corre el juego de verdad)
--
--   tools/tests/run.sh flappy_campaign   (CASE=nombre: solo ese)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({ play = function() end }, { __index = function() return function() end end })

local fails = 0
local function check(case, ok, msg)
    print(('%-10s %s  %s'):format(case, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function deepEq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local cases = {}

function cases.archivo()
    local SaveFile = require 'src/core/SaveFile'
    local data = { a = 1, t = { 'x' }, s = 'hola "q"' }
    local wrote = SaveFile.write('prueba.sav', data)
    local back, dmg = SaveFile.read('prueba.sav')
    local roundOk = wrote and deepEq(back, data) and not dmg
    local garbage = 'esto no es Lua {{{'
    love.filesystem.write('flappy9.sav', garbage)
    love.filesystem.remove('flappy9.sav.bak')
    local d2, dmg2 = SaveFile.read('flappy9.sav')
    local kept = love.filesystem.read('flappy9.sav') == garbage
    local mt = SaveFile.modtime('prueba.sav')
    SaveFile.remove('prueba.sav')
    local gone = love.filesystem.getInfo('prueba.sav') == nil and love.filesystem.getInfo('prueba.sav.bak') == nil
    love.filesystem.remove('flappy9.sav'); love.filesystem.remove('flappy9.sav.damaged')
    check('archivo', roundOk and d2 == nil and dmg2 == true and kept and type(mt) == 'number' and gone,
          ('ida y vuelta=%s; roto → nil=%s, dañado=%s, intacto=%s; modtime=%s; borrar=%s'):format(
           tostring(roundOk), tostring(d2 == nil), tostring(dmg2), tostring(kept), tostring(mt), tostring(gone)))
end

function cases.progreso()
    local RunCore = require 'src/story/RunCore'
    local store = {}
    local saves = { SLOTS = 3,
        new = function(diff) return { difficulty = diff or 'normal', world = 1, node = 1, lives = 3, done = {}, best = {},
                                      playTime = 0, points = 0, gameOvers = 0 } end,
        load = function(i) return store[i] end,
        write = function(i, d) store[i] = d; return true end }
    local W = { { id = 'a', levels = { 'a1' }, boss = 'a2' }, { id = 'b', levels = { 'b1' }, boss = 'b2' } }
    local worlds = { count = function() return #W end, get = function(w) return W[w] end,
        nodes = function(w) local n = {}; for _, id in ipairs(W[w].levels) do n[#n + 1] = { id = id } end
                            n[#n + 1] = { id = W[w].boss }; return n end }
    local R = {}
    RunCore.install(R, saves, worlds)
    R.open(1, 'normal')
    local s0 = R.state(1, 1) == 'open' and R.state(1, 2) == 'locked' and not R.worldOpen(2)
    local sum = R.score('a1', { time = 10, width = 40, score = 500 })
    local s1 = R.state(1, 2) == 'open' and sum and sum.grade ~= nil and R.data.best.a1 ~= nil and R.data.points > 0
    R.score('a2', { time = 10, width = 40 })
    local s2 = R.worldOpen(2) and R.state(2, 1) == 'open'
    local fw, fk = R.frontier()
    local done, total = R.progress()
    R.restartWorld(1)
    local s3 = not R.isDone('a1') and not R.isDone('a2') and R.data.best.a1 ~= nil and store[1] == R.data
    R.setLives(0)
    check('progreso', s0 and s1 and s2 and fw == 2 and fk == 1 and done == 2 and total == 4 and s3 and R.data.lives == 1,
          ('al empezar=%s; tras a1=%s; tras el jefe, mundo 2=%s; frontier %s,%s; progreso %d/%d; reiniciar el mundo 1=%s; vidas mínimas %d'):format(
           tostring(s0), tostring(s1), tostring(s2), tostring(fw), tostring(fk), done, total, tostring(s3), R.data.lives))
end

function cases.zonas()
    local Zones = require 'src/flappy/Zones'
    local Level = require 'src/world/level/Level'
    local Model = require 'src/editor/EditorModel'
    local n, bad, zoneBg = 0, {}, {}
    for z = 1, Zones.count() do
        for _, node in ipairs(Zones.nodes(z)) do
            n = n + 1
            local path = Zones.path(node.id)
            if not love.filesystem.getInfo(path) then bad[#bad + 1] = node.id .. ' (no existe)'
            else
                local lv = Level.new(path)
                local errs = 0
                for _, w in ipairs(Model.load(path):validate()) do if w[1] == 'error' then errs = errs + 1 end end
                if not lv.flappy then bad[#bad + 1] = node.id .. ' (no es Flappy)' end
                if lv:countTrigger('finish') == 0 then bad[#bad + 1] = node.id .. ' (sin meta)' end
                if errs > 0 then bad[#bad + 1] = node.id .. ' (' .. errs .. ' errores)' end
                -- (contenido del Plan 4: al menos 1 jaula y 3 cargas; la comida es la de su zona)
                local cages, charges, food = 0, 0, 0
                for _, e in ipairs(lv.entities) do
                    if e.type == 'cage' then cages = cages + 1 end
                    if e.type == 'flapcharge' then charges = charges + 1 end
                    if e.type == 'apple' then
                        food = food + 1
                        local skin = require('src/world/entities/types/items/apple').class.skinFor(e.props, lv)
                        if skin ~= Zones.get(z).food then bad[#bad + 1] = node.id .. ' (comida ' .. tostring(skin) .. ')' end
                    end
                end
                -- (el muro TAPA algo: la casilla de detrás de su fila de arriba no se alcanza desde delante del muro
                --  sin romperlo — un escondite o la entrada de un túnel —: se busca un camino por casillas sin bloques
                --  sólidos ni muros —los pilares se atraviesan— sin pasar de dos columnas detrás del muro)
                local walls = {}
                for _, e in ipairs(lv.entities) do
                    if e.type == 'crackwall' then
                        local rows = e.props and e.props.rows or 3
                        for r = e.row - rows + 1, e.row do walls[e.col .. ',' .. r] = true end
                    end
                end
                for _, e in ipairs(lv.entities) do
                    if e.type == 'crackwall' then
                        local c, top = e.col, e.row - (e.props and e.props.rows or 3) + 1
                        local function free(cc, r)
                            return cc >= 1 and r >= 1 and r <= lv.tileH and not walls[cc .. ',' .. r]
                                   and lv:getDef(cc, r).collision ~= 'solid'
                        end
                        local seen, queue, reached = { [(c - 1) .. ',' .. top] = true }, { { c - 1, top } }, false
                        while #queue > 0 and not reached do
                            local p = table.remove(queue)
                            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                                local cc, r = p[1] + d[1], p[2] + d[2]
                                local k = cc .. ',' .. r
                                if cc <= c + 2 and not seen[k] and free(cc, r) then
                                    if cc == c + 1 and r == top then reached = true end
                                    seen[k] = true; queue[#queue + 1] = { cc, r }
                                end
                            end
                        end
                        if reached then bad[#bad + 1] = node.id .. ' (el muro de la columna ' .. c .. ' no encierra nada)' end
                    end
                end
                -- (SIN SUELO, Plan 5d: ni césped ni tierra; en la última fila solo pilares, soportes y la meta; cada tramo de
                --  pilar cuelga del techo o sube desde el borde de abajo —o de un bloque sólido: el suelo de un túnel—,
                --  nunca flota; cada lanzarredes, sobre su soporte hasta el borde de abajo; todas las etapas de la zona
                --  con el mismo fondo, puesto: el de la zona, no el prado por defecto)
                local H = lv.tileH
                local function nameAt(c, r) return lv:getDef(c, r).name end
                local ground
                for c = 1, lv.tileW do
                    for r = 1, H do
                        local nm = nameAt(c, r)
                        if (nm == 'grass' or nm == 'dirt') and not ground then
                            ground = true
                            bad[#bad + 1] = ('%s (suelo: %s en %d,%d)'):format(node.id, nm, c, r)
                        end
                        if r == H and nm ~= 'empty' and nm ~= 'pillar' and nm ~= 'mount' and nm ~= 'finish' and not ground then
                            bad[#bad + 1] = ('%s (fila de abajo: %s en la columna %d)'):format(node.id, nm, c)
                        end
                    end
                    local r = 1
                    while r <= H do
                        if nameAt(c, r) == 'pillar' then
                            local top = r
                            while r + 1 <= H and nameAt(c, r + 1) == 'pillar' do r = r + 1 end
                            local up = top == 1 or lv:getDef(c, top - 1).collision == 'solid'
                            local down = r == H or lv:getDef(c, r + 1).collision == 'solid'
                            if not (up or down) then
                                bad[#bad + 1] = ('%s (pilar flotando: columna %d, filas %d-%d)'):format(node.id, c, top, r)
                            end
                        end
                        r = r + 1
                    end
                end
                for _, e in ipairs(lv.entities) do
                    if e.type == 'netlauncher' then
                        for r = e.row + 1, H do
                            if nameAt(e.col, r) ~= 'mount' then
                                bad[#bad + 1] = ('%s (lanzarredes %d,%d sin soporte en la fila %d)'):format(node.id, e.col, e.row, r)
                                break
                            end
                        end
                    end
                end
                zoneBg[z] = zoneBg[z] or lv.background
                if not lv.background or lv.background ~= zoneBg[z] then
                    bad[#bad + 1] = ('%s (fondo %s, el de la zona %s)'):format(node.id, tostring(lv.background), tostring(zoneBg[z]))
                end
                -- (la etapa del jefe: sin jaula, pero con su zona de jefe y un jefe dentro)
                if node.boss then
                    local bosses = 0
                    for _, e in ipairs(lv.entities) do
                        local d = require('src/world/entities/base/EntityTypes').get(e.type)
                        if d and d.boss then
                            for _, bz in ipairs(lv.bossZones or {}) do
                                if require('src/world/systems/BossZones').containsCell(bz, e.col, e.row) then bosses = bosses + 1 end
                            end
                        end
                    end
                    if #(lv.bossZones or {}) < 1 or bosses < 1 then
                        bad[#bad + 1] = ('%s (jefe: %d zonas, %d jefes dentro)'):format(node.id, #(lv.bossZones or {}), bosses)
                    end
                    cages = math.max(cages, 1)
                end
                if cages < 1 or charges < 3 or food < 1 then
                    bad[#bad + 1] = ('%s (%d jaulas, %d cargas, %d comidas)'):format(node.id, cages, charges, food)
                end
            end
        end
    end
    -- (el MAPA de cada zona: su arte existe, cada nodo tiene su sitio dentro de la pantalla y, si la zona vende algo,
    --  el nido del mercader también; ningún par de sitios se pisa —a 1280 de ancho, cajas de 96 px—)
    for z = 1, Zones.count() do
        local M, Z = Zones.get(z).map, Zones.get(z)
        if not M then bad[#bad + 1] = Z.id .. ' (sin mapa)'
        else
            for _, f in ipairs({ '_bg', '_pillar', '_nest-Sheet', '_boss-Sheet', '_shop-Sheet' }) do
                local path = 'assets/images/flappy/map/' .. M.art .. f .. '.png'
                if not love.filesystem.getInfo(path) then bad[#bad + 1] = path .. ' (no existe)' end
            end
            local pts = {}
            local function at(name, p)
                if not p or p[1] < 0.03 or p[1] > 0.97 or p[2] < 0.25 or p[2] > 0.7 then
                    bad[#bad + 1] = ('%s: el sitio de %s (%s)'):format(Z.id, name, p and (p[1] .. ',' .. p[2]) or 'falta')
                else pts[#pts + 1] = { name, p } end
            end
            for _, node in ipairs(Zones.nodes(z)) do at(node.id, M.at and M.at[node.id]) end
            if #require('src/flappy/Shops').forZone(z) > 0 then at('la tienda', M.shop) end
            for i = 1, #pts do
                for j = i + 1, #pts do
                    if math.abs(pts[i][2][1] - pts[j][2][1]) * 1280 < 96 then
                        bad[#bad + 1] = ('%s: %s y %s se pisan'):format(Z.id, pts[i][1], pts[j][1])
                    end
                end
            end
        end
    end
    check('zonas', n >= 3 and #bad == 0 and Zones.get(1).id == 'valle',
          ('%d etapas en %d zonas; problemas: %s'):format(n, Zones.count(), #bad > 0 and table.concat(bad, ', ') or 'ninguno'))
end

function cases.partida()
    local FlappyRun = require 'src/flappy/FlappyRun'
    local FlappySave = require 'src/flappy/FlappySave'
    for i = 1, FlappySave.SLOTS do FlappySave.delete(i) end
    love.filesystem.remove('story2.sav')
    FlappyRun.open(2, 'easy')
    local files = love.filesystem.getInfo('flappy2.sav') ~= nil and love.filesystem.getInfo('story2.sav') == nil
    local lives0 = FlappyRun.data.lives
    local o0 = FlappyRun.state(1, 1) == 'open' and FlappyRun.state(1, 2) == 'locked'
    local sum = FlappyRun.complete('valle_pilares_1', { time = 20, width = 150, score = 100 })
    local o1 = sum ~= nil and FlappyRun.state(1, 2) == 'open' and FlappySave.load(2).done.valle_pilares_1 == true
    FlappyRun.data.world, FlappyRun.data.node = 1, 2
    local z = FlappyRun.gameOver()
    local back = z == 1 and FlappyRun.data.node == 1 and not FlappyRun.isDone('valle_pilares_1') and FlappyRun.data.lives == lives0
    -- (terminar la última etapa con la campaña aún no lista — Campaign.READY false — NO desbloquea Aventura para siempre)
    local Save = require 'src/story/Save'
    local g = Save.global(); g.adventure = nil; Save.writeGlobal(g)
    FlappyRun.complete('valle_pilares_1', { time = 20, width = 150 })
    local nodes = require('src/flappy/Zones').nodes(require('src/flappy/Zones').count())
    FlappyRun.complete(nodes[#nodes].id, { time = 20, width = 150 })
    local notYet = Save.global().adventure == nil
    FlappyRun.close()
    FlappySave.delete(2)
    check('partida', files and lives0 == 3 and o0 and o1 and back and notYet,
          ('flappy2.sav sí y story2.sav no=%s; vidas al empezar %d; orden al empezar=%s; tras la 1ª etapa=%s; game over → zona %s, nodo 1, vidas de nuevo=%s; terminarla sin la campaña lista no abre Aventura=%s'):format(
           tostring(files), lives0, tostring(o0), tostring(o1), tostring(z), tostring(back), tostring(notYet)))
end

-- El premio de la nota (Score.LEVEL_REWARD: S +1 vida, A +500 puntos), la primera vez: se DA, no solo se enseña
function cases.premio()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    local Score = require 'src/story/Score'
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    local l0, p0 = FlappyRun.data.lives, FlappyRun.data.points
    local out = FlappyRun.complete('valle_pilares_1', { time = 1, width = 400, deaths = 0, hits = 0, score = 0, lives = l0 })
    local rw = out and out.reward
    local given = rw ~= nil and ((rw.lives and FlappyRun.data.lives == l0 + rw.lives) or (rw.points and FlappyRun.data.points == p0 + (out.gain or 0) + rw.points))
    local saved = FlappySave.load(3)
    local kept = saved and saved.lives == FlappyRun.data.lives and saved.points == FlappyRun.data.points
    FlappyRun.close(); FlappySave.delete(3)
    check('premio', out and out.grade == 'S' and given and kept,
          ('nota %s; premio %s; vidas %d → %d; puntos %d → %d; guardado=%s'):format(out and out.grade or '-',
           rw and (rw.lives and ('+' .. rw.lives .. ' vida') or ('+' .. tostring(rw.points) .. ' puntos')) or 'ninguno',
           l0, FlappyRun.data and FlappyRun.data.lives or -1, p0, FlappyRun.data and FlappyRun.data.points or -1, tostring(kept)))
end

-- Los flappies liberados se guardan SOLO al terminar la etapa (golden rule 7): con `result.rescued`
function cases.jaulas()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    FlappyRun.setLives(FlappyRun.data.lives - 1)                         -- (salir a medias: solo vidas)
    local none = next(FlappySave.load(3).rescued or {}) == nil
    -- (el índice de colocación de la jaula de verdad de la etapa)
    local cageIdx
    for i, e in ipairs(require('libs/json').decode(love.filesystem.read('assets/levels/valle_pilares_1.json')).entities) do
        if e.type == 'cage' then cageIdx = i end
    end
    FlappyRun.complete('valle_pilares_1', { time = 20, width = 120, rescued = { cageIdx } })
    local d = FlappySave.load(3)
    local saved = cageIdx and d.rescued and d.rescued.valle_pilares_1 and d.rescued.valle_pilares_1[cageIdx] == true
    local freed, total = FlappyRun.rescuedCount('valle_pilares_1')
    FlappyRun.close(); FlappySave.delete(3)
    check('jaulas', none and saved and freed == 1 and FlappySave.VERSION >= 2,
          ('salir a medias no guarda nada=%s; terminar guarda la 1=%s; cuenta %s/%s; versión de las partidas %d'):format(
           tostring(none), tostring(saved), tostring(freed), tostring(total), FlappySave.VERSION))
end

-- Inventario de POWER-UPS por partida (docs/design/powerups.md): 6 en total, 3 por tipo; gastar escribe ya la partida
function cases.inventario()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    local Powerups = require 'src/world/powerups/Powerups'
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    local r = {}
    for i = 1, 4 do r[#r + 1] = FlappyRun.addPowerup('shield') end
    for i = 1, 3 do r[#r + 1] = FlappyRun.addPowerup('heart') end
    r[#r + 1] = FlappyRun.addPowerup('strength')
    local codes = table.concat(r, ',')
    local spent = FlappyRun.spendPowerup('shield')
    local inFile = (FlappySave.load(3).inventory or {}).shield
    local missing = FlappyRun.spendPowerup('ghost')
    local total = FlappyRun.inventoryCount()
    FlappyRun.close(); FlappySave.delete(3)
    -- una partida de la versión 2 (sin inventario) carga con el inventario vacío
    local SaveFile = require 'src/core/SaveFile'
    SaveFile.write('flappy3.sav', { version = 2, difficulty = 'normal', world = 1, node = 1, lives = 3, done = {}, best = {} })
    local old = FlappySave.load(3)
    FlappySave.delete(3)
    local ids = {}
    for _, p in ipairs(Powerups.forMode('flappy')) do ids[#ids + 1] = p.id end
    check('inventario', codes == 'ok,ok,ok,type_full,ok,ok,ok,full' and spent and inFile == 2 and not missing and total == 5
          and old and type(old.inventory) == 'table' and next(old.inventory) == nil and FlappySave.VERSION >= 3
          and table.concat(ids, ',') == 'shield,heart,strength,magnet_points,magnet_items,magnet_all,small,ghost',
          ('añadir: %s; gastar un escudo=%s (en el archivo: %s); gastar uno que no hay=%s; total %d; v2 → inventario vacío=%s; catálogo Flappy: %s'):format(
           codes, tostring(spent), tostring(inFile), tostring(missing), total, tostring(old and old.inventory and next(old.inventory) == nil), table.concat(ids, ',')))
end

-- Cada jaula REGALA su power-up (`gift`) al terminar la etapa; una vez por partida; con el inventario lleno se pierde
-- (y se avisa) pero la jaula cuenta como liberada
function cases.regalos()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    local ents = require('libs/json').decode(love.filesystem.read('assets/levels/valle_pilares_1.json')).entities
    local cageIdx, gift
    for i, e in ipairs(ents) do if e.type == 'cage' then cageIdx, gift = i, (e.props or {}).gift or 'shield' end end
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    local s1 = FlappyRun.complete('valle_pilares_1', { time = 20, width = 120, rescued = { cageIdx } })
    local got = (FlappyRun.data.inventory[gift] or 0) == 1 and s1.gifts and s1.gifts[1] == gift
    FlappyRun.complete('valle_pilares_1', { time = 20, width = 120, rescued = { cageIdx } })   -- (otra vez: ya liberada)
    local once = (FlappyRun.data.inventory[gift] or 0) == 1
    -- lleno: 6 en total → se pierde, con aviso; la jaula cuenta como liberada
    FlappyRun.data.rescued = {}
    FlappyRun.data.inventory = { heart = 3, strength = 3 }
    local s3 = FlappyRun.complete('valle_pilares_1', { time = 20, width = 120, rescued = { cageIdx } })
    local lost = s3.lostGifts and s3.lostGifts[1] == gift and FlappyRun.inventoryCount() == 6
                 and FlappySave.load(3).rescued.valle_pilares_1[cageIdx] == true
    FlappyRun.close(); FlappySave.delete(3)
    check('regalos', cageIdx and got and once and lost,
          ('la jaula %s regala %s=%s; una sola vez=%s; con el inventario lleno se pierde y se avisa=%s'):format(
           tostring(cageIdx), tostring(gift), tostring(got), tostring(once), tostring(lost)))
end

-- El MONEDERO (docs/design/powerups.md § Shops): se llena con los puntos de cada etapa TERMINADA (golden rule 7); salir
-- a medias o el game over no lo tocan; comprar lo gasta pero el récord de puntos (`points`, `best`) no baja
function cases.monedero()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    local w0 = FlappyRun.data.wallet
    FlappyRun.setLives(FlappyRun.data.lives - 1)                         -- (salir a medias: solo las vidas)
    local leftOk = FlappyRun.data.wallet == w0 and FlappySave.load(3).wallet == w0
    local out = FlappyRun.complete('valle_pilares_1', { time = 20, width = 150, score = 200 })
    local earned = (out and out.points or 0) + (out and out.reward and out.reward.points or 0)
    local w1 = FlappyRun.data.wallet
    local finOk = out and out.points > 0 and w1 == w0 + earned and FlappySave.load(3).wallet == w1
    -- el game over de la zona no quita ni da nada al monedero
    FlappyRun.gameOver()
    local goOk = FlappyRun.data.wallet == w1 and FlappySave.load(3).wallet == w1
    -- comprar: baja el monedero, NO el récord
    local p0, b0 = FlappyRun.data.points, FlappyRun.data.best.valle_pilares_1.score
    FlappyRun.data.wallet = 1000
    local r = FlappyRun.buy('shield', 300)
    local recOk = r == 'ok' and FlappyRun.data.wallet == 700 and FlappyRun.data.points == p0
                  and FlappyRun.data.best.valle_pilares_1.score == b0 and FlappySave.load(3).points == p0
    FlappyRun.close(); FlappySave.delete(3)
    check('monedero', type(w0) == 'number' and w0 == 0 and leftOk and finOk and goOk and recOk,
          ('al empezar %s; salir a medias no lo toca=%s; terminar la etapa +%d → %s (guardado)=%s; game over no lo toca=%s; comprar baja el monedero y no el récord=%s (%s)'):format(
           tostring(w0), tostring(leftOk), earned, tostring(w1), tostring(finOk), tostring(goOk), tostring(recOk), tostring(r)))
end

-- La TIENDA: FlappyRun.buy(id, precio) → 'ok' | 'poor' | 'full' | 'type_full'; solo 'ok' gasta y guarda; los datos de
-- la tienda del Valle (src/flappy/Shops.lua)
function cases.tienda()
    local FlappyRun, FlappySave = require 'src/flappy/FlappyRun', require 'src/flappy/FlappySave'
    local Shops, Powerups = require 'src/flappy/Shops', require 'src/world/powerups/Powerups'
    local list = Shops.LIST.valle or {}
    local items = {}
    for _, it in ipairs(list) do
        local def = Powerups.get(it.id)
        local flappy = false
        for _, m in ipairs(def and def.modes or {}) do if m == 'flappy' then flappy = true end end
        items[#items + 1] = it.id .. '=' .. tostring(it.price) .. (flappy and '' or '(?)')
    end
    local dataOk = table.concat(items, ',') == 'shield=300,heart=400,magnet_points=250'
                   and Shops.forZone(1) == list
    FlappySave.delete(3)
    FlappyRun.open(3, 'normal')
    local d = FlappyRun.data
    d.wallet = 1000
    local r1 = FlappyRun.buy('shield', 300)
    local f1 = FlappySave.load(3)
    local okBuy = r1 == 'ok' and d.wallet == 700 and d.inventory.shield == 1 and f1.wallet == 700 and f1.inventory.shield == 1
    d.wallet = 100
    local r2 = FlappyRun.buy('heart', 400)
    local poor = r2 == 'poor' and d.wallet == 100 and d.inventory.heart == nil and FlappySave.load(3).wallet == 700
    d.wallet = 5000
    d.inventory = { shield = 3 }
    local r3 = FlappyRun.buy('shield', 300)
    local tfull = r3 == 'type_full' and d.wallet == 5000 and d.inventory.shield == 3
    d.inventory = { heart = 3, strength = 3 }
    local r4 = FlappyRun.buy('magnet_points', 250)
    local full = r4 == 'full' and d.wallet == 5000 and d.inventory.magnet_points == nil and FlappyRun.inventoryCount() == 6
    FlappyRun.close(); FlappySave.delete(3)
    check('tienda', dataOk and okBuy and poor and tfull and full,
          ('Valle: %s; comprar=%s (%s); sin puntos=%s (%s); 3 de ese tipo=%s (%s); inventario lleno=%s (%s)'):format(
           table.concat(items, ','), tostring(okBuy), tostring(r1), tostring(poor), tostring(r2), tostring(tfull), tostring(r3),
           tostring(full), tostring(r4)))
end

-- Una partida de la versión 3 (sin monedero) carga con el monedero a 0 y todo lo demás igual; una v4 conserva el suyo
function cases.migrar()
    local FlappySave = require 'src/flappy/FlappySave'
    local SaveFile = require 'src/core/SaveFile'
    SaveFile.write('flappy3.sav', { version = 3, difficulty = 'hard', world = 1, node = 2, lives = 4, done = { valle_pilares_1 = true },
                                    best = { valle_pilares_1 = { score = 300, grade = 'A' } }, playTime = 50, points = 1234,
                                    gameOvers = 1, rescued = { valle_pilares_1 = { [7] = true } }, inventory = { shield = 2 } })
    local d = FlappySave.load(3)
    local kept = d and d.wallet == 0 and d.version == FlappySave.VERSION and FlappySave.VERSION == 4 and d.difficulty == 'hard'
                 and d.node == 2 and d.lives == 4 and d.done.valle_pilares_1 == true and d.best.valle_pilares_1.score == 300
                 and d.points == 1234 and d.gameOvers == 1 and d.rescued.valle_pilares_1[7] == true and d.inventory.shield == 2
    SaveFile.write('flappy3.sav', { version = 4, difficulty = 'normal', world = 1, node = 1, lives = 3, done = {}, best = {}, wallet = 55 })
    local d4 = FlappySave.load(3)
    local fresh = FlappySave.new('easy').wallet
    FlappySave.delete(3)
    check('migrar', kept and d4 and d4.wallet == 55 and fresh == 0,
          ('v3 → monedero %s, versión %s, lo demás igual=%s; v4 conserva el suyo (%s); partida nueva %s'):format(
           tostring(d and d.wallet), tostring(d and d.version), tostring(kept), tostring(d4 and d4.wallet), tostring(fresh)))
end

local ORDER = { 'archivo', 'progreso', 'zonas', 'partida', 'premio', 'jaulas', 'inventario', 'regalos', 'monedero', 'tienda', 'migrar' }
function love.load()
    local only = os.getenv('CASE')
    for _, name in ipairs(ORDER) do
        if not only or only == name then
            local ok, err = pcall(cases[name])
            if not ok then check(name, false, 'error de Lua: ' .. tostring(err)) end
        end
    end
    print(fails == 0 and 'TODO OK' or ('FALLOS: ' .. fails))
    love.event.quit(fails == 0 and 0 or 1)
end
