-- Q12. 유니버스 200사를 업종(KSIC 중분류)으로 묶으면 수익성과 성장은 어디에 몰려 있나
-- 기법: dim_company x dim_industry x fin_annual_wide 3테이블 JOIN, 업종별 중앙값(ROW_NUMBER + COUNT OVER 로 계산, SQLite 에 MEDIAN 없음),
--       POWER 로 4년 CAGR(FY2021 -> FY2025), 회사 수 3개 이상 업종만 (HAVING)
-- 주의: 금융업(is_financial = 1)은 매출액 개념이 달라 매출 CAGR·영업이익률에서 제외하고 회사 수만 센다
--       업종은 DART 기업개황 업종코드(KSIC) 앞 2자리 기준 - 지주회사는 '전문서비스(71)' 로 묶여 실제 사업과 다를 수 있다

WITH base AS (
    SELECT d.corp_code, d.corp_name, i.sector_major, i.sector_mid, i.is_financial,
           w25.revenue AS rev25, w25.op_income AS op25,
           w21.revenue AS rev21,
           100.0 * w25.op_income / NULLIF(w25.revenue, 0) AS opm25
    FROM dim_company d
    JOIN dim_industry i ON i.ksic2 = SUBSTR(d.induty_code, 1, 2)
    LEFT JOIN v_fin_annual w25 ON w25.corp_code = d.corp_code AND w25.fiscal_year = 2025
    LEFT JOIN v_fin_annual w21 ON w21.corp_code = d.corp_code AND w21.fiscal_year = 2021
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY sector_mid ORDER BY opm25) AS rn,
           COUNT(opm25)  OVER (PARTITION BY sector_mid)               AS cnt
    FROM base
    WHERE is_financial = 0 AND opm25 IS NOT NULL
),
median AS (
    -- 중앙값: 정렬 순번이 가운데 1~2개인 행의 평균
    SELECT sector_mid, AVG(opm25) AS opm25_median
    FROM ranked
    WHERE rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER))
    GROUP BY sector_mid
),
sector AS (
    SELECT b.sector_major, b.sector_mid,
           COUNT(*)                                                            AS n_cos,
           SUM(b.is_financial)                                                 AS n_financial,
           CAST(ROUND(SUM(CASE WHEN b.is_financial = 0 THEN b.rev25 END) / 1000.0, 0) AS BIGINT) AS rev25_sum_bn,
           ROUND(100.0 * SUM(CASE WHEN b.is_financial = 0 THEN b.op25 END)
                       / NULLIF(SUM(CASE WHEN b.is_financial = 0 THEN b.rev25 END), 0), 1) AS opm25_weighted_pct,
           ROUND(MAX(m.opm25_median), 1)                                       AS opm25_median_pct,   -- 집계 밖 열 금지 (DuckDB), 값은 업종당 1개
           ROUND(100.0 * (POWER(SUM(CASE WHEN b.is_financial = 0 AND b.rev21 > 0 THEN b.rev25 END) * 1.0
                               / NULLIF(SUM(CASE WHEN b.is_financial = 0 AND b.rev21 > 0 THEN b.rev21 END), 0), 0.25) - 1), 1)
                                                                               AS rev_cagr_21_25_pct,
           (SELECT corp_name FROM ranked r WHERE r.sector_mid = b.sector_mid ORDER BY opm25 DESC LIMIT 1) AS top_opm_company
    FROM base b
    LEFT JOIN median m ON m.sector_mid = b.sector_mid
    GROUP BY b.sector_major, b.sector_mid
    HAVING COUNT(*) >= 3
)
SELECT *
FROM sector
ORDER BY rev25_sum_bn DESC;
