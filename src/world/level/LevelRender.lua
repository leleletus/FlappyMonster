-- src/world/level/LevelRender.lua
-- PARTE de src/world/level/Level.lua: el dibujo del nivel (tiles, pinchos, agua con su shader) y las decoraciones.
-- La carga Level.lua con require(...)(Level, P): añade sus funciones a la tabla Level. P = lo que
-- antes eran locales del archivo y comparten las partes.
local Floods     = require 'src/world/systems/Floods'
local PointAreas = require 'src/world/systems/PointAreas'
local SubTiles   = require 'src/world/level/SubTiles'
local SpikeSkins = require 'src/world/level/SpikeSkins'
local WaterSurface = require 'src/fx/WaterSurface'
local BackPlane    = require 'src/world/level/BackPlane'

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

local SUB_OFF = { { 0, 0 }, { TILE_PX / 2, 0 }, { 0, TILE_PX / 2 }, { TILE_PX / 2, TILE_PX / 2 } }
local RENDER_CTX = {}
-- (`noPlane`: el plano de fondo ya se dibujó antes — los estados de nivel lo dibujan detrás de todo: Level:renderBackPlane)
function Level:render(camX, camY, noPlane)
    if not noPlane then self:renderBackPlane(camX, camY) end
    local t = love.timer.getTime()
    HALF_PX = TILE_PX / 2

    local sc2 = math.max(1,          math.floor(camX/TILE_PX)+1)
    local ec2 = math.min(self.tileW, math.ceil((camX+WINDOW_W)/TILE_PX)+1)
    local sr2 = math.max(1,          math.floor(camY/TILE_PX)+1)
    local er2 = math.min(self.tileH, math.ceil((camY+WINDOW_H)/TILE_PX)+1)

    local subOff = SUB_OFF
    local ctx = RENDER_CTX                 -- (una tabla para todo el fotograma y todos los fotogramas: sin basura)
    ctx.size, ctx.level, ctx.time = TILE_PX, self, t

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
-- un bloque macizo, que sería agua apretada contra un techo). Tampoco si el agua
-- de una INUNDACIÓN le llega por encima (la marea que sube sobre el agua fija):
-- las dos son un solo cuerpo y la superficie es la de arriba (la de la marea).
function Level:isWaterSurfaceCell(col, row)
    if row <= 1 then return false end
    local d = self:getDef(col, row)
    if d.collision == 'solid' and d.fullHitbox then return false end
    if liquidOfRaw(self:getRaw(col, row - 1)) then return false end
    local up = self:getDef(col, row - 1)
    if up.collision == 'solid' and up.fullHitbox then return false end
    local fl = self.floods
    return not (fl and fl[1] and Floods.liquidAt(fl, (col - 0.5) * TILE_PX, (row - 1) * TILE_PX - 0.5))
end

-- La malla de la distorsión: se rellena en cada fotograma (setVertex: sin crear tablas) y solo se vuelve a crear si
-- hacen falta más vértices que nunca (la pantalla creció)
local distortMesh, distortCap, distortN = nil, 0, 0
local dW, dH = 1, 1
local function beginDistort(rects, cw, ch)
    local need = rects * 6
    if need > distortCap then
        distortCap = need
        distortMesh = love.graphics.newMesh(distortCap, 'triangles', 'stream')
    end
    distortN, dW, dH = 0, cw, ch
end
local function vert(x, y)
    distortN = distortN + 1
    distortMesh:setVertex(distortN, x, y, x / dW, y / dH, 1, 1, 1, 1)
end
local function addDistortRect(x, y, w, h)
    if w <= 0 or h <= 0 or distortN + 6 > distortCap then return end
    vert(x, y); vert(x + w, y); vert(x + w, y + h)
    vert(x, y); vert(x + w, y + h); vert(x, y + h)
end

