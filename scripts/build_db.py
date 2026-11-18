"""
build_db.py - data/raw/*.csv 를 SQLite(dart_sector.db)에 적재하고 정제 SQL을 실행한다.

흐름:
    1. sql/01_schema.sql   : staging / 분석용 테이블 생성
    2. CSV -> stg_* 테이블  (pandas, 모두 문자열로 읽어 원형 보존)
    3. sql/02_load_clean.sql : staging -> 분석용 (UNPIVOT / PIVOT / 형변환 / 중복제거)

사용법:
    python scripts/build_db.py
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
SQL = ROOT / "sql"
DB = ROOT / "dart_sector.db"

# 같은 staging 테이블에 여러 파일을 append 할 수 있다 (연도별 DART 스냅샷)
CSV_TO_STAGING = {
    "companies.csv":                         "stg_companies",
    "dart_key_accounts_fy2025.csv":          "stg_dart_key_accounts",   # FY2023~2025
    "dart_key_accounts_fy2022.csv":          "stg_dart_key_accounts",   # FY2020~2022
    "dart_revenue_supplement_fy2022.csv":    "stg_dart_key_accounts",   # 주요계정 API에 매출액이 빠진 3사 보충
    "prices_daily.csv":                      "stg_prices_daily",
    "shares_outstanding.csv":                "stg_shares_outstanding",
    "shares_manual.csv":                     "stg_shares_manual",
    "filings.csv":                           "stg_filings",
}


def run_sql_file(conn: sqlite3.Connection, path: Path) -> None:
    conn.executescript(path.read_text(encoding="utf-8"))


def load_csvs(conn: sqlite3.Connection) -> None:
    for fname, table in CSV_TO_STAGING.items():
        path = RAW / fname
        if not path.exists():
            print(f"  skip {fname} (not found)")
            continue
        # 종목코드 앞자리 0 보존을 위해 문자열로 읽고, 숫자 컬럼만 pandas가 추론하도록 둔다
        df = pd.read_csv(path, dtype={"corp_code": str, "stock_code": str,
                                      "rcept_no": str, "bsns_year": str,
                                      "reprt_code": str, "rcept_dt": str},
                         keep_default_na=False)
        df.to_sql(table, conn, if_exists="append", index=False)
        print(f"  {fname:32s} -> {table:24s} {len(df):>7,} rows")


def main() -> None:
    if DB.exists():
        DB.unlink()
    conn = sqlite3.connect(DB)
    print("1) schema")
    run_sql_file(conn, SQL / "01_schema.sql")
    print("2) load staging")
    load_csvs(conn)
    print("3) clean / transform")
    run_sql_file(conn, SQL / "02_load_clean.sql")
    conn.commit()

    for t in ("companies", "financials_annual", "prices_daily", "shares_outstanding", "filings"):
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"   {t:20s} {n:>7,} rows")
    conn.close()
    print(f"done -> {DB.name}")


if __name__ == "__main__":
    main()
