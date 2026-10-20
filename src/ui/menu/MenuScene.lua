-- src/ui/menu/MenuScene.lua
-- EL FONDO VIVO de los menús (docs/architecture/menus.md): un trozo de un NIVEL DE VERDAD de cada isla (cielo con paralaje,
-- bloques, agua, decoraciones, luz; dibujado como en las cinemáticas: Stage.drawSet) y el monstruo corriendo por
-- él con su física de verdad (src/story/Actor.lua: un PlayerAdventure movido por un mando de mentira). Cada
-- escena dura hasta SCENE_TIME s (o hasta que el nivel se acaba o el monstruo se atasca) y pasa a la siguiente con
-- un fundido de PÍXELES (tramado por bloques). Es un módulo con estado propio: sigue igual al cambiar de pantalla
-- de menú, así que las pantallas entran y salen sobre el mismo fondo, sin cortes.
--   MenuScene.update(dt)   (cada pantalla de menú, en su update)
--   MenuScene.draw()       (cada pantalla de menú, lo primero de su render)
--   MenuScene.dim(a)       velo oscuro encima (para que se lea lo de delante)
--   MenuScene.backdrop()   el fondo + un PANEL oscuro grande encima: para las pantallas de contenido (partidas,
--                          juego libre, online) que se diseñaron sobre negro
--   MenuScene.reset(i)     empezar en la escena i (las pruebas)
-- Solo dibujo y un actor local: no toca la red ni las partidas.
local Stage = require 'src/story/Stage'
local Actor = require 'src/story/Actor'
local Particles = require 'src/fx/Particles'

local MenuScene = {}

-- Las escenas, en orden: niveles de las islas (de día, al atardecer, de noche) por los que el monstruo corre
-- las SCENE_TIME s enteras sin atascarse (para elegir otro: tools/tests/run.sh menu_flow LEVELS=a,b,c). Añadir una =
-- una línea.
MenuScene.SCENES = {
    { level = 'valle_soleado' },          -- la Pradera, de día
    { level = 'cala_de_los_muelles' },    -- la Costa
    { level = 'jardin_gummies' },         -- el bosque
    { level = 'cumbres_escarcha' },       -- las Cumbres
    { level = 'fortaleza_malvada' },      -- la Fortaleza, de noche
    { level = 'lago_de_cristal' },        -- las Cumbres, al atardecer
    { level = 'caldera_roja' },           -- el volcán
}
MenuScene.SCENE_TIME = 16       -- s como mucho por escena
MenuScene.FADE = 0.9            -- s del fundido de píxeles entre escenas
MenuScene.CELL = 16             -- px (de pantalla) de cada bloque del fundido
MenuScene.CAM_X = 0.14          -- el monstruo va a este tanto del ancho de la pantalla (a la izquierda: los
                                --  botones están en el centro)
MenuScene.CAM_Y = 0.70          -- … y a este tanto del alto
MenuScene.EDGE = 3              -- casillas del borde izquierdo del nivel que no se enseñan (la pared del borde)

local T = TILE_PX
local cur, nxt, fadeT, index, canvas
local stats = { scenes = 0, stuck = 0 }    -- (para las pruebas)
MenuScene.stats = stats

local ditherShader
local function dither()
    if ditherShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            extern number k;
            extern number cell;
            float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
            float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
            vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
                if (bayer4(floor(sc / cell)) >= k) discard;
                return Texel(t, uv) * c;
            }
        ]])
        ditherShader = ok and sh or false
    end
    return ditherShader or nil
end

-- Dónde quiere estar la cámara (el monstruo en CAM_X, CAM_Y; sin salirse del nivel ni enseñar su borde izquierdo)
local function camTarget(sc)
    local b = sc.actor.body
    local x = math.max(MenuScene.EDGE * T, math.min(sc.lw - WINDOW_W, b.x - WINDOW_W * MenuScene.CAM_X))
    local y = math.max(0, math.min(sc.lh - WINDOW_H, b.y - WINDOW_H * MenuScene.CAM_Y))
    return x, y
end

local function newScene(i)
    local def = MenuScene.SCENES[i]
    local Level = require 'src/world/level/Level'
    local lv = Level.new('assets/levels/' .. def.level .. '.json')
    lv.players, lv.canBreak = {}, false
    local sx, sy = lv:getSpawnPx()
    local a = Actor.new(lv, sx, sy, { mute = true })
    local b = a.body
    local sc = { i = i, set = { level = lv }, actor = a, t = 0, lastX = b.x, stuckT = 0, ended = false,
                 lw = lv.tileW * T, lh = lv.tileH * T }
    sc.camX, sc.camY = camTarget(sc)
    return sc
end

-- ── El monstruo: corre a la derecha y salta lo que haga falta ─────────────────
local function solid(lv, x, y) return lv:collisionAt(x, y, true) ~= nil end
local function danger(lv, x, y)
    return lv:hasSpikeCellInBox(x - 8, y - 8, 16, 16) or lv:liquidAt(x, y) ~= nil
