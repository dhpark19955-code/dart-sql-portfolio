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
