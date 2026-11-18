-- 04_load_layered.sql
-- staging(stg_fs_line, stg_fs_full) -> core(fs_fact) -> mart(fin_annual_wide) + 품질점검 뷰
-- dim_* 과 incr_scope 는 build_db.py 가 먼저 채운다. incr_scope 에 있는 회사만 다시 계산한다
-- (전체 빌드 = 200사 전부, --incremental = 새 raw 파일에 등장한 회사만. build_db.py 가 그 회사의 기존 core/mart 행을 지운 뒤 이 파일을 실행)
--
-- core 규칙
--   (1) UNPIVOT: 당기/전기/전전기 열 -> fiscal_year 행 (period_offset 0/1/2 로 출처 열 기록)
--   (2) 형변환: "1,234" / "-1,234" / "-" -> 정수 / NULL
--   (3) 한 회사·연도 = 한 보고서: 그 연도를 담은 보고서 중 rcept_no 최신 1건을 고르고 모든 계정을 거기서만 가져온다.
--       계정별로 따로 고르면 자산·부채는 올해 보고서, 자본은 작년 보고서가 섞여 항등식이 깨진다 (2단계 1차 빌드에서 2사 발견)
--   (4) 소스 우선순위: 같은 보고서를 주요계정 API(key_accounts)와 전체 재무제표 API(full_fs) 둘 다 줬으면 key_accounts 행 우선.
--       전체 재무제표는 주요계정 API 가 그 회사를 안 줄 때의 대체 경로 (은행 단독 법인 등은 OFS 만 있음)
--   (5) 표준 계정 매핑: account_id 가 있으면 account_id 로, 없으면 (sj_div, 계정명) 으로. CIS 는 IS 로 취급. 안 맞으면 std_account NULL
--   (6) 유니버스 밖 회사(dim_company 에 없음)는 적재하지 않음
-- 이식성: SQLite / DuckDB 공통. 정수 나눗셈 대신 TRUNC(x / 1000000.0), 불리언 합산 대신 CASE, 문자열 연결은 CAST

