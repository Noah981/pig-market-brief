"""Collect livestock support notices from explicitly allowed official boards.

Only titles and links exposed on public official notice boards are stored. Full
articles are not copied, and unknown amounts/eligibility are never inferred.
"""
import hashlib,html,json,os,re,time,subprocess,urllib.parse,urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone,timedelta
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/data/platform.json'
KST=timezone(timedelta(hours=9))
PIG=re.compile(r'양돈|돼지|돈사|아프리카돼지열병|\bASF\b|\bPED\b|\bPRRS\b',re.I)
OTHER_SPECIES=re.compile(r'한우|육우|젖소|낙농|양계|육계|산란계|오리|양봉|벌꿀|양잠|염소|말산업|승마|반려동물|반려견|반려묘|벼|쌀|과수|원예|수산|어업|음식점|식당')
SHARED=re.compile(r'축산농가|축산농업인|가축\s*사육\s*농가|축산업|축산시설|축산환경|축산악취|축산분뇨|축산방역|축사시설현대화|축산분야\s*ICT|사료구매자금|가축재해보험|축산악취개선')
FARM_SUPPORT=re.compile(r'시설|장비|사료|축사|분뇨|방역|퇴비|액비|악취|환경|저탄소|HACCP|무항생제|동물복지|재해|ICT|스마트|백신|예방접종|컨설팅|교육',re.I)
EXCLUDED_PIG=re.compile(r'(?:양돈|돼지|돈사)\s*(?:농가|농장|업)?\s*(?:는|은|를|을)?\s*(?:제외|미지원|지원대상\s*아님)|제외\s*(?:대상)?\s*[:：]?\s*(?:양돈|돼지)')
def pig_related(title,target='',summary='',tags=''):
    text=' '.join((title,target,summary,tags))
    if EXCLUDED_PIG.search(text) or re.search(r'채용|입찰|낙찰',title):return False
    if not SUPPORT.search(text):return False
    if PIG.search(title):return True
    if not PIG.search(target+' '+summary) and re.search(r'온실|토마토|원예|재배|과수|수경|수산',summary):return False
    if OTHER_SPECIES.search(title):return False
    if PIG.search(' '.join((target,summary))):return True
    return bool(SHARED.search(text) and FARM_SUPPORT.search(text) and not OTHER_SPECIES.search(target))

def eligible_item(item):
    if item.get('noticeKind')=='guideline' and str(datetime.now(KST).year) not in str(item.get('title','')):return False
    return pig_related(str(item.get('title','')),str(item.get('target','')),str(item.get('support','')),str(item.get('tags','')))
SUPPORT=re.compile(r'지원|보조금|융자|인센티브|모집|신청|참여|사업|공모|대상자')
SOURCES=[
 {'id':'mafra-livestock-guideline','agency':'농림축산식품부','url':'https://www.mafra.go.kr/bbs/home/795/575876/artclView.do','region':'전국','kind':'guideline','permissionBasis':'공공누리 출처표시 · 공식 축사시설현대화 시행지침 및 원문 링크'},
 {'id':'mafra-notice','agency':'농림축산식품부','url':'https://www.mafra.go.kr/home/5108/subview.do','region':'전국','permissionBasis':'공식 공개 공지·공고의 제목·원문 링크 이용'},
]
REGIONS=('서울','부산','대구','인천','광주','대전','울산','세종','경기','강원','충북','충남','전북','전남','경북','경남','제주')

def notice_region(title,tags='',agency=''):
    text=title+' '+tags+' '+agency
    names=[name for name in REGIONS if name in text]
    aliases={'경상북도':'경북','경상남도':'경남','충청북도':'충북','충청남도':'충남','전라북도':'전북','전라남도':'전남'}
    names+= [short for full,short in aliases.items() if full in text and short not in names]
    counties=re.findall(r'(?:^|[\s\]])([가-힣]{2,6}(?:시|군|구))(?=\s|$)',title)
    counties=[x for x in counties if not any(x.startswith(name) for name in REGIONS)]
    if names:return '·'.join(names+counties)
    if re.search(r'부$|청$',agency) or '전국' in text:return '전국'
    return agency or '지역 확인 필요'

