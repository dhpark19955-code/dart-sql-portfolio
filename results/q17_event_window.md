# q17_event_window

Q17. 공시일 전후 주가는 어떻게 움직였나 - 이벤트 윈도우 (공시 접수일 전 종가 대비 +1·+5·+20 거래일, 등가중 지수 대비 초과수익)
기법: 공시일 직전 거래일을 상관 서브쿼리(MAX(trade_seq) WHERE trade_date < 공시일)로 찾고, trade_seq + k 로 JOIN 해 k 거래일 뒤 종가를 같은 행에,
지수는 날짜로 JOIN, 유형 x 윈도우별 중앙값·양수 비율(창 함수 + 조건부 집계), 요약 + 상세(|초과수익 5일| 상위) UNION ALL
읽는 법: row_type = 'summary' 행은 유형·윈도우별 n, 초과수익 중앙값, 양수 비율. 'detail' 행은 +5 거래일 초과수익 절댓값 상위 10건
주의: 초과수익 = 종목 수익률 - 유니버스 등가중 지수 수익률 (베타 미조정, 통계 검정 없음). 같은 날 같은 회사의 공시 여러 건은 각각 1건으로 센다.
정정공시 제외. 공시 접수가 장 마감 후면 +1 거래일이 사실상 첫 반응일

## Result (22 rows)

| row_type   | event_type   | win   |   n |   abnormal_ret_median_pct |   pct_positive | corp_name   | rcept_dt   | report_nm               |   ar_5d_pct |   raw_5d_pct |
|:-----------|:-------------|:------|----:|--------------------------:|---------------:|:------------|:-----------|:------------------------|------------:|-------------:|
| summary    | financing    | +1d   |  50 |                       0.1 |           52   |             |            |                         |             |              |
| summary    | financing    | +5d   |  48 |                      -0.6 |           43.8 |             |            |                         |             |              |
| summary    | financing    | +20d  |  46 |                      -2.1 |           41.3 |             |            |                         |             |              |
| summary    | other        | +1d   |  17 |                      -0.9 |           47.1 |             |            |                         |             |              |
| summary    | other        | +5d   |  17 |                      -0.8 |           47.1 |             |            |                         |             |              |
| summary    | other        | +20d  |  15 |                      -4.5 |           13.3 |             |            |                         |             |              |
| summary    | restructure  | +1d   |  17 |                       1   |           70.6 |             |            |                         |             |              |
| summary    | restructure  | +5d   |  17 |                       0.3 |           52.9 |             |            |                         |             |              |
| summary    | restructure  | +20d  |  17 |                      -1.1 |           35.3 |             |            |                         |             |              |
| summary    | treasury     | +1d   | 455 |                      -0.1 |           47.9 |             |            |                         |             |              |
| summary    | treasury     | +5d   | 453 |                      -0.2 |           48.8 |             |            |                         |             |              |
| summary    | treasury     | +20d  | 447 |                      -0.8 |           46.8 |             |            |                         |             |              |
| detail     | financing    | +5d   |     |                           |                | SK이노베이션     | 2025-06-25 | 주요사항보고서(교환사채권발행결정)      |        23.8 |         24.3 |
| detail     | treasury     | +5d   |     |                           |                | DB하이텍       | 2025-02-05 | 주요사항보고서(자기주식처분결정)       |        34.4 |         36.5 |
| detail     | treasury     | +5d   |     |                           |                | 에이피알        | 2025-08-04 | 주요사항보고서(자기주식취득신탁계약해지결정) |        29.7 |         33.7 |
| detail     | treasury     | +5d   |     |                           |                | SK스퀘어       | 2025-09-30 | 주요사항보고서(자기주식취득신탁계약해지결정) |        24.1 |         24.6 |
| detail     | treasury     | +5d   |     |                           |                | SK이노베이션     | 2025-06-25 | 주요사항보고서(자기주식처분결정)       |        23.8 |         24.3 |
| detail     | treasury     | +5d   |     |                           |                | 아모레퍼시픽홀딩스   | 2024-08-06 | 주요사항보고서(자기주식처분결정)       |       -21   |        -12.5 |
| detail     | treasury     | +5d   |     |                           |                | LS에코에너지     | 2023-08-16 | 주요사항보고서(자기주식처분결정)       |       -22   |        -25   |
| detail     | treasury     | +5d   |     |                           |                | 고려아연        | 2025-03-13 | 주요사항보고서(자기주식처분결정)       |       -24.6 |        -22.3 |
| detail     | treasury     | +5d   |     |                           |                | 한진칼         | 2025-05-15 | 주요사항보고서(자기주식처분결정)       |       -25.6 |        -26.1 |
| detail     | treasury     | +5d   |     |                           |                | 아모레퍼시픽      | 2024-08-06 | 주요사항보고서(자기주식처분결정)       |       -32.9 |        -24.5 |

## SQL

