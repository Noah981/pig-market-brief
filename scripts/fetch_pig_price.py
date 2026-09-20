"""Collect the official KAPE Dabom producer pig auction price.

The headline must match the public Dabom producer card and the detailed table:
탕박 -> 등외제외 -> 전국(제주 제외). We do not reconstruct the headline from
grade/sex averages because that can differ from the official published value.
"""
import json
import re
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/data/pig-price.json"
HIST = ROOT / "docs/data/pig-price-history.json"
DETAIL = ROOT / "docs/data/pig-grade-detail.json"
KST = timezone(timedelta(hours=9))
DETAIL_URL = "https://www.ekapepia.com/v3/price/auction/period/pig/auctionPrice.do"
PRODUCER_URL = "https://www.ekapepia.com/v3/web/main.do?userGroup=producer"


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__(); self.rows = []; self._row = None; self._cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr": self._row = []
        elif tag in ("th", "td") and self._row is not None: self._cell = []

    def handle_data(self, data):
        if self._cell is not None: self._cell.append(data)

    def handle_endtag(self, tag):
        if tag in ("th", "td") and self._cell is not None and self._row is not None:
            self._row.append(" ".join("".join(self._cell).split())); self._cell = None
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row); self._row = None


def fetch(url, params=None):
    if params: url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": "DonDonHae/2.0 official-price-check"})
    with urllib.request.urlopen(request, timeout=25) as response:
        return response.read().decode("utf-8", "replace")


def parse_excluding_outgrade_price(html):
    parser = TableParser(); parser.feed(html)
    for row in parser.rows:
        if row and "등외제외" in row[0]:
            for cell in row[1:]:
                match = re.search(r"(?<!\d)([1-9]\d{0,2}(?:,\d{3})+)(?!\d)", cell)
                if match: return int(match.group(1).replace(",", ""))
    return None


def official_period_price(start, end=None):
    start_dash = datetime.strptime(start, "%Y%m%d").strftime("%Y-%m-%d")
    end_dash = datetime.strptime(end or start, "%Y%m%d").strftime("%Y-%m-%d")
    html = fetch(DETAIL_URL, {
        "searchStartDate": start_dash, "searchEndDate": end_dash,
        "searchCondition": "2", "searchCondition1": "", "searchCondition2": "1",
    })
    return parse_excluding_outgrade_price(html)


def parse_producer_headline(html):
    block = re.search(r'data-card="allPig"[\s\S]*?</a>', html)
    if not block: raise ValueError("Dabom producer allPig card not found")
    price_match = re.search(r"<em[^>]*>\s*([\d,]+)\s*</em>", block.group(0))
    tail = html[block.end():block.end() + 5000]
    date_match = re.search(r"(\d{2})년\s*(\d{2})월\s*(\d{2})일", tail)
    if not price_match or not date_match: raise ValueError("Dabom producer headline price/date not found")
    return {"price": int(price_match.group(1).replace(",", "")), "date": "20" + "".join(date_match.groups())}


def load_history():
    try:
        root = json.loads(HIST.read_text(encoding="utf-8"))
        return [r for r in root.get("rows", []) if re.fullmatch(r"\d{8}", str(r.get("date", ""))) and int(r.get("price", 0)) > 0]
    except Exception: return []


def atomic_write(path, payload):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"); tmp.replace(path)


def month_bounds(day):
    start = day.replace(day=1); next_month = (start + timedelta(days=32)).replace(day=1)
    return start.strftime("%Y%m%d"), (next_month - timedelta(days=1)).strftime("%Y%m%d")


def collect_periods(tasks, label):
    results = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(official_period_price, start, end): key for key, start, end in tasks}
        for future in as_completed(futures):
            key = futures[future]
            try:
                value = future.result()
                if value: results[key] = value
            except Exception as error: print(f"KAPE {label} check skipped", key, str(error)[:160])
    return results


