-- Q8. 분기 데이터는 믿을 만한가 - 누적/3개월 변환과 4분기 도출값 점검
-- 점검 1) 누적 -> 3개월 왕복: 3개월값을 SUM OVER 로 누적한 뒤 LAG 차분으로 되돌리면 원값과 같아야 한다
--         (대형 데이터에서 누적값만 오는 API 를 처리할 때 쓰는 변환 SQL 을 그대로 검증)
-- 점검 2) 분기 합 = 연간: 4분기가 연간 - 1~3분기로 도출되므로 정상이면 항상 통과. 4분기 도출에 NULL 이 끼면 FAIL
-- 점검 3) 4분기 도출값 이상치: 매출 <= 0 이거나 1~3분기 평균의 2배 초과면 연중 재분류 의심
--         (처음 빌드에서 카카오게임즈 2023·2024 가 걸림 -> 분기도 '최신 보고서 우선'으로 바꿔 2024 는 해소, 2023 은 남음)
-- 점검 4) 분기 재무상태표 항등식: 자산 = 부채 + 자본 (±2백만원)
-- 점검 5) 결측: 매출·영업이익·순이익 중 NULL 인 분기 (보충 CSV 누락 탐지)
-- 기법: SUM() OVER (ROWS UNBOUNDED PRECEDING), LAG, UNION ALL, HAVING, 조건부 집계

WITH cum AS (
    -- 3개월 -> 누적 (대형 데이터 설계의 역방향: API 가 누적만 줄 때는 이 결과가 입력이 된다)
    SELECT corp_code, fiscal_year, quarter, revenue,
           SUM(revenue) OVER (PARTITION BY corp_code, fiscal_year ORDER BY quarter
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rev_cum
    FROM financials_quarter
    WHERE fs_div = 'CFS'
),
back AS (
    -- 누적 -> 3개월: 같은 회사·연도·계정 안에서 직전 분기 누적을 뺀다. 1분기는 누적 그대로
    SELECT corp_code, fiscal_year, quarter, revenue,
           rev_cum - COALESCE(LAG(rev_cum) OVER (PARTITION BY corp_code, fiscal_year ORDER BY quarter), 0) AS rev_3m
    FROM cum
)

SELECT '1_cum_roundtrip' AS check_name,
       c.corp_name AS subject,
       b.fiscal_year || 'Q' || b.quarter AS detail,
       CASE WHEN b.rev_3m = b.revenue THEN 'OK' ELSE 'FAIL' END AS result,
       b.rev_3m - b.revenue AS diff_mn
FROM back b JOIN companies c ON c.corp_code = b.corp_code
WHERE b.rev_3m IS NOT b.revenue            -- 통과한 행은 생략 (NULL 안전 비교, SQLite 전용)

UNION ALL

SELECT '2_quarter_sum_vs_annual',
       c.corp_name,
       q.fiscal_year || ' rev: q_sum=' || COALESCE(SUM(q.revenue), 'NULL') || ', annual_latest=' || COALESCE(a.revenue, 'NULL'),
       CASE WHEN COUNT(*) <> 4 OR SUM(q.revenue) IS NULL THEN 'FAIL'
            WHEN ABS(SUM(q.revenue) - a.revenue) <= 2 THEN 'OK' ELSE 'FAIL' END,
       SUM(q.revenue) - a.revenue
FROM financials_quarter q
JOIN financials_annual a ON a.corp_code = q.corp_code AND a.fiscal_year = q.fiscal_year AND a.fs_div = q.fs_div
JOIN companies c ON c.corp_code = q.corp_code
WHERE q.fs_div = 'CFS'
GROUP BY c.corp_name, q.fiscal_year, a.revenue
HAVING COUNT(*) <> 4 OR ABS(SUM(q.revenue) - a.revenue) > 2 OR SUM(q.revenue) IS NULL

UNION ALL

SELECT '3_q4_outlier',
       c.corp_name,
       q4.fiscal_year || 'Q4 rev=' || q4.revenue || ', avg(Q1~3)=' || CAST(ROUND(p.avg_rev, 0) AS INTEGER),
       'WARN',
       NULL
FROM financials_quarter q4
JOIN (SELECT corp_code, fiscal_year, AVG(revenue) AS avg_rev
      FROM financials_quarter WHERE quarter <= 3 AND fs_div = 'CFS'
      GROUP BY corp_code, fiscal_year) p
     ON p.corp_code = q4.corp_code AND p.fiscal_year = q4.fiscal_year
JOIN companies c ON c.corp_code = q4.corp_code
WHERE q4.quarter = 4 AND q4.fs_div = 'CFS'
  AND (q4.revenue <= 0 OR q4.revenue > 2 * p.avg_rev)

UNION ALL

SELECT '4_bs_identity',
       c.corp_name,
       q.fiscal_year || 'Q' || q.quarter,
       'FAIL',
       q.total_assets - (q.total_liab + q.total_equity)
FROM financials_quarter q JOIN companies c ON c.corp_code = q.corp_code
WHERE ABS(q.total_assets - (q.total_liab + q.total_equity)) > 2

UNION ALL

SELECT '5_missing_pl',
       c.corp_name,
       q.fiscal_year || 'Q' || q.quarter || ' ' ||
           CASE WHEN q.revenue IS NULL THEN 'revenue ' ELSE '' END ||
           CASE WHEN q.op_income IS NULL THEN 'op_income ' ELSE '' END ||
           CASE WHEN q.net_income IS NULL THEN 'net_income' ELSE '' END,
       'WARN',
       NULL
FROM financials_quarter q JOIN companies c ON c.corp_code = q.corp_code
WHERE q.revenue IS NULL OR q.op_income IS NULL OR q.net_income IS NULL

UNION ALL

-- 요약 행: 점검 대상 규모를 같이 남긴다
SELECT '0_summary',
       'financials_quarter',
       'rows=' || COUNT(*) || ', derived_q4=' || SUM(is_derived) || ', years=' || MIN(fiscal_year) || '~' || MAX(fiscal_year),
       'INFO',
       NULL
FROM financials_quarter

ORDER BY check_name, subject, detail;
