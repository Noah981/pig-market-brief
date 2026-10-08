import copy
import unittest
from datetime import datetime,timezone
from scripts.send_official_push import deliver,confirmed_events

NOW=datetime(2026,10,8,14,30,tzinfo=timezone.utc) # KST 23:30: no quiet hours
def row(key,**extra):
    return dict(id=key,disease='ASF',countryCode='KR',evidenceLevel='OFFICIAL',
      status='공식 발생',occurrenceDate='2026-10-08',province='제주특별자치도',cityCounty='제주시',**extra)
def feed(items):
    return dict(items=items,updatedAt=NOW.isoformat(),coverageVerified=True,
      asfDisclosureVerified=True,fmdDisclosureVerified=True,pedStatisticsVerified=True)
PRICE=dict(date='20261007',price=6100,change=100,status='ok',scope='전국·탕박·등외제외·제주제외')

class PushTests(unittest.TestCase):
    def test_first_sync_is_silent_then_nationwide_night_new_occurrence_only(self):
        state={};sent=[];persisted=[]
        persist=lambda s:persisted.append(copy.deepcopy(s))
        self.assertEqual(deliver(feed([row('old')]),PRICE,state,sent.append,persist,NOW),0)
        items=[row('old'),row('new')]
        for key,field,value in [('suspect','status','의심'),('negative','status','음성'),('closed','status','종식'),('foreign','countryCode','VN'),('news','evidenceLevel','PUBLIC_INFO')]:
            r=row(key);r[field]=value;items.append(r)
        self.assertEqual(deliver(feed(items),PRICE,state,sent.append,persist,NOW),1)
        self.assertEqual(sent[0]['topic'],'dondonhae_confirmed_asf_v1')
        self.assertIn('제주시',sent[0]['notification']['body'])
        self.assertEqual(deliver(feed(items),PRICE,state,sent.append,persist,NOW),0)

    def test_suspected_to_confirmed_is_one_new_occurrence(self):
        state={};sent=[]
        r=row('same');r['status']='의심'
        deliver(feed([r]),PRICE,state,sent.append,lambda _:None,NOW)
        self.assertEqual(deliver(feed([row('same')]),PRICE,state,sent.append,lambda _:None,NOW),1)
        self.assertEqual(deliver(feed([row('same')]),PRICE,state,sent.append,lambda _:None,NOW),0)

    def test_missing_stale_or_incomplete_data_does_not_advance_state(self):
        for bad in [dict(feed([]),coverageVerified=False),dict(feed([]),updatedAt='2026-10-01T00:00:00+00:00')]:
            state={}
            with self.assertRaises(ValueError):deliver(bad,PRICE,state,lambda _:None,lambda _:None,NOW)
            self.assertEqual(state,{})

    def test_failed_delivery_is_retried_and_completed_events_are_preserved(self):
        state={};deliver(feed([]),PRICE,state,lambda _:None,lambda _:None,NOW)
        sent=[]
        def send(msg):
            if 'second' in msg['data'].get('stableKey',''):raise OSError('connection')
            sent.append(msg)
        with self.assertRaises(OSError):deliver(feed([row('first'),row('second')]),PRICE,state,send,lambda _:None,NOW)
        self.assertEqual(state['diseaseIds'],['first'])
        self.assertEqual(deliver(feed([row('first'),row('second')]),PRICE,state,sent.append,lambda _:None,NOW),1)
        self.assertEqual(len(sent),2)

    def test_new_quote_correction_duplicate_and_regression(self):
        state={};sent=[];persist=lambda _:None
        deliver(feed([]),PRICE,state,sent.append,persist,NOW)
        newer=dict(PRICE,date='20261008',price=6200)
        self.assertEqual(deliver(feed([]),newer,state,sent.append,persist,NOW),1)
        self.assertEqual(deliver(feed([]),dict(newer,price=6250),state,sent.append,persist,NOW),1)
        self.assertEqual(deliver(feed([]),dict(newer,price=6250),state,sent.append,persist,NOW),0)
        self.assertEqual(deliver(feed([]),PRICE,state,sent.append,persist,NOW),0)

if __name__=='__main__':unittest.main()
