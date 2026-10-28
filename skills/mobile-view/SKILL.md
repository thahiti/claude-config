---
name: mobile-view
description: Use when the user wants to read work results (reports, translations, markdown, code) on their phone, asks for a tailscale or mobile link to files Claude wrote, wants another repository added to that phone view, or invokes /mobile-view
---

# Mobile View

## Overview

`/Users/randy/claude_code/mobile-viewer/` 의 읽기 전용 FastAPI 뷰어에 작업 디렉터리를 하나
이상 붙이고, tailnet 안에서만 열리는 링크를 휴대폰으로 보낼 수 있게 만든다.
뷰어는 마크다운 렌더링, 코드 하이라이트, Mermaid, 다크 모드를 지원하고 파일이 바뀌면
3초 안에 화면이 따라온다.
서버는 127.0.0.1 에만 바인딩하고 외부 노출은 `tailscale serve` 가 맡는다.

## 사전 조건

- Mac 에 Tailscale 앱이 로그인돼 있고 휴대폰도 같은 tailnet 에 연결돼 있다.
- `uv` 가 설치돼 있다.

## 실행

```bash
bash ~/claude-config/skills/mobile-view/scripts/viewer.sh start <디렉터리>...
bash ~/claude-config/skills/mobile-view/scripts/viewer.sh add <디렉터리>
bash ~/claude-config/skills/mobile-view/scripts/viewer.sh status
bash ~/claude-config/skills/mobile-view/scripts/viewer.sh stop
```

- `start` 는 떠 있는 뷰어를 내리고 지정한 디렉터리들만 루트로 다시 띄운 뒤 `url:` 줄에 링크를 출력한다.
- `add` 는 지금 보이는 루트 목록에 디렉터리를 하나 더해 다시 띄운다.
  사용자가 "이 저장소도 폰에서 보게 해 줘" 라고 하면 `start` 가 아니라 `add` 를 쓴다.
- 루트는 사용자가 읽을 파일이 들어 있는 가장 좁은 디렉터리로 잡는다.
  보통 프로젝트 루트면 충분하고, 홈 디렉터리 전체를 루트로 잡지 않는다.
- 트리 맨 위에는 루트가 디렉터리 이름으로 나란히 보인다.
  이름이 같은 디렉터리 둘은 한 번에 붙일 수 없다.

## 링크 전달

사용자에게는 루트 링크가 아니라 **읽을 파일을 바로 여는 링크**를 준다.
형식은 `url` 뒤에 `#/`, 루트 디렉터리 이름, 루트 기준 상대 경로를 붙인 것이다.

```
http://mac-mini.taila50133.ts.net/#/harness-research/translation-guide.md
```

링크와 함께 아래 두 가지를 한 줄씩 덧붙인다.

- 휴대폰의 Tailscale 이 켜져 있어야 열린다.
- 호스트 이름으로만 열린다. `100.x.x.x` 숫자 주소로 열면 404 가 난다.

## 알아둘 점

| 항목 | 내용 |
|---|---|
| 뷰어는 하나 | 포트 7777 하나를 쓰므로 `start` 는 이전 루트 목록을 지운다. 보태려면 `add` |
| 재부팅 | 뷰어 프로세스는 꺼지고 `tailscale serve` 설정만 남는다. `start` 를 다시 실행한다 |
| HTTP 인 이유 | 계정에 HTTPS 인증서가 없어 기본 serve(443) 가 인증서를 기다리며 멈춘다. 그래서 `--http=80` 으로 건다 |
| serve 해제 | `tailscale serve --http=80 off` |
| 제외 대상 | `.git`, `node_modules`, `__pycache__`, `.venv` 는 트리에 나오지 않고 1MB 초과 파일과 바이너리는 다운로드로만 보인다 |
| 로그 | `/tmp/mobile-viewer.log`, 현재 루트 목록은 `/tmp/mobile-viewer.roots` |
| 읽던 위치 | 파일마다 휴대폰 브라우저에 저장된다. 루트 링크로 들어가면 마지막 파일이 그 자리에서 열린다 |

## Common Mistakes

| 실수 | 왜 문제인가 |
|---|---|
| 루트 링크만 주고 끝냄 | 사용자가 트리에서 파일을 찾아야 한다. 파일 딥링크를 준다 |
| 딥링크에 루트 이름을 빼먹음 | `#/docs/a.md` 는 404 다. `#/<루트이름>/docs/a.md` 로 쓴다 |
| 저장소를 보태야 하는데 `start` 사용 | 먼저 보던 저장소가 트리에서 사라진다. `add` 를 쓴다 |
| `tailscale serve --bg 7777` 을 직접 실행 | HTTPS 인증서가 없어 출력 없이 멈춘다. 스크립트를 쓴다 |
| 숫자 IP 로 링크 작성 | serve 가 Host 이름으로 경로를 찾아 404 가 난다 |
| 홈 디렉터리를 루트로 지정 | 트리가 너무 커지고 관계없는 파일까지 tailnet 에 노출된다 |
| 서버를 직접 `uv run app.py` 로 띄움 | `.env` 의 루트로 뜨고 기존 프로세스와 포트가 충돌한다 |
