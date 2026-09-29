#!/usr/bin/env bash
#
# backup.sh — 현재 디렉토리를 바탕화면/share/<날짜>_<시분>_<디렉토리명> 으로 백업한다.
#
# git 저장소는 커밋된 상태(HEAD)만 복원한다. 하위 디렉토리에 .git 이 있으면
# 재귀적으로 각 저장소를 찾아, 별도 폴더로 분리하지 않고 원래 구조를 보존한 채
# 같은 상대경로에 함께 백업한다. git 이 아닌 파일은 그대로 복사한다.
#
# main 이 아닌 브랜치가 체크아웃된 저장소는 기본적으로 경고하고 멈춘다.
#   --confirm   : not-main 저장소를 main 에 --no-ff 로 머지한 뒤 백업한다.
#                 (머지 불가 상태인 저장소가 하나라도 있으면 진행하지 않는다.)
#   --no-merge  : 머지하지 않고 각 저장소의 현재 커밋 상태 그대로 백업한다.
#
# 종료 코드:
#   0  성공
#   10 확인/조치 필요 (경고 출력됨) — 사용자 승인 후 --confirm 또는 --no-merge 로 재실행
#   1  오류
#
set -euo pipefail

MODE=scan   # scan | merge | nomerge
for arg in "$@"; do
  case "$arg" in
    --confirm)  MODE=merge ;;
    --no-merge) MODE=nomerge ;;
    *) echo "알 수 없는 인자: $arg" >&2; exit 1 ;;
  esac
done

SRC="$(pwd)"
DIRNAME="$(basename "$SRC")"
DATE="$(date +%F)"                 # YYYY-MM-DD
TIME="$(date +%H%M)"               # HHMM
DEST_NAME="${DATE}_${TIME}_${DIRNAME}"

# --- 바탕화면 경로 해석 (WSL: 윈도우 Desktop 우선) ---
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

DESKTOP="$(resolve_desktop)" || { echo "바탕화면 경로를 찾지 못했습니다." >&2; exit 1; }
DEST_BASE="$DESKTOP/share"
DEST="$DEST_BASE/$DEST_NAME"