def fetch(url):
 req=urllib.request.Request(url,headers={'User-Agent':'Dondonhae/1.2 official-notice-reader'})
 for attempt in range(2):
  try:return urllib.request.urlopen(req,timeout=20).read().decode('utf-8','strict')
  except Exception:
   if attempt==0:time.sleep(1)
 try:
  result=subprocess.run(['curl','--ipv4','--fail','--silent','--location','--http1.1','--connect-timeout','10','--max-time','25',url],capture_output=True,timeout=30)
  if result.returncode==0 and result.stdout:return result.stdout.decode('utf-8','strict')
 except (OSError,subprocess.TimeoutExpired,UnicodeError):pass
 raise RuntimeError('Official support source unavailable after bounded HTTPS retries')

def clean(value):return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',value))).strip()

def ymd(value):
 match=re.search(r'(20\d{2})[.\-/]?(\d{2})[.\-/]?(\d{2})',value or '')
 return f'{match.group(1)}-{match.group(2)}-{match.group(3)}' if match else None

def period(value):
 dates=re.findall(r'20\d{2}[.\-/]?\d{2}[.\-/]?\d{2}',value or '')
 return (ymd(dates[0]),ymd(dates[-1])) if dates else (None,None)

def bizinfo_rows(data):
 root=data.get('jsonArray',data) if isinstance(data,dict) else data
 rows=root.get('item') if isinstance(root,dict) else root
 if isinstance(rows,dict):rows=[rows]
 if not isinstance(rows,list) or any(not isinstance(row,dict) for row in rows):
  raise ValueError('Unrecognized official Bizinfo response; do not treat errors as zero notices')
 return rows

def collect_bizinfo():
 key=os.getenv('BIZINFO_API_KEY','').strip()
 if not key:return collect_bizinfo_public()
 try:return collect_bizinfo_api(key)
 except Exception:
  print('Official Bizinfo API unavailable; verifying public official notices instead',flush=True)
  return collect_bizinfo_public()

def collect_bizinfo_api(key):
 query=urllib.parse.urlencode({'crtfcKey':key,'dataType':'json','searchCnt':'0'})
 data=json.loads(fetch('https://www.bizinfo.go.kr/uss/rss/bizinfoApi.do?'+query))
 rows=bizinfo_rows(data)
 print('Bizinfo official notices received:',len(rows))
 items=[]
 for row in rows:
  title=clean(str(row.get('pblancNm') or row.get('title') or ''))
  summary=clean(str(row.get('bsnsSumryCn') or row.get('description') or ''))
  tags=clean(str(row.get('hashTags') or ''))
  haystack=' '.join((title,summary,tags))
  if not pig_related(title,clean(str(row.get('trgetNm') or '')),summary,tags):continue
  url=urllib.parse.urljoin('https://www.bizinfo.go.kr/',str(row.get('pblancUrl') or row.get('link') or '').strip())
  parsed=urllib.parse.urlparse(url)
  if parsed.scheme!='https' or parsed.hostname not in ('www.bizinfo.go.kr','bizinfo.go.kr') or parsed.username or parsed.password:continue
  start,end=period(str(row.get('reqstBeginEndDe') or row.get('reqstDt') or ''))
  matched=[name for name in REGIONS if name in tags or name in title]
  region=notice_region(title,tags,clean(str(row.get('jrsdInsttNm') or row.get('author') or '')))
  ident=str(row.get('pblancId') or row.get('seq') or hashlib.sha256(url.encode()).hexdigest()[:24])
  item={'id':'bizinfo-'+ident,'title':title,'region':region,'agency':clean(str(row.get('jrsdInsttNm') or row.get('author') or '기업마당')),'url':url,'target':clean(str(row.get('trgetNm') or '공식 공고에서 확인')),'support':summary or '공식 공고에서 확인','sourceId':'bizinfo','publishedAt':ymd(str(row.get('creatPnttm') or row.get('pubDate') or '')),'collectedAt':datetime.now(KST).isoformat()}
  if start:item['startDate']=start
  if end:item['deadline']=end
  item['applicationPeriod']=str(row.get('reqstBeginEndDe') or row.get('reqstDt') or '')
  items.append(item)
 return list({x['id']:x for x in items}.values()),f'연결 완료 · {len(items)}건 확인'


