# DART x KRX 섹터 재무 분석 - SQL 포트폴리오

공개 데이터(DART 전자공시, 거래소 주가)를 여러 테이블로 적재하고 SQL만으로 결합·정제·분석한 프로젝트입니다.
"여러 테이블을 JOIN해 필요한 데이터를 직접 추출·가공한다"는 작업을, 투자 실무에서 실제로 하는 질문(섹터 내 수익성 순위, 연말 밸류에이션, 턴어라운드 스크리닝)으로 보여주는 것이 목적입니다.

- 대상: 국내 상장 인터넷플랫폼 4사 · IT인프라/SaaS 5사 · 게임 4사, 총 13개사
- 기간: FY2020~FY2025 연결 재무제표(사업보고서 2건), 2023~2025 일별 주가, 2023~2025 주요사항보고서
- 엔진: SQLite 3.45 (window function, CTE, math 함수 사용) - PostgreSQL로 옮겨도 그대로 동작하도록 표준 SQL 위주로 작성

## 1. 데이터와 ERD

| 테이블 | 원천 | 행 수 | 키 |
|---|---|---|---|
| `companies` | 직접 작성 (섹터 분류는 본인 기준) | 13 | corp_code (PK), stock_code (UQ) |
| `financials_annual` | DART 다중회사 주요계정 API, 사업보고서(11011) FY2025·FY2022 | 78 (13사 x 6년) | corp_code + fiscal_year + fs_div |
| `prices_daily` | yfinance (KOSPI .KS / KOSDAQ .KQ) | 8,760 (12사 x 730일) | stock_code + trade_date |
| `shares_outstanding` | KRX 상장종목 목록 (수집 시점 기준) + 수기 보충 1건 | 13 | stock_code |
| `filings` | DART 공시목록 API(list.json), 주요사항보고서(B) 2023~2025 | 86 (정정 15건 포함) | rcept_no |

```
companies 1 ──< financials_annual     (corp_code)
companies 1 ──< prices_daily          (stock_code)
companies 1 ──1 shares_outstanding    (stock_code)
companies 1 ──< filings               (corp_code)
```

원천 CSV는 `data/raw/` 에 API 응답 형태 그대로(금액은 `"1,234,567"` 문자열, 당기/전기/전전기 3컬럼) 두고,
`sql/02_load_clean.sql` 에서 UNPIVOT → 형변환 → PIVOT → 중복제거 → 단위통일(백만원)을 SQL로 처리합니다.

FY2022 사업보고서의 주요계정 API 응답에는 카카오·크래프톤·카카오게임즈의 매출액 행이 없습니다(손익계산서 계정명이 '영업수익').
이 3사는 같은 보고서의 전체 재무제표 API(fnlttSinglAcntAll) '영업수익' 값을 `dart_revenue_supplement_fy2022.csv` 에
같은 원형으로 옮겨 적재했습니다. 카카오 FY2022 값은 2024-03 정정 사업보고서(20240320000393) 기준입니다.

## 2. 실행 방법

```bash
pip install -r requirements.txt
python scripts/fetch_prices.py     # 주가·주식수 재수집 (선택, 네트워크 필요)
python scripts/build_db.py         # CSV -> dart_sector.db (schema + load/clean)
python scripts/run_queries.py      # sql/q*.sql 실행 -> results/*.md
```

DART 재무 데이터를 다른 연도로 늘리려면 OpenDART API 키를 환경변수 `DART_API_KEY` 로 두고
`python scripts/fetch_dart.py 2019` 처럼 실행한 뒤 `build_db.py` 의 `CSV_TO_STAGING` 에 파일을 추가합니다.
(fetch_dart.py 는 매출액 계정명이 다른 회사를 보충하지 않으므로, 결측이 생기면 위 보충 CSV 방식으로 채웁니다.)

## 3. 질문과 결과 요약

전체 결과 표와 SQL 전문은 `results/` 폴더에 있습니다. 아래는 핵심만 정리한 것이며,
**사실**은 결과 표 수치, **계산**은 SQL에 명시된 식, **추론**은 해석입니다.

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

## 4. 폴더 구조

```
dart-sql-portfolio/
├── README.md
├── CLAUDE.md                 # Claude Code 작업 규칙·남은 작업
├── docs/PLAN.md              # 기획 문서
├── docs/SQL_STRUCTURE.md     # SQL 구현 구조 도식 (파이프라인·정제·ERD·쿼리별 기법)
├── requirements.txt / .env.example / .gitignore
├── dart_sector.db            # 빌드 결과 (재생성 가능)
├── data/raw/
│   ├── companies.csv                 # 회사 마스터 (섹터 분류)
│   ├── dart_key_accounts_fy2025.csv  # DART 주요계정 원형 스냅샷 FY2023~2025 (2026-11-18)
│   ├── dart_key_accounts_fy2022.csv  # DART 주요계정 원형 스냅샷 FY2020~2022 (2026-11-18)
│   ├── dart_revenue_supplement_fy2022.csv  # 매출액 행이 빠진 3사 보충 (전체 재무제표 API)
│   ├── filings.csv                   # DART 주요사항보고서 목록 2023~2025
│   ├── prices_daily.csv              # yfinance 일별 주가
│   ├── shares_outstanding.csv        # KRX 주식수
│   └── shares_manual.csv             # KRX 목록에 없는 종목 주식수 수기 보충 (근거 포함)
├── scripts/
│   ├── fetch_dart.py         # OpenDART API (DART_API_KEY 필요)
│   ├── fetch_prices.py       # yfinance + KRX 목록
│   ├── build_db.py           # CSV -> SQLite
│   └── run_queries.py        # q*.sql -> results/*.md
├── sql/
│   ├── 01_schema.sql         # staging / 분석용 테이블
│   ├── 02_load_clean.sql     # UNPIVOT·PIVOT·형변환·중복제거
│   └── q1 ~ q7 *.sql         # 분석 쿼리 (질문·기법 주석 포함)
└── results/                  # 쿼리별 결과 표 + SQL
```

## 5. 출처

- 재무제표: 금융감독원 DART 다중회사 주요계정 (fnlttMultiAcnt), 사업보고서 기준, 접수번호는 `financials_annual.source_rcept_no`
- 주가: Yahoo Finance (yfinance)
- 주식수: KRX 상장종목 목록 (FinanceDataReader), 2026-11-18 기준. 더존비즈온은 FY2025 사업보고서 자본금 / 액면가 500원으로 추정(31,477,993주) - 주가가 없어 q2 결과는 NULL 유지
- 공시 목록: 금융감독원 DART 공시검색 (list.json, pblntf_ty=B), 최종보고서 기준
- 더존비즈온 상장폐지(2026-07-15): EQT파트너스 공개매수 후 주식교환, 언론 보도 기준
