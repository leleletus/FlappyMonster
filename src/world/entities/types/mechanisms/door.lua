-- LA PUERTA ACTIVABLE (el usuario, 2026-10-29: en el Templo de los Pesos bastaba con pulsar 2 de los 3 Activadores
-- para pasar; con 3 puertas una detrás de otra, cada una con SU Activador, hay que pulsarlos todos). Genérica: sirve en
-- cualquier nivel y en cualquier isla.
--   * Un cuerpo SÓLIDO de `width` × `height` casillas (solidFull + isSolidBody: jugadores, enemigos, cajas y bombas no
--     pasan). Se coloca en la casilla de ABAJO a la izquierda; sube `height` casillas.
--   * Se abre cuando "salta" lo que la suelta (`source`):
--       'switch' = su Activador ON/OFF (activatable: el enlace genérico `links`, Activador → `id`, herramienta Conectar
--                  del editor). Salta cuando cambia (`trigger`: cualquier cambio, solo a ON o solo a OFF).
--       'boss'   = la pelea de su zona de jefe (`zone`, 0 = la más cercana) acaba ganada.
--   * Al saltar: el cerrojo (doorClick, en la puerta y en sus Activadores: quien lo pulsa lejos lo oye), un momento de
--     temblor (`unlock`), y se ABRE deslizándose (`dir`: sube al techo o baja al suelo; se recorta en su hueco) en
--     `openTime` s (doorOpen). Lo sólido es lo que aún se ve: se puede pasar en cuanto deja hueco.
--   * `stay` (por defecto): se queda abierta para siempre. Sin `stay`: con `closeAfter` > 0 se cierra a los N s; con 0,
--     va y viene con cada salto. Al cerrarse NUNCA aplasta a nadie: si lo que va a ocupar tiene un jugador, un enemigo
--     o algo que se mueve (una caja, una bomba) dentro, se queda quieta esperando (y vuelve a abrirse si salta).
-- Estados (autoritativos: un jugador y el servidor; el cliente los recibe):
--   closed → unlock → opening → open [→ closing → closed]
-- Red: lo abierto en px (`k` × su alto, redondeado como la caja) en su netPack; la caja sólida sale de ahí, así que el
-- cliente predice a su jugador contra la MISMA caja, al píxel. Cerrada está en reposo (no se manda).
-- Arte por isla (`isleArt`; tools/art/world/make_doors.py): assets/images/mechanisms/door/<isla>-Sheet.png, 4 cuadros
-- de 16x16 (sola, arriba, en medio, abajo); la hoja ocupa 12 px de ancho, el hitbox también.
local Entity    = require 'src/world/entities/base/Entity'
local Isles     = require 'src/world/level/Isles'
local BossZones = require 'src/world/systems/BossZones'
local Clip      = require 'src/ui/Clip'

local Door = Entity.extend(Entity, { debugColor = { 0.8, 0.7, 0.4 },
    hitbox = { outerW = 1, outerH = 1, innerW = 1, innerH = 1 } })
Door.solidFull  = true
Door.wantsLevel = true

local T, S      = TILE_PX, GUMMY_SCALE
local INSET     = 2 * S          -- (la hoja empieza 2 px de arte dentro de su casilla, por cada lado)
local UNLOCK_T  = 0.35           -- s de temblor entre el cerrojo y empezar a moverse
Door.UNLOCK_T, Door.INSET = UNLOCK_T, INSET

function Door.sizePx() return T, T end

local function num(v, d) v = tonumber(v); return v and math.floor(v) or d end

-- El rectángulo de la puerta (casillas y px) a partir de la colocación
function Door.rectOf(col, row, p)
    local w, h = math.max(1, num(p.width, 1)), math.max(1, num(p.height, 3))
    local c0, r1 = col, row
    local c1, r0 = col + w - 1, row - h + 1
    return c0, r0, c1, r1, (c0 - 1) * T, (r0 - 1) * T, c1 * T, r1 * T
end

