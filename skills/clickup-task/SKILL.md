---
name: clickup-task
description: Use when the user invokes /clickup-task to create a ClickUp task — interactively gather the category list, task title, description, dates, priority, time estimate, and assignee, then create it via the ClickUp API and add it to the current sprint
---
# ClickUp Task Creation Skill

## Overview

ClickUp API를 사용하여 태스크를 생성하는 Claude Code 스킬.
사용자에게 필요한 필드를 **인터랙티브하게 질문**하면서 구조화된 태스크를
ClickUp 리스트에 생성한다.

## Prerequisites

| 환경변수 | 값 | 발급 방법 |
|---|---|---|
| `CLICKUP_API_TOKEN` | Personal API Token (`pk_` 접두사) | `docs/tokens.md` 참조 |
| `CLICKUP_SPACE_ID` | 태스크를 만들 Space 의 ID | `docs/tokens.md` 참조 |

두 값이 모두 있어야 실행된다. 하나라도 비어 있으면 첫 API 호출이 401 또는 404 로
실패하므로, 시작 전에 확인하고 없으면 발급 방법을 안내한 뒤 중단한다.

```bash
: "${CLICKUP_API_TOKEN:?docs/tokens.md 를 보고 발급해 셸 프로필에 등록하세요}"
: "${CLICKUP_SPACE_ID:?docs/tokens.md 를 보고 Space ID 를 확인해 등록하세요}"
```

태스크를 만들 List 는 Space 안의 카테고리 중에서 **사용자에게 질문**해 결정한다.

## Interactive Workflow (핵심)

스킬이 실행되면 아래 순서로 필드를 채운다. **기본값이 있는 항목은 기본값을
적용하고, "물어보기"로 표시된 항목은 사용자에게 질문한다.** 한 번에 모든 질문을
던지기보다, 추출 가능한 값은 먼저 채워서 사용자에게 제시하고 빠진 값만 묻는다.

