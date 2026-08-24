---
name: sync-claude-config
description: Use when the user wants to apply the claude-config repo (settings.json, skills, statusline) to the current machine, or explicitly invokes /sync-claude-config. Safely merges with any existing ~/.claude/settings.json so local customizations are preserved.
---

# Sync Claude Config Skill

## Overview

이 스킬은 `~/claude-config/` 리포의 Claude Code 설정을 **현재 컴퓨터의 `~/.claude/`** 에 적용한다. 기존 설정이 있으면 손실 없이 병합한다.

## When to Invoke

- 새 컴퓨터에 Claude 설정을 처음 깔 때
- 리포가 업데이트된 후 기존 머신을 동기화할 때
- 사용자가 명시적으로 `/sync-claude-config` 를 호출했을 때

## Prerequisites

1. 리포가 로컬에 클론되어 있어야 한다 (기본 경로 `~/claude-config`). 없으면:
   ```bash
   git clone git@github.com:thahiti/claude-config.git ~/claude-config
   ```
2. Python 3.8+ 설치 필요 (병합 스크립트).
3. **이 스킬을 호출하는 가장 간단한 방법**:
   ```bash
   cd ~/claude-config
   claude
   # 프롬프트에서: /sync-claude-config
   ```
   리포 안의 `.claude/skills/sync-claude-config` 심볼릭 링크 덕분에 clone 직후 별도 설치 없이 프로젝트 레벨 스킬로 발견된다.

## Repo Path Detection

스킬 실행 시 리포 경로는 다음 순서로 찾는다:
1. 사용자가 인자로 경로를 지정했으면 그 경로
2. 현재 cwd 의 git 루트가 `thahiti/claude-config` 원격을 가지면 그 경로
3. `~/claude-config/` (기본값)

어느 것으로 잡혔는지 사용자에게 알려준 뒤 절차를 진행한다.

## 절차 (반드시 순서대로)

### 1. 사전 확인

```bash
REPO="$HOME/claude-config"
TARGET="$HOME/.claude/settings.json"

test -d "$REPO" || { echo "리포가 없습니다. git clone 부터 진행하세요."; exit 1; }
test -f "$REPO/settings.json" || { echo "리포에 settings.json 이 없습니다."; exit 1; }
```

### 2. 대상 설정 상태 분류

다음 세 가지 중 하나를 판별한다:

| 상태 | 판별 | 대응 |
|---|---|---|
| **없음** | `~/.claude/settings.json` 파일 자체가 없음 | 심볼릭 링크 생성 |
| **심볼릭 링크** | 이미 `$REPO/settings.json` 로 연결됨 | 아무것도 하지 않음 |
| **독립 파일** | 일반 파일 또는 다른 곳으로 연결된 링크 | **병합** |

```bash
if [ ! -e "$TARGET" ]; then
  STATE="none"
elif [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$REPO/settings.json" ]; then
  STATE="linked"
else
  STATE="standalone"
fi
```

### 3. 상태별 처리

#### 3-A. `none` — 심볼릭 링크 생성

```bash
mkdir -p "$HOME/.claude"
ln -s "$REPO/settings.json" "$TARGET"
```

#### 3-B. `linked` — 아무 작업 없음

사용자에게 "이미 리포의 `settings.json` 에 연결되어 있습니다" 라고 안내만 한다.

#### 3-C. `standalone` — 병합

반드시 다음 순서로:

1. **백업**: `cp "$TARGET" "$TARGET.backup.$(date +%Y%m%d-%H%M%S)"`
2. **병합**: `scripts/merge-settings.py` 실행 (아래 병합 규칙 참조)
3. **diff 표시**: 사용자에게 `diff "$TARGET.backup.*" "$TARGET"` 결과를 보여준다
4. **확인 요청**: 사용자가 승인하지 않으면 `cp $TARGET.backup.* $TARGET` 로 롤백

### 4. 스킬 배포

리포의 `skills/*/` 각각에 대해 네 가지 상태로 분류한다:

| 상태 | 판별 | 대응 |
|---|---|---|
| **없음** | 대상 경로에 아무것도 없음 | 심볼릭 링크 생성 |
| **정상 링크** | 이미 리포의 해당 디렉토리로 연결됨 | 아무것도 하지 않음 |
| **끊긴 링크** | 링크이지만 대상이 존재하지 않음 | 삭제 후 재생성 (사용자 확인 불필요) |
| **충돌** | 실제 디렉토리이거나 다른 곳을 가리키는 링크 | **사용자에게 물어본다** (자동 덮어쓰기 금지) |

끊긴 링크를 충돌로 취급하면 안 된다. `[ ! -e "$target" ]` 는 끊긴 링크에 대해 거짓이므로
`-e` 단독 판별은 끊긴 링크를 충돌 분기로 보낸다. 리포 경로가 바뀌면 모든 링크가 한꺼번에
끊기는데, 그때 복구가 막히는 원인이 바로 이 검사다. `-L` 을 함께 봐야 한다.

경로 비교 시 glob 이 붙이는 후행 슬래시를 `${skill_dir%/}` 로 제거한다. 제거하지 않으면
같은 대상인데도 `readlink` 결과가 달라 정상 링크를 충돌로 오판한다.

