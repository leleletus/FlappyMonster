-- tools/tests/sp_boss — pelea de jefe en el modo UN JUGADOR REAL (AdventureState,
-- el mismo camino que "Probar" del editor). El jugador entra andando en la
-- arena y esquiva a medias; se registran los estados del jefe, los súbditos
-- activos y los bloques de jefe tal como los ve AdventureState.
--
--   LEVEL=assets/levels/guarida_cangrejo_rey.json love tools/tests/sp_boss
io.stdout:setvbuf('no')
love.filesystem.setSymlinksEnabled(true)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate = love.load, love.update
local P = require 'src/network/Protocol'
local stub = P.newInputStub()
local t, st, last = 0, nil, {}
local SECS = tonumber(os.getenv('SECS')) or 60
function love.load(a)
    gameLoad(a); love.audio.setVolume(0)
    gStateMachine:change('adventure', { level = os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json' })
    st = gStateMachine:_top()
end
function love.update(dt)
    t = t + dt
    local pa = st.player
    local boss
    for _, e in ipairs(st.enemies) do if e.def.boss then boss = e end end
    -- (empieza dentro de la arena: los niveles definitivos tienen un tramo antes)
    if boss and boss.zone and pa and not last.placed then
        last.placed = true
        pa.x, pa.y = boss.zone.x0 + 2 * TILE_PX, boss.zone.y1 - 60
    end
    local s = stub.state
    s.left, s.right, s.jump, s.jump_pressed = false, false, false, false
    if boss and boss.zone and pa then
        local z = boss.zone
        if pa.x < z.x0 + 3 * TILE_PX then s.right = true
        elseif boss.state ~= 'dormant' then
            local d = pa.x - boss.x
            if math.abs(d) < 4 * TILE_PX then s.right, s.left = d > 0, d <= 0 end
        end
    end
    Input = setmetatable({ pressed = stub.pressed, down = stub.down }, { __index = package.loaded['input'] })
    gameUpdate(dt)
    Input = package.loaded['input']
    -- (CAMFRAC=0.6: cámara con decimales, como al deslizarse; para ver rendijas
    -- de medio píxel entre bloques en las capturas)
    if os.getenv('CAMFRAC') and st.camY then
        local f = tonumber(os.getenv('CAMFRAC'))
        st.camX, st.camY = math.floor(st.camX) + f, math.floor(st.camY) + f
    end
    if boss then
        local nm, walls = 0, {}
        for _, e in ipairs(st.enemies) do
            if e.summonOf and e.alive then nm = nm + 1 end
            if e.def.name == 'bosswall' then walls[#walls + 1] = e.state end
        end
        local line = ('jefe=%s súbditos=%d bloques=%s'):format(boss.state, nm, table.concat(walls, ','))
        if line ~= last.line then last.line = line; print(('%6.1fs %s'):format(t, line)) end
    end
    -- golpes al jugador: tiempo desde el anterior (nunca debe ser < la protección)
    if pa then
        if last.hp and pa.hp < last.hp and not pa.dying then
            print(('%6.1fs   golpe al jugador (vida %d, %.2f s desde el anterior, jefe=%s)'):format(t, pa.hp, t - (last.hitT or -99), boss and boss.state or '?'))
            last.minGap = math.min(last.minGap or 99, t - (last.hitT or -99))
            if os.getenv('SHOTS') and not last.shotAt then last.shotAt = t + 0.25; last.shots = 0 end
            last.hitT = t
        end
        if pa.dying and not last.dead then print(('%6.1fs   jugador MUERE (jefe=%s)'):format(t, boss and boss.state or '?')) end
        last.dead = pa.dying
        last.hp = pa.hp
    end
    -- (SHOTS=1: 3 capturas seguidas tras el primer golpe, para ver el parpadeo)
    if last.shotAt and t >= last.shotAt and last.shots < 3 then
        last.shots = last.shots + 1
        last.shotAt = t + 0.021
        love.graphics.captureScreenshot(function(img) img:encode('png', 'hit_' .. last.shots .. '.png') end)
        print(('  captura %d: invT=%.2f alfa=%.2f'):format(last.shots, pa.invT or 0,
            require('src/entities/PlayerAdventure').invulnAlpha(pa.invT or 0)))
    end
    -- (INTRO_SHOTS=1: capturas de la entrada del jefe cada 0.6 s → intro_N.png:
    -- franjas de cine con el nombre, cámara centrada en el jefe)
    if os.getenv('INTRO_SHOTS') and boss and boss.zone and boss.zone.state == 'intro' then
        last.introN = last.introN or 0
        if t >= (last.introAt or 0) and last.introN < 6 then
            last.introN, last.introAt = last.introN + 1, t + 0.6
            local n = last.introN
            love.graphics.captureScreenshot(function(img) img:encode('png', 'intro_' .. n .. '.png') end)
            print(('  captura entrada %d (jefe=%s)'):format(n, boss.state))
        end
    end
    -- (FIGHT_SHOT=1: una captura 1.5 s después de empezar la pelea → fight.png:
    -- bloques de jefe ya sólidos, uniones con el suelo)
    if os.getenv('FIGHT_SHOT') and boss and boss.zone and boss.zone.state == 'fight' then
        last.fightAt = last.fightAt or t
        if not last.fightShot and t - last.fightAt >= 1.5 then
            last.fightShot = true
            love.graphics.captureScreenshot(function(img) img:encode('png', 'fight.png') end)
            print('  captura de la pelea: fight.png')
        end
    end
    if t > SECS then
        print(('Menor tiempo entre dos golpes: %.2f s'):format(last.minGap or -1))
        love.event.quit()
    end
end
