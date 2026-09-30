-- tools/tests/touch_layout — controles táctiles (src/ui/TouchControls.lua) en
-- pantallas de móvil y tableta de distintos tamaños y proporciones:
--   dentro     la cruceta y el botón de salto caben enteros en la pantalla
--   separados  no se tocan entre sí
--   hud        no pisan el HUD de arriba (tiempo/puntos, vidas, pausa) ni la
--              antena de ping (abajo en el centro con controles táctiles)
--   grandes    la cruceta mide ≥ 24 % del alto de la pantalla y el salto ≥ 17 %
--   zonas      un dedo en el centro de cada brazo / del botón da esa acción, y
--              una diagonal abajo-izq da agachado + izquierda
-- Guarda <save>/touch_layout.png: una rejilla con cada pantalla (bandas negras,
-- área del juego, HUD de referencia y los controles de verdad).
--
--   tools/tests/run.sh touch_layout
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Input = { isMobile = true, lastDevice = 'touch', VirtualPad = { down = {}, pressed = {} } }
local TC = require 'src/ui/TouchControls'
local PingIcon = require 'src/ui/PingIcon'

-- (ancho, alto) en píxeles de pantalla
local SCREENS = {
    { 2400, 1080, '20:9' }, { 2340, 1080, '19.5:9' }, { 2160, 1080, '18:9' },
    { 1920, 1080, '16:9' }, { 1280, 720, '16:9 pequeño' }, { 1600, 720, '20:9 pequeño' },
    { 2048, 1536, 'tableta 4:3' }, { 2560, 1600, 'tableta 16:10' },
}

local fails = 0
local function check(name, ok, msg)
    print(('%-10s %s  %s'):format(name, ok and 'OK   ' or 'FALLA', msg))
    if not ok then fails = fails + 1 end
end
local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end

-- Rectángulos del HUD (lógicos 1280x720) que no se pueden tapar
local function hudRects()
    return {
        { x = 16, y = 12, w = 520, h = 170, n = 'tiempo/puntos' },
        { x = WINDOW_W - 280, y = 12, w = 264, h = 80, n = 'vidas' },
        { x = WINDOW_W - 76, y = 76, w = 56, h = 56, n = 'pausa' },
        { x = WINDOW_W / 2 - 110, y = WINDOW_H - 60, w = 220, h = 50, n = 'ping' },
    }
end

function love.load()
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    local ok = { dentro = true, separados = true, hud = true, grandes = true, zonas = true }
    local notes = {}
    local COLS, CW, CH = 4, 480, 300
    local canvas = love.graphics.newCanvas(COLS * CW, math.ceil(#SCREENS / COLS) * CH)
    love.graphics.setCanvas(canvas); love.graphics.clear(0.1, 0.1, 0.12, 1); love.graphics.setCanvas()
    for i, S in ipairs(SCREENS) do
        local sw, sh = S[1], S[2]
        local L = TC.layout(sw, sh)
        local pad = { x = L.padX - L.padW / 2, y = L.padY - L.padW / 2, w = L.padW, h = L.padW }
        local jmp = { x = L.jumpX - L.jumpW / 2, y = L.jumpY - L.jumpW / 2, w = L.jumpW, h = L.jumpW }
        local gx, gy, gw, gh, gs = TC.gameRect(sw, sh)
        local function toScreen(r) return { x = gx + r.x * gs, y = gy + r.y * gs, w = r.w * gs, h = r.h * gs, n = r.n } end
        -- dentro
        for _, r in ipairs({ pad, jmp }) do
            if r.x < 0 or r.y < 0 or r.x + r.w > sw or r.y + r.h > sh then ok.dentro = false; notes[#notes + 1] = S[3] .. ' fuera' end
        end
        if overlap(pad, jmp) then ok.separados = false; notes[#notes + 1] = S[3] .. ' se tocan' end
        for _, h in ipairs(hudRects()) do
            local hs = toScreen(h)
            for _, r in ipairs({ pad, jmp }) do
                if overlap(r, hs) then ok.hud = false; notes[#notes + 1] = S[3] .. ' pisa ' .. h.n end
            end
        end
        if L.padW < 0.24 * sh or L.jumpW < 0.17 * sh then ok.grandes = false; notes[#notes + 1] = S[3] .. ' pequeños' end
        -- zonas: dedos en los brazos, el botón y la diagonal
        local armOff = L.padW * 0.36
        local function rd(x, y) return TC.read(L, { { x, y } }) end
        local a, b, c, d, e = rd(L.padX - armOff, L.padY), rd(L.padX + armOff, L.padY), rd(L.padX, L.padY + armOff),
                              rd(L.jumpX, L.jumpY), rd(L.padX - armOff * 0.8, L.padY + armOff * 0.8)
        if not (a.l and not a.d and b.r and c.d and not c.l and d.j and e.d and e.l) then
            ok.zonas = false; notes[#notes + 1] = S[3] .. ' zonas'
        end
        -- dibujo (reducido) para la rejilla
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local k = math.min((CW - 10) / sw, (CH - 24) / sh)
        love.graphics.setCanvas(canvas)
        love.graphics.push()
        love.graphics.translate(col * CW + 5, row * CH + 20)
        love.graphics.scale(k, k)
        love.graphics.setColor(0, 0, 0, 1); love.graphics.rectangle('fill', 0, 0, sw, sh)
        love.graphics.setColor(0.45, 0.62, 0.8, 1); love.graphics.rectangle('fill', gx, gy, gw, gh)
        for _, h in ipairs(hudRects()) do
            local hs = toScreen(h)
            love.graphics.setColor(1, 0.9, 0.2, 0.5); love.graphics.rectangle('fill', hs.x, hs.y, hs.w, hs.h)
        end
        TC.draw(L, { l = false, r = false, d = (i % 2 == 0), j = (i % 3 == 0) })
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.print(('%s %dx%d'):format(S[3], sw, sh), col * CW + 5, row * CH + 4)
        love.graphics.setCanvas()
    end
    check('dentro', ok.dentro, #SCREENS .. ' pantallas')
    check('separados', ok.separados, 'cruceta y salto no se tocan')
    check('hud', ok.hud, 'no pisan tiempo/puntos, vidas, pausa ni ping' .. (#notes > 0 and (': ' .. table.concat(notes, ', ')) or ''))
    check('grandes', ok.grandes, 'cruceta ≥ 24 % del alto, salto ≥ 17 %')
    check('zonas', ok.zonas, 'brazos, botón y diagonal abajo-izq')
    canvas:newImageData():encode('png', 'touch_layout.png')
    print('captura: ' .. love.filesystem.getSaveDirectory() .. '/touch_layout.png')
    print(fails == 0 and 'TODO OK' or (fails .. ' FALLOS'))
    love.event.quit(fails == 0 and 0 or 1)
end
