-- Q5. 2025년 주가 수익률은 실적 변화를 따라갔나?
-- 기법: FIRST_VALUE / LAST_VALUE (연초·연말 종가), 일별 테이블을 연도 단위로 집계 후 재무와 JOIN,
--       MAX/MIN OVER로 연중 고가-저가 변동폭 계산 (순서 무시, 진짜 MDD는 아님)
-- 해석 주의: 13개 표본, 1개 연도 -> 통계적 결론이 아니라 "눈에 띄는 괴리"를 찾는 용도

WITH p AS (
    SELECT
        stock_code,
        CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr,
        trade_date, close,
        FIRST_VALUE(close) OVER w  AS first_close,
        LAST_VALUE(close)  OVER w  AS last_close,
        MAX(close)         OVER w  AS high_close,
        MIN(close)         OVER w  AS low_close
    FROM prices_daily
    WINDOW w AS (PARTITION BY stock_code, SUBSTR(trade_date, 1, 4)
                 ORDER BY trade_date
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
yearly AS (
    SELECT DISTINCT stock_code, yr, first_close, last_close, high_close, low_close
    FROM p
),
fund AS (
    SELECT
        f.corp_code, f.fiscal_year, f.op_income,
        LAG(f.op_income) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_op
    FROM financials_annual f
    WHERE f.fs_div = 'CFS'
)
SELECT
    c.sector,
    c.corp_name,
    y.yr                                                                  AS fiscal_year,
    y.first_close, y.last_close,
    ROUND(100.0 * (y.last_close / y.first_close - 1), 1)                  AS price_return_pct,
    ROUND(100.0 * (y.low_close  / y.high_close - 1), 1)                   AS high_low_range_pct,
    ROUND(fd.prev_op   / 1000.0, 1)                                       AS prev_op_bn,
    ROUND(fd.op_income / 1000.0, 1)                                       AS op_income_bn,
    CASE WHEN fd.prev_op > 0
         THEN ROUND(100.0 * (fd.op_income - fd.prev_op) / fd.prev_op, 1) END AS op_change_pct,
    -- 괴리 라벨: 이익은 늘었는데 주가가 빠졌거나, 그 반대
    CASE
        WHEN fd.op_income > fd.prev_op AND y.last_close < y.first_close THEN '이익↑ 주가↓'
        WHEN fd.op_income < fd.prev_op AND y.last_close > y.first_close THEN '이익↓ 주가↑'
        ELSE ''
    END AS divergence
FROM yearly y
JOIN companies c ON c.stock_code = y.stock_code
JOIN fund fd     ON fd.corp_code = c.corp_code AND fd.fiscal_year = y.yr
WHERE y.yr = 2025
ORDER BY price_return_pct DESC;
