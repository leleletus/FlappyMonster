-- tools/tests/name_filter — el FILTRO DE NOMBRES (src/network/NameFilter.lua + NameWords.lua) sin ventana: nombres que
-- tienen que pasar (incluidos nombres de verdad que contienen trozos vetados) y nombres que no (con trucos: números por
-- letras, letras repetidas, separadores, mayúsculas).
--
--   tools/tests/run.sh name_filter
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
local NF = require 'src/network/NameFilter'

local GOOD = { 'Mati', 'Serqwjahk', 'mtvemo', 'Cassandra', 'Dickson', 'Hitchcock', 'Classic_77', 'Assassin', 'Bass_Pro',
    'Grapefruit', 'Analia', 'Cumbia', 'Torpedo', 'Pollito', 'Final_Boss', 'Monster_99', 'Michelle', 'Hello', 'Titan',
    'Sussex', 'Spike', 'Sapo', 'Gilberto', 'Mamut', 'Repollo', 'Computadora', 'Popular', 'Escultor', 'Pinchos', 'Glass',
    'Constitucion', 'Shell', 'Canal', 'Animal_Crew', 'Peacock', 'Cocktail', 'Benedick', 'Petition',
    'Bob', 'Bobby', 'Esperanza', 'Diaspora', 'Consuelo', 'Constanza', 'Xavier', 'Alexis', 'Forest_Gamer', 'xX_Pro_Xx' }
local BAD = { 'puta', 'PuT4', 'p_u_t_a', 'puuuuta', 'Fuck', 'fvck_you', 'f_u_c_k', 'sh1t', 'Bitch99', 'nigg4', 'Hitler',
    'nazi_boy', 'pendejo', 'Cabron', 'mierda', 'gilipollas', 'motherf', 'caralho', 'merda', 'porra', 'buceta', 'viado',
    'ass', 'culo', 'pene', 'admin', 'Server', 'moderador', 'conchetumare', 'hdp', 'kys', 'malparido', 'gonorrea',
    'pajero', 'zorra', 'Pinche', 'chingada', 'w4nker', 'twat', 'Prick', 'blowjob', 'p0rn', 'sexy', 'Tranny', 'pedofilo', 'perra', 'ptm' }

local fails = {}
for _, n in ipairs(GOOD) do if NF.isBlocked(n) then fails[#fails + 1] = 'vetado sin motivo: ' .. n end end
for _, n in ipairs(BAD) do if not NF.isBlocked(n) then fails[#fails + 1] = 'deja pasar: ' .. n end end
-- las reglas de forma (longitud, caracteres)
local shape = { { 'ab', 'short' }, { 'abcdefghijklmno', 'long' }, { 'hola mundo', 'chars' }, { '1234', 'chars' } }
for _, c in ipairs(shape) do
    local ok, why = NF.check(c[1])
    if ok or why ~= c[2] then fails[#fails + 1] = ('%s: %s (quería %s)'):format(c[1], tostring(why), c[2]) end
end
print(('%-8s %s  %d buenos, %d malos, %d de forma; %s'):format('nombres', #fails == 0 and 'OK   ' or 'FALLA', #GOOD, #BAD, #shape,
    #fails == 0 and 'todo bien' or table.concat(fails, ' · ')))
print(#fails == 0 and 'TODO OK' or 'FALLOS: 1')
function love.load() love.event.quit(#fails == 0 and 0 or 1) end
