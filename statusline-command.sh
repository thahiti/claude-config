#!/bin/bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
# Claude Code 2.1+ stdin: .rate_limits.{five_hour,seven_day}.used_percentage
# (Claude.ai 구독자에 한해, 최초 API 응답 이후부터 채워짐)
usage_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Current directory (shorten home to ~)
home="$HOME"
if [ -n "$cwd" ]; then
  dir="${cwd/#$home/~}"
else
  dir="$(pwd | sed "s|^$HOME|~|")"
fi

# Git branch (skip optional lock)
branch=""
if git -C "${cwd:-$(pwd)}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "${cwd:-$(pwd)}" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "${cwd:-$(pwd)}" rev-parse --short HEAD 2>/dev/null)
fi

# ── ccusage: 7일 누적 비용 (캐시) ─────────────────────────────────────────
# 상태라인은 매우 자주 렌더된다. npx 를 그때마다 띄우면 프로세스 생성과 네트워크
# 조회가 반복돼 입력이 눈에 띄게 느려진다. 캐시를 읽어 즉시 출력하고, 만료됐으면
# 갱신은 백그라운드로 던져 렌더를 절대 막지 않는다.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.claude/cache}"
CACHE_FILE="$CACHE_DIR/ccusage-week.txt"
CACHE_TTL=300

mkdir -p "$CACHE_DIR" 2>/dev/null

cache_age() {
  [ -f "$CACHE_FILE" ] || { echo 999999; return; }
  local mtime
  mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
  [ -n "$mtime" ] && echo $(( $(date +%s) - mtime )) || echo 999999
}

refresh_week_cost() {
  npx --yes ccusage@latest daily --since 7d --json 2>/dev/null | jq -r '
    if type == "array" then
      (map(.cost // .totalCost // 0) | add // 0)
    elif .daily then
      (.daily | map(.cost // .totalCost // 0) | add // 0)
    else empty end
  ' 2>/dev/null > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
}

if [ "$(cache_age)" -gt "$CACHE_TTL" ]; then
  # 락 파일로 중복 실행을 막는다. 여러 세션이 동시에 렌더해도 갱신은 하나만 돈다.
  if mkdir "$CACHE_FILE.lock" 2>/dev/null; then
    ( refresh_week_cost; rmdir "$CACHE_FILE.lock" ) >/dev/null 2>&1 &
  fi
fi

week_cost=$(cat "$CACHE_FILE" 2>/dev/null)

# ── 출력 ──────────────────────────────────────────────────────────────────────

# Directory segment
printf '\033[34m%s\033[0m' "$dir"

# Git branch segment
if [ -n "$branch" ]; then
  printf ' \033[35m\xee\x9c\xa5 %s\033[0m' "$branch"
fi

# Model segment
if [ -n "$model" ]; then
  printf ' \033[36m%s\033[0m' "$model"
fi

# Context remaining
if [ -n "$remaining" ]; then
  # Color: green > 50%, yellow > 20%, red <= 20%
  pct=$(printf '%.0f' "$remaining")
  if [ "$pct" -gt 50 ]; then
    color='\033[32m'
  elif [ "$pct" -gt 20 ]; then
    color='\033[33m'
  else
    color='\033[31m'
  fi
  printf " ${color}ctx:%d%%\033[0m" "$pct"
fi

# 현재 5시간 블록 한도 대비 사용률
if [ -n "$usage_pct" ] && [ "$usage_pct" != "null" ]; then
  upct=$(printf '%.0f' "$usage_pct" 2>/dev/null)
  # Color: green < 50%, yellow < 80%, red >= 80%
  if [ "$upct" -lt 50 ]; then
    ucolor='\033[32m'
  elif [ "$upct" -lt 80 ]; then
    ucolor='\033[33m'
  else
    ucolor='\033[31m'
  fi
  printf " ${ucolor}usage:%d%%\033[0m" "$upct"
fi

# 7일 누적 비용
if [ -n "$week_cost" ] && [ "$week_cost" != "null" ] && [ "$week_cost" != "0" ]; then
  formatted_week=$(printf '%.2f' "$week_cost" 2>/dev/null)
  printf ' \033[35m주간:$%s\033[0m' "$formatted_week"
fi

printf '\n'
