"""Keep newer source observations when scheduled collectors publish concurrently."""
import json,sys
from pathlib import Path
from datetime import datetime

def stamp(row):
 for key in ('updatedAt','checkedAt','collectedAt'):
  try:return datetime.fromisoformat(str(row.get(key,'')).replace('Z','+00:00')).timestamp()
  except (ValueError,TypeError):pass
 return 0

def merge(name,current,incoming):
 if name=='pig-price.json':
  if str(current.get('date',''))>str(incoming.get('date','')):return current
 elif name=='pig-price-history.json':
  rows={(str(x.get('date','')),str(x.get('resolution','day'))):x for x in current.get('rows',[])}
  rows.update({(str(x.get('date','')),str(x.get('resolution','day'))):x for x in incoming.get('rows',[])})
  return {**incoming,'rows':sorted(rows.values(),key=lambda x:str(x.get('date','')))}
 elif name=='platform.json':
  newer=incoming if stamp(incoming)>=stamp(current) else current
  rows={x['name']:x for x in current.get('markets',[]) if x.get('name')}
  for x in incoming.get('markets',[]):
   old=rows.get(x.get('name')); new_date=str(x.get('date',''))
   if old is None or new_date>str(old.get('date','')) or (new_date==str(old.get('date','')) and stamp(x)>=stamp(old)):rows[x['name']]=x
  return {**newer,'markets':list(rows.values())}
 elif stamp(current)>stamp(incoming):return current
 return incoming

def main():
 source=Path(sys.argv[1]);target=Path(sys.argv[2]);target.mkdir(parents=True,exist_ok=True)
 for path in source.glob('*.json'):
  incoming=json.loads(path.read_text());destination=target/path.name
  current=json.loads(destination.read_text()) if destination.exists() else {}
  destination.write_text(json.dumps(merge(path.name,current,incoming),ensure_ascii=False,indent=2))
if __name__=='__main__':main()
