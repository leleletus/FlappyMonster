-- src/world/level/BackPlane.lua
-- EL PLANO DE FONDO (0.5.87, el usuario): bloques y decoraciones que se ponen POR DETRÁS del escenario — detrás de
-- todo menos del cielo del nivel —, sin colisión ni efectos, más oscuros (para que se lean como fondo) y con la SOMBRA
-- de los bloques de delante (abajo a la derecha: la luz viene de arriba a la izquierda, como en todo el arte).
--   * Datos: `bgTiles` en el JSON del nivel (la misma rejilla y codificación que `tiles`; sin la clave, no hay plano) y
--     las decoraciones con `plane = 'bg'` (en el JSON; o su tipo con `plane = 'bg'`: los árboles grandes van SIEMPRE
--     al fondo — el usuario: así el escenario se lee mejor).
--   * Qué puede ir: los bloques que se ven sólidos (terreno, piedra, ladrillos, plataformas, hielo…) — `allows` — y
--     todas las decoraciones. Ni líquidos, ni peligros, ni pinchos, ni activadores, ni metas.
--   * Dibujo: en un lienzo propio (el plano y sus decoraciones), encima la sombra de los bloques de delante con mezcla
--     'multiply' (solo oscurece lo que hay en el plano: el cielo no), y el lienzo se pone sobre el cielo más oscuro
--     (SHADE × el tinte de la hora). Sin stencil (Switch / Android).
-- Solo dibujo: el servidor no lo usa. Los bloques del plano se unen entre ellos (no con los de delante).
local TileTypes = require 'src/world/tiles/TileTypes'
local TileCodec = require 'src/world/tiles/TileCodec'

local BackPlane = {}

BackPlane.SHADE  = { 0.5, 0.53, 0.6 }    -- lo oscuro del plano (con un punto azulado hacia el cielo; el usuario: un poco más)
BackPlane.SHADOW = { 0.5, 0.5, 0.56 }    -- lo que deja la sombra de un bloque de delante (× sobre el plano)
BackPlane.OFF    = 16                    -- px: la sombra, abajo a la derecha (¼ de casilla)

-- ¿Puede ir este tipo de bloque al plano de fondo?
function BackPlane.allows(def)
    if not def or def.id == 0 then return false end
    if def.collision == 'none' or def.trigger or def.toggle or def.activator or def.lava then return false end
    if def.mat and (def.mat.liquid or def.mat.contact) then return false end
    return true
end

-- La "vista" de nivel del plano: lo que TileTypes necesita para unir bloques (getRaw), sobre la rejilla del plano
local View = {}
View.__index = View
function View:getRaw(c, r)
    local row = self.tiles[r]
    return row and row[c] or 0
end
function View:getDef(c, r) return TileTypes.get(TileCodec.id(self:getRaw(c, r))) end

-- (Level.fromData) el plano del nivel, o nil
function BackPlane.build(level, data)
    local src, any = data.bgTiles, false
    local tiles = {}
    if type(src) == 'table' then
        for r = 1, level.tileH do
            tiles[r] = {}
            for c = 1, level.tileW do
                local raw = math.floor(tonumber(src[r] and src[r][c]) or 0)
                -- (sin pinchos ni nada que no sea un bloque permitido: solo el bloque)
                local id = TileCodec.id(raw)
                local v = BackPlane.allows(TileTypes.get(id)) and TileCodec.encode(id, false, nil) or 0
                tiles[r][c] = v
                if v ~= 0 then any = true end
            end
        end
    end
    level.bg = any and setmetatable({ tiles = tiles, tileW = level.tileW, tileH = level.tileH }, View) or nil
end

-- ¿Va esta decoración al plano de fondo?
function BackPlane.isBg(d) return d.plane == 'bg' or d.def.plane == 'bg' end

local canvas, cw, ch, quad
local CTX = {}

