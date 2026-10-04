-- src/network/NameFilter.lua
-- Reglas de los NOMBRES de jugador, iguales en el cliente (antes de enviar) y en el servidor (que no se fía del
-- cliente). Un nombre vale si:
--   · tiene entre MIN y MAX caracteres;
--   · solo lleva letras sin acento, números, guion y guion bajo (sin espacios ni símbolos);
--   · no contiene una palabra vetada (BLOCKED / EXACT) ni se hace pasar por el sistema (RESERVED).
--
--   NameFilter.check(nombre) → true  |  false, motivo ('short' | 'long' | 'chars' | 'blocked')
--   NameFilter.typed(texto)  → el texto solo con los caracteres permitidos (para el campo de escribir)
--   NameFilter.isBlocked(texto) → ¿contiene algo vetado? (también para nombres de sala)
--
-- CÓMO SE MANTIENE: para vetar una palabra, añádela a BLOCKED (se busca DENTRO del nombre) o a EXACT (solo si el
-- nombre entero, o un trozo separado por _ - o números, es esa palabra: para palabras cortas que aparecen dentro de
-- otras inocentes). Escríbela en minúsculas, sin acentos y sin letras repetidas ("puta", no "puuta"): antes de
-- comparar, el nombre se NORMALIZA — minúsculas, números y símbolos que imitan letras (4→a, 3→e, 1→i, 0→o, 5→s, 7→t,
-- @→a, $→s, !→i), fuera separadores y letras repetidas — así "P_U_T_4", "puuuta" o "PuT4" caen igual. Si una palabra
-- inocente queda vetada por contener otra, ponla en ALLOWED.
local NameFilter = { MIN = 3, MAX = 14 }

local BLOCKED = {
    -- español
    'puta', 'puto', 'putit', 'mierd', 'cabron', 'pendej', 'verga', 'coñ', 'cono', 'joder', 'jodet', 'jodid', 'malparid', 'gonorea',
    'hijueput', 'hijodeput', 'hdp', 'maric', 'marica', 'zora', 'pinga', 'chinga', 'culer', 'mamon', 'mamaguev', 'guevon', 'huevon',
    'pajer', 'pajill', 'polla', 'chupapi', 'chupame', 'mamada', 'violad', 'violar', 'violacion', 'pedofil', 'nazi', 'hitler',
    'negrat', 'sudaca', 'retrasad', 'mongol', 'subnormal', 'prostitut', 'culiad', 'culiao', 'conchetumar', 'conchatumadre', 'ctm',
    'vergon', 'pichula', 'cagar', 'cagad', 'cojon', 'gilipoll', 'capull', 'boludo', 'pelotud', 'forro', 'trolo',
    -- inglés
    'fuck', 'fuk', 'fck', 'shit', 'bitch', 'biatch', 'cunt', 'nigger', 'niger', 'nigga', 'niga', 'fagot', 'fag', 'dick', 'cock', 'pussy', 'pusy',
    'whore', 'slut', 'bastard', 'asshole', 'ashole', 'jerkof', 'wank', 'penis', 'vagina', 'porn', 'sex', 'rape', 'rapist', 'pedo',
    'retard', 'kys', 'kilyourself', 'suicid', 'cum', 'jizz', 'boob', 'tits', 'dildo', 'anal', 'anus', 'horny', 'milf', 'incest',
    'terrorist', 'isis', 'heil',
}
-- (solo si el nombre entero o uno de sus trozos es exactamente esto: aparecen dentro de palabras inocentes)
local EXACT = { 'ass', 'culo', 'pito', 'pene', 'teta', 'tetas', 'ano', 'gay', 'homo', 'coño', 'pis', 'caca', 'semen', 'hoe', 'hell', 'damn', 'kkk' }
local RESERVED = { 'admin', 'administrador', 'moderador', 'moderator', 'mod', 'server', 'servidor', 'system', 'sistema', 'host', 'anthropic', 'staff', 'dev' }
-- (inocentes que contienen una vetada)
local ALLOWED = { 'cucumber', 'document', 'analog', 'analis', 'canal', 'banal', 'final', 'animal', 'manual', 'anual', 'sexto', 'sexta', 'essex',
                  'cocktail', 'peacock', 'hancock', 'dickens', 'scunthorpe', 'grape', 'drape', 'scrape', 'therapist', 'conocer', 'conocid',
                  'icono', 'cono_', 'mongolia', 'tarzan', 'forros', 'analia', 'analy', 'cumbre', 'cumbia', 'cumple', 'circum', 'acumul', 'document',
                  'pedor', 'torpedo', 'pedal', 'expedic', 'cagarruta', 'recagad', 'transex', 'pollac', 'polland', 'apollo', 'pollo' }

