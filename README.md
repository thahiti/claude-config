# claude-config

개인 Claude Code 설정·스킬·상태라인 스크립트의 진실 원천(source of truth) 리포.

여러 컴퓨터에 동일한 Claude Code 환경을 배포하기 위해 사용한다. 기존 설정이 있는 머신에서는 손실 없이 병합한다.

## 포함 내용

- `settings.json` — 전역 Claude Code 설정 (`permissions.allow`, hooks, 플러그인 등)
- `CLAUDE.md` — 모든 프로젝트에 적용되는 개인 지침
- `PERMISSIONS.md` — 허용 규칙 카테고리별 문서 (변경 시 함께 갱신 필수)
- `skills/` — 사용자 스킬 (블로그 포스팅, ClickUp 태스크 생성, GitHub 푸시, GitLab MR 리뷰, 설정 동기화 등)
- `statusline-command.sh` — 커스텀 상태라인 스크립트

## 새 컴퓨터에서 사용법

```bash
git clone git@github.com:thahiti/claude-config.git ~/dev/claude-config
cd ~/dev/claude-config
claude
```

Claude Code 프롬프트에서:

```
/sync-claude-config
```

cd 시점부터 `.claude/skills/sync-claude-config` 가 프로젝트 레벨 스킬로 자동 발견되므로 별도 설치 단계 없이 바로 호출할 수 있다. 스킬 실행이 끝나면 모든 스킬이 `~/.claude/skills/` 로 심볼릭 링크되어 어디서든 사용 가능해진다.

## 동작 요약 (`/sync-claude-config`)

| 대상 머신 상태 | 처리 |
|---|---|
| `~/.claude/settings.json` 없음 | 리포의 `settings.json` 으로 심볼릭 링크 생성 |
| 이미 리포로 심볼릭 링크 | 변화 없음 |
| 독립 파일로 존재 | 백업 후 필드별 규칙으로 **병합**, diff 표시, 사용자 승인 |

병합 규칙 핵심:
- `permissions.{allow,deny,ask}` — 합집합 + 중복 제거
- `env` — 로컬 우선 (API 키 등 머신 고유값 보호)
- 스칼라(`model`, `theme` 등) — 리포 우선

자세한 절차와 병합 규칙은 [`skills/sync-claude-config/SKILL.md`](skills/sync-claude-config/SKILL.md), 허용 규칙 카테고리는 [`PERMISSIONS.md`](PERMISSIONS.md) 참조.

## 사전 요구사항

- Python 3.8+ (병합 스크립트)
- Claude Code

## 유지보수

`settings.json` 의 `permissions` 배열을 수정할 때는 같은 커밋(또는 직후 커밋)에서 `PERMISSIONS.md` 의 해당 카테고리 표와 변경 이력도 갱신한다. 자세한 규칙은 [`PERMISSIONS.md`](PERMISSIONS.md) 의 "유지보수 규칙" 섹션 참조.
