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
-- 'intro' / 'ready' (su entrada, ver abajo), 'fight', 'dying_hold',
-- 'dying_fall', 'dead'. Los tipos añaden los suyos.
--
-- ENTRADA (cinemática antes de la pelea, genérica): un jefe con
-- `Cls.introLength` (s, o la función introLength(self)) tiene entrada. Cuando
-- todos los jugadores están en su zona, la zona pasa a 'intro' (jugadores
-- congelados e invulnerables, sin música, cámara centrada en el jefe, franjas
-- de cine con su nombre: BossZones / BossHud) y el jefe pasa a 'intro':
--   onIntroStart(level, players)  -- colocarse (fuera de pantalla...), sonidos
--   updateIntro(dt, level, t)     -- animar la entrada (t = deadTimer); sin
--                                 -- tocar a nadie. Al llegar a introLength
--                                 -- pasa solo a 'ready' y empieza la pelea.
--   introFocus()                  -- (opcional) x, y donde mira la cámara
-- En 'intro'/'ready' no se le puede tocar ni es sólido. Todo lo que dibuje
-- debe salir de su estado + deadTimer (+ x, y): llega igual por red.
-- (El Mega Crabby tiene su propia entrada, con estados propios.)
-- Hooks: initBoss, updateBoss, isStunned, endStun, onFightStart(n), onDamaged(n, kind),
-- onDefeat, onDeathFall, onPounded(pa), onKnocked(dir), onPlayerDeath(pa),
-- isVulnerable, isSolidBody.

local Entity = require 'src/world/entities/Entity'
local Lang = require 'src/Lang'

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
        -- Nombre propio en este nivel, en cada idioma (como el nombre del nivel: Nivel → General)
        { key='title', kind='text', label='Nombre en la barra (español)', group='Nombre', default='', maxLen=28,
          help='Vacío = el nombre de siempre del jefe (traducido). En MAYÚSCULAS, como las barras' },
        { key='title_en', kind='text', label='Nombre en inglés', group='Nombre', default='', maxLen=28,
          help='Vacío = el nombre en español de arriba (o el de siempre si tampoco hay)' },
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
    -- (la dificultad: más o menos vida — src/Difficulty.lua; su ritmo va con Difficulty.dt)
    local D = require 'src/Difficulty'
    local k = D.k('bossHp') * (p.xtraPair and D.k('pairHp') or 1)      -- (dos a la vez: cada uno con menos vida)
    self.hpMax = math.max(1, math.floor(self.hpMax * k + 0.5))
    self.hp    = self.hpMax
    self.inv   = 0
    self.state, self.deadTimer = 'fight', 0
    self:onFightStart(nPlayers or 1)
end

-- Nombre en la barra (y en la entrada): el que le puso el nivel en su idioma (props title /
-- title_en), si no la clave de idioma boss.<tipo>; si no, def.boss.title (Lang.bossName)
function Boss:title()
    return Lang.bossName(self.def.name, self.props) or (self.def.boss and self.def.boss.title) or self.def.label
end

function Boss:isDying()
    local s = self.state
    return s == 'dying_hold' or s == 'dying_fall' or s == 'dead' or not self.alive
end

-- ── Entrada genérica ─────────────────────────────────────────────────────────
local INTRO = { intro = true, ready = true }
Boss.INTRO = INTRO
function Boss:introTime()
    local l = self.introLength
    if type(l) == 'function' then return l(self) end
    return l
end
function Boss:hasIntro() return self.zone ~= nil and self:introTime() ~= nil end
function Boss:startIntro(level, players, z)
    self.zone = self.zone or z
    self.state, self.deadTimer = 'intro', 0
    self:onIntroStart(level, players)
end
function Boss:introDone() return self.state == 'ready' end
function Boss:inIntro() return INTRO[self.state] == true end

-- ¿Se le puede tocar / dañar ahora?
function Boss:isActive() return self.state ~= 'dormant' and not INTRO[self.state] and not self:isDying() end
function Boss:isVulnerable() return self:isActive() end
function Boss:isInvulnerable() return self.inv > 0 end

