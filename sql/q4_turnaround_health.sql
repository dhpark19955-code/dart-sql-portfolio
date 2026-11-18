-- Q4. 흑자전환 / 적자전환 기업을 찾고, 재무건전성(부채비율·유동비율)과 함께 본다
-- 기법: LAG로 전년 영업이익과 비교, CASE로 상태 라벨링, 다중 조건 필터
-- 활용: 스크리닝 1차 필터 - "턴어라운드인데 재무구조도 괜찮은 곳"을 먼저 추린다

WITH seq AS (
    SELECT
        c.sector, c.corp_name, f.fiscal_year,
        f.op_income, f.net_income,
        LAG(f.op_income)  OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_op,
        LAG(f.net_income) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_ni,
        f.total_liab, f.total_equity, f.current_assets, f.current_liab
    FROM financials_annual f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
),
labeled AS (
    SELECT *,
        CASE
            WHEN prev_op IS NULL                  THEN 'n/a'
            WHEN prev_op <= 0 AND op_income > 0   THEN '흑자전환'
            WHEN prev_op > 0  AND op_income <= 0  THEN '적자전환'
            WHEN prev_op <= 0 AND op_income <= 0  THEN '적자지속'
            WHEN op_income >= prev_op             THEN '흑자확대'
            ELSE                                       '흑자축소'
        END AS op_status,
        ROUND(100.0 * total_liab / NULLIF(total_equity, 0), 1)       AS debt_ratio_pct,
        ROUND(100.0 * current_assets / NULLIF(current_liab, 0), 1)   AS current_ratio_pct
    FROM seq
)
SELECT
    sector, corp_name, fiscal_year,
    ROUND(prev_op   / 1000.0, 1) AS prev_op_bn,
    ROUND(op_income / 1000.0, 1) AS op_income_bn,
    op_status,
    ROUND(net_income / 1000.0, 1) AS net_income_bn,
    debt_ratio_pct,
    current_ratio_pct,
    -- 간단한 건전성 플래그: 부채비율 100% 이하 & 유동비율 150% 이상
    CASE WHEN debt_ratio_pct <= 100 AND current_ratio_pct >= 150 THEN 'Y' ELSE '' END AS healthy_flag
FROM labeled
WHERE fiscal_year >= 2024
ORDER BY
    CASE op_status WHEN '흑자전환' THEN 1 WHEN '적자전환' THEN 2 WHEN '적자지속' THEN 3
                   WHEN '흑자확대' THEN 4 ELSE 5 END,
    fiscal_year DESC, corp_name;
