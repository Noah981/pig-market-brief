import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from scripts.validate_official_apis import get

class OfficialTransportTests(unittest.TestCase):
    def test_https_fallback_reuses_url_and_preserves_schema(self):
        url="https://official.example/data?serviceKey=test-only"
        with patch("scripts.validate_official_apis.urllib.request.urlopen",side_effect=TimeoutError()), patch("scripts.validate_official_apis.time.sleep"), patch("scripts.validate_official_apis.subprocess.run",return_value=SimpleNamespace(returncode=0,stdout=b'{"response":{"header":{"resultCode":"00"}}}')) as call:
            self.assertEqual("00",get("KMA",url,json_response=True)["response"]["header"]["resultCode"])
            self.assertEqual(url,call.call_args.args[0][-1])
            self.assertNotIn("--insecure",call.call_args.args[0])
    def test_error_document_and_transport_failure_cannot_pass(self):
        for result in [SimpleNamespace(returncode=0,stdout=b"<html>error</html>"),SimpleNamespace(returncode=22,stdout=b'{"response":{}}')]:
            with patch("scripts.validate_official_apis.urllib.request.urlopen",side_effect=TimeoutError()), patch("scripts.validate_official_apis.time.sleep"), patch("scripts.validate_official_apis.subprocess.run",return_value=result):
                with self.assertRaises(RuntimeError):get("KMA","https://official.example/data",json_response=True)

if __name__ == "__main__": unittest.main()
