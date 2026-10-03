import unittest
from scripts.fetch_disease_alerts import diseases,event_title,region_fields,country_code,event_status,event_date,occurrence_date,woah_notifications

class DiseaseClassifierTest(unittest.TestCase):
 def test_woah_notifications_exclude_simulations_and_preserve_date_basis(self):
  rows=woah_notifications('<p>04/10/2026 Egypt – Simulation : Foot and mouth disease</p><p>24/09/2026 Namibia: Foot and mouth disease</p><p>18/09/2026 South Sudan: African swine fever</p>')
  self.assertEqual([x['countryCode'] for x in rows],['NA','SS'])
  self.assertEqual([x['disease'] for x in rows],['구제역','ASF'])
  self.assertEqual(rows[1]['announcementDate'],'2026-09-18')
  self.assertEqual(rows[1]['occurrenceDate'],'')
  self.assertEqual(rows[1]['dateBasis'],'notification')
 def test_asf_is_not_classical_swine_fever(self):
  self.assertEqual(diseases('아프리카돼지열병 발생'),['ASF'])
 def test_prevention_is_not_outbreak(self):
  self.assertFalse(event_title('순천시 아프리카돼지열병 차단 방역 강화'))
 def test_ganghwa_word_is_not_region(self):
  self.assertEqual(region_fields('방역을 강화하고 있습니다'),{})
 def test_real_regions(self):
  self.assertEqual(region_fields('경남 창녕서 ASF 발생')['region'],'창녕군')
  self.assertEqual(region_fields('전남 순천시 ASF 발생')['region'],'순천시')
  self.assertEqual(region_fields('경기 양평군 ASF 의심 신고')['region'],'양평군')
 def test_suspect_and_result_are_events(self):
  self.assertTrue(event_title('양평군 아프리카돼지열병 의심 신고'))
  self.assertTrue(event_title('양평군 아프리카돼지열병 정밀검사 결과 음성'))
  self.assertEqual(event_status('ASF 의심 신고','PUBLIC_UNCONFIRMED'),'의심 · 정밀검사 중')
  self.assertEqual(event_status('ASF 정밀검사 결과 음성','PUBLIC_UNCONFIRMED'),'음성 · 의심 해제')
  self.assertEqual(event_date('Sun, 27 Sep 2026 03:20:00 GMT'),'2026-09-27')
 def test_republished_old_incident_uses_title_date(self):
  published='Sun, 27 Sep 2026 03:20:00 GMT'
  self.assertEqual(occurrence_date('지난 2월 발생한 양평 ASF 사례 재조명',published),'2026-02-01')
  self.assertEqual(occurrence_date('2026년 2월 14일 ASF 발생 후속 보도',published),'2026-02-14')
 def test_unknown_domestic_title_is_not_forced_to_korea(self):
  self.assertIsNone(country_code('돼지 질병 발생 소식','국내'))
 def test_named_domestic_region_is_korea(self):
  self.assertEqual(country_code('경북 예천군 구제역 발생','국내'),'KR')
 def test_republic_of_korea_is_not_united_states(self):
  self.assertEqual(country_code('대한민국 ASF 발생','국내'),'KR')

if __name__=='__main__':unittest.main()
