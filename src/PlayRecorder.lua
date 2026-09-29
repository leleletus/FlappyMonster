-- src/PlayRecorder.lua — grabación de partidas de UN JUGADOR para analizarlas
-- (herramienta de desarrollo). Solo se activa lanzando el juego con la
-- variable FM_RECORD=1:
--
--     FM_RECORD=1 love .
--
-- Escribe en la carpeta de guardado (Linux: ~/.local/share/love/FlappyMonster/)
-- recordings/<nivel>_<fecha>.csv con una fila cada 0,1 s y una por evento:
--   t (s), evento, col, fila, x, y, vida, vidas, en_agua, aire_usado (s), detalle
-- Eventos: pos (muestra), daño (causa), muerte (causa), reaparece, checkpoint,
-- meta, fin. Causa probable: ahogado / pincho / pez / enemigo / otro.
local PlayRecorder = {}
PlayRecorder.__index = PlayRecorder

local SAMPLE = 0.1

function PlayRecorder.enabled()
    local v = os.getenv('FM_RECORD')
    return v ~= nil and v ~= '' and v ~= '0'
end

-- levelName: el nombre del nivel (el de "Probar" en el editor es siempre
-- editor_playtest.json, así que el archivo se llama como el nivel)
function PlayRecorder.new(levelPath, levelName)
    local name = (levelName and levelName ~= '' and levelName ~= '?') and levelName
                 or (levelPath or 'nivel'):match('([^/]+)%.json$') or 'nivel'
    name = name:lower():gsub('[^%w]+', '_')
    love.filesystem.createDirectory('recordings')
    local file = ('recordings/%s_%s.csv'):format(name, os.date('%Y%m%d_%H%M%S'))
    local self = setmetatable({ file = file, t = 0, acc = 0, lines = {}, flushT = 0 }, PlayRecorder)
    love.filesystem.write(file, '# ' .. tostring(levelName or '') .. ' (' .. tostring(levelPath) .. ')\n' ..
        't,evento,col,fila,x,y,vida,vidas,en_agua,aire_usado,detalle\n')
    print('[PlayRecorder] grabando en ' .. love.filesystem.getSaveDirectory() .. '/' .. file)
    return self
end

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

-- ¿Qué le ha hecho daño? (lo más probable, mirando lo que toca ahora)
local function cause(st)
    local pa, level = st.player, st.level
    if pa.drownPhase == 'dead' or pa.drownDead then return 'ahogado' end
    local b = pa:getOuterBounds()
    local m = 6
    local box = { x = b.x - m, y = b.y - m, w = b.w + 2 * m, h = b.h + 2 * m }
    if level.getSpikesInBox and #level:getSpikesInBox(box.x, box.y, box.w, box.h) > 0 then return 'pincho' end
    for _, e in ipairs(st.enemies or {}) do
        if e.alive then
            for _, hb in ipairs(e:getHazardBoxes() or {}) do
                if overlap(box, hb) then return e.def and e.def.name == 'pufferfish' and 'pez' or ('peligro:' .. e.def.name) end
            end
            if not e:isBodyDisabled() and overlap(box, e:getOuterBounds()) then return 'enemigo:' .. e.def.name end
        end
    end
    return 'otro'
end

function PlayRecorder:row(ev, st, detail)
    local pa = st.player
    local T = TILE_PX
    self.lines[#self.lines + 1] = ('%.2f,%s,%d,%d,%d,%d,%d,%d,%d,%.1f,%s'):format(self.t, ev,
        math.floor(pa.x / T) + 1, math.floor(pa.y / T) + 1, pa.x, pa.y, pa.hp or 0, pa.lives or 0,
        pa.inWater and 1 or 0, pa.drownTimer or 0, detail or '')
end

function PlayRecorder:flush()
    if #self.lines == 0 then return end
    love.filesystem.append(self.file, table.concat(self.lines, '\n') .. '\n')
    self.lines = {}
end

-- Una vez por fotograma, después de actualizar el juego
function PlayRecorder:step(dt, st)
    local pa = st.player
    self.t = self.t + dt
    -- Eventos
    if pa.dying and not self.wasDying then self:row('muerte', st, cause(st)); self:flush() end
    if not pa.dying and self.wasDying then self:row('reaparece', st) end
    if self.hp and pa.hp < self.hp and not pa.dying then self:row('daño', st, cause(st)) end
    if st.checkpoint and st.checkpoint ~= self.cp then self:row('checkpoint', st) end
    local b = pa:getOuterBounds()
    local atFinish = st.level:triggerInBox(b.x, b.y, b.w, b.h, 'finish')
    if atFinish and not self.finished then self:row('meta', st); self:flush() end
    self.finished = self.finished or atFinish
    self.wasDying, self.hp, self.cp = pa.dying, pa.hp, st.checkpoint
    -- Muestras
    self.acc = self.acc + dt
    if self.acc >= SAMPLE then
        self.acc = self.acc - SAMPLE
        self:row('pos', st)
    end
    self.flushT = self.flushT + dt
    if self.flushT >= 0.5 then self.flushT = 0; self:flush() end      -- (cerrar la ventana no pasa por exit)
end

function PlayRecorder:finish(st)
    if st and st.player then self:row('fin', st) end
    self:flush()
end

return PlayRecorder
