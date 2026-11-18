# DART x KRX 섹터 재무 분석 - SQL 포트폴리오

공시(DART)와 주가(거래소) 데이터를 5개 테이블로 적재하고, **정제부터 분석까지 SQL로만** 처리한 프로젝트입니다.
투자 실무에서 실제로 던지는 7개 질문(섹터 내 수익성 순위, 연말 밸류에이션, 턴어라운드 스크리닝 등)에 답합니다.

| 항목 | 내용 |
|---|---|
| 대상 | 국내 상장 13개사 - 인터넷플랫폼 4 · IT인프라/SaaS 5 · 게임 4 |
| 데이터 | 연결 재무제표 FY2020~2025, 일별 주가 2023~2025, 주요사항보고서 2023~2025 |
| 엔진 | SQLite (3.35 이상, 3.50.4에서 실행). 표준 SQL 위주, SQLite 전용 함수는 주석으로 표시 |
| 규모 | 테이블 5개, SQL 9개 파일(약 590줄), 분석 쿼리 7개 |

## 결과물

| 결과물 | 위치 | 내용 |
|---|---|---|
| 분석 결과 7건 | [`results/`](results/) | 질문별 md 1개: 질문·기법 주석 + 결과 표 + 실행한 SQL 전문 |
| 분석 DB | `dart_sector.db` | 정제 완료된 SQLite 파일. 클론 후 바로 쿼리 가능 |
| SQL | [`sql/`](sql/) | 테이블 정의, 정제, 분석 쿼리 q1~q7 |
| 구조 설명 | [`docs/SQL_STRUCTURE.md`](docs/SQL_STRUCTURE.md) | 파이프라인·정제 단계·ERD 도식, 쿼리별 기법 표 |
| 원천 데이터 | [`data/raw/`](data/raw/) | API 응답 형태 그대로의 CSV 8개 (재현용) |

## 핵심 결과

**사실**은 결과 표 수치, **추론**은 해석입니다. 상세는 각 링크의 결과 파일에 있습니다.

| # | 질문 | 핵심 결과 |
|---|---|---|
| [Q1](results/q1_margin_rank_yoy.md) | 섹터 안에서 누가 가장 수익성이 좋은가 | FY2025 영업이익률 1위: 크래프톤 31.7%(게임), 더존비즈온 28.6%(IT인프라/SaaS), SOOP 26.8%(플랫폼) |
| [Q2](results/q2_yearend_valuation.md) | 2025년 말 밸류에이션은 | PER 최저 헥토이노베이션 5.7배, 최고 카카오 51.4배. ROE 최고 SOOP 20.6% |
| [Q3](results/q3_sector_share_cagr.md) | 5년간 누가 섹터 점유율을 늘렸나 | 크래프톤 게임 섹터 매출 비중 23.6% → 40.9%, NC 34.2% → 18.5% |
| [Q4](results/q4_turnaround_health.md) | 흑자·적자전환 기업과 재무건전성 | FY2025 흑자전환 NC·NHN, 적자전환 카카오게임즈. NC는 건전성 조건 충족 |
| [Q5](results/q5_price_return_vs_profit.md) | 2025년 주가는 이익을 따라갔나 | 넷마블(영업이익 +63.5%, 주가 -4.6%)과 SOOP이 '이익↑ 주가↓' 괴리 |
| [Q6](results/q6_data_quality.md) | 데이터를 믿을 수 있나 | 자산 = 부채 + 자본 78행 전부 일치. 주가 누락은 상장폐지 1사뿐 |
| [Q7](results/q7_filings_vs_price_range.md) | 공시가 많은 해에 주가도 크게 움직였나 | 주요사항보고서 71건 중 59건이 자기주식 관련. 건수와 변동폭은 뚜렷한 관계 없음 |

## SQL로 한 것

