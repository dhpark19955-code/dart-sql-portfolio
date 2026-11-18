# SQL 구현 구조

README 의 질문별 결과가 어떤 SQL 구조에서 나오는지 정리한 문서입니다. GitHub 에서 mermaid 도식으로 보입니다.

## 1. 파이프라인

```mermaid
flowchart TD
    A["원천 CSV 8개<br/>data/raw - API 응답 그대로"] -->|build_db.py: pandas to_sql| B["staging 테이블 6개<br/>stg_* - 문자열 원형 보존"]
    B -->|02_load_clean.sql| C["정제<br/>UNPIVOT - 형변환 - 중복제거 - PIVOT - 단위통일"]
    C --> D["분석 테이블 5개<br/>companies 중심"]
    D -->|run_queries.py| E["분석 쿼리 q1~q7<br/>CTE + 윈도우 함수"]
    E --> F["results/q*.md<br/>질문 주석 + 결과 표 + SQL"]
```

원칙: Python 은 CSV 를 문자열 그대로 옮기고 결과를 md 로 쓰는 일만 한다. 숫자를 바꾸는 모든 처리(콤마 제거, 연도 펼치기, 중복 제거, 단위 변환)는 `sql/02_load_clean.sql` 한 곳에 있다.

## 2. 재무 데이터 정제 (02_load_clean.sql)

```mermaid
flowchart LR
    S["stg_dart_key_accounts<br/>계정 1행 = 당기·전기·전전기 3열"] -->|"UNION ALL x3<br/>연도 = bsns_year, -1, -2"| L["long<br/>계정 x 연도 1행"]
    L -->|"CASE '-' → NULL<br/>REPLACE 콤마 → CAST"| C["cleaned<br/>원 단위 정수"]
    C -->|"ROW_NUMBER OVER<br/>(회사, 연도, 계정 ORDER BY rcept_no DESC)"| D["dedup<br/>정정공시 우선 1건"]
    D -->|"MAX(CASE WHEN 계정 ...) / 1e6<br/>GROUP BY 회사, 연도"| P["financials_annual<br/>회사 x 연도 1행, 백만원"]
```

| 단계 | 하는 일 | 쓰인 SQL |
|---|---|---|
| UNPIVOT | 사업보고서 1건의 3개년 열을 연도별 행으로 | `UNION ALL`, 연도 산술 |
| 형변환 | `"1,234"` / `"-1,234"` / `"-"` → 정수 또는 NULL | `CASE`, `TRIM`, `REPLACE`, `CAST` |
| 중복제거 | 같은 회사·연도·계정이 여러 보고서에 있으면 최신 접수번호 1건 | `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY rcept_no DESC)` |
| PIVOT | 계정(행) → 컬럼, 회사 x 연도 1행 | `MAX(CASE WHEN ...)`, `GROUP BY` |
| 단위 | 원 → 백만원 | `/ 1000000` |

분기(`financials_quarter`)는 같은 패턴에 두 가지가 더해진다. (a) 분기보고서의 당기 열(그 해 3개월)과 전기 열(전년 같은 분기 3개월, 최신 기준 재표시)을 둘 다 행으로 펼친 뒤 접수번호 최신 1건을 고른다 - 손익 계정만이며 재무상태표 전기 열은 전년 말 잔액이라 제외. (b) 4분기는 보고서가 없으므로 `financials_annual` - 1~3분기 합으로 도출하고 `is_derived = 1` 을 단다. 연초누적은 `SUM() OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.

같은 파일에서 주가는 `ROW_NUMBER` 로 중복 거래일 제거, 주식수는 `NOT EXISTS` 로 KRX 목록에 없는 종목만 수기 값 보충, 공시는 `SUBSTR` 로 날짜 형식 통일과 정정공시 플래그(`LIKE '[%'`)를 붙인다.

## 3. 분석 테이블 관계

```mermaid
erDiagram
  companies ||--o{ financials_annual : corp_code
  companies ||--o{ prices_daily : stock_code
  companies ||--o| shares_outstanding : stock_code
  companies ||--o{ filings : corp_code
  companies ||--o{ financials_quarter : corp_code
  companies {
    text corp_code PK
    text stock_code UK
    text corp_name
    text sector
    text delisted_date
  }
  financials_annual {
    text corp_code PK
    int fiscal_year PK
    text fs_div PK
    int revenue
    int op_income
    int net_income
    int total_equity
    text source_rcept_no
  }
  prices_daily {
    text stock_code PK
    text trade_date PK
    real close
    int volume
  }
  shares_outstanding {
    text stock_code PK
    int shares
    text source
  }
  financials_quarter {
    text corp_code PK
    int fiscal_year PK
    int quarter PK
    int revenue
    int revenue_cum
    int is_derived
  }
  filings {
    text rcept_no PK
    text corp_code FK
    text report_nm
    text rcept_dt
    int is_amendment
  }
```

`companies` 가 두 개의 키(DART `corp_code`, 거래소 `stock_code`)를 모두 들고 있어서 DART 계열 테이블과 거래소 계열 테이블을 잇는 다리 역할을 한다.

## 4. 쿼리별 기법

| 쿼리 | 질문 | JOIN 한 테이블 | 핵심 기법 |
|---|---|---|---|
| q1 | 섹터 내 영업이익률 순위, YoY | financials, companies | `LAG`, `RANK() OVER (PARTITION BY sector)` |
| q2 | 연말 시가총액·PER·PBR | financials, companies, prices, shares | `ROW_NUMBER` 로 연말 거래일, `LEFT JOIN` 결측 유지 |
| q3 | 섹터 비중 변화, 5년 CAGR | financials, companies | `SUM() OVER (PARTITION BY)`, `POWER` |
| q4 | 흑자·적자전환 + 건전성 | financials, companies | `LAG` + `CASE` 상태 라벨, 복합 조건 플래그 |
| q5 | 주가 수익률 vs 이익 변화 | prices, financials, companies | `FIRST_VALUE`/`LAST_VALUE`, `WINDOW` 절 |
| q6 | 데이터 품질 점검 | financials, prices, companies | `UNION ALL` 점검 묶기, `LEFT JOIN ... IS NULL` |
| q7 | 주요사항보고서 건수 vs 주가 변동폭 | filings, prices, companies | `CROSS JOIN` 뼈대 + `LEFT JOIN`, `CASE` 조건부 집계, `RANK` |
| q8 | 분기 데이터 품질 점검 | financials_quarter, financials_annual, companies | `SUM() OVER (ROWS UNBOUNDED PRECEDING)` 누적, `LAG` 차분 왕복, `UNION ALL` |
| q9 | 2025년 분기 추세 | financials_quarter, financials_annual, companies | `LAG(…, 4)` 전년 동기, `LAG(…, 1)` QoQ |
