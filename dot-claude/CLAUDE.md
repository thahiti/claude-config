# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

# 스킬 게이트

아래 조건에 걸리면 **작업을 시작하기 전에** 해당 스킬을 끝까지 읽는다.
읽었는지 여부가 결과를 바꾸므로 기억에 의존하지 않는다.

| 스킬 | 읽어야 할 때 | 건너뛸 때 |
|---|---|---|
| `atomic-commit` | 커밋을 만들기 전 | 없음 |
| `implementation` | 소스 파일을 새로 쓰거나 고칠 때 | 문서와 설정만 바꿀 때 |
| `stack-python` | `.py` 를 건드릴 때 | 그 외 |
| `doc-review` | 기존 문서를 다듬어달라는 요청 | 문서를 처음 쓸 때 |
| `meeting-notes` | 회의록이나 회의 정리 요청 | 그 외 |
| `claude-config-doctor` | claude-config 리포를 고친 뒤 | 그 외 |

# 사용툴
## python 프로젝트
프로젝트를 위해 다음 툴들을 필수로 사용
uv, ruff, mypy, git

## 환경변수
환경변수는 항상 .env를 통해 읽어오도록 함

# 줄바꿈
마크다운(.md) 문서는 문장 단위로 줄바꿈한다.
Python 코드는 가독성을 우선하면서 한 줄을 79자 이내로 작성한다.
Python의 주석(Comment)과 독스트링(Docstring)은 한 줄을 72자 이내로 작성한다.
단, 줄 길이 제한으로 인해 가독성이 오히려 떨어지는 경우에는 예외를 허용하며, 절대적인 제약으로 적용하지 않는다.

# Git
## 커밋
- 가독성(직접 연관된 수정은 한커밋에)과 working 한다는 전제하에서 가능한 작은 커밋을 선호
- 파일의 이동과 내용의 변경은 반드시 분리
- 기계적 변경과 내용의 추가는 반드시 분리
- 반드시 논리적으로 하나의 변경만 하나의 커밋에 담는다
  예: 변경 후 추가X -> 변경 커밋 후 추가 커밋
- 수정 커밋의 Python 코드 변경량(추가와 삭제 합계)은 30줄을 목표로 한다.
- 복사 커밋, 스캐폴드, uv.lock, README, 테스트는 세지 않는다.
- 넘으면 실행 가능한 단위로 나눈다. 예: 클래스 정의 커밋, root_agent 교체 커밋.
- 나눠도 넘는 단일 클래스는 예외로 두고 본문에 이유를 적는다.
- 테스트는 코드와 같은 커밋에 둔다.

## 커밋 메시지
- Claude 나 Anthropic 관련 trailer 와 서명을 넣지 않는다. 커밋 메시지와 PR 본문 모두 해당한다.
- 제목은 영어로, 본문은 한글을 사용해 커밋 작성한다.
- 50자 이내, 어떤 변화가 있는지 한눈에 들어오게 짧고 명확하게 적는다.
- 본문은 한줄 띄우고, '무엇을', '왜' 바꿨는지 작성 제목 아래에 반드시 빈 줄을 하나 띄우고 작성합니다. 변경한 이유와 배경을 구체적으로 적는다. 가로 길이 (줄바꿈): 72자 이내

## 브랜치 전략: GitHub Flow
- feature 브랜치에서 작업하고 `feature/`, `fix/`, `test/`, `chore/` 접두사를 쓴다.
- main 으로는 rebase 후 --no-ff로 머지하고 브랜치를 지운다.
- 머지 커밋의 제목은 merge: 로 시작하고 본문은 해당 브랜치에서의 작업 내용을 한글로 작성한다.

# 문체
# 언어와 표기
- 용어와 개념을 나타내는 경우 명사형 어미와 개조식 들여쓰기를 이용해 구조를 드러낸다.
- 경로를 표시하는 경우 **항상 전체 경로**를 표기한다.
- 이모지를 쓰지 않는다. 가운뎃점, 세미콜론처럼 한국어 글쓰기에서 잘 쓰지 않는 기호도 쓰지 않는다.
- 영어를 그대로 옮긴 직역 표현을 쓰지 않고 한국에서 실제로 쓰는 표현을 고른다.
  예: 배선한다 → 연결한다, 이 컨텍스트에서 → 이 상황에서
  다만 실무에서 굳어진 외래어는 그대로 쓴다. 예: 얼라인, 피드백, 싱크, 디플로이
- 영어 줄임말은 처음 등장할 때 괄호에 원어를 풀어 쓴다. 두 번째부터는 줄임말만 쓴다.
  예: RAG(Retrieval-Augmented Generation, 검색 증강 생성)

## 금지단어
조립, 경계면, 배선, 긴장