"""Verify complete public KAHIS occurrence-date pagination; publish no farm PII."""
import hashlib,re,urllib.parse,subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from disease_supplementary import clean,request

URL='https://home.kahis.go.kr/home/lkntscrinfo/selectLkntsOccrrncList.do'
DISEASES={'아프리카돼지열병':'ASF','구제역':'구제역','돼지생식기호흡기증후군':'PRRS'}

def parse_page(raw,start,end,page):
 raw=re.sub(r'<!--.*?-->','',raw,flags=re.S)
 for name,value in [('occrFromDt',start),('occrToDt',end),('pageIndex',str(page))]:
  fields=re.findall(r'<input\b[^>]*>',raw,re.I)
  found=[x for x in fields if re.search(r'name="'+name+r'"',x)]
  if not found or any(not re.search(r'value="'+re.escape(value)+r'"',x) for x in found):
   raise ValueError('KAHIS date/page scope not echoed')
 if not re.search(r'<input[^>]*name="turmGubun"[^>]*value="02"[^>]*checked',raw):
  raise ValueError('KAHIS occurrence date basis not echoed')
 for name in ('dissCl','lstkspCl','ctprvn','signgu'):
  select=re.search(r'<select[^>]*name="'+name+r'"[^>]*>(.*?)</select>',raw,re.S)
  if not select or re.search(r'<option\s+value="[^"]+"[^>]*selected',select[1]):
   raise ValueError('KAHIS unexpected scope filter')
 pages=[int(x) for x in re.findall(r'fn_page_link\((\d+)\)',raw)]
 last=max(pages+[1])
 if last>1000 or page>last:raise ValueError('KAHIS pagination invalid')
 rows=[];header=False
 for tr in re.findall(r'<tr[^>]*>(.*?)</tr>',raw,re.S):
  cells=re.findall(r'<td[^>]*>(.*?)</td>',tr,re.S)
  if len(cells)!=8:continue
  if 'list_title' in tr:
   labels=[clean(x).replace(' ','') for x in cells]
   if labels[:5]!=['가축전염병명','농장명(농장주)','농장소재지','발생일자(진단일)','축종(품종)']:
    raise ValueError('KAHIS headers changed')
   header=True;continue
  if not header:continue
  values=[clean(x) for x in cells]
  match=re.fullmatch(r'(20\d{2}-\d{2}-\d{2})\s*\((20\d{2}-\d{2}-\d{2})\)',values[3])
  if not match or not start<=match[1]<=end:raise ValueError('KAHIS row date outside query')
  # Hash farm details for deduplication, never retain or publish their text.
  fingerprint=hashlib.sha256('\x1f'.join(values).encode()).hexdigest()
  disease=DISEASES.get(values[0]);item=None
  if disease:
   parts=values[2].split();admin=[]
   for part in parts:
    if not re.fullmatch(r'[가-힣]+(?:도|시|군|구)',part):break
    admin.append(part)
   if not admin:raise ValueError('KAHIS administrative region missing')
   region=' '.join(admin)
   item={'id':'KAHIS|'+fingerprint,'disease':disease,'countryCode':'KR','source':'농림축산검역본부 KAHIS 가축전염병 발생현황','sourceUrl':URL,'evidenceLevel':'OFFICIAL','status':'공식 발생','summary':region+' '+disease,'region':region,'occurrenceDate':match[1],'diagnosisDate':match[2],'livestockType':values[4],'locationPrecision':'cityCounty'}
  rows.append((fingerprint,item))
 if not header or not rows:raise ValueError('KAHIS occurrence table empty/missing')
 if len(rows)>10 or (page<last and len(rows)!=10):raise ValueError('KAHIS page truncated')
 return last,rows

def kahis_incidents(now):
 start=(now-timedelta(days=366)).date().isoformat();end=now.date().isoformat()
 def read(page):
  params={'pageIndex':str(page),'occrFromDt':start,'occrToDt':end,'turmGubun':'02','dissCl':'','lstkspCl':'','ctprvn':'','signgu':'','legalIctsdGradSe':''}
  data=urllib.parse.urlencode(params).encode()
  # curl reaches this official TLS endpoint reliably in both CI and local jobs.
  # Preserve certificate verification and exact POST parameters.
  try:
   result=subprocess.run(['curl','--fail','--silent','--show-error','--location','--http1.1','--connect-timeout','10','--max-time','25','--data-binary','@-',URL],input=data,capture_output=True,timeout=30)
   raw=result.stdout if result.returncode==0 and result.stdout else request(URL,data)
  except (OSError,subprocess.TimeoutExpired):raw=request(URL,data)
  raw=raw.decode('utf-8','strict')
  return parse_page(raw,start,end,page)
 last,first=read(1)
 with ThreadPoolExecutor(max_workers=4) as pool:rest=list(pool.map(read,range(2,last+1)))
 if any(total!=last for total,_ in rest):raise ValueError('KAHIS pagination changed during collection')
 rows=first+[row for _,batch in rest for row in batch]
 if len({ident for ident,_ in rows})!=len(rows):raise ValueError('KAHIS repeated rows/pages')
 items=[item for _,item in rows if item]
 if not all(any(x['disease']==d for x in items) for d in DISEASES.values()):
  raise ValueError('KAHIS required disease coverage missing')
 print('KAHIS complete occurrence-date coverage verified',last,'pages',len(rows),'rows',len(items),'relevant incidents',flush=True)
 return items
