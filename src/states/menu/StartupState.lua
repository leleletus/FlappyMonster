-- src/states/menu/StartupState.lua
-- PANTALLA DE INICIO: el logo de mtvemo antes del título. Negro → funde a blanco → las seis letras del logo salen
-- una a una, cada una con su nota de la melodía (assets/sounds/jingles/startup.wav, tools/sounds/startup.py) → con
-- el acorde final el logo entero da un pequeño latido → funde a negro → título.
-- El logo (assets/startup/mtvemo_logo.png) lo dibujó el usuario; sus letras recortadas y dónde va cada una salen de
-- tools/art/ui/make_logo_parts.py (assets/startup/parts/, assets/startup/logo.json).
-- Se salta con cualquier botón o tocando la pantalla (funde a negro enseguida). Solo sale al arrancar el juego.

local BaseState = require 'src/core/BaseState'
local json      = require 'libs/json'
local StartupState = BaseState:new()

-- (los dos primeros, igual que STEP y CHORD_AT de tools/sounds/startup.py)
local NOTE_STEP, CHORD_AT = 0.15, 0.90
StartupState.T_WHITE = 0.6        -- s de negro a blanco
StartupState.T_FIRST = 0.85       -- s a los que sale la primera letra (y empieza la melodía)
StartupState.T_HOLD  = 1.6        -- s con el logo entero (desde el acorde)
StartupState.T_OUT   = 0.6        -- s de fundido a negro
StartupState.T_SKIP  = 0.25       -- … si se salta
local POP = 0.16                  -- s que tarda una letra en asentarse
local LOGO_W = 0.56               -- ancho del logo (su tinta) respecto al ancho de la pantalla

local art
local function loadArt()
    if art then return art end
    local data = json.decode(love.filesystem.read('assets/startup/logo.json'))
    art = { parts = {}, x0 = math.huge, y0 = math.huge, x1 = -math.huge, y1 = -math.huge }
    for i, p in ipairs(data.parts) do
        local img = love.graphics.newImage('assets/startup/parts/' .. p.file, { mipmaps = true })
        img:setFilter('linear', 'linear')
        art.parts[i] = { img = img, x = p.x, y = p.y, w = p.w, h = p.h }
        art.x0, art.y0 = math.min(art.x0, p.x), math.min(art.y0, p.y)
        art.x1, art.y1 = math.max(art.x1, p.x + p.w), math.max(art.y1, p.y + p.h)
    end
    return art
end

function StartupState:enter(args)
    self.after = (args and args.after) or 'title'
    self.t, self.outAt, self.outDur, self.played = 0, nil, StartupState.T_OUT, false
    loadArt()
end

function StartupState:total() return StartupState.T_FIRST + CHORD_AT + StartupState.T_HOLD end

function StartupState:skip()
    if self.outAt then return end
    self.outAt, self.outDur = self.t, StartupState.T_SKIP
    if self.played then Sound.stopTracked('startup') end
    self.played = true                                    -- (si aún no había sonado, ya no suena)
end

function StartupState:update(dt)
    self.t = self.t + dt
    if not self.played and self.t >= StartupState.T_FIRST then
        self.played = true
        Sound.playTracked('startup')
    end
    if not self.outAt then
        if Input.pressed('confirm') or Input.pressed('flap') or Input.pressed('back') then self:skip()
        elseif self.t >= self:total() then self.outAt = self.t end
    elseif self.t >= self.outAt + self.outDur then
        gStateMachine:change(self.after)
    end
end

function StartupState:touchpressed() self:skip() end

-- 0..1 con un pequeño rebote al final (la letra se pasa un poco y vuelve)
local function back(k)
    k = k - 1
    return 1 + k * k * (2.7 * k + 1.7)
end

function StartupState:render()
    local a, t = loadArt(), self.t
    local white = math.max(0, math.min(1, t / StartupState.T_WHITE))
    love.graphics.setColor(white, white, white, 1)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    -- el logo, centrado; con el acorde, un latido
    local sc = WINDOW_W * LOGO_W / (a.x1 - a.x0)
    local tc = t - (StartupState.T_FIRST + CHORD_AT)
    if tc > 0 then sc = sc * (1 + 0.04 * math.exp(-tc / 0.16)) end
    local cx, cy = (a.x0 + a.x1) / 2, (a.y0 + a.y1) / 2
    for i, p in ipairs(a.parts) do
        local k = (t - (StartupState.T_FIRST + (i - 1) * NOTE_STEP)) / POP
        if k > 0 then
            k = math.min(1, k)
            local rise = (1 - back(k)) * 34 * sc
            love.graphics.setColor(1, 1, 1, math.min(1, k * 2))
            love.graphics.draw(p.img, WINDOW_W / 2 + (p.x - cx) * sc, WINDOW_H / 2 + (p.y - cy) * sc + rise, 0, sc, sc)
        end
    end
    if self.outAt then
        love.graphics.setColor(0, 0, 0, math.max(0, math.min(1, (t - self.outAt) / self.outDur)))
        love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return StartupState
