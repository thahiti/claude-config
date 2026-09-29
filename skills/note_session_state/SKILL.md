---
name: note_session_state
description: Use when the user wants to record the current session's state to their vault for later daily/weekly reports or review. Trigger on "세션 기록해줘", "note_session_state", "지금까지 한 거 남겨줘", "세션 상태 남겨줘", "/note_session_state", or any request to log what was worked on in this session.
---

# Note Session State

## Overview

현재 세션에서 무엇을 했는지 vault 에 한 파일로 남기는 스킬.
목적은 세 가지다. 일간 보고 생성, 주간 보고 생성, 나중에 무슨 작업을 했는지
되짚어보기다.

읽는 대상이 사람과 보고서 생성기 둘 다이므로 파일은 두 층으로 나눈다.
집계용 **YAML 프론트매터**와 회고용 **마크다운 본문**이다.

**한 세션은 하루에 한 파일이다.**
같은 세션을 오늘 이미 기록했다면 새 파일을 만들지 않고 그 파일을 갱신한다.

## 절차

1. `session_id` 를 얻는다.
   `echo "$CLAUDE_CODE_SESSION_ID"` 로 얻는다.
2. 오늘 이 세션의 노트가 이미 있는지 찾는다.
   아래 `기존 노트 찾기` 를 따른다.
3. 있으면 `기존 노트 갱신` 대로 그 파일을 고친다.
   없으면 `파일 형식` 대로 새 파일을 만든다.
4. 저장한 전체 경로와 함께 새로 만들었는지 갱신했는지 사용자에게 알린다.

## 기존 노트 찾기

오늘 날짜 접두어(`date '+%Y_%m%d'`)로 시작하는 파일만 대상으로 한다.
어제 시작한 세션이라도 오늘 노트가 없으면 새 파일을 만든다.

```bash
grep -l "^session_id: $CLAUDE_CODE_SESSION_ID$" \
  /mnt/c/Users/randy/vault/randy/sessions/$(date '+%Y_%m%d')_*.md 2>/dev/null
```

- 결과가 있으면 그 파일이 이 세션의 노트다.
- 결과가 없으면 새 파일을 만든다.
  오늘 파일 중 `session_id` 가 없는 노트가 있어도 이 세션 것으로 간주하지 않는다.
  다른 세션이 같은 디렉토리에서 남긴 노트일 수 있기 때문이다.

## 기존 노트 갱신

파일명은 바꾸지 않는다.
파일명의 시각은 처음 기록한 시점이고, 최신 종료 시각은 프론트매터 `ended` 가 담당한다.

| 대상 | 갱신 방법 |
|---|---|
| `started`, `directory`, `project`, `session_id` | 그대로 둔다 |
| `branch` | 현재 값으로 바꾼다 |
| `ended`, `duration`, `status` | 현재 시점 기준으로 다시 쓴다 |
| `tags` | 기존 태그를 유지하고 새 태그만 덧붙인다 |
| `요약` | 세션 전체를 아우르도록 다시 쓴다 |
| `한 일`, `변경 파일 / 커밋`, `이슈 / 배운 점` | 기존 항목을 유지하고 이전 기록 이후에 생긴 항목만 덧붙인다. `없음` 자리표시는 실제 항목이 생기면 지운다 |
| `다음 할 일` | 현재 시점의 할 일로 통째로 바꾼다. 끝낸 항목은 `한 일` 에 반영돼 있는지 확인한다. 같은 내용을 두 줄로 중복해 적지 않는다 |

기존 항목을 지우거나 고쳐 쓰지 않는다.
이전 기록 시점에 사실이었던 내용은 지금도 기록으로 남아야 한다.
예외는 두 가지다.

- `없음` 같은 자리표시 항목은 실제 항목이 생기면 지운다.
- 상태가 바뀐 항목은 항목 뒤에 바뀐 내용을 덧붙인다.
  예: `parser.py (미커밋)` 을 `parser.py (미커밋, 이후 a1b2c3d 에 포함)` 으로 고친다.

## 저장 위치와 파일명

