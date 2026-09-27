-- src/world/entities/Crawler.lua
-- Movimiento "trepador": una entidad pegada a la superficie de los bloques que
-- la rodea entera — suelo, paredes y techo — girando en las esquinas (como
-- los bichos que dan vueltas a los bloques en los plataformas clásicos).
-- Lo usan los Crabbies con la propiedad "Anda por paredes y techos".
--
-- Estado en la entidad:
--   e.cnx, e.cny   normal de la superficie (hacia donde queda el aire):
--                  suelo (0,-1), techo (0,1), pared a su izquierda (1,0)...
--   e.cdir         ±1 sentido de avance a lo largo de la superficie
-- El avance es t = r * cdir, con r = (-cny, cnx) (la "derecha" local).
-- El centro queda a outerH/2 de la superficie: la misma altura a la que se
-- apoya un Crabby normal en el suelo (así se ve igual y el pincho o el
-- trampolín quedan pegados al caparazón escondido, no flotando).
--
-- Esquinas (giro rígido de 90° alrededor de la esquina real, medida píxel a
-- píxel: la posición respecto a la esquina se conserva, sin saltos):
--   * cóncava (pared delante): gira hacia arriba de esa pared.
--   * convexa (se acaba el bloque): da la vuelta al borde y sigue por el
--     otro lado del mismo bloque.
-- Si se queda sin nada a lo que agarrarse (p. ej. rompen el bloque), se
-- suelta y cae (Crawler.detach): vuelve a agarrarse al tocar el suelo.

local Crawler = {}

-- Tiles (con su forma real) y objetos sólidos (trampolines, morteros...)
local function solid(level, x, y) return level:entitySolidAt(x, y) end

local function halfH(e) return e.outerH / 2 end
local function halfW(e) return e.sprW * 0.45 end

-- Ángulo de dibujo: el "arriba" del sprite apunta a la normal
function Crawler.angle(e)
    return math.atan2(e.cnx, -e.cny)
end

-- ¿Está en una pared (no en suelo ni techo)?
function Crawler.onWall(e) return e.crawl and e.cnx ~= 0 end

-- Vectores locales: derecha (r) y abajo (d = -n)
function Crawler.axes(e)
    return -e.cny, e.cnx, -e.cnx, -e.cny
end

-- Caja local (lx, ly = esquina sup-izq con el origen en el centro, "arriba"
-- = normal) → caja en el mundo (las rotaciones son de 90°)
function Crawler.toWorldBox(e, lx, ly, w, h)
    local rx, ry, dx, dy = Crawler.axes(e)
    local x0, y0 = math.huge, math.huge
    local x1, y1 = -math.huge, -math.huge
    for _, c in ipairs({ { lx, ly }, { lx + w, ly }, { lx, ly + h }, { lx + w, ly + h } }) do
        local wx = e.x + rx * c[1] + dx * c[2]
        local wy = e.y + ry * c[1] + dy * c[2]
        x0, y0 = math.min(x0, wx), math.min(y0, wy)
        x1, y1 = math.max(x1, wx), math.max(y1, wy)
    end
    return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

