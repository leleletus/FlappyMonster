-- tools/tests/flappy_campaign — la CAMPAÑA FLAPPY a nivel de módulos (docs/design/flappy-plan-3-campaign-frame.md):
--   archivo    SaveFile: escribir y leer una tabla; un archivo roto se lee como nil + dañado y NO se sobrescribe
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

local ORDER = { 'archivo' }
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