local LEET = { ['4'] = 'a', ['@'] = 'a', ['3'] = 'e', ['1'] = 'i', ['!'] = 'i', ['0'] = 'o', ['5'] = 's', ['$'] = 's', ['7'] = 't', ['8'] = 'b', ['9'] = 'g' }

-- minúsculas, sin acentos (por si llegan), letras que se imitan con números, y letras repetidas en una
local function fold(s)
    s = s:lower()
    s = s:gsub('á', 'a'):gsub('é', 'e'):gsub('í', 'i'):gsub('ó', 'o'):gsub('ú', 'u'):gsub('ü', 'u')
    s = s:gsub('Á', 'a'):gsub('É', 'e'):gsub('Í', 'i'):gsub('Ó', 'o'):gsub('Ú', 'u'):gsub('ñ', 'ñ'):gsub('Ñ', 'ñ')
    return s
end
local function squeeze(s)
    local out, last = {}, nil
    for ch in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if ch ~= last then out[#out + 1] = ch end
        last = ch
    end
    return table.concat(out)
end
local function norm(s, leet)
    s = fold(s)
    if leet then s = s:gsub('.', LEET) end
    return squeeze((s:gsub('[^%a\128-\255]', '')))
end

local function has(list, s, plain)
    for _, w in ipairs(list) do
        if s:find(squeeze(w), 1, true) then return w end
    end
end

function NameFilter.isBlocked(text)
    if type(text) ~= 'string' then return true end
    -- trozos (separados por lo que no es letra): una palabra corta vetada o reservada, tal cual
    local low = fold(text)
    for tok in (low:gsub('[%d]', function(d) return LEET[d] or d end)):gmatch('[%a\128-\255]+') do
        local t = squeeze(tok)
        for _, w in ipairs(EXACT) do if t == squeeze(w) then return true end end
        for _, w in ipairs(RESERVED) do if t == squeeze(w) then return true end end
    end
    -- el nombre entero, normalizado de dos maneras (con los números como letras y sin ellos)
    for _, leet in ipairs({ true, false }) do
        local n = norm(text, leet)
        for _, w in ipairs(EXACT) do if n == squeeze(w) then return true end end
        for _, w in ipairs(RESERVED) do if n == squeeze(w) then return true end end
        local clean = n
        for _, ok in ipairs(ALLOWED) do clean = clean:gsub(squeeze((ok:gsub('_', ''))), ' ') end
        if has(BLOCKED, clean) then return true end
    end
    return false
end

-- Solo los caracteres que puede llevar un nombre (para filtrar lo que se teclea)
function NameFilter.typed(text)
    return (tostring(text or ''):gsub('[^%w_%-]', ''))
end

function NameFilter.check(name)
    if type(name) ~= 'string' then return false, 'chars' end
    if name:find('[^%w_%-]') then return false, 'chars' end
    if #name < NameFilter.MIN then return false, 'short' end
    if #name > NameFilter.MAX then return false, 'long' end
    if not name:find('%a') then return false, 'chars' end          -- (al menos una letra)
    if NameFilter.isBlocked(name) then return false, 'blocked' end
    return true
end

return NameFilter
