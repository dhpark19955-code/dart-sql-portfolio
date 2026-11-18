-- Q7. 주요사항보고서를 많이 낸 해에 주가 변동폭도 컸나?
-- 기법: 공시(filings) x 주가(prices_daily) x 회사(companies) 4번째 JOIN 축, 공시 유형을 CASE로 분류해 조건부 집계,
--       회사 x 연도 뼈대(CROSS JOIN)에 LEFT JOIN 해서 공시 0건인 해도 행을 유지
-- 주의: 정정공시([기재정정] 등)는 같은 사건의 재제출이라 건수에서 빼고 따로 센다
--       변동폭 = (연중 최고 종가 - 최저 종가) / 최저 종가, 종가 기준이라 장중 고저가와 다르다
--       (q5 의 high_low_range_pct 는 최저/최고 - 1 로 음수 표기, 같은 고저가를 다른 기준으로 본 값)
--       공시 건수와 변동폭은 인과가 아니라 동시 관찰(추론 금지), 13개사 x 3년 표본

WITH years AS (
    SELECT DISTINCT CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr
    FROM prices_daily
),
grid AS (                                   -- 회사 x 연도 뼈대
    SELECT c.corp_code, c.stock_code, c.sector, c.corp_name, y.yr
    FROM companies c
    CROSS JOIN years y
),
filing_cnt AS (
    SELECT
        corp_code,
        CAST(SUBSTR(rcept_dt, 1, 4) AS INTEGER)                                    AS yr,
        SUM(CASE WHEN is_amendment = 0 THEN 1 ELSE 0 END)                          AS n_filings,
        SUM(CASE WHEN is_amendment = 1 THEN 1 ELSE 0 END)                          AS n_amend,
        SUM(CASE WHEN is_amendment = 0 AND report_nm LIKE '%자기주식%' THEN 1 ELSE 0 END) AS n_treasury,
        SUM(CASE WHEN is_amendment = 0
                  AND (report_nm LIKE '%사채권발행%' OR report_nm LIKE '%유상증자%')
                 THEN 1 ELSE 0 END)                                                 AS n_financing,
        SUM(CASE WHEN is_amendment = 0
                  AND (report_nm LIKE '%합병%' OR report_nm LIKE '%분할%'
                       OR report_nm LIKE '%감자%' OR report_nm LIKE '%양수%' OR report_nm LIKE '%양도%')
                 THEN 1 ELSE 0 END)                                                 AS n_restructure
    FROM filings
    GROUP BY corp_code, CAST(SUBSTR(rcept_dt, 1, 4) AS INTEGER)
),
price_range AS (
    SELECT
        stock_code,
        CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS yr,
        MIN(close) AS low_close,
        MAX(close) AS high_close
    FROM prices_daily
    GROUP BY stock_code, CAST(SUBSTR(trade_date, 1, 4) AS INTEGER)
),
joined AS (
    SELECT
        g.sector, g.corp_name, g.yr,
        COALESCE(fc.n_filings, 0)     AS n_filings,
        COALESCE(fc.n_amend, 0)       AS n_amend,
        COALESCE(fc.n_treasury, 0)    AS n_treasury,
        COALESCE(fc.n_financing, 0)   AS n_financing,
        COALESCE(fc.n_restructure, 0) AS n_restructure,
        ROUND(100.0 * (pr.high_close - pr.low_close) / NULLIF(pr.low_close, 0), 1) AS range_pct
    FROM grid g
    LEFT JOIN filing_cnt  fc ON fc.corp_code  = g.corp_code  AND fc.yr = g.yr
    LEFT JOIN price_range pr ON pr.stock_code = g.stock_code AND pr.yr = g.yr
)
SELECT
    sector, corp_name, yr AS fiscal_year,
    n_filings, n_amend, n_treasury, n_financing, n_restructure,
    range_pct,
    -- 같은 해 13개사 중 변동폭 순위 (1 = 가장 큼), 주가 없는 종목은 NULL
    CASE WHEN range_pct IS NOT NULL
         THEN RANK() OVER (PARTITION BY yr, range_pct IS NULL ORDER BY range_pct DESC) END AS range_rank_in_year
FROM joined
ORDER BY fiscal_year, n_filings DESC, range_pct DESC;
