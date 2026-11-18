-- 03_schema_layered.sql
-- 대형화 2~3단계: raw -> staging -> core -> mart 4계층 + 보조테이블(dim_*) + 품질점검 뷰
-- 1단계까지의 테이블(companies, financials_annual, financials_quarter ...)은 그대로 두고,
-- 유니버스를 KOSPI 시가총액 상위 200사로 넓힌 연간 재무를 이 계층 구조로 적재한다.
-- 3단계에서 추가: 전체 재무제표 API(stg_fs_full, account_id 기준 매핑), 소스 우선순위, 증분 적재 범위(incr_scope)
-- 설계 근거: docs/LARGE_SCALE_PLAN.md, docs/LARGE_SCALE_DESIGN.xlsx
-- 이식성: SQLite 와 DuckDB 에서 같은 파일을 쓴다. 금액은 BIGINT(SQLite 에서는 INTEGER 와 동일), 정수 나눗셈 대신 TRUNC

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
    marcap_krw      BIGINT,                      -- 유니버스 선정 시점 시가총액 (원)
    listing_date    TEXT,
    delisted_date   TEXT,
    is_financial    INTEGER NOT NULL DEFAULT 0,  -- 1 = 금융업 (매출액 대신 영업수익·순영업수익)
    universe        TEXT NOT NULL,               -- 'KOSPI_TOP200_20261118'
    as_of_date      TEXT NOT NULL
);

DROP TABLE IF EXISTS dim_account_map;
CREATE TABLE dim_account_map (
    map_id       INTEGER PRIMARY KEY,
    account_id   TEXT,                           -- IFRS/DART 표준 계정코드. 있으면 계정명보다 우선 (전체 재무제표 API)
    sj_div       TEXT,                           -- BS / IS / CF. NULL 이면 재무제표 구분 무관 (CIS 는 IS 로 취급)
    account_nm   TEXT,                           -- API 가 주는 계정명 변형 (주요계정 API 는 account_id 가 없음)
    std_account  TEXT NOT NULL,                  -- 표준 계정 (mart 컬럼명)
    sign         INTEGER NOT NULL DEFAULT 1,     -- 1 그대로, -1 뒤집기 (abs 금지)
    value_type   TEXT NOT NULL CHECK (value_type IN ('flow', 'balance')),
    priority     INTEGER NOT NULL DEFAULT 1,     -- 같은 표준 계정에 여러 변형이 있을 때 낮을수록 우선
    note         TEXT
);
CREATE INDEX idx_map_nm ON dim_account_map (account_nm);
CREATE INDEX idx_map_id ON dim_account_map (account_id);

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
    log_id      INTEGER PRIMARY KEY,             -- build_db.py 가 채번
    endpoint    TEXT NOT NULL,                   -- fnlttMultiAcnt / fnlttSinglAcntAll
    params      TEXT,                            -- 호출 파라미터 (키 제외)
    status      TEXT,                            -- DART 상태코드 (000 정상, 013 없음, 020 한도)
    row_count   INTEGER,
    fetched_at  TEXT,
    raw_ref     TEXT UNIQUE,                     -- raw 파일 위치. 증분 적재 시 이미 적재된 파일 판별 키
    error_msg   TEXT
);

-- 증분 적재 범위: build_db.py 가 매 실행마다 채운다 (전체 빌드 = 전 회사, 증분 = 새 raw 파일에 등장한 회사만)
DROP TABLE IF EXISTS incr_scope;
CREATE TABLE incr_scope (
    corp_code   TEXT PRIMARY KEY
);

-- ---------- staging (원문 행, 값은 문자열) ----------
-- (a) 다중회사 주요계정 API: 계정명만, 회사당 10~15 계정
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

-- (b) 단일회사 전체 재무제표 API: account_id 포함, 회사당 100~200 계정. 주요계정 API 가 안 주는 회사의 대체 경로
DROP TABLE IF EXISTS stg_fs_full;
CREATE TABLE stg_fs_full (
    rcept_no         TEXT,
    bsns_year        TEXT,
    reprt_code       TEXT,
    corp_code        TEXT,
    fs_div           TEXT,
    sj_div           TEXT,                       -- BS / CIS / IS / CF / SCE
    account_id       TEXT,
    account_nm       TEXT,
    thstrm_amount    TEXT,
    frmtrm_amount    TEXT,
    bfefrmtrm_amount TEXT,
    currency         TEXT,
    source_file      TEXT
);

