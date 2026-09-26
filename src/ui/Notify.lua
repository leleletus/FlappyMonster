-- src/ui/Notify.lua
-- Sistema global de avisos, dibujado por encima de cualquier pantalla.
--
--   Notify.toast(msg, kind)          aviso temporal arriba al centro (se apilan)
--   Notify.modal(title, msg, opts)   ventana que hay que ACEPTAR (bloquea la
--                                    pantalla de debajo hasta cerrarla)
--   Notify.roomExit(event, data)     te sacaron de la sala (kicked / banned /
--                                    room_closed): vuelve al hub y lo explica
--
-- kind: 'info' | 'success' | 'warn' | 'error' | 'join' | 'leave' | 'kick' |
--       'ban' | 'admin' | 'game'
-- main.lua llama a update/render/touch/hover y cede la entrada al modal.

local PixelIcons = require 'src/ui/PixelIcons'

local Notify = {}

local KINDS = {
    info    = { col = {0.35, 0.70, 1.00}, icon = 'i' },
    success = { col = {0.35, 1.00, 0.50}, icon = 'ok' },
    warn    = { col = {1.00, 0.80, 0.20}, icon = '!' },
    error   = { col = {1.00, 0.30, 0.30}, icon = 'x' },
    join    = { col = {0.35, 1.00, 0.50}, icon = '+' },
    leave   = { col = {0.65, 0.65, 0.75}, icon = '-' },
    kick    = { col = {1.00, 0.60, 0.20}, icon = '!' },
    ban     = { col = {1.00, 0.25, 0.25}, icon = 'x' },
    admin   = { col = {1.00, 0.82, 0.20}, icon = 'crown' },
    game    = { col = {0.35, 0.85, 1.00}, icon = '>' },
}

local TOAST_W_MAX, TOAST_H, TOAST_GAP = 760, 58, 10
local TOAST_LIFE  = 4.5
local TOAST_MAX   = 4
local MODAL_W     = 660

local toasts = {}
local modals = {}      -- cola: se muestran de uno en uno

local function kindOf(k) return KINDS[k] or KINDS.info end
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end

-- ── API ───────────────────────────────────────────────────────────────────────

function Notify.toast(msg, kind)
    if type(msg) ~= 'string' or msg == '' then return end
    -- No repetir el mismo aviso si aún está en pantalla
    for _, t in ipairs(toasts) do
        if t.msg == msg and t.t < TOAST_LIFE - 0.5 then t.t = 0.3; return end
    end
    table.insert(toasts, 1, { msg = msg, kind = kind or 'info', t = 0,
                              life = (kind == 'error' or kind == 'ban') and TOAST_LIFE + 1.5 or TOAST_LIFE })
    while #toasts > TOAST_MAX do table.remove(toasts) end
    if kind == 'error' or kind == 'ban' or kind == 'kick' then Sound.play('dies2', 1.4, 0.5) end
end

-- opts: { kind, subtitle, button }
function Notify.modal(title, msg, opts)
    opts = opts or {}
    for _, m in ipairs(modals) do               -- no apilar el mismo aviso
        if m.title == title and m.msg == msg then return end
    end
    table.insert(modals, { title = title or '', msg = msg or '', kind = opts.kind or 'info',
                           subtitle = opts.subtitle, button = opts.button or 'ACEPTAR', t = 0, hover = false })
    if #modals == 1 then Sound.play('dies2', 0.8, 0.6) end
end

function Notify.blocking() return modals[1] ~= nil end

function Notify.clear() toasts = {}; modals = {} end

-- Te sacaron de la sala: volver al hub y explicar claramente por qué.
local EXIT_TEXT = {
    kicked      = { title = 'EXPULSADO',     kind = 'kick',
                    msg = 'El host te expulsó de la sala. Puedes volver a unirte si quieres.' },
    banned      = { title = 'BANEADO',       kind = 'ban',
                    msg = 'El host te baneó de la sala. No podrás volver a entrar en ella.' },
    room_closed = { title = 'SALA CERRADA',  kind = 'warn',
                    msg = 'El host cerró la sala.' },
}
function Notify.roomExit(event, data)
    local e = EXIT_TEXT[event] or EXIT_TEXT.room_closed
    data = type(data) == 'table' and data or {}
    Sound.stopTracked('drowning')
    gStateMachine:change('online_hub')
    Notify.modal(e.title, type(data.msg) == 'string' and data.msg or e.msg, {
        kind = e.kind,
        subtitle = type(data.room) == 'string' and ('Sala: ' .. data.room) or nil,
    })
end

-- ── Geometría del modal ──────────────────────────────────────────────────────

