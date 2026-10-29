-- src/world/entities/base/Interactions.lua
-- Reglas jugador ↔ entidad, en UN solo lugar. Las usan el modo un jugador
-- (AdventureState), el servidor online y la predicción del cliente.
--
-- Interactions.check(player, entity) devuelve:
--   nil                           sin contacto relevante
--   'kill'                        el jugador muere (pinchos, entidad hostil)
--   'hurt'[, n]                   el jugador pierde n HP (1 por defecto; entidad onTouch='hurt'
--                                 o caja de peligro effect='hurt', dmg=n)
--   'stomp', bounceVy, points[, dirX]  el jugador pisotea a la entidad (dirX:
--                                 rebote de lado, p. ej. un Crabby en una pared)
--   'pound', bounceVy, points     le cae encima en pleno ground pound (e:pound)
--   'helmet', bounceVy            salta sobre un Gummy con casco: rebota, el
--                                 casco aguanta (e:onHelmetBounce), sin puntos
--   'bounce', bounceVy, dirX      rebota sin hacerle nada (jefe invulnerable, `stompProof`);
--                                 con dirX sale empujado hacia ese lado
--   'recoil', dirX                choca con su cuerpo y sale empujado
--   'launch', vx, vy[, jumps]     lanzado (trampolín, cristal roto, el EMPUJÓN de lo que embiste — caja de
--                                 peligro effect='launch' —): pa:launch, e:onLaunch(pa)
--   'freeze', t                   congelado t s (chorro del congelador): pa:freeze(t)
--   'shatter', bounceVy           le cae encima a un enemigo congelado que no se puede
--                                 matar: rebota y le rompe el hielo (e:shatter)
--   'pickup'                      coleccionable (estrella, vida extra...)
--   'checkpoint'                  punto de control
--
-- Interactions.run(pa, entities, cb, rewind) aplica todo lo anterior (y el
-- impacto del ground pound) para un jugador; el juego solo pone los efectos
-- propios en `cb` (puntos, vidas, eventos online...).

local Interactions = {}

local function overlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and
           a.y < b.y + b.h and a.y + a.h > b.y
end

local BOUNCE = 0.40   -- fracción de la velocidad de salto al rebotar
local STEP_DT = 1 / 60  -- paso fijo de la simulación (Protocol.TICK_RATE)
Interactions.BOUNCE = BOUNCE
-- Cuánto bajó el jugador en este paso: lo que se movió de verdad (a pocos FPS el paso es más largo que 1/60 s y con
-- `vy × 1/60` un pisotón rápido se saltaba la franja y contaba como choque; y si en ese mismo paso llegaba al suelo, ya
-- con vy = 0, tampoco contaba como caída); sin dato, el paso fijo
local function prevDy(pa)
    if pa.prevY then return math.max(0, pa.y - pa.prevY) end
    return pa.vy * STEP_DT
end