| 작업 | 쓴 기법 | 위치 |
|---|---|---|
| 테이블 설계 | 원천 그대로 받는 staging(`stg_*`)과 분석용 테이블 분리, PK·FK·UNIQUE·CHECK 제약 | `sql/01_schema.sql` |
| 문자열 금액 정제 | `"1,234"` / `"-"` → 정수·NULL (`CASE`, `REPLACE`, `CAST`) | `sql/02_load_clean.sql` |
| 가로 ↔ 세로 변환 | 3개년 열 → 연도별 행 (`UNION ALL`), 계정 행 → 열 (`MAX(CASE ...)` + `GROUP BY`) | `sql/02_load_clean.sql` |
| 중복 제거 | 정정공시 우선 1건 (`ROW_NUMBER() OVER (... ORDER BY rcept_no DESC)`) | `sql/02_load_clean.sql` |
| 여러 테이블 결합 | 재무·주가·주식수·공시 4계열을 `companies` 를 통해 JOIN. 결측 행은 `LEFT JOIN` 으로 유지 | q2, q5, q7 |
| 윈도우 함수 | `LAG`, `RANK`, `ROW_NUMBER`, `FIRST_VALUE`/`LAST_VALUE`, `SUM() OVER (PARTITION BY)` | q1~q5, q7 |
| 품질 점검 | 회계 항등식, 결측 탐지(`LEFT JOIN ... IS NULL`), 거래일 수 비교를 `UNION ALL` 로 한 표에 | q6 |

```mermaid
flowchart LR
    A["원천 CSV 8개<br/>API 응답 그대로"] --> B["staging 테이블<br/>stg_*"]
    B -->|"02_load_clean.sql"| C["분석 테이블 5개"]
    C -->|"q1~q7"| D["results/*.md"]
```

정제 단계별 예시와 ERD는 [`docs/SQL_STRUCTURE.md`](docs/SQL_STRUCTURE.md)에 있습니다.

## 데이터

| 테이블 | 원천 | 행 수 | 키 |
|---|---|---|---|
| `companies` | 직접 작성 (섹터 분류는 작성자 기준) | 13 | corp_code (PK), stock_code (UQ) |
| `financials_annual` | DART 다중회사 주요계정 API, 사업보고서 FY2025·FY2022 | 78 (13사 x 6년) | corp_code + fiscal_year + fs_div |
| `prices_daily` | yfinance (KOSPI .KS / KOSDAQ .KQ) | 8,760 (12사 x 730일) | stock_code + trade_date |
| `shares_outstanding` | KRX 상장종목 목록 + 수기 보충 1건 | 13 | stock_code |
| `filings` | DART 공시목록 API, 주요사항보고서 2023~2025 | 86 (정정 15건 포함) | rcept_no |

```
companies 1 ──< financials_annual     (corp_code)
companies 1 ──< prices_daily          (stock_code)
companies 1 ──1 shares_outstanding    (stock_code)
companies 1 ──< filings               (corp_code)
```

`companies` 가 DART 키(`corp_code`)와 거래소 키(`stock_code`)를 모두 가지고 있어서, 공시 계열 테이블과 주가 계열 테이블을 잇는 역할을 합니다.

## 질문별 상세

<details>
<summary>Q1~Q7 사실 / 계산 / 추론 전체 보기</summary>

### Q1. 섹터 내 영업이익률 순위와 YoY 성장 - [q1](results/q1_margin_rank_yoy.md)
기법: JOIN, LAG, RANK() OVER (PARTITION BY sector)
- 사실: FY2025 섹터별 영업이익률 1위는 더존비즈온 28.6%, 크래프톤 31.7%, SOOP 26.8%
- 사실: 게임 섹터는 크래프톤(22.8%)·넷마블(6.4%) 외 2사 매출 역성장, 카카오게임즈 -25.9%
- 추론: IT인프라/SaaS는 삼성SDS를 빼면 4사 매출 성장률이 +10.9~18.9%로 비슷하고, 차이는 마진에서 난다

### Q2. 연말 시가총액·PER·PBR - [q2](results/q2_yearend_valuation.md)
기법: ROW_NUMBER로 연도별 마지막 거래일 추출, 3테이블 JOIN, LEFT JOIN으로 결측 유지
- 계산: 시가총액 = 2025-12-30 종가 x 주식수, PER = 시가총액 / FY2025 순이익, PBR = 시가총액 / 자본총계
- 사실: PER 최저는 헥토이노베이션 5.7배(PBR 0.6배), 최고는 카카오 51.4배. ROE 최고는 SOOP 20.6%
- 주의: 주식수는 수집 시점(2026-11) 기준이라 과거 연도 시가총액은 근사치. 더존비즈온은 2026-07 상장폐지로 주가가 없어 NULL (LEFT JOIN으로 행은 유지)