local function drawTiles(bg, camX, camY)
    local T = TILE_PX
    local c0, c1 = math.max(1, math.floor(camX / T) + 1), math.min(bg.tileW, math.ceil((camX + WINDOW_W) / T) + 1)
    local r0, r1 = math.max(1, math.floor(camY / T) + 1), math.min(bg.tileH, math.ceil((camY + WINDOW_H) / T) + 1)
    CTX.size, CTX.level, CTX.time = T, bg, love.timer.getTime()
    for r = r0, r1 do
        local row = bg.tiles[r]
        for c = c0, c1 do
            local raw = row[c]
            if raw ~= 0 then
                CTX.x, CTX.y, CTX.col, CTX.row, CTX.raw = (c - 1) * T - camX, (r - 1) * T - camY, c, r, raw
                TileTypes.drawTile(TileTypes.get(TileCodec.id(raw)), CTX)
            end
        end
    end
end

-- La sombra de los bloques de delante sobre el plano (su hitbox, corrida OFF abajo a la derecha)
local function drawShadows(level, camX, camY)
    local T, o = TILE_PX, BackPlane.OFF
    local c0, c1 = math.max(1, math.floor((camX - o) / T) + 1), math.min(level.tileW, math.ceil((camX + WINDOW_W) / T) + 1)
    local r0, r1 = math.max(1, math.floor((camY - o) / T) + 1), math.min(level.tileH, math.ceil((camY + WINDOW_H) / T) + 1)
    local rect = love.graphics.rectangle
    for r = r0, r1 do
        for c = c0, c1 do
            local def = level:getDef(c, r)
            if def.collision ~= 'none' and not def.mat.liquid then
                local hx, hy, hw, hh = TileTypes.worldHitbox(def, c, r)
                rect('fill', hx - camX + o, hy - camY + o, hw, hh)
            end
        end
    end
end

-- Dibuja el plano (si el nivel lo tiene): después del cielo, antes de todo lo demás
function BackPlane.render(level, camX, camY)
    local bg, decos = level.bg, level.bgDecorations
    if not bg and not (decos and decos[1]) then return end
    -- (el lienzo solo CRECE: en el editor WINDOW_W/H es la vista, que cambia con cada paso de zoom, y uno nuevo por paso
    -- llenaba la memoria de vídeo; se usa su trozo de W×H. Nunca mayor que lo que admite la tarjeta: alejado del todo
    -- en una ventana enorme, lo que no quepa no se ve)
    local maxT = love.graphics.getSystemLimits().texturesize
    local W, H = math.min(maxT, math.ceil(WINDOW_W)), math.min(maxT, math.ceil(WINDOW_H))
    if not canvas or W > cw or H > ch then
        if canvas then canvas:release() end
        cw, ch = math.max(W, cw or 0), math.max(H, ch or 0)
        canvas = love.graphics.newCanvas(cw, ch)
        canvas:setFilter('nearest', 'nearest')
        quad = love.graphics.newQuad(0, 0, W, H, cw, ch)
    end
    quad:setViewport(0, 0, W, H, cw, ch)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    if bg then drawTiles(bg, camX, camY) end
    if decos then
        for _, d in ipairs(decos) do
            local sx, sy = math.floor(d.x - camX), math.floor(d.y - camY)
            local m = TILE_PX * d.def.cullMargin
            if sx > -m and sx < W + m and sy > -m and sy < H + m then d.def.draw(d, sx, sy) end
        end
    end
    -- (la sombra solo oscurece lo que ya hay en el lienzo: lo transparente sigue transparente)
    love.graphics.setBlendMode('multiply', 'premultiplied')
    love.graphics.setColor(BackPlane.SHADOW[1], BackPlane.SHADOW[2], BackPlane.SHADOW[3], 1)
    drawShadows(level, camX, camY)
    love.graphics.pop()
    -- (pop devuelve el recorte ANTES de volver al lienzo de destino: calculado para el lienzo del plano, en la pantalla
    -- caía en otro sitio — en el editor, con su recorte, el plano salía cortado o no salía —; se vuelve a poner)
    love.graphics.setScissor()
    if sx then love.graphics.setScissor(sx, sy, sw, sh) end
    -- sobre el cielo, más oscuro (y teñido por la hora, como las capas del cielo)
    local tint = require('src/fx/Sky').timeOf(level).tint
    local s = BackPlane.SHADE
    love.graphics.push('all')
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.setColor(s[1] * tint[1], s[2] * tint[2], s[3] * tint[3], 1)
    love.graphics.draw(canvas, quad, 0, 0)
    love.graphics.pop()
end

return BackPlane
