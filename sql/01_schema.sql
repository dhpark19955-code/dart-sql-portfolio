-- 01_schema.sql
-- 원천(staging) 테이블과 정제된 분석용 테이블을 분리한다.
-- stg_*  : CSV를 그대로 적재 (문자열, 콤마 포함 금액 등 원형 유지)
-- 분석용 : 타입 정리·단위 통일·피벗 완료, 분석 쿼리는 이 테이블만 사용

PRAGMA foreign_keys = ON;

-- ---------- staging ----------
DROP TABLE IF EXISTS stg_companies;
CREATE TABLE stg_companies (
    corp_code      TEXT,
    stock_code     TEXT,
    corp_name      TEXT,
    corp_name_en   TEXT,
    market         TEXT,
    sector         TEXT,
    yf_ticker      TEXT,
    delisted_date  TEXT
);

DROP TABLE IF EXISTS stg_dart_key_accounts;
CREATE TABLE stg_dart_key_accounts (
    rcept_no         TEXT,
    bsns_year        TEXT,
    reprt_code       TEXT,
    corp_code        TEXT,
    stock_code       TEXT,
    fs_div           TEXT,
    sj_div           TEXT,
    account_nm       TEXT,
    thstrm_amount    TEXT,   -- 당기  (예: "1,234,567" / "-1,234" / "-")
    frmtrm_amount    TEXT,   -- 전기
    bfefrmtrm_amount TEXT,   -- 전전기
    currency         TEXT
);

DROP TABLE IF EXISTS stg_prices_daily;
CREATE TABLE stg_prices_daily (
    stock_code TEXT,
    trade_date TEXT,
    open       REAL,
    high       REAL,
    low        REAL,
    close      REAL,
    adj_close  REAL,
    volume     REAL
);

DROP TABLE IF EXISTS stg_shares_outstanding;
CREATE TABLE stg_shares_outstanding (
    stock_code  TEXT,
    shares      INTEGER,
    as_of_date  TEXT
);

-- 분기보고서(1Q 11013 / 반기 11012 / 3Q 11014) 주요계정. 이 스냅샷의 thstrm_amount 는 당기 3개월값
-- (원 API 에는 누적 열 thstrm_add_amount 가 따로 있으나 수집 경로에서 빠짐)
DROP TABLE IF EXISTS stg_dart_key_accounts_q;
CREATE TABLE stg_dart_key_accounts_q (
    rcept_no         TEXT,
    bsns_year        TEXT,
    reprt_code       TEXT,   -- 11013 / 11012 / 11014
    corp_code        TEXT,
    stock_code       TEXT,
    fs_div           TEXT,
    sj_div           TEXT,
    account_nm       TEXT,
    thstrm_amount    TEXT,   -- 당기 3개월 (BS 는 분기말 잔액)
    frmtrm_amount    TEXT,
    currency         TEXT
);

-- KRX 목록에 없는 종목(상장폐지 등)의 주식수를 사람이 보충. source에 근거를 적는다
DROP TABLE IF EXISTS stg_shares_manual;
CREATE TABLE stg_shares_manual (
    stock_code  TEXT,
    shares      INTEGER,
    as_of_date  TEXT,
    source      TEXT
);

-- OpenDART list.json 응답 그대로 (pblntf_ty=B 주요사항보고서)
DROP TABLE IF EXISTS stg_filings;
CREATE TABLE stg_filings (
    rcept_no    TEXT,
    corp_code   TEXT,
    stock_code  TEXT,
    report_nm   TEXT,
    rcept_dt    TEXT,   -- 'YYYYMMDD'
    pblntf_ty   TEXT
);

-- ---------- 분석용 ----------
DROP TABLE IF EXISTS companies;
CREATE TABLE companies (
    corp_code      TEXT PRIMARY KEY,          -- DART 고유번호 (8자리)
    stock_code     TEXT NOT NULL UNIQUE,      -- 종목코드 (6자리)
    corp_name      TEXT NOT NULL,
    corp_name_en   TEXT,
    market         TEXT CHECK (market IN ('KOSPI', 'KOSDAQ')),
    sector         TEXT NOT NULL,
    delisted_date  TEXT                       -- NULL이면 상장 유지
);

