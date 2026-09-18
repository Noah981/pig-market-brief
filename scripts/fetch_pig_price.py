import os, json, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/data/pig-price.json"
HIST=ROOT/"docs/data/pig-price-history.json"
KST=timezone(timedelta(hours=9))
BASE="http://data.ekape.or.kr/openapi-data/service/user/grade/auct/pigGrade"

def request(key, day, sex):
    params={"startYmd":day,"endYmd":day,"skinYn":"Y","sexCd":sex,"egradeExceptYn":"N"}
    q=urllib.parse.urlencode(params)
    encoded=urllib.parse.quote(urllib.parse.unquote(key),safe="")
    with urllib.request.urlopen(BASE+"?serviceKey="+encoded+"&"+q,timeout=15) as r:
        root=ET.fromstring(r.read())
    code=(root.findtext(".//resultCode") or "").strip()
    if code and code!="00":
        raise RuntimeError("KAPE "+code+" "+(root.findtext(".//resultMsg") or ""))
    total_value=0.0; total_count=0
    for x in root.findall(".//item"):
        amt=(x.findtext("c_1101eTotAmt") or "").replace(",","").strip()
        cnt=(x.findtext("c_1101eTotCnt") or "").replace(",","").strip()
        if amt and cnt:
            a=float(amt); n=int(float(cnt))
            if a>0 and n>0:
                total_value += a*n; total_count += n
    return total_value,total_count

def day_price(key, day):
    # 전국 돼지 경락가격: 탕박, 등외 제외, 제주 제외. 암+거세를 두수 가중평균.
    value=count=0
    for sex in ("025001","025003"):
        v,n=request(key,day,sex); value+=v; count+=n
    return (round(value/count) if count else None),count

def main():
    key=os.environ["KAPE_SERVICE_KEY"]; now=datetime.now(KST)
    rows=[]
    for ago in range(44,-1,-1):
        day=(now-timedelta(days=ago)).strftime("%Y%m%d")
        price,count=day_price(key,day)
        if price:
            rows.append({"date":day,"price":price,"count":count})
    if not rows: raise RuntimeError("No KAPE pigGrade national rows")
    latest=rows[-1]; prev=rows[-2] if len(rows)>1 else latest
    diff=latest["price"]-prev["price"]; pct=round(diff/prev["price"]*100,2) if prev["price"] else 0
    payload={"source":"축산물품질평가원","operation":"auct/pigGrade","label":"전국 돈가","scope":"탕박·등외제외·제주제외·암+거세 두수가중","date":latest["date"],"price":latest["price"],"previousDate":prev["date"],"previousPrice":prev["price"],"change":diff,"changePct":pct,"count":latest["count"],"unit":"원/kg","updatedAt":now.isoformat(),"status":"ok"}
    OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
    old=[]
    if HIST.exists():
        try:\n            cached=json.loads(HIST.read_text(encoding="utf-8"))\n            old=cached.get("rows",[]) if cached.get("scope")==payload["scope"] else []
        except Exception: pass
    merged={r["date"]:r for r in old}
    for r in rows: merged[r["date"]]=r
    HIST.write_text(json.dumps({"source":"축산물품질평가원","scope":payload["scope"],"rows":sorted(merged.values(),key=lambda r:r["date"])},ensure_ascii=False,indent=2),encoding="utf-8")

if __name__=="__main__": main()