def main():
    now = datetime.now(KST)
    # The producer headline is the publication gate. A detailed table can
    # contain partial weekend/intraday trades before the representative value
    # is officially rolled forward, so dates after this gate are ignored.
    headline = parse_producer_headline(fetch(PRODUCER_URL))
    published_day = datetime.strptime(headline["date"], "%Y%m%d").replace(tzinfo=KST)
    existing = load_history()
    merged = {f'{r["date"]}|{r.get("resolution", "day")}': r for r in existing if r["date"] <= headline["date"]}
    daily_existing = {r["date"] for r in merged.values() if r.get("resolution", "day") == "day" and r.get("verified") is True}

    # Holidays return no value and are never written as zero.
    recent_span = 35
    daily_tasks = []
    for ago in range(recent_span - 1, -1, -1):
        candidate = published_day - timedelta(days=ago)
        if candidate.weekday() >= 5: continue
        day = candidate.strftime("%Y%m%d")
        if day in daily_existing and ago > 2: continue
        daily_tasks.append((day, day, day))
    for day, value in collect_periods(daily_tasks, "daily").items():
        merged[day + "|day"] = {"date": day, "price": value, "resolution": "day", "verified": True}

    # Store official range aggregates for the 3-year graph.
    cursor = (now.replace(day=1) - timedelta(days=31 * 35)).replace(day=1)
    month_tasks = []
    while cursor <= now.replace(day=1):
        key = cursor.strftime("%Y%m"); stored = merged.get(key + "01|month")
        if stored is None or stored.get("verified") is not True or (cursor.year, cursor.month) == (now.year, now.month):
            start, end = month_bounds(cursor)
            if (cursor.year, cursor.month) == (published_day.year, published_day.month): end = headline["date"]
            month_tasks.append((key, start, end))
        cursor = (cursor + timedelta(days=32)).replace(day=1)
    for key, value in collect_periods(month_tasks, "month").items():
        merged[key + "01|month"] = {"date": key + "01", "price": value, "resolution": "month", "verified": True}

    daily = sorted((r for r in merged.values() if r.get("resolution", "day") == "day" and r.get("verified") is True), key=lambda r: r["date"])
    if len(daily) < 2: raise RuntimeError("At least two official KAPE trading days are required")
    latest, previous = daily[-1], daily[-2]

    # Do not publish unless official producer headline and detail agree.
    if headline["date"] != latest["date"] or headline["price"] != latest["price"]:
        raise RuntimeError(f"KAPE screen mismatch: headline={headline}, detail={latest}")

    change = latest["price"] - previous["price"]; change_pct = round(change / previous["price"] * 100, 2)
    latest_date = datetime.strptime(latest["date"], "%Y%m%d")
    month_average = official_period_price(latest_date.replace(day=1).strftime("%Y%m%d"), latest["date"])
    year_average = official_period_price(latest_date.replace(month=1, day=1).strftime("%Y%m%d"), latest["date"])
    payload = {
        "source": "축산물품질평가원", "sourceUrl": DETAIL_URL,
        "operation": "dabom/producer-pig-auction-price", "label": "생산자 돼지 경락가격",
        "scope": "전국·탕박·등외제외·제주제외", "formula": "전체거래대금/전체거래중량",
        "filters": {"skin": "탕박", "grade": "등외제외", "region": "전국(제주 제외)"},
        "date": latest["date"], "price": latest["price"], "previousDate": previous["date"],
        "previousPrice": previous["price"], "change": change, "changePct": change_pct,
        "monthAverage": month_average, "yearAverage": year_average, "unit": "원/kg",
        "updatedAt": now.isoformat(), "status": "ok", "displayStatus": "축산유통정보 다봄 공표값",
        "verifiedAgainstOfficialScreen": True,
    }
    coverage = sorted(merged.values(), key=lambda r: (r["date"], r.get("resolution", "day")))
    history = {"source": payload["source"], "sourceUrl": DETAIL_URL, "scope": payload["scope"],
        "formulaVersion": "kape-dabom-published-v2",
        "coverage": {"from": coverage[0]["date"], "to": latest["date"], "minimumMonths": 36}, "rows": coverage}
    atomic_write(OUT, payload); atomic_write(HIST, history)
    atomic_write(DETAIL, {"source": payload["source"], "date": latest["date"], "status": "공식 대표값 검증 완료", "prices": {}, "updatedAt": now.isoformat()})


if __name__ == "__main__": main()