-- 회사 x 회계연도 1행, 금액은 백만원(KRW mn) 단위로 통일
DROP TABLE IF EXISTS financials_annual;
CREATE TABLE financials_annual (
    corp_code        TEXT NOT NULL REFERENCES companies(corp_code),
    fiscal_year      INTEGER NOT NULL,
    fs_div           TEXT NOT NULL DEFAULT 'CFS',   -- 연결
    current_assets   INTEGER,
    total_assets     INTEGER,
    current_liab     INTEGER,
    total_liab       INTEGER,
    total_equity     INTEGER,
    revenue          INTEGER,
    op_income        INTEGER,
    net_income       INTEGER,
    source_rcept_no  TEXT,                          -- 출처 접수번호
    PRIMARY KEY (corp_code, fiscal_year, fs_div)
);

DROP TABLE IF EXISTS prices_daily;
CREATE TABLE prices_daily (
    stock_code TEXT NOT NULL REFERENCES companies(stock_code),
    trade_date TEXT NOT NULL,                 -- 'YYYY-MM-DD'
    close      REAL NOT NULL,
    adj_close  REAL,
    volume     INTEGER,
    PRIMARY KEY (stock_code, trade_date)
);
CREATE INDEX idx_prices_date ON prices_daily (trade_date);

DROP TABLE IF EXISTS shares_outstanding;
CREATE TABLE shares_outstanding (
    stock_code TEXT PRIMARY KEY REFERENCES companies(stock_code),
    shares     INTEGER NOT NULL,
    as_of_date TEXT NOT NULL,
    source     TEXT NOT NULL DEFAULT 'KRX'        -- 'KRX' 또는 수기 보충 근거
);

-- 회사 x 회계연도 x 분기 1행. 손익은 3개월값과 연초누적을 둘 다 둔다 (백만원)
-- 4분기는 분기보고서가 없으므로 사업보고서 연간값 - 1~3분기 합으로 도출 (is_derived = 1)
DROP TABLE IF EXISTS financials_quarter;
CREATE TABLE financials_quarter (
    corp_code        TEXT NOT NULL REFERENCES companies(corp_code),
    fiscal_year      INTEGER NOT NULL,
    quarter          INTEGER NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    fs_div           TEXT NOT NULL DEFAULT 'CFS',
    current_assets   INTEGER,                      -- 재무상태표: 분기말 잔액
    total_assets     INTEGER,
    current_liab     INTEGER,
    total_liab       INTEGER,
    total_equity     INTEGER,
    revenue          INTEGER,                      -- 손익: 3개월
    op_income        INTEGER,
    net_income       INTEGER,
    revenue_cum      INTEGER,                      -- 손익: 연초부터 누적
    op_income_cum    INTEGER,
    net_income_cum   INTEGER,
    is_derived       INTEGER NOT NULL DEFAULT 0,   -- 1 = 4분기 도출값
    source_rcept_no  TEXT,
    PRIMARY KEY (corp_code, fiscal_year, quarter, fs_div)
);

-- 공시 1건 1행. 정정공시도 별도 rcept_no 로 들어온다
DROP TABLE IF EXISTS filings;
CREATE TABLE filings (
    rcept_no   TEXT PRIMARY KEY,                  -- 접수번호 (14자리)
    corp_code  TEXT NOT NULL REFERENCES companies(corp_code),
    report_nm  TEXT NOT NULL,
    rcept_dt   TEXT NOT NULL,                     -- 'YYYY-MM-DD' 로 정규화
    pblntf_ty  TEXT NOT NULL,                     -- B = 주요사항보고서
    is_amendment INTEGER NOT NULL DEFAULT 0       -- report_nm 이 '[' 로 시작(기재정정 등)하면 1
);
CREATE INDEX idx_filings_corp_dt ON filings (corp_code, rcept_dt);
