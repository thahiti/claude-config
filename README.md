# claude-config

개인 Claude Code 설정, 스킬, 상태라인 스크립트의 진실 원천(source of truth) 리포.

여러 컴퓨터에 동일한 Claude Code 환경을 배포하기 위해 사용한다. 기존 설정이 있는 머신에서는 손실 없이 병합한다.

## 포함 내용

| 경로 | 배포 대상 | 방식 |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | 병합 |
| `dot-claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 심볼릭 링크 |
| `dot-claude/rules/` | `~/.claude/rules/` | 심볼릭 링크 |
| `skills/` | `~/.claude/skills/` | 심볼릭 링크 |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | 심볼릭 링크 |

그 밖에 `PERMISSIONS.md` 에 허용 규칙을 카테고리별로 정리해 두었고(변경 시 함께 갱신 필수), `docs/tokens.md` 에 스킬이 요구하는 환경변수의 발급과 등록 절차가 있다.

`settings.json` 만 병합 방식인 이유는 Claude Code 가 이 파일을 직접 쓰기 때문이다. 링크로 두면 설정 변경 시 파일이 통째로 교체되며 링크가 끊길 수 있다.

## 스킬 목록

| 스킬 | 용도 |
|---|---|
| `atomic-commit` | 커밋 단위 판단과 Conventional Commits 형식 |
| `implementation` | 언어 공통 코딩 규칙 |
| `stack-python` | Python 타입힌트, docstring, 도구 |
| `doc-review` | 기존 문서를 목소리 유지한 채 다듬기 |
| `meeting-notes` | 회의록 작성 |
| `blog-draft` | 초안을 발행 가능한 글로 다듬기 |
| `blog-post` | Jekyll 블로그에 발행 |
| `clickup-task` | ClickUp 태스크 생성 |
| `github-push` | GitHub 리포 생성과 push |
| `gitlab-mr-review` | GitLab MR 코드 리뷰 |
| `sync-claude-config` | 이 리포를 머신에 적용 |
| `claude-config-doctor` | 배포 무결성 점검 |

## 새 컴퓨터에서 사용법

```bash
git clone git@github.com:thahiti/claude-config.git ~/claude-config
cd ~/claude-config
claude
```

Claude Code 프롬프트에서:

```
/sync-claude-config
```

cd 시점부터 `.claude/skills/sync-claude-config` 가 프로젝트 레벨 스킬로 자동 발견되므로 별도 설치 단계 없이 바로 호출할 수 있다. 스킬 실행이 끝나면 모든 스킬과 전역 지침이 `~/.claude/` 로 심볼릭 링크되어 어디서든 사용 가능해진다.

토큰이 필요한 스킬(`clickup-task`, `gitlab-mr-review`)은 [`docs/tokens.md`](docs/tokens.md) 를 보고 환경변수를 따로 등록한다.

## 동작 요약 (`/sync-claude-config`)

| 대상 머신 상태 | 처리 |
|---|---|
| `~/.claude/settings.json` 없음 | 리포의 `settings.json` 으로 심볼릭 링크 생성 |
| 이미 리포로 심볼릭 링크 | 변화 없음 |
| 독립 파일로 존재 | 백업 후 필드별 규칙으로 **병합**, diff 표시, 사용자 승인 |

링크 대상(스킬, 전역 지침, 상태라인)은 네 가지 상태로 분류한다. 없으면 생성, 정상 링크면 그대로, **끊긴 링크면 확인 없이 재연결**, 실제 파일이거나 다른 대상을 가리키면 사용자에게 확인한다.

병합 규칙 핵심:
- `permissions.{allow,deny,ask}` — 합집합 + 중복 제거
- `env` — 로컬 우선 (API 키 등 머신 고유값 보호)
- 스칼라(`model`, `theme` 등) — 리포 우선

자세한 절차와 병합 규칙은 [`skills/sync-claude-config/SKILL.md`](skills/sync-claude-config/SKILL.md), 허용 규칙 카테고리는 [`PERMISSIONS.md`](PERMISSIONS.md) 참조.

## 점검

```bash
python3 ~/claude-config/skills/claude-config-doctor/scripts/doctor.py
```

심볼릭 링크 무결성, 리포와 `~/.claude` 의 설정 드리프트, 유령 스킬 참조, 상태라인 동작, 환경변수 설정 여부를 확인한다. 리포 경로를 옮긴 뒤나 스킬이 목록에서 사라졌을 때 먼저 돌린다.

## 사전 요구사항

- Python 3.8+ (병합 스크립트, 점검 스크립트)
- `jq` (상태라인)
- Claude Code

## 유지보수

`settings.json` 의 `permissions` 배열을 수정할 때는 같은 커밋(또는 직후 커밋)에서 `PERMISSIONS.md` 의 해당 카테고리 표와 변경 이력도 갱신한다. 스킬을 추가하거나 삭제하면 위 스킬 목록도 함께 갱신한다. 자세한 규칙은 [`PERMISSIONS.md`](PERMISSIONS.md) 의 "유지보수 규칙" 섹션과 [`CLAUDE.md`](CLAUDE.md) 참조.
