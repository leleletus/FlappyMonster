-- Activador ON/OFF (encendido). Sólido; un cabezazo desde abajo o un ground
-- pound encima lo cambia a su otro estado (`toggle`: el nombre del tile en que
-- se convierte). Enciende/apaga los objetos conectados (inundaciones...) y los
-- Bloques ON/OFF que dependen de él (switchblock_*.lua). Texturas:
-- assets/images/world/tiles/switch_on.png / switch_off.png.
return {
    id = 13, name = 'switch_on', label = 'Activador ON', category = 'Mecanismos',
    collision = 'solid', material = 'stone', toggle = 'switch_off',
    editorColor = { 0.1, 0.35, 0.95 },
    texture = { image = 'assets/images/world/tiles/switch_on.png' },
    debris = { { 0.1, 0.35, 0.95 }, { 0.05, 0.2, 0.7 }, { 0.9, 0.93, 1.0 } },
}
