-- src/story/CreditsFight.lua
-- LA PELEA DEL FINAL DE LOS CRÉDITOS (docs/story/credits.md): el monstruo contra el Espejo en su arena
-- (assets/story/sets/credits_espejo.json), JUGADA con el motor del juego dentro de un escenario vivo
-- (src/story/LiveStage.lua): física, cuerpos, ataques y sonidos de verdad. Este módulo es el MANDO del monstruo:
-- cada paso de 1/60 s decide qué botones pulsa mirando dónde está el Espejo y qué hace (como un jugador). El
-- escenario va a pasos fijos con su propio azar: la pelea sale IGUAL cada vez que se ven los créditos — una pelea
-- grabada, pero que se juega de nuevo con la física del juego en vez de reproducir un vídeo.
--   * se aparta de sus ataques de arena (la marca del picado desde el espejo flotante, la del salto desde una
--     plataforma): corre al otro lado;
--   * a ratos ataca: se acerca, se QUEDA QUIETO hasta que el Espejo —que repite lo que él pulsa con retraso— también
--     se para en el suelo, y entonces salta (el doble salto en lo alto), se pone encima y GROUND POUND antes de que el
--     Espejo llegue a copiar el salto: queda KO (2 de vida);
--   * entre ataque y ataque baila por la arena — y el Espejo, que copia lo que pulsa con retraso, lo imita;
--   * vencido el Espejo, salta de alegría;
--   * los ataques se abren a sus horas (`windows`): el ÚLTIMO golpe llega justo al final de la pelea, cuando la
--     música pasa al final (la película lo asegura por si acaso: credits.lua).
--   local f = CreditsFight.new(pa, boss, { windows = { 3, 8.5, 15.8 } })
--   f:step(dt, level)            (lo llama el escenario en lugar del bot: mueve al jugador)
local P = require 'src/network/Protocol'

local CreditsFight = {}
CreditsFight.__index = CreditsFight

local L, R, J, JP, C, CP = P.IN_LEFT, P.IN_RIGHT, P.IN_JUMP, P.IN_JUMP_P, P.IN_CROUCH, P.IN_CROUCH_P
local DT = 1 / 60
local T = TILE_PX
local DANGER = { warp_out = true, portal = true, perch = true, leap = true, dive = true }
local HITTABLE = { fight = true, recover = true, laugh = true }

function CreditsFight.new(pa, boss, opts)
    opts = opts or {}
    return setmetatable({ pa = pa, boss = boss, stub = P.newInputStub(), acc = 0, t = 0, mode = 'dance',
                          windows = opts.windows or { 3, 8.5, 15.8 }, win = 1, hp0 = boss.hp,
                          danceTo = nil, danceT = 0, prevBits = 0 }, CreditsFight)
end

local function has(b, f) return math.floor(b / f) % 2 == 1 end
-- ¿Hay techo (una plataforma) sobre ese punto del suelo? (de 1 a 5 casillas encima)
local function roofAt(level, x, footY)
    for y = footY - 2 * T, footY - 5 * T, -T / 2 do
        if level:collisionAt(x, y, true) then return true end
    end
    return false
end
-- Un sitio del suelo SIN plataforma encima, cerca de x, entre a y b (debajo de una, el picado del Espejo cae en
-- ella y se queda ahí arriba)
local function openSpot(level, x, a, b, footY)
    for k = 0, 12 do
        for _, sg in ipairs({ 1, -1 }) do
            local xx = x + sg * k * T / 2
            if xx >= a and xx <= b and not roofAt(level, xx, footY) then return xx end
        end
    end
    return x
end
-- ¿Una plataforma (o un bloque) poco por encima de él? (hasta 3 casillas sobre su cabeza: saltando hacia él se
-- quedaba en ella) (de 1 a 5 casillas sobre su cabeza)
local function roofedAt(level, m)
    local b = m:getOuterBounds()
    for _, x in ipairs({ b.x + 4, m.x, b.x + b.w - 4 }) do
        for y = b.y - T / 2, b.y - 3 * T, -T / 2 do                -- (la de lo alto del centro, a 4, no estorba)
            if level:collisionAt(x, y, true) then return true end
        end
    end
    return false
end

