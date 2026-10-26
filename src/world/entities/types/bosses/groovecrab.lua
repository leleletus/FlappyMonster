-- Jefe secreto EL GROOVE (types/groovecrab.lua): un Crabby trampolín gigante — un CANGREJO VIOLINISTA (pinza grande y
-- pinza pequeña) con gafas de sol y el trampolín del juego en la espalda — que PELEA AL RITMO DE SU TEMA (`groove`,
-- tools/music/slap_boss.py: el slap bass de protagonista). Se abre en el mapa tras vencer al Espejo
-- (docs/bosses/groovecrab.md). Arte propio: tools/art/bosses/make_groove_crab.py.
--
-- EL RELOJ ES LA CANCIÓN: `songT` = el tiempo desde que empezó la pelea (la música de la zona empieza en ese mismo
-- instante y sigue sonando al reaparecer). De él sale en qué SECCIÓN, compás y semicorchea está (tabla SONG: la
-- partitura del tema, 150 BPM: intro 8 compases + bucle A 16 · B 16 · SOLO 8 · SUBIDA 8 · CLÍMAX 16 · VUELTA 4), y de
-- eso, qué hace. No le afecta el ritmo de la dificultad (def.pace = false): todo cae en el compás.
--   · SALTO (A, la subida, compases impares del clímax, la vuelta): se AGACHA con una diana en el suelo que te sigue
--     (fija en la semicorchea 6), SALTA en el tercer tiempo y CAE en el siguiente compás justo en el bombo: dos ONDAS DE
--     ARENA por el suelo, una a cada lado (se saltan; base/BossWaves.lua). Un salto es pura función del tiempo.
--   · NOTAS (B y compases pares del clímax): alza la pinza grande y, en los POPS del bajo, chasquea y dispara una NOTA
--     (corchea de colores) hacia ti; va recta. Entre chasquido y chasquido se te acerca andando.
--   · POSE (la ÚNICA apertura): en los golpes de banda que cierran cada frase (último compás de cada 4, desde el cuarto
--     tiempo hasta el segundo del compás siguiente) y en el SOLO (cada golpe: el compás entero). Esconde el trampolín
--     y alza la pinza: pisotón 1, ground pound 2, un golpe por pose (luego 'hurt': saca el trampolín de golpe y aparta
--     sin daño). En el SOLO, entre pose y pose da un saltito que cae justo en el golpe siguiente.
--   · El resto del tiempo, su TRAMPOLÍN te lanza muy alto si le caes encima (también con ground pound): así se llega
--     arriba a tiempo para la pose. Tocar su cuerpo = 1 de vida y empujón (posando, no); las PINZAS no hacen daño.
--   · ENFADADO (por debajo de `rageAt`; en Xtra extremo desde el principio): salta en todos los compases que puede y
--     dispara más notas. Vida 10 (+4 por jugador).
-- Entrada: cae del cielo en su sitio, chasquea dos veces las pinzas y rebota en su trampolín. Derrota: aturdido
-- (estrellitas) y se va de un BOTE enorme en su trampolín hacia el cielo (pura función del tiempo). Sin fragmento.
-- Todo lo que se dibuja sale de state + deadTimer + x, y + netPackExtra (songT, diana, ondas, notas): igual online.

local Entity = require 'src/world/entities/base/Entity'
local Boss   = require 'src/world/entities/base/Boss'
local BossFx = require 'src/fx/BossFx'
local BossWaves = require 'src/world/entities/base/BossWaves'
local SpriteStrip = require 'src/fx/SpriteStrip'

local GC = Entity.extend(Boss, {
    ATTACKS  = { crouch = true, hop = true, snap = true },
    OPENINGS = { pose = true },
    debugColor = { 0.3, 0.9, 0.85 },
    -- (la caja: SOLO el caparazón y las patas — 14 de los 18 px de ancho, sin las pinzas, que no hacen daño —; de
    -- alto, todo el cuerpo)
    hitbox = { outerW = 0.78, outerH = 1.0, innerW = 0.66, innerH = 0.7 },
})
GC.hurtSound   = 'megaHurt'
GC.introLength = 3.6
GC.wantsLevel  = true
local strike, overlap = Boss.strike, Boss.overlap

local T  = TILE_PX
local MS = 10                                   -- escala del pixel art (los Crabbies: 4)
local FW, FH = 18, 10                           -- el cuerpo: 18x10 (caparazón 7 filas + patas)
GC.MS = MS

-- ── LA CANCIÓN (tools/music/slap_boss.py; si cambia la partitura, cambia esto) ──
local S16 = 0.1                                 -- 150 BPM: semicorchea
local BAR = 16 * S16
local INTRO_BARS = 8
local SONG = { { 'A', 16 }, { 'B', 16 }, { 'K', 8 }, { 'S', 8 }, { 'C', 16 }, { 'O', 4 } }
local LOOP = 0
for _, s in ipairs(SONG) do LOOP = LOOP + s[2] end
GC.S16, GC.BAR, GC.INTRO_BARS, GC.LOOP = S16, BAR, INTRO_BARS, LOOP
-- Las notas: en los POPS del bajo de cada compás de la B (y de la 2ª mitad del clímax, que es la B)
local B_NOTES = { { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 10 }, { 4, 8 }, {},
                  { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 8 }, { 4, 10 }, { 4, 8 }, { 6 } }
