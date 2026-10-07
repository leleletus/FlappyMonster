-- Bloque ON / Bloque OFF: dependen de un Activador ON/OFF (switch_on/off).
-- Un Bloque ON está ACTIVO (sólido, textura llena) cuando su activador está en
-- ON; un Bloque OFF, cuando está en OFF. Inactivo = se atraviesa (textura de
-- contorno). Cada uno tiene dos tiles (activo / inactivo, `switchBlock`); el
-- nivel cambia uno por otro cuando cambia su activador (Level:updateSwitchBlocks,
-- por la misma vía que los bloques rotos: evento `tile` online). Su activador:
-- el conectado en el editor (nivel "blockLinks") o, si no tiene, el más cercano.
return {
    {
        id = 18, name = 'switchblock_on', label = 'Bloque ON', category = 'Mecanismos',
        collision = 'solid', material = 'stone',
        switchBlock = { kind = 'on', active = true, other = 'switchblock_on_x' },
        editorColor = { 0.05, 0.2, 0.75 },
        texture = { image = 'assets/images/world/tiles/activated_on_block.png' },
        debris = { { 0.05, 0.2, 0.75 }, { 0.02, 0.12, 0.5 }, { 0.5, 0.6, 1.0 } },
    },
    {
        id = 19, name = 'switchblock_on_x', label = 'Bloque ON (inactivo)', category = 'Mecanismos',
        collision = 'none', material = 'default', enemySolid = false, editorHide = true,
        switchBlock = { kind = 'on', active = false, other = 'switchblock_on' },
        editorColor = { 0.05, 0.2, 0.75 },
        texture = { image = 'assets/images/world/tiles/deactivated_on_block.png' },
    },
    {
        id = 27, name = 'switchblock_off', label = 'Bloque OFF', category = 'Mecanismos',
        collision = 'solid', material = 'stone',
        switchBlock = { kind = 'off', active = true, other = 'switchblock_off_x' },
        editorColor = { 0.6, 0.02, 0.02 },
        texture = { image = 'assets/images/world/tiles/activated_off_block.png' },
        debris = { { 0.6, 0.02, 0.02 }, { 0.4, 0.0, 0.0 }, { 1.0, 0.5, 0.5 } },
    },
    {
        id = 28, name = 'switchblock_off_x', label = 'Bloque OFF (inactivo)', category = 'Mecanismos',
        collision = 'none', material = 'default', enemySolid = false, editorHide = true,
        switchBlock = { kind = 'off', active = false, other = 'switchblock_off' },
        editorColor = { 0.6, 0.02, 0.02 },
        texture = { image = 'assets/images/world/tiles/deactivated_off_block.png' },
    },
}
