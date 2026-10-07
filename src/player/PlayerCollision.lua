-- src/player/PlayerCollision.lua
-- PARTE de src/player/PlayerAdventure.lua: moverse y chocar con el nivel (bloques, plataformas, cuerpos sólidos, paredes de arena) y los pinchos.
-- La carga PlayerAdventure.lua con require(...)(PlayerAdventure, P): añade sus funciones a la tabla PlayerAdventure. P = lo que
-- antes eran locales del archivo y comparten las partes.

return function(PlayerAdventure, P)
local fx, DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT, OUTER_YOFF = P.fx, P.DIR_UP, P.DIR_DOWN, P.DIR_LEFT, P.DIR_RIGHT, P.OUTER_YOFF
local INNER_W, INNER_H = P.INNER_W, P.INNER_H

-- ── Colisión ──────────────────────────────────────────────────────────────────
-- Todo se consulta al nivel por TIPO de tile (colisión, hitbox, material); aquí
-- no se nombra ningún tile concreto.

-- Si el jugador (en el suelo) está apoyado SOLO sobre plataformas
-- traspasables, devuelve la Y de su cara superior; si algo no traspasable lo
-- sostiene (sólido, plataforma normal...), devuelve nil.
local function dropPlatformTop(pa, level)
    local ob    = pa:getOuterBounds()
    local footY = ob.y + ob.h + 2
    local top
    for _, cx in ipairs({ pa.x - pa.w/2 + 4, pa.x, pa.x + pa.w/2 - 4 }) do
        local t = level:getDefAt(cx, footY)
        if t.collision == 'oneway' and t.dropThrough then
            top = math.floor(footY / TILE_PX) * TILE_PX + t.hitbox.y * TILE_PX
        elseif t.collision ~= 'none' then
            return nil
        end
    end
    return top
end

-- Comprueba si un pincho dado (dir, pos) realmente golpea al jugador
-- basado en la dirección: la punta debe apuntar hacia el centro del jugador
local function spikeHitsPlayer(spike, pb)
    -- Centro del jugador
    local pcx = pb.x + pb.w/2
    local pcy = pb.y + pb.h/2
    -- Centro del pincho
    local scx = spike.x + spike.w/2
    local scy = spike.y + spike.h/2

    if spike.dir == DIR_UP    then return pcy < scy   end   -- punta hacia arriba, jugador encima
    if spike.dir == DIR_DOWN  then return pcy > scy   end
    if spike.dir == DIR_LEFT  then return pcx < scx   end
    if spike.dir == DIR_RIGHT then return pcx > scx   end
    return true
end

