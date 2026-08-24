---
name: stack-python
description: Use when writing or modifying Python code, adding type hints or docstrings, choosing a Python dependency or test layout, or setting up a Python project
---

# Stack Python

## Overview

Python 작업의 언어별 규칙만 담는다. 최소 구현, 함수형 스타일, 진행 방식 같은 공통 규칙은
**implementation** 스킬에 있다.

## 타입 힌트

모든 함수 시그니처에 엄밀한 타입 힌트를 붙인다. 반환값이 없으면 `-> None` 도 명시한다.

- 컨테이너는 원소 타입까지 적는다. `list` 가 아니라 `list[str]` 이다.
- 인자로 받는 컬렉션은 `Sequence`, `Mapping` 처럼 필요한 최소 기능만 요구하고,
  반환값은 `list`, `dict` 처럼 구체 타입으로 준다. 인자를 좁게 잡으면 호출자가
  자료구조를 바꿔도 시그니처가 버틴다.
- `Any` 는 경계에서만 쓴다. 외부 JSON 을 받는 지점처럼 타입을 알 수 없는 곳에서만 허용하고,
  받은 즉시 검증해 구체 타입으로 좁힌다.
- `Optional[T]` 대신 `T | None` 을 쓴다.

```python
from collections.abc import Sequence

def summarize(scores: Sequence[float], label: str | None = None) -> dict[str, float]:
    """점수 목록의 요약 통계를 계산한다."""
    if not scores:  # 빈 입력에서 max/min 이 터지므로 먼저 거른다
        return {}
    return {"mean": sum(scores) / len(scores), "max": max(scores), "min": min(scores)}
```

## Docstring

Google 스타일로 쓴다. 한 줄 요약은 한글 명령형이나 서술형으로 통일하고, 인자와 반환값이
이름만으로 자명하면 `Args` 와 `Returns` 를 생략한다. 자명한 값을 다시 적는 docstring 은
코드와 어긋날 여지만 만든다.

```python
def load_config(path: Path, *, strict: bool = False) -> Config:
    """설정 파일을 읽어 Config 로 변환한다.

    Args:
        path: 설정 파일 경로.
        strict: True 면 알 수 없는 키를 만났을 때 예외를 던진다.

    Returns:
        검증을 마친 설정 객체.

    Raises:
        ConfigError: 파일이 없거나 스키마에 맞지 않을 때.
    """
```

## 네이밍

| 대상 | 규칙 |
|---|---|
| 변수, 함수, 메서드 | `snake_case` |
| 클래스, 타입 별칭 | `PascalCase` |
| 모듈 상수 | `UPPER_SNAKE_CASE` |
| 내부 전용 | 앞에 밑줄 하나 `_helper` |

## 도구

- 패키지 관리와 실행은 `uv` 를 기본으로 한다. `uv sync` 로 환경을 맞추고
  `uv run` 으로 실행한다. 전역 `pip install` 로 프로젝트 의존성을 넣지 않는다.
- 테스트는 `pytest` 를 쓴다. 테스트 함수 이름은 무엇을 검증하는지 문장으로 적는다.
  `test_load_config_raises_on_unknown_key` 처럼 이름만 읽고 실패 내용을 알 수 있게 한다.
- 타입 검사는 pyright 를 쓴다. 이 환경에는 `pyright-lsp` 플러그인이 켜져 있어
  편집 중에 진단이 올라온다.

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| 가변 기본 인자 `def f(xs: list = [])` | 기본값이 호출 간에 공유되어 이전 호출의 값이 남는다. `None` 을 받고 안에서 만든다 |
| 반환 타입에 `Sequence` 사용 | 호출자가 인덱싱 외의 연산을 못 한다. 반환은 구체 타입으로 준다 |
| `except Exception` 으로 광범위 포획 | `KeyboardInterrupt` 외 모든 버그까지 삼킨다. 잡을 예외를 지정한다 |
| docstring 에 타입 반복 기재 | 시그니처와 어긋날 수 있다. 타입은 힌트에만 둔다 |
| 모듈 최상위에서 부수효과 실행 | import 만 해도 동작한다. `if __name__ == "__main__":` 아래로 내린다 |
