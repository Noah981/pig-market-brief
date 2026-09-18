import os, json, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/data/pig-price.json"
DETAIL=ROOT/"docs/data/pig-grade-detail.json"
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

def grade_detail(key,day):
    params={"startYmd":day,"endYmd":day,"skinYn":"Y","egradeExceptYn":"Y"}
    q=urllib.parse.urlencode(params);encoded=urllib.parse.quote(urllib.parse.unquote(key),safe="")
    with urllib.request.urlopen(BASE+"?serviceKey="+encoded+"&"+q,timeout=15) as r: root=ET.fromstring(r.read())
    # KAPE 응답 태그를 등급별로 분류. 숫자가 실제 응답에 존재할 때만 표시한다.
    groups={"1+":[],"1":[],"2":[],"등외":[]}
    for x in root.findall(".//item"):
        for ch in list(x):
            tag=ch.tag.lower(); t=(ch.text or "").replace(",","").strip()
            try: val=float(t)
            except: continue
            if val<=0 or not ("amt" in tag or "price" in tag): continue
            if "1p" in tag or "1plus" in tag or "1+" in tag: groups["1+"].append(val)
            elif re.search(r"(^|_)1(g|grade|amt|price)",tag): groups["1"].append(val)
            elif re.search(r"(^|_)2(g|grade|amt|price)",tag): groups["2"].append(val)
            elif "egrade" in tag or "out" in tag: groups["등외"].append(val)
    prices={g:round(sum(v)/len(v)) for g,v in groups.items() if v}
    now=datetime.now(KST)
    latest_day=datetime.strptime(day,"%Y%m%d").date()
    today=now.date()
    if latest_day==today:
        state="당일 경락가격 반영"
    elif now.hour<18:
        state="금일 경락 진행 중 · 최근 확정 "+latest_day.strftime("%m/%d")
    else:
        state="오늘 확정가격 대기 · 최근 확정 "+latest_day.strftime("%m/%d")
    return {"date":day,"source":"축산물품질평가원","status":state,"prices":prices,"updatedAt":now.isoformat()}

def main():
    key=os.environ["KAPE_SERVICE_KEY"]; now=datetime.now(KST)
    # API 요청 제한을 피하기 위해 기존 이력을 재사용하고 최근 10일만 갱신한다.
    cached_rows=[]
    if HIST.exists():
        try: cached_rows=json.loads(HIST.read_text(encoding="utf-8")).get("rows",[])
        except Exception: pass
    merged0={r["date"]:r for r in cached_rows}
    for ago in range(9,-1,-1):
        day=(now-timedelta(days=ago)).strftime("%Y%m%d")
        try:
            price,count=day_price(key,day)
            if price: merged0[day]={"date":day,"price":price,"count":count}
        except Exception as e:
            print("KAPE recent fetch skipped",day,e)
    rows=sorted(merged0.values(),key=lambda r:r["date"])
    if not rows:
        # 최초 설치 시에만 최근 45일을 순차 조회
        for ago in range(44,-1,-1):
            day=(now-timedelta(days=ago)).strftime("%Y%m%d")
            try:
                price,count=day_price(key,day)
                if price: rows.append({"date":day,"price":price,"count":count})
            except Exception: break
    if not rows: raise RuntimeError("No KAPE pigGrade national rows")
    latest=rows[-1]; prev=rows[-2] if len(rows)>1 else latest
    diff=latest["price"]-prev["price"]; pct=round(diff/prev["price"]*100,2) if prev["price"] else 0
    month=latest["date"][:6]; prev_month=(now.replace(day=1)-timedelta(days=1)).strftime("%Y%m"); last_year=str(int(month[:4])-1)+month[4:6]
    def avg(prefix):
        a=[r["price"] for r in rows if r["date"].startswith(prefix)]
        return round(sum(a)/len(a)) if a else 0
    month_avg=avg(month); prev_month_avg=avg(prev_month); last_year_avg=avg(last_year)
    payload={"source":"축산물품질평가원","operation":"auct/pigGrade","label":"축산유통정보 공지 돈가","scope":"전국·탕박·등외제외·제주제외","date":latest["date"],"price":latest["price"],"previousDate":prev["date"],"previousPrice":prev["price"],"change":diff,"changePct":pct,"monthAverage":month_avg,"previousMonthAverage":prev_month_avg,"previousMonthChange":month_avg-prev_month_avg if prev_month_avg else 0,"lastYearMonthAverage":last_year_avg,"lastYearChange":month_avg-last_year_avg if last_year_avg else 0,"count":latest["count"],"unit":"원/kg","updatedAt":now.isoformat(),"status":"ok"}
    OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
    DETAIL.write_text(json.dumps(grade_detail(key,latest["date"]),ensure_ascii=False,indent=2),encoding="utf-8")
    old=[]
    if HIST.exists():
        try:
            cached=json.loads(HIST.read_text(encoding="utf-8"))
            old=cached.get("rows",[]) if cached.get("scope")==payload["scope"] else []
        except Exception: pass
    merged={r["date"]:r for r in old}
    for r in rows: merged[r["date"]]=r
    HIST.write_text(json.dumps({"source":"축산물품질평가원","scope":"탕박·등외제외·제주제외·암+거세 두수가중","rows":sorted(merged.values(),key=lambda r:r["date"])},ensure_ascii=False,indent=2),encoding="utf-8")

if __name__=="__main__": main()
