import unittest
from scripts.fetch_disease_alerts import diseases,event_title,region_fields,country_code

class DiseaseClassifierTest(unittest.TestCase):
 def test_asf_is_not_classical_swine_fever(self):
  self.assertEqual(diseases('아프리카돼지열병 발생'),['ASF'])
 def test_prevention_is_not_outbreak(self):
  self.assertFalse(event_title('순천시 아프리카돼지열병 차단 방역 강화'))
 def test_ganghwa_word_is_not_region(self):
  self.assertEqual(region_fields('방역을 강화하고 있습니다'),{})
 def test_real_regions(self):
  self.assertEqual(region_fields('경남 창녕서 ASF 발생')['region'],'창녕군')
  self.assertEqual(region_fields('전남 순천시 ASF 발생')['region'],'순천시')
  self.assertEqual(region_fields('경남 의령 돼지농장 ASF 발생')['region'],'의령군')
  self.assertEqual(region_fields('전남 무안 돼지농장 ASF 발생')['region'],'무안군')
 def test_unknown_domestic_title_is_not_forced_to_korea(self):
  self.assertIsNone(country_code('돼지 질병 발생 소식','국내'))
 def test_named_domestic_region_is_korea(self):
  self.assertEqual(country_code('경북 예천군 구제역 발생','국내'),'KR')
 def test_republic_of_korea_is_not_united_states(self):
  self.assertEqual(country_code('대한민국 ASF 발생','국내'),'KR')

if __name__=='__main__':unittest.main()