-- (c) 공시목록 API(list.json) 주요사항보고서: 4단계 이벤트 축
DROP TABLE IF EXISTS stg_filings_u;
CREATE TABLE stg_filings_u (
    rcept_no    TEXT,
    corp_code   TEXT,
    stock_code  TEXT,
    report_nm   TEXT,
    rcept_dt    TEXT,                            -- 'YYYYMMDD'
    pblntf_ty   TEXT,
    source_file TEXT
);

-- ---------- core (회사 x 연도 x 계정 1행, 원 단위 정수, 표준 계정 매핑) ----------
DROP TABLE IF EXISTS fs_fact;
CREATE TABLE fs_fact (
    corp_code      TEXT NOT NULL,
    fiscal_year    INTEGER NOT NULL,
    fs_div         TEXT NOT NULL,                -- CFS / OFS
    sj_div         TEXT NOT NULL,
    account_nm     TEXT NOT NULL,                -- 원문 계정명 (매핑 전)
    account_id     TEXT,                         -- 전체 재무제표 API 행만 있음
    std_account    TEXT,                         -- NULL = 미매핑 (품질점검 대상)
    value_type     TEXT,
    amount_krw     BIGINT,                       -- 원 단위. '-' 는 NULL
    period_offset  INTEGER NOT NULL,             -- 0 당기 / 1 전기 / 2 전전기 열에서 왔는지
    source         TEXT NOT NULL,                -- 'key_accounts' / 'full_fs'
    rcept_no       TEXT NOT NULL,                -- 채택된 보고서 (회사·연도당 1건)
    PRIMARY KEY (corp_code, fiscal_year, fs_div, sj_div, account_nm)
);
CREATE INDEX idx_fact_std ON fs_fact (std_account, fiscal_year);

-- 공시 1건 1행 + 유형 분류 (core). 유형 규칙은 04 의 CASE 에 있고, 바뀌면 재빌드로 다시 분류된다
DROP TABLE IF EXISTS filings_universe;
CREATE TABLE filings_universe (
    rcept_no      TEXT PRIMARY KEY,
    corp_code     TEXT NOT NULL,
    report_nm     TEXT NOT NULL,
    rcept_dt      TEXT NOT NULL,                 -- 'YYYY-MM-DD'
    fiscal_year   INTEGER NOT NULL,              -- 공시 연도 (12월 결산 가정)
    pblntf_ty     TEXT NOT NULL,
    is_amendment  INTEGER NOT NULL,              -- [기재정정]·[첨부정정]·[첨부추가]·[연장결정] 등 '[' 로 시작
    event_type    TEXT NOT NULL                  -- treasury / financing / restructure / other
);
CREATE INDEX idx_filings_u_corp ON filings_universe (corp_code, fiscal_year);

-- ---------- mart (회사 x 연도 x 기준 1행 와이드, 백만원) ----------
DROP TABLE IF EXISTS fin_annual_wide;
CREATE TABLE fin_annual_wide (
    corp_code        TEXT NOT NULL,
    fiscal_year      INTEGER NOT NULL,
    fs_div           TEXT NOT NULL,
    revenue          BIGINT,
    op_income        BIGINT,
    pretax_income    BIGINT,
    net_income       BIGINT,
    current_assets   BIGINT,
    total_assets     BIGINT,
    current_liab     BIGINT,
    total_liab       BIGINT,
    total_equity     BIGINT,
    issued_capital   BIGINT,
    n_mapped         INTEGER NOT NULL,           -- 매핑된 계정 수
    n_unmapped       INTEGER NOT NULL,           -- 미매핑 계정 수 (품질 플래그)
    qc_identity_ok   INTEGER,                    -- 자산 = 부채 + 자본 (1/0/NULL)
    source           TEXT NOT NULL,              -- 'key_accounts' / 'full_fs' / 'mixed'
    PRIMARY KEY (corp_code, fiscal_year, fs_div)
);
