#!/usr/bin/env bash
#
# import.sh 의 저장소 스냅샷 반입 동작 테스트.
# 가짜 HOME 아래에 share 폴더와 백업 폴더를 만들어 실제 바탕화면을
# 건드리지 않는다. 백업 폴더는 backup 스킬 결과와 같은 모양으로
# 바깥 저장소가 /inner/ 를 무시하고 그 안에 내부 저장소를 둔다.
#
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/import.sh"
DATE="$(date +%F)"

commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.email=t@t -c user.name=t commit -q -m "$2"
}

setup() {
  HOME="$(mktemp -d)"
  export HOME
  SHARE="$HOME/Desktop/share"
  SRC="$HOME/src"
  mkdir -p "$SHARE" "$SRC/inner"
  git -C "$SRC" init -q -b main
  printf '/inner/\n' > "$SRC/.gitignore"
  printf 'a1\n' > "$SRC/a.txt"
  printf 'c1\n' > "$SRC/c.txt"
  commit_all "$SRC" init
  git -C "$SRC/inner" init -q -b main
  printf 'i1\n' > "$SRC/inner/i.txt"
  commit_all "$SRC/inner" init
}

# backup 스킬처럼 .git 까지 통째로 복사한다
backup() {
  cp -r "$SRC" "$SHARE/${DATE}_$1_proj"
}

run_package() {
  printf '# %s\n' "$1" > "$SHARE/$1.md"
  bash "$SCRIPT" package --name "$1" --md "$SHARE/$1.md" > /dev/null
}

has() {
  grep -qxF "$2" <<< "$1" || { echo "    '$2' 가 없음"; return 1; }
}

lacks() {
  ! grep -qF "$2" <<< "$1" || { echo "    '$2' 가 있으면 안 됨"; return 1; }
}

test_first_import_includes_everything_and_records_state() {
  backup 0900
  run_package p
  local list; list="$(unzip -Z1 "$SHARE/${DATE}_p.zip")"
  has "$list" "p.md" &&
  has "$list" "${DATE}_0900_proj/a.txt" &&
  has "$list" "${DATE}_0900_proj/c.txt" &&
  has "$list" "${DATE}_0900_proj/.git/HEAD" &&
  has "$list" "${DATE}_0900_proj/inner/i.txt" &&
  has "$list" "${DATE}_0900_proj/inner/.git/HEAD" &&
  has "$(cut -f2 "$SHARE/.import-state")" "$(git -C "$SRC" rev-parse HEAD)"
}

test_same_day_changed_repo_is_included_in_full() {
  backup 0900
  run_package p
  printf 'a2\n' > "$SRC/a.txt"
  printf 'b1\n' > "$SRC/b.txt"
  commit_all "$SRC" change
  backup 1000
  run_package p
  local list; list="$(unzip -Z1 "$SHARE/${DATE}_p_2.zip")"
  has "$list" "${DATE}_1000_proj/a.txt" &&
  has "$list" "${DATE}_1000_proj/b.txt" &&
  has "$list" "${DATE}_1000_proj/c.txt" &&
  has "$list" "${DATE}_1000_proj/.gitignore" &&
  has "$list" "${DATE}_1000_proj/.git/HEAD" &&
  lacks "$list" "${DATE}_1000_proj/inner/" &&
  lacks "$list" "${DATE}_0900_proj/"
}

test_same_day_zip_is_not_overwritten() {
  backup 0900
  run_package p
  local before; before="$(unzip -Z1 "$SHARE/${DATE}_p.zip")"
  printf 'a2\n' > "$SRC/a.txt"
  commit_all "$SRC" change
  backup 1000
  run_package p
  [ -f "$SHARE/${DATE}_p_2.zip" ] || { echo "    _2 zip 없음"; return 1; }
  [ "$before" = "$(unzip -Z1 "$SHARE/${DATE}_p.zip")" ] ||
    { echo "    첫 zip 이 바뀜"; return 1; }
}

test_discover_fails_when_nothing_new() {
  backup 0900
  run_package p
  backup 1000
  ! bash "$SCRIPT" discover > /dev/null 2>&1 ||
    { echo "    변경이 없는데 성공함"; return 1; }
}

test_previous_day_record_is_ignored_and_dropped() {
  backup 0900
  local key; key="$(git -C "$SRC" rev-list --max-parents=0 HEAD)"
  printf '%s\t%s\t%s\t%s\n' "$key" "$(git -C "$SRC" rev-parse HEAD)" \
    "2000-01-01 10:00" "2000-01-01_p.zip" > "$SHARE/.import-state"
  run_package p
  local list; list="$(unzip -Z1 "$SHARE/${DATE}_p.zip")"
  has "$list" "${DATE}_0900_proj/a.txt" &&
  has "$list" "${DATE}_0900_proj/c.txt" &&
  has "$list" "${DATE}_0900_proj/.git/HEAD" &&
  lacks "$(cat "$SHARE/.import-state")" "2000-01-01"
}

failed=0
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  if ( setup && "$t"; r=$?; rm -rf "$HOME"; exit "$r" ); then
    echo "PASS $t"
  else
    echo "FAIL $t"
    failed=1
  fi
done
exit "$failed"