local function modalLayout(m)
    local _, lines = FONT_MED:getWrap(m.msg, MODAL_W - 80)
    local h = 96 + (m.subtitle and 26 or 0) + #lines * (FONT_MED:getHeight() + 10) + 30 + 56 + 30
    local x = math.floor((WINDOW_W - MODAL_W) / 2)
    local y = math.floor((WINDOW_H - h) / 2)
    local bw, bh = 260, 56
    return { x = x, y = y, w = MODAL_W, h = h, lines = lines,
             btn = { x = math.floor(WINDOW_W / 2 - bw / 2), y = y + h - bh - 26, w = bw, h = bh } }
end

local function inRect(r, x, y)
    return x >= r.x - 6 and x <= r.x + r.w + 6 and y >= r.y - 6 and y <= r.y + r.h + 6
end

-- ── Update / entrada ─────────────────────────────────────────────────────────

function Notify.update(dt)
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        t.t = t.t + dt
        if t.t >= t.life then table.remove(toasts, i) end
    end
    local m = modals[1]
    if m then
        m.t = m.t + dt
        if m.t > 0.35 and (Input.pressed('confirm') or Input.pressed('back') or Input.pressed('pause')) then
            Sound.play('select')
            table.remove(modals, 1)
        end
    end
end

-- Devuelve true si el toque/clic lo consumió el modal.
function Notify.touch(x, y)
    local m = modals[1]
    if not m then return false end
    if m.t > 0.35 and inRect(modalLayout(m).btn, x, y) then
        Sound.play('select')
        table.remove(modals, 1)
    end
    return true
end

function Notify.hover(x, y)
    local m = modals[1]
    if not m then return false end
    m.hover = inRect(modalLayout(m).btn, x, y)
    return true
end

-- ── Dibujo ────────────────────────────────────────────────────────────────────

local function drawIcon(kind, cx, cy, s, alpha)
    local k = kindOf(kind)
    local c = k.col
    if k.icon == 'crown' then
        local px = math.max(2, math.floor(s / 10))
        PixelIcons.crown(cx - PixelIcons.CROWN_W * px / 2, cy - PixelIcons.CROWN_H * px / 2, px, alpha)
        return
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.circle('fill', cx, cy, s / 2)
    love.graphics.setColor(0, 0, 0, alpha * 0.85)
    local w = math.max(3, math.floor(s / 7))
    if k.icon == 'x' then
        love.graphics.setLineWidth(w)
        love.graphics.line(cx - s / 5, cy - s / 5, cx + s / 5, cy + s / 5)
        love.graphics.line(cx + s / 5, cy - s / 5, cx - s / 5, cy + s / 5)
        love.graphics.setLineWidth(1)
    elseif k.icon == 'ok' then
        love.graphics.setLineWidth(w)
        love.graphics.line(cx - s / 4.5, cy, cx - s / 14, cy + s / 6, cx + s / 4, cy - s / 5)
        love.graphics.setLineWidth(1)
    elseif k.icon == '+' then
        love.graphics.rectangle('fill', cx - s / 4, cy - w / 2, s / 2, w)
        love.graphics.rectangle('fill', cx - w / 2, cy - s / 4, w, s / 2)
    elseif k.icon == '-' then
        love.graphics.rectangle('fill', cx - s / 4, cy - w / 2, s / 2, w)
    elseif k.icon == '>' then
        love.graphics.polygon('fill', cx - s / 6, cy - s / 4, cx + s / 4, cy, cx - s / 6, cy + s / 4)
    elseif k.icon == '!' then
        love.graphics.rectangle('fill', cx - w / 2, cy - s / 4, w, s / 3)
        love.graphics.rectangle('fill', cx - w / 2, cy + s / 7, w, w)
    else -- 'i'
        love.graphics.rectangle('fill', cx - w / 2, cy - s / 4, w, w)
        love.graphics.rectangle('fill', cx - w / 2, cy - s / 10, w, s / 3)
    end
end