-- ---------- core: fs_fact ----------
WITH src AS (
    SELECT rcept_no, bsns_year, corp_code, fs_div, sj_div, NULL AS account_id, account_nm,
           thstrm_amount, frmtrm_amount, bfefrmtrm_amount, 'key_accounts' AS source, 0 AS source_rank
    FROM stg_fs_line
    UNION ALL
    SELECT rcept_no, bsns_year, corp_code, fs_div, sj_div, account_id, account_nm,
           thstrm_amount, frmtrm_amount, bfefrmtrm_amount, 'full_fs' AS source, 1 AS source_rank
    FROM stg_fs_full
),
long AS (
    SELECT corp_code, rcept_no, fs_div, sj_div, account_id, account_nm, source, source_rank,
           CAST(bsns_year AS INTEGER)     AS fiscal_year, 0 AS period_offset, thstrm_amount    AS amount_raw FROM src
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, sj_div, account_id, account_nm, source, source_rank,
           CAST(bsns_year AS INTEGER) - 1 AS fiscal_year, 1 AS period_offset, frmtrm_amount    AS amount_raw FROM src
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, sj_div, account_id, account_nm, source, source_rank,
           CAST(bsns_year AS INTEGER) - 2 AS fiscal_year, 2 AS period_offset, bfefrmtrm_amount AS amount_raw FROM src
),
cleaned AS (
    SELECT l.*,
           CASE WHEN TRIM(COALESCE(l.amount_raw, '')) IN ('', '-') THEN NULL
                ELSE CAST(REPLACE(TRIM(l.amount_raw), ',', '') AS BIGINT) END AS amount_krw
    FROM long l
    JOIN dim_company d ON d.corp_code = l.corp_code
    JOIN incr_scope  s ON s.corp_code = l.corp_code
    WHERE TRIM(COALESCE(l.amount_raw, '')) <> ''          -- 전전기 열이 비어 있는 보고서의 빈 행 제거
),
chosen AS (
    -- 회사·연도·기준마다 그 연도를 담은 보고서 중 최신 1건
    SELECT corp_code, fs_div, fiscal_year, MAX(rcept_no) AS rcept_no
    FROM cleaned
    GROUP BY corp_code, fs_div, fiscal_year
),
dedup AS (
    SELECT c.*,
           ROW_NUMBER() OVER (
               PARTITION BY c.corp_code, c.fs_div, c.sj_div, c.account_nm, c.fiscal_year
               -- 같은 보고서에 같은 계정명이 둘 이상(기타자산 유동/비유동, 당기순이익 2회)이면 금액·코드로 결정적 순서
               ORDER BY c.source_rank ASC, c.period_offset ASC, COALESCE(c.amount_krw, 0) DESC, COALESCE(c.account_id, '')
           ) AS rn
    FROM cleaned c
    JOIN chosen ch ON ch.corp_code = c.corp_code AND ch.fs_div = c.fs_div
                  AND ch.fiscal_year = c.fiscal_year AND ch.rcept_no = c.rcept_no
),
mapped AS (
    -- account_id 매핑이 있으면 그것을, 없으면 계정명 매핑. 둘 다 맞으면 account_id 쪽 (map_rank 0)
    SELECT d.*,
           m.std_account, m.value_type, m.sign,
           ROW_NUMBER() OVER (
               PARTITION BY d.corp_code, d.fs_div, d.sj_div, d.account_nm, d.fiscal_year
               ORDER BY CASE WHEN m.account_id IS NOT NULL THEN 0 ELSE 1 END, m.priority
           ) AS map_rank
    FROM dedup d
    LEFT JOIN dim_account_map m
           ON (m.account_id IS NOT NULL AND m.account_id = d.account_id
               AND d.sj_div IN ('BS', 'IS', 'CIS'))
           OR (m.account_id IS NULL AND m.account_nm = d.account_nm
               AND (m.sj_div IS NULL OR m.sj_div = d.sj_div
                    OR (m.sj_div = 'IS' AND d.sj_div = 'CIS')))
    WHERE d.rn = 1
)
INSERT INTO fs_fact (corp_code, fiscal_year, fs_div, sj_div, account_nm, account_id, std_account, value_type,
                     amount_krw, period_offset, source, rcept_no)
SELECT corp_code, fiscal_year, fs_div, sj_div, account_nm, account_id, std_account, value_type,
       amount_krw * COALESCE(sign, 1), period_offset, source, rcept_no
FROM mapped
WHERE map_rank = 1;

