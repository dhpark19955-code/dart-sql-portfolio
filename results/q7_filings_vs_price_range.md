# q7_filings_vs_price_range

Q7. 주요사항보고서를 많이 낸 해에 주가 변동폭도 컸나?
기법: 공시(filings) x 주가(prices_daily) x 회사(companies) 4번째 JOIN 축, 공시 유형을 CASE로 분류해 조건부 집계,
회사 x 연도 뼈대(CROSS JOIN)에 LEFT JOIN 해서 공시 0건인 해도 행을 유지
주의: 정정공시([기재정정] 등)는 같은 사건의 재제출이라 건수에서 빼고 따로 센다
변동폭 = (연중 최고 종가 - 최저 종가) / 최저 종가, 종가 기준이라 장중 고저가와 다르다
(q5 의 high_low_range_pct 는 최저/최고 - 1 로 음수 표기, 같은 고저가를 다른 기준으로 본 값)
공시 건수와 변동폭은 인과가 아니라 동시 관찰(추론 금지), 13개사 x 3년 표본

## Result (39 rows)

| sector     | corp_name   |   fiscal_year |   n_filings |   n_amend |   n_treasury |   n_financing |   n_restructure |   range_pct |   range_rank_in_year |
|:-----------|:------------|--------------:|------------:|----------:|-------------:|--------------:|----------------:|------------:|---------------------:|
| 인터넷플랫폼     | 카카오         |          2023 |           8 |         2 |            5 |             0 |               1 |        83.8 |                    5 |
| IT인프라/SaaS | 가비아         |          2023 |           3 |         0 |            3 |             0 |               0 |        75.9 |                    6 |
| 게임         | 크래프톤        |          2023 |           3 |         0 |            3 |             0 |               0 |        48.8 |                    9 |
| IT인프라/SaaS | 더존비즈온       |          2023 |           3 |         0 |            1 |             0 |               2 |             |                      |
| 인터넷플랫폼     | SOOP        |          2023 |           2 |         1 |            2 |             0 |               0 |        53.1 |                    7 |
| 인터넷플랫폼     | NAVER       |          2023 |           2 |         1 |            2 |             0 |               0 |        31.5 |                   11 |
| 인터넷플랫폼     | NHN         |          2023 |           1 |         0 |            1 |             0 |               0 |        44.4 |                   10 |
| IT인프라/SaaS | 헥토이노베이션     |          2023 |           1 |         0 |            1 |             0 |               0 |        27.6 |                   12 |
| 게임         | NC          |          2023 |           0 |         0 |            0 |             0 |               0 |       124.2 |                    1 |
| IT인프라/SaaS | 케이아이엔엑스     |          2023 |           0 |         0 |            0 |             0 |               0 |       113.7 |                    2 |
| 게임         | 카카오게임즈      |          2023 |           0 |         0 |            0 |             0 |               0 |       112.8 |                    3 |
| 게임         | 넷마블         |          2023 |           0 |         0 |            0 |             0 |               0 |        93.8 |                    4 |
| IT인프라/SaaS | 삼성에스디에스     |          2023 |           0 |         0 |            0 |             0 |               0 |        49.3 |                    8 |
| 인터넷플랫폼     | 카카오         |          2024 |           7 |         2 |            5 |             0 |               2 |        86.3 |                    3 |
| IT인프라/SaaS | 가비아         |          2024 |           5 |         0 |            3 |             2 |               0 |        77.5 |                    5 |
| 인터넷플랫폼     | NAVER       |          2024 |           4 |         0 |            4 |             0 |               0 |        49.4 |                    9 |
| 게임         | 크래프톤        |          2024 |           3 |         0 |            3 |             0 |               0 |        90.2 |                    2 |
| 인터넷플랫폼     | NHN         |          2024 |           3 |         0 |            3 |             0 |               0 |        83.8 |                    4 |
| 인터넷플랫폼     | SOOP        |          2024 |           3 |         0 |            3 |             0 |               0 |        61.7 |                    7 |
| 게임         | NC          |          2024 |           1 |         2 |            1 |             0 |               0 |        52.4 |                    8 |
| IT인프라/SaaS | 헥토이노베이션     |          2024 |           1 |         0 |            1 |             0 |               0 |        26.8 |                   12 |
| IT인프라/SaaS | 케이아이엔엑스     |          2024 |           0 |         0 |            0 |             0 |               0 |       101.5 |                    1 |
| 게임         | 카카오게임즈      |          2024 |           0 |         1 |            0 |             0 |               0 |        77.4 |                    6 |
| 게임         | 넷마블         |          2024 |           0 |         0 |            0 |             0 |               0 |        48.1 |                   10 |
| IT인프라/SaaS | 삼성에스디에스     |          2024 |           0 |         0 |            0 |             0 |               0 |        34.2 |                   11 |
| IT인프라/SaaS | 더존비즈온       |          2024 |           0 |         1 |            0 |             0 |               0 |             |                      |
| IT인프라/SaaS | 헥토이노베이션     |          2025 |           6 |         0 |            6 |             0 |               0 |        62.2 |                   11 |
| 게임         | 크래프톤        |          2025 |           4 |         0 |            4 |             0 |               0 |        59.8 |                   12 |
| 인터넷플랫폼     | 카카오         |          2025 |           3 |         2 |            2 |             0 |               1 |        96.9 |                    2 |
| 인터넷플랫폼     | NAVER       |          2025 |           3 |         0 |            3 |             0 |               0 |        64.2 |                   10 |
| 인터넷플랫폼     | NHN         |          2025 |           2 |         1 |            2 |             0 |               0 |        93.3 |                    3 |
| IT인프라/SaaS | 가비아         |          2025 |           1 |         0 |            1 |             0 |               0 |       124.5 |                    1 |
| 게임         | 넷마블         |          2025 |           1 |         0 |            0 |             1 |               0 |        81.3 |                    5 |
| 게임         | 카카오게임즈      |          2025 |           1 |         0 |            0 |             1 |               0 |        80.4 |                    6 |
| 인터넷플랫폼     | SOOP        |          2025 |           0 |         1 |            0 |             0 |               0 |        89.8 |                    4 |
| 게임         | NC          |          2025 |           0 |         1 |            0 |             0 |               0 |        78.2 |                    7 |
| IT인프라/SaaS | 삼성에스디에스     |          2025 |           0 |         0 |            0 |             0 |               0 |        76.6 |                    8 |
| IT인프라/SaaS | 케이아이엔엑스     |          2025 |           0 |         0 |            0 |             0 |               0 |        73   |                    9 |
| IT인프라/SaaS | 더존비즈온       |          2025 |           0 |         0 |            0 |             0 |               0 |             |                      |