```bash
for skill_dir in "$REPO"/skills/*/; do
  src="${skill_dir%/}"
  name=$(basename "$src")
  target="$HOME/.claude/skills/$name"

  if [ -L "$target" ] && [ ! -e "$target" ]; then
    rm "$target"; ln -s "$src" "$target"
    echo "repaired: $name (끊긴 링크 재연결)"
  elif [ ! -e "$target" ]; then
    ln -s "$src" "$target"
    echo "linked: $name"
  elif [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    echo "already linked: $name"
  else
    echo "conflict: $name — 사용자 확인 필요"
    # diff -r "$src" "$target" 결과를 사용자에게 보여주고 승인 받기
  fi
done
```

### 5. 상태라인 스크립트

`~/.claude/statusline-command.sh` 도 스킬과 같은 네 상태로 분류한다. 특히 **끊긴 링크**를
반드시 잡아야 한다. `[ ! -L ... ]` 단독 검사는 링크가 존재하기만 하면 통과시키므로,
대상이 사라진 링크를 그대로 방치해 상태라인이 조용히 빈 줄만 출력하게 만든다.

```bash
SL="$HOME/.claude/statusline-command.sh"

if [ -L "$SL" ] && [ ! -e "$SL" ]; then
  rm "$SL"; ln -s "$REPO/statusline-command.sh" "$SL"
  echo "repaired: statusline (끊긴 링크 재연결)"
elif [ ! -e "$SL" ]; then
  ln -s "$REPO/statusline-command.sh" "$SL"
elif [ -L "$SL" ] && [ "$(readlink "$SL")" = "$REPO/statusline-command.sh" ]; then
  echo "already linked: statusline"
else
  cp "$SL" "$SL.backup.$(date +%Y%m%d-%H%M%S)"
  ln -sf "$REPO/statusline-command.sh" "$SL"
fi
```

연결 후 실제로 동작하는지 확인한다:

```bash
echo '{"model":{"display_name":"test"},"workspace":{"current_dir":"'"$PWD"'"}}' | bash "$SL"
```

### 6. 마무리

사용자에게 다음을 안내한다:

- 적용된 카테고리 요약 (설정 병합 / 신규 심볼릭 링크 / 충돌 스킬 수)
- **재시작 필요**: `/hooks` 메뉴를 한 번 열거나 Claude Code 재시작해야 반영
- 백업 파일 위치

---

## 병합 규칙 (Merge Semantics)

`settings.json` 병합은 **필드별로 서로 다른 전략**을 쓴다. 리포가 진실 원천(source of truth)이지만, 머신 고유 설정(특히 `env`)은 보존한다.

### 규칙

| 필드 | 전략 |
|---|---|
| `permissions.allow` / `deny` / `ask` / `additionalDirectories` | **합집합 (union)** — 중복 제거 후 병합, 순서는 리포 우선 |
| `permissions.defaultMode` 등 permissions 스칼라 | 리포 우선 (로컬이 명시되어 있으면 로컬 우선) |
| `env` | **로컬 우선** — 로컬에만 있는 키 보존, 충돌 시 로컬 유지 (API 키 등) |
| `hooks` | 이벤트·matcher 단위 병합. 같은 matcher 는 hook 항목 concat 후 `(type, command \| prompt)` 으로 dedup |
| `enabledPlugins` | 합집합. 같은 키는 리포 우선 |
| `extraKnownMarketplaces` | 합집합. 같은 키는 리포 우선 |
| `statusLine`, `subagentStatusLine` | 리포 우선 (공유 스크립트) |
| 나머지 스칼라 (`model`, `agent`, `theme`, `remoteControlAtStartup` 등) | 리포 우선. 단, 리포에 해당 키가 없으면 로컬 유지 |
| 리포에 없고 로컬에만 있는 필드 | 로컬 보존 |

### 예외 처리

- `statusLine.command` 가 로컬 경로에 의존하는 스크립트(예: `bash /some/custom/path.sh`)를 가리키면, 사용자에게 **물어본다** (자동 덮어쓰지 않음)
- 리포의 `enabledPlugins` 에 해당 머신에 설치되지 않은 플러그인이 있으면, 병합 후 `claude` 가 자동으로 설치 프롬프트를 띄운다 — 스킬은 건드리지 않음

### 구현

`scripts/merge-settings.py` 에 구현되어 있다. 입력은 `repo-path` 와 `local-path`, 출력은 stdout 에 병합된 JSON. 호출 예:

```bash
python3 "$REPO/skills/sync-claude-config/scripts/merge-settings.py" \
  "$REPO/settings.json" "$TARGET" > "$TARGET.merged"
```

---

## 실패 시 롤백

어떤 단계에서든 실패하면:
1. `cp $TARGET.backup.* $TARGET` 로 원상 복구
2. 생성된 심볼릭 링크 중 이번 실행분 제거
3. 사용자에게 실패 이유 보고

## 주의사항 (절대 하지 말 것)

- ✗ 백업 없이 `settings.json` 을 덮어쓰는 행위
- ✗ `env` 블록의 로컬 값 (API 키 등) 을 리포 값으로 덮어쓰는 행위
- ✗ 대상이 이미 심볼릭 링크일 때 추가 조작
- ✗ 사용자 확인 없이 충돌한 스킬 디렉토리 덮어쓰기
