#!/usr/bin/env bash
# tools/deploy_server.sh — PONE AL DÍA EL SERVIDOR del juego después de un push a master:
#   entra por ssh, cierra la screen donde corre, hace git pull y lo vuelve a arrancar en la screen.
#
#   tools/deploy_server.sh            actualiza y reinicia
#   tools/deploy_server.sh --status   solo mira: versión, commit, screen, proceso y puerto (no toca nada)
#
# NO guarda ninguna clave: usa tu ssh tal cual (el host de ~/.ssh/config). Si la llave tiene passphrase, tiene que
# estar cargada en un ssh-agent ANTES (una vez por sesión):   eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa
# Sin agente, ssh la pedirá por teclado (a mano funciona igual).
#
# Ajustes (variables de entorno):
#   FM_SSH_HOST    host de ssh                     (dj-vera-server)
#   FM_SERVER_DIR  carpeta del repo en el servidor (~/FlappyMonsterOnLain)
#   FM_SCREEN      nombre de la screen             (flappy)
#   FM_SERVER_CMD  cómo se arranca                 (love server --headless)
#   FM_SERVER_LOG  dónde va su salida              (~/flappy.log)
#   FM_BRANCH      rama                            (master)
set -euo pipefail

HOST="${FM_SSH_HOST:-dj-vera-server}"
DIR="${FM_SERVER_DIR:-FlappyMonsterOnLain}"
SCREEN="${FM_SCREEN:-flappy}"
CMD="${FM_SERVER_CMD:-love server --headless}"
LOG="${FM_SERVER_LOG:-flappy.log}"
BRANCH="${FM_BRANCH:-master}"
PORT=22122
MODE="${1:-deploy}"

# (lo que se ejecuta ALLÍ; las variables de arriba viajan como argumentos, sin comillas raras)
remote() {
    ssh -o ConnectTimeout=15 "$HOST" bash -s -- "$MODE" "$DIR" "$SCREEN" "$CMD" "$LOG" "$BRANCH" "$PORT" <<'REMOTE'
set -euo pipefail
MODE="$1"; DIR="$2"; SCREEN="$3"; CMD="$4"; LOG="$5"; BRANCH="$6"; PORT="$7"
cd "$HOME/$DIR" 2>/dev/null || cd "$DIR"

status() {
    echo "  versión:  $(cat version.txt 2>/dev/null || echo '?')   commit: $(git log --oneline -1 | cut -c1-70)"
    echo "  screen:   $(screen -ls 2>/dev/null | grep -E "[0-9]+\.$SCREEN[[:space:]]" | tr -s '[:space:]' ' ' || true)"
    echo "  proceso:  $(pgrep -af 'love.*server' | head -1 || true)"
    echo "  puerto:   $(ss -lunH 2>/dev/null | grep -c ":$PORT " || true) escuchando en $PORT/udp"
}

echo "== servidor: $(hostname) · $(pwd)"
echo "-- antes"
status
[ "$MODE" = "--status" ] && exit 0

# Cambios a mano en el servidor: no se pisan (el pull es solo hacia delante y falla si chocan)
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "!! hay cambios locales sin guardar en el servidor:"; git status --short --untracked-files=no | head -10
fi

# 1. cerrar la screen (con el servidor dentro) y esperar a que suelte el puerto
if screen -ls 2>/dev/null | grep -qE "[0-9]+\.$SCREEN[[:space:]]"; then
    echo "-- cerrando la screen '$SCREEN'"
    screen -S "$SCREEN" -X quit || true
fi
for _ in $(seq 1 20); do
    ss -lunH 2>/dev/null | grep -q ":$PORT " || break
    sleep 0.5
done
if ss -lunH 2>/dev/null | grep -q ":$PORT "; then
    echo "!! el puerto $PORT sigue ocupado (¿otro servidor fuera de la screen?): no se arranca otro"; pgrep -af 'love.*server' || true
    exit 1
fi

# 2. al día
echo "-- git pull ($BRANCH)"
git fetch --quiet origin "$BRANCH"
git pull --ff-only --quiet origin "$BRANCH"

# 3. de nuevo en su screen (desde la raíz del repo: el servidor necesita git para publicar las actualizaciones)
echo "-- arrancando: $CMD"
case "$LOG" in /*) L="$LOG" ;; *) L="$HOME/$LOG" ;; esac
screen -dmS "$SCREEN" bash -lc "cd '$(pwd)' && $CMD 2>&1 | tee -a '$L'"
for _ in $(seq 1 20); do
    ss -lunH 2>/dev/null | grep -q ":$PORT " && break
    sleep 0.5
done
echo "-- después"
status
if ! ss -lunH 2>/dev/null | grep -q ":$PORT "; then
    echo "!! no ha quedado escuchando en $PORT: mira el registro"; tail -15 "$L" 2>/dev/null || true
    exit 1
fi
echo "OK: servidor al día y corriendo"
REMOTE
}

remote
