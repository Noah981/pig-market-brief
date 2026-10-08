"""Send deduplicated nationwide official disease and pork-price FCM topic alerts.
Requires FIREBASE_SERVICE_ACCOUNT_JSON GitHub Actions secret. First run seeds baseline.
"""
import json, os, pathlib, datetime
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

ROOT=pathlib.Path(__file__).resolve().parents[1]
DATA=ROOT/'docs/data'
STATE=DATA/'push-alert-state.json'

def eligible(item):
    return item.get('countryCode')=='KR' and item.get('evidenceLevel')=='OFFICIAL' and item.get('id') and not any(x in str(item.get('status','')) for x in ('음성','종결'))

def snapshot():
    disease=json.loads((DATA/'disease-alerts.json').read_text())
    market=json.loads((DATA/'pig-price.json').read_text())
    events={str(e['id']):e for e in disease.get('items',[]) if eligible(e)}
    return events,market

def send(session, project, topic, title, body, event_id):
    url=f'https://fcm.googleapis.com/v1/projects/{project}/messages:send'
    payload={'message':{'topic':topic,'notification':{'title':title,'body':body},'data':{'event_id':str(event_id)},'android':{'priority':'high','notification':{'channel_id':'dondonhae_remote','default_sound':True}}}}
    response=session.post(url,json=payload,timeout=30)
    response.raise_for_status()

def main():
    events,market=snapshot()
    current={'disease_ids':sorted(events),'market_date':str(market.get('date','')),'market_price':market.get('price')}
    if not STATE.exists():
        STATE.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\\n')
        print('Seeded push baseline without notifying historical events')
        return
    previous=json.loads(STATE.read_text())
    account=os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON','')
    if not account:
        raise SystemExit('FIREBASE_SERVICE_ACCOUNT_JSON missing: no alerts sent or state advanced')
    credentials=service_account.Credentials.from_service_account_info(json.loads(account),scopes=['https://www.googleapis.com/auth/firebase.messaging'])
    session=AuthorizedSession(credentials)
    project=credentials.project_id
    new_ids=set(events)-set(previous.get('disease_ids',[]))
    for event_id in sorted(new_ids):
        e=events[event_id]
        send(session,project,'dondonhae_disease_nationwide','전국 가축질병 신규 발생 · '+str(e.get('disease','질병')),str(e.get('region','전국'))+' · '+str(e.get('status','공식 발생')),event_id)
    if previous.get('market_date') is not None and (str(previous.get('market_date'))!=current['market_date'] or previous.get('market_price')!=current['market_price']):
        send(session,project,'dondonhae_market_updates','전국 돈가 갱신 · '+str(current['market_price'])+'원/kg','기준일 '+current['market_date'],current['market_date']+'-'+str(current['market_price']))
    STATE.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\\n')
    print('Sent',len(new_ids),'new disease alerts; market comparison complete')

if __name__=='__main__':main()
