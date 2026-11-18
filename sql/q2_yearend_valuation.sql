-- Q2. 연말 기준 시가총액·PER·PBR - 재무제표(DART)와 주가(거래소)를 결합
-- 기법: ROW_NUMBER로 "연도별 마지막 거래일" 추출, 3개 테이블 JOIN, LEFT JOIN으로 결측 유지
-- 주의: shares_outstanding은 수집 시점(현재) 기준 주식수 -> 과거 연도 시가총액은 근사치(추론)
--       더존비즈온(012510)은 2026-07 상장폐지로 주가 이력이 없어 NULL로 남는다 (LEFT JOIN 효과)

WITH last_trade AS (
    SELECT
        stock_code,
        CAST(SUBSTR(trade_date, 1, 4) AS INTEGER) AS fiscal_year,
        trade_date,
        close,
        ROW_NUMBER() OVER (
            PARTITION BY stock_code, SUBSTR(trade_date, 1, 4)
            ORDER BY trade_date DESC
        ) AS rn
    FROM prices_daily
),
yearend AS (
    SELECT stock_code, fiscal_year, trade_date AS yearend_date, close AS yearend_close
    FROM last_trade
    WHERE rn = 1
),
valuation AS (
    SELECT
        c.sector,
        c.corp_name,
        f.fiscal_year,
        y.yearend_date,
        y.yearend_close,
        -- 시가총액(십억원) = 종가 x 주식수 / 1e9
        ROUND(y.yearend_close * s.shares / 1e9, 0)                                   AS mktcap_bn,
        -- 순이익·자본은 백만원 단위이므로 1e6을 곱해 원 단위로 맞춘다
        ROUND(y.yearend_close * s.shares / NULLIF(f.net_income * 1e6, 0), 1)         AS per_x,
        ROUND(y.yearend_close * s.shares / NULLIF(f.total_equity * 1e6, 0), 2)       AS pbr_x,
        ROUND(100.0 * f.net_income / NULLIF(f.total_equity, 0), 1)                   AS roe_pct
    FROM financials_annual f
    JOIN companies c            ON c.corp_code  = f.corp_code
    LEFT JOIN yearend y         ON y.stock_code = c.stock_code AND y.fiscal_year = f.fiscal_year
    LEFT JOIN shares_outstanding s ON s.stock_code = c.stock_code
    WHERE f.fs_div = 'CFS'
)
SELECT
    sector, corp_name, fiscal_year, yearend_date, yearend_close,
    mktcap_bn,
    -- 적자 기업의 PER은 의미가 없으므로 표시하지 않는다
    CASE WHEN per_x > 0 THEN per_x END AS per_x,
    pbr_x,
    roe_pct
FROM valuation
WHERE fiscal_year = 2025
ORDER BY sector, mktcap_bn DESC;
