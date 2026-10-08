-- src/editor/ScenePreview.lua
-- ESCENARIO de las vistas previas de los editores (animaciones y enemigos): en vez de un fondo liso, el dibujo se ve
-- "más o menos como en el juego" — cielo, suelo de casillas de verdad a su tamaño y el monstruo al lado para comparar
-- tamaños —, para ajustar a ojo el ancla, la escala o la caja (¿pisa el suelo?, ¿se hunde?, ¿es muy grande?).
--   Scene.draw(kind, x, y, w, h, groundY, tilePx, centerX)   kind: 'pradera' | 'cueva' | 'nada'
--        groundY = fila de pantalla del SUELO; tilePx = lo que mide una casilla (64 px del juego) en esta vista
--   Scene.player(feetX, groundY, gamePx)                    el monstruo de pie ahí (gamePx = px de vista por px de juego)
--   Scene.next(kind) → el siguiente escenario; Scene.LABEL[kind]
local Scene = { KINDS = { 'pradera', 'cueva', 'nada' }, LABEL = { pradera = 'Pradera', cueva = 'Cueva', nada = 'Sin escenario' } }

local SKY = {
    pradera = { { 0.36, 0.63, 0.90 }, { 0.62, 0.83, 0.97 } },
    cueva   = { { 0.07, 0.06, 0.09 }, { 0.13, 0.11, 0.15 } },
}
local TILES = { pradera = { 'grass', 'dirt' }, cueva = { 'stone', 'deep_stone' } }
local imgs = {}
local function tile(name)
    if imgs[name] == nil then
        local ok, im = pcall(love.graphics.newImage, 'assets/images/world/tiles/' .. name .. '.png')
        if ok then im:setFilter('nearest', 'nearest') end
        imgs[name] = ok and im or false
    end
    return imgs[name]
end

function Scene.next(kind)
    for i, k in ipairs(Scene.KINDS) do if k == kind then return Scene.KINDS[i % #Scene.KINDS + 1] end end
    return Scene.KINDS[1]
end

function Scene.draw(kind, x, y, w, h, groundY, tilePx, centerX)
    if kind == 'nada' or not SKY[kind] then return false end
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    love.graphics.setScissor(x, y, w, h)
    -- cielo (degradado a franjas, como los fondos del juego)
    local top, bot = SKY[kind][1], SKY[kind][2]
    local bands = 6
    for i = 0, bands - 1 do
        local k = i / (bands - 1)
        love.graphics.setColor(top[1] + (bot[1] - top[1]) * k, top[2] + (bot[2] - top[2]) * k, top[3] + (bot[3] - top[3]) * k, 1)
        love.graphics.rectangle('fill', x, y + math.floor(h * i / bands), w, math.ceil(h / bands) + 1)
    end
    -- suelo: casillas de verdad, con una junta justo bajo el centro
    love.graphics.setColor(1, 1, 1, 1)
    tilePx = math.max(4, tilePx)
    local names = TILES[kind]
    local x0 = (centerX or (x + w / 2)) - tilePx / 2
    x0 = x0 - math.ceil((x0 - x) / tilePx) * tilePx
    local row = 0
    for ty = groundY, y + h, tilePx do
        local im = tile(names[math.min(#names, row + 1)])
        for tx = x0, x + w, tilePx do
            if im then
                local iw = im:getWidth()
                -- (las texturas grandes, de 128, cubren 2x2 casillas: se enseña su esquina)
                local q = love.graphics.newQuad(0, 0, 64, 64, iw, im:getHeight())
                love.graphics.draw(im, q, math.floor(tx), math.floor(ty), 0, tilePx / 64, tilePx / 64)
            else
                love.graphics.setColor(0.3, 0.25, 0.2, 1); love.graphics.rectangle('fill', tx, ty, tilePx, tilePx); love.graphics.setColor(1, 1, 1, 1)
            end
        end
        row = row + 1
    end
    if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) else love.graphics.setScissor() end
    return true
end

-- El monstruo, de pie en (feetX, groundY), al tamaño que tiene en el juego
function Scene.player(feetX, groundY, gamePx)
    local ok, PS = pcall(require, 'src/player/PlayerSprite')
    if not ok then return end
    local f = PS.rec('idle')
    if not (f and f.image) then return end
    local s = (PLAYER_SCALE or 6) * gamePx
    love.graphics.setColor(1, 1, 1, 0.9)
    PS.draw(f, math.floor(feetX), math.floor(groundY), 0, s, s, f.w / 2, f.h)
    love.graphics.setColor(1, 1, 1, 1)
end

return Scene