### Q3. 섹터 합산 비중 변화와 5년 CAGR (FY2020 → FY2025) - [q3](results/q3_sector_share_cagr.md)
기법: SUM() OVER (PARTITION BY), POWER()를 이용한 CAGR
- 사실: 크래프톤은 게임 섹터 매출 비중이 23.6% → 40.9%(+17.3%p), 섹터 영업이익의 74.1% 차지
- 사실: NC는 같은 기간 게임 섹터 매출 비중 34.2% → 18.5%(-15.7%p), 매출 CAGR -9.0%로 유일한 큰 폭 역성장
- 사실: NAVER는 플랫폼 섹터 매출 비중 47.3% → 52.1%, 매출 CAGR 17.8%, 영업이익 비중 69.1%
- 계산: CAGR = (FY2025 매출 / FY2020 매출)^(1/5) - 1
- 추론: 두 섹터 모두 1위 기업으로의 이익 집중이 매출 집중보다 훨씬 강하다 - 규모의 경제보다 사업 믹스 차이로 보임

### Q4. 흑자전환·적자전환 스크리닝 + 재무건전성 - [q4](results/q4_turnaround_health.md)
기법: LAG + CASE 상태 라벨, 다중 조건 플래그
- 사실: FY2025 흑자전환은 NC(-109.2 → 16.1십억), NHN(-32.6 → 132.4십억). 적자전환은 카카오게임즈
- 사실: NC는 부채비율 28.6%, 유동비율 353.5%로 건전성 플래그 충족
- 추론: NC는 영업이익(16십억)보다 순이익(347십억)이 훨씬 커서 영업외 이익이 실적을 만든 해 - 턴어라운드 품질은 따로 봐야 한다

### Q5. 2025년 주가 수익률 vs 영업이익 변화 - [q5](results/q5_price_return_vs_profit.md)
기법: FIRST_VALUE / LAST_VALUE, WINDOW 절, 일별 → 연간 집계 후 재무 JOIN
- 사실: 주가 수익률 상위는 가비아 +87.5%, NHN +65.2%, 카카오 +60.5%. 하위는 SOOP -24.8%, 크래프톤 -22.3%
- 사실: '이익↑ 주가↓' 괴리는 넷마블(영업이익 +63.5%, 주가 -4.6%)과 SOOP(+10.0%, -24.8%)
- 추론: 13개 표본 1개 연도라 통계적 결론은 불가. 괴리 종목을 추가 조사 대상으로 뽑는 1차 필터 용도

### Q6. 데이터 품질 점검 - [q6](results/q6_data_quality.md)
기법: UNION ALL로 점검 묶기, LEFT JOIN + IS NULL, HAVING
- 사실: 자산 = 부채 + 자본 항등식은 78행(13사 x 6년) 전부 ±2백만원 안에서 일치
- 사실: 더존비즈온 주가 누락 1건(상장폐지), 나머지 12사는 거래일 730일로 동일

### Q7. 주요사항보고서 건수 vs 주가 변동폭 - [q7](results/q7_filings_vs_price_range.md)
기법: 회사 x 연도 뼈대(CROSS JOIN) + LEFT JOIN으로 공시 0건 연도 유지, CASE 조건부 집계로 공시 유형 분류, RANK() OVER (PARTITION BY 연도)
- 사실: 정정공시를 뺀 주요사항보고서 71건 중 59건이 자기주식 취득·처분·신탁 관련
- 사실: 연도별 변동폭 1위는 NC(2023, 124.2%), 케이아이엔엑스(2024, 101.5%), 가비아(2025, 124.5%) - 그 해 주요사항보고서는 각각 0건, 0건, 1건
- 사실: 3년간 공시가 가장 많은 카카오(8·7·3건)는 변동폭 순위 5·3·2위
- 계산: 변동폭 = (연중 최고 종가 - 최저 종가) / 최저 종가
- 추론: 주요사항보고서 대부분이 자기주식 관련 정례 공시라 건수 자체는 주가 변동의 설명 변수가 되기 어렵다. 자금조달(사채·증자)·구조변경(합병·분할·감자)만 따로 보는 편이 의미 있음

</details>

## 실행 방법

```bash
pip install -r requirements.txt
python scripts/build_db.py         # CSV -> dart_sector.db (기존 DB 삭제 후 재생성)
python scripts/run_queries.py      # sql/q*.sql 실행 -> results/*.md
```