- 디렉토리: `/mnt/c/Users/randy/vault/randy/sessions/`
  (Windows 의 `c:\Users\randy\vault\randy\sessions\` 를 WSL 에서 매핑한 경로)
  없으면 `mkdir -p` 로 만든다.
- 파일명: `년도_MMDD_HHMM_세션명.md`
  - 예: `2026_0831_1430_note-session-state.md`
  - 시각은 24시간제. 세션명의 공백은 하이픈으로 바꾼다.
  - 시각은 처음 기록하는 시점 기준이다. `date '+%Y %m%d %H%M'` 로 얻는다.
    갱신할 때는 파일명을 바꾸지 않는다.

## 파일 형식

```markdown
---
title: note_session_state 스킬 만들기
session_id: ead552ae-e17e-4314-9eac-62eddbb036da
directory: /home/randy/workspace/test_ragas
project: test_ragas
branch: null
started: 2026-08-31 14:30
ended: 2026-08-31 15:10
duration: 40m
status: 완료
tags: [스킬개발, 브레인스토밍, 문서작업]
---

## 요약

세션 상태를 vault 에 남기는 note_session_state 스킬을 설계하고 만들었다.

## 한 일

- 기록할 내용과 파일 형식을 브레인스토밍으로 확정
- 스킬 파일 작성

## 변경 파일 / 커밋

- (git 저장소가 아니라 생략)

## 다음 할 일

- 실제 세션 몇 개 기록해보고 형식 다듬기

## 이슈 / 배운 점

- WSL 에서 Windows vault 경로는 /mnt/c 로 매핑해서 써야 함
```

## 필드 채우는 법

| 필드 | 채우는 법 |
|---|---|
| `title` | 세션의 핵심 작업을 한 구절로. 파일명의 세션명도 여기서 따온다 |
| `session_id` | `echo "$CLAUDE_CODE_SESSION_ID"` 로 얻는다. 기존 노트를 찾는 키다 |
| `directory` | 작업 디렉토리 전체 경로. `pwd` 로 얻는다 |
| `project` | 디렉토리 basename |
| `branch` | git 저장소면 `git branch --show-current`, 아니면 `null` |
| `started` | 대화 첫 메시지 시각을 추정해 기록. 정확하지 않으면 그대로 추정값을 쓴다 |
| `ended` | 기록하는 시점. `date` 로 얻는다 |
| `duration` | `ended - started` 를 사람이 읽는 단위로 (예: `40m`, `2h 10m`) |
| `status` | `완료` / `진행중` / `중단` 중 세션 상태에 맞게 |
| `tags` | 세션 내용을 보고 자유 태그를 붙인다. 주간 보고에서 묶는 기준이 된다 |

## 작성 규칙

- **git 정보는 best-effort 다.** `git rev-parse --is-inside-work-tree` 로 저장소인지
  먼저 확인한다. 저장소면 `branch`, 이 세션에서 만든 커밋, 변경 파일을
  `변경 파일 / 커밋` 섹션에 채운다. 저장소가 아니면 `branch: null` 로 두고
  섹션에는 생략 사유를 한 줄 적는다.
- **본문은 보고서에 그대로 옮길 수 있게 쓴다.** `요약` 은 한두 문장으로,
  보고서 한 줄에 바로 들어갈 수준으로 압축한다.
- **하지 않은 일을 추론해 채우지 않는다.** 세션에서 실제로 한 것만 적는다.
  다음 할 일이 없으면 없다고 적는다.
- **줄바꿈은 사용자 규칙을 따른다.** 마크다운은 문장 단위로 줄바꿈한다.
- 파일을 다 쓰면 저장한 전체 경로를 사용자에게 알린다.

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| Windows 경로에 그대로 저장 시도 | WSL 이라 `/mnt/c/...` 로 매핑해야 파일이 실제로 써진다 |
| 프론트매터 없이 본문만 작성 | 일간, 주간 보고 집계가 안 된다. 프론트매터가 집계 층이다 |
| tags 생략 | 주간 보고에서 묶을 기준이 사라진다 |
| 요약을 장황하게 작성 | 보고서에 바로 못 옮긴다. 한두 문장으로 압축한다 |
| duration 을 정확한 값처럼 단정 | started 는 추정값이다. 추정임을 감안해 적는다 |
| 오늘 노트가 있는데 새 파일 생성 | 같은 세션이 하루에 여러 파일로 쪼개져 보고 집계가 중복된다. 먼저 `session_id` 로 찾는다 |
| `session_id` 생략 | 다음 기록 때 기존 노트를 못 찾아 새 파일이 생긴다 |
| 갱신하면서 파일명 시각 변경 | 파일명이 바뀌면 vault 내 링크가 깨진다. `ended` 만 고친다 |
| 갱신하면서 기존 항목 삭제 | 이전 기록 시점의 사실이 사라진다. 덧붙이기만 한다 |
