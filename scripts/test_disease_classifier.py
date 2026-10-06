import unittest,io,zipfile,json,os
from unittest.mock import patch
from scripts.fetch_disease_alerts import parse_asf_hwpx,merge_asf_table
from scripts.fetch_disease_alerts import diseases,event_title,region_fields,country_code,event_status,event_date,occurrence_date,woah_notifications

class DiseaseClassifierTest(unittest.TestCase):
 def test_official_numbered_table_preserves_kimcheon_incident_date(self):
  stream=io.BytesIO()
  xml='<hp:section xmlns:hp="http://www.hancom.co.kr/hwpml/2011/paragraph"><hp:tr>'+''.join('<hp:tc><hp:p><hp:run><hp:t>'+x+'</hp:t></hp:run></hp:p></hp:tc>' for x in ['1','2.12(목)','2,722','경북 김천시 구성면'])+'</hp:tr></hp:section>'
  with zipfile.ZipFile(stream,'w') as z:z.writestr('Contents/section0.xml',xml)
  rows=parse_asf_hwpx(stream.getvalue(),2026,'https://mafra.go.kr/official','2026-03-20',1)
  self.assertEqual(rows[0]['occurrenceDate'],'2026-02-12')
  self.assertEqual(rows[0]['region'],'경상북도 김천시 구성면')
  with self.assertRaises(ValueError):parse_asf_hwpx(stream.getvalue(),2026,'official','2026-03-20',24)
  api=[{'id':'api','disease':'ASF','countryCode':'KR','occurrenceDate':'2026-02-13'},{'id':'future','disease':'ASF','countryCode':'KR','occurrenceDate':'2026-04-01'},{'id':'prrs','disease':'PRRS','countryCode':'KR','occurrenceDate':'2026-02-12'}]
  self.assertEqual([x['id'] for x in merge_asf_table(api,rows)],['future','prrs','MAFRA-ASF-TABLE|2026|1'])
 def test_cattle_fmd_is_kept_with_original_livestock_type(self):
  from scripts.fetch_disease_alerts import mafra_incidents,datetime,KST
  today=datetime.now(KST).strftime('%Y%m%d')
  row={'ICTSD_OCCRRNC_NO':'official-cattle-fmd','LKNTS_NM':'구제역','OCCRRNC_DE':today,'LVSTCKSPC_NM':'소','FARM_LOCPLC':'경기도 포천시 영북면'}
  response=json.dumps({'Grid_20151204000000000316_1':{'totalCnt':1,'row':[row]}},ensure_ascii=False)
  with patch.dict(os.environ,{'MAFRA_API_KEY':'unit-test'}),patch('scripts.fetch_disease_alerts.fetch',return_value=response):items=mafra_incidents()
  self.assertEqual(len(items),1);self.assertEqual(items[0]['disease'],'구제역');self.assertEqual(items[0]['livestockType'],'소')
 def test_prior_year_cumulative_table_includes_dangjin(self):
  stream=io.BytesIO()
  cells=['1','충남 당진시 합덕읍 신리 123','‘25.11.24.','1,000']
  xml='<hp:section xmlns:hp="http://www.hancom.co.kr/hwpml/2011/paragraph"><hp:tr>'+''.join('<hp:tc><hp:p><hp:run><hp:t>'+x+'</hp:t></hp:run></hp:p></hp:tc>' for x in cells)+'</hp:tr></hp:section>'
  with zipfile.ZipFile(stream,'w') as z:z.writestr('Contents/section0.xml',xml)
  rows=parse_asf_hwpx(stream.getvalue(),2025,'https://mafra.go.kr/official','2025-12-30',1)
  self.assertEqual(rows[0]['occurrenceDate'],'2025-11-24')
  self.assertEqual(rows[0]['region'],'충청남도 당진시 합덕읍')
  self.assertNotIn('123',str(rows))
 def test_woah_notifications_exclude_simulations_and_preserve_date_basis(self):
  rows=woah_notifications('<p>04/10/2026 Egypt – Simulation : Foot and mouth disease</p><p>24/09/2026 Namibia: Foot and mouth disease</p><p>18/09/2026 South Sudan: African swine fever</p>')
  self.assertEqual([x['countryCode'] for x in rows],['NA','SS'])
  self.assertEqual([x['disease'] for x in rows],['구제역','ASF'])
  self.assertEqual(rows[1]['announcementDate'],'2026-09-18')
  self.assertEqual(rows[1]['occurrenceDate'],'')
  self.assertEqual(rows[1]['dateBasis'],'notification')
 def test_official_api_abbreviations_are_not_dropped(self):
  self.assertEqual(diseases("ASF"),["ASF"])
  self.assertEqual(diseases("FMD"),["구제역"])
  self.assertEqual(diseases("PED"),["PED"])
  self.assertEqual(diseases("PRRS"),["PRRS"])
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


class DiseaseTransportTest(unittest.TestCase):
 def test_same_official_url_recovers_without_disabling_tls(self):
  from types import SimpleNamespace
  from scripts.fetch_disease_alerts import fetch
  url="https://official.example/data?key=unit-test-only"
  with patch('scripts.fetch_disease_alerts.urllib.request.urlopen',side_effect=TimeoutError()),patch('scripts.fetch_disease_alerts.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=b'{"row":[]}')) as call:
   self.assertEqual('{"row":[]}',fetch(url))
   self.assertEqual(url,call.call_args.args[0][-1])
   self.assertNotIn('--insecure',call.call_args.args[0])
 def test_failed_alternate_transport_remains_unverified_and_redacted(self):
  from types import SimpleNamespace
  from scripts.fetch_disease_alerts import fetch
  with patch('scripts.fetch_disease_alerts.urllib.request.urlopen',side_effect=TimeoutError()),patch('scripts.fetch_disease_alerts.subprocess.run',return_value=SimpleNamespace(returncode=22,stdout=b'error')):
   with self.assertRaises(ValueError) as error:fetch('https://official.example/private-key')
   self.assertNotIn('private-key',str(error.exception))

if __name__=='__main__':unittest.main()

class OfficialSourceRecoveryTest(unittest.TestCase):
 def test_transient_source_failure_recovers_with_validated_result(self):
  from scripts.fetch_disease_alerts import retry_official_source
  expected=[{'id':'official-original','occurrenceDate':'2026-10-06'}]
  from unittest.mock import Mock
  source=Mock(side_effect=[TimeoutError(),expected])
  with patch('scripts.fetch_disease_alerts.time.sleep'):
   self.assertEqual(retry_official_source('MAFRA',source),expected)
 def test_persistent_failure_is_never_reported_as_verified(self):
  from scripts.fetch_disease_alerts import retry_official_source
  from unittest.mock import Mock
  with patch('scripts.fetch_disease_alerts.time.sleep'),self.assertRaises(ValueError):
   retry_official_source('FMD',Mock(side_effect=ValueError('coverage incomplete')))
