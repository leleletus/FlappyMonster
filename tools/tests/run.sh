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
ROOT=$(pwd)

run_one() {
    local name=$1; shift
    local envs=() args=() tmp="" server_pid="" had_pub=0 rc
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
    [ -d server/published ] && had_pub=1
    if [[ $name == online_* ]]; then
        pkill -f "^love server" 2>/dev/null; sleep 0.5
        love server --headless > /tmp/fm_test_server.log 2>&1 &
        server_pid=$!
        for _ in $(seq 1 40); do ss -lun 2>/dev/null | grep -q ':22122 ' && break; sleep 0.25; done
    fi
    # (un error de LÖVE deja la pantalla de error abierta: límite de tiempo)
    local runner=(timeout "${TEST_TIMEOUT:-900}" love)
    [ "$name" = level_solve ] && command -v xvfb-run >/dev/null && runner=(timeout "${TEST_TIMEOUT:-900}" xvfb-run -a love)
    env "${envs[@]}" "${runner[@]}" "tools/tests/$name" "${args[@]}" 2>&1 \
        | grep -v "^\[warning\] Tried to activate trigger" | tee /tmp/fm_test_out.log
    rc=${PIPESTATUS[0]}
    grep -q "^Error: \|stack traceback" /tmp/fm_test_out.log && { echo "!! error de Lua en el arnés"; rc=1; }
    [ "$rc" = 124 ] && echo "!! tiempo agotado (TEST_TIMEOUT=${TEST_TIMEOUT:-900} s)"
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null; pkill -f "^love server" 2>/dev/null
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
    # Batería rápida (~5 min): física de entidades, jefe (solo y online), partida online
    fail=0
    for t in "project_check" "docs_reference CHECK=1" "enemy_data" "tool_editors" "tool_editors TOOL=enemy" "flyers" "flyers SEED=3" "crawler_drop" "crawler_drop SUMMON=1" "mechanics" "snowboss_rules" "megagummy_rules" "icecrabby_rules" "gloomy_rules" "megagloomy_rules" "lang_names" "sounds" "boss_sim" "boss_sim LEVEL=assets/levels/ruta_del_espejo.json" "boss_intro SECS=200" "sp_boss SECS=40 RETRY=level" "sp_boss SECS=40 DIFF=xtra" "boss_intro LEVEL=assets/levels/ruta_del_espejo.json SECS=40" "subtiles" "touch_layout" "flood_control" "editor_open" "editor_open LINKS=1" "free_play" "story_flow" "story_film NOSHOTS=1" "difficulty_rules" "bot_nav" "update_boot FM_UPDATE=1" \
             "online_helmet LEVEL=tools/tests/online_helmet/level.json" \
             "online_smoke LEVEL=assets/levels/jardin_gummies.json MODE=race SECS=16" \
             "online_smoke LEVEL=assets/levels/isla_flotante.json MODE=koth SECS=16" \
             "online_smoke LEVEL=tools/levelgen/arenas/bombas.json MODE=race SECS=12 WATCH=bomb WANT=lit,exploding" \
             "online_smoke LEVEL=tools/levelgen/arenas/hielo.json MODE=race SECS=10 WANTTILES=thin_ice_1,thin_ice_2,thin_ice_3,empty" \
             "online_boss LEVEL=tools/levelgen/arenas/jefe_cangrejo.json NOSHOTS=1" \
             "flappy_hud" \
             "online_boss LEVEL=tools/tests/online_boss/fortaleza_flood.json NOSHOTS=1 SECS=40" \
             "online_boss LEVEL=tools/tests/online_boss/espejo.json NOSHOTS=1 SECS=30"; do
        echo "════ $t"
        # shellcheck disable=SC2086
        run_one $t > /tmp/fm_test_all.log 2>&1; r=$?
        tail -8 /tmp/fm_test_all.log
        [ $r = 0 ] || { fail=1; echo "!! FALLA: $t"; }
    done
    [ $fail = 0 ] && echo "════ TODO OK" || echo "════ HAY FALLOS"
    exit $fail
fi
[ $# -ge 1 ] || { sed -n '2,20p' "$0"; exit 2; }
run_one "$@"