function Interactions.check(pa, e)
    if not e.alive or e.state == 'dead' or (e.isGhost and e:isGhost()) then return nil end
    if e.state == 'carried' then return nil end                     -- (en las manos de alguien: systems/Carry)
    if e.thrownBy == pa and (e.thrownT or 0) > 0 then return nil end   -- (recién lanzado: no le da a quien lo lanzó)
    -- Congelada en un bloque de hielo: inofensiva; caerle encima rompe el hielo
    -- (los jefes y lo que tiene reglas propias deciden ellos: ver interact)
    if e.state == 'frozen' and not e.interact then return Interactions.frozenCheck(pa, e) end
    -- Reglas propias (jefes: ver entities/Boss.lua). Debe ser una consulta
    -- sin efectos: el cliente online la usa para predecir rebotes.
    local r, a, b, c
    if e.interact then r, a, b, c = e:interact(pa) else r, a, b, c = Interactions.defaultCheck(pa, e) end
    -- Enemigos DUROS (`needsPound` en su clase): un pisotón normal solo rebota; hace falta un
    -- ground pound para matarlos
    if r == 'stomp' and e.needsPound and pa.gpPhase ~= 'fall' then return 'bounce', a, c end
    -- A prueba de PISOTONES (`stompProof = true` en su clase; 0.5.97, la Planta carnívora: "no se la puede matar
    -- pisándola"): ni un pisotón ni un ground pound le hacen nada, solo rebotas. Todo lo demás que mata a un enemigo
    -- (explosiones, su bloque roto, lava, pinchos, el vacío...) sí
    if (r == 'stomp' or r == 'pound') and e.stompProof then return 'bounce', a, (r == 'stomp') and c or nil end
    -- … y encima de ellos NO hacen daño (solo de lado, o con su ataque: `hurtsFromAbove()`): tras el
    -- rebote el jugador sigue un momento dentro de su caja, subiendo, y eso contaba como tocarlo
    if e.needsPound and (r == 'hurt' or r == 'kill') and not (e.hurtsFromAbove and e:hurtsFromAbove()) then
        local pob, gob = pa:getOuterBounds(), e:getOuterBounds()
        local nx, ny = 0, -1
        if e.surfaceNormal then
            local sx, sy = e:surfaceNormal()
            if sx then nx, ny = sx, sy end
        end
        local above
        if nx ~= 0 then above = (pa.x - (gob.x + gob.w / 2)) * nx > gob.w * 0.25          -- (en una pared: por su lado abierto)
        elseif ny > 0 then above = pob.y > gob.y + gob.h * 0.4                              -- (en el techo: por debajo)
        else above = pob.y + pob.h < gob.y + gob.h * 0.6 end                               -- (en el suelo: los pies por encima)
        if above then return nil end
    end
    -- Nivel de enemigos INOFENSIVOS ("peaceful": true): tocarlos no hace nada (pisarlos, rebotar... sí)
    if pa.peaceful and (r == 'hurt' or r == 'kill') then return nil end
    return r, a, b, c
end

-- Enemigo congelado: solo cuenta caerle encima (o un ground pound): rompe el
-- hielo; si se le puede pisotear muere (puntos), si no solo se descongela
function Interactions.frozenCheck(pa, e)
    local pob, gob = pa:getOuterBounds(), e:getOuterBounds()
    if not overlap(pob, gob) then return nil end
    local line, foot = gob.y + gob.h * 0.5, pob.y + pob.h
    if pa.gpPhase == 'fall' or ((pa.vy > 0 or prevDy(pa) > 0) and (foot < line or foot - prevDy(pa) <= line)) then
        local vy = -math.abs(ADV_JUMP_VEL) * BOUNCE
        if e.props.stompable then return 'stomp', vy, e.props.points end
        return 'shatter', vy
    end
    return nil
end

-- Reglas normales (enemigos, coleccionables...). Las entidades con interact()
-- propio pueden usarlas para los casos que no tratan ellas.
local EMPTY = {}          -- (en vez de crear una tabla vacía en cada comprobación; solo lectura)
local EOB, GIB, MAG = {}, {}, {}   -- (las de la entidad: igual)
local function fill(t, x, y, w, h) t.x, t.y, t.w, t.h = x, y, w, h; return t end
local POB = {}            -- (la caja del jugador, rellenada en cada comprobación: se hace una por entidad y fotograma)
function Interactions.defaultCheck(pa, e)
    local pob = pa:getOuterBounds(POB)

    -- Coleccionables y checkpoints: basta con tocarlos
    local def = e.def or EMPTY
    if def.pickup or def.checkpoint then
        -- Margen de "imán": que no se escape por un píxel al pasar por debajo
        local b, m = e:getOuterBounds(EOB), 12
        if overlap(pob, fill(MAG, b.x - m, b.y - m, b.w + 2 * m, b.h + 2 * m)) then
            return def.pickup and 'pickup' or 'checkpoint'
        end
        return nil
    end

    -- Zonas de peligro propias (el pincho del Crabby, el fuego del mortero...):
    -- matan, salvo que la caja diga otra cosa (hb.effect = 'hurt': 1 de vida)
    -- (3er valor 'hazard': un peligro, no el cuerpo — en Fácil quita 1 como los pinchos del suelo: hazardHit)
    for _, hb in ipairs(e:getHazardBoxes() or EMPTY) do
        if overlap(pob, hb) then
            if hb.effect == 'launch' then
                -- EMPUJÓN (hb.vx, hb.vy[, hb.jumps]: lo que embiste, comportamiento `ram`): sale lanzado como por un
                -- trampolín, sin daño (el cliente lo predice igual). Ya lanzado (ctrlLockT, viaja en el estado propio)
                -- no se repite ni hace nada más esta entidad; `stompable`: cayéndole ENCIMA no empuja (se le pisa)
                if (pa.ctrlLockT or 0) > 0 then return nil end
                local fromAbove = hb.stompable and (pa.vy > 0 or prevDy(pa) > 0) and pob.y + pob.h - prevDy(pa) <= hb.y + 8
                if not fromAbove then return 'launch', hb.vx or 0, hb.vy or 0, hb.jumps end
            else
                return hb.effect or 'kill', hb.time or hb.dmg, 'hazard'
            end
        end
    end

    if e:isBodyDisabled() then return nil end

    local gib = e:getInnerBounds(GIB)
    if not overlap(pob, gib) then return nil end

    local p = e.props
    if p.stompable then
        local gob = e:getOuterBounds(EOB)
        -- Ground pound: cae en picado; cualquier contacto desde arriba aplasta
        -- Superficie del trepador (girando en una esquina: a la que más mira)
        local snx, sny = e.cnx, e.cny
        local flipped = e.flipped
        if e.surfaceNormal then
            local nx, ny = e:surfaceNormal()
            if nx then snx, sny, flipped = nx, ny, (ny == 1) end
        end
        if pa.gpPhase == 'fall' and not flipped and pob.y + pob.h * 0.5 < gob.y + gob.h * 0.5 then
            return 'stomp', -math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
        end
        if e.cattached and snx and snx ~= 0 then
            -- En una pared (trepador): el caparazón mira hacia fuera (normal cnx).
            -- Se le pisotea cayéndole encima (como en el suelo) o saltándole
            -- desde el lado abierto; desde abajo o andando por el suelo, no.
            if not pa.onGround then
                local fromTop  = pa.vy > 0 and pob.y + pob.h < gob.y + gob.h * 0.35 + 10
                -- (lado abierto = el centro del jugador más allá de la cara de fuera
                -- del Crabby; si no, viene de debajo/encima, por sus patas)
                local gcx = gob.x + gob.w / 2                          -- (centro de la pose)
                local fromSide = (pa.x - gcx) * snx > gob.w / 2
                                 and (pa.vx or 0) * snx <= 60      -- (no alejándose de él)
                if fromTop or fromSide then
                    return 'stomp', -math.abs(ADV_JUMP_VEL) * BOUNCE, p.points, snx
                end
            end
        elseif flipped then
            -- Boca abajo (techo): se pisotea desde abajo, subiendo
            if pa.vy < 0 and pob.y > gob.y + gob.h * 0.65 - 10 then
                return 'stomp', math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
            end
        else
            -- Cayendo desde arriba. También vale si los pies estaban por
            -- encima de la línea en el paso ANTERIOR: cayendo rápido (≥ 20 px por
            -- paso) se podía saltar la franja de pisotón y morir al tocarlo
            local line, foot = gob.y + gob.h * 0.35 + 10, pob.y + pob.h
            if (pa.vy > 0 or prevDy(pa) > 0) and (foot < line or foot - prevDy(pa) <= line) then
                return 'stomp', -math.abs(ADV_JUMP_VEL) * BOUNCE, p.points
            end
        end
    end

    if p.onTouch == 'none' then return nil end
    return p.onTouch
end

-- Zona aplastada al impactar un ground pound: SOLO justo bajo los pies (lo
-- que queda debajo del jugador; lo de los lados solo sale despedido)
-- Qué hace DE VERDAD un coleccionable a ese jugador (uno para todos: un jugador y servidor). Uno que CURA
-- (`pickup = { heal = n, score = p }`, la manzana) devuelve vida si le falta; con la vida llena da sus puntos.
--   → { heal = n } | { score = p, lives = n }
-- (`e.taken`: una vida extra que ya se cogió en una partida anterior de este nivel — modo historia —: ahora solo da
-- puntos; repetir un nivel no puede dar vidas sin fin)
Interactions.TAKEN_SCORE = 100
function Interactions.pickupEffect(pa, pk, e)
    if e and e.taken and pk.lives then return { score = Interactions.TAKEN_SCORE } end
    if pk.heal then
        if (pa.hp or 0) < (pa.hpMax or 0) then return { heal = math.min(pk.heal, pa.hpMax - pa.hp) } end
        return { score = pk.score }
    end
    return pk
end

function Interactions.poundZone(pa)
    local ob = pa:getOuterBounds()
    return { x = ob.x + 4, y = ob.y + ob.h - 24, w = ob.w - 8, h = 30 }
end

-- Aplica las interacciones de un jugador con todas las entidades.
--   cb.stomp(e, points, i)  cb.pickup(e, pickupDef, i)  cb.checkpoint(e, i)
--   rewind(i, e, fn)        opcional (servidor): evalúa fn() con el estado
--                           del enemigo que veía el jugador
function Interactions.run(pa, entities, cb, rewind)
    if pa.dying or not pa.alive then return end
    if pa.gulped then return end                      -- (tragado por una planta: no toca nada — PlayerGulp.lua —)
    local Noise = require 'src/world/systems/Noise'
    for i, e in ipairs(entities) do
        local result, a, b, c
        Noise.src(e.x, e.y)                           -- (los sonidos-ruido de lo que pase con ella salen de ella)
        if rewind then
            result, a, b, c = rewind(i, e, Interactions.check)      -- (rewind(i, e, check) → check(pa, e) rebobinada)
        else
            result, a, b, c = Interactions.check(pa, e)
        end
        if result == 'kill' then
            local died
            if b == 'hazard' then died = pa:hazardHit() else died = pa:die() ~= false end
            if died then Noise.src(nil); return end                   -- (invulnerable al reaparecer: sigue)
        elseif result == 'hurt' then
            -- (e:onHurtPlayer: solo si de verdad le quitó vida; p. ej. el pinchazo del pez globo)
            local hp0 = pa.hp
            local killed = pa:hurt(a)                       -- (a = vida que quita: hb.dmg; nil = 1)
            if pa.hp < hp0 and e.onHurtPlayer then e:onHurtPlayer(pa) end
            if killed then Noise.src(nil); return end
        elseif result == 'stomp' then
            e.lastHitter = pa                               -- (quién le dio: el ranking del Mega Mashup)
            e:stomp()
            pa:bounce(a, c, true)
            if cb.stomp then cb.stomp(e, b, i) end
        elseif result == 'pound' then
            e.lastHitter = pa
            if e.pound then e:pound(pa) else e:stomp() end
            pa:bounce(a)
            if cb.stomp then cb.stomp(e, b, i) end
        elseif result == 'helmet' then
            -- Salto sobre un Gummy con casco: rebota, sin daño ni puntos
            pa:bounce(a)
            if e.onHelmetBounce then e:onHelmetBounce(pa) end
        elseif result == 'bounce' then
            pa:bounce(a, b)
            if e.onBounced then e:onBounced(pa) end         -- (bombas: salen pateadas)
        elseif result == 'freeze' then
            pa:freeze(a)
        elseif result == 'shatter' then
            e:shatter()
            pa:bounce(a)
        elseif result == 'recoil' then
            pa:recoil(a)
        elseif result == 'launch' then
            pa:launch(a, b, c)
            if e.onLaunch then e:onLaunch(pa) end
        elseif result == 'pickup' then
            if e:collect() then
                Noise.emit(e.x, e.y, e.def.noise or (e.def.pickup and e.def.pickup.lives and Noise.R.life) or Noise.R.pickup)
                if cb.pickup then cb.pickup(e, e.def.pickup, i) end
            end
        elseif result == 'checkpoint' then
            if cb.checkpoint then cb.checkpoint(e, i) end
        end
    end
    Noise.src(nil)
    -- Impacto del ground pound: muere solo lo que queda aplastado justo
    -- debajo; lo que está cerca sale despedido y queda aturdido, igual que
    -- los otros jugadores.
    if pa.gpLanded then
        local z = Interactions.poundZone(pa)
        local rx, ry = pa.GP_RADIUS_X or 170, pa.GP_RADIUS_Y or 110
        for i, e in ipairs(entities) do
            if e.alive and e.state ~= 'dead' and e.state ~= 'carried' and not (e.isGhost and e:isGhost()) then
                -- (lo que reacciona a un ground pound a su manera: `onPound(pa, zona)` → true = ya está — la Caja se
                -- rompe, la Balanza catapulta, la Semilla se planta)
                if e.onPound and e:onPound(pa, z) then
                elseif e.state == 'frozen' and not e.interact then
                    -- (congelada: el impacto rompe el hielo)
                    if overlap(z, e:getOuterBounds()) then
                        local killed = e.props.stompable
                        e:shatter()
                        if killed and cb.stomp then cb.stomp(e, e.props.points, i) end
                    end
                elseif e.props.stompable and not e.stompProof and e:canBeStomped() and overlap(z, e:getInnerBounds()) then
                    e:stomp()
                    if cb.stomp then cb.stomp(e, e.props.points, i) end
                else
                    local dx, dy = e.x - pa.x, e.y - pa.y
                    if math.abs(dx) <= rx and math.abs(dy) <= ry and e:canBeKnocked() then
                        e:knockback(dx >= 0 and 1 or -1)
                    end
                end
            end
        end
    end
end

return Interactions
