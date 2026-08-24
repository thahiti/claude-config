# claude-config

개인 Claude Code 환경의 진실 원천(source of truth) 리포다.

일반 작업 지침은 이 파일에 두지 않는다. 문체, 설명 방식, 코딩 표준, Git 규칙은
`dot-claude/CLAUDE.md` 한 곳에만 있고, 그 파일이 `~/.claude/CLAUDE.md` 로 배포되어
모든 프로젝트에 적용된다. 여기에는 이 리포를 다룰 때만 필요한 규칙을 적는다.

## 디렉토리 구조

| 경로 | 배포 대상 | 설명 |
|---|---|---|
| `dot-claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 개인 지침 |
| `dot-claude/rules/` | `~/.claude/rules/` | 상황별 규칙 파일 |
| `skills/` | `~/.claude/skills/` | 개인 스킬 |
| `settings.json` | `~/.claude/settings.json` | 병합 배포 (링크 아님) |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | 상태라인 |

`settings.json` 을 제외한 나머지는 심볼릭 링크로 배포된다. 링크된 파일을 이 리포에서
고치면 즉시 반영되므로, 편집 후 재시작 없이 동작이 바뀔 수 있다는 점을 감안한다.

## 유지보수 규칙

- `settings.json` 의 `permissions` 배열을 수정하면 같은 커밋에서 `PERMISSIONS.md` 의
  해당 카테고리 표와 변경 이력도 갱신한다. 자세한 절차는 `PERMISSIONS.md` 의
  "유지보수 규칙" 섹션에 있다.
- 스킬을 추가하거나 삭제하면 `README.md` 의 스킬 목록을 함께 갱신한다.
- 스킬이 다른 스킬을 이름으로 참조하면 그 스킬이 실제로 `skills/` 에 존재하는지 확인한다.
  존재하지 않는 스킬을 참조하는 문서는 실행 시점에 조용히 실패한다.
- 리포 경로나 디렉토리 구조를 바꾸면 `~/.claude` 안의 심볼릭 링크가 한꺼번에 끊긴다.
  변경 후 `/claude-config-doctor` 로 무결성을 확인한다.

## 검증

변경을 커밋하기 전에 다음을 확인한다:

```bash
/claude-config-doctor
```

심볼릭 링크 무결성, 리포와 `~/.claude` 의 드리프트, 유령 스킬 참조를 한 번에 점검한다.
