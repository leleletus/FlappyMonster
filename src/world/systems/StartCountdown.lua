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

StartCountdown.TIME    = 3        -- s
StartCountdown.GO_TIME = 0.8      -- s que se ve "¡YA!" al acabar

-- Ticks de la cuenta atrás a paso fijo (servidor)
function StartCountdown.ticks(tickDt) return math.floor(StartCountdown.TIME / tickDt + 0.5) end

-- Sonido de cada número y del ¡YA! (un jugador y cliente; el servidor no la llama). `prev` = lo que faltaba en el
-- frame anterior (nil = primer frame: suena el primer número), `rem` = lo que falta ahora.
function StartCountdown.beeps(prev, rem)
    if rem <= 0 then
        if prev and prev > 0 then Sound.play('countGo') end
    elseif prev == nil or math.ceil(rem) < math.ceil(prev) then
        Sound.play('countTick')
    end
end

return StartCountdown