local C_NOTES = { [2] = { 11 }, [6] = { 11 } }  -- (1ª mitad del clímax: el pop del final del riff)
local POSE_AT   = 12                            -- semicorchea en que posa al cerrar la frase (el golpe de banda)
local POSE_TAIL = 4                             -- ... hasta esta semicorchea del compás siguiente
local CROUCH_LOCK = 6                           -- la diana se fija aquí; salta en la 8 y cae en la 0 siguiente
local MIN_WARN = 0.3                            -- s mínimos agachado (con la diana a la vista) para saltar

-- Saltos
local HOP_H, LICK_H = 3.2 * T, 1.4 * T          -- altura de un salto y de un saltito del solo
local HOP_DUR = 8 * S16                         -- de la semicorchea 8 a la 0 del compás siguiente
local WALK_SPD = 70                             -- px/s acercándose entre notas
local NOTE_SPD = { 330, 390 }                   -- { normal, enfadado }
local NOTE_R = 16                               -- media caja de una nota
local NOTE_LIFE = 4.0
local LAUNCH = 1.85                             -- × la velocidad de salto: lo que lanza el trampolín
local HURT_T = 0.45
local GRACE  = 0.8

-- Golpes a los jugadores: { vida, vx, vy, s sin control, s aturdido }
local HIT_TOUCH = { 1, 480, -420, 0.2, 0 }
local HIT_NOTE  = { 1, 300, -340, 0.15, 0 }
local HIT_SHOVE = { 0, 520, -420, 0.2, 0 }
local WAVES = { spd = 470, life = 2.0, w = 44, h = 34, hit = { 1, 300, -440, 0.15, 0 } }

-- Muerte
local DAZE_T = 2.2
local FLEE_VX, FLEE_VY, FLEE_G = 120, -2100, 1500
local FLEE_MIN = 1.5
local DEATH = { dying_daze = true, dying_flee = true }

-- ── Arte ──
local DIR = 'assets/images/bosses/groovecrab/'
local art
function GC.loadAssets()
    if art or not (love and love.graphics) then return end
    art = { body = SpriteStrip.load(DIR .. 'body-Sheet.png', FW), big = SpriteStrip.load(DIR .. 'bigclaw-Sheet.png', 12),
            small = SpriteStrip.load(DIR .. 'claw-Sheet.png', 7), tramp = SpriteStrip.load(DIR .. 'tramp.png', 16),
            note = SpriteStrip.load(DIR .. 'note-Sheet.png', 9), wave = SpriteStrip.load(DIR .. 'wave-Sheet.png', 12) }
end
function GC.sizePx() return FW * MS, FH * MS end

function GC:feetY() return self.y + self.outerH / 2 end
function GC:bossPhase() return self.rage and 2 or 1 end
-- (su "fase enfadada" es la del ritmo: el enfado genérico de Xtra extremo, que acelera, rompería el compás)
function GC:angryPhase() return true end

function GC:initBoss()
    self.floorY = self.row * T                         -- (los pies: de pie en el suelo de su celda; la arena es llana)
    self.y = self.floorY - self.outerH / 2
    self.vx, self.vy, self.onGround = 0, 0, true
    self.facing = -1
    self.rage = false
    self.songT, self.prevT = 0, 0
    self.waves, self.nextId = {}, 0
    self.notes, self.noteId = {}, 0
    self.graceT = 0
    self.markX = math.floor(self.x)
end

function GC:onFightStart(n)
    self.songT, self.prevT = 0, -1e-6
    self.rage = require('src/core/Difficulty').flag('bossFury') == true
    self:enter('groove')
end

-- ── Dónde va la canción ───────────────────────────────────────────────────────
-- → compás absoluto (0…), sección, compás dentro de ella (1…), semicorchea (0…16, con decimales)
function GC.where(st)
    local b = math.floor(st / BAR)
    local step = (st - b * BAR) / S16
    if b < INTRO_BARS then return b, 'I', b + 1, step end
    local lb = (b - INTRO_BARS) % LOOP
    for _, s in ipairs(SONG) do
        if lb < s[2] then return b, s[1], lb + 1, step end
        lb = lb - s[2]
    end
end

-- ¿Posa en el compás (sec, k)? → semicorchea en que empieza (0 = el compás entero, el solo), o nil
local PHRASE = { A = true, B = true, S = true, C = true }
function GC.poseStart(sec, k)
    if PHRASE[sec] and k % 4 == 0 then return POSE_AT end
    if sec == 'K' and k % 2 == 1 then return 0 end
    return nil
end

