# Claude Code 기본 허용 규칙 (Default Allow List)

이 문서는 `settings.json` 의 `permissions.allow` 에 등록된 규칙을 카테고리별로 정리하고, 각 규칙의 근거와 주의사항을 기록한다. 다른 컴퓨터에 이 설정을 적용할 때의 기준 문서다.

---

## 유지보수 규칙 (Maintenance Rule)

**`settings.json` 의 `permissions.allow` / `deny` / `ask` 배열을 수정할 때 반드시 이 문서도 함께 업데이트한다.** 새 규칙을 추가하거나 제거하면:

1. 해당 카테고리 표에 행을 추가/삭제한다
2. 카테고리가 없으면 새 카테고리 섹션을 만든다
3. 말미의 **변경 이력** 에 날짜·변경 사항·이유를 한 줄 추가한다
4. 커밋 메시지는 `chore(permissions): ...` 또는 `docs(permissions): ...` 를 사용한다

이 규칙은 리포지토리의 진실 원천(source of truth) 역할을 위한 필수 절차다.

---

## 설계 원칙

| 범주 | 기본 허용 대상 |
|---|---|
| 읽기 | 작업 디렉토리 + `~/.claude` + `/tmp` 계열 |
| 네트워크 | 웹 검색·페치, 문서 조회 MCP |
| 셸 — 읽기 전용 | 변경 없는 조회 명령 |
| 셸 — 변경 계열 | Git 전체, 의존성 설치, 테스트 러너 |
| 파괴적 작업 | **전역 허용 금지** — 필요 시 프로젝트 `settings.local.json` 에 한정 |

**파괴적이거나 환경에 고유한 규칙(프로젝트 경로, 1회성 명령 등)은 이 문서와 전역 설정에 넣지 않는다. 프로젝트별 `.claude/settings.local.json` 에 기록한다.**

---

## 1. 읽기 경로 (Read paths)

| 규칙 | 근거 |
|---|---|
| `Read(//Users/randy/workspace/**)` | 주요 작업 디렉토리 |
| `Read(//Users/randy/claude_code/**)` | Claude 협업 프로젝트 디렉토리 |
| `Read(//Users/randy/.claude/**)` | 설정·스킬·플러그인 점검 빈번 |
| `Read(//tmp/**)` | 임시 빌드 산출물·스크래치 파일 |
| `Read(//private/tmp/**)` | macOS `/tmp` 의 실제 경로 |

**주의**: 절대경로 패턴은 `//` 접두사를 사용한다 (`/` 한 개는 프로젝트 루트 기준 상대경로).

## 2. 네트워크 (Web & MCP)

| 규칙 | 근거 |
|---|---|
| `WebSearch` | 최신 정보·라이브러리 조사 |
| `WebFetch` | 공식 문서·GitHub README 조회 |
| `mcp__plugin_context7_context7__resolve-library-id` | context7 플러그인 — 라이브러리 식별 |
| `mcp__plugin_context7_context7__query-docs` | context7 플러그인 — 공식 문서 조회 |

## 3. 셸 — 읽기 전용 (Read-only shell)

| 규칙 | 근거 |
|---|---|
| `Bash(ls:*)` | 디렉토리 조회 |
| `Bash(cat:*)` | 파일 내용 확인 (Read 로 대체 권장) |
| `Bash(grep:*)` | 텍스트 검색 |
| `Bash(find:*)` | 파일 검색 |
| `Bash(wc:*)` | 라인·단어 수 |
| `Bash(head:*)` | 파일 앞부분 |
| `Bash(tail:*)` | 파일 뒷부분·로그 스트리밍 |
| `Bash(pwd)` | 현재 디렉토리 |
| `Bash(which:*)` | 실행 파일 경로 |
| `Bash(file:*)` | 파일 타입 식별 |
| `Bash(stat:*)` | 파일 메타데이터 |
| `Bash(env)` | 환경 변수 확인 |

## 4. Git

| 규칙 | 근거 |
|---|---|
| `Bash(git:*)` | 모든 git 서브커맨드 |

