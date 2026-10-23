#!/bin/bash
# 휴대폰용 읽기 전용 뷰어를 켜고 끄고 상태를 본다.
#   bash viewer.sh start <디렉터리>...   지정한 디렉터리들을 루트로 (재)시작하고 링크를 출력
#   bash viewer.sh add <디렉터리>        현재 루트 목록에 더해 다시 시작
#   bash viewer.sh stop                  뷰어 프로세스만 종료 (tailscale serve 설정은 유지)
#   bash viewer.sh status                루트 목록, 포트, 링크를 출력
set -euo pipefail

APP_DIR=/Users/randy/claude_code/mobile-viewer
PORT=${VIEWER_PORT:-7777}
LOG=/tmp/mobile-viewer.log
ROOTS_FILE=/tmp/mobile-viewer.roots

tailnet_host() {
    tailscale status --json | python3 -c \
        'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))'
}

kill_listener() {
    local pids
    pids=$(lsof -ti :"$PORT" || true)
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill
        sleep 1
    fi
}

ensure_serve() {
    # 계정에 HTTPS 인증서가 없으면 기본(443) serve 는 멈추므로 HTTP 80 으로 건다.
    if ! tailscale serve status 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
        tailscale serve --bg --http=80 "$PORT" >/dev/null
    fi
}

# 인자로 받은 디렉터리들을 절대 경로로 바꿔 한 줄에 하나씩 출력한다.
absolute_dirs() {
    local dir
    for dir in "$@"; do
        (cd "$dir" && pwd -P)
    done
}

start_with() {
    local roots_spec
    roots_spec=$(printf '%s\n' "$@" | paste -sd: -)
    kill_listener
    (cd "$APP_DIR" && VIEWER_ROOTS="$roots_spec" VIEWER_PORT="$PORT" \
        nohup uv run --frozen app.py >"$LOG" 2>&1 </dev/null &)
    for _ in $(seq 1 20); do
        if curl -sf -o /dev/null "http://127.0.0.1:$PORT/"; then break; fi
        sleep 0.5
    done
    curl -sf -o /dev/null "http://127.0.0.1:$PORT/" \
        || { echo "뷰어가 뜨지 않았다. 로그: $LOG" >&2; tail -3 "$LOG" >&2; exit 1; }
    printf '%s\n' "$@" >"$ROOTS_FILE"
    ensure_serve
    printf 'root: %s\n' "$@"
    echo "url: http://$(tailnet_host)/"
}

case "${1:-}" in
start)
    [ $# -ge 2 ] || { echo "디렉터리를 하나 이상 지정한다" >&2; exit 2; }
    shift
    roots=()
    while IFS= read -r line; do roots+=("$line"); done < <(absolute_dirs "$@")
    start_with "${roots[@]}"
    ;;
add)
    new=$(cd "${2:?디렉터리를 지정한다}" && pwd -P)
    roots=()
    if [ -f "$ROOTS_FILE" ]; then
        while IFS= read -r line; do roots+=("$line"); done <"$ROOTS_FILE"
    fi
    for r in "${roots[@]}"; do
        [ "$r" = "$new" ] && { echo "이미 포함된 루트: $new"; exit 0; }
    done
    start_with "${roots[@]}" "$new"
    ;;
stop)
    kill_listener
    rm -f "$ROOTS_FILE"
    echo "stopped"
    ;;
status)
    if lsof -ti :"$PORT" >/dev/null; then
        echo "running"
        sed 's/^/root: /' "$ROOTS_FILE" 2>/dev/null || echo "root: ?"
        echo "url: http://$(tailnet_host)/"
    else
        echo "not running"
    fi
    tailscale serve status 2>/dev/null || true
    ;;
*)
    sed -n '2,6p' "$0" >&2
    exit 2
    ;;
esac