-- ---------- mart: fin_annual_wide ----------
-- 같은 표준 계정에 여러 원문 계정이 매핑되면(매출액·영업수익) dim_account_map.priority 가 낮은 것을 쓴다
WITH ranked AS (
    SELECT f.corp_code, f.fiscal_year, f.fs_div, f.std_account, f.amount_krw,
           ROW_NUMBER() OVER (
               PARTITION BY f.corp_code, f.fiscal_year, f.fs_div, f.std_account
               ORDER BY m.priority, f.sj_div, f.account_nm
           ) AS rn
    FROM fs_fact f
    JOIN incr_scope s ON s.corp_code = f.corp_code
    JOIN dim_account_map m
      ON (m.account_id IS NOT NULL AND m.account_id = f.account_id)
      OR (m.account_id IS NULL AND m.account_nm = f.account_nm
          AND (m.sj_div IS NULL OR m.sj_div = f.sj_div OR (m.sj_div = 'IS' AND f.sj_div = 'CIS')))
    WHERE f.std_account IS NOT NULL AND m.std_account = f.std_account
),
pivoted AS (
    SELECT corp_code, fiscal_year, fs_div,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'revenue'        THEN amount_krw END) / 1000000.0) AS BIGINT) AS revenue,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'op_income'      THEN amount_krw END) / 1000000.0) AS BIGINT) AS op_income,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'pretax_income'  THEN amount_krw END) / 1000000.0) AS BIGINT) AS pretax_income,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'net_income'     THEN amount_krw END) / 1000000.0) AS BIGINT) AS net_income,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'current_assets' THEN amount_krw END) / 1000000.0) AS BIGINT) AS current_assets,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'total_assets'   THEN amount_krw END) / 1000000.0) AS BIGINT) AS total_assets,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'current_liab'   THEN amount_krw END) / 1000000.0) AS BIGINT) AS current_liab,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'total_liab'     THEN amount_krw END) / 1000000.0) AS BIGINT) AS total_liab,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'total_equity'   THEN amount_krw END) / 1000000.0) AS BIGINT) AS total_equity,
           CAST(TRUNC(MAX(CASE WHEN std_account = 'issued_capital' THEN amount_krw END) / 1000000.0) AS BIGINT) AS issued_capital
    FROM ranked
    WHERE rn = 1
    GROUP BY corp_code, fiscal_year, fs_div
),
counts AS (
    SELECT f.corp_code, f.fiscal_year, f.fs_div,
           SUM(CASE WHEN f.std_account IS NOT NULL THEN 1 ELSE 0 END) AS n_mapped,
           SUM(CASE WHEN f.std_account IS NULL     THEN 1 ELSE 0 END) AS n_unmapped,
           CASE WHEN MIN(f.source) = MAX(f.source) THEN MIN(f.source) ELSE 'mixed' END AS source
    FROM fs_fact f
    JOIN incr_scope s ON s.corp_code = f.corp_code
    GROUP BY f.corp_code, f.fiscal_year, f.fs_div
)
INSERT INTO fin_annual_wide
    (corp_code, fiscal_year, fs_div, revenue, op_income, pretax_income, net_income,
     current_assets, total_assets, current_liab, total_liab, total_equity, issued_capital,
     n_mapped, n_unmapped, qc_identity_ok, source)
SELECT p.corp_code, p.fiscal_year, p.fs_div, p.revenue, p.op_income, p.pretax_income, p.net_income,
       p.current_assets, p.total_assets, p.current_liab, p.total_liab, p.total_equity, p.issued_capital,
       c.n_mapped, c.n_unmapped,
       CASE WHEN p.total_assets IS NULL OR p.total_liab IS NULL OR p.total_equity IS NULL THEN NULL
            WHEN ABS(p.total_assets - (p.total_liab + p.total_equity)) <= 2 THEN 1 ELSE 0 END,
       c.source
FROM pivoted p
JOIN counts c ON c.corp_code = p.corp_code AND c.fiscal_year = p.fiscal_year AND c.fs_div = p.fs_div;

-- ---------- core: filings_universe (공시 유형 분류) ----------
-- 유형 규칙: 제목의 키워드. 자기주식(취득·처분·신탁) / 자금조달(사채·증자·채무증권·조건부자본증권) / 구조변경(합병·분할·영업양수도·감자·타법인주식취득·주식교환) / 기타
INSERT INTO filings_universe (rcept_no, corp_code, report_nm, rcept_dt, fiscal_year, pblntf_ty, is_amendment, event_type)
SELECT DISTINCT
    f.rcept_no,
    f.corp_code,
    TRIM(f.report_nm),
    SUBSTR(f.rcept_dt, 1, 4) || '-' || SUBSTR(f.rcept_dt, 5, 2) || '-' || SUBSTR(f.rcept_dt, 7, 2),
    CAST(SUBSTR(f.rcept_dt, 1, 4) AS INTEGER),
    f.pblntf_ty,
    CASE WHEN TRIM(f.report_nm) LIKE '[%' THEN 1 ELSE 0 END,
    CASE
        WHEN f.report_nm LIKE '%자기주식%'                                                         THEN 'treasury'
        WHEN f.report_nm LIKE '%사채%' OR f.report_nm LIKE '%증자%' OR f.report_nm LIKE '%채무증권%'
          OR f.report_nm LIKE '%자본증권%'                                                          THEN 'financing'
        WHEN f.report_nm LIKE '%합병%' OR f.report_nm LIKE '%분할%' OR f.report_nm LIKE '%양수%'
          OR f.report_nm LIKE '%양도%' OR f.report_nm LIKE '%감자%' OR f.report_nm LIKE '%타법인%'
          OR f.report_nm LIKE '%주식교환%'                                                          THEN 'restructure'
        ELSE 'other'
    END
