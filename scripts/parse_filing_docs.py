"""
parse_filing_docs.py - data/raw/layered_docs/<rcept_no>.txt (DART 주요사항보고서 원문 앞부분) 에서 핵심 수치를 뽑아
data/raw/layered_docs_parsed/filing_details.csv 로 저장한다.

원문 형식: 공시 표가 " | 항목명 | \\n | 값 | " 로 납작하게 펼쳐져 있다. 날짜는 파이프 없이 한 줄.
방식: 항목명을 찾고 그 다음에 오는 비어 있지 않은 토큰을 값으로 읽는다 (라벨 → 값 규칙). 유형별로 읽을 항목만 다르다.
수치는 "1,234" -> 1234 정수, "0.4492620" -> 실수, '-' -> NULL. 파싱 못 한 항목은 비워 두고 parse_note 에 남긴다.

사용법:
    python scripts/parse_filing_docs.py
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "data" / "raw" / "layered_docs"
OUT = ROOT / "data" / "raw" / "layered_docs_parsed" / "filing_details.csv"
FILINGS = ROOT / "data" / "raw" / "layered_filings" / "filings_universe_2023_2025.csv"

COLS = ["rcept_no", "doc_type", "amount_krw", "purpose_facility", "purpose_operating", "purpose_debt",
        "purpose_acquisition", "purpose_other", "coupon_pct", "ytm_pct", "maturity_date", "issue_method",
        "conv_price", "shares_new", "shares_before", "price_per_share", "discount_pct",
        "shares_reduced", "reduction_ratio_pct", "reduction_method",
        "merger_ratio", "counterparty", "counterparty_assets_krw", "counterparty_revenue_krw",
        "truncated", "parse_note"]


def tokens(text: str) -> list[str]:
    """' | a | \\n | b | ' 를 ['a', 'b', ...] 로. 빈 토큰 제거, 줄바꿈으로 쪼개진 값은 한 토큰으로 두지 않는다 (라벨 기준 탐색이라 충분)."""
    out = []
    for line in text.splitlines():
        for piece in line.split("|"):
            p = piece.strip()
            if p:
                out.append(p)
    return out


def find_after(toks: list[str], label: str, start: int = 0, skip: int = 1, prefix: bool = True) -> tuple[str | None, int]:
    """label 과 일치(또는 시작)하는 토큰 뒤 skip 번째 토큰. (값, 위치) 반환. 못 찾으면 (None, -1)."""
    for i in range(start, len(toks)):
        t = toks[i]
        if (t.startswith(label) if prefix else t == label):
            j = i + skip
            return (toks[j] if j < len(toks) else None), i
    return None, -1


def num(v: str | None) -> int | None:
    if v is None:
        return None
    s = v.replace(",", "").replace(" ", "")
    if s in ("", "-", "0") or not re.fullmatch(r"-?\d+", s):
        return None if s != "0" else 0
    return int(s)


def fnum(v: str | None) -> float | None:
    if v is None:
        return None
    s = v.replace(",", "").replace(" ", "").rstrip("%")
    try:
        return float(s)
    except ValueError:
        return None


def date(v: str | None) -> str | None:
    if not v:
        return None
    m = re.search(r"(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일", v.replace("\n", ""))
    return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}" if m else None


def purpose(toks: list[str], row: dict, start: int) -> None:
    for key, label in [("purpose_facility", "시설자금"), ("purpose_operating", "운영자금"), ("purpose_debt", "채무상환자금"),
                       ("purpose_acquisition", "타법인 증권"), ("purpose_other", "기타자금")]:
        v, _ = find_after(toks, label, start)
        row[key] = num(v)


def parse_bond(toks: list[str], row: dict) -> None:
    v, i = find_after(toks, "2. 사채의 권면")
    row["amount_krw"] = num(v)
    purpose(toks, row, max(i, 0))
    v, _ = find_after(toks, "표면이자율"); row["coupon_pct"] = fnum(v)
    v, _ = find_after(toks, "만기이자율"); row["ytm_pct"] = fnum(v)
    v, _ = find_after(toks, "5. 사채만기일"); row["maturity_date"] = date(v)
    v, _ = find_after(toks, "8. 사채발행방법"); row["issue_method"] = v
    for lab in ("교환가액 (원/주)", "전환가액 (원/주)", "행사가액 (원/주)"):
        v, _ = find_after(toks, lab)
        if v is not None:
            row["conv_price"] = num(v); break


def parse_capital_security(toks: list[str], row: dict) -> None:
    # 자본으로 인정되는 채무증권(신종자본증권): 항목 번호가 다르다
    for lab in ("2. 사채의 권면", "권면(전자등록)총액 (원)", "발행총액 (원)", "2. 발행총액"):
        v, i = find_after(toks, lab)
        if num(v) is not None:
            row["amount_krw"] = num(v); break
    purpose(toks, row, 0)
    v, _ = find_after(toks, "표면이자율"); row["coupon_pct"] = fnum(v)
    v, _ = find_after(toks, "만기일"); row["maturity_date"] = date(v)
    v, _ = find_after(toks, "발행방법"); row["issue_method"] = v


def parse_rights_issue(toks: list[str], row: dict) -> None:
    v, i = find_after(toks, "1. 신주의 종류와 수")
    v2, _ = find_after(toks, "보통주식 (주)", max(i, 0)); row["shares_new"] = num(v2)
    v, i2 = find_after(toks, "3. 증자전 발행주식총수")
    v2, _ = find_after(toks, "보통주식 (주)", max(i2, 0)); row["shares_before"] = num(v2)
    purpose(toks, row, max(i2, 0))
    v, i3 = find_after(toks, "6. 신주 발행가액")
    v2, _ = find_after(toks, "보통주식 (원)", max(i3, 0)); row["price_per_share"] = num(v2)
    v, _ = find_after(toks, "5. 증자방식"); row["issue_method"] = v
    v, _ = find_after(toks, "7-2. 기준주가에 대한 할인율"); row["discount_pct"] = fnum(v)
    parts = [row.get(k) for k in ("purpose_facility", "purpose_operating", "purpose_debt", "purpose_acquisition", "purpose_other")]
    if any(p for p in parts):
        row["amount_krw"] = sum(p for p in parts if p)
    elif row.get("shares_new") and row.get("price_per_share"):
        row["amount_krw"] = row["shares_new"] * row["price_per_share"]


def parse_bonus_issue(toks: list[str], row: dict) -> None:
    v, i = find_after(toks, "1. 신주의 종류와 수")
    v2, _ = find_after(toks, "보통주식 (주)", max(i, 0)); row["shares_new"] = num(v2)
    v, i2 = find_after(toks, "증자전 발행주식총수")
    v2, _ = find_after(toks, "보통주식 (주)", max(i2, 0)); row["shares_before"] = num(v2)
    v, _ = find_after(toks, "1주당 신주배정 주식수"); row["merger_ratio"] = fnum(v)   # 배정비율을 ratio 칸에
    row["issue_method"] = "무상증자"


def parse_reduction(toks: list[str], row: dict) -> None:
    v, i = find_after(toks, "1. 감자주식의 종류와 수")
    v2, _ = find_after(toks, "보통주식 (주)", max(i, 0)); row["shares_reduced"] = num(v2)
    v, i2 = find_after(toks, "4. 감자전후 발행주식수")
    v2, _ = find_after(toks, "보통주식(주)", max(i2, 0)); row["shares_before"] = num(v2)
    v, i3 = find_after(toks, "5. 감자비율")
    v2, _ = find_after(toks, "보통주식 (%)", max(i3, 0)); row["reduction_ratio_pct"] = fnum(v2)
    v, _ = find_after(toks, "7. 감자방법"); row["reduction_method"] = v


def parse_merger(toks: list[str], row: dict) -> None:
    v, i = find_after(toks, "4. 합병비율")
    if v is not None:
        # 값이 줄바꿈으로 쪼개져 다음 토큰에 이어질 수 있어 3개 토큰을 붙여 본다. "1.0000000 : 0.0000000" (무증자 합병) 은 0
        joined = " ".join(toks[i + 1:i + 4]).replace(" ", "")
        m = re.search(r"=?1(?:\.0+)?[:：]([\d]+(?:\.\d+)?)", joined)
        row["merger_ratio"] = float(m.group(1)) if m else None
    v, i = find_after(toks, "8. 합병상대회사")
    v2, _ = find_after(toks, "회사명", max(i, 0)); row["counterparty"] = v2
    v2, _ = find_after(toks, "자산총계", max(i, 0)); row["counterparty_assets_krw"] = num(v2)
    v2, _ = find_after(toks, "매출액", max(i, 0)); row["counterparty_revenue_krw"] = num(v2)
    v, i2 = find_after(toks, "7. 합병신주의 종류와 수")
    v2, _ = find_after(toks, "보통주식", max(i2, 0)); row["shares_new"] = num(v2)


def parse_split(toks: list[str], row: dict) -> None:
    v, _ = find_after(toks, "1. 분할방법"); row["issue_method"] = (v or "")[:200]
    v, _ = find_after(toks, "분할비율"); row["merger_ratio"] = fnum(v) if v and re.fullmatch(r"[\d.]+", v.replace(",", "")) else None
    v, i = find_after(toks, "분할신설회사")
    v2, _ = find_after(toks, "회사명", max(i, 0)); row["counterparty"] = v2


def parse_acquisition(toks: list[str], row: dict) -> None:
    for lab in ("취득금액(원)", "취득금액 (원)", "양수금액(원)", "양수금액 (원)", "양도금액(원)", "양도금액 (원)", "거래금액(원)", "취득가액(원)"):
        v, _ = find_after(toks, lab)
        if num(v) is not None:
            row["amount_krw"] = num(v); break
    for lab in ("발행회사", "회사명", "양수도 대상"):
        v, _ = find_after(toks, lab)
        if v and not v.startswith("1."):
            row["counterparty"] = v[:120]; break
    v, _ = find_after(toks, "자산총액대비"); row["reduction_ratio_pct"] = fnum(v)    # 자산총액 대비 % 를 ratio 칸에


def parse_bond_repurchase(toks: list[str], row: dict) -> None:
    # "8. 취득금액" 다음에 "금액(원)" 라벨이 한 번 더 오고 그 뒤가 값
    v, i = find_after(toks, "8. 취득금액")
    if i >= 0:
        v2, _ = find_after(toks, "금액(원)", i)
        row["amount_krw"] = num(v2)
    if row.get("amount_krw") is None:
        for lab in ("취득금액(원)", "취득금액 (원)", "6. 취득 대상 사채의 권면"):
            v, _ = find_after(toks, lab)
            if num(v) is not None:
                row["amount_krw"] = num(v); break
    v, _ = find_after(toks, "9. 취득 방법"); row["issue_method"] = v


def doc_type(report_nm: str) -> str:
    n = report_nm
    if "자본으로인정" in n: return "capital_security"
    if "자기전환사채" in n or "만기전취득" in n: return "bond_repurchase"
    if "사채" in n: return "bond"
    if "무상증자" in n: return "bonus_issue"
    if "유상증자" in n: return "rights_issue"
    if "감자" in n: return "reduction"
    if "합병" in n: return "merger"
    if "분할" in n: return "split"
    if "양수" in n or "취득" in n or "양도" in n: return "acquisition"
    return "other"


PARSERS = {"bond": parse_bond, "capital_security": parse_capital_security, "rights_issue": parse_rights_issue,
           "bonus_issue": parse_bonus_issue, "reduction": parse_reduction, "merger": parse_merger,
           "split": parse_split, "acquisition": parse_acquisition, "bond_repurchase": parse_bond_repurchase}


def main() -> None:
    names = pd.read_csv(FILINGS, dtype=str).set_index("rcept_no")["report_nm"].to_dict()
    rows = []
    for path in sorted(DOCS.glob("*.txt")):
        rcept = path.stem
        text = path.read_text(encoding="utf-8")
        row: dict = {c: None for c in COLS}
        row["rcept_no"] = rcept
        row["doc_type"] = doc_type(names.get(rcept, ""))
        if text.startswith("ERROR"):
            row["parse_note"] = text.strip()[:200]; rows.append(row); continue
        toks = tokens(text)
        row["truncated"] = 1 if "next_offset" in text else 0
        fn = PARSERS.get(row["doc_type"])
        notes = []
        if fn:
            try:
                fn(toks, row)
            except Exception as e:  # 한 건이 깨져도 나머지는 계속
                notes.append(f"exception {type(e).__name__}: {e}")
        else:
            notes.append("no parser for doc_type")
        key = {"bond": "amount_krw", "capital_security": "amount_krw", "rights_issue": "amount_krw", "bonus_issue": "shares_new",
               "reduction": "shares_reduced", "merger": "merger_ratio", "split": "issue_method", "acquisition": "amount_krw",
               "bond_repurchase": "amount_krw"}.get(row["doc_type"])
        if key and row.get(key) in (None, ""):
            notes.append(f"missing {key}")
        row["parse_note"] = "; ".join(notes) if notes else None
        rows.append(row)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLS); w.writeheader(); w.writerows(rows)
    df = pd.DataFrame(rows)
    print(f"{OUT.relative_to(ROOT)}: {len(df)} rows")
    print(df.groupby("doc_type").agg(n=("rcept_no", "size"), parsed_amount=("amount_krw", lambda s: s.notna().sum()),
                                     notes=("parse_note", lambda s: s.notna().sum())).to_string())


if __name__ == "__main__":
    main()
