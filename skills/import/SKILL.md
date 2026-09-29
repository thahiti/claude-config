---
name: import
description: Use when the user wants to package today's backups into an import/반입 archive — investigates directories backed up today under 바탕화면/share/<오늘날짜>_*, writes a manifest .md summarizing the work, and zips full repository snapshots that have not been imported yet today into share/<오늘날짜>_<name>.zip. Trigger on "import", "반입", "반입 패키지", "오늘 백업 압축해줘", "백업한 거 묶어서 zip 만들어줘", or any request to bundle today's backup directories for external import. Pairs with the backup skill.
---

# Import

`backup` 스킬이 오늘 날짜로 만든 `바탕화면/share/<오늘날짜>_<시분>_<디렉토리명>` 디렉토리들을 조사해서, 하나의 반입(import) zip 패키지로 묶는 스킬.
저장소는 항상 스냅샷 전체(추적 파일 전체와 `.git`)로 넣는다.
오늘 이미 반입한 저장소만 빼고, 날짜가 바뀌면 반입 기록은 처음부터 다시 시작한다.

결과물:
- **`share/<날짜>_<name>.zip`** — 반입 대상 + 아래 `.md` 를 하나로 압축
- **`share/<name>.md`** — 반입 설명서 (zip 안에도 `<name>.md` 로 포함됨)

`<name>` 은 소스 디렉토리명 기반 **20글자 이하 영문** 이름이고, 이 이름이 곧 제목의 **agent code** 로도 쓰인다.

## 반입 대상

- 저장소는 폴더명이 아니라 루트 커밋으로 구분한다.
  같은 저장소의 백업이 오늘 여러 개면 HEAD 커밋 시각이 가장 늦은 백업 하나만 쓴다.
- 반입하는 저장소는 **항상 추적 파일 전체와 `.git` 전체**를 넣는다.
  바뀐 파일만 넣는 변경분 반입은 하지 않는다.
- 저장소마다 오늘 반입한 HEAD 를 `share/.import-state` 에 기록한다.
  - 오늘 같은 HEAD 로 이미 반입한 저장소는 뺀다.
  - 오늘 반입한 뒤 새 커밋이 생긴 저장소는 스냅샷 전체를 다시 넣는다.
  - 반입 시각이 오늘이 아닌 기록은 무시하고, 다음 package 때 파일에서 지운다.
- git 저장소 밖의 파일은 반입 기록의 기준이 없어서 매번 그대로 넣는다.

## 워크플로우

### 1. 반입 대상 조사

```bash
bash <이 스킬 경로>/scripts/import.sh discover
```

출력에서 다음을 읽는다:
- `DATE` — 오늘 날짜 (제목에 사용)
- `SHARE` — share 폴더 경로 (`.md` 를 여기에 쓴다)
- `SUGGESTED_SLUG` — 첫 디렉토리명 기반 추천 이름
- `DIR\t<경로>` — 오늘 백업된 디렉토리들
- `REPO\t<루트커밋>\t<경로>\t<오늘 반입 또는 ->\t<HEAD>\t<파일 수>` — 이번에 스냅샷 전체로 반입할 저장소. `<경로>` 는 `SHARE` 기준이고, `-` 는 오늘 첫 반입이다
- `SKIP\t<경로>\t<HEAD>` — 오늘 같은 HEAD 로 이미 반입해서 빠지는 저장소

오늘 백업이 하나도 없거나 오늘 이미 반입한 것 외에 새로 반입할 내용이 없으면 스크립트가 종료 코드 1로 알려준다. 이땐 사용자에게 알리고 멈춘다.

### 2. 이름(agent code) 정하기

`SUGGESTED_SLUG` 을 기본으로 쓴다. 다만 **영문으로 시작, 영문/숫자만, 20글자 이하** 규칙을 지켜야 한다. 추천 slug 이 비어 있거나(소스 디렉토리명이 한글 등) 부적절하면, 소스 디렉토리명의 의미를 살려 20글자 이하 영문 이름을 직접 만든다. 예: `데이터현대화` → `datamod`, `my_long_project-name` → `mylongprojectname`.

### 3. 설명서 `.md` 작성

`SHARE/<name>.md` 를 아래 형식으로 쓴다. 백업 디렉토리들의 **실제 내용을 살펴보고** 무엇이 반입되는지 구체적으로 채운다 — 이 파일이 반입 대상이 무엇인지 알려주는 유일한 설명서다.

**작업 요약은 커밋을 입력으로 쓴다.** `REPO` 줄마다 커밋을 조회해서:

```bash
# 오늘 반입이 있으면 그 이후 커밋
git -C <SHARE>/<경로> log --format='%h %s' <오늘 반입>..<HEAD>
# 오늘 첫 반입(-)이면 오늘 커밋
git -C <SHARE>/<경로> log --since="<DATE> 00:00" --format='%h %s'
```

커밋 메시지들을 근거로 무슨 작업이 이루어졌는지 요약해 `오늘 작업 요약` 섹션에 쓴다. `SKIP` 저장소와 git 저장소가 아닌 디렉토리는 요약에서 생략한다.

`반입 내용` 은 저장소마다 스냅샷 전체라는 점과 HEAD, 추적 파일 수를 적고 구성을 설명한다.
받는 쪽은 앞선 반입본 위에 덧풀지 않고 이 스냅샷으로 저장소를 통째로 바꾼다.

```markdown
# 외부 파일 반입 - Agent 중심 데이터 현대화 - <DATE> - <name> - 이상욱

## 반입 개요
- 반입일: <DATE>
- Agent code: <name>
- 담당: 이상욱

## 오늘 작업 요약
<저장소별로 커밋 로그를 근거로 작업 내용을 요약>

## 반입 내용
<저장소별로 스냅샷 전체(HEAD, 추적 파일 수, .git 포함)와 어떤 파일/데이터가 들어 있는지 구체적으로 설명>

## 포함 항목
- <디렉토리명>: <한 줄 설명>
- ...
```

제목 라인의 순서는 반드시 `외부 파일 반입 - Agent 중심 데이터 현대화 - <날짜> - <agent code> - 이상욱` 로 고정한다. `<name>` 과 agent code 는 같은 값이다.

### 4. 압축

```bash
bash <이 스킬 경로>/scripts/import.sh package --name <name> --md "<SHARE>/<name>.md"
```

스크립트가 하는 일:
- `--name` 규칙(영문 시작, 20글자 이하) 검증
- `.md` 를 `share/<name>.md` 로 배치
- 반입 대상 + `<name>.md` 를 `share/<날짜>_<name>.zip` 으로 압축.
  같은 이름의 zip 이 이미 있으면 덮어쓰지 않고 `_2`, `_3` 을 붙인다
- zip 을 만든 뒤 `share/.import-state` 에 오늘 반입한 HEAD 를 기록하고 전날 기록을 지운다

완료 후 스크립트가 출력한 zip 경로와 저장소별 반입 내역을 사용자에게 알려준다.

## 주의

- `<name>.md` 는 zip 안에 반드시 포함되어야 한다 — package 커맨드가 자동으로 넣으므로 3단계에서 만든 파일 경로를 `--md` 로 정확히 넘기면 된다.
- 여러 디렉토리가 있어도 zip 은 하나만 만든다.
- discover 와 package 사이에 백업을 새로 만들지 않는다. package 가 반입 대상을 다시 계산하므로 설명서와 zip 이 어긋난다.
- 오늘 만든 zip 을 다시 만들어야 하면 `.import-state` 에서 해당 저장소의 오늘 기록을 지운 뒤 다시 실행한다.
