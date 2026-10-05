import os,json,urllib.request,urllib.parse,collections
key=os.environ.get('MAFRA_API_KEY','')
if not key: raise SystemExit('MAFRA key missing')
grid='Grid_20151204000000000316_1'
def read(start,end):
 url=f'http://211.237.50.150:7080/openapi/{urllib.parse.quote(key,safe="")}/json/{grid}/{start}/{end}'
 try:
  with urllib.request.urlopen(url,timeout=25) as r: data=json.load(r)
 except Exception: raise SystemExit('MAFRA request failed; credentials omitted') from None
 value=data.get(grid)
 if not value: raise SystemExit('MAFRA grid missing')
 return value
first=read(1,1);total=int(first.get('totalCnt',first.get('TOTAL_CNT',0)))
print('MAFRA totalRows',total)
for label,start,end in [('head',1,min(total,1000)),('tail',max(1,total-999),total)]:
 page=read(start,end);rows=page.get('row',[])
 counts=collections.Counter(str(x.get('LKNTS_NM',x.get('DISEASE_NM','unknown'))) for x in rows)
 dates=[str(x.get('OCCRRNC_DE',x.get('OCCRRNC_DT',''))) for x in rows]
 print(label,json.dumps({'rows':len(rows),'diseases':dict(counts),'minDate':min(dates,default=''),'maxDate':max(dates,default=''),'fieldNames':list(rows[0]) if rows else []},ensure_ascii=False))

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timedelta
bounds=[(start,min(start+999,total)) for start in range(1,total+1,1000)]
with ThreadPoolExecutor(max_workers=4) as pool:pages=list(pool.map(lambda pair:read(*pair),bounds))
rows=[x for page in pages for x in page.get('row',[])]
if len(rows)!=total:raise SystemExit('Full coverage incomplete')
cutoff=(datetime.now()-timedelta(days=366)).strftime('%Y%m%d')
print('FULL official disease names',json.dumps(dict(collections.Counter(str(x.get('LKNTS_NM','')) for x in rows)),ensure_ascii=False))
print('RECENT official disease names',json.dumps(dict(collections.Counter(str(x.get('LKNTS_NM','')) for x in rows if str(x.get('OCCRRNC_DE','')).replace('-','')>=cutoff)),ensure_ascii=False))
