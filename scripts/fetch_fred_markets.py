"""Fetch verified public market series from FRED without API keys.

The app uses benchmark/spot series, not executable futures quotes. Each row keeps
its original frequency, observation date, source and URL so stale monthly data is
never presented as today's price.
"""
import csv
import io
import json
import math
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/data/platform.json"
KST = timezone(timedelta(hours=9))

SERIES = {
    "usd_krw": {
        "id": "DEXKOUS", "unit": "원/USD", "frequency": "daily",
        "source": "미국 연방준비제도 이사회·FRED",
        "basis": "뉴욕 정오 원/달러 현물환율",
    },
    "wti": {
        "id": "DCOILWTICO", "unit": "$/bbl", "frequency": "daily",
        "source": "미국 에너지정보청(EIA)·FRED",
        "basis": "WTI Cushing 현물가격",
    },
    "corn": {
        "id": "PMAIZMTUSDM", "unit": "$/톤", "frequency": "monthly",
        "source": "국제통화기금(IMF)·FRED",
        "basis": "세계 옥수수 벤치마크 월평균",
    },
    "soybean_meal": {
        "id": "PSMEAUSDM", "unit": "$/톤", "frequency": "monthly",
        "source": "국제통화기금(IMF)·FRED",
        "basis": "세계 대두박 벤치마크 월평균",
    },
    "soybean": {
        "id": "PSOYBUSDM", "unit": "$/톤", "frequency": "monthly",
        "source": "국제통화기금(IMF)·FRED",
        "basis": "세계 대두 벤치마크 월평균",
    },
    "wheat": {
        "id": "PWHEAMTUSDM", "unit": "$/톤", "frequency": "monthly",
        "source": "국제통화기금(IMF)·FRED",
        "basis": "세계 소맥 벤치마크 월평균",
    },
}


def _url(series_id):
    return f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"


def parse_series(name, spec, raw):
    rows = []
    for row in csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))):
        text = row.get(spec["id"], "").strip()
        if not text or text == ".":
            continue
        value = float(text)
        if not math.isfinite(value) or value <= 0:
            continue
        rows.append({"date": row["observation_date"], "value": value})
    if len(rows) < 2:
        raise ValueError(f"{name}: fewer than two valid observations")
    latest, previous = rows[-1], rows[-2]
    change_pct = (latest["value"] - previous["value"]) / previous["value"] * 100
    return {
        "name": name,
        "value": latest["value"],
        "previousValue": previous["value"],
        "changePct": round(change_pct, 2),
        "unit": spec["unit"],
        "date": latest["date"],
        "previousDate": previous["date"],
        "frequency": spec["frequency"],
        "basis": spec["basis"],
        "source": spec["source"],
        "url": f"https://fred.stlouisfed.org/series/{spec['id']}",
        "history": rows[-12:],
        "updatedAt": datetime.now(KST).isoformat(),
    }


def fetch_one(name, spec):
    req = urllib.request.Request(_url(spec["id"]), headers={"User-Agent": "Dondonhae/1.1"})
    with urllib.request.urlopen(req, timeout=25) as response:
        raw = response.read(2_000_001)
    if len(raw) > 2_000_000:
        raise ValueError("payload too large")
    return parse_series(name, spec, raw)


def update(previous, fetched):
    old = {row.get("name"): row for row in previous.get("markets", []) if row.get("name")}
    old.update({row["name"]: row for row in fetched})
    result = dict(previous)
    result["markets"] = [old[name] for name in SERIES if name in old]
    result["checkedAt"] = datetime.now(KST).isoformat()
    result["sourceStatus"] = [
        {"id": "fred-public-series", "agency": "FRED 공개 시계열", "status":
         "연결 완료" if len(fetched) == len(SERIES) else f"일부 연결 · {len(fetched)}/{len(SERIES)}"}
    ]
    return result


def main():
    previous = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {"markets": [], "benefits": []}
    fetched = []
    with ThreadPoolExecutor(max_workers=len(SERIES)) as pool:
        futures = {pool.submit(fetch_one, name, spec): name for name, spec in SERIES.items()}
        for future in as_completed(futures):
            try:
                fetched.append(future.result())
            except Exception as exc:
                print(f"{futures[future]} fetch failed: {exc}")
    if not fetched and not previous.get("markets"):
        raise RuntimeError("No market data and no last-known-good cache")
    result = update(previous, fetched)
    temp = OUT.with_suffix(".tmp")
    temp.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(OUT)
    print(f"market series updated: {len(fetched)}/{len(SERIES)}")


if __name__ == "__main__":
    main()
