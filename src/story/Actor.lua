-- src/story/Actor.lua
-- Un ACTOR de las películas de la historia: un PlayerAdventure DE VERDAD dentro del decorado (su física, su
-- aceleración y frenada, sus saltos y su doble salto, sus pasos y sus animaciones), movido por un GUION de entradas
-- en vez de por el mando (como el cuerpo del jefe Espejo: types/bosses/mirror.lua). Así lo que se ve en la película
-- es exactamente lo que haría el monstruo en el juego.
--   local a = Actor.new(level, x, y, { invert = true (el Reflejo), pitch = 0.8, mute = bool })
--   a.mx = -1 | 0 | 1 (andar), a.crouch = bool (agacharse), a:jump() (pulsar saltar: salto o doble salto)
--   a:update(dt, level)     pasos fijos de 1/60 s
--   a:draw()                en coordenadas del MUNDO (dentro de Stage.drawSet), con su estela si a.trail
-- Campos útiles: a.body (x, y = centro; vx, vy, onGround, jumpsLeft, facing), a.hidden, a.face (forzar hacia dónde
-- mira cuando está quieto), a.trail (copias detrás, como el Espejo perseguidor).
local PlayerAdventure = require 'src/player/PlayerAdventure'
local PS = require 'src/player/PlayerSprite'
local Silhouette = require 'src/fx/Silhouette'

local Actor = {}
Actor.__index = Actor

local STEP = 1 / 60
local function noop() end

function Actor.new(level, x, y, o)
    o = o or {}
    local b = PlayerAdventure:new(x, y)
    b.updateDrowning = noop
    b.lives = 99
    local a = setmetatable({ level = level, body = b, mx = 0, crouch = false, jumpQ = false, acc = 0, invert = o.invert,
                             pitch = o.pitch or 1, mute = o.mute, hist = {}, histT = 0, trail = 0 }, Actor)
    -- (cae al suelo antes de empezar: queda de pie)
    for _ = 1, 30 do a:_step(level) end
    return a
end

function Actor:jump() self.jumpQ = true end
function Actor:place(x, y) self.body.x, self.body.y, self.body.vx, self.body.vy = x, y, 0, 0 end

-- El mando de mentira y los sonidos (los pasos y los saltos suenan como en el juego; el Reflejo, más graves)
function Actor:_step(level)
    local b, me = self.body, self
    local jp = self.jumpQ
    self.jumpQ = false
    local input = {
        pressed = function(k) if k == 'jump' then local v = jp; jp = false; return v end; return false end,
        down = function(k)
            if k == 'move_left' then return me.mx < 0 end
            if k == 'move_right' then return me.mx > 0 end
            if k == 'crouch' then return me.crouch end
            return false
        end,
    }
    local rS = Sound
    local snd = setmetatable({
        play = function(name, pitch, vol)
            if not me.mute and (name == 'jump' or name == 'step' or name == 'land') then rS.play(name, (pitch or 1) * me.pitch, vol) end
        end,
        playTracked = noop, stopTracked = noop, playMusic = noop, stopMusic = noop,
        isPlaying = function() return false end,
    }, { __index = function() return noop end })
    local rI, rFx = Input, PlayerAdventure.fx
    Input, Sound, PlayerAdventure.fx = setmetatable(input, { __index = rI }), snd, nil
    local ok, err = pcall(b.update, b, STEP, level)
    Input, Sound, PlayerAdventure.fx = rI, rS, rFx
    if not ok then error(err, 0) end
    -- (en una película nadie muere: la lava o los pinchos no le hacen nada)
    if b.dying then b.dying, b.deathPhase, b.alive, b.vy = false, nil, true, ADV_JUMP_VEL * 0.6 end
end

function Actor:update(dt, level)
    self.level = level
    self.acc = math.min(self.acc + (dt or 0), 0.25)
    while self.acc >= STEP do
        self.acc = self.acc - STEP
        self:_step(level)
        -- (la estela: dónde estuvo)
        self.histT = self.histT + STEP
        if self.histT >= 0.035 then
            self.histT = 0
            table.insert(self.hist, 1, { self.body.x, self.body.y, self.body.frame, self.body.facing })
            self.hist[6] = nil
        end
    end
end

local invertShader
local function invert(on)
    if not on then love.graphics.setShader(); return end
    if invertShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv); return vec4(1.0 - p.rgb, p.a) * c; }
        ]])
        invertShader = ok and sh or false
    end
    if invertShader then love.graphics.setShader(invertShader) end
end

local function frameOf(frame) return (frame == 5) and 'crouch' or frame end

-- Lo dibuja como el juego (PlayerRender): su animación, su "hinchazo" y su filo blanco en lo oscuro
function Actor:draw(o)
    if self.hidden then return end
    o = o or {}
    local b = self.body
    local f = (b.onGround and math.abs(b.vx) < 5 and self.face) or b.facing
    local s = PLAYER_SCALE * (b.puff or 1)
    local alpha = o.alpha or 1
    if self.invert and self.trail > 0 then
        invert(true)
        for i = math.min(self.trail, #self.hist), 1, -1 do
            local h = self.hist[i]
            local img = PS.rec(frameOf(h[3]))
            love.graphics.setColor(1, 1, 1, 0.14 * (4 - math.min(3, i)) * alpha)
            PS.draw(img, math.floor(h[1]), math.floor(h[2]), 0, PLAYER_SCALE * h[4], PLAYER_SCALE, img.w / 2, img.h / 2)
        end
    end
    local img = PS.rec(frameOf(b.frame))
    -- (el filo blanco, como en el juego: solo donde está oscuro — Silhouette.on —)
    if not self.invert and alpha > 0.5 and Silhouette.on(self.level, b.y) then Silhouette.draw(img, b.x, b.y, 0, s * f, s, alpha) end
    invert(self.invert)
    love.graphics.setColor(1, 1, 1, alpha)
    PS.draw(img, math.floor(b.x), math.floor(b.y), 0, s * f, s, img.w / 2, img.h / 2)
    invert(false)
    love.graphics.setColor(1, 1, 1, 1)
end

return Actor
