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

## 예외 처리

`except Exception:` 은 최상위 핸들러가 아니면 쓰지 않는다. 잡을 예외를 지정해야
예상한 실패와 그 자리에 섞여 들어온 버그가 구분된다.

| 상황 | 잡을 예외 |
|---|---|
| 파일 조작 | `except (OSError, PermissionError):` |
| JSON 파싱 | `except json.JSONDecodeError:` |
| 네트워크 | `except (ConnectionError, TimeoutError):` |

위 셋은 예시이지 전부가 아니다. 호출하는 함수가 실제로 던지는 예외를 확인하고 적는다.

- 예외를 잡은 자리의 로깅은 `logger.error()` 가 아니라 `logger.exception()` 을 쓴다.
  `error()` 는 스택 트레이스를 버려서 어디서 났는지 알 수 없게 만든다.
- `try` 블록은 최대한 좁게 잡는다. 함수 전체를 감싸면 관련 없는 줄에서 난 진짜 버그가
  예상된 실패로 보고된다. 예외를 던지지 않는 호출까지 `try` 안에 넣지 않는다.
- 검증이 키의 존재를 보장하는 자리에서는 `data.get("key")` 대신 `data["key"]` 로 접근한다.
  `.get()` 은 계약 위반을 `None` 으로 바꿔 조용히 흘려보낸다.

핸들러를 붙일지 말지의 판단 기준은 **implementation** 스킬의 에러 처리 절에 있다.

## 도구

### 패키지 관리와 실행: uv

uv 가 인터프리터와 가상환경을 함께 관리한다. `source .venv/bin/activate` 로 환경을 직접
켤 필요가 없고 `uv sync` 와 `uv run` 이 실행 직전에 맞춘다.

| 목적 | 명령 | 알아둘 점 |
|---|---|---|
| 프로젝트 생성 | `uv init` | 0.12 부터 애플리케이션도 `[build-system]` 과 `src/` 배치가 기본이다. 평면 배치가 필요하면 `--no-package` 나 `--bare` 를 쓴다 |
| 의존성 추가 | `uv add <패키지>` | pyproject.toml, uv.lock, 환경을 한 번에 갱신한다 |
| 개발 의존성 추가 | `uv add --dev <패키지>` | PEP 735 `[dependency-groups]` 의 dev 그룹에 들어가고 배포 시 PyPI 로 나가지 않는다 |
| 환경 맞추기 | `uv sync` | 기본이 exact 라 락파일에 없는 패키지를 제거한다. 남기려면 `--inexact` |
| 실행 | `uv run <명령>` | 실행 전에 lock 과 sync 를 자동으로 한다. 이때 sync 는 inexact 다 |
| 버전 올리기 | `uv lock --upgrade-package <패키지>` | 새 버전이 나왔다는 사실만으로는 락파일이 낡은 것으로 취급되지 않는다 |
| CI 검증 | `uv sync --locked` | 락파일이 최신이 아니면 다시 풀지 않고 에러를 낸다 |

도구를 한 번만 돌릴 때는 `uv run --frozen <도구>` 를 쓴다. `--frozen` 이 없으면 그 실행이
uv.lock 을 다시 써서 작업과 무관한 diff 가 남는다. `--locked` 는 락파일이 최신인지 검사하고
아니면 에러를 내며 `--frozen` 은 검사를 건너뛰고 락파일을 그대로 믿는다. 둘 다 환경 sync 는 한다.

`uv.lock` 은 커밋한다. 커밋하지 않으면 CI 가 매번 새로 해석해 "내 컴퓨터에서는 됐는데" 가
반복된다. 사람이 읽을 수 있는 TOML 이지만 uv 가 관리하는 파일이라 손으로 고치지 않는다.

아래는 몰라서 틀리는 것이 아니라 학습된 습관 때문에 되돌아가는 것들이다.

