-- SOPORTE de los niveles Flappy (Plan 5d, docs/design/flappy-plan-5d-valley-fixes.md): el poste de hierro sobre el que
-- se posa un lanzarredes (types/traps/netlauncher.lua), ahora que las etapas Flappy no tienen suelo: sube desde el borde
-- de abajo del nivel. Sólido (para al jugador; posarse en él quita 1 y bota, como todo lo sólido de debajo en vuelo:
-- src/player/PlayerFlight.lua). La placa de arriba sale sola en la casilla que no tiene otro soporte encima; el borde
-- del mapa lo cierra (sigue hacia abajo). Arte: mount.png, mount_top.png de tools/art/enemies/make_netlauncher.py.
local BODY = { image = 'assets/images/world/tiles/mount.png' }
local TOP  = { image = 'assets/images/world/tiles/mount_top.png' }
local imgs = {}
local function img(path)
    if imgs[path] == nil then
        local ok, im = pcall(love.graphics.newImage, path)
        imgs[path] = ok and im or false
        if ok then im:setFilter('nearest', 'nearest') end
    end
    return imgs[path]
end

-- ¿Otro soporte encima? (el borde de arriba del mapa no cuenta: sin él, la placa)
local function under(ctx)
    local lv = ctx.level
    if not (lv and ctx.col and ctx.row) or ctx.row <= 1 then return false end
    return lv:getDef(ctx.col, ctx.row - 1).name == 'mount'
end

return {
    id = 60, name = 'mount', label = 'Soporte (Flappy)', category = 'Flappy',
    flappyOnly = true,
    collision = 'solid', material = 'default',
    editorColor = { 0.49, 0.49, 0.55 },
    texture = TOP,
    draw = function(t, ctx)
        local im = img(under(ctx) and BODY.image or TOP.image)
        if not im then return end
        local s = ctx.size / im:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(im, ctx.x, ctx.y, 0, s, s)
    end,
}
