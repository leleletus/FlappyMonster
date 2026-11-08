-- Power-up magnet_points (src/world/powerups/Powerups.lua): IMÁN DE PUNTOS: atrae lo que da puntos, unas 4 casillas, durante 20 s
-- Su efecto: src/player/PlayerAdventure.lua (usePowerup).
return { id = 'magnet_points', modes = { 'flappy', 'adventure' }, duration = 20 }
