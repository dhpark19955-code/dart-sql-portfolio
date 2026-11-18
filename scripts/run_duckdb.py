"""
run_duckdb.py - 2단계 계층 파이프라인(sql/03, sql/04)을 DuckDB 로 똑같이 빌드하고, SQLite 결과와 대조한다.

목적: "표준 SQL 위주로 썼다"는 주장을 실제로 검증한다. 같은 SQL 파일을 두 엔진에서 실행해
      fs_fact / fin_annual_wide / q10 / q12 / q13 결과가 같은지 비교하고 docs/ENGINE_PARITY.md 에 기록한다.

사용법:
    python scripts/build_db.py            # 먼저 SQLite 전체 빌드
    python scripts/run_duckdb.py          # DuckDB 빌드 + 대조 -> dart_sector.duckdb, docs/ENGINE_PARITY.md

엔진 차이로 손댄 것 (SQL 파일은 공통, 여기서만 처리):
    - DuckDB 는 CSV 를 pandas 경유로 넣는다 (SQLite 와 같은 경로). 문자열 -> BIGINT 는 INSERT 시 암묵 변환
    - etl_log 의 log_id 는 파이썬에서 채번 (AUTOINCREMENT 는 두 엔진이 다름)
    - q11 은 1단계 테이블(financials_annual)이 필요해 DuckDB 대조에서 제외
"""
from __future__ import annotations

import sqlite3
import time
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
DIM = ROOT / "data" / "dim"
RAW_LAYERED = ROOT / "data" / "raw" / "layered"
RAW_LAYERED_FULL = ROOT / "data" / "raw" / "layered_full"
RAW_LAYERED_FILINGS = ROOT / "data" / "raw" / "layered_filings"
RAW_LAYERED_PRICES = ROOT / "data" / "raw" / "layered_prices"
SQLITE_DB = ROOT / "dart_sector.db"
DUCK_DB = ROOT / "dart_sector.duckdb"
OUT_MD = ROOT / "docs" / "ENGINE_PARITY.md"
QUERIES = ["q10_universe_mapping_monitor", "q12_universe_sector_profile", "q13_universe_screen",
           "q14_events_vs_financials", "q15_restructure_next_year", "q16_universe_filings_vs_price", "q17_event_window"]


def build_duckdb() -> float:
    if DUCK_DB.exists():
        DUCK_DB.unlink()
    t0 = time.perf_counter()
    con = duckdb.connect(str(DUCK_DB))
    con.execute((SQL / "03_schema_layered.sql").read_text(encoding="utf-8"))
    for fname in ("dim_company.csv", "dim_account_map.csv", "dim_period.csv", "dim_industry.csv"):
        df = pd.read_csv(DIM / fname, dtype=str, keep_default_na=False).replace({"": None})
        con.register("df", df)
        con.execute(f"INSERT INTO {fname[:-4]} SELECT * FROM df")
        con.unregister("df")
    log_id = 0
    for folder, table in ((RAW_LAYERED, "stg_fs_line"), (RAW_LAYERED_FULL, "stg_fs_full"), (RAW_LAYERED_FILINGS, "stg_filings_u"), (RAW_LAYERED_PRICES, "stg_prices_u")):
        for path in sorted(folder.glob("*.csv")) if folder.exists() else []:
            df = pd.read_csv(path, dtype=str, keep_default_na=False)
            df["source_file"] = path.name
            con.register("df", df)
            con.execute(f"INSERT INTO {table} SELECT * FROM df")
            con.unregister("df")
            log_id += 1
            con.execute("INSERT INTO etl_log (log_id, endpoint, params, status, row_count, raw_ref) VALUES (?,?,?,?,?,?)",
                        [log_id, table, path.stem, "000", len(df), f"{folder.name}/{path.name}"])
    con.execute("INSERT INTO incr_scope SELECT corp_code FROM dim_company")
    con.execute((SQL / "04_load_layered.sql").read_text(encoding="utf-8"))
    con.close()
    return time.perf_counter() - t0


def fetch(engine: str, sql: str) -> pd.DataFrame:
    if engine == "sqlite":
        with sqlite3.connect(SQLITE_DB) as c:
            return pd.read_sql_query(sql, c)
    con = duckdb.connect(str(DUCK_DB), read_only=True)
    try:
        return con.execute(sql).df()
    finally:
        con.close()


def normalize(df: pd.DataFrame) -> pd.DataFrame:
    """엔진별 타입 표기 차이를 없앤다: 값이 전부 숫자(또는 NULL)인 열은 float 로 통일해 소수 4자리 반올림,
    불리언은 0/1, 나머지는 문자열. (DuckDB 는 NULL 이 섞인 정수 열을 float 로, SQLite 는 object 로 돌려준다)"""
    df = df.copy()
    df.columns = [c.lower() for c in df.columns]
    for c in df.columns:
        col = df[c]
        if pd.api.types.is_bool_dtype(col):
            df[c] = col.astype(float)
            continue
        num = pd.to_numeric(col, errors="coerce")
        if num.notna().sum() == col.notna().sum():          # 숫자 아닌 값이 없으면 숫자 열로 취급
            df[c] = num.astype(float).round(4)
        else:
            df[c] = col.astype(object).where(col.notna(), None).map(lambda v: None if v is None else str(v))
    df = df.astype(object).where(pd.notna(df), None)
    return df.sort_values(list(df.columns), key=lambda s: s.map(str)).reset_index(drop=True)