-- Busca a qué superficie agarrarse alrededor de su posición (preferencia:
-- la normal que ya tenga, luego suelo, techo y paredes)
-- `maxD` = hasta dónde buscar (px más allá de hh). Por defecto media casilla;
-- al colocarla, una casilla entera (bajo una losa fina, su cara de abajo
-- queda más lejos que el borde de la celda).
function Crawler.attach(e, level, maxD)
    local hh = halfH(e)
    maxD = maxD or TILE_PX / 2
    local cands = { { e.cnx or 0, e.cny or -1 }, { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }
    for _, n in ipairs(cands) do
        local nx, ny = n[1], n[2]
        -- La superficie tiene que estar a menos de media casilla; se busca
        -- píxel a píxel para quedar exactamente apoyado
        for d = -8, maxD do
            if solid(level, e.x - nx * (hh + d), e.y - ny * (hh + d))
               and not solid(level, e.x - nx * (hh + d - 1), e.y - ny * (hh + d - 1)) then
                e.cnx, e.cny = nx, ny
                e.x, e.y = e.x - nx * (d - 1), e.y - ny * (d - 1)        -- pegado
                e.cattached = true
                return true
            end
        end
    end
    e.cattached = false
    return false
end

-- Objeto sólido (trampolín...) sobre el que está apoyado y cuál de sus caras
-- pisa (según la normal: suelo → su cara 'top', techo → 'bottom'...), o nil
local FACE_OF = { ['0,-1'] = 'top', ['0,1'] = 'bottom', ['1,0'] = 'right', ['-1,0'] = 'left' }
function Crawler.supportBody(e, level)
    if not e.cattached then return nil end
    local hh = halfH(e)
    local o = level:bodyAt(e.x - e.cnx * (hh + 1), e.y - e.cny * (hh + 1), e)
    if not o then return nil end
    return o, FACE_OF[(e.cnx + 0) .. ',' .. (e.cny + 0)]
end

function Crawler.detach(e)
    e.cattached = false
    e.cnx, e.cny = 0, -1
end

-- Avanza `dist` px a lo largo de la superficie, girando en las esquinas.
-- Devuelve false si se ha soltado (no hay superficie).
function Crawler.move(e, level, dist)
    local hh, hw = halfH(e), halfW(e)
    local left = math.abs(dist)
    local guard = 0
    while left > 0 and guard < 40 do
        guard = guard + 1
        local s = math.min(left, 4)
        local nx, ny = e.cnx, e.cny
        local tx, ty = -ny * e.cdir, nx * e.cdir
        -- Esquina cóncava: pared justo delante → subirse a ella
        if solid(level, e.x + tx * (hw + 1), e.y + ty * (hw + 1)) then
            -- Distancia exacta a la pared (píxel a píxel) y giro rígido de 90°
            -- alrededor de la esquina: la distancia a la pared pasa a ser la
            -- altura sobre el suelo, y queda a hh de la pared (como attach)
            local D = hw + 1
            for d = 1, hw + 1 do
                if solid(level, e.x + tx * d, e.y + ty * d) then D = d; break end
            end
            local k = D - (hh + 1)
            e.x, e.y = e.x + tx * k + nx * k, e.y + ty * k + ny * k
            local nnx, nny = -tx, -ty                        -- normal de la pared
            local rx, ry = -nny, nnx
            e.cnx, e.cny = nnx, nny
            e.cdir = (rx * nx + ry * ny >= 0) and 1 or -1     -- avanzar hacia la antigua normal
        else
            e.x, e.y = e.x + tx * s, e.y + ty * s
            left = left - s
            -- Esquina convexa: ya no hay bloque debajo → dar la vuelta al borde
            if not solid(level, e.x - nx * (hh + 2), e.y - ny * (hh + 2)) then
                -- ¿Cuánto se ha pasado del borde? Se busca hacia atrás, en la
                -- primera fila sólida bajo él, la última columna del bloque
                local sx, sy = e.x - nx * (hh + 1), e.y - ny * (hh + 1)
                local J
                for j = 1, math.ceil(hw) + 8 do
                    if solid(level, sx - tx * j, sy - ty * j) then J = j; break end
                end
                if not J then Crawler.detach(e); return false end
                -- Giro rígido de 90° alrededor de la esquina: lo que se había
                -- pasado del borde pasa a ser lo que baja por el lado nuevo, y
                -- queda a hh del lado (primera columna sólida a hh + 1)
                e.x = e.x - nx * (hh + J) + tx * (hh + 1 - J)
                e.y = e.y - ny * (hh + J) + ty * (hh + 1 - J)
                local nnx, nny = tx, ty                          -- normal: hacia donde avanzaba
                local rx, ry = -nny, nnx
                e.cnx, e.cny = nnx, nny
                e.cdir = (rx * (-nx) + ry * (-ny) >= 0) and 1 or -1   -- bajar por el lado
                -- ¿Hay de verdad algo en el que apoyarse? Si no, se suelta
                if not solid(level, e.x - nnx * (hh + 2), e.y - nny * (hh + 2)) then
                    Crawler.detach(e)
                    return false
                end
            end
        end
    end
    return true
end

return Crawler
