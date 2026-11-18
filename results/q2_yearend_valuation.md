# q2_yearend_valuation

Q2. 연말 기준 시가총액·PER·PBR - 재무제표(DART)와 주가(거래소)를 결합
기법: ROW_NUMBER로 "연도별 마지막 거래일" 추출, 3개 테이블 JOIN, LEFT JOIN으로 결측 유지
주의: shares_outstanding은 수집 시점(현재) 기준 주식수 -> 과거 연도 시가총액은 근사치(추론)
더존비즈온(012510)은 2026-07 상장폐지로 주가 이력이 없어 NULL로 남는다 (LEFT JOIN 효과)

## Result (13 rows)

| sector     | corp_name   |   fiscal_year | yearend_date   |   yearend_close |   mktcap_bn |   per_x |   pbr_x |   roe_pct |
|:-----------|:------------|--------------:|:---------------|----------------:|------------:|--------:|--------:|----------:|
| IT인프라/SaaS | 삼성에스디에스     |          2025 | 2025-12-30     |         171,500 |      13,270 |    17   |     1.3 |       7.6 |
| IT인프라/SaaS | 케이아이엔엑스     |          2025 | 2025-12-30     |         121,100 |         591 |    30.2 |     2.4 |       7.9 |
| IT인프라/SaaS | 가비아         |          2025 | 2025-12-30     |          32,250 |         433 |    13.9 |     1.2 |       8.3 |
| IT인프라/SaaS | 헥토이노베이션     |          2025 | 2025-12-30     |          16,120 |         209 |     5.7 |     0.6 |      10.2 |
| IT인프라/SaaS | 더존비즈온       |          2025 |                |                 |             |         |         |      14.6 |
| 게임         | 크래프톤        |          2025 | 2025-12-30     |         246,000 |      11,189 |    15.2 |     1.6 |      10.2 |
| 게임         | NC          |          2025 | 2025-12-30     |         201,500 |       4,341 |    12.5 |     1.3 |      10.3 |
| 게임         | 넷마블         |          2025 | 2025-12-30     |          48,250 |       4,012 |    17.4 |     0.7 |       4.2 |
| 게임         | 카카오게임즈      |          2025 | 2025-12-30     |          14,900 |       1,591 |         |     1.3 |     -11.9 |
| 인터넷플랫폼     | NAVER       |          2025 | 2025-12-30     |         242,500 |      36,891 |    20.3 |     1.3 |       6.3 |
| 인터넷플랫폼     | 카카오         |          2025 | 2025-12-30     |          60,100 |      26,624 |    51.4 |     1.8 |       3.4 |
| 인터넷플랫폼     | NHN         |          2025 | 2025-12-30     |          29,050 |         939 |    18.1 |     0.5 |       2.9 |
| 인터넷플랫폼     | SOOP        |          2025 | 2025-12-30     |          67,800 |         759 |     7.3 |     1.5 |      20.6 |

## SQL

```sql
-- Q2. 연말 기준 시가총액·PER·PBR - 재무제표(DART)와 주가(거래소)를 결합
-- 기법: ROW_NUMBER로 "연도별 마지막 거래일" 추출, 3개 테이블 JOIN, LEFT JOIN으로 결측 유지
-- 주의: shares_outstanding은 수집 시점(현재) 기준 주식수 -> 과거 연도 시가총액은 근사치(추론)
--       더존비즈온(012510)은 2026-07 상장폐지로 주가 이력이 없어 NULL로 남는다 (LEFT JOIN 효과)

WITH last_trade AS (
    SELECT
        stock_code,
        CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS fiscal_year,
        trade_date,
        close,
        ROW_NUMBER() OVER (
            PARTITION BY stock_code, SUBSTR(trade_date, 1, 4)
            ORDER BY trade_date DESC
        ) AS rn
    FROM prices_daily
),
yearend AS (
    SELECT stock_code, fiscal_year, trade_date AS yearend_date, close AS yearend_close
    FROM last_trade
    WHERE rn = 1
),
valuation AS (
    SELECT
        c.sector,
        c.corp_name,
        f.fiscal_year,
        y.yearend_date,
        y.yearend_close,
        -- 시가총액(십억원) = 종가 x 주식수 / 1e9
        ROUND(y.yearend_close * s.shares / 1e9, 0)                                   AS mktcap_bn,
        -- 순이익·자본은 백만원 단위이므로 1e6을 곱해 원 단위로 맞춘다
        ROUND(y.yearend_close * s.shares / NULLIF(f.net_income * 1e6, 0), 1)         AS per_x,
        ROUND(y.yearend_close * s.shares / NULLIF(f.total_equity * 1e6, 0), 2)       AS pbr_x,
        ROUND(100.0 * f.net_income / NULLIF(f.total_equity, 0), 1)                   AS roe_pct
    FROM financials_annual f
    JOIN companies c            ON c.corp_code  = f.corp_code
    LEFT JOIN yearend y         ON y.stock_code = c.stock_code AND y.fiscal_year = f.fiscal_year
    LEFT JOIN shares_outstanding s ON s.stock_code = c.stock_code
    WHERE f.fs_div = 'CFS'
)
SELECT
    sector, corp_name, fiscal_year, yearend_date, yearend_close,
    mktcap_bn,
    -- 적자 기업의 PER은 의미가 없으므로 표시하지 않는다
    CASE WHEN per_x > 0 THEN per_x END AS per_x,
    pbr_x,
    roe_pct
FROM valuation
WHERE fiscal_year = 2025
ORDER BY sector, mktcap_bn DESC;
```
