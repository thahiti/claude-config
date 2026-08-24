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

# ── ccusage: 7일 누적 비용 ────────────────────────────────────────────────
CCUSAGE_BIN="npx --yes ccusage@latest"
week_cost=$($CCUSAGE_BIN daily --since 7d --json 2>/dev/null | jq -r '
  if type == "array" then
    (map(.cost // .totalCost // 0) | add // 0)
  elif .daily then
    (.daily | map(.cost // .totalCost // 0) | add // 0)
  else empty end
' 2>/dev/null)

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
