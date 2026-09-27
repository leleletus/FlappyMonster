-- src/world/entities/Boss.lua
-- Clase base de los JEFES. Un jefe es una entidad normal del catálogo
-- (types/<nombre>.lua) que hereda de aquí y cuya definición lleva `boss`:
--
--   local Boss = require 'src/world/entities/Boss'
--   local Cls  = Entity.extend(Boss, { ... tuning ... })
--   function Cls:initBoss() ... end               -- al crearse
--   function Cls:updateBoss(dt, level) ... end    -- estados propios ('fight'...)
--   function Cls:render(camX, camY) ... end
--   return { name='x', label='...', category='Jefes', class=Cls,
--            boss = { title='NOMBRE EN LA BARRA' },
--            hide = Boss.HIDE, props = Boss.props({ hp=8, hpPerPlayer=4 }, { ...propias }),
--            defaults = { points = 25 }, editor = { sprite='...' } }
--
-- Lo que da la base (igual en un jugador, servidor y cliente online):
--  * Vida: props.hp + props.hpPerPlayer por cada jugador extra, fijada al
--    empezar la pelea (startFight, lo llama la zona: world/BossZones.lua).
--  * Golpes: pisotón en la cabeza = 1, ground pound encima = 2 (e:pound);
--    tras un golpe es invulnerable INV_TIME s (parpadea rojo, los pisotones
--    solo rebotan). Sonido 'bossHurt'.
--  * Ground pound encima (jefes que se aturden, p. ej. el Espejo): le quita 2,
--    lo deja KO y queda invulnerable YA, STUN_INV s (más que el KO): no se le
--    puede dar otro golpe mientras está KO ni justo al despertar.
--  * Aturdido por OTRA cosa (el empujón de un ground pound cercano) solo
--    admite UN golpe: tras él se despierta y queda invulnerable STUN_INV s.
--    Invulnerable así parpadea transparente (como el jugador al reaparecer),
--    sigue atacando, no se le puede aturdir y no choca con los jugadores.
--  * Su cuerpo es SÓLIDO para los jugadores: de lado se chocan y se paran
--    (level.solidBodies, ver Entities.solidBodies y PlayerAdventure).
--  * Muerte: 'dying_hold' (quieto parpadeando entre explosiones) y luego
--    'dying_fall' (salta y cae fuera de la pantalla); después alive = false.
--  * Red: hp, hpMax e invulnerabilidad viajan en netPack; los tipos añaden
--    lo suyo con netPackExtra() / netApplyExtra(a, b, f).
--
-- Estados comunes: 'dormant' (antes de la pelea: no se le puede tocar),
-- 'fight', 'dying_hold', 'dying_fall', 'dead'. Los tipos añaden los suyos.
-- Hooks: initBoss, updateBoss, isStunned, endStun, onFightStart(n), onDamaged(n, kind),
-- onDefeat, onDeathFall, onPounded(pa), onKnocked(dir), onPlayerDeath(pa),
-- isVulnerable, isSolidBody.

local Entity = require 'src/world/entities/Entity'

local Boss = Entity.extend(Entity, { debugColor = { 1, 0.25, 0.6 } })

Boss.INV_TIME         = 1.0     -- s invulnerable tras un golpe normal (parpadea rojo)
Boss.STUN_INV         = 3.0     -- s invulnerable tras el ground pound que lo deja KO (dura más
                                -- que el KO) o tras el único golpe que admite aturdido
Boss.DEATH_HOLD       = 3.4     -- s parpadeando entre explosiones antes de caer
Boss.DEATH_BLAST_EVERY = 0.55   -- s entre sonidos de explosión / daño
Boss.DEATH_FREEZE     = 0.05
Boss.DEATH_JUMP_VEL   = -560
Boss.BOUNCE           = 0.55    -- fracción del salto al rebotar en su cabeza

-- Propiedades comunes que no aplican a un jefe
Boss.HIDE = { 'movement', 'attach', 'speed', 'startDir', 'patrol', 'turnAtEdges', 'bobAmp', 'pauses',
              'onTouch', 'stompable', 'dropOnSight', 'detectRange', 'respawn' }