def bizinfo_detail(raw):
    fields={}
    for block in re.findall(r'<li[^>]*>(.*?)</li>',raw,re.I|re.S):
        label=re.search(r'<span[^>]*class=["\']s_title["\'][^>]*>(.*?)</span>',block,re.I|re.S)
        if label:
            rest=block[label.end():]
            fields[clean(label.group(1))]=clean(rest)
    if not fields.get('사업개요'):raise ValueError('Official notice summary unavailable')
    summary=fields['사업개요']
    targets=[x.strip() for x in summary.split('☞')[1:] if re.search(r'농가|농장|축산업|돈사|돼지|양돈',x)]
    return {'support':summary[:900],'target':targets[0][:350] if targets else '공식 공고에서 확인',
            'applicationPeriod':fields.get('신청기간',''),'agency':fields.get('소관부처·지자체','')}


def collect_bizinfo_public():
    base='https://www.bizinfo.go.kr/sii/siia/selectSIIA200View.do'
    candidates={}
    # Direct pig mentions in the body must also find generic livestock titles.
    searches=[('searchPblancNm',word) for word in ['양돈','돼지','축산','가축','사료','분뇨','ASF','PED','PRRS']]
    searches += [('CONTS',word) for word in ['양돈','돼지','돈사']]
    for condition,keyword in searches:
        for page in range(1,101):
            query=urllib.parse.urlencode({'pblancId':'','hashCode':'','rowsSel':'','rows':15,'cpage':page,'cat':'','schJrsdCodeTy':'','schWntyAt':'','schAreaDetailCodes':'','schEndAt':'','orderGb':'','sort':'','schPblancDiv':'','condition':condition,'condition1':'AND','preKeywords':'','keyword':keyword})
            raw=fetch(base+'?'+query)
            found=0
            for tr in re.findall(r'<tr[^>]*>(.*?)</tr>',raw,re.I|re.S):
                link=re.search(r'<a[^>]+href\s*=\s*["\']([^"\']*selectSIIA200Detail.do[^"\']*)["\'][^>]*>(.*?)</a>',tr,re.I|re.S)
                if not link:continue
                found+=1
                title=clean(link.group(2))
                # Do not apply positive title-only filtering before reading eligibility.
                if OTHER_SPECIES.search(title) and not PIG.search(title):continue
                if re.search(r'채용|입찰|낙찰',title):continue
                cells=[clean(c) for c in re.findall(r'<td[^>]*>(.*?)</td>',tr,re.I|re.S)]
                if len(cells)<7:raise ValueError('Official notice fields changed')
                ident=urllib.parse.parse_qs(urllib.parse.urlparse(html.unescape(link.group(1))).query).get('pblancId',[''])[0]
                if not ident:raise ValueError('Official notice identifier unavailable')
                url='https://www.bizinfo.go.kr/sii/siia/selectSIIA200Detail.do?'+urllib.parse.urlencode({'pblancId':ident})
                candidates[ident]={'id':'bizinfo-'+ident,'title':title,'url':url,'region':notice_region(title,agency=cells[4]),
                    'agency':cells[4],'sourceId':'bizinfo','publishedAt':ymd(cells[6]),'applicationPeriod':cells[3],
                    'collectedAt':datetime.now(KST).isoformat()}
            if not found and '등록된 게시물이 없습니다' not in raw:raise ValueError('Official list is not a verified empty result')
            print('Official support search:',condition,keyword,'page',page,'rows',found,flush=True)
            if found<15:break
        else:raise ValueError('Official notice pagination incomplete')
    def enrich(item):
        details=bizinfo_detail(fetch(item['url']))
        item.update({k:v for k,v in details.items() if v})
        start,end=period(item['applicationPeriod'])
        if start:item['startDate']=start
        if end:item['deadline']=end
        return item if eligible_item(item) else None
    with ThreadPoolExecutor(max_workers=3) as pool:
        items=[x for x in pool.map(enrich,candidates.values()) if x is not None]
    print('Official support candidates checked:',len(candidates),'eligible pig programmes:',len(items))
    return items,f'공식 공개 공고 연결 완료 · {len(items)}건 확인'