# 안전장치: DEST 가 반드시 DEST_BASE 하위여야 함
case "$DEST" in
  "$DEST_BASE"/*) : ;;
  *) echo "대상 경로 계산 오류: $DEST" >&2; exit 1 ;;
esac

# --- git 저장소 루트 수집 (SRC 기준 상대경로, 얕은 경로 우선) ---
REPO_ROOTS=()
while IFS= read -r gitdir; do
  [ -n "$gitdir" ] || continue
  root="$(dirname "$gitdir")"
  rel="${root#"$SRC"}"; rel="${rel#/}"
  [ -z "$rel" ] && rel="."
  REPO_ROOTS+=("$rel")
done < <(find "$SRC" -type d -name .git 2>/dev/null)

if [ ${#REPO_ROOTS[@]} -gt 0 ]; then
  # 슬래시 개수(깊이) 오름차순 정렬 — 부모 저장소를 자식보다 먼저 처리한다.
  mapfile -t REPO_ROOTS < <(
    printf '%s\n' "${REPO_ROOTS[@]}" \
      | awk -F/ '{print NF-1"\t"$0}' | sort -n -s -k1,1 | cut -f2-
  )
fi

repo_root() { [ "$1" = "." ] && echo "$SRC" || echo "$SRC/$1"; }
git_branch() { git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null || true; }
repo_dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }
has_main()   { git -C "$1" show-ref --verify --quiet refs/heads/main; }

# --- 저장소 분류 ---
MERGE_REPOS=()    # not-main, clean, main 존재 -> --no-ff 머지 대상
BLOCK_MSGS=()     # not-main 이지만 머지 불가 (dirty / main 없음 / detached)
DIRTY_MAIN=()     # main 이지만 로컬 수정 있음 (커밋 안 된 변경은 백업에 안 담김)

if [ ${#REPO_ROOTS[@]} -gt 0 ]; then
  for r in "${REPO_ROOTS[@]}"; do
    root="$(repo_root "$r")"
    br="$(git_branch "$root")"
    if [ "$br" = "main" ]; then
      repo_dirty "$root" && DIRTY_MAIN+=("$r")
      continue
    fi
    if [ -z "$br" ]; then
      BLOCK_MSGS+=("$r: detached HEAD 상태라 머지 불가")
    elif ! has_main "$root"; then
      BLOCK_MSGS+=("$r: 로컬 main 브랜치가 없어 머지 불가 (현재: $br)")
    elif repo_dirty "$root"; then
      BLOCK_MSGS+=("$r: 커밋 안 된 로컬 수정이 있어 머지 불가 (현재: $br). 커밋/스태시 후 재실행하세요")
    else
      MERGE_REPOS+=("$r")
    fi
  done
fi

# 기존 백업은 지우지 않는다. 같은 분에 재실행한 경우에만 겹친다.
if [ -e "$DEST" ]; then
  echo "대상 폴더가 이미 존재합니다. 1분 뒤 다시 실행하세요: $DEST" >&2
  exit 1
fi

echo "소스   : $SRC"
echo "대상   : $DEST"
echo "저장소 : ${#REPO_ROOTS[@]} 개 (git), 그 외 파일은 구조 그대로 복사"
echo

# --- 확인 게이트 (scan 모드) ---
if [ "$MODE" = "scan" ]; then
  NEED_CONFIRM=0

  if [ ${#MERGE_REPOS[@]} -gt 0 ]; then
    NEED_CONFIRM=1
    echo "다음 저장소는 main 이 아닙니다. --confirm 시 main 에 --no-ff 로 머지 후 백업합니다:" >&2
    for r in "${MERGE_REPOS[@]}"; do
      echo "  - $r (현재: $(git_branch "$(repo_root "$r")") -> main)" >&2
    done
    echo >&2
  fi

  if [ ${#BLOCK_MSGS[@]} -gt 0 ]; then
    NEED_CONFIRM=1
    echo "다음 저장소는 머지할 수 없습니다 (--confirm 으로 진행 불가):" >&2
    for m in "${BLOCK_MSGS[@]}"; do echo "  - $m" >&2; done
    echo >&2
  fi

  if [ ${#DIRTY_MAIN[@]} -gt 0 ]; then
    NEED_CONFIRM=1
    echo "다음 저장소는 로컬 수정이 있습니다. 커밋 안 된 변경은 백업에 담기지 않습니다:" >&2
    for r in "${DIRTY_MAIN[@]}"; do echo "  - $r" >&2; done
    echo >&2
  fi

  if [ "$NEED_CONFIRM" -eq 1 ]; then
    echo "진행 방법:" >&2
    echo "  --confirm   main 아닌 저장소를 main 에 --no-ff 머지 후 백업" >&2
    echo "  --no-merge  머지하지 않고 현재 커밋 상태로 백업" >&2
    exit 10
  fi
  # 경고 없음 — 머지도 필요 없으므로 바로 백업한다.
  MODE=nomerge
fi

# --- 머지 (merge 모드) ---
if [ "$MODE" = "merge" ]; then
  if [ ${#BLOCK_MSGS[@]} -gt 0 ]; then
    echo "머지 불가 저장소가 있어 --confirm 으로 진행할 수 없습니다:" >&2
    for m in "${BLOCK_MSGS[@]}"; do echo "  - $m" >&2; done
    echo >&2
    echo "커밋/스태시 후 재실행하거나, --no-merge 로 현재 커밋 상태를 백업하세요." >&2
    exit 10
  fi
  if [ ${#MERGE_REPOS[@]} -gt 0 ]; then
    for r in "${MERGE_REPOS[@]}"; do
      root="$(repo_root "$r")"
      br="$(git_branch "$root")"
      echo "머지: $r ($br -> main)"
      git -C "$root" checkout main
      if ! git -C "$root" merge --no-ff "$br" -m "Merge branch '$br' into main for backup"; then
        git -C "$root" merge --abort 2>/dev/null || true
        echo "머지 충돌로 실패: $r. 수동으로 해결한 뒤 재실행하세요." >&2
        exit 1
      fi
    done
    echo
  fi
fi

# --- 백업 실행 ---
mkdir -p "$DEST"

WHOLE_IS_REPO=0
EXCLUDES=()
if [ ${#REPO_ROOTS[@]} -gt 0 ]; then
  for r in "${REPO_ROOTS[@]}"; do
    if [ "$r" = "." ]; then
      WHOLE_IS_REPO=1
    else
      EXCLUDES+=( --exclude="./$r" )   # 저장소 워킹트리는 pass 2 에서 커밋 상태로 복원
    fi
  done
fi

# pass 1: 저장소를 뺀 나머지 트리를 구조 그대로 복사 (숨김 파일 포함)
if [ "$WHOLE_IS_REPO" -eq 0 ]; then
  ( cd "$SRC" && tar -cf - "${EXCLUDES[@]}" . ) | ( cd "$DEST" && tar -xf - )
fi

# pass 2: 각 git 저장소를 같은 상대경로에 커밋(HEAD) 상태로 복원
if [ ${#REPO_ROOTS[@]} -gt 0 ]; then
  for r in "${REPO_ROOTS[@]}"; do
    s="$(repo_root "$r")"
    d="$DEST"; [ "$r" != "." ] && d="$DEST/$r"
    mkdir -p "$d"
    cp -r "$s/.git" "$d/.git"
    git -C "$d" reset --hard HEAD >/dev/null
  done
fi

echo "백업 완료: $DEST"
if [ ${#REPO_ROOTS[@]} -gt 0 ]; then
  echo "복원한 git 저장소:"
  for r in "${REPO_ROOTS[@]}"; do
    d="$DEST"; [ "$r" != "." ] && d="$DEST/$r"
    echo "  - $r  [$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?') @ $(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')]"
  done
fi
