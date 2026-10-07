-- Bloque rompible: sólido, se rompe con un cabezazo desde abajo o con un
-- ground pound encima (nada más lo rompe). Textura de ladrillo marrón para
-- que se distinga de un bloque normal (assets/images/world/tiles/breakable.png).
return {
    id = 12, name = 'breakable', label = 'Bloque rompible', category = 'Terreno',
    collision = 'solid', material = 'stone', breakable = true,
    editorColor = { 0.55, 0.42, 0.30 },
    texture = { image = 'assets/images/world/tiles/breakable.png' },
    debris = { { 0.55, 0.4, 0.28 }, { 0.42, 0.29, 0.2 }, { 0.66, 0.5, 0.36 } },
}
