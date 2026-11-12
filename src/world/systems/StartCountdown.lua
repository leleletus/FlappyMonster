-- src/world/systems/StartCountdown.lua
-- CUENTA ATRÁS del principio de cada nivel (3, 2, 1, ¡YA!), igual en un jugador, en el servidor y en el cliente
-- online: tiempo para reaccionar antes de que empiece nada. Mientras dura, TODO está congelado (jugador, enemigos,
-- trampas, agua, reloj del nivel, cámara automática) y el jugador no controla a su personaje.
--
--  * Un jugador (AdventureState): `st.startCd` = segundos que faltan; el estado no avanza el mundo mientras > 0.
--  * Servidor: los primeros `ticks()` ticks de la ronda no simulan nada; los inputs se consumen (se confirman al
--    cliente) sin mover al jugador. El número de ticks va en game_init (`cd`).
--  * Cliente online: lo que falta sale del reloj de instantáneas (el tick del servidor). La predicción NO mueve al
--    jugador en los ticks que el servidor procesará aún congelado (Predictor:tick(bits, true)).
-- La cuenta atrás propia de la cámara automática (src/world/systems/AutoScroll.lua) ya no se hace al empezar:
-- solo si tras esta aún falta alguien por entrar en la ventana (online).
-- Sin gráficos aquí (lo comparte el servidor): el dibujo es BossHud.drawStartCountdown.

local StartCountdown = {}

-- INICIO EN DOS FASES (0.5.202, docs/design/level-intro-card.md): primero la TARJETA de presentación del nivel
-- (CARD_TIME, src/ui/IntroCard.lua: pantalla negra, no se salta) y luego la cuenta atrás de siempre (TIME). Las dos
-- con el mundo congelado y SIN pausa. `rem` = lo que falta para empezar a jugar (s): > TIME tarjeta, (0, TIME] cuenta
-- atrás, (−GO_TIME, 0] el ¡YA!. TIME = 0 deja solo la tarjeta (el usuario la probará en el juego).
StartCountdown.CARD_TIME = 5.0    -- s de tarjeta (0.5.203: 5 s, el usuario; con la escena del monstruo cruzando)
StartCountdown.TIME      = 0      -- s de cuenta atrás (0.5.203: 0 para PROBAR sin ella — el usuario —; antes 3)
StartCountdown.GO_TIME   = 0.8    -- s que se ve "¡YA!" al acabar

-- Lo que dura el inicio entero (s): con tarjeta o sin ella (demo, niveles Flappy, prueba del editor)
function StartCountdown.total(card) return (card and StartCountdown.CARD_TIME or 0) + StartCountdown.TIME end

-- En qué fase está un inicio al que le faltan `rem` s: 'card' | 'count' | 'go' | nil (ya se juega)
function StartCountdown.phase(rem)
    if not rem then return nil end
    if rem > StartCountdown.TIME then return 'card' end
    if rem > 0 then return 'count' end
    if rem > -StartCountdown.GO_TIME then return 'go' end
    return nil
end

-- Ticks del inicio a paso fijo (servidor); `card` = con la tarjeta delante
function StartCountdown.ticks(tickDt, card) return math.floor(StartCountdown.total(card) / tickDt + 0.5) end

-- Sonido de cada número y del ¡YA! (un jugador y cliente; el servidor no la llama). `prev` = lo que faltaba en el
-- frame anterior (nil = primer frame), `rem` = lo que falta ahora. Callado durante la tarjeta: el primer número suena
-- al entrar en la cuenta atrás.
function StartCountdown.beeps(prev, rem)
    local T = StartCountdown.TIME
    if rem <= 0 then
        if prev and prev > 0 then Sound.play('countGo') end
    elseif rem > T then
        return
    elseif prev == nil or prev > T or math.ceil(rem) < math.ceil(prev) then
        Sound.play('countTick')
    end
end

return StartCountdown