function Door:init()
    self.moving, self.flying, self.vx, self.vy = false, true, 0, 0
    self.c0, self.r0, self.c1, self.r1, self.x0, self.y0, self.x1, self.y1 = Door.rectOf(self.col, self.row, self.props)
    self.x, self.y = (self.x0 + self.x1) / 2, (self.y0 + self.y1) / 2
    self.outerW, self.outerH = self.x1 - self.x0, self.y1 - self.y0
    self.innerW, self.innerH = self.outerW, self.outerH
    self.state, self.deadTimer, self.k = 'closed', 0, 0
end

-- La parte que aún se ve (y es sólida) con la puerta abierta `k`
function Door:boxAt(k, into)
    local H = self.y1 - self.y0
    local cut = math.floor(math.max(0, math.min(1, k)) * H + 0.5)
    local y0, y1 = self.y0, self.y1 - cut
    if self.props.dir == 'down' then y0, y1 = self.y0 + cut, self.y1 end
    return Entity.box(into, self.x0 + INSET, y0, (self.x1 - self.x0) - 2 * INSET, y1 - y0)
end
function Door:getOuterBounds(into) return self:boxAt(self.k or 0, into) end
function Door:getInnerBounds(into) return self:getOuterBounds(into) end

function Door:isSolidBody() return self.alive and (self.k or 0) < 1 end
function Door:canBeStomped() return false end
function Door:canBeKnocked() return false end
function Door:canBeLaunched() return false end
function Door:canFreeze() return false end
function Door:canBeEaten() return false end
function Door:isBodyDisabled() return true end
function Door:isObstacle() return false end
function Door:isGhost() return (self.k or 0) >= 1 end
function Door:interact() return nil end
function Door:collect() return false end

function Door:isle() return Isles.of(self.levelRef, self.props.isle) end

-- ── Red ─────────────────────────────────────────────────────────────────────────
function Door:netAtRest() return self.state == 'closed' end
function Door:netRest() self.state, self.deadTimer, self.k = 'closed', 0, 0 end
function Door:netPack() return { math.floor((self.k or 0) * (self.y1 - self.y0) + 0.5) } end
function Door:netApply(a, b, f)
    local H = self.y1 - self.y0
    local ca, cb = a[1] or 0, b[1] or 0
    self.k = math.floor(ca + (cb - ca) * f + 0.5) / H
end

-- ── Lo que la suelta ────────────────────────────────────────────────────────────
-- ¿Saltó este paso? (un jugador y el servidor). El primer paso solo apunta cómo estaba.
function Door:fired(level)
    local p = self.props
    if (p.source or 'switch') == 'boss' then
        self.zoneRef = self.zoneRef or BossZones.find(level, p.zone or 0, self.x0, self.y0, self.x1, self.y1)
        local st = self.zoneRef and self.zoneRef.state
        local was = self.lastZone
        self.lastZone = st
        return was == 'fight' and st == 'cleared'
    end
    local sig = level:signal(p.id or 1)
    local was = self.lastSig
    self.lastSig = sig
    if was == nil or sig == was then return false end
    local tr = p.trigger or 'any'
    return tr == 'any' or (tr == 'on' and sig) or (tr == 'off' and not sig)
end

local function overlap(a, b) return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y end
local BB = {}
-- ¿Hay alguien dentro de `box`? (jugadores, enemigos, jefes y lo que se mueve: cajas, bombas…). Cerrándose, la
-- puerta espera a que salga: nadie se queda encerrado dentro.
function Door:occupied(level, box)
    for _, pa in ipairs(level.players or {}) do
        if not pa.dying and pa.alive ~= false and overlap(pa:getOuterBounds(), box) then return true end
    end
    for _, e in ipairs(level.liveEntities or {}) do
        if e ~= self and e.alive and not (e.isGhost and e:isGhost()) and e.def
           and (e.def.category == 'Enemigos' or e.def.category == 'Jefes' or e.carryable or e.moves)
           and overlap(e:getOuterBounds(BB), box) then
            return true
        end
    end
    return false
end

