---
name: claude-config-doctor
description: Use when Claude Code skills or the statusline stop working, after moving or renaming the claude-config repo, before committing changes to it, or when the user invokes /claude-config-doctor to check config integrity
---

# Claude Config Doctor

## Overview

`~/claude-config` 리포와 `~/.claude` 사이가 어긋났는지 점검한다. 이 배포 방식은 심볼릭 링크에
의존하므로 리포를 옮기거나 이름을 바꾸면 링크가 한꺼번에 끊기는데, 끊긴 링크는 에러를 내지 않고
그냥 스킬이 목록에서 사라지고 상태라인이 빈 줄을 출력하는 형태로 나타난다. 조용히 고장 나기
때문에 주기적으로 확인해야 한다.

## 실행

```bash
python3 ~/claude-config/skills/claude-config-doctor/scripts/doctor.py
```

리포 경로는 인자, 현재 git 원격, `~/claude-config` 순으로 찾는다. 다른 위치면 인자로 넘긴다.

종료 코드는 문제가 있으면 1, 리포를 못 찾으면 2, 정상이면 0이다.

## 점검 항목

| 항목 | 무엇을 잡는가 |
|---|---|
| 심볼릭 링크 무결성 | 끊긴 링크, 미배포, 다른 대상을 가리키는 링크, 링크가 아닌 독립 파일 |
| settings.json 드리프트 | 리포와 `~/.claude` 의 키별 값 불일치, 한쪽에만 있는 키 |
| 유령 스킬 참조 | 문서가 이름으로 참조하지만 실제로 없는 스킬 |
| 상태라인 실행 | 빈 출력, 20초 초과, 이스케이프 문자가 남은 출력 |
| 환경변수 | 스킬이 전제하는 토큰이 실제로 설정돼 있는지 |

## 결과 해석

- **FAIL** 은 지금 동작하지 않는 상태다. 링크 관련 FAIL 은 `/sync-claude-config` 로 복구된다.
- **WARN** 은 의도적일 수 있다. 독립 파일 경고는 `settings.json` 처럼 병합 배포하는 대상이면
  정상이고, 환경변수 경고는 그 스킬을 안 쓰는 머신이면 넘어가도 된다.
- 드리프트 FAIL 이 "리포에만 있음" 이면 로컬에 아직 적용되지 않은 것이고,
  WARN 이 "로컬에만 있음" 이면 로컬에서 바꾼 값을 리포로 역반영할지 판단해야 한다.
  `settings.json` 은 링크가 아니라 병합 배포 대상이라 양방향으로 갈라질 수 있다.

## 언제 돌리는가

- 리포 경로나 디렉토리 구조를 바꾼 직후
- 스킬이 `/` 목록에서 사라졌을 때
- 상태라인이 비어 보일 때
- 리포 변경을 커밋하기 전
- 새 머신에서 `/sync-claude-config` 를 돌린 뒤 검증용으로

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| 링크가 있으니 정상이라고 판단 | 끊긴 링크도 `ls` 에는 보인다. 대상 존재 여부까지 봐야 한다 |
| 드리프트 경고를 무조건 리포 값으로 덮음 | 로컬이 더 최신인 경우가 있다. 어느 쪽이 나중인지 먼저 본다 |
| 유령 스킬 참조를 문서 오타로 처리 | 참조된 스킬을 실제로 만들거나 참조를 지워야 한다. 방치하면 실행 시점에 실패한다 |