FROM stg_filings_u f
JOIN dim_company d ON d.corp_code = f.corp_code
JOIN incr_scope  s ON s.corp_code = f.corp_code;

-- ---------- core: filing_details (공시 본문 파싱값) ----------
INSERT INTO filing_details (rcept_no, corp_code, doc_type, amount_krw, purpose_facility, purpose_operating, purpose_debt,
                            purpose_acquisition, purpose_other, coupon_pct, ytm_pct, maturity_date, issue_method, conv_price,
                            shares_new, shares_before, price_per_share, discount_pct, shares_reduced, reduction_ratio_pct,
                            reduction_method, merger_ratio, counterparty, counterparty_assets_krw, counterparty_revenue_krw,
                            truncated, parse_note)
SELECT s.rcept_no, f.corp_code, s.doc_type,
       CAST(NULLIF(s.amount_krw, '') AS BIGINT), CAST(NULLIF(s.purpose_facility, '') AS BIGINT),
       CAST(NULLIF(s.purpose_operating, '') AS BIGINT), CAST(NULLIF(s.purpose_debt, '') AS BIGINT),
       CAST(NULLIF(s.purpose_acquisition, '') AS BIGINT), CAST(NULLIF(s.purpose_other, '') AS BIGINT),
       CAST(NULLIF(s.coupon_pct, '') AS DOUBLE), CAST(NULLIF(s.ytm_pct, '') AS DOUBLE),
       NULLIF(s.maturity_date, ''), NULLIF(s.issue_method, ''), CAST(NULLIF(s.conv_price, '') AS BIGINT),
       CAST(NULLIF(s.shares_new, '') AS BIGINT), CAST(NULLIF(s.shares_before, '') AS BIGINT),
       CAST(NULLIF(s.price_per_share, '') AS BIGINT), CAST(NULLIF(s.discount_pct, '') AS DOUBLE),
       CAST(NULLIF(s.shares_reduced, '') AS BIGINT), CAST(NULLIF(s.reduction_ratio_pct, '') AS DOUBLE),
       NULLIF(s.reduction_method, ''), CAST(NULLIF(s.merger_ratio, '') AS DOUBLE), NULLIF(s.counterparty, ''),
       CAST(NULLIF(s.counterparty_assets_krw, '') AS BIGINT), CAST(NULLIF(s.counterparty_revenue_krw, '') AS BIGINT),
       CAST(NULLIF(s.truncated, '') AS INTEGER), NULLIF(s.parse_note, '')
FROM stg_filing_details s
JOIN filings_universe f ON f.rcept_no = s.rcept_no
JOIN incr_scope      i ON i.corp_code = f.corp_code;

-- ---------- core: prices_universe ----------
-- 같은 날짜가 두 번 오면 거래량 큰 행, 종가 없거나 0 이면 제외. 유니버스 종목만
INSERT INTO prices_universe (stock_code, trade_date, trade_seq, close, adj_close, volume)
SELECT stock_code, trade_date,
       ROW_NUMBER() OVER (PARTITION BY stock_code ORDER BY trade_date) AS trade_seq,
       close, adj_close, volume
