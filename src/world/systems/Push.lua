-- src/world/systems/Push.lua
-- EMPUJONES de aire: lo que sopla (la racha del Soplón, la Ventisca, el chorro del Géiser) mueve a los jugadores y a
-- todo lo que tiene física (enemigos, cajas, bombas, semillas…) SIN hacer daño. Un sistema para todos: una entidad que
-- sopla solo declara `pushAt(x, y)` → (wx, wy) = la velocidad del aire en ese punto (px/s; 0, 0 = nada) y el juego la
-- junta en `level.pushers` (Push.collect, a la vez que los cuerpos sólidos: un jugador, servidor y la predicción del
-- cliente — que la calcula con lo que llega en las instantáneas, así no hay correcciones —).
--   * De lado: el aire ARRASTRA (se suma al avance, como la resaca de una inundación), con un poco de inercia.
--   * Hacia arriba: frena la caída y eleva hacia esa velocidad (ayuda a volar; el géiser lanza).
--   * Hacia abajo: empuja hacia el suelo (cuesta subir).
local Push = {}

local SIDE_K = 6          -- 1/s: lo rápido que el arrastre de lado llega a la velocidad del aire (inercia)
local UP_K   = 4          -- 1/s: lo rápido que el aire de abajo lleva la caída hacia su velocidad
local DOWN_A = 2          -- × la velocidad del aire: aceleración hacia abajo (px/s²) del que sopla hacia el suelo
local ENTITY = 0.8        -- a las entidades el aire las mueve un poco menos (pesan más que el monstruo)

-- Las que soplan, de una lista de entidades (vivas)
function Push.collect(list)
    local out = {}
    for _, e in pairs(list or {}) do
        if e.pushAt and e.alive then out[#out + 1] = e end
    end
    return out
end

-- Velocidad del aire en un punto: la suma de todo lo que sopla ahí. Un tercer valor de `pushAt` = lo BRUSCO que es
-- (× la rapidez con la que lleva la velocidad hacia la suya: 1 = viento, el Géiser ~10 = un chorro explosivo).
-- `pushAt(x, y, o)` recibe también A QUIÉN (jugador o entidad): el Géiser empuja distinto lo que levanta; un cuarto
-- valor `true` = ya contó su peso (no se multiplica por su `windK`)
function Push.at(level, x, y, o)
    local wx, wy, k, exact = 0, 0, 1, false
    for _, p in ipairs(level.pushers or {}) do
        local ax, ay, ak, ex = p:pushAt(x, y, o)
        if ax then wx, wy = wx + ax, wy + (ay or 0); k = math.max(k, ak or 1); exact = exact or ex == true end
    end
    return wx, wy, k, exact
end

-- La vertical: hacia arriba lleva la velocidad hacia la del aire; hacia abajo acelera
local function vertical(o, wy, dt, k)
    if wy < 0 then
        if o.vy > wy then o.vy = o.vy + (wy - o.vy) * math.min(1, UP_K * (k or 1) * dt) end
    elseif wy > 0 then
        o.vy = o.vy + wy * DOWN_A * dt
    end
end

-- Jugador (PlayerAdventure._update): cambia su vy y devuelve el arrastre de lado (px/s) que se suma a su avance
function Push.player(pa, level, dt)
    local wx, wy, k = 0, 0, 1
    if level.pushers and level.pushers[1] then wx, wy, k = Push.at(level, pa.x, pa.y, pa) end
    pa.windVx = (pa.windVx or 0) + (wx - (pa.windVx or 0)) * math.min(1, SIDE_K * dt)
    if math.abs(pa.windVx) < 1 and wx == 0 then pa.windVx = 0 end
    if wy ~= 0 then
        vertical(pa, wy, dt, k)
        if wy < 0 and pa.vy < -40 then pa.onGround = false end
    end
    return pa.windVx
end

-- ¿Lo mueve el aire? Lo que tiene física: enemigos y objetos sueltos (no los coleccionables fijos, los jefes, los
-- de reserva ni los que van pegados a una pared). Un tipo puede decir otra cosa con `canBePushed()`.
function Push.canPush(e)
    if e.canBePushed then return e:canBePushed() end
    local d = e.def or {}
    if d.boss or d.pickup or d.checkpoint or e.pushAt then return false end
    if d.category ~= 'Enemigos' and d.category ~= 'Objetos' then return false end
    if not e.alive or e.state == 'reserve' or e.state == 'gone' or e.state == 'carried' or e.cattached then return false end
    return true
end

-- Entidad (Entity:update, antes de su propio paso)
function Push.entity(e, level, dt)
    local wx, wy, sharp, exact = Push.at(level, e.x, e.y, e)
    if wx == 0 and wy == 0 then return end
    -- (lo pesado se mueve menos — la Caja grande —; `exact`: quien sopla ya tuvo en cuenta su peso — el Géiser —)
    local k = exact and 1 or ENTITY * (e.windK or 1)
    if wx ~= 0 then e:moveAndCollide(level, wx * k * dt, 0) end
    if wy ~= 0 and not e.flying then
        e.vy = e.vy or 0
        vertical(e, wy * k, dt, sharp)
        if e.vy < -40 then e.onGround = false end
    end
end

return Push
