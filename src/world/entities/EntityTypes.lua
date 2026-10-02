-- src/world/entities/EntityTypes.lua
-- Registro de TIPOS DE ENTIDAD (enemigos, NPCs...). Cada tipo es un archivo en
-- src/world/entities/types/ que devuelve su definición; se listan en
-- src/world/Entities.lua.
--
-- Definición de un tipo:
--   name, label, category (ver EntityTypes.CATEGORIES)
--   description texto corto para el editor (paleta e inspector)
--   defaults    valores por defecto de las propiedades COMUNES para este tipo
--               (p. ej. { speed = 55, points = 10 })
--   props       propiedades EXTRA propias del tipo (mismo formato que Props)
--   hide        claves de propiedades comunes que no aplican a este tipo,
--               o 'all' (objetos: trampolines, directores... sin ninguna común)
--   variant     { group='trampoline', label='Arriba', groupLabel='Trampolín' }:
--               varias definiciones que son el MISMO objeto en distintas
--               versiones (direcciones...). El editor las muestra como una sola
--               ficha con un selector (y la tecla X las recorre).
--   class       clase (derivada de Entity) con su comportamiento y dibujo
--   editor      { sprite='assets/...png', scale=4, tint={...} } miniatura
--   pickup      coleccionable: { score=25 } / { lives=1 } (se recoge al tocarlo)
--   checkpoint  true: al tocarlo pasa a ser el punto de reaparición del jugador
--   placement   'sub': se coloca en subceldas (como los pinchos); guarda `sub`
--   ceilingOnly true: solo se puede colocar justo debajo de un bloque sólido
--   inBlockOk   true: colocada dentro de un bloque no es un aviso (pez globo, zonas)
--   activatable true: se le pueden CONECTAR bloques ON/OFF (editor: capa
--               Bloques → Conectar). Tiene una propiedad `id` (si el tipo no la
--               declara, se añade sola) y en el juego pregunta
--               level:signal(id) (¿algún bloque conectado en ON?). Opcional
--               onLink(props): al conectarle un bloque en el editor (p. ej. la
--               inundación pasa a moverse con bloques ON/OFF). Ver flood.lua.
--
-- En el nivel, cada colocación es:
--   { type='crabby', col=10, row=2, props={ attach='ceiling', ... } }
-- Solo se guardan las propiedades que difieren del valor por defecto.

local Props = require 'src/world/entities/Props'
local IceEncase           -- (solo dibujo: el bloque de hielo de lo congelado)

local EntityTypes = { byName = {}, list = {}, variants = {} }

-- Categorías de la paleta del editor, en este orden (una categoría nueva que
-- no esté aquí sale al final). `description` = ayuda al pasar el ratón.
EntityTypes.CATEGORIES = {
    { id = 'Enemigos',   description = 'Criaturas que se mueven y hacen daño. Casi todas se pueden pisotear.' },
    { id = 'Jefes',      description = 'Colócalos dentro de una zona de jefe (capa Especial).' },
    { id = 'Trampas',    description = 'Peligros del escenario.' },
    { id = 'Mecanismos', description = 'Objetos que cambian el nivel: trampolines, agua...' },
    { id = 'Objetos',    description = 'Coleccionables y puntos de control.' },
    { id = 'Directores', description = 'Invisibles en la partida: controlan a otros objetos.' },
}

-- Orden de los grupos de propiedades COMUNES en el inspector. Los grupos
-- propios de un tipo (p. ej. 'Mortero', 'Inundación') van antes que estos.
EntityTypes.COMMON_GROUPS = { 'Movimiento', 'Comportamiento', 'Combate', 'Caída desde el techo', 'Reaparición' }

