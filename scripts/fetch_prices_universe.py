"""
fetch_prices_universe.py - dim_company.csv 의 200사 일별 주가를 yfinance 로 받아 data/raw/layered_prices/ 에 저장한다.

- 티커: 종목코드 + '.KS' (KOSPI). 2023-01-01 ~ 2025-12-31
- 열: stock_code, trade_date, close, adj_close, volume (1단계 prices_daily 와 같은 뜻)
- 50개씩 나눠 받고, 한 배치가 실패해도 나머지는 계속한다. 못 받은 종목은 마지막에 출력

사용법:
    python scripts/fetch_prices_universe.py
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd
import yfinance as yf

ROOT = Path(__file__).resolve().parents[1]
DIM = ROOT / "data" / "dim" / "dim_company.csv"
OUT_DIR = ROOT / "data" / "raw" / "layered_prices"
START, END = "2023-01-01", "2026-01-01"
BATCH = 50


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dim = pd.read_csv(DIM, dtype=str)
    codes = dim["stock_code"].tolist()
    frames, missing = [], []
    for i in range(0, len(codes), BATCH):
        chunk = codes[i:i + BATCH]
        tickers = [f"{c}.KS" for c in chunk]
        raw = yf.download(tickers, start=START, end=END, auto_adjust=False, progress=False,
                          group_by="ticker", threads=True)
        for code, t in zip(chunk, tickers):
            try:
                df = raw[t].dropna(subset=["Close"]).copy()
            except KeyError:
                missing.append(code); continue
            if df.empty:
                missing.append(code); continue
            df.index.name = "trade_date"
            df = df.reset_index()[["trade_date", "Close", "Adj Close", "Volume"]]
            df.columns = ["trade_date", "close", "adj_close", "volume"]
            df.insert(0, "stock_code", code)
            frames.append(df)
        print(f"batch {i // BATCH + 1}: {len(chunk)} tickers, rows so far {sum(len(f) for f in frames):,}")
    out = pd.concat(frames, ignore_index=True)
    out["trade_date"] = pd.to_datetime(out["trade_date"]).dt.strftime("%Y-%m-%d")
    out["volume"] = out["volume"].fillna(0).astype("int64")
    out = out.sort_values(["stock_code", "trade_date"])
    path = OUT_DIR / "prices_universe_2023_2025.csv"
    out.to_csv(path, index=False, float_format="%.4f")
    print(f"{path.name}: {len(out):,} rows, {out.stock_code.nunique()} stocks, missing {len(missing)}: {missing}")


if __name__ == "__main__":
    main()
