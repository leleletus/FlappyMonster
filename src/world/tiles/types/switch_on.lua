-- Bloque ON/OFF (encendido). Sólido; un cabezazo desde abajo o un ground pound
-- encima lo cambia a su otro estado (`toggle`: el nombre del tile en que se
-- convierte). De momento no activa nada: en el futuro se enlazará con objetos
-- activables. Texturas: assets/images/tiles/switch_on.png / switch_off.png.
return {
    id = 13, name = 'switch_on', label = 'Bloque ON', category = 'Mecanismos',
    collision = 'solid', material = 'stone', toggle = 'switch_off',
    editorColor = { 0.25, 0.75, 0.35 },
    texture = { image = 'assets/images/tiles/switch_on.png' },
}
