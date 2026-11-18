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

-- ---------- financials_quarter ----------
-- (1) 보고서코드 -> 분기 번호, 문자열 금액 -> 정수. 손익 계정은 UNPIVOT:
--     당기 열(thstrm) = 그 해 분기 3개월, 전기 열(frmtrm) = 전년 같은 분기 3개월을 최신 기준으로 재표시한 값
--     재무상태표의 전기 열은 "전년 말 잔액"이라 분기 행으로 쓰지 않는다
-- (2) 같은 회사·분기·계정이 여러 보고서에 있으면 최신 접수번호 1건 (ROW_NUMBER)
--     -> 이듬해 분기보고서가 있으면 그 전기 열이 당해 보고서의 당기 열을 이긴다 (중단영업 재분류 등 반영)
-- (3) 계정 PIVOT, 백만원
-- (4) 4분기 도출: financials_annual(최신 보고 기준 연간) - 1~3분기 합. 1~3분기 중 하나라도 없으면 NULL
--     분기(최신 보고서 우선)와 연간(최신 보고서 우선)이 같은 기준이 되도록 맞춘 것.
--     연중에 재분류가 생기면(카카오게임즈 2023: 3분기 보고서부터 중단영업 분리) 그 해는 기준이 섞여 4분기가 왜곡된다 -> q8 점검 3
-- (5) 연초누적 = 3개월값의 누적합 (SUM OVER ... ROWS UNBOUNDED PRECEDING)
WITH
q_raw AS (
    SELECT corp_code, rcept_no, fs_div, account_nm,
           CAST(bsns_year AS INTEGER) AS fiscal_year,
           CASE reprt_code WHEN '11013' THEN 1 WHEN '11012' THEN 2 WHEN '11014' THEN 3 END AS quarter,
           CASE WHEN TRIM(thstrm_amount) IN ('', '-') THEN NULL
                ELSE CAST(REPLACE(TRIM(thstrm_amount), ',', '') AS INTEGER) END AS amount_krw
    FROM stg_dart_key_accounts_q
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, account_nm,
           CAST(bsns_year AS INTEGER) - 1 AS fiscal_year,
           CASE reprt_code WHEN '11013' THEN 1 WHEN '11012' THEN 2 WHEN '11014' THEN 3 END AS quarter,
           CASE WHEN TRIM(frmtrm_amount) IN ('', '-') THEN NULL
                ELSE CAST(REPLACE(TRIM(frmtrm_amount), ',', '') AS INTEGER) END AS amount_krw
    FROM stg_dart_key_accounts_q
    WHERE sj_div <> 'BS'                              -- 손익 계정만 전기 열을 쓴다
      AND TRIM(COALESCE(frmtrm_amount, '')) NOT IN ('', '-')
),
q_dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY corp_code, fs_div, fiscal_year, quarter, account_nm
                              ORDER BY rcept_no DESC) AS rn
    FROM q_raw
    WHERE quarter IS NOT NULL
      -- 전기 열만으로 생기는 연도(수집 첫해의 전년)는 제외: 자기 분기보고서가 있는 연도만 적재
      AND fiscal_year IN (SELECT DISTINCT CAST(bsns_year AS INTEGER) FROM stg_dart_key_accounts_q)
),
q_pivot AS (
    SELECT corp_code, fiscal_year, quarter, fs_div,
           MAX(CASE WHEN account_nm = '유동자산'       THEN amount_krw END) / 1000000 AS current_assets,
           MAX(CASE WHEN account_nm = '자산총계'       THEN amount_krw END) / 1000000 AS total_assets,
           MAX(CASE WHEN account_nm = '유동부채'       THEN amount_krw END) / 1000000 AS current_liab,
           MAX(CASE WHEN account_nm = '부채총계'       THEN amount_krw END) / 1000000 AS total_liab,
           MAX(CASE WHEN account_nm = '자본총계'       THEN amount_krw END) / 1000000 AS total_equity,
           MAX(CASE WHEN account_nm = '매출액'         THEN amount_krw END) / 1000000 AS revenue,
           MAX(CASE WHEN account_nm = '영업이익'       THEN amount_krw END) / 1000000 AS op_income,
           MAX(CASE WHEN account_nm LIKE '당기순이익%' THEN amount_krw END) / 1000000 AS net_income,
           MAX(rcept_no) AS source_rcept_no
    FROM q_dedup
    WHERE rn = 1
    GROUP BY corp_code, fiscal_year, quarter, fs_div
),
q4 AS (
    SELECT a.corp_code, a.fiscal_year, 4 AS quarter, a.fs_div,
           a.current_assets, a.total_assets, a.current_liab, a.total_liab, a.total_equity,
           CASE WHEN COUNT(p.revenue)    = 3 THEN a.revenue    - SUM(p.revenue)    END AS revenue,
           CASE WHEN COUNT(p.op_income)  = 3 THEN a.op_income  - SUM(p.op_income)  END AS op_income,
           CASE WHEN COUNT(p.net_income) = 3 THEN a.net_income - SUM(p.net_income) END AS net_income,
           a.source_rcept_no
    FROM financials_annual a
    JOIN q_pivot p ON p.corp_code = a.corp_code AND p.fiscal_year = a.fiscal_year AND p.fs_div = a.fs_div
    GROUP BY a.corp_code, a.fiscal_year, a.fs_div
),
all_q AS (
    SELECT corp_code, fiscal_year, quarter, fs_div, current_assets, total_assets, current_liab,
           total_liab, total_equity, revenue, op_income, net_income, 0 AS is_derived, source_rcept_no
    FROM q_pivot
    UNION ALL
    SELECT corp_code, fiscal_year, quarter, fs_div, current_assets, total_assets, current_liab,
           total_liab, total_equity, revenue, op_income, net_income, 1 AS is_derived, source_rcept_no
    FROM q4
)
INSERT INTO financials_quarter
    (corp_code, fiscal_year, quarter, fs_div, current_assets, total_assets, current_liab, total_liab,
     total_equity, revenue, op_income, net_income, revenue_cum, op_income_cum, net_income_cum,
     is_derived, source_rcept_no)
SELECT corp_code, fiscal_year, quarter, fs_div, current_assets, total_assets, current_liab, total_liab,
       total_equity, revenue, op_income, net_income,
       SUM(revenue)    OVER w AS revenue_cum,
       SUM(op_income)  OVER w AS op_income_cum,
       SUM(net_income) OVER w AS net_income_cum,
       is_derived, source_rcept_no
FROM all_q
WINDOW w AS (PARTITION BY corp_code, fiscal_year, fs_div ORDER BY quarter
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW);

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