-- Sonido del cerrojo: en la puerta y en cada Activador conectado
function Door:clickSound(level)
    Sound.play('doorClick')
    if (self.props.source or 'switch') == 'switch' and level.linkedCells then
        for _, c in ipairs(level:linkedCells(self.props.id or 1)) do
            Sound.playAt('doorClick', (c[1] - 0.5) * T, (c[2] - 0.5) * T)
        end
    end
end

-- Polvo por el canto que se mueve
function Door:dust()
    local b = self:boxAt(0)
    local y = self.props.dir == 'down' and b.y or b.y + b.h
    for c = self.c0, self.c1 do Entity.emitFx('smoke', (c - 0.5) * T, y) end
end

function Door:updateCustom(dt, level)
    self.levelRef = level
    local p = self.props
    local speed = 1 / math.max(0.05, p.openTime or 0.8)
    local fire = self:fired(level)
    local st = self.state
    self.deadTimer = self.deadTimer + dt
    if st == 'closed' then
        if fire then
            self.state, self.deadTimer = 'unlock', 0
            self:clickSound(level)
        end
    elseif st == 'unlock' then
        if self.deadTimer >= UNLOCK_T then
            self.state, self.deadTimer = 'opening', 0
            Sound.play('doorOpen')
            self:dust()
        end
    elseif st == 'opening' then
        self.k = math.min(1, self.k + dt * speed)
        if self.k >= 1 then self.state, self.deadTimer = 'open', 0 end
    elseif st == 'open' then
        if not (p.stay ~= false) then
            local after = p.closeAfter or 0
            if (after > 0 and self.deadTimer >= after) or (after <= 0 and fire) then
                self.state, self.deadTimer = 'closing', 0
                Sound.play('doorOpen', 0.85)
            end
        end
    elseif st == 'closing' then
        if fire then
            self.state, self.deadTimer = 'opening', 0
        else
            local nk = math.max(0, self.k - dt * speed)
            -- (lo que va a tapar ya: si hay alguien dentro, espera)
            if not self:occupied(level, self:boxAt(nk, {})) then self.k = nk end
            if self.k <= 0 then
                self.state, self.deadTimer = 'closed', 0
                Sound.play('doorThud')
                self:dust()
                Entity.emitFx('shake_small', self.x, self.y)
            end
        end
    end
    return true
end

-- Ya abierta del todo (los arneses, el resolvedor de niveles: `level_solve DOORS=…`)
function Door:setOpen(open)
    self.k = open and 1 or 0
    self.state, self.deadTimer = open and 'open' or 'closed', 0
end

-- ── Dibujo ──────────────────────────────────────────────────────────────────────
local imgs = {}
local function art(isle)
    if not imgs[isle] then
        imgs[isle] = require('src/fx/SpriteStrip').load('assets/images/mechanisms/door/' .. isle .. '-Sheet.png', 16)
    end
    return imgs[isle]
end
Door.art = art

function Door:render(camX, camY)
    local a = art(self:isle())
    local k = self.k or 0
    if k >= 1 and not EDITOR_VIEW then return end
    local h = self.r1 - self.r0 + 1
    local H = h * T
    local off = math.floor(k * H + 0.5) * (self.props.dir == 'down' and 1 or -1)
    -- (el temblor del cerrojo: ±1 px de arte, a saltos)
    local shake = 0
    if self.state == 'unlock' then shake = (math.floor(self.deadTimer * 30) % 2 == 0) and -S / 2 or S / 2 end
    local x0, y0 = math.floor(self.x0 - camX), math.floor(self.y0 - camY)
    love.graphics.setColor(1, 1, 1, (EDITOR_VIEW and k >= 1) and 0.35 or 1)
    Clip.push(x0, y0, self.x1 - self.x0, H)
    for c = 0, self.c1 - self.c0 do
        for i = 1, h do
            local fr = h == 1 and 1 or (i == 1 and 2 or (i == h and 4 or 3))
            a:draw(fr, x0 + c * T + T / 2 + shake, y0 + (i - 1) * T + T / 2 + off, 0, S, S)
        end
    end
    Clip.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Editor: su número y lo que la suelta, encima