| 하지 않는 것 | 손이 가는 이유 | 실제로 벌어지는 일 |
|---|---|---|
| `pip install` | 학습 데이터의 기본값이라 자동으로 손이 간다 | 다른 환경에 설치되고 uv.lock 과 어긋난다 |
| `uv pip install` | uv 명령처럼 보여 안전해 보인다 | pyproject.toml 과 uv.lock 을 건드리지 않아 선언이 남지 않는다 |
| 맨 `python script.py` | 한 번 확인할 뿐이라 빨라 보인다 | 시스템 인터프리터를 잡아 다른 버전으로 돈다 |
| `pyproject.toml` 을 손으로 편집 | 한 줄만 고치면 되는 일로 보인다 | uv.lock 이 낡아 CI 가 다른 버전을 푼다 |
| 개발 도구를 `[project.optional-dependencies]` 에 선언 | extras 라는 이름이 개발용처럼 들린다 | pytest 나 ruff 가 사용자에게 배포되는 extras 로 새어 나간다 |

### 린트와 포맷: ruff

린터와 포매터를 ruff 하나로 합친다. 공식 문서 기준 대체 범위는 Flake8, Black, isort,
pydocstyle, pyupgrade, autoflake 다. 임포트 정렬도 별도 도구 없이 `I` 규칙에 맡긴다.

| 목적 | 명령 | 알아둘 점 |
|---|---|---|
| 포맷 | `uv run ruff format .` | 제자리에서 고친다. 고쳐도 종료 코드는 0 이라 CI 에서 변경 감지가 필요하면 `--exit-non-zero-on-format` |
| 포맷 검사 | `uv run ruff format --check .` | 쓰지 않고 대상만 알린다. 0 은 없음, 1 은 있음, **2 는 설정 오류** |
| 린트 | `uv run ruff check .` | 디렉터리는 재귀 탐색하고 `.gitignore` 를 따른다 |
| 자동 수정 | `uv run ruff check . --fix` | `--fix` 는 옵트인이다. 안전하지 않은 수정은 `--unsafe-fixes` 로 따로 켠다 |

CI 에서 종료 코드 2 를 1 과 같이 취급하지 않는다. 2 는 미포맷이 아니라 설정이 깨진 상태라,
합쳐 보면 설정 오류를 포맷 실패로 오인한다.

룰셋은 프로젝트마다 정한다. 실제 저장소가 갈리는 축은 큐레이션한 `select` 목록이냐,
`select = ["ALL"]` 후 `ignore` 로 깎느냐다. pydantic 과 MCP Python SDK 는 앞쪽,
Streamlit 은 뒤쪽이다. 표본이 셋뿐이라 다수를 말할 수 없으므로 하나를 권장하지 않는다.
다만 `select` 를 비워두는 곳은 없다.

**하위 옵션은 해당 룰 패밀리를 select 해야 살아난다.** pydantic 은 mccabe `max-complexity` 를
적어두고 `C901` 을 선택하지 않아 그 설정이 통째로 무효다. 설정을 적었으니 켜졌다고 가정하지 않는다.

줄 길이 같은 수치는 `pyproject.toml` 에 두고 문서나 리뷰 코멘트에 값을 옮겨 적지 않는다.
포매터가 감싸는 폭과 `E501` 이 허용하는 폭을 다르게 두는 방식도 있다. 주석, URL, 문자열
리터럴은 포매터가 흘려 넣지 못하므로 사람이 길게 남겨도 되는 폭을 따로 여는 것이다.

### 타입 검사: pyright

**기본 typeCheckingMode 는 standard 다. basic 이 아니다.** standard 는 1.1.339 에서
추가되면서 기본값이 되었다. 옛 자료를 따라 "기본이 basic 이니 올려야 한다" 고 판단하면
이미 켜져 있는 검사를 다시 켜는 설정을 쓰게 된다.

strict 가 standard 위에 얹는 것은 세 갈래다.

