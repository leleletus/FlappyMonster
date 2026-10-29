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
local PS = require 'src/player/PlayerSprite'       -- (el sprite del monstruo: animaciones por nombre)
local function loadSprites() end

function PlayerAdventure:render(camX, camY)
    if self.gulped and not self.dying then return end      -- (tragado por una planta: no se ve — PlayerGulp.lua —)
    -- (acaba de subir un escalón bajo andando: se dibuja lo que le falta por "subir" — stepVis, PlayerCollision —)
    local vis = (not self.dying and self.stepVis) or 0
    if vis > 0 then camY = camY - math.floor(vis + 0.5) end
    local img
    if self.dying then
        img = PS.rec('dead')
    elseif self.frame == 5 then
        img = PS.rec('crouch')
    else
        img = PS.rec(self.frame)
    end
    local iw=img.w; local ih=img.h
    local s=PLAYER_SCALE*self.puff
    local r, g, b = PlayerAdventure.hurtTint(self.dying and 0 or self.hurtT)
    love.graphics.setColor(r, g, b, PlayerAdventure.invulnAlpha(not self.dying and self.invT or 0))
    local squashed = not self.dying and (self.squashT or 0) > 0
    local iced = not self.dying and (self.iceT or 0) > 0
    local stunned = not self.dying and (self.stunT or 0) > 0
    if stunned then                                  -- (aturdido: las estrellitas de DETRÁS de la cabeza, antes del cuerpo)
        local cr, cg, cb, ca = love.graphics.getColor()
        PlayerAdventure.drawStunStars(self.x - camX, self.y - camY, squashed, 'back')
        love.graphics.setColor(cr, cg, cb, ca)
    end
    if iced then                                     -- (congelado: el cuerpo teñido de hielo)
        IceEncase = IceEncase or require 'src/fx/IceEncase'
        local sh = IceEncase.tint()
        if sh then love.graphics.setShader(sh) end
    end
    if squashed then
        -- Aplastado: agachado y achatado de arriba abajo, con los pies en el suelo
        PS.draw(PS.rec('crouch'), math.floor(self.x-camX), math.floor(self.y-camY+SPRITE_H/2),
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
        PS.draw(img,
            math.floor(self.x-camX), math.floor(self.y-camY),
            0, s*self.facing, s, iw/2, ih/2)
    end
    if iced then love.graphics.setShader() end
    if self.dying then
        DeadEyes.draw(math.floor(self.x-camX), math.floor(self.y-camY), s, self.facing)
    elseif stunned then
        PlayerAdventure.drawStunStars(self.x - camX, self.y - camY, squashed, 'front')
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

-- Estrellitas girando en corro alrededor de la cabeza (aturdido). También para jugadores remotos y el Espejo.
-- squashed = aplastado: la cabeza está mucho más abajo (sprite agachado, 9 filas visibles, achatado a SQUASH_K).
-- part = 'back' | 'front' (o nada = todas): el corro da la vuelta a la cabeza, así que las que pasan por DETRÁS se
-- dibujan antes del cuerpo y las de DELANTE después (en una sola pasada encima parecía un halo plano). Las de
-- detrás, un poco más pequeñas y apagadas. (`StunRing.split`: la misma regla que el corro de los jefes.)
function PlayerAdventure.drawStunStars(sx, sy, squashed, part)
    local StunRing = require 'src/fx/StunRing'
    local headY = squashed and (sy + SPRITE_H / 2 - 9 * PLAYER_SCALE * SQUASH_K) or (sy - SPRITE_H / 2)
    for _, p in ipairs(StunRing.points(3, 6, part)) do
        local x = math.floor(sx + p.x * 22)
        local y = math.floor(headY - 10 + p.y * 6)
        local k = p.back and 3 or 4                                -- (las de detrás, más pequeñas…)
        love.graphics.setColor(1, 0.9, 0.3, p.back and 0.7 or 1)  -- (…y apagadas)
        love.graphics.rectangle('fill', x - k, y - 1, 2 * k, 2)
        love.graphics.rectangle('fill', x - 1, y - k, 2, 2 * k)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

P.loadSprites = loadSprites
end
