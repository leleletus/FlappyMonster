-- src/world/level/SceneLayers.lua
-- EL ORDEN DE LAS CAPAS de la escena de un nivel, en UN sitio: lo usan el juego de un jugador (AdventureState) y el
-- cliente online (OnlineAdventureRender). Antes cada uno llevaba su copia de la lista y una capa nueva (las gotas del
-- hielo, la lava, la nieve...) había que acordarse de ponerla en los dos (regla de oro 1: lo que se ve, igual en los
-- dos sitios).
--
--   SceneLayers.draw(level, camX, camY, canvas, ents, actors[, noSky])
--     canvas  el lienzo de la escena (src/fx/SceneCanvas.lua): todo se dibuja en él y luego va a donde se estaba
--             dibujando con el efecto del agua por encima
--     ents    las entidades (lista o tabla por índice: se recorre con pairs, el orden de una lista se respeta)
--     actors  function(camX, camY): lo que va entre las entidades de atrás y las de delante — los jugadores, el
--             fantasma, los bots, el progreso de las zonas de puntos — ya con el filo de lo oscuro de los monstruos
--             (PlayerAdventure.lightLevel)
--     noSky   sin cielo: fondo transparente (los créditos, que dibujan su escena detrás)
--     reuse   no redibuja el lienzo: vuelve a poner la escena del fotograma anterior (el hit-stop online: solo en esta
--             pantalla, la partida sigue — src/ui/HitStop.lua —)
-- La oscuridad, los fragmentos, las ayudas y el HUD van DESPUÉS, fuera del lienzo: los pone cada estado.
local IceDrips        = require 'src/fx/IceDrips'
local LavaFx          = require 'src/fx/LavaFx'
local Sky             = require 'src/fx/Sky'
local Snowfall        = require 'src/fx/Snowfall'
local Darkness        = require 'src/fx/Darkness'
local Particles       = require 'src/fx/Particles'
local Ambience        = require 'src/fx/Ambience'
local Silhouette      = require 'src/fx/Silhouette'

local SceneLayers = {}

local PlayerAdventure, Entities           -- (perezosos: los dos requieren cosas que requieren el nivel)

local function drawEntities(ents, front, camX, camY)
    for _, g in pairs(ents) do
        if g.alive and (not g:drawsInFront()) ~= front then (g.renderLive or g.render)(g, camX, camY) end   -- (reservas: no)
    end
end

function SceneLayers.draw(level, camX, camY, canvas, ents, actors, noSky, reuse)
    if reuse then
        love.graphics.setColor(1, 1, 1, 1)
        level:renderWaterEffect(camX, camY, canvas)
        return
    end
    PlayerAdventure = PlayerAdventure or require 'src/player/PlayerAdventure'
    Entities = Entities or require 'src/world/entities/Entities'
    ents = ents or {}

    -- ── Aislar transformaciones para el lienzo (evita zoom doble y cortes) ──
    love.graphics.push()
    love.graphics.origin()
    -- El recorte de lovesize (bandas negras) está en píxeles de la PANTALLA: dentro del lienzo de la escena (tamaño
    -- lógico) recortaba otra zona y, con la ventana a otro tamaño que 1280x720, el juego salía cortado/descuadrado
    local scX, scY, scW, scH = love.graphics.getScissor()
    love.graphics.setScissor()
    local outCanvas = love.graphics.getCanvas()          -- (a dónde va luego: la pantalla, o el lienzo de quien la dibuja)
    love.graphics.setCanvas(canvas)
    if noSky then
        love.graphics.clear(0, 0, 0, 0)                    -- (sin cielo: se ve lo que haya detrás; los créditos)
    else
        love.graphics.clear(0, 0, 0, 1)
        Sky.punch = Darkness.active(level) and not level.dark      -- (lo incandescente del fondo: ver Sky.lua)
        Sky.render(level, camX, camY)                      -- (cielo y fondo con paralaje)
        Sky.punch = false
    end

    level:renderBackPlane(camX, camY)                     -- (el plano de fondo: detrás de todo menos del cielo)
    Entities.renderBack(ents, camX, camY)                 -- (lo que las entidades dibujan detrás de los bloques)
    level:render(camX, camY, true)
    IceDrips.render(level, camX, camY)                    -- (gotas del hielo: solo dibujo)
    Ambience.tick(level)                                  -- (ambiente de la isla: cuevas, jungla... solo sonido)
    LavaFx.render(level, camX, camY)                      -- (burbujas de la lava: solo dibujo)
    level:renderVents(camX, camY)
    level:renderFoliageBack(camX, camY)

    Silhouette.level = level                              -- (filo de los enemigos oscuros en lo oscuro: `darkEdge`)
    drawEntities(ents, false, camX, camY)                 -- (entre los bloques y los jugadores)

    PlayerAdventure.lightLevel = level                    -- (en lo oscuro, filo blanco: cada monstruo según SU sitio)
    if actors then actors(camX, camY) end
    PlayerAdventure.lightLevel = nil
    Particles.render(camX, camY)

    drawEntities(ents, true, camX, camY)                  -- (por delante de los jugadores: pez globo, la red…)
    level:renderFoliage(camX, camY)                       -- (decoraciones: por encima de entidades y jugadores)
    level:renderBubbles(camX, camY)                       -- (burbujas de agua y respiraderos: encima de todo menos el agua)
    Snowfall.render(level, camX, camY)                    -- (nieve cayendo: solo dibujo)

    love.graphics.setCanvas(outCanvas)
    if scX then love.graphics.setScissor(scX, scY, scW, scH) end
    love.graphics.pop()

    -- ── Volver a donde se dibujaba y aplicar el efecto del agua ──
    love.graphics.setColor(1, 1, 1, 1)
    level:renderWaterEffect(camX, camY, canvas)
end

return SceneLayers
