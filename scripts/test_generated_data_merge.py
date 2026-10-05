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
if __name__=='__main__':unittest.main()
