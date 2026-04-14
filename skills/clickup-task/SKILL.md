---
name: clickup-task
description: Use when the user explicitly invokes /clickup-task to generate a ClickUp task description from provided arguments and copy it to clipboard
---
# ClickUp Task Creation Skill

## Overview

ClickUp API를 사용하여 태스크를 생성하는 Claude Code 스킬.
개발 작업 분석 후 구조화된 태스크를 ClickUp 리스트에 자동 생성한다.

## Prerequisites

- 환경변수 `CLICKUP_API_TOKEN`: Personal API Token (`pk_` 접두사)
- 환경변수 `CLICKUP_LIST_ID`: 태스크를 생성할 기본 List ID

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

```bash
curl -X POST "https://api.clickup.com/api/v2/list/${CLICKUP_LIST_ID}/task" \
  -H "Authorization: ${CLICKUP_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "[Feature] WebSocket 실시간 알림 구현",
    "markdown_description": "## 목적\n- 사용자에게 실시간 알림을 전달하여 UX 개선\n\n## 작업 내용\n- [ ] WebSocket 서버 엔드포인트 구현\n- [ ] 클라이언트 연결 관리 (heartbeat, reconnect)\n- [ ] 알림 이벤트 발행 서비스 구현\n- [ ] 프론트엔드 알림 컴포넌트 연동\n\n## 기술 스펙\n- **영향 범위**: `ara-chat` 서비스, 프론트엔드 알림 모듈\n- **기술 스택**: FastAPI WebSocket, React\n- **의존성**: 사용자 인증 토큰 검증 로직 완료 필요\n\n## 완료 조건\n- [ ] WebSocket 연결/해제 정상 동작\n- [ ] 알림 수신 테스트 통과\n- [ ] 동시 접속 100명 부하 테스트 통과",
    "status": "to do",
    "priority": 2,
    "tags": ["backend", "websocket"],
    "time_estimate": 28800000
  }'
```

## Subtask Decomposition

큰 태스크는 서브태스크로 분해한다. `parent` 필드에 부모 태스크 ID를 지정하면 서브태스크가 된다.

분해 기준:
- 하나의 태스크가 8시간(1일)을 초과하면 분해를 고려
- 서로 다른 담당자가 병렬로 작업 가능한 단위로 분리
- 각 서브태스크는 독립적으로 테스트/검증 가능해야 함

## Workflow

1. 사용자가 작업 내용을 설명하면 태스크 구조를 제안
2. 사용자 확인 후 API 호출로 태스크 생성
3. 생성된 태스크 ID와 URL을 반환

## Error Handling

| 상태 코드 | 의미 | 대응 |
|-----------|------|------|
| 401 | 인증 실패 | API 토큰 확인 |
| 404 | List ID 없음 | List ID 확인 |
| 429 | Rate limit (100/min) | 재시도 대기 |
| 500 | 서버 오류 | 재시도 |

## Notes

- `description`과 `markdown_description`을 동시에 보내면 `markdown_description`이 우선
- Custom Field는 Create Task에서 `custom_fields` 배열로 설정 가능
- 태스크 생성 후 Custom Field 수정은 별도 `Set Custom Field Value` 엔드포인트 사용
- 한글 태스크명/설명은 UTF-8 인코딩으로 정상 처리됨
