-- Activador ON/OFF (apagado): ver switch_on.lua
return {
    id = 14, name = 'switch_off', label = 'Activador OFF', category = 'Mecanismos',
    collision = 'solid', material = 'stone', toggle = 'switch_on',
    editorColor = { 0.60, 0.20, 0.22 },
    texture = { image = 'assets/images/world/tiles/switch_off.png' },
    debris = { { 0.8, 0.25, 0.25 }, { 0.58, 0.16, 0.16 }, { 0.95, 0.9, 0.9 } },
}
