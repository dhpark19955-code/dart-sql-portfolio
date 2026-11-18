-- Q11. 새 계층 파이프라인(fin_annual_wide)이 1단계 테이블(financials_annual)과 같은 숫자를 내는가
-- 기법: 두 파이프라인의 교집합(13사 x 겹치는 연도)을 JOIN 해 계정별 차이를 UNPIVOT(UNION ALL)으로 한 표에
-- 읽는 법: diff_mn = 0 이면 같은 원천·같은 규칙. 0 이 아니면 (a) 1단계가 보충 CSV 로 채운 값(카카오 FY2022 매출 등)
--          (b) 2단계 유니버스에 그 회사가 없음(NULL) (c) 정정보고서 채택 차이 - 어느 쪽인지 note 로 표시
-- 주의: financials_annual 은 FY2020~2025, fin_annual_wide 는 사업보고서 2021~2025 기준 FY2019~2025 이므로 겹치는 연도만

WITH both_ AS (
    SELECT c.corp_name, a.fiscal_year,
           a.revenue AS rev_p1,   w.revenue AS rev_p2,
           a.op_income AS op_p1,  w.op_income AS op_p2,
           a.net_income AS ni_p1, w.net_income AS ni_p2,
           a.total_assets AS ta_p1, w.total_assets AS ta_p2,
           w.corp_code IS NULL AS not_in_universe
    FROM financials_annual a
    JOIN companies c ON c.corp_code = a.corp_code
    LEFT JOIN fin_annual_wide w ON w.corp_code = a.corp_code AND w.fiscal_year = a.fiscal_year AND w.fs_div = a.fs_div
    WHERE a.fs_div = 'CFS'
),
diffs AS (
    SELECT corp_name, fiscal_year, 'revenue'      AS account, rev_p1 AS phase1_mn, rev_p2 AS phase2_mn, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'op_income',  op_p1, op_p2, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'net_income', ni_p1, ni_p2, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'total_assets', ta_p1, ta_p2, not_in_universe FROM both_
)
SELECT corp_name, fiscal_year, account, phase1_mn, phase2_mn,
       phase2_mn - phase1_mn AS diff_mn,
       CASE WHEN not_in_universe THEN 'not in KOSPI top200 universe'
            WHEN phase2_mn IS NULL THEN 'phase2 NULL (account not mapped or year not loaded)'
            WHEN phase1_mn = phase2_mn THEN 'same'
            ELSE 'differs - check supplement / restatement' END AS note
FROM diffs
WHERE phase1_mn IS NOT phase2_mn           -- 같은 행은 생략 (IS NOT 은 NULL 안전 비교, SQLite 전용)
ORDER BY corp_name, fiscal_year, account;
