import unittest
from scripts.fetch_official_benefits import pig_related,eligible_item
class PigBenefitTests(unittest.TestCase):
 def test_pig_and_shared_farm_support(self):
  for title,target in [('양돈농가 시설 지원 신청',''),('돼지 방역 지원',''),('축산농가 사료구매 융자 지원',''),('가축 사육 농가 분뇨 처리 지원',''),('축산시설 현대화 지원',''),('가축재해보험 지원','돼지 농가')]:
   with self.subTest(title=title):self.assertTrue(pig_related(title,target))
 def test_unrelated_and_explicit_exclusions(self):
  for title,target,summary in [('한우농가 사료 지원','','축산농가 돼지'),('낙농 시설 지원','',''),('양계 방역 지원','',''),('반려동물 지원','',''),('저탄소 벼 농가 지원','',''),('축산농가 사료 지원','양돈 제외',''),('양돈농가 지원','돼지 농가 미지원',''),('양돈사육원 채용 모집','',''),('축산시설 지원','한우 농가','')]:
   with self.subTest(title=title,target=target):self.assertFalse(pig_related(title,target,summary))
 def test_cached_rows_are_filtered_again(self):
  self.assertFalse(eligible_item({'title':'한우 시설 지원','support':'양돈도 언급'}))
  self.assertTrue(eligible_item({'title':'양돈 시설 지원'}))
if __name__=='__main__':unittest.main()
