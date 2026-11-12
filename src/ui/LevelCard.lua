-- src/ui/LevelCard.lua
-- La TARJETA DEL NIVEL al empezar (0.5.200, docs/design/ux-round-2026-11.md): su nombre, su isla y el tiempo objetivo,
-- unos segundos en el tercio de abajo, sin parar el juego. Un jugador (AdventureState) y el cliente online
-- (OnlineAdventureState): sale de datos que tienen los dos (el nivel y su archivo). Solo dibujo.
--   local card = LevelCard.new(level, id [, o])   id = el archivo sin .json (nil: sin isla); o.par = false: sin tiempo
--   LevelCard.draw(card, t)                       t = segundos desde que empezó el nivel (o la cuenta atrás)
local L         = require 'src/core/Lang'
local MenuButton = require 'src/ui/menu/MenuButton'
local PixelFont = require 'src/ui/PixelFont'

local LevelCard = {}
LevelCard.SHOW = 3.6            -- s a la vista (entra 0,3 s, se va los últimos 0,5)

function LevelCard.new(level, id, o)
    o = o or {}
    if not level or level.flappy then return nil end
    local card = { name = L.localName(level) }
    if id then
        local Worlds = require 'src/story/Worlds'
        local w = Worlds.worldOf(id)
        if w and L.has('story.world.' .. w) then card.island = L('story.world.' .. w) end
    end
    if o.par ~= false then
        local par = (level.parTime and level.parTime > 0) and level.parTime or require('src/story/Score').par(level.tileW)
        card.par = string.format('%d:%02d', math.floor(par / 60), math.floor(par % 60))
    end
    return card
end

function LevelCard.draw(card, t)
    if not card or not t or t < 0 or t > LevelCard.SHOW then return end
    local a = math.min(1, t / 0.3, (LevelCard.SHOW - t) / 0.5)
    local slide = math.floor((1 - math.min(1, t / 0.3)) * 24 / 4) * 4
    local title = card.name:upper()
    local s = 4
    while s > 2 and PixelFont.width(title, s) > WINDOW_W - 200 do s = s - 1 end
    love.graphics.setFont(FONT_SMALL)
    local sub = {}
    if card.island then sub[#sub + 1] = card.island end
    if card.par then sub[#sub + 1] = L('levelcard.par', { t = card.par }) end
    local subT = table.concat(sub, '   ·   ')
    local w = math.max(PixelFont.width(title, s), FONT_SMALL:getWidth(subT)) + 64
    local h = PixelFont.height(s) + (subT ~= '' and 34 or 0) + 36
    local x, y = math.floor((WINDOW_W - w) / 2), math.floor(WINDOW_H * 0.68) + slide
    MenuButton.panel(x, y, w, h, 0.92 * a)
    PixelFont.draw(title, math.floor((WINDOW_W - PixelFont.width(title, s)) / 2), y + 18, s, a)
    if subT ~= '' then
        love.graphics.setColor(1, 0.86, 0.45, a)
        love.graphics.printf(subT, x, y + 26 + PixelFont.height(s), w, 'center')
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return LevelCard
