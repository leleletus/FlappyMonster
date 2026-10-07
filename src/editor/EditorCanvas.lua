-- src/editor/EditorCanvas.lua
-- PARTE de src/editor/Editor.lua: el LIENZO — lo que hace cada herramienta al pulsar / arrastrar / soltar, y el dibujo del mapa.
-- La carga Editor.lua con require(...)(E, P): añade sus funciones a la tabla E. P = lo que
-- antes eran locales del archivo y comparten las partes.
local ui       = require 'src/editor/ui'
local DT       = require('src/world/decorations/Decorations').types
local Clip     = require 'src/ui/Clip'
local Sky      = require 'src/fx/Sky'
local BossZones = require 'src/world/systems/BossZones'

return function(E, P)
local TT, ET, Codec, th, Editor, T = P.TT, P.ET, P.Codec, P.th, P.Editor, P.T
local DIR_ARROW, msg, canvasRect, screenToWorld, worldToCell, lineCells = P.DIR_ARROW, P.msg, P.canvasRect, P.screenToWorld, P.worldToCell, P.lineCells
local img, drawTileThumb, markDirty, pushUndo = P.img, P.drawTileThumb, P.markDirty, P.pushUndo

-- ── Acciones sobre el lienzo ──────────────────────────────────────────────────
local function pal() return E.palette[E.layer] end

local function applyCell(c, r, erase)
    local m = E.model
    if not m:inBounds(c, r) then return false end
    local L = E.layer
    if L == 'tiles' then
        return m:setId(c, r, erase and TILE_EMPTY or pal())
    elseif L == 'water' then
        return m:setWater(c, r, not erase)
    end
    return false
end

local function applySpike(c, r, sub, erase)
    if not E.model:inBounds(c, r) then return false end
    return E.model:setSpike(c, r, sub, not erase, E.spikeDir)
end

local function applyMini(c, r, sub, erase)
    if not E.model:inBounds(c, r) then return false end
    return E.model:setSubtile(c, r, sub, (not erase) and E.palette.mini or nil, E.miniSolid)
end

local function applyFill(c, r, erase)
    local m = E.model
    if E.layer == 'tiles' then
        local id = erase and TILE_EMPTY or pal()
        return m:flood(c, r, function(raw) return Codec.id(raw) end,
                       function(cc, rr) return m:setId(cc, rr, id) end) > 0
    elseif E.layer == 'water' then
        return m:flood(c, r, function(raw) return Codec.id(raw) * 2 + (Codec.isWaterlogged(raw) and 1 or 0) end,
                       function(cc, rr) return m:setWater(cc, rr, not erase) end) > 0
    end
end