local function renderToasts()
    local y = 16
    for _, t in ipairs(toasts) do
        local k   = kindOf(t.kind)
        local c   = k.col
        local inA = clamp01(t.t / 0.25)
        local out = clamp01((t.life - t.t) / 0.4)
        local a   = math.min(inA, out)
        local ease = 1 - (1 - inA) ^ 3
        love.graphics.setFont(FONT_MED)
        local tw = math.min(TOAST_W_MAX, FONT_MED:getWidth(t.msg) + 110)
        local _, lines = FONT_MED:getWrap(t.msg, tw - 110)
        local h  = math.max(TOAST_H, #lines * (FONT_MED:getHeight() + 8) + 26)
        local x  = math.floor(WINDOW_W / 2 - tw / 2)
        local ty = math.floor(y - (1 - ease) * 30)

        love.graphics.setColor(0, 0, 0, 0.45 * a)
        love.graphics.rectangle('fill', x + 5, ty + 5, tw, h, 6, 6)
        love.graphics.setColor(0.05, 0.05, 0.08, 0.95 * a)
        love.graphics.rectangle('fill', x, ty, tw, h, 6, 6)
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle('fill', x, ty, 8, h, 4, 4)
        love.graphics.setColor(c[1], c[2], c[3], 0.8 * a)
        love.graphics.rectangle('line', x, ty, tw, h, 6, 6)
        -- barra de tiempo restante
        love.graphics.setColor(c[1], c[2], c[3], 0.5 * a)
        love.graphics.rectangle('fill', x + 8, ty + h - 3, (tw - 8) * clamp01(1 - t.t / t.life), 3)

        drawIcon(t.kind, x + 44, ty + h / 2, 32, a)
        love.graphics.setColor(1, 1, 1, a)
        local ly = ty + h / 2 - #lines * (FONT_MED:getHeight() + 8) / 2 + 4
        for _, line in ipairs(lines) do
            love.graphics.print(line, x + 80, ly)
            ly = ly + FONT_MED:getHeight() + 8
        end
        y = y + h + TOAST_GAP
    end
end

local function renderModal()
    local m = modals[1]
    if not m then return end
    local k  = kindOf(m.kind)
    local c  = k.col
    local L  = modalLayout(m)
    local a  = clamp01(m.t / 0.2)
    local sc = 0.85 + 0.15 * (1 - (1 - clamp01(m.t / 0.25)) ^ 3)

    love.graphics.setColor(0, 0, 0, 0.72 * a)
    love.graphics.rectangle('fill', 0, 0, WINDOW_W, WINDOW_H)

    love.graphics.push()
    love.graphics.translate(WINDOW_W / 2, WINDOW_H / 2)
    love.graphics.scale(sc, sc)
    love.graphics.translate(-WINDOW_W / 2, -WINDOW_H / 2)

    love.graphics.setColor(0, 0, 0, 0.5 * a)
    love.graphics.rectangle('fill', L.x + 8, L.y + 8, L.w, L.h)
    love.graphics.setColor(0.06, 0.06, 0.09, a)
    love.graphics.rectangle('fill', L.x, L.y, L.w, L.h)
    love.graphics.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, a)
    love.graphics.rectangle('fill', L.x, L.y, L.w, 80)
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.rectangle('fill', L.x, L.y + 78, L.w, 3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', L.x, L.y, L.w, L.h)
    love.graphics.setLineWidth(1)

    -- Icono + título
    love.graphics.setFont(FONT_BIG)
    local tw = FONT_BIG:getWidth(m.title)
    local tx = WINDOW_W / 2 - (tw + 56) / 2
    drawIcon(m.kind, tx + 20, L.y + 40, 40, a)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.print(m.title, tx + 56 + 3, L.y + 40 - FONT_BIG:getHeight() / 2 + 3)
    love.graphics.setColor(c[1], c[2], c[3], a)
    love.graphics.print(m.title, tx + 56, L.y + 40 - FONT_BIG:getHeight() / 2)

    local y = L.y + 100
    if m.subtitle then
        love.graphics.setFont(FONT_SMALL)
        love.graphics.setColor(1, 1, 1, 0.55 * a)
        love.graphics.printf(m.subtitle, L.x, y, L.w, 'center')
        y = y + 26
    end
    love.graphics.setFont(FONT_MED)
    love.graphics.setColor(1, 1, 1, a)
    for _, line in ipairs(L.lines) do
        love.graphics.printf(line, L.x + 40, y, L.w - 80, 'center')
        y = y + FONT_MED:getHeight() + 10
    end

    -- Botón
    local b = L.btn
    local ready = m.t > 0.35
    local pulse = 0.5 + 0.5 * math.sin(m.t * 5)
    love.graphics.setColor(0, 0, 0, 0.5 * a)
    love.graphics.rectangle('fill', b.x + 4, b.y + 4, b.w, b.h)
    love.graphics.setColor(1, 1, 1, (ready and 1 or 0.5) * a)
    love.graphics.rectangle('fill', b.x, b.y, b.w, b.h)
    love.graphics.setColor(c[1], c[2], c[3], (m.hover and 1 or 0.6 + 0.4 * pulse) * a)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle('line', b.x - 3, b.y - 3, b.w + 6, b.h + 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.printf(m.button, b.x, b.y + b.h / 2 - FONT_MED:getHeight() / 2, b.w, 'center')
    love.graphics.pop()
end

function Notify.render()
    renderToasts()
    renderModal()
    love.graphics.setColor(1, 1, 1, 1)
end

return Notify