-- Lo que pulsa en este paso
function CreditsFight:think(level)
    local pa, m = self.pa, self.boss
    local t = self.t
    if pa.dying or (pa.stunT or 0) > 0 or (pa.ctrlLockT or 0) > 0 then return 0 end
    local zx0, zx1 = m:zoneBounds()
    local x0, x1 = zx0 + 1.5 * T, zx1 - 1.5 * T
    local dx = m.x - pa.x
    local dir = (dx < 0) and L or R
    -- ¡GOLPEADO! (su vida bajó): se aparta y espera a la siguiente ventana
    if m.hp < self.hp0 then
        self.hp0, self.mode = m.hp, 'dance'
        self.win = self.win + 1
        self.danceTo = nil
    end
    -- en pleno ground pound: que caiga
    if pa.gpPhase then return 0 end
    -- ¡GANÓ! (el Espejo explota): saltitos de alegría en el sitio
    if m:isDying() or not m.alive then
        self.mode = 'win'
        return (pa.onGround and math.floor(t * 3) % 2 == 0) and J or 0
    end
    if pa.onGround and not self.footY then local ob = pa:getOuterBounds(); self.footY = ob.y + ob.h end
    -- PELIGRO: su marca (picado desde el espejo, salto desde una plataforma) cerca → al otro lado
    if DANGER[m.state] and not m:isDying() then
        local mx = m.markX or m.x
        if math.abs(mx - pa.x) < 3.2 * T then
            -- (a un sitio despejado al otro lado de la marca, sin plataforma encima)
            local side = (pa.x < mx) and -1 or 1
            if (side < 0 and pa.x < x0 + 2 * T) or (side > 0 and pa.x > x1 - 2 * T) then side = -side end
            local to = openSpot(level, mx + side * 2.6 * T, x0, x1, self.footY or pa.y)
            self.mode, self.danceTo, self.danceT = 'dance', to, 1.5
            local away = (to < pa.x) and L or R
            -- (a la carrera, y saltando si lo tiene encima)
            if pa.onGround and math.abs(mx - pa.x) < 1.2 * T then return away + J end
            return away
        end
    end
    -- ATAQUE: en su ventana y con el Espejo golpeable (en el suelo, sin invulnerabilidad, sin una plataforma encima:
    -- saltando hacia él se quedaba de pie en ella)
    local open = t >= (self.windows[self.win] or self.windows[#self.windows])     -- (pasada la última, hasta vencerlo)
    local body = m.body
    local roofed = roofedAt(level, m)
    local low = body and m.y > pa.y - T                    -- (a su altura o más abajo: no subido a una plataforma)
    -- (a por él: recién caído de su picado —'recover': se queda un momento— o aturdido, o cerca y quieto)
    local chance = m.state == 'recover' or m.state == 'ko' or math.abs(dx) < 3 * T
    local grounded = body and (body.onGround or m.state == 'recover' or m.state == 'ko')      -- (tras su picado lo coloca él)
    if open and chance and HITTABLE[m.state] and (m.inv or 0) <= 0 and grounded and not roofed and low then self.mode = 'attack' end
    if self.mode == 'attack' then
        if not (HITTABLE[m.state] or m.state == 'ko') or m:isDying() or ((roofed or not low) and pa.onGround) then self.mode = 'dance'
        else
            local mob = m:getOuterBounds()
            local ob = pa:getOuterBounds()
            if pa.onGround then
                -- (encima, en una plataforma: se baja por el lado que le acerca)
                if ob.y + ob.h < mob.y + mob.h - T / 2 then return (math.abs(dx) < 20) and R or dir end
                -- tras su picado se queda un momento en el suelo ('recover'): ¡a por él ya!
                if m.state == 'recover' and math.abs(dx) < 4 * T then self.still = 0; return dir + J end
                if math.abs(dx) > 1.6 * T then self.still = 0; return dir end        -- (se acerca)
                -- (quieto hasta que él también lo está: si no, copiaba los saltos y nunca estaba en el suelo)
                self.still = (self.still or 0) + DT
                if self.still < 0.45 or not grounded or math.abs(body.vx or 0) > 25 then return 0 end
                self.still = 0
                return J + ((math.abs(dx) > 30) and dir or 0)                        -- (¡arriba, junto a él!)
            end
            -- en el aire: hacia él (adonde ESTARÁ: se mueve copiándole), frenando si se pasa; el salto entero, el
            -- segundo en lo alto y, justo encima, GROUND POUND
            local tx = m.x + (body.vx or 0) * 0.2
            local adx = tx - pa.x
            local bits = 0
            if math.abs(adx) > 6 then bits = (adx < 0) and L or R end
            -- (bits sueltos: sumar J dos veces daba C — se agachaba en el aire: ground pound donde no debía —)
            if pa.vy > -60 and (pa.jumpsLeft or 0) > 0 and ob.y + ob.h > mob.y - 40 then bits = bits + J + JP
            elseif pa.vy < 0 then bits = bits + J end
            if math.abs(adx) < 16 and ob.y + ob.h < mob.y + 4 and pa.vy > -320 then bits = C + CP end
            return bits
        end
    end
    -- BAILE (entre golpes): de un sitio a otro de la arena, lejos de él, con saltitos — y él lo copia
    self.danceT = self.danceT - DT
    if not self.danceTo or self.danceT <= 0 or math.abs(self.danceTo - pa.x) < 12 then
        local far = (m.x < (zx0 + zx1) / 2) and (x1 - math.random() * 4 * T) or (x0 + math.random() * 4 * T)
        self.danceTo, self.danceT = openSpot(level, far, x0, x1, self.footY or pa.y), 1.2 + math.random() * 1.4
    end
    local ddx = self.danceTo - pa.x
    if math.abs(ddx) < 12 then return 0 end
    local bits = (ddx < 0) and L or R
    return bits
end

function CreditsFight:step(dt, level)
    self.acc = math.min(self.acc + dt, 0.1)
    while self.acc >= DT - 1e-9 do
        self.acc = self.acc - DT
        self.t = self.t + DT
        -- (lo que pulsa: "recién pulsado" al empezar a pulsar; el doble salto lo pide él con JP)
        local bits = self:think(level)
        if has(bits, J) and not has(self.prevBits, J) and not has(bits, JP) then bits = bits + JP end
        if has(bits, C) and not has(self.prevBits, C) and not has(bits, CP) then bits = bits + CP end
        self.prevBits = bits
        P.decodeInput(bits, self.stub.state)
        local real = Input
        Input = self.stub
        local ok, err = pcall(self.pa.update, self.pa, DT, level)
        Input = real
        if not ok then error(err, 0) end
    end
end

return CreditsFight
