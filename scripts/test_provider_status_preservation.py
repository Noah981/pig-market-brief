import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from scripts import platform_pipeline

class ProviderStatusTests(unittest.TestCase):
 def test_general_adapter_keeps_independent_source_states(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);(root/'config').mkdir();(root/'docs/data').mkdir(parents=True)
   (root/'config/platform_sources.json').write_text(json.dumps({'sources':[]}))
   path=root/'docs/data/platform.json'
   previous={'markets':[{'name':'corn','date':'2026-07-01','status':'LIVE'}],'benefits':[],'sourceStatus':[{'id':'fred-public-series','status':'연결 완료'},{'id':'bizinfo','status':'API 승인 또는 키 연결 대기'}]}
   path.write_text(json.dumps(previous))
   with patch.object(platform_pipeline,'ROOT',root):platform_pipeline.main()
   result=json.loads(path.read_text())
  self.assertEqual(result['sourceStatus'],previous['sourceStatus'])
  self.assertEqual(result['markets'],previous['markets'])

if __name__=='__main__':unittest.main()
