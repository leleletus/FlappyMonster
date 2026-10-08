-- ESCONDERSE: cada cierto tiempo (o al acercarse un jugador) se esconde un rato y vuelve a salir. Escondido no se
-- le puede pisar ni tocar; puede sacar una TAPA que daña (como el pincho del Crabby). Un solo estado, 'hide', con
-- tres tramos por su reloj: entrar (secuencia `hide`), quieto (`hidden`; si no existe, el último cuadro de `hide`)
-- y salir (`unhide`; si no existe, `hide` al revés).
local T = TILE_PX
local function phase(e, cfg)
    local t = e.deadTimer or 0
    if t < cfg.inTime then return 'in', t end
    if t < cfg.inTime + cfg.stay then return 'hidden', t - cfg.inTime end
    return 'out', t - cfg.inTime - cfg.stay
end
return {
    name = 'hide', label = 'Esconderse',
    description = 'Se esconde un rato (no se le puede pisar ni tocar) y vuelve a salir; puede sacar una tapa que daña.',
    states = { 'hide' },
    anims = { 'hide' },
    crawlOk = true,
    params = {
        { key = 'every',   kind = 'number', label = 'Cada (s)', default = 5, min = 0.5, max = 60, step = 0.5 },
        { key = 'near',    kind = 'number', label = 'Solo con un jugador a (casillas; 0 = siempre)', default = 0, min = 0, max = 20, step = 0.5 },
        { key = 'inTime',  kind = 'number', label = 'Tarda en esconderse (s)', default = 0.5, min = 0.05, max = 3, step = 0.05 },
        { key = 'stay',    kind = 'number', label = 'Escondido (s)', default = 2.5, min = 0.2, max = 30, step = 0.1 },
        { key = 'outTime', kind = 'number', label = 'Tarda en salir (s)', default = 0.5, min = 0.05, max = 3, step = 0.05 },
        { key = 'cover',   kind = 'enum',   label = 'Tapa mientras está escondido', default = 'none',
          options = { { value = 'none', label = 'Nada' }, { value = 'hurt', label = 'Quita 1 de vida' }, { value = 'kill', label = 'Mata' } } },
    },
    think = function(e, cfg, dt, level)
        if e.cd_hide == nil then e.cd_hide = cfg.every * (0.4 + 0.6 * math.random()) end     -- (no todos a la vez)
        if e.cd_hide > 0 then return false end
        if not e.flying and not e.onGround and not (e.crawl and e.cattached) then return false end
        if cfg.near > 0 and not e:seesPlayer(level, cfg.near, cfg.near) then return false end
        e.vx = 0
        e:enter('hide')
        return true
    end,
    update = function(e, cfg, dt, level)
        if not e.flying and not (e.crawl and e.cattached) then
            e.vy = e.vy + ADV_GRAVITY * dt
            local dir = e.facing
            e:moveAndCollide(level, 0, e.vy * dt)
            e.facing = dir
        end
        if e.deadTimer >= cfg.inTime + cfg.stay + cfg.outTime then
            e.cd_hide = cfg.every
            e:backToWalk()
        end
    end,
    disabled = function(e, cfg) return phase(e, cfg) == 'hidden' end,
    hazards = function(e, cfg)
        if cfg.cover == 'none' or phase(e, cfg) ~= 'hidden' then return nil end
        local b = e:getOuterBounds()
        return { { x = b.x + b.w * 0.2, y = b.y, w = b.w * 0.6, h = b.h, effect = cfg.cover } }
    end,
    anim = function(e, cfg, set, map)
        local ph, t = phase(e, cfg)
        local hide = map.hide or 'hide'
        local len = set:length(hide)
        if ph == 'in' then return hide, math.min(len - 0.001, t / cfg.inTime * len) end
        if ph == 'hidden' then
            if set:has('hidden') then return 'hidden', t end
            return hide, math.max(0, len - 0.001)
        end
        if set:has('unhide') then return 'unhide', math.min(set:length('unhide') - 0.001, t / cfg.outTime * set:length('unhide')) end
        return hide, math.max(0, len - 0.001 - t / cfg.outTime * len)
    end,
}