function Door.drawEditorOverlay(props, cx, cy, zoom, ctx)
    if not ctx then return end
    local h = math.max(1, num(props.height, 3))
    local txt = (props.source == 'boss') and (((props.zone or 0) > 0) and ('Puerta: zona de jefe ' .. props.zone) or 'Puerta: la zona de jefe más cercana')
                or ('Puerta #' .. (props.id or 1) .. (props.stay == false and '' or ' (se queda abierta)'))
    love.graphics.push()
    love.graphics.translate(cx - TILE_PX / 2, cy - TILE_PX / 2 - (h - 1) * TILE_PX - 18 / zoom); love.graphics.scale(1 / zoom)
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.print(txt, 1, 1)
    love.graphics.setColor(1, 0.85, 0.2, 1); love.graphics.print(txt, 0, 0)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawIcon(x, y, s)
    local a = art('jungla')
    love.graphics.setColor(1, 1, 1, 1)
    local k = s / 34
    a:draw(2, x + s / 2, y + s / 2 - 8 * k, 0, k, k)
    a:draw(4, x + s / 2, y + s / 2 + 8 * k, 0, k, k)
end

return {
    name = 'door', label = 'Puerta', category = 'Mecanismos', class = Door,
    description = 'Puerta sólida que se ABRE cuando salta su Activador ON/OFF conectado (capa Bloques → Conectar) o al '
               .. 'vencer al jefe de su zona. Se coloca en la casilla de abajo; sube hasta su alto. Por defecto se queda '
               .. 'abierta. Nunca se cierra con nadie dentro.',
    defaults = { movement = 'static' }, hide = 'all',
    inBlockOk = true,
    activatable = true,          -- (prop `id`: los Activadores conectados — `links` — la sueltan)
    needsLink = function(p) return (p.source or 'switch') == 'switch' end,
    isleArt = true,
    props = {
        { key = 'height', kind = 'int', label = 'Alto (casillas)', group = 'Puerta', default = 3, min = 1, max = 12, step = 1,
          help = 'Desde la casilla de la entidad hacia arriba' },
        { key = 'width', kind = 'int', label = 'Ancho (casillas)', group = 'Puerta', default = 1, min = 1, max = 4, step = 1,
          help = 'Hacia la derecha. Cada casilla es una hoja' },
        { key = 'dir', kind = 'enum', label = 'Al abrirse', group = 'Puerta', default = 'up',
          options = { { value = 'up', label = 'Sube al techo' }, { value = 'down', label = 'Baja al suelo' } } },
        { key = 'source', kind = 'enum', label = 'La abre', group = 'Puerta', default = 'switch',
          options = { { value = 'switch', label = 'Su Activador ON/OFF' }, { value = 'boss', label = 'Vencer al jefe de su zona' } },
          help = 'Activador: conéctalo en la capa Bloques → Conectar (elige el Activador y, en su panel, esta puerta)' },
        { key = 'trigger', kind = 'enum', label = 'Salta con', group = 'Puerta', default = 'any',
          showIf = function(p) return (p.source or 'switch') == 'switch' end,
          options = { { value = 'any', label = 'Cualquier cambio' }, { value = 'on', label = 'Solo al pasar a ON' },
                      { value = 'off', label = 'Solo al pasar a OFF' } } },
        { key = 'zone', kind = 'int', label = 'Zona de jefe (id)', group = 'Puerta', default = 0, min = 0, max = 99,
          showIf = function(p) return p.source == 'boss' end, help = '0 = la zona más cercana' },
        { key = 'stay', kind = 'bool', label = 'Se queda abierta', group = 'Puerta', default = true,
          help = 'Si no: se cierra a los segundos de abajo, o (con 0) se abre y se cierra con cada salto' },
        { key = 'closeAfter', kind = 'number', label = 'Se cierra a los (s)', group = 'Puerta', default = 0, min = 0, max = 60, step = 0.5,
          showIf = function(p) return p.stay == false end, help = '0 = se cierra cuando su Activador vuelve a saltar' },
        { key = 'openTime', kind = 'number', label = 'Tarda en abrirse (s)', group = 'Puerta', default = 0.8, min = 0.1, max = 4, step = 0.1 },
    },
    editor = { draw = drawIcon },
}