-- Propiedades de jefe (+ las propias del tipo al final)
function Boss.props(defaults, extra)
    defaults = defaults or {}
    local list = {
        { key='zone', kind='int', label='Zona de jefe (id)', group='Jefe', default=0, min=0, max=99,
          help='Id de la zona de jefe a la que pertenece. 0 = la zona en la que está colocado' },
        { key='hp', kind='int', label='Vida (1 jugador)', group='Jefe', default=defaults.hp or 8,
          min=1, max=300, step=1, help='Golpes que aguanta con un solo jugador' },
        { key='hpPerPlayer', kind='int', label='Vida extra por jugador', group='Jefe',
          default=defaults.hpPerPlayer or 4, min=0, max=100, step=1,
          help='Se suma por cada jugador además del primero al empezar la pelea' },
    }
    for _, p in ipairs(extra or {}) do list[#list+1] = p end
    return list
end

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end
Boss.overlap = overlap

-- Los sonidos que un jefe le causa a un jugador (daño, muerte) se atribuyen
-- a ese jugador (online: su cliente los genera al ver bajar su vida). El
-- servidor pone aquí cómo hacerlo; en un jugador no hace falta.
function Boss.withPlayer(pa, fn)
    return require('src/entities/PlayerAdventure').asOwner(pa, fn)
end

-- ── Ciclo de vida ─────────────────────────────────────────────────────────────
function Boss:init()
    self.moving, self.flying, self.vx, self.vy = false, false, 0, 0
    self.state     = 'dormant'
    self.hpMax     = self.props.hp or 1
    self.hp        = self.hpMax
    self.inv       = 0
    self.ghost     = false
    self.deadTimer = 0
    self.blastN    = 0
    self:initBoss()
end

function Boss:startFight(nPlayers)
    local p = self.props
    self.hpMax = (p.hp or 1) + (p.hpPerPlayer or 0) * math.max(0, (nPlayers or 1) - 1)
    self.hp    = self.hpMax
    self.inv   = 0
    self.state, self.deadTimer = 'fight', 0
    self:onFightStart(nPlayers or 1)
end

function Boss:title() return (self.def.boss and self.def.boss.title) or self.def.label end

function Boss:isDying()
    local s = self.state
    return s == 'dying_hold' or s == 'dying_fall' or s == 'dead' or not self.alive
end

-- ¿Se le puede tocar / dañar ahora?
function Boss:isActive() return self.state ~= 'dormant' and not self:isDying() end
function Boss:isVulnerable() return self:isActive() end
function Boss:isInvulnerable() return self.inv > 0 end

-- Daño. Devuelve true si le hizo daño (no estaba invulnerable).
function Boss:damage(n, kind)
    if not self:isVulnerable() or self.inv > 0 then return false end
    local wasStunned = self:isStunned()
    self.hp = math.max(0, self.hp - (n or 1))
    Sound.play('bossHurt')
    Entity.emitFx('boss_hit', self.x, self.y)
    if self.hp <= 0 then self:defeat(); return true end
    if wasStunned then
        -- El único golpe que admite aturdido: se despierta, invulnerable un rato
        self.inv, self.ghost = self.STUN_INV, true
        self:endStun()
    elseif kind == 'pound' and self.stunnable then
        -- Ground pound: queda KO e invulnerable desde ya hasta después de
        -- despertar (nada de rematarlo mientras está KO)
        self.inv, self.ghost = self.STUN_INV, true
    else
        self.inv, self.ghost = self.INV_TIME, false
    end
    self:onDamaged(n or 1, kind)
    return true
end

function Boss:defeat()
    self.hp, self.inv = 0, 0
    self.state, self.deadTimer, self.blastN = 'dying_hold', 0, 0
    self.vx, self.vy = 0, 0
    self:onDefeat()
end

-- Interactions: pisotón (1) y ground pound (2)
function Boss:stomp() self:damage(1, 'stomp') end
function Boss:pound(pa)
    local wasStunned = self:isStunned()
    -- Solo aturde si no lo estaba ya (el golpe estando aturdido lo despierta)
    if self:damage(2, 'pound') and not self:isDying() and not wasStunned then self:onPounded(pa) end
end
function Boss:canBeStomped() return self:isVulnerable() end
function Boss:canBeKnocked() return self:isVulnerable() and self.inv <= 0 and not self:isStunned() end
function Boss:knockback(dir) self:onKnocked(dir) end
function Boss:isObstacle() return self.alive and not self:isDying() end
function Boss:isGhost() return false end
function Boss:collect() return false end

-- Reglas jugador ↔ jefe (sin efectos: ver Interactions.check)
function Boss:interact(pa)
    if not self:isActive() then return nil end
    if self.ghost and self.inv > 0 then return nil end     -- invulnerable largo: se atraviesan
    local pob, gob = pa:getOuterBounds(), self:getOuterBounds()
    if not overlap(pob, self:getInnerBounds()) then return nil end
    local pts = self.props.points or 0
    local bvy = -math.abs(ADV_JUMP_VEL) * self.BOUNCE
    -- El jugador le cae encima
    -- Invulnerable: rebota y sale despedido hacia un lado (no se puede
    -- quedar encima rebotando ni dejarse llevar)
    local immune = self.inv > 0 or not self:isVulnerable()
    local side = (pa.x >= self.x) and 1 or -1
    if pa.gpPhase == 'fall' and pob.y + pob.h * 0.5 < gob.y + gob.h * 0.5 then
        if immune then return 'bounce', bvy, side end
        return 'pound', bvy, pts
    end
    if pa.vy > 0 and pob.y + pob.h < gob.y + gob.h * 0.35 + 10 then
        if immune then return 'bounce', bvy, side end
        return 'stomp', bvy, pts
    end
    -- De lado no pasa nada: el cuerpo es sólido (lo resuelve la física)
    return nil
end

-- ¿Bloquea a los jugadores de lado? (vivo, sin morir y sin ser invulnerable:
-- invulnerable, jefe y jugadores se atraviesan)
function Boss:isSolidBody() return self.alive and not self:isDying() and self.inv <= 0 end

-- ── Update ────────────────────────────────────────────────────────────────────
function Boss:update(dt, level)
    if self.inv > 0 then self.inv = math.max(0, self.inv - dt) end
    if self.inv <= 0 then self.ghost = false end
    local st = self.state
    if st == 'dead' then self.alive = false; return end
    if st == 'dying_hold' then
        self.deadTimer = self.deadTimer + dt
        -- Explosiones alternando con el sonido de daño
        local n = math.floor(self.deadTimer / self.DEATH_BLAST_EVERY)
        while self.blastN <= n do
            Sound.play(self.blastN % 2 == 0 and 'bossExplode' or 'bossHurt', 0.9 + math.random() * 0.2)
            Entity.emitFx('boss_blast', self.x + (math.random() - 0.5) * self.sprW * 0.9,
                                        self.y + (math.random() - 0.5) * self.sprH * 0.8)
            self.blastN = self.blastN + 1
        end
        if self.deadTimer >= self.DEATH_HOLD then
            self.state, self.deadTimer = 'dying_fall', 0
            self.vy, self.deathY = 0, self.y
            self:onDeathFall()
        end
        return
    elseif st == 'dying_fall' then
        self.deadTimer = self.deadTimer + dt
        if self.deadTimer >= self.DEATH_FREEZE then
            if self.vy == 0 then self.vy = self.DEATH_JUMP_VEL end
            self.vy = self.vy + ADV_GRAVITY * dt
            self.y  = self.y + self.vy * dt
            if self.y > self.deathY + WINDOW_H + 140 then
                self.state = 'dead'
                self.alive = false
            end
        end
        return
    end
    self:updateBoss(dt, level)
end

-- ¿Se dibuja en rojo ahora? (tras un golpe y mientras explota)
function Boss:flashRed()
    if self.state == 'dying_hold' or (self.inv > 0 and not self.ghost) then
        return math.floor(love.timer.getTime() * 12) % 2 == 0
    end
    return false
end

-- Transparencia al dibujar: parpadea mientras dura la invulnerabilidad larga
function Boss:ghostAlpha()
    if self.ghost and self.inv > 0 and math.floor(love.timer.getTime() * 15) % 2 == 0 then return 0.3 end
    return 1
end

-- ── Red ───────────────────────────────────────────────────────────────────────
function Boss:netPack()
    local out = { self.hp, self.hpMax, math.floor(self.inv * 100 + 0.5), self.ghost and 1 or 0 }
    for _, v in ipairs(self:netPackExtra() or {}) do out[#out+1] = v end
    return out
end

function Boss:netApply(a, b, f)
    a = a or b
    if type(b[1]) == 'number' then self.hp = b[1] end
    if type(b[2]) == 'number' then self.hpMax = b[2] end
    if type(b[3]) == 'number' then self.inv = b[3] / 100 end
    self.ghost = b[4] == 1
    local xa, xb = {}, {}
    for k = 5, #b do xb[#xb+1] = b[k]; xa[#xa+1] = a[k] end
    self:netApplyExtra(xa, xb, f)
end

-- ── Hooks por defecto ─────────────────────────────────────────────────────────
Boss.stunnable = false                        -- ¿el ground pound lo deja KO? (Mirror: sí)
function Boss:isStunned() return false end   -- p. ej. estado 'ko'
function Boss:endStun() end                  -- se despierta (tras su único golpe)
function Boss:initBoss() end
function Boss:updateBoss(dt, level) end
function Boss:onFightStart(n) end
function Boss:onDamaged(n, kind) end
function Boss:onDefeat() end
function Boss:onDeathFall() Sound.play('bossExplode') end
function Boss:onPounded(pa) end
function Boss:onKnocked(dir) end
function Boss:onPlayerDeath(pa) end
function Boss:netPackExtra() return nil end
function Boss:netApplyExtra(a, b, f) end

return Boss
