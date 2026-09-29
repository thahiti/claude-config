---
name: backup
description: Use when the user wants to back up the current directory to the desktop — copies committed git state (HEAD) into 바탕화면/share/<날짜>_<시분>_<디렉토리명>, recursing into any nested .git repos while preserving structure, or copies all files if there is no git repo. If a repo is not on main, offers to merge into main (--no-ff) first. Trigger on "백업", "backup", "이 디렉토리 백업해줘", "지금 폴더 백업", or any request to snapshot the current working directory to the desktop share folder.
---

# Backup

현재 디렉토리를 바탕화면의 `share/<날짜>_<시분>_<디렉토리명>` 폴더로 백업하는 스킬.
실행할 때마다 새 폴더를 만들고 기존 백업은 지우지 않는다.

- **git 저장소인 경우**: `.git` 을 복사한 뒤 커밋된 상태(HEAD)를 복원한다. 워킹트리의 커밋 안 된 로컬 수정은 백업에 담기지 않으므로, 로컬 수정이 있으면 경고하고 사용자 확인을 받는다.
- **하위 디렉토리에 `.git` 이 있는 경우**: 재귀적으로 모든 git 저장소를 찾아 각각 커밋 상태로 복원한다. 별도 폴더로 분리하지 않고 원래 구조를 보존한 채 같은 상대경로에 백업하며, git 이 아닌 파일은 그대로 복사한다.
- **git 저장소가 아닌 경우**: 현재 디렉토리의 모든 파일(숨김 파일 포함)을 그대로 복사한다.

대상 경로 예시: 2026-08-27 14시 05분에 현재 디렉토리 `myproject` 를 백업하면
`바탕화면/share/2026-08-27_1405_myproject`.

## main 브랜치 게이트

각 git 저장소가 `main` 에 체크아웃돼 있는지 확인한다.

- `main` 이 아니면 스크립트가 경고하고 종료 코드 10 으로 빠진다. 이때 사용자에게
  **main 에 머지하고 진행할지** 문의한다.
- 승인하면 `--confirm` 으로 재실행한다. 해당 저장소는 `git checkout main` 후
  `git merge --no-ff <브랜치>` 로 머지한 뒤 백업한다. 머지는 소스 저장소에서 실제로 일어난다.
- 사용자가 머지를 원치 않으면 `--no-merge` 로 재실행한다. 머지 없이 현재 커밋 상태 그대로 백업한다.

머지가 필요한 저장소에 커밋 안 된 로컬 수정이 있으면 안전하게 머지할 수 없으므로
**머지 불가로 분류하고 멈춘다.** 사용자가 커밋/스태시로 정리한 뒤 재실행하거나,
`--no-merge` 로 현재 상태를 백업하도록 안내한다. 로컬 `main` 브랜치가 없거나 detached HEAD
상태인 저장소도 같은 이유로 머지 불가다.

## 실행 방법

핵심 로직은 `scripts/backup.sh` 에 있다. **현재 백업하려는 디렉토리에서** 실행한다.

```bash
bash <이 스킬 경로>/scripts/backup.sh
```

스크립트는 다음을 자동으로 처리한다:

- 바탕화면 경로 해석 (WSL 윈도우 Desktop 우선)
- 하위 `.git` 재귀 탐색 후 저장소 분류 (머지 대상 / 머지 불가 / main 이지만 dirty)
- 구조를 보존한 백업 (비-저장소 파일은 `tar` 로 복사, 각 저장소는 `.git` 복사 후 `reset --hard HEAD`)
- 로컬 수정 / main 아님 감지
- 같은 분에 재실행해 대상 폴더가 이미 있으면 기존 폴더를 지우지 않고 오류로 멈춤

## 확인 게이트 다루기

확인이 필요한 상황(main 아닌 저장소, 로컬 수정 존재)에서는
스크립트가 **경고만 출력하고 종료 코드 10** 으로 빠진다. 이때는:

1. 스크립트가 출력한 경고 내용(머지 대상 목록, 머지 불가 사유, dirty 저장소 등)을 사용자에게 그대로 전달한다.
2. 어떻게 진행할지 사용자에게 확인받는다.
3. 선택에 따라 플래그를 붙여 다시 실행한다.

```bash
# main 아닌 저장소를 main 에 --no-ff 머지 후 백업
bash <이 스킬 경로>/scripts/backup.sh --confirm

# 머지하지 않고 현재 커밋 상태로 백업
bash <이 스킬 경로>/scripts/backup.sh --no-merge
```

경고 상황이 없으면(모든 저장소가 main 이고 clean) 확인 없이 한 번에 백업이 끝난다.

## 종료 코드

| 코드 | 의미 |
|---|---|
| 0 | 성공 |
| 10 | 확인/조치 필요 — 경고를 사용자에게 전달하고 승인받아 `--confirm` 또는 `--no-merge` 로 재실행 |
| 1 | 오류 (바탕화면 경로 못 찾음, 같은 분의 대상 폴더가 이미 존재, 머지 충돌, 잘못된 인자 등) |

백업 완료 후 스크립트가 출력한 대상 경로를 사용자에게 알려준다.
