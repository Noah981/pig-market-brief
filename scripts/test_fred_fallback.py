import io
import unittest
from unittest.mock import patch
from scripts.fetch_fred_markets import SERIES,parse_table,fetch_one

TABLE=b'''<tr><th>Series ID</th><td>DEXKOUS</td></tr>
<tr><th scope="row">2026-09-23</th><td>1366.99</td></tr>
<div id="extra-rows">#2026-09-24|1369.44 #2026-09-25|1356.51 #2026-09-26|. #2099-01-01|9000</div>'''

class FredFallbackTests(unittest.TestCase):
 def test_table_uses_latest_deferred_observations(self):
  row=parse_table('usd_krw',SERIES['usd_krw'],TABLE)
  self.assertEqual(row['date'],'2026-09-25')
  self.assertEqual(row['previousValue'],1369.44)
  self.assertEqual(row['value'],1356.51)
  self.assertEqual(len(row['history']),3)
 def test_wrong_series_cannot_be_used(self):
  with self.assertRaises(ValueError):parse_table('wti',SERIES['wti'],TABLE)
 def test_csv_timeout_uses_official_table(self):
  with patch('scripts.fetch_fred_markets.urllib.request.urlopen',side_effect=[TimeoutError(),io.BytesIO(TABLE)]) as request:
   row=fetch_one('usd_krw',SERIES['usd_krw'])
  self.assertEqual(row['date'],'2026-09-25')
  self.assertEqual(request.call_args_list[1].args[0].full_url,'https://fred.stlouisfed.org/data/DEXKOUS')

if __name__=='__main__':unittest.main()
