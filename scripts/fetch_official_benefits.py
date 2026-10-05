"""Collect livestock support notices from explicitly allowed official boards.

Only titles and links exposed on public official notice boards are stored. Full
articles are not copied, and unknown amounts/eligibility are never inferred.
"""
import hashlib,html,json,os,re,urllib.parse,urllib.request
from datetime import datetime,timezone,timedelta
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/data/platform.json'
KST=timezone(timedelta(hours=9))
KEYWORDS=re.compile(r'양돈|돼지|축산|가축|사료|방역|축사|분뇨|저탄소|HACCP|무항생제|동물복지')
SUPPORT=re.compile(r'지원|사업|보조|융자|시설|개선|인센티브|인증')
SOURCES=[
 {'id':'mafra-notice','agency':'농림축산식품부','url':'https://www.mafra.go.kr/home/5108/subview.do','region':'전국','permissionBasis':'공식 공개 공지·공고의 제목·원문 링크 이용'},
]
REGIONS=('서울','부산','대구','인천','광주','대전','울산','세종','경기','강원','충북','충남','전북','전남','경북','경남','제주')

def fetch(url):
 req=urllib.request.Request(url,headers={'User-Agent':'Dondonhae/1.2 official-notice-reader'})
 return urllib.request.urlopen(req,timeout=20).read().decode('utf-8','ignore')

def clean(value):return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',value))).strip()

def ymd(value):
 match=re.search(r'(20\d{2})[.\-/]?(\d{2})[.\-/]?(\d{2})',value or '')
 return f'{match.group(1)}-{match.group(2)}-{match.group(3)}' if match else None

def period(value):
 dates=re.findall(r'20\d{2}[.\-/]?\d{2}[.\-/]?\d{2}',value or '')
 return (ymd(dates[0]),ymd(dates[-1])) if dates else (None,None)

def collect_bizinfo():
 key=os.getenv('BIZINFO_API_KEY','').strip()
 if not key:return [],'API 승인 또는 키 연결 대기'
 query=urllib.parse.urlencode({'crtfcKey':key,'dataType':'json','searchCnt':'500'})
 data=json.loads(fetch('https://www.bizinfo.go.kr/uss/rss/bizinfoApi.do?'+query))
 root=data.get('jsonArray',data);rows=root.get('item',[]) if isinstance(root,dict) else []
 if isinstance(rows,dict):rows=[rows]
 items=[]
 for row in rows:
  title=clean(str(row.get('pblancNm') or row.get('title') or ''))
  summary=clean(str(row.get('bsnsSumryCn') or row.get('description') or ''))
  tags=clean(str(row.get('hashTags') or ''))
  haystack=' '.join((title,summary,tags))
  if not KEYWORDS.search(haystack) or not SUPPORT.search(haystack):continue
  url=str(row.get('pblancUrl') or row.get('link') or '').strip()
  if not url.startswith('https://www.bizinfo.go.kr/'):continue
  start,end=period(str(row.get('reqstBeginEndDe') or row.get('reqstDt') or ''))
  matched=[name for name in REGIONS if name in tags or name in title]
  region='·'.join(matched) if matched else '전국'
  ident=str(row.get('pblancId') or row.get('seq') or hashlib.sha256(url.encode()).hexdigest()[:24])
  item={'id':'bizinfo-'+ident,'title':title,'region':region,'agency':clean(str(row.get('jrsdInsttNm') or row.get('author') or '기업마당')),'url':url,'target':clean(str(row.get('trgetNm') or '공식 공고에서 확인')),'support':summary or '공식 공고에서 확인','sourceId':'bizinfo','publishedAt':ymd(str(row.get('creatPnttm') or row.get('pubDate') or '')),'collectedAt':datetime.now(KST).isoformat()}
  if start:item['startDate']=start
  if end:item['deadline']=end
  items.append(item)
 return list({x['id']:x for x in items}.values()),f'연결 완료 · {len(items)}건 확인'

def collect(source):
 raw=fetch(source['url']);items=[]
 for href,label in re.findall(r'<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S):
  title=clean(label)
  if len(title)<8 or len(title)>180 or '반려동물' in title or not KEYWORDS.search(title) or not SUPPORT.search(title):continue
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
  if not rows and status!='API 승인 또는 키 연결 대기':all_items.extend(x for x in previous.get('benefits',[]) if x.get('sourceId')=='bizinfo')
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
 result['benefits']=list({x['id']:x for x in all_items}.values())
 temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(OUT)
 print('official benefits',len(result['benefits']))
if __name__=='__main__':main()
