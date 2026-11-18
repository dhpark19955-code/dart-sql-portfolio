-- 04_load_layered.sql
-- staging(stg_fs_line) -> core(fs_fact) -> mart(fin_annual_wide)
-- dim_* 은 build_db.py 가 data/dim/*.csv 에서 먼저 적재한다.
--
-- core 규칙
--   (1) UNPIVOT: 당기/전기/전전기 열 -> fiscal_year 행 (period_offset 0/1/2 로 출처 열 기록)
--   (2) 형변환: "1,234" / "-1,234" / "-" -> 정수 / NULL
--   (3) 최신 보고서 우선 - 단, 회사·연도 단위로 한 보고서만 쓴다: 그 연도를 담은 보고서 중 rcept_no 최신 1건을 고르고
--       모든 계정을 그 보고서에서만 가져온다. 계정별로 따로 고르면 자산·부채는 올해 보고서, 자본은 작년 보고서가 섞여
--       항등식이 깨진다 (1차 빌드에서 금호석유화학 2021·한화 2021 이 그렇게 걸림). 같은 보고서 안의 중복 행은 당기 열 우선
--   (4) 표준 계정 매핑: dim_account_map (sj_div 가 NULL 인 행은 재무제표 구분 무관). 안 맞으면 std_account NULL 로 남김
--   (5) 유니버스 밖 회사(dim_company 에 없음)는 적재하지 않음

-- ---------- core: fs_fact ----------
WITH long AS (
    SELECT corp_code, rcept_no, fs_div, sj_div, account_nm,
           CAST(bsns_year AS INTEGER)     AS fiscal_year, 0 AS period_offset, thstrm_amount    AS amount_raw
    FROM stg_fs_line
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, sj_div, account_nm,
           CAST(bsns_year AS INTEGER) - 1 AS fiscal_year, 1 AS period_offset, frmtrm_amount    AS amount_raw
    FROM stg_fs_line
    UNION ALL
    SELECT corp_code, rcept_no, fs_div, sj_div, account_nm,
           CAST(bsns_year AS INTEGER) - 2 AS fiscal_year, 2 AS period_offset, bfefrmtrm_amount AS amount_raw
    FROM stg_fs_line
),
cleaned AS (
    SELECT l.*,
           CASE WHEN TRIM(COALESCE(amount_raw, '')) IN ('', '-') THEN NULL
                ELSE CAST(REPLACE(TRIM(amount_raw), ',', '') AS INTEGER) END AS amount_krw
    FROM long l
    JOIN dim_company d ON d.corp_code = l.corp_code
),
chosen AS (
    -- 회사·연도마다 그 연도를 담은 보고서 중 최신 1건
    SELECT corp_code, fs_div, fiscal_year, MAX(rcept_no) AS rcept_no
    FROM cleaned
    GROUP BY corp_code, fs_div, fiscal_year
),
dedup AS (
    SELECT c.*,
           ROW_NUMBER() OVER (
               PARTITION BY c.corp_code, c.fs_div, c.sj_div, c.account_nm, c.fiscal_year
               ORDER BY c.period_offset ASC
           ) AS rn
    FROM cleaned c
    JOIN chosen ch ON ch.corp_code = c.corp_code AND ch.fs_div = c.fs_div
                  AND ch.fiscal_year = c.fiscal_year AND ch.rcept_no = c.rcept_no
)
INSERT INTO fs_fact (corp_code, fiscal_year, fs_div, sj_div, account_nm, std_account, value_type,
                     amount_krw, period_offset, rcept_no)
SELECT c.corp_code, c.fiscal_year, c.fs_div, c.sj_div, c.account_nm,
       m.std_account,
       m.value_type,
       c.amount_krw * COALESCE(m.sign, 1),
       c.period_offset,
       c.rcept_no
FROM dedup c
LEFT JOIN dim_account_map m
       ON m.account_nm = c.account_nm
      AND (m.sj_div IS NULL OR m.sj_div = c.sj_div)
WHERE c.rn = 1;

-- ---------- mart: fin_annual_wide ----------
-- 같은 표준 계정에 여러 원문 계정이 매핑되면(매출액·영업수익) dim_account_map.priority 가 낮은 것을 쓴다
WITH ranked AS (
    SELECT f.corp_code, f.fiscal_year, f.fs_div, f.std_account, f.amount_krw,
           ROW_NUMBER() OVER (
               PARTITION BY f.corp_code, f.fiscal_year, f.fs_div, f.std_account
               ORDER BY m.priority, f.account_nm
           ) AS rn
    FROM fs_fact f
    JOIN dim_account_map m
      ON m.account_nm = f.account_nm AND (m.sj_div IS NULL OR m.sj_div = f.sj_div)
    WHERE f.std_account IS NOT NULL
),
pivoted AS (
    SELECT corp_code, fiscal_year, fs_div,
           MAX(CASE WHEN std_account = 'revenue'        THEN amount_krw END) / 1000000 AS revenue,
           MAX(CASE WHEN std_account = 'op_income'      THEN amount_krw END) / 1000000 AS op_income,
           MAX(CASE WHEN std_account = 'pretax_income'  THEN amount_krw END) / 1000000 AS pretax_income,
           MAX(CASE WHEN std_account = 'net_income'     THEN amount_krw END) / 1000000 AS net_income,
           MAX(CASE WHEN std_account = 'current_assets' THEN amount_krw END) / 1000000 AS current_assets,
           MAX(CASE WHEN std_account = 'total_assets'   THEN amount_krw END) / 1000000 AS total_assets,
           MAX(CASE WHEN std_account = 'current_liab'   THEN amount_krw END) / 1000000 AS current_liab,
           MAX(CASE WHEN std_account = 'total_liab'     THEN amount_krw END) / 1000000 AS total_liab,
           MAX(CASE WHEN std_account = 'total_equity'   THEN amount_krw END) / 1000000 AS total_equity,
           MAX(CASE WHEN std_account = 'issued_capital' THEN amount_krw END) / 1000000 AS issued_capital
    FROM ranked
    WHERE rn = 1
    GROUP BY corp_code, fiscal_year, fs_div
),
counts AS (
    SELECT corp_code, fiscal_year, fs_div,
           SUM(CASE WHEN std_account IS NOT NULL THEN 1 ELSE 0 END) AS n_mapped,
           SUM(CASE WHEN std_account IS NULL     THEN 1 ELSE 0 END) AS n_unmapped
    FROM fs_fact
    GROUP BY corp_code, fiscal_year, fs_div
)
INSERT INTO fin_annual_wide
    (corp_code, fiscal_year, fs_div, revenue, op_income, pretax_income, net_income,
     current_assets, total_assets, current_liab, total_liab, total_equity, issued_capital,
     n_mapped, n_unmapped, qc_identity_ok)
SELECT p.corp_code, p.fiscal_year, p.fs_div, p.revenue, p.op_income, p.pretax_income, p.net_income,
       p.current_assets, p.total_assets, p.current_liab, p.total_liab, p.total_equity, p.issued_capital,
       c.n_mapped, c.n_unmapped,
       CASE WHEN p.total_assets IS NULL OR p.total_liab IS NULL OR p.total_equity IS NULL THEN NULL
            WHEN ABS(p.total_assets - (p.total_liab + p.total_equity)) <= 2 THEN 1 ELSE 0 END
FROM pivoted p
JOIN counts c ON c.corp_code = p.corp_code AND c.fiscal_year = p.fiscal_year AND c.fs_div = p.fs_div;

-- ---------- 품질점검 뷰 (core -> mart 관문, 읽기 전용) ----------
DROP VIEW IF EXISTS v_qc_unmapped_accounts;
CREATE VIEW v_qc_unmapped_accounts AS
SELECT sj_div, account_nm,
       COUNT(DISTINCT corp_code) AS n_companies,
       COUNT(*)                  AS n_rows,
       MIN(fiscal_year) || '~' || MAX(fiscal_year) AS years
FROM fs_fact
WHERE std_account IS NULL
GROUP BY sj_div, account_nm;

DROP VIEW IF EXISTS v_qc_company_coverage;
CREATE VIEW v_qc_company_coverage AS
SELECT d.corp_code, d.corp_name, d.is_financial,
       COUNT(w.fiscal_year)                                   AS n_years,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.revenue    IS NULL THEN 1 ELSE 0 END)  AS years_no_revenue,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.op_income  IS NULL THEN 1 ELSE 0 END)  AS years_no_op_income,
       SUM(CASE WHEN w.fiscal_year IS NOT NULL AND w.net_income IS NULL THEN 1 ELSE 0 END)  AS years_no_net_income,
       SUM(CASE WHEN w.qc_identity_ok = 0 THEN 1 ELSE 0 END)  AS years_identity_fail,
       SUM(w.n_unmapped)                                      AS unmapped_rows,
       ROUND(100.0 * SUM(w.n_unmapped) / NULLIF(SUM(w.n_mapped + w.n_unmapped), 0), 1) AS unmapped_pct
FROM dim_company d
LEFT JOIN fin_annual_wide w ON w.corp_code = d.corp_code AND w.fs_div = 'CFS'
                           AND w.fiscal_year BETWEEN 2021 AND 2025     -- 수집 창. 전기·전전기 열로 생긴 2019~2020 은 제외
GROUP BY d.corp_code, d.corp_name, d.is_financial;
