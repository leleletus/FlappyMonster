-- src/story/Score.lua
-- NOTA de un nivel (modo historia): de lo que pasó en él (las estadísticas que da AdventureState
-- al llegar a la meta) sale una valoración de 0 a 100 y su LETRA. Todo aquí, en una tabla: cambiar
-- el reparto o los cortes es tocar WEIGHTS / GRADES.
--   tiempo     30   entero si se tarda ≤ el tiempo de referencia del nivel (PAR_PER_TILE s por
--                   casilla de ancho, mínimo PAR_MIN); baja hasta 0 al triple
--   vidas      25   -1/3 por cada vida perdida
--   golpes     10   -1/6 por cada golpe recibido
--   enemigos   15   × los eliminados de los que se pueden eliminar (sin enemigos: entero)
--   estrellas  20   × las cogidas (sin estrellas: entero)
-- La nota de un MUNDO es la media de la mejor valoración de cada uno de sus niveles.
-- Premios (Score.reward): la primera vez que se saca S en un nivel, +1 vida; A, puntos extra.
-- Al completar un mundo (su jefe), según su nota: S +2 vidas, A +1 vida, B puntos extra.
local Score = {}

Score.WEIGHTS = { time = 30, lives = 25, hits = 10, kills = 15, stars = 20 }
Score.GRADES = { { 'S', 95 }, { 'A', 85 }, { 'B', 70 }, { 'C', 50 }, { 'D', 0 } }
Score.PAR_PER_TILE, Score.PAR_MIN = 0.75, 40

local function clamp(v) return math.max(0, math.min(1, v)) end

function Score.par(widthTiles) return math.max(Score.PAR_MIN, (widthTiles or 0) * Score.PAR_PER_TILE) end

function Score.grade(rating)
    for _, g in ipairs(Score.GRADES) do
        if rating >= g[2] then return g[1] end
    end
    return 'D'
end

-- stats: { time, par, deaths, hits, kills, killable, stars, starsTotal }
-- → { rating (0-100, entero), grade, parts = { time, lives, hits, kills, stars } (puntos de cada parte) }
function Score.level(st)
    local W = Score.WEIGHTS
    local par = st.par or Score.PAR_MIN
    local parts = {
        time  = W.time * clamp(1 - ((st.time or 0) - par) / (2 * par)),
        lives = W.lives * clamp(1 - (st.deaths or 0) / 3),
        hits  = W.hits * clamp(1 - (st.hits or 0) / 6),
        kills = W.kills * (((st.killable or 0) > 0) and clamp((st.kills or 0) / st.killable) or 1),
        stars = W.stars * (((st.starsTotal or 0) > 0) and clamp((st.stars or 0) / st.starsTotal) or 1),
    }
    local total = 0
    for _, v in pairs(parts) do total = total + v end
    local rating = math.floor(total + 0.5)
    return { rating = rating, grade = Score.grade(rating), parts = parts }
end

-- Media de las mejores valoraciones de una lista de niveles (los que falten cuentan 0)
function Score.average(ratings, n)
    local sum = 0
    for _, r in ipairs(ratings) do sum = sum + r end
    local avg = (n or #ratings) > 0 and math.floor(sum / (n or #ratings) + 0.5) or 0
    return avg, Score.grade(avg)
end

-- Premio por una letra: { lives = n } / { points = n } / nil
Score.LEVEL_REWARD = { S = { lives = 1 }, A = { points = 500 } }
Score.WORLD_REWARD = { S = { lives = 2 }, A = { lives = 1 }, B = { points = 1000 } }

return Score