local function opts(...)
    local o = {}
    for _, pair in ipairs({...}) do o[#o+1] = { value = pair[1], label = pair[2] } end
    return o
end

-- Propiedades que toda entidad tiene (y el editor muestra), salvo que el tipo
-- las oculte con `hide`. Los tipos cambian sus valores por defecto con
-- `defaults`. Añadir aquí una propiedad la da a TODAS las entidades.
EntityTypes.COMMON = {
    { key='movement', kind='enum', label='Movimiento', group='Movimiento', default='walk',
      options=opts({'walk','Camina'}, {'fly','Vuela'}, {'static','Quieto'}) },
    { key='attach', kind='enum', label='Superficie', group='Movimiento', default='floor',
      options=opts({'floor','Suelo'}, {'ceiling','Techo (boca abajo)'}),
      showIf=function(p) return p.movement == 'walk' end },
    { key='speed', kind='number', label='Velocidad (px/s)', group='Movimiento', default=50,
      min=0, max=600, step=5, help='El jugador anda a 240 px/s',
      showIf=function(p) return p.movement ~= 'static' end },
    { key='startDir', kind='enum', label='Dirección inicial', group='Movimiento', default='right',
      options=opts({'right','Derecha'}, {'left','Izquierda'}) },
    { key='patrol', kind='patrol', label='Ruta con límites', group='Movimiento',
      help='Columnas entre las que se mueve. Desactívalo para que no tenga límites.',
      default=function(d) return { left = (d.col or 1) - 3, right = (d.col or 1) + 3 } end,
      showIf=function(p) return p.movement ~= 'static' and not (p.movement == 'fly' and p.flyMode == 'free') end },
    { key='turnAtEdges', kind='bool', label='Gira en los bordes', group='Movimiento', default=true,
      help='Da la vuelta antes de caer por un borde',
      showIf=function(p) return p.movement == 'walk' end },
    { key='flyMode', kind='enum', label='Vuelo', group='Movimiento', default='route',
      options=opts({'route','Ruta (va y viene)'}, {'free','Libre'}),
      help='Libre: recorre toda su zona por donde quepa (rodea plataformas, sale de huecos y esquinas) y se '
        .. 'acerca a los jugadores; no usa la ruta',
      showIf=function(p) return p.movement == 'fly' end },
    { key='flyRange', kind='int', label='Vuelo libre: radio (casillas)', group='Movimiento', default=6,
      min=2, max=40, step=1, help='Hasta dónde se aleja de su sitio en cada dirección',
      showIf=function(p) return p.movement == 'fly' and p.flyMode == 'free' end },
    { key='bobAmp', kind='number', label='Oscilación vertical (px)', group='Movimiento', default=16,
      min=0, max=200, step=2, help='Cuánto sube y baja al volar',
      showIf=function(p) return p.movement == 'fly' and p.flyMode ~= 'free' end },
    { key='pauses', kind='bool', label='Hace pausas', group='Comportamiento', default=true,
      help='De vez en cuando se para un momento' },
    { key='onTouch', kind='enum', label='Al tocarlo', group='Combate', default='kill',
      options=opts({'kill','Mata'}, {'hurt','Quita 1 de vida'}, {'none','Nada (neutral)'}) },
    { key='stompable', kind='bool', label='Se puede pisotear', group='Combate', default=true },
    { key='points', kind='int', label='Puntos al pisotearlo', group='Combate', default=10,
      min=0, max=9999, step=5, showIf=function(p) return p.stompable end },
    { key='dropOnSight', kind='bool', label='Cae al ver a un jugador', group='Caída desde el techo', default=false,
      help='Desde el techo: al ver a un jugador debajo tiembla y cae (luego sigue en el suelo)',
      showIf=function(p) return p.movement == 'walk' and p.attach == 'ceiling' end },
    { key='detectRange', kind='int', label='Alcance (casillas)', group='Caída desde el techo', default=6,
      min=1, max=30, step=1, help='Hasta cuántas casillas por debajo ve a los jugadores',
      showIf=function(p) return p.dropOnSight and p.movement == 'walk' and p.attach == 'ceiling' end },
    { key='respawn', kind='number', label='Reaparece tras (s)', group='Reaparición', default=0,
      min=0, max=120, step=1, help='0 = no reaparece. Si muere, vuelve a su sitio pasado ese tiempo' },
}

-- Orden de una categoría en la paleta (las desconocidas al final)
function EntityTypes.categoryOrder(id)
    for i, c in ipairs(EntityTypes.CATEGORIES) do if c.id == id then return i, c end end
    return #EntityTypes.CATEGORIES + 1, nil
end

-- Variantes hermanas de un tipo (lista de nombres) o nil
function EntityTypes.variantsOf(name)
    local t = EntityTypes.byName[name]
    return t and t.variant and EntityTypes.variants[t.variant.group] or nil
end

function EntityTypes.register(def)
    assert(type(def) == 'table' and type(def.name) == 'string', "entidad sin nombre")
    assert(not EntityTypes.byName[def.name], "entidad duplicada: " .. def.name)
    assert(def.class, "entidad " .. def.name .. " sin class")
    local t = {}
    for k, v in pairs(def) do t[k] = v end
    t.label    = t.label or t.name
    t.category = t.category or 'Enemigos'
    -- Sonidos suyos que además son RUIDO (lo oyen los Crabbies lúgubres): `noises = { sonido = casillas }`
    if t.noises then require('src/world/Noise').register(t.noises) end

    -- Esquema final: comunes (con defaults del tipo) + propios
    local hide = {}
    if t.hide == 'all' then
        for _, p in ipairs(EntityTypes.COMMON) do hide[p.key] = true end
    else
        for _, k in ipairs(t.hide or {}) do hide[k] = true end
    end
    t.schema = {}
    for _, p in ipairs(EntityTypes.COMMON) do
        if not hide[p.key] then
            local c = {}
            for k, v in pairs(p) do c[k] = v end
            if t.defaults and t.defaults[p.key] ~= nil then c.default = t.defaults[p.key] end
            table.insert(t.schema, c)
        end
    end
    for _, p in ipairs(t.props or {}) do table.insert(t.schema, p) end
    if t.activatable then
        local has = false
        for _, p in ipairs(t.schema) do if p.key == 'id' then has = true end end
        if not has then
            table.insert(t.schema, { key='id', kind='int', label='Número (id)', group='Conexión', default=1,
                                     min=1, max=99, step=1, help='Los bloques ON/OFF se conectan a este número' })
        end
    end

    -- Agrupar por `group` para el editor: primero los grupos propios del tipo
    -- (lo que lo define: 'Mortero', 'Inundación'...), luego los comunes en su
    -- orden fijo (las propiedades propias de un grupo común van con él)
    local isCommon = {}
    for i, g in ipairs(EntityTypes.COMMON_GROUPS) do isCommon[g] = i end
    local own, byGroup = {}, {}
    for _, p in ipairs(t.schema) do
        local g = p.group or 'General'
        if not byGroup[g] then
            byGroup[g] = {}
            if not isCommon[g] then own[#own+1] = g end
        end
        table.insert(byGroup[g], p)
    end
    t.schema, t.groups = {}, {}
    local function add(g) if byGroup[g] then t.groups[#t.groups+1] = g; for _, p in ipairs(byGroup[g]) do table.insert(t.schema, p) end end end
    for _, g in ipairs(own) do add(g) end
    for _, g in ipairs(EntityTypes.COMMON_GROUPS) do add(g) end

    -- Variantes (el mismo objeto en varias versiones: direcciones...)
    if t.variant then
        local g = t.variant.group
        EntityTypes.variants[g] = EntityTypes.variants[g] or {}
        table.insert(EntityTypes.variants[g], t.name)
    end

    t.class.def = t

    -- Dibujo común para todos: invisible esperando reaparecer, animación de
    -- aparición con partículas y temblor antes de caer (funciona igual online:
    -- solo depende de state/deadTimer, que viajan en el snapshot).
    local cls = t.class
    if not cls._wrappedRender then
        local drawBody = cls.render
        local draw = function(self, camX, camY)
            if self.state ~= 'frozen' then EntityTypes.drawWings(self, camX, camY) end   -- (detrás del cuerpo)
            drawBody(self, camX, camY)
        end
        cls._wrappedRender = true
        cls.render = function(self, camX, camY)
            local st = self.state
            if st == 'gone' or st == 'dead_burst' then return end      -- (reventada: solo quedan los pedazos)
            if st == 'dead_fling' then
                -- Despedida girando (le rompieron el bloque de debajo)
                local t = self.deadTimer or 0
                local sx, sy = math.floor(self.x - camX + 0.5), math.floor(self.y - camY + 0.5)
                love.graphics.push()
                love.graphics.translate(sx, sy)
                love.graphics.rotate((self.facing or 1) * t * 13)
                love.graphics.translate(-sx, -sy)
                draw(self, camX, camY)
                love.graphics.pop()
                love.graphics.setColor(1, 1, 1, 1)
                return
            end
            if st == 'spawning' then
                local k  = math.min(1, (self.deadTimer or 0) / 0.7)
                local sx = self.x - camX
                local sy = self.y - camY
                love.graphics.push()
                love.graphics.translate(sx, sy)
                love.graphics.scale(0.2 + 0.8 * k, 0.2 + 0.8 * k)
                love.graphics.translate(-sx, -sy)
                draw(self, camX, camY)
                love.graphics.pop()
                -- partículas convergiendo
                for i = 0, 11 do
                    local a = i / 12 * math.pi * 2 + k * 4
                    local r = (1 - k) * 60 + 6
                    love.graphics.setColor(1, 1, 1, 1 - k * 0.8)
                    love.graphics.rectangle('fill', math.floor(sx + math.cos(a) * r) - 2,
                                            math.floor(sy + math.sin(a) * r) - 2, 4, 4)
                end
                love.graphics.setColor(1, 1, 1, 1)
                return
            end
            if st == 'stunned' then
                -- Aturdida: se tambalea con estrellitas girando sobre la cabeza
                local k  = math.max(0, 1 - (self.deadTimer or 0) / 1.2)
                local sx = self.x - camX
                local sy = self.y - camY
                love.graphics.push()
                love.graphics.translate(sx, sy)
                love.graphics.rotate(math.sin((self.deadTimer or 0) * 18) * 0.18 * k)
                love.graphics.translate(-sx, -sy)
                draw(self, camX, camY)
                love.graphics.pop()
                local t  = love.timer.getTime()
                local hy = self.flipped and (sy + (self.sprH or 40) / 2 + 10) or (sy - (self.sprH or 40) / 2 - 8)
                for i = 0, 2 do
                    local a = t * 6 + i * (math.pi * 2 / 3)
                    local x = math.floor(sx + math.cos(a) * 18)
                    local y = math.floor(hy + math.sin(a) * 5)
                    love.graphics.setColor(1, 0.9, 0.3, 1)
                    love.graphics.rectangle('fill', x - 3, y - 1, 6, 2)
                    love.graphics.rectangle('fill', x - 1, y - 3, 2, 6)
                end
                love.graphics.setColor(1, 1, 1, 1)
                return
            end
            if st == 'frozen' then
                -- Congelada: el cuerpo quieto, teñido de azul, dentro de un bloque de hielo
                -- (deadTimer = lo que le queda: parpadea al final)
                IceEncase = IceEncase or require 'src/fx/IceEncase'
                IceEncase.tinted(function() draw(self, camX, camY) end)
                local b = self:getOuterBounds()
                IceEncase.draw(b.x - camX, b.y - camY, b.w, b.h, love.timer.getTime(), self.deadTimer)
                return
            end
            if st == 'drop_shake' then
                love.graphics.push()
                love.graphics.translate(math.floor(math.sin((self.deadTimer or 0) * 70) * 3), 0)
                draw(self, camX, camY)
                love.graphics.pop()
                return
            end
            draw(self, camX, camY)
        end
    end
    EntityTypes.byName[t.name] = t
    table.insert(EntityTypes.list, t)
    return t
end

-- ── Alas de los voladores ────────────────────────────────────────────────────
-- Toda entidad con movimiento 'fly' lleva un ala a cada lado, DETRÁS del
-- sprite: assets/images/wings/wings-Sheet.png (ala IZQUIERDA, 2 cuadros de
-- 9x13 de aleteo, unida al cuerpo por su borde derecho); la derecha es la misma
-- espejada. Se colocan SIMÉTRICAS respecto a lo que se VE: la caja de píxeles
-- visibles del sprite del tipo (editor.sprite, medida una vez), con su lado y su
-- vuelta; sin sprite, la hitbox exterior. Solo dibujo.
local wingStrip
local WING_FPS = 9
local visCache = {}

-- Caja visible del sprite del tipo, en píxeles de arte: {x0, x1, y0, y1, iw, ih} o false
local function visibleBox(def)
    local path = def and def.editor and def.editor.sprite
    if not path then return false end
    local fw = def.editor.frameW                                   -- (hoja de cuadros: solo el primero)
    if visCache[path] == nil then
        local ok, data = pcall(love.image.newImageData, path)
        if not ok then visCache[path] = false; return false end
        local iw, ih = data:getDimensions()
        if fw then iw = math.min(iw, fw) end
        local x0, x1, y0, y1 = iw, -1, ih, -1
        for y = 0, ih - 1 do
            for x = 0, iw - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0 then
                    if x < x0 then x0 = x end
                    if x > x1 then x1 = x end
                    if y < y0 then y0 = y end
                    if y > y1 then y1 = y end
                end
            end
        end
        visCache[path] = (x1 >= 0) and { x0 = x0, x1 = x1, y0 = y0, y1 = y1, iw = iw, ih = ih } or false
    end
    return visCache[path]
end

function EntityTypes.drawWings(e, camX, camY)
    if not (e.props and e.props.movement == 'fly') or e.state == 'dead' then return end
    wingStrip = wingStrip or require('src/fx/SpriteStrip').load('assets/images/wings/wings-Sheet.png', 9)
    -- Cuerpo visible (centro x, arriba y alto en px de mundo)
    local cxw, top, bw, bh
    local vb = e.sprW and e.sprH and visibleBox(e.def or (e.class and e.class.def))
    if vb then
        local k = e.sprW / vb.iw                                 -- px de mundo por píxel de arte
        local facing = (e.facing or 1) < 0 and -1 or 1
        local mid = ((vb.x0 + vb.x1 + 1) / 2 - vb.iw / 2) * k     -- (dibujado centrado en e.x)
        cxw = e.x + mid * facing
        bw, bh = (vb.x1 - vb.x0 + 1) * k, (vb.y1 - vb.y0 + 1) * (e.sprH / vb.ih)
        -- (dibujado apoyado abajo: los pies en e.y + sprH/2)
        top = e.y + e.sprH / 2 - (vb.ih - vb.y0) * (e.sprH / vb.ih)
        if e.flipped then top = 2 * e.y - (top + bh) end
    else
        bw, bh = e.outerW or e.sprW or 40, e.outerH or e.sprH or 40
        cxw, top = e.x, e.y - bh / 2
    end
    local s = math.max(1, math.floor(bh * 0.7 / wingStrip.h + 0.5))    -- escala entera (pixel art)
    local half = wingStrip.w * s / 2
    -- Raíz del ala: un poco dentro del cuerpo (queda tapada), en su mitad alta
    local rootX = math.floor(bw * 0.42)
    local cy = math.floor(top + bh * (e.flipped and 0.68 or 0.32) - camY)
    local cx = math.floor(cxw - camX)
    -- Aleteo (desfasado por entidad para que no vayan todas a la vez)
    local f = wingStrip:frameAt(love.timer.getTime() + (e.home and e.home.x or 0) * 0.013, WING_FPS)
    local sy = e.flipped and -s or s
    love.graphics.setColor(1, 1, 1, 1)
    wingStrip:draw(f, cx - rootX - half, cy, 0, s, sy)      -- izquierda
    wingStrip:draw(f, cx + rootX + half, cy, 0, -s, sy)     -- derecha (espejada)
end

function EntityTypes.get(name)
    return EntityTypes.byName[name]
end

-- Convierte una colocación del nivel (formato nuevo o antiguo) en
-- { type, col, row, props = <valores resueltos> }. nil si el tipo no existe.
function EntityTypes.normalize(data)
    local t = EntityTypes.byName[data.type]
    if not t then return nil end
    local raw = {}
    for k, v in pairs(data.props or {}) do raw[k] = v end
    -- Formato antiguo: leftBound/rightBound/flipped en la raíz
    if raw.patrol == nil and data.leftBound and data.rightBound then
        raw.patrol = { left = data.leftBound, right = data.rightBound }
    end
    if raw.attach == nil and data.flipped then raw.attach = 'ceiling' end
    local base = { type = data.type, col = math.floor(tonumber(data.col) or 1),
                   row = math.floor(tonumber(data.row) or 1) }
    if t.placement == 'sub' then
        local sub = math.floor(tonumber(data.sub) or 1)
        base.sub = (sub >= 1 and sub <= 4) and sub or 1
    end
    base.props = Props.resolve(t.schema, raw, base)
    return base
end

-- Forma compacta para guardar: solo props distintas del default.
function EntityTypes.serialize(e)
    local t = EntityTypes.byName[e.type]
    local out = { type = e.type, col = e.col, row = e.row, sub = e.sub }
    out.props = t and Props.diff(t.schema, e.props, e) or nil
    return out
end

return EntityTypes
