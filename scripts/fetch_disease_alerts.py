"""Build a provenance-preserving disease signal feed.

Official pages and public news are deliberately kept as separate evidence
levels.  A keyword match is a signal, never an app-side diagnosis.
"""
import html,json,re,urllib.parse,urllib.request,xml.etree.ElementTree as ET
from datetime import datetime,timezone,timedelta
from pathlib import Path

OUT=Path("docs/data/disease-alerts.json")
KST=timezone(timedelta(hours=9))
DISEASES={
 "아프리카돼지열병":"ASF","구제역":"구제역","돼지열병":"돼지열병","PRRS":"PRRS","돼지생식기호흡기증후군":"PRRS",
 "PED":"PED","돼지유행성설사":"PED","돼지인플루엔자":"돼지인플루엔자","PCV2":"PCV2","써코":"PCV2",
 "마이코플라즈마":"마이코플라즈마","흉막폐렴":"흉막폐렴","회장염":"회장염","살모넬라":"살모넬라",
 "로타바이러스":"로타바이러스","대장균":"대장균","돈단독":"돈단독","오제스키":"오제스키병"}
DISEASES.update({"African swine fever":"ASF","foot and mouth disease":"구제역","classical swine fever":"돼지열병","porcine reproductive and respiratory syndrome":"PRRS","porcine epidemic diarrhea":"PED","swine influenza":"돼지인플루엔자"})
EVENT=re.compile(r"발생|확진|양성|의심|신고|방역|이동중지|위기경보|검출|outbreak|confirmed|positive|reported|alert",re.I)

def fetch(url):
 req=urllib.request.Request(url,headers={"User-Agent":"TodayPig/5.0 provenance feed"})
 return urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")

def clean(text):return re.sub(r"\s+"," ",html.unescape(re.sub(r"<[^>]+>"," ",text))).strip()
def diseases(text):return sorted({v for k,v in DISEASES.items() if k.lower() in text.lower()})

def official_page(source,url,scope="국내"):
 out=[]
 try:
  raw=fetch(url)
  for href,label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S):
   title=clean(label);ds=diseases(title)
   if len(title)<8 or not ds or not EVENT.search(title):continue
   link=urllib.parse.urljoin(url,href)
   for disease in ds:out.append({"disease":disease,"source":source,"scope":scope,"evidenceLevel":"OFFICIAL","level":"공식 발생 확인","summary":title[:260],"sourceUrl":link,"detectedAt":datetime.now(KST).isoformat()})
 except Exception as e:print("official source skipped",source,e)
 return out

def public_news(scope="국내"):
 out=[]
 terms=["아프리카돼지열병","구제역 돼지","PED 돼지","PRRS 돼지"] if scope=="국내" else ["African swine fever outbreak","foot and mouth disease outbreak","PRRS outbreak","porcine epidemic diarrhea outbreak"]
 for term in terms:
  try:
   url="https://news.google.com/rss/search?q="+urllib.parse.quote(term+(" 발생" if scope=="국내" else ""))+"&hl=ko&gl=KR&ceid=KR:ko"
   root=ET.fromstring(fetch(url));
   for item in root.findall(".//item")[:10]:
    title=clean(item.findtext("title") or "");ds=diseases(title)
    if not ds or not EVENT.search(title):continue
    for disease in ds:out.append({"disease":disease,"source":"공개뉴스","scope":scope,"evidenceLevel":"PUBLIC_UNCONFIRMED","level":"공개정보 · 확인중","summary":title[:260],"sourceUrl":item.findtext("link") or url,"publishedAt":item.findtext("pubDate"),"detectedAt":datetime.now(KST).isoformat()})
  except Exception as e:print("public source skipped",term,e)
 return out

items=[]
items+=official_page("농림축산식품부","https://www.mafra.go.kr/home/5108/subview.do")
items+=official_page("농림축산검역본부","https://www.qia.go.kr/listindexWebAction.do")
items+=official_page("WOAH 세계동물보건기구","https://www.woah.org/en/disease/african-swine-fever/","국외")
items+=public_news("국내")
items+=public_news("국외")
seen=set();dedup=[]
for x in items:
 key=(x["disease"],x["summary"])
 if key not in seen:seen.add(key);dedup.append(x)
payload={"schemaVersion":2,"updatedAt":datetime.now(KST).isoformat(),"items":dedup[:50],"evidencePolicy":{"OFFICIAL":"정부·방역기관 원문에서 발생/확진/방역 공지가 확인된 항목","PUBLIC_UNCONFIRMED":"공개 뉴스에서 탐지됐으나 공식 원문 확인 전인 항목","FARM_OBSERVATION":"사용자가 자기 농장에서 직접 기록한 관찰"},"notice":"이 피드는 조기 확인을 위한 정보이며 진단 또는 처방이 아닙니다. 공개정보·확인중은 공식 발생으로 해석하지 마세요."}
OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
print("disease signals",len(dedup))
