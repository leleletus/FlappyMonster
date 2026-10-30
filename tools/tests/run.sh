#!/usr/bin/env bash
# tools/tests/run.sh — lanza un arnés de tools/tests con todo lo que necesita.
# Desde la raíz del repo:
#
#   tools/tests/run.sh <arnés> [VAR=valor ...] [-- args del arnés]
#   tools/tests/run.sh all                       # la batería rápida (ver abajo)
#
# - Los arneses online (online_smoke, online_boss) arrancan un servidor LOCAL
#   NUEVO para cada ejecución (uno reutilizado arrastra conexiones viejas),
#   esperan a que escuche y lo paran al acabar. Nunca el servidor real.
# - LEVEL= / PLAY=tools/levelgen/arenas/x.json (una arena de prueba, fuera de
#   assets/levels): se copia temporalmente a assets/levels/zz_tmp_*.json (el
#   servidor ignora los que empiezan por _) y se borra al acabar.
# - Borra server/published si no existía antes (lo crea el servidor local).
#
# Ejemplos:
#   tools/tests/run.sh crawler_drop SUMMON=1
#   tools/tests/run.sh online_boss LEVEL=tools/levelgen/arenas/jefe_cangrejo.json NOSHOTS=1
#   tools/tests/run.sh online_smoke LEVEL=assets/levels/isla_flotante.json MODE=koth
#   tools/tests/run.sh level_solve -- assets/levels/carrera01.json
set -u
cd "$(dirname "$0")/../.." || exit 1
# (el juego no se pausa al perder el foco de la ventana: game.lua love.focus)
export FM_TEST=1
# SIN VENTANAS a la vista (FM_TEST_SHOW=1 para verlas), igual en macOS y Linux:
#  - Linux con xvfb-run: cada arnés en una pantalla VIRTUAL (invisible; las capturas salen exactas); también en una
#    sesión Wayland (se le quita WAYLAND_DISPLAY y se fuerza SDL a X11: si no, la ventana salía en el escritorio).
#  - macOS (y Linux sin xvfb): ventanas FUERA DE LA PANTALLA (src/core/TestWindow.lua: dibujan y capturan igual);
#    en macOS además no roban el foco ni salen en el Dock (SDL_MAC_BACKGROUND_APP).
XVFB=0
if [ -z "${FM_TEST_SHOW:-}" ]; then
    if [ "$(uname)" = Darwin ]; then
        export FM_TEST_HIDE=1 SDL_MAC_BACKGROUND_APP=1
    elif command -v xvfb-run >/dev/null; then
        XVFB=1
    else
        export FM_TEST_HIDE=1
    fi
fi
# ¿Escucha el servidor local? (ss en Linux; lsof en macOS, donde no hay ss y se esperaban 10 s enteros)
port_up() {
    if command -v ss >/dev/null; then ss -lun 2>/dev/null | grep -q ':22122 '
    else lsof -nP -iUDP:22122 >/dev/null 2>&1; fi
}
ROOT=$(pwd)

