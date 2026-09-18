import os, json, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/data/pig-price.json"
HIST = ROOT / "docs/data/pig-price-history.json"
KST = timezone(timedelta(hours=9))
BASE = "http://data.ekape.or.kr/openapi-data/service/user/grade/auct/pigRepresentativePrice"

def main():
    key = os.environ["KAPE_SERVICE_KEY"]
    now = datetime.now(KST)
    end = now.strftime("%Y%m%d")
    start = (now - timedelta(days=40)).strftime("%Y%m%d")
    q = urllib.parse.urlencode({"startYmd": start, "endYmd": end, "numOfRows": 100, "pageNo": 1})
    encoded_key = urllib.parse.quote(urllib.parse.unquote(key), safe="")
    url = BASE + "?serviceKey=" + encoded_key + "&" + q
    with urllib.request.urlopen(url, timeout=15) as response:
        root = ET.fromstring(response.read())
    code = (root.findtext(".//resultCode") or "").strip()
    msg = (root.findtext(".//resultMsg") or "").strip()
    if code and code != "00":
        raise RuntimeError("KAPE " + code + " " + msg)

    rows = []
    for x in root.findall(".//item"):
        typ = (x.findtext("sableGubn") or "").strip()
        price = int((x.findtext("costAmt") or "0").replace(",", ""))
        date = (x.findtext("sumYmd") or "").strip()
        if typ in ("전체", "대표가격") and price > 0:
            rows.append({"date": date, "price": price})
    rows.sort(key=lambda r: r["date"])
    if not rows:
        raise RuntimeError("No representative pig price rows")

    latest = rows[-1]
    prev = rows[-2] if len(rows) > 1 else latest
    diff = latest["price"] - prev["price"]
    pct = round(diff / prev["price"] * 100, 2) if prev["price"] else 0
    payload = {
        "source": "축산물품질평가원",
        "operation": "auct/pigRepresentativePrice",
        "label": "전국 돈가",
        "date": latest["date"],
        "price": latest["price"],
        "previousDate": prev["date"],
        "previousPrice": prev["price"],
        "change": diff,
        "changePct": pct,
        "unit": "원/kg",
        "updatedAt": now.isoformat(),
        "status": "ok"
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    old = []
    if HIST.exists():
        try:
            old = json.loads(HIST.read_text(encoding="utf-8")).get("rows", [])
        except Exception:
            pass
    merged = {r["date"]: r for r in old}
    for r in rows:
        merged[r["date"]] = r
    HIST.write_text(json.dumps({"source": "축산물품질평가원", "rows": sorted(merged.values(), key=lambda r: r["date"])}, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
