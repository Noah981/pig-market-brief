import json
import os
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime, timezone, timedelta

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"docs/data"
KST=timezone(timedelta(hours=9))

OFFICIAL_FEEDS=[
    ('미국 에너지정보청(EIA)','https://www.eia.gov/rss/todayinenergy.xml'),
    ('미국 농무부(USDA)','https://www.usda.gov/rss/latest-releases.xml'),
]

def official_headlines():
    items=[]
    for agency,url in OFFICIAL_FEEDS:
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'Dondonhae/1.2'})
            raw=urllib.request.urlopen(req,timeout=15).read(1_000_001)
            if len(raw)>1_000_000:continue
            root=ET.fromstring(raw)
            for item in root.findall('.//item')[:12]:
                title=(item.findtext('title') or '').strip()
                link=(item.findtext('link') or '').strip()
                if title and link:items.append({'agency':agency,'title':title,'url':link})
        except Exception as exc:print(f'official feed skipped: {agency}: {exc}')
    return items

def related(items,words):
    return [x for x in items if any(w.lower() in x['title'].lower() for w in words)][:2]

def add_commodity_analysis(platform,headlines,updated):
    rows=platform.get('markets',[]); by_id={x.get('name'):x for x in rows}
    labels={'corn':'옥수수','soybean_meal':'대두박','soybean':'대두','wheat':'소맥','wti':'국제유가','usd_krw':'원/달러 환율'}
    keywords={
      'corn':['corn','maize','grain','crop','feed'],'soybean_meal':['soybean','meal','oilseed','feed'],
      'soybean':['soybean','oilseed','crop'],'wheat':['wheat','grain','crop'],
      'wti':['oil','petroleum','opec','gasoline','energy'],'usd_krw':['dollar','currency','interest rate','exchange rate'],
    }
    for row in rows:
        key=row.get('name'); change=float(row.get('changePct') or 0); history=row.get('history') or []
        factors=[]
        if len(history)>=3:
            base=float(history[-3]['value']); last=float(history[-1]['value']); momentum=(last-base)/base*100 if base else 0
            factors.append({'title':'최근 추세','status':'계산','detail':f"최근 3개 발표 기준 {momentum:+.1f}% 흐름입니다. 단기 하루 변동과 더 긴 방향이 같은지 확인한 결과입니다."})
        if key in ('corn','soybean_meal','soybean','wheat'):
            fx=by_id.get('usd_krw',{}).get('changePct'); oil=by_id.get('wti',{}).get('changePct')
            if fx is not None:factors.append({'title':'원화 환산 압력','status':'연관 신호','detail':f"원/달러 환율이 직전 발표 대비 {float(fx):+.1f}%입니다. 국제가격의 원인이 아니라 국내 수입원가를 키우거나 낮추는 별도 요인입니다."})
            if oil is not None:factors.append({'title':'에너지·운송 여건','status':'연관 신호','detail':f"WTI가 직전 발표 대비 {float(oil):+.1f}%입니다. 운임과 가공비에 영향을 줄 수 있으나 곡물가격의 직접 원인으로 단정하지 않습니다."})
        matches=related(headlines,keywords.get(key,[]))
        for news in matches:factors.append({'title':news['title'],'status':'공식 발표','detail':f"{news['agency']} 최신 발표입니다. 현재 가격과 시점·방향이 맞는지 추가 확인해야 하며 제목만으로 원인을 확정하지 않습니다."})
        confidence='보통' if matches and len(history)>=3 else '제한적'
        direction='상승' if change>0 else '하락' if change<0 else '보합'
        subject=labels.get(key,key); particle='은' if subject[-1] in '0123456789율값격' else '는'
        row['analysis']={'updatedAt':updated,'confidence':confidence,'summary':f"{subject}{particle} 직전 발표 대비 {direction}했습니다. 자동 분석은 가격 추세, 환율·유가의 연관 신호와 공식기관 발표를 교차 확인하며 직접 인과관계가 확인되지 않으면 추정으로 표시합니다.",'factors':factors,'sources':[{'name':x['agency'],'label':x['title'],'url':x['url']} for x in matches]}