def collect(source):
 raw=fetch(source['url']);items=[]
 if source.get('kind')=='guideline':
  titles=[clean(x) for x in re.findall(r'<dt[^>]*>(.*?)</dt>',raw,re.I|re.S)]
  title=next((x for x in titles if '축사시설현대화' in x and '시행지침' in x),'')
  if not title:raise ValueError('Official livestock guideline title unavailable')
  if str(datetime.now(KST).year) not in title:return []
  return [{'id':source['id']+'-'+str(datetime.now(KST).year),'title':title,'region':'전국','agency':source['agency'],'url':source['url'],
    'target':'양돈농가 포함 · 세부 지원자격은 공식 시행지침 확인','support':'축사 신축·개보수 및 생산·방역시설 지원 지침 · 실제 접수 여부는 관할 지자체 확인',
    'applicationPeriod':'관할 시·군·구 접수 일정 확인','noticeKind':'guideline','sourceId':source['id'],'collectedAt':datetime.now(KST).isoformat()}]

 for href,label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S):
  title=clean(label)
  if len(title)<8 or len(title)>180 or not pig_related(title):continue
  url=urllib.parse.urljoin(source['url'],href)
  if urllib.parse.urlparse(url).scheme!='https' or 'artclView.do' not in url:continue
  ident=hashlib.sha256((source['id']+'|'+url).encode()).hexdigest()[:24]
  items.append({'id':ident,'title':title,'region':source['region'],'agency':source['agency'],'url':url,'target':'공식 공고에서 확인','support':'공식 공고에서 확인','documents':'공식 공고에서 확인','eligibility':'공식 담당부서 확인 필요','sourceId':source['id'],'collectedAt':datetime.now(KST).isoformat()})
 return list({x['id']:x for x in items}.values())[:30]

def main():
 previous=json.loads(OUT.read_text(encoding='utf-8')) if OUT.exists() else {'markets':[],'benefits':[]}
 result={**previous,'checkedAt':datetime.now(KST).isoformat(),'sourceStatus':[x for x in previous.get('sourceStatus',[]) if x.get('id') not in {'bizinfo',*[s['id'] for s in SOURCES]}]};all_items=[]
 try:
  rows,status=collect_bizinfo();all_items.extend(rows)
 except Exception:
  status='연결 오류 · 마지막 정상 데이터 유지';all_items.extend(x for x in previous.get('benefits',[]) if x.get('sourceId')=='bizinfo')
 result['sourceStatus'].append({'id':'bizinfo','agency':'기업마당','status':status,'permissionBasis':'기업마당 지원사업정보 공식 API'})
 for source in SOURCES:
  try:
   rows=collect(source);all_items.extend(rows);status=f'연결 완료 · {len(rows)}건 확인'
  except Exception:
   rows=[];status='연결 오류 · 마지막 정상 데이터 유지'
   all_items.extend(x for x in previous.get('benefits',[]) if x.get('sourceId')==source['id'])
  result['sourceStatus'].append({'id':source['id'],'agency':source['agency'],'status':status,'permissionBasis':source['permissionBasis']})
 result['benefits']=list({x['id']:x for x in all_items if eligible_item(x)}.values())
 temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(OUT)
 print('official benefits',len(result['benefits']))
if __name__=='__main__':main()