-- Lo que hace en un compás: { hop = true | lick = true, notes = { semicorcheas } }
function GC.plan(sec, k, rage)
    local p = { notes = {} }
    local posing = GC.poseStart(sec, k) ~= nil
    if sec == 'I' then
        p.hop = k == 5 or k == 7
    elseif sec == 'A' or sec == 'S' then
        p.hop = not posing and (sec == 'S' or rage or k % 2 == 1)
    elseif sec == 'B' then
        p.notes = B_NOTES[k] or {}
        if rage and not posing and k % 2 == 1 then p.notes = { 4, 8, 12 } end
    elseif sec == 'C' then
        if k % 2 == 1 then p.hop = true
        elseif k <= 8 then
            p.notes = C_NOTES[k] or {}
            if rage and not posing then p.notes = { 6, 11 } end
        else p.notes = B_NOTES[k] or {} end
    elseif sec == 'K' then
        p.lick = k % 2 == 0
    elseif sec == 'O' then
        p.hop = k % 2 == 1
    end
    return p
end

-- La pose que manda AHORA (id = compás absoluto en que empezó) o nil
function GC:poseNow(b, sec, k, step)
    local s0 = GC.poseStart(sec, k)
    if s0 and step >= s0 then return b end
    if b > 0 then                                                       -- (la cola de la del compás anterior)
        local pb, psec, pk = GC.where((b - 1) * BAR + 1e-6)
        local ps = GC.poseStart(psec, pk)
        if ps and ps > 0 and step < POSE_TAIL then return pb end
    end
    return nil
end

-- ¿El compás `b` empieza en la cola de una pose? (entonces se agacha más tarde)
local function afterPose(b)
    if b <= 0 then return false end
    local _, psec, pk = GC.where((b - 1) * BAR + 1e-6)
    local ps = GC.poseStart(psec, pk)
    return ps ~= nil and ps > 0
end

