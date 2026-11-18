-- Q13. 200사 중 "성장 + 수익성 + 건전성"을 동시에 갖춘 곳은 어디인가 (q4 턴어라운드 스크리닝의 유니버스 확장판)
-- 기법: 4개 연도를 self-join 없이 조건부 집계로 한 행에 모으기, 복합 조건 플래그, 전체 순위(RANK) 와 업종 내 순위(RANK PARTITION BY)
-- 조건(1차 필터, 추론 아님): 매출 CAGR(21->25) >= 10%, FY2025 영업이익률 >= 10%, 부채비율 <= 100%, 3년 연속 영업흑자
-- 주의: 금융업 제외(매출·부채비율 개념이 다름). 2021 매출이 없는 신규 상장사는 CAGR 이 NULL 이라 빠진다 - 누락이 아니라 조건 미충족

WITH y AS (
    SELECT d.corp_code, d.corp_name, i.sector_mid,
           MAX(CASE WHEN w.fiscal_year = 2021 THEN w.revenue END)   AS rev21,
           MAX(CASE WHEN w.fiscal_year = 2025 THEN w.revenue END)   AS rev25,
           MAX(CASE WHEN w.fiscal_year = 2025 THEN w.op_income END) AS op25,
           MIN(CASE WHEN w.fiscal_year BETWEEN 2023 AND 2025 THEN w.op_income END) AS min_op_23_25,
           MAX(CASE WHEN w.fiscal_year = 2025 THEN w.total_liab END)   AS liab25,
           MAX(CASE WHEN w.fiscal_year = 2025 THEN w.total_equity END) AS equity25
    FROM dim_company d
    JOIN dim_industry i ON i.ksic2 = SUBSTR(d.induty_code, 1, 2)
    JOIN fin_annual_wide w ON w.corp_code = d.corp_code AND w.fs_div = 'CFS'
    WHERE i.is_financial = 0
    GROUP BY d.corp_code, d.corp_name, i.sector_mid
),
m AS (
    SELECT *,
           ROUND(100.0 * (POWER(rev25 * 1.0 / NULLIF(rev21, 0), 0.25) - 1), 1) AS rev_cagr_pct,
           ROUND(100.0 * op25 / NULLIF(rev25, 0), 1)                             AS opm25_pct,
           ROUND(100.0 * liab25 / NULLIF(equity25, 0), 1)                        AS debt_ratio_pct
    FROM y
    WHERE rev21 > 0 AND rev25 IS NOT NULL
),
flagged AS (
    SELECT *,
           (rev_cagr_pct >= 10) + (opm25_pct >= 10) + (debt_ratio_pct <= 100) + (min_op_23_25 > 0) AS n_pass
    FROM m
)
SELECT corp_name, sector_mid,
       ROUND(rev25 / 1000.0, 0) AS rev25_bn,
       rev_cagr_pct, opm25_pct, debt_ratio_pct,
       CASE WHEN min_op_23_25 > 0 THEN 'Y' ELSE '' END AS op_positive_3y,
       n_pass,
       RANK() OVER (ORDER BY n_pass DESC, rev_cagr_pct DESC)                          AS rank_all,
       RANK() OVER (PARTITION BY sector_mid ORDER BY n_pass DESC, rev_cagr_pct DESC)  AS rank_in_sector
FROM flagged
WHERE n_pass = 4
ORDER BY rank_all;
