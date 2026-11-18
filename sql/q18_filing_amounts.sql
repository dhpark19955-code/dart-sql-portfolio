-- Q18. 공시 본문의 금액을 붙이면 무엇이 달라지나 - 자금조달 규모(자본총계 대비) x 공시일 주가 반응, 합병 상대 규모 x 이듬해 매출
-- 기법: 공시 본문 파싱 테이블(filing_details) 을 공시 목록·재무 mart·주가에 JOIN,
--       조달액 / 직전 연도 자본총계 로 규모 구간(CASE), 구간별 +5 거래일 초과수익 중앙값(창 함수), 합병은 상대회사 매출 / 자사 매출 비율과 LEAD 로 이듬해 매출
-- 읽는 법: section = 'A_financing_size' 는 조달 규모 구간별 건수·초과수익 중앙값·양수 비율. 'B_merger' 는 합병 1건 1행
--          'C_parse_coverage' 는 본문 72건 중 핵심 수치를 뽑은 비율 (파서 품질)
-- 주의: 72건(정정 제외 자금조달·구조변경)만 파싱. 자본으로 인정되는 채무증권(신종자본증권)은 금융사 자본확충이라 조달 목적이 다름 - doc_type 으로 구분

WITH fin AS (
    SELECT d.rcept_no, d.corp_code, d.doc_type, d.amount_krw, d.coupon_pct, d.issue_method, d.purpose_debt, d.purpose_facility,
           f.rcept_dt, f.fiscal_year, c.corp_name, c.stock_code, c.is_financial,
           w.total_equity * 1000000.0 AS equity_prev_krw
    FROM filing_details d
    JOIN filings_universe f ON f.rcept_no = d.rcept_no
    JOIN dim_company c      ON c.corp_code = d.corp_code
    LEFT JOIN v_fin_annual w ON w.corp_code = d.corp_code AND w.fiscal_year = f.fiscal_year - 1
    WHERE d.doc_type IN ('bond', 'capital_security', 'rights_issue') AND d.amount_krw > 0
      -- 영구전환사채는 '전환사채권발행결정'과 '자본으로인정되는채무증권발행결정' 두 공시가 같은 날 같은 금액으로 나온다 → 사채 쪽만 센다
      AND NOT EXISTS (SELECT 1 FROM filing_details d2 JOIN filings_universe f2 ON f2.rcept_no = d2.rcept_no
                      WHERE d.doc_type = 'capital_security' AND d2.doc_type = 'bond'
                        AND d2.corp_code = d.corp_code AND f2.rcept_dt = f.rcept_dt AND d2.amount_krw = d.amount_krw)
),
sized AS (
    SELECT *,
           100.0 * amount_krw / NULLIF(equity_prev_krw, 0) AS pct_of_equity,
           CASE WHEN equity_prev_krw IS NULL THEN 'n/a'
                WHEN 100.0 * amount_krw / equity_prev_krw < 1  THEN '1_under_1pct'
                WHEN 100.0 * amount_krw / equity_prev_krw < 5  THEN '2_1_to_5pct'
                ELSE '3_over_5pct' END AS size_bucket
    FROM fin
),
ev AS (
    SELECT s.*,
           (SELECT MAX(p.trade_seq) FROM prices_universe p WHERE p.stock_code = s.stock_code AND p.trade_date < s.rcept_dt) AS seq0
    FROM sized s
),
ar AS (
    SELECT e.*,
           100.0 * ((p5.adj_close / p0.adj_close - 1) - (i5.idx / i0.idx - 1)) AS ar_5
    FROM ev e
    JOIN prices_universe p0 ON p0.stock_code = e.stock_code AND p0.trade_seq = e.seq0
    LEFT JOIN prices_universe p5 ON p5.stock_code = e.stock_code AND p5.trade_seq = e.seq0 + 5
    LEFT JOIN v_universe_index i0 ON i0.trade_date = p0.trade_date
    LEFT JOIN v_universe_index i5 ON i5.trade_date = p5.trade_date
),
ranked AS (
    SELECT doc_type, size_bucket, ar_5, pct_of_equity,
           ROW_NUMBER() OVER (PARTITION BY doc_type, size_bucket ORDER BY ar_5) AS rn,
           COUNT(*)     OVER (PARTITION BY doc_type, size_bucket)               AS cnt
    FROM ar
    WHERE ar_5 IS NOT NULL
),
a_rows AS (
    SELECT 'A_financing_size' AS section, doc_type, size_bucket AS grp,
           MAX(cnt) AS n,
           ROUND(AVG(pct_of_equity), 1) AS avg_pct_of_equity,
           ROUND(AVG(CASE WHEN rn IN (CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER), CAST(FLOOR((cnt + 2) / 2.0) AS INTEGER)) THEN ar_5 END), 2) AS ar5_median_pct,
           ROUND(100.0 * SUM(CASE WHEN ar_5 > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_positive,
           NULL AS corp_name, NULL AS counterparty, NULL AS merger_ratio, NULL AS counterparty_rev_pct_of_own, NULL AS next_rev_yoy_pct
    FROM ranked
    GROUP BY doc_type, size_bucket
),
mg AS (
    SELECT d.rcept_no, c.corp_name, d.counterparty, d.merger_ratio, d.counterparty_revenue_krw, f.fiscal_year,
           w0.revenue AS rev0, w1.revenue AS rev1
    FROM filing_details d
    JOIN filings_universe f ON f.rcept_no = d.rcept_no
    JOIN dim_company c      ON c.corp_code = d.corp_code
    LEFT JOIN v_fin_annual w0 ON w0.corp_code = d.corp_code AND w0.fiscal_year = f.fiscal_year
    LEFT JOIN v_fin_annual w1 ON w1.corp_code = d.corp_code AND w1.fiscal_year = f.fiscal_year + 1
    WHERE d.doc_type = 'merger'
),
b_rows AS (
    SELECT 'B_merger' AS section, 'merger' AS doc_type, CAST(fiscal_year AS VARCHAR) AS grp, NULL AS n, NULL AS avg_pct_of_equity,
           NULL AS ar5_median_pct, NULL AS pct_positive,
           corp_name, counterparty,
           CAST(merger_ratio AS VARCHAR) AS merger_ratio,          -- 소수 7자리 보존 (결과 md 가 실수를 1자리로 줄이므로 문자열로)
           ROUND(100.0 * counterparty_revenue_krw / NULLIF(rev0 * 1000000.0, 0), 1) AS counterparty_rev_pct_of_own,
           ROUND(100.0 * (rev1 - rev0) / NULLIF(rev0, 0), 1) AS next_rev_yoy_pct
    FROM mg
),
c_rows AS (
    SELECT 'C_parse_coverage' AS section, doc_type, 'all' AS grp, COUNT(*) AS n,
           ROUND(100.0 * SUM(CASE WHEN parse_note IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS avg_pct_of_equity,   -- 여기서는 '파싱 성공률 %'
           NULL AS ar5_median_pct, NULL AS pct_positive, NULL AS corp_name, NULL AS counterparty, NULL AS merger_ratio,
           NULL AS counterparty_rev_pct_of_own, NULL AS next_rev_yoy_pct
    FROM filing_details
    GROUP BY doc_type
)
SELECT * FROM (
    SELECT * FROM a_rows UNION ALL SELECT * FROM b_rows UNION ALL SELECT * FROM c_rows
) u
ORDER BY section, doc_type, grp;