## SQL

```sql
-- Q7. 주요사항보고서를 많이 낸 해에 주가 변동폭도 컸나?
-- 기법: 공시(filings) x 주가(prices_daily) x 회사(companies) 4번째 JOIN 축, 공시 유형을 CASE로 분류해 조건부 집계,
--       회사 x 연도 뼈대(CROSS JOIN)에 LEFT JOIN 해서 공시 0건인 해도 행을 유지
-- 주의: 정정공시([기재정정] 등)는 같은 사건의 재제출이라 건수에서 빼고 따로 센다
--       변동폭 = (연중 최고 종가 - 최저 종가) / 최저 종가, 종가 기준이라 장중 고저가와 다르다
--       (q5 의 high_low_range_pct 는 최저/최고 - 1 로 음수 표기, 같은 고저가를 다른 기준으로 본 값)
--       공시 건수와 변동폭은 인과가 아니라 동시 관찰(추론 금지), 13개사 x 3년 표본

WITH years AS (
    SELECT DISTINCT CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr
    FROM prices_daily
),
grid AS (                                   -- 회사 x 연도 뼈대
    SELECT c.corp_code, c.stock_code, c.sector, c.corp_name, y.yr
    FROM companies c
    CROSS JOIN years y
),
filing_cnt AS (
    SELECT
        corp_code,
        CAST(SUBSTR(rcept_dt, 1, 4) AS INTEGER)                                    AS yr,
        SUM(CASE WHEN is_amendment = 0 THEN 1 ELSE 0 END)                          AS n_filings,
        SUM(CASE WHEN is_amendment = 1 THEN 1 ELSE 0 END)                          AS n_amend,
        SUM(CASE WHEN is_amendment = 0 AND report_nm LIKE '%자기주식%' THEN 1 ELSE 0 END) AS n_treasury,
        SUM(CASE WHEN is_amendment = 0
                  AND (report_nm LIKE '%사채권발행%' OR report_nm LIKE '%유상증자%')
                 THEN 1 ELSE 0 END)                                                 AS n_financing,
        SUM(CASE WHEN is_amendment = 0
                  AND (report_nm LIKE '%합병%' OR report_nm LIKE '%분할%'
                       OR report_nm LIKE '%감자%' OR report_nm LIKE '%양수%' OR report_nm LIKE '%양도%')
                 THEN 1 ELSE 0 END)                                                 AS n_restructure
    FROM filings
    GROUP BY corp_code, CAST(SUBSTR(rcept_dt, 1, 4) AS INTEGER)
),
price_range AS (
    SELECT
        stock_code,
        CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr,
        MIN(close) AS low_close,
        MAX(close) AS high_close
    FROM prices_daily
    GROUP BY stock_code, CAST(SUBSTR(trade_date, 1, 4) AS INTEGER)
),
joined AS (
    SELECT
        g.sector, g.corp_name, g.yr,
        COALESCE(fc.n_filings, 0)     AS n_filings,
        COALESCE(fc.n_amend, 0)       AS n_amend,
        COALESCE(fc.n_treasury, 0)    AS n_treasury,
        COALESCE(fc.n_financing, 0)   AS n_financing,
        COALESCE(fc.n_restructure, 0) AS n_restructure,
        ROUND(100.0 * (pr.high_close - pr.low_close) / NULLIF(pr.low_close, 0), 1) AS range_pct
    FROM grid g
    LEFT JOIN filing_cnt  fc ON fc.corp_code  = g.corp_code  AND fc.yr = g.yr
    LEFT JOIN price_range pr ON pr.stock_code = g.stock_code AND pr.yr = g.yr
)
SELECT
    sector, corp_name, yr AS fiscal_year,
    n_filings, n_amend, n_treasury, n_financing, n_restructure,
    range_pct,
    -- 같은 해 13개사 중 변동폭 순위 (1 = 가장 큼), 주가 없는 종목은 NULL
    CASE WHEN range_pct IS NOT NULL
         THEN RANK() OVER (PARTITION BY yr, range_pct IS NULL ORDER BY range_pct DESC) END AS range_rank_in_year
FROM joined
ORDER BY fiscal_year, n_filings DESC, range_pct DESC;
```