DB만 열어 보려면 빌드 없이 `sqlite3 dart_sector.db` 로 바로 쿼리할 수 있습니다.

데이터 재수집(선택, 네트워크 필요):
- 주가·주식수: `python scripts/fetch_prices.py`
- 재무: OpenDART API 키를 환경변수 `DART_API_KEY` 로 두고 `python scripts/fetch_dart.py 2019` 처럼 실행한 뒤 `scripts/build_db.py` 의 `CSV_TO_STAGING` 에 파일을 등록

## 데이터 처리 메모와 한계

- FY2022 사업보고서의 주요계정 API에는 카카오·크래프톤·카카오게임즈의 매출액 행이 없습니다(손익계산서 계정명이 '영업수익'). 같은 보고서의 전체 재무제표 API '영업수익' 값을 `dart_revenue_supplement_fy2022.csv` 에 원형 그대로 옮겨 적재했습니다. `fetch_dart.py` 로 다른 연도를 받을 때도 같은 결측이 생길 수 있습니다.
- 카카오 FY2022 값은 2024-03 정정 사업보고서(20240320000393) 기준입니다.
- 주식수는 수집 시점(2026-11-18) 기준이라 과거 연도 시가총액은 근사치입니다.
- 더존비즈온은 2026-07 상장폐지로 주가가 없습니다. 주식수는 사업보고서 자본금 / 액면가로 추정해 보충했지만(31,477,993주), 주가가 없어 Q2 밸류에이션은 NULL로 남습니다.
- 섹터 분류는 작성자 기준입니다(삼성SDS를 IT인프라/SaaS에 넣은 것은 논쟁 여지가 있음).
- 13개사 표본이라 통계적 결론은 내지 않습니다. 결과는 추가 조사 대상을 고르는 1차 필터 용도입니다.
- PostgreSQL 실행은 검증하지 않았습니다.

## 폴더 구조

```
dart-sql-portfolio/
├── README.md
├── CLAUDE.md                 # Claude Code 작업 규칙·진행 상황
├── docs/
│   ├── PLAN.md               # 기획 문서
│   └── SQL_STRUCTURE.md      # SQL 구현 구조 도식
├── requirements.txt / .env.example / .gitignore
├── dart_sector.db            # 빌드 결과 (재생성 가능)
├── data/raw/
│   ├── companies.csv                       # 회사 마스터 (섹터 분류)
│   ├── dart_key_accounts_fy2025.csv        # DART 주요계정 원형 FY2023~2025
│   ├── dart_key_accounts_fy2022.csv        # DART 주요계정 원형 FY2020~2022
│   ├── dart_revenue_supplement_fy2022.csv  # 매출액 행이 빠진 3사 보충
│   ├── filings.csv                         # 주요사항보고서 목록 2023~2025
│   ├── prices_daily.csv                    # 일별 주가
│   ├── shares_outstanding.csv              # KRX 주식수
│   └── shares_manual.csv                   # 주식수 수기 보충 (근거 포함)
├── scripts/
│   ├── fetch_dart.py         # OpenDART API (DART_API_KEY 필요)
│   ├── fetch_prices.py       # yfinance + KRX 목록
│   ├── build_db.py           # CSV -> SQLite
│   └── run_queries.py        # q*.sql -> results/*.md
├── sql/
│   ├── 01_schema.sql         # staging / 분석용 테이블
│   ├── 02_load_clean.sql     # 정제 (UNPIVOT·형변환·중복제거·PIVOT)
│   └── q1 ~ q7 *.sql         # 분석 쿼리 (질문·기법 주석 포함)
└── results/                  # 쿼리별 결과 표 + SQL
```

## 출처

- 재무제표: 금융감독원 DART 다중회사 주요계정 (fnlttMultiAcnt), 사업보고서 기준. 숫자별 접수번호는 `financials_annual.source_rcept_no`
- 공시 목록: 금융감독원 DART 공시검색 (list.json, pblntf_ty=B), 최종보고서 기준
- 주가: Yahoo Finance (yfinance)
- 주식수: KRX 상장종목 목록 (FinanceDataReader), 2026-11-18 기준
- 더존비즈온 상장폐지(2026-07-15): EQT파트너스 공개매수 후 주식교환, 언론 보도 기준
