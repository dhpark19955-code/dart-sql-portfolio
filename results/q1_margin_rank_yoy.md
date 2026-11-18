# q1_margin_rank_yoy

Q1. 섹터 안에서 누가 가장 수익성이 좋고, 성장은 어디서 나오는가?
기법: JOIN, CTE, LAG (전년 대비), RANK (섹터 내 순위), NULLIF (0 나눗셈 방어)
단위: 매출·영업이익 십억원, 비율 %

## Result (13 rows)

| sector     | corp_name   |   fiscal_year |   revenue_bn |   op_income_bn |   opm_pct |   rev_yoy_pct |   op_yoy_pct |   opm_rank_in_sector |
|:-----------|:------------|--------------:|-------------:|---------------:|----------:|--------------:|-------------:|---------------------:|
| IT인프라/SaaS | 더존비즈온       |          2025 |        446.3 |          127.7 |      28.6 |          10.9 |         45   |                    1 |
| IT인프라/SaaS | 케이아이엔엑스     |          2025 |        159.2 |           23.9 |      15   |          14.6 |          0.6 |                    2 |
| IT인프라/SaaS | 헥토이노베이션     |          2025 |        375.8 |           50.2 |      13.4 |          17.6 |          2.7 |                    3 |
| IT인프라/SaaS | 가비아         |          2025 |        335.7 |           40.5 |      12.1 |          18.9 |         15.3 |                    4 |
| IT인프라/SaaS | 삼성에스디에스     |          2025 |      13929.9 |          957.1 |       6.9 |           0.7 |          5   |                    5 |
| 게임         | 크래프톤        |          2025 |       3326.6 |         1054.4 |      31.7 |          22.8 |        -10.8 |                    1 |
| 게임         | 넷마블         |          2025 |       2835.1 |          352.5 |      12.4 |           6.4 |         63.5 |                    2 |
| 게임         | NC          |          2025 |       1506.9 |           16.1 |       1.1 |          -4.5 |              |                    3 |
| 게임         | 카카오게임즈      |          2025 |        465   |          -39.6 |      -8.5 |         -25.9 |       -306.8 |                    4 |
| 인터넷플랫폼     | SOOP        |          2025 |        466.6 |          124.8 |      26.8 |          12.9 |         10   |                    1 |
| 인터넷플랫폼     | NAVER       |          2025 |      12035   |         2208.1 |      18.3 |          12.1 |         11.6 |                    2 |
| 인터넷플랫폼     | 카카오         |          2025 |       8099.1 |          732   |       9   |           3   |         47.8 |                    3 |
| 인터넷플랫폼     | NHN         |          2025 |       2516.2 |          132.4 |       5.3 |           2.4 |              |                    4 |

## SQL

```sql
-- Q1. 섹터 안에서 누가 가장 수익성이 좋고, 성장은 어디서 나오는가?
-- 기법: JOIN, CTE, LAG (전년 대비), RANK (섹터 내 순위), NULLIF (0 나눗셈 방어)
-- 단위: 매출·영업이익 십억원, 비율 %

WITH base AS (
    SELECT
        c.sector,
        c.corp_name,
        f.fiscal_year,
        f.revenue,
        f.op_income,
        LAG(f.revenue)   OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_revenue,
        LAG(f.op_income) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_op_income
    FROM financials_annual f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
),
metrics AS (
    SELECT
        sector, corp_name, fiscal_year,
        ROUND(revenue   / 1000.0, 1)                                            AS revenue_bn,
        ROUND(op_income / 1000.0, 1)                                            AS op_income_bn,
        ROUND(100.0 * op_income / NULLIF(revenue, 0), 1)                        AS opm_pct,
        ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 1)    AS rev_yoy_pct,
        -- 전년이 적자면 증가율이 의미가 없으므로 NULL 처리
        CASE WHEN prev_op_income > 0
             THEN ROUND(100.0 * (op_income - prev_op_income) / prev_op_income, 1)
        END                                                                     AS op_yoy_pct
    FROM base
)
SELECT
    sector,
    corp_name,
    fiscal_year,
    revenue_bn,
    op_income_bn,
    opm_pct,
    rev_yoy_pct,
    op_yoy_pct,
    RANK() OVER (PARTITION BY sector, fiscal_year ORDER BY opm_pct DESC) AS opm_rank_in_sector
FROM metrics
WHERE fiscal_year = 2025
ORDER BY sector, opm_rank_in_sector;
```
