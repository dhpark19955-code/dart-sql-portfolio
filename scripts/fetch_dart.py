"""
fetch_dart.py - OpenDART API로 다중회사 주요계정을 받아 data/raw/dart_key_accounts_fy<YEAR>.csv 로 저장한다.

- 엔드포인트: https://opendart.fss.or.kr/api/fnlttMultiAcnt.json  (다중회사 주요계정)
- 사업보고서(reprt_code=11011) 1건에 당기/전기/전전기 3개년이 들어오므로
  fy2025 + fy2022 두 번이면 2020~2025 6개년이 채워진다.
- API 키는 환경변수 DART_API_KEY 로만 읽는다. 코드·CSV에 키를 쓰지 않는다.

사용법:
    export DART_API_KEY=...            (Windows: $env:DART_API_KEY="...")
    python scripts/fetch_dart.py 2025
    python scripts/fetch_dart.py 2022

주의:
    - data/raw/dart_key_accounts_fy2025.csv 는 2026-11-18 에 MCP 경유로 받은 스냅샷이다.
      이 스크립트로 다시 받으면 같은 파일을 덮어쓴다 (정정공시 반영 가능).
    - build_db.py 의 CSV_TO_STAGING 에 새 연도 파일을 추가해야 적재된다.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
URL = "https://opendart.fss.or.kr/api/fnlttMultiAcnt.json"

KEEP_ACCOUNTS = {"유동자산", "자산총계", "유동부채", "부채총계", "자본총계",
                 "매출액", "영업이익", "당기순이익(손실)"}
KEEP_COLS = ["rcept_no", "bsns_year", "reprt_code", "corp_code", "stock_code",
             "fs_div", "sj_div", "account_nm", "thstrm_amount", "frmtrm_amount",
             "bfefrmtrm_amount", "currency"]


def fetch(year: str, corp_codes: list[str], api_key: str) -> pd.DataFrame:
    params = {
        "crtfc_key": api_key,
        "corp_code": ",".join(corp_codes),   # 최대 100개사
        "bsns_year": year,
        "reprt_code": "11011",               # 사업보고서
    }
    r = requests.get(URL, params=params, timeout=30)
    r.raise_for_status()
    body = r.json()
    if body.get("status") != "000":
        raise RuntimeError(f"DART error {body.get('status')}: {body.get('message')}")
    df = pd.DataFrame(body["list"])
    df = df[(df["fs_div"] == "CFS") & (df["account_nm"].isin(KEEP_ACCOUNTS))]
    # 당기순이익이 2행 오는 경우가 있어 첫 행만 남긴다
    df = df.drop_duplicates(subset=["corp_code", "fs_div", "account_nm"], keep="first")
    df["currency"] = df.get("currency", "KRW")
    return df[KEEP_COLS].reset_index(drop=True)


def main() -> None:
    api_key = os.environ.get("DART_API_KEY")
    if not api_key:
        sys.exit("DART_API_KEY 환경변수가 없습니다. .env.example 참고")
    year = sys.argv[1] if len(sys.argv) > 1 else "2025"

    companies = pd.read_csv(RAW / "companies.csv", dtype=str)
    df = fetch(year, companies["corp_code"].tolist(), api_key)
    out = RAW / f"dart_key_accounts_fy{year}.csv"
    df.to_csv(out, index=False)
    print(f"{out.name}: {len(df)} rows, {df['corp_code'].nunique()} companies")


if __name__ == "__main__":
    main()
