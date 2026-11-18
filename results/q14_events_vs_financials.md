# q14_events_vs_financials

Q14. 주요사항보고서를 낸 회사와 안 낸 회사는 재무 상태가 다른가 (4단계: 공시 이벤트 x 재무 결합, 200사)
기법: 공시 유형별 집계(CASE 조건부 집계) -> 회사 x 유형 플래그, 재무 mart(v_fin_annual) 와 JOIN,
그룹별 중앙값(ROW_NUMBER + COUNT OVER, 엔진 공통), 세 유형을 UNION ALL 로 한 표에
읽는 법: 유형별로 '공시 있음' 그룹과 '없음' 그룹의 회사 수·부채비율 중앙값·영업이익률 중앙값·매출 CAGR 중앙값
예: financing 공시 있음 그룹의 부채비율 중앙값이 높다면 "차입·증자 공시는 이미 레버리지가 높은 회사에서 나온다"
주의: 금융업 제외(부채비율 개념이 다름). 2023~2025 공시와 FY2025 재무를 붙인 동시 관찰이며 인과가 아님. 정정공시는 건수에서 제외

## Result (6 rows)

| event_type   | grp   |   n_cos |   debt_ratio_median_pct |   opm_median_pct |   rev_cagr_median_pct | most_filings_company   |
|:-------------|:------|--------:|------------------------:|-----------------:|----------------------:|:-----------------------|
| financing    | filed |      25 |                    78.9 |              5.2 |                   8.3 | 아시아나항공                 |
| financing    | none  |     126 |                   101.5 |              7.1 |                   6.9 | BGF리테일                 |
| restructure  | filed |      10 |                    77.6 |              3.6 |                  14.4 | 카카오                    |
| restructure  | none  |     141 |                   106.5 |              7   |                   6.9 | BGF리테일                 |
| treasury     | filed |      66 |                    77.4 |              7.8 |                   6.7 | 셀트리온                   |
| treasury     | none  |      85 |                   113.1 |              6.6 |                   7.6 | BGF리테일                 |

## SQL

