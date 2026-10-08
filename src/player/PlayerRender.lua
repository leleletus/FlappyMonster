-- src/player/PlayerRender.lua
-- PARTE de src/player/PlayerAdventure.lua: el dibujo del jugador (sprites, parpadeo, hielo, filo blanco).
-- La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P): añade sus funciones a la tabla PlayerAdventure. P = lo que
-- antes eran locales del archivo y comparten las partes.
local DeadEyes = require 'src/player/DeadEyes'

return function(PlayerAdventure, P)
local SPRITE_H, SQUASH_K = P.SPRITE_H, P.SQUASH_K

-- ── Render ────────────────────────────────────────────────────────────────────
local IceEncase            -- (solo dibujo: se carga al dibujar el hielo)
local Silhouette
local sprites    = nil
local spriteDead = nil
local spriteCrouch = nil
local function loadSprites()
    if sprites then return end
    sprites = {
        require('src/fx/Anim').image('assets/images/player/monstrito1.png'),
        require('src/fx/Anim').image('assets/images/player/monstrito2.png'),
        require('src/fx/Anim').image('assets/images/player/monstrito3.png'),
    }
    spriteDead  = require('src/fx/Anim').image('assets/images/player/monstrito4.png')
    spriteCrouch = require('src/fx/Anim').image('assets/images/player/monstrito5.png')
end

function PlayerAdventure:render(camX, camY)
    local img
    if self.dying then
        img = spriteDead
    elseif self.frame == 5 then
        img = spriteCrouch
    else
        img = sprites[self.frame] or sprites[3]
    end
    local iw=img:getWidth(); local ih=img:getHeight()
    local s=PLAYER_SCALE*self.puff
    local r, g, b = PlayerAdventure.hurtTint(self.dying and 0 or self.hurtT)
    love.graphics.setColor(r, g, b, PlayerAdventure.invulnAlpha(not self.dying and self.invT or 0))
    local squashed = not self.dying and (self.squashT or 0) > 0
    local iced = not self.dying and (self.iceT or 0) > 0
    if iced then                                     -- (congelado: el cuerpo teñido de hielo)
        IceEncase = IceEncase or require 'src/fx/IceEncase'
        local sh = IceEncase.tint()
        if sh then love.graphics.setShader(sh) end
    end
    if squashed then
        -- Aplastado: agachado y achatado de arriba abajo, con los pies en el suelo
        love.graphics.draw(spriteCrouch, math.floor(self.x-camX), math.floor(self.y-camY+SPRITE_H/2),
            0, s*self.facing, s*SQUASH_K, iw/2, ih)
    else
        -- En lo oscuro (niveles a oscuras, de noche, cuevas, bajo la superficie) su filo blanco (src/fx/Silhouette.lua).
        -- CADA monstruo lo decide por SU sitio: quien dibuja solo dice en qué nivel (`PlayerAdventure.lightLevel`);
        -- antes era un sí/no común y el del jugador local encendía o apagaba el de todos los demás
        Silhouette = Silhouette or require 'src/fx/Silhouette'
        if PlayerAdventure.lightLevel and not iced and Silhouette.on(PlayerAdventure.lightLevel, self.y) then
            local _, _, _, al = love.graphics.getColor()
            Silhouette.draw(img, self.x-camX, self.y-camY, 0, s*self.facing, s, al)
        end
        love.graphics.draw(img,
            math.floor(self.x-camX), math.floor(self.y-camY),
            0, s*self.facing, s, iw/2, ih/2)
    end
    if iced then love.graphics.setShader() end
    if self.dying then
        DeadEyes.draw(math.floor(self.x-camX), math.floor(self.y-camY), s, self.facing)
    elseif (self.stunT or 0) > 0 then
        PlayerAdventure.drawStunStars(self.x - camX, self.y - camY, squashed)
    end
    if not self.dying and (self.iceT or 0) > 0 then
        PlayerAdventure.drawIce(math.floor(self.x-camX), math.floor(self.y-camY), love.timer.getTime(), self.iceT,
                                self.crouching or squashed)
    end
end

-- Bloque de hielo alrededor del jugador congelado (x, y = centro en pantalla).
-- También para jugadores remotos (sin `left`: no parpadea al final).
function PlayerAdventure.drawIce(sx, sy, t, left, crouched)
    IceEncase = IceEncase or require 'src/fx/IceEncase'
    -- (todo el dibujo, antenas incluidas: 9 px de arte de ancho, 16 de alto / 9 agachado)
    local w, h = 9 * PLAYER_SCALE, (crouched and 9 or 16) * PLAYER_SCALE
    IceEncase.draw(sx - w / 2, sy + SPRITE_H / 2 - h, w, h - 2, t, left)
end

-- Destello rojo al recibir un golpe. También para jugadores remotos.
function PlayerAdventure.hurtTint(hurtT, a)
    if (hurtT or 0) > 0 and math.floor(love.timer.getTime() * 12) % 2 == 0 then
        return 1, 0.22, 0.22, a or 1
    end
    return 1, 1, 1, a or 1
end

-- Parpadeo (transparencia) mientras es invulnerable (por lo que sea)
function PlayerAdventure.invulnAlpha(invT, a)
    if (invT == true or (tonumber(invT) or 0) > 0) and math.floor(love.timer.getTime() * 15) % 2 == 0 then
        return (a or 1) * 0.25
    end
    return a or 1
end

-- Estrellitas girando sobre la cabeza (aturdido). También para jugadores remotos.
-- squashed = aplastado: la cabeza está mucho más abajo (sprite agachado,
-- 9 filas visibles, achatado a SQUASH_K)
function PlayerAdventure.drawStunStars(sx, sy, squashed)
    local t = love.timer.getTime()
    local headY = squashed and (sy + SPRITE_H / 2 - 9 * PLAYER_SCALE * SQUASH_K) or (sy - SPRITE_H / 2)
    for i = 0, 2 do
        local a  = t * 6 + i * (math.pi * 2 / 3)
        local x  = math.floor(sx + math.cos(a) * 22)
        local y  = math.floor(headY - 10 + math.sin(a) * 6)
        love.graphics.setColor(1, 0.9, 0.3, 1)
        love.graphics.rectangle('fill', x - 4, y - 1, 8, 2)
        love.graphics.rectangle('fill', x - 1, y - 4, 2, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

P.loadSprites = loadSprites
end