run_one() {
    local name=$1; shift
    local envs=() args=() tmp="" server_pid="" had_pub=1 rc out
    out=$(mktemp "${TMPDIR:-/tmp}/fm_test_out.XXXXXX")
    while [ $# -gt 0 ]; do
        case "$1" in
            --) shift; args=("$@"); break ;;
            *=*) envs+=("$1") ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    [ -d "tools/tests/$name" ] || { echo "No existe el arnés tools/tests/$name"; return 2; }
    # Arena de prueba fuera de assets/levels → copia temporal
    local i
    for i in "${!envs[@]}"; do
        local v=${envs[$i]}
        if [[ ( $v == LEVEL=* || $v == PLAY=* ) && $v != *=assets/levels/* ]]; then
            local key=${v%%=*} src=${v#*=}
            tmp="assets/levels/zz_tmp_$(basename "$src")"
            cp "$src" "$tmp" || return 2
            envs[$i]="$key=$tmp"
        fi
    done
    if [[ $name == online_* ]]; then
        # (solo los online crean server/published: los demás, que pueden ir en paralelo, no lo tocan)
        [ -d server/published ] || had_pub=0
        # (el de la prueba anterior tiene que haber SOLTADO el puerto: si no, el nuevo no arranca y la prueba habla con
        # el viejo, que se está cerrando — con lsof en macOS se veía el puerto "listo" al momento)
        pkill -f "^love server" 2>/dev/null
        for _ in $(seq 1 20); do port_up || break; sleep 0.25; done
        port_up && { pkill -9 -f "^love server" 2>/dev/null; sleep 0.5; }
        export FM_SERVER=localhost      # (los arneses online nunca hablan con el servidor real)
        love server --headless > /tmp/fm_test_server.log 2>&1 &
        server_pid=$!
        for _ in $(seq 1 40); do port_up && break; sleep 0.25; done
    fi
    # (un error de LÖVE deja la pantalla de error abierta: límite de tiempo)
    local runner=(timeout "${TEST_TIMEOUT:-900}" love)
    # (pantalla virtual: -a busca una libre; el número de partida al azar evita que dos arneses en paralelo choquen)
    if [ $XVFB = 1 ] || { [ "$name" = level_solve ] && command -v xvfb-run >/dev/null; }; then
        # (en una sesión WAYLAND el SDL de LÖVE prefiere Wayland y abría la ventana en el escritorio de verdad aunque
        # corriera dentro de xvfb — el usuario, 2026-10-28 —: sin WAYLAND_DISPLAY y con el vídeo forzado a X11, la
        # ventana va a la pantalla virtual)
        runner=(timeout "${TEST_TIMEOUT:-900}" env -u WAYLAND_DISPLAY SDL_VIDEODRIVER=x11 xvfb-run -a -n $((100 + RANDOM % 800)) -s "-screen 0 1920x1080x24" love)
    fi
    env "${envs[@]}" "${runner[@]}" "tools/tests/$name" "${args[@]}" 2>&1 \
        | grep -v "^\[warning\] Tried to activate trigger" | tee "$out"
    rc=${PIPESTATUS[0]}
    # (16 arneses a la vez: a veces la pantalla virtual de xvfb no está lista y SDL no arranca — "x11 not available" —;
    # eso no es un fallo del arnés: se repite UNA vez, en otra pantalla virtual)
    if grep -q "Could not initialize SDL video subsystem" "$out"; then
        echo "   (la pantalla virtual no arrancó: se repite una vez)"
        [ ${#runner[@]} -gt 3 ] && runner=(timeout "${TEST_TIMEOUT:-900}" env -u WAYLAND_DISPLAY SDL_VIDEODRIVER=x11 xvfb-run -a -n $((100 + RANDOM % 800)) -s "-screen 0 1920x1080x24" love)
        sleep 1
        env "${envs[@]}" "${runner[@]}" "tools/tests/$name" "${args[@]}" 2>&1 \
            | grep -v "^\[warning\] Tried to activate trigger" | tee "$out"
        rc=${PIPESTATUS[0]}
    fi
    grep -q "^Error: \|stack traceback" "$out" && { echo "!! error de Lua en el arnés"; rc=1; }
    rm -f "$out"
    [ "$rc" = 124 ] && echo "!! tiempo agotado (TEST_TIMEOUT=${TEST_TIMEOUT:-900} s)"
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null; pkill -f "^love server" 2>/dev/null
        for _ in $(seq 1 20); do kill -0 "$server_pid" 2>/dev/null || break; sleep 0.25; done
        kill -9 "$server_pid" 2>/dev/null
        if grep -qi "error\|traceback" /tmp/fm_test_server.log; then
            echo "!! errores en el servidor (/tmp/fm_test_server.log):"; grep -i -A5 "error\|traceback" /tmp/fm_test_server.log | head -20
            rc=1
        fi
    fi
    [ -n "$tmp" ] && rm -f "$tmp"
    [ $had_pub = 0 ] && rm -rf server/published
    return $rc
}

if [ "${1:-}" = all ]; then
    # Batería. EN PARALELO (FM_JOBS a la vez; por defecto la mitad de los núcleos): cada arnés con sus variantes en un
    # grupo seguido (comparten carpeta de guardado); los ONLINE (y los que comparten su carpeta) en un solo grupo seguido
    # (un solo servidor local, un solo puerto); los que miden TIEMPOS (perf, el coste de los lúgubres) al final, solos.
    # FM_JOBS=1 = como antes, uno detrás de otro.
    LIST=("project_check" "docs_reference CHECK=1" "enemy_data" "tool_editors" "tool_editors TOOL=enemy" "tool_editors TOOL=enemy KIND=boss" "tool_editors FLOW=runtime" "boss_intro" "startup_intro" "menu_flow" "flyers" "flyers SEED=3" "crawler_drop" "crawler_drop SUMMON=1" "mechanics" "snowboss_rules" "megagummy_rules" "icecrabby_rules" "avalanche_rules" "cablecar_rules" "door_rules" "step_rules" "megagloomy_rules" "giantpuffer_rules" "gianthopper_rules" "giantbeetle_rules" "penguin_rules" "snowball_rules" "groovecrab_rules" "mashup_rules" "mashup_rules GAME=1" "lang_names" "sounds" "boss_sim" "boss_sim LEVEL=assets/levels/ruta_del_espejo.json" "boss_intro SECS=200" "sp_boss SECS=40 RETRY=level" "sp_boss SECS=40 DIFF=xtra" "sp_boss SECS=40 DIFF=xtra PAIR=1" "sp_boss LEVEL=assets/levels/fortaleza_malvada.json SECS=40" "boss_intro LEVEL=assets/levels/ruta_del_espejo.json SECS=40" "subtiles" "touch_layout" "flood_control" "iceberg_rules" "editor_open" "editor_open LINKS=1" "editor_open PLANE=1 LEVEL=tools/levelgen/arenas/fondo.json" "free_play" "story_flow" "story_film NOSHOTS=1" "difficulty_rules" "bot_nav" "flappy_hud"
          "update_boot FM_UPDATE=1"
          "online_menus"
          "online_update"
          "online_helmet LEVEL=tools/tests/online_helmet/level.json"
          "online_smoke LEVEL=assets/levels/jardin_gummies.json MODE=race SECS=16"
          "online_smoke LEVEL=assets/levels/isla_flotante.json MODE=koth SECS=16"
          "online_smoke LEVEL=assets/levels/jardin_gummies.json MODE=race SECS=14 LAG=120 LOSS=10"
          "online_smoke LEVEL=assets/levels/templo_del_eco.json MODE=hunt SECS=14 STALL=4.5"
          "online_smoke LEVEL=assets/levels/laberinto_submarino.json MODE=race SECS=12 WANTOXY=1"
          "online_smoke LEVEL=assets/levels/lluvia_pinchos.json MODE=race SECS=12 WATCH=rainspike WANT=armed,falling,stuck"
          "online_smoke LEVEL=tools/levelgen/arenas/bombas.json MODE=race SECS=12 WATCH=bomb WANT=lit,exploding"
          "online_smoke LEVEL=tools/levelgen/arenas/hielo.json MODE=race SECS=10 WANTTILES=thin_ice_1,thin_ice_2,thin_ice_3,empty"
          "online_smoke LEVEL=tools/tests/avalanche_rules/montana.json MODE=race SECS=12 WATCH=avalanche WANT=warn,pour,drain"
          "online_smoke LEVEL=tools/tests/online_smoke/planta.json MODE=race SECS=12 WATCH=carnivoreplant WANT=hold WANTGULP=1"
          "online_smoke LEVEL=tools/tests/iceberg_rules/costa.json MODE=race SECS=14 WATCH=iceberg WANT=warn,sunk WANTICE=1"
          "online_smoke LEVEL=tools/tests/online_smoke/pinguino.json MODE=race SECS=12 WATCH=penguin WANT=walk,slide"
          "online_smoke LEVEL=tools/tests/online_smoke/puerta.json MODE=race SECS=14 WATCH=door WANT=unlock,opening,open"
          "online_smoke LEVEL=tools/tests/online_smoke/bola_de_nieve.json MODE=hunt SECS=14 WATCH=snowball WANT=windup,charge WANTSHOVE=1"
          "online_boss LEVEL=tools/levelgen/arenas/jefe_cangrejo.json NOSHOTS=1"
          "online_boss LEVEL=tools/tests/online_boss/fortaleza_flood.json NOSHOTS=1 SECS=40"
          "online_boss LEVEL=tools/tests/online_boss/espejo.json NOSHOTS=1 SECS=30")
    ALONE=("gloomy_rules" "perf N=240 PROFILE=0")
    JOBS=${FM_JOBS:-$(( $( (sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 2) ) / 2 ))}
    [ "$JOBS" -ge 1 ] 2>/dev/null || JOBS=1
    LOGS=$(mktemp -d "${TMPDIR:-/tmp}/fm_tests.XXXXXX")
    T0=$(date +%s)
    # grupos: nombre del arnés (online_* y update_boot → "online")
    GROUPS_=()
    for t in "${LIST[@]}"; do
        n=${t%% *}
        case "$n" in online_*|update_boot) n=online ;; esac
        found=0
        for g in "${GROUPS_[@]:-}"; do [ "$g" = "$n" ] && found=1; done
        [ $found = 0 ] && GROUPS_+=("$n")
    done
    # el grupo online (el más largo) primero
    run_group() {
        local g=$1 k=0 t n r t1
        for t in "${LIST[@]}"; do
            n=${t%% *}
            case "$n" in online_*|update_boot) n=online ;; esac
            [ "$n" = "$g" ] || continue
            k=$((k + 1)); t1=$(date +%s)
            # shellcheck disable=SC2086
            run_one $t > "$LOGS/$g.$k.full" 2>&1; r=$?
            { echo "════ $t   ($(( $(date +%s) - t1 )) s)"; tail -8 "$LOGS/$g.$k.full"
              [ $r = 0 ] || echo "!! FALLA: $t"; } > "$LOGS/$g.$k.out"
            [ $r = 0 ] || touch "$LOGS/FAIL"
        done
        touch "$LOGS/$g.done"
    }
    ORDER=(online)
    for g in "${GROUPS_[@]}"; do [ "$g" = online ] || ORDER+=("$g"); done
    for g in "${ORDER[@]}"; do
        while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 0.3; done
        run_group "$g" &
    done
    wait
    for g in "${ORDER[@]}"; do cat "$LOGS/$g".*.out 2>/dev/null; done
    # los que miden tiempos: solos, al final
    k=0
    for t in "${ALONE[@]}"; do
        k=$((k + 1)); t1=$(date +%s)
        # shellcheck disable=SC2086
        run_one $t > "$LOGS/alone.$k.full" 2>&1; r=$?
        echo "════ $t   ($(( $(date +%s) - t1 )) s, solo)"; tail -8 "$LOGS/alone.$k.full"
        [ $r = 0 ] || { touch "$LOGS/FAIL"; echo "!! FALLA: $t"; }
    done
    echo "════ $(( $(date +%s) - T0 )) s en total, $JOBS a la vez (registros completos: $LOGS)"
    if [ -e "$LOGS/FAIL" ]; then echo "════ HAY FALLOS"; exit 1; fi
    echo "════ TODO OK"
    exit 0
fi
[ $# -ge 1 ] || { sed -n '2,20p' "$0"; exit 2; }
run_one "$@"
