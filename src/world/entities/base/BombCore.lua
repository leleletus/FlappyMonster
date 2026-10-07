-- src/world/entities/base/BombCore.lua
-- Lo que comparten la Bomba viva (types/bomb.lua) y la Bomba objeto
-- (types/bombobject.lua): mecha, explosión, patadas y dibujo del encendido.
-- Un jefe futuro podrá lanzar bombas objeto ya encendidas (BombObject:throw).
--
-- Estados propios:
--   'lit'        mecha encendida: parpadea (sprite 4 ↔ 1, cada vez más rápido),
--                se pone roja, chisporrotea; con física (se la puede patear)
--   'exploding'  explota (Explosions.blast) y se ve la explosión; luego muere
-- Se enciende: al tocarla (jugador o enemigo), al pisarla / patearla / con el
-- empujón de un ground pound, con otra explosión cerca (mecha corta) y, la
-- viva, además al acercarse un jugador (triggerRange).
-- Nunca hace daño por tocarla: solo la explosión (y la bomba objeto cayendo o
-- lanzada, ver bombobject.lua).

local Entity      = require 'src/world/entities/base/Entity'
local Explosions  = require 'src/world/systems/Explosions'
local SpriteStrip = require 'src/fx/SpriteStrip'

local Core = {}

Core.EXPLODE_T = 0.6          -- s de la animación de la explosión
Core.KICK_VX, Core.KICK_VY = 380, -330
Core.CHAIN_FUSE = 0.35        -- mecha al encenderla otra explosión
Core.FIZZ_EVERY = 0.5         -- s entre chisporroteos (bomb_fizz dura 0,5 s)
Core.FW, Core.FH = 15, 16     -- cuadro de las hojas
-- Punta de la mecha por cuadro (píxeles de la hoja; ver tools/ui/make_bomb_sprites.py)
Core.TIPS = {
    bomb   = { { 6, 0 }, { 4, 0 }, { 10, 0 }, { 7, 0 } },
    object = { { 6, 1 }, { 4, 1 }, { 10, 1 }, { 6, 0 } },
}

local explosionSheet
function Core.loadExplosion()
    explosionSheet = explosionSheet or SpriteStrip.load('assets/images/bomb/explosion-Sheet.png', 48)
    return explosionSheet
end

function Core.radii(self)
    local p = self.props
    return { kill = p.killRadius or Explosions.DEFAULT.kill, hurt = p.hurtRadius or Explosions.DEFAULT.hurt,
             push = p.pushRadius or Explosions.DEFAULT.push }
end

function Core.isLit(self) return self.state == 'lit' end
function Core.isExploding(self) return self.state == 'exploding' end

-- Enciende la mecha (una vez)
function Core.light(self, fuse)
    if self.state == 'lit' or self.state == 'exploding' or self.state == 'dead' or not self.alive then return end
    self.state, self.deadTimer = 'lit', 0
    self.fuseT = fuse or self.props.fuseTime or 2.0
    self.fizzAt = 0.15
    if self.releaseCrawl then self:releaseCrawl() end
    Sound.play('bombIgnite')
end

-- Patada (pisotón, empujón de un ground pound, otra explosión): sale
-- despedida (fuera de su ruta, si tenía) y se enciende. k = fuerza (0..1)
function Core.kick(self, dirX, k)
    k = k or 1
    self.vx = dirX * Core.KICK_VX * (0.5 + 0.5 * k)
    self.vy = Core.KICK_VY * (0.5 + 0.5 * k)
    self.onGround = false
    self.leftBoundPx, self.rightBoundPx = -math.huge, math.huge
    self.kicked = true
    Sound.play('bombKick')
    Core.light(self)
end

-- Explota: efectos (Explosions), fx y sonido
function Core.explode(self, level)
    self.state, self.deadTimer, self.vx, self.vy = 'exploding', 0, 0, 0
    Sound.play('bombBlast')
    Entity.emitFx('bomb_blast', self.x, self.y)
    Entity.emitFx('shake_big', self.x, self.y)
    Explosions.blast(level, self.x, self.y, Core.radii(self), self)
