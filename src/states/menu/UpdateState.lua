-- src/states/menu/UpdateState.lua
-- Primera pantalla del juego: busca una versión nueva en el servidor y, si la
-- hay, la descarga (src/update/Updater.lua) y reinicia el juego. Sin red o si
-- ya está al día, pasa al título enseguida (el aviso "Buscando..." solo sale
-- si tarda). Se puede saltar con [atrás]. También se llega desde el login
-- online cuando el servidor rechaza la versión (args.after = 'online_login').

local BaseState = require 'src/core/BaseState'
local Updater   = require 'src/update/Updater'
local L         = require 'src/core/Lang'
local UpdateState = BaseState:new()

local SHOW_AFTER = 0.6        -- s antes de enseñar "buscando" (si no, ni se ve)

function UpdateState:enter(args)
    args = args or {}
    self.after = args.after or 'title'
    self.t = 0
    -- (UPDATE_BLOCKED: este aparato no puede montar las actualizaciones; ver main.lua)
    if not UPDATE_ENABLED or UPDATE_BLOCKED then self.skip = true; return end
    self.upd = Updater.new(SERVER_HOST, SERVER_PORT)
end

function UpdateState:_leave()
    if self.upd then self.upd:cancel(); self.upd = nil end
    gStateMachine:change(self.after)
end

function UpdateState:update(dt)
    self.t = self.t + dt
    if self.skip then return gStateMachine:change(self.after) end
    if self.restartT then
        self.restartT = self.restartT - dt
        if self.restartT <= 0 then love.event.quit('restart') end
        return
    end
    local s = self.upd:update(dt)
    if s ~= self.lastStatus then
        self.lastStatus = s
        local u = self.upd
        print(string.format('[update] %s  (instalada %s, servidor %s, %d archivos / %.1f MB)', s,
              tostring(u.current or Updater.localVersion()), tostring(u.version), u.filesTotal, u.bytesTotal / 1048576))
    end
    if s == 'done' then
        self.restartT = 0.6
    elseif s == 'uptodate' or s == 'failed' then
        -- (si venía del login por versión incompatible y no hay nada nuevo, se
        -- vuelve igual: el login dirá lo que pase)
        self.upd = nil
        gStateMachine:change(self.after)
    elseif Input.pressed('back') and s ~= 'installing' then
        self:_leave()
    end
end

local function shadowText(text, y, r, g, b)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(text, 3, y + 3, WINDOW_W, 'center')
    love.graphics.setColor(r, g, b, 1)
    love.graphics.printf(text, 0, y, WINDOW_W, 'center')
end

function UpdateState:render()
    love.graphics.clear(0.03, 0.03, 0.06, 1)
    if self.skip or not (self.upd or self.restartT) then return end
    local u = self.upd
    local s = u.status
    if (s == 'connecting' or s == 'hashing') and self.t < SHOW_AFTER then return end

    local cy = math.floor(WINDOW_H * 0.42)
    love.graphics.setFont(FONT_BIG)
    if s == 'connecting' then
        shadowText(L('upd.checking'), cy, 1, 0.95, 0.15)
    elseif self.restartT then
        shadowText(L('upd.restarting'), cy, 0.3, 1, 0.45)
    else
        shadowText(L('upd.updating', { v = u.version or '?' }), cy, 1, 0.95, 0.15)
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.printf(L('upd.from', { v = u.current or '?' }), 0, cy + 46, WINDOW_W, 'center')

        -- Barra de progreso (pixel: marco duro, relleno por bytes)
        local bw = math.min(640, WINDOW_W - 120)
        local bx, by, bh = math.floor((WINDOW_W - bw) / 2), cy + 80, 22
        local k = (s == 'hashing') and 0 or (u.bytesTotal > 0 and u.bytesDone / u.bytesTotal or 1)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle('fill', bx + 3, by + 3, bw, bh)
        love.graphics.setColor(0.12, 0.12, 0.18, 1)
        love.graphics.rectangle('fill', bx, by, bw, bh)
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.rectangle('fill', bx + 3, by + 3, math.floor((bw - 6) * math.min(1, k)), bh - 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle('line', bx + 0.5, by + 0.5, bw - 1, bh - 1)

        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.8)
        local line
        if s == 'hashing' then line = L('upd.comparing')
        else
            line = L('upd.progress', { n = u.filesDone, total = u.filesTotal,
                                       mb = string.format('%.1f', u.bytesDone / 1048576),
                                       tmb = string.format('%.1f', u.bytesTotal / 1048576) })
        end
        love.graphics.printf(line, 0, by + bh + 16, WINDOW_W, 'center')
    end
    if not self.restartT and s ~= 'installing' then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.printf(L('upd.skip', { key = Input.label('back') }), 0, WINDOW_H - 40, WINDOW_W, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return UpdateState
