-- src/world/level/LevelRender.lua
-- PARTE de src/world/level/Level.lua: el dibujo del nivel (tiles, pinchos, agua con su shader) y las decoraciones.
-- La carga Level.lua con require(...)(Level, P): añade sus funciones a la tabla Level. P = lo que
-- antes eran locales del archivo y comparten las partes.
local Floods     = require 'src/world/systems/Floods'
local PointAreas = require 'src/world/systems/PointAreas'
local SubTiles   = require 'src/world/level/SubTiles'
local SpikeSkins = require 'src/world/level/SpikeSkins'
local WaterSurface = require 'src/fx/WaterSurface'

return function(Level, P)
local TileTypes, DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT, decTile = P.TileTypes, P.DIR_UP, P.DIR_DOWN, P.DIR_LEFT, P.DIR_RIGHT, P.decTile
local tileBaseId, liquidOfRaw = P.tileBaseId, P.liquidOfRaw

-- ── Shader de agua ────────────────────────────────────────────────────────────
local waterShader = nil
local shaderOk    = false
local function loadWaterShader()
    if waterShader ~= nil then return end
    local ok, sh = pcall(love.graphics.newShader, 'assets/shaders/water.glsl')
    if ok then waterShader=sh; shaderOk=true else shaderOk=false end
end

-- ── Render ────────────────────────────────────────────────────────────────────
local HALF_PX = nil

-- Púa de tile: la imagen del aspecto de pinchos del nivel (SpikeSkins: spike.png / spike_ice.png;
-- hacia arriba, del tamaño de media casilla); las otras direcciones son la misma imagen girada o volteada
local function drawMiniSpike(dir, px, py, size, skin)
        local k = size / SpikeSkins.width(skin)
    love.graphics.setColor(1, 1, 1, 1)
    if dir == DIR_UP then
        SpikeSkins.draw(skin, px, py, 0, k, k)
    elseif dir == DIR_DOWN then
        SpikeSkins.draw(skin, px, py + size, 0, k, -k)
    elseif dir == DIR_LEFT then
        SpikeSkins.draw(skin, px, py + size, -math.pi / 2, k, k)
    elseif dir == DIR_RIGHT then
        SpikeSkins.draw(skin, px + size, py, math.pi / 2, k, k)
    end
end

-- Helper para aplicar recorte usando las transformaciones actuales (cámara/zoom)
-- Recorte a una celda (varias seguidas) y, con nil, vuelta al recorte que
-- había antes (las bandas de lovesize), no a "sin recorte"
local prevScissor
local function setTransformedScissor(x, y, w, h)
    if x and y and w and h then
        if not prevScissor then prevScissor = { love.graphics.getScissor() } end
        local p = prevScissor
        if p[1] then love.graphics.setScissor(p[1], p[2], p[3], p[4]) else love.graphics.setScissor() end
        local sx, sy = love.graphics.transformPoint(x, y)
        local ex, ey = love.graphics.transformPoint(x + w, y + h)
        local x0, y0 = math.floor(math.min(sx, ex)), math.floor(math.min(sy, ey))
        local x1, y1 = math.ceil(math.max(sx, ex)), math.ceil(math.max(sy, ey))
        love.graphics.intersectScissor(x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0))
    else
        local p = prevScissor
        prevScissor = nil
        if p and p[1] then love.graphics.setScissor(p[1], p[2], p[3], p[4]) else love.graphics.setScissor() end
    end
end

