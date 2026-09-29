#!/usr/bin/env bash
#
# import.sh — 오늘 날짜로 backup 된 디렉토리들을 조사하고, 오늘 아직 반입하지
# 않은 저장소를 저장소 스냅샷 전체로 하나의 zip 반입 패키지에 담는다.
#
# 서브커맨드:
#   discover                       반입 대상(저장소별 스냅샷) + 추천 slug + share 경로 출력
#   package --name NAME --md PATH  반입 대상 + NAME.md 를 share/<날짜>_NAME.zip 으로 압축
#
# backup 스킬이 만든 바탕화면/share/<날짜>_<시분>_<디렉토리명> 구조를 전제로 한다.
# 저장소마다 오늘 반입한 HEAD 를 share/.import-state 에 기록한다.
# 기록은 그날에만 유효하고, 날짜가 바뀌면 모든 저장소를 다시 전체로 넣는다.
#
set -euo pipefail

# --- 바탕화면 경로 해석 (backup 스킬과 동일 로직) ---
resolve_desktop() {
  if [ -d "$HOME/Desktop" ]; then echo "$HOME/Desktop"; return 0; fi
  local up wp
  up="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)"
  if [ -n "$up" ]; then
    wp="$(wslpath "$up" 2>/dev/null || true)"
    [ -n "$wp" ] && [ -d "$wp/Desktop" ] && { echo "$wp/Desktop"; return 0; }
  fi
  local d
  for d in /mnt/c/Users/*/Desktop; do
    case "$d" in
      */Default/*|*/"Default User"/*|*/Public/*|*/"All Users"/*) continue ;;
    esac
    [ -d "$d" ] && { echo "$d"; return 0; }
  done
  return 1
}

DATE="$(date +%F)"                  # YYYY-MM-DD
DESKTOP="$(resolve_desktop)" || { echo "바탕화면 경로를 찾지 못했습니다." >&2; exit 1; }
SHARE="$DESKTOP/share"
# 한 줄에 저장소 하나: 루트커밋 \t 반입한 HEAD \t 반입 시각 \t zip 파일명
STATE="$SHARE/.import-state"

# 오늘 날짜 백업 디렉토리 수집 (한 줄에 하나씩; 없으면 아무것도 출력 안 함)
collect_dirs() {
  local d
  if [ -d "$SHARE" ]; then
    for d in "$SHARE/${DATE}_"*/; do
      [ -d "$d" ] || continue
      printf '%s\n' "${d%/}"
    done
  fi
}

# 첫 디렉토리명에서 slug 추천: 날짜 접두사 제거 → 소문자 → [a-z0-9]만 → 20자 컷
suggest_slug() {
  local first name slug
  first="$1"
  name="$(basename "$first")"
  name="${name#${DATE}_}"
  name="${name#[0-9][0-9][0-9][0-9]_}"   # backup 의 HHMM 접두사
  slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  printf '%s' "${slug:0:20}"
}

# 저장소를 폴더명 대신 루트 커밋으로 구분한다. 백업 폴더명은 매번
# 바뀌고, 이름이 같은 다른 저장소(하네스와 내부 저장소)도 있기 때문이다.
repo_key() {
  git -C "$1" rev-list --max-parents=0 HEAD | sort | head -1
}

# 반입 시각이 오늘인 기록만 본다. 받는 쪽은 날마다 저장소 전체를 새로
# 받으므로 전날 반입한 HEAD 는 기준이 되지 않는다.
last_import() {
  [ -f "$STATE" ] || return 0
  awk -F'\t' -v k="$1" -v d="$DATE" \
    '$1 == k && substr($3, 1, 10) == d { h = $2 } END { print h }' "$STATE"
}

# 저장소마다 오늘 백업 중 HEAD 커밋 시각이 가장 늦은 것을 고르고,
# 반입할 항목을 탭 구분 레코드로 출력한다.
#   FILE    <share 기준 경로>   zip 에 넣을 파일이나 폴더
#   REPO    <루트커밋> <경로> <오늘 반입|-> <HEAD> <파일 수>
#   SKIP    <경로> <HEAD>       오늘 같은 HEAD 로 이미 반입함
# 받는 쪽이 저장소를 그대로 쓸 수 있도록 변경분이 아니라 추적 파일
# 전체와 .git 을 넣는다.
# 폴더명 정렬은 옛 형식(<날짜>_<이름>)과 새 형식(<날짜>_<시분>_<이름>)이
# 섞이면 순서가 틀리므로 커밋 시각으로 고른다.
plan() {
  local dirs d g f cands=()
  mapfile -t dirs < <(collect_dirs)
  for d in "${dirs[@]}"; do
    # 저장소 밖 파일은 반입 기록이 없으므로 그대로 넣는다
    find "$d" \( -type d -exec test -e '{}/.git' \; -prune \) -o -type f -print |
      while IFS= read -r f; do printf 'FILE\t%s\n' "${f#"$SHARE"/}"; done
    while IFS= read -r g; do
      f="$(dirname "$g")"
      cands+=("$(repo_key "$f")	$(git -C "$f" log -1 --format=%ct)	$f")
    done < <(find "$d" -type d -name .git -prune -print)
  done
  [ "${#cands[@]}" -gt 0 ] || return 0

  local key ct r rel head last n
  while IFS=$'\t' read -r key ct r; do
    rel="${r#"$SHARE"/}"
    head="$(git -C "$r" rev-parse HEAD)"
    last="$(last_import "$key")"
    if [ "$last" = "$head" ]; then
      printf 'SKIP\t%s\t%s\n' "$rel" "$head"
      continue
    fi
    printf 'FILE\t%s/.git\n' "$rel"
    n=0
    while IFS= read -r f; do
      printf 'FILE\t%s/%s\n' "$rel" "$f"; n=$((n + 1))
    done < <(git -C "$r" -c core.quotePath=false ls-files)
    printf 'REPO\t%s\t%s\t%s\t%s\t%s\n' "$key" "$rel" "${last:--}" "$head" "$n"
  done < <(printf '%s\n' "${cands[@]}" |
    sort -t$'\t' -k1,1 -k2,2n -k3,3 |
    awk -F'\t' '{ c[$1] = $0 } END { for (k in c) print c[k] }' |
    sort -t$'\t' -k3,3)
}

