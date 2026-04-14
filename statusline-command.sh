#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Current directory (shorten home to ~)
home="$HOME"
if [ -n "$cwd" ]; then
  dir="${cwd/#$home/\~}"
else
  dir="$(pwd | sed "s|^$HOME|~|")"
fi

# Git branch (skip optional lock)
branch=""
if git -C "${cwd:-$(pwd)}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "${cwd:-$(pwd)}" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "${cwd:-$(pwd)}" rev-parse --short HEAD 2>/dev/null)
fi

# ── ccusage: 현재 활성 블록 비용 & 7일 누적 비용 (병렬 실행) ──────────────
CCUSAGE_BIN="npx --yes ccusage@latest"
TMP_BLOCK=$(mktemp)
TMP_WEEK=$(mktemp)

# 병렬로 두 쿼리 실행
$CCUSAGE_BIN blocks --active --json >"$TMP_BLOCK" 2>/dev/null &
PID_BLOCK=$!
$CCUSAGE_BIN daily --since 7d --json >"$TMP_WEEK" 2>/dev/null &
PID_WEEK=$!

wait $PID_BLOCK $PID_WEEK

# 현재 활성 블록 비용 파싱
session_cost=""
if [ -s "$TMP_BLOCK" ]; then
  # blocks --active --json: { blocks: [ { totalCost: N, ... } ] }
  session_cost=$(jq -r '
    if type == "array" then
      (map(.totalCost // 0) | add // 0)
    elif .blocks then
      (.blocks | map(.totalCost // 0) | add // 0)
    else empty end
  ' "$TMP_BLOCK" 2>/dev/null)
fi

# 7일 누적 비용 파싱
week_cost=""
if [ -s "$TMP_WEEK" ]; then
  # daily --since 7d --json: { daily: [ { cost: N, ... } ] } 또는 배열
  week_cost=$(jq -r '
    if type == "array" then
      (map(.cost // .totalCost // 0) | add // 0)
    elif .daily then
      (.daily | map(.cost // .totalCost // 0) | add // 0)
    else empty end
  ' "$TMP_WEEK" 2>/dev/null)
fi

rm -f "$TMP_BLOCK" "$TMP_WEEK"

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

# 현재 세션(활성 블록) 비용
if [ -n "$session_cost" ] && [ "$session_cost" != "null" ] && [ "$session_cost" != "0" ]; then
  formatted=$(printf '%.4f' "$session_cost" 2>/dev/null)
  printf ' \033[33m세션:$%s\033[0m' "$formatted"
fi

# 7일 누적 비용
if [ -n "$week_cost" ] && [ "$week_cost" != "null" ] && [ "$week_cost" != "0" ]; then
  formatted_week=$(printf '%.2f' "$week_cost" 2>/dev/null)
  printf ' \033[35m주간:$%s\033[0m' "$formatted_week"
fi

printf '\n'