function Level:render(camX, camY)
    local t = love.timer.getTime()
    HALF_PX = TILE_PX / 2

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    local subOff = {{0,0},{HALF_PX,0},{0,HALF_PX},{HALF_PX,HALF_PX}}
    local ctx = { size = TILE_PX, level = self, time = t }

    for row = sr2, er2 do
        for col = sc2, ec2 do
            local raw = self:getRaw(col, row)
            local px  = (col-1)*TILE_PX - camX
            local py  = (row-1)*TILE_PX - camY

            -- Aspecto del tipo (el agua se pinta en renderWaterEffect). Los
            -- bloques cuyo trigger no usa el modo en juego (hiddenTriggers, p. ej.
            -- la meta en Cacería) no se dibujan: no tienen colisión.
            ctx.x, ctx.y, ctx.col, ctx.row, ctx.raw = px, py, col, row, raw
            local def = TileTypes.get(tileBaseId(raw))
            local anim = self.tileAnim and self.tileAnim[row * 65536 + col]
            if anim then
                -- Golpeado: el mismo saltito, hacia arriba con un cabezazo y
                -- hacia abajo con un ground pound (se hunde un poco y vuelve)
                local k = anim.t / anim.dur
                love.graphics.push()
                if anim.kind == 'crack' then
                    -- Hielo fino que se agrieta: tiembla de lado y se hunde un pelín
                    love.graphics.translate(math.floor(math.sin(anim.t * 70) * 3 * (1 - k) + 0.5),
                                            math.floor(math.sin(k * math.pi) * 3))
                else
                    local dir = (anim.kind == 'pound') and 1 or -1
                    love.graphics.translate(0, dir * math.floor(math.sin(k * math.pi) * TILE_PX * 0.22))
                end
            end
            if not (def.trigger and self.hiddenTriggers and self.hiddenTriggers[def.trigger]) then
                TileTypes.drawTile(def, ctx)
            end
            if anim then love.graphics.pop() end
            -- Subtiles (bloques de un cuarto de casilla)
            if self.subCells then SubTiles.renderCell(self, col, row, px, py, ctx) end

            -- Pinchos (subceldas)
            local _, _, spikes = decTile(raw)
            for i = 1, 4 do
                if spikes[i].present then
                    local ox,oy = subOff[i][1], subOff[i][2]
                    drawMiniSpike(spikes[i].dir, px+ox, py+oy, HALF_PX, self.spikeSkin)
                end
            end
        end
    end

    -- Zonas de puntos (detrás de entidades y jugadores)
    PointAreas.render(self, camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Debug (F1): hitboxes REALES que usa la física. Pinchos en rojo, tiles con
-- efecto de contacto en rojo intenso y formas de colisión no completas en cian.
function Level:renderDebug(camX, camY)
    local sc = math.max(1, math.floor(camX/TILE_PX))
    local ec = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr = math.max(1, math.floor(camY/TILE_PX))
    local er = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)
    for row = sr, er do
        for col = sc, ec do
            local t = self:getDef(col, row)
            local hx, hy, hw, hh = TileTypes.worldHitbox(t, col, row)
            if t.mat.contact then
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle('line', hx - camX, hy - camY, hw, hh)
            elseif t.collision ~= 'none' and not t.fullHitbox then
                love.graphics.setColor(0.2, 1, 1, 0.6)
                love.graphics.rectangle('line', hx - camX, hy - camY, hw, hh)
            end
            local ss = self.subSolid and self.subSolid[SubTiles.key(col, row)]
            for q = 1, 4 do
                if ss and ss[q] then
                    hx, hy, hw, hh = TileTypes.worldHitbox(ss[q], col, row)
                    love.graphics.setColor(0.2, 1, 1, 0.6)
                    love.graphics.rectangle('line', hx - camX, hy - camY, hw, hh)
                end
            end
        end
    end
    -- Burbujas de oxígeno: su círculo de colisión (cian)
    love.graphics.setColor(0.2, 1, 1, 0.8)
    for _, vent in ipairs(self.vents or {}) do
        for _, b in ipairs(vent.oxyBubbles) do
            if b.alive then
                local cx, cy, r = Level.oxyBubbleCircle(b)
                love.graphics.circle('line', cx - camX, cy - camY, r)
            end
        end
    end
    local x0, y0 = (sc-1)*TILE_PX, (sr-1)*TILE_PX
    for _, sp in ipairs(self:getSpikesInBox(x0, y0, (ec-sc+1)*TILE_PX, (er-sr+1)*TILE_PX)) do
        love.graphics.setColor(1, 0.3, 0.3, 0.5)
        love.graphics.rectangle('line', sp.x - camX, sp.y - camY, sp.w, sp.h)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ¿Celda de agua con la superficie arriba? (encima hay aire: ni líquido ni
-- un bloque macizo, que sería agua apretada contra un techo)
function Level:isWaterSurfaceCell(col, row)
    if row <= 1 then return false end
    local d = self:getDef(col, row)
    if d.collision == 'solid' and d.fullHitbox then return false end
    if liquidOfRaw(self:getRaw(col, row - 1)) then return false end
    local up = self:getDef(col, row - 1)
    return not (up.collision == 'solid' and up.fullHitbox)
