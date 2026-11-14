-- Bloques BEEP de cristal (rosa / cian; docs/design/beep-blocks.md): se cambian SOLOS cada `period` s de música
-- (4 s = una frase de la canción) con el reloj de compás del nivel (src/world/systems/BeatClock.lua), sin activador.
-- Mientras el rosa es sólido, el cian se atraviesa, y al revés. La base es la de los Bloques ON/OFF (`switchBlock`,
-- Level:updateSwitchBlocks: el cambio de tile, el evento online, esperar a que nadie esté dentro); `beat = true` dice
-- que su estado lo decide el reloj y no un activador. Arte: tools/art/world/make_beep_blocks.py.
local function def(id, name, label, active, other, color, cb)
    return {
        id = id, name = name, cbSymbol = cb, label = label, category = 'Mecanismos',
        collision = active and 'solid' or 'none', material = active and 'stone' or 'default',
        enemySolid = (not active) and false or nil, editorHide = (not active) or nil,
        switchBlock = { kind = (cb == 'pink') and 'beep_pink' or 'beep_cyan', active = active, other = other, beat = true },
        editorColor = color,
        texture = { image = 'assets/images/world/tiles/' .. name:gsub('block', '') .. '.png' },
        -- el AVISO de cada beep (solo dibujo): una mezcla de los dos estados — el sólido sigue pareciendo sólido y el
        -- hueco, hueco — (el usuario, 2026-11-14; antes se dibujaba el otro estado)
        warnLook = { name = name .. '_warn', cbSymbol = cb,
                     texture = { image = 'assets/images/world/tiles/' .. name:gsub('block', '') .. '_warn.png' } },
        debris = active and { color, { color[1] * 0.6, color[2] * 0.6, color[3] * 0.6 }, { 1, 1, 1 } } or nil,
    }
end

local PINK, CYAN = { 0.96, 0.5, 0.75 }, { 0.38, 0.87, 0.94 }
return {
    def(45, 'beepblock_pink',   'Bloque de cristal rosa',             true,  'beepblock_pink_x', PINK, 'pink'),
    def(46, 'beepblock_pink_x', 'Bloque de cristal rosa (inactivo)',  false, 'beepblock_pink',   PINK, 'pink'),
    def(47, 'beepblock_cyan',   'Bloque de cristal cian',             true,  'beepblock_cyan_x', CYAN, 'cyan'),
    def(48, 'beepblock_cyan_x', 'Bloque de cristal cian (inactivo)',  false, 'beepblock_cyan',   CYAN, 'cyan'),
}