| 항목 | 처리 방식 | 기본값 / 동작 |
|------|-----------|---------------|
| **카테고리 (생성 List)** | **물어보기** | 8개 카테고리 중 하나를 질문 ([Category & Current Sprint](#category--current-sprint)). 이 List가 태스크의 home List가 된다 |
| **제목 (name)** | 추출 또는 붙여넣기 | 사용자의 설명/붙여넣은 내용에서 적절히 추출. `[카테고리] 작업 내용` 형식으로 정리 |
| **내용 (markdown_description)** | 추출 또는 붙여넣기 | 사용자의 설명에서 [Task Description Template](#task-description-template)에 맞춰 구성. 붙여넣은 내용이 있으면 그대로 활용 |
| **start date** | 기본값 | **오늘** (`start_date_time: false`) |
| **due date** | 물어보기 | 사용자에게 마감일을 질문. 답이 없으면 비워둠 |
| **priority** | 기본값 | **Normal (3)**. 사용자가 명시하면 변경 |
| **time estimate** | 물어보기 | 사용자에게 예상 소요시간을 질문 ([Time Estimate Guidelines](#time-estimate-guidelines) 참고). 답이 없으면 비워둠 |
| **assignee** | 기본값 + 자동 조회 | **randy@ahha.ai**. 아래 [Assignee Resolution](#assignee-resolution)으로 user ID를 조회해 사용 |
| **현재 스프린트** | **항상 포함** | 생성 후 현재 스프린트 List에 추가 ([Category & Current Sprint](#category--current-sprint)). 별도 질문 없음 |

### 진행 절차

1. **카테고리**를 사용자에게 질문한다 (8개 중 하나).
2. 사용자의 설명이나 붙여넣은 텍스트에서 **제목**과 **내용**을 추출한다.
3. **due date**와 **time estimate**를 사용자에게 질문한다 (한 번에 묶어서 물어도 됨).
4. start date(오늘), priority(Normal), assignee(randy@ahha.ai)는 기본값으로 채운다.
5. 구성된 태스크 요약을 보여주고, [Assignee Resolution](#assignee-resolution)으로
   assignee user ID를 조회한 뒤 선택한 카테고리 List에 [Create Task](#example-curl) API로 생성한다.
6. **항상** 현재 스프린트 List를 동적으로 계산해 생성된 태스크를 거기에도 추가한다.
7. 생성된 태스크 ID와 URL을 반환한다.

### Assignee Resolution

`assignees` 필드는 숫자 user ID 배열이 필요하다. 이메일(`randy@ahha.ai`)을
List 멤버 조회 API로 user ID로 변환한다.

```bash
# List 멤버 중 randy@ahha.ai 의 user id 조회
curl -s "https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/member" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; m=json.load(sys.stdin)['members']; print(next(u['id'] for u in m if u['email']=='randy@ahha.ai'))"
```

조회된 ID를 `assignees: [<id>]`로 사용한다. 이메일이 멤버 목록에 없으면 사용자에게 알린다.

### Date 계산 (오늘 start date)

`start_date`는 Unix timestamp(밀리초)다. 오늘 자정 기준 값:

```bash
# macOS: 오늘 00:00:00 의 밀리초 timestamp
echo "$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date +%Y-%m-%d) 00:00:00" +%s)000"
```

due date도 동일하게 사용자가 지정한 날짜를 밀리초 timestamp로 변환한다.

## Category & Current Sprint

태스크는 **카테고리 List**에 생성하고, **항상 현재 스프린트 List에도 추가**한다
(ClickUp의 Tasks in Multiple Lists 기능). 카테고리 List가 home List가 되고,
현재 스프린트는 추가 location이 된다.

### 카테고리 List (Space 직속, folderless)

카테고리는 Space 에서 조회한다. 목록을 문서에 고정하지 않는 이유는 두 가지다.
ClickUp 에서 List 를 추가하거나 이름을 바꾸면 고정 표가 바로 낡고, 개인 워크스페이스
구조가 공개 리포에 남기 때문이다.

```bash
curl -s "https://api.clickup.com/api/v2/space/${CLICKUP_SPACE_ID}/list?archived=false" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; [print(f\"{l['id']}\t{l['name']}\") for l in json.load(sys.stdin)['lists']]"
```

조회한 이름을 사용자에게 보여주고 하나를 고르게 한 뒤, 그 List ID 를 `LIST_ID` 로 쓴다.
조회 결과가 비어 있으면 `CLICKUP_SPACE_ID` 가 잘못된 것이므로 값을 확인하도록 안내한다.

### 현재 스프린트 (동적 계산)

스프린트 Folder 안의 List 중 **오늘이 start_date ~ due_date 범위에 드는 것**이
현재 스프린트다. 스프린트는 2주마다 바뀌므로 매번 동적으로 계산한다.

Folder 도 Space 에서 찾는다. 이름에 `sprint` 가 들어가는 Folder 를 쓰고,
여러 개면 사용자에게 묻는다.

```bash
SPRINT_FOLDER="$(curl -s "https://api.clickup.com/api/v2/space/${CLICKUP_SPACE_ID}/folder?archived=false" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; print(next(f['id'] for f in json.load(sys.stdin)['folders'] if 'sprint' in f['name'].lower()))")"

NOW="$(date +%s)000"
SPRINT_LIST_ID="$(curl -s "https://api.clickup.com/api/v2/folder/${SPRINT_FOLDER}/list?archived=false" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; now=int('${NOW}'); d=json.load(sys.stdin); print(next(l['id'] for l in d['lists'] if l.get('start_date') and l.get('due_date') and int(l['start_date'])<=now<=int(l['due_date'])))")"
echo "현재 스프린트 List: ${SPRINT_LIST_ID}"
```

현재 날짜에 해당하는 스프린트가 없으면 `StopIteration` 이 난다. 스프린트가 아직
만들어지지 않았다는 뜻이므로, 태스크는 카테고리 List 에만 만들고 스프린트 추가는 건너뛴다.

### 스프린트에 태스크 추가

카테고리 List에 태스크를 생성한 뒤, 반환된 `task_id`를 현재 스프린트 List에 추가한다:

```bash
curl -s -X POST "https://api.clickup.com/api/v2/list/${SPRINT_LIST_ID}/task/${TASK_ID}" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" -H "Content-Type: application/json" -d '{}'
```

> 동작 전제: 해당 Space에 **Tasks in Multiple Lists** ClickApp이 활성화돼 있어야 한다.
> 비활성 상태면 이 호출이 실패하므로, 카테고리 List 생성까지만 하고 스프린트 추가는 건너뛴다.

## API Reference

```
POST https://api.clickup.com/api/v2/list/{list_id}/task
Authorization: {CLICKUP_API_TOKEN}
Content-Type: application/json
```

## Task Structure

태스크 생성 시 아래 필드를 구성한다.

### 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | string | 태스크 제목. `[카테고리] 구체적 작업 내용` 형식 |

### 권장 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `markdown_description` | string | 마크다운 형식의 상세 설명 |
| `status` | string | 리스트에 존재하는 상태값 (예: `to do`, `in progress`) |
| `priority` | integer | 1=Urgent, 2=High, 3=Normal, 4=Low |
| `start_date` | integer | Unix timestamp (밀리초). 기본값 오늘 |
| `start_date_time` | boolean | 시간 포함 여부 (날짜만이면 `false`) |
| `due_date` | integer | Unix timestamp (밀리초) |
| `due_date_time` | boolean | 시간 포함 여부 |
| `time_estimate` | integer | 예상 소요시간 (밀리초) |
| `assignees` | int[] | 담당자 user ID 배열 |
| `tags` | string[] | 태그 배열 |
| `parent` | string | 부모 태스크 ID (서브태스크 생성 시) |

## Task Description Template

`markdown_description`에 들어갈 내용을 아래 템플릿으로 구성한다.

```markdown
## 목적
- 이 태스크가 필요한 이유와 비즈니스/기술적 배경

## 작업 내용
- [ ] 구체적인 작업 항목 1
- [ ] 구체적인 작업 항목 2
- [ ] 구체적인 작업 항목 3

## 기술 스펙
- **영향 범위**: 변경되는 파일/모듈/서비스
- **기술 스택**: 관련 기술 (예: FastAPI, React, PostgreSQL)
- **의존성**: 선행 작업이나 외부 의존성

## 완료 조건 (Definition of Done)
- [ ] 기능 구현 완료
- [ ] 단위 테스트 작성 및 통과
- [ ] 코드 리뷰 완료
- [ ] 문서 업데이트 (해당 시)

## 참고 자료
- 관련 문서, PR, 이슈 링크
```

## Naming Convention

태스크 이름은 아래 카테고리 접두사를 사용한다:

| 접두사 | 용도 | 예시 |
|--------|------|------|
| `[Feature]` | 새 기능 개발 | `[Feature] 사용자 프로필 이미지 업로드` |
| `[Fix]` | 버그 수정 | `[Fix] 로그인 세션 만료 시 리다이렉트 실패` |
| `[Refactor]` | 리팩토링 | `[Refactor] 인증 모듈 의존성 역전 적용` |
| `[Infra]` | 인프라/DevOps | `[Infra] Staging 환경 Docker Compose 구성` |
| `[Docs]` | 문서화 | `[Docs] API 엔드포인트 OpenAPI 스펙 작성` |
| `[Test]` | 테스트 | `[Test] 결제 모듈 통합 테스트 추가` |
| `[Chore]` | 기타 잡무 | `[Chore] 미사용 의존성 정리` |

## Priority Guidelines

| Priority | 기준 |
|----------|------|
| 1 (Urgent) | 프로덕션 장애, 보안 취약점, 데이터 유실 위험 |
| 2 (High) | 현재 스프린트 핵심 작업, 블로커 해소 |
| 3 (Normal) | 일반 개발 작업, 개선사항 |
| 4 (Low) | 기술 부채, nice-to-have, 실험적 작업 |

## Time Estimate Guidelines

| 규모 | 시간 | 밀리초 값 |
|------|------|-----------|
| XS | 1h | 3600000 |
| S | 2h | 7200000 |
| M | 4h | 14400000 |
| L | 8h (1일) | 28800000 |
| XL | 16h (2일) | 57600000 |
| XXL | 40h (1주) | 144000000 |

## Example: curl

인터랙티브하게 수집한 값으로 ① 선택한 카테고리 List에 태스크를 생성하고
② 현재 스프린트 List에 추가하는 전체 흐름이다. 기본값(start_date=오늘,
priority=3 Normal, assignee=randy@ahha.ai)과 사용자가 답한 카테고리 / due date /
time estimate 를 반영한다.

> **반드시 아래 안전 패턴을 따른다** ([Common Mistakes](#common-mistakes) 참고):
> - payload JSON은 셸 here-string으로 만들지 말고 **`python3` + `json.dumps`** 로 생성한다
>   (한글·개행·따옴표 이스케이프 안전).
> - 응답에서 `id`를 뽑을 때 `echo "$RESP" | python3` 를 쓰지 않는다. zsh `echo` 가
>   응답 JSON의 `\n` 을 실제 개행으로 바꿔 파싱이 깨진다. **응답은 파일로 받아** 파싱한다.

```bash
# --- 입력 (인터랙티브 수집 결과) ---
export LIST_ID="${LIST_ID:?위에서 사용자가 고른 카테고리 List ID}"   # 카테고리 조회 결과에서 선택
export TASK_NAME="[Research] 한국형 ARPA-H 프로젝트 제안서 파악"
export MD="## 목적
- ...

## 작업 내용
- [ ] ...
"                                                            # markdown_description (개행/한글 자유롭게)
export PRIORITY=3                                            # 기본 Normal
export START_MS="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date +%Y-%m-%d) 00:00:00" +%s)000"  # 오늘
export DUE_MS=""                                            # 없으면 빈 값 (필드 생략됨)
export TIME_EST_MS=10800000                                 # 3h. 없으면 빈 값

# assignee 이메일 → user ID
export ASSIGNEE_ID="$(curl -s "https://api.clickup.com/api/v2/list/${LIST_ID}/member" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; m=json.load(sys.stdin)['members']; print(next(u['id'] for u in m if u['email']=='randy@ahha.ai'))")"

# payload 생성 (json.dumps — 빈 due/time 은 자동 생략)
PAYLOAD="$(python3 - <<'PY'
import json, os
body = {
    "name": os.environ["TASK_NAME"],
    "markdown_description": os.environ["MD"],
    "status": "to do",
    "priority": int(os.environ["PRIORITY"]),
    "start_date": int(os.environ["START_MS"]),
    "start_date_time": False,
    "assignees": [int(os.environ["ASSIGNEE_ID"])],
}
if os.environ.get("DUE_MS"):
    body["due_date"] = int(os.environ["DUE_MS"]); body["due_date_time"] = False
if os.environ.get("TIME_EST_MS"):
    body["time_estimate"] = int(os.environ["TIME_EST_MS"])
print(json.dumps(body, ensure_ascii=False))
PY
)"

# ① 카테고리 List에 태스크 생성 — 응답을 파일로 받아 파싱 (echo 사용 금지)
RESP_FILE="$(mktemp)"
curl -s -X POST "https://api.clickup.com/api/v2/list/${LIST_ID}/task" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" -H "Content-Type: application/json" \
  -d "$PAYLOAD" -o "$RESP_FILE"
TASK_ID="$(python3 -c "import json,sys; print(json.load(open('$RESP_FILE'))['id'])")"
echo "created: $TASK_ID"

# ② 현재 스프린트 List 계산 후 태스크 추가 (위 Category & Current Sprint 참고)
SPRINT_LIST_ID="$(curl -s "https://api.clickup.com/api/v2/folder/${SPRINT_FOLDER}/list?archived=false" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  | python3 -c "import sys,json; now=int('$(date +%s)000'); d=json.load(sys.stdin); print(next(l['id'] for l in d['lists'] if l.get('start_date') and l.get('due_date') and int(l['start_date'])<=now<=int(l['due_date'])))")"
curl -s -o /dev/null -w "add-to-sprint HTTP %{http_code}\n" -X POST \
  "https://api.clickup.com/api/v2/list/${SPRINT_LIST_ID}/task/${TASK_ID}" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" -H "Content-Type: application/json" -d '{}'
```

## Subtask Decomposition

큰 태스크는 서브태스크로 분해한다. `parent` 필드에 부모 태스크 ID를 지정하면 서브태스크가 된다.

분해 기준:
- 하나의 태스크가 8시간(1일)을 초과하면 분해를 고려
- 서로 다른 담당자가 병렬로 작업 가능한 단위로 분리
- 각 서브태스크는 독립적으로 테스트/검증 가능해야 함

## Workflow

전체 인터랙티브 진행 순서는 상단 [Interactive Workflow](#interactive-workflow-핵심)를
따른다. 요약하면:

1. 카테고리(생성 List)를 질문
2. 사용자 설명/붙여넣기에서 제목·내용을 추출
3. due date, time estimate를 질문
4. start date(오늘)·priority(Normal)·assignee(randy@ahha.ai) 기본값 적용
5. assignee user ID 조회 후 선택한 카테고리 List에 태스크 생성
6. 현재 스프린트 List를 동적 계산해 태스크를 추가 (항상)
7. 생성된 태스크 ID와 URL을 반환

## Error Handling

| 상태 코드 | 의미 | 대응 |
|-----------|------|------|
| 401 | 인증 실패 | API 토큰 확인 |
| 404 | List ID 없음 | List ID 확인 |
| 429 | Rate limit (100/min) | 재시도 대기 |
| 500 | 서버 오류 | 재시도 |

## Common Mistakes

| 증상 | 원인 | 해결 |
|------|------|------|
| `JSONDecodeError: Invalid control character` (응답 파싱 시) | zsh `echo "$RESP"` 가 응답 JSON의 `\n` 을 실제 개행으로 바꿔 JSON이 깨짐 | 응답을 `-o "$RESP_FILE"` 로 **파일에 받아** 파싱. `echo` 대신 `printf '%s'` 도 가능 |
| `KeyError: 'id'` / 빈 `TASK_ID` | 태스크 생성이 실패했는데 그대로 진행 | 생성 응답에 `id` 가 없으면(=에러 응답) 멈추고 응답 본문 확인 |
| `add-to-sprint HTTP 400` | `TASK_ID` 가 비어서 잘못된 URL 로 호출 | 위 두 문제 먼저 해결. ID 확보 후 스프린트 추가 |
| 한글/따옴표/개행으로 payload 깨짐 | 셸 here-string 으로 JSON 을 수기 작성 | `python3` + `json.dumps(..., ensure_ascii=False)` 로 생성 |
| 생성 실패로 보였는데 태스크가 만들어져 있음 | 생성은 성공, 후처리(파싱)만 실패 | **재시도 전** 카테고리 List 에서 동일 제목 태스크 존재 여부 확인 (중복 방지) |

## Notes

- `description`과 `markdown_description`을 동시에 보내면 `markdown_description`이 우선
- Custom Field는 Create Task에서 `custom_fields` 배열로 설정 가능
- 태스크 생성 후 Custom Field 수정은 별도 `Set Custom Field Value` 엔드포인트 사용
- 한글 태스크명/설명은 UTF-8 인코딩으로 정상 처리됨
