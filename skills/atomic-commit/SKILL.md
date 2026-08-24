---
name: atomic-commit
description: Use when committing code, when the working tree has more than one logical change, when a commit message needs a Conventional Commits type or scope, or when another skill delegates committing to atomic-commit
---

# Atomic Commit

## Overview

하나의 커밋은 하나의 논리적 변경만 담는다. 커밋을 설명할 때 "and" 가 필요하면 그 커밋은
둘로 나뉘어야 한다.

기준은 diff 크기가 아니라 되돌릴 수 있는 단위다. 이 커밋 하나만 revert 했을 때
저장소가 일관된 상태로 남는가를 묻는다. 남지 않으면 경계를 잘못 그은 것이다.

## 커밋 단위 판단

먼저 `git status --porcelain` 과 `git diff` 로 변경 전체를 확인한 다음, 아래 표로 쪼갠다.

| 변경 성격 | 커밋 단위 |
|---|---|
| 새 함수나 메서드 + 그 테스트 | 1 커밋 (구현과 테스트를 나누지 않는다) |
| 버그 수정 1건 | 1 커밋 |
| 리네이밍 | 1 커밋 (동작 변경과 절대 섞지 않는다) |
| 포매팅, 공백 정리 | 1 커밋 (로직 변경과 절대 섞지 않는다) |
| 의존성 추가나 업데이트 | 1 커밋 |
| 설정 변경 | 1 커밋 |

리네이밍과 포매팅을 로직 변경과 섞으면 안 되는 이유는 리뷰어가 diff 에서 의미 있는
한 줄을 찾을 수 없게 되기 때문이다. 기계적 변경은 따로 떼어 통째로 넘기게 만든다.

이상적인 diff 는 50~200줄이다. 400줄을 넘으면 분리를 검토한다. 다만 줄 수는 신호일 뿐
기준이 아니다. 자동 생성 파일이나 대량 이동은 400줄이 넘어도 한 논리 단위다.

모든 커밋은 빌드와 테스트가 통과하는 상태를 유지한다. 중간 커밋이 깨진 상태면
bisect 가 무의미해지고 revert 도 안전하지 않다.

## 커밋 타이밍

- 논리적 작업 단위를 하나 끝냈을 때
- 테스트가 통과한 직후 (Green 이면 Commit)
- 작업 방향을 바꾸기 전에 (기능 개발에서 버그 수정으로 넘어가는 시점 등)
- 위험한 변경을 시도하기 전에 (안정 상태를 먼저 남긴다)

## 메시지 형식

Conventional Commits 를 따른다.

```
<type>(<scope>): <description>

[본문]

[footer]
```

| Type | 용도 |
|---|---|
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `test` | 테스트 추가나 수정 |
| `refactor` | 기능 변경 없는 구조 개선 |
| `docs` | 문서만 변경 |
| `style` | 포매팅, 공백 등 로직 변경 없음 |
| `chore` | 빌드, 설정, 도구 등 유지보수 |
| `perf` | 성능 개선 |

### 규칙

- 제목은 영어, 최대 50자, 소문자로 시작, 마침표 없음, 명령형을 쓴다. `add` 이고 `added` 가 아니다.
- 본문은 한글로 쓰고 72자에서 줄바꿈한다.
- 본문에는 **why** 를 적는다. how 는 diff 에 이미 보인다. 무엇을 바꿨는지 나열하는 본문은
  diff 를 문장으로 옮긴 것에 지나지 않으므로, 왜 그 선택을 했는지와 어떤 대안을 버렸는지를 적는다.
- 이슈 참조는 footer 에 `Closes #123`, `Refs #456` 형태로 단다.
- **Claude 나 Anthropic 관련 trailer 와 서명을 넣지 않는다.** `Co-Authored-By: Claude ...`,
  `Claude-Session: ...`, `Generated with Claude Code` 전부 해당하고, PR 본문에도 넣지 않는다.

### 예시

```
# GOOD
feat(layout): add BlockClusterer with adjacent bbox merging
test(classifier): add unit tests for HeadingRule font height thresholds
fix(sync): repair dangling symlinks instead of flagging conflict

# BAD
update code                              제목이 무엇을 바꿨는지 말하지 않는다
fix bug and refactor utils and add tests  and 가 셋이면 커밋도 셋이다
feat(auth): Added retry logic.            대문자 시작, 과거형, 마침표
```

## 절대 커밋하지 않을 것

- 시크릿 (`.env`, API 키, 인증 정보)
- 빌드 산출물 (`.build/`, `DerivedData/`)
- 생성된 파일 (`node_modules/`, `.pyc`)

스테이징 전에 `git diff --cached` 로 한 번 훑어 이 셋이 섞이지 않았는지 확인한다.

## 여러 변경이 섞여 있을 때

한 파일 안에 서로 다른 논리 변경이 섞였으면 파일 단위 `git add` 로는 나눌 수 없다.
`git add -p` 로 hunk 단위로 골라 담는다. hunk 하나에도 두 변경이 붙어 있으면
`s` 로 쪼개고, 그래도 안 나뉘면 `e` 로 직접 편집한다.

커밋을 나눈 뒤에는 각 커밋에서 테스트가 통과하는지 확인한다. 앞 커밋만 적용한 상태가
깨진다면 순서를 바꾸거나 경계를 다시 그어야 한다.

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| 작업이 다 끝난 뒤 한 번에 커밋 | 논리 단위가 이미 섞여 사후 분리가 어렵다. 단위가 끝날 때마다 커밋한다 |
| 리네이밍과 로직 수정을 한 커밋에 | diff 전체가 바뀐 것처럼 보여 실제 변경을 찾을 수 없다 |
| 본문에 변경 내역을 나열 | diff 가 이미 말하는 내용이다. why 를 적는다 |
| 테스트를 별도 커밋으로 분리 | 구현만 있는 중간 커밋이 검증되지 않은 상태로 남는다 |
| "WIP" 커밋을 그대로 남김 | 히스토리가 깨진 상태를 포함한다. 머지 전에 squash 한다 |
