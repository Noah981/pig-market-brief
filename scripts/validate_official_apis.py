"""GitHub Actions connectivity gate. Never prints credentials or response URLs."""
import json
import os
import urllib.parse
import urllib.request
import time
import re
from html import unescape
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))

def get(name, url, *, json_response=False):
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "dondonhae-ci/1.0"}), timeout=20) as response:
                raw = response.read()
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status}")
            if json_response:
                return json.loads(raw.decode("utf-8"))
            return raw
        except Exception as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"{name} connectivity/parse failed after retries: {type(last_error).__name__}") from None

def key(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} missing")
    return value

def main():
    now = datetime.now(KST)
    start = (now - timedelta(days=45)).strftime("%Y%m%d")
    end = now.strftime("%Y%m%d")
    ecos = get("ECOS", f"https://ecos.bok.or.kr/api/StatisticSearch/{urllib.parse.quote(key('ECOS_API_KEY'), safe='')}/json/kr/1/5/731Y001/D/{start}/{end}/0000001", json_response=True)
    if not ((ecos.get("StatisticSearch") or {}).get("row")):
        raise RuntimeError("ECOS empty/service error")
    print("ECOS: authenticated response and required rows OK")

    kape_rows = None
    for ago in range(14):
        day = (now - timedelta(days=ago)).strftime("%Y-%m-%d")
        query = urllib.parse.urlencode({"searchStartDate":day,"searchEndDate":day,"searchCondition":"057016","searchCondition1":"Y","searchCondition2":""})
        raw = get("KAPE_DABOM", "https://www.ekapepia.com/v3/price/auction/period/pig/detail.do?" + query)
        html = raw.decode("utf-8", errors="replace")
        match = re.search(r'<table[^>]*id=["\']table-type1["\'][^>]*>(.*?)</table>', html, re.I | re.S)
        if not match:
            continue
        rows = []
        for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', match.group(1), re.I | re.S):
            cells = [re.sub(r'<[^>]+>', '', unescape(x)).strip().replace(',', '') for x in re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', tr, re.I | re.S)]
            if len(cells)>1 and cells[0] == "등급": cells.pop(0)
            if cells: rows.append(cells)
        grades = {r[0]:r for r in rows if r and r[0] in ("1+","1","2","등외")}
        summary = next((r for r in rows if r and r[0] == "평균"), None)
        def number(value):
            try: return float(value)
            except (TypeError, ValueError): return 0
        valid_grades = all(number(row[1]) > 0 and number(row[2]) > 0 for row in grades.values())
        if len(grades)==4 and valid_grades and summary and number(summary[1])>0 and number(summary[3])>0:
            kape_rows = (grades,summary); break
    if not kape_rows: raise RuntimeError("KAPE Dabom nationwide-ex-Jeju rows missing")
    print(f"KAPE_DABOM: nationwide-ex-Jeju grade/status rows OK dataDate={day}")

    # Fixed official KMA grid/time only verifies auth and response schema; app requests its actual GPS grid.
    candidate = now - timedelta(minutes=15)
    slots = [2, 5, 8, 11, 14, 17, 20, 23]
    hours = [h for h in slots if h <= candidate.hour]
    if not hours:
        candidate -= timedelta(days=1); hour = 23
    else:
        hour = hours[-1]
    kma_query = urllib.parse.urlencode({"serviceKey": key("KMA_API_KEY"), "pageNo": 1, "numOfRows": 10, "dataType": "JSON", "base_date": candidate.strftime("%Y%m%d"), "base_time": f"{hour:02d}00", "nx": 89, "ny": 90})
    kma = get("KMA", "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst?" + kma_query, json_response=True)
    if str(((kma.get("response") or {}).get("header") or {}).get("resultCode")) != "00":
        raise RuntimeError("KMA authentication/service error")
    print("KMA: authenticated JSON response and schema OK")

    mafra = get("MAFRA", f"http://211.237.50.150:7080/openapi/{urllib.parse.quote(key('MAFRA_API_KEY'), safe='')}/json/Grid_20151204000000000316_1/1/5", json_response=True)
    if "Grid_20151204000000000316_1" not in mafra:
        raise RuntimeError("MAFRA authentication/schema error")
    print("MAFRA: authenticated JSON response and schema OK")

    fred = get("FRED", "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DCOILWTICO")
    if b"observation_date" not in fred or len(fred.splitlines()) < 3:
        raise RuntimeError("FRED official series empty/schema error")
    print("FRED: official market series response OK")

if __name__ == "__main__":
    main()
