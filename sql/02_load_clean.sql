-- 02_load_clean.sql
-- staging -> 분석용 테이블. 정제 포인트:
--   (1) DART 금액 문자열 "1,234,567" / "-1,234" / "-"  ->  INTEGER (NULL 처리 포함)
--   (2) 당기/전기/전전기 3개 컬럼(wide) -> 회계연도별 행(long) 으로 UNPIVOT
--   (3) 계정명(행) -> 컬럼(wide) 으로 PIVOT, 회사 x 연도 1행
--   (4) 동일 접수번호에 중복 계정 행이 오는 경우(당기순이익 2회 등) ROW_NUMBER로 1건만
--   (5) 금액 단위 원 -> 백만원

-- ---------- companies ----------
INSERT INTO companies (corp_code, stock_code, corp_name, corp_name_en, market, sector, delisted_date)
SELECT
    corp_code,
    stock_code,
    corp_name,
    corp_name_en,
    market,
    sector,
    NULLIF(TRIM(delisted_date), '')
FROM stg_companies;

-- ---------- financials_annual ----------
WITH
-- (2) UNPIVOT: 당기/전기/전전기 -> fiscal_year 행
long AS (
    SELECT corp_code, rcept_no, fs_div, account_nm,
           CAST(bsns_year AS INTEGER)      AS fiscal_year, thstrm_amount    AS amount_raw
    FROM stg_dart_key_accounts
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, account_nm,
           CAST(bsns_year AS INTEGER) - 1  AS fiscal_year, frmtrm_amount    AS amount_raw
    FROM stg_dart_key_accounts
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, account_nm,
           CAST(bsns_year AS INTEGER) - 2  AS fiscal_year, bfefrmtrm_amount AS amount_raw
    FROM stg_dart_key_accounts
),
-- (1) 문자열 금액 -> 정수(원). "-" 또는 공백은 NULL
cleaned AS (
    SELECT corp_code, rcept_no, fs_div, account_nm, fiscal_year,
           CASE
               WHEN TRIM(amount_raw) IN ('', '-') THEN NULL
               ELSE CAST(REPLACE(TRIM(amount_raw), ',', '') AS INTEGER)
           END AS amount_krw
    FROM long
),
-- (4) 중복 제거: 같은 회사·연도·계정이면 접수번호가 가장 최근(=정정 반영)인 1건
dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY corp_code, fs_div, fiscal_year, account_nm
               ORDER BY rcept_no DESC
           ) AS rn
    FROM cleaned
),
-- (3) PIVOT + (5) 단위 통일
pivoted AS (
    SELECT
        corp_code,
        fiscal_year,
        fs_div,
        MAX(CASE WHEN account_nm = '유동자산'        THEN amount_krw END) / 1000000 AS current_assets,
        MAX(CASE WHEN account_nm = '자산총계'        THEN amount_krw END) / 1000000 AS total_assets,
        MAX(CASE WHEN account_nm = '유동부채'        THEN amount_krw END) / 1000000 AS current_liab,
        MAX(CASE WHEN account_nm = '부채총계'        THEN amount_krw END) / 1000000 AS total_liab,
        MAX(CASE WHEN account_nm = '자본총계'        THEN amount_krw END) / 1000000 AS total_equity,
        MAX(CASE WHEN account_nm = '매출액'          THEN amount_krw END) / 1000000 AS revenue,
        MAX(CASE WHEN account_nm = '영업이익'        THEN amount_krw END) / 1000000 AS op_income,
        MAX(CASE WHEN account_nm LIKE '당기순이익%'  THEN amount_krw END) / 1000000 AS net_income,
        MAX(rcept_no) AS source_rcept_no
    FROM dedup
    WHERE rn = 1
    GROUP BY corp_code, fiscal_year, fs_div
)
INSERT INTO financials_annual
    (corp_code, fiscal_year, fs_div, current_assets, total_assets, current_liab,
     total_liab, total_equity, revenue, op_income, net_income, source_rcept_no)
SELECT corp_code, fiscal_year, fs_div, current_assets, total_assets, current_liab,
       total_liab, total_equity, revenue, op_income, net_income, source_rcept_no
FROM pivoted;

-- ---------- prices_daily ----------
-- yfinance는 가끔 같은 날짜가 두 번 오거나 close가 NULL인 행을 준다 -> 둘 다 걸러낸다
INSERT INTO prices_daily (stock_code, trade_date, close, adj_close, volume)
SELECT stock_code, trade_date, close, adj_close, CAST(volume AS INTEGER)
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY stock_code, trade_date ORDER BY volume DESC) AS rn
    FROM stg_prices_daily
    WHERE close IS NOT NULL AND close > 0
)
WHERE rn = 1;

-- ---------- shares_outstanding ----------
INSERT INTO shares_outstanding (stock_code, shares, as_of_date, source)
SELECT stock_code, shares, as_of_date, 'KRX'
FROM stg_shares_outstanding
WHERE shares IS NOT NULL AND shares > 0;

-- KRX 목록에 없는 종목만 수기 값으로 보충 (KRX 값이 있으면 KRX 우선)
INSERT INTO shares_outstanding (stock_code, shares, as_of_date, source)
SELECT m.stock_code, m.shares, m.as_of_date, m.source
FROM stg_shares_manual m
WHERE m.shares IS NOT NULL AND m.shares > 0
  AND NOT EXISTS (SELECT 1 FROM shares_outstanding s WHERE s.stock_code = m.stock_code);

-- ---------- filings ----------
-- 날짜 'YYYYMMDD' -> 'YYYY-MM-DD' (prices_daily.trade_date 와 같은 형식), 분석 대상 회사만
INSERT INTO filings (rcept_no, corp_code, report_nm, rcept_dt, pblntf_ty, is_amendment)
SELECT DISTINCT
    f.rcept_no,
    f.corp_code,
    TRIM(f.report_nm),
    SUBSTR(f.rcept_dt, 1, 4) || '-' || SUBSTR(f.rcept_dt, 5, 2) || '-' || SUBSTR(f.rcept_dt, 7, 2),
    f.pblntf_ty,
    CASE WHEN TRIM(f.report_nm) LIKE '[%' THEN 1 ELSE 0 END
FROM stg_filings f
JOIN companies c ON c.corp_code = f.corp_code;