end

-- Otra explosión la alcanza: patada y mecha corta (reacción en cadena)
function Core.onBlast(self, x, y, d, pushR)
    if self.state == 'exploding' or not self.alive then return end
    local dir = (self.x >= x) and 1 or -1
    local wasLit = self.state == 'lit'
    Core.kick(self, dir, 1 - math.min(1, d / pushR))
    if not wasLit then self.fuseT = math.min(self.fuseT or Core.CHAIN_FUSE, Core.CHAIN_FUSE)
    else self.fuseT = math.min(self.fuseT, self.deadTimer + Core.CHAIN_FUSE) end
end

-- ¿Algo la toca? (jugadores; y enemigos/objetos que chocan con ella)
function Core.touched(self, level)
    local b = self:getOuterBounds()
    local function ov(o)
        return b.x < o.x + o.w and b.x + b.w > o.x and b.y < o.y + o.h and b.y + b.h > o.y
    end
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and ov(pa:getOuterBounds()) then return true end
    end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and not (e.isGhost and e:isGhost()) and e.def and not e.def.boss
           and e.def.category == 'Enemigos' and ov(e:getOuterBounds()) then
            return true
        end
    end
    return false
end

-- Física de la bomba encendida o suelta: gravedad (salvo voladora), frena en
-- el suelo, choca con el nivel (trampolines incluidos)
function Core.physics(self, level, dt)
    if self.flying and not self.kicked then
        self.vy = self.vy * math.max(0, 1 - 4 * dt)
    else
        self.vy = math.min(self.vy + ADV_GRAVITY * dt, 1400)
    end
    if self.onGround then self.vx = self.vx * math.max(0, 1 - 7 * dt) end
    local vx = self.vx
    self:moveAndCollide(level, vx * dt, self.vy * dt)
    if self.vx ~= vx and vx ~= 0 and self.state ~= 'launched' then self.vx = -vx * 0.35 end   -- (rebota en las paredes)
    if self.onGround then self.thrown = false end                  -- (ya no "va lanzada")
end

-- Paso de los estados de la bomba (true = ya hecho)
function Core.update(self, dt, level)
    local st = self.state
    if st == 'lit' then
        self.deadTimer = self.deadTimer + dt
        Core.physics(self, level, dt)
        if self.deadTimer >= self.fizzAt then
            self.fizzAt = self.fizzAt + Core.FIZZ_EVERY
            Sound.play('bombFizz')
        end
        if self.deadTimer >= self.fuseT then Core.explode(self, level) end
        return true
    elseif st == 'exploding' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= Core.EXPLODE_T then
            if self.finishDeath then self:finishDeath() else self.alive = false end
        end
        return true
    end
    return false
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- Cuadro (1..4) mientras arde: 4 ↔ 1, cada vez más deprisa (3 → 21 veces/s)
function Core.litFrame(t, fuse)
    fuse = math.max(0.05, fuse)
    local phase = 3 * t + 6 * t * t * t / (fuse * fuse)       -- (∫ 3 + 18 (t/F)²)
    return (math.floor(phase * 2) % 2 == 0) and 4 or 1
end
function Core.redness(t, fuse) return math.min(1, math.max(0, t / math.max(0.05, fuse))) end

