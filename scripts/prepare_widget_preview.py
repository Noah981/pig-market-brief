"""Public official inputs for native QA only; never used as production mock data."""
import json
from pathlib import Path
import urllib.request, urllib.parse
import concurrent.futures

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'flutter_app/android/app/src/test/resources/widget'
OUT.mkdir(parents=True,exist_ok=True)
def get(url):
    request=urllib.request.Request(url,headers={'User-Agent':'DonDonHae-widget-verification/1.8.9','Cache-Control':'no-cache'})
    with urllib.request.urlopen(request,timeout=25) as response:
        if response.status!=200:raise RuntimeError('Official widget input HTTP error')
        return response.read()
base='https://noah981.github.io/pig-market-brief/data/'
with concurrent.futures.ThreadPoolExecutor() as executor:
    future_price=executor.submit(get,base+'pig-price.json')
    future_history=executor.submit(get,base+'pig-price-history.json')
    price=future_price.result();history=future_history.result()
row=json.loads(price);h=json.loads(history)
assert row.get('status')=='ok' and row['price']>0 and '제주제외' in row['scope'].replace(' ','')
assert h.get('rows') and '제주제외' in h['scope'].replace(' ','')
(OUT/'official-price.json').write_bytes(price)
(OUT/'official-history.json').write_bytes(history)
def table(date):
    d=f'{date[:4]}-{date[4:6]}-{date[6:]}'
    q=urllib.parse.urlencode({'searchStartDate':d,'searchEndDate':d,'searchCondition':'057016','searchCondition1':'Y','searchCondition2':''})
    return get('https://www.ekapepia.com/v3/price/auction/period/pig/detail.do?'+q)
with concurrent.futures.ThreadPoolExecutor() as executor:
    cur=executor.submit(table,row['date']);prev=executor.submit(table,row['previousDate'])
    (OUT/'official-current-grade.html').write_bytes(cur.result())
    (OUT/'official-previous-grade.html').write_bytes(prev.result())
print('Public native-widget inputs received; price date='+row['date'])
