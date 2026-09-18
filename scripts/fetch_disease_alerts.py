import json,re,urllib.request,urllib.parse
from datetime import datetime,timezone,timedelta
from pathlib import Path
OUT=Path("docs/data/disease-alerts.json")
SOURCES=[
 ("공식·농림축산식품부","https://www.mafra.go.kr/home/5108/subview.do"),
 ("공식·농림축산검역본부","https://www.qia.go.kr/listindexWebAction.do"),
]
KEYS=["아프리카돼지열병","ASF","구제역","돼지열병","PED","PRRS"]
EVENT=["발생","확진","양성","의심","신고","방역","이동중지","위기경보"]
items=[]
def scan(source,url,kind):
 try:
  req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
  raw=urllib.request.urlopen(req,timeout=12).read().decode("utf-8","ignore")
  plain=re.sub(r"<[^>]+>"," ",raw);plain=re.sub(r"\\s+"," ",plain)
  for k in KEYS:
   for m in re.finditer(re.escape(k),plain,re.I):
    s=plain[max(0,m.start()-120):min(len(plain),m.end()+220)].strip()
    if any(x in s for x in EVENT):
     items.append({"disease":k,"source":source,"level":kind,"summary":s[:300],"sourceUrl":url})
 except Exception: pass
for x in SOURCES: scan(x[0],x[1],"공식")
# 공개 뉴스 검색은 공식 확인 전 '속보/확인중'으로만 분류한다.
for k in ["아프리카돼지열병 ASF","구제역 돼지","PED 돼지","PRRS 돼지"]:
 q=urllib.parse.quote(k+" 발생")
 scan("공개뉴스·Google News","https://news.google.com/rss/search?q="+q+"&hl=ko&gl=KR&ceid=KR:ko","확인중")
seen=set();dedup=[]
for x in items:
 key=(x["disease"],re.sub(r"\\s+"," ",x["summary"])[:180])
 if key not in seen: seen.add(key);dedup.append(x)
payload={"updatedAt":datetime.now(timezone(timedelta(hours=9))).isoformat(),"items":dedup[:40],"notice":"공식은 확인된 기관 공개정보, 확인중은 공개 뉴스에서 탐지된 조기정보입니다. 확인중 항목은 발생 확정으로 해석하지 마세요."}
OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
print("disease alerts",len(dedup))