-- Daño. Devuelve true si le hizo daño (no estaba invulnerable).
function Boss:damage(n, kind)
    if not self:isVulnerable() or self.inv > 0 then return false end
    local wasStunned = self:isStunned()
    self.hp = math.max(0, self.hp - (n or 1))
    Sound.play(self.hurtSound or 'bossHurt')
    Entity.emitFx('boss_hit', self.x, self.y)
    require('src/world/Noise').emit(self.x, self.y, require('src/world/Noise').R.hit)   -- (dar un golpe se oye: niveles a oscuras)
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

-- ── Utilidades comunes de los jefes (antes cada uno traía su copia) ──────────
-- Cambio de estado: estado nuevo y su reloj a 0 (lo que se dibuja sale de state + deadTimer)
function Boss:enter(st) self.state, self.deadTimer = st, 0 end
-- Su zona (x0, x1, y0, y1); sin zona, un recuadro alrededor de donde está
function Boss:zoneBounds()
    local z = self.zone
    if z then return z.x0, z.x1, z.y0, z.y1 end
    local T = TILE_PX
    return self.x - 12 * T, self.x + 12 * T, self.y - 8 * T, self.y + 2 * T
end
-- Sus súbditos de reserva (los que el nivel creó para él: `summons` del tipo; self.summonKey)
function Boss:minions(level)
    local out = {}
    for _, e in ipairs(level.liveEntities or {}) do
        if e.summonOf == self.summonKey then out[#out + 1] = e end
    end
    return out
end
-- El jugador vivo más cercano (lo vertical cuenta menos) y su distancia
function Boss:nearestPlayer(level)
    local best, bd
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false then
            local d = math.abs(pa.x - self.x) + math.abs(pa.y - self.y) * 0.3
            if not bd or d < bd then best, bd = pa, d end
        end
    end
    return best, bd
end
-- Golpe del jefe a un jugador: hit = { vida, vx, vy, s sin control, s aturdido }, dir = ±1.
-- false si no le da (invulnerable, muriendo). El daño queda atribuido (Boss.withPlayer).
function Boss.strike(pa, hit, dir)
    if pa.dying or pa.alive == false or pa:isInvulnerable() then return false end
    Boss.withPlayer(pa, function()
        if pa:hurt(hit[1]) or pa.dying then return end
        pa.vx, pa.vy = dir * hit[2], hit[3]
        pa.onGround, pa.crouching = false, false
        pa.gpPhase, pa.gpT = nil, 0
        pa.ctrlLockT = math.max(pa.ctrlLockT or 0, hit[4])
        if hit[5] > 0 then
            pa.stunT = math.max(pa.stunT or 0, hit[5])
            Sound.play('stunned')
        end
    end)
    return true
end
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
function Boss:isSolidBody()
    return self.alive and not self:isDying() and self.inv <= 0 and self.state ~= 'dormant' and not INTRO[self.state]
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Boss:update(dt, level)
    if self.inv > 0 then self.inv = math.max(0, self.inv - dt) end
    if self.inv <= 0 then self.ghost = false end
    local st = self.state
    if st == 'dead' then self.alive = false; return end
    if st == 'intro' then
        self.deadTimer = self.deadTimer + dt
        self:updateIntro(dt, level, self.deadTimer)
        if self.deadTimer >= (self:introTime() or 0) then self.state, self.deadTimer = 'ready', 0 end
        return
    elseif st == 'ready' then
        self.deadTimer = self.deadTimer + dt
        self:updateIntro(dt, level, (self:introTime() or 0) + self.deadTimer)
        return
    end
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
    -- (con un ALIADO en la zona — Xtra extremo —: se turnan y no se pisan)
    if self:inFight() then self.fightT = (self.fightT or 0) + dt end
    self:updateBoss(dt, level)
    if self.props and self.props.xtraPair then self:trackAttack() end
end

-- ── ALIADOS: dos jefes en la misma zona (Xtra extremo, src/world/XtraBosses.lua) ─────────────────────
-- Genérico para todos: cada tipo solo dice qué estados son ATAQUE (`ATTACKS = { estado = true }`, en su
-- tuning) y pregunta Boss:mayAttack donde decide atacar.
--   * SE TURNAN: un jefe solo EMPIEZA un ataque si su aliado no está atacando ni acaba de hacerlo (`ALLY_GAP`
--     s: un respiro para el jugador) — Boss:mayAttack, que cada tipo pregunta donde decide atacar (sus relojes
--     siguen corriendo: en cuanto le toca, ataca). La copia no ataca hasta `ALLY_START` s.
--   * Nada más, A PROPÓSITO: se mueven a su ritmo y se atraviesan. Se probó que chocaran / se apartaran
--     (empujones, cargas cortadas) y frenar al que espera (quedaban flotando a cámara lenta): más problemas que
--     ventajas (el usuario).
-- Todo esto es simulación (un jugador y servidor); el cliente lo ve en los snapshots.
Boss.ALLY_START, Boss.ALLY_GAP = 2.5, 0.8

function Boss:allies(level)
    local out = {}
    if not self.zone then return out end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.zone == self.zone and e.alive and e.isDying and not e:isDying() and e.def
           and e.def.category == 'Jefes' then
            out[#out + 1] = e
        end
    end
    return out
end
-- ¿En plena pelea? (la zona luchando; no en su entrada, que cada jefe hace a su manera)
function Boss:inFight() return self.zone ~= nil and self.zone.state == 'fight' and self:isActive() end
-- (la tabla va en el `tuning` del tipo: Entity.extend(Boss, { ATTACKS = { estado = true, ... } }))
function Boss:isAttacking()
    local a = self.tuning and self.tuning.ATTACKS
    return a ~= nil and a[self.state] == true
end

-- Cuándo empezó / acabó su último ataque (para los turnos con un aliado)
function Boss:trackAttack()
    local now = self:isAttacking()
    if now and not self._wasAttacking then self.attackSince = self.fightT or 0 end
    if not now and self._wasAttacking then self.attackEnd = self.fightT or 0 end
    self._wasAttacking = now
end

-- ¿Puede EMPEZAR un ataque ya? (cada tipo lo pregunta donde decide atacar). Con un aliado: no mientras el
-- otro ataca ni hasta `ALLY_GAP` s después (un respiro para el jugador), y la copia no antes de `ALLY_START`.
-- Sin aliado, siempre. Los relojes de sus ataques siguen corriendo: en cuanto le toca, ataca.
function Boss:mayAttack(level)
    if not (self.props and self.props.xtraPair) or not self:inFight() then return true end
    local t = self.fightT or 0
    if self.props.xtraCopy and t < Boss.ALLY_START then return false end
    for _, a in ipairs(self:allies(level)) do
        if a:isActive() and ((a.isAttacking and a:isAttacking()) or (a.attackEnd and t - a.attackEnd < Boss.ALLY_GAP)) then
            return false
        end
    end
    return true
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
    for k = 5, #b do xb[#xb+1] = b[k] end
    for k = 5, #a do xa[#xa+1] = a[k] end      -- (a puede ser más largo: listas de proyectiles)
    self:netApplyExtra(xa, xb, f)
end

-- ── Hooks por defecto ─────────────────────────────────────────────────────────
Boss.stunnable = false                        -- ¿el ground pound lo deja KO? (Mirror: sí)
Boss.hurtSound = 'bossHurt'                   -- sonido al recibir un golpe (cada jefe el suyo)
function Boss:bossPhase() return 1 end        -- fase de la pelea (1..): la zona la usa (BossZones)
function Boss:isStunned() return false end   -- p. ej. estado 'ko'
function Boss:endStun() end                  -- se despierta (tras su único golpe)
function Boss:initBoss() end
function Boss:updateBoss(dt, level) end
function Boss:onFightStart(n) end
function Boss:onIntroStart(level, players) end
function Boss:updateIntro(dt, level, t) end
function Boss:onDamaged(n, kind) end
function Boss:onDefeat() end
function Boss:onDeathFall() Sound.play('bossExplode') end
function Boss:onPounded(pa) end
function Boss:onKnocked(dir) end
function Boss:onPlayerDeath(pa) end
function Boss:netPackExtra() return nil end
function Boss:netApplyExtra(a, b, f) end

return Boss
