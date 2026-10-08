import unittest
from scripts.merge_generated_data import merge
class PublicationTests(unittest.TestCase):
 def test_old_collector_cannot_replace_new_price_or_disease(self):
  new={'date':'20261005','price':6100};old={'date':'20261001','price':6027}
  self.assertEqual(merge('pig-price.json',new,old),new)
  new={'updatedAt':'2026-10-05T14:00:00+09:00','coverageVerified':True}
  old={'updatedAt':'2026-10-05T13:00:00+09:00','coverageVerified':False}
  self.assertEqual(merge('disease-alerts.json',new,old),new)
 def test_history_union_and_monthly_resolution_survive(self):
  current={'rows':[{'date':'20261005','price':6100},{'date':'20261001','price':6200,'resolution':'month'}]}
  incoming={'rows':[{'date':'20261001','price':6027}]}
  self.assertEqual(len(merge('pig-price-history.json',current,incoming)['rows']),3)
 def test_newer_source_observation_wins_while_notice_status_remains(self):
  current={'checkedAt':'2026-10-05T14:00:00+09:00','markets':[{'name':'corn','date':'2026-08-01','value':220}],'benefits':[{'id':'new'}],'sourceStatus':[{'id':'bizinfo'}]}
  incoming={'checkedAt':'2026-10-05T13:00:00+09:00','markets':[{'name':'corn','date':'2026-07-01','value':213}],'benefits':[]}
  value=merge('platform.json',current,incoming)
  self.assertEqual(value['markets'][0]['value'],220);self.assertEqual(value['benefits'],current['benefits']);self.assertEqual(value['sourceStatus'],current['sourceStatus'])
 def test_later_market_job_cannot_erase_newer_support_collection(self):
  current={'checkedAt':'2026-10-08T16:10:00+09:00','benefitsCheckedAt':'2026-10-08T16:10:00+09:00','benefits':[{'id':'actual-pig-notice'}],'sourceStatus':[{'id':'bizinfo','status':'connected'}]}
  incoming={'checkedAt':'2026-10-08T16:15:00+09:00','benefits':[],'sourceStatus':[{'id':'bizinfo','status':'old-empty'},{'id':'market','status':'LIVE'}]}
  result=merge('platform.json',current,incoming)
  self.assertEqual(result['benefits'],current['benefits']);self.assertIn({'id':'bizinfo','status':'connected'},result['sourceStatus']);self.assertIn({'id':'market','status':'LIVE'},result['sourceStatus'])
 def test_genuinely_new_support_can_publish_verified_empty_result(self):
  current={'benefitsCheckedAt':'2026-10-08T16:10:00+09:00','benefits':[{'id':'old'}]}
  incoming={'benefitsCheckedAt':'2026-10-08T16:15:00+09:00','benefits':[]}
  self.assertEqual(merge('platform.json',current,incoming)['benefits'],[])
if __name__=='__main__':unittest.main()
