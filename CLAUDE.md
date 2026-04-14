# General Principles
- 확실하지 않은 정보는 추측하지 말고 모른다고 하거나 검색해

# Git Workflow

## Commit 규칙
> 프로젝트의 **atomic-commit** 스킬에 상세 정의. Conventional Commits + atomic commit 원칙.

- **하나의 커밋 = 하나의 논리적 변경**. 한꺼번에 몰아서 커밋 금지.
- 테스트가 통과한 직후 커밋 (Green → Commit)
- 위험한 변경을 시도하기 전에 안정 상태를 먼저 커밋

## 브랜치 전략: GitHub Flow
- `main` 브랜치는 항상 배포 가능한 상태 유지
- 기능 개발은 feature 브랜치에서 진행
- 브랜치 수명: 최대 1~2일 (길어지면 작은 PR로 분리)
- 브랜치 네이밍: `feat/기능명`, `fix/버그명`, `test/테스트명`, `chore/작업명`
- main으로 머지 시 squash-merge 또는 rebase로 히스토리를 깔끔하게 유지
- 머지 후 feature 브랜치 삭제

## 절대 커밋하지 않을 것
- 시크릿 (.env, API 키, 인증 정보)
- 빌드 산출물 (.build/, DerivedData/)
- 생성된 파일 (node_modules/, .pyc)

# Coding Standards
> 프로젝트의 **implementation** 스킬에 정의. 함수형 스타일, YAGNI, 타입 명시, SOLID 등.
> Python 프로젝트의 경우 **stack-python** 스킬 참조 (해당 스킬 존재 시).

- 코드를 수정할 때 trailing space를 만들지 않도록 해
- Ask questions to clarify any unclear parts
- Stop and ask before proceeding to the next step after completing the instructed amount

# 문서 리뷰시
- 말투나 어미 톤과 매너는 그대로 유지해
- 단어나 문장의 어색함 등이 감지되는 경우 수정해
- 고급스럽고 업무적으로 formal한 형태로 수정해줘.

# Communication Style
- 기술적 설명 시 단계별로 구조화해서 설명
- 예시 코드 제공 시 주석으로 설명 추가
- 대안이 있는 경우 간략하게 언급

# Debugging & Problem Solving
- 문제에 대한 원인 파악을 우선할 것
- 문제를 회피하지 말고 근본적인 해결책을 우선
- 에러 메시지 분석 시 원인과 해결책을 명확히 구분
- 여러 해결 방법이 있는 경우 장단점 비교
- 성능이나 보안에 영향을 주는 부분은 별도 언급

# 추가 고려사항
- 라이브러리나 프레임워크 추천 시 최신 버전 기준으로 안내
- 베스트 프랙티스와 안티 패턴 구분해서 설명
