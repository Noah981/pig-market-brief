"""GitHub Actions connectivity gate. Never prints credentials or response URLs."""
import json
import os
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))

def get(name, url, *, json_response=False, xml_response=False):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "dondonhae-ci/1.0"}), timeout=20) as response:
            raw = response.read()
            if response.status != 200:
                raise RuntimeError(f"HTTP {response.status}")
        if json_response:
            return json.loads(raw.decode("utf-8"))
        if xml_response:
            return ET.fromstring(raw)
        return raw
    except Exception as exc:
        raise RuntimeError(f"{name} connectivity/parse failed: {type(exc).__name__}") from None

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

    day = now.strftime("%Y%m%d")
    kape_query = urllib.parse.urlencode({"serviceKey": key("KAPE_API_KEY"), "startYmd": day, "endYmd": day, "skinYn": "Y", "sexCd": "025001", "egradeExceptYn": "Y"})
    kape = get("KAPE", "http://data.ekape.or.kr/openapi-data/service/user/grade/auct/pigGrade?" + kape_query, xml_response=True)
    code = (kape.findtext(".//resultCode") or "00").strip()
    if code != "00":
        raise RuntimeError("KAPE authentication/service error")
    print("KAPE: authenticated XML response OK")

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

if __name__ == "__main__":
    main()
