-- src/player/OnlinePlayer.lua
-- Representación visual de un jugador remoto en la partida online.
-- NO tiene física propia; renderiza la posición que le llega del servidor.

local Class = require 'libs/class'
local OnlinePlayer = Class:new()
local PixelIcons = require 'src/ui/PixelIcons'
local DeadEyes   = require 'src/player/DeadEyes'
local L = require 'src/core/Lang'

-- Sprites compartidos con PlayerAdventure (love2d cachea las imágenes)
local PS = require 'src/player/PlayerSprite'       -- (el sprite del monstruo: animaciones por nombre)
local function loadSprites() end

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
    self.stunned     = data.stunned     or false
    self.hurt        = data.hurt        or false
    self.invuln      = data.invuln      or false
    self.squashed    = data.squashed    or false
    if data.iced and not self.iced then self.icedAt = love.timer.getTime() end
    self.iced        = data.iced        or false
    self.lightOn     = data.lightOn     or false     -- (linterna encendida: la dibuja Darkness)
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
    -- Parpadeo de invulnerabilidad tras reaparecer
    local PA = require('src/player/PlayerAdventure')
    local spriteAlpha = PA.invulnAlpha(self.invuln and not self.dying, alpha)

    -- Seleccionar sprite según frame / estado de muerte
    local img
    if self.dying then
        img = PS.rec('dead')
    elseif self.frame == 5 then
        img = PS.rec('crouch')
    else
        img = PS.rec(self.frame)
    end

    local iw = img.w
    local ih = img.h
    local sc = PLAYER_SCALE

    local r, g, b = self.color[1], self.color[2], self.color[3]

    -- Sprite con tinte de color del jugador
    if self.hurt and math.floor(love.timer.getTime() * 12) % 2 == 0 then
        love.graphics.setColor(1, 0.22, 0.22, spriteAlpha)    -- parpadeo rojo al recibir daño
    else
        love.graphics.setColor(
            0.6 + r * 0.4,
            0.6 + g * 0.4,
            0.6 + b * 0.4,
            spriteAlpha)
    end
    local PAm = require('src/player/PlayerAdventure')
    local iced = self.iced and not self.dying
    if iced then                                     -- (congelado: el cuerpo teñido de hielo)
        local sh = require('src/fx/IceEncase').tint()
        if sh then love.graphics.setShader(sh) end
    end
    if self.squashed and not self.dying then
        -- Aplastado: agachado y achatado, con los pies en el suelo
        PS.draw(PS.rec('crouch'), sx, sy + 16 * PLAYER_SCALE / 2, 0, sc * self.facing, sc * PAm.SQUASH_K,
                           iw/2, PS.rec('crouch').h)
    else
        -- (en lo oscuro: su filo blanco; lo decide SU posición, no la de quien mira)
        if PAm.lightLevel and require('src/fx/Silhouette').on(PAm.lightLevel, self.renderY) then
            local _, _, _, al = love.graphics.getColor()
            require('src/fx/Silhouette').draw(img, sx, sy, 0, sc * self.facing, sc, al)
        end
        PS.draw(img, sx, sy, 0, sc * self.facing, sc, iw/2, ih/2)
    end
    if iced then love.graphics.setShader() end
    if self.dying then
        DeadEyes.draw(sx, sy, sc, self.facing, 1, 1, 1, alpha)
    end
    if self.stunned and not self.dying then
        require('src/player/PlayerAdventure').drawStunStars(sx, sy, self.squashed)
    end
    if self.iced and not self.dying then           -- (congelado: bloque de hielo)
        PAm.drawIce(sx, sy, love.timer.getTime() - (self.icedAt or 0), nil, self.squashed)
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
        love.graphics.printf(L('oadv.finish_place', { n = self.place }), sx - 60, nameY - 16, 120, 'center')
    elseif self.isSpectator then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(0.7, 0.7, 1, 0.7)
        love.graphics.printf("SPEC", sx - 40, nameY - 16, 80, 'center')
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return OnlinePlayer
