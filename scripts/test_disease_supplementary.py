import io,unittest,zipfile
from scripts.disease_supplementary import parse_fmd,parse_ped,PROVINCES

class SupplementaryDiseaseTests(unittest.TestCase):
 def hwpx(self,rows,count=2):
  cells=lambda values:'<hp:tr>'+''.join('<hp:tc><hp:p><hp:t>'+v+'</hp:t></hp:p></hp:tc>' for v in values)+'</hp:tr>'
  xml='<hp:section xmlns:hp="http://www.hancom.co.kr/hwpml/2011/paragraph"><hp:p><hp:t>26년 9월 구제역 발생 현황 : '+str(count)+'건</hp:t></hp:p><hp:tbl>'+''.join(cells(r) for r in rows)+'</hp:tbl></hp:section>'
  out=io.BytesIO()
  with zipfile.ZipFile(out,'w') as archive:archive.writestr('Contents/section0.xml',xml)
  return out.getvalue()
 def test_fmd_same_date_region_different_farms_remain_distinct(self):
  data=self.hwpx([['1차','예찰','26.9.3.','경북','예천군','소','86','O형'],['2차','예찰','26.9.3.','경북','예천군','소','46','O형']])
  result=parse_fmd(data,'https://www.mafra.go.kr','2026-09-23')
  self.assertEqual(len(result),2);self.assertNotEqual(result[0]['id'],result[1]['id']);self.assertEqual(result[0]['livestockType'],'소');self.assertNotIn('latitude',result[0])
 def test_fmd_incomplete_table_rejected(self):
  with self.assertRaises(ValueError):parse_fmd(self.hwpx([['1차','예찰','26.9.3.','경북','예천군','소','86','O형']]),'https://www.mafra.go.kr','2026-09-23')
 def ped(self,total=2):
  names=[n for n in PROVINCES if n!='광주']
  header='<tr>'+''.join('<td class="list_title">'+n+'</td>' for n in ['월',*names,'소계'])+'</tr>'
  def row(name,last):
   nums=[(10,2)]+[(0,0)]*(len(names)-1)+[(10,last)]
   return '<tr><td name="yymm">'+name+'</td>'+''.join('<td><span class="had">'+str(a)+'</span>(<span class="co">'+str(f)+'</span>)</td>' for a,f in nums)+'</tr>'
  return '<option value="0422" selected="selected">PED</option><input name="occrFromDt" value="2026-09-05"><input name="occrToDt" value="2026-10-05">'+header+row('202609',2)+row('합 계',total)
 def test_ped_is_aggregate_not_fabricated_farm_incidents(self):
  result=parse_ped(self.ped(),'2026-09-05','2026-10-05')
  self.assertEqual(result['farmCount'],2);self.assertEqual(result['animalCount'],10);self.assertEqual(result['regions'][0]['province'],'서울특별시');self.assertNotIn('latitude',result['regions'][0]);self.assertNotIn('occurrenceDate',result)
 def test_ped_explicit_empty_is_zero_but_missing_html_is_not(self):
  raw=self.ped();raw=raw[:raw.index('<tr><td name="yymm">')]+ '<tr><th>조회된 결과가 없습니다.</th></tr>'
  self.assertEqual(parse_ped(raw,'2026-09-05','2026-10-05')['farmCount'],0)
  with self.assertRaises(ValueError):parse_ped(raw.replace('조회된 결과가 없습니다.',''),'2026-09-05','2026-10-05')
 def test_ped_mismatched_totals_and_wrong_scope_rejected(self):
  with self.assertRaises(ValueError):parse_ped(self.ped(3),'2026-09-05','2026-10-05')
  with self.assertRaises(ValueError):parse_ped(self.ped(),'2026-08-05','2026-10-05')
if __name__=='__main__':unittest.main()

class SupplementaryTransportTest(unittest.TestCase):
 def test_post_fallback_preserves_ped_scope_and_tls_verification(self):
  from scripts.disease_supplementary import request
  from unittest.mock import patch
  from types import SimpleNamespace
  body=b'dissCl=0422&occrFromDt=2026-09-06&occrToDt=2026-10-06'
  url='https://home.kahis.go.kr/official'
  with patch('scripts.disease_supplementary.urllib.request.urlopen',side_effect=TimeoutError()),patch('scripts.disease_supplementary.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=b'<table>official</table>')) as call:
   self.assertEqual(request(url,body),b'<table>official</table>')
   self.assertEqual(call.call_args.kwargs['input'],body)
   self.assertIn('--data-binary',call.call_args.args[0]);self.assertNotIn('--insecure',call.call_args.args[0])
 def test_failed_fallback_does_not_expose_url_or_credentials(self):
  from scripts.disease_supplementary import request
  from unittest.mock import patch
  from types import SimpleNamespace
  url='https://official.example/?key=private-test-key'
  with patch('scripts.disease_supplementary.urllib.request.urlopen',side_effect=TimeoutError()),patch('scripts.disease_supplementary.subprocess.run',return_value=SimpleNamespace(returncode=28,stdout=b'',stderr=url.encode())),self.assertRaises(ValueError) as error:request(url)
  self.assertNotIn('private-test-key',str(error.exception));self.assertNotIn(url,str(error.exception))
