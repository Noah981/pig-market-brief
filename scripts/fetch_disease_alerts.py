"""Build a provenance-preserving disease signal feed.

Official pages and public news are deliberately kept as separate evidence
levels.  A keyword match is a signal, never an app-side diagnosis.
"""
import html,json,re,os,io,zipfile,urllib.parse,urllib.request,subprocess,time,sys,xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone,timedelta
from email.utils import parsedate_to_datetime
from pathlib import Path

OUT=Path("docs/data/disease-alerts.json")
KST=timezone(timedelta(hours=9))
DISEASES={
 "ASF":"ASF","FMD":"구제역","아프리카돼지열병":"ASF","구제역":"구제역","돼지열병":"돼지열병","PRRS":"PRRS","돼지생식기호흡기증후군":"PRRS",
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
 agent="Mozilla/5.0 (compatible; DondonhaeOfficialFeed/1.0)"
 req=urllib.request.Request(url,headers={"User-Agent":agent})
 last_error="unknown";curl_code="not-run"
 for attempt in range(3):
  try:return urllib.request.urlopen(req,timeout=15).read().decode("utf-8","ignore")
  except (OSError,TimeoutError) as error:last_error=type(error).__name__
 # Same official URL and TLS verification through an independent transport.
 # URLs and stderr may contain API credentials; never print either.
 try:
  result=subprocess.run(["curl","--fail","--silent","--show-error","--location","--http1.1","--connect-timeout","10","--max-time","25","--user-agent",agent,url],capture_output=True,timeout=30)
  curl_code=str(result.returncode)
  if result.returncode==0 and result.stdout:return result.stdout.decode("utf-8","ignore")
 except (OSError,subprocess.TimeoutExpired) as error:curl_code=type(error).__name__
 raise ValueError(f"Official disease request failed (python={last_error},curl={curl_code}); credentials omitted") from None

def retry_official_source(name,call):
 # Retry only the failed source; retain all existing schema/count checks.
 for attempt in range(2):
  try:return call()
  except Exception as error:
   if attempt==1:raise
   print('Official source retry',name,type(error).__name__,flush=True)
   time.sleep(3)

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
   if not isinstance(result.get('row'),list):
    code=str(result.get('RESULT',{}).get('CODE','missing-row')) if isinstance(result.get('RESULT'),dict) else 'missing-row'
    code=code if re.fullmatch(r'[A-Za-z0-9_-]{1,40}',code) else 'unrecognized'
    raise ValueError('MAFRA schema: '+code)
   return result
  except Exception as error:
   reason=str(error) if isinstance(error,ValueError) and str(error).startswith(("Official disease request failed (","MAFRA schema:")) else type(error).__name__
   raise ValueError("MAFRA request failed: "+reason+"; credentials omitted") from None
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
   out.append({'id':str(row.get('ICTSD_OCCRRNC_NO','')),'disease':disease,'countryCode':'KR','source':'농림축산검역본부 가축질병발생정보','sourceUrl':'https://data.mafra.go.kr/opendata/data/indexOpenDataDetail.do?data_id=20151204000000000316','evidenceLevel':'OFFICIAL','status':'종식' if row.get('CESSATION_DE') else '공식 발생','summary':f'{region} {disease}','region':region,'occurrenceDate':date,'livestockType':livestock})
 print('MAFRA coverage verified',total,'recent relevant incidents',len(out))
 from collections import Counter
 print('MAFRA disease counts',json.dumps(dict(Counter(x['disease'] for x in out)),ensure_ascii=False))
 return out


ASF_BOARD="https://mafra.go.kr/FMD-AI2/2145/subview.do"
ASF_NS={"hp":"http://www.hancom.co.kr/hwpml/2011/paragraph"}
ASF_PROVINCES={"강원":"강원특별자치도","경기":"경기도","충남":"충청남도","충북":"충청북도","전북":"전북특별자치도","전남":"전라남도","경북":"경상북도","경남":"경상남도"}

def parse_asf_hwpx(data,year,source_url,announcement_date,expected_count):
 """Read the official numbered farm table, never publication-date headlines."""
 out=[];row_ids=set()
 with zipfile.ZipFile(io.BytesIO(data)) as archive:
  for name in archive.namelist():
   if not re.fullmatch(r"Contents/section\d+\.xml",name):continue
   root=ET.fromstring(archive.read(name))
   for row in root.findall('.//hp:tr',ASF_NS):
    cells=[''.join(c.itertext()).strip() for c in row.findall('hp:tc',ASF_NS)]
    if len(cells)!=4 or not cells[0].isdigit():continue
    row_ids.add(int(cells[0]))
    match=re.match(r"(\d{1,2})\.(\d{1,2})",cells[1])
    if match:
     date=datetime(year,int(match[1]),int(match[2])).date().isoformat();address=cells[3]
    else:
     full=re.search(r"(\d{2})\.(\d{1,2})\.(\d{1,2})",cells[2])
     if not full:
      hint=re.match(r"\D*(\d{2})",cells[2])
      if hint and 2000+int(hint[1])<year:
       print("ASF old malformed date excluded outside disclosure year",cells[0]);continue
      raise ValueError("ASF table date changed")
     date=datetime(2000+int(full[1]),int(full[2]),int(full[3])).date().isoformat();address=cells[1]
    parts=address.split();province=ASF_PROVINCES.get(parts[0],parts[0]);region=' '.join([province]+[x for x in parts[1:] if re.fullmatch(r'[가-힣]+[시군구읍면동]',x)])
    out.append({"id":f"MAFRA-ASF-TABLE|{date[:4]}|{int(cells[0])}","disease":"ASF","countryCode":"KR","source":"농림축산식품부 ASF 발생현황 정보공개","sourceUrl":source_url,"evidenceLevel":"OFFICIAL","status":"공식 발생","summary":f"{region} ASF · {year}년 {cells[0]}차","region":region,"occurrenceDate":date,"announcementDate":announcement_date,"livestockType":"돼지"})
 if row_ids!=set(range(1,expected_count+1)):
  raise ValueError("ASF official table coverage incomplete")
 return out

def asf_official_table():
 board=fetch(ASF_BOARD);year=datetime.now(KST).year
 links=re.findall(r'<a[^>]+href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>',board,re.S)
 candidates=[]
 for href,label in links:
  title=clean(label)
  if re.search(rf"(?:{year}|{str(year)[2:]})년.*아프리카돼지열병.*발생현황",title) and 'artclView' in href:
   candidates.append((urllib.parse.urljoin(ASF_BOARD,html.unescape(href)),title))
 prior=next(((urllib.parse.urljoin(ASF_BOARD,html.unescape(href)),clean(label)) for href,label in links if 'artclView' in href and re.search(rf"(?:{year-1}|{str(year-1)[2:]})년.*아프리카돼지열병.*발생현황",clean(label))),None)
 if not candidates or not prior:raise ValueError("ASF disclosure coverage unavailable")
 # The board is newest first. Validate the declared total before replacing API rows.
 def read_document(candidate,document_year):
  url,title=candidate;page=fetch(url)
  expected=re.search(r"[~～]\s*(\d+)차",title)
  published=re.search(r"(20\d{2})\.(\d{2})\.(\d{2})",clean(page))
  downloads=re.findall(r'<a[^>]+href=[\"\']([^\"\']*download\.do[^\"\']*)[\"\'][^>]*>(.*?)</a>',page,re.S)
  hwpx=next((urllib.parse.urljoin(url,html.unescape(href)) for href,label in downloads if '.hwpx' in clean(label)),None)
  if not expected or not published or not hwpx:raise ValueError("ASF table metadata changed")
  announcement='-'.join(published.groups())
  req=urllib.request.Request(hwpx,headers={"User-Agent":"DondonhaeOfficialFeed/1.0"})
  from disease_supplementary import request
  data=request(hwpx)
  return parse_asf_hwpx(data,document_year,url,announcement,int(expected[1]))
 with ThreadPoolExecutor(max_workers=2) as pool:
  current,previous=list(pool.map(lambda p:read_document(*p),[(candidates[0],year),(prior,year-1)]))
 cutoff=(datetime.now(KST)-timedelta(days=366)).date().isoformat()
 return current+[x for x in previous if x['occurrenceDate']>=cutoff]

def merge_asf_table(items,table):
 if not table:return items
 periods={x['occurrenceDate'][:4]:max(y['announcementDate'] for y in table if y['occurrenceDate'][:4]==x['occurrenceDate'][:4]) for x in table}
 # The numbered cumulative disclosure is authoritative for this covered period.
 # API reporting dates can differ by a day; merging by date would double count farms.
 return [x for x in items if not (x.get('countryCode')=='KR' and x.get('disease')=='ASF' and x.get('occurrenceDate','')[:4] in periods and x['occurrenceDate']<=periods[x['occurrenceDate'][:4]])]+table

def main():
 from disease_supplementary import fmd_disclosures,ped_statistics
 items=[];coverage=False
 previous=json.loads(OUT.read_text()) if OUT.exists() else {}
 statistics=previous.get('statistics',{})
 fmd_verified=False;ped_verified=False
 try:
  table=retry_official_source('FMD',lambda:fmd_disclosures(datetime.now(KST)));fmd_verified=True
  items+=table
  print('FMD disclosure verified',len(table),'farms')
 except Exception as error:
  print('FMD disclosure unavailable:',type(error).__name__)
  items+=[x for x in previous.get('items',[]) if str(x.get('id','')).startswith('MAFRA-FMD-TABLE|')]
 try:
  statistics['ped']=retry_official_source('PED',lambda:ped_statistics(datetime.now(KST)));ped_verified=True
  print('PED official statistical reports verified',statistics['ped']['periods']['365']['farmCount'])
 except Exception as error:
  print('PED statistics unavailable:',type(error).__name__)

 try:
  api=retry_official_source('MAFRA',mafra_incidents);coverage=True
  disclosed=items.copy()
  items+= [x for x in api if not (x.get('disease')=='구제역' and any(d['occurrenceDate'][:7]==x['occurrenceDate'][:7] for d in disclosed))]
 except ValueError as error:
  print("MAFRA full coverage unavailable; retaining previous official records:",str(error))
  if OUT.exists():items+=[x for x in json.loads(OUT.read_text()).get("items",[]) if x.get("countryCode")=="KR" and x.get("occurrenceDate")]
 asf_verified=False
 try:
  table=retry_official_source('ASF',asf_official_table);items=merge_asf_table(items,table);asf_verified=True
  print("ASF disclosure verified",len(table),"farms")
 except Exception as error:
  print("ASF disclosure unavailable:",type(error).__name__)
  if OUT.exists():
   previous=[x for x in json.loads(OUT.read_text()).get("items",[]) if str(x.get("id","")).startswith("MAFRA-ASF-TABLE|")]
   items=merge_asf_table(items,previous)
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
 payload={"schemaVersion":5,"pedStatisticsVerified":ped_verified,"statistics":statistics,"fmdDisclosureVerified":fmd_verified,"coverageVerified":coverage and asf_verified and fmd_verified,"asfDisclosureVerified":asf_verified,"coverageScope":"국내 API 전체 조회(구제역 우제류 포함) + 올해·전년 ASF 및 구제역 공표자료 대조; PED KAHIS 시도별 통계; 해외 WOAH 아프리카 통보 (세계 전체 집계 아님)","updatedAt":datetime.now(KST).isoformat(),"items":dedup,"evidencePolicy":{"OFFICIAL":"정부·방역기관 원문에서 발생·확진·양성이 확인된 항목","PUBLIC_UNCONFIRMED":"공개 뉴스에서 탐지됐으나 공식 원문 확인 전인 항목","FARM_OBSERVATION":"사용자가 자기 농장에서 직접 기록한 관찰"},"notice":"이 피드는 조기 확인을 위한 정보이며 진단 또는 처방이 아닙니다. 공개정보·확인중은 공식 발생으로 해석하지 마세요."}
 OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
 print("disease signals",len(dedup))
 return payload

if __name__=="__main__":
 payload=main()
 if '--require-verified' in sys.argv and not all(payload.get(key) is True for key in ('coverageVerified','asfDisclosureVerified','fmdDisclosureVerified','pedStatisticsVerified')):
  raise SystemExit('Official disease coverage not verified; publishing blocked')
