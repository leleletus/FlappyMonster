-- src/ui/IntroScene.lua
-- LA ESCENA de la tarjeta de presentación (0.5.203, el usuario: «que el fondo sea el del nivel y que el monstruo y el
-- enemigo caminen, se animen y suenen como en un nivel de verdad»): detrás de las bandas (src/ui/IntroCard.lua), una
-- tira de nivel DE VERDAD — un AdventureState en modo demo, como el fondo de los menús (src/ui/menu/MenuScene.lua) —
-- con el fondo del nivel que empieza (su cielo, su hora, sus nubes, su luz) y su suelo (las casillas de superficie más
-- comunes del nivel), el ENEMIGO de su isla (Worlds.INTRO) y el MONSTRUO de siempre (con su filo blanco: `outline`,
-- src/fx/Silhouette.lua) que entra andando por la izquierda y se va por la derecha. Por el camino, al azar: SALTA por
-- encima del enemigo, lo PISA o le HACE DAÑO. Sus sonidos, los de siempre. Nada de esto cuenta para el nivel de verdad
-- (ni muertes, ni golpes, ni enemigos vencidos: regla 7). Solo cliente: el servidor no la ve.
--   local sc = IntroScene.new(level, id[, o])   level = el nivel que empieza (su fondo y su suelo); id = su archivo;
--                                               o.outcome = 'jump' | 'stomp' | 'hurt' (si no, al azar)
--   sc:update(dt, hold, restore)   hold = true: el monstruo se queda en pantalla esperando (online, mientras el servidor
--                                  espera a los demás); restore() = el que llama vuelve a apuntar sus globales a SU nivel
--   sc:draw()                      la escena a pantalla completa
--   sc.player, sc.enemy, sc:gone() (el monstruo ya salió por la derecha), sc.outcome
local IntroScene = {}
IntroScene.__index = IntroScene

IntroScene.FILE = 'intro_scene.json'    -- (la tira se escribe en la carpeta de guardado, como la prueba del editor)
IntroScene.CROSS = 4.2                  -- s en cruzar la pantalla sin esperar (dentro de los CARD_TIME de la tarjeta)
IntroScene.HOLD_AT = 0.3                -- … esperando: se para a este tanto del ancho
IntroScene.OUTCOMES = { 'jump', 'stomp', 'hurt' }

local MARGIN = 3                        -- casillas fuera de la pantalla a cada lado

-- Las casillas del SUELO del nivel: la de superficie más común (sólida, con aire encima, sin peligro ni mecanismo) y la
-- más común debajo de ella. Si no hay ninguna clara, las de la isla (Worlds.INTRO top / under)
local function groundOf(level, look)
    local TileTypes = require 'src/world/tiles/TileTypes'
    local function plain(d) return d and d.collision == 'solid' and not d.trigger and not d.hazard and not d.damage and not d.breakable end
    local tops, unders = {}, {}
    if level and level.tiles then
        for r = 2, level.tileH - 1 do
            for c = 1, level.tileW do
                local d, up = level:getDef(c, r), level:getDef(c, r - 1)
                if plain(d) and up and up.collision == 'none' then
                    local raw = level:getRaw(c, r)
                    tops[raw] = (tops[raw] or 0) + 1
                    local below = level:getDef(c, r + 1)
                    if plain(below) then
                        local b = unders[raw] or {}
                        unders[raw] = b
                        local braw = level:getRaw(c, r + 1)
                        b[braw] = (b[braw] or 0) + 1
                    end
                end
            end
        end
    end
    local function best(t) local k, n = nil, 0; for v, m in pairs(t or {}) do if m > n then k, n = v, m end end; return k end
    local top = best(tops)
    local under = top and best(unders[top]) or top
    if not top then
        local function byImg(p) local t = p and TileTypes.byName[p:match('([^/]+)%.png$') or ''] return t and t.id end
        top = byImg(look.top) or (TileTypes.byName.grass and TileTypes.byName.grass.id) or 1
        under = byImg(look.under) or top
    end
    return top, under or top
end