function PlayerAdventure:moveAndCollide(level, dx, dy)
    local T      = TILE_PX
    -- Caja con la que choca: la de pie o, agachado, la baja (mismos pies)
    local yoff, hh = OUTER_YOFF, self.h/2
    if self.crouching then
        local ob = self:getOuterBounds()
        hh = ob.h / 2
        yoff = ob.y + hh - self.y
    end
    local x, y   = self.x, self.y+yoff
    local hw     = self.w/2
    -- Choque de este paso contra un cuerpo sólido: { o, face, speed }. Cara
    -- del CUERPO que se tocó ('top', 'bottom', 'left', 'right') y velocidad
    -- con la que se llegó (los trampolines la usan para saber si rebotar).
    self.bodyHit = nil

    -- X: al chocar, pegarse al borde de la hitbox del tile
    x = x + dx
    -- (con varios choques manda la cara más restrictiva: con subtiles, medio
    -- tile y un tile entero pueden tener caras distintas en la misma columna)
    local chy = level.samples and level:samples(y-hh+4, y+hh-4) or {y-hh+4, y, y+hh-4}
    if dx > 0 then
        local edge
        for _,py in ipairs(chy) do
            local t = level:collisionAt(x+hw, py)
            if t then
                local e = math.floor((x+hw)/T)*T + t.hitbox.x*T
                if not edge or e < edge then edge = e end
            end
        end
        if edge then x = edge - hw; self.vx=0 end
    elseif dx < 0 then
        local edge
        for _,py in ipairs(chy) do
            local t = level:collisionAt(x-hw, py)
            if t then
                local e = t.fullHitbox and math.ceil((x-hw)/T)*T
                          or math.floor((x-hw)/T)*T + (t.hitbox.x + t.hitbox.w)*T
                if not edge or e > edge then edge = e end
            end
        end
        if edge then x = edge + hw; self.vx=0 end
    end

    -- Cuerpos sólidos (p. ej. el jefe espejo): de lado se chocan y se paran,
    -- sin empujones. Desde arriba no (eso es pisar / caer encima).
    local x0 = self.x
    local bodies
    if self.solidAgainst then bodies = self.solidAgainst(level)
    elseif not self:isInvulnerable() then bodies = level.solidBodies
    elseif level.solidBodies then
        -- Invulnerable: atraviesa a los jefes, pero no los objetos sólidos (morteros...)
        bodies = {}
        for _, o in ipairs(level.solidBodies) do if o.solidFull then bodies[#bodies+1] = o end end
    end
    if bodies then
        for _, o in ipairs(bodies) do
            if o ~= self and not o.dying and o.alive ~= false then
                local ob = o:getOuterBounds()
                local myTop, myBot = y - hh, y + hh
                -- Solapan en vertical "de lado": en los sólidos completos (solidFull,
                -- p. ej. el mortero) de verdad; en los demás, sin contar la zona de
                -- la cabeza (eso es pisarlo) ni los pies
                local sideTop = o.solidFull and (ob.y + 1) or (ob.y + ob.h * 0.35 + 10)
                local sideBot = o.solidFull and (ob.y + ob.h - 1) or (ob.y + ob.h - 8)
                if myBot > sideTop and myTop < sideBot
                   and x + hw > ob.x and x - hw < ob.x + ob.w then
                    local was = x0 + hw > ob.x and x0 - hw < ob.x + ob.w
                    if not was and dx ~= 0 then
                        -- Choque al moverse: se queda pegado a su costado
                        x = (dx > 0) and (ob.x - hw) or (ob.x + ob.w + hw)
                        self.bodyHit = { o = o, face = (dx > 0) and 'left' or 'right', speed = math.abs(self.vx) }
                        self.vx = 0
                    elseif was then
                        -- Ya estaban metidos (p. ej. cayó a su lado): se separan
                        -- poco a poco, sin atravesar paredes
                        local dir = (x < ob.x + ob.w / 2) and -1 or 1
                        if dx * dir < 0 then x = x - dx end        -- no avanzar hacia dentro
                        local nx = x + dir * 3
                        if not level:collisionAt(nx + dir * hw, y) then x = nx end
                        if (self.vx or 0) * dir < 0 then self.vx = 0 end
                    end
                end
            end
        end
    end

    -- Zona de jefe activa: paredes invisibles (no se puede salir del área).
    -- La zona se mira desde donde ESTABA: ningún empujón la atraviesa.
    local arena = level.arenaAt and (level:arenaAt(x0, y) or level:arenaAt(x, y))
    if arena then
        if x - hw < arena.x0 then x = arena.x0 + hw; self.vx = 0 end
        if x + hw > arena.x1 then x = arena.x1 - hw; self.vx = 0 end
    end

    -- Y
    local prevFoot = self.y + yoff - OUTER_YOFF + hh     -- (misma referencia que de pie)
    y = y + dy
    self.onGround = false
    self.groundDef = nil
    local chx = level.samples and level:samples(x-hw+4, x+hw-4) or {x-hw+4, x, x+hw-4}
    if dy > 0 then
        local best, bestT
        for _,px in ipairs(chx) do
            -- (una losa fina cuenta desde su cara hasta el fondo de la celda: un
            -- paso rápido no la atraviesa; abajo se comprueba que venía de arriba)
            local t = level:collisionAt(px, y+hh, true) or level:onewayCellAt(px, y+hh)
            if t then
                local top = math.floor((y+hh)/T)*T + t.hitbox.y*T
                local ok = true
                if t.collision == 'oneway' then
                    -- Bajando a través de ESTA plataforma traspasable: no colisionar
                    local passing = self.dropping and t.dropThrough and top==self.dropTop
                    ok = not passing and prevFoot<=top+2
                end
                if ok and (not best or top < best) then best, bestT = top, t end
            end
        end
        if best then
            y=best-hh
            self.vy=0; self.onGround=true; self.jumpsLeft=2
            self.groundDef=bestT
        end
    elseif dy < 0 then
        -- El centro primero: si hay un bloque rompible sobre la cabeza, es el que se rompe
        local heads = {x, x-hw+4, x+hw-4}
        if level.subSolid then for _, px in ipairs(chx) do heads[#heads+1] = px end end
        for _,px in ipairs(heads) do
            local t = level:collisionAt(px, y-hh)
            if t then
                local edge = t.fullHitbox and math.ceil((y-hh)/T)*T
                             or math.floor((y-hh)/T)*T + (t.hitbox.y + t.hitbox.h)*T
                if level.subSolid then
                    -- (subtiles: la cara más baja de todas las que toca)
                    for _, qx in ipairs(heads) do
                        local u = level:collisionAt(qx, y-hh)
                        if u and not u.fullHitbox then
                            edge = math.max(edge, math.floor((y-hh)/T)*T + (u.hitbox.y + u.hitbox.h)*T)
                        elseif u then
                            edge = math.max(edge, math.ceil((y-hh)/T)*T)
                        end
                    end
                end
                y = edge + hh; self.vy=0
                -- Cabezazo: rompe bloques rompibles y cambia los ON/OFF (desde abajo)
                local c, r = math.floor(px/T)+1, math.floor((y-hh-2)/T)+1
                local how = (t.breakable or t.toggle or t.thinIce) and level:hitTile(c, r, 'head')
                if how == 'crack' then
                    -- (hielo fino: los efectos los hace crackIce / el evento del servidor)
                elseif how == 'break' then
                    if not t.thinIce then fx(self, 'block_break', (c-1)*T, (r-1)*T) end
                elseif how == 'toggle' then
                    fx(self, 'switch_hit', (c-1)*T, (r-1)*T)
                elseif not self.crouching then       -- (saltitos agachado en un túnel: sin "bonk")
                    Sound.play('headBump')
                end
                break
            end
        end
    end

    -- Sólidos completos (solidFull): se puede estar de pie encima y darse con
    -- la cabeza por debajo, como con un bloque
    if bodies then
        local footWas = self.y + yoff + hh
        local headWas = self.y + yoff - hh
        for _, o in ipairs(bodies) do
            if o.solidFull and o ~= self and o.alive ~= false then
                local ob = o:getOuterBounds()
                if x + hw - 2 > ob.x and x - hw + 2 < ob.x + ob.w then
                    if dy > 0 and footWas <= ob.y + 2 and y + hh >= ob.y then
                        self.bodyHit = { o = o, face = 'top', speed = self.vy }
                        y = ob.y - hh; self.vy = 0; self.onGround = true; self.jumpsLeft = 2
                        self.groundDef = nil
                    elseif dy < 0 and headWas >= ob.y + ob.h - 2 and y - hh <= ob.y + ob.h then
                        self.bodyHit = { o = o, face = 'bottom', speed = -self.vy }
                        y = ob.y + ob.h + hh; self.vy = 0
                        if not o.bouncyFace then Sound.play('headBump') end
                    end
                end
            end
        end
    end

    -- Techo invisible de la zona de jefe
    if arena and y - hh < arena.y0 then y = arena.y0 + hh; if self.vy < 0 then self.vy = 0 end end

    self.x, self.y = x, y-yoff

    -- Fin de la bajada: los pies ya pasaron la zona en la que la plataforma
    -- volvería a "atraparlos" (prevFoot se mide OUTER_YOFF más arriba que los
    -- pies reales, más el margen de 2px del aterrizaje), o aterrizó en otra cosa.
    if self.dropping and (self.onGround or y + hh > self.dropTop + OUTER_YOFF + 4) then
        self.dropping = false
    end

    -- Contacto (hitbox interna) con materiales que matan o dañan
    local iw2, ih2 = INNER_W/2, INNER_H/2
    local iy = self.y+OUTER_YOFF
    if self.crouching then                      -- agachado: la caja interna baja
        local ib = self:getInnerBounds()
        ih2, iy = ib.h/2, ib.y + ib.h/2
    end
    local corners={
        {x-iw2+2,iy-ih2+2},{x+iw2-2,iy-ih2+2},
        {x-iw2+2,iy+ih2-2},{x+iw2-2,iy+ih2-2},
    }
    for _,c in ipairs(corners) do
        local t = level:contactAt(c[1],c[2])
        if t then
            if t.mat.contact == 'kill' and self:hazardHit() then return end
            if t.mat.contact == 'hurt' and self:hurt() then return end
        end
    end

    -- Pinchos: usar outer bounds contra getSpikesInBox
    local ob = self:getOuterBounds()
    local spikeList = level:getSpikesInBox(ob.x, ob.y, ob.w, ob.h)
    for _, sp in ipairs(spikeList) do
        if spikeHitsPlayer(sp, ob) and self:hazardHit() then return end
    end

    -- Líquidos
    self.liquid  = level:liquidInBox(ob.x, ob.y, ob.w, ob.h)
    self.inWater = self.liquid ~= nil
    if self.inWater and self.onGround then self.jumpsLeft=2 end
end

P.dropPlatformTop = dropPlatformTop
end
