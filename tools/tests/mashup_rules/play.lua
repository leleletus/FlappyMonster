-- tools/tests/mashup_rules GAME=1 — el Mega Mashup en el JUEGO DE VERDAD (ver main.lua)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw
local SPEED = tonumber(os.getenv('SPEED')) or 4          -- (pasos de juego por fotograma: va más deprisa)
-- LOOP=pieza (con SPEED=1, y CP=n para empezar en ese cangrejo): no se le baja la vida a nadie; se escucha esa pieza
-- dando la vuelta y se cuentan las RECOLOCACIONES de la música (saltos que se oyen): tiene que haber 0
local LOOP = os.getenv('LOOP')
local st, t, beatenAt, seen, bad, shots = nil, 0, {}, {}, 0, {}
local LIMIT = tonumber(os.getenv('SECS')) or 260
-- (DIFF=xtra…: esa dificultad. En el FINAL se cuentan los ataques de los que esperan al fondo — notas, carámbanos,
-- Crabbies — por segundo: más de 2 en un segundo es un fallo; el usuario vio cientos en Xtra extremo)
local haz = { sec = -1, n = 0, max = 0, lastId = 0 }
-- (SHOT_AT=s,s,…: capturas en esos segundos de juego, mashup_t<s>.png)
local shotAt = {}
for v in (os.getenv('SHOT_AT') or ''):gmatch('[%d%.]+') do shotAt[#shotAt + 1] = tonumber(v) end

local function cm() return st and st.level and st.level.musicDirector end

function love.load(a)
    -- (a más velocidad que el audio, el audio no puede mandar: el reloj del director va por su cuenta — en el juego,
    -- a tiempo real, sí manda: AdventureState → CM:syncAudio)
    if SPEED > 1 and not LOOP then require('src/world/entities/types/directors/crabmashup').class.syncAudio = nil end
    gameLoad(a)
    love.audio.setVolume(0)
    gStateMachine:change('adventure', { level = 'assets/levels/mashup_cangrejos.json', eventCheckpoint = tonumber(os.getenv('CP')),
                                        difficulty = os.getenv('DIFF') })
    st = gStateMachine:_top()
    st.player.hurt = function() return false end           -- (inmortal: se prueba el evento)
end

-- Al que pelea, al segundo de pelear, se le baja su vida del turno (vulnerable a la fuerza)
local function beatActive(d)
    if LOOP then return end
    local b
    if d.phase == 'crab' then b = d.main[d.ROLES[d.ci]]
    elseif d.phase == 'final' then b = d.active and d.fin[d.active] end
    if not b or b.eventFrozen or b.offstage or not b:isActive() then return end
    local key = d.phase .. (d.ci or 0) .. tostring(d.active)
    beatenAt[key] = beatenAt[key] or t
    if t - beatenAt[key] < 1 then return end
    local real = b.isVulnerable
    b.isVulnerable = function() return true end
    for _ = 1, 5 do b.inv = 0; b.lastHitter = st.player; b:damage(1, 'stomp') end
    b.isVulnerable = real
end

function love.update(dt)
    for _ = 1, LOOP and 1 or SPEED do
        local step = LOOP and math.min(dt, 1 / 20) or 1 / 60      -- (LOOP: a tiempo REAL, como el audio)
        t = t + step
        gameUpdate(step)
        local d = cm()
        if shotAt[1] and t >= shotAt[1] then shots[#shots + 1] = 't' .. table.remove(shotAt, 1) end
        if d then
            if d.phase == 'final' then
                local s = math.floor(t)
                if s ~= haz.sec then haz.sec, haz.n = s, 0 end
                local id = (d.noteId or 0) + (d.crabDrops or 0)
                if id > haz.lastId then haz.n = haz.n + (id - haz.lastId); haz.max = math.max(haz.max, haz.n) end
                haz.lastId = id
            end
            beatActive(d)
            if not seen[d.phase] then
                seen[d.phase] = t
                print(('%6.1fs fase %-6s pieza %-14s escena %s'):format(t, d.phase, tostring(d.piece), tostring(st.level.sceneIdx)))
                if os.getenv('SHOTS') then shots[#shots + 1] = d.phase end
            end
            -- la música que suena es la pieza del director (o la siguiente, si ya se adelantó)
            local name = Sound.musicPosition()
            if d.piece and name and name ~= Sound.ADAPTIVE and d.phase ~= 'wait' then bad = bad + 1 end
        end
        if LOOP and d and d.piece == LOOP then
            if not seen.loopAt then seen.loopAt, seen.seeks0, seen.lap0 = t, Sound.adaptiveSeeks or 0, d.lap end
            if d.lap > seen.lap0 and d.pos > 3 then
                local n = (Sound.adaptiveSeeks or 0) - seen.seeks0
                print(('bucle %s: una vuelta entera (%.1f s) con %d recolocaciones de la música'):format(LOOP, t - seen.loopAt, n))
                print(n == 0 and 'TODO OK' or 'FALLOS: la música se recolocó (salto)')
                love.event.quit(n == 0 and 0 or 1)
                return
            end
        end
        if (d and d.phase == 'outro' and t - (seen.outro or t) > 3) or t > LIMIT then
            local ok = d and d.phase == 'outro' and bad < 30 and haz.max <= 2
            print(('ataques de los del fondo en el final: como mucho %d en un segundo (máx. 2)'):format(haz.max))
            print(('fases: %s · música no adaptativa en %d pasos'):format(
                table.concat((function() local o = {} for _, p in ipairs({ 'intro', 'crab', 'seam', 'final', 'end', 'outro' }) do o[#o + 1] = p .. (seen[p] and '✓' or '✗') end return o end)(), ' '), bad))
            print(ok and 'TODO OK' or 'FALLOS: no llegó a la salida')
            love.event.quit(ok and 0 or 1)
            return
        end
    end
end

function love.draw()
    gameDraw()
    if #shots > 0 then
        local name = 'mashup_' .. table.remove(shots, 1) .. '.png'
        love.graphics.captureScreenshot(name)
        print('  captura ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
    end
end
