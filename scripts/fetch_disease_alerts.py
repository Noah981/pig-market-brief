"""Build a provenance-preserving disease signal feed.

Official pages and public news are deliberately kept as separate evidence
levels.  A keyword match is a signal, never an app-side diagnosis.
"""
import html,json,re,os,urllib.parse,urllib.request,xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
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
OUTBREAK_EVENT=re.compile(r"발생|발병|확진|양성|의심축|의심 신고|정밀검사|음성|의심 해제|불검출|검출|outbreak|confirmed|positive|suspected|negative|reported",re.I)
NON_EVENT=re.compile(r"발생[하지 ]*않|없는 청정|발생 대비|발생 예방|차단 방역|예방 훈련|모의 훈련|특별방역|집중 점검|방역 강화|선정|성과",re.I)
COUNTRIES=[
 ("KR",("대한민국","한국","국내","south korea","republic of korea","경기도","강원도","강원특별자치도","충청북도","충청남도","전북특별자치도","전라북도","전라남도","경상북도","경상남도","제주특별자치도")),
 ("VN",("베트남","vietnam","까마우","ca mau")),("CN",("중국","china","chinese")),
 ("JP",("일본","japan")),("US",("미국","united states","usa")),
]
PLACES={
 "강화군":(37.746,126.488),"예천군":(36.657,128.452),"창녕군":(35.544,128.492),"순천시":(34.950,127.487),
 "영주시":(36.805,128.624),"상주시":(36.410,128.159),"문경시":(36.586,128.186),"김천시":(36.139,128.114),
 "경주시":(35.856,129.224),"포천시":(37.895,127.200),"연천군":(38.096,127.075),"철원군":(38.146,127.313),
 "화천군":(38.106,127.708),"양구군":(38.110,127.990),"인제군":(38.069,128.170),"고성군":(38.380,128.467),
 "양평군":(37.491,127.488)
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
 req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 (compatible; DondonhaeOfficialFeed/1.0)"})
 return urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")

def clean(text):return re.sub(r"\s+"," ",html.unescape(re.sub(r"<[^>]+>"," ",text))).strip()
def event_date(value):
 try:return parsedate_to_datetime(value).astimezone(KST).date().isoformat()
 except Exception:return ""

def occurrence_date(text,published=""):
 """Prefer the incident date written in the article title.

 A news publication date is only a last-resort proxy for a genuinely new
 signal.  This prevents a recently republished article about a February
 incident from appearing as a new outbreak in September.
 """
 reference=event_date(published)
 ref=datetime.fromisoformat(reference).date() if reference else datetime.now(KST).date()
 full=re.search(r'((?:19|20)\d{2})\s*[년./-]\s*(\d{1,2})\s*[월./-]\s*(\d{1,2})\s*일?',text)
 if full:
  try:return datetime(int(full.group(1)),int(full.group(2)),int(full.group(3))).date().isoformat()
  except ValueError:return ""
 month_day=re.search(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일',text)
 month_only=re.search(r'(?:지난|올해|금년)?\s*(\d{1,2})\s*월(?:\s*(?:발생|확진|의심|사례|건))',text)
 match=month_day or month_only
 if match:
  month=int(match.group(1));day=int(match.group(2)) if match.lastindex and match.lastindex>=2 else 1
  year=ref.year
  try:
   candidate=datetime(year,month,day).date()
   if candidate>ref+timedelta(days=31):candidate=datetime(year-1,month,day).date()
   return candidate.isoformat()
  except ValueError:return ""
 return reference
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
  if re.search(rf'(?<![가-힣]){re.escape(stem)}(?:서|지역|일대|농장)',text):return {"region":name,"latitude":lat,"longitude":lng}
 return {}

def event_title(text):
 if re.search(r"음성|불검출|의심.*해제|negative",text,re.I):return bool(diseases(text))
 return bool(OUTBREAK_EVENT.search(text)) and not NON_EVENT.search(text)
def event_status(text,evidence):
 if re.search(r"음성|불검출|의심.*해제|negative",text,re.I):return "음성 · 의심 해제"
 if re.search(r"의심|정밀검사|suspected",text,re.I):return "의심 · 정밀검사 중"
 if evidence=="OFFICIAL" or re.search(r"확진|양성|confirmed|positive",text,re.I):return "공식 발생"
 return "공개정보 · 확인 중"
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
  for href,label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S):
   title=clean(label);ds=diseases(title)
   if len(title)<8 or not ds or not event_title(title):continue
   link=urllib.parse.urljoin(url,href)
   code=country_code(title,scope) or default_country
   if not code:continue
   for disease in ds:out.append({"disease":disease,"source":source,"countryCode":code,"scope":classify(code),"evidenceLevel":"OFFICIAL","status":event_status(title,"OFFICIAL"),"level":event_status(title,"OFFICIAL"),"summary":title[:260],"sourceUrl":link,"detectedAt":datetime.now(KST).isoformat(),**region_fields(title)})
 except Exception as e:print("official source skipped",source,e)
 return out

def public_news(scope="국내"):
 out=[]
 terms=["ASF","아프리카돼지열병","구제역 돼지","PED 돼지","PRRS 돼지"] if scope=="국내" else ["African swine fever outbreak","foot and mouth disease outbreak","PRRS outbreak","porcine epidemic diarrhea outbreak"]
 for term in terms:
  try:
   url="https://news.google.com/rss/search?q="+urllib.parse.quote(term)+"&hl=ko&gl=KR&ceid=KR:ko"
   root=ET.fromstring(fetch(url));
   for item in root.findall(".//item")[:10]:
    title=clean(item.findtext("title") or "");ds=diseases(title);published=item.findtext("pubDate") or ""
    if not ds or not event_title(title) or not recent(published):continue
    code=country_code(title,scope)
    if not code:continue
    occurred=occurrence_date(title,published)
    if not occurred:continue
    for disease in ds:out.append({"disease":disease,"source":"공개뉴스","countryCode":code,"scope":classify(code),"evidenceLevel":"PUBLIC_UNCONFIRMED","status":event_status(title,"PUBLIC_UNCONFIRMED"),"level":event_status(title,"PUBLIC_UNCONFIRMED"),"summary":title[:260],"sourceUrl":item.findtext("link") or url,"occurrenceDate":occurred,"publishedAt":published,"detectedAt":datetime.now(KST).isoformat(),**region_fields(title)})
  except Exception as e:print("public source skipped",term,e)
 return out

WOAH_URL="https://rr-africa.woah.org/en/immediate-notifications-in-africa/"
WOAH_COUNTRIES={"South Sudan":"SS","Namibia":"NA","Botswana":"BW","Kenya":"KE","Libya":"LY","Zambia":"ZM","Lesotho":"LS","Eswatini":"SZ","Cabo Verde":"CV","Zimbabwe":"ZW","Mozambique":"MZ","South Africa":"ZA","Eritrea":"ER","Mali":"ML","Egypt":"EG","Burkina Faso":"BF"}
def woah_notifications(raw):
 out=[]
 # Each dated entry is isolated before checking its disease and country.
 chunks=re.split(r"(?=\b\d{2}/\d{2}/20\d{2}\b)",raw)
 for chunk in chunks:
  text=clean(chunk)
  match=re.match(r"(\d{2})/(\d{2})/(20\d{2})\s+(.+)",text)
  if not match or re.search(r"simulation|exercise",text,re.I):continue
  try:date=datetime(int(match[3]),int(match[2]),int(match[1])).date().isoformat()
  except ValueError:continue
  name=next((x for x in WOAH_COUNTRIES if re.match(re.escape(x)+r"\s*[:–-]",match[4])),None)
  if not name:continue
  for disease in diseases(text):
   if disease not in ("ASF","구제역","PED","PRRS"):continue
   out.append({"id":f"WOAH-AFRICA|{WOAH_COUNTRIES[name]}|{date}|{disease}","disease":disease,"source":"WOAH 아프리카 공식 즉시통보","countryCode":WOAH_COUNTRIES[name],"scope":"국외","evidenceLevel":"OFFICIAL","status":"공식 통보","summary":f"{name} · {disease} 공식 통보","sourceUrl":WOAH_URL,"occurrenceDate":"","announcementDate":date,"dateBasis":"notification","livestockType":"축종은 원문 확인"})
 return out

def mafra_incidents():
 key=os.environ.get("MAFRA_API_KEY","")
 if not key:raise ValueError("MAFRA key unavailable")
 grid="Grid_20151204000000000316_1"
 def read(bounds):
  start,end=bounds
  url=f"http://211.237.50.150:7080/openapi/{urllib.parse.quote(key,safe='')}/json/{grid}/{start}/{end}"
  try:
   result=json.loads(fetch(url)).get(grid,{})
   if not isinstance(result.get('row'),list):raise ValueError()
   return result
  except Exception:raise ValueError("MAFRA request failed; credentials omitted") from None
 first=read((1,1));total=int(first.get("totalCnt",first.get("TOTAL_CNT",0)))
 if total<=0:raise ValueError("MAFRA coverage unknown")
 with ThreadPoolExecutor(max_workers=4) as pool:pages=list(pool.map(read,[(start,min(start+999,total)) for start in range(1,total+1,1000)]))
 rows=[row for page in pages for row in page['row']]
 if len(rows)!=total:raise ValueError("MAFRA coverage incomplete")
 cutoff=(datetime.now(KST)-timedelta(days=366)).date().isoformat();out=[]
 for row in rows:
  types=diseases(str(row.get('LKNTS_NM','')))
  raw=str(row.get('OCCRRNC_DE','')).replace('-','')
  if len(raw)!=8:continue
  date=f"{raw[:4]}-{raw[4:6]}-{raw[6:]}"
  if date<cutoff:continue
  livestock=str(row.get('LVSTCKSPC_NM',''))
  address=str(row.get('FARM_LOCPLC',''))
  # Keep administrative locations; never publish farm names or owner details.
  region=' '.join(re.findall(r'[가-힣]+(?:특별자치도|특별시|광역시|도|시|군|구|읍|면|동)(?=\s|$)',address))
  for disease in types:
   if disease not in ('ASF','구제역','PED','PRRS'):continue
   if disease=='구제역' and livestock and '돼지' not in livestock:continue
   out.append({'id':str(row.get('ICTSD_OCCRRNC_NO','')),'disease':disease,'countryCode':'KR','source':'농림축산검역본부 가축질병발생정보','sourceUrl':'https://data.mafra.go.kr/opendata/data/indexOpenDataDetail.do?data_id=20151204000000000316','evidenceLevel':'OFFICIAL','status':'종식' if row.get('CESSATION_DE') else '공식 발생','summary':f'{region} {disease}','region':region,'occurrenceDate':date,'livestockType':livestock})
 print('MAFRA coverage verified',total,'recent pig incidents',len(out))
 return out

def main():
 items=[];coverage=False
 try:
  items+=mafra_incidents();coverage=True
 except ValueError:
  print("MAFRA full coverage unavailable; retaining previous official records")
  if OUT.exists():items+=[x for x in json.loads(OUT.read_text()).get("items",[]) if x.get("countryCode")=="KR" and x.get("occurrenceDate")]
 try:
  overseas=woah_notifications(fetch(WOAH_URL))
  if not overseas:raise ValueError("no dated notifications")
  items+=overseas
 except Exception:
  print("WOAH source unavailable; retaining verified previous notifications")
  for previous in (OUT,Path("flutter_app/assets/data/disease-alerts.json")):
   if previous.exists():items+=[x for x in json.loads(previous.read_text()).get("items",[]) if x.get("sourceUrl")==WOAH_URL]
 items+=official_page("농림축산식품부","https://www.mafra.go.kr/home/5108/subview.do",default_country="KR")
 items+=official_page("농림축산검역본부","https://www.qia.go.kr/listindexWebAction.do",default_country="KR")
 # 공개뉴스의 게시일은 실제 발생일이 아니므로 법정질병 발생 피드에
 # 포함하지 않는다. 앱의 국내 발생 현황은 공식 MAFRA API가 보강한다.
 seen=set();dedup=[]
 for x in items:
  key=(x.get("id"),x["disease"],x["summary"],x.get("occurrenceDate"),x.get("announcementDate"))
  if key not in seen:seen.add(key);dedup.append(x)
 payload={"schemaVersion":4,"coverageVerified":coverage,"coverageScope":"국내 공식 전체 조회; 해외 WOAH 아프리카 통보 (세계 전체 집계 아님)","updatedAt":datetime.now(KST).isoformat(),"items":dedup,"evidencePolicy":{"OFFICIAL":"정부·방역기관 원문에서 발생·확진·양성이 확인된 항목","PUBLIC_UNCONFIRMED":"공개 뉴스에서 탐지됐으나 공식 원문 확인 전인 항목","FARM_OBSERVATION":"사용자가 자기 농장에서 직접 기록한 관찰"},"notice":"이 피드는 조기 확인을 위한 정보이며 진단 또는 처방이 아닙니다. 공개정보·확인중은 공식 발생으로 해석하지 마세요."}
 OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
 print("disease signals",len(dedup))

if __name__=="__main__":main()
