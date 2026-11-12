-- src/player/Knockback.lua
-- EL EMPUJE de los golpes (0.5.210; el usuario: «que TODOS los golpes empujen hacia el lado contrario»; antes solo
-- algunos — los de los jefes, algún enemigo — y era incoherente). Un módulo para todo: el daño del jugador
-- (PlayerAdventure:hurt / hazardHit, con la fuente del golpe — src/player/DamageSource.lua —) y los golpes de los
-- jefes (Boss.strike, con su tabla propia). Sin dibujo: lo comparten un jugador, el servidor y el cliente.
--   Knockback.apply(pa, dir, k)   empuja a pa hacia dir (±1) con k = { vx, vy, lock[, stun] } (vy hacia arriba < 0);
--                                 pa.knockK (1 por defecto) lo escala
--   Knockback.of(src)             el empuje de una fuente: una de PROFILES o nil (ninguno)
--   Knockback.dirFrom(pa, src)    hacia dónde: lejos de donde vino (src.x); sin sitio, hacia atrás de donde mira
--   Knockback.hit(pa, src)        of + dirFrom + apply (lo que hace el daño del jugador)
local Knockback = {}

-- Los empujes: el de casi todo, uno más fuerte y uno más flojo (lock = s sin control: no se vuelve a meter en el golpe)
Knockback.PROFILES = {
    normal = { vx = 300, vy = -300, lock = 0.2 },
    strong = { vx = 520, vy = -380, lock = 0.3 },
    weak   = { vx = 180, vy = -200, lock = 0.12 },
}
-- (las partes y causas que empujan MÁS: explosiones, golpes de peso, ondas y embestidas; MENOS: proyectiles y hielo;
--  NADA: lo que no es un golpe — ahogarse, el tiempo, aplastado por la cámara, la caída de un nivel Flappy —)
local STRONG_PART = { slam = true, pound = true, wave = true, blast = true, dash = true, stomp = true }
local WEAK_PART   = { projectile = true, ice = true }
local NONE_WHAT   = { drown = true, time = true, crush = true, fall = true }

function Knockback.of(src)
    if not src then return Knockback.PROFILES.normal end
    if NONE_WHAT[src.what] then return nil end
    if src.what == 'explosion' or STRONG_PART[src.part] then return Knockback.PROFILES.strong end
    if WEAK_PART[src.part] then return Knockback.PROFILES.weak end
    -- (el CUERPO de un jefe pesa más que el de un enemigo)
    if src.part == 'body' then
        local ok, ET = pcall(require, 'src/world/entities/base/EntityTypes')
        local def = ok and ET.byName and ET.byName[src.what]
        if def and (def.boss or def.category == 'Jefes') then return Knockback.PROFILES.strong end
    end
    return Knockback.PROFILES.normal
end

function Knockback.dirFrom(pa, src)
    if src and src.x then return (pa.x >= src.x) and 1 or -1 end
    return -((pa.facing ~= 0 and pa.facing) or 1)
end

function Knockback.apply(pa, dir, k)
    if not k or pa.dying then return end
    local m = pa.knockK or 1                             -- (cuánto le afecta: 1; la escena de la tarjeta, menos)
    pa.vx, pa.vy = dir * (k.vx or 0) * m, (k.vy or 0) * m
    pa.onGround, pa.crouching = false, false
    pa.gpPhase, pa.gpT = nil, 0
    pa.ctrlLockT = math.max(pa.ctrlLockT or 0, k.lock or 0)
    if (k.stun or 0) > 0 then
        pa.stunT = math.max(pa.stunT or 0, k.stun)
        Sound.play('stunned')
    end
end

function Knockback.hit(pa, src)
    if pa.flight then return end                         -- (volando — niveles Flappy —: su propio rebote)
    Knockback.apply(pa, Knockback.dirFrom(pa, src), Knockback.of(src))
end

return Knockback
