"""Official FMD farm disclosures and PED aggregate statistics.

PED statistics never become fabricated farm incidents or distance alerts.
"""
import html,io,re,urllib.parse,urllib.request,zipfile,xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timedelta

FMD_BOARD='https://www.mafra.go.kr/FMD-AI2/2216/subview.do'
PED_URL='https://home.kahis.go.kr/home/lkntscrinfo/selectLkntsOccrrnc.do'
NS={'hp':'http://www.hancom.co.kr/hwpml/2011/paragraph'}
PROVINCES={'서울':'서울특별시','부산':'부산광역시','대구':'대구광역시','인천':'인천광역시','광주':'광주광역시','대전':'대전광역시','울산':'울산광역시','세종':'세종특별자치시','경기':'경기도','강원':'강원특별자치도','충북':'충청북도','충남':'충청남도','전북':'전북특별자치도','전남':'전라남도','경북':'경상북도','경남':'경상남도','제주':'제주특별자치도'}
def clean(text):return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',text))).strip()
def request(url,data=None):
 req=urllib.request.Request(url,data=data,headers={'User-Agent':'Mozilla/5.0 (DondonhaeOfficialFeed/1.0)'})
 return urllib.request.urlopen(req,timeout=20).read()
def parse_fmd(data,url,announcement):
 texts=[];tables=[]
 with zipfile.ZipFile(io.BytesIO(data)) as archive:
  for name in archive.namelist():
   if re.fullmatch(r'Contents/section\d+\.xml',name):
    root=ET.fromstring(archive.read(name));texts+=[''.join(x.itertext()) for x in root.findall('.//hp:t',NS)]
    tables += [[''.join(c.itertext()).strip() for c in row.findall('hp:tc',NS)] for row in root.findall('.//hp:tr',NS)]
 joined=''.join(texts)
 expected=re.search(r'(?:구제역\s*)?발생\s*현황\s*[:：]\s*(\d+)\s*건',joined)
 if not expected:raise ValueError('FMD declared count missing')
 out=[];ids=set()
 for cells in tables:
  if len(cells)!=8 or not re.fullmatch(r'\d+(?:차)?',cells[0]):continue
  match=re.search(r'(\d{2,4})\.(\d{1,2})\.(\d{1,2})',cells[2])
  if not match or cells[3] not in PROVINCES:raise ValueError('FMD row invalid')
  year=int(match[1]);year=year+2000 if year<100 else year
  date=datetime(year,int(match[2]),int(match[3])).date().isoformat()
  if date>announcement:raise ValueError('FMD future occurrence')
  sequence=re.match(r'\d+',cells[0])[0]
  ident=f'MAFRA-FMD-TABLE|{date[:7]}|{sequence}'
  if ident in ids:raise ValueError('FMD duplicate sequence')
  ids.add(ident);region=PROVINCES[cells[3]]+' '+cells[4]
  out.append({'id':ident,'disease':'구제역','countryCode':'KR','source':'농림축산식품부 구제역 발생현황 정보공개','sourceUrl':url,'evidenceLevel':'OFFICIAL','status':'공식 발생','summary':region+' 구제역 공식 발생','province':PROVINCES[cells[3]],'cityCounty':cells[4],'region':region,'occurrenceDate':date,'announcementDate':announcement,'livestockType':cells[5],'locationPrecision':'cityCounty'})
 if len(out)!=int(expected[1]):raise ValueError('FMD disclosure count mismatch')
 return out

