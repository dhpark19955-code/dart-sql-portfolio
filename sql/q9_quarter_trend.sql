-- Q9. 분기로 보면 실적 방향이 어디서 바뀌었나 - 2025년 분기별 매출 YoY, 영업이익률, QoQ
-- 기법: LAG(..., 4) 로 "전년 같은 분기" 비교 (분기 데이터는 계절성이 있어 직전 분기보다 전년 동기가 기준),
--       LAG(..., 1) 로 QoQ, 연간 테이블과 JOIN 해 분기 영업이익률을 연간 영업이익률과 나란히
-- 주의: 4분기는 연간 - 1~3분기 도출값(is_derived = 1). 연간 보고서에서 재분류·정정이 있으면 4분기에 몰려 보인다

WITH q AS (
    SELECT
        c.sector, c.corp_name, f.corp_code, f.fiscal_year, f.quarter,
        f.revenue, f.op_income, f.is_derived,
        LAG(f.revenue, 4)   OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year, f.quarter) AS rev_yoy_base,
        LAG(f.op_income, 4) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year, f.quarter) AS op_yoy_base,
        LAG(f.op_income, 1) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year, f.quarter) AS op_prev_q
    FROM financials_quarter f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
)
SELECT
    q.sector, q.corp_name,
    q.fiscal_year || 'Q' || q.quarter                                         AS period,
    ROUND(q.revenue   / 1000.0, 1)                                            AS revenue_bn,
    ROUND(q.op_income / 1000.0, 1)                                            AS op_income_bn,
    ROUND(100.0 * q.op_income / NULLIF(q.revenue, 0), 1)                      AS opm_pct,
    ROUND(100.0 * (q.revenue - q.rev_yoy_base) / NULLIF(q.rev_yoy_base, 0), 1) AS rev_yoy_pct,
    CASE WHEN q.op_yoy_base > 0
         THEN ROUND(100.0 * (q.op_income - q.op_yoy_base) / q.op_yoy_base, 1) END AS op_yoy_pct,
    CASE WHEN q.op_prev_q > 0
         THEN ROUND(100.0 * (q.op_income - q.op_prev_q) / q.op_prev_q, 1) END    AS op_qoq_pct,
    ROUND(100.0 * a.op_income / NULLIF(a.revenue, 0), 1)                      AS opm_annual_pct,
    CASE WHEN q.is_derived = 1 THEN 'derived' ELSE '' END                     AS note
FROM q
JOIN financials_annual a ON a.corp_code = q.corp_code AND a.fiscal_year = q.fiscal_year AND a.fs_div = 'CFS'
WHERE q.fiscal_year = 2025
ORDER BY q.sector, q.corp_name, q.quarter;
