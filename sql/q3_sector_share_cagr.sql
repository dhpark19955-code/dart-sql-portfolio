-- Q3. 섹터 합산 대비 각 회사의 비중은 얼마고, 3년간 누가 점유율을 늘렸나?
-- 기법: SUM() OVER (PARTITION BY) 로 섹터 합산 대비 비중, 자기 조인 없이 FIRST/LAST 연도 비교,
--       POWER/ln을 이용한 CAGR (SQLite 3.35+ math 함수)

WITH yr AS (
    SELECT MIN(fiscal_year) AS first_year, MAX(fiscal_year) AS last_year
    FROM financials_annual
),
share AS (
    SELECT
        c.sector,
        c.corp_name,
        f.fiscal_year,
        f.revenue,
        f.op_income,
        100.0 * f.revenue   / SUM(f.revenue)   OVER (PARTITION BY c.sector, f.fiscal_year) AS rev_share_pct,
        -- 영업이익은 적자가 섞이면 합산 비중이 왜곡되므로 흑자 기업만 분모에 넣는다
        100.0 * f.op_income / SUM(CASE WHEN f.op_income > 0 THEN f.op_income END)
                              OVER (PARTITION BY c.sector, f.fiscal_year)                 AS op_share_pct
    FROM financials_annual f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
),
first_last AS (
    SELECT
        s.sector, s.corp_name,
        MAX(CASE WHEN s.fiscal_year = y.first_year THEN s.revenue END)        AS rev_first,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.revenue END)        AS rev_last,
        MAX(CASE WHEN s.fiscal_year = y.first_year THEN s.rev_share_pct END)  AS share_first,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.rev_share_pct END)  AS share_last,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.op_share_pct END)   AS op_share_last,
        y.last_year - y.first_year                                            AS n_years
    FROM share s CROSS JOIN yr y
    GROUP BY s.sector, s.corp_name, y.last_year, y.first_year
)
SELECT
    sector,
    corp_name,
    ROUND(rev_first / 1000.0, 1)                                    AS rev_first_bn,
    ROUND(rev_last  / 1000.0, 1)                                    AS rev_last_bn,
    ROUND(100.0 * (POWER(rev_last * 1.0 / rev_first, 1.0 / n_years) - 1), 1) AS rev_cagr_pct,
    ROUND(share_first, 1)                                           AS rev_share_first_pct,
    ROUND(share_last, 1)                                            AS rev_share_last_pct,
    ROUND(share_last - share_first, 1)                              AS share_change_pp,
    ROUND(op_share_last, 1)                                         AS op_share_last_pct
FROM first_last
ORDER BY sector, rev_share_last_pct DESC;