-- Dibuja la bomba (hoja `sheet`, mecha `fuseSheet`, puntas `tips`) con los pies
-- en (fx, fy) de pantalla, escala s. frame = cuadro base cuando no arde.
local Particles
function Core.draw(self, sheet, fuseSheet, tips, fx, fy, s, frame, alpha, camX, camY, bx, by)
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    if st == 'exploding' then
        local ex = Core.loadExplosion()
        local k = math.min(ex.count, math.floor(t / Core.EXPLODE_T * ex.count) + 1)
        local T = TILE_PX
        local es = math.max(2, math.floor((self.props.hurtRadius or 2.3) * T * 2 / 48 + 0.5))
        love.graphics.setColor(1, 1, 1, 1)
        ex:draw(k, math.floor(self.x - (camX or 0)), math.floor(self.y - (camY or 0)), 0, es, es)
        return
    end
    local lit = st == 'lit'
    local fuse = self.fuseT or self.props.fuseTime or 2.0
    if lit then frame = Core.litFrame(t, fuse) end
    local red = lit and Core.redness(t, fuse) or 0
    -- (bx, by: "respiración" como el Gummy, anclada a los pies)
    bx, by = bx or 1, by or 1
    local sx, sy = s * (self.facing or 1) * bx, s * by
    love.graphics.setColor(1, 1 - 0.8 * red, 1 - 0.85 * red, alpha or 1)
    local cx = math.floor(fx)
    local cy = math.floor(fy - Core.FH * sy / 2)
    sheet:draw(frame, cx, cy, 0, sx, sy)
    if lit then
        -- Mecha encendida (2 variantes que parpadean) y chispas en la punta
        love.graphics.setColor(1, 1, 1, alpha or 1)
        local v = math.floor(now * 14) % 2
        fuseSheet:draw(frame + v * 4, cx, cy, 0, sx, sy)
        local tip = tips[frame] or tips[1]
        local tx = cx + (tip[1] + 0.5 - Core.FW / 2) * sx
        local ty = cy + (tip[2] + 0.5 - Core.FH / 2) * sy
        self._sparkT = self._sparkT or 0
        if not EDITOR_VIEW and now - self._sparkT > 0.05 then
            self._sparkT = now
            Particles = Particles or require 'src/fx/Particles'
            Particles.emit('fuse_spark', tx + (camX or 0), ty + (camY or 0))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Radios de la explosión en el editor (muerte / daño / empujón) y el de
-- activación de la bomba viva
function Core.drawRadii(props, cx, cy, zoom, withTrigger)
    local T = TILE_PX / zoom
    local function ring(r, col)
        love.graphics.setColor(col[1], col[2], col[3], 0.8)
        love.graphics.circle('line', cx, cy, r * T)
        love.graphics.setColor(col[1], col[2], col[3], 0.08)
        love.graphics.circle('fill', cx, cy, r * T)
    end
    ring(props.pushRadius or Explosions.DEFAULT.push, { 1, 0.9, 0.3 })
    ring(props.hurtRadius or Explosions.DEFAULT.hurt, { 1, 0.55, 0.15 })
    ring(props.killRadius or Explosions.DEFAULT.kill, { 1, 0.15, 0.1 })
    if withTrigger and (props.triggerRange or 0) > 0 then
        love.graphics.setColor(0.4, 0.9, 1, 0.9)
        local r = props.triggerRange * T
        for i = 0, 23, 2 do
            local a0, a1 = i / 24 * math.pi * 2, (i + 1) / 24 * math.pi * 2
            love.graphics.line(cx + math.cos(a0) * r, cy + math.sin(a0) * r, cx + math.cos(a1) * r, cy + math.sin(a1) * r)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Propiedades comunes de explosión (editor)
function Core.props()
    return {
        { key='fuseTime', kind='number', label='Mecha (s)', group='Explosión', default=2.0, min=0.3, max=8, step=0.1,
          help='Tiempo desde que se enciende hasta que explota' },
        { key='killRadius', kind='number', label='Radio mortal (casillas)', group='Explosión', default=1.2,
          min=0.3, max=6, step=0.1, help='Jugador aquí: muere al instante' },
        { key='hurtRadius', kind='number', label='Radio de daño (casillas)', group='Explosión', default=2.3,
          min=0.5, max=8, step=0.1, help='Jugador: -1 vida y empujón. Enemigos fuera; rompe bloques y cambia activadores' },
        { key='pushRadius', kind='number', label='Radio de empujón (casillas)', group='Explosión', default=3.6,
          min=0.5, max=10, step=0.1, help='Solo empuja (enemigos: aturdidos). Más lejos, nada' },
    }
end

return Core