end

-- Efecto de los líquidos: distorsión (shader) y tinte según su material.
function Level:renderWaterEffect(camX, camY, sceneCanvas)
    local t = love.timer.getTime()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    -- Distorsión: la escena se vuelve a dibujar con shader, recortada a cada
    -- celda líquida (tile completo, también el hueco bajo una plataforma).
    if shaderOk and waterShader then
        waterShader:send('time',     t)
        waterShader:send('strength', 0.001)
        waterShader:send('speed',    1.2)
        love.graphics.setShader(waterShader)
    end
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.distort then
                local px = math.floor((col-1)*TILE_PX - camX)
                local py = math.floor((row-1)*TILE_PX - camY)
                -- (en la superficie, sin distorsión justo bajo la ola)
                local cut = self:isWaterSurfaceCell(col, row) and WaterSurface.MARGIN or 0
                setTransformedScissor(px, py + cut, TILE_PX, TILE_PX - cut)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sceneCanvas, 0, 0)
            end
        end
    end
    Floods.renderDistort(self, camX, camY, sceneCanvas, setTransformedScissor, Level.liquidOfCell)
    setTransformedScissor()
    if shaderOk and waterShader then love.graphics.setShader() end

    -- Tinte: una sola pasada, color uniforme por material (sin acumulación)
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.tint then
                if self:isWaterSurfaceCell(col, row) then
                    -- Superficie con olas (el tinte sigue a la ola: sin borde plano detrás)
                    WaterSurface.draw((col-1)*TILE_PX, col*TILE_PX, (row-1)*TILE_PX, row*TILE_PX,
                                      camX, camY, m.tint, 2, t)
                else
                    -- Alineado al píxel igual que la franja de la superficie (si
                    -- no, con la cámara en posiciones fraccionarias quedaba una
                    -- rendija de 1 px entre la superficie y el agua de debajo)
                    love.graphics.setColor(m.tint)
                    local x0, y0 = math.floor((col-1)*TILE_PX - camX), math.floor((row-1)*TILE_PX - camY)
                    love.graphics.rectangle('fill', x0, y0, math.floor(col*TILE_PX - camX) - x0,
                                            math.floor(row*TILE_PX - camY) - y0)
                end
            end
        end
    end

    Floods.renderTint(self, camX, camY, Level.liquidOfCell)

    -- (Los pinchos de celdas con agua ya están en la escena: reciben la
    -- distorsión y el tinte igual que el resto de lo que hay bajo el agua.)

    love.graphics.setColor(1, 1, 1, 1)
end


-- ── Decoraciones: animación y dibujo ────────────────────────────────────────
function Level:updateFoliage(dt)
    for _, d in ipairs(self.decorations) do
        d.animT = d.animT + dt
        if d.def.update then d.def.update(d, dt) end
    end
end

-- Dibuja las decoraciones de una capa: 'front' (por encima de jugador y
-- enemigos) o 'back' (detrás de ellos, justo después del nivel).
function Level:renderDecorations(camX, camY, layer)
    for _, d in ipairs(self.decorations) do
        if d.layer == layer then
            local sx = math.floor(d.x - camX)
            local sy = math.floor(d.y - camY)
            local m  = TILE_PX * d.def.cullMargin
            if sx > -m and sx < WINDOW_W + m and sy > -m and sy < WINDOW_H + m then
                d.def.draw(d, sx, sy)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Level:renderFoliage(camX, camY)     self:renderDecorations(camX, camY, 'front') end
function Level:renderFoliageBack(camX, camY) self:renderDecorations(camX, camY, 'back')  end

P.loadWaterShader = loadWaterShader
end
