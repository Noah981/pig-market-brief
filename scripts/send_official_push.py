"""Free FCM topic delivery from the existing public-repository collector.

No Cloud Functions, paid server, device-token database, or billing account.
The first successful run establishes a silent baseline. State is only advanced
after FCM accepts a message. Never manufacture occurrences from PED statistics.
"""
import argparse
import hashlib
import json
import os
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
STATE=ROOT/'docs/data/push-state.json'
KST=timezone(timedelta(hours=9))
TYPES={'ASF':'asf','구제역':'fmd','PED':'ped','PRRS':'prrs'}

def identity(row):
    return str(row.get('id') or '|'.join(str(row.get(k,'')) for k in
        ['disease','countryCode','occurrenceDate','province','cityCounty','town','summary']))

def confirmed_events(feed,now):
    if not all(feed.get(k) is True for k in ['coverageVerified','asfDisclosureVerified','fmdDisclosureVerified','pedStatisticsVerified']):
        raise ValueError('Official disease coverage is incomplete')
    updated=datetime.fromisoformat(feed['updatedAt'].replace('Z','+00:00'))
    if updated.tzinfo is None or now-updated>timedelta(hours=6) or updated>now+timedelta(minutes=5):
        raise ValueError('Disease feed is stale or dated in the future')
    result={}
    for row in feed.get('items',[]):
        status=str(row.get('status',''))
        if row.get('countryCode')!='KR' or row.get('evidenceLevel')!='OFFICIAL':continue
        if any(x in status for x in ['의심','확인 중','음성','해제','불검출','종식']):continue
        if not any(x in status for x in ['발생','확진','양성']):continue
        disease=TYPES.get(row.get('disease'))
        if disease is None:continue
        try:day=datetime.fromisoformat(row['occurrenceDate'][:10]).date()
        except (ValueError,KeyError,TypeError):continue
        if not now.astimezone(KST).date()-timedelta(days=30)<=day<=now.astimezone(KST).date():continue
        result[identity(row)]=row
    return result

def disease_message(row):
    disease=TYPES[row['disease']]
    key=identity(row)
    event_id=hashlib.sha256(('disease|'+key).encode()).hexdigest()
    region=' '.join(str(row.get(k,'')) for k in ['province','cityCounty','town'] if row.get(k))
    return {'topic':f'dondonhae_confirmed_{disease}_v1',
      'notification':{'title':f"[전국] {row['disease']} 신규 발생",'body':f"{region} · 발생일 {row['occurrenceDate']}"},
      'data':{'kind':'disease','eventId':event_id,'countryCode':'KR','confirmed':'true','stableKey':key},
      'android':{'priority':'HIGH','ttl':'86400s','notification':{'channel_id':'disease_nationwide_v2','tag':event_id,'sound':'default'}}}

def price_identity(row):
    date=str(row.get('date','')).replace('-','')
    value=row.get('price')
    if row.get('status') not in ['ok','LIVE'] or len(date)!=8 or not isinstance(value,(int,float)) or isinstance(value,bool) or not 1000<=value<=20000:
        raise ValueError('Unverified official pig price')
    if '제주제외' not in str(row.get('scope','')).replace(' ',''):raise ValueError('Wrong official pig-price scope')
    datetime.strptime(date,'%Y%m%d')
    return date,int(value)

def price_message(row):
    date,value=price_identity(row)
    key=f'market|{date}|{value}'
    event_id=hashlib.sha256(key.encode()).hexdigest()
    change=row.get('change')
    body=f'기준일 {date}'
    if isinstance(change,(int,float)) and not isinstance(change,bool):body+=f' · 전일 대비 {int(change):+,}원'
    return {'topic':'dondonhae_market_v1','notification':{'title':f'전국 돈가 갱신 · {value:,}원/kg',
      'body':body},
      'data':{'kind':'market','eventId':event_id,'date':date,'price':str(value)},
      'android':{'priority':'HIGH','ttl':'86400s','notification':{'channel_id':'market_price','tag':event_id,'sound':'default'}}}

def deliver(feed,price,state,send,persist,now):
    events=confirmed_events(feed,now)
    date,value=price_identity(price)
    if date>now.astimezone(KST).strftime('%Y%m%d'):raise ValueError('Future pig-price date')
    if not state.get('initialized'):
        state.update(initialized=True,diseaseIds=list(events),priceDate=date,priceValue=value)
        persist(state)
        return 0
    seen=set(state.get('diseaseIds',[]))
    count=0
    for key,row in events.items():
        if key in seen:continue
        send(disease_message(row))
        seen.add(key)
        state['diseaseIds']=sorted(seen)
        persist(state)
        count+=1
    prior_date=state.get('priceDate','')
    if date>=prior_date and (date!=prior_date or value!=state.get('priceValue')):
        send(price_message(price))
        state.update(priceDate=date,priceValue=value)
        persist(state)
        count+=1
    return count

def fcm_sender():
    config=json.loads(os.environ['DDH_FCM_SERVICE_ACCOUNT_JSON'])
    project=config['project_id']
    if os.environ.get('DDH_FIREBASE_PROJECT_ID')!=project:raise ValueError('Firebase project mismatch')
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request
    creds=service_account.Credentials.from_service_account_info(config,scopes=['https://www.googleapis.com/auth/firebase.messaging'])
    def send(message):
        if not creds.valid:creds.refresh(Request())
        request=urllib.request.Request(f'https://fcm.googleapis.com/v1/projects/{project}/messages:send',
          data=json.dumps({'message':message},ensure_ascii=False).encode(),
          headers={'Authorization':'Bearer '+creds.token,'Content-Type':'application/json'},method='POST')
        with urllib.request.urlopen(request,timeout=30) as response:
            result=json.load(response)
            if response.status!=200 or not result.get('name'):raise RuntimeError('FCM did not confirm acceptance')
    return send

def persist(state):
    temporary=STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    temporary.replace(STATE)

if __name__=='__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    # Missing configuration is a release blocker, never a successful fake delivery.
    sender=fcm_sender()
    state=json.loads(STATE.read_text()) if STATE.exists() else {}
    count=deliver(json.loads((ROOT/'docs/data/disease-alerts.json').read_text()),
      json.loads((ROOT/'docs/data/pig-price.json').read_text()),state,sender,persist,datetime.now(timezone.utc))
    print('FCM accepted new official notifications:',count)
