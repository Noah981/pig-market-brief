import unittest
from unittest.mock import patch
from scripts.fetch_official_benefits import bizinfo_detail,collect_bizinfo_public,pig_related,collect

DETAIL='''<ul><li><span class="s_title">소관부처·지자체</span><div class="txt">경상남도</div></li><li><span class="s_title">신청기간</span><div class="txt">2025.12.23 ~ 2026.12.31</div></li><li><span class="s_title">사업개요</span><div class="txt"><p>가축분뇨 운반 수수료 지원</p><p>☞ 돈사 면적 1,000㎡ 이하 양돈농가</p><p>☞ 규모별 지원</p></div></li></ul>'''
ROW='''<table><tbody><tr><td>1</td><td>경영</td><td><a href= "/sii/siia/selectSIIA200Detail.do?pblancId=TEST">[경남] 김해시 가축분뇨 수수료 지원사업</a></td><td>2025-12-23 ~ 2026-12-31</td><td>경상남도</td><td>시청</td><td>2025-12-24</td></tr></tbody></table>'''
EMPTY='<table><tbody><tr><td>등록된 게시물이 없습니다.</td></tr></tbody></table>'
class PublicBenefitTests(unittest.TestCase):
 def test_body_eligibility_is_read_before_filtering_and_deduplicated(self):
  def response(url):return DETAIL if 'Detail.do' in url else ROW
  with patch('scripts.fetch_official_benefits.fetch',side_effect=response):items,status=collect_bizinfo_public()
  self.assertEqual(len(items),1);self.assertIn('양돈농가',items[0]['target']);self.assertEqual(items[0]['deadline'],'2026-12-31');self.assertEqual(items[0]['region'],'경남·김해시')
 def test_missing_list_structure_is_not_zero_notices(self):
  with patch('scripts.fetch_official_benefits.fetch',return_value='<h1>지원사업 공고</h1>'):
   with self.assertRaises(ValueError):collect_bizinfo_public()
 def test_detail_schema_failure_is_not_silent_exclusion(self):
  with self.assertRaises(ValueError):bizinfo_detail('<html>일시적 오류</html>')
 def test_other_species_only_body_is_excluded(self):
  def response(url):return DETAIL.replace('돈사 면적 1,000㎡ 이하 양돈농가','한우농가') if 'Detail.do' in url else ROW
  with patch('scripts.fetch_official_benefits.fetch',side_effect=response):items,status=collect_bizinfo_public()
  self.assertEqual(items,[])
 def test_crop_only_summary_is_not_pig_eligible(self):
  self.assertFalse(pig_related('농·축산시설 탄소 지원사업',summary='토마토 재배 온실 테스트베드 활용 지원'))
 def test_official_guideline_has_no_invented_application_deadline(self):
  source={'id':'mafra-livestock-guideline','kind':'guideline','agency':'농림축산식품부','url':'https://www.mafra.go.kr/bbs/home/795/575876/artclView.do'}
  from datetime import datetime
  with patch('scripts.fetch_official_benefits.fetch',return_value=f'<dt>{datetime.now().year}년 축사시설현대화사업 시행지침</dt>'):
   rows=collect(source)
  self.assertEqual(rows[0]['region'],'전국');self.assertNotIn('deadline',rows[0]);self.assertIn('접수 일정 확인',rows[0]['applicationPeriod'])
if __name__=='__main__':unittest.main()