# plan 결과를 파일에 남긴다. 반입할 내용이 없으면 멈춘다.
write_plan() {
  plan > "$1"
  if ! grep -q '^FILE' "$1"; then
    echo "오늘 이미 반입한 내용 외에 새로 반입할 내용이 없습니다: $SHARE/${DATE}_*" >&2
    exit 1
  fi
}

cmd_discover() {
  local dirs
  mapfile -t dirs < <(collect_dirs)
  if [ "${#dirs[@]}" -eq 0 ]; then
    echo "오늘($DATE) 날짜로 백업된 디렉토리가 없습니다: $SHARE/${DATE}_*" >&2
    exit 1
  fi
  # EXIT trap 은 함수가 끝난 뒤 실행되므로 PLAN 은 전역으로 둔다
  PLAN="$(mktemp)"
  trap 'rm -f "$PLAN"' EXIT
  write_plan "$PLAN"
  echo "DATE=$DATE"
  echo "SHARE=$SHARE"
  echo "SUGGESTED_SLUG=$(suggest_slug "${dirs[0]}")"
  echo "COUNT=${#dirs[@]}"
  local d
  for d in "${dirs[@]}"; do
    echo "DIR	$d"
  done
  grep -v '^FILE' "$PLAN" || true
}

cmd_package() {
  local NAME="" MD=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) NAME="$2"; shift 2 ;;
      --md)   MD="$2"; shift 2 ;;
      *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
    esac
  done

  [ -n "$NAME" ] || { echo "--name 이 필요합니다." >&2; exit 1; }
  [ -n "$MD" ]   || { echo "--md 가 필요합니다." >&2; exit 1; }

  # NAME 검증: 영문 시작, 영문/숫자, 20자 이하
  if ! [[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || [ "${#NAME}" -gt 20 ]; then
    echo "이름이 규칙에 맞지 않습니다(영문으로 시작, 영문/숫자, 20자 이하): '$NAME'" >&2
    exit 1
  fi
  [ -f "$MD" ] || { echo ".md 파일이 없습니다: $MD" >&2; exit 1; }

  local dirs
  mapfile -t dirs < <(collect_dirs)
  if [ "${#dirs[@]}" -eq 0 ]; then
    echo "오늘($DATE) 날짜로 백업된 디렉토리가 없습니다: $SHARE/${DATE}_*" >&2
    exit 1
  fi
  # EXIT trap 은 함수가 끝난 뒤 실행되므로 PLAN 은 전역으로 둔다
  PLAN="$(mktemp)"
  trap 'rm -f "$PLAN"' EXIT
  write_plan "$PLAN"

  # .md 를 share/NAME.md 로 배치 (zip 안에 NAME.md 로 들어가도록)
  local MD_DEST="$SHARE/$NAME.md"
  if [ "$(readlink -f "$MD")" != "$(readlink -f "$MD_DEST" 2>/dev/null || echo "$MD_DEST")" ]; then
    cp -f "$MD" "$MD_DEST"
  fi

  # 같은 날 앞선 반입 zip 은 이미 반출된 것이므로 덮어쓰지 않는다
  local ZIP="$SHARE/${DATE}_$NAME.zip" n=2
  while [ -e "$ZIP" ]; do
    ZIP="$SHARE/${DATE}_${NAME}_$n.zip"; n=$((n + 1))
  done

  # share 기준 상대경로로 압축해서 zip 내부 구조를 깔끔하게 유지.
  # .git 은 폴더째 넣어야 빈 refs/ 같은 폴더까지 남아 저장소로 인식된다.
  { printf '%s\n' "$NAME.md"; awk -F'\t' '$1 == "FILE" { print $2 }' "$PLAN"; } |
    ( cd "$SHARE" && zip -r -q "$ZIP" -@ )

  # zip 이 만들어진 뒤에만 반입 지점을 갱신한다. 전날 기록은 버린다.
  local now next
  now="$(date '+%F %H:%M')"
  next="$(mktemp)"
  {
    if [ -f "$STATE" ]; then
      awk -F'\t' -v d="$DATE" 'NR == FNR { if ($1 == "REPO") done[$2] = 1; next }
                  !($1 in done) && substr($3, 1, 10) == d' "$PLAN" "$STATE"
    fi
    awk -F'\t' -v now="$now" -v zip="$(basename "$ZIP")" \
      '$1 == "REPO" { print $2 "\t" $5 "\t" now "\t" zip }' "$PLAN"
  } > "$next"
  mv "$next" "$STATE"

  echo "반입 패키지 생성 완료"
  echo "   zip : $ZIP"
  echo "   md  : $MD_DEST"
  echo "   반입 기록: $STATE"
  awk -F'\t' '
    $1 == "REPO" { print "     - " $3 ": 저장소 전체 " $6 "개 파일과 .git (HEAD " substr($5, 1, 7) ")" }
    $1 == "SKIP" { print "     - " $2 ": 오늘 같은 HEAD 로 반입함, 제외" }' "$PLAN"
}

case "${1:-}" in
  discover) shift; cmd_discover "$@" ;;
  package)  shift; cmd_package "$@" ;;
  *) echo "사용법: import.sh {discover|package --name NAME --md PATH}" >&2; exit 1 ;;
esac
