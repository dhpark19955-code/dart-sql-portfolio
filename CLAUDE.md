# CLAUDE.md - dart-sql-portfolio

SQL 포트폴리오 프로젝트. 배경과 설계는 `docs/PLAN.md`, 결과 설명은 `README.md`.

## 실행 순서 (항상 이 순서)

```bash
pip install -r requirements.txt
python scripts/build_db.py        # dart_sector.db 재생성 (기존 DB 삭제 후 빌드)
python scripts/run_queries.py     # results/*.md 재생성
```

SQL을 고쳤으면 `run_queries.py` 를 다시 돌려 `results/` 를 갱신하고, README의 수치가 바뀌면 README도 같이 고친다.

## 규칙

- 시크릿: OpenDART 키는 환경변수 `DART_API_KEY` 로만. 코드·CSV·README에 키 원문을 쓰지 않는다. `.env` 는 gitignore 대상.
- 데이터: 공개 데이터(DART·KRX·yfinance)만 사용. 사내 자료나 포지션 정보는 넣지 않는다.
- 금액 단위: DB는 백만원(`financials_annual`), 결과 표시는 십억원(`/1000.0`). 음수는 `-` 로 표기, △ 사용 금지.
- 문장 부호: em dash(—) 대신 하이픈(-).
- SQL 스타일: 각 `sql/q*.sql` 상단에 `-- Q번호. 질문 / 기법 / 주의` 주석을 유지한다 (`run_queries.py` 가 이 주석을 결과 md 머리말로 가져간다). 0 나눗셈은 `NULLIF`. 표준 SQL 우선, SQLite 전용 함수는 주석으로 표시.
- 원천 CSV(`data/raw/dart_key_accounts_fy*.csv`)는 API 응답 형태(콤마 포함 금액 문자열, 3개년 wide)를 그대로 둔다. 정제는 `sql/02_load_clean.sql` 에서만 한다.
- 새 연도 CSV를 추가하면 `scripts/build_db.py` 의 `CSV_TO_STAGING` 에 등록해야 적재된다.
- 결과 해석을 쓸 때는 사실(표 수치) / 계산(식) / 추론(해석)을 구분해 표기한다.

## 진행 상황

완료 (2026-11-18)
- [x] 연도 확장: FY2020~2025 6개년 (`dart_key_accounts_fy2022.csv`, 키 대신 MCP 경유로 수집). 연도가 겹치지 않아 dedup 혼입 없음 확인 (78행, 결측 0)
- [x] 매출액 보충: FY2022 주요계정 API에 매출액이 없는 카카오·크래프톤·카카오게임즈는 `dart_revenue_supplement_fy2022.csv` (전체 재무제표 API '영업수익')
- [x] filings 테이블 + q7 (`filings.csv` 86건, 정정 15건은 `is_amendment=1`)
- [x] 더존비즈온 주식수 보완 (`shares_manual.csv`, `shares_outstanding.source` 컬럼). q2 NULL 은 주가가 없어 유지
- [x] README 3절 수치 재확인 (q3 기간 변경 반영, Q1 추론 문구 정정, Q7 추가)

남은 작업
1. **GitHub 배포 (새 public 레포 `dart-sql-portfolio`)**: 사용자가 2026-11-18 "새 레포로 push" 승인. 대상 계정 = `dhpark19955-code`(사용자 지정).
   **2026-11-18 push 완료**: https://github.com/dhpark19955-code/dart-sql-portfolio (public, main). 작성자 = 이 계정 noreply(로컬 설정만), origin 에 계정명 포함. 이후 수정분은 `git push` 만 하면 된다(자격증명은 Git Credential Manager 에 저장됨).
   아래 gh 경로는 더 이상 필요 없음(참고용).
   다음 세션 절차:
   - 사용자가 직접: `winget install --id GitHub.cli -e` → 새 터미널에서 `gh auth login` (브라우저 로그인은 사용자 몫, Claude 가 대신 하지 않는다)
   - 그다음 이 폴더에서:

```bash
powershell -ExecutionPolicy Bypass -File .\publish_github.ps1 -DryRun
```

```bash
powershell -ExecutionPolicy Bypass -File .\publish_github.ps1
```

   - `publish_github.ps1` 이 하는 일: gh 로그인 확인 → 이 레포에만 커밋 작성자를 GitHub noreply 주소로 설정(전역 git 설정은 건드리지 않음) → 스테이징 파일에서 키 원문 검사(걸리면 중단) → 첫 커밋 → `gh repo create dart-sql-portfolio --public --source . --push`. 이름 충돌 시 `-Name 다른이름`, 비공개는 `-Visibility private`
   - 스크립트 자체는 `.gitignore` 로 레포에서 제외. `.git` 은 이미 init·스테이징만 된 상태(커밋 없음)
   - 2026-11-18 가짜 gh 로 사본에서 시험 완료(정상 경로·origin 기존 경로·키 원문 차단). 실제 GitHub 생성·push 는 미검증

2. (선택) PostgreSQL 호환성: q7 의 `PARTITION BY yr, range_pct IS NULL`, `SUBSTR` 등은 Postgres 에서도 동작하지만 실제 검증은 안 함.

## 파일 역할 요약

| 경로 | 역할 |
|---|---|
| `scripts/fetch_dart.py` | OpenDART 다중회사 주요계정 → raw CSV (키 필요, 매출액 계정명이 다른 회사는 보충 CSV 필요) |
| `scripts/fetch_prices.py` | yfinance 일별 주가 + KRX 주식수 → raw CSV |
| `scripts/build_db.py` | raw CSV → SQLite staging → 정제 테이블 |
| `scripts/run_queries.py` | `sql/q*.sql` 실행 → `results/*.md` |
| `sql/01_schema.sql` | 테이블 정의 |
| `sql/02_load_clean.sql` | UNPIVOT·형변환·PIVOT·중복제거·단위통일 |
| `sql/q1~q7` | 분석 쿼리 |
