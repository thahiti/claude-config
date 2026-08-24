#!/usr/bin/env python3
"""claude-config 리포와 ~/.claude 사이의 무결성을 점검한다.

심볼릭 링크, 설정 드리프트, 유령 스킬 참조, 상태라인 동작을 확인하고
문제 건수를 종료 코드로 돌려준다.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from collections.abc import Iterator
from pathlib import Path

HOME = Path.home()
CLAUDE = HOME / ".claude"

RED, YELLOW, GREEN, DIM, RESET = "\033[31m", "\033[33m", "\033[32m", "\033[2m", "\033[0m"

problems: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    problems.append(msg)
    print(f"  {RED}FAIL{RESET} {msg}")


def warn(msg: str) -> None:
    warnings.append(msg)
    print(f"  {YELLOW}WARN{RESET} {msg}")


def ok(msg: str) -> None:
    print(f"  {GREEN}ok{RESET}   {DIM}{msg}{RESET}")


def find_repo() -> Path:
    """리포 경로를 인자, git 원격, 기본 경로 순으로 찾는다."""
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).expanduser().resolve()
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        remote = subprocess.run(
            ["git", "-C", root, "remote", "get-url", "origin"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        if "claude-config" in remote:
            return Path(root).resolve()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return (HOME / "claude-config").resolve()


def expected_links(repo: Path) -> Iterator[tuple[Path, Path]]:
    """(리포 원본, 배포 대상) 쌍을 만든다."""
    for skill in sorted((repo / "skills").iterdir()):
        if skill.is_dir():
            yield skill, CLAUDE / "skills" / skill.name
    dot = repo / "dot-claude"
    if dot.is_dir():
        for src in sorted(p for p in dot.rglob("*") if p.is_file()):
            yield src, CLAUDE / src.relative_to(dot)
    yield repo / "statusline-command.sh", CLAUDE / "statusline-command.sh"


def check_links(repo: Path) -> None:
    print("\n[1] 심볼릭 링크 무결성")
    for src, target in expected_links(repo):
        rel = target.relative_to(CLAUDE)
        if target.is_symlink() and not target.exists():
            fail(f"{rel} — 끊긴 링크 (대상: {os.readlink(target)})")
        elif not target.exists():
            fail(f"{rel} — 배포되지 않음")
        elif not target.is_symlink():
            warn(f"{rel} — 링크가 아닌 독립 파일. 리포 변경이 반영되지 않는다")
        elif Path(os.readlink(target)).resolve() != src.resolve():
            fail(f"{rel} — 다른 대상을 가리킴 ({os.readlink(target)})")
        else:
            ok(str(rel))


def check_settings_drift(repo: Path) -> None:
    print("\n[2] settings.json 드리프트")
    target = CLAUDE / "settings.json"
    if not target.exists():
        fail("~/.claude/settings.json 이 없다")
        return
    repo_cfg = json.loads((repo / "settings.json").read_text())
    live_cfg = json.loads(target.read_text())

    def flatten(obj: object, prefix: str = "") -> dict[str, str]:
        if isinstance(obj, dict):
            out: dict[str, str] = {}
            for k, v in obj.items():
                out |= flatten(v, f"{prefix}.{k}" if prefix else k)
            return out
        return {prefix: json.dumps(obj, sort_keys=True, ensure_ascii=False)}

    flat_repo, flat_live = flatten(repo_cfg), flatten(live_cfg)
    drifted = False
    for key in sorted(set(flat_repo) | set(flat_live)):
        r, l = flat_repo.get(key), flat_live.get(key)
        if r == l:
            continue
        drifted = True
        if r is None:
            warn(f"{key} — 로컬에만 있음 (리포에 반영 필요 여부 확인)")
        elif l is None:
            fail(f"{key} — 리포에만 있음 (로컬에 미적용)")
        else:
            fail(f"{key} — 값 불일치\n         리포: {r[:90]}\n         로컬: {l[:90]}")
    if not drifted:
        ok("리포와 로컬이 일치")


def known_skill_names(repo: Path) -> set[str]:
    names = {p.name for p in (repo / "skills").iterdir() if p.is_dir()}
    if (CLAUDE / "skills").is_dir():
        names |= {p.name for p in (CLAUDE / "skills").iterdir() if p.is_dir()}
    plugins = CLAUDE / "plugins" / "cache"
    if plugins.is_dir():
        names |= {p.parent.name for p in plugins.rglob("skills/*/SKILL.md")}
    return names


def check_ghost_skills(repo: Path) -> None:
    """존재하지 않는 스킬을 이름으로 참조하는 문서를 찾는다."""
    print("\n[3] 유령 스킬 참조")
    known = known_skill_names(repo)
    # `**name** 스킬` 과 `name 스킬` 두 형태를 잡는다.
    pattern = re.compile(r"(?:\*\*([a-z][a-z0-9-]{2,})\*\*|\b([a-z][a-z0-9-]{2,}))\s*스킬")
    docs = [*(repo / "skills").rglob("SKILL.md"), repo / "CLAUDE.md",
            *(repo / "dot-claude").rglob("*.md")]
    found = False
    for doc in docs:
        if not doc.exists():
            continue
        for lineno, line in enumerate(doc.read_text().splitlines(), 1):
            for m in pattern.finditer(line):
                name = m.group(1) or m.group(2)
                if "-" not in name or name in known:
                    continue  # 하이픈 없는 일반 명사는 스킬 이름으로 보지 않는다
                found = True
                fail(f"{doc.relative_to(repo)}:{lineno} — '{name}' 스킬이 존재하지 않는다")
    if not found:
        ok(f"참조된 스킬 이름이 모두 존재 (알려진 스킬 {len(known)}개)")


def check_statusline() -> None:
    print("\n[4] 상태라인 실행")
    sl = CLAUDE / "statusline-command.sh"
    if not sl.exists():
        fail("statusline-command.sh 를 실행할 수 없다")
        return
    payload = json.dumps({"model": {"display_name": "probe"},
                          "workspace": {"current_dir": str(HOME)}})
    try:
        res = subprocess.run(["bash", str(sl)], input=payload, capture_output=True,
                             text=True, timeout=20)
    except subprocess.TimeoutExpired:
        fail("상태라인이 20초 안에 끝나지 않는다. 매 렌더마다 지연이 생긴다")
        return
    out = res.stdout.strip()
    if not out:
        fail("상태라인 출력이 비어 있다")
    elif "\\~" in out or "\\$" in out:
        fail(f"상태라인 출력에 이스케이프 문자가 그대로 남아 있다: {out[:60]}")
    else:
        ok(f"출력 정상 ({len(out)}자)")


def check_hook_scripts(repo: Path) -> None:
    """훅이 참조하는 스크립트가 실제로 존재하는지 본다.

    훅 커맨드의 경로가 끊기면 차단이 조용히 사라진다. 훅은 실패해도 눈에 띄지 않으므로
    없어진 것을 알려주지 않으면 보호받고 있다고 착각하게 된다.
    """
    print("\n[5] 훅 스크립트 경로")
    cfg = json.loads((repo / "settings.json").read_text())
    path_re = re.compile(r'["\']?(\$HOME|~)(/[\w./-]+\.(?:py|sh))["\']?')
    found = False
    for event, matchers in (cfg.get("hooks") or {}).items():
        for matcher in matchers:
            for hook in matcher.get("hooks", []):
                for m in path_re.finditer(str(hook.get("command", ""))):
                    found = True
                    target = HOME / m.group(2).lstrip("/")
                    label = f"{event} — {m.group(1)}{m.group(2)}"
                    if target.exists():
                        ok(label)
                    else:
                        fail(f"{label} — 파일이 없다. 이 훅은 조용히 실패한다")
    if not found:
        ok("외부 스크립트를 참조하는 훅 없음 (전부 인라인)")


def check_env_tokens(repo: Path) -> None:
    """스킬이 전제하는 환경변수가 실제로 설정돼 있는지 본다.

    목록의 출처는 docs/tokens.md 의 표다. SKILL.md 본문에서 긁으면 서술 방식이
    바뀔 때마다 조용히 놓치므로, 한 곳에 모아둔 표를 정답으로 삼는다.
    """
    print("\n[6] 스킬이 요구하는 환경변수")
    required: dict[str, str] = {}

    tokens_doc = repo / "docs" / "tokens.md"
    if tokens_doc.exists():
        row = re.compile(r"^\|\s*`([A-Z][A-Z0-9_]+)`\s*\|\s*([^|]+?)\s*\|")
        for line in tokens_doc.read_text().splitlines():
            if m := row.match(line):
                required[m.group(1)] = m.group(2)
    else:
        warn("docs/tokens.md 가 없다. 환경변수 목록을 확인할 수 없다")

    # 표에 빠진 것이 있으면 SKILL.md 본문에서도 주워 담는다.
    pattern = re.compile(r"환경변수 `([A-Z][A-Z0-9_]+)`")
    for doc in (repo / "skills").rglob("SKILL.md"):
        for name in pattern.findall(doc.read_text()):
            required.setdefault(name, doc.parent.name)
    if not required:
        ok("환경변수를 요구하는 스킬 없음")
        return
    for name, skill in sorted(required.items()):
        if os.environ.get(name):
            ok(f"{name} (필요: {skill})")
        else:
            warn(f"{name} 미설정 — {skill} 스킬이 첫 API 호출에서 실패한다")


def main() -> int:
    repo = find_repo()
    print(f"claude-config doctor\n리포: {repo}\n대상: {CLAUDE}")
    if not (repo / "settings.json").exists():
        print(f"{RED}리포를 찾을 수 없다. 경로를 인자로 넘겨라.{RESET}")
        return 2

    check_links(repo)
    check_settings_drift(repo)
    check_ghost_skills(repo)
    check_statusline()
    check_hook_scripts(repo)
    check_env_tokens(repo)

    print(f"\n{'-' * 50}")
    if problems:
        print(f"{RED}문제 {len(problems)}건{RESET}, 경고 {len(warnings)}건")
        return 1
    print(f"{GREEN}문제 없음{RESET}, 경고 {len(warnings)}건")
    return 0


if __name__ == "__main__":
    sys.exit(main())
