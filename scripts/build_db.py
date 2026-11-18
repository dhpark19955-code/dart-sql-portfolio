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
    "dart_key_accounts_fy2023.csv":          "stg_dart_key_accounts",   # FY2021~2023 (4분기 도출용 당초 보고값)
    "dart_key_accounts_fy2024.csv":          "stg_dart_key_accounts",   # FY2022~2024 (4분기 도출용 당초 보고값)
    "dart_revenue_supplement_fy2022.csv":    "stg_dart_key_accounts",   # 주요계정 API에 매출액이 빠진 3사 보충
    # 분기보고서 주요계정 (1Q/반기/3Q x 2023~2025) + 계정명이 달라 빠진 행 보충
    "dart_key_accounts_q_fy2023_11013.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2023_11012.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2023_11014.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2024_11013.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2024_11012.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2024_11014.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2025_11013.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2025_11012.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_fy2025_11014.csv":  "stg_dart_key_accounts_q",
    "dart_key_accounts_q_supplement.csv":    "stg_dart_key_accounts_q",
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


DIM = ROOT / "data" / "dim"
RAW_LAYERED = RAW / "layered"
RAW_LAYERED_FULL = RAW / "layered_full"


def _load_dims(conn: sqlite3.Connection) -> None:
    for fname in ("dim_company.csv", "dim_account_map.csv", "dim_period.csv", "dim_industry.csv"):
        df = pd.read_csv(DIM / fname, dtype=str, keep_default_na=False)
        df = df.replace({"": None})
        conn.execute(f"DELETE FROM {fname[:-4]}")
        df.to_sql(fname[:-4], conn, if_exists="append", index=False)
        print(f"  {fname:36s} -> {fname[:-4]:24s} {len(df):>7,} rows")


def _load_raw_file(conn: sqlite3.Connection, path: Path, table: str, endpoint: str) -> set[str]:
    import datetime as _dt
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    df["source_file"] = path.name
    df.to_sql(table, conn, if_exists="append", index=False)
    next_id = conn.execute("SELECT COALESCE(MAX(log_id), 0) + 1 FROM etl_log").fetchone()[0]
    conn.execute(
        "INSERT INTO etl_log (log_id, endpoint, params, status, row_count, fetched_at, raw_ref) VALUES (?,?,?,?,?,?,?)",
        (next_id, endpoint, path.stem, "000", len(df),
         _dt.datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
         f"{path.parent.name}/{path.name}"))
    print(f"  {path.name:52s} -> {table:12s} {len(df):>7,} rows")
    return set(df["corp_code"].unique())


def build_layered(conn: sqlite3.Connection, incremental: bool = False) -> None:
    """대형화 2~3단계: dim_* + staging -> fs_fact -> fin_annual_wide (sql/03, sql/04).

    incremental=True: 기존 DB 를 지우지 않고, etl_log.raw_ref 에 없는 raw 파일만 적재한 뒤
    그 파일에 등장한 회사(incr_scope)의 core/mart 행만 지우고 다시 계산한다.
    """
    if not (DIM / "dim_company.csv").exists():
        print("4) layered: skip (data/dim/dim_company.csv not found)")
        return
    raw_sets = [(RAW_LAYERED, "stg_fs_line", "fnlttMultiAcnt"),
                (RAW_LAYERED_FULL, "stg_fs_full", "fnlttSinglAcntAll"),
                (RAW / "layered_filings", "stg_filings_u", "list.json")]
    if incremental:
        print("4) layered: incremental")
        loaded = {r[0] for r in conn.execute("SELECT raw_ref FROM etl_log")}
        _load_dims(conn)
        scope: set[str] = set()
        for folder, table, endpoint in raw_sets:
            for path in (sorted(folder.glob("*.csv")) if folder.exists() else []):
                if f"{folder.name}/{path.name}" in loaded:
                    continue
                scope |= _load_raw_file(conn, path, table, endpoint)
        if not scope:
            print("   nothing new - core/mart unchanged")
            conn.commit()
            return
        conn.execute("DELETE FROM incr_scope")
        conn.executemany("INSERT INTO incr_scope (corp_code) VALUES (?)", [(c,) for c in sorted(scope)])
        conn.execute("DELETE FROM fs_fact WHERE corp_code IN (SELECT corp_code FROM incr_scope)")
        conn.execute("DELETE FROM fin_annual_wide WHERE corp_code IN (SELECT corp_code FROM incr_scope)")
        conn.execute("DELETE FROM filings_universe WHERE corp_code IN (SELECT corp_code FROM incr_scope)")
        print(f"   recompute scope: {len(scope)} companies")
    else:
        print("4) layered schema")
        run_sql_file(conn, SQL / "03_schema_layered.sql")
        print("5) layered dims + staging")
        _load_dims(conn)
        for folder, table, endpoint in raw_sets:
            for path in (sorted(folder.glob("*.csv")) if folder.exists() else []):
                _load_raw_file(conn, path, table, endpoint)
        conn.execute("INSERT INTO incr_scope (corp_code) SELECT corp_code FROM dim_company")
    print("6) layered core / mart")
    run_sql_file(conn, SQL / "04_load_layered.sql")
    conn.commit()
    for t in ("dim_company", "dim_account_map", "stg_fs_line", "stg_fs_full", "fs_fact", "fin_annual_wide", "filings_universe", "etl_log"):
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"   {t:20s} {n:>7,} rows")


def main() -> None:
    import argparse
    ap = argparse.ArgumentParser(description="CSV -> SQLite build")
    ap.add_argument("--incremental", action="store_true",
                    help="DB 를 지우지 않고, 아직 적재되지 않은 raw/layered*.csv 만 더해 해당 회사만 재계산")
    args = ap.parse_args()
    if args.incremental:
        if not DB.exists():
            raise SystemExit("incremental 모드는 기존 dart_sector.db 가 필요합니다. 먼저 전체 빌드를 하세요.")
        conn = sqlite3.connect(DB)
        build_layered(conn, incremental=True)
        conn.close()
        print(f"done (incremental) -> {DB.name}")
        return
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

    for t in ("companies", "financials_annual", "financials_quarter", "prices_daily", "shares_outstanding", "filings"):
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"   {t:20s} {n:>7,} rows")

    build_layered(conn)
    conn.close()
    print(f"done -> {DB.name}")


if __name__ == "__main__":
    main()
