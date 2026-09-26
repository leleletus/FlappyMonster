-- src/entities/OnlinePlayer.lua
-- Representación visual de un jugador remoto en la partida online.
-- NO tiene física propia; renderiza la posición que le llega del servidor.

local Class = require 'libs/class'
local OnlinePlayer = Class:new()
local PixelIcons = require 'src/ui/PixelIcons'
local DeadEyes   = require 'src/entities/DeadEyes'

-- Sprites compartidos con PlayerAdventure (love2d cachea las imágenes)
local sprites     = nil
local spriteDead  = nil
local spriteCrouch = nil

local function loadSprites()
    if sprites then return end
    sprites = {
        love.graphics.newImage('assets/images/player/monstrito1.png'),
        love.graphics.newImage('assets/images/player/monstrito2.png'),
        love.graphics.newImage('assets/images/player/monstrito3.png'),
    }
    spriteDead   = love.graphics.newImage('assets/images/player/monstrito4.png')
    spriteCrouch = love.graphics.newImage('assets/images/player/monstrito5.png')
end

function OnlinePlayer:new(id, name, color)
    loadSprites()
    local o = setmetatable({}, self)
    self.__index = self

    o.id    = id
    o.name  = name or "???"
    o.color = color or {1, 1, 1}

    -- Estado recibido del servidor
    o.x           = 0
    o.y           = 0
    o.facing      = 1
    o.frame       = 3
    o.lives       = 3
    o.hp          = 3
    o.score       = 0
    o.drownPhase  = "none"
    o.isSpectator = false
    o.dying       = false

    -- Posición interpolada para renderizado suave
    o.renderX = 0
    o.renderY = 0
    o.firstSync = true

    return o
end

-- Actualiza el estado con los datos ya interpolados por OnlineAdventureState
-- (SnapshotBuffer). La posición llega suavizada: se dibuja tal cual.
function OnlinePlayer:applyData(data)
    self.x           = data.x           or self.x
    self.y           = data.y           or self.y
    self.facing      = data.facing      or self.facing
    self.frame       = data.frame       or self.frame
    self.lives       = data.lives       or self.lives
    self.hp          = data.hp          or self.hp
    self.score       = data.score       or self.score
    self.drownPhase  = data.drownPhase  or self.drownPhase
    self.isSpectator = data.isSpectator or false
    self.dying       = data.dying       or false
    self.finished    = data.finished    or false
    self.place       = data.place       or 0
    self.color       = data.color       or self.color

    self.renderX = self.x
    self.renderY = self.y
    self.firstSync = false
end

function OnlinePlayer:update(dt)
end

function OnlinePlayer:render(camX, camY)
    local sx = math.floor(self.renderX - camX)
    local sy = math.floor(self.renderY - camY)

    -- Solo renderizar si está en pantalla (con margen)
    if sx < -PLAYER_SCALE * 18 or sx > WINDOW_W + PLAYER_SCALE * 18 then return end
    if sy < -PLAYER_SCALE * 18 or sy > WINDOW_H + PLAYER_SCALE * 18 then return end

    -- Alpha: espectadores son semi-transparentes (los que llegaron a la meta, menos)
    local alpha = self.finished and 0.6 or (self.isSpectator and 0.32 or 1.0)

    -- Seleccionar sprite según frame / estado de muerte
    local img
    if self.dying then
        img = spriteDead
    elseif self.frame == 5 then
        img = spriteCrouch
    else
        img = sprites[self.frame] or sprites[3]
    end

    local iw = img:getWidth()
    local ih = img:getHeight()
    local sc = PLAYER_SCALE

    local r, g, b = self.color[1], self.color[2], self.color[3]

    -- Sprite con tinte de color del jugador
    love.graphics.setColor(
        0.6 + r * 0.4,
        0.6 + g * 0.4,
        0.6 + b * 0.4,
        alpha)
    love.graphics.draw(img, sx, sy, 0, sc * self.facing, sc, iw/2, ih/2)
    if self.dying then
        DeadEyes.draw(sx, sy, sc, self.facing, 1, 1, 1, alpha)
    end

    -- Nombre sobre el sprite
    love.graphics.setFont(FONT_SMALL)
    local nameW = FONT_SMALL:getWidth(self.name)
    local nameX = sx - nameW / 2
    local nameY = sy - ih / 2 * sc - 14

    love.graphics.setColor(0, 0, 0, alpha * 0.85)
    love.graphics.print(self.name, nameX + 1, nameY + 1)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.print(self.name, nameX, nameY)

    -- Corona sobre el nombre si es el host de la sala
    if self.isHost then
        local px = 2
        local cy = nameY - PixelIcons.CROWN_H * px - 4 - (self.isSpectator and 18 or 0)
        PixelIcons.crown(sx - PixelIcons.CROWN_W * px / 2, cy, px, alpha)
    end

    -- Indicador "META nº" (llegó a la meta) o "SPEC" (eliminado)
    if self.finished then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 0.85, 0.2, 0.95)
        love.graphics.printf("META " .. self.place .. "º", sx - 60, nameY - 16, 120, 'center')
    elseif self.isSpectator then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0.7, 0.7, 1, 0.7)
        love.graphics.printf("SPEC", sx - 40, nameY - 16, 80, 'center')
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return OnlinePlayer
