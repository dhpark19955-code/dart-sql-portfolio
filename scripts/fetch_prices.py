"""
fetch_prices.py - 분석 대상 13개사의 일별 주가와 상장주식수를 수집해 data/raw/에 저장한다.

- 주가: yfinance (KOSPI .KS / KOSDAQ .KQ 접미사), 2023-01-01 ~ 2025-12-31
- 상장주식수: FinanceDataReader의 KRX 상장종목 목록 (수집 시점 기준 현재 주식수)

사용법:
    python scripts/fetch_prices.py

출력:
    data/raw/prices_daily.csv      (stock_code, trade_date, open, high, low, close, adj_close, volume)
    data/raw/shares_outstanding.csv (stock_code, shares, as_of_date)
"""
from __future__ import annotations

import datetime as dt
from pathlib import Path

import pandas as pd
import yfinance as yf
import FinanceDataReader as fdr

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

START, END = "2023-01-01", "2026-01-01"


def fetch_prices(companies: pd.DataFrame) -> pd.DataFrame:
    tickers = companies["yf_ticker"].tolist()
    raw = yf.download(tickers, start=START, end=END, auto_adjust=False,
                      progress=False, group_by="ticker")
    frames = []
    for _, row in companies.iterrows():
        t = row["yf_ticker"]
        df = raw[t].dropna(subset=["Close"]).copy()
        df.index.name = "trade_date"
        df = df.reset_index()
        df.insert(0, "stock_code", row["stock_code"])
        df.columns = ["stock_code", "trade_date", "open", "high", "low",
                      "close", "adj_close", "volume"]
        frames.append(df)
    out = pd.concat(frames, ignore_index=True)
    out["trade_date"] = pd.to_datetime(out["trade_date"]).dt.strftime("%Y-%m-%d")
    return out


def fetch_shares(companies: pd.DataFrame) -> pd.DataFrame:
    lst = fdr.StockListing("KRX")[["Code", "Stocks"]]
    lst = lst[lst["Code"].isin(companies["stock_code"])].rename(
        columns={"Code": "stock_code", "Stocks": "shares"})
    lst["as_of_date"] = dt.date.today().isoformat()
    return lst.reset_index(drop=True)


def main() -> None:
    companies = pd.read_csv(RAW / "companies.csv", dtype=str)
    prices = fetch_prices(companies)
    prices.to_csv(RAW / "prices_daily.csv", index=False)
    print(f"prices_daily.csv: {len(prices):,} rows")

    shares = fetch_shares(companies)
    shares.to_csv(RAW / "shares_outstanding.csv", index=False)
    print(f"shares_outstanding.csv: {len(shares)} rows")


if __name__ == "__main__":
    main()
