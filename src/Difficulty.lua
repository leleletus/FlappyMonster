-- src/Difficulty.lua
-- DIFICULTAD = un marco GENÉRICO de modificadores del juego. Cada dificultad es una tabla de
-- modificadores CON NOMBRE; el código base pregunta por un modificador (Difficulty.k('airTime'))
-- y nunca por el nombre de la dificultad. Sirve igual al modo historia y al online: la dificultad
-- es una propiedad del NIVEL que se simula (`level.difficulty`, un id de ORDER o nil), igual en un
-- jugador, en el servidor y en la predicción del cliente (el servidor la manda en game_init).
--
--   Difficulty.bind(level)     el nivel que se simula ahora (estados al entrar; el servidor en cada
--                              paso de sala, como Noise.bind). nil = sin dificultad = NEUTRA: todo a 1,
--                              el juego tal como era (juego libre, editor, online sin elegirla, arneses)
--   Difficulty.k(nombre)       el modificador (1 si la dificultad no lo toca)
--   Difficulty.flag(nombre)    un interruptor (false si no lo toca)
--   Difficulty.dt(e, dt)       el paso de tiempo de una entidad: su RITMO. Enemigos, trampas y jefes
--                              van más lentos o más rápidos escalando su tiempo: todo lo suyo a la vez
--                              (andar, caer, avisos, esperas, proyectiles), sin retocar a nadie a mano.
--                              Un tipo puede salirse con `pace = false` en su definición, o elegir
--                              otro modificador con `pace = 'bossPace'`.
--
-- Qué significa cada una (el usuario): NORMAL = los niveles como están hoy; DIFÍCIL = los jefes como
-- están hoy; FÁCIL, todo más lento y con más margen; EXTREMO, más rápido y con menos margen;
-- XTRA EXTREMO = extremo + cambios en los jefes (dos a la vez...: `bossExtra`, etapa 6).
-- Modificadores:
--   enemyPace, trapPace, bossPace   ritmo (× tiempo) de enemigos / trampas / jefes
--   bossHp                          × vida de los jefes
--   playerHp                        vida del jugador (3)
--   invuln                          × tiempo invulnerable tras un golpe o al reaparecer
--   airTime                         × aire bajo el agua
--   hazardHurt                      pinchos y lava quitan 1 de vida (y te sacan de un bote) en vez de matar
--   bossExtra                       un SEGUNDO jefe en cada arena (src/world/XtraBosses.lua; Xtra extremo)
--   pairHp                          × vida de cada jefe cuando van DOS a la vez (bossExtra)
--   sense                           × alcance con que los enemigos te notan: ver desde el techo, oír ruidos,
--                                   sentirte cerca, alcance de morteros y peces globo (Fácil 0,8; Extremo 1,3)
--   botRest                         (bonus contra el bot) × descanso entre sus ground pounds (1 = Difícil; más = más manso)
--   botChase                        (bonus) casillas a las que te persigue fuera de la zona (7)
--   botCount                        (bonus) cuántos bots (1; Xtra extremo 2)
--   scoreMult                       (historia) × los puntos del nivel al apuntarlos (Fácil 0,8 … Xtra extremo 2)
--   livesStart                      (historia) vidas con las que empieza la aventura: 3; Extremo 4; Xtra extremo 6
--   restartGame                     (historia) un Game Over reinicia el JUEGO entero, no solo el mundo (Xtra extremo)
local Difficulty = {}

Difficulty.ORDER = { 'easy', 'normal', 'hard', 'extreme', 'xtra' }
Difficulty.START = { easy = true, normal = true, hard = true }       -- disponibles desde el principio (historia)
Difficulty.DEFAULT = 'normal'

Difficulty.MODS = {
    easy    = { scoreMult = 0.8, enemyPace = 0.8, trapPace = 0.8, bossPace = 0.7, bossHp = 0.75, playerHp = 4, invuln = 1.3, airTime = 1.4, hazardHurt = true,
                sense = 0.8, botRest = 3.5, botChase = 3 },
    normal  = { bossPace = 0.85, bossHp = 0.9, botRest = 2, botChase = 5 },
    hard    = { scoreMult = 1.2, enemyPace = 1.1, trapPace = 1.1, airTime = 0.9 },
    extreme = { scoreMult = 1.5, enemyPace = 1.25, trapPace = 1.3, bossPace = 1.2, bossHp = 1.15, invuln = 0.75, airTime = 0.8, livesStart = 4,
                sense = 1.3, botRest = 0.7, botChase = 10 },
    xtra    = { scoreMult = 2, enemyPace = 1.25, trapPace = 1.3, bossPace = 1.2, bossHp = 1.15, invuln = 0.75, airTime = 0.8, livesStart = 6,
                sense = 1.3, botRest = 0.7, botChase = 10, botCount = 2, bossExtra = true, pairHp = 0.65, restartGame = true },
}
-- DESBLOQUEOS (historia, globales): acabar el juego (el jefe del último mundo) en esta dificultad abre esta otra
Difficulty.UNLOCKS = { hard = 'extreme', extreme = 'xtra' }
-- Qué ritmo lleva cada categoría de entidad
Difficulty.PACE_OF = { Enemigos = 'enemyPace', Trampas = 'trapPace', Jefes = 'bossPace' }

local bound          -- la tabla de modificadores del nivel en curso (nil = neutra)

function Difficulty.valid(id) return type(id) == 'string' and Difficulty.MODS[id] ~= nil end

function Difficulty.bind(level)
    bound = level and Difficulty.MODS[level.difficulty or ''] or nil
end

function Difficulty.k(name, default)
    local v = bound and bound[name]
    if type(v) == 'number' then return v end
    return default or 1
end

function Difficulty.flag(name) return bound ~= nil and bound[name] == true end

-- Un modificador de una dificultad concreta, sin nivel (menús, partidas guardadas)
function Difficulty.of(id, name, default)
    local v = Difficulty.MODS[id or ''] and Difficulty.MODS[id][name]
    if v == nil then return default end
    return v
end

function Difficulty.dt(e, dt)
    if not bound then return dt end
    local def = e.def
    local pace = def and def.pace
    if pace == false then return dt end
    local key = pace or (def and Difficulty.PACE_OF[def.category])
    local k = key and bound[key]
    return k and dt * k or dt
end

return Difficulty
