-- src/story/RunOut.lua
-- EL FINAL DE UNA CARRERA, EN LA HISTORIA (solo un jugador; no es simulación compartida): un nivel de cámara
-- automática que en el modo historia NO acaba en la meta sino en una pequeña escena dentro del propio nivel, con
-- su música, que enlaza directamente con el nivel siguiente (su película y él). Hoy: "La Huida del Espejo" → la
-- película de la guarida → "Ruta del Espejo" (Worlds.LIST: `outros`).
--   · Al entrar: la META desaparece del nivel (aquí no se llega a ella).
--   · Cuando la cámara llega a la columna `col` (con el jugador vivo): la cámara se para, el HUD se desvanece y
--     entran las franjas de cine (level.cinema → BossHud.drawCinema / fadeHud); el jugador PIERDE el control: sigue
--     corriendo solo y salta (un salto con doble salto, otro después); el Espejo perseguidor deja de
--     atacar y lo sigue persiguiendo (mirrorchase: startOutro) hasta que los dos salen de la pantalla por la derecha.
--   · Entonces, fundido a negro y `done` → AdventureState llama a onFinish(result) con result.outro = true.
--   local ro = RunOut.new(state, { col = 182 });  ro:update(dt) (antes del jugador); ro:input() (el mando de mentira
--   mientras actúa, o nil); ro:render() (el fundido, encima de todo)
local RunOut = {}
RunOut.__index = RunOut

local FADE = 0.7           -- s del fundido a negro
local OUT = 90             -- px más allá del borde derecho para darlos por fuera
local MAX_T = 9            -- s como mucho (por si algo se atasca)

function RunOut.new(state, def)
    local ro = setmetatable({ state = state, col = def.col or 1, active = false, t = 0, fadeT = nil, done = false,
                              jumps = {} }, RunOut)
    -- la meta no está: en la historia esta carrera no acaba ahí
    local lv = state.level
    for r = 1, lv.tileH do
        for c = 1, lv.tileW do
            local d = lv:getDef(c, r)
            if d and d.trigger == 'finish' then lv:setTileRaw(c, r, 0) end
        end
    end
    return ro
end

-- El mando mientras actúa: siempre a la derecha; saltar cuando lo diga el guion
function RunOut:input()
    if not self.active then return nil end
    local me = self
    return setmetatable({
        pressed = function(k)
            if k == 'jump' and me.jumpNow then me.jumpNow = false; return true end
            return false
        end,
        down = function(k) return k == 'move_right' end,
    }, { __index = Input })
end

local function chasers(state)
    local out = {}
    for _, e in ipairs(state.enemies or {}) do
        if e.alive and e.def and e.def.name == 'mirrorchase' then out[#out + 1] = e end
    end
    return out
end

function RunOut:_start()
    local st, lv = self.state, self.state.level
    self.active, self.t = true, 0
    lv.cinema = true
    local a = lv.autoScroll
    if a then a.state = 'stop' end                         -- (sin paredes: se puede salir de cuadro)
    self.camX = st.camX                                    -- (y la cámara se queda AQUÍ: AdventureState:updateCamera)
    -- (sin invulnerabilidad: parpadearía; en ese último tramo llano no hay nada que le haga daño y el Espejo ya no pega)
    -- (el Espejo: si se había quedado atrás o estaba a medio teletransporte, entra por el borde izquierdo)
    for _, e in ipairs(chasers(st)) do if e.startOutro then e:startOutro(lv, st.camX - TILE_PX) end end
end

-- true cuando ha terminado (el estado llama a onFinish)
function RunOut:update(dt)
    if self.done then return true end
    local st = self.state
    local lv, p = st.level, st.player
    if not self.active then
        local a = lv.autoScroll
        local reached = a and (a.state == 'stop' or (a.state == 'run' and a.x >= (self.col - 1) * TILE_PX))
        if reached and not p.dying and not st.respawning and not st.dead then self:_start() end
        return false
    end
    self.t = self.t + dt
    -- el guion de saltos: uno con doble salto (en lo alto) y, más adelante, otro
    local t = self.t
    if not self.jumps[1] and t >= 0.45 and p.onGround then self.jumps[1] = true; self.jumpNow = true end
    if self.jumps[1] and not self.jumps[2] and not p.onGround and p.vy > -60 then self.jumps[2] = true; self.jumpNow = true end
    if not self.jumps[3] and t >= 2.0 and p.onGround then self.jumps[3] = true; self.jumpNow = true end
    -- ¿los dos fuera de cuadro?
    if not self.fadeT then
        local right = st.camX + WINDOW_W + OUT
        local gone = p.x > right
        for _, e in ipairs(chasers(st)) do if e.x < right then gone = false end end
        if gone or self.t > MAX_T then self.fadeT = 0 end
    else
        self.fadeT = self.fadeT + dt
        if self.fadeT >= FADE then self.done = true; return true end
    end
    return false
end

function RunOut:render()
    if not self.fadeT then return end
    love.graphics.setColor(0, 0, 0, math.min(1, self.fadeT / FADE))
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

return RunOut