def load(name,default):
    try:return json.loads((DATA/name).read_text(encoding="utf-8"))
    except:return default

p=load("pig-price.json",{})
h=load("pig-price-history.json",{"rows":[]})
platform=load('platform.json',{'markets':[]})
headlines=official_headlines()
rows=[x for x in h.get("rows",[]) if x.get("verified") is True and x.get("resolution","day")=="day" and (x.get("price") or 0)>0]
latest=p.get("price",0); prev=p.get("previousPrice",0); change=p.get("change",0)
last7=rows[-7:]
avg7=round(sum(x["price"] for x in last7)/len(last7)) if last7 else 0
trend7=latest-avg7 if latest and avg7 else 0
count=p.get("count") or 0
recent_counts=[x.get("count",0) for x in rows[-8:-1] if x.get("count",0)>0]
avg_count=round(sum(recent_counts)/len(recent_counts)) if recent_counts else 0

factors=[]
if change<0:
    factors.append({"title":"당일 경락가격 하락","status":"확인","detail":f"전 거래일 대비 {abs(change):,}원/kg 하락했습니다. 이는 가격 변화 자체를 설명하는 사실이며 단독으로 원인을 확정하지 않습니다."})
elif change>0:
    factors.append({"title":"당일 경락가격 상승","status":"확인","detail":f"전 거래일 대비 {change:,}원/kg 상승했습니다."})
if avg7:
    factors.append({"title":"최근 7거래일 흐름","status":"체크","detail":f"최근 7거래일 평균은 {avg7:,}원/kg이며 오늘 가격은 평균 대비 {latest-avg7:+,}원입니다."})
if count and avg_count:
    pct=(count-avg_count)/avg_count*100
    factors.append({"title":"경매 두수 변화","status":"체크","detail":f"오늘 집계 두수 {count:,}두, 직전 거래일 평균 대비 {pct:+.1f}%입니다. 경매 물량 변화는 가격 변동과 함께 볼 요인입니다."})
if p.get('monthAverage'):
    factors.append({"title":"이번 달 공식 흐름","status":"확인","detail":f"이번 달 확정 거래일까지의 공식 평균은 {int(p['monthAverage']):,}원/kg이며 현재 가격은 이 평균보다 {latest-int(p['monthAverage']):+,}원입니다."})
if p.get('yearAverage'):
    factors.append({"title":"올해 공식 흐름","status":"확인","detail":f"올해 확정 거래일까지의 공식 평균은 {int(p['yearAverage']):,}원/kg입니다."})

summary=("오늘 돈가는 전 거래일보다 낮습니다. " if change<0 else "오늘 돈가는 전 거래일보다 높습니다. " if change>0 else "오늘 돈가는 전 거래일과 같습니다. ")
summary+="당일 가격은 경매 물량·출하 흐름·수요 등 여러 요인의 결과이므로 앱은 확인 가능한 지표와 중기 수급 배경을 분리해 보여줍니다."

updated=datetime.now(KST).isoformat()
pig_news=related(headlines,['pork','hog','swine'])
for news in pig_news:factors.append({'title':news['title'],'status':'공식 발표','detail':f"{news['agency']} 최신 발표입니다. 국내 당일 돈가와 직접 연결된 원인인지는 추가 확인이 필요합니다."})
out={"updatedAt":updated,"headline":"오늘 돈가, 왜 움직였나","summary":summary,"factors":factors,
"sources":[
{"name":"축산물품질평가원","label":"생산자 돼지 경락가격·전국(제주 제외)","url":"https://www.ekapepia.com/v3/price/auction/period/pig/auctionPrice.do"},
*[{"name":x['agency'],"label":x['title'],"url":x['url']} for x in pig_news]
]}
(DATA/"market-analysis.json").write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8")
if os.environ.get('PRICE_ONLY') != '1':
    add_commodity_analysis(platform,headlines,updated)
    (DATA/'platform.json').write_text(json.dumps(platform,ensure_ascii=False,indent=2),encoding='utf-8')
