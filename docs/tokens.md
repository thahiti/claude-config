# 스킬이 요구하는 환경변수

일부 스킬은 외부 서비스를 호출하므로 토큰이 필요하다. 토큰은 리포에 넣지 않고
셸 프로필에 둔다. 값이 비어 있으면 스킬은 첫 API 호출에서 실패한다.

`/claude-config-doctor` 가 이 목록의 설정 여부를 점검한다.

## 목록

| 환경변수 | 쓰는 스킬 | 성격 |
|---|---|---|
| `CLICKUP_API_TOKEN` | clickup-task | 시크릿 |
| `CLICKUP_SPACE_ID` | clickup-task | 식별자 |
| `GITLAB_TOKEN` | gitlab-mr-review | 시크릿 |

## 등록 방법

`~/.zshrc` 가 아니라 `~/.zshenv` 에 넣는다. Claude Code 가 훅이나 백그라운드에서
비대화형 셸을 띄울 때 `~/.zshrc` 는 읽히지 않는 경우가 있다.

```bash
# ~/.zshenv
export CLICKUP_API_TOKEN="pk_..."
export CLICKUP_SPACE_ID="9018..."
export GITLAB_TOKEN="glpat-..."
```

파일 권한을 좁힌다. 시크릿이 들어가므로 다른 사용자가 읽을 이유가 없다.

```bash
chmod 600 ~/.zshenv
```

등록 후 새 셸을 열거나 `source ~/.zshenv` 로 반영한다. 이미 떠 있는 Claude Code
세션에는 적용되지 않으므로 재시작한다.

## 발급 절차

### CLICKUP_API_TOKEN

ClickUp 웹에서 우측 하단 프로필 아바타 → **Settings** → **Apps** → **API Token**
에서 Personal API Token 을 생성한다. `pk_` 로 시작하는 문자열이다.

Personal Token 은 계정 권한 전체를 그대로 가진다. 워크스페이스를 나눠 쓰거나
자동화를 남에게 넘길 일이 있으면 Personal Token 대신 OAuth 앱을 쓰는 편이 맞다.

### CLICKUP_SPACE_ID

토큰을 먼저 등록한 뒤 조회한다.

```bash
# 1. 팀(워크스페이스) 목록
curl -s "https://api.clickup.com/api/v2/team" -H "Authorization: $CLICKUP_API_TOKEN" \
  | python3 -c "import sys,json; [print(t['id'], t['name']) for t in json.load(sys.stdin)['teams']]"

# 2. 해당 팀의 Space 목록
curl -s "https://api.clickup.com/api/v2/team/<TEAM_ID>/space?archived=false" \
  -H "Authorization: $CLICKUP_API_TOKEN" \
  | python3 -c "import sys,json; [print(s['id'], s['name']) for s in json.load(sys.stdin)['spaces']]"
```

웹 URL 에서도 읽을 수 있다. Space 를 연 주소의 `/v/o/s/<SPACE_ID>` 부분이다.

### GITLAB_TOKEN

GitLab 에서 **User Settings** → **Access Tokens** 에서 Personal Access Token 을
발급한다. `glpat-` 로 시작한다.

scope 는 용도에 따라 다르다.

| 용도 | 필요한 scope |
|---|---|
| MR 조회와 diff 읽기 | `read_api` |
| 리뷰 결과를 MR 코멘트로 작성 | `api` |

기본은 터미널 출력이므로 `read_api` 로 충분하다. 코멘트 작성까지 하려면 `api` 가
필요한데, `api` 는 쓰기 권한 전체를 포함하므로 만료일을 짧게 잡는다.

## 토큰이 유출됐을 때

1. 발급처에서 해당 토큰을 즉시 폐기한다. 새 토큰 발급보다 폐기가 먼저다.
2. `~/.zshenv` 에서 값을 지우고 새 토큰으로 교체한다.
3. 셸 히스토리에 남았는지 확인한다. `grep -n 'pk_\|glpat-' ~/.zsh_history`
4. 리포 히스토리에 들어갔으면 폐기만으로는 부족하다. 커밋을 다시 쓰고 강제 푸시해야 한다.