def compare(name: str, sql: str) -> tuple[str, int, int, int]:
    a, b = normalize(fetch("sqlite", sql)), normalize(fetch("duckdb", sql))
    if list(a.columns) != list(b.columns):
        return name, len(a), len(b), -1
    if len(a) != len(b):
        return name, len(a), len(b), max(len(a), len(b))
    diff = int((a.astype(str) != b.astype(str)).any(axis=1).sum())
    return name, len(a), len(b), diff


def main() -> None:
    if not SQLITE_DB.exists():
        raise SystemExit("먼저 python scripts/build_db.py 로 SQLite 를 빌드하세요.")
    duck_sec = build_duckdb()

    checks = [
        ("fs_fact", "SELECT corp_code, fiscal_year, fs_div, sj_div, account_nm, std_account, amount_krw, period_offset, source, rcept_no FROM fs_fact"),
        ("fin_annual_wide", "SELECT * FROM fin_annual_wide"),
        ("v_fin_annual", "SELECT * FROM v_fin_annual"),
        ("v_qc_company_coverage", "SELECT * FROM v_qc_company_coverage"),
        ("filings_universe", "SELECT * FROM filings_universe"),
        ("prices_universe", "SELECT * FROM prices_universe"),
        ("v_universe_index", "SELECT * FROM v_universe_index"),
    ] + [(q, (SQL / f"{q}.sql").read_text(encoding="utf-8")) for q in QUERIES]
    rows = [compare(n, s) for n, s in checks]

    # SQLite 쪽 빌드 시간은 build_db.py 의 layered 구간만 따로 재서 비교 (같은 CSV, 같은 SQL)
    t0 = time.perf_counter()
    tmp = ROOT / "_parity_tmp.db"
    if tmp.exists():
        tmp.unlink()
    con = sqlite3.connect(tmp)
    con.executescript((SQL / "03_schema_layered.sql").read_text(encoding="utf-8"))
    for fname in ("dim_company.csv", "dim_account_map.csv", "dim_period.csv", "dim_industry.csv"):
        pd.read_csv(DIM / fname, dtype=str, keep_default_na=False).replace({"": None}).to_sql(fname[:-4], con, if_exists="append", index=False)
    for folder, table in ((RAW_LAYERED, "stg_fs_line"), (RAW_LAYERED_FULL, "stg_fs_full"), (RAW_LAYERED_FILINGS, "stg_filings_u"), (RAW_LAYERED_PRICES, "stg_prices_u")):
        for path in sorted(folder.glob("*.csv")) if folder.exists() else []:
            df = pd.read_csv(path, dtype=str, keep_default_na=False)
            df["source_file"] = path.name
            df.to_sql(table, con, if_exists="append", index=False)
    con.execute("INSERT INTO incr_scope SELECT corp_code FROM dim_company")
    con.executescript((SQL / "04_load_layered.sql").read_text(encoding="utf-8"))
    con.commit(); con.close(); tmp.unlink()
    sqlite_sec = time.perf_counter() - t0

    lines = ["# 엔진 대조 - SQLite vs DuckDB", "",
             f"생성: {time.strftime('%Y-%m-%d %H:%M')} · `python scripts/run_duckdb.py`", "",
             "같은 `sql/03_schema_layered.sql`, `sql/04_load_layered.sql`, `sql/q10·q12·q13` 을 두 엔진에서 실행한 결과 비교.",
             "diff_rows = 정렬·반올림(소수 4자리) 후 문자열로 비교했을 때 다른 행 수. -1 = 컬럼 구성이 다름.", "",
             "| 대상 | SQLite 행 | DuckDB 행 | diff_rows |", "|---|---:|---:|---:|"]
    lines += [f"| {n} | {a:,} | {b:,} | {d} |" for n, a, b, d in rows]
    lines += ["", "## 빌드 시간 (dim + staging 적재 + 04 실행, 같은 PC)", "",
              f"- SQLite {sqlite_sec:.1f}초 / DuckDB {duck_sec:.1f}초 (CSV 15개, staging 약 154,000행 기준. pandas 적재 시간 포함)", "",
              "## 엔진 차이로 SQL 에서 피한 것", "",
              "- 정수 나눗셈: SQLite 는 `x / 1000000` 이 정수, DuckDB 는 실수 → `CAST(TRUNC(x / 1000000.0) AS BIGINT)`",
              "- 불리언 합산: SQLite 는 `SUM(cond)` 가 되지만 DuckDB 는 안 됨 → `SUM(CASE WHEN cond THEN 1 ELSE 0 END)`",
              "- 문자열 연결: DuckDB 는 숫자를 `||` 로 붙이지 못함 → `CAST(n AS VARCHAR)`",
              "- NULL 안전 비교: SQLite `IS NOT` 는 DuckDB 에 없음 → `NOT (a = b) OR (a IS NULL) <> (b IS NULL)`",
              "- 32비트 정수: DuckDB `INTEGER` 는 32비트라 원 단위 금액이 넘침 → 금액 컬럼은 `BIGINT` (SQLite 에서는 INTEGER 와 동일)",
              "- 중앙값 순번: `(cnt + 1) / 2` 가 DuckDB 에서 실수 → `CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER)`",
              "- `AUTOINCREMENT` 는 엔진마다 달라 etl_log.log_id 는 파이썬에서 채번", "",
              "검증 안 한 것: q11 (1단계 테이블 필요), 1단계 SQL(01·02·q1~q9) 의 DuckDB 실행."]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    for n, a, b, d in rows:
        print(f"{n:28s} sqlite={a:>6,} duckdb={b:>6,} diff={d}")
    print(f"build: sqlite {sqlite_sec:.1f}s, duckdb {duck_sec:.1f}s -> {OUT_MD.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
