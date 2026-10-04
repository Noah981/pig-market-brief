import io,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from scripts import fetch_weather
class WeatherDataTest(unittest.TestCase):
 def test_today_only_not_tomorrow_or_missing_measurements(self):
  today=fetch_weather.datetime.now(fetch_weather.KST).strftime('%Y%m%d')
  def response(rows):return io.BytesIO(json.dumps({'response':{'header':{'resultCode':'00'},'body':{'items':{'item':rows}}}}).encode())
  rows=[{'fcstDate':today,'category':key,'fcstValue':value} for key,value in [('TMP','18'),('TMP','27'),('REH','85'),('POP','40')]]
  rows.append({'fcstDate':'20990101','category':'TMP','fcstValue':'99'})
  with patch.object(fetch_weather.urllib.request,'urlopen',return_value=response(rows)):
   result=fetch_weather.fetch('서울특별시',60,127,'test',today,'0200')
  self.assertEqual(result['tempMax'],27);self.assertEqual(result['forecastDate'],today)
  with patch.object(fetch_weather.urllib.request,'urlopen',return_value=response([r for r in rows if r['category']!='REH'])):
   with self.assertRaises(ValueError):fetch_weather.fetch('서울특별시',60,127,'test',today,'0200')
 def test_network_outage_does_not_overwrite_previous_forecast(self):
  with tempfile.TemporaryDirectory() as root,patch.dict(os.environ,{'KMA_API_KEY':'unit-test'},clear=True):
   path=Path(root)/'weather.json';before='{"updatedAt":"old-observation","regions":[{"region":"fixture"}]}';path.write_text(before)
   with patch.object(fetch_weather,'OUT',path),patch.object(fetch_weather,'fetch',side_effect=TimeoutError):
    with self.assertRaises(SystemExit):fetch_weather.main()
   self.assertEqual(path.read_text(),before)
if __name__=='__main__':unittest.main()
