import json,re,urllib.request
from datetime import datetime,timezone,timedelta
from pathlib import Path
OUT=Path("docs/data/disease-alerts.json")
SOURCES=[("농림축산식품부","https://www.mafra.go.kr/home/5108/subview.do"),("농림축산검역본부","https://www.qia.go.kr/listindexWebAction.do")]
KEYS=["아프리카돼지열병","ASF","구제역","돼지열병","PED","PRRS"]
items=[]
for source,url in SOURCES:
 try:
  req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
  text=urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")
  plain=re.sub(r"<[^>]+>"," ",text);plain=re.sub(r"\\s+"," ",plain)
  for k in KEYS:
   for m in re.finditer(re.escape(k),plain,re.I):
    s=plain[max(0,m.start()-90):min(len(plain),m.end()+150)].strip()
    if any(x in s for x in ["발생","확진","양성","방역","이동중지","위기경보"]):items.append({"disease":k,"source":source,"summary":s[:220],"sourceUrl":url})
 except Exception:pass
seen=set();dedup=[]
for x in items:
 key=(x["disease"],x["summary"])
 if key not in seen:seen.add(key);dedup.append(x)
payload={"updatedAt":datetime.now(timezone(timedelta(hours=9))).isoformat(),"items":dedup[:20],"notice":"공식기관 공개정보에서 탐지한 방역 관련 항목입니다. 발생 확정 여부와 적용 지역은 원문 공고를 확인하세요."}
OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
print("disease alerts",len(dedup))
