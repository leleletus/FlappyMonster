-- src/network/NameWords.lua
-- Las LISTAS del filtro de nombres (src/network/NameFilter.lua: ahí, cómo se usan y cómo se normaliza el nombre antes de
-- comparar). Datos: para vetar una palabra, añádela aquí — en minúsculas, sin acentos, sin letras repetidas —; si una
-- palabra inocente cae, ponla en ALLOWED. El arnés `name_filter` comprueba nombres que deben pasar y que no.
-- Español, inglés y portugués; basado en listas públicas de palabras malsonantes (LDNOOBW), recortado a lo que puede
-- formar un nombre de 3-14 letras.
return {
    -- se buscan DENTRO del nombre
    BLOCKED = {
        'puta', 'puto', 'putit', 'mierd', 'cabron', 'pendej', 'verga', 'coñ', 'cono', 'joder', 'jodet', 'jodid',
        'malparid', 'gonorea', 'hijueput', 'hijodeput', 'hdp', 'maric', 'marica', 'zora', 'pinga', 'chinga', 'culer',
        'mamon', 'mamaguev', 'guevon', 'huevon', 'pajer', 'pajill', 'polla', 'chupapi', 'chupame', 'mamada',
        'violad', 'violar', 'violacion', 'pedofil', 'nazi', 'hitler', 'negrat', 'sudaca', 'retrasad', 'mongol',
        'subnormal', 'prostitut', 'culiad', 'culiao', 'conchetumar', 'conchatumadre', 'ctm', 'vergon', 'pichula',
        'cagar', 'cagad', 'cojon', 'gilipoll', 'capull', 'boludo', 'pelotud', 'trolo', 'fuck', 'fuk', 'fck',
        'shit', 'bitch', 'biatch', 'cunt', 'nigger', 'niger', 'nigga', 'niga', 'fagot', 'fag', 'dick', 'cock',
        'pussy', 'pusy', 'whore', 'slut', 'bastard', 'asshole', 'ashole', 'jerkof', 'wank', 'penis', 'vagina',
        'porn', 'sex', 'rape', 'rapist', 'pedo', 'retard', 'kys', 'kilyourself', 'suicid', 'cum', 'jizz', 'tits',
        'dildo', 'anal', 'anus', 'horny', 'milf', 'incest', 'terrorist', 'isis', 'heil', 'culiar', 'ojete', 'cerot',
        'huevad', 'conchesumadre', 'conchasumadre', 'reconcha', 'ptmr', 'cagon', 'vrga', 'chingad', 'pinche',
        'mamahuevo', 'carechimba', 'gonorrea', 'malnacid', 'zorra', 'puñet', 'punet', 'pajero', 'follar', 'follad',
        'cachond', 'putona', 'putero', 'travelo', 'sidos', 'motherf', 'mofo', 'fucker', 'fuking', 'fvck', 'phuck',
        'shithead', 'dumbass', 'jackass', 'dipshit', 'douche', 'twat', 'wanker', 'bollock', 'bellend', 'arsehole',
        'prick', 'skank', 'hooker', 'nazis', 'chink', 'spic', 'wetback', 'kike', 'tranny', 'molest', 'pedophil',
        'hentai', 'nude', 'naked', 'orgasm', 'blowjob', 'handjob', 'rimjob', 'cumshot', 'creampie', 'gangbang',
        'bdsm', 'fetish', 'erotic', 'stripper', 'caralh', 'buceta', 'viado', 'arrombad', 'foder', 'fodid',
        'filhodaput', 'vagabund', 'cuzao', 'punheta', 'piroca', 'xoxota', 'merda'
    },
    -- solo si el nombre entero, o un trozo separado por _ - o números, es exactamente esto (aparecen dentro de
    -- palabras inocentes; también las que al quitar letras repetidas quedan en un trozo corriente: 'perra' → 'pera')
    EXACT = {
        'forro', 'ass', 'culo', 'pito', 'pene', 'teta', 'tetas', 'ano', 'gay', 'homo', 'coño', 'pis', 'caca', 'semen', 'hoe',
        'hell', 'damn', 'kkk', 'pija', 'pajas', 'cul', 'tit', 'fap', 'sexy', 'gai', 'nig', 'fuc', 'mrd',
        'vrg', 'idiot', 'imbecil', 'estupid', 'tonto', 'gil', 'perra', 'gook', 'porra', 'ptm', 'csm'
    },
    -- nadie se hace pasar por el sistema
    RESERVED = {
        'admin', 'administrador', 'moderador', 'moderator', 'mod', 'server', 'servidor', 'system', 'sistema', 'host',
        'anthropic', 'staff', 'dev'
    },
    -- inocentes que contienen una vetada (se quitan del nombre antes de buscar)
    ALLOWED = {
        'cucumber', 'document', 'analog', 'analis', 'canal', 'banal', 'final', 'animal', 'manual', 'anual', 'sexto',
        'sexta', 'essex', 'cocktail', 'peacock', 'hancock', 'dickens', 'scunthorpe', 'grape', 'drape', 'scrape',
        'therapist', 'conocer', 'conocid', 'icono', 'cono_', 'mongolia', 'tarzan', 'forros', 'analia', 'analy', 'cumbre',
        'cumbia', 'cumple', 'circum', 'acumul', 'pedor', 'torpedo', 'pedal', 'expedic', 'cagarruta', 'recagad',
        'transex', 'pollac', 'polland', 'apollo', 'pollo', 'shittake', 'scunthorp', 'grapefruit', 'manscape',
        'dickinson', 'dickson', 'benedick', 'hitchcock', 'babcock', 'cockpit', 'cockroach', 'shuttlecock', 'assassin',
        'classic', 'passion', 'assist', 'bass', 'mass', 'pass', 'glass', 'grass', 'class', 'brass', 'sussex', 'essence',
        'sextant', 'sextet', 'title', 'titan', 'titular', 'petition', 'constitut', 'competit', 'spicy', 'spice', 'spike',
        'skankhunt', 'hellen', 'hello', 'shell', 'hellfire', 'michelle', 'damnation', 'analys', 'canalla', 'finalis',
        'marica_', 'putter', 'compute', 'reputa', 'disput', 'computad', 'deputad', 'cucaracha', 'escultor', 'pupil',
        'popular', 'repollo', 'pollito', 'pollera', 'vergel', 'divergen', 'convergen', 'perrito_', 'zorrillo', 'monaco',
        'cagliari', 'follaje', 'sapo', 'pinchit', 'pinchos', 'pinchazo', 'chinchilla', 'chingon_', 'mamut',
        'mamifer', 'gilberto', 'gilbert', 'tontodilo', 'glock'
    },
}
