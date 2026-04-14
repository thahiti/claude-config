---
name: gitlab-mr-review
description: Use when the user provides a GitLab merge request URL (e.g. https://git.ahha.tf/.../merge_requests/123) and wants a code review
---

# GitLab MR Review

## Overview

GitLab Merge Request URL을 입력받아 multi-agent 코드 리뷰를 수행하는 스킬.

## Prerequisites

- 환경변수 `GITLAB_TOKEN`: GitLab Personal Access Token (`glpat-` 접두사, `read_api` scope 이상)

## URL Parsing

URL 형식: `https://{host}/{project_path}/-/merge_requests/{iid}`

```
https://git.ahha.tf/ahha-ai/ai-agent-project/newpermarket/-/merge_requests/109
         ^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                   ^^^
         host        project_path (URL-encode: %2F)                         iid
```

## GitLab API Reference

Base: `https://{host}/api/v4`
Auth header: `PRIVATE-TOKEN: $GITLAB_TOKEN`

| Endpoint | 용도 |
|----------|------|
| `GET /projects/{path}/merge_requests/{iid}` | MR 메타정보 (title, description, state, author, sha) |
| `GET /projects/{path}/merge_requests/{iid}/changes` | 변경 파일 목록 + diff |
| `GET /projects/{path}/merge_requests/{iid}/notes` | MR 코멘트 |
| `POST /projects/{path}/merge_requests/{iid}/notes` | 리뷰 코멘트 작성 |

project path는 슬래시를 `%2F`로 URL-encode해서 전달. 예: `ahha-ai%2Fai-agent-project%2Fnewpermarket`

## Workflow

1. **URL 파싱**: host, project_path, MR IID 추출
2. **사전 체크** (Haiku agent): MR이 closed/merged인지, draft인지 확인. 해당 시 중단.
3. **MR 정보 수집** (parallel):
   - Haiku agent: MR 설명 + 메타정보 요약
   - Haiku agent: 프로젝트 내 CLAUDE.md 파일 존재 여부 확인 (있으면 내용 수집)
4. **코드 리뷰** (5 parallel Sonnet agents):
   - Agent #1: CLAUDE.md 준수 여부 검토 (CLAUDE.md가 있는 경우에만)
   - Agent #2: 변경된 코드의 명백한 버그 탐지 (변경된 라인 중심, nitpick 제외)
   - Agent #3: 코드 구조/설계 이슈 (불필요한 복잡성, 잘못된 추상화, 누락된 에러 처리)
   - Agent #4: 보안 취약점 탐지 (injection, 인증/인가 우회, 민감정보 노출)
   - Agent #5: 변경사항 간 일관성 검토 (네이밍 컨벤션, 패턴 혼용, 미완성 리팩토링)
5. **신뢰도 점수 매기기** (parallel Haiku agents): 각 이슈에 0-100 점수 부여
6. **필터링**: 신뢰도 80 미만 이슈 제거
7. **결과 출력**: 발견된 이슈 정리하여 출력

## Confidence Scoring Scale

각 이슈에 대해 Haiku agent가 아래 기준으로 점수를 매긴다:

| 점수 | 의미 |
|------|------|
| 0 | False positive. 가볍게 봐도 문제 아님, 또는 PR 이전부터 있던 이슈 |
| 25 | 문제일 수도 있지만 false positive일 가능성도 있음 |
| 50 | 실제 이슈이나 nitpick이거나 실제 발생 빈도가 낮음 |
| 75 | 실제 발생할 가능성이 높은 이슈. 기존 PR 코드가 불충분함 |
| 100 | 확실한 이슈. 실제 환경에서 빈번히 발생할 것이 확인됨 |

## False Positive 기준

다음은 이슈로 보고하지 않는다:

- PR에서 수정하지 않은 라인의 기존 이슈
- Linter, type checker, CI가 잡아줄 이슈 (import 오류, 타입 에러, 포맷팅)
- 시니어 엔지니어가 지적하지 않을 수준의 pedantic nitpick
- 의도적인 기능 변경으로 보이는 동작 변경
- 일반적인 코드 품질 이슈 (테스트 커버리지 부족, 문서화 부족 등) - CLAUDE.md에서 명시적으로 요구하지 않는 한

## Output Format

```markdown
### Code Review: {MR title}

**MR**: {MR URL}
**Author**: {author} | **Branch**: {source} -> {target}

Found {N} issues:

1. **[Bug/Security/Design/Consistency]** {간결한 설명}

   `{file_path}#L{start}-L{end}`
   ```
   {관련 코드 스니펫}
   ```
   {왜 문제인지, 어떻게 수정해야 하는지}

---

No issues found. Checked for bugs, security, design, and consistency.
```

## curl Examples

```bash
HOST="https://git.ahha.tf"
PROJECT="ahha-ai%2Fai-agent-project%2Fnewpermarket"
MR_IID="109"

# MR 정보
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$HOST/api/v4/projects/$PROJECT/merge_requests/$MR_IID"

# MR 변경사항 (diff)
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$HOST/api/v4/projects/$PROJECT/merge_requests/$MR_IID/changes"

# MR 코멘트
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$HOST/api/v4/projects/$PROJECT/merge_requests/$MR_IID/notes"

# 리뷰 코멘트 작성
curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "Content-Type: application/json" \
  -d '{"body": "리뷰 내용"}' \
  "$HOST/api/v4/projects/$PROJECT/merge_requests/$MR_IID/notes"
```

## Notes

- GitLab API v14.6+ 대응 (self-hosted)
- 대규모 MR (변경 파일 50+)의 경우 diff가 클 수 있으므로, 에이전트에게 파일을 나눠서 전달
- `PRIVATE-TOKEN` 헤더 사용 (OAuth가 아닌 Personal Access Token 방식)
- 리뷰 결과를 GitLab에 코멘트로 작성하려면 `api` scope 토큰 필요 (기본은 터미널 출력)
