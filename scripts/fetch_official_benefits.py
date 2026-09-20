"""Collect livestock support notices from explicitly allowed official boards.

Only titles and links exposed on public official notice boards are stored. Full
articles are not copied, and unknown amounts/eligibility are never inferred.
"""
import hashlib,html,json,re,urllib.parse,urllib.request
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

def fetch(url):
 req=urllib.request.Request(url,headers={'User-Agent':'Dondonhae/1.2 official-notice-reader'})
 return urllib.request.urlopen(req,timeout=20).read().decode('utf-8','ignore')

def clean(value):return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',value))).strip()

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
 result={**previous,'checkedAt':datetime.now(KST).isoformat(),'sourceStatus':[]};all_items=[]
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