end
-- ¿hay suelo pisable (sin peligro) bajo x, a menos de `rows` casillas de los pies?
local function groundBelow(lv, x, feet, rows)
    for dy = 4, rows * T, 12 do
        if danger(lv, x, feet + dy - 12) then return false end
        if solid(lv, x, feet + dy) then return true end
    end
    return false
end

local function think(sc, dt)
    local a, lv = sc.actor, sc.set.level
    local b = a.body
    a.mx = 1
    local feet = b.y + b.h / 2
    local front = b.x + b.w / 2 + 14
    if b.onGround then
        local wall = solid(lv, front, feet - 12) or solid(lv, front, feet - T * 0.8)
        local ahead = b.x + T * 0.9
        if wall or not groundBelow(lv, ahead, feet, 3) or danger(lv, ahead, feet - 16) then
            a:jump(); sc.double = true
        end
    elseif sc.double and b.vy > -90 then
        -- en lo alto del salto: doble salto si aún hay pared, hueco o peligro delante
        sc.double = false
        local ahead = b.x + T * 1.4
        if solid(lv, front, feet - 4) or not groundBelow(lv, ahead, feet, 4) then a:jump() end
    end
    -- atascado (una pared demasiado alta): salta; si sigue, se acaba la escena
    if b.x - sc.lastX > 6 then sc.lastX, sc.stuckT = b.x, 0 else sc.stuckT = sc.stuckT + dt end
    if sc.stuckT > 0.8 and b.onGround then a:jump(); sc.double = true end
    return sc.stuckT > 1.8
end

local function updateScene(sc, dt)
    sc.t = sc.t + dt
    local stuck = think(sc, dt)
    local lv = sc.set.level
    sc.actor:update(dt, lv)
    lv:update(dt)
    if lv.updateFoliage then lv:updateFoliage(dt) end
    local b = sc.actor.body
    local tx, ty = camTarget(sc)
    sc.camX = sc.camX + (tx - sc.camX) * math.min(1, dt * 5)
    sc.camY = sc.camY + (ty - sc.camY) * math.min(1, dt * 3)
    if sc.endReason then return true end
    sc.endReason = (stuck and 'atascado') or (sc.t >= MenuScene.SCENE_TIME and 'tiempo')
                   or (b.x > sc.lw - WINDOW_W * 0.5 and 'fin del nivel') or (b.y > sc.lh and 'cae') or nil
    if stuck then stats.stuck = stats.stuck + 1 end
    return sc.endReason ~= nil
end

local function drawScene(sc)
    Stage.drawSet(sc.set, sc.camX, sc.camY, function() sc.actor:draw() end)
end

-- ── API ─────────────────────────────────────────────────────────────────────
function MenuScene.reset(i)
    index = i or love.math.random(#MenuScene.SCENES)
    cur, nxt, fadeT = newScene(index), nil, nil
    stats.scenes = 1
    Particles.clear()
    Particles.setLevel(nil)
end

function MenuScene.current() return cur end
function MenuScene.fading() return nxt ~= nil end

function MenuScene.update(dt)
    if not cur then MenuScene.reset() end
    local over = updateScene(cur, dt)
    if nxt then
        updateScene(nxt, dt)
        fadeT = fadeT + dt
        if fadeT >= MenuScene.FADE then cur, nxt, fadeT = nxt, nil, nil end
    elseif over then
        index = index % #MenuScene.SCENES + 1
        nxt, fadeT = newScene(index), 0
        stats.scenes = stats.scenes + 1
    end
    Particles.update(dt)
end

function MenuScene.draw()
    if not cur then MenuScene.reset() end
    drawScene(cur)
    if nxt then
        local sh = dither()
        if not sh then
            drawScene(nxt)                      -- (sin shaders: corte directo)
        else
            if not canvas or canvas:getWidth() ~= WINDOW_W or canvas:getHeight() ~= WINDOW_H then
                canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
            end
            -- (la escena nueva en su lienzo, sin la transformación de lovesize; luego se pone encima tramada)
            love.graphics.push('all')
            love.graphics.origin()
            love.graphics.setScissor()
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 1)
            drawScene(nxt)
            love.graphics.pop()
            local sx = select(1, love.graphics.transformPoint(1, 0)) - select(1, love.graphics.transformPoint(0, 0))
            sh:send('k', math.min(1, fadeT / MenuScene.FADE))
            sh:send('cell', math.max(1, math.floor(MenuScene.CELL * sx + 0.5)))
            love.graphics.setShader(sh)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(canvas, 0, 0)
            love.graphics.setShader()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

MenuScene.MARGIN = 24        -- px de fondo vivo que deja ver el panel de MenuScene.backdrop
function MenuScene.backdrop()
    MenuScene.draw()
    local m = MenuScene.MARGIN
    require('src/ui/menu/MenuButton').panel(m, m, WINDOW_W - 2 * m, WINDOW_H - 2 * m)
end

function MenuScene.dim(a)
    love.graphics.setColor(0.04, 0.05, 0.12, a or 0.35)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(1, 1, 1, 1)
end

return MenuScene