```sql
-- Q14. 주요사항보고서를 낸 회사와 안 낸 회사는 재무 상태가 다른가 (4단계: 공시 이벤트 x 재무 결합, 200사)
-- 기법: 공시 유형별 집계(CASE 조건부 집계) -> 회사 x 유형 플래그, 재무 mart(v_fin_annual) 와 JOIN,
--       그룹별 중앙값(ROW_NUMBER + COUNT OVER, 엔진 공통), 세 유형을 UNION ALL 로 한 표에
-- 읽는 법: 유형별로 '공시 있음' 그룹과 '없음' 그룹의 회사 수·부채비율 중앙값·영업이익률 중앙값·매출 CAGR 중앙값
--          예: financing 공시 있음 그룹의 부채비율 중앙값이 높다면 "차입·증자 공시는 이미 레버리지가 높은 회사에서 나온다"
-- 주의: 금융업 제외(부채비율 개념이 다름). 2023~2025 공시와 FY2025 재무를 붙인 동시 관찰이며 인과가 아님. 정정공시는 건수에서 제외

WITH ev AS (
    SELECT corp_code,
           SUM(CASE WHEN event_type = 'treasury'    AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_treasury,
           SUM(CASE WHEN event_type = 'financing'   AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_financing,
           SUM(CASE WHEN event_type = 'restructure' AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_restructure
    FROM filings_universe
    WHERE fiscal_year BETWEEN 2023 AND 2025
    GROUP BY corp_code
),
fin AS (
    SELECT d.corp_code, d.corp_name,
           COALESCE(e.n_treasury, 0)    AS n_treasury,
           COALESCE(e.n_financing, 0)   AS n_financing,
           COALESCE(e.n_restructure, 0) AS n_restructure,
           100.0 * w25.total_liab / NULLIF(w25.total_equity, 0)                          AS debt_ratio,
           100.0 * w25.op_income  / NULLIF(w25.revenue, 0)                               AS opm,
           100.0 * (POWER(w25.revenue * 1.0 / NULLIF(w21.revenue, 0), 0.25) - 1)         AS rev_cagr
    FROM dim_company d
    JOIN dim_industry i ON i.ksic2 = SUBSTR(d.induty_code, 1, 2)
    LEFT JOIN ev e ON e.corp_code = d.corp_code
    LEFT JOIN v_fin_annual w25 ON w25.corp_code = d.corp_code AND w25.fiscal_year = 2025
    LEFT JOIN v_fin_annual w21 ON w21.corp_code = d.corp_code AND w21.fiscal_year = 2021 AND w21.revenue > 0
    WHERE i.is_financial = 0 AND w25.revenue > 0
),
grouped AS (
    -- UNION 에서는 열을 명시한다: SQLite 가 '별칭, *' 조합에서 별칭을 잃는다
    SELECT 'treasury' AS event_type, CASE WHEN n_treasury > 0 THEN 'filed' ELSE 'none' END AS grp,
           corp_code, corp_name, n_treasury, n_financing, n_restructure, debt_ratio, opm, rev_cagr FROM fin
    UNION ALL
    SELECT 'financing', CASE WHEN n_financing > 0 THEN 'filed' ELSE 'none' END,
           corp_code, corp_name, n_treasury, n_financing, n_restructure, debt_ratio, opm, rev_cagr FROM fin
    UNION ALL
    SELECT 'restructure', CASE WHEN n_restructure > 0 THEN 'filed' ELSE 'none' END,
           corp_code, corp_name, n_treasury, n_financing, n_restructure, debt_ratio, opm, rev_cagr FROM fin
),
med AS (
    -- 지표 3개를 세로로 펼쳐 같은 중앙값 로직을 한 번만 쓴다
    SELECT event_type, grp, 'debt_ratio' AS metric, debt_ratio AS v FROM grouped WHERE debt_ratio IS NOT NULL
    UNION ALL
    SELECT event_type, grp, 'opm',        opm        FROM grouped WHERE opm IS NOT NULL
    UNION ALL
    SELECT event_type, grp, 'rev_cagr',   rev_cagr   FROM grouped WHERE rev_cagr IS NOT NULL
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY event_type, grp, metric ORDER BY v) AS rn,
           COUNT(*)     OVER (PARTITION BY event_type, grp, metric)            AS cnt
    FROM med
),
medians AS (
    SELECT event_type, grp, metric, AVG(v) AS median_v
    FROM ranked
    WHERE rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER))
    GROUP BY event_type, grp, metric
),
top_filer AS (
    -- 그룹 안에서 해당 유형 공시가 가장 많은 회사 (상관 서브쿼리 대신 창 함수 - 두 엔진 공통)
    SELECT event_type, grp, corp_name,
           ROW_NUMBER() OVER (PARTITION BY event_type, grp
                              ORDER BY CASE event_type WHEN 'treasury' THEN n_treasury
                                                       WHEN 'financing' THEN n_financing
                                                       ELSE n_restructure END DESC, corp_name) AS rn
    FROM grouped
),
cnt AS (
    SELECT event_type, grp, COUNT(*) AS n_cos FROM grouped GROUP BY event_type, grp
)
SELECT c.event_type, c.grp, c.n_cos,
       ROUND(MAX(CASE WHEN m.metric = 'debt_ratio' THEN m.median_v END), 1) AS debt_ratio_median_pct,
       ROUND(MAX(CASE WHEN m.metric = 'opm'        THEN m.median_v END), 1) AS opm_median_pct,
       ROUND(MAX(CASE WHEN m.metric = 'rev_cagr'   THEN m.median_v END), 1) AS rev_cagr_median_pct,
       MAX(t.corp_name)                                                     AS most_filings_company
FROM cnt c
LEFT JOIN medians   m ON m.event_type = c.event_type AND m.grp = c.grp
LEFT JOIN top_filer t ON t.event_type = c.event_type AND t.grp = c.grp AND t.rn = 1
GROUP BY c.event_type, c.grp, c.n_cos
ORDER BY c.event_type, c.grp;
```
