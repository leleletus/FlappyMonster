-- PILAR de los niveles Flappy (docs/design/flappy-prequel.md): las columnas huecas del Valle de los Pilares, las
-- "tuberías" del Flappy de siempre. SOLO para niveles Flappy (`flappyOnly`: el editor no lo ofrece en los demás y
-- level_check falla si aparece en uno). No es sólido: tocarlo con la hitbox interna quita 1 de vida (material
-- 'hurtful') y la invulnerabilidad del golpe deja ATRAVESARLO (la regla del diseño). La boca se pone sola en la cara
-- que da al aire (arriba o abajo). Arte: tools/art/world/make_flappy_pillars.py.
local BODY = { image = 'assets/images/world/tiles/pillar.png' }
local CAP  = { image = 'assets/images/world/tiles/pillar_cap.png' }
local imgs = {}
local function img(path)
    if imgs[path] == nil then
        local ok, im = pcall(love.graphics.newImage, path)
        imgs[path] = ok and im or false
        if ok then im:setFilter('nearest', 'nearest') end
    end
    return imgs[path]
end

-- ¿Cerrado por ese lado (dr = -1 arriba, 1 abajo)? Otro pilar, algo sólido o el borde del mapa: sin boca
local function closed(ctx, dr)
    local lv = ctx.level
    if not (lv and ctx.col and ctx.row) then return dr > 0 end   -- (miniatura del editor: boca arriba)
    local r = ctx.row + dr
    if r < 1 or r > lv.tileH then return true end                -- (el borde: también sin suelo debajo, openBottom)
    local n = lv:getDef(ctx.col, r)
    return n == nil or n.name == 'pillar' or n.collision == 'solid'
end

return {
    id = 59, name = 'pillar', label = 'Pilar (Flappy)', category = 'Flappy',
    flappyOnly = true,
    collision = 'none', material = 'hurtful', enemySolid = true,
    hitbox = { x = 2 / 16, y = 0, w = 12 / 16, h = 1 },
    editorColor = { 0.1, 0.1, 0.16 },
    texture = BODY,
    draw = function(t, ctx)
        local up, down = not closed(ctx, -1), not closed(ctx, 1)
        local im = img((up or down) and CAP.image or BODY.image)
        if not im then return end
        local s = ctx.size / im:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        if up or not down then
            love.graphics.draw(im, ctx.x, ctx.y, 0, s, s)
        else                                                   -- (boca abajo: la misma imagen volteada)
            love.graphics.draw(im, ctx.x, ctx.y + ctx.size, 0, s, -s)
        end
    end,
}
