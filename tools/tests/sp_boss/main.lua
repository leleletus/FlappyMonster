-- tools/tests/sp_boss — pelea de jefe en el modo UN JUGADOR REAL (AdventureState,
-- el mismo camino que "Probar" del editor). El jugador entra andando en la
-- arena y esquiva a medias; se registran los estados del jefe, los súbditos
-- activos y los bloques de jefe tal como los ve AdventureState.
--
-- RETRY=1: en plena pelea (música del jefe sonando) pierde la última vida y
-- elige "Reintentar": todo debe empezar de cero (música del nivel desde el
-- principio, zona de jefe esperando, bloques de jefe ocultos, tiles como en el
-- archivo, jefe con toda la vida). RETRY=level: igual pero muriendo FUERA de la
-- pelea (la misma pista del nivel sonando: antes seguía donde iba al reintentar).
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
    -- (MOBILE=1: como en un móvil, con los controles táctiles a la vista)
    if os.getenv('MOBILE') then package.loaded['input'].isMobile = true; package.loaded['input'].lastDevice = 'touch' end
    gStateMachine:change('adventure', { level = os.getenv('LEVEL') or 'assets/levels/guarida_cangrejo_rey.json', difficulty = os.getenv('DIFF') })
    st = gStateMachine:_top()
end
function love.update(dt)
    t = t + dt
    if os.getenv('MOBILE') then package.loaded['input'].lastDevice = 'touch' end   -- (la ventana de prueba recibe ratón)
    local pa = st.player
    local boss
    for _, e in ipairs(st.enemies) do if e.def.boss then boss = e end end
    -- (empieza dentro de la arena: los niveles definitivos tienen un tramo antes)
    if boss and boss.zone and pa and not last.placed and os.getenv('RETRY') ~= 'level' then
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
            require('src/player/PlayerAdventure').invulnAlpha(pa.invT or 0)))
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
    if os.getenv('RETRY') and st then
        local z = boss and boss.zone
        local outside = os.getenv('RETRY') == 'level'
        if not last.retry and z and (outside or z.state == 'fight') and pa and not pa.dying then
            last.fightAt2 = last.fightAt2 or t
            if t - last.fightAt2 > (outside and 6 or 3) then
                -- (antes de morir: rompe un bloque rompible si lo hay, para ver que vuelve)
                last.retry = { music = Sound.getLevelMusic() }
                pa.lives = 1
                pa:die(nil, true)
            end
        elseif last.retry and not last.retry.done and st.dead and st.deadTimer > 1 then
            last.retry.done = t
            gStateMachine:change('adventure', { level = st.levelPath, returnTo = st.returnTo })   -- (= "Reintentar")
            st = gStateMachine:_top()
        elseif last.retry and last.retry.done and t - last.retry.done > 0.5 then
            local b2
            for _, e in ipairs(st.enemies) do if e.def.boss then b2 = e end end
            local walls = 0
            for _, e in ipairs(st.enemies) do if e.def.name == 'bosswall' and e.state ~= 'hidden' then walls = walls + 1 end end
            local name, pos = Sound.musicPosition()
            local fresh = require('src/world/level/Level').new(st.levelPath)
            local same = true
            for r = 1, fresh.tileH do for c = 1, fresh.tileW do
                if fresh:getRaw(c, r) ~= st.level:getRaw(c, r) then same = false end
            end end
            local ok = (last.retry.music ~= nil or os.getenv('RETRY') == 'level') and Sound.getLevelMusic() == nil and name == Sound.resolveMusic('level')
                       and pos and pos < 1.0 and b2 and b2.zone.state ~= 'fight' and b2.hp == b2.hpMax and walls == 0 and same
            print(('reintentar %s  música antes=%s ahora=%s pos=%.2f s · zona=%s jefe hp=%s/%s · bloques de jefe visibles=%d · tiles como el archivo=%s'):format(
                ok and 'OK   ' or 'FALLA', tostring(last.retry.music), tostring(name), pos or -1, b2 and b2.zone.state or '?',
                b2 and b2.hp or '?', b2 and b2.hpMax or '?', walls, tostring(same)))
            love.event.quit(ok and 0 or 1)
            return
        end
    end
    -- (DIFF=xtra: aliados — cuánto rato se solapan y cuánto atacan a la vez)
    if st and st.enemies and boss and boss.zone and boss.zone.state == 'fight' then
        local list = {}
        for _, e in ipairs(st.enemies) do if e.def.boss and e.alive and e:isActive() then list[#list + 1] = e end end
        if #list >= 2 then
            last.duoT = (last.duoT or 0) + dt
            local a, b = list[1]:getOuterBounds(), list[2]:getOuterBounds()
            local ov = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
            local ovy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
            if ov > 8 and ovy > 8 then last.overT = (last.overT or 0) + dt end
            if list[1]:isAttacking() and list[2]:isAttacking() then last.bothT = (last.bothT or 0) + dt end
            if list[1]:isAttacking() or list[2]:isAttacking() then last.anyT = (last.anyT or 0) + dt end
        end
    end
    if t > SECS then
        if last.duoT then
            -- los aliados se turnan: nunca atacan los dos a la vez (Boss:mayAttack); se atraviesan, no chocan
            local ok = (last.bothT or 0) <= 0.5      -- (un instante: la bola sale del agua de un salto sin esperar)
            print(('Aliados %s %.1f s juntos · atacando alguno %.1f s, los dos a la vez %.1f s (se atraviesan: solapados %.1f s)'):format(
                ok and 'OK   ' or 'FALLA', last.duoT, last.anyT or 0, last.bothT or 0, last.overT or 0))
            if not ok then love.event.quit(1); return end
        end
        print(('Menor tiempo entre dos golpes: %.2f s'):format(last.minGap or -1))
        -- (DIFF=xtra: dos jefes en la arena; los dos pelean)
        local list, sts = {}, {}
        for _, e in ipairs(st.enemies or {}) do if e.def.boss then list[#list + 1] = e; sts[#sts + 1] = e.state .. ' ' .. tostring(e.hp) .. '/' .. tostring(e.hpMax) end end
        print(('Jefes: %d (%s) · zona %s · dificultad %s'):format(#list, table.concat(sts, ', '),
            boss and boss.zone and boss.zone.state or '?', tostring(st.level and st.level.difficulty)))
        love.event.quit()
    end
end
