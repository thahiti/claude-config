#!/usr/bin/env python3
"""Edit 와 Write 직후 새로 쓴 내용만 검사한다.

파일 전체가 아니라 이번에 추가된 문자열만 본다. 남이 쓴 파일을 한 줄 고쳤을 때
원래 있던 이모지까지 걸고 넘어지면 훅이 방해물이 되기 때문이다.

문제를 발견하면 exit 2 로 모델에 되먹인다. 파일을 직접 고치지는 않는다.
훅이 몰래 파일을 바꾸면 모델이 들고 있는 파일 상태와 어긋난다.
"""

from __future__ import annotations

import json
import re
import sys

# 한국어 글쓰기에서 쓰지 않기로 한 기호. CLAUDE.md 의 "언어와 표기" 규칙과 짝을 이룬다.
DECORATIVE = re.compile(
    "["
    "\U0001f300-\U0001faff"  # 그림 이모지
    "☀-➿"          # 딩뱃, 기타 기호 (✓ ✗ ⚠ ★ 등)
    "⬀-⯿"          # 화살표, 도형
    "️"                 # variation selector
    "·•ㆍ"     # 가운뎃점 계열
    "]"
)

# 줄 끝 공백을 검사하지 않을 확장자. 마크다운은 줄 끝 공백 두 개가 줄바꿈 문법이다.
TRAILING_WS_EXEMPT = {".md", ".markdown", ".mdx"}


def written_text(tool_input: dict[str, object]) -> str:
    """이번 도구 호출로 새로 들어간 텍스트만 모은다."""
    parts = [tool_input.get(k) for k in ("content", "new_string")]
    if isinstance(edits := tool_input.get("edits"), list):  # MultiEdit 대응
        parts += [e.get("new_string") for e in edits if isinstance(e, dict)]
    return "\n".join(p for p in parts if isinstance(p, str))


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # 입력을 못 읽으면 통과시킨다. 훅이 작업을 막는 쪽이 더 나쁘다.

    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return 0
    path = tool_input.get("file_path")
    text = written_text(tool_input)
    if not isinstance(path, str) or not text:
        return 0

    problems: list[str] = []

    if found := sorted(set(DECORATIVE.findall(text))):
        problems.append(f"이모지와 장식 기호를 쓰지 않기로 했습니다. 발견: {' '.join(found)}")

    if not any(path.endswith(ext) for ext in TRAILING_WS_EXEMPT):
        lines = [i for i, line in enumerate(text.splitlines(), 1) if line.rstrip() != line]
        if lines:
            shown = ", ".join(map(str, lines[:5]))
            more = f" 외 {len(lines) - 5}곳" if len(lines) > 5 else ""
            problems.append(f"줄 끝 공백이 있습니다. 새로 쓴 내용 기준 {shown}번째 줄{more}")

    if not problems:
        return 0

    print(f"{path} 에 쓴 내용에서 확인이 필요합니다:", file=sys.stderr)
    for p in problems:
        print(f"- {p}", file=sys.stderr)
    print("수정한 뒤 다시 쓰세요.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
