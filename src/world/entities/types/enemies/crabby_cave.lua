-- Crabby DE CUEVA (las cuevas normales; a oscuras sigue siendo cosa del Crabby lúgubre): el Crabby con OTRA forma —
-- caparazón redondo lila con un racimo de cristales, SIN pinzas —: assets/images/enemies/crabby_cave/
-- (tools/ui/make_crab_species.py --apply; versión A "Geoda" elegida por el usuario). Mismas reglas.
-- topperDy 2: la púa / el trampolín se apoyan en el caparazón, entre los cristales, no en su punta.
return require('src/world/entities/base/CrabVariant').defs('cave', 'Crabby de cueva', 'crabby_cave', 'crabbytramp_cave',
    'Crabby de las cuevas: caparazón con cristales, sin pinzas. Igual que el Crabby.', nil, { topperDy = 2 })
