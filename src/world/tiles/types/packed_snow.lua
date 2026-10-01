-- Nieve prensada: bloque ROMPIBLE (cabezazo desde abajo o ground pound encima),
-- como el bloque rompible pero de nieve. La Gran Bola de Nieve tapa con él los
-- Activadores de su arena (fase 3). Solo frena a los jugadores (enemySolid = false). Textura: assets/images/tiles/packed_snow.png
-- (tools/ui/make_snowboss_sprites.py).
return {
    id = 37, name = 'packed_snow', label = 'Nieve prensada (rompible)', category = 'Terreno',
    collision = 'solid', material = 'snow', breakable = true,
    enemySolid = false,        -- (solo para los jugadores: la Bola de Nieve pasa rodando)
    editorColor = { 0.78, 0.84, 0.96 },
    texture = { image = 'assets/images/tiles/packed_snow.png' },
    debris = { { 0.95, 0.97, 1 }, { 0.8, 0.86, 0.96 }, { 0.62, 0.7, 0.86 } },
}