local function rectCells(a, b)
    local out = {}
    for r = math.min(a[2], b[2]), math.max(a[2], b[2]) do
        for c = math.min(a[1], b[1]), math.max(a[1], b[1]) do out[#out+1] = { c, r } end
    end
    return out
end

-- Asas editables (rutas, puntos) de una entidad según su esquema
local function handlesOf(e)
    local hs = {}
    local t = ET.get(e.type)
    if not t then return hs end
    for _, p in ipairs(t.schema) do
        local v = e.props[p.key]
        if p.kind == 'patrol' and v and (not p.showIf or p.showIf(e.props)) then
            hs[#hs+1] = { key = p.key, side = 'left',  col = v.left,  row = e.row }
            hs[#hs+1] = { key = p.key, side = 'right', col = v.right, row = e.row }
        elseif p.kind == 'point' and v then
            hs[#hs+1] = { key = p.key, side = 'point', col = v.col, row = v.row }
        elseif p.kind == 'points' and v then
            for i, q in ipairs(v) do
                hs[#hs+1] = { key = p.key, side = 'pts', idx = i, col = q.col, row = q.row, list = v }
            end
        end
    end
    return hs
end

local function canvasPress(button)
    local mx, my = love.mouse.getPosition()
    local wx, wy = screenToWorld(mx, my)
    local c, r, sub = worldToCell(wx, wy)
    local m, L, tool = E.model, E.layer, E.tool[E.layer]
    local erase = (button == 2) or tool == 'erase'
    E.stroke = { button = button, start = { c, r }, last = { c, r }, changed = false }
    pushUndo()
    local s = E.stroke

    if L == 'tiles' and tool == 'link' then
        local d = m:inBounds(c, r) and TT.get(Codec.id(m:get(c, r)))
        if d and (d.name == 'switch_on' or d.name == 'switch_off') then
            E.selSwitch = { c = c, r = r }
        elseif d and d.switchBlock and E.selSwitch then
            -- Con un activador elegido: clic (y arrastrar) en Bloques ON/OFF los
            -- conecta a él; clic en uno ya conectado a él lo desconecta
            local l = m:blockLinkAt(c, r)
            local mine = l and l.from[1] == E.selSwitch.c and l.from[2] == E.selSwitch.r
            s.blockPaint = mine and 'remove' or 'add'
            s.changed = m:setBlockLink(c, r, (not mine) and { E.selSwitch.c, E.selSwitch.r } or nil)
            s.last = { c, r }
        elseif d and d.switchBlock then
            msg('Conectar: elige primero un activador ON/OFF y luego haz clic en sus bloques', 'warn')
        else
            E.selSwitch = nil
            if button == 1 then msg('Conectar: haz clic en un bloque ON/OFF', 'warn') end
        end
    elseif L == 'tiles' or L == 'water' then
        if tool == 'pick' and button == 1 then
            local raw = m:get(c, r)
            if raw then E.palette.tiles = Codec.id(raw); E.tool.tiles = 'brush'; msg('Bloque copiado: ' .. TT.get(Codec.id(raw)).label) end
        elseif tool == 'fill' then
            s.changed = applyFill(c, r, erase)
        elseif tool == 'rect' or tool == 'line' then
            s.shape = tool; s.erase = erase
        else
            s.paint = true; s.erase = erase
            s.changed = applyCell(c, r, erase)
        end
    elseif L == 'spikes' then
        s.spikes = true; s.erase = erase; s.lastSub = sub
        s.changed = applySpike(c, r, sub, erase)
    elseif L == 'mini' then
        if tool == 'pick' and button == 1 then
            local o = m:subtileAt(c, r, sub)
            if o then
                E.palette.mini, E.miniSolid, E.tool.mini = o.kind, o.solid, 'brush'
                msg('Mini bloque copiado: ' .. TT.byName[o.kind].label .. (o.solid and '' or ' (decoración)'))
            end
        else
            s.mini = true; s.erase = erase; s.lastSub = sub
            s.changed = applyMini(c, r, sub, erase)
        end
    elseif L == 'entities' then
        -- ¿Asa de la entidad seleccionada?
        if E.selected and tool ~= 'erase' then
            for _, h in ipairs(handlesOf(E.selected)) do
                if h.col == c and h.row == r then s.handle = h; return end
            end
        end
        local pdef = ET.get(E.palette.entities)
        local e, idx = m:entityAt(c, r, sub)
        if erase then
            if e then table.remove(m.entities, idx); if E.selected == e then E.selected = nil end; s.changed = true end
        elseif e then
            E.selected = e; s.move = { e = e, dc = 0 }
        elseif tool == 'place' then
            if m:inBounds(c, r) then
                local n, why = m:addEntity(E.palette.entities, c, r, pdef and pdef.placement == 'sub' and sub or nil)
                if n then
                    E.selected = n; s.changed = true
                    if pdef and pdef.paint then
                        s.paintEntity = pdef          -- se siguen colocando al arrastrar
                    else
                        s.move = { e = E.selected }
                    end
                else
                    msg(why or 'No se puede colocar ahí', 'warn')
                end
            end
        else
            E.selected = nil
        end
    elseif L == 'deco' then
        local ft = DT.get(E.palette.deco)
        local useSub = ft and ft.placement == 'sub'
        if erase then
            local o, idx = m:findObject(m.foliage, c, r)
            if o then table.remove(m.foliage, idx); if E.selDeco == o then E.selDeco = nil end; s.changed = true end
        elseif tool == 'select' then
            local o = m:findObject(m.foliage, c, r, sub) or m:findObject(m.foliage, c, r)
            E.selDeco = o
            if o then s.moveDeco = o end
        elseif ft and m:inBounds(c, r) and not m:findObject(m.foliage, c, r, useSub and sub or nil) then
            local n = DT.normalize({ type = ft.name, col = c, row = r, sub = useSub and sub or nil })
            m.foliage[#m.foliage+1] = n
            E.selDeco = n
            s.changed = true
        end
    elseif L == 'special' then
        if tool == 'spawn' and not erase then
            if m:inBounds(c, r) then m.playerStart = { c, r }; s.changed = true end
        elseif tool == 'boss' and not erase then
            -- Esquina inferior derecha de la zona elegida: cambiar tamaño.
            -- Dentro de una zona: seleccionar y moverla. Fuera: crear una.
            local sz = E.selZone
            if sz and c == sz.col + sz.w - 1 and r == sz.row + sz.h - 1 then
                s.zoneResize = sz
            else
                local z = m:zoneAt(c, r)
                if z then
                    E.selZone = z
                    s.zoneMove = { z = z, dc = c - z.col, dr = r - z.row }
                elseif m:inBounds(c, r) then
                    s.zoneNew = true
                    E.selZone = nil
                end
            end
        elseif tool == 'vent' and not erase then
            -- Clic en un vent: seleccionarlo (para su límite de altura); en una
            -- subcelda libre: colocar uno ahí (en el centro de esa subcelda)
            local o = m:findObject(m.vents, c, r, sub)
            if o then
                E.selVent = o
            elseif m:inBounds(c, r) then
                local v = { col = c, row = r, sub = sub }
                m.vents[#m.vents+1] = v
                E.selVent = v
                s.changed = true
            end
        elseif tool == 'boss' and erase then
            local z, idx = m:zoneAt(c, r)
            if z then
                table.remove(m.bossZones, idx); s.changed = true
                if E.selZone == z then E.selZone = nil end
            end
        else
            local o, idx = m:findObject(m.vents, c, r, sub)
            if not o then o, idx = m:findObject(m.vents, c, r) end
            if o then
                table.remove(m.vents, idx); s.changed = true
                if E.selVent == o then E.selVent = nil end
            else
                local z, zi = m:zoneAt(c, r)
                if z and tool == 'erase' then
                    table.remove(m.bossZones, zi); s.changed = true
                    if E.selZone == z then E.selZone = nil end
                end
            end
        end
    end
    if s.changed then markDirty() end
end

local function canvasDrag()
    local s = E.stroke
    if not s then return end
    local wx, wy = screenToWorld(love.mouse.getPosition())
    local c, r, sub = worldToCell(wx, wy)
    if s.paint then
        for _, cell in ipairs(lineCells(s.last[1], s.last[2], c, r)) do
            if applyCell(cell[1], cell[2], s.erase) then s.changed = true; markDirty() end
        end
    elseif s.spikes then
        if c ~= s.last[1] or r ~= s.last[2] or sub ~= s.lastSub then
            if applySpike(c, r, sub, s.erase) then s.changed = true; markDirty() end
            s.lastSub = sub
        end
    elseif s.blockPaint then
        if (c ~= s.last[1] or r ~= s.last[2]) and E.model:isSwitchBlock(c, r) and E.selSwitch then
            local ch = E.model:setBlockLink(c, r, s.blockPaint == 'add' and { E.selSwitch.c, E.selSwitch.r } or nil)
            if ch then s.changed = true; markDirty() end
        end
    elseif s.mini then
        if c ~= s.last[1] or r ~= s.last[2] or sub ~= s.lastSub then
            if applyMini(c, r, sub, s.erase) then s.changed = true; markDirty() end
            s.lastSub = sub
        end
    elseif s.handle and E.selected then
        local h, p = s.handle, E.selected.props[s.handle.key]
        if h.side == 'left'  and c ~= p.left  then p.left  = math.min(c, p.right); s.changed = true; markDirty() end
        if h.side == 'right' and c ~= p.right then p.right = math.max(c, p.left);  s.changed = true; markDirty() end
        if h.side == 'point' and (c ~= p.col or r ~= p.row) then p.col, p.row = c, r; s.changed = true; markDirty() end
        if h.side == 'pts' then
            local q = p[h.idx]
            if q and (c ~= q.col or r ~= q.row) then q.col, q.row = c, r; h.row = r; s.changed = true; markDirty() end
        end
        h.col = (h.side == 'left' and p.left) or (h.side == 'right' and p.right) or c
    elseif s.paintEntity and E.model:inBounds(c, r) then
        -- Pintar entidades (p. ej. pinchos de lluvia a lo largo de un techo)
        local pd = s.paintEntity
        local psub = pd.placement == 'sub' and sub or nil
        if not E.model:entityAt(c, r, psub) then
            local n = E.model:addEntity(pd.name, c, r, psub)
            if n then s.changed = true; markDirty() end
        end
    elseif s.zoneMove then
        local z, m = s.zoneMove.z, E.model
        local nc = math.max(1, math.min(m.width - z.w + 1, c - s.zoneMove.dc))
        local nr = math.max(1, math.min(m.height - z.h + 1, r - s.zoneMove.dr))
        if nc ~= z.col or nr ~= z.row then z.col, z.row = nc, nr; s.changed = true; markDirty() end
    elseif s.zoneResize then
        local z, m = s.zoneResize, E.model
        local nw = math.max(4, math.min(m.width - z.col + 1, c - z.col + 1))
        local nh = math.max(3, math.min(m.height - z.row + 1, r - z.row + 1))
        if nw ~= z.w or nh ~= z.h then z.w, z.h = nw, nh; s.changed = true; markDirty() end
    elseif s.moveDeco and E.model:inBounds(c, r) then
        local d = s.moveDeco
        local nsub = d.sub and sub or nil
        if c ~= d.col or r ~= d.row or nsub ~= d.sub then
            d.col, d.row, d.sub = c, r, nsub
            s.changed = true; markDirty()
        end
    elseif s.move and E.model:inBounds(c, r) then
        local e = s.move.e
        local nsub = e.sub and sub or nil
        local edef = ET.get(e.type)
        local okPos = not (edef and edef.ceilingOnly) or E.model:ceilingAbove(c, r, nsub)
        if okPos and (c ~= e.col or r ~= e.row or nsub ~= e.sub) then
            -- La ruta se desplaza con la entidad
            local dc = c - e.col
            if e.props.patrol then e.props.patrol.left = e.props.patrol.left + dc; e.props.patrol.right = e.props.patrol.right + dc end
            -- ...y también sus rutas por puntos (waypoints)
            local dr = r - e.row
            local et = ET.get(e.type)
            for _, pp in ipairs(et and et.schema or {}) do
                if pp.kind == 'points' and type(e.props[pp.key]) == 'table' then
                    for _, q in ipairs(e.props[pp.key]) do q.col, q.row = q.col + dc, q.row + dr end
                end
                if pp.kind == 'point' and type(e.props[pp.key]) == 'table' then
                    local q = e.props[pp.key]
                    q.col, q.row = q.col + dc, q.row + dr
                end
            end
            e.col, e.row, e.sub = c, r, nsub
            s.changed = true; markDirty()
        end
    end
    s.last = { c, r }
end

local function canvasRelease()
    local s = E.stroke
    if not s then return end
    if s.shape then
        local wx, wy = screenToWorld(love.mouse.getPosition())
        local c, r = worldToCell(wx, wy)
        local cells = (s.shape == 'rect') and rectCells(s.start, { c, r })
                      or lineCells(s.start[1], s.start[2], c, r)
        for _, cell in ipairs(cells) do
            if applyCell(cell[1], cell[2], s.erase) then s.changed = true end
        end
        if s.changed then markDirty() end
    end
    if s.zoneNew then
        local wx, wy = screenToWorld(love.mouse.getPosition())
        local c, r = worldToCell(wx, wy)
        local m = E.model
        c = math.max(1, math.min(m.width, c)); r = math.max(1, math.min(m.height, r))
        local z
        if math.abs(c - s.start[1]) < 3 and math.abs(r - s.start[2]) < 2 then
            -- Clic: una pantalla de tamaño, empezando en la celda
            z = m:addZone(s.start[1], s.start[2], s.start[1] + BossZones.DEFAULT_W - 1, s.start[2] + BossZones.DEFAULT_H - 1)
        else
            z = m:addZone(s.start[1], s.start[2], c, r)
        end
        E.selZone = z
        s.changed = true; markDirty()
        msg('Zona de jefe #' .. z.id .. ' creada. Coloca un jefe dentro (capa Entidades).')
    end
    if not s.changed then table.remove(E.undo) end    -- el clic no cambió nada
    E.stroke = nil
end

-- ── Dibujo del lienzo ─────────────────────────────────────────────────────────
local function drawCanvas()
    local cx, cy, cw, ch = canvasRect()
    local m, lv, t, z = E.model, E.level, T(), E.zoom
    ui.rect(cx, cy, cw, ch, th.canvas, 0)
    love.graphics.setScissor(cx, cy, cw, ch)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(z)

    local camX, camY = E.camX, E.camY
    local vw, vh = cw / z, ch / z
    EDITOR_VIEW = true         -- las entidades invisibles en la partida se dibujan aquí

    -- Nivel (los culls de Level usan WINDOW_W/H: se ajustan a la vista)
    local ww, wh = WINDOW_W, WINDOW_H
    WINDOW_W, WINDOW_H = vw, vh

    -- Fondo del mapa: el MISMO cielo con paralaje que en la partida (bioma, hora,
    -- profundidad y línea de superficie) para la cámara del editor, recortado al nivel
    love.graphics.setColor(0.36, 0.48, 0.62, 1)
    love.graphics.rectangle('fill', -camX, -camY, m.width * t, m.height * t)
    if lv then
        Clip.push(-camX, -camY, m.width * t, m.height * t)
        Sky.render(lv, camX, camY)
        Clip.pop()
    end

    if lv then
        lv:render(camX, camY)
        -- Líquidos: tinte por material
        local c0, c1 = math.max(1, math.floor(camX / t) + 1), math.min(m.width, math.floor((camX + vw) / t) + 1)
        local r0, r1 = math.max(1, math.floor(camY / t) + 1), math.min(m.height, math.floor((camY + vh) / t) + 1)
        for r = r0, r1 do for c = c0, c1 do
            local liq = lv:liquidOfCell(c, r)
            if liq and liq.tint then
                love.graphics.setColor(liq.tint)
                love.graphics.rectangle('fill', (c-1)*t - camX, (r-1)*t - camY, t, t)
            end
        end end
        lv:renderVents(camX, camY)
        lv:renderFoliageBack(camX, camY)
        -- Bloques trampa: en el editor se marcan (en el juego son idénticos al original)
        love.graphics.setFont(ui.fontSm)
        for r = r0, r1 do for c = c0, c1 do
            local d = TT.get(Codec.id(m:get(c, r)))
            if d.fake then
                local x, y = (c-1)*t - camX, (r-1)*t - camY
                love.graphics.setColor(1, 0.3, 0.8, 0.9)
                love.graphics.setLineWidth(2 / z)
                for k = 0, 3 do   -- borde discontinuo
                    love.graphics.line(x + k*t/4, y + 1, x + k*t/4 + t/8, y + 1)
                    love.graphics.line(x + k*t/4, y + t - 1, x + k*t/4 + t/8, y + t - 1)
                end
                love.graphics.print('?', x + t/2 - 4, y + t/2 - 8)
            end
        end end
        -- Límite de altura de las burbujas de cada vent
        for vi, vd in ipairs(m.vents) do
            local v = lv.vents[vi]
            if v and (tonumber(vd.limit) or 0) > 0 then
                local y = v.ceilingY - camY
                love.graphics.setColor(0.4, 0.9, 1, 0.9)
                love.graphics.setLineWidth(2 / z)
                for xx = v.x - camX - 30, v.x - camX + 24, 12 do love.graphics.line(xx, y, xx + 6, y) end
                love.graphics.print('límite', v.x - camX + 30, y - 8)
            end
            if vd == E.selVent then
                love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 1)
                love.graphics.circle('line', v and (v.x - camX) or 0, v and (v.y - camY) or 0, t * 0.4)
            end
        end
    end
    Editor.drawZones(camX, camY, t, z)
    Editor.drawLinks(camX, camY, t, z)
    Editor.drawAutoScroll(camX, camY, t, z)
    for _, inst in pairs(E.instances or {}) do
        -- Si cae desde donde se colocó, se marca el recorrido hasta donde aterriza
        if inst._spawnY and math.abs(inst.y - inst._spawnY) > t * 0.5 then
            love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.7)
            love.graphics.setLineWidth(2 / z)
            local x = inst.x - camX
            local y0, y1 = inst._spawnY - camY, inst.y - camY
            local dir = y1 > y0 and 1 or -1
            for yy = y0, y1 - dir * 10, dir * 12 do love.graphics.line(x, yy, x, yy + dir * 6) end
            love.graphics.circle('line', x, y0, 6)
        end
        inst:render(camX, camY)
    end
    if lv then lv:renderFoliage(camX, camY) end
    WINDOW_W, WINDOW_H = ww, wh

    -- Punto de inicio
    local ps = m.playerStart
    local pimg = img('assets/images/player/monstrito3.png')
    if pimg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pimg, (ps[1]-0.5)*t - camX, (ps[2]-0.5)*t - camY, 0, PLAYER_SCALE, PLAYER_SCALE,
                           pimg:getWidth()/2, pimg:getHeight()/2)
    end
    love.graphics.setColor(th.ok[1], th.ok[2], th.ok[3], 0.9)
    love.graphics.setLineWidth(2 / z)
    love.graphics.rectangle('line', (ps[1]-1)*t - camX, (ps[2]-1)*t - camY, t, t)

    -- Línea de superficie del fondo (pestaña Nivel): arriba la superficie, abajo la profundidad
    if E.rightTab == 'level' and lv then
        local row = (m.surfaceRow and m.surfaceRow > 0) and m.surfaceRow or Sky.autoSurfaceRow(lv)
        local yy = (row - 1) * t - camY
        love.graphics.setColor(0.4, 0.85, 1, 0.9)
        love.graphics.setLineWidth(3 / z)
        for xx = -camX, m.width * t - camX, 24 do love.graphics.line(xx, yy, math.min(xx + 14, m.width * t - camX), yy) end
        love.graphics.print('Superficie (Alt + clic: moverla)' .. (m.depth and (' / ' .. (Sky.byId[m.depth] and Sky.byId[m.depth].label or m.depth)) or ''),
                            8 - camX, yy - 20 / z, 0, 1 / z, 1 / z)
    end

    -- Rejilla
    if E.grid then
        local c0 = math.max(0, math.floor(camX / t)); local c1 = math.min(m.width, math.ceil((camX + vw) / t))
        local r0 = math.max(0, math.floor(camY / t)); local r1 = math.min(m.height, math.ceil((camY + vh) / t))
        love.graphics.setLineWidth(1 / z)
        for c = c0, c1 do
            love.graphics.setColor(1, 1, 1, c % 5 == 0 and 0.16 or 0.07)
            love.graphics.line(c*t - camX, r0*t - camY, c*t - camX, r1*t - camY)
        end
        for r = r0, r1 do
            love.graphics.setColor(1, 1, 1, r % 5 == 0 and 0.16 or 0.07)
            love.graphics.line(c0*t - camX, r*t - camY, c1*t - camX, r*t - camY)
        end
    end

    -- Rutas de entidades (todas tenues; la seleccionada destacada y editable)
    love.graphics.setLineWidth(3 / z)
    for i, e in ipairs(m.entities) do
        local sel = (e == E.selected)
        if E.showRoutes or sel then
            for _, h in ipairs(handlesOf(e)) do
                local a = sel and 1 or 0.35
                if h.side == 'left' then
                    local p = e.props[h.key]
                    local y = (e.row - 0.5) * t - camY
                    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.8 * a)
                    love.graphics.line((p.left - 0.5) * t - camX, y, (p.right - 0.5) * t - camX, y)
                end
                if h.side == 'pts' then
                    -- Ruta por puntos: línea hacia el siguiente (y cierre al primero)
                    local nq = h.list[h.idx % #h.list + 1]
                    love.graphics.setColor(1, 0.55, 0.2, 0.8 * a)
                    love.graphics.line((h.col - 0.5) * t - camX, (h.row - 0.5) * t - camY,
                                       (nq.col - 0.5) * t - camX, (nq.row - 0.5) * t - camY)
                end
                local hx, hy = (h.col - 1) * t - camX + t * 0.2, (h.row - 1) * t - camY + t * 0.2
                love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35 * a)
                love.graphics.rectangle('fill', hx, hy, t * 0.6, t * 0.6, 6, 6)
                love.graphics.setColor(1, 1, 1, 0.9 * a)
                love.graphics.rectangle('line', hx, hy, t * 0.6, t * 0.6, 6, 6)
                if h.idx then
                    love.graphics.setFont(ui.fontSm)
                    love.graphics.print(tostring(h.idx), hx + t * 0.22, hy + t * 0.18)
                end
            end
        end
        if sel then
            -- Ayuda visual propia del tipo (p. ej. el alcance del mortero)
            local et = ET.get(e.type)
            if et and et.class.drawEditorOverlay then
                et.class.drawEditorOverlay(e.props, (e.col - 0.5) * t - camX, (e.row - 0.5) * t - camY, z,
                                           { entities = m.entities, t = t, camX = camX, camY = camY })
            end
            love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
            if e.sub then
                local h = t / 2
                love.graphics.rectangle('line', (e.col-1)*t + ((e.sub-1) % 2) * h - camX + 1,
                                        (e.row-1)*t + math.floor((e.sub-1) / 2) * h - camY + 1, h - 2, h - 2, 3, 3)
            else
                love.graphics.rectangle('line', (e.col-1)*t - camX + 2, (e.row-1)*t - camY + 2, t - 4, t - 4, 6, 6)
            end
        end
    end

    -- Decoración seleccionada
    local sd = E.selDeco
    if sd and E.layer == 'deco' then
        local h = sd.sub and t / 2 or t
        local ox = sd.sub and ((sd.sub - 1) % 2) * h or 0
        local oy = sd.sub and math.floor((sd.sub - 1) / 2) * h or 0
        love.graphics.setColor(th.warn[1], th.warn[2], th.warn[3], 0.9 + 0.1 * math.sin(love.timer.getTime() * 6))
        love.graphics.setLineWidth(2 / z)
        love.graphics.rectangle('line', (sd.col-1)*t + ox - camX + 1, (sd.row-1)*t + oy - camY + 1, h - 2, h - 2, 4, 4)
    end

    -- Borde del mapa
    love.graphics.setLineWidth(2 / z)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.6)
    love.graphics.rectangle('line', -camX, -camY, m.width * t, m.height * t)

    -- Vista previa bajo el cursor
    local mx, my = love.mouse.getPosition()
    if ui.inside(cx, cy, cw, ch) and not E.modal then
        local wx, wy = screenToWorld(mx, my)
        local c, r, sub = worldToCell(wx, wy)
        local tool = E.tool[E.layer]
        local s = E.stroke
        love.graphics.setLineWidth(2 / z)
        if s and s.shape then
            local cells = (s.shape == 'rect') and rectCells(s.start, { c, r }) or lineCells(s.start[1], s.start[2], c, r)
            love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
            for _, cell in ipairs(cells) do love.graphics.rectangle('fill', (cell[1]-1)*t - camX, (cell[2]-1)*t - camY, t, t) end
        elseif E.layer == 'tiles' and (tool == 'brush' or tool == 'rect' or tool == 'line' or tool == 'fill') then
            drawTileThumb(TT.get(E.palette.tiles), (c-1)*t - camX, (r-1)*t - camY, t)
        end
        local subLayer = E.layer == 'spikes' or E.layer == 'mini' or (E.layer == 'special' and tool == 'vent')
        if E.layer == 'entities' and tool == 'place' then
            local et = ET.get(E.palette.entities)
            if et and et.placement == 'sub' then subLayer = true end
        end
        if E.layer == 'deco' then
            local ft = DT.get(E.palette.deco)
            if E.tool.deco ~= 'erase' and ft and ft.placement == 'sub' then subLayer = true end
        end
        love.graphics.setColor(1, 1, 1, 0.9)
        if subLayer then
            local h = t / 2
            local sx, sy = (c-1)*t + ((sub-1) % 2) * h - camX, (r-1)*t + math.floor((sub-1) / 2) * h - camY
            love.graphics.rectangle('line', sx, sy, h, h)
            if E.layer == 'spikes' then ui.text(DIR_ARROW[E.spikeDir], sx, sy + h/2 - 8, th.warn, ui.fontLg, h, 'center') end
        else
            love.graphics.rectangle('line', (c-1)*t - camX, (r-1)*t - camY, t, t)
        end
        E.hover = { c = c, r = r, sub = sub }
    else
        E.hover = nil
    end

    love.graphics.setLineWidth(1)
    love.graphics.pop()
    love.graphics.setScissor()
    EDITOR_VIEW = false
end

P.canvasPress = canvasPress; P.canvasDrag = canvasDrag; P.canvasRelease = canvasRelease; P.drawCanvas = drawCanvas
end
