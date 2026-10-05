"""Fetch official FRED observations, with public downloads as a fallback.

The app uses benchmark/spot series, not executable futures quotes. Each row keeps
its original frequency, observation date, source and URL so stale monthly data is
never presented as today's price.
"""
import time
import csv
import io
import json
import math
import re
import subprocess
import os
import urllib.parse
from html import unescape
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone, timedelta, date
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
        try:value = float(text)
        except ValueError:continue
        try:observed=date.fromisoformat(row["observation_date"])
        except (ValueError,KeyError):continue
        if observed>datetime.now(KST).date():continue
        if not math.isfinite(value) or value <= 0:
            continue
        rows.append({"date": row["observation_date"], "value": value})
    rows=sorted({r["date"]:r for r in rows}.values(),key=lambda r:r["date"])
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
        "history": rows[-(36 if spec["frequency"]=="monthly" else 366):],
        "updatedAt": datetime.now(KST).isoformat(),"status":"LIVE",
    }


def parse_table(name, spec, raw):
    """Read FRED's own data table, including its deferred observation rows."""
    text=raw.decode('utf-8-sig')
    if not re.search(r'Series ID\s*</th>\s*<td[^>]*>\s*'+re.escape(spec['id'])+r'\s*</td>',text,re.I):
        raise ValueError('FRED table series mismatch')
    observations=[]
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>',text,re.S|re.I):
        cells=[unescape(re.sub(r'<[^>]+>','',x)).strip() for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S|re.I)]
        if len(cells)==2 and re.fullmatch(r'\d{4}-\d{2}-\d{2}',cells[0]):observations.append(cells)
    observations.extend(re.findall(r'#(\d{4}-\d{2}-\d{2})\|\s*([^\s<]+)',text))
    buffer=io.StringIO();writer=csv.writer(buffer)
    writer.writerow(['observation_date',spec['id']]);writer.writerows(observations)
    return parse_series(name,spec,buffer.getvalue().encode('utf-8'))


def fetch_one(name, spec):
    key=os.getenv('FRED_API_KEY','').strip()
    if key:
        try:
            query=urllib.parse.urlencode({'api_key':key,'series_id':spec['id'],'file_type':'json','sort_order':'desc','limit':'1000'})
            request=urllib.request.Request('https://api.stlouisfed.org/fred/series/observations?'+query,headers={'User-Agent':'Dondonhae/1.8'})
            with urllib.request.urlopen(request,timeout=20) as response:payload=response.read(2_000_001)
            if len(payload)>2_000_000:raise ValueError('payload too large')
            document=json.loads(payload)
            if not isinstance(document,dict):raise ValueError('Invalid official API response')
            observations=document.get('observations',[])
            if not isinstance(observations,list):raise ValueError('Invalid official API observations')
            buffer=io.StringIO();writer=csv.writer(buffer)
            writer.writerow(['observation_date',spec['id']])
            writer.writerows([r.get('date',''),r.get('value','')] for r in observations if isinstance(r,dict))
            return parse_series(name,spec,buffer.getvalue().encode('utf-8'))
        except (OSError,TimeoutError,ValueError,TypeError):
            # Do not log a request URL: it contains the credential.
            pass
    # An alternate official endpoint avoids treating one CSV timeout as a
    # complete provider outage. Never substitute another series or sample value.
    endpoints=[(_url(spec['id']),parse_series),(f"https://fred.stlouisfed.org/data/{spec['id']}",parse_table)]
    last_error=None
    for attempt in range(2):
        for url,parser in endpoints:
            try:
                if attempt==0:
                    req=urllib.request.Request(url,headers={'User-Agent':'Dondonhae/1.8'})
                    with urllib.request.urlopen(req,timeout=20) as response:raw=response.read(2_000_001)
                else:
                    # curl negotiates a different HTTP transport on CI runners.
                    # TLS verification stays enabled; both endpoints are FRED.
                    result=subprocess.run(['curl','--http1.1','--fail','--location','--compressed','--silent','--show-error','--max-time','20','--max-filesize','2000000','--user-agent','Dondonhae/1.8',url],capture_output=True,timeout=25)
                    if result.returncode:raise OSError(f'Official FRED transport exit {result.returncode}')
                    raw=result.stdout
                if len(raw)>2_000_000:raise ValueError('payload too large')
                return parser(name,spec,raw)
            except (OSError,TimeoutError,ValueError,subprocess.TimeoutExpired) as exc:last_error=exc
        if attempt==0:time.sleep(1)
    raise last_error


def update(previous, fetched):
    old = {row.get("name"): row for row in previous.get("markets", []) if row.get("name")}
    for row in old.values():row["status"]="STALE"
    for row in fetched:
        previous_row=old.get(row["name"])
        if previous_row and previous_row.get("source")==row.get("source") and previous_row.get("date","")>row.get("date",""):continue
        old[row["name"]]=row
    result = dict(previous)
    result["markets"] = [old[name] for name in SERIES if name in old]
    result["checkedAt"] = datetime.now(KST).isoformat()
    result["sourceStatus"] = [x for x in previous.get("sourceStatus",[]) if x.get("id") not in ("fred-public-series", "official-market-upstreams", "official-market")] + [
        {"id": "official-market-upstreams", "agency": "한국은행·세계은행·EIA 공식 시황", "status":
         "연결 완료" if len(fetched) == len(SERIES) else f"일부 연결 · {len(fetched)}/{len(SERIES)}"}
    ]
    return result


def main():
    previous = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {"markets": [], "benefits": []}
    import sys
    sys.path.insert(0, str(ROOT))
    from scripts.direct_market_sources import fetch_all
    fetched = fetch_all()
    if not fetched and not previous.get("markets"):
        raise RuntimeError("No market data and no last-known-good cache")
    result = update(previous, fetched)
    temp = OUT.with_suffix(".tmp")
    temp.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(OUT)
    print(f"market series updated: {len(fetched)}/{len(SERIES)}")


if __name__ == "__main__":
    main()
