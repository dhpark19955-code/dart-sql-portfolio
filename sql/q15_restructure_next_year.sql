-- Q15. 구조변경·자금조달 공시가 있던 해의 다음 해 매출은 어떻게 움직였나 (이벤트 -> 이듬해 실적)
-- 기법: 회사 x 연도 뼈대에 공시 건수를 LEFT JOIN, LEAD 로 다음 해 매출·영업이익을 같은 행에, 이벤트 유무별 분포 비교
-- 읽는 법: event_year 행 = 그 해 공시가 있었던 회사·연도. next_rev_yoy = 다음 해 매출 증가율
--          맨 아래 'ALL_*' 요약 행은 이벤트 있음/없음 회사·연도의 다음 해 매출 증가율 중앙값
-- 주의: 2023~2024 공시만 다음 해(2024~2025) 실적이 있다. 표본이 작고 공시 성격(합병 vs 분할)이 섞여 있어 방향만 본다

WITH grid AS (
    SELECT d.corp_code, d.corp_name, i.sector_mid, w.fiscal_year, w.revenue, w.op_income,
           LEAD(w.revenue)   OVER (PARTITION BY d.corp_code ORDER BY w.fiscal_year) AS next_rev,
           LEAD(w.op_income) OVER (PARTITION BY d.corp_code ORDER BY w.fiscal_year) AS next_op
    FROM dim_company d
    JOIN dim_industry i ON i.ksic2 = SUBSTR(d.induty_code, 1, 2)
    JOIN v_fin_annual w ON w.corp_code = d.corp_code AND w.fiscal_year BETWEEN 2022 AND 2025
    WHERE i.is_financial = 0
),
ev AS (
    SELECT corp_code, fiscal_year,
           SUM(CASE WHEN event_type = 'restructure' AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_restructure,
           SUM(CASE WHEN event_type = 'financing'   AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_financing,
           MIN(CASE WHEN event_type IN ('restructure', 'financing') AND is_amendment = 0 THEN report_nm END) AS sample_report
    FROM filings_universe
    GROUP BY corp_code, fiscal_year
),
joined AS (
    SELECT g.*, COALESCE(e.n_restructure, 0) AS n_restructure, COALESCE(e.n_financing, 0) AS n_financing, e.sample_report,
           ROUND(100.0 * (g.next_rev - g.revenue) / NULLIF(g.revenue, 0), 1) AS next_rev_yoy_pct,
           CASE WHEN g.op_income > 0 THEN ROUND(100.0 * (g.next_op - g.op_income) / g.op_income, 1) END AS next_op_yoy_pct
    FROM grid g
    LEFT JOIN ev e ON e.corp_code = g.corp_code AND e.fiscal_year = g.fiscal_year
    WHERE g.fiscal_year BETWEEN 2023 AND 2024 AND g.next_rev IS NOT NULL AND g.revenue > 0
),
detail AS (
    SELECT 'event_year' AS row_type, corp_name, sector_mid, fiscal_year AS event_year,
           n_restructure, n_financing, sample_report,
           ROUND(revenue / 1000.0, 0) AS rev_bn, next_rev_yoy_pct, next_op_yoy_pct
    FROM joined
    WHERE n_restructure > 0
),
summary_src AS (
    SELECT CASE WHEN n_restructure > 0 THEN 'ALL_restructure_filed'
                WHEN n_financing   > 0 THEN 'ALL_financing_only'
                ELSE 'ALL_no_event' END AS grp,
           next_rev_yoy_pct AS v
    FROM joined
    WHERE next_rev_yoy_pct IS NOT NULL
),
ranked AS (
    SELECT grp, v,
           ROW_NUMBER() OVER (PARTITION BY grp ORDER BY v) AS rn,
           COUNT(*)     OVER (PARTITION BY grp)            AS cnt
    FROM summary_src
),
summary AS (
    SELECT grp AS row_type, NULL AS corp_name, NULL AS sector_mid, NULL AS event_year,
           NULL AS n_restructure, NULL AS n_financing,
           'n=' || CAST(MAX(cnt) AS VARCHAR) AS sample_report,
           NULL AS rev_bn,
           ROUND(AVG(CASE WHEN rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER)) THEN v END), 1) AS next_rev_yoy_pct,
           NULL AS next_op_yoy_pct
    FROM ranked
    GROUP BY grp
)
SELECT * FROM detail
UNION ALL
SELECT * FROM summary
ORDER BY row_type, next_rev_yoy_pct DESC;
