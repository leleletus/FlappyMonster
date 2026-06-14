-- settings.lua

-- ── Pantalla ──────────────────────────────────────────────────────────────────
WINDOW_W = 1280
WINDOW_H = 720

GUMMY_SCALE   = 4

-- ── Jugador ───────────────────────────────────────────────────────────────────
PLAYER_SCALE   = 6
PLAYER_W       = 9  * PLAYER_SCALE   -- 36
PLAYER_H       = 16 * PLAYER_SCALE   -- 64
PLAYER_START_X = 200
PLAYER_START_Y = WINDOW_H / 2
GRAVITY        = 1800
FLAP_VELOCITY  = -480

-- ── Tuberías (valores base – la dificultad los multiplica) ────────────────────
PIPE_SCALE      = 13
PIPE_W          = 6 * PIPE_SCALE    -- 78
PIPE_GAP        = 200
PIPE_SPEED      = 220
PIPE_SPAWN_TIME = 1.6
PIPE_MIN_Y      = 80
PIPE_MAX_Y      = WINDOW_H - 80 - PIPE_GAP

-- ── Dificultades ──────────────────────────────────────────────────────────────
-- Cada entrada: { speed_mult, gap_mult, spawn_mult, points, label }
DIFFICULTIES = {
    easy   = { speedMult = 0.75, gapMult = 1.35, spawnMult = 0.60, points = 1 },
    normal = { speedMult = 1.15, gapMult = 0.95, spawnMult = 1.10, points = 2 },
    hard   = { speedMult = 1.90, gapMult = 0.65, spawnMult = 1.20, points = 5 },
}
DIFFICULTY_ORDER = { 'easy', 'normal', 'hard' }  -- orden de selección

-- ── Escalas de menú ───────────────────────────────────────────────────────────
-- Imágenes pixel art → escala entera para que llenen la pantalla limpio
-- Menu.png    104x48  * 15 = 1560x720  (se centra horizontal)
-- MenuDif.png  84x48  * 15 = 1260x720  (se centra horizontal)
-- logo.png     42x16  * 10 =  420x160
-- easy.png     20x5   *  8 =  160x40
-- normal.png   30x5   *  8 =  240x40
-- hard.png     38x5   *  8 =  304x40
MENU_BG_SCALE   = 15
LOGO_SCALE      = 10
DIFF_IMG_SCALE  = 8

-- ── Scroll / Suelo ────────────────────────────────────────────────────────────
BG_SCROLL_SPEED = 60
GROUND_HEIGHT   = 60

-- ── Colores ───────────────────────────────────────────────────────────────────
COLOR_WHITE  = {1,   1,   1,   1}
COLOR_BLACK  = {0,   0,   0,   1}
COLOR_RED    = {1,   0.2, 0.2, 1}
COLOR_SKY    = {1,   1,   1,   1}   -- fondo blanco en PlayState
COLOR_GROUND = {0,   0,   0,   1}   -- suelo negro en PlayState
COLOR_PIPE   = {1,   1,   1,   1}   -- pipes usan sprite, color neutro
COLOR_PLAYER = {1,   0.85,0.10,1}

-- ── Puntuación ────────────────────────────────────────────────────────────────
SCORE_FILE = "highscore.dat"

-- ── Modo Aventura ─────────────────────────────────────────────────────────────
TILE_SIZE      = 16          -- px del sprite de tile
TILE_SCALE     = 4           -- 16 * 4 = 64px en pantalla
TILE_PX        = 16 * 4     -- 64px

-- IDs de tiles
TILE_EMPTY     = 0
TILE_SOLID     = 1
TILE_PLATFORM  = 2           -- one-way: solo colisión desde arriba
TILE_DANGER    = 3           -- mata al jugador

-- Física del plataformero
ADV_GRAVITY    = 1600
ADV_JUMP_VEL   = -560
ADV_MOVE_SPD   = 240
ADV_FRICTION   = 12          -- lerp horizontal en suelo
ADV_AIR_FRIC   = 6           -- lerp en aire (menor control)

-- Cámara
CAM_LERP       = 6           -- suavidad de seguimiento

-- IDs de tile (extendidos)
TILE_BORDER  = 4   -- borde de nivel, material distinto
TILE_SPIKE_U = 5   -- pincho apuntando arriba
TILE_SPIKE_D = 6   -- pincho apuntando abajo
TILE_SPIKE_L = 7   -- pincho apuntando izquierda
TILE_SPIKE_R = 8   -- pincho apuntando derecha
TILE_WATER   = 9   -- agua traversable
 
-- Física del agua (usadas en PlayerAdventure)
WATER_GRAVITY_MULT = 0.30   -- gravedad * este factor dentro del agua
WATER_JUMP_MULT    = 0.55   -- salto * este factor dentro del agua
WATER_SPEED_MULT   = 0.55   -- velocidad horizontal * este factor
WATER_DRAG         = 5      -- amortiguación vertical en agua

-- ── Multijugador Online ───────────────────────────────────────────────────────
SERVER_HOST = "localhost"    -- host por defecto del servidor
SERVER_PORT = 22122          -- puerto del servidor