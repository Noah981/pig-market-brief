"""Build a provenance-preserving disease signal feed.

Official pages and public news are deliberately kept as separate evidence
levels.  A keyword match is a signal, never an app-side diagnosis.
"""
import html,json,re,urllib.parse,urllib.request,xml.etree.ElementTree as ET
from datetime import datetime,timezone,timedelta
from email.utils import parsedate_to_datetime
from pathlib import Path

OUT=Path("docs/data/disease-alerts.json")
KST=timezone(timedelta(hours=9))
DISEASES={
 "아프리카돼지열병":"ASF","구제역":"구제역","돼지열병":"돼지열병","PRRS":"PRRS","돼지생식기호흡기증후군":"PRRS",
 "PED":"PED","돼지유행성설사":"PED","돼지인플루엔자":"돼지인플루엔자","PCV2":"PCV2","써코":"PCV2",
 "마이코플라즈마":"마이코플라즈마","흉막폐렴":"흉막폐렴","회장염":"회장염","살모넬라":"살모넬라",
 "로타바이러스":"로타바이러스","대장균":"대장균","돈단독":"돈단독","오제스키":"오제스키병"}
DISEASES.update({"African swine fever":"ASF","foot and mouth disease":"구제역","classical swine fever":"돼지열병","porcine reproductive and respiratory syndrome":"PRRS","porcine epidemic diarrhea":"PED","swine influenza":"돼지인플루엔자"})
OUTBREAK_EVENT=re.compile(r"발생|발병|확진|양성|의심축|의심 신고|검출|outbreak|confirmed|positive|suspected|reported",re.I)
NON_EVENT=re.compile(r"발생[하지 ]*않|없는 청정|발생 대비|발생 예방|차단 방역|예방 훈련|모의 훈련|특별방역|집중 점검|방역 강화|선정|성과",re.I)
COUNTRIES=[
 ("KR",("대한민국","한국","국내","south korea","republic of korea","경기도","강원도","강원특별자치도","충청북도","충청남도","전북특별자치도","전라북도","전라남도","경상북도","경상남도","제주특별자치도")),
 ("VN",("베트남","vietnam","까마우","ca mau")),("CN",("중국","china","chinese")),
 ("JP",("일본","japan")),("US",("미국","united states","usa")),
]
PLACES={
 "강화군":(37.746,126.488),"예천군":(36.657,128.452),"창녕군":(35.544,128.492),"순천시":(34.950,127.487),
 "고양시":(37.658,126.832),"의령군":(35.322,128.261),"무안군":(34.990,126.481),"연천군":(38.096,127.075),
 "영주시":(36.805,128.624),"상주시":(36.410,128.159),"문경시":(36.586,128.186),"김천시":(36.139,128.114),
 "경주시":(35.856,129.224),"포천시":(37.895,127.200),"연천군":(38.096,127.075),"철원군":(38.146,127.313),
 "화천군":(38.106,127.708),"양구군":(38.110,127.990),"인제군":(38.069,128.170),"고성군":(38.380,128.467)
}

def country_code(text,expected_scope=None):
 lower=text.lower()
 for code,names in COUNTRIES:
  if any(name in lower for name in names):return code
 if expected_scope=="국내" and region_fields(text):return "KR"
 return None

def classify(code):
 return "국내" if code=="KR" else ("국외" if code else "분류 확인 필요")

def fetch(url):
 req=urllib.request.Request(url,headers={"User-Agent":"TodayPig/5.0 provenance feed"})
 return urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")

def clean(text):return re.sub(r"\s+"," ",html.unescape(re.sub(r"<[^>]+>"," ",text))).strip()
def diseases(text):
 lower=text.lower();found=[];occupied=[]
 for alias,value in sorted(DISEASES.items(),key=lambda x:len(x[0]),reverse=True):
  for match in re.finditer(re.escape(alias.lower()),lower):
   span=match.span()
   if any(span[0]>=a and span[1]<=b for a,b in occupied):continue
   found.append(value);occupied.append(span)
 return list(dict.fromkeys(found))
def region_fields(text):
 for name,(lat,lng) in PLACES.items():
  if name in text:return {"region":name,"latitude":lat,"longitude":lng}
 for name,(lat,lng) in PLACES.items():
  stem=re.sub(r'[시군구]$','',name)
  if re.search(rf'(?<![가-힣]){re.escape(stem)}(?:시|군|구|서|지역|일대|\s)',text):return {"region":name,"latitude":lat,"longitude":lng}
 return {}

