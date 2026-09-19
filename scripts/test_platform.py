import unittest
from platform_pipeline import market,benefit,won_per_kg,index
from fetch_disease_alerts import classify,country_code,diseases
from fetch_fred_markets import parse_series,update
class PlatformTests(unittest.TestCase):
 def test_countries(self):
  self.assertEqual(classify('KR'),'국내')
  for code in ['VN','CN','JP','US']:self.assertEqual(classify(code),'국외')
  self.assertIsNone(country_code('해외 발생 동향','국내'))
  self.assertEqual(country_code('베트남 아프리카돼지열병'),'VN')
 def test_asf_not_csf(self):self.assertEqual(diseases('베트남 아프리카돼지열병 발생'),['ASF'])
 def test_conversion(self):
  self.assertAlmostEqual(won_per_kg(200,'USD/ton',1300),260)
  self.assertAlmostEqual(won_per_kg(400,'USD/short ton',1300),573.201881,places=4)
  with self.assertRaises(ValueError):won_per_kg(200,'unknown',1300)
 def test_index(self):
  self.assertEqual(index({'a':110,'b':90},{'a':100,'b':100},{'a':1,'b':1}),100)
 def test_reject_mock(self):
  with self.assertRaises(ValueError):market(dict(name='corn',value=1,unit='USD/ton',date='2026-09-19',basis='spot',url='https://example.org',mock=True),dict(agency='fixture',id='fixture'))
 def test_notice_id(self):
  row=dict(title='축산',region='전국',agency='fixture',url='https://example.org/notice/1',deadline='2026-10-01');source=dict(id='fixture')
  self.assertEqual(benefit(row,source)['id'],benefit(row,source)['id'])
  with self.assertRaises(ValueError):benefit({**row,'deadline':'2026-02-30'},source)
 def test_fred_series_keeps_provenance_and_change(self):
  raw=b'observation_date,DEXKOUS\n2026-09-10,1345.63\n2026-09-11,1340.30\n'
  spec=dict(id='DEXKOUS',unit='원/USD',frequency='daily',source='Federal Reserve',basis='spot')
  row=parse_series('usd_krw',spec,raw)
  self.assertEqual(row['date'],'2026-09-11')
  self.assertAlmostEqual(row['changePct'],-0.40,places=2)
  self.assertEqual(row['source'],'Federal Reserve')
 def test_failed_source_preserves_last_good(self):
  previous={'markets':[{'name':'wti','value':100}],'benefits':[]}
  result=update(previous,[])
  self.assertEqual(result['markets'][0]['value'],100)
if __name__=='__main__':unittest.main()
