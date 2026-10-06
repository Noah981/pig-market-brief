import json,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from kahis_occurrences import parse_page,normalize_pages

class KahisTests(unittest.TestCase):
 def fixture(self,last=1,count=1):
  fields=''.join(f'<input name="{k}" value="{v}">' for k,v in [('pageIndex',1),('occrFromDt','2025-10-05'),('occrToDt','2026-10-06')])
  fields+='<input name="turmGubun" value="02" checked>'
  fields+=''.join(f'<select name="{k}"><option value="">전체</option></select>' for k in ('dissCl','lstkspCl','ctprvn','signgu'))
  heads=['가축전염병명','농장명(농장주)','농장소재지','발생일자(진단일)','축종(품종)','발생두수','진단기관','종식일']
  fields+='<tr>'+''.join('<td class="list_title">'+v+'</td>' for v in heads)+'</tr>'
  for i in range(count):
   vals=['돼지생식기호흡기증후군','비공개농장'+str(i),'경기도 포천시 비공개로 123','2026-09-01 (2026-09-02)','돼지-일반','1','검역본부','']
   fields+='<tr>'+''.join('<td>'+v+'</td>' for v in vals)+'</tr>'
  return fields+f'<a onclick="fn_page_link({last})">마지막</a>'
 def test_dates_and_private_farm_text(self):
  _,rows=parse_page(self.fixture(),'2025-10-05','2026-10-06',1)
  item=rows[0][1];self.assertEqual(item['occurrenceDate'],'2026-09-01');self.assertEqual(item['diagnosisDate'],'2026-09-02');self.assertEqual(item['region'],'경기도 포천시')
  self.assertNotIn('비공개',json.dumps(item,ensure_ascii=False))
 def test_wrong_scope_page_and_date_rejected(self):
  for before,after in [('value="02"','value="01"'),('value="2025-10-05"','value="2025-10-06"'),('name="pageIndex" value="1"','name="pageIndex" value="2"'),('2026-09-01 (','2027-09-01 (')]:
   with self.subTest(before=before),self.assertRaises(ValueError):parse_page(self.fixture().replace(before,after),'2025-10-05','2026-10-06',1)
 def test_short_nonfinal_page_rejected(self):
  with self.assertRaises(ValueError):parse_page(self.fixture(last=2,count=9),'2025-10-05','2026-10-06',1)
 def test_missing_or_empty_table_rejected(self):
  for raw in ('',self.fixture(count=0)):
   with self.assertRaises(ValueError):parse_page(raw,'2025-10-05','2026-10-06',1)
 def test_distinct_farms_have_distinct_opaque_ids(self):
  _,rows=parse_page(self.fixture(count=2),'2025-10-05','2026-10-06',1)
  self.assertNotEqual(rows[0][1]['id'],rows[1][1]['id'])

 def test_identical_records_normalized_but_repeated_pages_rejected(self):
  _,rows=parse_page(self.fixture(),'2025-10-05','2026-10-06',1)
  self.assertEqual(len(normalize_pages([rows+rows])),1)
  with self.assertRaises(ValueError):normalize_pages([rows,rows])
