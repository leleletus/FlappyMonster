-- tools/tests/boss_frames — dibuja una pelea de jefe real (clases del juego,
-- jugador quieto que esquiva las caídas) en una rejilla de fotogramas, para
-- revisar el aspecto sin jugar. Guarda <save>/boss_frames.png.
--
--   LEVEL=assets/levels/jefe_cangrejo.json love tools/tests/boss_frames
--   (STATES=chase,climb,... elige qué estados capturar; EVERY = s entre capturas)
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/Level'
local Entities = require 'src/world/Entities'
local BossZones = require 'src/world/BossZones'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local Particles = require 'src/fx/Particles'

local COLS, ROWS, CW, CH = 5, 6, 360, 240
function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    math.randomseed(3)
    local data = json.decode(love.filesystem.read(os.getenv('LEVEL') or 'assets/levels/jefe_cangrejo.json'))
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local z = boss.zone
    local pa = PlayerAdventure:new(z.x0 + 3 * TILE_PX, z.y1 - 60)
    level.players = { pa }
    local want = {}
    for s in (os.getenv('STATES') or 'intro,chase,windup,charge,climb,ceiling,aim,drop,stuck,getup,dying_kick,dying_shrink,dying_flee'):gmatch('[^,]+') do want[s] = true end
    local every = tonumber(os.getenv('EVERY') or 0.35)
    local canvas = love.graphics.newCanvas(COLS * CW, ROWS * CH)
    love.graphics.setCanvas(canvas); love.graphics.clear(0.1, 0.1, 0.12, 1); love.graphics.setCanvas()
    local n, lastShot, dt, t = 0, -1, 1 / 60, 0
    local hitDone = {}
    while n < COLS * ROWS and t < 200 do
        t = t + dt
        pa:update(dt, level)
        level.solidBodies = Entities.solidBodies(ents)
        ctrl:update(dt)
        for _, e in ipairs(ents) do if e.alive then e:update(dt, level) end end
        Entities.interactions.run(pa, ents, {})
        if pa.dying or not pa.alive then pa:respawn(); pa.hp = pa.hpMax end
        if boss.state == 'aim' and math.abs(pa.x - boss.x) < 3 * TILE_PX then
            pa.x = boss.x + ((boss.x - z.x0 > z.x1 - boss.x) and -5 or 5) * TILE_PX
        end
        -- golpea al jefe clavado (para ver el daño y, al final, la muerte)
        if boss.state == 'stuck' and boss.deadTimer > 1.0 and not hitDone[boss] then
            boss.hp = math.min(boss.hp, 1)
            boss:damage(1, 'stomp')
        end
        if want[boss.state] and t - lastShot >= every and boss.alive then
            lastShot = t
            local col, row = n % COLS, math.floor(n / COLS)
            love.graphics.setCanvas(canvas)
            love.graphics.setScissor(col * CW, row * CH, CW - 2, CH - 2)
            love.graphics.push()
            local camX = math.floor(boss.x - CW / 2 * 1.6)
            local camY = math.floor(boss.y - CH / 2 * 1.6)
            love.graphics.translate(col * CW, row * CH)
            love.graphics.scale(1 / 1.6, 1 / 1.6)
            love.graphics.clear(0.55, 0.7, 0.85, 1)
            level:render(camX, camY)
            pa:render(camX, camY)
            for _, e in ipairs(ents) do if e.alive then e:render(camX, camY) end end
            if os.getenv('BOXES') then       -- cajas reales: cuerpo (azul), contacto (amarillo), mata (rojo)
                local function box(b, r, g, bl)
                    love.graphics.setColor(r, g, bl, 0.9)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle('line', b.x - camX, b.y - camY, b.w, b.h)
                end
                box(boss:getOuterBounds(), 0.2, 0.4, 1)
                if boss.footBox then
                    for _, b in ipairs(boss._dbgBoxes or {}) do box(b, 1, 0.9, 0.1) end
                end
                for _, hb in ipairs(boss:getHazardBoxes() or {}) do box(hb, 1, 0.1, 0.1) end
                love.graphics.setLineWidth(1)
            end
            love.graphics.pop()
            love.graphics.setScissor()
            love.graphics.setColor(0, 0, 0, 0.7); love.graphics.rectangle('fill', col * CW, row * CH, CW - 2, 14)
            love.graphics.setColor(1, 1, 1, 1); love.graphics.setFont(FONT_SMALL)
            love.graphics.print(('%.1fs %s'):format(t, boss.state), col * CW + 3, row * CH + 2)
            love.graphics.setCanvas()
            n = n + 1
        end
        if not boss.alive then break end
    end
    canvas:newImageData():encode('png', 'boss_frames.png')
    print('capturas: ' .. n .. '  -> ' .. love.filesystem.getSaveDirectory() .. '/boss_frames.png')
    love.event.quit()
end
