-- tools/tests/mashup_rules GAME=1 — el Mega Mashup en el JUEGO DE VERDAD (ver main.lua)
love.filesystem.load('game_main.lua')()
local gameLoad, gameUpdate, gameDraw = love.load, love.update, love.draw
local SPEED = tonumber(os.getenv('SPEED')) or 4          -- (pasos de juego por fotograma: va más deprisa)
local st, t, beatenAt, seen, bad, shots = nil, 0, {}, {}, 0, {}
local LIMIT = tonumber(os.getenv('SECS')) or 260

local function cm() return st and st.level and st.level.musicDirector end

function love.load(a)
    gameLoad(a)
    love.audio.setVolume(0)
    gStateMachine:change('adventure', { level = 'assets/levels/mashup_cangrejos.json' })
    st = gStateMachine:_top()
    st.player.hurt = function() return false end           -- (inmortal: se prueba el evento)
end

-- Al que pelea, al segundo de pelear, se le baja su vida del turno (vulnerable a la fuerza)
local function beatActive(d)
    local b
    if d.phase == 'crab' then b = d.main[d.ROLES[d.ci]]
    elseif d.phase == 'final' then b = d.active and d.fin[d.active] end
    if not b or b.eventFrozen or b.offstage or not b:isActive() then return end
    local key = d.phase .. (d.ci or 0) .. tostring(d.active)
    beatenAt[key] = beatenAt[key] or t
    if t - beatenAt[key] < 1 then return end
    local real = b.isVulnerable
    b.isVulnerable = function() return true end
    for _ = 1, 3 do b.inv = 0; b.lastHitter = st.player; b:damage(1, 'stomp') end
    b.isVulnerable = real
end

function love.update(dt)
    for _ = 1, SPEED do
        t = t + 1 / 60
        gameUpdate(1 / 60)
        local d = cm()
        if d then
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
        if (d and d.phase == 'outro' and t - (seen.outro or t) > 3) or t > LIMIT then
            local ok = d and d.phase == 'outro' and bad < 30
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
