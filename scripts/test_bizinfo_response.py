import json
import unittest
from unittest.mock import patch
from scripts.fetch_official_benefits import bizinfo_rows, collect_bizinfo

class BizinfoResponseTests(unittest.TestCase):
 def test_documented_and_array_responses(self):
  row={'pblancNm':'축산 지원'}
  for document in [{'jsonArray':{'item':[row]}},{'jsonArray':[row]},[row],{'item':row}]:
   self.assertEqual(bizinfo_rows(document),[row])
 def test_authentication_error_is_not_zero_notices(self):
  with self.assertRaises(ValueError):bizinfo_rows({'error':'invalid credential'})
  self.assertEqual(bizinfo_rows({'jsonArray':{'item':[]}}),[])
 def test_all_notices_relative_official_urls_and_livestock_filter(self):
  rows=[{'pblancNm':'2026년 축산농가 시설 지원 신청','pblancUrl':'/web/lay1/bbs/view.do?pblancId=1','pblancId':'1','hashTags':'경북','reqstBeginEndDe':'20261001 ~ 20261031'},
        {'pblancNm':'식당 시설 지원 신청','pblancUrl':'https://www.bizinfo.go.kr/view/2'},
        {'pblancNm':'축산 시설 지원','pblancUrl':'https://example.com/fake'}]
  def response(url):
   from urllib.parse import parse_qs,urlparse
   self.assertEqual(parse_qs(urlparse(url).query)['searchCnt'],['0'])
   return json.dumps({'jsonArray':rows})
  with patch.dict('os.environ',{'BIZINFO_API_KEY':'fixture'}),patch('scripts.fetch_official_benefits.fetch',side_effect=response):
   items,status=collect_bizinfo()
  self.assertEqual(len(items),1);self.assertEqual(items[0]['region'],'경북')
  self.assertEqual(items[0]['deadline'],'2026-10-31');self.assertIn('연결 완료',status)

if __name__=='__main__':unittest.main()
