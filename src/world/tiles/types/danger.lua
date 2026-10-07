-- Lava (antes "Peligro"; se mantiene el nombre interno 'danger' y el id 3 para
-- que los niveles no cambien): se atraviesa, pero tocarla con la hitbox interna
-- mata. Textura animada (4 cuadros de 16x16 x4, se repite sin costura):
-- assets/images/world/tiles/lava.png y, con la cara de arriba al aire, lava_top.png
-- (cresta brillante). Burbujas y salpicaduras: src/fx/LavaFx.lua (solo dibujo).
-- Arte: tools/art/world/make_world_art.py.
local FPS = 4
local imgs, quads = {}, {}

local function frames(path)
    if imgs[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        imgs[path] = ok and img or false
        if ok then
            img:setFilter('nearest', 'nearest')
            local w, h = img:getDimensions()
            local q = {}
            for i = 1, math.floor(w / h) do q[i] = love.graphics.newQuad((i - 1) * h, 0, h, h, w, h) end
            quads[path] = q
        end
    end
    return imgs[path], quads[path]
end

-- ¿Hay lava encima? (entonces se ve el interior, sin cresta)
local function lavaAbove(t, ctx)
    local lv = ctx.level
    if not (lv and ctx.col and ctx.row) then return false end
    local n = lv:getDef(ctx.col, ctx.row - 1)
    return n and (n.name == t.name or n.mimics == t.name or n.name == 'danger' or n.mimics == 'danger')
end

return {
    id = 3, name = 'danger', label = 'Lava', category = 'Peligros',
    -- (da luz de noche / en cueva y no se oscurece nunca: emisiva — src/fx/Darkness.lua)
    light = { r = 160, color = { 1, 0.5, 0.18 }, a = 0.3, pulse = 2.3, emissive = true },
    collision = 'none', material = 'deadly', enemySolid = false, lava = true,
    editorColor = { 0.94, 0.42, 0.12 },
    texture = { image = 'assets/images/world/tiles/lava_top.png', frames = 4, fps = FPS },
    draw = function(t, ctx)
        local path = lavaAbove(t, ctx) and 'assets/images/world/tiles/lava.png' or 'assets/images/world/tiles/lava_top.png'
        local img, q = frames(path)
        if not img then return end
        local f = math.floor((ctx.time or love.timer.getTime()) * FPS) % #q + 1
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, q[f], ctx.x, ctx.y, 0, ctx.size / img:getHeight(), ctx.size / img:getHeight())
    end,
}
