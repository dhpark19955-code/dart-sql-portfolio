# q5_price_return_vs_profit

Q5. 2025년 주가 수익률은 실적 변화를 따라갔나?
기법: FIRST_VALUE / LAST_VALUE (연초·연말 종가), 일별 테이블을 연도 단위로 집계 후 재무와 JOIN,
MAX/MIN OVER로 연중 고가-저가 변동폭 계산 (순서 무시, 진짜 MDD는 아님)
해석 주의: 13개 표본, 1개 연도 -> 통계적 결론이 아니라 "눈에 띄는 괴리"를 찾는 용도

## Result (12 rows)

| sector     | corp_name   |   fiscal_year |   first_close |   last_close |   price_return_pct |   high_low_range_pct |   prev_op_bn |   op_income_bn |   op_change_pct | divergence   |
|:-----------|:------------|--------------:|--------------:|-------------:|-------------------:|---------------------:|-------------:|---------------:|----------------:|:-------------|
| IT인프라/SaaS | 가비아         |          2025 |        17,200 |       32,250 |               87.5 |                -55.5 |         35.1 |           40.5 |            15.3 |              |
| 인터넷플랫폼     | NHN         |          2025 |        17,590 |       29,050 |               65.2 |                -48.3 |        -32.6 |          132.4 |                 |              |
| 인터넷플랫폼     | 카카오         |          2025 |        37,450 |       60,100 |               60.5 |                -49.2 |        495.3 |          732   |            47.8 |              |
| IT인프라/SaaS | 케이아이엔엑스     |          2025 |        77,300 |      121,100 |               56.7 |                -42.2 |         23.7 |           23.9 |             0.6 |              |
| IT인프라/SaaS | 삼성에스디에스     |          2025 |       124,500 |      171,500 |               37.8 |                -43.4 |        911.1 |          957.1 |             5   |              |
| IT인프라/SaaS | 헥토이노베이션     |          2025 |        12,320 |       16,120 |               30.8 |                -38.3 |         48.9 |           50.2 |             2.7 |              |
| 인터넷플랫폼     | NAVER       |          2025 |       193,800 |      242,500 |               25.1 |                -39.1 |       1979.3 |         2208.1 |            11.6 |              |
| 게임         | NC          |          2025 |       182,000 |      201,500 |               10.7 |                -43.9 |       -109.2 |           16.1 |                 |              |
| 게임         | 넷마블         |          2025 |        50,600 |       48,250 |               -4.6 |                -44.9 |        215.6 |          352.5 |            63.5 | 이익↑ 주가↓      |
| 게임         | 카카오게임즈      |          2025 |        16,300 |       14,900 |               -8.6 |                -44.6 |         19.1 |          -39.6 |          -306.8 |              |
| 게임         | 크래프톤        |          2025 |       316,500 |      246,000 |              -22.3 |                -37.4 |       1182.5 |         1054.4 |           -10.8 |              |
| 인터넷플랫폼     | SOOP        |          2025 |        90,200 |       67,800 |              -24.8 |                -47.3 |        113.5 |          124.8 |            10   | 이익↑ 주가↓      |

## SQL

```sql
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
```