def event_title(text):return bool(OUTBREAK_EVENT.search(text)) and not NON_EVENT.search(text)
def recent(value,days=120):
 if not value:return True
 try:
  parsed=parsedate_to_datetime(value)
  if parsed.tzinfo is None:parsed=parsed.replace(tzinfo=timezone.utc)
  return parsed>=datetime.now(timezone.utc)-timedelta(days=days)
 except Exception:return True

def official_page(source,url,scope="국내",default_country=None):
 out=[]
 try:
  raw=fetch(url)
  for match in re.finditer(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S):
   href,label=match.groups()
   title=clean(label);ds=diseases(title)
   if len(title)<8 or not ds or not event_title(title):continue
   link=urllib.parse.urljoin(url,href)
   code=country_code(title,scope) or default_country
   if not code:continue
   nearby=clean(raw[max(0,match.start()-600):min(len(raw),match.end()+600)])
   date_match=re.search(r'(20\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})',nearby)
   published=(f'{date_match.group(1)}-{int(date_match.group(2)):02d}-{int(date_match.group(3)):02d}' if date_match else datetime.now(KST).date().isoformat())
   try:
    if datetime.fromisoformat(published).date()<datetime.now(KST).date()-timedelta(days=365):continue
   except ValueError:continue
   for disease in ds:out.append({"disease":disease,"source":source,"countryCode":code,"scope":classify(code),"evidenceLevel":"OFFICIAL","level":"공식 발생 확인","summary":title[:260],"sourceUrl":link,"publishedAt":published,"detectedAt":datetime.now(KST).isoformat(),**region_fields(title)})
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
    title=clean(item.findtext("title") or "");ds=diseases(title);published=item.findtext("pubDate") or ""
    if not ds or not event_title(title) or not recent(published):continue
    code=country_code(title,scope)
    if not code:continue
    for disease in ds:out.append({"disease":disease,"source":"공개뉴스","countryCode":code,"scope":classify(code),"evidenceLevel":"PUBLIC_UNCONFIRMED","level":"공개정보 · 공식 확인 필요","summary":title[:260],"sourceUrl":item.findtext("link") or url,"publishedAt":published,"detectedAt":datetime.now(KST).isoformat(),**region_fields(title)})
  except Exception as e:print("public source skipped",term,e)
 return out

def main():
 items=[]
 items+=official_page("농림축산식품부 가축전염병 중앙사고수습본부","https://www.mafra.go.kr/FMD-AI2/",default_country="KR")
 items+=official_page("농림축산식품부 ASF 보도자료","https://www.mafra.go.kr/FMD-AI2/2241/subview.do",default_country="KR")
 items+=official_page("농림축산식품부 구제역 발생현황","https://www.mafra.go.kr/FMD-AI2/2216/subview.do",default_country="KR")
 items+=official_page("농림축산검역본부","https://www.qia.go.kr/listindexWebAction.do",default_country="KR")
 # WOAH의 질병 소개 페이지는 개별 발생 공고가 아니므로 수집하지 않는다.
 # 해외는 국가가 제목에 명시된 최신 공개정보만 표시하고 공식 원문 여부를 구분한다.
 items+=public_news("국내")
 items+=public_news("국외")
 seen=set();dedup=[]
 for x in items:
  key=(x["disease"],x["summary"])
  if key not in seen:seen.add(key);dedup.append(x)
 payload={"schemaVersion":2,"updatedAt":datetime.now(KST).isoformat(),"items":dedup[:50],"evidencePolicy":{"OFFICIAL":"정부·방역기관 원문에서 발생·확진·양성이 확인된 항목","PUBLIC_UNCONFIRMED":"공개 뉴스에서 탐지됐으나 공식 원문 확인 전인 항목","FARM_OBSERVATION":"사용자가 자기 농장에서 직접 기록한 관찰"},"notice":"이 피드는 조기 확인을 위한 정보이며 진단 또는 처방이 아닙니다. 공개정보·확인중은 공식 발생으로 해석하지 마세요."}
 OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
 print("disease signals",len(dedup))

if __name__=="__main__":main()
