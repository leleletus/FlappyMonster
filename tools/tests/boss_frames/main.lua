-- tools/tests/boss_frames — dibuja una pelea de jefe real (clases del juego,
-- jugador quieto que esquiva las caídas) en una rejilla de fotogramas, para
-- revisar el aspecto sin jugar. Guarda <save>/boss_frames.png.
--
--   LEVEL=assets/levels/guarida_cangrejo_rey.json love tools/tests/boss_frames
--   (STATES=chase,climb,... elige qué estados capturar; EVERY = s entre capturas;
--    FX=1: partículas del juego y reloj de dibujo = tiempo simulado (rugidos,
--    rayos, humo...); RAGE=1: el jefe empieza con poca vida = enfadado)
--   Rey Gummy: LEVEL=tools/levelgen/arenas/jefe_gummy.json FX=1 ZONE=1
--     STATES=intro,chase,flop_wind,flop_air,flop_land,dazed,phase_up,split,parts,dying_pop
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
require 'settings'
Sound = setmetatable({}, { __index = function() return function() end end })
local P = require 'src/network/Protocol'
Input = P.newInputStub()
local json = require 'libs/json'
local Level = require 'src/world/level/Level'
local Entities = require 'src/world/entities/Entities'
local BossZones = require 'src/world/systems/BossZones'
local PlayerAdventure = require 'src/player/PlayerAdventure'
local Particles = require 'src/fx/Particles'
local Entity = require 'src/world/entities/base/Entity'

local COLS, ROWS, CW, CH = 5, 6, 360, 240
local FX = os.getenv('FX') ~= nil
local simT = 0
if FX then love.timer.getTime = function() return simT end end   -- (el dibujo sigue la simulación)
function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    FONT_SMALL = love.graphics.newFont('assets/fonts/PressStart2P.ttf', 10)
    math.randomseed(3)
    local data = json.decode(love.filesystem.read(os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json'))
    local level = Level.fromData(data)
    local ents = {}
    for _, pl in ipairs(level.entities) do ents[#ents + 1] = Entities.create(pl) end
    level.liveEntities = ents
    local ctrl = BossZones.newController(level, ents)
    local boss
    for _, e in ipairs(ents) do if e.def.boss then boss = e end end
    local z = boss.zone
    if FX then Entity.fx = function(kind, x, y) Particles.emit(kind, x, y) end; Particles.setLevel(level) end
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
        simT = t
        if FX then Particles.update(dt) end
        if os.getenv('RAGE') and boss.hpMax and boss.hp > boss.hpMax * 0.4 then boss.hp = math.floor(boss.hpMax * 0.4) end
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
        -- Rey Gummy: ground pound al mareado y a los trozos (uno cada s) para verlo todo hasta el final
        if boss.def.name == 'megagummy' then
            if boss.state == 'dazed' and boss.deadTimer > 0.8 then boss:damage(2, 'pound') end
            if boss.state == 'parts' and boss.deadTimer > 1.5 and t - (hitDone.part or 0) > 1 then
                for i, p in ipairs(boss.parts) do
                    if p.st ~= 0 and p.inv <= 0 then hitDone.part = t; boss:hitPart(i, 2); break end
                end
            end
        end
        if want[boss.state] and t - lastShot >= every and (boss.alive or boss.def.name == 'megagummy') then
            lastShot = t
            local col, row = n % COLS, math.floor(n / COLS)
            love.graphics.setCanvas(canvas)
            love.graphics.setScissor(col * CW, row * CH, CW - 2, CH - 2)
            love.graphics.push()
            -- (ZONE=1: toda la zona del jefe en cada captura)
            local zoom = os.getenv('ZONE') and ((z.x1 - z.x0 + 4 * TILE_PX) / CW) or tonumber(os.getenv('ZOOM') or 1.6)
            local cx, cy = boss.x, boss.y
            if os.getenv('ZONE') then cx, cy = (z.x0 + z.x1) / 2, (z.y0 + z.y1) / 2 end
            local camX = math.floor(cx - CW / 2 * zoom)
            local camY = math.floor(cy - CH / 2 * zoom)
            love.graphics.translate(col * CW, row * CH)
            love.graphics.scale(1 / zoom, 1 / zoom)
            love.graphics.clear(0.55, 0.7, 0.85, 1)
            level:render(camX, camY)
            pa:render(camX, camY)
            for _, e in ipairs(ents) do if e.alive then e:render(camX, camY) end end
            if FX then Particles.render(camX, camY) end
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
