# q16_universe_filings_vs_price

Q16. (q7 확장) 200사: 주요사항보고서를 낸 해의 주가 수익률·변동폭은 안 낸 해와 다른가
기법: 회사 x 연도 뼈대(CROSS JOIN) + 공시 집계 LEFT JOIN, FIRST_VALUE/LAST_VALUE 로 연간 수익률, MAX/MIN 으로 변동폭,
등가중 지수(v_universe_index) 대비 초과수익률, 유형별 그룹 중앙값(창 함수)
읽는 법: 유형별 filed / none 그룹의 회사·연도 수, 연간 수익률 중앙값, 지수 대비 초과수익 중앙값, 고저 변동폭 중앙값
주의: 13사 q7 과 같은 동시 관찰. 2025 한 해의 시장 급등(지수 참조)이 결과를 지배할 수 있어 초과수익률을 같이 본다. 정정공시 제외

## Result (6 rows)

| event_type   | grp   |   n_company_years |   ret_median_pct |   excess_vs_index_median_pct |   range_median_pct |
|:-------------|:------|------------------:|-----------------:|-----------------------------:|-------------------:|
| financing    | filed |                37 |             26.7 |                         -9.2 |               81.3 |
| financing    | none  |               544 |             19   |                        -14.9 |               68.5 |
| restructure  | filed |                16 |             22.4 |                        -18   |              103.1 |
| restructure  | none  |               565 |             19.4 |                        -14.9 |               68.6 |
| treasury     | filed |               187 |             26.3 |                        -12   |               74.3 |
| treasury     | none  |               394 |             17.2 |                        -16.2 |               67.9 |

## SQL

```sql
-- Q16. (q7 확장) 200사: 주요사항보고서를 낸 해의 주가 수익률·변동폭은 안 낸 해와 다른가
-- 기법: 회사 x 연도 뼈대(CROSS JOIN) + 공시 집계 LEFT JOIN, FIRST_VALUE/LAST_VALUE 로 연간 수익률, MAX/MIN 으로 변동폭,
--       등가중 지수(v_universe_index) 대비 초과수익률, 유형별 그룹 중앙값(창 함수)
-- 읽는 법: 유형별 filed / none 그룹의 회사·연도 수, 연간 수익률 중앙값, 지수 대비 초과수익 중앙값, 고저 변동폭 중앙값
-- 주의: 13사 q7 과 같은 동시 관찰. 2025 한 해의 시장 급등(지수 참조)이 결과를 지배할 수 있어 초과수익률을 같이 본다. 정정공시 제외

WITH px AS (
    SELECT p.stock_code, CAST(SUBSTR(p.trade_date, 1, 4) AS INTEGER) AS yr, p.trade_date, p.adj_close, p.close,
           FIRST_VALUE(p.adj_close) OVER w AS first_px,
           LAST_VALUE(p.adj_close)  OVER w AS last_px,
           MAX(p.close) OVER w AS high_px,
           MIN(p.close) OVER w AS low_px
    FROM prices_universe p
    WINDOW w AS (PARTITION BY p.stock_code, SUBSTR(p.trade_date, 1, 4) ORDER BY p.trade_date
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
yearly AS (
    SELECT DISTINCT stock_code, yr, first_px, last_px, high_px, low_px FROM px
),
idx AS (
    SELECT CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr,
           FIRST_VALUE(idx) OVER w AS idx_first,
           LAST_VALUE(idx)  OVER w AS idx_last
    FROM v_universe_index
    WINDOW w AS (PARTITION BY SUBSTR(trade_date, 1, 4) ORDER BY trade_date
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
idx_y AS (SELECT DISTINCT yr, idx_first, idx_last FROM idx),
ev AS (
    SELECT corp_code, fiscal_year,
           SUM(CASE WHEN event_type = 'treasury'    AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_treasury,
           SUM(CASE WHEN event_type = 'financing'   AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_financing,
           SUM(CASE WHEN event_type = 'restructure' AND is_amendment = 0 THEN 1 ELSE 0 END) AS n_restructure
    FROM filings_universe
    GROUP BY corp_code, fiscal_year
),
base AS (
    SELECT d.corp_code, d.corp_name, y.yr,
           COALESCE(e.n_treasury, 0) AS n_treasury, COALESCE(e.n_financing, 0) AS n_financing, COALESCE(e.n_restructure, 0) AS n_restructure,
           100.0 * (y.last_px / y.first_px - 1)                                           AS ret_pct,
           100.0 * (y.last_px / y.first_px - i.idx_last / i.idx_first)                   AS excess_pct,
           100.0 * (y.high_px - y.low_px) / NULLIF(y.low_px, 0)                          AS range_pct
    FROM dim_company d
    JOIN yearly y ON y.stock_code = d.stock_code
    JOIN idx_y  i ON i.yr = y.yr
    LEFT JOIN ev e ON e.corp_code = d.corp_code AND e.fiscal_year = y.yr
    WHERE y.yr BETWEEN 2023 AND 2025 AND y.first_px > 0
),
grouped AS (
    SELECT 'treasury' AS event_type, CASE WHEN n_treasury > 0 THEN 'filed' ELSE 'none' END AS grp, corp_name, yr, ret_pct, excess_pct, range_pct FROM base
    UNION ALL
    SELECT 'financing', CASE WHEN n_financing > 0 THEN 'filed' ELSE 'none' END, corp_name, yr, ret_pct, excess_pct, range_pct FROM base
    UNION ALL
    SELECT 'restructure', CASE WHEN n_restructure > 0 THEN 'filed' ELSE 'none' END, corp_name, yr, ret_pct, excess_pct, range_pct FROM base
),
long_m AS (
    SELECT event_type, grp, 'ret'    AS metric, ret_pct    AS v FROM grouped
    UNION ALL SELECT event_type, grp, 'excess', excess_pct FROM grouped
    UNION ALL SELECT event_type, grp, 'range',  range_pct  FROM grouped
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY event_type, grp, metric ORDER BY v) AS rn,
              COUNT(*)     OVER (PARTITION BY event_type, grp, metric)            AS cnt
    FROM long_m WHERE v IS NOT NULL
),
med AS (
    SELECT event_type, grp, metric, AVG(v) AS median_v
    FROM ranked
    WHERE rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER))
    GROUP BY event_type, grp, metric
),
cnt AS (SELECT event_type, grp, COUNT(*) AS n_company_years FROM grouped GROUP BY event_type, grp)
SELECT c.event_type, c.grp, c.n_company_years,
       ROUND(MAX(CASE WHEN m.metric = 'ret'    THEN m.median_v END), 1) AS ret_median_pct,
       ROUND(MAX(CASE WHEN m.metric = 'excess' THEN m.median_v END), 1) AS excess_vs_index_median_pct,
       ROUND(MAX(CASE WHEN m.metric = 'range'  THEN m.median_v END), 1) AS range_median_pct
FROM cnt c
LEFT JOIN med m ON m.event_type = c.event_type AND m.grp = c.grp
GROUP BY c.event_type, c.grp, c.n_company_years
ORDER BY c.event_type, c.grp;
```
