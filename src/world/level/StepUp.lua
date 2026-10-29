-- src/world/level/StepUp.lua
-- ESCALONES BAJOS: quien ANDA por el suelo y se mete de lado en un escalón cuya cara de arriba está como mucho `maxH`
-- px por encima de sus pies, se sube a él sin saltar (si cabe encima). Una mecánica típica de muchos juegos (el
-- usuario, 2026-10-29: bajarse de la cabina del teleférico a su estación pedía un saltito).
--
-- Genérico: mira las casillas del nivel (sólidas y de un solo sentido, bloques pequeños incluidos) y los cuerpos
-- sólidos (`solidFull`: cajas, plataformas que se mueven, platillos, la cabina del teleférico...). No nombra ningún
-- tipo. Lo usa el jugador (PlayerCollision: un jugador, el servidor y la predicción del cliente, igual); cualquier otro
-- que ande (un enemigo) puede usarlo con su caja.
--
-- Reglas:
--   * escalón = algo sólido justo encima de los pies (en la caja ya movida de lado); su cara de arriba (lo que haya
--     apilado encima incluido) a 0 < h <= maxH. Más alto y sólido = una PARED: no se sube (devuelve nil). Una
--     plataforma de un solo sentido más alta se atraviesa como siempre (no cuenta).
--   * sitio: la caja subida h px no toca nada sólido (casillas ni cuerpos sólidos que no sean de un solo sentido).
local StepUp = {}

local PROBE = 16          -- px: separación máxima entre los puntos que se miran (un bloque pequeño mide 32)

-- Puntos de a a b (los dos incluidos), separados como mucho PROBE, en `out` (se reutiliza: sin basura cada paso)
local XS, YS, OB = {}, {}, {}
local function span(a, b, out)
    local n = math.max(1, math.ceil((b - a) / PROBE))
    for i = #out, n + 2, -1 do out[i] = nil end
    for i = 0, n do out[i + 1] = a + (b - a) * i / n end
    return out
end

-- Cara de arriba de lo sólido que hay en (px, py), subiendo por lo que esté apilado encima mientras pueda ser un
-- escalón (hasta `limit`). nil si en ese punto no hay nada.
local function tileTop(level, px, py, limit)
    local T = TILE_PX
    local t = level:collisionAt(px, py, true)
    if not t then return nil end
    local top = math.floor(py / T) * T + t.hitbox.y * T
    local oneway = t.collision == 'oneway'
    for _ = 1, 4 do
        if top < limit then break end
        local u = level:collisionAt(px, top - 0.5)
        if not u then break end
        top, oneway = math.floor((top - 0.5) / T) * T + u.hitbox.y * T, false
    end
    return top, oneway, t
end

-- ¿Cuánto subir? Caja YA movida de lado: x0..x1 (lados), head (arriba), foot (pies); dir = hacia dónde se mueve (±1:
-- ese lado se mira entero; el de detrás, `back` px más adentro — 0,5 por defecto —: estar pegado a una pared a la
-- espalda no cuenta). bodies = cuerpos sólidos (o nil); skipA / skipB = cuerpos que no cuentan (el que anda, si es uno
-- de la lista; el que lo lleva montado: ese ya lo sube y lo baja él).
-- Devuelve lift (0 < lift <= maxH) y `face`, la x de la cara del escalón más cercana (por donde se entra en él);
-- o nil (no hay escalón, es una pared o no cabe encima).
function StepUp.lift(level, x0, x1, head, foot, dir, maxH, bodies, back, skipA, skipB)
    local T = TILE_PX
    local a, b = x0, x1
    if dir > 0 then a = x0 + (back or 0.5) else b = x1 - (back or 0.5) end
    local limit = foot - maxH
    local best, face                              -- (la cara más alta de los escalones encontrados; su lado más cercano)
    local xs = span(a, b, XS)
    for _, px in ipairs(xs) do
        local top, oneway, t = tileTop(level, px, foot - 0.5, limit)
        if top then
            if top < limit then
                if not oneway then return nil end  -- (una pared)
            else
                if not best or top < best then best = top end
                local hb, cx = t.hitbox, math.floor(px / T) * T
                local f = (dir > 0) and (cx + hb.x * T) or (cx + (hb.x + hb.w) * T)
                if not face or (f - face) * dir < 0 then face = f end
            end
        end
    end
    if bodies then
        for _, o in ipairs(bodies) do
            if o.solidFull and o.alive ~= false and not o.dying and o ~= skipA and o ~= skipB then
                local ob = o:getOuterBounds(OB)
                if ob.x < b and ob.x + ob.w > a and ob.y < foot - 0.5 and ob.y + ob.h >= foot - 0.5 then
                    if ob.y < limit then
                        if not o.oneway then return nil end
                    else
                        if not best or ob.y < best then best = ob.y end
                        local f = (dir > 0) and ob.x or (ob.x + ob.w)
                        if not face or (f - face) * dir < 0 then face = f end
                    end
                end
            end
        end
    end
    if not best then return nil end
    local lift = foot - best
    if lift <= 0 then return nil end
    -- Sitio encima: la caja subida (de la cabeza a los pies nuevos) no toca nada sólido
    local top, bot = head - lift + 1, foot - lift - 1
    local ys = span(top, bot, YS)
    for _, px in ipairs(xs) do
        for _, py in ipairs(ys) do
            if level:collisionAt(px, py) then return nil end
        end
    end
    if bodies then
        for _, o in ipairs(bodies) do
            if o.solidFull and not o.oneway and o.alive ~= false and not o.dying and o ~= skipA and o ~= skipB then
                local ob = o:getOuterBounds(OB)
                if ob.x < b and ob.x + ob.w > a and ob.y < bot and ob.y + ob.h > top then return nil end
            end
        end
    end
    return lift, face
end

return StepUp
