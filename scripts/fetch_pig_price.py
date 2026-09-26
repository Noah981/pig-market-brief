"""Collect the exact KAPE Dabom producer pig-price headline."""

import json
import re
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/data/pig-price.json"
HIST = ROOT / "docs/data/pig-price-history.json"
KST = timezone(timedelta(hours=9))
URL = "https://www.ekapepia.com/v3/web/main.do?userGroup=common"


def fetch_html() -> str:
    request = urllib.request.Request(URL, headers={
        "User-Agent": "Mozilla/5.0 (compatible; dondonhae-price-watch/1.0)",
        "Accept-Language": "ko-KR,ko;q=0.9",
    })
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"Dabom HTTP {response.status}")
        return response.read().decode("utf-8")


def parse_headline(html: str) -> tuple[str, int]:
    # Lock onto the exact official card so no raw pigGrade-derived value can
    # be substituted for the Dabom headline.
    card = re.search(
        r'<div class="main-menu-wrap">(?:(?!<div class="main-menu-wrap">).)*?'
        r'<h3>.*?alt="돼지".*?</h3>.*?경락가격.*?'
        r'<a[^>]+data-card="auctPig"[^>]*>\s*'
        r'<b>전국\(등외,\s*제주 제외\)</b>.*?'
        r'<em[^>]*>\s*([0-9,]+)\s*</em>.*?'
        r'<div class="main-menu-bottom">\s*<div><b>'
        r'(\d{2})년\s*(\d{2})월\s*(\d{2})일</b>',
        html,
        re.S,
    )
    if not card:
        raise RuntimeError("Dabom official pig headline not found")
    price = int(card.group(1).replace(",", ""))
    date = f"20{card.group(2)}{card.group(3)}{card.group(4)}"
    if price < 1000 or price > 20000:
        raise RuntimeError("Dabom official pig headline out of range")
    return date, price


def load_history() -> dict:
    try:
        data = json.loads(HIST.read_text(encoding="utf-8"))
        return {row["date"]: row for row in data.get("rows", [])}
    except Exception:
        return {}


def main() -> None:
    date, price = parse_headline(fetch_html())
    rows = load_history()
    rows[date] = {"date": date, "price": price, "sourceType": "dabom-headline"}
    ordered = sorted(rows.values(), key=lambda row: row["date"])
    previous_rows = [row for row in ordered if row["date"] < date and row.get("price")]
    if not previous_rows:
        raise RuntimeError("Previous verified price missing; keeping existing cache")
    previous = previous_rows[-1]
    change = price - int(previous["price"])
    change_pct = round(change / int(previous["price"]) * 100, 2)
    now = datetime.now(KST).isoformat()

    payload = {
        "source": "축산물품질평가원",
        "sourceUrl": URL,
        "operation": "dabom/producer-pig-auction-price",
        "label": "생산자 돼지 경락가격",
        "scope": "전국·탕박·등외제외·제주제외",
        "formula": "축산유통정보 다봄 공표 대표값(재계산 없음)",
        "date": date,
        "price": price,
        "previousDate": previous["date"],
        "previousPrice": int(previous["price"]),
        "change": change,
        "changePct": change_pct,
        "count": None,
        "unit": "원/kg",
        "updatedAt": now,
        "status": "ok",
        "displayStatus": "축산유통정보 다봄 공표값",
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    HIST.write_text(json.dumps({
        "source": "축산물품질평가원 축산유통정보 다봄",
        "scope": "전국·탕박·등외제외·제주제외",
        "formulaVersion": "dabom-headline-v1-no-recalculation",
        "rows": ordered,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[DONPRICE] dataDate={date} price={price} source=dabom-headline")


if __name__ == "__main__":
    main()