**주의**: `Bash(git:*)` 는 파괴적 명령까지 포함한다. 그중 되돌리기 어려운 것은 아래 [8. 차단 규칙](#8-차단-규칙-deny) 에서 막는다.

## 5. 의존성 설치 (Dependency install / query)

| 규칙 | 근거 |
|---|---|
| `Bash(npm install:*)`, `Bash(npm i:*)`, `Bash(npm ci:*)` | npm 설치 |
| `Bash(npm view:*)`, `Bash(npm search:*)` | npm 메타 조회 |
| `Bash(pnpm install:*)`, `Bash(pnpm i:*)`, `Bash(pnpm add:*)` | pnpm 설치·추가 |
| `Bash(pnpm approve-builds:*)` | pnpm 빌드 승인 |
| `Bash(yarn install:*)`, `Bash(yarn add:*)` | yarn |
| `Bash(bun install:*)`, `Bash(bun add:*)` | bun |
| `Bash(pip install:*)`, `Bash(pip3 install:*)` | pip 설치 |
| `Bash(pip list:*)`, `Bash(pip show:*)`, `Bash(pip3 show:*)` | pip 메타 |
| `Bash(uv sync:*)`, `Bash(uv add:*)`, `Bash(uv pip install:*)` | uv |
| `Bash(uv run:*)` | uv 실행 |

## 6. 테스트 러너 (Test runners)

| 규칙 | 근거 |
|---|---|
| `Bash(pytest:*)`, `Bash(python -m pytest:*)`, `Bash(python3 -m pytest:*)` | pytest |
| `Bash(npm test:*)`, `Bash(npm run test:*)` | npm 스크립트 |
| `Bash(pnpm test:*)`, `Bash(pnpm test\:web:*)`, `Bash(pnpm test\:e2e:*)` | pnpm 스크립트 |
| `Bash(yarn test:*)` | yarn |
| `Bash(npx vitest:*)`, `Bash(vitest:*)`, `Bash(pnpm vitest:*)`, `Bash(pnpm exec vitest:*)` | vitest |
| `Bash(npx jest:*)`, `Bash(jest:*)` | jest |
| `Bash(go test:*)` | Go |

## 7. 기타 (Misc)

| 규칙 | 근거 |
|---|---|
| `Bash(source ~/.nvm/nvm.sh *)` | nvm 환경 로드 — 사전 조건 |

## 8. 차단 규칙 (Deny)

`deny` 는 `allow` 보다 우선한다. `Bash(git:*)` 로 열어둔 범위에서 되돌리기 어려운 명령만 도로 닫는다.

| 규칙 | 근거 |
|---|---|
| `Bash(git push --force:*)` | 원격 히스토리 파괴. 되돌릴 수 없다 |
| `Bash(git push -f:*)` | 위와 동일, 축약 플래그 |
| `Bash(git reset --hard:*)` | 커밋되지 않은 작업 유실 |
| `Bash(git branch -D:*)` | 머지되지 않은 브랜치 강제 삭제 |
| `Bash(git clean -fd:*)` | 추적되지 않는 파일 일괄 삭제 |

**한계**: 접두사 매칭이라 `git push origin main --force` 처럼 플래그가 뒤에 오면 빠져나간다. 실수를 막는 턱이지 봉인이 아니다. 완전한 차단이 필요하면 커맨드를 파싱하는 `PreToolUse` 훅으로 올린다.

## 9. 훅으로 강제하는 규칙

허용 규칙으로 표현할 수 없는 것은 훅이 맡는다. 문장으로만 있는 규칙은 지켜지지 않으므로, 강제 가능한 것은 이쪽으로 옮긴다.

| 훅 | 시점 | 막는 것 |
|---|---|---|
| 커밋 게이트 (settings.json 인라인) | `PreToolUse` / `Bash(git commit *)` | 커밋 메시지의 Claude 서명, `.env` 와 빌드 산출물 스테이징 |
| `dot-claude/hooks/check-written-file.py` | `PostToolUse` / `Edit`, `Write` | 새로 쓴 내용의 이모지와 줄 끝 공백 |
| 커밋 리뷰 (settings.json 인라인) | `PostToolUse` / `Bash(git commit *)` | 커밋 형식과 원자성 사후 검토 |

커밋 게이트를 외부 스크립트가 아닌 인라인으로 둔 이유는 경로가 끊겼을 때 차단이 조용히 사라지는 것을 막기 위해서다. 스크립트를 쓰는 훅은 `/claude-config-doctor` 가 경로 존재를 점검한다.

---

## 설정 적용 방법

새 컴퓨터에 이 설정을 적용하거나 기존 설정과 병합할 때는 **`/sync-claude-config`** 스킬을 사용한다. 자세한 절차는 `skills/sync-claude-config/SKILL.md` 참조.

```bash
git clone git@github.com:thahiti/claude-config.git ~/claude-config
cd ~/claude-config
claude        # Claude Code 실행 후
# /sync-claude-config
```

cd 만 해도 `.claude/skills/sync-claude-config` 가 프로젝트 레벨 스킬로 자동 발견된다(리포에 심볼릭 링크 포함).

핵심 병합 규칙:
- 배열(`permissions.allow` 등)은 합집합 + 중복 제거
- 스칼라는 리포가 우선
- `env` 는 로컬 유지 (API 키 등 머신 고유값 보호)

---

## 변경 이력 (Changelog)

- **2026-04-24** — 초기 문서화. 61개 규칙을 7개 카테고리로 정리. 설계 원칙, 유지 규칙, 적용 방법 수록.
- **2026-08-24** — `deny` 5건 신설. `Bash(git:*)` 가 열어둔 파괴적 명령을 도로 닫았다. 훅으로 강제하는 규칙을 9장에 정리.