def fmd_disclosures(now):
 cutoff=(now-timedelta(days=366)).date().isoformat()
 candidates=[]
 for page_number in range(1,6):
  raw=request(FMD_BOARD+('?page='+str(page_number) if page_number>1 else '')).decode('utf-8','ignore')
  found_old=False;found_any=False
  for row in re.findall(r'<tr[^>]*>(.*?)</tr>',raw,re.S):
   if 'artclView.do' not in row:continue
   published=re.search(r'(20\d{2})\.\d{2}\.\d{2}',clean(row))
   if published and published[0].replace('.','-')<cutoff:found_old=True;continue
   for href,label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',row,re.S):
    title=clean(label)
    if '구제역' in title and '정보공개' in title and 'artclView.do' in href:
     url=urllib.parse.urljoin(FMD_BOARD,html.unescape(href));found_any=True
     if url not in candidates:candidates.append(url)
  if found_old:break
  if not found_any:raise ValueError('FMD board pagination incomplete')
 else:raise ValueError('FMD current year pagination not complete')
 if not candidates:raise ValueError('FMD disclosure list missing')
 def read(url):
  page=request(url).decode('utf-8','ignore');published=re.search(r'(20\d{2})\.(\d{2})\.(\d{2})',clean(page))
  if not published:return []
  announcement='-'.join(published.groups())
  if '-'.join(published.groups())<cutoff:return []
  files=re.findall(r'<a[^>]+href=["\']([^"\']*download\.do[^"\']*)["\'][^>]*>(.*?)</a>',page,re.S)
  link=next((urllib.parse.urljoin(url,html.unescape(href)) for href,label in files if '.hwpx' in clean(label)),None)
  if not link:raise ValueError('FMD HWPX missing')
  return parse_fmd(request(link),url,announcement)
 with ThreadPoolExecutor(max_workers=3) as pool:tables=list(pool.map(read,candidates))
 latest={}
 for table in tables:
  for period in {x['occurrenceDate'][:7] for x in table}:
   subset=[x for x in table if x['occurrenceDate'].startswith(period)]
   if period not in latest or subset[0]['announcementDate']>latest[period][0]['announcementDate']:latest[period]=subset
 cutoff=(now-timedelta(days=366)).date().isoformat()
 out=[x for table in latest.values() for x in table if cutoff<=x['occurrenceDate']<=now.date().isoformat()]
 if not out:raise ValueError('FMD disclosed periods unavailable')
 return out

def parse_ped(raw,start,end):
 raw=re.sub(r'<!--.*?-->','',raw,flags=re.S)
 if not re.search(r'<option\s+value="0422"[^>]*selected',raw):raise ValueError('PED selection not echoed')
 for name,value in [('occrFromDt',start),('occrToDt',end)]:
  if not re.search(r'name="'+name+r'"[^>]*value="'+value+r'"',raw):raise ValueError('PED date scope not echoed')
 header=None;periods=[];total=None
 for row in re.findall(r'<tr[^>]*>(.*?)</tr>',raw,re.S):
  cells=re.findall(r'<td[^>]*>(.*?)</td>',row,re.S)
  if cells and 'list_title' in row:
   labels=[clean(c).replace(' ','') for c in cells]
   if labels[0]=='월' and labels[-1]=='소계':header=labels[1:-1]
  if 'name="yymm"' not in row:continue
  if header is None or len(header)<15 or len(cells)!=len(header)+2:raise ValueError('PED table schema changed')
  def numbers(c):
   a=re.search(r'class="had">\s*(\d*)\s*</span>',c);f=re.search(r'class="co">\s*(\d*)\s*</span>',c)
   if not a:raise ValueError('PED animal count missing')
   return {'animalCount':int(a[1] or 0),'farmCount':int(f[1] or 0) if f else 0}
  values=[numbers(c) for c in cells[1:]];summary=values[-1]
  if any(sum(v[k] for v in values[:-1])!=summary[k] for k in summary):raise ValueError('PED regional totals mismatch')
  parsed={'month':clean(cells[0]),**summary,'regions':[{'province':PROVINCES[name],**value} for name,value in zip(header,values[:-1])]}
  if parsed['month'].replace(' ','')=='합계':total=parsed
  elif re.fullmatch(r'20\d{4}',parsed['month']):periods.append(parsed)
  else:raise ValueError('PED month invalid')
 if total is None:
  if header is not None and not periods and '조회된 결과가 없습니다.' in clean(raw):
   return {'from':start,'to':end,'farmCount':0,'animalCount':0,'regions':[],'months':[]}
  raise ValueError('PED total missing')
 if any(sum(p[k] for p in periods)!=total[k] for k in ('farmCount','animalCount')):raise ValueError('PED monthly totals mismatch')
 return {'from':start,'to':end,'farmCount':total['farmCount'],'animalCount':total['animalCount'],'regions':total['regions'],'months':periods}

def ped_statistics(now):
 def read(days):
  end=now.date().isoformat();start=(now-timedelta(days=days)).date().isoformat()
  params={'dissCl':'0422','lstkspCl':'413000','occrFromDt':start,'occrToDt':end,'turmGubun':'02','flag':'month'}
  raw=request(PED_URL,urllib.parse.urlencode(params).encode()).decode('utf-8','ignore')
  return str(days),parse_ped(raw,start,end)
 with ThreadPoolExecutor(max_workers=4) as pool:periods=dict(pool.map(read,(30,90,180,365)))
 return {'source':'KAHIS 법정가축전염병 발생통계','sourceUrl':PED_URL,'checkedAt':now.isoformat(),'basis':'발생일 기준 시도별 집계 · 농장별 위치 미공개','periods':periods}
