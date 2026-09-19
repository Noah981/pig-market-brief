"""Validated, provenance-preserving JSON/RSS adapters; no synthetic market values.
Only configured sources with a recorded permission basis are fetched.
"""
import json, os, math, hashlib, urllib.request, urllib.parse, xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime, timezone, timedelta, date
ROOT=Path(__file__).resolve().parents[1]
KST=timezone(timedelta(hours=9))

def https(url):
 p=urllib.parse.urlparse(url)
 return p.scheme=='https' and bool(p.hostname) and not p.username and not p.password

def valid_date(value):
 try: return date.fromisoformat(value[:10]).isoformat()
 except (ValueError,TypeError): raise ValueError('Invalid source date')

def market(row, source):
 for key in ('name','value','unit','date','basis','url'):
  if key not in row:raise ValueError('Missing market field '+key)
 value=float(row['value'])
 if not math.isfinite(value) or value<=0 or not https(row['url']):raise ValueError('Invalid quote')
 if row.get('mock') or row.get('sample'):raise ValueError('Samples are not production data')
 out={k:row[k] for k in ('name','unit','basis','url')}
 out.update(value=value,date=valid_date(row['date']),source=source['agency'],sourceId=source['id'],updatedAt=row.get('updatedAt',row['date']))
 return out

def benefit(row,source):
 for key in ('title','region','agency','url'):
  if not row.get(key):raise ValueError('Missing benefit field '+key)
 if not https(row['url']):raise ValueError('Invalid official URL')
 out=dict(row)
 for key in ('deadline','publishedAt','startDate'):
  if row.get(key):out[key]=valid_date(row[key])
 canonical=urllib.parse.urlparse(row['url'])._replace(fragment='').geturl()
 out['id']=hashlib.sha256((source['id']+'|'+canonical).encode()).hexdigest()[:24]
 out['sourceId']=source['id'];out['eligibility']='공식 담당부서 확인 필요'
 return out

def won_per_kg(value,unit,fx):
 if any(not math.isfinite(x) or x<=0 for x in (value,fx)):raise ValueError('Invalid conversion')
 kg={'USD/ton':1000,'USD/short ton':907.18474,'USD/lb':0.45359237,'US cents/bushel corn':25.40117272*100,'US cents/bushel wheat':27.2155422*100,'US cents/bushel soybean':27.2155422*100}
 if unit not in kg:raise ValueError('Unsupported unit; do not assume conversion')
 return value*fx/kg[unit]

def index(values,base,weights):
 if set(values)!=set(base) or set(values)!=set(weights):raise ValueError('Incomplete basket')
 if any(base[k]<=0 or weights[k]<0 for k in base) or sum(weights.values())<=0:raise ValueError('Invalid basket')
 return sum(values[k]/base[k]*100*weights[k] for k in base)/sum(weights.values())

def collect(source):
 if not source.get('enabled') or not source.get('permissionBasis'):return [],'연결 검증 대기'
 if not https(source['endpoint']):raise ValueError('HTTPS required')
 headers={'User-Agent':'Dondonhae/5.0'}
 if source.get('keyEnv'):
  key=os.getenv(source['keyEnv'])
  if not key:return [],'API 승인 또는 키 연결 대기'
  headers[source.get('keyHeader','Authorization')]=key
 req=urllib.request.Request(source['endpoint'],headers=headers)
 with urllib.request.urlopen(req,timeout=15) as response:
  raw=response.read(5_000_001)
 if len(raw)>5_000_000:raise ValueError('Payload too large')
 if source.get('format')=='rss':
  rows=[]
  for item in ET.fromstring(raw).findall('.//item'):
   title=item.findtext('title','')
   if not any(k in title for k in ('양돈','축산','돼지','사료','인증')):continue
   rows.append(dict(title=title,url=item.findtext('link',''),region=source['region'],agency=source['agency'],target='공식 원문 확인',support='공식 원문 확인',documents='공식 원문 확인'))
 else:
  data=json.loads(raw);rows=data[source.get('itemsKey','items')]
 validate=market if source['kind']=='markets' else benefit
 return [validate(row,source) for row in rows],'연결 완료'

def main():
 out=ROOT/'docs/data/platform.json';config=json.loads((ROOT/'config/platform_sources.json').read_text())
 previous=json.loads(out.read_text()) if out.exists() else {'markets':[],'benefits':[]}
 result={**previous,'checkedAt':datetime.now(KST).isoformat(),'sourceStatus':[]}
 for source in config['sources']:
  try:
   rows,status=collect(source)
   if status=='연결 완료':
    kind=source['kind'];kept=[r for r in result.get(kind,[]) if r.get('sourceId')!=source['id']]
    merged=kept+rows;result[kind]=list({r.get('id',r.get('sourceId','')+r.get('name','')):r for r in merged}.values())
  except Exception:
   status='연결 오류 · 마지막 정상 데이터 유지'
  result['sourceStatus'].append(dict(id=source['id'],agency=source['agency'],status=status))
 out.parent.mkdir(parents=True,exist_ok=True);temp=out.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False,indent=2));temp.replace(out)
if __name__=='__main__':main()
