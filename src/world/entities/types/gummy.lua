-- Gummy: enemigo básico que camina, hace pausas "respirando" y muere al
-- pisotearlo. Todo el movimiento y combate viene de Entity + propiedades.
local Entity = require 'src/world/entities/Entity'

local Gummy = Entity.extend(Entity, {
    walkFps = 7, walkFrames = 2,
    idleEvery = { 3.0, 7.0 }, idleFor = { 1.0, 2.2 },
    debugColor = { 1, 0.55, 0 },
})

local imgIdle, imgWalk1, imgWalk2, imgDead

function Gummy.loadAssets()
    if imgIdle then return end
    imgIdle  = love.graphics.newImage('assets/images/gummy/gummy.png')
    imgWalk1 = love.graphics.newImage('assets/images/gummy/gummy1.png')
    imgWalk2 = love.graphics.newImage('assets/images/gummy/gummy2.png')
    imgDead  = love.graphics.newImage('assets/images/gummy/dead.png')
end

function Gummy.sizeImage() return imgIdle end

function Gummy:render(camX, camY)
    local img
    local bx, by = self:breatheScale()
    if self.state == 'dead' then
        img = imgDead
    elseif self.state == 'idle' then
        img = imgIdle
    else
        img = (self.frame == 1) and imgWalk1 or imgWalk2
    end
    local scaleX = GUMMY_SCALE * self.facing * bx
    local scaleY = GUMMY_SCALE * by
    if self.flipped then scaleY = -scaleY end

    -- Ancla en la BASE del sprite (los pies): self.y ± sprH/2
    local drawX = math.floor(self.x - camX)
    local feetY = self.flipped and math.floor(self.y - camY - self.sprH / 2)
                               or math.floor(self.y - camY + self.sprH / 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, drawX, feetY, 0, scaleX, scaleY, img:getWidth() / 2, img:getHeight())
end

return {
    name = 'gummy', label = 'Gummy', category = 'Enemigos',
    class = Gummy,
    defaults = { speed = 55, points = 10 },
    editor = { sprite = 'assets/images/gummy/gummy.png' },
}