-- Franja de tinte [ya, yb) (px de mundo) entre las x de pantalla x0 y x1
local function tintBand(tint, x0, x1, ya, yb, camY)
    local y0 = math.floor(ya - camY)
    local h = math.floor(yb - camY) - y0
    if h > 0 then love.graphics.setColor(tint); love.graphics.rectangle('fill', x0, y0, x1 - x0, h) end
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

    -- Distorsión: la escena se vuelve a dibujar con shader, SOLO en las celdas líquidas (tile completo, también el
    -- hueco bajo una plataforma). Todas las celdas van en UNA malla (un rectángulo por celda, con las coordenadas de
    -- la escena como textura) y se dibujan de una vez: antes era un dibujo de pantalla entera por celda, recortado.
    local cw, ch = sceneCanvas:getDimensions()
    beginDistort(((ec2 - sc2 + 1) * (er2 - sr2 + 1)) * 2 + 64, cw, ch)
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.distort then
                local px = math.floor((col-1)*TILE_PX - camX)
                local py = math.floor((row-1)*TILE_PX - camY)
                -- (en la superficie, sin distorsión justo bajo la ola)
                local cut = self:isWaterSurfaceCell(col, row) and WaterSurface.MARGIN or 0
                addDistortRect(px, py + cut, TILE_PX, TILE_PX - cut)
            end
        end
    end
    Floods.renderDistort(self, camX, camY, addDistortRect, Level.liquidOfCell)
    if distortN > 0 then
        if shaderOk and waterShader then
            waterShader:send('time',     t)
            waterShader:send('strength', 0.001)
            waterShader:send('speed',    1.2)
            love.graphics.setShader(waterShader)
        end
        distortMesh:setTexture(sceneCanvas)
        distortMesh:setDrawRange(1, distortN)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(distortMesh, 0, 0)
        if shaderOk and waterShader then love.graphics.setShader() end
    end

    -- Tinte: una sola pasada, color uniforme por material (sin acumulación). Lo que el agua de una inundación
    -- cubre de la celda lleva el tinte de la inundación (la física le da a ella ese trozo: Level:liquidAt / coldAt),
    -- así el agua fija y la marea que la tapa se ven como un solo cuerpo, sin dos tintes.
    local floods = self.floods
    if floods and not floods[1] then floods = nil end
    for row = sr2, er2 do
        for col = sc2, ec2 do
            local m = liquidOfRaw(self:getRaw(col, row))
            if m and m.tint then
                local tint = (self.coldWater and m.coldTint) or m.tint          -- (agua helada: Level:coldAt)
                local cT, cB = (row-1)*TILE_PX, row*TILE_PX
                -- Alineado al píxel igual que la franja de la superficie (si
                -- no, con la cámara en posiciones fraccionarias quedaba una
                -- rendija de 1 px entre la superficie y el agua de debajo)
                local x0, x1 = math.floor((col-1)*TILE_PX - camX), math.floor(col*TILE_PX - camX)
                local f, fa, fb
                if floods then f, fa, fb = Floods.coverIn(floods, col, cT, cB) end
                local ownB = f and fa or cB                  -- (lo de la celda que es solo agua fija, desde arriba)
                if ownB > cT then
                    if self:isWaterSurfaceCell(col, row) then
                        -- Superficie con olas (el tinte sigue a la ola: sin borde plano detrás)
                        WaterSurface.draw((col-1)*TILE_PX, col*TILE_PX, cT, ownB, camX, camY, tint, 2, t)
                    else
                        tintBand(tint, x0, x1, cT, ownB, camY)
                    end
                end
                if f then
                    tintBand(Floods.tintOf(f), x0, x1, fa, fb, camY)
                    if fb < cB then tintBand(tint, x0, x1, fb, cB, camY) end
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
        if d.layer == layer and not (d.plane == 'bg' or d.def.plane == 'bg') then
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

-- El plano de fondo (src/world/level/BackPlane.lua): después del cielo, antes de todo lo demás
function Level:renderBackPlane(camX, camY) BackPlane.render(self, camX, camY) end

function Level:renderFoliage(camX, camY)     self:renderDecorations(camX, camY, 'front') end
function Level:renderFoliageBack(camX, camY) self:renderDecorations(camX, camY, 'back')  end

P.loadWaterShader = loadWaterShader
end