- 추론 엄격화 스위치 3개: `strictListInference`, `strictDictionaryInference`, `strictSetInference`
- 규칙 7개를 warning 에서 error 로 승격
- unknown 타입 계열 5개와 `reportMissingTypeStubs` 를 새로 켬. 나머지 모드에서는 전부 `none` 이다

거는 방식은 둘로 갈린다. 신규 코드베이스는 전역 `typeCheckingMode = "strict"` 를 걸고
디렉터리별로 완화하는 편이 손이 덜 가고, 이미 큰 코드베이스는 파일 허용목록으로 넓혀가는
편이 낫다. MCP Python SDK 가 앞쪽, pydantic 이 뒤쪽이다.

설정은 `pyrightconfig.json` 이나 `pyproject.toml` 의 `[tool.pyright]` 에 둔다. **둘 다 있으면
`pyrightconfig.json` 이 이기고 병합이 아니라 `[tool.pyright]` 를 아예 읽지 않는다.** 상위
디렉터리의 JSON 이 프로젝트의 toml 을 이기기도 하므로, 설정이 안 먹으면 위쪽에 JSON 이
있는지 먼저 본다.

검사기 선택은 아직 갈린다. 조사한 셋 중 MCP Python SDK 는 pyright 단독, pydantic 은 pyright
주력에 mypy 병행, Streamlit 은 pyright 없이 mypy 다. 이 환경에는 `pyright-lsp` 플러그인이
켜져 있어 편집 중 진단이 올라오지만, 프로젝트에 이미 검사기가 있으면 그쪽을 따른다.

### 테스트: pytest

`uv run pytest` 로 돌린다. 테스트 함수 이름은 무엇을 검증하는지 문장으로 적는다.
`test_load_config_raises_on_unknown_key` 처럼 이름만 읽고 실패 내용을 알 수 있게 한다.

특정 인터프리터로 확인할 때는 `uv run --frozen --python 3.10 pytest` 를 쓴다.
지원 최소 버전을 검증할 때는 `UV_PROJECT_ENVIRONMENT=.venv_310` 을 앞에 붙여 기본
`.venv` 를 건드리지 않게 한다.

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| 가변 기본 인자 `def f(xs: list = [])` | 기본값이 호출 간에 공유되어 이전 호출의 값이 남는다. `None` 을 받고 안에서 만든다 |
| 반환 타입에 `Sequence` 사용 | 호출자가 인덱싱 외의 연산을 못 한다. 반환은 구체 타입으로 준다 |
| `except Exception` 으로 광범위 포획 | 예상한 실패와 그 자리의 버그를 구분할 수 없다. 최상위 핸들러가 아니면 잡을 예외를 지정한다 |
| 보장된 키를 `.get()` 으로 접근 | 계약 위반이 `None` 으로 바뀌어 관련 없는 지점에서 터진다 |
| 예외 로깅에 `logger.error()` | 스택 트레이스가 사라져 원인 지점을 잃는다 |
| `uv pip install` 로 의존성 추가 | uv 명령처럼 보이지만 pyproject.toml 과 uv.lock 을 건드리지 않는다 |
| 도구를 맨 `python` 으로 실행 | 시스템 인터프리터를 잡아 다른 의존성 버전으로 돈다 |
| pyright 기본을 basic 으로 가정 | 기본은 standard 다. 이미 켜진 검사를 다시 켜는 설정이 된다 |
| select 없이 룰 하위 옵션만 설정 | 패밀리를 선택하지 않으면 그 설정은 통째로 무효다 |
| `ruff format --check` 의 2 를 실패로 처리 | 2 는 미포맷이 아니라 설정 오류다 |
| docstring 에 타입 반복 기재 | 시그니처와 어긋날 수 있다. 타입은 힌트에만 둔다 |
| 모듈 최상위에서 부수효과 실행 | import 만 해도 동작한다. `if __name__ == "__main__":` 아래로 내린다 |
