"""
run_queries.py - sql/q*.sql 을 순서대로 실행하고 결과를 results/<name>.md 로 저장한다.

각 결과 파일 구성:
    1. SQL 파일 상단의 주석(질문·기법·주의사항)
    2. 결과 표 (markdown)
    3. 실행한 SQL 전문

사용법:
    python scripts/run_queries.py            # 전체
    python scripts/run_queries.py q2         # 파일명에 'q2'가 포함된 것만
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
RESULTS = ROOT / "results"
DB = ROOT / "dart_sector.db"


def header_comment(sql_text: str) -> str:
    lines = []
    for line in sql_text.splitlines():
        if line.startswith("--"):
            lines.append(line[2:].strip())
        elif line.strip() == "":
            continue
        else:
            break
    return "\n".join(lines)


def to_markdown(df: pd.DataFrame) -> str:
    df = df.copy()
    for col in df.columns:
        if pd.api.types.is_float_dtype(df[col]):
            df[col] = df[col].map(lambda v: "" if pd.isna(v) else f"{v:,.1f}".rstrip("0").rstrip("."))
        elif pd.api.types.is_integer_dtype(df[col]) and not col.endswith("year"):
            df[col] = df[col].map(lambda v: f"{v:,}")
    df = df.fillna("")
    return df.to_markdown(index=False)


def main() -> None:
    pattern = sys.argv[1] if len(sys.argv) > 1 else ""
    RESULTS.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB)
    for path in sorted(SQL.glob("q*.sql")):
        if pattern and pattern not in path.name:
            continue
        sql_text = path.read_text(encoding="utf-8")
        df = pd.read_sql_query(sql_text, conn)
        out = RESULTS / f"{path.stem}.md"
        out.write_text(
            f"# {path.stem}\n\n"
            f"{header_comment(sql_text)}\n\n"
            f"## Result ({len(df)} rows)\n\n{to_markdown(df)}\n\n"
            f"## SQL\n\n```sql\n{sql_text.strip()}\n```\n",
            encoding="utf-8",
        )
        print(f"{path.name:36s} {len(df):>4} rows -> {out.relative_to(ROOT)}")
    conn.close()


if __name__ == "__main__":
    main()
