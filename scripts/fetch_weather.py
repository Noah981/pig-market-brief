import json, os, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/data/weather.json"
KST=timezone(timedelta(hours=9))
# 17개 시도 대표 격자. 시군구 세부 격자는 다음 단계에서 행정구역 표로 확장.
POINTS={
"서울특별시":(60,127),"부산광역시":(98,76),"대구광역시":(89,90),"인천광역시":(55,124),
"광주광역시":(58,74),"대전광역시":(67,100),"울산광역시":(102,84),"세종특별자치시":(66,103),
"경기도":(60,120),"강원특별자치도":(73,134),"충청북도":(69,107),"충청남도":(68,100),
"전북특별자치도":(63,89),"전라남도":(51,67),"경상북도":(89,91),"경상남도":(91,77),"제주특별자치도":(52,38)
}
BASE="https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"

def base_time(now):
    slots=[2,5,8,11,14,17,20,23]
    # 자료 생성 지연을 고려해 약 15분 여유
    candidate=now-timedelta(minutes=15)
    h=max([x for x in slots if x<=candidate.hour], default=None)
    if h is None:
        candidate-=timedelta(days=1); h=23
    return candidate.strftime("%Y%m%d"), f"{h:02d}00"

def fetch(name,nx,ny,key,date,t):
    q=urllib.parse.urlencode({"serviceKey":key,"pageNo":1,"numOfRows":1000,"dataType":"JSON",
                              "base_date":date,"base_time":t,"nx":nx,"ny":ny},safe="%")
    # urlencode가 이미 인코딩된 인증키를 재인코딩할 수 있어 serviceKey는 별도 조립
    params=urllib.parse.urlencode({"pageNo":1,"numOfRows":1000,"dataType":"JSON","base_date":date,"base_time":t,"nx":nx,"ny":ny})
    url=BASE+"?serviceKey="+key+"&"+params
    with urllib.request.urlopen(url,timeout=20) as r: data=json.load(r)
    items=data["response"]["body"]["items"]["item"]
    today=datetime.now(KST).strftime("%Y%m%d")
    vals={}
    for i in items:
        if i["fcstDate"]==today:
            vals.setdefault(i["category"],[]).append(i)
    def nums(cat):
        out=[]
        for x in vals.get(cat,[]):
            try: out.append(float(x["fcstValue"]))
            except: pass
        return out
    tmp=nums("TMP"); reh=nums("REH"); pop=nums("POP")
    return {"region":name,"nx":nx,"ny":ny,
            "tempMin":min(tmp) if tmp else None,"tempMax":max(tmp) if tmp else None,
            "diurnalRange":round(max(tmp)-min(tmp),1) if tmp else None,
            "humidityMax":max(reh) if reh else None,"rainProbabilityMax":max(pop) if pop else None}

def main():
    key=os.environ.get("KMA_SERVICE_KEY")
    if not key: raise SystemExit("KMA_SERVICE_KEY missing")
    now=datetime.now(KST); date,t=base_time(now)
    regions=[]; errors=[]
    for name,(nx,ny) in POINTS.items():
        try: regions.append(fetch(name,nx,ny,key,date,t))
        except Exception as e: errors.append({"region":name,"error":str(e)[:160]})
    payload={"source":"기상청 단기예보 조회서비스","baseDate":date,"baseTime":t,
             "updatedAt":now.isoformat(),"regions":regions,"errors":errors}
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
    if not regions: raise SystemExit("No weather data fetched")
if __name__=="__main__": main()