```sql
-- Q17. 공시일 전후 주가는 어떻게 움직였나 - 이벤트 윈도우 (공시 접수일 전 종가 대비 +1·+5·+20 거래일, 등가중 지수 대비 초과수익)
-- 기법: 공시일 직전 거래일을 상관 서브쿼리(MAX(trade_seq) WHERE trade_date < 공시일)로 찾고, trade_seq + k 로 JOIN 해 k 거래일 뒤 종가를 같은 행에,
--       지수는 날짜로 JOIN, 유형 x 윈도우별 중앙값·양수 비율(창 함수 + 조건부 집계), 요약 + 상세(|초과수익 5일| 상위) UNION ALL
-- 읽는 법: row_type = 'summary' 행은 유형·윈도우별 n, 초과수익 중앙값, 양수 비율. 'detail' 행은 +5 거래일 초과수익 절댓값 상위 10건
-- 주의: 초과수익 = 종목 수익률 - 유니버스 등가중 지수 수익률 (베타 미조정, 통계 검정 없음). 같은 날 같은 회사의 공시 여러 건은 각각 1건으로 센다.
--       정정공시 제외. 공시 접수가 장 마감 후면 +1 거래일이 사실상 첫 반응일

WITH f AS (
    SELECT fu.rcept_no, fu.corp_code, d.corp_name, d.stock_code, fu.event_type, fu.report_nm, fu.rcept_dt,
           (SELECT MAX(p.trade_seq) FROM prices_universe p
             WHERE p.stock_code = d.stock_code AND p.trade_date < fu.rcept_dt) AS seq0
    FROM filings_universe fu
    JOIN dim_company d ON d.corp_code = fu.corp_code
    WHERE fu.is_amendment = 0
),
w AS (
    SELECT f.*,
           p0.trade_date AS d0, p0.adj_close AS px0,
           p1.trade_date AS d1, p1.adj_close AS px1,
           p5.trade_date AS d5, p5.adj_close AS px5,
           p20.trade_date AS d20, p20.adj_close AS px20
    FROM f
    JOIN prices_universe p0  ON p0.stock_code  = f.stock_code AND p0.trade_seq  = f.seq0
    LEFT JOIN prices_universe p1  ON p1.stock_code  = f.stock_code AND p1.trade_seq  = f.seq0 + 1
    LEFT JOIN prices_universe p5  ON p5.stock_code  = f.stock_code AND p5.trade_seq  = f.seq0 + 5
    LEFT JOIN prices_universe p20 ON p20.stock_code = f.stock_code AND p20.trade_seq = f.seq0 + 20
),
ar AS (
    SELECT w.rcept_no, w.corp_name, w.event_type, w.report_nm, w.rcept_dt,
           100.0 * ((w.px1  / w.px0 - 1) - (i1.idx  / i0.idx - 1)) AS ar_1,
           100.0 * ((w.px5  / w.px0 - 1) - (i5.idx  / i0.idx - 1)) AS ar_5,
           100.0 * ((w.px20 / w.px0 - 1) - (i20.idx / i0.idx - 1)) AS ar_20,
           100.0 * (w.px5 / w.px0 - 1) AS raw_5
    FROM w
    JOIN v_universe_index i0  ON i0.trade_date  = w.d0
    LEFT JOIN v_universe_index i1  ON i1.trade_date  = w.d1
    LEFT JOIN v_universe_index i5  ON i5.trade_date  = w.d5
    LEFT JOIN v_universe_index i20 ON i20.trade_date = w.d20
    WHERE w.px0 > 0
),
long_ar AS (
    SELECT event_type, '+1d'  AS win, ar_1  AS v FROM ar WHERE ar_1  IS NOT NULL
    UNION ALL SELECT event_type, '+5d',  ar_5  FROM ar WHERE ar_5  IS NOT NULL
    UNION ALL SELECT event_type, '+20d', ar_20 FROM ar WHERE ar_20 IS NOT NULL
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY event_type, win ORDER BY v) AS rn,
              COUNT(*)     OVER (PARTITION BY event_type, win)            AS cnt
    FROM long_ar
),
summary AS (
    SELECT 'summary' AS row_type, event_type, win,
           MAX(cnt) AS n,
           ROUND(AVG(CASE WHEN rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER)) THEN v END), 2) AS abnormal_ret_median_pct,
           ROUND(100.0 * SUM(CASE WHEN v > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive,
           NULL AS corp_name, NULL AS rcept_dt, NULL AS report_nm, NULL AS ar_5d_pct, NULL AS raw_5d_pct
    FROM ranked
    GROUP BY event_type, win
),
detail AS (
    SELECT 'detail' AS row_type, event_type, '+5d' AS win, NULL AS n, NULL AS abnormal_ret_median_pct, NULL AS pct_positive,
           corp_name, rcept_dt, report_nm, ROUND(ar_5, 1) AS ar_5d_pct, ROUND(raw_5, 1) AS raw_5d_pct
    FROM ar
    WHERE ar_5 IS NOT NULL
    ORDER BY ABS(ar_5) DESC
    LIMIT 10
)
SELECT *
FROM (SELECT * FROM summary UNION ALL SELECT * FROM detail) u     -- UNION 결과를 감싸야 ORDER BY 에 식을 쓸 수 있다 (SQLite)
ORDER BY row_type DESC, event_type, CASE win WHEN '+1d' THEN 1 WHEN '+5d' THEN 2 ELSE 3 END, ar_5d_pct DESC;
```