FROM (
    SELECT p.stock_code, p.trade_date,
           CAST(p.close AS DOUBLE)     AS close,
           CAST(p.adj_close AS DOUBLE) AS adj_close,
           CAST(p.volume AS BIGINT)    AS volume,
           ROW_NUMBER() OVER (PARTITION BY p.stock_code, p.trade_date ORDER BY CAST(p.volume AS BIGINT) DESC) AS rn
    FROM stg_prices_u p
    JOIN dim_company d ON d.stock_code = p.stock_code
    JOIN incr_scope  s ON s.corp_code = d.corp_code
    WHERE TRIM(COALESCE(p.close, '')) <> '' AND CAST(p.close AS DOUBLE) > 0
) x
WHERE rn = 1;

-- 유니버스 등가중 지수: 종목별 일간 수정종가 수익률의 날짜 평균을 누적 (시작 1.0)
-- 이벤트 윈도우의 "시장 대비" 기준. SQLite 3.35+ / DuckDB 공통 (LN·EXP)
DROP VIEW IF EXISTS v_universe_index;
CREATE VIEW v_universe_index AS
WITH r AS (
    SELECT stock_code, trade_date,
           adj_close / LAG(adj_close) OVER (PARTITION BY stock_code ORDER BY trade_date) - 1 AS ret
    FROM prices_universe
    WHERE adj_close > 0
),
d AS (
    SELECT trade_date, AVG(ret) AS mret, COUNT(*) AS n_stocks
    FROM r
    WHERE ret IS NOT NULL
    GROUP BY trade_date
)
SELECT trade_date, n_stocks,
       EXP(SUM(LN(1 + mret)) OVER (ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS idx
FROM d;

-- ---------- 분석용 뷰: 회사·연도당 1행, 연결(CFS)이 있으면 연결, 없으면 별도(OFS) ----------
DROP VIEW IF EXISTS v_fin_annual;
CREATE VIEW v_fin_annual AS
SELECT w.*
FROM fin_annual_wide w
WHERE w.fs_div = 'CFS'
   OR NOT EXISTS (SELECT 1 FROM fin_annual_wide c
                  WHERE c.corp_code = w.corp_code AND c.fiscal_year = w.fiscal_year AND c.fs_div = 'CFS');

-- ---------- 품질점검 뷰 (core -> mart 관문, 읽기 전용) ----------
DROP VIEW IF EXISTS v_qc_unmapped_accounts;
CREATE VIEW v_qc_unmapped_accounts AS
SELECT sj_div, account_nm, source,
       COUNT(DISTINCT corp_code) AS n_companies,
       COUNT(*)                  AS n_rows,
       CAST(MIN(fiscal_year) AS VARCHAR) || '~' || CAST(MAX(fiscal_year) AS VARCHAR) AS years
FROM fs_fact
WHERE std_account IS NULL
GROUP BY sj_div, account_nm, source;

DROP VIEW IF EXISTS v_qc_company_coverage;
CREATE VIEW v_qc_company_coverage AS
SELECT d.corp_code, d.corp_name, d.is_financial,
       COUNT(w.fiscal_year)                                                              AS n_years,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.revenue    IS NULL THEN 1 ELSE 0 END) AS years_no_revenue,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.op_income  IS NULL THEN 1 ELSE 0 END) AS years_no_op_income,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.net_income IS NULL THEN 1 ELSE 0 END) AS years_no_net_income,
       SUM(CASE WHEN w.qc_identity_ok = 0 THEN 1 ELSE 0 END)                              AS years_identity_fail,
       SUM(CASE WHEN w.fs_div = 'OFS' THEN 1 ELSE 0 END)                                  AS years_ofs_only,
       COALESCE(SUM(w.n_unmapped), 0)                                                    AS unmapped_rows,
       ROUND(100.0 * SUM(w.n_unmapped) / NULLIF(SUM(w.n_mapped + w.n_unmapped), 0), 1)  AS unmapped_pct
FROM dim_company d
LEFT JOIN v_fin_annual w ON w.corp_code = d.corp_code
                        AND w.fiscal_year BETWEEN 2021 AND 2025     -- 수집 창. 전기·전전기 열로 생긴 2019~2020 은 제외
GROUP BY d.corp_code, d.corp_name, d.is_financial;
