# 엔진 대조 - SQLite vs DuckDB

생성: 2026-11-18 23:40 · `python scripts/run_duckdb.py`

같은 `sql/03_schema_layered.sql`, `sql/04_load_layered.sql`, `sql/q10·q12·q13` 을 두 엔진에서 실행한 결과 비교.
diff_rows = 정렬·반올림(소수 4자리) 후 문자열로 비교했을 때 다른 행 수. -1 = 컬럼 구성이 다름.

| 대상 | SQLite 행 | DuckDB 행 | diff_rows |
|---|---:|---:|---:|
| fs_fact | 18,981 | 18,981 | 0 |
| fin_annual_wide | 1,286 | 1,286 | 0 |
| v_fin_annual | 1,286 | 1,286 | 0 |
| v_qc_company_coverage | 200 | 200 | 0 |
| filings_universe | 778 | 778 | 0 |
| prices_universe | 139,982 | 139,982 | 0 |
| v_universe_index | 730 | 730 | 0 |
| q10_universe_mapping_monitor | 255 | 255 | 0 |
| q12_universe_sector_profile | 19 | 19 | 0 |
| q13_universe_screen | 11 | 11 | 0 |
| q14_events_vs_financials | 6 | 6 | 0 |
| q15_restructure_next_year | 10 | 10 | 0 |
| q16_universe_filings_vs_price | 6 | 6 | 0 |
| q17_event_window | 22 | 22 | 0 |

## 빌드 시간 (dim + staging 적재 + 04 실행, 같은 PC)

- SQLite 3.4초 / DuckDB 2.6초 (CSV 15개, staging 약 154,000행 기준. pandas 적재 시간 포함)

## 엔진 차이로 SQL 에서 피한 것

- 정수 나눗셈: SQLite 는 `x / 1000000` 이 정수, DuckDB 는 실수 → `CAST(TRUNC(x / 1000000.0) AS BIGINT)`
- 불리언 합산: SQLite 는 `SUM(cond)` 가 되지만 DuckDB 는 안 됨 → `SUM(CASE WHEN cond THEN 1 ELSE 0 END)`
- 문자열 연결: DuckDB 는 숫자를 `||` 로 붙이지 못함 → `CAST(n AS VARCHAR)`
- NULL 안전 비교: SQLite `IS NOT` 는 DuckDB 에 없음 → `NOT (a = b) OR (a IS NULL) <> (b IS NULL)`
- 32비트 정수: DuckDB `INTEGER` 는 32비트라 원 단위 금액이 넘침 → 금액 컬럼은 `BIGINT` (SQLite 에서는 INTEGER 와 동일)
- 중앙값 순번: `(cnt + 1) / 2` 가 DuckDB 에서 실수 → `CAST(FLOOR((cnt + 1) / 2.0) AS INTEGER)`
- `AUTOINCREMENT` 는 엔진마다 달라 etl_log.log_id 는 파이썬에서 채번

검증 안 한 것: q11 (1단계 테이블 필요), 1단계 SQL(01·02·q1~q9) 의 DuckDB 실행.
