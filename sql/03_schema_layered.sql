-- 03_schema_layered.sql
-- 대형화 2단계: raw -> staging -> core -> mart 4계층 + 보조테이블(dim_*) + 품질점검 뷰
-- 1단계까지의 테이블(companies, financials_annual, financials_quarter ...)은 그대로 두고,
-- 유니버스를 KOSPI 시가총액 상위 200사로 넓힌 연간 재무를 이 계층 구조로 적재한다.
-- 설계 근거: docs/LARGE_SCALE_PLAN.md, docs/LARGE_SCALE_DESIGN.xlsx

-- ---------- 보조테이블 (사람이 관리) ----------
DROP TABLE IF EXISTS dim_company;
CREATE TABLE dim_company (
    corp_code       TEXT PRIMARY KEY,            -- DART 고유번호 8자리
    stock_code      TEXT NOT NULL UNIQUE,        -- 종목코드 6자리
    corp_name       TEXT NOT NULL,
    market          TEXT,
    induty_code     TEXT,                        -- DART 기업개황 업종코드 (KSIC)
    sector_krx      TEXT,                        -- KSIC 대분류명 (dim_industry 로 매핑)
    industry_krx    TEXT,                        -- KSIC 중분류명
    settle_month    INTEGER,                     -- 결산월. 12 가 아니면 분기 매핑 주의
    marcap_krw      INTEGER,                     -- 유니버스 선정 시점 시가총액 (원)
    listing_date    TEXT,
    delisted_date   TEXT,
    is_financial    INTEGER NOT NULL DEFAULT 0,  -- 1 = 금융업 (매출액 대신 영업수익·순영업수익)
    universe        TEXT NOT NULL,               -- 'KOSPI_TOP200_20261118'
    as_of_date      TEXT NOT NULL
);

DROP TABLE IF EXISTS dim_account_map;
CREATE TABLE dim_account_map (
    map_id       INTEGER PRIMARY KEY,
    sj_div       TEXT,                           -- BS / IS / CF. NULL 이면 재무제표 구분 무관
    account_nm   TEXT NOT NULL,                  -- API 가 주는 계정명 변형
    std_account  TEXT NOT NULL,                  -- 표준 계정 (mart 컬럼명)
    sign         INTEGER NOT NULL DEFAULT 1,     -- 1 그대로, -1 뒤집기 (abs 금지)
    value_type   TEXT NOT NULL CHECK (value_type IN ('flow', 'balance')),
    priority     INTEGER NOT NULL DEFAULT 1,     -- 같은 표준 계정에 여러 변형이 있을 때 낮을수록 우선
    note         TEXT
);
CREATE INDEX idx_map_nm ON dim_account_map (account_nm);

-- KSIC 중분류(2자리) -> 대분류·중분류명. 업종코드 앞 2자리로 JOIN
DROP TABLE IF EXISTS dim_industry;
CREATE TABLE dim_industry (
    ksic2         TEXT PRIMARY KEY,
    sector_major  TEXT NOT NULL,
    sector_mid    TEXT NOT NULL,
    is_financial  INTEGER NOT NULL DEFAULT 0
);

DROP TABLE IF EXISTS dim_period;
CREATE TABLE dim_period (
    reprt_code              TEXT PRIMARY KEY,
    report_name             TEXT,
    quarter                 INTEGER,
    flow_thstrm_meaning     TEXT,
    flow_frmtrm_meaning     TEXT,
    balance_frmtrm_meaning  TEXT,
    filing_month            INTEGER
);

DROP TABLE IF EXISTS etl_log;
CREATE TABLE etl_log (
    log_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint    TEXT NOT NULL,
    params      TEXT,                            -- 호출 파라미터 (키 제외)
    status      TEXT,                            -- DART 상태코드 (000 정상, 013 없음, 020 한도)
    row_count   INTEGER,
    fetched_at  TEXT,
    raw_ref     TEXT,                            -- raw 파일 위치
    error_msg   TEXT
);

-- ---------- staging (원문 행, 값은 문자열) ----------
DROP TABLE IF EXISTS stg_fs_line;
CREATE TABLE stg_fs_line (
    rcept_no         TEXT,
    bsns_year        TEXT,
    reprt_code       TEXT,
    corp_code        TEXT,
    stock_code       TEXT,
    fs_div           TEXT,
    sj_div           TEXT,
    account_nm       TEXT,
    thstrm_amount    TEXT,
    frmtrm_amount    TEXT,
    bfefrmtrm_amount TEXT,
    currency         TEXT,
    source_file      TEXT                        -- raw CSV 파일명 (추적용)
);

-- ---------- core (회사 x 연도 x 계정 1행, 원 단위 정수, 표준 계정 매핑) ----------
DROP TABLE IF EXISTS fs_fact;
CREATE TABLE fs_fact (
    corp_code      TEXT NOT NULL REFERENCES dim_company(corp_code),
    fiscal_year    INTEGER NOT NULL,
    fs_div         TEXT NOT NULL,
    sj_div         TEXT NOT NULL,
    account_nm     TEXT NOT NULL,                -- 원문 계정명 (매핑 전)
    std_account    TEXT,                         -- NULL = 미매핑 (품질점검 대상)
    value_type     TEXT,
    amount_krw     INTEGER,                      -- 원 단위. '-' 는 NULL
    period_offset  INTEGER NOT NULL,             -- 0 당기 / 1 전기 / 2 전전기 열에서 왔는지
    rcept_no       TEXT NOT NULL,                -- 채택된 보고서 (최신 접수번호)
    PRIMARY KEY (corp_code, fiscal_year, fs_div, sj_div, account_nm)
);
CREATE INDEX idx_fact_std ON fs_fact (std_account, fiscal_year);

-- ---------- mart (회사 x 연도 1행 와이드, 백만원) ----------
DROP TABLE IF EXISTS fin_annual_wide;
CREATE TABLE fin_annual_wide (
    corp_code        TEXT NOT NULL REFERENCES dim_company(corp_code),
    fiscal_year      INTEGER NOT NULL,
    fs_div           TEXT NOT NULL,
    revenue          INTEGER,
    op_income        INTEGER,
    pretax_income    INTEGER,
    net_income       INTEGER,
    current_assets   INTEGER,
    total_assets     INTEGER,
    current_liab     INTEGER,
    total_liab       INTEGER,
    total_equity     INTEGER,
    issued_capital   INTEGER,
    n_mapped         INTEGER NOT NULL,           -- 매핑된 계정 수
    n_unmapped       INTEGER NOT NULL,           -- 미매핑 계정 수 (품질 플래그)
    qc_identity_ok   INTEGER,                    -- 자산 = 부채 + 자본 (1/0/NULL)
    PRIMARY KEY (corp_code, fiscal_year, fs_div)
);