-- ── Golpes a los jugadores ───────────────────────────────────────────────────
-- Tocar su CUERPO (caparazón y patas) quita 1 y empuja; las PINZAS no hacen daño (el usuario: "es injusto, ningún Mega
-- funciona así"): la caja es solo el cuerpo (hitbox outerW) y no se agranda. Encima, no (es pisarlo o el trampolín)
function GC:touch(level)
    if self.graceT > 0 then return end
    local b = self:getOuterBounds()
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and not pa:isInvulnerable() then
            local pb = pa:getOuterBounds()
            local onTop = pb.y + pb.h <= b.y + 14 and (pa.vy or 0) >= -50
            if not onTop and overlap(pb, b) and strike(pa, HIT_TOUCH, (pa.x >= self.x) and 1 or -1) then
                self.graceT = GRACE
            end
        end
    end
end

-- ── El trampolín de la espalda ───────────────────────────────────────────────
function GC:trampOut() return self:isActive() and self.state ~= 'pose' end
function GC:trampBox()
    local b = self:getOuterBounds()
    local w = 14 * MS
    return { x = self.x - w / 2, y = b.y - 9 * MS, w = w, h = 9 * MS + 8 }
end

-- (sin efectos: el cliente online lo usa para predecir)
function GC:interact(pa)
    if not self:isActive() then return nil end
    if self:trampOut() and (pa.vy or 0) > 0 then
        local tb, pob = self:trampBox(), pa:getOuterBounds()
        if overlap(pob, tb) and pob.y + pob.h <= tb.y + tb.h then
            return 'launch', 0, -math.abs(ADV_JUMP_VEL) * LAUNCH
        end
    end
    return Boss.interact(self, pa)
end
function GC:onLaunch(pa)
    Sound.play('trampoline', 0.9, 0.8)
    self.boingAt = love and love.timer and love.timer.getTime() or 0      -- (solo el dibujo: el muelle se mece)
end

-- ── Notas ─────────────────────────────────────────────────────────────────────
-- (de la punta de la pinza grande, que va por delante, hacia el jugador más cercano)
function GC:clawTip()
    local f = self.facing or 1
    return self.x + f * 15 * MS, self:feetY() - 9 * MS
end
function GC:fireNote(level)
    local pa = self:nearestPlayer(level)
    if not pa then return end
    local x, y = self:clawTip()
    local dx, dy = pa.x - x, (pa.y - 6) - y
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    local spd = NOTE_SPD[self.rage and 2 or 1]
    self.noteId = self.noteId % 999 + 1
    self.notes[#self.notes + 1] = { id = self.noteId, x = x, y = y, vx = dx / d * spd, vy = dy / d * spd, t = 0,
                                    c = self.noteId % 4 }
    Sound.play('megaClack', 0.8, 1.25)
end
function GC:noteBox(n) return { x = n.x - NOTE_R, y = n.y - NOTE_R, w = 2 * NOTE_R, h = 2 * NOTE_R } end
function GC:updateNotes(level, dt)
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    for i = #self.notes, 1, -1 do
        local n = self.notes[i]
        n.t = n.t + dt
        n.x, n.y = n.x + n.vx * dt, n.y + n.vy * dt
        local gone = n.t >= NOTE_LIFE or n.x < zx0 - T or n.x > zx1 + T or n.y < zy0 - 3 * T or n.y > zy1 + T
        if not gone then
            local box = self:noteBox(n)
            for _, pa in ipairs(level.players or {}) do
                if overlap(pa:getOuterBounds(), box) and strike(pa, HIT_NOTE, n.vx >= 0 and 1 or -1) then gone = true end
            end
        end
        if gone then table.remove(self.notes, i) end
    end
end

-- ── Estados que sabe hacer el cuerpo ─────────────────────────────────────────
function GC:isActive() return Boss.isActive(self) and not DEATH[self.state] end
function GC:isDying() return DEATH[self.state] == true or Boss.isDying(self) end
function GC:isVulnerable() return self:isActive() and self.state == 'pose' end
function GC:releasesZone() return self.state == 'dying_flee' or self.state == 'dead' end
function GC:shardDrop() return false end                                -- (jefe secreto: no guarda fragmento)
function GC:isSolidBody() return Boss.isSolidBody(self) and not DEATH[self.state] end
function GC:canBeKnocked() return false end

-- Tras un golpe (uno por pose): saca el trampolín de golpe y aparta a quien tenga al lado
function GC:onDamaged(n, kind)
    if self:isDying() then return end
    self.poseHit = self.poseId
    if not self.rage and self.hp <= self.hpMax * (self.props.rageAt or 0.5) then
        self.rage = true
        Entity.emitFx('shake_roar', self.x, self.y)
        Sound.play('megaRoar', 0.6)
    end
    self:enter('hurt')
    Sound.play('trampoline', 0.8, 0.6)
    for _, pa in ipairs((self.levelRef or {}).players or {}) do
        if math.abs(pa.x - self.x) < 3 * T and math.abs(pa.y - self.y) < 3 * T then
            strike(pa, HIT_SHOVE, (pa.x >= self.x) and 1 or -1)
        end
    end
end

function GC:defeat()
    self.hp, self.inv, self.ghost = 0, 0, false
    self.waves, self.notes, self.hop = {}, {}, nil
    self.y = self.floorY - self.outerH / 2
    self:enter('dying_daze')
    Sound.play('megaHurt', 0.9)
    Sound.play('stunned')
    self:onDefeat()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function GC:faceTo(x) if math.abs(x - self.x) > 8 then self.facing = (x > self.x) and 1 or -1 end end
function GC:set(st) if self.state ~= st then self:enter(st) end end

function GC:aimMark(level)
    local zx0, zx1 = self:zoneBounds()
    local hw = self.outerW / 2 + 8
    local pa = self:nearestPlayer(level)
    local x = pa and pa.x or self.x
    self.markX = math.floor(math.max(zx0 + hw, math.min(zx1 - hw, x)))
end

function GC:land(lick)
    self.x, self.y = self.hop.x1, self.floorY - self.outerH / 2
    self.hop = nil
    Entity.emitFx('gp_land', self.x, self.floorY)
    if lick then
        Sound.play('megaStep', 0.8)
        Entity.emitFx('shake_small', self.x, self.y)
    else
        BossWaves.spawn(self, self.floorY, self.outerW / 2)
        Sound.play('megaSlam', 0.7)
        Sound.play('gpImpact', 0.6)
        Entity.emitFx('shake_big', self.x, self.y)
    end
    self:set('groove')
end

function GC:updateBoss(dt, level)
    if self.state == 'dormant' then return end
    self.levelRef = self.levelRef or level
    self.deadTimer = self.deadTimer + dt
    if self.graceT > 0 then self.graceT = math.max(0, self.graceT - dt) end
    BossWaves.update(self, level, dt, WAVES)
    self:updateNotes(level, dt)
    local st, t = self.state, self.deadTimer

    if st == 'dying_daze' then
        if t >= DAZE_T then
            self.fleeDir = self:fleeSide(level)
            self.fleeX0, self.fleeY0, self.fleeing = self.x, self.y, true
            Sound.play('trampoline', 1, 0.5)
            Entity.emitFx('gp_land', self.x, self.floorY)
            self:enter('dying_flee')
        end
        return
    elseif st == 'dying_flee' then
        -- un BOTE enorme en su trampolín hacia el cielo (sin choques: pura función del tiempo)
        self.x = self.fleeX0 + self.fleeDir * FLEE_VX * t
        self.y = self.fleeY0 + FLEE_VY * t + 0.5 * FLEE_G * t * t
        self.vx, self.vy = self.fleeDir * FLEE_VX, FLEE_VY + FLEE_G * t
        if self:fleeOver(level, dt, t, FLEE_MIN) then self.state, self.alive = 'dead', false end
        return
    end
    self.prevT, self.songT = self.songT, self.songT + dt
    local b, sec, k, step = GC.where(self.songT)
    local pb, _, _, pstep = GC.where(math.max(0, self.prevT))
    local crossed = function(s) return pb == b and pstep < s and step >= s end
    local plan = GC.plan(sec, k, self.rage)

    -- En el aire: el salto sigue hasta caer en su compás
    if self.hop then
        local u = (self.songT - self.hop.t0) / HOP_DUR
        if u >= 1 then self:land(self.hop.lick)
        else
            self.x = self.hop.x0 + (self.hop.x1 - self.hop.x0) * u
            self.y = self.floorY - self.outerH / 2 - self.hop.h * 4 * u * (1 - u)
            self:set('hop')
            self:touch(level)
            return
        end
    end

    -- La POSE (la apertura): mientras dure y no le hayan dado ya en esta
    local pid = self:poseNow(b, sec, k, step)
    if pid and pid ~= self.poseHit then
        if self.state ~= 'pose' then
            self.poseId = pid
            Sound.play('crabPop', 0.9, 0.8)
        end
        self:set('pose')
        return
    end
    if self.state == 'hurt' and t < HURT_T then return end

    -- El SALTO: agachado (la diana te sigue hasta la semicorchea 6), salta en la 8
    if plan.hop or plan.lick then
        local c0 = afterPose(b) and POSE_TAIL or 0
        if step >= c0 and step < 8 then
            if self.state ~= 'crouch' then Sound.play('megaWindup', plan.lick and 0.3 or 0.5) end
            if step < CROUCH_LOCK then self:aimMark(level) end
            self:faceTo(self.markX)
            self:set('crouch')
            self:touch(level)
            return
        end
        -- (sin al menos MIN_WARN s agachado —venía de un golpe— no salta: la diana tiene que verse)
        if crossed(8) and self.state == 'crouch' and self.deadTimer >= MIN_WARN then
            self.hop = { t0 = b * BAR + 8 * S16, x0 = self.x, x1 = self.markX, h = plan.lick and LICK_H or HOP_H,
                         lick = plan.lick == true }
            Sound.play('trampoline', 0.7, plan.lick and 0.9 or 0.7)
            self:set('hop')
            return
        end
    end

    -- Las NOTAS, en los pops del bajo; entre una y otra se acerca andando
    local last = plan.notes[#plan.notes]
    for _, s in ipairs(plan.notes) do if crossed(s) then self:fireNote(level) end end
    local pa = self:nearestPlayer(level)
    if pa then self:faceTo(pa.x) end
    if last and step < last + 2 then
        self:set('snap')
    else
        self:set('groove')
        if pa and (sec == 'B' or sec == 'C') and math.abs(pa.x - self.x) > 2.5 * T then
            local zx0, zx1 = self:zoneBounds()
            local hw = self.outerW / 2 + 8
            self.x = math.max(zx0 + hw, math.min(zx1 - hw, self.x + self.facing * WALK_SPD * dt))
        end
    end
    self:touch(level)
end

-- ── Entrada: cae del cielo, chasquea dos veces y rebota en su trampolín ──
local FALL_AT, LAND_AT, SNAP1, SNAP2, BOING = 0.3, 1.0, 1.7, 2.1, 2.8
GC.LAND_AT = LAND_AT
function GC:introFocus()
    local zx0, zx1, zy0, zy1 = self:zoneBounds()
    return (zx0 + zx1) / 2, (zy0 + zy1) / 2
end
function GC:onIntroStart(level, players)
    self.introStep = 0
    self.levelRef = self.levelRef or level
end
function GC:updateIntro(dt, level, t)
    local hy = self.floorY - self.outerH / 2
    local _, _, zy0 = self:zoneBounds()
    self.x = self.home.x
    if t < LAND_AT then
        local y0 = zy0 - 3 * self.outerH
        local u = math.max(0, (t - FALL_AT) / (LAND_AT - FALL_AT))
        self.y = (t < FALL_AT) and y0 or (y0 + (hy - y0) * u * u)
        return
    end
    self.y = hy
    if self.introStep < 1 then
        self.introStep = 1
        Sound.play('megaSlam', 0.7)
        Entity.emitFx('gp_land', self.x, self.floorY)
        Entity.emitFx('shake_big', self.x, self.y)
    end
    if t >= SNAP1 and self.introStep < 2 then self.introStep = 2; Sound.play('megaClack', 0.8, 1.2) end
    if t >= SNAP2 and self.introStep < 3 then self.introStep = 3; Sound.play('megaClack', 0.8, 1.35) end
    if t >= BOING and self.introStep < 4 then self.introStep = 4; Sound.play('trampoline', 0.8, 0.7) end
end

-- ── Red ───────────────────────────────────────────────────────────────────────
-- { songT·100, enfadado 0/1, diana x, nOndas, {ondas…}, nNotas, {id, x, y, vx, vy, color}… }
local NOTE_STRIDE = 6
function GC:netPackExtra()
    local out = { math.floor(self.songT * 100), self.rage and 1 or 0, self.markX or 0 }
    BossWaves.pack(self.waves, out)
    out[#out + 1] = #self.notes
    for _, n in ipairs(self.notes) do
        out[#out + 1] = n.id; out[#out + 1] = math.floor(n.x); out[#out + 1] = math.floor(n.y)
        out[#out + 1] = math.floor(n.vx); out[#out + 1] = math.floor(n.vy); out[#out + 1] = n.c
    end
    return out
end

local function readNotes(b, k)
    local n = type(b[k]) == 'number' and b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, NOTE_STRIDE do e[j] = b[k + 1 + i * NOTE_STRIDE + j - 1] end
        list[#list + 1] = e
    end
    return list
end

function GC:netApplyExtra(a, b, f)
    if type(b[1]) ~= 'number' then return end
    local s0 = type(a[1]) == 'number' and a[1] or b[1]
    self.songT = (s0 + (b[1] - s0) * f) / 100
    self.rage, self.markX = b[2] == 1, b[3]
    local waves, k = BossWaves.unpack(a, b, 4, f)
    self.waves = waves
    local prev = {}
    if type(a[1]) == 'number' then
        local _, ka = BossWaves.unpack(a, a, 4, 1)
        for _, e in ipairs(readNotes(a, ka)) do if e[1] then prev[e[1]] = e end end
    end
    self.notes = {}
    for _, e in ipairs(readNotes(b, k)) do
        local x, y = e[2], e[3]
        local o = prev[e[1]]
        if o and type(o[2]) == 'number' and type(x) == 'number' then x, y = o[2] + (x - o[2]) * f, o[3] + (y - o[3]) * f end
        self.notes[#self.notes + 1] = { id = e[1], x = x, y = y, vx = e[4], vy = e[5], c = e[6] or 0, t = 0 }
    end
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────
-- La postura según el estado y el compás: { pata (cuadro), sx, sy, trampolín (0..1.3), pinza grande (cuadro, dx, dy),
-- pinza pequeña (cuadro, dy), temblor x }
function GC:pose()
    local st, t = self.state, self.deadTimer or 0
    local now = love.timer.getTime()
    local beat = ((self.songT or 0) / (4 * S16)) % 1
    local on = beat < 0.25
    local nb = math.floor((self.songT or 0) / (4 * S16))
    local p = { leg = 1, sx = 1, sy = 1, tk = 1, bf = 1, bdx = 0, bdy = 0, sf = 1, sdy = 0, jx = 0 }
    if st == 'intro' or st == 'ready' then
        local it = (st == 'ready') and (self:introTime() + t) or t
        if it < LAND_AT then p.sy, p.sx, p.tk = 1.1, 0.92, 1.2
        elseif it < LAND_AT + 0.25 then local k = 1 - (it - LAND_AT) / 0.25; p.sy, p.sx = 1 - 0.2 * k, 1 + 0.15 * k
        else
            local snap = (it >= SNAP1 and it < SNAP1 + 0.1) or (it >= SNAP2 and it < SNAP2 + 0.1)
            p.bf, p.bdy = snap and 2 or 1, (it >= SNAP1 and it < BOING) and -5 or 0
            if it >= BOING then p.tk = 1 + 0.35 * math.max(0, math.sin((it - BOING) * 18) * (1 - (it - BOING) / 0.8)) end
        end
    elseif st == 'groove' then
        p.leg = (nb % 2) * 2 + 1
        p.sy, p.sx, p.tk = on and 0.9 or 1, on and 1.06 or 1, on and 0.85 or 1
        p.bf, p.bdy, p.sdy = on and 2 or 1, (nb % 2 == 1) and -2 or 0, (nb % 2 == 1) and 0 or -1
        if self._walking then p.leg = math.floor(now * 8) % 3 + 1 end
    elseif st == 'snap' then
        p.bdy, p.bdx = -5, -2
        local step = ((self.songT or 0) % BAR) / S16
        p.bf = (step % 1 < 0.8 and math.floor(step) % 2 == 0 and on) and 2 or 1
        p.leg = (nb % 2) * 2 + 1
    elseif st == 'crouch' then
        local k = math.min(1, t / 0.25)
        p.sy, p.sx, p.tk = 1 - 0.15 * k, 1 + 0.1 * k, 0.7
        p.jx = (math.floor(now * 30) % 2 == 0) and 1 or 0
    elseif st == 'hop' then
        p.sy, p.sx, p.tk, p.leg, p.bdy, p.sdy = 1.1, 0.92, 1.2, 2, 2, 2
    elseif st == 'pose' then
        local k = math.min(1, t / 0.12)
        p.tk = 1 - 0.85 * k                                          -- el trampolín se esconde
        p.bf, p.bdy, p.bdx, p.sdy = 1, -9 * k, 2 * k, -3 * k             -- ¡la pinza grande arriba, abierta!
        p.sy, p.sx = 1 + 0.06 * k, 1 - 0.03 * k
    elseif st == 'hurt' then
        local k = math.max(0, 1 - t / HURT_T)
        p.tk = 1 + 0.4 * k * math.abs(math.sin(t * 30))
        p.sy, p.sx = 1 - 0.15 * k, 1 + 0.1 * k
    elseif st == 'dying_daze' then
        local w = math.sin(now * 7)
        p.sy, p.sx, p.tk = 1 + 0.05 * math.abs(w), 1 - 0.03 * math.abs(w), 0.6
        p.bdy, p.sdy, p.bdx = 0.5 + w * 0.5, 0.5, w                     -- (las pinzas cuelgan, sin meterse en el suelo)
    elseif st == 'dying_flee' then
        p.sy, p.sx, p.tk, p.leg, p.bdy, p.sdy = 1.12, 0.9, 1.3, 2, -4, -3
    end
    -- EL VAIVÉN de las pinzas (como los Mega Crabbies, nunca tiesas): desvío en px de arte que se suma a la postura
    -- (sin girarlas: el pixel art no se rota). Andando se mecen a contrapié; agachado, recogidas y temblando; en el
    -- aire, agitándose; posando, la grande saluda; con un golpe, sacudidas
    local sw = function(amp, speed, ph) return math.sin(now * speed + (ph or 0)) * amp end
    local it = (st == 'ready') and (self:introTime() + t) or t
    if st == 'groove' and self._walking then
        p.bdy, p.bdx, p.sdy = p.bdy + sw(1.5, 12), p.bdx + sw(1, 12, 1.5), p.sdy + sw(1.5, 12, math.pi)
    elseif st == 'groove' then
        p.bdy, p.sdy = p.bdy + sw(0.5, 4), p.sdy + sw(0.5, 4, 2)
    elseif st == 'snap' then
        p.bdx = p.bdx + ((p.bf == 2) and -1.2 or 0)
        p.sdy = p.sdy + sw(1, 10)
    elseif st == 'crouch' then
        p.bdx, p.bdy, p.sdy = p.bdx + 1.5 + sw(0.4, 40), p.bdy + 1, p.sdy + 1 + sw(0.4, 40, 1)
    elseif st == 'hop' or ((st == 'intro' or st == 'ready') and it < LAND_AT) then
        p.bdy, p.sdy, p.bdx = -3 + sw(1.5, 20), -2 + sw(1, 20, 1.3), p.bdx + sw(0.8, 20, 0.7)
    elseif st == 'pose' then
        p.bdy = p.bdy + sw(0.6, 8)
    elseif st == 'hurt' then
        local k = math.max(0, 1 - t / HURT_T)
        p.bdx, p.bdy, p.sdy = p.bdx + math.cos(now * 17) * 1.2 * k, p.bdy + math.sin(now * 22) * 2 * k, p.sdy + math.sin(now * 19 + 1) * 1.5 * k
    elseif st == 'dying_flee' then
        p.bdy, p.sdy = -4 + sw(1.5, 16), -3 + sw(1, 16, 1)
    end
    if self.boingAt and now - self.boingAt < 0.5 and st ~= 'pose' then
        p.tk = p.tk + 0.3 * math.sin((now - self.boingAt) * 30) * (1 - (now - self.boingAt) / 0.5)
    end
    return p
end

local BEAT_COLS = { { 1, 0.31, 0.64 }, { 0.25, 0.85, 1 }, { 1, 0.82, 0.25 }, { 0.36, 0.94, 0.48 } }

-- Los focos del escenario: dos conos desde arriba hacia él, que cambian de color en cada tiempo
function GC:drawSpotlights(camX, camY)
    local zx0, zx1, zy0 = self:zoneBounds()
    local nb = math.floor((self.songT or 0) / (4 * S16))
    local fx, fy = math.floor(self.x - camX), math.floor(self.floorY - camY)
    love.graphics.setBlendMode('add')
    for i, sx0 in ipairs({ zx0 + T, zx1 - T }) do
        local c = BEAT_COLS[(nb + (i - 1) * 2) % 4 + 1]
        love.graphics.setColor(c[1], c[2], c[3], 0.10)
        local x0, y0 = math.floor(sx0 - camX), math.floor(zy0 - 2 * T - camY)
        love.graphics.polygon('fill', x0 - 16, y0, x0 + 16, y0, fx + 1.4 * T, fy, fx - 1.4 * T, fy)
    end
    love.graphics.setBlendMode('alpha')
end

function GC:render(camX, camY)
    if self.state == 'dormant' and not EDITOR_VIEW then return end
    if self.state == 'dead' or not art then return end
    local st = self.state
    local now = love.timer.getTime()
    if self:isActive() and not EDITOR_VIEW then self:drawSpotlights(camX, camY) end
    -- (¿anda? lo que avanzó desde el dibujo anterior)
    self._walking = self._lx ~= nil and math.abs(self.x - self._lx) > 0.05 and st == 'groove'
    self._lx = self.x
    local p = self:pose()
    local alpha = self:ghostAlpha()
    if st == 'dying_flee' then alpha = alpha * self:fleeAlpha(self.deadTimer) end
    local f = self.facing or 1
    local fx, fy = math.floor(self.x - camX + 0.5) + p.jx, math.floor(self:feetY() - camY + 0.5)
    if st == 'dying_daze' and not EDITOR_VIEW then BossFx.stars(fx, fy - 12 * MS, 7 * MS, 1.4 * MS, 5, alpha, 'back') end
    if self:flashRed() then love.graphics.setColor(1, 0.35, 0.35, alpha)
    elseif self.rage and self:isActive() then
        local q = 0.86 + 0.08 * math.sin(now * 8)
        love.graphics.setColor(1, q, q, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    love.graphics.push()
    love.graphics.translate(fx, fy)
    love.graphics.scale(p.sx, p.sy)
    -- (el dibujo mira a la IZQUIERDA: mirando a la derecha va espejado; la pinza grande va por delante)
    local A = art
    local th = math.max(0.05, p.tk)
    love.graphics.draw(A.tramp.image, A.tramp.quads[1], 0, -(FH - 1) * MS, 0, MS, MS * th, 8, 9)    -- (el muelle, metido un píxel en el caparazón)
    love.graphics.draw(A.body.images and A.body.images[p.leg] or A.body.image, A.body.quads[p.leg], 0, 0, 0, -MS * f, MS, FW / 2, FH)
    local bx = f * (13 - math.floor(p.bdx + 0.5)) * MS        -- (bdx: hacia el cuerpo; en px de arte enteros)
    p.bdy, p.sdy = math.floor(p.bdy + 0.5), math.floor(p.sdy + 0.5)
    love.graphics.draw(A.big.images and A.big.images[p.bf] or A.big.image, A.big.quads[p.bf], bx, (-4.5 + p.bdy) * MS, 0,
                       -MS * f, MS, 6, 4.5)
    local sxp = -f * 11.5 * MS
    love.graphics.draw(A.small.images and A.small.images[p.sf] or A.small.image, A.small.quads[p.sf], sxp, (-4 + p.sdy) * MS, 0,
                       MS * f, MS, 3.5, 3)
    love.graphics.pop()
    if st == 'dying_daze' and not EDITOR_VIEW then BossFx.stars(fx, fy - 12 * MS, 7 * MS, 1.4 * MS, 5, alpha, 'front') end
    self:drawOver(camX, camY)
    love.graphics.setColor(1, 1, 1, 1)
end

-- La diana, las ondas, las notas y el enfado
function GC:drawOver(camX, camY)
    local now = love.timer.getTime()
    if self.state == 'crouch' and not EDITOR_VIEW then
        local blink = (math.floor(now * 12) % 2 == 0) and 0.95 or 0.55
        love.graphics.setColor(1, 0.3, 0.3, blink)
        BossFx.target(now * 1.2, math.floor(self.markX - camX), math.floor(self.floorY - camY - 16), 8, 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    for _, w in ipairs(self.waves or {}) do
        local fr = math.floor((w.t or 0) * 12) % 3 + 1
        art.wave:draw(fr, math.floor(w.x - camX), math.floor(w.y - camY) - 18, 0, 4 * w.dir, 4)
    end
    for _, n in ipairs(self.notes or {}) do
        local fr = (n.c or 0) * 2 + (math.floor(now * 6 + (n.id or 0)) % 2) + 1
        art.note:draw(fr, math.floor(n.x - camX), math.floor(n.y - camY), 0, 4, 4)
    end
    BossFx.anger(self, self.rage and self:isActive(), self.x - camX, self:feetY() - camY - 16 * MS)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cajas de depuración (F1): ondas, notas y el cojín del trampolín
function GC:debugBoxes()
    local out = {}
    for _, w in ipairs(self.waves or {}) do local b = BossWaves.box(w, WAVES); b.kind = 'hazard'; out[#out + 1] = b end
    for _, n in ipairs(self.notes or {}) do local b = self:noteBox(n); b.kind = 'hazard'; out[#out + 1] = b end
    if self:trampOut() then local b = self:trampBox(); b.kind = 'area'; out[#out + 1] = b end
    return out
end

local G = 'El Groove'
return {
    name = 'groovecrab', label = 'El Groove', category = 'Jefes',
    description = 'Jefe SECRETO: un Crabby trampolín gigante que pelea al ritmo de su tema (salta y cae en el bombo, '
               .. 'dispara notas en los pops del bajo). Solo se le golpea cuando POSA en los golpes de la banda; '
               .. 'si no, su trampolín te lanza.',
    class = GC,
    pace = false,                                -- (va al compás de su música: la dificultad no le cambia el ritmo)
    boss = { title = 'EL GROOVE' },
    hide = Boss.HIDE,
    defaults = { points = 40 },
    props = Boss.props({ hp = 10, hpPerPlayer = 4 }, {
        { key = 'rageAt', kind = 'number', label = 'Se enfada con (fracción de vida)', group = G, default = 0.5,
          min = 0.1, max = 0.9, step = 0.05 },
    }),
    editor = { sprite = DIR .. 'body-Sheet.png', frameW = FW },
}