function IntroScene.new(level, id, o)
    o = o or {}
    local Worlds = require 'src/story/Worlds'
    local look = Worlds.introOf(id)
    local W, H = WINDOW_W, WINDOW_H
    local cols = math.ceil(W / TILE_PX) + 2 * MARGIN
    local rows = math.ceil(H / TILE_PX) + 1
    local top, under = groundOf(level, look)
    local tiles = {}
    for r = 1, rows do
        tiles[r] = {}
        for c = 1, cols do tiles[r][c] = (r == rows - 1) and top or (r == rows) and under or 0 end
    end
    local groundRow = rows - 1
    -- el enemigo, a 3/5 de la pantalla, paseando un poco
    local ec = MARGIN + math.floor(W / TILE_PX * 0.62) + 1
    local data = {
        name = 'intro', width = cols, height = rows, playerStart = { 2, groundRow - 1 }, tiles = tiles,
        entities = { { type = look.enemy or 'gummy', col = ec, row = groundRow - 1, props = { patrol = { left = ec - 1, right = ec + 1 } } } },
        foliage = {}, vents = {},
        -- el FONDO del nivel que empieza (src/fx/Sky.lua) y su luz; sin profundidad ni oscuridad (es un escenario)
        background = level and level.background, time = level and level.timeOfDay, clouds = level and level.clouds,
        light = level and level.light ~= 'cave' and level.light or nil,
    }
    love.filesystem.write(IntroScene.FILE, require('libs/json').encode(data))

    local self = setmetatable({ t = 0, look = look, groundRow = groundRow }, IntroScene)
    local rng = love.math.newRandomGenerator(o.seed or os.time())
    self.outcome = o.outcome or IntroScene.OUTCOMES[rng:random(1, #IntroScene.OUTCOMES)]
    self.stub = require('src/network/Protocol').newInputStub()
    self.camX = MARGIN * TILE_PX
    self.camY = rows * TILE_PX - H
    -- (la tira es un nivel de verdad en modo DEMO: sin HUD, sin música, sin pausa; el jugador lo mueve `step`)
    local AdventureState = require 'src/states/adventure/AdventureState'
    local st = AdventureState:new()
    local Entity = require 'src/world/entities/base/Entity'
    local PlayerAdventure = require 'src/player/PlayerAdventure'
    local keepKill, keepPfx, keepEfx = Entity.onKill, PlayerAdventure.fx, Entity.fx
    st:enter({ level = IntroScene.FILE, returnTo = 'main_menu',
               demo = { camera = function() return self.camX, self.camY end,
                        step = function(dt, lv) self:_step(dt, lv) end } })
    Entity.onKill, PlayerAdventure.fx, Entity.fx = keepKill, keepPfx, keepEfx
    self.st = st
    self.player = st.player
    self.enemy = st.enemies[1]
    -- (cruza la pantalla en CROSS s: su velocidad de andar, escalada al ancho — en pantallas anchas anda más deprisa —)
    local dist = W + 2 * TILE_PX
    self.player.moveK = math.max(1, math.min(1.5, dist / (ADV_MOVE_SPD * IntroScene.CROSS)))
    self.player.facing = 1
    self.player.knockK = 0.35                 -- (el golpe se nota pero no lo devuelve atrás: sale a tiempo por la derecha)
    return self
end

-- ¿Ya salió por la derecha?
function IntroScene:gone() return self.player.x > self.camX + WINDOW_W + TILE_PX * 0.75 end

-- Lo que pulsa el monstruo (en lugar del mando): andar a la derecha; al llegar al enemigo, lo de esta vez
function IntroScene:_think(hold)
    local s, p, e = self.stub.state, self.player, self.enemy
    for k in pairs(s) do s[k] = false end
    if hold and p.x >= self.camX + WINDOW_W * IntroScene.HOLD_AT then return end      -- (esperando: quieto)
    s.right = true
    local d = (e and e.alive) and (e.x - p.x) or math.huge
    if self.jumpT then
        self.jumpT = self.jumpT - 1 / 60
        s.jump = self.jumpT > 0
        if self.jumpT <= -0.5 then self.jumpT = nil end
        return
    end
    if self.done or not e or not e.alive then return end
    -- (con el salto entero: saltando LEJOS del enemigo cae encima — ~0,59 s de vuelo hasta la altura de su cabeza —;
    -- saltando CERCA pasa por encima — sobre él a ~0,31 s, aún subiendo —; sin saltar se lo come)
    local vx = math.max(60, p.vx - (e.vx or 0))           -- (lo que se acercan: el enemigo también anda)
    if self.outcome == 'jump' and d < vx * 0.31 and p.onGround then
        s.jump, s.jump_pressed, self.jumpT, self.done = true, true, 0.45, true
    elseif self.outcome == 'stomp' and d < vx * 0.59 and p.onGround then
        s.jump, s.jump_pressed, self.jumpT, self.done = true, true, 0.45, true
    end
end

function IntroScene:_step(dt, level)
    local real = Input
    Input = setmetatable({ pressed = self.stub.pressed, down = self.stub.down }, { __index = real })
    local ok, err = pcall(self.player.update, self.player, dt, level)
    Input = real
    if not ok then error(err, 0) end
end

function IntroScene:update(dt, hold, restore)
    local Entity = require 'src/world/entities/base/Entity'
    local PlayerAdventure = require 'src/player/PlayerAdventure'
    local keepKill, keepPfx, keepEfx = Entity.onKill, PlayerAdventure.fx, Entity.fx
    Entity.onKill = nil                                -- (vencer al enemigo de la escena no cuenta en el nivel)
    self.st:rebindGlobals()
    self.st.sceneCanvas = require('src/fx/SceneCanvas').get()
    self.acc = math.min((self.acc or 0) + dt, 0.1)
    while self.acc >= 1 / 60 do                        -- (a pasos fijos: la escena sale igual en cualquier aparato)
        self.acc = self.acc - 1 / 60
        self.t = self.t + 1 / 60
        self:_think(hold)
        if self.player.hp < self.player.hpMax then self.hurtSeen = true end
        self.st:update(1 / 60)
        Sound.setListener(self.camX + WINDOW_W / 2, self.player.y)
    end
    Entity.onKill, PlayerAdventure.fx, Entity.fx = keepKill, keepPfx, keepEfx
    require('src/ui/HitStop').reset()                  -- (un golpe de la escena no congela el nivel de verdad)
    if restore then restore() end
end

function IntroScene:draw()
    self.st:render()
end

-- Al acabar: sin las partículas de la escena (estaban en otro nivel) y sin el archivo de la tira
function IntroScene:finish()
    require('src/fx/Particles').clear()
    love.filesystem.remove(IntroScene.FILE)
end

return IntroScene
