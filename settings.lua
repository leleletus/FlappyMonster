-- settings.lua

-- ── Pantalla ──────────────────────────────────────────────────────────────────
WINDOW_W = 1280
WINDOW_H = 720

GUMMY_SCALE   = 4

-- ── Jugador ───────────────────────────────────────────────────────────────────
PLAYER_SCALE   = 6
PLAYER_START_X = 200
PLAYER_START_Y = WINDOW_H / 2
GRAVITY        = 1800
FLAP_VELOCITY  = -480

-- ── Tuberías (valores base – la dificultad los multiplica) ────────────────────
PIPE_SCALE      = 13
PIPE_W          = 6 * PIPE_SCALE    -- 78
PIPE_GAP        = 200
PIPE_SPEED      = 220

-- ── Dificultades ──────────────────────────────────────────────────────────────
-- speedMult/gapMult: sobre PIPE_SPEED / PIPE_GAP; spacing: px entre tuberías (se
-- sacan por DISTANCIA, así la separación no cambia al acelerar); ramp: velocidad
-- extra por tubería pasada hasta rampMax (la partida se anima sin cambiar de
-- dificultad); maxJump: lo más que se mueve el hueco de una tubería a la
-- siguiente (nil = libre). Fácil y normal eran justas pero MUY lentas.
DIFFICULTIES = {
    easy   = { speedMult = 1.20, gapMult = 1.30, spacing = 430, ramp = 0.012, rampMax = 0.25, maxJump = 170, points = 1 },
    normal = { speedMult = 1.50, gapMult = 1.00, spacing = 400, ramp = 0.012, rampMax = 0.30, maxJump = 210, points = 2 },
    hard   = { speedMult = 1.90, gapMult = 0.65, spacing = 557, ramp = 0,     rampMax = 0,                  points = 5 },
}
DIFFICULTY_ORDER = { 'easy', 'normal', 'hard' }  -- orden de selección

-- ── Escalas de menú ───────────────────────────────────────────────────────────
-- (logo.png 42x16 * 10; los rótulos de dificultad son texto de PixelFont a esta escala)
LOGO_SCALE      = 10
DIFF_IMG_SCALE  = 8

-- ── Colores ───────────────────────────────────────────────────────────────────
COLOR_WHITE  = {1,   1,   1,   1}
COLOR_RED    = {1,   0.2, 0.2, 1}

-- ── Puntuación ────────────────────────────────────────────────────────────────
SCORE_FILE = "highscore.dat"

-- ── Modo Aventura ─────────────────────────────────────────────────────────────
TILE_PX        = 16 * 4     -- 64px

-- Los IDs de tile (TILE_SOLID, TILE_WATER...) los genera el catálogo de tiles
-- (src/world/tiles/Tiles.lua), cargado al final de este archivo.

-- Física del plataformero
ADV_GRAVITY    = 1600
ADV_JUMP_VEL   = -568        -- og -560
ADV_MOVE_SPD   = 240
ADV_FRICTION   = 12          -- lerp horizontal en suelo
ADV_AIR_FRIC   = 6           -- lerp en aire (menor control)

-- Cámara
CAM_LERP       = 6           -- suavidad de seguimiento

-- ── Multijugador Online ───────────────────────────────────────────────────────
SERVER_HOST = os.getenv("FM_SERVER") or "djvemo.net.pe"  -- servidor (online y actualizaciones); FM_SERVER=localhost para pruebas
SERVER_PORT = 22122          -- puerto del servidor

-- ── Catálogo de tiles y materiales ────────────────────────────────────────────
-- Registra los tipos de tile (y sus constantes TILE_*). La física del agua y de
-- cualquier material vive ahora en src/world/tiles/materials/.
require 'src/world/tiles/Tiles'

-- Hitboxes a la vista (F1 en el juego). FM_HITBOX=1 las enciende desde el arranque: los arneses de tools/tests
-- la usan para comprobar que dibujarlas no falla con ningún enemigo ni jefe (un jugador y online).
DEBUG_HITBOX = os.getenv('FM_HITBOX') == '1'
