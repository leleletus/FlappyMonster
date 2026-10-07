-- Crabby DE LAVA (isla del volcán): el Crabby con OTRA forma — roca ancha y baja con grietas y ojos de brasa, y
-- pinzas con el filo al rojo —: assets/images/enemies/crabby_lava/ (tools/ui/make_crab_species.py --apply). Mismas reglas.
return require('src/world/entities/base/CrabVariant').defs('lava', 'Crabby de lava', 'crabby_lava', 'crabbytramp_lava',
    'Crabby de roca volcánica para la isla del volcán: grietas encendidas y pinzas al rojo. Igual que el Crabby.',
    nil, { darkEdge = { 1, 0.8, 0.55, 0.9 } })      -- (roca oscura: en lo oscuro lleva un filo fino; EntityTypes / Silhouette)
